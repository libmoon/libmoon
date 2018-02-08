--- Fast pcap IO, can write > 40 Gbit/s (to fs cache) and read > 30 Mpps (from fs cache).
--- Read/write performance can saturate several NVMe SSDs from a single core.

local mod = {}

local S      = require "syscall"
local ffi    = require "ffi"
local log    = require "log"
local libmoon = require "libmoon"

local cast = ffi.cast
local memcopy = ffi.copy
local C = ffi.C
local min = math.min

-- http://wiki.wireshark.org/Development/LibpcapFileFormat/
ffi.cdef[[
typedef struct {
	uint32_t magic_number;  /* magic number */
	uint16_t version_major; /* major version number */
	uint16_t version_minor; /* minor version number */
	int32_t thiszone;       /* GMT to local correction */
	uint32_t sigfigs;       /* accuracy of timestamps */
	uint32_t snaplen;       /* max length of captured packets, in octets */
	uint32_t network;       /* data link type */
} pcap_hdr_t;

typedef struct {
	uint32_t ts_sec;   /* timestamp seconds */
	uint32_t ts_usec;  /* timestamp microseconds */
	uint32_t incl_len; /* number of octets of packet saved in file */
	uint32_t orig_len; /* actual length of packet */
	uint8_t data[];
} pcaprec_hdr_t;
]]

local headerType = ffi.typeof("pcap_hdr_t")
local headerPointer = ffi.typeof("pcap_hdr_t*")
local packetType = ffi.typeof("pcaprec_hdr_t")
local packetPointer = ffi.typeof("pcaprec_hdr_t*")
local voidPointer = ffi.typeof("void*")

local INITIAL_FILE_SIZE = 512 * 1024 * 1024

--- Set the file size for new pcap writers
--- @param newSizeInBytes new file size in bytes
function mod:setInitialFilesize(newSizeInBytes)
	INITIAL_FILE_SIZE = newSizeInBytes
end

local writer = {}
writer.__index = writer

local function writeHeader(ptr)
	local hdr = headerPointer(ptr)
	hdr.magic_number = 0xa1b2c3d4
	hdr.version_major = 2
	hdr.version_minor = 4
	hdr.thiszone = 0
	hdr.sigfigs = 0
	hdr.snaplen = 0x40000
	hdr.network = 1
	return ffi.sizeof(headerType)
end

--- Create a new fast pcap writer with the given file name.
--- Call :close() on the writer when you are done.
--- @param startTime posix timestamp, all timestamps of inserted packets will be relative to this timestamp
---        default: relative to libmoon.getTime() == 0
function mod:newWriter(filename, startTime)
	startTime = startTime or wallTime() - libmoon.getTime()
	local fd = S.open(filename, "creat, rdwr, trunc", "0666")
	if not fd then
		log:fatal("could not create pcap file: %s", strError(S.errno()))
	end
	fd:nogc()
	local size = INITIAL_FILE_SIZE
	if not S.fallocate(fd, 0, 0, size) then
		log:fatal("fallocate failed: %s", strError(S.errno()))
	end
	local ptr = S.mmap(nil, size, "write", "shared, noreserve", fd, 0)
	if not ptr then
		log:fatal("mmap failed: %s", strError(S.errno()))
	end
	local offset = writeHeader(ptr)
	ptr = cast("uint8_t*", ptr)
	return setmetatable({fd = fd, ptr = ptr, size = size, offset = offset, startTime = startTime}, writer)
end

function writer:resize(size)
	if not S.fallocate(self.fd, 0, 0, size) then
		log:fatal("fallocate failed: %s", strError(S.errno()))
	end
	-- two ways to prevent MAP_MAYMOVE here if someone wants to implement this:
	-- 1) mmap a large virtual address block (and use MAP_FIXED to not have a huge file)
	-- 2) unmap the whole old area, mmap only the newly allocated file space (and the last page of the old space)
	-- problem with 1 is: wastes a lot of virtual address space, problematic if we have multiple writers at the same time
	-- so implement 2) if you feel like it (however, I haven't noticed big problems with the current MAP_MAYMOVE implementation)
	local ptr = S.mremap(self.ptr, self.size, size, "maymove")
	if not ptr then
		log:fatal("mremap failed: %s", strError(S.errno()))
	end
	self.ptr = cast("uint8_t*", ptr)
	self.size = size
end

--- Close and truncate the file.
function writer:close()
	S.munmap(self.ptr, self.size)
	S.ftruncate(self.fd, self.offset)
	S.fsync(self.fd)
	S.close(self.fd)
	self.fd = nil
	self.ptr = nil
end

ffi.cdef[[
	void libmoon_write_pcap(void* dst, const void* packet, uint32_t len, uint32_t orig_len, uint32_t ts_sec, uint32_t ts_usec);
]]

--- Write a packet to the pcap file
--- @param timestamp relative to the timestamp specified when creating the file
function writer:write(timestamp, data, len, origLen)
	if self.offset + len + 16 >= self.size then
		self:resize(self.size * 2)
	end
	local time = self.startTime + timestamp
	local timeSec = math.floor(time)
	local timeMicros = (time - timeSec) * 1000000
	C.libmoon_write_pcap(self.ptr + self.offset, data, len, origLen or len, time, timeMicros)
	self.offset = self.offset + len + 16
end

--- Write a mbuf to the pcap file
--- @param timestamp relative to the timestamp specified when creating the file
--- @param snapLen truncate the packet to this size
function writer:writeBuf(timestamp, buf, snapLen)
	local size = buf:getSize()
	snapLen = snapLen or size
	self:write(timestamp, buf:getData(), min(size, snapLen), size)
end

local reader = {}
reader.__index = reader

local function readHeader(ptr)
	local hdr = headerPointer(ptr)
	if hdr.magic_number == 0xd4c3b2a1 then
		log:fatal("big endian pcaps are not supported")
	elseif hdr.magic_number ~= 0xa1b2c3d4 then
		log:fatal("not a pcap file")
	end
	if hdr.version_major ~= 2 or hdr.version_minor ~= 4 then
		log:fatal("unsupported pcap version")
	end
	if hdr.thiszone ~= 0 then
		log:warn("timezone information in pcap header ignored")
	end
	if hdr.network ~= 1 then
		log:fatal("unsupported link layer type")
	end
	return ffi.sizeof(headerType)
end

--- Create a new fast pcap reader for the given file name.
--- Call :close() on the reader when you are done to avoid fd leakage.
function mod:newReader(filename)
	local fd = S.open(filename, "rdonly")
	if not fd then
		log:fatal("could not open pcap file: %s", strError(S.errno()))
	end
	local size = fd:stat().size
	fd:nogc()
	local ptr = S.mmap(nil, size, "read", "private", fd, 0)
	if not ptr then
		log:fatal("mmap failed: %s", strError(S.errno()))
	end
	local offset = readHeader(ptr)
	ptr = cast("uint8_t*", ptr)
	return setmetatable({fd = fd, ptr = ptr, size = size, offset = offset}, reader)
end

ffi.cdef[[
	struct rte_mbuf* libmoon_read_pcap(struct mempool* mp, const void* pcap, uint64_t remaining, uint32_t mempool_buf_size);
	uint32_t libmoon_read_pcap_batch(struct mempool* mp, struct rte_mbuf** bufs, uint32_t num_bufs, const void* pcap, uint64_t remaining, uint32_t mempool_buf_size);
]]

--- Read the next packet into a buf, the timestamp is stored in the udata64 field as microseconds.
--- The buffer's packet size corresponds to the original packet size, cut off bytes are zero-filled.
function reader:readSingle(mempool, mempoolBufSize)
	mempoolBufSize = mempoolBufSize or 2048
	local fileRemaining = self.size - self.offset
	if fileRemaining < 32 then -- header size
		return nil
	end
	local buf = C.libmoon_read_pcap(mempool, self.ptr + self.offset, fileRemaining, mempoolBufSize)
	if buf then
		self.offset = self.offset + buf.pkt_len + 16
		-- chained mbufs not supported for now
		buf.pkt_len = buf.data_len
	end
	return buf
end

--- Read a batch of packets into a bufArray, the timestamp is stored in the udata64 field as microseconds.
--- The buffer's packet size corresponds to the original packet size, cut off bytes are zero-filled.
--- @return the number of packets read
function reader:read(bufs, mempoolBufSize)
	mempoolBufSize = mempoolBufSize or 2048
	local fileRemaining = self.size - self.offset
	if fileRemaining < 32 then -- header size
		return 0
	end
	local numRead = C.libmoon_read_pcap_batch(bufs.mem, bufs.array, bufs.size, self.ptr + self.offset, fileRemaining, mempoolBufSize)
	for i = 0, numRead - 1 do
		self.offset = self.offset + bufs.array[i].pkt_len + 16
		-- chained mbufs not supported for now
		bufs.array[i].pkt_len = bufs.array[i].data_len
	end
	return numRead
end

function reader:close()
	S.munmap(self.ptr, self.size)
	S.close(self.fd)
	self.fd = nil
	self.ptr = nil
end

function reader:reset()
	self.offset = ffi.sizeof(headerType)
end


return mod


--- pcap IO

local mod = {}

local S   = require "syscall"
local ffi = require "ffi"
local log = require "log"

local cast = ffi.cast
local memcopy = ffi.copy
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

local INITIAL_FILE_SIZE = 16 * 1024 * 1024

local writer = {}
writer.__index = writer

local function writeHeader(ptr)
	local hdr = headerPointer(ptr)
	hdr.magic_number = 0xa1b2c3d4
	hdr.version_major = 2
	hdr.version_minor = 4
	hdr.thiszone = 0
	hdr.sigfigs = 0
	hdr.snaplen = 0x7FFFFFFF
	hdr.network = 1
	return ffi.sizeof(headerType)
end

--- Create a new fast pcap writer with the given file name.
--- Call :close() on the writer when you are done.
--- @param startTime posix timestamp, all timestamps of inserted packets will be relative to this timestamp
function mod:newWriter(filename, startTime)
	startTime = startTime or 0
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
		log:fatal("mmap failed")
	end
	local offset = writeHeader(ptr)
	ptr = cast("uint8_t*", ptr)
	return setmetatable({fd = fd, ptr = ptr, size = size, offset = offset, startTime = startTime}, writer)
end

function writer:resize(size)
	if not S.fallocate(self.fd, 0, 0, size) then
		log:fatal("fallocate failed: %s", strError(S.errno()))
	end
	local ptr = S.mremap(self.ptr, self.size, size, "maymove")
	if not ptr then
		log:fatal("mremap failed")
	end
	self.ptr = cast("uint8_t*", ptr)
	self.size = size
end

--- Close and truncate the file.
function writer:close()
	S.ftruncate(self.fd, self.offset)
	S.fsync(self.fd)
	S.munmap(self.ptr, self.size)
	S.close(self.fd)
	self.fd = nil
	self.ptr = nil
end

--- Write a packet to the pcap file
--- @param timestamp relative to the timestamp specified when creating the file
function writer:write(timestamp, data, len, origLen)
	if self.offset + len + 16 >= self.size then
		self:resize(self.size * 2)
	end
	pkt = packetPointer(voidPointer(self.ptr + self.offset))
	pkt.ts_sec = 0
	pkt.ts_usec = 0
	pkt.incl_len = len
	pkt.orig_len = origLen or len
	memcopy(pkt.data, data, len)
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

return mod

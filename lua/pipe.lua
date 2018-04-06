--- Inter-task communication via pipes
local mod = {}

local memory  = require "memory"
local ffi     = require "ffi"
local serpent = require "Serpent"
local libmoon = require "libmoon"
local log     = require "log"
local S       = require "syscall"

ffi.cdef [[
	// dummy
	struct spsc_ptr_queue { };
	struct mpmc_ptr_queue { };

	struct spsc_ptr_queue* pipe_spsc_new(int size);
	void pipe_spsc_delete(struct spsc_ptr_queue* queue);
	void pipe_spsc_enqueue(struct spsc_ptr_queue* queue, void* data);
	uint8_t pipe_spsc_try_enqueue(struct spsc_ptr_queue* queue, void* data);
	void* pipe_spsc_try_dequeue(struct spsc_ptr_queue* queue);
	size_t pipe_spsc_count(struct spsc_ptr_queue* queue);

	struct mpmc_ptr_queue* pipe_mpmc_new(int size);
	void pipe_mpmc_delete(struct mpmc_ptr_queue* queue);
	void pipe_mpmc_enqueue(struct mpmc_ptr_queue* queue, void* data);
	uint8_t pipe_mpmc_try_enqueue(struct mpmc_ptr_queue* queue, void* data);
	void* pipe_mpmc_try_dequeue(struct mpmc_ptr_queue* queue);
	size_t pipe_mpmc_count(struct mpmc_ptr_queue* queue);
	
	// DPDK SPSC ring
	struct rte_ring { };
	struct rte_ring* create_ring(uint32_t count, int32_t socket);
	void free_ring(struct rte_ring* r);
	int ring_enqueue(struct rte_ring* r, struct rte_mbuf** obj, int n);
	int ring_dequeue(struct rte_ring* r, struct rte_mbuf** obj, int n);
	int ring_count(struct rte_ring* r);
	int ring_free_count(struct rte_ring* r);
	bool ring_empty(struct rte_ring* r);
	bool ring_full(struct rte_ring* r);
]]

local C = ffi.C

mod.packetRing = {}
local packetRing = mod.packetRing
packetRing.__index = packetRing

function mod:newPacketRing(size, socket)
	size = size or 512
	socket = socket or -1
	return setmetatable({
		ring = C.create_ring(size, socket)
	}, packetRing)
end

function mod:newPacketRingFromRing(ring)
	return setmetatable({
		ring = ring
	}, packetRing)
end

local ENOBUFS = S.c.E.NOBUFS

-- FIXME: this is work-around for some bug with the serialization of nested objects
function mod:sendToPacketRing(ring, bufs, n)
	return C.ring_enqueue(ring, bufs.array, n or bufs.size) > 0
end

function packetRing:free()
	return C.free_ring(self.ring)
end

-- try to enqueue packets in a ring, returns true on success
function packetRing:send(bufs)
	return C.ring_enqueue(self.ring, bufs.array, bufs.size) > 0
end

-- try to enqueue packets in a ring, returns true on success
function packetRing:sendN(bufs, n)
	return C.ring_enqueue(self.ring, bufs.array, n) > 0
end

-- returns number of packets received
function packetRing:recv(bufs)
	return C.ring_dequeue(self.ring, bufs.array, bufs.size)
end

-- returns number of packets received
function packetRing:recvN(bufs, n)
	return C.ring_dequeue(self.ring, bufs.array, n)
end

function packetRing:count()
	return C.ring_count(self.ring)
end

function packetRing:freeCount()
	return C.ring_free_count(self.ring)
end

function packetRing:empty()
	return C.ring_empty(self.ring)
end

function packetRing:full()
	return C.ring_full(self.ring)
end

function packetRing:__serialize()
	return "require'pipe'; return " .. serpent.addMt(serpent.dumpRaw(self), "require('pipe').packetRing"), true
end

mod.slowPipe = {}
local slowPipe = mod.slowPipe
slowPipe.__index = slowPipe

--- Create a new slow pipe.
--- Slow pipes are called slow pipe because they are slow (duh).
--- Any objects passed to it will be *serialized* as strings.
--- This means that it supports arbitrary Lua objects following libmoon's usual serialization rules.
--- Use a 'fast pipe' if you need fast inter-task communication. Fast pipes are restricted to LuaJIT FFI objects.
--- Rule of thumb: use a slow pipe if you don't need more than a few thousand messages per second,
--- e.g. to pass aggregated data or statistics between tasks. Use fast pipes if you intend to do something for
--- every (or almost every) packet you process.
function mod:newSlowPipe()
	return setmetatable({
		pipe = C.pipe_mpmc_new(512)
	}, slowPipe)
end

-- This is work-around for some bug with the serialization of nested objects
function mod:sendToSlowPipe(slowPipe, ...)
	local vals = serpent.dump({...})
	local buf = memory.alloc("char*", #vals + 1)
	ffi.copy(buf, vals)
	C.pipe_mpmc_enqueue(slowPipe.pipe, buf)
end

function slowPipe:send(...)
	local vals = serpent.dump({ ... })
	local buf = memory.alloc("char*", #vals + 1)
	ffi.copy(buf, vals)
	C.pipe_mpmc_enqueue(self.pipe, buf)
end

function slowPipe:tryRecv(wait)
	wait = wait or 0
	while wait >= 0 do
		local buf = C.pipe_mpmc_try_dequeue(self.pipe)
		if buf ~= nil then
			local result = loadstring(ffi.string(buf))()
			memory.free(buf)
			return unpackAll(result)
		end
		wait = wait - 10
		if wait < 0 then
			break
		end
		libmoon.sleepMicrosIdle(10)
	end
end

function slowPipe:recv()
	local function loop(...)
		if not ... then
			return loop(self:tryRecv(10))
		else
			return ...
		end
	end
	return loop()
end

function slowPipe:count()
	return tonumber(C.pipe_mpmc_count(self.pipe))
end

-- Dequeue and discard all objects from pipe
function slowPipe:empty()
	while self:count() > 0 do
		self:recv()
	end
end

function slowPipe:delete()
	C.pipe_mpmc_delete(self.pipe)
end

function slowPipe:__serialize()
	return "require'pipe'; return " .. serpent.addMt(serpent.dumpRaw(self), "require('pipe').slowPipe"), true
end


mod.fastPipe = {}
local fastPipe = mod.fastPipe
fastPipe.__index = fastPipe

--- Create a new fast pipe.
--- A pipe can only be used by exactly two tasks: a single reader and a single writer.
--- Fast pipes are fast, but only accept FFI cdata pointers and nothing else.
--- Use a slow pipe to pass arbitrary objects.
--- TODO: add a MPMC variant (pull requests welcome)
function mod:newFastPipe(size)
	return setmetatable({
		pipe = C.pipe_spsc_new(size or 512)
	}, fastPipe)
end

function fastPipe:send(obj)
	C.pipe_spsc_enqueue(self.pipe, obj)
end

function fastPipe:trySend(obj)
	return C.pipe_spsc_try_enqueue(self.pipe, obj) ~= 0
end

-- FIXME: this is work-around for some bug with the serialization of nested objects
function mod:sendToFastPipe(pipe, obj)
	return C.pipe_spsc_try_enqueue(pipe, obj) ~= 0
end

function fastPipe:tryRecv(wait)
	while wait >= 0 do
		local buf = C.pipe_spsc_try_dequeue(self.pipe)
		if buf ~= nil then
			return buf
		end
		wait = wait - 10
		if wait < 0 then
			break
		end
		libmoon.sleepMicrosIdle(10)
	end
end

function fastPipe:recv()
	local function loop(...)
		if not ... then
			return loop(self:tryRecv(10))
		else
			return ...
		end
	end
	return loop()
end

function fastPipe:count()
	return tonumber(C.pipe_spsc_count(self.pipe))
end

function fastPipe:delete()
	C.pipe_spsc_delete(self.pipe)
end

function fastPipe:__serialize()
	return "require'pipe'; return " .. serpent.addMt(serpent.dumpRaw(self), "require('pipe').fastPipe"), true
end

return mod


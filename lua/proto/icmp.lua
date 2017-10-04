------------------------------------------------------------------------
--- @file icmp.lua
--- @brief Internet control message protocol utility.
--- Utility functions for the icmp_header struct
--- Includes:
--- - Icmp4 constants
--- - Icmp6 constants
--- - Icmp header utility
--- - Definition of Icmp packets
------------------------------------------------------------------------

local ffi     = require "ffi"
local ns      = require "namespaces"
local pipe    = require "pipe"
local memory  = require "memory"
local libmoon = require "libmoon"
local log     = require "log"
local eth     = require "proto.ethernet"
local ip      = require "proto.ip4"

require "utils"
require "proto.template"
local initHeader = initHeader

local ntoh, hton = ntoh, hton
local ntoh16, hton16 = ntoh16, hton16
local bor, band, bnot, rshift, lshift= bit.bor, bit.band, bit.bnot, bit.rshift, bit.lshift
local istype = ffi.istype
local format = string.format

-- FIXME
-- ICMPv6 and ICMPv4 use different values for the same types/codes which causes some complications when handling this with only one header:
-- - getString() does not work for ICMPv6 correctly without some ugly workarounds (basically adding 'ipv4' flags to getString()'s of type/code and header)
-- 	 currently getString() simply does not recognise ICMPv6
-- - Furthermore, packetDump would need a change to pass this flag when calling getString()


---------------------------------------------------------------------------
---- ICMPv4 constants
---------------------------------------------------------------------------

--- Icmp4 protocol constants
local icmp = {}

--- Icmp4 type-code pair: echo reply
icmp.ECHO_REPLY					= { type = 0, code = 0 }
--- Icmp4 type-code pair: echo request
icmp.ECHO_REQUEST 				= { type = 8, code = 0 }

--- Icmp4 type-code pair: destination unreachable - port unreachable
icmp.DST_UNR_PORT_UNR		 	= { type = 3, code = 3 }

--- Icmp4 type-code pair: time exceeded - TTL exceeded
icmp.TIME_EXCEEDED_TTL_EXPIRED	= { type = 11, code = 0 }


--------------------------------------------------------------------------
---- ICMPv6 constants
---------------------------------------------------------------------------

--- Icmp6 protocol constants
local icmp6 = {}

--- Icmp6 type-code pair: echo request
icmp6.ECHO_REQUEST				= { type = 128, code = 0 }
--- Icmp6 type-code pair: echo reply
icmp6.ECHO_REPLY				= { type = 129, code = 0 }


---------------------------------------------------------------------------
---- ICMP header
---------------------------------------------------------------------------

-- definition of the header format
icmp.headerFormat = [[
	uint8_t		type;
	uint8_t		code;
	uint16_t	cs;
	uint8_t		body[];
]]

--- Variable sized member
icmp.headerVariableMember = "body"

--- Module for icmp_header struct
local icmpHeader = initHeader()
icmpHeader.__index = icmpHeader

--- Set the type.
--- @param int Type of the icmp header as 8 bit integer.
function icmpHeader:setType(int)
	int = int or icmp.ECHO_REQUEST.type
	self.type = int
end

--- Retrieve the type.
--- @return Type as 8 bit integer.
function icmpHeader:getType()
	return self.type
end

--- Retrieve the type.
--- does not work for ICMPv6 (ICMPv6 uses different values)
--- @return Type as string.
function icmpHeader:getTypeString()
	local type = self:getType()
	local cleartext = "unknown"

	if type == icmp.ECHO_REPLY.type then
		cleartext = "echo reply"
	elseif type == icmp.ECHO_REQUEST.type then
		cleartext = "echo request"
	elseif type == icmp.DST_UNR_PORT_UNR.type then
		cleartext = "dst. unr."
	elseif type == icmp.TIME_EXCEEDED_TTL_EXPIRED.type then
		cleartext = "time exceeded"
	end

	return format("%s (%s)", type, cleartext)
end

--- Set the code.
--- @param int Code of the icmp header as 8 bit integer.
function icmpHeader:setCode(int)
	int = int or icmp.ECHO_REQUEST.code
	self.code = int
end

--- Retrieve the code.
--- @return Code as 8 bit integer.
function icmpHeader:getCode()
	return self.code
end

--- Retrieve the code.
--- does not work for ICMPv6
--- @return Code as string.
function icmpHeader:getCodeString()
	local type = self:getType()
	local code = self:getCode()
	local cleartext = "unknown"

	if type == icmp.ECHO_REPLY.type then
		cleartext = code == icmp.ECHO_REPLY.code and "correct" or "wrong"
	
	elseif type == icmp.ECHO_REQUEST.type then
		cleartext = code == icmp.ECHO_REQUEST.code and "correct" or "wrong"
	
	elseif type == icmp.DST_UNR_PORT_UNR.type then
		if code == icmp.DST_UNR_PORT_UNR.code then
			cleartext = "port unr."
		end
	
	elseif type == icmp.TIME_EXCEEDED_TTL_EXPIRED.type then
		if code == icmp.TIME_EXCEEDED_TTL_EXPIRED.code then
			cleartext = "ttl expired"
		end
	end

	return format("%s (%s)", code, cleartext)
end


--- Set the checksum.
--- @param int Checksum of the icmp header as 16 bit integer.
function icmpHeader:setChecksum(int)
	int = int or 0
	self.cs = hton16(int)
end

--- Calculate the checksum
--- @param len Number of bytes that the checksum will be computed over
function icmpHeader:calculateChecksum(len)
	len = len or ffi.sizeof(self)
	self:setChecksum(0)
	self:setChecksum(hton16(checksum(self, len)))
end

--- Retrieve the checksum.
--- @return Checksum as 16 bit integer.
function icmpHeader:getChecksum()
	return hton16(self.cs)
end

--- Retrieve the checksum.
--- @return Checksum as string.
function icmpHeader:getChecksumString()
	return format("0x%04x", self:getChecksum())  
end

--- Set the message body.
--- @param int Message body of the icmp header as TODO.
function icmpHeader:setMessageBody(body)
	body = body or 0
	--self.body.uint8_t = body
end

--- Retrieve the message body.
--- @return Message body as TODO.
function icmpHeader:getMessageBody()
	return 0 --self.body
end

--- Retrieve the message body.
--- @return Message body as string TODO.
function icmpHeader:getMessageBodyString()
	return "<some data>"
end

--- Set all members of the icmp header.
--- Per default, all members are set to default values specified in the respective set function.
--- Optional named arguments can be used to set a member to a user-provided value.
--- @param args Table of named arguments. Available arguments: Type, Code, Checksum, MessageBody
--- @param pre prefix for namedArgs. Default 'icmp'.
--- @code
--- fill() --- only default values
--- fill{ icmpCode=3 } --- all members are set to default values with the exception of icmpCode
--- @endcode
function icmpHeader:fill(args, pre)
	args = args or {}
	pre = pre or "icmp"

	self:setType(args[pre .. "Type"])
	self:setCode(args[pre .. "Code"])
	self:setChecksum(args[pre .. "Checksum"])
	self:setMessageBody(args[pre .. "MessageBody"])
end

--- Retrieve the values of all members.
--- @param pre prefix for namedArgs. Default 'icmp'.
--- @return Table of named arguments. For a list of arguments see "See also".
--- @see icmpHeader:fill
function icmpHeader:get(pre)
	pre = pre or "icmp"

	local args = {}
	args[pre .. "Type"] = self:getType()
	args[pre .. "Code"] = self:getCode()
	args[pre .. "Checksum"] = self:getChecksum()
	args[pre .. "MessageBody"] = self:getMessageBody()
	
	return args
end

--- Retrieve the values of all members.
--- Does not work correctly for ICMPv6 packets
--- @return Values in string format.
function icmpHeader:getString()
	return "ICMP type "			.. self:getTypeString() 
			.. " code "		.. self:getCodeString() 
			.. " cksum "	.. self:getChecksumString()
			.. " body "		.. self:getMessageBodyString() .. " "
end


--------------------------------------------------------------------------------------
---- ICMP responder, IPv4 only for now
---- Pull requests for IPv6 are welcome :)
--------------------------------------------------------------------------------------


--- Starts a simple ICMPv4 ping responder on a shared core.
--- This is *not optimized for latency* ping relies will be slow (> 1ms)
--- The main usecase of this is letting others on the network know that an IP is being used.
--- This will try to setup a filter on the rx queue to match ICMP packets addressed to the given IP.
--- @param queues array of queue pairs to use, each entry has the following format
--- {rxQueue = rxQueue, txQueue = txQueue, ips = "ip" | {"ip", ...}}
--- rxQueue is optional, packets can alternatively be provided through the pipe API, see icmp.handlePacket()
function icmp.startIcmpTask(queues)
	libmoon.startSharedTask("__LM_ICMP_TASK", queues)
end

local pipes = ns:get()

local function handleIcmpPacket(rxBufs, nic)
	-- FIXME: support non-offloaded vlan tags
	local pkt = rxBufs[1]:getIcmpPacket()
	if pkt.eth:getType() ~= eth.TYPE_IP
	or pkt.ip4:getProtocol() ~= ip.PROTO_ICMP then
		rxBufs:freeAll()
		return
	end
	local dstIp = pkt.ip4.dst:getString()
	local ipOk = false
	for i, v in ipairs(nic.ips) do
		if v == dstIp then
			ipOk = true
			break
		end
	end
	if not ipOk then
		rxBufs:freeAll()
		return
	end
	-- yes, we assume that the path is symmetric and that the source MAC is correct
	-- could be improved by using the ARP task here, pull requests welcome
	pkt.eth.dst:set(pkt.eth.src:get())
	pkt.eth.src:set(nic.txQueue.dev:getMac(true))
	local tmp = pkt.ip4.src:get()
	pkt.ip4.src:set(pkt.ip4.dst:get())
	pkt.ip4.dst:set(tmp)
	pkt.ip4.ttl = 64
	pkt.icmp:setType(icmp.ECHO_REPLY.type)
	pkt.ip4:calculateChecksum() -- avoid offloading dependency
	pkt.icmp:calculateChecksum(pkt.ip4:getLength() - pkt.ip4:getHeaderLength() * 4)
	nic.txQueue:send(rxBufs)
end

local function icmpTask(queues)
	-- two ways to call this: single nic or array of nics
	if queues[1] == nil and queues.txQueue then
		return icmpTask({queues})
	end

	for i, nic in ipairs(queues) do
		if nic.rxQueue and nic.txQueue.id ~= nic.rxQueue.id then
			error("both queues must belong to the same device")
		end
		if type(nic.ips) == "string" then
			nic.ips = { nic.ips }
		end
		if nic.rxQueue then
			for i, v in ipairs(nic.ips) do
				local ok = nic.rxQueue.dev:fiveTupleFilter({
					dstIp = v,
					proto = ip.PROTO_ICMP
				}, nic.rxQueue)
				if not ok then
					break
				end
			end
		end
		local pipe = pipe:newFastPipe()
		nic.pipe = pipe
		pipes[tostring(i)] = pipe
	end

	local rxBufs = memory.createBufArray(1)
	while libmoon.running() do
		for _, nic in pairs(queues) do
			if nic.rxQueue then
				rx = nic.rxQueue:tryRecvIdle(rxBufs, 1000)
				assert(rx <= 1)
				if rx > 0 then
					handleIcmpPacket(rxBufs, nic)
				end
			end
			-- if only we had something like poll :/
			-- maybe write some wrapper that takes multiple tryRecv-able things?
			local pkt = nic.pipe:tryRecv(1000)
			if pkt then
				rxBufs[1] = pkt
				handleIcmpPacket(rxBufs, nic)
			end
		end
	end
end

--- Send a buf containing an ICMP packet to the ICMP reseponder.
--- The buf is free'd by the ICMP task, do not free this (or increase ref count if you still need the buf).
--- @param buf the ICMP packet
--- @param nic the ID of the NIC from which the packt was received, defaults to 1
---            corresponds to the index in the queue array passed to the ICMP task
function icmp.handlePacket(buf, nic)
	nic = nic or 1
	local pipe = pipes[tostring(nic)]
	if not pipe then
		log:fatal("NIC %s not found", nic)
	end
	pipe:send(buf)
end

__LM_ICMP_TASK = icmpTask


------------------------------------------------------------------------
---- Metatypes
------------------------------------------------------------------------

icmp.metatype = icmpHeader

return icmp, icmp6

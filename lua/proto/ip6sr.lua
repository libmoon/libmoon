------------------------------------------------------------------------
--- @file ip6sr.lua
--- @brief (ip6sr) utility.
--- Utility functions for the ip6sr_header structs 
--- Includes:
--- - ip6sr constants
--- - ip6sr header utility
--- - Definition of ip6sr packets
------------------------------------------------------------------------

--[[
-- Use this file as template when implementing a new protocol (to implement all mandatory stuff)
-- Replace all occurrences of ip6sr with your protocol (e.g. sctp)
-- Necessary changes to other files:
-- - packet.lua: if the header has a length member, adapt packetSetLength; 
-- 				 if the packet has a checksum, adapt createStack (loop at end of function) and packetCalculateChecksums
-- - proto/proto.lua: add ip6sr.lua to the list so it gets loaded
--]]
local ffi = require "ffi"
require "proto.template"
local initHeader = initHeader


---------------------------------------------------------------------------
---- ip6sr constants 
---------------------------------------------------------------------------

--- TODO copy-pastad from ip6.lua, reuse?
--- ip6sr protocol constants
local ip6sr = {}

--- NextHeader field value for Tcp
ip6sr.PROTO_TCP 	= 0x06
--- NextHeader field value for Udp
ip6sr.PROTO_UDP 	= 0x11
ip6sr.PROTO_GRE = 0x2f
--- NextHeader field value for Icmp
ip6sr.PROTO_ICMP	= 0x3a -- 58
ip6sr.PROTO_ESP	= 0x32
ip6sr.PROTO_AH	= 0x33
-- NextHeader field value for SRH
ip6sr.PROTO_SRH   = 0x2b


--- TODO copy-pastad from ip6.lua, reuse?
-- Maps headers to respective nextHeader value.
-- This list should be extended whenever a new protocol is added to 'IPv6 constants'.
local mapNameProto = {
	icmp = ip6sr.PROTO_ICMP,
	udp = ip6sr.PROTO_UDP,
	tcp = ip6sr.PROTO_TCP,
	esp = ip6sr.PROTO_ESP,
	ah = ip6sr.PROTO_AH,
	gre = ip6sr.PROTO_GRE,
	srh = ip6sr.PROTO_SRH,
}

local ip6AddrType = ffi.typeof("union ip6_address")

---------------------------------------------------------------------------
---- ip6sr header
---------------------------------------------------------------------------

ip6sr.headerFormat = [[
	uint8_t		nextHeader;
	uint8_t		headerExtLen;
	uint8_t		routingType;
	uint8_t		segmentsLeft;
	uint8_t		lastEntry;
	uint8_t		flags;
	uint16_t	tag;
	union ip6_address segments[];
]]


--- Variable sized member
ip6sr.headerVariableMember = "segments"

--- Module for ip6sr_address struct
local ip6srHeader = initHeader()
ip6srHeader.__index = ip6srHeader

--[[ for all members of the header with non-standard data type: set, get, getString 
-- for set also specify a suitable default value
--]]
function ip6srHeader:getNextHeader()
	return self.nextHeader
end
function ip6srHeader:getNextHeaderString()
	return self:getNextHeader()
end
function ip6srHeader:setNextHeader(nextHeader)
	self.nextHeader = nextHeader
end

function ip6srHeader:getHeaderExtLen()
	return self.headerExtLen
end
function ip6srHeader:getHeaderExtLenString()
	return self:getHeaderExtLen()
end
function ip6srHeader:setHeaderExtLen(headerExtLen)
	-- no default, this needs to be calculated from the rest of the packet if
	-- it's not manually passed in (it should really just be calculated)
	self.headerExtLen = headerExtLen
end

function ip6srHeader:getRoutingType()
	return self.routingType
end
function ip6srHeader:getRoutingTypeString()
	return self:getRoutingType()
end
function ip6srHeader:setRoutingType(routingType)
	routingType = routingType or 4
	self.routingType = routingType
end

function ip6srHeader:getSegmentsLeft()
	return self.segmentsLeft
end
function ip6srHeader:getSegmentsLeftString()
	return self:getSegmentsLeft()
end
function ip6srHeader:setSegmentsLeft(segmentsLeft)
	segmentsLeft = segmentsLeft or 0
	self.segmentsLeft = segmentsLeft
end

function ip6srHeader:getLastEntry()
	return self.lastEntry
end
function ip6srHeader:getLastEntryString()
	return self:getLastEntry()
end
function ip6srHeader:setLastEntry(lastEntry)
	self.lastEntry = lastEntry
end

function ip6srHeader:getFlags()
	print("Entering getFlags")
	return self.flags
end
function ip6srHeader:getFlagsString()
	return self:getFlags()
end
function ip6srHeader:setFlags(flags)
	flags = flags or 0x0
	self.flags = flags
end


function ip6srHeader:getTag()
	print("Entering getTag")
	return self.tag
end
function ip6srHeader:getTagString()
	return self:getTag()
end
function ip6srHeader:setTag(tag)
	tag = tag or 0x0000
	self.tag = hton16(tag)
end

function byteSwap(addr)
	local swapped = ip6AddrType()
	swapped.uint32[0] = bswap(addr.uint32[3])
	swapped.uint32[1] = bswap(addr.uint32[2])
	swapped.uint32[2] = bswap(addr.uint32[1])
	swapped.uint32[3] = bswap(addr.uint32[0])
	return swapped
end

--- Retrieve the Segments.
--- @return Segment array in 'union ip6_address' format.
function ip6srHeader:getSegments()
	local segments = {}
	for i, v in ipairs(self.segments) do
		local segment = v:get()
		segments[i] = segment
	end
	return segments
end

--- Retrieve the Segment address.
--- @return Segment in string format.
function ip6srHeader:getSegmentsString()
	local str = "[ "
	for _, v in pairs(self.segments) do
		str = str .. v:getString() .. " "
	end
	str = str .. "]"
	return str
end

--- Set the Segment.
--- @param ip6_address segment of the ip6sr header as a union ip6_address.
function ip6srHeader:setSegments(segments)
	if (#segments > 0 and type(segments[1]) == "string") then
		self:setSegmentsString(segments)
	else
		self.segments = segments
	end
end

function ip6srHeader:setSegmentsString(segmentStrings)
	local segments = {}
	for i, v in ipairs(segmentStrings) do
		local segment = byteSwap(parseIP6Address(v))
		segments[i] = segment
	end
	self.segments = segments
end



--- Set all members of the ip6sr header.
--- Per default, all members are set to default values specified in the respective set function.
--- Optional named arguments can be used to set a member to a user-provided value.
--- @param args Table of named arguments. Available arguments: ip6srXYZ
--- @param pre prefix for namedArgs. Default 'ip6sr'.
--- @code
--- fill() -- only default values
--- fill{ ip6srXYZ=1 } -- all members are set to default values with the exception of ip6srXYZ, ...
--- @endcode
function ip6srHeader:fill(args, pre)
	args = args or {}
	pre = pre or "ip6sr"

	self:setNextHeader(args[pre .. "NextHeader"])
	self:setHeaderExtLen(args[pre .. "HeaderExtLen"])
	self:setRoutingType(args[pre .. "RoutingType"])
	self:setSegmentsLeft(args[pre .. "SegmentsLeft"])
	self:setLastEntry(args[pre .. "LastEntry"])
	self:setFlags(args[pre .. "Flags"])
	self:setTag(args[pre .. "Tag"])
	self:setSegments(args[pre .. "Segments"])
end

--- Retrieve the values of all members.
--- @param pre prefix for namedArgs. Default 'ip6sr'.
--- @return Table of named arguments. For a list of arguments see "See also".
--- @see ip6srHeader:fill
function ip6srHeader:get(pre)
	pre = pre or "ip6sr"

	local args = {}
	args[pre .. "NextHeader"] = self:getNextHeader()
	args[pre .. "HeaderExtLen"] = self:getHeaderExtLen()
	args[pre .. "RoutingType"] = self:getRoutingType()
	args[pre .. "SegmentsLeft"] = self:getSegmentsLeft()
	args[pre .. "LastEntry"] = self:getLastEntry()
	args[pre .. "Flags"] = self:getFlags()
	args[pre .. "Tag"] = self:getTag()
	args[pre .. "Segments"] = self:getSegments()

	return args
end

--- Retrieve the values of all members.
--- @return Values in string format.
function ip6srHeader:getString()
	return "ip6sr" ..
			" nextHeader " .. self:getNextHeaderString() ..
			" headerExtLen " .. self:getHeaderExtLenString() ..
			" routingType " .. self:getRoutingTypeString() ..
			" segmentsLeft " .. self:getSegmentsLeftString() ..
			" lastEntry " .. self:getLastEntryString() ..
			" flags " .. self.getFlagsString() ..
			" tag " .. self.getTagString() ..
			" segments " .. self.self:getSegmentsString()
end

--- Resolve which header comes after this one (in a packet)
--- For instance: in tcp/udp based on the ports
--- This function must exist and is only used when get/dump is executed on 
--- an unknown (mbuf not yet casted to e.g. tcpv6 packet) packet (mbuf)
--- @return String next header (e.g. 'eth', 'ip4', nil)
function ip6srHeader:resolveNextHeader()
	local proto = self:getNextHeader()
	for name, _proto in pairs(mapNameProto) do
		if proto == _proto then
			return name
		end
	end
	return nil
end	

--- Change the default values for namedArguments (for fill/get)
--- This can be used to for instance calculate a length value based on the total packet length
--- See proto/ip4.setDefaultNamedArgs as an example
--- This function must exist and is only used by packet.fill
--- @param pre The prefix used for the namedArgs, e.g. 'ip6sr'
--- @param namedArgs Table of named arguments (see See more)
--- @param nextHeader The header following after this header in a packet
--- @param accumulatedLength The so far accumulated length for previous headers in a packet
--- @return Table of namedArgs
--- @see ip6srHeader:fill
function ip6srHeader:setDefaultNamedArgs(pre, namedArgs, nextHeader, accumulatedLength)
	local segmentCount = #(namedArgs[pre .. "Segments"] or {})

	-- set headerExtLen
	if not namedArgs[pre .. "HeaderExtLen"] then
		-- length of the SRH header in 8-octet units, not including the first 8 octets
		-- i.e., skipping the static portion of the SRH, and 2 units per IPv6 Segment
		namedArgs[pre .. "HeaderExtLen"] = segmentCount * 2
	end

	-- set lastEntry
	if not namedArgs[pre .. "LastEntry"] then
		-- lastEntry is equal to the number of segments - 1
		namedArgs[pre .. "LastEntry"] = segmentCount - 1
	end

	-- set protocol for next header
	if not namedArgs[pre .. "NextHeader"] then
		for name, type in pairs(mapNameProto) do
			if nextHeader == name then
				namedArgs[pre .. "NextHeader"] = type
				break
			end
		end
	end

	return namedArgs
end


------------------------------------------------------------------------
---- Metatypes
------------------------------------------------------------------------

ip6sr.metatype = ip6srHeader

return ip6sr

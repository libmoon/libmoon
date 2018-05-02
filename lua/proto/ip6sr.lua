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
-- Remove unnecessary comments in this file (comments inbetween [[...]])
-- Necessary changes to other files:
-- - packet.lua: if the header has a length member, adapt packetSetLength; 
-- 				 if the packet has a checksum, adapt createStack (loop at end of function) and packetCalculateChecksums
-- - proto/proto.lua: add ip6sr.lua to the list so it gets loaded
--]]
local ffi = require "ffi"
require "proto.template"
-- require "ip6"
local ip6 = require "ip6"
-- local ip6_address = ip6.ip6_address
local initHeader = initHeader


---------------------------------------------------------------------------
---- ip6sr constants 
---------------------------------------------------------------------------

--- ip6sr protocol constants
local ip6sr = {}


---------------------------------------------------------------------------
---- ip6sr header
---------------------------------------------------------------------------

ip6sr.headerFormat = [[
	uint8_t		nextHeader;
	uint8_t		hdrExtLen;
	uint8_t		routingType;
	uint8_t		segmentsLeft;
	uint8_t		lastEntry;
	uint8_t		flags;
	uint16_t	tag;
	union ip6.ip6_address segment;
]]


--- Variable sized member
ip6sr.headerVariableMember = nil;

--- Module for ip6sr_address struct
local ip6srHeader = initHeader()
ip6srHeader.__index = ip6srHeader

--[[ for all members of the header with non-standard data type: set, get, getString 
-- for set also specify a suitable default value
--]]
--- Set the Segment.
--- @param ip6_address segment of the ip6sr header as a union ip6_address.
function ip6srHeader:setSegment(addr)
	-- allocate enough space for address.len ip6_address
    -- for i <- 0 .. len: self.segmentList[i]:set(addresses[i])

    -- for now, just set one segment
	self.segment:set(addr)
end

--- Retrieve the Segment.
--- @return Segment in 'union ip6_address' format.
function ip6srHeader:getSegment()
	return self.segment:get()
end

--- Retrieve the Segment address.
--- @return Segment in string format.
function ip6Header:getSegmentString()
	return self.segment:getString()
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
	self:setSegment(args[pre .. "Segment"])
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
	args[pre .. "Segment"] = self:getSegment()

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
			" segment " .. self:self:getSegmentString()
end

--- Resolve which header comes after this one (in a packet)
--- For instance: in tcp/udp based on the ports
--- This function must exist and is only used when get/dump is executed on 
--- an unknown (mbuf not yet casted to e.g. tcpv6 packet) packet (mbuf)
--- @return String next header (e.g. 'eth', 'ip4', nil)
function ip6srHeader:resolveNextHeader()
	local proto = self:getNextHeader()
	for name, _proto in pairs(ip6.mapNameProto) do
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
	-- set protocol
	if not namedArgs[pre .. "NextHeader"] then
		for name, type in pairs(ip6.mapNameProto) do
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

ffi.metatype("union ip6_address", ip6.ip6Addr)
ip6sr.metatype = ip6srHeader

return ip6sr

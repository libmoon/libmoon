------------------------------------------------------------------------
--- @file ip6sr.lua
--- @brief (ip6sr) utility.
--- Utility functions for the ip6sr_header structs 
--- Includes:
--- - ip6sr constants
--- - ip6sr header utility
--- - Definition of ip6sr packets
------------------------------------------------------------------------

local ffi = require "ffi"
require "proto.template"
local initHeader = initHeader

---------------------------------------------------------------------------
---- IPv6 SR Constants
---------------------------------------------------------------------------

--- ip6sr protocol constants
local ip6sr = {}

ip6sr.PROTO_TCP 	= 0x06
ip6sr.PROTO_UDP 	= 0x11
ip6sr.PROTO_GRE 	= 0x2f
ip6sr.PROTO_ICMP	= 0x3a
ip6sr.PROTO_ESP 	= 0x32
ip6sr.PROTO_AH		= 0x33
ip6sr.PROTO_SRH 	= 0x2b

-- Maps headers to respective nextHeader value.
-- This list should be extended whenever a new protocol is added to 'IPv6 SR constants'.
local mapNameProto = {
	icmp = ip6sr.PROTO_ICMP,
	udp = ip6sr.PROTO_UDP,
	tcp = ip6sr.PROTO_TCP,
	esp	= ip6sr.PROTO_ESP,
	ah = ip6sr.PROTO_AH,
	gre = ip6sr.PROTO_GRE,
	ip6sr = ip6sr.PROTO_SRH,
}

local ip6AddrType = ffi.typeof("union ip6_address")

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
	union ip6_address segmentList[];
]]


--- Variable sized member
ip6sr.headerVariableMember = "segmentList"

--- Module for ip6sr_address struct
local ip6srHeader = initHeader()
ip6srHeader.__index = ip6srHeader

---------------------------------------------------------------------------
--- Next Header: 8-bit selector.  Identifies the type of header
--- immediately following the SRH.
---------------------------------------------------------------------------
--- Set the NextHeader field. Default is TCP.
--- @param nextHeader 8-bit uint
function ip6srHeader:setNextHeader(nextHeader)
	nextHeader = nextHeader or ip6sr.PROTO_TCP
	self.nextHeader = nextHeader
end
function ip6srHeader:getNextHeader()
	return self.nextHeader
end
function ip6srHeader:getNextHeaderString()
	return self:getNextHeader()
end

---------------------------------------------------------------------------
--- Hdr Ext Len: 8-bit unsigned integer, is the length of the SRH
--- header in 8-octet units, not including the first 8 octets.
---------------------------------------------------------------------------
--- Set the HdrExtLen field. There is no inline default for this value, it
--- should be calculated based on the number of segments provided (unless
--- the value has been passed in by the user). This calculation is performed
--- in setDefaultNamedArgs. It's generally best to leave this unset so it can
--- be correctly calculated.
--- @param hdrExtLen 8-bit uint
function ip6srHeader:setHdrExtLen(hdrExtLen)
	self.hdrExtLen = hdrExtLen
end
function ip6srHeader:getHdrExtLen()
	return self.hdrExtLen
end
function ip6srHeader:getHdrExtLenString()
	return self:getHdrExtLen()
end

---------------------------------------------------------------------------
--- Routing Type: TBD, to be assigned by IANA (suggested value: 4).
---------------------------------------------------------------------------
--- Set the RoutingType field. Not much reason to change this from the default,
--- unless IANA actually assigns a value.
--- @param routingHeader 8-bit uint
function ip6srHeader:setRoutingType(routingType)
	routingType = routingType or 4
	self.routingType = routingType
end
function ip6srHeader:getRoutingType()
	return self.routingType
end
function ip6srHeader:getRoutingTypeString()
	return self:getRoutingType()
end

---------------------------------------------------------------------------
--- Segments Left.  Defined in [RFC8200], it contains the index, in
--- the Segment List, of the next segment to inspect.  Segments Left
--- is decremented at each segment.
---------------------------------------------------------------------------
--- Set the SegmentsLeft field. Defaults to 0 (no more segments to process)
--- @param segmentsLeft 8-bit uint
function ip6srHeader:setSegmentsLeft(segmentsLeft)
	segmentsLeft = segmentsLeft or 0
	self.segmentsLeft = segmentsLeft
end
function ip6srHeader:getSegmentsLeft()
	return self.segmentsLeft
end
function ip6srHeader:getSegmentsLeftString()
	return self:getSegmentsLeft()
end

---------------------------------------------------------------------------
--- Last Entry: contains the index, in the Segment List, of the last
--- element of the Segment List.
---------------------------------------------------------------------------
--- Set the LastEntry field. There is no inline default for this value, it
--- should be calculated based on the number of segments provided. This
--- calculation is performed in setDefaultNamedArgs.
--- @param lastEntry 8-bit uint
function ip6srHeader:setLastEntry(lastEntry)
	self.lastEntry = lastEntry
end
function ip6srHeader:getLastEntry()
	return self.lastEntry
end
function ip6srHeader:getLastEntryString()
	return self:getLastEntry()
end

---------------------------------------------------------------------------
--- Flags: 8 bits of flags.  Following flags are defined:
--- 0 1 2 3 4 5 6 7
--- +-+-+-+-+-+-+-+-+
--- |U|P|O|A|H|  U  |
--- +-+-+-+-+-+-+-+-+
--- U: Unused and for future use.  SHOULD be unset on transmission
--- and MUST be ignored on receipt.
--- P-flag: Protected flag.  Set when the packet has been rerouted
--- through FRR mechanism by an SR endpoint node.
--- O-flag: OAM flag.  When set, it indicates that this packet is
--- an operations and management (OAM) packet.
--- A-flag: Alert flag.  If present, it means important Type Length
--- Value (TLV) objects are present.  See Section 3.1 for details
--- on TLVs objects.
--- H-flag: HMAC flag.  If set, the HMAC TLV is present and is
--- encoded as the last TLV of the SRH.  In other words, the last
--- 36 octets of the SRH represent the HMAC information.  See
--- Section 3.1.5 for details on the HMAC TLV.
---------------------------------------------------------------------------
--- Set flags field. Defaults to 0x00
--- @param flags 8-bit uint
function ip6srHeader:setFlags(flags)
	flags = flags or 0x00
	self.flags = flags
end
function ip6srHeader:getFlags()
	return self.flags
end
function ip6srHeader:getFlagsString()
	return self:getFlags()
end

---------------------------------------------------------------------------
--- Tag: tag a packet as part of a class or group of packets, e.g.,
--- packets sharing the same set of properties.
---------------------------------------------------------------------------
--- Set the tag field -- TODO does this work as expected?
--- @param tag 16-bit uint
function ip6srHeader:setTag(tag)
	tag = tag or 0
	self.tag = hton16(tag)
end
function ip6srHeader:getTag()
	return self.tag
end
function ip6srHeader:getTagString()
	return self:getTag()
end

---------------------------------------------------------------------------
--- Segment List[n]: 128 bit IPv6 addresses representing the nth
--- segment in the Segment List.  The Segment List is encoded starting
--- from the last segment of the path.  I.e., the first element of the
--- segment list (Segment List [0]) contains the last segment of the
--- path, the second element contains the penultimate segment of the
--- path and so on.
---------------------------------------------------------------------------
--- Set the SegmentList. If the provided segmentList is actually an
--- array of strings, be helpful and hand those to setSegmentListString
--- @param segmentList array of 'union ip6_address' types.
function ip6srHeader:setSegmentList(segmentList)
	if (#segmentList > 0 and type(segmentList[1]) == "string") then
		self:setSegmentListString(segmentList)
	else
		self.segmentList = segmentList
	end
end

--- Set the SegmentList from an array of strings. Parse strings as IPv6
--- addresses use the :set() defined on the ip6addr to handle any necessary
--- byte-ordering.
--- @param segmentList array of Strings
function ip6srHeader:setSegmentListString(segmentListStrings)
	local segmentList = {}
	for i, v in ipairs(segmentListStrings) do
		local segment = ip6AddrType()
		segment:set(parseIP6Address(v))
		segmentList[i] = segment
	end
	self.segmentList = segmentList
end

--- Retrieve the SegmentList addresses
--- @return SegmentList as an array of 'union ip6_address' format
function ip6srHeader:getSegmentList()
	local segmentList = {}
	for i, v in ipairs(self.segmentList) do
		segmentList[i] = v:get()
	end
	return segmentList
end

--- Retrieve the SegmentList as a string
--- @return SegmentList in a single string
function ip6srHeader:getSegmentListString()
	local str = "[ "
	for _, v in pairs(self.segmentList) do
		str = str .. v:getString() .. " "
	end
	str = str .. "]"
	return str
end


--- Set all members of the ip6sr header.
--- Per default, all members are set to default values specified in the respective set function.
--- Optional named arguments can be used to set a member to a user-provided value.
--- @param args Table of named arguments. Available arguments: ip6srNextHeader, ip6srHdrExtLen,
---	       ip6srRoutingType, ip6srSegmentsLeft, ip6srLastEntry, ip6srFlags, ip6srTag,
---        ip6srSegmentList
--- @param pre prefix for namedArgs. Default 'ip6sr'.
function ip6srHeader:fill(args, pre)
	args = args or {}
	pre = pre or "ip6sr"

	self:setNextHeader(args[pre .. "NextHeader"])
	self:setHdrExtLen(args[pre .. "HdrExtLen"])
	self:setRoutingType(args[pre .. "RoutingType"])
	self:setSegmentsLeft(args[pre .. "SegmentsLeft"])
	self:setLastEntry(args[pre .. "LastEntry"])
	self:setFlags(args[pre .. "Flags"])
	self:setTag(args[pre .. "Tag"])
	self:setSegmentList(args[pre .. "SegmentList"])
end

--- Retrieve the values of all members.
--- @param pre prefix for namedArgs. Default 'ip6sr'.
--- @return Table of named arguments. For a list of arguments see "See also".
--- @see ip6srHeader:fill
function ip6srHeader:get(pre)
	pre = pre or "ip6sr"

	local args = {}
	args[pre .. "NextHeader"] = self:getNextHeader()
	args[pre .. "HdrExtLen"] = self:getHdrExtLen()
	args[pre .. "RoutingType"] = self:getRoutingType()
	args[pre .. "SegmentsLeft"] = self:getSegmentsLeft()
	args[pre .. "LastEntry"] = self:getLastEntry()
	args[pre .. "Flags"] = self:getFlags()
	args[pre .. "Tag"] = self:getTag()
	args[pre .. "SegmentList"] = self:getSegmentList()

	return args
end

--- Retrieve the values of all members.
--- @return Values in string format.
function ip6srHeader:getString()
	return "ip6sr" ..
			" nextHeader " .. self:getNextHeaderString() ..
			" hdrExtLen " .. self:getHdrExtLenString() ..
			" routingType " .. self:getRoutingTypeString() ..
			" segmentsLeft " .. self:getSegmentsLeftString() ..
			" lastEntry " .. self:getLastEntryString() ..
			" flags " .. self.getFlagsString() ..
			" tag " .. self.getTagString() ..
			" segmentList " .. self.self:getSegmentListString()
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
	local segmentCount = #(namedArgs[pre .. "SegmentList"] or {})

	-- set hdrExtLen
	if not namedArgs[pre .. "HdrExtLen"] then
		-- length of the SRH header in 8-octet units, not including the first 8 octets
		-- i.e., skipping the static portion of the SRH, and 2 units per IPv6 Segment
		namedArgs[pre .. "HdrExtLen"] = segmentCount * 2
	end

	-- set lastEntry
	if not namedArgs[pre .. "LastEntry"] then
		-- lastEntry is 0-indexed index of last segment
		-- i.e., the number of segments - 1
		namedArgs[pre .. "LastEntry"] = segmentCount - 1
	end

	-- set protocol for next header
	-- nextHeader arg is passed in from packet.lua and is the name of the next header
	-- pulled from the original createStack call. Seldom need to actually set the
	-- ip6srNextHeader field, though it does override nextHeader if set.
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

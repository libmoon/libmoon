------------------------------------------------------------------------
--- @file gre.lua
--- @brief Generic Routing Encapsulation protocol (GRE) utility.
--- This implementation includes only the basic GRE header fields, none 
--- of the optional fields
--- Utility functions for gre_header struct
--- Includes:
--- - Gre constants
--- - Gre header utility
--- - Definition of Gre packets
------------------------------------------------------------------------

local ffi = require "ffi"

require "utils"
require "proto.template"
local initHeader = initHeader

local ntoh, hton = ntoh, hton
local ntoh16, hton16 = ntoh16, hton16
local bor, band, bnot, rshift, lshift = bit.bor, bit.band, bit.bnot, bit.rshift, bit.lshift
local istype = ffi.istype
local format = string.format


---------------------------------------------------------------------------
---- GRE constants 
---------------------------------------------------------------------------

--- Gre protocol constants
local gre = {}

gre.PROTO_TEB = 0x6558

---------------------------------------------------------------------------
---- GRE header
---------------------------------------------------------------------------

-- definition of the header format
gre.headerFormat = [[
	uint16_t flags_and_version;
	uint16_t protocol_type;
]]

--- Variable sized member
gre.headerVariableMember = nil

--- Module for gre_header struct (see \ref headers.lua).
local greHeader = initHeader()
greHeader.__index = greHeader

--- Set the encapsulated ether protocol type.
--- @param int protocol type as 16 bit integer.
function greHeader:setProtoType(int)
	int = int or gre.PROTO_TEB
	self.protocol_type = hton16(int)
end

--- Retrieve the encapsulated ether protocol type.
--- @return Protocol type as a 16 bit integer.
function greHeader:getProtoType()
	return ntoh16(self.protocol_type)
end

--- Set the gre header flag and version fields.
--- @param int protocol type as 16 bit integer.
function greHeader:setFlagsAndVersion(int)
	int = int or 0x0000
	self.flags_and_version = hton16(int)
end

--- Retrieve the gre header flag and version fields.
--- @return Protocol type as a 16 bit integer.
function greHeader:getFlagsAndVersion()
	return ntoh16(self.flags_and_version)
end

--- Set all members of the gre header.
--- Per default, all members are set to default values specified in the respective set function.
--- Optional named arguments can be used to set a member to a user-provided value.
--- @param args Table of named arguments. Available arguments: 
--- @param pre prefix for namedArgs. Default 'gre'.
--- @code
--- fill() --- only default values
--- fill{greProto = 10} --- all members are set to default values
--- @endcode
function greHeader:fill(args, pre)
	args = args or {}
	pre = pre or "gre"
	self:setProtoType(args[pre .. "Proto"])
	self:setFlagsAndVersion(args[pre .. "Flags"])
end

--- Retrieve the values of all members.
--- @param pre prefix for namedArgs. Default 'gre'.
--- @return Table of named arguments. For a list of arguments see "See also".
--- @see greHeader:fill
function greHeader:get(pre)
	pre = pre or "gre"

	local args = {}
	args[pre .. "Proto"] = self:getProtoType()
	args[pre .. "Flags"] = self:getFlagsAndVersion()

	return args
end

--- Retrieve the values of all members.
--- @return Values in string format.
function greHeader:getString()
	local retStr = "GRE "
	retStr = retStr .. "Flags " .. self:getFlagsAndVersionString()
	retStr = retStr .. "Proto " .. self:getProtoTypeString()

	return retStr
end

--- Resolve which header comes after this one (in a packet).
--- This function must exist and is only used when get/dump is executed on
--- an unknown (mbuf not yet casted to e.g. tcpv6 packet) packet (mbuf)
--- @return String next header (e.g. 'udp', 'icmp', nil)
function greHeader:resolveNextHeader()
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
--- @param pre The prefix used for the namedArgs, e.g. 'PROTO'
--- @param namedArgs Table of named arguments (see See more)
--- @param nextHeader The header following after this header in a packet
--- @param accumulatedLength The so far accumulated length for previous headers in a packet
--- @return Table of namedArgs
--- @see greHeader:fill
function greHeader:setDefaultNamedArgs(pre, namedArgs, nextHeader, accumulatedLength)
	return namedArgs
end


------------------------------------------------------------------------
---- Metatypes
------------------------------------------------------------------------

gre.metatype = greHeader


return gre

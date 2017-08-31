------------------------------------------------------------------------
--- @file PROTO.lua
--- @brief (PROTO) utility.
--- Utility functions for the PROTO_header structs 
--- Includes:
--- - PROTO constants
--- - PROTO header utility
--- - Definition of PROTO packets
------------------------------------------------------------------------

--[[
-- Use this file as template when implementing a new protocol (to implement all mandatory stuff)
-- Replace all occurrences of PROTO with your protocol (e.g. sctp)
-- Remove unnecessary comments in this file (comments inbetween [[...]])
-- Necessary changes to other files:
-- - packet.lua: if the header has a length member, adapt packetSetLength; 
-- 				 if the packet has a checksum, adapt createStack (loop at end of function) and packetCalculateChecksums
-- - proto/proto.lua: add PROTO.lua to the list so it gets loaded
--]]
local ffi = require "ffi"
require "proto.template"
local initHeader = initHeader


---------------------------------------------------------------------------
---- PROTO constants 
---------------------------------------------------------------------------

--- PROTO protocol constants
local PROTO = {}


---------------------------------------------------------------------------
---- PROTO header
---------------------------------------------------------------------------

PROTO.headerFormat = [[
	uint8_t		xyz;
]]

--- Variable sized member
PROTO.headerVariableMember = nil

--- Module for PROTO_address struct
local PROTOHeader = initHeader()
PROTOHeader.__index = PROTOHeader

--[[ for all members of the header with non-standard data type: set, get, getString 
-- for set also specify a suitable default value
--]]
--- Set the XYZ.
--- @param int XYZ of the PROTO header as A bit integer.
function PROTOHeader:setXYZ(int)
	int = int or 0
end

--- Retrieve the XYZ.
--- @return XYZ as A bit integer.
function PROTOHeader:getXYZ()
	return nil
end

--- Retrieve the XYZ as string.
--- @return XYZ as string.
function PROTOHeader:getXYZString()
	return nil
end

--- Set all members of the PROTO header.
--- Per default, all members are set to default values specified in the respective set function.
--- Optional named arguments can be used to set a member to a user-provided value.
--- @param args Table of named arguments. Available arguments: PROTOXYZ
--- @param pre prefix for namedArgs. Default 'PROTO'.
--- @code
--- fill() -- only default values
--- fill{ PROTOXYZ=1 } -- all members are set to default values with the exception of PROTOXYZ, ...
--- @endcode
function PROTOHeader:fill(args, pre)
	args = args or {}
	pre = pre or "PROTO"

	self:setXYZ(args[pre .. "PROTOXYZ"])
end

--- Retrieve the values of all members.
--- @param pre prefix for namedArgs. Default 'PROTO'.
--- @return Table of named arguments. For a list of arguments see "See also".
--- @see PROTOHeader:fill
function PROTOHeader:get(pre)
	pre = pre or "PROTO"

	local args = {}
	args[pre .. "PROTOXYZ"] = self:getXYZ() 

	return args
end

--- Retrieve the values of all members.
--- @return Values in string format.
function PROTOHeader:getString()
	return "PROTO " .. self:getXYZString()
end

--- Resolve which header comes after this one (in a packet)
--- For instance: in tcp/udp based on the ports
--- This function must exist and is only used when get/dump is executed on 
--- an unknown (mbuf not yet casted to e.g. tcpv6 packet) packet (mbuf)
--- @return String next header (e.g. 'eth', 'ip4', nil)
function PROTOHeader:resolveNextHeader()
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
--- @see PROTOHeader:fill
function PROTOHeader:setDefaultNamedArgs(pre, namedArgs, nextHeader, accumulatedLength)
	return namedArgs
end


------------------------------------------------------------------------
---- Metatypes
------------------------------------------------------------------------

PROTO.metatype = PROTOHeader


return PROTO

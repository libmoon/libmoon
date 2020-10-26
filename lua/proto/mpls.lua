------------------------------------------------------------------------
--- @file mpls.lua
--- @brief (mpls) utility.
--- Includes:
--- - mpls constants
--- - Definition of mpls packets
------------------------------------------------------------------------

local ffi = require "ffi"
require "proto.template"
local initHeader = initHeader

local bor, band, bnot, rshift, lshift= bit.bor, bit.band, bit.bnot, bit.rshift, bit.lshift


---------------------------------------------------------------------------
---- mpls constants 
---------------------------------------------------------------------------

--- mpls protocol constants
local mpls = {}


---------------------------------------------------------------------------
---- MPLS header
---------------------------------------------------------------------------
-- 1                   2                   3
-- 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2
-- |----------label----------------------|-exp-|-b-|----TTL--------|
-- 0-20 Label
-- 20-22 Experimental Bits (QoS) or Traffic Class (TC) field.
-- 23 BoS (Bottom of Stack bit)
-- 24-31 Time to Live (TTL)

mpls.headerFormat = [[
	uint8_t labelstart;
	uint8_t labelmid;
	uint8_t labelend_tc_s;
	uint8_t ttl;
]]

--- Variable sized member
mpls.headerVariableMember = nil

--- Module for mpls_address struct
local mplsHeader = initHeader()
mplsHeader.__index = mplsHeader

--- Set the Label
--- @param int label of the mpls header as 20 bit integer.
function mplsHeader:setLabel(int)
	int = int or 4
	-- Per block (8, 8, 4)
	-- Only get the first 8
	firstbits = rshift(band(int, 0xff000), 12)
	self.labelstart = rshift(int, 24) -- retain the first 8 bits
	-- The second set of 8
	self.labelmid = rshift(band(int, 0xff0), 4) -- retain the second 8 bits
	-- The last 4, which is merged with the TC and BoS
	lastbits = band(int, 0xf) -- last 4, in the correct position
	old_last = self.labelend_tc_s
	old_last = band(old_last, 0x0f) -- retain TC and BoS
	self.labelend_tc_s = bor(lshift(lastbits, 4), old_last)
end

--- Retrieve the label.
--- @return label as 20 bit integer.
function mplsHeader:getLabel()
	label = lshift(self.labelstart, 12) + lshift(self.labelmid, 4)
	label = label + rshift(self.labelend_tc_s, 4)
	return label
end

--- Retrieve the label as string.
--- @return label as string.
function mplsHeader:getLabelString()
	return self.getLabel()
end


--- Set the TC
--- Is the 3 bits after the label in label_tc_s
--- @param int tc of the mpls header as 3 bit integer.
function mplsHeader:setTC(int)
	int = int or 0
	-- Zero out the previous TC
	self.labelend_tc_s = band(self.labelend_tc_s, 0xf1)
	-- Now set it
	self.labelend_tc_s = bor(self.labelend_tc_s, lshift(int, 1))
end

--- Retrieve the TC
--- @return TC as 3 bit integer.
function mplsHeader:getTC()
	-- get the 3 bits and shift them to the right
	return rshift(band(self.labelend_tc_s, 0x0e), 1)
end

--- Retrieve the TC as string.
--- @return TC as string.
function mplsHeader:getTCString()
	return self.getTC()
end


--- Set the BOS
--- @param int bos of the mpls header as 1 bit integer.
function mplsHeader:setBOS(int)
	int = int or 0
	-- Zero out the previous BoS
	self.labelend_tc_s = band(self.labelend_tc_s, 0xfe)
	-- Now set it
	self.labelend_tc_s = bor(self.labelend_tc_s, int)
end

--- Retrieve the BoS.
--- @return BoS as A bit integer.
function mplsHeader:getBOS()
	-- get the bit
	return  band(self.labelend_tc_s, 0x01)
end

--- Retrieve the BoS as string.
--- @return BoS as string.
function mplsHeader:getBOSString()
	return self.getBOS()
end


function mplsHeader:setTTL(int)
	int = int or 255
	self.ttl = int
end

--- Retrieve the label.
--- @return label as A bit integer.
function mplsHeader:getTTL()
	return self.ttl 
end

--- Retrieve the TTL as string.
--- @return TTL as string.
function mplsHeader:getTTLString()
	return self.getTTL()
end


--- Set all members of the mpls header.
--- Per default, all members are set to default values specified in the respective set function.
--- Optional named arguments can be used to set a member to a user-provided value.
--- @param args Table of named arguments. Available arguments: mpls
--- @param pre prefix for namedArgs. Default 'mpls'.
--- @code
--- fill() -- only default values
--- fill{ mplsLabel=1 } -- all members are set to default values with the exception of mplsLabel, ...
--- @endcode
function mplsHeader:fill(args, pre)
	args = args or {}
	pre = pre or "mpls"

	self:setLabel(args[pre .. "Label"])
	self:setTC(args[pre .. "TC"])
	self:setBOS(args[pre .. "BOS"])
	self:setTTL(args[pre .. "TTL"])
end

--- Retrieve the values of all members.
--- @param pre prefix for namedArgs. Default 'mpls'.
--- @return Table of named arguments. For a list of arguments see "See also".
--- @see mplsHeader:fill
function mplsHeader:get(pre)
	pre = pre or "mpls"

	local args = {}
	args[pre .. "Label"] = self:getLabel()
	args[pre .. "TC"] = self:getTC()
	args[pre .. "BOS"] = self:getBOS()
	args[pre .. "TTL"] = self:getTTL()

	return args
end

--- Retrieve the values of all members.
--- @return Values in string format.
function mplsHeader:getString()
	return "MPLS " .. "Label: " .. self:getLabelString()
		.. " TC " .. self.getTCString() .. " BoS " .. self.getBOSString()
		.. " TTL " .. self.getTTLString()
end


------------------------------------------------------------------------
---- Metatypes
------------------------------------------------------------------------

mpls.metatype = mplsHeader


return mpls

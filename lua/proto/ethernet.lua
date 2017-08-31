------------------------------------------------------------------------
--- @file ethernet.lua
--- @brief Ethernet protocol utility.
--- Utility functions for the mac_address and ethernet_header structs 
--- Includes:
--- - Ethernet constants
--- - Mac address utility
--- - Ethernet header utility
--- - Definition of ethernet packets
------------------------------------------------------------------------

local ffi = require "ffi"

require "utils"
require "proto.template"
local initHeader = initHeader

local ntoh, hton = ntoh, hton
local ntoh16, hton16 = ntoh16, hton16
local bor, band, bnot, rshift, lshift= bit.bor, bit.band, bit.bnot, bit.rshift, bit.lshift
local istype = ffi.istype
local format = string.format

------------------------------------------------------------------------
---- Ethernet constants
------------------------------------------------------------------------

--- Ethernet protocol constants
local eth = {}

--- EtherType for IP4
eth.TYPE_IP = 0x0800
--- EtherType for Arp
eth.TYPE_ARP = 0x0806
--- EtherType for IP6
eth.TYPE_IP6 = 0x86dd
--- EtherType for Ptp
eth.TYPE_PTP = 0x88f7

eth.TYPE_8021Q = 0x8100

--- EtherType for LACP (Actually, 'Slow Protocols')
eth.TYPE_LACP = 0x8809

--- Special addresses
--- Ethernet broadcast address
eth.BROADCAST	= "ff:ff:ff:ff:ff:ff"
--- Invalid null address
eth.NULL	= "00:00:00:00:00:00"


------------------------------------------------------------------------
---- Mac addresses
------------------------------------------------------------------------

-- struct
ffi.cdef[[
	union __attribute__((__packed__)) mac_address {
		uint8_t		uint8[6];
		uint64_t	uint64[0]; // for efficient reads
	};
]]

--- Module for mac_address struct
local macAddr = {}
macAddr.__index = macAddr
local macAddrType = ffi.typeof("union mac_address")

--- Retrieve the MAC address.
--- @return Address as number
function macAddr:get()
	return tonumber(bit.band(self.uint64[0], 0xFFFFFFFFFFFFULL))
end

--- Set the MAC address.
--- @param addr Address as number
function macAddr:set(addr)
	addr = addr or 0
	self.uint8[0] = bit.band(addr, 0xFF)
	self.uint8[1] = bit.band(bit.rshift(addr, 8), 0xFF)
	self.uint8[2] = bit.band(bit.rshift(addr, 16), 0xFF)
	self.uint8[3] = bit.band(bit.rshift(addr, 24), 0xFF)
	self.uint8[4] = bit.band(bit.rshift(addr + 0ULL, 32ULL), 0xFF)
	self.uint8[5] = bit.band(bit.rshift(addr + 0ULL, 40ULL), 0xFF)
end

--- Set the MAC address.
--- @param mac Address in string format.
function macAddr:setString(mac)
	self:set(parseMacAddress(mac, true))
end

--- Test equality of two MAC addresses.
--- @param lhs Address in 'union mac_address' format.
--- @param rhs Address in 'union mac_address' format.
--- @return true if equal, false otherwise.
function macAddr.__eq(lhs, rhs)
	local isMAC = istype(macAddrType, lhs) and istype(macAddrType, rhs) 
	for i = 0, 5 do
		isMAC = isMAC and lhs.uint8[i] == rhs.uint8[i] 
	end
	return isMAC
end

--- Retrieve the string representation of a MAC address.
--- @return Address in string format.
function macAddr:getString()
	return ("%02x:%02x:%02x:%02x:%02x:%02x"):format(
			self.uint8[0], self.uint8[1], self.uint8[2], 
			self.uint8[3], self.uint8[4], self.uint8[5]
			)
end


----------------------------------------------------------------------------
---- Ethernet header
----------------------------------------------------------------------------

eth.default = {}
-- definition of the header format
eth.default.headerFormat = [[
	union mac_address	dst;
	union mac_address	src;
	uint16_t		type;
]]

--- Variable sized member
eth.default.headerVariableMember = nil

eth.vlan = {}
-- definition of the header format
eth.vlan.headerFormat = [[
	union mac_address	dst;
	union mac_address	src;
	uint16_t		vlan_id;
	uint16_t		vlan_tag;
	uint16_t		type;
]]

--- Variable sized member
eth.vlan.headerVariableMember = nil

eth.qinq = {}
-- definition of the header format
eth.qinq.headerFormat = [[
	union mac_address	dst;
	union mac_address	src;
	uint16_t		outer_vlan_id;
	uint16_t		outer_vlan_tag;
	uint16_t		inner_vlan_id;
	uint16_t		inner_vlan_tag;
	uint16_t		type;
]]

--- Variable sized member
eth.qinq.headerVariableMember = nil

eth.defaultType = "default"

--- Module for ethernet_header struct
local etherHeader = initHeader()
local etherVlanHeader = initHeader()
local etherQinQHeader = initHeader()
etherHeader.__index = etherHeader
etherVlanHeader.__index = etherVlanHeader
etherQinQHeader.__index = etherQinQHeader

--- Set the destination MAC address.
--- @param addr Address as number
function etherHeader:setDst(addr)
	self.dst:set(addr)
end

etherVlanHeader.setDst = etherHeader.setDst
etherQinQHeader.setDst = etherHeader.setDst

--- Retrieve the destination MAC address.
--- @return Address as number
function etherHeader:getDst(addr)
	return self.dst:get()
end

etherVlanHeader.getDst = etherHeader.getDst
etherQinQHeader.getDst = etherHeader.getDst

--- Set the source MAC address.
--- @param addr Address as number
function etherHeader:setSrc(addr)
	self.src:set(addr)
end

etherVlanHeader.setSrc = etherHeader.setSrc
etherQinQHeader.setSrc = etherHeader.setSrc

--- Retrieve the source MAC address.
--- @return Address as number
function etherHeader:getSrc(addr)
	return self.src:get()
end

etherVlanHeader.getSrc = etherHeader.getSrc
etherQinQHeader.getSrc = etherHeader.getSrc

--- Set the destination MAC address.
--- @param str Address in string format.
function etherHeader:setDstString(str)
	self.dst:setString(str)
end

etherVlanHeader.setDstString = etherHeader.setDstString
etherQinQHeader.setDstString = etherHeader.setDstString

--- Retrieve the destination MAC address.
--- @return Address in string format.
function etherHeader:getDstString()
	return self.dst:getString()
end

etherVlanHeader.getDstString = etherHeader.getDstString
etherQinQHeader.getDstString = etherHeader.getDstString

--- Set the source MAC address.
--- @param str Address in string format.
function etherHeader:setSrcString(str)
	self.src:setString(str)
end

etherVlanHeader.setSrcString = etherHeader.setSrcString
etherQinQHeader.setSrcString = etherHeader.setSrcString

--- Retrieve the source MAC address.
--- @return Address in string format.
function etherHeader:getSrcString()
	return self.src:getString()
end

etherVlanHeader.getSrcString = etherHeader.getSrcString
etherQinQHeader.getSrcString = etherHeader.getSrcString

--- Set the EtherType.
--- @param int EtherType as 16 bit integer.
function etherHeader:setType(int)
	int = int or eth.TYPE_IP
	self.type = hton16(int)
end

etherVlanHeader.setType = etherHeader.setType
etherQinQHeader.setType = etherHeader.setType

--- Retrieve the EtherType.
--- @return EtherType as 16 bit integer.
function etherHeader:getType()
	return hton16(self.type)
end

etherVlanHeader.getType = etherHeader.getType
etherQinQHeader.getType = etherHeader.getType

function etherVlanHeader:getVlanTag()
	return bit.band(hton16(self.vlan_tag), 0xFFF)
end

--- Set the full vlan tag, including the PCP and DEI bits (upper 4 bits)
function etherVlanHeader:setVlanTag(int)
	self.vlan_tag = hton16(int)
end

function etherQinQHeader:getInnerVlanTag()
	return bit.band(hton16(self.inner_vlan_tag), 0xFFF)
end

--- Set the full inner vlan tag, including the PCP and DEI bits (upper 4 bits)
function etherQinQHeader:setInnerVlanTag(int)
	int = int or 0
	self.inner_vlan_tag = hton16(int)
end

function etherQinQHeader:getOuterVlanTag()
	return bit.band(hton16(self.outer_vlan_tag), 0xFFF)
end

--- Set the full outer vlan tag, including the PCP and DEI bits (upper 4 bits)
function etherQinQHeader:setOuterVlanTag(int)
	int = int or 0
	self.outer_vlan_tag = hton16(int)
end

function etherQinQHeader:getOuterVlanId()
	return hton16(self.outer_vlan_tag)
end

--- Set the outer vlan id
function etherQinQHeader:setOuterVlanId(int)
	int = int or 0x8100
	self.outer_vlan_id = hton16(int)
end

--- Retrieve the ether type.
--- @return EtherType as string.
function etherHeader:getTypeString()
	local type = self:getType()
	local cleartext = ""
	
	if type == eth.TYPE_IP then
		cleartext = "(IP4)"
	elseif type == eth.TYPE_IP6 then
		cleartext = "(IP6)"
	elseif type == eth.TYPE_ARP then
		cleartext = "(ARP)"
	elseif type == eth.TYPE_PTP then
		cleartext = "(PTP)"
	elseif type == eth.TYPE_LACP then
		cleartext = "(LACP)"
	elseif type == eth.TYPE_8021Q then
		cleartext = "(VLAN)"
	else
		cleartext = "(unknown)"
	end

	return format("0x%04x %s", type, cleartext)
end

etherVlanHeader.getTypeString = etherHeader.getTypeString
etherQinQHeader.getTypeString = etherHeader.getTypeString

--- Set all members of the ethernet header.
--- Per default, all members are set to default values specified in the respective set function.
--- Optional named arguments can be used to set a member to a user-provided value. \n
--- Exemplary invocations:
--- @code
--- fill() --- only default values
--- fill{ ethSrc="12:23:34:45:56:67", ethType=0x137 } --- default value for ethDst; ethSrc and ethType user-specified
--- @endcode
--- @param args Table of named arguments. Available arguments: Src, Dst, Type
--- @param pre Prefix for namedArgs. Default 'eth'.
function etherHeader:fill(args, pre)
	args = args or {}
	pre = pre or "eth"

	local src = pre .. "Src"
	local dst = pre .. "Dst"
	args[src] = args[src] or "01:02:03:04:05:06"
	args[dst] = args[dst] or "07:08:09:0a:0b:0c"
	
	-- addresses can be either a string, a mac_address ctype or a device/queue object
	if type(args[src]) == "string" then
		self:setSrcString(args[src])
	elseif istype(macAddrType, args[src]) then
		self.src = args[src]
	elseif type(args[src]) == 'number' then
		self:setSrc(args[src])
	elseif type(args[src]) == "table" and args[src].id then
		self:setSrcString((args[src].dev or args[src]):getMacString())
	end
	if type(args[dst]) == "string" then
		self:setDstString(args[dst])
	elseif istype(macAddrType, args[dst]) then
		self.dst = args[dst]
	elseif type(args[dst]) == 'number' then
		self:setDst(args[dst])
	elseif type(args[dst]) == "table" and args[dst].id then
		self:setDstString((args[dst].dev or args[dst]):getMacString())
	end
	self:setType(args[pre .. "Type"])
end

function etherVlanHeader:fill(args, pre)
	self.vlan_id = 0x0081
	local vlanTag = args[pre .. "Vlan"] or 1
	self:setVlanTag(vlanTag)
	etherHeader.fill(self, args, pre)
end

function etherQinQHeader:fill(args, pre)
	local innerVlanTag = args[pre .. "innerVlanTag"] or 0
	local outerVlanId = args[pre .. "outerVlanId"] or 0x8100
	local outerVlanTag = args[pre .. "outerVlanTag"] or 0
	self.inner_vlan_id = hton16(0x8100)
	self:setInnerVlanTag(innerVlanTag)
	self:setOuterVlanId(outerVlanId)
	self:setOuterVlanTag(outerVlanTag)
	etherHeader.fill(self, args, pre)
end

--- Retrieve the values of all members.
--- @param pre Prefix for namedArgs. Default 'eth'.
--- @return Table of named arguments. For a list of arguments see "See Also".
--- @see etherHeader:fill
function etherHeader:get(pre)
	pre = pre or "eth"
	
	local args = {}
	args[pre .. "Src"] = self:getSrcString()
	args[pre .. "Dst"] = self:getDstString()
	args[pre .. "Type"] = self:getType()
	
	return args
end

function etherVlanHeader:get(pre)
	pre = pre or "eth"
	local args = etherHeader.get(self, pre)
	args[pre .. "Vlan"] = self:getVlanTag()
	return args
end

function etherQinQHeader:get(pre)
	pre = pre or "eth"
	local args = etherHeader.get(self, pre)
	args[pre .. "outerVlanId"] = self:getOuterVlanId()
	args[pre .. "outerVlanTag"] = self:getOuterVlanTag()
	args[pre .. "innerVlanTag"] = self:getInnerVlanTag()
	return args
end

--- Retrieve the values of all members.
--- @return Values in string format.
function etherHeader:getString()
	return "ETH " .. self:getSrcString() .. " > " .. self:getDstString() .. " type " .. self:getTypeString()
end

function etherVlanHeader:getString()
	return "ETH " .. self:getSrcString() .. " > " .. self:getDstString() .. " vlan " .. self:getVlanTag() .. " type " .. self:getTypeString()
end

function etherQinQHeader:getString()
	return "ETH " .. self:getSrcString() .. " > " .. self:getDstString() .. " outerVlan " .. self:getOuterVlanTag() .. " innerVlan " .. self:getInnerVlanTag() .. " type " .. self:getTypeString()
end

-- Maps headers to respective types.
-- This list should be extended whenever a new type is added to 'Ethernet constants'. 
local mapNameType = {
	ip4 = eth.TYPE_IP,
	ip6 = eth.TYPE_IP6,
	arp = eth.TYPE_ARP,
	ptp = eth.TYPE_PTP, 
	lacp = eth.TYPE_LACP,
}

--- Resolve which header comes after this one (in a packet).
--- For instance: in tcp/udp based on the ports.
--- This function must exist and is only used when get/dump is executed on
--- an unknown (mbuf not yet casted to e.g. tcpv6 packet) packet (mbuf)
--- @return String next header (e.g. 'eth', 'ip4', nil)
function etherHeader:resolveNextHeader()
	local type = self:getType()
	for name, _type in pairs(mapNameType) do
		if type == _type then
			return name
		end
	end
	return nil
end

etherVlanHeader.resolveNextHeader = etherHeader.resolveNextHeader
etherQinQHeader.resolveNextHeader = etherHeader.resolveNextHeader

--- Change the default values for namedArguments (for fill/get).
--- This can be used to for instance calculate a length value based on the total packet length.
--- See proto/ip4.setDefaultNamedArgs as an example.
--- This function must exist and is only used by packet.fill.
--- @param pre The prefix used for the namedArgs, e.g. 'eth'
--- @param namedArgs Table of named arguments (see See Also)
--- @param nextHeader The header following after this header in a packet
--- @param accumulatedLength The so far accumulated length for previous headers in a packet
--- @return Table of namedArgs
--- @see etherHeader:fill
function etherHeader:setDefaultNamedArgs(pre, namedArgs, nextHeader, accumulatedLength)
	-- only set Type
	if not namedArgs[pre .. "Type"] then
		for name, type in pairs(mapNameType) do
			if nextHeader == name then
				namedArgs[pre .. "Type"] = type
				break
			end
		end
	end
	if nextHeader == "lacp" then
		namedArgs[pre .. "Dst"] = "01:80:c2:00:00:02"
	end
	return namedArgs
end

etherVlanHeader.setDefaultNamedArgs = etherHeader.setDefaultNamedArgs
etherQinQHeader.setDefaultNamedArgs = etherHeader.setDefaultNamedArgs

function etherHeader:getSubType()
	if self:getType() == eth.TYPE_8021Q then
		return "vlan"
	else
		return "default"
	end
end

function etherVlanHeader:getSubType()
	return "vlan"
end

function etherQinQHeader:getSubType()
	return "qinq"
end

----------------------------------------------------------------------------------
---- Metatypes
----------------------------------------------------------------------------------

ffi.metatype("union mac_address", macAddr)
eth.default.metatype = etherHeader
eth.vlan.metatype = etherVlanHeader
eth.qinq.metatype = etherQinQHeader

return eth

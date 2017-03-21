------------------------------------------------------------------------
--- @file qinq.lua
--- @brief (802.1Q in Q) utility.
--- Utility functions for the 8021q_in_q_header structs 
--- Includes:
--- - qinq constants
--- - qinq header utility
--- - Definition of qinq packets
------------------------------------------------------------------------

local ffi = require "ffi"

require "utils"
require "proto.template"
local initHeader = initHeader

local istype = ffi.istype
local format = string.format
local macAddrType = ffi.typeof("union mac_address")



---------------------------------------------------------------------------
---- QINQ constants 
---------------------------------------------------------------------------

--- QINQ protocol constants
local qinq = {}


---------------------------------------------------------------------------
---- QINQ header
---------------------------------------------------------------------------

-- definition of the header format
qinq.headerFormat = [[
  union mac_address dst;
  union mac_address src;
  uint16_t          outer_vlan_id;
  uint16_t          outer_vlan_tag;
  uint16_t          inner_vlan_id;
  uint16_t          inner_vlan_tag;
  uint16_t          type;
]]

--- Variable sized member
qinq.headerVariableMember = nil

--- Module for qinq_address struct (see \ref headers.lua).
local qinqHeader = initHeader()
qinqHeader.__index = qinqHeader

--- Set the type.
--- @param int type of the QINQ header as 16 bit integer.
function qinqHeader:setType(int)
	int = int or 0x0800
  self.type = hton16(int)
end

--- Retrieve the type.
--- @return type as 16 bit integer.
function qinqHeader:getType()
	return hton16(self.type)
end

--- Retrieve the type as string.
--- @return type as string.
function qinqHeader:getTypeString()
	return self:getType()
end

--- Set the destination MAC address.
--- @param addr Address as number
function qinqHeader:setDst(addr)
  self.dst:set(addr)
end

--- Retrieve the destination MAC address.
--- @return Address as number
function qinqHeader:getDst(addr)
  return self.dst:get()
end

--- Set the source MAC address.
--- @param addr Address as number
function qinqHeader:setSrc(addr)
  self.src:set(addr)
end

--- Retrieve the source MAC address.
--- @return Address as number
function qinqHeader:getSrc(addr)
  return self.src:get()
end

--- Set the destination MAC address.
--- @param str Address in string format.
function qinqHeader:setDstString(str)
  self.dst:setString(str)
end

--- Retrieve the destination MAC address.
--- @return Address in string format.
function qinqHeader:getDstString()
  return self.dst:getString()
end

--- Set the source MAC address.
--- @param addr Address as number
function qinqHeader:setSrc(addr)
  self.src:set(addr)
end

--- Retrieve the source MAC address.
--- @return Address as number
function qinqHeader:getSrc(addr)
  return self.src:get()
end

--- Set the destination MAC address.
--- @param str Address in string format.
function qinqHeader:setDstString(str)
  self.dst:setString(str)
end

--- Retrieve the destination MAC address.
--- @return Address in string format.
function qinqHeader:getDstString()
  return self.dst:getString()
end

--- Set the source MAC address.
--- @param str Address in string format.
function qinqHeader:setSrcString(str)
  self.src:setString(str)
end

--- Retrieve the source MAC address.
--- @return Address in string format.
function qinqHeader:getSrcString()
  return self.src:getString()
end

--- Set the outer VLAN tag
--- @param VLAN tag 
function qinqHeader:setOuterTag(tag)
  tag = tag or 0
  self.outer_vlan_tag = hton16(tag)
end

--- Set the inner VLAN tag
--- @param VLAN tag 
function qinqHeader:setInnerTag(tag)
  tag = tag or 0
  self.inner_vlan_tag = hton16(tag)
end

--- Get the outer VLAN tag
--- @param VLAN tag 
function qinqHeader:getOuterTag()
  return hton16(self.outer_vlan_tag)
end

--- Get the inner VLAN tag
--- @param VLAN tag 
function qinqHeader:getInnerTag()
  return hton16(self.inner_vlan_tag)
end

--- Set all members of the QINQ  header.
--- Per default, all members are set to default values specified in the respective set function.
--- Optional named arguments can be used to set a member to a user-provided value.
--- @param args Table of named arguments. Available arguments: qinqType
--- @param pre prefix for namedArgs. Default 'qinq'.
--- @code
--- fill() -- only default values
--- fill{ qinqType=1 } -- all members are set to default values with the exception of qinqType, ...
--- @endcode
function qinqHeader:fill(args, pre)
	args = args or {}
	pre = pre or "qinq"

  local src = pre .. "Src"
  local dst = pre .. "Dst"
  args[src] = args[src] or "01:02:03:04:05:06"
  args[dst] = args[dst] or "07:08:09:0a:0b:0c"

  -- addresses can be either a string, a mac_address ctype or a device/queue object
  if type(args[src]) == "string" then
    self:setSrcString(args[src])
  elseif istype(macAddrType, args[src]) then
    self:setSrc(args[src])
  elseif type(args[src]) == "table" and args[src].id then
    self:setSrcString((args[src].dev or args[src]):getMacString())
  end
  if type(args[dst]) == "string" then
    self:setDstString(args[dst])
  elseif istype(macAddrType, args[dst]) then
    self:setDst(args[dst])
  elseif type(args[dst]) == "table" and args[dst].id then
    self:setDstString((args[dst].dev or args[dst]):getMacString())
  end

	self:setType(args[pre .. "Type"])

  self.inner_vlan_id = hton16(0x8100)
  self.outer_vlan_id = hton16(0x8100)

  local outertag = pre .. "OuterTag"
  local innertag = pre .. "InnerTag"
  self:setOuterTag(args[outertag])
  self:setInnerTag(args[innertag])

end

--- Retrieve the values of all members.
--- @param pre prefix for namedArgs. Default 'qinq'.
--- @return Table of named arguments. For a list of arguments see "See also".
--- @see qinqHeader:fill
function qinqHeader:get(pre)
	pre = pre or "qinq"

	local args = {}
  args[pre .. "Src"] = self:getSrcString()
  args[pre .. "Dst"] = self:getDstString()
	args[pre .. "Type"] = self:getType() 
  args[pre .. "OuterTag"] = self:getOuterTag()
  args[pre .. "InnerTag"] = self:getInnerTag()

	return args
end

--- Retrieve the values of all members.
--- @return Values in string format.
function qinqHeader:getString()
	return "qinq " .. self:getTypeString()
end

--- Resolve which header comes after this one (in a packet)
--- For instance: in tcp/udp based on the ports
--- This function must exist and is only used when get/dump is executed on 
--- an unknown (mbuf not yet casted to e.g. tcpv6 packet) packet (mbuf)
--- @return String next header (e.g. 'eth', 'ip4', nil)
function qinqHeader:resolveNextHeader()
	return nil
end	

--- Change the default values for namedArguments (for fill/get)
--- This can be used to for instance calculate a length value based on the total packet length
--- See proto/ip4.setDefaultNamedArgs as an example
--- This function must exist and is only used by packet.fill
--- @param pre The prefix used for the namedArgs, e.g. 'qinq'
--- @param namedArgs Table of named arguments (see See more)
--- @param nextHeader The header following after this header in a packet
--- @param accumulatedLength The so far accumulated length for previous headers in a packet
--- @return Table of namedArgs
--- @see qinqHeader:fill
function qinqHeader:setDefaultNamedArgs(pre, namedArgs, nextHeader, accumulatedLength)
	return namedArgs
end


------------------------------------------------------------------------
---- Metatypes
------------------------------------------------------------------------

qinq.metatype = qinqHeader


return qinq

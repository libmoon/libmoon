------------------------------------------------------------------------
--- @file packetChecks.lua
--- @brief Check of packet types
------------------------------------------------------------------------

local proto = require "proto/proto"

local mod = {}

function mod.isIP4(pkt)
	return pkt.eth:getType() == proto.eth.TYPE_IP 
end

function mod.isTcp4(pkt)
	return mod.isIP4(pkt) and pkt.ip4:getProtocol() == proto.ip4.PROTO_TCP
end

return mod

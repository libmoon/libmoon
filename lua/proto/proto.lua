------------------------------------------------------------------------
--- @file proto.lua
--- @brief Includes all protocol modules in one place.
------------------------------------------------------------------------
local proto = {}

-- order is relevant as for instance arp requires eth/ip addresses
proto.eth = require "proto.ethernet"
proto.ethernet = proto.eth
proto.ip4 = require "proto.ip4"
proto.ip6 = require "proto.ip6"
proto.arp = require "proto.arp"
proto.icmp = require "proto.icmp"
proto.udp = require "proto.udp"
proto.tcp = require "proto.tcp"
proto.ptp = require "proto.ptp"
proto.vxlan = require "proto.vxlan"
proto.esp = require "proto.esp"
proto.ah = require "proto.ah"
proto.dns = require "proto.dns"
proto.ipfix = require "proto.ipfix"
proto.sflow = require "proto.sflow"
proto.lacp = require "proto.lacp"
proto.gre = require "proto.gre"

return proto

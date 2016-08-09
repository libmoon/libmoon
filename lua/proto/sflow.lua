--- sFlowv5 implementation

local ffi = require "ffi"
local pkt = require "packet"

local ntoh, hton = ntoh, hton
local ntoh16, hton16 = ntoh16, hton16
local bor, band, bnot, rshift, lshift= bit.bor, bit.band, bit.bnot, bit.rshift, bit.lshift
local istype = ffi.istype
local format = string.format

-- http://www.sflow.org/SFLOW-DATAGRAM5.txt
ffi.cdef[[
struct __attribute__((__packed__)) sflowv5_ipv4_header {
	uint32_t version;
	uint32_t agent_ip_type;
	union ip4_address agent_ip;
	uint32_t sub_agent_id;
	uint32_t seq;
	uint32_t uptime;
	uint32_t num_samples;
};

struct __attribute__((__packed__)) sflowv5_ipv6_header {
	uint32_t version;
	uint32_t agent_ip_type;
	union ip6_address agent_ip;
	uint32_t sub_agent_id;
	uint32_t seq;
	uint32_t uptime;
	uint32_t num_samples;
};

struct __attribute__((__packed__)) sflow_unknown_entry {
	uint32_t type;
	uint32_t len;
};

struct __attribute__((__packed__)) sflow_flow_sample {
	uint32_t type;
	uint32_t len;
	uint32_t seq;
	uint32_t source_id;
	uint32_t sampling_rate;
	uint32_t sample_pool;
	uint32_t drops;
	uint32_t input_port;
	uint32_t output_port;
	uint32_t num_records;
};

struct __attribute__((__packed__)) sflow_ext_switch_data {
	uint32_t type;
	uint32_t len;
	uint32_t src_vlan;
	uint32_t src_prio;
	uint32_t dst_vlan;
	uint32_t dst_prio;
};

struct __attribute__((__packed__)) sflow_raw_packet {
	uint32_t type;
	uint32_t len;
	uint32_t proto;
	uint32_t packet_len;
	uint32_t stripped_bytes;
	uint32_t header_size;
	union payload_t data;
};
]]

--- sflow protocol constants
local sflow = {}

local sflowHeader = {}
sflowHeader.__index = sflowHeader

function sflowHeader:setVersion(int)
	int = int or 0
	self.version = hton(int)
end

function sflowHeader:getVersion()
	return ntoh(self.version)
end

function sflowHeader:setAgentIp(ip)
	self.agent_ip_type = hton(1)
	self.agent_ip:set(ip)
end

function sflowHeader:getAgentIp()
	assert(self.agent_ip_type == hton(1))
	return self.agent_ip:get()
end

function sflowHeader:getAgentIpString()
	assert(self.agent_ip_type == hton(1))
	return self.agent_ip:getString()
end

function sflowHeader:setSubAgentId(int)
	int = int or 0
	self.sub_agent_id = hton(int)
end

function sflowHeader:getSubAgentId()
	return ntoh(self.sub_agent_id)
end

function sflowHeader:setSeq(int)
	int = int or 0
	self.seq = hton(int)
end

function sflowHeader:getSeq()
	return ntoh(self.seq)
end

function sflowHeader:setUptime(int)
	int = int or 0
	self.uptime = hton(int)
end

function sflowHeader:getUptime()
	return ntoh(self.uptime)
end

function sflowHeader:setNumSamples(int)
	int = int or 0
	self.num_samples = hton(int)
end

function sflowHeader:getUptime()
	return ntoh(self.num_samples)
end

--- Set all members of the sFlow header.
--- Per default, all members are set to default values specified in the respective set function.
--- Optional named arguments can be used to set a member to a user-provided value.
--- @param args Table of named arguments. Available arguments:
---  Version
---  AgentIp
---  SubAgentId
---  Seq
---  Uptime
---  NumSamples
--- @param pre prefix for namedArgs. Default 'sFlow'.
--- @code
--- fill() -- only default values
--- fill{ xyz=1 } -- all members are set to default values with the exception of xyz, ...
--- @endcode
function sflowHeader:fill(args, pre)
	args = args or {}
	pre = pre or "sflow"
	self:setVersion(args[pre .. "Version"])
	self:setAgentIp(args[pre .. "AgentIp"])
	self:setSubAgentId(args[pre .. "SubAgentId"])
	self:setSeq(args[pre .. "Seq"])
	self:setUptime(args[pre .. "Uptime"])
	self:setNumSamples(args[pre .. "NumSamples"])
end

--- Retrieve the values of all members.
--- @param pre prefix for namedArgs. Default 'sFlow'.
--- @return Table of named arguments. For a list of arguments see "See also".
--- @see sflowHeader:fill
function sflowHeader:get(pre)
	pre = pre or "sflow"
	local args = {}
	args[pre .. "Version"] = self:getVersion(args[pre .. "Version"])
	args[pre .. "AgentIp"] = self:getVersion(args[pre .. "AgentIp"])
	args[pre .. "SubAgentId"] = self:getVersion(args[pre .. "SubAgentId"])
	args[pre .. "Seq"] = self:getVersion(args[pre .. "Seq"])
	args[pre .. "Uptime"] = self:getVersion(args[pre .. "Uptime"])
	args[pre .. "NumSamples"] = self:getVersion(args[pre .. "NumSamples"])
	return args
end

--- Retrieve the values of all members.
--- @return Values in string format.
function sflowHeader:getString()
	return ("sFlowv5, agent IP %s, agent id %d, seq %d, uptime %d, samples %d "):format(
		self:getAgentIpString(), self:getAgentId(), self:getSeq(), self:getUptime(), self:getNumSamples()
	)
end

--- Resolve which header comes after this one (in a packet), nil in this case
function sflowHeader:resolveNextHeader()
	return nil
end	

--- Change the default values for namedArguments (for fill/get)
function sflowHeader:setDefaultNamedArgs(pre, namedArgs, nextHeader, accumulatedLength)
	return namedArgs
end


--- Cast the packet to a IPv4 sflow packet
pkt.getSFlowPacket = packetCreate('eth', 'ip4', 'sflowv5_ipv4')


ffi.metatype("struct sflowv5_ipv4_header", sflowHeader)


return sflow

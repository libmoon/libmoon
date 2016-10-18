--- sFlowv5 implementation

local ffi = require "ffi"
require "proto.template"
local initHeader = initHeader

local ntoh, hton = ntoh, hton
local ntoh16, hton16 = ntoh16, hton16
local bor, band, bnot, rshift, lshift= bit.bor, bit.band, bit.bnot, bit.rshift, bit.lshift
local istype = ffi.istype
local format = string.format
local cast = ffi.cast
local uint32 = ffi.typeof("uint32_t*")

-- http://www.sflow.org/SFLOW-DATAGRAM5.txt

ffi.cdef[[
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
	uint32_t num_entries;
	union payload_t payload;
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
	union payload_t payload;
};
]]

local sflowUnknownEntryType = ffi.typeof("struct sflow_unknown_entry*")
local sflowFlowSampleType = ffi.typeof("struct sflow_flow_sample*")
local sflowExtSwitchDataType = ffi.typeof("struct sflow_ext_switch_data*")
local sflowRawPacketType = ffi.typeof("struct sflow_raw_packet*")

--- sflow protocol constants
local sflow = {}

sflow.RECORD_TYPE_FLOW_SAMPLE_BE = hton(0x01)
sflow.RECORD_TYPE_EXT_SWITCH_DATA_BE = 0xe9030000
sflow.RECORD_TYPE_RAW_PACKET_BE = hton(0x01)

--- sflow ip6 header
sflow.ip6 = {}

-- definition of the header format
sflow.ip6.headerFormat = [[
	uint32_t version;
	uint32_t agent_ip_type;
	union ip6_address agent_ip;
	uint32_t sub_agent_id;
	uint32_t seq;
	uint32_t uptime;
	uint32_t num_samples;
	uint8_t payload[]; // use with a noPayload proto stack
]]

--- Variable sized member
sflow.ip6.headerVariableMember = "payload"

--- slfow ip4 header
sflow.ip4 = {}

-- definition of the header format
sflow.ip4.headerFormat = [[
	uint32_t version;
	uint32_t agent_ip_type;
	union ip4_address agent_ip;
	uint32_t sub_agent_id;
	uint32_t seq;
	uint32_t uptime;
	uint32_t num_samples;
	uint8_t payload[]; // use with a noPayload proto stack
]]

--- Variable sized member
sflow.ip4.headerVariableMember = "payload"

sflow.defaultType = "ip4"

local sflowHeader = initHeader()
sflowHeader.__index = sflowHeader

local sflowUnknownEntry = {}
sflowUnknownEntry.__index = sflowUnknownEntry

local sflowFlowSample = {}
sflowFlowSample.__index = sflowFlowSample

local sflowExtSwitchData = {}
sflowExtSwitchData.__index = sflowExtSwitchData

local sflowRawPacket = {}
sflowRawPacket.__index = sflowRawPacket

local function genIntSetter(field)
	return function(self, int)
		self[field] = hton(int or 0)
	end
end
local function genIntGetter(field)
	return function(self, int)
		local num = ntoh(self[field])
		if num < 0 then
			num = 0x100000000 + num
		end
		return num
	end
end

sflow.headerType = sflowHeader
sflow.unknownEntryType = sflowUnknownEntryType
sflow.flowSampleType = sflowFlowSampleType
sflow.rawPacketType = sflowRawPacketType

sflowHeader.setVersion = genIntSetter("version")
sflowHeader.setSubAgentId = genIntSetter("sub_agent_id")
sflowHeader.setSeq = genIntSetter("seq")
sflowHeader.setUptime = genIntSetter("uptime")
sflowHeader.setNumSamples = genIntSetter("num_samples")

sflowHeader.getVersion = genIntGetter("version")
sflowHeader.getSubAgentId = genIntGetter("sub_agent_id")
sflowHeader.getSeq = genIntGetter("seq")
sflowHeader.getUptime = genIntGetter("uptime")
sflowHeader.getNumSamples = genIntGetter("num_samples")


sflowUnknownEntry.setType = genIntSetter("type")
sflowUnknownEntry.setLen = genIntSetter("len")

sflowUnknownEntry.getType = genIntGetter("type")
sflowUnknownEntry.getLen = genIntGetter("len")


sflowFlowSample.setType = genIntSetter("type")
sflowFlowSample.setLen = genIntSetter("len")
sflowFlowSample.setSeq = genIntSetter("seq")
sflowFlowSample.setSourceId = genIntSetter("source_id")
sflowFlowSample.setSamplingRate = genIntSetter("sampling_rate")
sflowFlowSample.setSamplePool = genIntSetter("sample_pool")
sflowFlowSample.setDrops = genIntSetter("drops")
sflowFlowSample.setInputPort = genIntSetter("input_port")
sflowFlowSample.setOutputPort = genIntSetter("output_port")
sflowFlowSample.setNumEntries = genIntSetter("num_entries")

sflowFlowSample.getType = genIntGetter("type")
sflowFlowSample.getLen = genIntGetter("len")
sflowFlowSample.getSeq = genIntGetter("seq")
sflowFlowSample.getSourceId = genIntGetter("source_id")
sflowFlowSample.getSamplingRate = genIntGetter("sampling_rate")
sflowFlowSample.getSamplePool = genIntGetter("sample_pool")
sflowFlowSample.getDrops = genIntGetter("drops")
sflowFlowSample.getInputPort = genIntGetter("input_port")
sflowFlowSample.getOutputPort = genIntGetter("output_port")
sflowFlowSample.getNumEntries = genIntGetter("num_entries")


sflowExtSwitchData.setType = genIntSetter("type")
sflowExtSwitchData.setLen = genIntSetter("len")
sflowExtSwitchData.setSrcVlan = genIntSetter("src_vlan")
sflowExtSwitchData.setSrcPrio = genIntSetter("src_prio")
sflowExtSwitchData.setDstVlan = genIntSetter("dst_vlan")
sflowExtSwitchData.setDstPrio = genIntSetter("dst_prio")

sflowExtSwitchData.getType = genIntGetter("type")
sflowExtSwitchData.getLen = genIntGetter("len")
sflowExtSwitchData.getSrcVlan = genIntGetter("src_vlan")
sflowExtSwitchData.getSrcPrio = genIntGetter("src_prio")
sflowExtSwitchData.getDstVlan = genIntGetter("dst_vlan")
sflowExtSwitchData.getDstPrio = genIntGetter("dst_prio")


sflowRawPacket.setType = genIntSetter("type")
sflowRawPacket.setLen = genIntSetter("len")
sflowRawPacket.setProto = genIntSetter("proto")
sflowRawPacket.setPacketLen = genIntSetter("packet_len")
sflowRawPacket.setStrippedBytes = genIntSetter("stripped_bytes")
sflowRawPacket.setHeaderSize = genIntSetter("header_size")

sflowRawPacket.getType = genIntGetter("type")
sflowRawPacket.getLen = genIntGetter("len")
sflowRawPacket.getProto = genIntGetter("proto")
sflowRawPacket.getPacketLen = genIntGetter("packet_len")
sflowRawPacket.getStrippedBytes = genIntGetter("stripped_bytes")
sflowRawPacket.getHeaderSize = genIntGetter("header_size")

local voidPtrType = voidPtrType
function sflowRawPacket:getData()
	return cast(voidPtrType, self.payload)
end

function sflowFlowSample:getNumEntries()
	return ntoh(self.num_entries)
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
	self:setAgentIp(args[pre .. "AgentIp"] or 0)
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
	local str = ("sFlowv5, agent IP %s, sub agent id %d, seq %d, uptime %d, samples %d \n"):format(
		self:getAgentIpString(), self:getSubAgentId(), self:getSeq(), self:getUptime(), self:getNumSamples()
	)
	
	for i, record in self:iterateSamples() do
		str = str .. "   " .. record:getString() .. "\n"
		for i, entry in record:iterateEntries() do
			str = str .. "      " .. entry:getString() .. "\n"
		end
	end
	return str:sub(0, #str - 1)
end

function sflowUnknownEntry:getString()
	return ("unsupported record type %d, len %d"):format(self:getType(), self:getLen())
end

function sflowFlowSample:getString()
	return ("Flow sample, type %d, len %d, seq %d, source id %d, sampling_rate %d, sample_pool %d, drops %d, input port %d, output port %d, records %d"):format(
		self:getType(), self:getLen(), self:getSeq(), self:getSourceId(), self:getSamplingRate(),
		self:getSamplePool(), self:getDrops(), self:getInputPort(), self:getOutputPort(), self:getNumEntries()
	)
end

function sflowExtSwitchData:getString()
	return ("Extended switch data, type %d, len %d, source vlan %d, src priority %d, dest vlan %d, dest priority %d"):format(
		self:getType(), self:getLen(), self:getSrcVlan(), self:getSrcPrio(), self:getDstVlan(), self:getDstPrio()
	)
end

function sflowRawPacket:getString()
	local str = ("Raw packet data, type %d, len %d, protocol %d, packet len %d, stripped bytes %d, header size %d"):format(
		self:getType(), self:getLen(), self:getProto(), self:getPacketLen(), self:getStrippedBytes(), self:getHeaderSize()
	)
	return str
end

function sflowHeader:iterateSamples()
	local numSamples = self:getNumSamples()
	local pos = 0
	return function(self, i)
		local payload = self.payload
		if i == numSamples then
			return
		end
		-- nope, there is no alignment or whatsoever
		local recordType = cast(uint32, payload + pos)[0]
		local recordLen = ntoh(cast(uint32, payload + pos)[1])
		local record
		if recordType == sflow.RECORD_TYPE_FLOW_SAMPLE_BE then
			record = cast(sflowFlowSampleType, payload + pos)
		else
			record = cast(sflowUnknownEntryType, payload + pos)
		end
		pos = pos + recordLen + 8
		if pos > 1600 then
			-- we unfortunately do not have the real packet len here
			-- however, packet buffers are at least 2048 - 64*3 bytes long
			-- so we at least we don't do anything completely stupid here
			-- (no we cannot support jumboframes with this at the moment)
			return
		end
		return i + 1, record
	end, self, 0
end

function sflowFlowSample:iterateEntries()
	local numSamples = self:getNumEntries()
	local payload = self.payload
	local pos = 0
	return function(self, i)
		if i == numSamples then
			return
		end
		local recordType = cast(uint32, payload.uint8 + pos)[0]
		local recordLen = ntoh(cast(uint32, payload.uint8 + pos)[1])
		local record
		if recordType == sflow.RECORD_TYPE_EXT_SWITCH_DATA_BE then
			record = cast(sflowExtSwitchDataType, payload.uint8 + pos)
		elseif recordType == sflow.RECORD_TYPE_RAW_PACKET_BE then
			record = cast(sflowRawPacketType, payload.uint8 + pos)
		else
			record = cast(sflowUnknownEntryType, payload.uint8 + pos)
		end
		pos = pos + recordLen + 8
		-- at least prevent the worst, but we can't do any better with the current architecture
		if pos > 1600 then
			return
		end
		return i + 1, record
	end, self, 0
end

local function it() return end
function sflowUnknownEntry:iterateEntries()
	return it
end



sflow.ip4.metatype = sflowHeader
ffi.metatype("struct sflow_unknown_entry", sflowUnknownEntry)
ffi.metatype("struct sflow_flow_sample", sflowFlowSample)
ffi.metatype("struct sflow_ext_switch_data", sflowExtSwitchData)
ffi.metatype("struct sflow_raw_packet", sflowRawPacket)


return sflow

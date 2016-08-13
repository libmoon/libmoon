--- i40e-specific code
local dev = {}

local ffi   = require "ffi"
local dpdkc = require "dpdkc"

ffi.cdef[[
int i40e_aq_config_vsi_bw_limit(void *hw, uint16_t seid, uint16_t credit, uint8_t max_bw, struct i40e_asq_cmd_details *cmd_details);
]]

-- statistics
local GLPRT_UPRCL = {}
local GLPRT_MPRCL = {}
local GLPRT_BPRCL = {}
local GLPRT_GORCL = {}
local GLPRT_UPTCL = {}
local GLPRT_MPTCL = {}
local GLPRT_BPTCL = {}
local GLPRT_GOTCL = {}
for i = 0, 3 do
	GLPRT_UPRCL[i] = 0x003005A0 + 0x8 * i
	GLPRT_MPRCL[i] = 0x003005C0 + 0x8 * i
	GLPRT_BPRCL[i] = 0x003005E0 + 0x8 * i
	GLPRT_GORCL[i] = 0x00300000 + 0x8 * i
	GLPRT_UPTCL[i] = 0x003009C0 + 0x8 * i
	GLPRT_MPTCL[i] = 0x003009E0 + 0x8 * i
	GLPRT_BPTCL[i] = 0x00300A00 + 0x8 * i
	GLPRT_GOTCL[i] = 0x00300680 + 0x8 * i
end

-- timestamping
local PRTTSYN_CTL1      = 0x00085020
local PRTTSYN_STAT_1    = 0x00085140
local PRTTSYN_TIME_L    = 0x001E4100
local PRTTSYN_TIME_H    = 0x001E4120
local PRTTSYN_ADJ       = 0x001E4280
local PRTTSYN_ADJ_DUMMY = 0x00083100 -- actually GL_FWRESETCNT (RO)
local PRTTSYN_TXTIME_L  = 0x001E41C0
local PRTTSYN_TXTIME_H  = 0x001E41E0

local PRTTSYN_CTL1_TSYNENA       = bit.lshift(1, 31)
local PRTTSYN_CTL1_TSYNTYPE_OFFS = 24
local PRTTSYN_CTL1_TSYNTYPE_MASK = bit.lshift(3, PRTTSYN_CTL1_TSYNTYPE_OFFS)
local PRTTSYN_CTL1_UDP_ENA_OFFS  = 26
local PRTTSYN_CTL1_UDP_ENA_MASK  = bit.lshift(3, PRTTSYN_CTL1_UDP_ENA_OFFS)
local PRTTSYN_STAT_1_RXT_ALL     = 0xf

dev.useTimsyncIds = true
dev.timeRegisters = {PRTTSYN_TIME_L, PRTTSYN_TIME_H, PRTTSYN_ADJ, PRTTSYN_ADJ_DUMMY}

--- Set the maximum rate by all queues in Mbit/s.
--- Only supported on XL710 NICs.
--- Note: these NICs use packet size excluding CRC checksum unlike the ixgbe-style NICs.
--- This means you will get an unexpectedly high rate.
function dev:setRate(rate)
	-- we cannot calculate the "proper" rate here as we do not know the packet size
	rate = math.floor(rate / 50 + 0.5) -- 50mbit granularity
	local i40eDev = dpdkc.dpdk_get_i40e_dev(self.id)
	local vsiSeid = dpdkc.dpdk_get_i40e_vsi_seid(self.id)
	assert(ffi.C.i40e_aq_config_vsi_bw_limit(i40eDev, vsiSeid, rate, 0, nil) == 0)
end

local function readCtr32(id, addr, last)
	local val = dpdkc.read_reg32(id, addr)
	local diff = val - last
	if diff < 0 then
		diff = 2^32 + diff
	end
	return last + diff
end

local function readCtr48(id, addr, last)
	local addrl = addr
	local addrh = addr + 4
	-- the intel driver doesn't use a memory fence between the two addrh reads, so this should be fine
	local h = dpdkc.read_reg32(id, addrh)
	local l = dpdkc.read_reg32(id, addrl)
	local h2 = dpdkc.read_reg32(id, addrh) -- check for overflow during read
	if h2 ~= h then
		-- overflow during the read
		-- we can just read the lower value again (1 overflow every 850ms max)
		l = dpdkc.read_reg32(self.id, addrl)
		h = h2 -- use the new high value
	end
	local val = l + h * 2^32 -- 48 bits, double is fine
	local diff = val - last
	if diff < 0 then
		diff = 2^48 + diff
	end
	return last + diff
end

function dev:getRxStats()
	local port = dpdkc.dpdk_get_pci_function(self.id)
	-- unicast, multicast, and broadcast packets
	self.uprc = readCtr32(self.id, GLPRT_UPRCL[port], self.uprc)
	self.mprc = readCtr32(self.id, GLPRT_MPRCL[port], self.mprc)
	self.bprc = readCtr32(self.id, GLPRT_BPRCL[port], self.bprc)
	-- octets
	self.gorc = readCtr48(self.id, GLPRT_GORCL[port], self.gorc)
	return self.uprc + self.mprc + self.bprc - self.initPkts, self.gorc - self.initBytes
end

dev.txStatsIgnoreCrc = true

function dev:init()
	self.uprc = 0
	self.mprc = 0
	self.bprc = 0
	self.gorc = 0
	-- these stats are unforunately not reset to 0 when the device is initialized
	-- the datasheet claims that the register can be cleared by writing 1s into them
	-- but that doesn't work on any of my XL710-based NICs...
	-- rte_eth_stats_reset also doesn't do anything
	local port = dpdkc.dpdk_get_pci_function(self.id)
	self.initPkts = readCtr32(self.id, GLPRT_UPRCL[port], 0)
	              + readCtr32(self.id, GLPRT_MPRCL[port], 0)
	              + readCtr32(self.id, GLPRT_BPRCL[port], 0)
	self.initBytes = readCtr48(self.id, GLPRT_GORCL[port], 0)
	self:store()
end


ffi.cdef[[
int phobos_i40e_reset_timecounters(uint32_t port_id);
]]

function dev:resetTimeCounters()
	ffi.C.phobos_i40e_reset_timecounters(self.id)
end

function dev:enableRxTimestamps(queue, udpPort)
	udpPort = udpPort or 319
	if udpPort ~= 319 then
		self:unsupported("Timestamping on UDP ports other than 319")
	end
	-- enable rx timestamping
	if not self.timesyncEnabled then
		-- this function takes 100ms for some reason, do not run this unnecessarily
		-- (the enable function is also called to change the UDP port)
		dpdkc.rte_eth_timesync_enable(self.id)
		self.timesyncEnabled = true
	end
	-- enable UDP as well
	local val1 = dpdkc.read_reg32(self.id, PRTTSYN_CTL1)
	val1 = bit.bor(val1, PRTTSYN_CTL1_TSYNENA)
	val1 = bit.band(val1, bit.bnot(PRTTSYN_CTL1_TSYNTYPE_MASK))
	val1 = bit.bor(val1, bit.lshift(2, PRTTSYN_CTL1_TSYNTYPE_OFFS))
	val1 = bit.band(val1, bit.bnot(PRTTSYN_CTL1_UDP_ENA_MASK))
	val1 = bit.bor(val1, bit.lshift(3, PRTTSYN_CTL1_UDP_ENA_OFFS))
	dpdkc.write_reg32(self.id, PRTTSYN_CTL1, val1)
end

function dev:clearTimestamps()
	local stats = dpdkc.read_reg32(self.id, PRTTSYN_STAT_1)
	if bit.band(stats, PRTTSYN_STAT_1_RXT_ALL) ~= 0 then
		for i = 0, 3 do
			self:getRxTimestamp(nil, 10, i)
		end
	end
end

-- could skip a few registers here, but doesn't matter
dev.enableTxTimestamps = dev.enableRxTimestamps

function dev:hasRxTimestamp()
	local stats = dpdkc.read_reg32(self.id, PRTTSYN_STAT_1)
	return bit.band(stats, PRTTSYN_STAT_1_RXT_ALL) ~= 0 and -1 or nil
end


return dev

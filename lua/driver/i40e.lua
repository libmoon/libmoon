--- i40e-specific code
local dev = {}

local ffi   = require "ffi"
local dpdkc = require "dpdkc"

ffi.cdef[[
int i40e_aq_config_vsi_bw_limit(void *hw, uint16_t seid, uint16_t credit, uint8_t max_bw, struct i40e_asq_cmd_details *cmd_details);
]]

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

return dev

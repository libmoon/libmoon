--- ixgbe-specific code
local dev = {}

local dpdkc = require "dpdkc"

-- rx stats
local GPRC	= 0x00004074
local GORCL = 0x00004088
local GORCH	= 0x0000408C

-- tx stats
local GPTC      = 0x00004080
local GOTCL     = 0x00004090
local GOTCH     = 0x00004094

-- ixgbe does not count bytes dropped due to buffer space and the packet drop counters seem to be empty
-- however, we want to count all packets *at the NIC level* regardless whether they were fetched by the driver or not
-- this behavior is consistent with other drivers and more useful
function dev:getRxStats()
	-- these counters are clear-on-read
	self.rxPkts = (self.rxPkts or 0ULL) + dpdkc.read_reg32(self.id, GPRC)
	self.rxBytes = (self.rxBytes or 0ULL) + dpdkc.read_reg32(self.id, GORCL) + dpdkc.read_reg32(self.id, GORCH) * 2^32
	return tonumber(self.rxPkts), tonumber(self.rxBytes)
end

-- necessary because of clear-on-read registers and the interaction with the normal rte_eth_stats_get() call
function dev:getTxStats()
	self.txPkts = (self.txPkts or 0ULL) + dpdkc.read_reg32(self.id, GPTC)
	self.txBytes = (self.txBytes or 0ULL) + dpdkc.read_reg32(self.id, GOTCL) + dpdkc.read_reg32(self.id, GOTCH) * 2^32
	return tonumber(self.txPkts), tonumber(self.txBytes)
end


return dev


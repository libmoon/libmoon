--- ixgbe-specific code
local dev = {}

local dpdkc = require "dpdkc"
local ffi   = require "ffi"
local log   = require "log"

-- rx stats
local GPRC	= 0x00004074
local GORCL = 0x00004088
local GORCH	= 0x0000408C

-- tx stats
local GPTC      = 0x00004080
local GOTCL     = 0x00004090
local GOTCH     = 0x00004094

-- timestamping
local RXMTRL     = 0x00005120
local TSYNCRXCTL = 0x00005188
local RXSATRH    = 0x000051A8
local SYSTIMEL   = 0x00008C0C
local SYSTIMEH   = 0x00008C10
local TIMEADJL   = 0x00008C18
local TIMEADJH   = 0x00008C1C
local ETQS_3     = 0x0000EC00 + 4 * 3

local TSYNCRXCTL_RXTT            = 1
local TSYNCRXCTL_TYPE_OFFS       = 1
local TSYNCRXCTL_TYPE_MASK       = bit.lshift(7, TSYNCRXCTL_TYPE_OFFS)
local TSYNCRXCTL_TSIP_UT_EN_OFFS = 23
local TSYNCRXCTL_TSIP_UP_EN_OFFS = 24

local ETQS_RX_QUEUE_OFFS   = 16
local ETQS_QUEUE_ENABLE    = bit.lshift(1, 31)


dev.supportsFdir  = true
dev.timeRegisters = {SYSTIMEL, SYSTIMEH, TIMEADJL, TIMEADJH}
dev.crcPatch      = true

-- magic values for the CRC based rate control in moongen
dev.minPacketSize = 14   -- yes, this NIC can send out packets that are that small without padding :)
dev.maxPacketRate = 16.4 -- maximum rate with illegally small packets

-- ixgbe does not count bytes dropped due to buffer space and the packet drop counters seem to be empty
-- however, we want to count all packets *at the NIC level* regardless whether they were fetched by the driver or not
-- this behavior is consistent with other drivers and more useful
function dev:getRxStats()
	-- these counters are clear-on-read
	self.rxPkts = (self.rxPkts or 0ULL) + dpdkc.read_reg32(self.id, GPRC)
	self.rxBytes = (self.rxBytes or 0ULL) + dpdkc.read_reg32(self.id, GORCL) + dpdkc.read_reg32(self.id, GORCH) * 2^32
	return tonumber(self.rxPkts), tonumber(self.rxBytes)
end

-- clear RX counters.  We want to clear the s/w statistics and also reg read to clear the h/w level
function dev:clearRxStats()
	dpdkc.read_reg32(self.id, GPRC)
	dpdkc.read_reg32(self.id, GORCL)
	dpdkc.read_reg32(self.id, GORCH)
	self.rxPkts = 0ULL
	self.rxBytes = 0ULL
	return
end

-- necessary because of clear-on-read registers and the interaction with the normal rte_eth_stats_get() call
function dev:getTxStats()
	self.txPkts = (self.txPkts or 0ULL) + dpdkc.read_reg32(self.id, GPTC)
	self.txBytes = (self.txBytes or 0ULL) + dpdkc.read_reg32(self.id, GOTCL) + dpdkc.read_reg32(self.id, GOTCH) * 2^32
	return tonumber(self.txPkts), tonumber(self.txBytes)
end

ffi.cdef[[
int libmoon_ixgbe_reset_timecounters(uint32_t port_id);
]]

function dev:resetTimeCounters()
	ffi.C.libmoon_ixgbe_reset_timecounters(self.id)
end

-- just rte_eth_timesync_enable doesn't do the trick :(
function dev:enableRxTimestamps(queue, udpPort)
	udpPort = udpPort or 319
	dpdkc.rte_eth_timesync_enable(self.id)
	-- enable timestamping UDP packets as well
	local val = dpdkc.read_reg32(self.id, TSYNCRXCTL)
	val = bit.band(val, bit.bnot(TSYNCRXCTL_TYPE_MASK))
	val = bit.bor(val, bit.lshift(2, TSYNCRXCTL_TYPE_OFFS))
	dpdkc.write_reg32(self.id, TSYNCRXCTL, val)
	-- configure UDP port
	-- fun fact: the register is initialized to 0x319 instead of 319
	dpdkc.write_reg32(self.id, RXMTRL, bit.lshift(udpPort, 16))
end

-- could skip a few registers here, but doesn't matter
dev.enableTxTimestamps = dev.enableRxTimestamps

function dev:hasRxTimestamp()
	if bit.band(dpdkc.read_reg32(self.id, TSYNCRXCTL), TSYNCRXCTL_RXTT) == 0 then
		return nil
	end
	-- this register is undocumented on X550 but it seems to work just fine
	local res = bswap16(bit.rshift(dpdkc.read_reg32(self.id, RXSATRH), 16))
	return res
end

function dev:filterL2Timestamps(queue)
	-- DPDK's init function configures ETQF3 to enable PTP L2 timestamping, so use this one
	dpdkc.write_reg32(self.id, ETQS_3, bit.bor(ETQS_QUEUE_ENABLE, bit.lshift(queue.qid, ETQS_RX_QUEUE_OFFS)))
end

function dev:enableRxTimestampsAllPackets(queue)
	dpdkc.rte_eth_timesync_enable(self.id)
	local val = dpdkc.read_reg32(self.id, TSYNCRXCTL)
	val = bit.band(val, bit.bnot(TSYNCRXCTL_TYPE_MASK))
	val = bit.bor(val, bit.lshift(4, TSYNCRXCTL_TYPE_OFFS))
	val = bit.bor(val, bit.lshift(1, TSYNCRXCTL_TSIP_UT_EN_OFFS))
	-- not necessary unless you configure some weird stuff
	val = bit.bor(val, bit.lshift(0xFF, TSYNCRXCTL_TSIP_UP_EN_OFFS))
	dpdkc.write_reg32(self.id, TSYNCRXCTL, val)
end

dev.embeddedTimestampAtEndOfBuffer = true

return dev


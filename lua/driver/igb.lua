--- igb-specific code
local dev = {}

local dpdkc = require "dpdkc"
local ffi   = require "ffi"
local log   = require "log"

-- the igb driver actually reports stats almost as expected
dev.txStatsIgnoreCrc = true
dev.rxStatsIgnoreCrc = true

-- timestamping
local TSAUXC     = 0x0000B640
local TIMINCA    = 0x0000B608
local TSYNCRXCTL = 0x0000B620
local TSYNCTXCTL = 0x0000B614
local TXSTMPL    = 0x0000B618
local TXSTMPH    = 0x0000B61C
local RXSTMPL    = 0x0000B624
local RXSTMPH    = 0x0000B628
local RXSATRH    = 0x0000B630
local ETQF_3     = 0x00005CB0 + 4 * 3
local SYSTIMEL   = 0x0000B600
local SYSTIMEH   = 0x0000B604
local TIMEADJL   = 0x0000B60C
local TIMEADJH   = 0x0000B610

local SRRCTL_82580 = {}
for i = 0, 7 do
	SRRCTL_82580[i] = 0x0000C00C + 0x40 * i
end

local TSYNCRXCTL_TYPE_OFFS = 1
local TSYNCRXCTL_TYPE_MASK = bit.lshift(7, TSYNCRXCTL_TYPE_OFFS)
local TSYNCRXCTL_RXTT      = 1
local ETQF_QUEUE_ENABLE    = bit.lshift(1, 31)
local SRRCTL_TIMESTAMP     = bit.lshift(1, 30)

-- device initializing takes unreasonably long sometimes
dev.linkWaitTime = 18

dev.timeRegisters = {SYSTIMEL, SYSTIMEH, TIMEADJL, TIMEADJH}
dev.crcPatch      = true

ffi.cdef[[
int libmoon_igb_reset_timecounters(uint32_t port_id);
]]

function dev:resetTimeCounters()
	ffi.C.libmoon_igb_reset_timecounters(self.id)
end

-- just rte_eth_timesync_enable doesn't do the trick :(
function dev:enableRxTimestamps(queue, udpPort)
	udpPort = udpPort or 319
	if udpPort ~= 319 then
		self:unsupported("Timestamping on UDP ports other than 319")
	end
	dpdkc.rte_eth_timesync_enable(self.id)
	-- enable timestamping UDP packets as well
	local val = dpdkc.read_reg32(self.id, TSYNCRXCTL)
	val = bit.band(val, bit.bnot(TSYNCRXCTL_TYPE_MASK))
	val = bit.bor(val, bit.lshift(2, TSYNCRXCTL_TYPE_OFFS))
	dpdkc.write_reg32(self.id, TSYNCRXCTL, val)
end

dev.enableTxTimestamps = dev.enableRxTimestamps

function dev:hasRxTimestamp()
	if bit.band(dpdkc.read_reg32(self.id, TSYNCRXCTL), TSYNCRXCTL_RXTT) == 0 then
		return nil
	end
	return bswap16(bit.rshift(dpdkc.read_reg32(self.id, RXSATRH), 16))
end

function dev:filterL2Timestamps(queue)
	-- DPDK's init function configures ETQF3 to enable PTP L2 timestamping, so use this one
	local val = dpdkc.read_reg32(self.id, ETQF_3)
	val = bit.bor(val, ETQF_QUEUE_ENABLE, bit.lshift(queue.qid, 16))
	dpdkc.write_reg32(self.id, ETQF_3, val)
end

function dev:filterUdpTimestamps()
	-- have a look at the FHFT (0x9000) registers if you want to implement this
	log:warn("Filtering UDP timestamps on IGB is supported by the HW but NYI")
end

function dev:enableRxTimestampsAllPackets(queue)
	dpdkc.rte_eth_timesync_enable(self.id)
	local val = dpdkc.read_reg32(self.id, TSYNCRXCTL)
	val = bit.band(val, bit.bnot(TSYNCRXCTL_TYPE_MASK))
	val = bit.bor(val, bit.lshift(bit.lshift(1, 2), TSYNCRXCTL_TYPE_OFFS))
	dpdkc.write_reg32(self.id, TSYNCRXCTL, val)
	dpdkc.write_reg32(self.id, SRRCTL_82580[queue.qid], bit.bor(dpdkc.read_reg32(self.id, SRRCTL_82580[queue.qid]), SRRCTL_TIMESTAMP))
end

return dev


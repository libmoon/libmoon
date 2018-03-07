--- Hardware timestamping.
local mod = {}

local ffi    = require "ffi"
local dpdkc  = require "dpdkc"
local dpdk   = require "dpdk"
local device = require "device"
local eth    = require "proto.ethernet"
local memory = require "memory"
local timer  = require "timer"
local log    = require "log"
local filter = require "filter"
local libmoon = require "libmoon"

local timestamper = {}
timestamper.__index = timestamper

--- Create a new timestamper.
--- A NIC can only be used by one thread at a time due to clock synchronization.
--- Best current pratice is to use only one timestamping thread to avoid problems.
function mod:newTimestamper(txQueue, rxQueue, mem, udp, doNotConfigureUdpPort)
	mem = mem or memory.createMemPool(function(buf)
		-- defaults are good enough for us here
		if udp then
			buf:getUdpPtpPacket():fill{
				ethSrc = txQueue,
			}
		else
			buf:getPtpPacket():fill{
				ethSrc = txQueue,
			}
		end
	end)
	txQueue:enableTimestamps()
	rxQueue:enableTimestamps()
	if udp and rxQueue.dev.supportsFdir then
		rxQueue:filterUdpTimestamps()
	elseif not udp then
		rxQueue:filterL2Timestamps()
	end
	return setmetatable({
		mem = mem,
		txBufs = mem:bufArray(1),
		rxBufs = mem:bufArray(128),
		txQueue = txQueue,
		rxQueue = rxQueue,
		txDev = txQueue.dev,
		rxDev = rxQueue.dev,
		seq = 1,
		udp = udp,
		useTimesync = rxQueue.dev.useTimsyncIds,
		doNotConfigureUdpPort = doNotConfigureUdpPort
	}, timestamper)
end

--- See newTimestamper()
function mod:newUdpTimestamper(txQueue, rxQueue, mem, doNotConfigureUdpPort)
	return self:newTimestamper(txQueue, rxQueue, mem, true, doNotConfigureUdpPort)
end

--- Try to measure the latency of a single packet.
--- @param pktSize optional, the size of the generated packet, optional, defaults to the smallest possible size
--- @param packetModifier optional, a function that is called with the generated packet, e.g. to modified addresses
--- @param maxWait optional (cannot be the only argument) the time in ms to wait before the packet is assumed to be lost (default = 15)
function timestamper:measureLatency(pktSize, packetModifier, maxWait)
	if type(pktSize) == "function" then -- optional first argument was skipped
		return self:measureLatency(nil, pktSize, packetModifier)
	end
	pktSize = pktSize or self.udp and 76 or 60
	maxWait = (maxWait or 15) / 1000
	self.txBufs:alloc(pktSize)
	local buf = self.txBufs[1]
	buf:enableTimestamps()
	local expectedSeq = self.seq
	self.seq = (self.seq + 1) % 2^16
	if self.udp then
		buf:getUdpPtpPacket().ptp:setSequenceID(expectedSeq)
	else
		buf:getPtpPacket().ptp:setSequenceID(expectedSeq)
	end
	local skipReconfigure
	if packetModifier then
		skipReconfigure = packetModifier(buf)
	end
	if self.udp then
		if not self.doNotConfigureUdpPort then
			-- change timestamped UDP port as each packet may be on a different port
			self.rxQueue:enableTimestamps(buf:getUdpPacket().udp:getDstPort())
		end
		buf:getUdpPtpPacket():setLength(pktSize)
		self.txBufs:offloadUdpChecksums()
		if self.rxQueue.dev.reconfigureUdpTimestampFilter and not skipReconfigure then
			-- i40e driver fdir filters are broken
			-- it is not possible to match on flex bytes in udp packets without matching IPs and ports as well
			-- so we have to look at that packet and reconfigure the filters
			self.rxQueue.dev:reconfigureUdpTimestampFilter(self.rxQueue, buf:getUdpPacket())
		end
	end
	mod.syncClocks(self.txDev, self.rxDev)
	-- clear any "leftover" timestamps
	self.rxDev:clearTimestamps()
	self.txQueue:send(self.txBufs)
	local tx = self.txQueue:getTimestamp(500)
	local numPkts = 0
	if tx then
		-- sent was successful, try to get the packet back (assume that it is lost after a given delay)
		local timer = timer:new(maxWait)
		while timer:running() do
			local rx = self.rxQueue:tryRecv(self.rxBufs, 1000)
			numPkts = numPkts + rx
			local timestampedPkt = self.rxDev:hasRxTimestamp()
			if not timestampedPkt then
				-- NIC didn't save a timestamp yet, just throw away the packets
				self.rxBufs:freeAll()
			else
				-- received a timestamped packet (not necessarily in this batch)
				for i = 1, rx do
					local buf = self.rxBufs[i]
					local timesync = self.useTimesync and buf:getTimesync() or 0
					local seq = (self.udp and buf:getUdpPtpPacket() or buf:getPtpPacket()).ptp:getSequenceID()
					if buf:hasTimestamp() and seq == expectedSeq and (seq == timestampedPkt or timestampedPkt == -1) then
						-- yay!
						local rxTs = self.rxQueue:getTimestamp(nil, timesync) 
						if not rxTs then
							-- can happen if you hotplug cables
							return nil, numPkts
						end
						self.rxBufs:freeAll()
						local lat = rxTs - tx
						if lat > 0 and lat < 2 * maxWait * 10^9 then
							-- negative latencies may happen if the link state changes
							-- (timers depend on a clock that scales with link speed on some NICs)
							-- really large latencies (we only wait for up to maxWait ms)
							-- also sometimes happen since changing to DPDK for reading the timing registers
							-- probably something wrong with the DPDK wraparound tracking
							-- (but that's really rare and the resulting latency > a few days, so we don't really care)
							return lat, numPkts
						else
							return nil, numPkts
						end
					elseif buf:hasTimestamp() and (seq == timestampedPkt or timestampedPkt == -1) then
						-- we got a timestamp but the wrong sequence number. meh.
						self.rxQueue:getTimestamp(nil, timesync) -- clears the register
						-- continue, we may still get our packet :)
					elseif seq == expectedSeq and (seq ~= timestampedPkt and timestampedPkt ~= -1) then
						-- we got our packet back but it wasn't timestamped
						-- we likely ran into the previous case earlier and cleared the ts register too late
						self.rxBufs:freeAll()
						return nil, numPkts
					end
				end
			end
		end
		-- looks like our packet got lost :(
		return nil, numPkts
	else
		-- happens when hotplugging cables
		log:warn("Failed to timestamp packet on transmission")
		timer:new(maxWait):wait()
		return nil, numPkts
	end
end


function mod.syncClocks(dev1, dev2)
	local regs1 = dev1.timeRegisters
	local regs2 = dev2.timeRegisters
	if regs1[1] ~= regs2[1]
	or regs1[2] ~= regs2[2]
	or regs1[3] ~= regs2[3]
	or regs1[4] ~= regs2[4] then
		log:fatal("NICs incompatible, cannot sync clocks")
	end
	dpdkc.libmoon_sync_clocks(dev1.id, dev2.id, unpack(regs1))
	-- just to tell the driver that we are resetting the clock
	-- otherwise the cycle tracker becomes confused on long latencies
	dev1:resetTimeCounters()
	dev2:resetTimeCounters()
end

return mod


--- Device and queue configuration

local mod = {}

local libmoon    = require "libmoon"
local ffi        = require "ffi"
local dpdkc      = require "dpdkc"
local dpdk       = require "dpdk"
local memory     = require "memory"
local serpent    = require "Serpent"
local log        = require "log"
local timer      = require "timer"
local namespaces = require "namespaces"
local pciIds     = require "pci-ids"
local drivers    = require "drivers"
local eth        = require "proto.ethernet"
local E          = require "syscall".c.E

function mod.numDevices()
	return dpdkc.rte_eth_dev_count();
end

local dev = {}
dev.__index = dev
dev.__type = "device"

function dev:__tostring()
	return ("[Device: id=%d]"):format(self.id)
end

function dev:__eq(other)
	return self.id == other.id
end

function dev:__serialize()
    return "require 'device' local dev = " .. serpent.addMt(serpent.dumpRaw(self), "require('device').__devicePrototype") .. " require('drivers').initDriver(dev) dev:checkSocket() return dev", true
end

local txQueue = {}
txQueue.__index = txQueue
txQueue.__type = "txQueue"

function txQueue:__tostring()
	return ("[TxQueue: id=%d, qid=%d]"):format(self.id, self.qid)
end

function txQueue:__eq(other)
	return self.id == other.id and self.qid == other.qid
end

function txQueue:__serialize()
	return ('local dev = require "device" return dev.get(%d):getTxQueue(%d)'):format(self.id, self.qid), true
end

local rxQueue = {}
rxQueue.__index = rxQueue
rxQueue.__type = "rxQueue"

function rxQueue:__tostring()
	return ("[RxQueue: id=%d, qid=%d]"):format(self.id, self.qid)
end

function rxQueue:__eq(other)
	return self.id == other.id and self.qid == other.qid
end

function rxQueue:__serialize()
	return ('local dev = require "device" return dev.get(%d):getRxQueue(%d)'):format(self.id, self.qid), true
end


local devices = namespaces:get()

--- Configure a device
--- @param args A table containing the following named arguments
---   port Port to configure
---   mempools optional (default = create new mempools) RX mempools to associate with the queues
---   rxQueues optional (default = 1) Number of RX queues to configure 
---   txQueues optional (default = 1) Number of TX queues to configure 
---   rxDescs optional (default = 512)
---   txDescs optional (default = 1024)
---   numBufs optional (default max(2047, rxDescs * 2 -1))
---   bufSize optional (default = 2048)
---   speed optional (default = 0/max) Speed in Mbit to negotiate (currently disabled due to DPDK changes)
---   dropEnable optional (default = true) Drop rx packets directly if no rx descriptors are available
---   rssQueues optional (default = 0) Number of queues to use for RSS
---   rssBaseQueue optional (default = 0) The first queue to use for RSS, packets will go to queues rssBaseQueue up to rssBaseQueue + rssQueues - 1
---   rssFunctions optional (default = all supported functions) Table with hash functions specified in dpdk.ETH_RSS_*
---	  disableOffloads optional (default = false) Disable all offloading features, this significantly speeds up some drivers (e.g., ixgbe).
---                   set by default for drivers that do not support offloading (e.g., virtio)
---   stripVlan (default = true) Strip the VLAN tag on the NIC.
function mod.config(args)
	if not args or not args.port then
		log:fatal("usage: device.config({ port = x, ... })")
	end
	if args.port >= dpdkc.dpdk_get_max_ports() then
		log:fatal("maximum number of supported ports is %d, this can be changed with the DPDK compile-time configuration variable RTE_MAX_ETHPORTS\n", dpdkc.dpdk_get_max_ports())
	end
	if args.port >= dpdkc.rte_eth_dev_count() then
		log:fatal("there are only %d ports, tried to configure port id %d", dpdkc.rte_eth_dev_count(), args.port)
	end
	if mod.get(args.port) and mod.get(args.port).initialized then
		log:warn("Device %d already configured, skipping initilization", args.port)
		return mod.get(args.port)
	end
	local info = dev.getInfo{id = args.port}
	local driverInfo = drivers.getDriverInfo(ffi.string(info.driver_name))
	args.rxQueues = args.rxQueues or 1
	args.txQueues = args.txQueues or 1
	args.rxDescs = args.rxDescs or 512
	args.txDescs = args.txDescs or 1024
	args.numBufs = args.numBufs or math.max(2047, args.rxDescs * 2 - 1)
	args.bufSize = args.bufSize or 2048
	if args.rxQueues > info.max_rx_queues then
		log:fatal("device supports only %d rx queues, requested %d", info.max_rx_queues, args.rxQueues)
	end
	if args.txQueues > info.max_tx_queues then
		log:fatal("device supports only %d tx queues, requested %d", info.max_tx_queues, args.txQueues)
	end
	if args.rxDescs > info.rx_desc_lim.nb_max
	or args.rxDescs < info.rx_desc_lim.nb_min
	or args.rxDescs % info.rx_desc_lim.nb_align ~= 0 then
		log:fatal("device supports between %d and %d rx descriptors in steps of %d, requested %d",
			info.rx_desc_lim.nb_min, info.rx_desc_lim.nb_max, info.rx_desc_lim.nb_align, args.rxDescs)
	end
	if args.txDescs > info.tx_desc_lim.nb_max
	or args.txDescs < info.tx_desc_lim.nb_min
	or args.txDescs % info.tx_desc_lim.nb_align ~= 0 then
		log:fatal("device supports between %d and %d tx descriptors in steps of %d, requested %d",
			info.tx_desc_lim.nb_min, info.tx_desc_lim.nb_max, info.tx_desc_lim.nb_align, args.txDescs)
	end
	args.rssQueues = args.rssQueues or 0
	if args.disableOffloads == nil then
		args.disableOffloads = driverInfo.disableOffloads
	end
	args.rssFunctions = args.rssFunctions or {
		dpdk.ETH_RSS_IPV4,
		dpdk.ETH_RSS_FRAG_IPV4,
		dpdk.ETH_RSS_NONFRAG_IPV4_TCP,
		dpdk.ETH_RSS_NONFRAG_IPV4_UDP,
		dpdk.ETH_RSS_NONFRAG_IPV4_SCTP,
		dpdk.ETH_RSS_NONFRAG_IPV4_OTHER,
		dpdk.ETH_RSS_IPV6,
		dpdk.ETH_RSS_FRAG_IPV6,
		dpdk.ETH_RSS_NONFRAG_IPV6_TCP,
		dpdk.ETH_RSS_NONFRAG_IPV6_UDP,
		dpdk.ETH_RSS_NONFRAG_IPV6_SCTP,
		dpdk.ETH_RSS_NONFRAG_IPV6_OTHER,
		dpdk.ETH_RSS_L2_PAYLOAD,
		dpdk.ETH_RSS_IPV6_EX,
		dpdk.ETH_RSS_IPV6_TCP_EX,
		dpdk.ETH_RSS_IPV6_UDP_EX
	}
	local rssMask = 0
	for i, v in ipairs(args.rssFunctions) do
		rssMask = bit.bor(rssMask, v)
	end
	if args.stripVlan == nil then
		args.stripVlan = true
	end
	if args.dropEnable == nil then
		args.dropEnable = true
	end
	-- create mempools for rx queues
	if not args.mempools then
		args.mempools = {}
		for i = 1, args.rxQueues do
			table.insert(args.mempools, memory.createMemPool{n = args.numBufs, socket = dpdkc.dpdk_get_socket(args.port), bufSize = args.bufSize})
		end
	elseif #args.mempools ~= args.rxQueues then
		log:fatal("number of mempools must equal number of rx queues")
	end
	args.speed = args.speed or 0
	if args.rxQueues == 0 or args.txQueues == 0 then
		-- dpdk does not like devices without rx/tx queues :(
		log:fatal("Cannot initialize device without %s queues", args.rxQueues == 0 and args.txQueues == 0 and "rx and tx" or args.rxQueues == 0 and "rx" or "tx")
	end
	local mempools = ffi.new("struct mempool*[?]", args.rxQueues)
	for i, v in ipairs(args.mempools) do
		mempools[i - 1] = v
	end
	local rc = dpdkc.dpdk_configure_device(ffi.new("struct libmoon_device_config", {
		port = args.port,
		mempools = mempools,
		rx_queues = args.rxQueues,
		tx_queues = args.txQueues,
		rx_descs = args.rxDescs,
		tx_descs = args.txDescs,
		drop_enable = args.dropEnable,
		enable_rss = args.rssQueues > 1,
		rss_mask = rssMask,
		disable_offloads = args.disableOffloads,
		strip_vlan = args.stripVlan
	}))
	if rc ~= 0 then
	    log:fatal("Could not configure device %d: error %s", args.port, strError(rc))
	end
	local dev = mod.get(args.port)
	dev.initialized = true
	if args.rssQueues > 1 then
		dev:setRssQueues(args.rssQueues, args.rssBaseQueue)
	end
	if dev.init then
		dev:init()
	end
	dev:store()
	dev:setPromisc(true)
	if dev:getDriverName():match("i40e") then
		local fw = dev:getFirmware()
		if fw:match("^%s*5.05") then
			log:warn(
				"Device %s is an i40e NIC with firmware 5.05 which has known bugs related to timestamping.\n" ..
				"Refer to Intel's errata sheet for more information. Downgrade to 5.04 or upgrade to 6.x to fix this.",
				dev
			)
		end
	end
	return dev
end

ffi.cdef[[
struct rte_eth_rss_reta_entry64 {
	uint64_t mask;
	uint16_t reta[64];
};

int rte_eth_dev_rss_reta_update(uint8_t port, struct rte_eth_rss_reta_entry64* reta_conf, uint16_t reta_size);
]]

--- Setup RSS RETA table.
function dev:setRssQueues(n, baseQueue)
	baseQueue = baseQueue or 0
	assert(n > 0)
	if bit.band(n, n - 1) ~= 0 then
		log:warn("RSS distribution to queues will not be balanced as the number of queues (%d) is not a power of two.", n)
	end
	local retaSize = self:getInfo().reta_size
	if retaSize % 64 ~= 0 then
		log:fatal("NYI: number of RETA entries is not a multiple of 64", retaSize)
	end
	local entries = ffi.new("struct rte_eth_rss_reta_entry64[?]", retaSize / 64)
	local queue = baseQueue
	for i = 0, retaSize / 64 - 1 do
		entries[i].mask = 0xFFFFFFFFFFFFFFFFULL
		for j = 0, 63 do
			entries[i].reta[j] = queue
			queue = queue + 1
			if queue == baseQueue + n then
				queue = baseQueue
			end
		end
	end
	local ret = ffi.C.rte_eth_dev_rss_reta_update(self.id, entries, retaSize)
	if ret ~= 0 then
		log:fatal("Error setting up RETA table: " .. strError(ret))
	end
end

function mod.get(id)
	if type(id) ~= "number" then
		log:fatal("bad argument #1, expected number, got " .. type(id))
	end
	local obj
	local idStr = tostring(id)
	if devices[idStr] then
		obj = devices[idStr]
	else
		obj = setmetatable({id = id, rxQueues = {}, txQueues = {}}, dev)
		devices[idStr] = obj
	end
	drivers.initDriver(obj)
	return obj
end

function dev:store()
	local idStr = tostring(self.id)
	devices[idStr] = self
end

function dev:getTxQueue(id)
	local tbl = self.txQueues
	if tbl[id] then
		return tbl[id]
	end
	local info = self:getInfo()
	if id >= info.nb_tx_queues then
		log:fatal("device is configured with tx queues 0 to %d, tried to get queue number %d", info.nb_tx_queues - 1, id)
	end
	tbl[id] = setmetatable({id = self.id, qid = id, dev = self}, txQueue)
	return tbl[id]
end

function dev:getRxQueue(id)
	local tbl = self.rxQueues
	if tbl[id] then
		return tbl[id]
	end
	local info = self:getInfo()
	if id >= info.nb_rx_queues then
		log:fatal("device is configured with rx queues 0 to %d, tried to get rx queue number %d", info.nb_rx_queues - 1, id)
	end
	tbl[id] = setmetatable({id = self.id, qid = id, dev = self}, rxQueue)
	return tbl[id]
end

local warningShown = {} -- per-core
function dev:checkSocket()
	if LIBMOON_TASK_NAME ~= "master" and not LIBMOON_IGNORE_BAD_NUMA_MAPPING then
		-- check the NUMA association if we are running in a worker thread
		-- (it's okay to do the initial config from the wrong socket, but sending packets from it is a bad idea)
		local devSocket = self:getSocket()
		local core, threadSocket = libmoon.getCore()
		if devSocket ~= threadSocket then
			if not warningShown[self.id] then
				warningShown[self.id] = true
				log:warn("You are trying to use %s (attached to CPU socket %d) from a thread on core %d on socket %d!",
					self, devSocket, core, threadSocket)
				log:warn("This can significantly impact the performance or even not work at all")
				log:warn("You can change the used CPU cores in dpdk-conf.lua or by using dpdk.startTaskOnCore(core, ...)")
			end
			return false
		end
	end
	return true
end


--- Waits until all given devices are initialized by calling wait() on them.
function mod.waitForLinks(...)
	log:info("Waiting for devices to come up...")
	local ports
	if select("#", ...) == 0 then
		ports = {}
		devices:forEach(function(key, dev)
			if dev.initialized then
				ports[#ports + 1] = dev
			end
		end)
	else
		ports = { ... }
	end
	local portsUniq = {}
	for i, port in ipairs(ports) do
		portsUniq[port.id] = port
	end
	ports = {}
	local maxWait = 9
	for i, v in pairs(portsUniq) do
		ports[#ports + 1] = v
		maxWait = math.max(maxWait, v.linkWaitTime or 0)
	end
	local waitTimer = timer:new(maxWait)
	local portsUp = 0
	while #ports > 0 and waitTimer:running() do
		for i = #ports, 1, -1 do
			local port = ports[i]
			if port:getLinkStatus().status then
				portsUp = portsUp + 1
				table.remove(ports, i)
				port:wait(0) -- prints message immediately
			end
		end
		libmoon.sleepMillisIdle(100)
	end
	for i, port in ipairs(ports) do -- ports that did not come up
		port:wait(0)
	end
	log:info(green(portsUp == 1 and "%d device is up." or "%d devices are up.", portsUp))
	return portsUp
end


--- Wait until the device is fully initialized and up to maxWait seconds to establish a link.
--- Logs the current link state.
-- @param maxWait maximum number of seconds to wait for the link, default = 9
function dev:wait(maxWait)
	maxWait = maxWait or 9
	local link
	repeat
		link = self:getLinkStatus()
		if maxWait > 0 then
			libmoon.sleepMillisIdle(100)
			maxWait = maxWait - 0.1
		else
			break
		end
	until link.status
	self.speed = link.speed
	local out = string.format("Device %d (%s) is %s: %s%s MBit/s", self.id, self:getMacString(), link.status and "up" or "DOWN", link.duplex and "full-duplex " or "half-duplex ", link.speed)
	if link.status then
		log:info(out)
	else
		log:error(out)
	end
	return link.status
end


function dev:getLinkStatus()
	local link = ffi.new("struct rte_eth_link")
	dpdkc.rte_eth_link_get_nowait(self.id, link)
	return {status = link.link_status == 1, autoneg = link.link_autoneg == 1, duplex = link.link_duplex == 1, speed = link.link_speed}
end

function dev:getMacString()
	local buf = ffi.new("char[20]")
	dpdkc.dpdk_get_mac_addr(self.id, buf)
	return ffi.string(buf)
end

function dev:getMac(number)
	return parseMacAddress(self:getMacString(), number)
end

function dev:getFirmware()
	local buf = ffi.new("char[1024]")
	local rc = dpdkc.rte_eth_dev_fw_version_get(self.id, buf, 1024);
	if rc ~= 0 then
		log:warn("Failed to get firmware version: %d", rc)
		return nil
	else
		return ffi.string(buf)
	end
end

function dev:setPromisc(enable)
	if enable then
		dpdkc.rte_eth_promiscuous_enable(self.id)
	else
		dpdkc.rte_eth_promiscuous_disable(self.id)
	end
end

function dev:addMac(mac)
	local rc = dpdkc.rte_eth_dev_mac_addr_add(self.id, parseMacAddress(mac), 0)
	if rc ~= 0 then
		log:fatal("could not add mac: %d", rc)
	end
end

function dev:removeMac(mac)
	local rc = dpdkc.rte_eth_dev_mac_addr_remove(self.id, parseMacAddress(mac))
	if rc ~= 0 then
		log:fatal("could not remove mac: %d", rc)
	end
end

function dev:getInfo()
	local info = ffi.new("struct rte_eth_dev_info")
	dpdkc.rte_eth_dev_info_get(self.id, info)
	return info
end

function dev:getPciId()
	return dpdkc.dpdk_get_pci_id(self.id)
end

function dev:getSocket()
	return dpdkc.dpdk_get_socket(self.id)
end

function dev:getName()
	return pciIds.getName(self:getPciId())
end

function dev:getDriverName()
	return ffi.string(self:getInfo().driver_name)
end


-- some operations are unsupported unless we have device-specific magic

function dev:unsupported(operation, level)
	if not self.unsupportedWarningsShown or not self.unsupportedWarningsShown[operation] then
		self.unsupportedWarningsShown = self.unsupportedWarningsShown or {}
		self.unsupportedWarningsShown[operation] = true
		log[level or "warn"](log, "%s is not supported by the hardware or driver", tostring(operation))
	end
end

--- Set a device-wide hardware rate limiter.
function dev:setRate()
	self:unsupported("global rate limiting")
end

--- Enable timestamping of received PTP packets.
--- @param queue rx queue to use (device-wide for most NICs)
--- @param udpPort udp port to use for PTP, default = 319. Some NICs do not support other ports.
function dev:enableRxTimestamps(queue, udpPort)
	self:unsupported("rx timestamping", "fatal")
end

--- Enable timestamping all received ports, timestamp is stored in a device-specific way in the rx buffer.
--- @param queue rx queue to use .
function dev:enableRxTimestampsAllPackets(queue)
	self:unsupported("timestamping all rx packets", "fatal")
end

--- Enable timestamps of transmitted packets, often limited to PTP.
--- @param queue tx queue to use
function dev:enableTxTimestamps(queue)
	self:unsupported("tx timestamping", "fatal")
end

function dev:clearTimestamps()
	if self:hasRxTimestamp() then
		self:getRxTimestamp(nil, 10)
	end
end

function dev:getTxTimestamp(queue, wait)
	local ts = ffi.new("struct timespec")
	return waitForFunc(wait, function()
		local res = dpdkc.rte_eth_timesync_read_tx_timestamp(self.id, ts)
		if res == 0 then
			return tonumber(ts.tv_sec) * 10^9 + tonumber(ts.tv_nsec)
		end
	end)
end

function dev:getRxTimestamp(queue, wait, timesync)
	wait = wait or 500
	local ts = ffi.new("struct timespec")
	return waitForFunc(wait, function()
		local res = dpdkc.rte_eth_timesync_read_rx_timestamp(self.id, ts, timesync or 0)
		if res == 0 then
			return tonumber(ts.tv_sec) * 10^9 + tonumber(ts.tv_nsec)
		end
	end)
end

--- Checks whether a RX timestamp is available on the device.
function dev:hasRxTimestamp()
	self:unsupported("rx timestamping")
end

--- Reads the clock of the device
function dev:readTime()
	local ts = ffi.new("struct timespec")
	local res = dpdkc.rte_eth_timesync_read_time(self.id, ts)
	checkDpdkError(res, "reading device time")
	return tonumber(ts.tv_sec) * 10^9 + tonumber(ts.tv_nsec)
end

function dev:filterL2Timestamps(queue)
	local qid = type(queue) == "number" and queue or queue.qid
	if qid == 0 then
		return
	end
	self:l2Filter(eth.TYPE_PTP, queue)
end

--- @deprecated
function dev:filterTimestamps(queue)
	log:warn("device:filterTimestamps(q) is deprecated and will be removed. Use queue:filterUdpTimestamps() instead. Or use the timestamper class which handles this for you.")
	queue:filterUdpTimestamps()
end

--- Resets DPDKs internal tracking of device cycle counters.
function dev:resetTimeCounters()
	self:unsupported("Time counter tracking")
end

function dev:clearRxStats()
	return
end

function dev:stop()
	self.initialized = false
	self:store()
	dpdkc.rte_eth_dev_stop(self.id)
end

--- Enable tx timestamps.
--- @see dev.enableTxTimestamps()
function txQueue:enableTimestamps()
	self.dev:enableTxTimestamps(self)
end

--- Enable rx timestamps.
--- @see dev.enableRxTimestamps()
function rxQueue:enableTimestamps(udpPort)
	self.dev:enableRxTimestamps(self, udpPort)
end

--- Enable all rx timestamps.
--- @see dev.enableRxTimestampsAllPackets()
function rxQueue:enableTimestampsAllPackets()
	self.dev:enableRxTimestampsAllPackets(self)
end

--- Read a TX timestamp from the device.
--- Timestamps are usually device-wide.
--- @param wait timeout in microseconds
function txQueue:getTimestamp(wait)
	return self.dev:getTxTimestamp(self, wait)
end

--- Read a RX timestamp from the device.
--- Timestamps are usually device-wide.
--- @param wait timeout in microseconds
--- @param timesync timesync ID for NICs using IDs (i40e).
function rxQueue:getTimestamp(wait, timesync)
	return self.dev:getRxTimestamp(self, wait, timesync)
end

--- Configure a flex byte filter to send UDP timestamp packets to this port.
--- This filter matches on the PTP identifier and version bytes in the payload.
--- Only works if the flex byte settings for fdir are correct (default settings).
--- You can also use a regular 5 tuple filter on the UDP port if this is sufficient for your usecase.
--- Caution: broken on i40e, see i40e-driver docs and timestamper for a work-around.
function rxQueue:filterUdpTimestamps()
	return self.dev:filterUdpTimestamps(self)
end

--- Configure an EthType filter to match PTP packets.
function rxQueue:filterL2Timestamps()
	return self.dev:filterL2Timestamps(self)
end

function mod.getDevices()
	local result = {}
	for i = 0, dpdkc.rte_eth_dev_count() - 1 do
		local dev = mod.get(i)
		result[#result + 1] = { id = i, mac = dev:getMacString(i), name = dev:getName(i) }
	end
	return result
end




ffi.cdef[[

struct rte_eth_xstat {
        uint64_t id;
        uint64_t value;
};


struct rte_eth_xstat_name {
	char name[64];
};
   
int rte_eth_xstats_get_names(uint8_t port_id, struct rte_eth_xstat_name* names, uint32_t size);
int rte_eth_xstats_get(uint8_t port_id, struct rte_eth_xstat * xstats, unsigned int n);
int rte_eth_xstats_get_id_by_name(uint8_t port_id, const char * xstat_name, uint64_t * id);
int rte_eth_xstats_get_by_id(uint8_t port_id, const uint64_t * ids, uint64_t * values, unsigned int n);

]]

local ethStatsType

local function buildEthStatsStruct(n)
	return ffi.typeof(([[
	struct {
		uint64_t ipackets;  
		uint64_t opackets;  
		uint64_t ibytes;    
		uint64_t obytes;    
		uint64_t imissed;
		uint64_t ierrors;   
		uint64_t oerrors;   
		uint64_t rx_nombuf; 
		uint64_t q_ipackets[%d];
		uint64_t q_opackets[%d];
		uint64_t q_ibytes[%d];
		uint64_t q_obytes[%d];
		uint64_t q_errors[%d];
	}
	]]):format(n, n, n, n, n))
end

--- Get ethernet statistics.
--- Warning: the exact meaning of the results may vary between NICs, especially when packets are dropped due to full rx queues.
--- Also, they may sometimes be clear-on-read and sometimes running totals; stats are just wildly inconsistent in DPDK.
--- In case of clear-on-read counters, there will be interactions between this function and get[Rx|Tx]Stats
--- Counting packets at the application-level might be a good idea if you want to support different NICs.
function dev:getStats()
	if not ethStatsType then
		ethStatsType = buildEthStatsStruct(dpdkc.dpdk_get_rte_queue_stat_cntrs_num())
	end
	local stats = ethStatsType()
	dpdkc.rte_eth_stats_get(self.id, stats)
	return stats
end

do
	local stats
	--- Get the total number of packets and bytes transmitted successfully.
	--- This does not include packets that were queued but not yet sent by the NIC.
	--- This counter should include the CRC checksum, but drivers are inconsistent here.
	--- libmoon tries to correct this inconsistency, currently tested with ixgbe, i40e and igb NICs.
	--- @return packets, bytes
	function dev:getTxStats()
		if not ethStatsType then
			ethStatsType = buildEthStatsStruct(dpdkc.dpdk_get_rte_queue_stat_cntrs_num())
		end
		if not stats then
			stats = ethStatsType()
		end
		dpdkc.rte_eth_stats_get(self.id, stats)
		-- in case you are wondering: the precision of a double starts the become a minor problem after 4.17 days at 100 gbit/s
		-- but we ignore that here as packets are >= 64 bytes
		local pkts = tonumber(stats.opackets)
		local bytes = tonumber(stats.obytes)
		return pkts, bytes + (self.txStatsIgnoreCrc and pkts * 4 or 0)
	end
	
	--- Get the number packets and bytes received at the physical layer regardless whether they were received by the driver.
	--- The drivers may be inconsistent regarding counting of packets dropped due to insufficient buffer space...
	--- libmoon has custom implementations for this function for ixgbe and i40e that work correctly.
	--- Use dev:getStats() to get the full statistics exposed by DPDK.
	--- @return packets, bytes
	function dev:getRxStats()
		if not ethStatsType then
			ethStatsType = buildEthStatsStruct(dpdkc.dpdk_get_rte_queue_stat_cntrs_num())
		end
		if not stats then
			stats = ethStatsType()
		end
		dpdkc.rte_eth_stats_get(self.id, stats)
		-- the meaning of the packet stats is completely inconsistent between drivers
		-- for example, i40e reports some random value that corresponds to about 25% of the number of packets received...
		-- the bytes are mostly fine, though
		-- there are custom implementations for i40e and ixgbe
		local pkts = tonumber(stats.ipackets + stats.imissed + stats.rx_nombuf)
		local bytes = tonumber(stats.ibytes)
		return pkts, bytes + (self.rxStatsIgnoreCrc and pkts * 4 or 0)
	end
end


--- Set the tx rate of a queue in Mbit/s.
--- This sets the payload rate, not to the actual wire rate, i.e. preamble, SFD, and IFG are ignored.
function txQueue:setRate(rate)
	local rc = dpdkc.rte_eth_set_queue_rate_limit(self.id, self.qid, rate)
	if rc == -E.NOTSUP then
		-- fails if doing this from multiple threads
		-- but that's okay since this is just a crude work-around and the app should be updated for the NIC
		local dev = self.dev
		dev.totalRate = dev.totalRate or 0
		dev.totalRate = dev.totalRate + rate
		log:warn("Per-queue rate limit is not supported on this device, setting per-device rate limit to %d Mbit/s instead (note: this may fail as well if the NIC doesn't support any rate limiting).", dev.totalRate)
		dev:setRate(dev.totalRate)
	elseif rc ~= 0 then
		log:warn("Failed to set rate limiter on queue %s: %s", self, strError(rc))
	end
end

function txQueue:setRateMpps(rate, pktSize)
	pktSize = pktSize or 60
	self:setRate(rate * (pktSize + 4) * 8)
end


function txQueue:send(bufs)
	self.used = true
	dpdkc.dpdk_send_all_packets(self.id, self.qid, bufs.array, bufs.size)
	return bufs.size
end

function txQueue:sendSingle(buf)
	self.used = true
	dpdkc.dpdk_send_single_packet(self.id, self.qid, buf)
	return 1
end

-- Try to transmit a single packet.
-- Returns 1 if sent, 0 if not
function txQueue:trySendSingle(buf)
	self.used = true
	return dpdkc.dpdk_try_send_single_packet(self.id, self.qid, buf)
end

function txQueue:sendN(bufs, n)
	self.used = true
	dpdkc.dpdk_send_all_packets(self.id, self.qid, bufs.array, n)
	return n
end

--- Try to transmit buffers on a queue.
--- Returns the number of packets actually sent out.
--- @param startIndex 0-based offset in the buffer, default = 0 (use last return value here)
--- @param numPkts max number of packets, defaults to bufs.size - startIndex
function txQueue:trySend(bufs, startIndex, numPkts)
	startIndex = startIndex or 0
	numPkts = numPkts or bufs.size - startIndex
	return dpdkc.rte_eth_tx_burst_export(self.id, self.qid, bufs.array + startIndex, numPkts)
end

function txQueue:start()
	assert(dpdkc.rte_eth_dev_tx_queue_start(self.id, self.qid) == 0)
end

function txQueue:stop()
	assert(dpdkc.rte_eth_dev_tx_queue_stop(self.id, self.qid) == 0)
end

--- Restarts all tx queues that were actively used by this task.
--- 'Actively used' means that :send() was called from the current task.
function mod.reclaimTxBuffers()
	local old = LIBMOON_IGNORE_BAD_NUMA_MAPPING
	LIBMOON_IGNORE_BAD_NUMA_MAPPING = true
	devices:forEach(function(_, dev)
		for _, queue in pairs(dev.txQueues) do
			if queue.used then
				queue:stop()
				queue:start()
			end
		end
	end)
	LIBMOON_IGNORE_BAD_NUMA_MAPPING = old
end

-- cleanup devices if necessary
function mod.cleanupDevices()
	local old = LIBMOON_IGNORE_BAD_NUMA_MAPPING
	LIBMOON_IGNORE_BAD_NUMA_MAPPING = true
	devices:forEach(function(_, dev)
		-- only call stop if the driver requires it
		-- otherwise it will slow down the program termination
		-- as a few drivers/NICs require some time to stop the devs (e.g. ixgbe/x540 takes about a second)
		if dev.initialized and dev.driverInfo.stopOnShutdown then
			dev:stop()
		end
	end)
	LIBMOON_IGNORE_BAD_NUMA_MAPPING = old
end

--- Receive packets from a rx queue.
--- Returns as soon as at least one packet is available.
function rxQueue:recv(bufArray, numpkts)
	numpkts = numpkts or bufArray.size
	while libmoon.running() do
		local rx = dpdkc.rte_eth_rx_burst_export(self.id, self.qid, bufArray.array, math.min(bufArray.size, numpkts))
		if rx > 0 then
			return rx
		end
	end
	return 0
end

--- Receive packets from a rx queue and save timestamps in the udata64 field.
--- Returns as soon as at least one packet is available.
function rxQueue:recvWithTimestamps(bufArray, numpkts)
	numpkts = numpkts or bufArray.size
	return dpdkc.dpdk_receive_with_timestamps_software(self.id, self.qid, bufArray.array, math.min(bufArray.size, numpkts))
end

function rxQueue:getMacAddr(number)
  return self.dev:getMac(number)
end

function txQueue:getMacAddr(number)
  return self.dev:getMac(number)
end

--- Receive packets from a rx queue with a timeout.
function rxQueue:tryRecv(bufArray, maxWait)
	maxWait = maxWait or math.huge
	while maxWait >= 0 do
		local rx = dpdkc.rte_eth_rx_burst_export(self.id, self.qid, bufArray.array, bufArray.size)
		if rx > 0 then
			return rx
		end
		maxWait = maxWait - 1
		-- don't sleep pointlessly
		if maxWait < 0 then
			break
		end
		libmoon.sleepMicros(1)
	end
	return 0
end

--- Receive packets from a rx queue with a timeout.
--- Does not perform a busy wait, this is not suitable for high-throughput applications.
function rxQueue:tryRecvIdle(bufArray, maxWait)
	maxWait = maxWait or math.huge
	while maxWait >= 0 do
		local rx = dpdkc.rte_eth_rx_burst_export(self.id, self.qid, bufArray.array, bufArray.size)
		if rx > 0 then
			return rx
		end
		maxWait = maxWait - 10
		-- don't sleep pointlessly
		if maxWait < 0 then
			break
		end
		libmoon.sleepMicrosIdle(10)
	end
	return 0
end

-- export prototypes to extend them in other modules
mod.__devicePrototype = dev
mod.__txQueuePrototype = txQueue
mod.__rxQueuePrototype = rxQueue

return mod


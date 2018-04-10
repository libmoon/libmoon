--- Captures packets, can dump to a pcap file or decode on standard out.
--- This is essentially an extremely fast version of tcpdump, single-threaded stats are:
---  * > 20 Mpps filtering (depending on filter, tested with port range and IP matching)
---  * > 11 Mpps pcap writing (60 byte packets)
--- 
--- This scales very well to multiple core, we achieved the following with 4 2.2 GHz cores:
---  * 20 Mpps pcap capturing (limited by small packet performance of i40e NIC)
---  * 40 Gbit/s pcap capturing of 128 byte packets to file system cache (mmap)
---  * 1900 MB/s (~15 Gbit/s) sustained write speed to a raid of two NVMe SSDs
---
--- Note that the stats shown at the end will probably not add up when plugging this into live traffic:
--- Some packets are simply lost during NIC reset and startup (the NIC counter is a hardware counter).

local lm     = require "libmoon"
local device = require "device"
local memory = require "memory"
local stats  = require "stats"
local arp    = require "proto.arp"
local eth    = require "proto.ethernet"
local log    = require "log"
local pcap   = require "pcap"
local pf     = require "pf"

function configure(parser)
	parser:argument("dev", "Device to use."):args(1):convert(tonumber)
	parser:option("-a --arp", "Respond to ARP queries on the given IP."):argname("ip")
	parser:option("-f --file", "Write result to a pcap file.")
	parser:option("-s --snap-len", "Truncate packets to this size."):convert(tonumber):target("snapLen")
	parser:option("-t --threads", "Number of threads."):convert(tonumber):default(1)
	parser:option("-o --output", "File to output statistics to")
	parser:argument("filter", "A BPF filter expression."):args("*"):combine()
	local args = parser:parse()
	if args.filter then
		local ok, err = pcall(pf.compile_filter, args.filter)
		if not ok then
			parser:error(err)
		end
	end
	return args
end

function master(args)
	local dev = device.config{port = args.dev, txQueues = args.arp and 2 or 1, rxQueues = args.threads, rssQueues = args.threads}
	device.waitForLinks()
	if args.arp then
		arp.startArpTask{txQueue = dev:getTxQueue(1), ips = args.arp}
		arp.waitForStartup() -- race condition with arp.handlePacket() otherwise
	end
	stats.startStatsTask{rxDevices = {dev}, file = args.output}
	for i = 1, args.threads do
		lm.startTask("dumper", dev:getRxQueue(i - 1), args, i)
	end
	lm.waitForTasks()
end

function dumper(queue, args, threadId)
	local handleArp = args.arp
	-- default: show everything
	local filter = args.filter and pf.compile_filter(args.filter) or function() return true end
	local snapLen = args.snapLen
	local writer
	local captureCtr, filterCtr
	if args.file then
		if args.threads > 1 then
			if args.file:match("%.pcap$") then
				args.file = args.file:gsub("%.pcap$", "")
			end
			args.file = args.file .. "-thread-" .. threadId .. ".pcap"
		else
			if not args.file:match("%.pcap$") then
				args.file = args.file .. ".pcap"
			end
		end
		writer = pcap:newWriter(args.file)
		captureCtr = stats:newPktRxCounter("Capture, thread #" .. threadId)
		filterCtr = stats:newPktRxCounter("Filter reject, thread #" .. threadId)
	end
	local bufs = memory.bufArray()
	while lm.running() do
		local rx = queue:tryRecv(bufs, 100)
		local batchTime = lm.getTime()
		for i = 1, rx do
			local buf = bufs[i]
			if filter(buf:getBytes(), buf:getSize()) then
				if writer then
					writer:writeBuf(batchTime, buf, snapLen)
					captureCtr:countPacket(buf)
				else
					buf:dump()
				end
			elseif filterCtr then
				filterCtr:countPacket(buf)
			end
			if handleArp and buf:getEthernetPacket().eth:getType() == eth.TYPE_ARP then
				-- inject arp packets to the ARP task
				-- this is done this way instead of using filters to also dump ARP packets here
				arp.handlePacket(buf)
			else
				-- do not free packets handlet by the ARP task, this is done by the arp task
				buf:free()
			end
		end
		if writer then
			captureCtr:update()
			filterCtr:update()
		end
	end
	if writer then
		captureCtr:finalize()
		filterCtr:finalize()
		log:info("Flushing buffers, this can take a while...")
		writer:close()
	end
end


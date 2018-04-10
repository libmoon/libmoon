--- Layer 2 reflector, swaps src and dst MACs and echoes the packet
local lm     = require "libmoon"
local memory = require "memory"
local device = require "device"
local stats  = require "stats"
local lacp   = require "proto.lacp"

function configure(parser)
	parser:argument("dev", "Devices to use."):args("+"):convert(tonumber)
	parser:option("-t --threads", "Number of threads per device."):args(1):convert(tonumber):default(1)
	parser:flag("-l --lacp", "Try to setup an LACP channel.")
	parser:option("-o --output", "File to output statistics to")
	return parser:parse()
end

function master(args)
	local lacpQueues = {}
	for i, dev in ipairs(args.dev) do
		local dev = device.config{
			port = dev,
			rxQueues = args.threads + (args.lacp and 1 or 0),
			txQueues = args.threads + (args.lacp and 1 or 0),
			rssQueues = args.threads
		}
		-- last queue for lacp
		if args.lacp then
			table.insert(lacpQueues, {rxQueue = dev:getRxQueue(args.threads), txQueue = dev:getTxQueue(args.threads)})
		end
		args.dev[i] = dev
	end
	device.waitForLinks()

	-- setup lacp if requested
	if args.lacp then
		lacp.startLacpTask("bond0", lacpQueues)
		lacp.waitForLink("bond0")
	end

	-- print statistics
	stats.startStatsTask{devices = args.dev, file = args.output}

	for i, dev in ipairs(args.dev) do 
		for i = 1, args.threads do
			lm.startTask("reflector", dev:getRxQueue(i - 1), dev:getTxQueue(i - 1))
		end
	end
	lm.waitForTasks()
end

function reflector(rxQ, txQ)
	local bufs = memory.bufArray()
	while lm.running() do
		local rx = rxQ:tryRecv(bufs, 1000)
		for i = 1, rx do
			-- swap MAC addresses
			local pkt = bufs[i]:getEthernetPacket()
			local tmp = pkt.eth:getDst()
			pkt.eth:setDst(pkt.eth:getSrc())
			pkt.eth:setSrc(tmp)
			local vlan = bufs[i]:getVlan()
			if vlan then
				bufs[i]:setVlan(vlan)
			end
		end
		txQ:sendN(bufs, rx)
	end
end


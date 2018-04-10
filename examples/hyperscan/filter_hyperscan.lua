local lm     = require "libmoon"
local hs     = require "hs"
local ffi    = require "ffi"
local device = require "device"
local memory = require "memory"
local stats  = require "stats"
local pcap   = require "pcap"
local log    = require "log"

function configure(parser)
	parser:description("Demonstrates packet filtering using Hyperscan.")
	parser:argument("rules", "File containing patterns for filtering"):args(1)
	parser:argument("devIn", "Device which receives the packets"):args(1):convert(tonumber)
	parser:argument("devOut", "Device which forwards the packets not matching filters"):args(1):convert(tonumber)
	parser:option("-p --pcapDev", "Device which replays a pcap for testing, connect to devIn"):args(1):convert(tonumber):default(-1)
	parser:option("-f --pcapFile", "pcap file for --pcapDev"):args(1):default("dump.pcap")
	parser:option("-o --output", "File to output statistics to")
	return parser:parse()
end

function master(args)
	local filter = hs:new(args.rules, hs.HS_MODE_BLOCK)
	local devRecv = device.config{port=args.devIn}:getRxQueue(0)
	local devForward = device.config{port=args.devOut}:getTxQueue(0)
	if args.pcapDev ~= -1 then
		args.pcapDev = device.config{port=args.pcapDev}:getTxQueue(0)
	end
	device.waitForLinks()

	if args.pcapDev ~= -1 then
		lm.startTask("playPcap", args.pcapFile, args.pcapDev)
	end
	lm.startTask("filter", devRecv, devForward, filter)
	stats.startStatsTask{rxDevices = {devRecv.dev}, txDevices = {devForward.dev}, file = args.output}
	lm.waitForTasks()
end

-- plays a pcap file
function playPcap(filename, queue)
	log:info("Replaying %s from %s.", filename, queue)
	local mempool = memory:createMemPool()
	local bufs = mempool:bufArray()
	local pcapFile = pcap:newReader(filename)
	while lm.running() do
		local n = pcapFile:read(bufs)
		if n == 0 then
			pcapFile:reset()
		end
		queue:sendN(bufs, n)
	end
end

-- filters incoming packets on queueIn. If filter returns true, the packet will be dropped, otherwise forwarded on queueOut.
function filter(queueIn, queueOut, filter)
	log:info("Filtering packets coming from %s and sending to %s.", queueIn, queueOut)
	local rxBufs = memory.bufArray()
	local txBufs = memory.bufArray()
	local pos = 0 -- counts dropped packets
	local neg = 0 -- counts forwarded packets
	local captureCtr = stats:newPktRxCounter("Capture rate")
	while lm.running() do
		local rx = queueIn:recv(rxBufs)
		local j = 0
		for i = 1, rx do
			local buf = rxBufs[i]
			captureCtr:countPacket(rxBufs[i])
			if filter:filter(rxBufs[i]) then
				--drop
				pos = pos + 1
				rxBufs[i]:free()		
			else
				--write to buf for forwarding
				neg = neg + 1
				j = j + 1
				txBufs[j] = rxBufs[i]
			end
		end
		--forward
		queueOut:sendN(txBufs, j)
		captureCtr:update()
	end
	print("Packets dropped: ", pos)
	print("Packets forwarded: ", neg)
	print("Drop rate: ", pos/(pos+neg))
	captureCtr:finalize()
end


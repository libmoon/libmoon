--- Demonstrates and tests hardware timestamping capabilities

local phobos = require "phobos"
local device = require "device"
local ts     = require "timestamping"
local hist   = require "histogram"
local timer  = require "timer"
local log    = require "log"

local RUN_TIME = 5

function configure(parser)
	parser:description("Demonstrate and test hardware timestamping capabilities.\nThe ideal test setup for this is a cable directly connecting the two test ports.")
	parser:argument("dev", "Devices to use."):args(2):convert(tonumber)
	return parser:parse()
end

function master(args)
	for i, dev in ipairs(args.dev) do
		local dev = device.config{port = dev, txQueues = 1, rxQueues = 2}
		args.dev[i] = dev
	end
	device.waitForLinks()
	local txQueue = args.dev[1]:getTxQueue(0)
	local rxQueue0 = args.dev[2]:getRxQueue(0)
	local rxQueue1 = args.dev[2]:getRxQueue(1)
	--phobos.startTask("timestamper", txQueue, rxQueue0)
	--phobos.startTask("timestamper", txQueue, rxQueue0, 3191)
	--phobos.startTask("timestamper", txQueue, rxQueue1)
	phobos.startTask("timestamper", txQueue, rxQueue1, 319)
	phobos.waitForTasks()
end

function timestamper(txQueue, rxQueue, udp)
	local filter = rxQueue.qid ~= 0
	log:info("Testing timestamping %s %s rx filtering for %d seconds.",
		udp and "UDP packets to port " .. udp or "L2 PTP packets",
		filter and "with" or "without",
		RUN_TIME
	)
	local runtime = timer:new(5)
	local hist = hist:new()
	local timestamper
	if udp then
		timestamper = ts:newUdpTimestamper(txQueue, rxQueue)
	else
		timestamper = ts:newTimestamper(txQueue, rxQueue)
	end
	if filter then
		if udp then
			rxQueue:filterUdpTimestamps()
		else
			rxQueue:filterL2Timestamps()
		end
	end
	while phobos.running() and runtime:running() do
		local lat = timestamper:measureLatency(function(buf)
			if udp then
				buf:getUdpPacket().udp:setDstPort(udp)
			end
		end)
		hist:update(lat)
	end
	hist:print()
	print()
end


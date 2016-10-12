--- Demonstrates and tests hardware timestamping capabilities

local lm     = require "libmoon"
local device = require "device"
local memory = require "memory"
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
	args.dev[1] = device.config{port = args.dev[1], txQueues = 2}
	args.dev[2] = device.config{port = args.dev[2], rxQueues = 2}
	device.waitForLinks()
	local txQueue0 = args.dev[1]:getTxQueue(0)
	local txQueue1 = args.dev[1]:getTxQueue(1)
	local rxQueue0 = args.dev[2]:getRxQueue(0)
	local rxQueue1 = args.dev[2]:getRxQueue(1)
	lm.startTask("timestamper", txQueue0, rxQueue0):wait()
	lm.startTask("timestamper", txQueue0, rxQueue1):wait()
	lm.startTask("timestamper", txQueue0, rxQueue0, nil, nil, true):wait()
	lm.startTask("timestamper", txQueue0, rxQueue0, 319):wait()
	lm.startTask("timestamper", txQueue0, rxQueue0, 1234):wait()
	lm.startTask("timestamper", txQueue0, rxQueue0, 319, nil, true):wait()
	lm.startTask("timestamper", txQueue0, rxQueue1, 319):wait()
	lm.startTask("timestamper", txQueue0, rxQueue1, 319, true):wait()
	lm.startTask("timestamper", txQueue0, rxQueue1, 319)
	lm.startTask("flooder", txQueue1, 319)
	lm.waitForTasks()
end


function timestamper(txQueue, rxQueue, udp, randomSrc, vlan)
	local filter = rxQueue.qid ~= 0
	log:info("Testing timestamping %s %s rx filtering for %d seconds.",
		udp and "UDP packets to port " .. udp or "L2 PTP packets",
		filter and "with" or "without",
		RUN_TIME
	)
	if randomSrc then
		log:info("Using multiple flows, this can be slower on some NICs.")
	end
	if vlan then
		log:info("Adding VLAN tag, this is not supported on some NICs.")
	end
	local runtime = timer:new(RUN_TIME)
	local hist = hist:new()
	local timestamper
	if udp then
		timestamper = ts:newUdpTimestamper(txQueue, rxQueue)
	else
		timestamper = ts:newTimestamper(txQueue, rxQueue)
	end
	while lm.running() and runtime:running() do
		local lat = timestamper:measureLatency(function(buf)
			if udp then
				if randomSrc then
					buf:getUdpPacket().udp:setSrcPort(math.random(1, 1000))
				end
				buf:getUdpPacket().udp:setDstPort(udp)
			end
			if vlan then
				buf:setVlan(1234)
			end
		end)
		hist:update(lat)
	end
	hist:print()
	if hist.numSamples == 0 then
		log:error("Received no packets.")
	end
	print()
end

function flooder(queue, port)
	log:info("Flooding link with UDP packets with the same flow 5-tuple.")
	log:info("This tests whether the filter matches on payload.")
	local mempool = memory.createMemPool(function(buf)
		local pkt = buf:getUdpPtpPacket()
		pkt:fill{
			ethSrc = queue,
		}
		-- the filter should not match this
		pkt.ptp:setVersion(0xFF)
		pkt.udp:setDstPort(port)
	end)
	local bufs = mempool:bufArray()
	local runtime = timer:new(RUN_TIME + 0.1)
	while lm.running() and runtime:running() do
		bufs:alloc(60)
		queue:send(bufs)
	end
end

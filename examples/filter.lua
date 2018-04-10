local lm     = require "libmoon"
local device = require "device"
local stats  = require "stats"
local memory = require "memory"
local log    = require "log"
local pf     = require "pf"
local eth    = require "proto.ethernet"
local ip4    = require "proto.ip4"

function configure(parser)
	parser:description("Demonstrates filtering capabilities.")
	parser:argument("rxDev", "Device to receive from."):args(1):convert(tonumber)
	parser:argument("txDev", "Device to send to."):args(1):convert(tonumber)
	parser:option("--threads -t", "Number of threads"):args(1):convert(tonumber):default(1)
	parser:option("-o --output", "File to output statistics to")
	parser:mutex(
		parser:option("--udp-port -u", "A UDP port to filter."):args(1):convert(tonumber):target("udpPort"),
		parser:option("--pcap -p", "A pcap filter expression."):args("*"):combine()
	)
	return parser:parse()
end

function master(args)
	local rxDev = device.config{ port = args.rxDev, rxQueues = args.threads }
	local txDev = device.config{ port = args.txDev, txQueues = args.threads }
	device.waitForLinks()
	for i = 1, args.threads do
		lm.startTask("filter", rxDev:getRxQueue(i - 1), txDev:getTxQueue(i - 1), args)
	end
	stats.startStatsTask{rxDevices = {rxDev}, txDevices = {txDev}, file = args.output}
	lm.waitForTasks()
end


function filter(rxQueue, txQueue, args)
	log:info("Filtering packets coming from %s and sending to %s.", rxQueue, txQueue)
	local filter
	if args.pcap then
		local compiled = pf.compile_filter(args.pcap)
		filter = function(buf)
			return compiled(buf:getBytes(), buf:getSize())
		end
	elseif args.udpPort then
		local port = args.udpPort
		filter = function(buf)
			local pkt = buf:getUdpPacket()
			if pkt.eth.type == bswap16(eth.TYPE_IP) and pkt.ip4.protocol == ip4.PROTO_UDP then
				return pkt.udp:getDstPort() == port
			end
		end
	else
		error("filter parameter missing, see --help")
	end
	local rxBufs = memory.bufArray()
	local txBufs = memory.bufArray()
	while lm.running() do
		local rx = rxQueue:recv(rxBufs)
		local j = 0
		for i = 1, rx do
			local buf = rxBufs[i]
			if filter(rxBufs[i]) then
				rxBufs[i]:free()		
			else
				j = j + 1
				txBufs[j] = rxBufs[i]
			end
		end
		txQueue:sendN(txBufs, j)
	end
end


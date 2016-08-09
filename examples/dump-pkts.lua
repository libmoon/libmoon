--- Decodes and prints packets to standardout, similar to tcpdump.

local phobos = require "phobos"
local device = require "device"
local memory = require "memory"
local arp    = require "proto.arp"
local eth    = require "proto.ethernet"
local argparse = require "argparse"

function master(...)
	local parser = argparse()
	parser:argument("dev", "Device to use"):args(1):convert(tonumber)
	parser:option("-a --arp", "Respond to ARP queries on the given IP."):argname("ip")
	local args = parser:parse(...)
	local dev = device.config{port = args.dev, txQueues = args.arp and 2 or 1}
	device.waitForLinks()
	if args.arp then
		arp.startArpTask{txQueue = dev:getTxQueue(1), ips = args.arp}
		arp.waitForStartup() -- race condition with arp.handlePacket() otherwise
	end
	phobos.startTask("dumper", dev:getRxQueue(0), args.arp)
	phobos.waitForTasks()
end

function dumper(queue, handleArp)
	local bufs = memory.bufArray()
	while phobos.running() do
		local rx = queue:tryRecv(bufs, 100)
		for i = 1, rx do
			local buf = bufs[i]
			buf:dump()
			if handleArp and buf:getEthernetPacket().eth:getType() == eth.TYPE_ARP then
				-- inject arp packets to the ARP task
				-- this is done this way instead of using filters to also dump ARP packets here
				arp.handlePacket(buf)
			else
				-- do not free packets handlet by the ARP task, this is done by the arp task
				buf:free()
			end
		end
	end
end


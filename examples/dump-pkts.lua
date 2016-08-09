--- Decodes and prints packets to standardout, similar to tcpdump.

local phobos = require "phobos"
local device = require "device"
local memory = require "memory"
local arp    = require "proto.arp"
local eth    = require "proto.ethernet"

function master(rxPort)
	local dev = device.config{port = rxPort, txQueues = 2}
	device.waitForLinks()
	arp.startArpTask{txQueue = dev:getTxQueue(1), ips = "172.17.0.20"}
	arp.waitForStartup() -- race condition with arp.handlePacket() otherwise
	phobos.startTask("dumper", dev:getRxQueue(0))
	phobos.waitForTasks()
end

function dumper(queue)
	local bufs = memory.bufArray()
	while phobos.running() do
		local rx = queue:tryRecv(bufs, 100)
		for i = 1, rx do
			local buf = bufs[i]
			buf:dump()
			if buf:getEthernetPacket().eth:getType() == eth.TYPE_ARP then
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


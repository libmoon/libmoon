--- Decodes and prints packets to standardout, similar to tcpdump.

local phobos = require "phobos"
local device = require "device"
local memory = require "memory"
local arp    = require "proto.arp"

function master(rxPort)
	local dev = device.config{port = rxPort}
	device.waitForLinks()
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
		end
		bufs:free(rx)
	end
end


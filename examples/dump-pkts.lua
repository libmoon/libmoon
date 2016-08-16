--- Decodes and prints packets to standardout, similar to tcpdump.
--- The filter can easily handle > 10 Mpps, printing is obviously slower ;)

local phobos = require "phobos"
local device = require "device"
local memory = require "memory"
local arp    = require "proto.arp"
local eth    = require "proto.ethernet"
local log    = require "log"
local pf     = require "pf"

function configure(parser)
	parser:argument("dev", "Device to use."):args(1):convert(tonumber)
	parser:option("-a --arp", "Respond to ARP queries on the given IP."):argname("ip")
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
	local dev = device.config{port = args.dev, txQueues = args.arp and 2 or 1}
	device.waitForLinks()
	if args.arp then
		arp.startArpTask{txQueue = dev:getTxQueue(1), ips = args.arp}
		arp.waitForStartup() -- race condition with arp.handlePacket() otherwise
	end
	phobos.startTask("dumper", dev:getRxQueue(0), args.arp, args.filter)
	phobos.waitForTasks()
end

function dumper(queue, handleArp, filter)
	-- default: show everything
	filter = filter and pf.compile_filter(filter) or function() return true end
	local bufs = memory.bufArray()
	while phobos.running() do
		local rx = queue:tryRecv(bufs, 100)
		for i = 1, rx do
			local buf = bufs[i]
			if filter(buf:getBytes(), buf:getSize()) then
				buf:dump()
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
	end
end


--- Basically the same as reflector.lua
--- Just to show how to integrate C code.
local phobos = require "phobos"
local memory = require "memory"
local device = require "device"
local stats  = require "stats"
local ffi    = require "ffi"

-- TODO: handle paths better
local clib = ffi.load("./examples/c-integration/libswap-macs.so")

-- declare function prototypes here to make them callable
ffi.cdef[[
	void swap_macs(struct rte_mbuf* mbufs[], uint32_t num_bufs);
]]

function configure(parser)
	parser:argument("dev", "Devices to use."):args("+"):convert(tonumber)
	parser:option("-t --threads", "Number of threads per device."):args(1):convert(tonumber):default(1)
end

function master(args)
	for i, dev in ipairs(args.dev) do
		args.dev[i] = device.config{
			port = dev,
			rxQueues = args.threads,
			txQueues = args.threads,
			rssQueues = args.threads
		}
	end
	device.waitForLinks()

	-- print statistics
	stats.startStatsTask{devices = args.dev}

	for i, dev in ipairs(args.dev) do 
		for i = 0, args.threads - 1 do
			phobos.startTask("reflector", dev:getRxQueue(i), dev:getTxQueue(i))
		end
	end
	phobos.waitForTasks()
end

function reflector(rxQ, txQ)
	local bufs = memory.bufArray()
	while phobos.running() do
		local rx = rxQ:tryRecv(bufs, 1000)
		-- you can just call C functions declared above
		-- bufs.array is the struct rte_mbuf* array used internally by a phobos bufArray
		clib.swap_macs(bufs.array, rx)
		txQ:sendN(bufs, rx)
	end
end


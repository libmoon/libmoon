--- Basically the same as reflector.lua
--- Just to show how to integrate C code.
local lm     = require "libmoon"
local memory = require "memory"
local device = require "device"
local stats  = require "stats"
local ffi    = require "ffi"

-- search for libswap-macs.so in the usual system paths and in Lua's package.path
-- this includes the directory in which the executed lm script is located
-- you can also specify subdirectories to search, e.g., ffi.load("build/foo") will look
-- for build/libfoo.so in all relevant directories
local clib = ffi.load("swap-macs")

-- declare function prototypes here to make them callable
-- for C++: declare the function as extern "C" in the C++ file and call like a C function
ffi.cdef[[
	void swap_macs(struct rte_mbuf* mbufs[], uint32_t num_bufs);
]]

function configure(parser)
	parser:argument("dev", "Devices to use."):args("+"):convert(tonumber)
	parser:option("-t --threads", "Number of threads per device."):args(1):convert(tonumber):default(1)
	parser:option("-o --output", "File to output statistics to")
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
	stats.startStatsTask{devices = args.dev, file = args.output}

	for i, dev in ipairs(args.dev) do 
		for i = 0, args.threads - 1 do
			lm.startTask("reflector", dev:getRxQueue(i), dev:getTxQueue(i))
		end
	end
	lm.waitForTasks()
end

function reflector(rxQ, txQ)
	local bufs = memory.bufArray()
	while lm.running() do
		local rx = rxQ:tryRecv(bufs, 1000)
		-- you can just call C functions declared above
		-- bufs.array is the struct rte_mbuf* array used internally by a lm bufArray
		clib.swap_macs(bufs.array, rx)
		txQ:sendN(bufs, rx)
	end
end


local hs = require "hs"
local ffi = require "ffi"

local device = require "device"
local memory = require "memory"
local stats  = require "stats"
local pcap = require "pcap"
local lm = require "libmoon"

-- the configure function is called on startup with a pre-initialized command line parser
function configure(parser)
	parser:description("Demonstrates a packet filtering using Hyperscan.")
	parser:argument("rules", "Filename of the patterns for filtering"):args(1)
	parser:argument("devIn", "Device which receives the packets"):args(1):convert(tonumber)
	parser:argument("devOut", "Device which forwards the unfiltered packets"):args(1):convert(tonumber)
	parser:option("-p --devPCAP", "Optionally a device which plays a PCAP for testing. This should be connected to devIn."):args(1):convert(tonumber):default(-1)
	parser:option("-f --pcapfile", "Optionally the file name of the PCAP which should be played."):args(1):default("dump.pcap")
	return parser:parse()
end

function master(args)
	local filter = hs:new(args.rules, hs.HS_MODE_BLOCK)
	
	local devRecv = device.config{port=args.devIn}:getRxQueue(0)
	local devForward = device.config{port=args.devOut}:getTxQueue(0)
	
	if args.devPCAP ~= -1 then
		lm.startTask("playPCAP", args.pcapfile, device.config{port=args.devPCAP}:getTxQueue(0))
	end

	device.waitForLinks()

	lm.startTask("filter", devRecv, devForward, filter)
	
	
	lm.waitForTasks()

end

-- plays an pcap file
function playPCAP(filename, queue)
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

--filters incoming packets on queueIn. If filter returns true, the packet will be dropped, otherwise forwarded on queueOut.
function filter(queueIn, queueOut, filter)
	local rxBufs = memory.bufArray()
	local txBufs = memory.bufArray()
	local pos = 0 --counts dropped packets
	local neg = 0 --counts forwarded packets
	local captureCtr = stats:newPktRxCounter("Filter handles")
	while lm.running() do
		local rx = queueIn:recv(rxBufs)
		local j = 0

		for i=1, rx do
			local buf = rxBufs[i]
			captureCtr:countPacket(rxBufs[i])
		
			if filter:filter(rxBufs[i]) then
				--drop
				pos = pos+1		
				rxBufs[i]:free()		
			else
				--write to buf for forwarding
				neg = neg+1
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


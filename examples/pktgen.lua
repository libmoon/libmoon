--- A simple UDP packet generator
local phobos = require "phobos"
local device = require "device"
local stats  = require "stats"
local log    = require "log"
local memory = require "memory"

-- set addresses here
local DST_MAC       = nil -- resolved via ARP on GW_IP or DST_IP, can be overriden with a string here
local PKT_LEN       = 60
local SRC_IP        = "10.0.0.10"
local DST_IP        = "10.1.0.10"
local SRC_PORT_BASE = 1234 -- actual port will be SRC_PORT_BASE * random(NUM_FLOWS)
local DST_PORT      = 1234
local NUM_FLOWS     = 1000
-- answer ARP requests for this IP on the rx port
local RX_IP		= DST_IP
-- used to resolve DST_MAC
local GW_IP		= DST_IP
-- used as source IP to resolve GW_IP to DST_MAC
local ARP_IP	= SRC_IP

function master(port1, port2)
	log:info("Check out MoonGen (built on Phobos) if you are looking for a fully featured packet generator")
	log:info("https://github.com/emmericp/MoonGen")
	local dev1 = device.config{ port = port1 }
	local dev2 = device.config{ port = port2 }
	device.waitForLinks()
	phobos.startTask("txSlave", dev1:getTxQueue(0))
	phobos.startTask("txSlave", dev2:getTxQueue(0))
	phobos.waitForTasks()
end

function txSlave(queue)
	queue:setRate(1500)
	-- memory pool with default values for all packets, this is our archetype
	local mempool = memory.createMemPool(function(buf)
		buf:getUdpPacket():fill{
			-- fields not explicitly set here are initialized to reasonable defaults
			ethSrc = queue, -- MAC of the tx device
			ethDst = DST_MAC,
			ip4Src = SRC_IP,
			ip4Dst = DST_IP,
			udpSrc = SRC_PORT,
			udpDst = DST_PORT,
			pktLength = PKT_LEN
		}
	end)
	-- a bufArray is just a list of buffers from a mempool that is processed as a single batch
	local bufs = mempool:bufArray()
	local txCtr = stats:newDevTxCounter(queue, "plain")
	local rxCtr = stats:newDevRxCounter(queue, "plain")
	while phobos.running() do -- check if Ctrl+c was pressed
		-- this actually allocates some buffers from the mempool the array is associated with
		-- this has to be repeated for each send because sending is asynchronous, we cannot reuse the old buffers here
		bufs:alloc(PKT_LEN)
		for i, buf in ipairs(bufs) do
			-- packet framework allows simple access to fields in complex protocol stacks
			local pkt = buf:getUdpPacket()
			pkt.udp:setSrcPort(SRC_PORT_BASE + math.random(SRC_PORT_BASE, SRC_PORT_BASE + NUM_FLOWS - 1))
		end
		-- UDP checksums are optional, so using just IPv4 checksums would be sufficient here
		-- UDP checksum offloading is comparatively slow: NICs typically do not support calculating the pseudo-header checksum so this is done in SW
		bufs:offloadUdpChecksums()
		-- send out all packets and frees old bufs that have been sent
		queue:send(bufs)
		txCtr:update()
		rxCtr:update()
	end
	txCtr:finalize()
	rxCtr:finalize()
end


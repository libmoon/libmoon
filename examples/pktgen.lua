--- A simple UDP packet generator
local lm     = require "libmoon"
local device = require "device"
local stats  = require "stats"
local log    = require "log"
local memory = require "memory"
local arp    = require "proto.arp"
local server = require "webserver"

-- set addresses here
local DST_MAC       = nil -- resolved via ARP on GW_IP or DST_IP, can be overriden with a string here
local PKT_LEN       = 60
local SRC_IP        = "10.0.0.10"
local DST_IP        = "10.1.0.10"
local SRC_PORT_BASE = 1234 -- actual port will be SRC_PORT_BASE * random(NUM_FLOWS)
local DST_PORT      = 1234
local NUM_FLOWS     = 1000
-- used as source IP to resolve GW_IP to DST_MAC
-- also respond to ARP queries on this IP
local ARP_IP	= SRC_IP
-- used to resolve DST_MAC
local GW_IP		= DST_IP


-- the configure function is called on startup with a pre-initialized command line parser
function configure(parser)
	parser:description("Edit the source to modify constants like IPs and ports.")
	parser:argument("dev", "Devices to use."):args("+"):convert(tonumber)
	parser:option("-t --threads", "Number of threads per device."):args(1):convert(tonumber):default(1)
	parser:option("-r --rate", "Transmit rate in Mbit/s per device."):args(1)
	parser:option("-w --webserver", "Start a REST API on the given port."):convert(tonumber)
	parser:option("-o --output", "File to output statistics to")
	parser:option("-s --seconds", "Stop after n seconds")
	parser:flag("-a --arp", "Use ARP.")
	parser:flag("--csv", "Output in CSV format")
	return parser:parse()
end

function master(args,...)
	log:info("Check out MoonGen (built on lm) if you are looking for a fully featured packet generator")
	log:info("https://github.com/emmericp/MoonGen")

	-- configure devices and queues
	local arpQueues = {}
	for i, dev in ipairs(args.dev) do
		-- arp needs extra queues
		local dev = device.config{
			port = dev,
			txQueues = args.threads + (args.arp and 1 or 0),
			rxQueues = args.arp and 2 or 1
		}
		args.dev[i] = dev
		if args.arp then
			table.insert(arpQueues, { rxQueue = dev:getRxQueue(1), txQueue = dev:getTxQueue(args.threads), ips = ARP_IP })
		end
	end
	device.waitForLinks()

	-- start ARP task and do ARP lookup (if not hardcoded above)
	if args.arp then
		arp.startArpTask(arpQueues)
		if not DST_MAC then
			log:info("Performing ARP lookup on %s, timeout 3 seconds.", GW_IP)
			DST_MAC = arp.blockingLookup(GW_IP, 3)
			if not DST_MAC then
				log:info("ARP lookup failed, using default destination mac address")
				DST_MAC = "01:23:45:67:89:ab"
			end
		end
		log:info("Destination mac: %s", DST_MAC)
	end

	if args.webserver then
		server.startWebserverTask{
			port = args.webserver
		}
	end

	-- print statistics
	stats.startStatsTask{devices = args.dev, file = args.output, format = args.csv and "csv" or "plain"}

	-- configure tx rates and start transmit slaves
	for i, dev in ipairs(args.dev) do
		for i = 1, args.threads do
			local queue = dev:getTxQueue(i - 1)
			if args.rate then
				queue:setRate(args.rate / args.threads)
			end
			lm.startTask("txSlave", queue, DST_MAC)
		end
	end

	if args.seconds then
		lm.setRuntime(tonumber(args.seconds))
	end

	lm.waitForTasks()
end

function txSlave(queue, dstMac)
	-- memory pool with default values for all packets, this is our archetype
	local mempool = memory.createMemPool(function(buf)
		buf:getUdpPacket():fill{
			-- fields not explicitly set here are initialized to reasonable defaults
			ethSrc = queue, -- MAC of the tx device
			ethDst = dstMac,
			ip4Src = SRC_IP,
			ip4Dst = DST_IP,
			udpSrc = SRC_PORT,
			udpDst = DST_PORT,
			pktLength = PKT_LEN
		}
	end)
	-- a bufArray is just a list of buffers from a mempool that is processed as a single batch
	local bufs = mempool:bufArray()
	while lm.running() do -- check if Ctrl+c was pressed
		-- this actually allocates some buffers from the mempool the array is associated with
		-- this has to be repeated for each send because sending is asynchronous, we cannot reuse the old buffers here
		bufs:alloc(PKT_LEN)
		for i, buf in ipairs(bufs) do
			-- packet framework allows simple access to fields in complex protocol stacks
			local pkt = buf:getUdpPacket()
			pkt.udp:setSrcPort(SRC_PORT_BASE + math.random(0, NUM_FLOWS - 1))
		end
		-- UDP checksums are optional, so using just IPv4 checksums would be sufficient here
		-- UDP checksum offloading is comparatively slow: NICs typically do not support calculating the pseudo-header checksum so this is done in SW
		bufs:offloadUdpChecksums()
		-- send out all packets and frees old bufs that have been sent
		queue:send(bufs)
	end
end


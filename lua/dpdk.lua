---------------------------------
--- @file dpdk.lua
--- @brief DPDK ...
--- @todo TODO docu
---------------------------------

--- high-level dpdk wrapper
local mod = {}
local libmoon = require "libmoon"
local dpdkc  = require "dpdkc"
local ffi    = require "ffi"
local log    = require "log"

-- DPDK mbuf flags (lib/librte_mbuf/rte_mbuf.h)
mod.PKT_RX_VLAN_PKT			= bit.lshift(1ULL, 0)
mod.PKT_RX_RSS_HASH			= bit.lshift(1ULL, 1)
mod.PKT_RX_FDIR				= bit.lshift(1ULL, 2)
mod.PKT_RX_L4_CKSUM_BAD		= bit.lshift(1ULL, 3)
mod.PKT_RX_IP_CKSUM_BAD		= bit.lshift(1ULL, 4)
mod.PKT_RX_EIP_CKSUM_BAD	= bit.lshift(0ULL, 0)
mod.PKT_RX_OVERSIZE			= bit.lshift(0ULL, 0)
mod.PKT_RX_HBUF_OVERFLOW	= bit.lshift(0ULL, 0)
mod.PKT_RX_RECIP_ERR		= bit.lshift(0ULL, 0)
mod.PKT_RX_MAC_ERR			= bit.lshift(0ULL, 0)
mod.PKT_RX_IPV4_HDR			= bit.lshift(1ULL, 5)
mod.PKT_RX_IPV4_HDR_EXT		= bit.lshift(1ULL, 6)
mod.PKT_RX_IPV6_HDR			= bit.lshift(1ULL, 7)
mod.PKT_RX_IPV6_HDR_EXT		= bit.lshift(1ULL, 8)
mod.PKT_RX_IEEE1588_PTP		= bit.lshift(1ULL, 9)
mod.PKT_RX_IEEE1588_TMST	= bit.lshift(1ULL, 10)
mod.PKT_RX_TUNNEL_IPV4_HDR	= bit.lshift(1ULL, 11)
mod.PKT_RX_TUNNEL_IPV6_HDR	= bit.lshift(1ULL, 12)
mod.PKT_RX_FDIR_ID			= bit.lshift(1ULL, 13)
mod.PKT_RX_FDIR_FLX			= bit.lshift(1ULL, 14)

mod.PKT_TX_NO_CRC_CSUM		= bit.lshift(1ULL, 48)
mod.PKT_TX_QINQ_PKT			= bit.lshift(1ULL, 49)
mod.PKT_TX_TCP_SEG			= bit.lshift(1ULL, 50)
mod.PKT_TX_IEEE1588_TMST	= bit.lshift(1ULL, 51)
mod.PKT_TX_L4_NO_CKSUM		= bit.lshift(0ULL, 52)
mod.PKT_TX_TCP_CKSUM		= bit.lshift(1ULL, 52)
mod.PKT_TX_SCTP_CKSUM		= bit.lshift(2ULL, 52)
mod.PKT_TX_UDP_CKSUM		= bit.lshift(3ULL, 52)
mod.PKT_TX_L4_MASK			= bit.lshift(3ULL, 52)
mod.PKT_TX_IP_CKSUM			= bit.lshift(1ULL, 54)
mod.PKT_TX_IPV4				= bit.lshift(1ULL, 55)
mod.PKT_TX_IPV6				= bit.lshift(1ULL, 56)
mod.PKT_TX_VLAN_PKT			= bit.lshift(1ULL, 57)
mod.PKT_TX_OUTER_IP_CKSUM	= bit.lshift(1ULL, 58)
mod.PKT_TX_OUTER_IPV4		= bit.lshift(1ULL, 59)
mod.PKT_TX_OUTER_IPV6		= bit.lshift(1ULL, 60)

-- flow types
mod.RTE_ETH_FLOW_UNKNOWN            = 0
mod.RTE_ETH_FLOW_RAW                = 1
mod.RTE_ETH_FLOW_IPV4               = 2
mod.RTE_ETH_FLOW_FRAG_IPV4          = 3
mod.RTE_ETH_FLOW_NONFRAG_IPV4_TCP   = 4
mod.RTE_ETH_FLOW_NONFRAG_IPV4_UDP	= 5
mod.RTE_ETH_FLOW_NONFRAG_IPV4_SCTP	= 6
mod.RTE_ETH_FLOW_NONFRAG_IPV4_OTHER = 7
mod.RTE_ETH_FLOW_IPV6               = 8
mod.RTE_ETH_FLOW_FRAG_IPV6          = 9
mod.RTE_ETH_FLOW_NONFRAG_IPV6_TCP   = 10
mod.RTE_ETH_FLOW_NONFRAG_IPV6_UDP   = 11
mod.RTE_ETH_FLOW_NONFRAG_IPV6_SCTP  = 12
mod.RTE_ETH_FLOW_NONFRAG_IPV6_OTHER = 13
mod.RTE_ETH_FLOW_L2_PAYLOAD         = 14
mod.RTE_ETH_FLOW_IPV6_EX            = 15
mod.RTE_ETH_FLOW_IPV6_TCP_EX        = 16
mod.RTE_ETH_FLOW_IPV6_UDP_EX        = 17
mod.RTE_ETH_FLOW_MAX                = 18

-- RSS flags
mod.ETH_RSS_IPV4               = bit.lshift(1ULL, mod.RTE_ETH_FLOW_IPV4)
mod.ETH_RSS_FRAG_IPV4          = bit.lshift(1ULL, mod.RTE_ETH_FLOW_FRAG_IPV4)
mod.ETH_RSS_NONFRAG_IPV4_TCP   = bit.lshift(1ULL, mod.RTE_ETH_FLOW_NONFRAG_IPV4_TCP)
mod.ETH_RSS_NONFRAG_IPV4_UDP   = bit.lshift(1ULL, mod.RTE_ETH_FLOW_NONFRAG_IPV4_UDP)
mod.ETH_RSS_NONFRAG_IPV4_SCTP  = bit.lshift(1ULL, mod.RTE_ETH_FLOW_NONFRAG_IPV4_SCTP)
mod.ETH_RSS_NONFRAG_IPV4_OTHER = bit.lshift(1ULL, mod.RTE_ETH_FLOW_NONFRAG_IPV4_OTHER)
mod.ETH_RSS_IPV6               = bit.lshift(1ULL, mod.RTE_ETH_FLOW_IPV6)
mod.ETH_RSS_FRAG_IPV6          = bit.lshift(1ULL, mod.RTE_ETH_FLOW_FRAG_IPV6)
mod.ETH_RSS_NONFRAG_IPV6_TCP   = bit.lshift(1ULL, mod.RTE_ETH_FLOW_NONFRAG_IPV6_TCP)
mod.ETH_RSS_NONFRAG_IPV6_UDP   = bit.lshift(1ULL, mod.RTE_ETH_FLOW_NONFRAG_IPV6_UDP)
mod.ETH_RSS_NONFRAG_IPV6_SCTP  = bit.lshift(1ULL, mod.RTE_ETH_FLOW_NONFRAG_IPV6_SCTP)
mod.ETH_RSS_NONFRAG_IPV6_OTHER = bit.lshift(1ULL, mod.RTE_ETH_FLOW_NONFRAG_IPV6_OTHER)
mod.ETH_RSS_L2_PAYLOAD         = bit.lshift(1ULL, mod.RTE_ETH_FLOW_L2_PAYLOAD)
mod.ETH_RSS_IPV6_EX            = bit.lshift(1ULL, mod.RTE_ETH_FLOW_IPV6_EX)
mod.ETH_RSS_IPV6_TCP_EX        = bit.lshift(1ULL, mod.RTE_ETH_FLOW_IPV6_TCP_EX)
mod.ETH_RSS_IPV6_UDP_EX        = bit.lshift(1ULL, mod.RTE_ETH_FLOW_IPV6_UDP_EX)

--- Do not call dpdk.init() automatically on startup.
--- You must not call any DPDK functions prior to invoking libmoon.init().
function mod.skipInit()
	libmoon.config.skipInit = true
end

--- Initializes DPDK. Called automatically on startup unless
--- libmoon.skipInit() is called before master().
function mod.init()
	local cfgFile = libmoon.config.dpdkConfig
	log:info("Initializing DPDK. This will take a few seconds...")
	-- find config file
	local cfgFileLocations
	if cfgFile then
		cfgFileLocations = { cfgFile }
	else
		cfgFileLocations = {
			"./dpdk-conf.lua",
			libmoon.config.basePath .. "/dpdk-conf.lua",
			"/etc/libmoon/dpdk-conf.lua"
		}
	end
	local cfg
	for _, f in ipairs(cfgFileLocations) do
		if fileExists(f) then
			local cfgScript = loadfile(f)
			setfenv(cfgScript, setmetatable({ DPDKConfig = function(arg) cfg = arg end }, { __index = _G }))
			local ok, err = pcall(cfgScript)
			if not ok then
				log:error("Could not load DPDK config: " .. err)
				return false
			end
			if not cfg then
				log:error("Config file does not contain DPDKConfig statement")
				return false
			end
			cfg.name = f
			break
		end
	end
	if not cfg then
		log:warn("No DPDK config found, using defaults")
		cfg = {}
	end
	-- load config
	local coreMask
	if not cfg.cores then
		-- default: use all the cores
		local cpus = io.open("/proc/cpuinfo", "r")
		cfg.cores = {}
		for cpu in cpus:read("*a"):gmatch("processor	: (%d+)") do
			cfg.cores[#cfg.cores + 1] = tonumber(cpu)
		end
		cpus:close()
	end
	table.sort(cfg.cores)
	libmoon.config.cores = cfg.cores
	libmoon.config.numSharedCores = cfg.sharedCores or 8
	local coreMask = 0ULL
	for i, v in ipairs(cfg.cores) do
		coreMask = bit.bor(coreMask, bit.lshift(1ULL, v))
	end
	local argv = { "libmoon" }
	local coreMaskUpper = tonumber(bit.rshift(coreMask, 32ULL))
	local coreMaskLower = tonumber(bit.band(coreMask, 0xFFFFFFFFULL))
	argv[#argv + 1] = ("-c0x%08X%08X"):format(coreMaskUpper, coreMaskLower)
	-- core mapping, shared cores use the highest IDs
	if #cfg.cores + libmoon.config.numSharedCores >= 128 then
		-- --lcores is restricted to 0-127 in DPDK; this is a problem on large CPUs
		for i = #cfg.cores, math.max(1, #cfg.cores - libmoon.config.numSharedCores + 1), -1 do
			cfg.cores[i] = nil
		end
		libmoon.config.cores = cfg.cores
	end
	local maxCore = cfg.cores[#cfg.cores]
	local coreMapping = ("%d-%d,(%d-%d)@%d"):format(cfg.cores[1], maxCore, maxCore + 1, maxCore + libmoon.config.numSharedCores, cfg.cores[1])
	argv[#argv + 1] = ("--lcores=%s"):format(coreMapping)

	if cfg.pciBlacklist then
		if type(cfg.pciBlacklist) == "table" then
			for i, v in ipairs(cfg.pciBlacklist) do
				argv[#argv + 1] = "-b" .. v
			end
		else
			log:warn("Need a list for the PCI black list")
		end
	end

	if cfg.pciWhitelist then
		if type(cfg.pciWhitelist) == "table" then
			for i, v in ipairs(cfg.pciWhitelist) do
				argv[#argv + 1] = "-w" .. v
			end
		else
			log:warn("Need a list for the PCI white list")
		end
	end
	if cfg.cli then
		for i, v in ipairs(cfg.cli) do
			argv[#argv + 1] = v
		end
	end
	local argc = #argv
	dpdkc.rte_eal_init(argc, ffi.new("const char*[?]", argc, argv))
	local device = require "device"
	local devices = device.getDevices()
	log:info("Found %d usable devices:", #devices)
	for _, device in ipairs(devices) do
		printf("   Device %d: %s (%s)", device.id, device.mac, green(device.name))
	end
	return true
end


return mod

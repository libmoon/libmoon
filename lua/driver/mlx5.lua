-- mlx5-specific code
local dev = {}

local dpdkc = require "dpdkc"
local ffi =  require "ffi"
local log = require "log"

local C = ffi.C

-- the mlx5 driver does not support the flowfilters we normally use
dev.USE_GENERIC_FILTER = true

--- Function which sets all mlx5 specific values, is automatically called at program startup
function dev:init()
	
	-- to enable statistics which count all packets fetched by the driver or not we have to use the xstats
	-- of the device
	-- first retrieve the IDs of the required xstat fields
	-- in case any of those stats is missing, proper packet/byte counting is not possible
	-- last resort in this case is to comment out dev:getRxStats() to default to the normal counting behavior
	local id = ffi.new("uint64_t[1]", 1337)
	
	local ok = C.rte_eth_xstats_get_id_by_name(self.id, "rx_port_unicast_bytes", id)
	self.uc_byte_id = tonumber(id[0])
	if ok ~= 0 then log:fatal("Failed to extract xstats. Uniform packet counting not possible.") end
	
	ok = C.rte_eth_xstats_get_id_by_name(self.id, "rx_port_multicast_bytes", id)
	self.mc_byte_id = tonumber(id[0])
	if ok ~= 0 then log:fatal("Failed to extract xstats. Uniform packet counting not possible.") end

	ok = C.rte_eth_xstats_get_id_by_name(self.id, "rx_port_broadcast_bytes", id)
	self.bc_byte_id = tonumber(id[0])
	if ok ~= 0 then log:fatal("Failed to extract xstats. Uniform packet counting not possible.") end

	ok = C.rte_eth_xstats_get_id_by_name(self.id, "rx_port_unicast_packets", id)
	self.uc_pkt_id = tonumber(id[0])
	if ok ~= 0 then log:fatal("Failed to extract xstats. Uniform packet counting not possible.") end

	ok = C.rte_eth_xstats_get_id_by_name(self.id, "rx_port_multicast_packets", id)
	self.mc_pkt_id = tonumber(id[0])
	if ok ~= 0 then log:fatal("Failed to extract xstats. Uniform packet counting not possible.") end

	ok = C.rte_eth_xstats_get_id_by_name(self.id, "rx_port_broadcast_packets", id)
	self.bc_pkt_id = tonumber(id[0])
	if ok ~= 0 then log:fatal("Failed to extract xstats. Uniform packet counting not possible.") end

	-- retrieve the number of available xstats
	self.numxstats = 0
	local xstats = ffi.new("struct rte_eth_xstat[?]", self.numxstats)
	
	-- because there is no easy function which returns the number of xstats we try to retrieve
	-- the xstats with a zero sized array
	-- if result > numxstats (0 in this case), then result equals the real number of xstats
	local result = C.rte_eth_xstats_get(self.id, xstats, self.numxstats)
	
	-- result will be at least 6, otherwise the above statements would have failed
	self.numxstats = tonumber(result)

end

--- Retrieve RxStats which are comparable between most devices
--- All packets are considered, regardless of memory errors, wrong CRCs etc.
function dev:getRxStats()
	-- the function "rte_eth_xstats_get_by_id" does not seem to work properly. It always returns the first xstat entry, ignoring the IDs
	-- so we get all xstats and use the IDs as index

	-- this function is called once every second or so. Performance penalty should be negligible

	-- only allocate xstats once
	if not self.xstats then
		self.xstats = ffi.new("struct rte_eth_xstat[?]", self.numxstats)
	end
        C.rte_eth_xstats_get(self.id, self.xstats, self.numxstats)

	-- sum of all recieved unicast, multicast and broadcast bytes/packets
	self.rxPkts = (self.xstats[self.uc_pkt_id].value or 0ULL) + (self.xstats[self.mc_pkt_id].value or 0ULL) + (self.xstats[self.bc_pkt_id].value or 0ULL)
	self.rxBytes =  (self.xstats[self.uc_byte_id].value or 0ULL) + (self.xstats[self.mc_byte_id].value or 0ULL) + (self.xstats[self.bc_byte_id].value or 0ULL)
	return tonumber(self.rxPkts), tonumber( self.rxBytes)
end

return dev

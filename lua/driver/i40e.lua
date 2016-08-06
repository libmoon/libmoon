--- i40e-specific code
local dev = {}
local ffi = require "ffi"
local dpdkc = require "dpdkc"

ffi.cdef[[
int i40e_aq_config_vsi_bw_limit(void *hw, uint16_t seid, uint16_t credit, uint8_t max_bw, struct i40e_asq_cmd_details *cmd_details);
]]

--- Set the maximum rate by all queues in Mbit/s.
--- Only supported on XL710 NICs.
--- Note: these NICs use packet size excluding CRC checksum unlike the ixgbe-style NICs.
--- This means you will get an unexpectedly high rate.
function dev:setRate(rate)
	-- we cannot calculate the "proper" rate here as we do not know the packet size
	rate = math.floor(rate / 50 + 0.5) -- 50mbit granularity
	local i40eDev = dpdkc.dpdk_get_i40e_dev(self.id)
	local vsiSeid = dpdkc.dpdk_get_i40e_vsi_seid(self.id)
	assert(ffi.C.i40e_aq_config_vsi_bw_limit(i40eDev, vsiSeid, rate, 0, nil) == 0)
end

return dev

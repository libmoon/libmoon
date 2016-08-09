local mod = {}

local dpdkc = require "dpdkc"
local ffi = require "ffi"

mod.rte_i40e_pmd = require "driver.i40e"
mod.rte_ixgbe_pmd = require "driver.ixgbe"
mod.rte_virtio_pmd = require "driver.virtio"

-- this is a pretty stupid way to do "inheritance" (done this way due to issues with serialization)
-- it would probably be a good idea to change this to proper inheritance
function mod.initDriver(dev)
	local driver = mod[dev:getDriverName()]
	if driver then
		for k, v in pairs(driver) do
			dev[k] = v
		end
	end
end

-- retrieve driver-specific information about a port
-- required for driver-specific configuration variables
function mod.getDriverInfo(id)
	local driverName = ffi.string(dpdkc.dpdk_get_driver_name(id))
	return mod[driverName].driverInfo or {}
end

return mod


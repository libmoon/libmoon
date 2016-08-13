local mod = {}

local dpdkc = require "dpdkc"
local ffi = require "ffi"

mod.rte_i40e_pmd = require "driver.i40e"
mod.rte_ixgbe_pmd = require "driver.ixgbe"
mod.rte_igb_pmd = require "driver.igb"
mod.rte_virtio_pmd = require "driver.virtio"

function mod.initDriver(dev)
	local device = require "device"
	local driver = mod[dev:getDriverName()]
	if driver then
		if not getmetatable(driver) then
			driver.__index = driver
			setmetatable(driver, device.__devicePrototype)
		end
		setmetatable(dev, driver)
	end
end

-- retrieve driver-specific information about a port
-- required for driver-specific configuration variables
function mod.getDriverInfo(id)
	local driverName = ffi.string(dpdkc.dpdk_get_driver_name(id))
	return (mod[driverName] or {}).driverInfo or {}
end

return mod


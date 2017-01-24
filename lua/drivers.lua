local mod = {}

local dpdkc = require "dpdkc"
local ffi = require "ffi"

mod.rte_i40e_pmd = require "driver.i40e"
mod.rte_ixgbe_pmd = require "driver.ixgbe"
mod.rte_ixgbevf_pmd = require "driver.ixgbevf"
mod.rte_igb_pmd = require "driver.igb"
mod.rte_virtio_pmd = require "driver.virtio"
mod.rte_vmxnet3_pmd = require "driver.vmxnet3"

function mod.initDriver(dev)
	local device = require "device"
	local driver = mod[dev:getDriverName()]
	if driver then
		if not getmetatable(driver) then
			driver.__index = driver
			driver.__eq = device.__devicePrototype.__eq
			driver.__tostring = device.__devicePrototype.__tostring
			setmetatable(driver, device.__devicePrototype)
		end
		setmetatable(dev, driver)
	end
	dev.driverInfo = dev.driverInfo or {}
end

-- retrieve driver-specific information
-- required for driver-specific configuration variables
function mod.getDriverInfo(driverName)
	return (mod[driverName] or {}).driverInfo or {}
end

return mod


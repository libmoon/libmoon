local mod = {}

local dpdkc = require "dpdkc"
local ffi = require "ffi"

mod.net_i40e = require "driver.i40e"
mod.net_ixgbe = require "driver.ixgbe"
mod.net_ixgbevf = require "driver.ixgbevf"
mod.net_e1000_igb = require "driver.igb"
mod.net_e1000_em = require "driver.igb"
mod.net_virtio = require "driver.virtio"
mod.net_vmxnet3 = require "driver.vmxnet3"
mod.net_mlx5 = require "driver.mlx5"
mod.net_ena = require "driver.ena"

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


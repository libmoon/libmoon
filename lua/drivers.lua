local mod = {}

mod.rte_i40e_pmd = require "driver.i40e"
mod.rte_ixgbe_pmd = require "driver.ixgbe"

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

return mod

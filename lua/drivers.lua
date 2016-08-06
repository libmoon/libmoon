local mod = {}

mod.rte_i40e_pmd = require "driver.i40e"
mod.rte_ixgbe_pmd = require "driver.ixgbe"

-- this is a pretty stupid way to do "inheritance" (done this way due to general ugliness in device.lua)
for k, v in pairs(mod) do
	v.initDriver = function(obj)
		for k, v in pairs(v) do
			obj[k] = v
		end
	end
end

return mod

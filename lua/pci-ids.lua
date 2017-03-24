local mod = {}

local log    = require "log"
local libmoon = require "libmoon"



local function getFile()
	local fileLocations = {
		libmoon.config.basePath .. "deps/pciids/pci.ids",
		"/usr/share/hwdata/pci.ids",
	}
	local file
	for i, v in ipairs(fileLocations) do
		file = io.open(v)
		if file then
			break
		end
	end
	if not file then
		log:fatal("could not find pci.ids, check git submodules")
	end
	return file
end

local cache = {}
function mod.getName(id)
	if cache[id] then
		return cache[id]
	end
	local vendor = bit.rshift(id, 16)
	local device = bit.band(id, 0xFFFF)
	local vendorId, vendorName
	local name
	local file = getFile()
	for line in file:lines() do
		local c1 = line:sub(1, 1)
		local c2 = line:sub(2, 2)
		if c1 ~= "" and c1 ~= "#" and c1 ~= "\t" and c1 ~= "C"  then
			-- vendor line
			vendorId, vendorName = line:match("(%x+)  (.+)")
			vendorId = tonumber(vendorId, 16)
		elseif vendorId == vendor and c1 == "\t" and c2 ~= "\t" then
			-- device line
			local deviceId, deviceName = line:match("\t(%x+)  (.+)")
			deviceId = tonumber(deviceId, 16)
			if deviceId == device then
				name = vendorName .. " " .. deviceName
				cache[id] = name
				break
			end
		end
	end
	file:close()
	return name or ("unknown NIC (PCI ID %x:%x)"):format(vendor, device)
end

return mod

local mod = {}

local device  = require "device"
local turbo   = require "turbo"
local libmoon = require "libmoon"
local stats   = require "stats"
local ffi     = require "ffi"

local HTTPError = turbo.web.HTTPError

local indexHandler = class("indexHandler", turbo.web.RequestHandler)
function indexHandler:get()
    self:write({hello = "world"})
end

local deviceHandler = class("deviceHandler", turbo.web.RequestHandler)

local function deviceInfo(id)
	local dev = device.get(id)
	local info = dev:getInfo()
	return {
		configured = dev.initialized or false,
		id = info.if_index,
		rxQueues = info.nb_rx_queues,
		txQueues = info.nb_tx_queues,
		maxRxQueues = info.max_rx_queues,
		maxTxQueues = info.max_tx_queues,
		driver = ffi.string(info.driver_name),
		name = dev:getName(),
		numaSocket = dev:getSocket(),
		mac = dev:getMacString(),
		linkUp = dev:getLinkStatus().status,
		linkSpeed = dev:getLinkStatus().speed,
	}
end

function deviceHandler:get(id)
	if id == "all" then
		local result = {}
		for i = 0, device.numDevices() - 1 do
			result[#result + 1] = deviceInfo(i)
		end
		self:write(result)
	elseif id == "num" then
		self:write({num = device.numDevices()})
	elseif tonumber(id) then
		local id = tonumber(id)
		if id >= device.numDevices() then
			error(HTTPError(400, {message = ("there are only %d devices"):format(device.numDevices())}))
		end
		self:write(deviceInfo(id))
	else
		self:set_status(400)	
	end
end

local counterHandler = class("counterHandler", turbo.web.RequestHandler)

local counters = {}
local statsPipe = stats.share.pipe
local function updateCounters()
	while true do
		local data = statsPipe:tryRecv()
		if not data then
			break
		end
		counters[data.id] = counters[data.id] or {
			id = data.id,
			name = data.name,
			direction = data.dir,
			data = {}
		}
		table.insert(counters[data.id].data, data)
		-- do not repeat these values for every entry
		data.id = nil
		data.name = nil
		data.dir = nil
	end
end

local function counterInfo(id)
	return counters[id] or {}
end


function counterHandler:get(id)
	if id == "all" then
		local result = {}
		for i = 1, stats.numCounters() do
			result[#result + 1] = counterInfo(i)
		end
		self:write(result)
	elseif id == "num" then
		self:write({num = stats.numCounters()})
	elseif tonumber(id) then
		local id = tonumber(id)
		if id > stats.numCounters() then
			error(HTTPError(400, {message = ("there are only %d counters"):format(stats.numCounters())}))
		end
		self:write(counterInfo(id))
	else
		self:set_status(400)	
	end
end


function mod.webserverTask(options, ...)
	options = options or {}
	if options.init then
		_G[options.init](turbo, ...)
	end
	local application = turbo.web.Application:new({
	    {"^/$",                  indexHandler},
	    {"^/device/([^/]+)/?$",  deviceHandler},
	    {"^/counter/([^/]+)/?$", counterHandler},
	})
	application:listen(options.port or 8888, nil, {
	})
	local ioloop = turbo.ioloop.instance()
	ioloop:set_interval(500, updateCounters)
	ioloop:set_interval(100, function()
		if not libmoon.running() then
			ioloop:close()
		end
	end)
	ioloop:start()
end


return mod

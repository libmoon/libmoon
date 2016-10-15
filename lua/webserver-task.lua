local mod = {}

local turbo   = require "turbo"
local libmoon = require "libmoon"
local pipe    = require "pipe"
local ns      = require "namespaces"

local indexHandler = class("indexHandler", turbo.web.RequestHandler)
function indexHandler:get()
    self:write({hello = "world"})
end

function mod.webserverTask(options, ...)
	options = options or {}
	if options.init then
		_G[options.init](turbo, ...)
	end
	local application = turbo.web.Application:new({
	    {"^/$", indexHandler}
	})
	application:listen(options.port or 8888, nil, {
	})
	local ioloop = turbo.ioloop.instance()
	ioloop:set_interval(100, function()
		if not libmoon.running() then
			ioloop:close()
		end
	end)
	ioloop:start()
end


return mod

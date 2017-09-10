local mod = {}

local libmoon = require "libmoon"
local ns = require "namespaces"

mod.share = ns:get()

--- Start a webserver task with some default handlers.
--- @param options, table of server settings
---   init: name of a global function that is called by the server task before the ioloop is started
---			receives the turbo object als parameter
---         this can be used to install custom handlers (details TBD)
---   port: port to listen on, default: 8888
---   TODO: SSL options
---  @param ..., vararg passed through to the init function after the turbo parameter
function mod.startWebserverTask(options, ...)
	mod.share.taskRunning = true
	libmoon.startSharedTask("__LM_WEBSERVER_TASK", options, ...)
end

__LM_WEBSERVER_TASK = require "webserver-task".webserverTask

function mod.running()
	if not mod.taskRunning then
		mod.taskRunning = mod.share.taskRunning
	end
	return mod.taskRunning
end

return mod

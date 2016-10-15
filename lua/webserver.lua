local mod = {}

local libmoon = require "libmoon"

--- Start a webserver task with some default handlers.
--- @param options, table of server settings
---   init: name of a global function that is called by the server task before the ioloop is started
---			receives the turbo object als parameter
---         this can be used to install custom handlers (details TBD)
---   port: port to listen on, default: 8888
---   TODO: SSL options
---  @param ..., vararg passed through to the init function after the turbo parameter
function mod.startWebserverTask(options, ...)
	libmoon.startSharedTask("__LM_WEBSERVER_TASK", options, ...)
end

__LM_WEBSERVER_TASK = require "webserver-task".webserverTask

return mod

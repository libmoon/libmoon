local lm     = require "libmoon"
local device = require "device"
local stats  = require "stats"
local log    = require "log"
local memory = require "memory"
local server = require "webserver"

function configure(parser)
	parser:description[[
REST API demo, check out these endpoints:
 * curl localhost/devices/<id>
 * curl localhost/counters/2
 * curl localhost/hello
 * curl localhost/hello/libmoon
 * curl -X POST localhost/hello --data-ascii '{"foo": 42, "hello": "world"}'
	]]
	parser:argument("dev", "Device to use, generates some dummy traffic to showcase the statistics API."):convert(tonumber)
	parser:option("-p --port", "Start the REST API on the given port."):args(1):default(8080):convert(tonumber)
	parser:option("-b --bind", "Bind to a specific IP.")
	parser:option("-o --output", "File to output statistics to")
	return parser:parse()
end

-- this function is executed in the context of the webserver thread
-- you have to define the handlers that you are using *in this thread*, otherwise they won't work
function initWebserver(turbo, defaultResponse)
	log:info("Running webserver initializer, received argument: %s", defaultResponse)

	-- See turbo documentation for more: https://github.com/kernelsauce/turbo
	local helloWorld = class("helloWorld", turbo.web.RequestHandler)
	
	function helloWorld:get(pathArg)
		if pathArg == "" then
			pathArg = defaultResponse
		end
	    self:write({hello = pathArg})
	end

	function helloWorld:post(...)
		local json = self:get_json(true)
		if not json then
			error(turbo.web.HTTPError(400, {message = "Expected JSON data in POST body."}))
		end
		self:write(json)
	end

	-- return an turbo handler list
	return {
		{"^/hello/?([^/]*)$", helloWorld},
	}
end

function master(args,...)
	server.startWebserverTask({
		port = args.port,
		bind = args.bind,
		-- a function that defines additional handlers, it's run as it would with lm.startTask()
		-- this means it needs to be passed by name
		-- any extra arguments passed to startWebserverTasks will be passed on to this function with the usual serialization
		init = "initWebserver"
	}, "Hello, world")
	if args.dev then
		local dev = device.config{port = args.dev}
		device.waitForLinks()
		stats.startStatsTask{devices = {dev}, file = args.output}
		lm.startTask("txTask", dev:getTxQueue(0))
	end
	lm.waitForTasks()
end

function txTask(queue)
	local mempool = memory.createMemPool(function(buf)
		-- just some random packets
		buf:getUdpPacket():fill{
			pktLength = 60
		}
	end)
	local bufs = mempool:bufArray()
	while lm.running() do
		bufs:alloc(60)
		bufs:offloadUdpChecksums()
		queue:send(bufs)
	end
end


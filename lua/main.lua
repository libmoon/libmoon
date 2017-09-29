--- Main file called by all tasks on startup

-- set up logger before doing anything else
local log = require "log"
-- set log level
log:setLevel("INFO")
-- enable logging to file
--log:fileEnable()

-- globally available utility functions
require "utils"

local libmoon     = require "libmoon"
local dpdk       = require "dpdk"
local dpdkc      = require "dpdkc"
local device     = require "device"
local stp        = require "StackTracePlus"
local ffi        = require "ffi"
local memory     = require "memory"
local serpent    = require "Serpent"
local argparse   = require "argparse"

-- loads all headers of the protocol stack
require "packet"

-- TODO: add command line switches for this and other luajit-debugging features
--require("jit.v").on()

local function getStackTrace(err)
	print(red("[FATAL] Lua error in task %s", LIBMOON_TASK_NAME))
	print(stp.stacktrace(err, 2))
end

local function run(file, ...)
	local script, err = loadfile(file)
	if not script then
		error(err)
	end
	return xpcall(script, getStackTrace, ...)
end

local function parseCommandLineArgs(...)
	local args = { ... }
	local dpdkCfg
	for i = #args, 1, -1 do
		local v = args[i]
		-- find --dpdk-config=foo parameter
		local cfg, count = string.gsub(v, "%-%-dpdk%-config%=", "")
		if count == 1 then
			dpdkCfg = cfg
			table.remove(args, i)
		else
			-- is it just a simple number?
			if tonumber(v) then
				v = tonumber(v)
			end
			args[i] = v
		end
	end
	return args, dpdkCfg
end

local function master(_, file, ...)
	memory.testAllocationSpace()
	LIBMOON_TASK_NAME = "master"
	local args, cfgFile = parseCommandLineArgs(...)
	libmoon.config.dpdkConfig = cfgFile
	libmoon.config.userscript = file
	libmoon.setupPaths() -- need the userscript first because we want to use the path
	-- run the userscript
	local ok = run(file)
	if not ok then
		return
	end
	local parsedArgs = {}
	if _G.configure then
		local parser = argparse()
		parser:args(unpack(args))
		parsedArgs = {xpcall(_G.configure, getStackTrace, parser, unpack(args))}
		if not parsedArgs[1] then
			return
		end
		table.remove(parsedArgs, 1)
		-- nothing returned but the parser was used
		-- just try to call the parser ourselves here
		if #parsedArgs == 0
		and (#parser._arguments ~= 0 or #parser._options ~= 0 or #parser._commands ~= 0) then
			parsedArgs = {parser:parse()}
		end
	end
	if not libmoon.config.skipInit then
		if not dpdk.init() then
			log:fatal("Could not initialize DPDK")
		end
	end
	local result = xpcall(_G.master, getStackTrace, unpack(concatArrays(parsedArgs, args)))
	-- stop devices if necessary (seems to be a problem with virtio attached via vhost user
	device.cleanupDevices()
	-- exit program once the master task finishes
	if not result then
		os.exit(result)
	end
	-- it is up to the user program to wait for slaves to finish, e.g. by calling dpdk.waitForSlaves()
end

local function slave(args)
	libmoon.setupPaths()
	-- must be done before parsing the args as they might rely on deserializers loaded by the script
	local ok = run(libmoon.config.userscript)
	if not ok then
		return
	end
	-- core > max core means this is a shared task
	if libmoon.getCore() > libmoon.config.cores[#libmoon.config.cores] then
		-- disabling this warning must be done before deserializing the arguments
		libmoon.disableBadSocketWarning()
	end
	args = loadstring(args)()
	local taskId = args[1]
	local func = args[2]
	if not _G[func] then
		log:fatal("slave function %s not found", func)
	end
	--require("jit.p").start("l")
	--require("jit.dump").on()
	LIBMOON_TASK_NAME = func
	LIBMOON_TASK_ID = taskId
	local results = { select(2, xpcall(_G[func], getStackTrace, select(3, unpackAll(args)))) }
	local vals = serpent.dump(results)
	local buf = ffi.new("char[?]", #vals + 1)
	ffi.copy(buf, vals)
	ffi.C.task_store_result(taskId, buf)
	if libmoon.running() then
		local ok, err = pcall(device.reclaimTxBuffers)
		if ok then
			memory.freeMemPools()
		else
			log:warn("Could not reclaim tx memory: %s", err)
		end
	end
	--require("jit.p").stop()
end

function main(task, ...)
	if task == "master" then
		master(...)
	elseif task == "slave" then
		slave(...)
	else
		log:fatal("invalid task type %s", task)
	end
end


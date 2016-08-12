--- Main file called by all tasks on startup

-- set up logger before doing anything else
local log = require "log"
-- set log level
log:setLevel("INFO")
-- enable logging to file
--log:fileEnable()

-- globally available utility functions
require "utils"

local phobos     = require "phobos"
local dpdk       = require "dpdk"
local dpdkc      = require "dpdkc"
local device     = require "device"
local stp        = require "StackTracePlus"
local ffi        = require "ffi"
local memory     = require "memory"
local serpent    = require "Serpent"
local argparse   = require "argparse"

-- all available headers, packets, ... and their utility functions
require "proto.proto"

-- TODO: add command line switches for this and other luajit-debugging features
--require("jit.v").on()

local function getStackTrace(err)
	print(red("[FATAL] Lua error in task %s", PHOBOS_TASK_NAME))
	print(stp.stacktrace(err, 2))
end

local function run(file, ...)
	local script, err = loadfile(file)
	if not script then
		error(err)
	end
	xpcall(script, getStackTrace, ...)
end

local function parseCommandLineArgs(...)
	local args = { ... }
	local dpdkCfg
	for i, v in ipairs(args) do
		-- find --dpdk-config=foo parameter
		local cfg, count = string.gsub(v, "%-%-dpdk%-config%=", "")
		if count == 1 then
			dpdkCfg = cfg
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
	PHOBOS_TASK_NAME = "master"
	local args, cfgFile = parseCommandLineArgs(...)
	phobos.config.dpdkConfig = cfgFile
	phobos.config.userscript = file
	-- run the userscript
	run(file)
	local parsedArgs = {}
	if _G.configure then
		local parser = argparse()
		parser:args(unpack(args))
		parsedArgs = {xpcall(_G.configure, getStackTrace, parser, unpack(args))}
		if not parsedArgs[1] then
			return
		end
		table.remove(parsedArgs, 1)
	end
	if not phobos.config.skipInit then
		if not dpdk.init() then
			log:fatal("Could not initialize DPDK")
		end
	end
	xpcall(_G.master, getStackTrace, unpack(concatArrays(parsedArgs, args)))
	-- exit program once the master task finishes
	-- it is up to the user program to wait for slaves to finish, e.g. by calling dpdk.waitForSlaves()
end

local function slave(args)
	-- must be done before parsing the args as they might rely on deserializers loaded by the script
	run(phobos.config.userscript)
	-- core > max core means this is a shared task
	if phobos.getCore() > phobos.config.cores[#phobos.config.cores] then
		-- disabling this warning must be done before deserializing the arguments
		phobos.disableBadSocketWarning()
	end
	args = loadstring(args)()
	local taskId = args[1]
	local func = args[2]
	if not _G[func] then
		log:fatal("slave function %s not found", func)
	end
	--require("jit.p").start("l")
	--require("jit.dump").on()
	PHOBOS_TASK_NAME = func
	PHOBOS_TASK_ID = taskId
	local results = { select(2, xpcall(_G[func], getStackTrace, select(3, unpackAll(args)))) }
	local vals = serpent.dump(results)
	local buf = ffi.new("char[?]", #vals + 1)
	ffi.copy(buf, vals)
	ffi.C.task_store_result(taskId, buf)
	if phobos.running() then
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


local mod = {}

local log        = require "log"
local namespaces = require "namespaces"
local dpdkc      = require "dpdkc"
local ffi        = require "ffi"
local serpent    = require "Serpent"

mod.config = namespaces:get()
mod.config.appName = "phobos"

local function checkCore()
	if PHOBOS_TASK_NAME ~= "master" then
		log:fatal("This function is only available on the master task.", 2)
	end
end


ffi.cdef[[
	void launch_lua_core(int core, const char* arg);
	void free(void* ptr);
	uint64_t task_generate_id();
	void task_store_result(uint64_t task_id, char* result);
	char* task_get_result(uint64_t task_id);
]]


local task = {}
task.__index = task

local tasks = {}

function task:new(core)
	checkCore()
	local obj = setmetatable({
		-- double instead of uint64_t is easier here and okay (unless you want to start more than 2^53 tasks)
		id = tonumber(ffi.C.task_generate_id()),
		core = core
	}, task)
	tasks[core] = obj
	return obj
end

--- Wait for a task and return any arguments returned by the task
function task:wait()
	checkCore()
	while true do
		if dpdkc.rte_eal_get_lcore_state(self.core) ~= dpdkc.RUNNING then
			-- task is finished
			local result = ffi.C.task_get_result(self.id)
			if result == nil then
				-- thread crashed :(
				return
			end
			local resultString = ffi.string(result)
			ffi.C.free(result)
			return unpackAll(loadstring(resultString)())
		end
		mod.sleepMillisIdle(1)
	end
end

function task:isRunning()
	checkCore()
	if not tasks[self.core] or task[self.core].id ~= self.id then
		-- something else or nothing is running on this core
		return false
	end
	-- this task is still on this core, but is it still running?
	return dpdkc.rte_eal_get_lcore_state(core) == dpdkc.RUNNING
end



--- Start a new task on the first free non-shared core
function mod.startTask(...)
	checkCore()
	for i = 2, #mod.config.cores do -- skip master
		local core = mod.config.cores[i]
		local status = dpdkc.rte_eal_get_lcore_state(core)
		if status == dpdkc.FINISHED or status == dpdkc.WAIT then
			return mod.startTaskOnCore(core, ...)
		end
	end
	log:fatal("Not enough cores to start this task")
end

function mod.startSharedTask(...)
	checkCore()
	local maxCore = mod.config.cores[#mod.config.cores]
	for core = maxCore + 1, maxCore + mod.config.numSharedCores do
		local status = dpdkc.rte_eal_get_lcore_state(core)
		if status == dpdkc.FINISHED or status == dpdkc.WAIT then
			return mod.startTaskOnCore(core, ...)
		end
	end
	log:fatal("Not enough shared task IDs available to start this task, this limit can be increased in dpdk-conf.lua")
end

--- Launch a LuaJIT VM on a core with the given arguments.
function mod.startTaskOnCore(core, ...)
	checkCore()
	local status = dpdkc.rte_eal_get_lcore_state(core)
	if status == dpdkc.FINISHED then
		dpdkc.rte_eal_wait_lcore(core)
		-- should be guaranteed to be in WAIT state now according to DPDK documentation
		status = dpdkc.rte_eal_get_lcore_state(core)
	end
	if status ~= dpdkc.WAIT then -- core is in WAIT state
		log:fatal("requested core is already in use")
	end
	local task = task:new(core)
	local args = serpent.dump({ task.id, ... })
	local buf = ffi.new("char[?]", #args + 1)
	ffi.copy(buf, args)
	dpdkc.launch_lua_core(core, buf)
	return task
end

ffi.cdef [[
	int usleep(unsigned int usecs);
]]

--- waits until all tasks (including shared cores) have finished their jobs
function mod.waitForTasks()
	while true do
		local allCoresFinished = true
		for i = 2, #mod.config.cores do -- skip master
			local core = mod.config.cores[i]
			if dpdkc.rte_eal_get_lcore_state(core) == dpdkc.RUNNING then
				allCoresFinished = false
				break
			end
		end
		local maxCore = mod.config.cores[#mod.config.cores]
		for core = maxCore + 1, maxCore + mod.config.numSharedCores do
			if dpdkc.rte_eal_get_lcore_state(core) == dpdkc.RUNNING then
				allCoresFinished = false
				break
			end
		end
		if allCoresFinished then
			return
		end
		ffi.C.usleep(1000)
	end
end

--- get the CPU's TSC
function mod.getCycles()
	return dpdkc.rte_rdtsc()
end

--- get the TSC frequency
function mod.getCyclesFrequency()
	return tonumber(dpdkc.rte_get_tsc_hz())
end

--- gets the time in seconds
function mod.getTime()
	return tonumber(mod.getCycles()) / tonumber(mod.getCyclesFrequency())
end

--- limit the total run time (to be called from master core on startup, shared between all cores)
function mod.setRuntime(time)
	dpdkc.set_runtime(time * 1000)
end

--- Returns false once the app receives SIGTERM or SIGINT, the time set via setRuntime expires, or when a thread calls phobos.stop().
-- @param extraTime additional time in milliseconds before false will be returned (e.g. to keep an rx task running longer than a tx task in a loopback test)
function mod.running(extraTime)
	return dpdkc.is_running(extraTime or 0) == 1 -- luajit-2.0.3 does not like bool return types (TRACE NYI: unsupported C function type)
end

--- request all tasks to exit
function mod.stop()
	dpdkc.set_runtime(0)
end

--- Delay by t milliseconds. Note that this does not sleep the actual thread;
--- the time is spent in a busy wait loop by DPDK.
function mod.sleepMillis(t)
	dpdkc.rte_delay_ms_export(t)
end

--- Delay by t microseconds. Note that this does not sleep the actual thread;
--- the time is spent in a busy wait loop by DPDK. This means that this sleep
--- is somewhat more accurate than relying on the OS.
function mod.sleepMicros(t)
	dpdkc.rte_delay_us_export(t)
end

--- Sleep by t milliseconds by calling usleep().
function mod.sleepMillisIdle(t)
	ffi.C.usleep(t * 1000)
end

--- Sleep by t microseconds by calling usleep().
function mod.sleepMicrosIdle(t)
	ffi.C.usleep(t)
end

--- Get the core and socket id for the current thread
function mod.getCore()
	return dpdkc.get_current_core(), dpdkc.get_current_socket()
end

function mod.disableBadSocketWarning()
	PHOBOS_IGNORE_BAD_NUMA_MAPPING = true
end

-- patch argparse to use the script as default name
local parser = require "argparse"
local old = package.loaded.argparse
package.loaded.argparse = function(...)
	return old(...):name(mod.config.appName .. " " .. mod.config.userscript)
end

return mod

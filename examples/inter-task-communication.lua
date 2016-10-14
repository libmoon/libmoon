--- Different methods to communicate between tasks.
local lm         = require "libmoon"
local ffi        = require "ffi"
local memory     = require "memory"
local namespaces = require "namespaces"
local pipe       = require "pipe"
local lock       = require "lock"
local barrier    = require "barrier"
local log        = require "log"

SOME_GLOBAL_VARIABLE = "foo"

-- hook print to show the current task's name
local print = function(str, ...)
	if not str then return print() end
	print(("[Task: %s] " .. str):format(LIBMOON_TASK_NAME, ...))
end

local function globalVarDemo()
	print("Global variable SOME_GLOBAL_VARIABLE = %s", SOME_GLOBAL_VARIABLE)
	print("Changing value to \"bar\"")
	SOME_GLOBAL_VARIABLE = "bar"
	lm.startTask("globalVarSlave")
	lm.waitForTasks()
	print("Back in master task")
	print("Global variable SOME_GLOBAL_VARIABLE = %s", SOME_GLOBAL_VARIABLE)
end

function globalVarSlave()
	print("This is a slave task")
	print("Global variable SOME_GLOBAL_VARIABLE = %s", SOME_GLOBAL_VARIABLE)
end


local function argumentsDemo()
	print("Passing arguments to slave tasks is the simplest way to communicate with them")
	print("All arguments are serialized to be passed to the other LuaJIT VM")
	print("This means all arguments are copied and modifications don't propagate")
	print("Calling argumentSlave with a few examples values")
	local task = lm.startTask("argumentSlave", "string", 3.14, {key = { key = "value"}})
	local tbl, str = task:wait()
	print("Received a %s return value: tbl.foo = \"%s\"", type(tbl), tbl.foo)
	print("Received a %s return value: \"%s\"", type(str), str)
	print("You can also pass objects such as devices or queues between tasks in this way")
	-- it's actually possible to pass bytecode
	-- however, this is disabled by default because it causes more problems than it solves
	-- you can use the Serpent library with nocode = false to serialize functions as bytecode
	print("However, you cannot pass function values")
end

function argumentSlave(str, num, tbl)
	print("Received a %s: %s ", type(str), str)
	print("Received a %s: %s ", type(num), tostring(num))
	print("Received a table: %s", type(tbl), tbl)
	print("tbl.key.key = %s", tbl.key.key)
	print("You can return values from tasks as well")
	return { foo = "bar" }, "second return value"
end


local ns = namespaces:get()
local function namespaceDemo()
	print("Namespaces are tables with shared values between different tasks.")
	print("Saving same values to the namespace...")
	ns.foo = 5
	ns.key = "value"
	lm.startTask("namespaceSlave")
	lm.waitForTasks()
	print("Namespaces use the same serialization mechanism as argument passing")
	print("That means retrieving a value results in a copy")
	print("A more complete example for namespaces is the ARP implementation in lua/proto/arp.lua")
end

function namespaceSlave()
	print("ns.foo = " .. ns.foo)
	print("ns.key = " .. ns.key)
end


local function pipeDemo()
	print("There are two types of pipes in lm: slowPipes and fastPipes")
	print("The former rely on serialization, the latter can only handle LuaJIT FFI cdata pointers")
	print("A typical usecase for slow pipes would be transferring statistics between tasks")
	print("Fast pipes are suitable to pass packets between tasks")
	local slowPipe = pipe:newSlowPipe()
	local fastPipe = pipe:newFastPipe()
	lm.startTask("slowPipeSlave", slowPipe)
	print("Sending data to slow pipe")
	slowPipe:send({key = "value"})
	lm.waitForTasks()
	print("Starting multiple fastPipe tasks")
	lm.startTask("fastPipeSendSlave", fastPipe)
	lm.startTask("fastPipeRecvSlave", fastPipe)
	lm.waitForTasks()
	print("Note: Slow pipes are multi-producer multi-consumer. Fast pipes default to single-producer single-consumer.")
end

function slowPipeSlave(pipe)
	print("Retrieving data using blocking recv(), use tryRecv() for non-blocking")
	print("Data: key = " .. pipe:recv().key)
end

ffi.cdef[[
	struct some_struct { uint32_t val; }
]]
function fastPipeSendSlave(pipe)
	print("Allocating cdata object")
	print("The pipe sends a pointer to another LuaJIT VM, so we cannot use the GC here")
	local data = memory.alloc("struct some_struct*", ffi.sizeof("struct some_struct"))
	data.val = 5
	print("Sending struct %s, val = %d", data, data.val)
	pipe:send(data)
end

function fastPipeRecvSlave(pipe)
	print("Receiving the object as void*, you should only pass data of one ctype through a given fast pipe")
	print("However, pipes are cheap and you can allocate a lot of them")
	local data = ffi.cast("struct some_struct*", pipe:recv())
	print("Received struct %s, val = %d", data, data.val)
	print("Note: this is the exact same memory address, take care when accessing it concurrently")
	memory.free(data)
end


local function syncDemo()
	print("lm provides locks and barriers")
	print("Locks work exactly as you expect them to work")
	local l = lock:new()
	print("Acquiring lock")
	l:lock()
	lm.startTask("lockSlave", l)
	print("Waiting 500ms before releasing lock")
	lm.sleepMillisIdle(500)
	l:unlock()
	lm.waitForTasks()
	print("Barriers are used to ensure a set of tasks reached the same point before continuing")
	local b = barrier:new(3)
	lm.startTask("barrierSlave", b, 1, 0)
	lm.startTask("barrierSlave", b, 2, 100)
	lm.startTask("barrierSlave", b, 3, 1000)
	lm.waitForTasks()
end

function lockSlave(l)
	print("Trying to acquire lock")
	l:lock()
	print("Got lock!")
	l:unlock()
end

function barrierSlave(b, taskId, sleep)
	print("Slave task %d, sleeping for %d milliseconds", taskId, sleep)
	lm.sleepMillisIdle(sleep)
	print("Waiting on barrier at timestamp %f", time())
	b:wait()
	print("Got through barrier at timestamp %f", time())
end

function master(...)
	log:info("Demonstrating global variables: they are not shared between tasks.")
	globalVarDemo()
	print()

	log:info("Demonstrating serialization for argument and return value passing.")
	argumentsDemo()
	print()

	log:info("Demonstrating namespaces to share state.")
	namespaceDemo()
	print()

	log:info("Demonstrating pipes.")
	pipeDemo()
	print()

	log:info("Demonstrating synchronization primitives.")
	syncDemo()
	print()

	log:info("You can also implement and call normal C functions (see c-integration example) if these methods are not sufficient.")
	log:info("All tasks run within the same process, so the usual concurrency features are available there.")
end


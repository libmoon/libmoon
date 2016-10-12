local lm = require "libmoon"

function master(...)
	print("Hello, world!")
	print("Command line arguments: ", ...)
	lm.startTask("slave", "Hello, world from first slave!")
	lm.startTask("slave", "Hello, world from second slave!")
	lm.waitForTasks()
	print("All slaves finished, exiting...")
end

function slave(arg)
	printf("Slave task, received argument: \"%s\"", arg)
end


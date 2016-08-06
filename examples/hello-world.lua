local phobos = require "phobos"

function master(...)
	print("Hello, world!")
	print("Command line arguments: ", ...)
	phobos.startTask("slave", "Hello, world from first slave!")
	phobos.startTask("slave", "Hello, world from second slave!")
	phobos.waitForTasks()
	print("All slaves finished, exiting...")
end

function slave(arg)
	printf("Slave task, received argument: \"%s\"", arg)
end


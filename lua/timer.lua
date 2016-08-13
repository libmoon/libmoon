--- Simple timer class.

local mod = {}

local phobos = require "phobos"

local timer = {}
timer.__index = timer

function mod:new(time)
	return setmetatable({
		time = time or 0,
		stop = phobos.getTime() + (time or 0)
	}, timer)
end

function timer:running()
	return self.stop > phobos.getTime()
end

function timer:expired()
	return self.stop <= phobos.getTime()
end

function timer:timeLeft()
	return self.stop - phobos.getTime()
end

function timer:reset(time)
	self.stop = phobos.getTime() + (time or self.time)
end

--- Perform a busy wait on the timer.
-- Returns early if Phobos is stopped (phobos.running() == false).
function timer:busyWait()
	while not self:expired() and phobos.running() do
	end
	return phobos.running()
end

--- Perform a non-busy wait on the timer.
--- Might be less accurate than busyWait()
function timer:wait()
	-- TODO: implement
	return self:busyWait()
end

return mod


--- Simple timer class.

local mod = {}

local libmoon = require "libmoon"

local timer = {}
timer.__index = timer

function mod:new(time)
	return setmetatable({
		time = time or 0,
		stop = libmoon.getTime() + (time or 0)
	}, timer)
end

function timer:running()
	return self.stop > libmoon.getTime()
end

function timer:expired()
	return self.stop <= libmoon.getTime()
end

function timer:timeLeft()
	return self.stop - libmoon.getTime()
end

function timer:reset(time)
	self.stop = libmoon.getTime() + (time or self.time)
end

--- Perform a busy wait on the timer.
-- Returns early if libmoon is stopped (libmoon.running() == false).
function timer:busyWait()
	while not self:expired() and libmoon.running() do
	end
	return libmoon.running()
end

--- Perform a non-busy wait on the timer.
--- Might be less accurate than busyWait()
function timer:wait()
	-- TODO: implement
	return self:busyWait()
end

return mod


local lm = require "libmoon"

local TBL_SIZE = 10 -- small, we don't want to spent all the time in (de-)serialization
local NUM_LOCAL_TABLES = 1000

local function makeLargeTable()
	local tbl = {}
	for i = 1, TBL_SIZE do
		tbl[tostring(i)] = {1, 2, 3, 4, "Entry " .. i}
	end
	return tbl
end

local function checkResult(tbl)
	for i = 1, TBL_SIZE do
		local entry = tbl[tostring(i)]
		assert(entry)
		assert(#entry == 5)
		assert(entry[5] == "Entry " .. i)
	end
end

function shouldNotLeak(table)
	collectgarbage("stop")
	for i = 1, NUM_LOCAL_TABLES do
		makeLargeTable()
	end
	return table
end

function master()
	for i = 1, 500 do
		checkResult(lm.startTask("shouldNotLeak", makeLargeTable()):wait())
	end
end


--- igb-specific code

local dev = {}

-- the igb driver actually reports stats almost as expected
dev.txStatsIgnoreCrc = true
dev.rxStatsIgnoreCrc = true

return dev


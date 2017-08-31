local dev = {}

-- stats of a VF are very limited, can't do better than DPDK here
dev.txStatsIgnoreCrc = true
dev.rxStatsIgnoreCrc = true

return dev


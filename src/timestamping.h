#pragma once

// cannot include rte_time.h because it doesn't have include guards
struct rte_timecounter;

void phobos_reset_timecounter(struct rte_timecounter* tc);


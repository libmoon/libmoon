#pragma once

// rte_time.h doesn't have include guards
#ifndef NO_INCLUDE_RTE_TIME
#include <rte_time.h>
#endif

static void libmoon_reset_timecounter(struct rte_timecounter* tc) {
	tc->nsec = 0;
	tc->nsec_frac = 0;
	tc->cycle_last = 0;
}

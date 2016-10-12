#include <stdbool.h>
#include <time.h>
#include <csignal>
#include <iostream>

#include <rte_config.h>
#include <rte_cycles.h>

#include "lifecycle.hpp"

namespace libmoon {
	// this code is, strictly speaking, incorrect as there are no memory fences
	// and these variables are accessed by multiple threads
	// however, memory fences are slow and this works in practice
	static volatile uint64_t stop_at = -1;
	static volatile uint64_t signal_at = -1;

	static void handler(int unused) {
		if (signal_at != (uint64_t) -1) {
			// cancel was requested more than once, just bail out
			std::cerr << "Received more than one SIGINT/SIGTERM, aborting" << std::endl;
			std::abort();
		}
		signal_at = rte_rdtsc();
	}

	void install_signal_handlers() {
		signal(SIGINT, handler);
		signal(SIGTERM, handler);
	}

	// do not change the return type to bool as luajit doesn't like this
	uint8_t is_running(uint32_t extra_time) {
		uint64_t extra_time_cycles = (uint64_t) extra_time * rte_get_tsc_hz() / 1000;
		uint64_t time = rte_rdtsc() - extra_time_cycles;
		return signal_at > time && stop_at > time;
	}
}

extern "C" {
	uint8_t is_running(uint32_t extra_time) {
		return libmoon::is_running(extra_time);
	}

	void set_runtime(uint32_t run_time) {
		libmoon::stop_at = rte_rdtsc() + run_time * rte_get_tsc_hz() / 1000;
	}
}

// vim:ts=4:sw=4:noexpandtab

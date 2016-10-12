#include <stdint.h>
#include <stdlib.h>

#include "device.h"

void libmoon_sync_clocks(uint8_t port1, uint8_t port2, uint32_t timl, uint32_t timh, uint32_t adjl, uint32_t adjh) {
	// resetting SYSTIML twice prevents a race-condition when SYSTIML is just about to overflow into SYSTIMH
	write_reg32(port1, timl, 0);
	write_reg32(port2, timl, 0);
	write_reg32(port1, timh, 0);
	write_reg32(port2, timh, 0);
	if (port1 == port2) {
		// just reset timers if port1 == port2
		return;
	}
	volatile uint32_t* port1time = get_reg_addr(port1, timl);
	volatile uint32_t* port2time = get_reg_addr(port2, timl);
	const int num_runs = 7; // must be odd
	int32_t offsets[num_runs];
	*port1time = 0;
	*port2time = 0; // the clocks now differ by offs, the time for the write access which is calculated in the following loop
	for (int i = 0; i < num_runs; i++) {
		uint32_t x1 = *port1time;
		uint32_t x2 = *port2time;
		uint32_t y1 = *port2time;
		uint32_t y2 = *port1time;
		int32_t delta_t = abs(((int64_t) x1 - x2 - ((int64_t) y2 - y1)) / 2); // time between two reads
		int32_t offs = delta_t + x1 - x2;
		offsets[i] = offs;
	}
	int cmp(const void* e1, const void* e2) {
		int32_t offs1 = *(int32_t*) e1;
		int32_t offs2 = *(int32_t*) e2;
		return offs1 < offs2 ? -1 : offs1 > offs2 ? 1 : 0;
	}
	// use the median offset
	qsort(offsets, num_runs, sizeof(int32_t), &cmp);
	int32_t offs = offsets[num_runs / 2];
	if (offs) {
		// offs of 0 is not supported by the hw
		write_reg32(port2, adjl, offs < 0 ? (uint32_t) -offs : (uint32_t) offs);
		write_reg32(port2, adjh, offs < 0 ? 1 << 31 : 0);
		// verification that the clocks are synced: the two clocks should only differ by a constant caused by the read operation
		// i.e. x2 - x1 = y2 - y1 iff clock1 == clock2
		/*uint32_t x1 = *port1time;
		uint32_t x2 = *port2time;
		uint32_t y1 = *port2time;
		uint32_t y2 = *port1time;
		printf("%d %d\n", x2 - x1, y2 - y1);*/
	}
}


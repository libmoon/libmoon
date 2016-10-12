// always include rte_config.h, almost all DPDK headers depend it
// (but almost none of them include it themselves...)
#include <rte_config.h>
#include <rte_mbuf.h>

// you can do everything DPDK can do from here, all libraries are available
// here we just modify some packets and let libmoon handle IO
// you could also handle the whole main loop here, however, that is unnecessarily complex
void swap_macs(struct rte_mbuf* mbufs[], uint32_t num_bufs) {
	for (uint32_t i = 0; i < num_bufs; i++) {
		uint16_t* pkt = rte_pktmbuf_mtod(mbufs[i], uint16_t*);
		// swap source and destination MAC
		uint16_t tmp1 = pkt[0];
		uint16_t tmp2 = pkt[1];
		uint16_t tmp3 = pkt[2];
		pkt[0] = pkt[3];
		pkt[1] = pkt[4];
		pkt[2] = pkt[5];
		pkt[3] = tmp1;
		pkt[4] = tmp2;
		pkt[5] = tmp3;
	}
}


#include <algorithm>

#include <cstring>
#include <cstdint>

#include <rte_config.h>
#include <rte_mbuf.h>
#include <rte_mempool.h>

struct pcapRecHeader {
	uint32_t ts_sec;   /* timestamp seconds */
	uint32_t ts_usec;  /* timestamp microseconds */
	uint32_t incl_len; /* number of octets of packet saved in file */
	uint32_t orig_len; /* actual length of packet */
	uint8_t data[];
};

extern "C" {
	void libmoon_write_pcap(pcapRecHeader* dst, const void* packet, uint32_t len, uint32_t orig_len, uint32_t ts_sec, uint32_t ts_usec) {
		dst->ts_sec = ts_sec;
		dst->ts_usec = ts_usec;
		dst->incl_len = len;
		dst->orig_len = len;
		memcpy(&dst->data, packet, len);
	}

	rte_mbuf* libmoon_read_pcap(rte_mempool* mp, const pcapRecHeader* src, uint64_t remaining, uint32_t mempool_buf_size) {
		if (src->incl_len >= remaining) {
			return nullptr;
		}
		uint32_t copy_len = src->incl_len;
		if (copy_len > mempool_buf_size - 128) {
			copy_len = mempool_buf_size - 128;
		}
		uint32_t zero_fill_len = std::min(mempool_buf_size - copy_len - 128, src->orig_len - src->incl_len);
		rte_mbuf* res = rte_pktmbuf_alloc(mp);
		if (!res) {
			return res;
		}
		res->pkt_len = src->incl_len;
		res->data_len = copy_len + zero_fill_len;
		res->udata64 = src->ts_sec * 1000000ULL + src->ts_usec;
		uint8_t* data = rte_pktmbuf_mtod(res, uint8_t*);
		memcpy(data, &src->data, copy_len);
		memset(data + copy_len, 0, zero_fill_len);
		return res;
	}

	uint32_t libmoon_read_pcap_batch(rte_mempool* mp, rte_mbuf** bufs, uint32_t num_bufs, const uint8_t* pcap, uint64_t remaining, uint32_t mempool_buf_size) {
		uint64_t offset = 0;
		for (uint32_t i = 0; i < num_bufs; ++i) {
			const pcapRecHeader* header = reinterpret_cast<const pcapRecHeader*>(pcap + offset);
			rte_mbuf* buf = libmoon_read_pcap(mp, header, remaining, mempool_buf_size);
			bufs[i] = buf;
			if (!buf) return i;
			offset += header->incl_len + sizeof(pcapRecHeader);
			remaining -= header->incl_len + sizeof(pcapRecHeader);
		}
		return num_bufs;
	}
}

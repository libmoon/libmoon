#include <cstring>
#include <cstdint>

struct pcapRecHeader {
	uint32_t ts_sec;   /* timestamp seconds */
	uint32_t ts_usec;  /* timestamp microseconds */
	uint32_t incl_len; /* number of octets of packet saved in file */
	uint32_t orig_len; /* actual length of packet */
	uint8_t data[];
};

extern "C" {
	void phobos_write_pcap(pcapRecHeader* dst, const void* packet, uint32_t len, uint32_t orig_len, uint32_t ts_sec, uint32_t ts_usec) {
		dst->ts_sec = 0;
		dst->ts_usec = 0;
		dst->incl_len = len;
		dst->orig_len = len;
		memcpy(&dst->data, packet, len);
	}
}

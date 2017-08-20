#include <rte_config.h>
#include <rte_ethdev.h> 
#include <rte_mempool.h>
#include <rte_ether.h>
#include <rte_cycles.h>
#include <rte_mbuf.h>
#include <ixgbe_type.h>
#include <rte_mbuf.h>
#include <rte_eth_ctrl.h>

#include "rdtsc.h"

#include "device.h"
#include "lifecycle.h"

// default descriptors per queue
#define DEFAULT_RX_DESCS 512
#define DEFAULT_TX_DESCS 256


static volatile uint8_t* registers[RTE_MAX_ETHPORTS];

uint32_t read_reg32(uint8_t port, uint32_t reg) {
	return *(volatile uint32_t*)(registers[port] + reg);
}

void write_reg32(uint8_t port, uint32_t reg, uint32_t val) {
	*(volatile uint32_t*)(registers[port] + reg) = val;
}

uint64_t read_reg64(uint8_t port, uint32_t reg) {
	return *(volatile uint64_t*)(registers[port] + reg);
}

void write_reg64(uint8_t port, uint32_t reg, uint64_t val) {
	*(volatile uint64_t*)(registers[port] + reg) = val;
}

volatile uint32_t* get_reg_addr(uint8_t port, uint32_t reg) {
	return (volatile uint32_t*)(registers[port] + reg);
}

int dpdk_get_max_ports() {
	return RTE_MAX_ETHPORTS;
}

struct libmoon_device_config {
	uint32_t port;
	struct rte_mempool** mempools;
	uint16_t rx_queues;
	uint16_t tx_queues;
	uint16_t rx_descs;
	uint16_t tx_descs;
	uint8_t drop_enable;
	uint8_t enable_rss;
	uint8_t disable_offloads;
	uint8_t strip_vlan;
	uint32_t rss_mask;
};

int dpdk_configure_device(struct libmoon_device_config* cfg) {
	const char* driver = dpdk_get_driver_name(cfg->port);
	bool is_i40e_device = strcmp("net_i40e", driver) == 0;
	// TODO: make fdir configurable
	struct rte_fdir_conf fdir_conf = {
		.mode = RTE_FDIR_MODE_PERFECT,
		.pballoc = RTE_FDIR_PBALLOC_64K,
		.status = RTE_FDIR_REPORT_STATUS_ALWAYS,
		.mask = {
			.vlan_tci_mask = 0x0,
			.ipv4_mask = {
				.src_ip = 0,
				.dst_ip = 0,
			},
			.ipv6_mask = {
				.src_ip = {0,0,0,0},
				.dst_ip = {0,0,0,0},
			},
			.src_port_mask = 0,
			.dst_port_mask = 0,
			.mac_addr_byte_mask = 0,
			.tunnel_type_mask = 0,
			.tunnel_id_mask = 0,
		},
		.flex_conf = {
			.nb_payloads = 1,
			.nb_flexmasks = 1,
			.flex_set = {
				[0] = {
					.type = RTE_ETH_RAW_PAYLOAD,
					// i40e requires to use all 16 values here, otherwise it just fails
					.src_offset = { 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57 },
				}
			},
			.flex_mask = {
				[0] = {
					// ixgbe *only* accepts RTE_ETH_FLOW_UNKNOWN, i40e accepts any value other than that
					// other drivers don't really seem to care...
					// WTF?
					// any other value is apparently an error for this undocumented field
					.flow_type = is_i40e_device ? RTE_ETH_FLOW_NONFRAG_IPV4_UDP : RTE_ETH_FLOW_UNKNOWN,
					.mask = { [0] = 0xFF, [1] = 0xFF }
				}
			},
		},
		.drop_queue = 63,
	};

	struct rte_eth_rss_conf rss_conf = {
		.rss_key = NULL,
		.rss_key_len = 0,
		.rss_hf = cfg->rss_mask,
	};
	struct rte_eth_conf port_conf = {
		.rxmode = {
			.mq_mode = cfg->enable_rss ? ETH_MQ_RX_RSS : ETH_MQ_RX_NONE,
			.split_hdr_size = 0,
			.header_split = 0,
			.hw_ip_checksum = !cfg->disable_offloads,
			.hw_vlan_filter = 0,
			.jumbo_frame = 0,
			.hw_strip_crc = 1,
			.hw_vlan_strip = cfg->strip_vlan ? 1 : 0,
		},
		.txmode = {
			.mq_mode = ETH_MQ_TX_NONE,
		},
		.fdir_conf = fdir_conf,
		// FIXME: update link speed API for dpdk 16.04
		.link_speeds = ETH_LINK_SPEED_AUTONEG,
    	.rx_adv_conf = {
			.rss_conf = rss_conf,
		}
	};
	int rc = rte_eth_dev_configure(cfg->port, cfg->rx_queues, cfg->tx_queues, &port_conf);
	if (rc) return rc;
	struct rte_eth_dev_info dev_info;
	rte_eth_dev_info_get(cfg->port, &dev_info);
	struct rte_eth_txconf tx_conf = {
		.tx_thresh = {
			.pthresh = dev_info.default_txconf.tx_thresh.pthresh,
			.hthresh = dev_info.default_txconf.tx_thresh.hthresh,
			.wthresh = dev_info.default_txconf.tx_thresh.wthresh,
		},
		.txq_flags = ETH_TXQ_FLAGS_NOMULTSEGS | (cfg->disable_offloads ? ETH_TXQ_FLAGS_NOOFFLOADS : 0),
	};
	for (int i = 0; i < cfg->tx_queues; i++) {
		rc = rte_eth_tx_queue_setup(cfg->port, i, cfg->tx_descs ? cfg->tx_descs : DEFAULT_TX_DESCS, SOCKET_ID_ANY, &tx_conf);
		if (rc) {
			printf("could not configure tx queue %d\n", i);
			return rc;
		}
	}
	struct rte_eth_rxconf rx_conf = {
		.rx_drop_en = cfg->drop_enable,
		.rx_thresh = {
			.pthresh = dev_info.default_rxconf.rx_thresh.pthresh,
			.hthresh = dev_info.default_rxconf.rx_thresh.hthresh,
			.wthresh = dev_info.default_rxconf.rx_thresh.wthresh,
		},
	};
	for (int i = 0; i < cfg->rx_queues; i++) {
		rc = rte_eth_rx_queue_setup(cfg->port, i, cfg->rx_descs ? cfg->rx_descs : DEFAULT_RX_DESCS, SOCKET_ID_ANY, &rx_conf, cfg->mempools[i]);
		if (rc != 0) {
			printf("could not configure rx queue %d\n", i);
			return rc;
		}
	}
	rc = rte_eth_dev_start(cfg->port);
	// save memory address of the register file
	if (dev_info.pci_dev) {
		registers[cfg->port] = (uint8_t*) dev_info.pci_dev->mem_resource[0].addr;
	} else {
		registers[cfg->port] = NULL; // TODO: provide dummy memory area here? check for null on access?
	}
	return rc;
}

void* dpdk_get_eth_dev(int port) {
	return &rte_eth_devices[port];
}

int dpdk_get_pci_function(int port) {
	struct rte_eth_dev_info dev_info;
	rte_eth_dev_info_get(port, &dev_info);
	if (dev_info.pci_dev) {
		return dev_info.pci_dev->addr.function;
	} else {
		return 0;
	}
}

const char* dpdk_get_driver_name(int port) {
	struct rte_eth_dev_info dev_info;
	rte_eth_dev_info_get(port, &dev_info);
	return dev_info.driver_name;
}

uint64_t dpdk_get_mac_addr(int port, char* buf) {
	struct ether_addr addr;
	rte_eth_macaddr_get(port, &addr);
	if (buf) {
		sprintf(buf, "%02X:%02X:%02X:%02X:%02X:%02X", addr.addr_bytes[0], addr.addr_bytes[1], addr.addr_bytes[2], addr.addr_bytes[3], addr.addr_bytes[4], addr.addr_bytes[5]);
	}
	return addr.addr_bytes[0] | (addr.addr_bytes[1] << 8) | (addr.addr_bytes[2] << 16) | ((uint64_t) addr.addr_bytes[3] << 24) | ((uint64_t) addr.addr_bytes[4] << 32) | ((uint64_t) addr.addr_bytes[5] << 40);
}

uint32_t dpdk_get_pci_id(uint8_t port) {
	struct rte_eth_dev_info dev_info;
	rte_eth_dev_info_get(port, &dev_info);
	if (!dev_info.pci_dev) {
		return 0;
	}
	return dev_info.pci_dev->id.vendor_id << 16 | dev_info.pci_dev->id.device_id;
}

uint8_t dpdk_get_socket(uint8_t port) {
	struct rte_eth_dev_info dev_info;
	rte_eth_dev_info_get(port, &dev_info);
	if (!dev_info.pci_dev) {
		return 0;
	}
	int node = dev_info.pci_dev->device.numa_node;
	if (node == -1) {
		node = 0;
	}
	return (uint8_t) node;
}

uint32_t dpdk_get_rte_queue_stat_cntrs_num() {
	return RTE_ETHDEV_QUEUE_STAT_CNTRS;
}

// the following functions are static inline function in header files
// this is the easiest/least ugly way to make them available to luajit (#defining static before including the header breaks stuff)
uint16_t rte_eth_rx_burst_export(uint8_t port_id, uint16_t queue_id, void* rx_pkts, uint16_t nb_pkts) {
	return rte_eth_rx_burst(port_id, queue_id, rx_pkts, nb_pkts);
}

uint16_t rte_eth_tx_burst_export(uint8_t port_id, uint16_t queue_id, void* tx_pkts, uint16_t nb_pkts) {
	return rte_eth_tx_burst(port_id, queue_id, tx_pkts, nb_pkts);
}

void dpdk_send_all_packets(uint8_t port_id, uint16_t queue_id, struct rte_mbuf** pkts, uint16_t num_pkts) {
	uint32_t sent = 0;
	while (1) {
		sent += rte_eth_tx_burst(port_id, queue_id, pkts + sent, num_pkts - sent);
		if (sent >= num_pkts) {
			return;
		}
	}
	return;
}

void dpdk_send_single_packet(uint8_t port_id, uint16_t queue_id, struct rte_mbuf* pkt) {
	uint32_t sent = 0;
	while (1) {
		sent = rte_eth_tx_burst(port_id, queue_id, &pkt, 1);
		if (sent > 0) {
			return;
		}
	}
	return;
}


uint16_t dpdk_try_send_single_packet(uint8_t port_id, uint16_t queue_id, struct rte_mbuf* pkt) {
	uint16_t sent = 0;
	sent = rte_eth_tx_burst(port_id, queue_id, &pkt, 1);
	return sent;
}

// receive packets and save the tsc at the time of the rx call
// this prevents potential gc/jit pauses right between the rdtsc and rx calls
uint16_t dpdk_receive_with_timestamps_software(uint8_t port_id, uint16_t queue_id, struct rte_mbuf* rx_pkts[], uint16_t nb_pkts) {
	uint32_t cycles_per_byte = rte_get_tsc_hz() / 10000000.0 / 0.8;
	while (is_running(0)) {
		uint64_t tsc = read_rdtsc();
		uint16_t rx = rte_eth_rx_burst(port_id, queue_id, rx_pkts, nb_pkts);
		uint16_t prev_pkt_size = 0;
		for (int i = 0; i < rx; i++) {
			rx_pkts[i]->udata64 = tsc + prev_pkt_size * cycles_per_byte;
			prev_pkt_size = rx_pkts[i]->pkt_len + 24;
		}
		if (rx > 0) {
			return rx;
		}
	}
	return 0;
}


void rte_pktmbuf_free_export(void* m) {
	rte_pktmbuf_free(m);
}


void rte_delay_ms_export(uint32_t ms) {
	rte_delay_ms(ms);
}

void rte_delay_us_export(uint32_t us) {
	rte_delay_us(us);
}


#pragma once
#include <stdint.h>
#include <rte_config.h>
#include <rte_mbuf.h>
#include "memory.h"

#ifdef __cplusplus
extern "C" {
#endif

void* dpdk_get_eth_dev(int port);
void* dpdk_get_i40e_dev(int port);
int dpdk_get_pci_function(int port);
const char* dpdk_get_driver_name(int port);
int dpdk_get_i40e_vsi_seid(int port);
uint64_t dpdk_get_mac_addr(int port, char* buf);
uint32_t dpdk_get_pci_id(uint8_t port);
uint8_t dpdk_get_socket(uint8_t port);
uint32_t read_reg32(uint8_t port, uint32_t reg);
void write_reg32(uint8_t port, uint32_t reg, uint32_t val);
volatile uint32_t* get_reg_addr(uint8_t port, uint32_t reg);
void dpdk_send_all_packets(uint8_t port_id, uint16_t queue_id, struct rte_mbuf** pkts, uint16_t num_pkts);
int config_device(uint32_t port, uint16_t rx_queues, uint16_t tx_queues, uint16_t rx_descs, uint16_t tx_descs, uint8_t drop_enable, uint8_t enable_rss, uint8_t disable_offloads, uint8_t strip_vlan, uint32_t rss_mask, uint32_t nb_mbuf, uint32_t mbuf_size);
uint16_t rte_eth_rx_burst_export(uint8_t port_id, uint16_t queue_id, void* rx_pkts, uint16_t nb_pkts);
uint16_t rte_eth_tx_burst_export(uint8_t port_id, uint16_t queue_id, void* tx_pkts, uint16_t nb_pkts);


#ifdef __cplusplus
}
#endif

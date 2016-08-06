#pragma once
#include <stdint.h>

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

#ifdef __cplusplus
}
#endif

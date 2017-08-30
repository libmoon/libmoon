#include <rte_config.h>
#include <rte_ethdev.h> 
// required for i40e_type.h
// (structs have a different layout if left undefined....)
#define X722_SUPPORT
#define X722_A0_SUPPORT

// i40e_ethdev depends on i40e_type.h but doesn't include it
#include <i40e_type.h>
#include <virtchnl.h>
#include <i40e_ethdev.h>

void* dpdk_get_i40e_dev(int port) {
	return I40E_DEV_PRIVATE_TO_HW(rte_eth_devices[port].data->dev_private);
}

int dpdk_get_i40e_vsi_seid(int port) {
	return I40E_DEV_PRIVATE_TO_PF(rte_eth_devices[port].data->dev_private)->main_vsi->seid;
}


#include <stdint.h>

#include <rte_config.h>
#include <rte_ethdev.h>

// required for i40e_type.h
#define X722_SUPPORT
#define X722_A0_SUPPORT

// i40e_ethdev depends on i40e_type.h but doesn't include it
#include <i40e_type.h>
#include <virtchnl.h>
// clashes with ixgbe_ethdev.h
#include <i40e_ethdev.h>

#define NO_INCLUDE_RTE_TIME
#include "timestamping.h"
#undef NO_INCLUDE_RTE_TIME

int libmoon_i40e_reset_timecounters(uint32_t port_id) {
	RTE_ETH_VALID_PORTID_OR_ERR_RET(port_id, -ENODEV);
	struct rte_eth_dev* dev = &rte_eth_devices[port_id];
	struct i40e_adapter* adapter = (struct i40e_adapter*) dev->data->dev_private;
	libmoon_reset_timecounter(&adapter->systime_tc);
	libmoon_reset_timecounter(&adapter->rx_tstamp_tc);
	libmoon_reset_timecounter(&adapter->tx_tstamp_tc);
	return 0;
}

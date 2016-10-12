#include <rte_config.h>
#include <rte_ethdev.h>

#include <e1000_hw.h>
#include <e1000_ethdev.h>

#define NO_INCLUDE_RTE_TIME
#include "timestamping.h"
#undef NO_INCLUDE_RTE_TIME

int libmoon_igb_reset_timecounters(uint32_t port_id) {
	RTE_ETH_VALID_PORTID_OR_ERR_RET(port_id, -ENODEV);
	struct rte_eth_dev* dev = &rte_eth_devices[port_id];
	struct e1000_adapter* adapter = (struct e1000_adapter*) dev->data->dev_private;
	libmoon_reset_timecounter(&adapter->systime_tc);
	libmoon_reset_timecounter(&adapter->rx_tstamp_tc);
	libmoon_reset_timecounter(&adapter->tx_tstamp_tc);
	return 0;
}

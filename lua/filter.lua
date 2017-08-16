---------------------------------
--- @file filter.lua
--- @brief Filter ...
--- @todo TODO docu
---------------------------------

local mod = {}

local dpdkc    = require "dpdkc"
local device   = require "device"
local ffi      = require "ffi"
local dpdk     = require "dpdk"
local mbitmask = require "bitmask"
local log      = require "log"
local generic  = require "filter_GenericFlowAPI"

mod.DROP = -1


local dev = device.__devicePrototype

ffi.cdef[[

// used by the (undocumented) flow_type fields in filters
enum rte_flow_type {
	RTE_ETH_FLOW_UNKNOWN = 0,
	RTE_ETH_FLOW_RAW,
	RTE_ETH_FLOW_IPV4,
	RTE_ETH_FLOW_FRAG_IPV4,
	RTE_ETH_FLOW_NONFRAG_IPV4_TCP,
	RTE_ETH_FLOW_NONFRAG_IPV4_UDP,
	RTE_ETH_FLOW_NONFRAG_IPV4_SCTP,
	RTE_ETH_FLOW_NONFRAG_IPV4_OTHER,
	RTE_ETH_FLOW_IPV6,
	RTE_ETH_FLOW_FRAG_IPV6,
	RTE_ETH_FLOW_NONFRAG_IPV6_TCP,
	RTE_ETH_FLOW_NONFRAG_IPV6_UDP,
	RTE_ETH_FLOW_NONFRAG_IPV6_SCTP,
	RTE_ETH_FLOW_NONFRAG_IPV6_OTHER,
	RTE_ETH_FLOW_L2_PAYLOAD,
	RTE_ETH_FLOW_IPV6_EX,
	RTE_ETH_FLOW_IPV6_TCP_EX,
	RTE_ETH_FLOW_IPV6_UDP_EX,
	RTE_ETH_FLOW_MAX
};

enum rte_eth_payload_type {
	RTE_ETH_PAYLOAD_UNKNOWN = 0,
	RTE_ETH_RAW_PAYLOAD,
	RTE_ETH_L2_PAYLOAD,
	RTE_ETH_L3_PAYLOAD,
	RTE_ETH_L4_PAYLOAD,
	RTE_ETH_PAYLOAD_MAX = 8,
};

enum rte_filter_type {
	RTE_ETH_FILTER_NONE = 0,
	RTE_ETH_FILTER_MACVLAN,
	RTE_ETH_FILTER_ETHERTYPE,
	RTE_ETH_FILTER_FLEXIBLE,
	RTE_ETH_FILTER_SYN,
	RTE_ETH_FILTER_NTUPLE,
	RTE_ETH_FILTER_TUNNEL,
	RTE_ETH_FILTER_FDIR,
	RTE_ETH_FILTER_HASH,
	RTE_ETH_FILTER_MAX
};

enum rte_filter_op {
	RTE_ETH_FILTER_NOP = 0,
	RTE_ETH_FILTER_ADD,
	RTE_ETH_FILTER_UPDATE,
	RTE_ETH_FILTER_DELETE,
	RTE_ETH_FILTER_FLUSH,
	RTE_ETH_FILTER_GET,
	RTE_ETH_FILTER_SET,
	RTE_ETH_FILTER_INFO,
	RTE_ETH_FILTER_STATS,
	RTE_ETH_FILTER_OP_MAX
};

enum rte_mac_filter_type {
	RTE_MAC_PERFECT_MATCH = 1,
	RTE_MACVLAN_PERFECT_MATCH,
	RTE_MAC_HASH_MATCH,
	RTE_MACVLAN_HASH_MATCH,
};

struct rte_eth_ethertype_filter {
	uint8_t mac_addr[6];
	uint16_t ether_type;
	uint16_t flags;
	uint16_t queue;
};


/**
 * A structure used to define the input for L2 flow
 */
struct rte_eth_l2_flow {
	uint16_t ether_type;          /**< Ether type in big endian */
};

struct rte_eth_ntuple_filter {
	uint16_t flags;
	uint32_t dst_ip;
	uint32_t dst_ip_mask;
	uint32_t src_ip;
	uint32_t src_ip_mask;
	uint16_t dst_port;
	uint16_t dst_port_mask;
	uint16_t src_port;
	uint16_t src_port_mask;
	uint8_t proto;
	uint8_t proto_mask;
	uint8_t tcp_flags;
	uint16_t priority;
	uint16_t queue;
};

/**
 * A structure used to define the input for IPV4 flow
 */
struct rte_eth_ipv4_flow {
	uint32_t src_ip;      /**< IPv4 source address in big endian. */
	uint32_t dst_ip;      /**< IPv4 destination address in big endian. */
	uint8_t  tos;         /**< Type of service to match. */
	uint8_t  ttl;         /**< Time to live to match. */
	uint8_t  proto;       /**< Protocol, next header in big endian. */
};

/**
 * A structure used to define the input for IPV4 UDP flow
 */
struct rte_eth_udpv4_flow {
	struct rte_eth_ipv4_flow ip; /**< IPv4 fields to match. */
	uint16_t src_port;           /**< UDP source port in big endian. */
	uint16_t dst_port;           /**< UDP destination port in big endian. */
};

/**
 * A structure used to define the input for IPV4 TCP flow
 */
struct rte_eth_tcpv4_flow {
	struct rte_eth_ipv4_flow ip; /**< IPv4 fields to match. */
	uint16_t src_port;           /**< TCP source port in big endian. */
	uint16_t dst_port;           /**< TCP destination port in big endian. */
};

/**
 * A structure used to define the input for IPV4 SCTP flow
 */
struct rte_eth_sctpv4_flow {
	struct rte_eth_ipv4_flow ip; /**< IPv4 fields to match. */
	uint16_t src_port;           /**< SCTP source port in big endian. */
	uint16_t dst_port;           /**< SCTP destination port in big endian. */
	uint32_t verify_tag;         /**< Verify tag in big endian */
};

/**
 * A structure used to define the input for IPV6 flow
 */
struct rte_eth_ipv6_flow {
	uint32_t src_ip[4];      /**< IPv6 source address in big endian. */
	uint32_t dst_ip[4];      /**< IPv6 destination address in big endian. */
	uint8_t  tc;             /**< Traffic class to match. */
	uint8_t  proto;          /**< Protocol, next header to match. */
	uint8_t  hop_limits;     /**< Hop limits to match. */
};

/**
 * A structure used to define the input for IPV6 UDP flow
 */
struct rte_eth_udpv6_flow {
	struct rte_eth_ipv6_flow ip; /**< IPv6 fields to match. */
	uint16_t src_port;           /**< UDP source port in big endian. */
	uint16_t dst_port;           /**< UDP destination port in big endian. */
};

/**
 * A structure used to define the input for IPV6 TCP flow
 */
struct rte_eth_tcpv6_flow {
	struct rte_eth_ipv6_flow ip; /**< IPv6 fields to match. */
	uint16_t src_port;           /**< TCP source port to in big endian. */
	uint16_t dst_port;           /**< TCP destination port in big endian. */
};

/**
 * A structure used to define the input for IPV6 SCTP flow
 */
struct rte_eth_sctpv6_flow {
	struct rte_eth_ipv6_flow ip; /**< IPv6 fields to match. */
	uint16_t src_port;           /**< SCTP source port in big endian. */
	uint16_t dst_port;           /**< SCTP destination port in big endian. */
	uint32_t verify_tag;         /**< Verify tag in big endian. */
};

/**
 * A structure used to define the input for MAC VLAN flow
 */
struct rte_eth_mac_vlan_flow {
	uint8_t mac_addr[6];  /**< Mac address to match. */
};

/**
 * Tunnel type for flow director.
 */
enum rte_eth_fdir_tunnel_type {
	RTE_FDIR_TUNNEL_TYPE_UNKNOWN = 0,
	RTE_FDIR_TUNNEL_TYPE_NVGRE,
	RTE_FDIR_TUNNEL_TYPE_VXLAN,
};

/**
 * A structure used to define the input for tunnel flow, now it is VxLAN or
 * NVGRE
 */
struct rte_eth_tunnel_flow {
	enum rte_eth_fdir_tunnel_type tunnel_type; /**< Tunnel type to match. */
	/** Tunnel ID to match. TNI, VNI... in big endian. */
	uint32_t tunnel_id;
	uint8_t mac_addr[6];  /**< Mac address to match. */
};

/**
 * An union contains the inputs for all types of flow
 * Items in flows need to be in big endian
 */
union rte_eth_fdir_flow {
	struct rte_eth_l2_flow     l2_flow;
	struct rte_eth_udpv4_flow  udp4_flow;
	struct rte_eth_tcpv4_flow  tcp4_flow;
	struct rte_eth_sctpv4_flow sctp4_flow;
	struct rte_eth_ipv4_flow   ip4_flow;
	struct rte_eth_udpv6_flow  udp6_flow;
	struct rte_eth_tcpv6_flow  tcp6_flow;
	struct rte_eth_sctpv6_flow sctp6_flow;
	struct rte_eth_ipv6_flow   ipv6_flow;
	struct rte_eth_mac_vlan_flow mac_vlan_flow;
	struct rte_eth_tunnel_flow   tunnel_flow;
};

/**
 * A structure used to contain extend input of flow
 */
struct rte_eth_fdir_flow_ext {
	uint16_t vlan_tci;
	uint8_t flexbytes[16];
	/**< It is filled by the flexible payload to match. */
	uint8_t is_vf;   /**< 1 for VF, 0 for port dev */
	uint16_t dst_id; /**< VF ID, available when is_vf is 1*/
};


struct rte_eth_fdir_input {
	uint16_t flow_type;
	union rte_eth_fdir_flow flow;
	/**< Flow fields to match, dependent on flow_type */
	struct rte_eth_fdir_flow_ext flow_ext;
	/**< Additional fields to match */
};

/**
* Behavior will be taken if FDIR match
*/
enum rte_eth_fdir_behavior {
	RTE_ETH_FDIR_ACCEPT = 0,
	RTE_ETH_FDIR_REJECT,
	RTE_ETH_FDIR_PASSTHRU,
};

/**
* Flow director report status
* It defines what will be reported if FDIR entry is matched.
*/
enum rte_eth_fdir_status {
	RTE_ETH_FDIR_NO_REPORT_STATUS = 0, /**< Report nothing. */
	RTE_ETH_FDIR_REPORT_ID,            /**< Only report FD ID. */
	RTE_ETH_FDIR_REPORT_ID_FLEX_4,     /**< Report FD ID and 4 flex bytes. */
	RTE_ETH_FDIR_REPORT_FLEX_8,        /**< Report 8 flex bytes. */
};


struct rte_eth_fdir_action {
	uint16_t rx_queue;        /**< Queue assigned to if FDIR match. */
	enum rte_eth_fdir_behavior behavior;     /**< Behavior will be taken */
	enum rte_eth_fdir_status report_status;  /**< Status report option */
	uint8_t flex_off;
	/**< If report_status is RTE_ETH_FDIR_REPORT_ID_FLEX_4 or
	RTE_ETH_FDIR_REPORT_FLEX_8, flex_off specifies where the reported
	flex bytes start from in flexible payload. */
};

struct rte_eth_fdir_filter {
	uint32_t soft_id;
	/**< ID, an unique value is required when deal with FDIR entry */
	struct rte_eth_fdir_input input;    /**< Input set */
	struct rte_eth_fdir_action action;  /**< Action taken when match */
};

/**
 * A structure used to define the statistics of flow director.
 * It supports RTE_ETH_FILTER_FDIR with RTE_ETH_FILTER_STATS operation.
 */
struct rte_eth_fdir_stats {
	uint32_t collision;    /**< Number of filters with collision. */
	uint32_t free;         /**< Number of free filters. */
	uint32_t maxhash;
	/**< The lookup hash value of the added filter that updated the value
	   of the MAXLEN field */
	uint32_t maxlen;       /**< Longest linked list of filters. */
	uint64_t add;          /**< Number of added filters. */
	uint64_t remove;       /**< Number of removed filters. */
	uint64_t f_add;        /**< Number of failed added filters. */
	uint64_t f_remove;     /**< Number of failed removed filters. */
	uint32_t guarant_cnt;  /**< Number of filters in guaranteed spaces. */
	uint32_t best_cnt;     /**< Number of filters in best effort spaces. */
};

enum rte_fdir_mode {
	RTE_FDIR_MODE_NONE      = 0, /**< Disable FDIR support. */
	RTE_FDIR_MODE_SIGNATURE,     /**< Enable FDIR signature filter mode. */
	RTE_FDIR_MODE_PERFECT,       /**< Enable FDIR perfect filter mode. */
	RTE_FDIR_MODE_PERFECT_MAC_VLAN, /**< Enable FDIR filter mode - MAC VLAN. */
	RTE_FDIR_MODE_PERFECT_TUNNEL,   /**< Enable FDIR filter mode - tunnel. */
};

/**
 *  A structure used to configure FDIR masks that are used by the device
 *  to match the various fields of RX packet headers.
 */
struct rte_eth_fdir_masks {
	uint16_t vlan_tci_mask;   /**< Bit mask for vlan_tci in big endian */
	/** Bit mask for ipv4 flow in big endian. */
	struct rte_eth_ipv4_flow   ipv4_mask;
	/** Bit maks for ipv6 flow in big endian. */
	struct rte_eth_ipv6_flow   ipv6_mask;
	/** Bit mask for L4 source port in big endian. */
	uint16_t src_port_mask;
	/** Bit mask for L4 destination port in big endian. */
	uint16_t dst_port_mask;
	/** 6 bit mask for proper 6 bytes of Mac address, bit 0 matches the
	    first byte on the wire */
	uint8_t mac_addr_byte_mask;
	/** Bit mask for tunnel ID in big endian. */
	uint32_t tunnel_id_mask;
	uint8_t tunnel_type_mask; /**< 1 - Match tunnel type,
				       0 - Ignore tunnel type. */
};

/**
 * A structure used to select bytes extracted from the protocol layers to
 * flexible payload for filter
 */
struct rte_eth_flex_payload_cfg {
	enum rte_eth_payload_type type;  /**< Payload type */
	uint16_t src_offset[16];
	/**< Offset in bytes from the beginning of packet's payload
	     src_offset[i] indicates the flexbyte i's offset in original
	     packet payload. This value should be less than
	     flex_payload_limit in struct rte_eth_fdir_info.*/
};

struct rte_eth_fdir_flex_mask {
	uint16_t flow_type;
	uint8_t mask[16];
	/**< Mask for the whole flexible payload */
};

struct rte_eth_fdir_flex_conf {
	uint16_t nb_payloads;  /**< The number of following payload cfg */
	uint16_t nb_flexmasks; /**< The number of following mask */
	struct rte_eth_flex_payload_cfg flex_set[RTE_ETH_PAYLOAD_MAX];
	/**< Flex payload configuration for each payload type */
	struct rte_eth_fdir_flex_mask flex_mask[RTE_ETH_FLOW_MAX];
	/**< Flex mask configuration for each flow type */
};

/**
 * A structure used to get the information of flow director filter.
 * It supports RTE_ETH_FILTER_FDIR with RTE_ETH_FILTER_INFO operation.
 * It includes the mode, flexible payload configuration information,
 * capabilities and supported flow types, flexible payload characters.
 * It can be gotten to help taking specific configurations per device.
 */
struct rte_eth_fdir_info {
	enum rte_fdir_mode mode; /**< Flow director mode */
	struct rte_eth_fdir_masks mask;
	/** Flex payload configuration information */
	struct rte_eth_fdir_flex_conf flex_conf;
	uint32_t guarant_spc; /**< Guaranteed spaces.*/
	uint32_t best_spc; /**< Best effort spaces.*/
	/** Bit mask for every supported flow type. */
	uint32_t flow_types_mask[1];
	uint32_t max_flexpayload; /**< Total flex payload in bytes. */
	/** Flexible payload unit in bytes. Size and alignments of all flex
	    payload segments should be multiplies of this value. */
	uint32_t flex_payload_unit;
	/** Max number of flexible payload continuous segments.
	    Each segment should be a multiple of flex_payload_unit.*/
	uint32_t max_flex_payload_segment_num;
	/** Maximum src_offset in bytes allowed. It indicates that
	    src_offset[i] in struct rte_eth_flex_payload_cfg should be less
	    than this value. */
	uint16_t flex_payload_limit;
	/** Flex bitmask unit in bytes. Size of flex bitmasks should be a
	    multiply of this value. */
	uint32_t flex_bitmask_unit;
	/** Max supported size of flex bitmasks in flex_bitmask_unit */
	uint32_t max_flex_bitmask_num;
};


int rte_eth_dev_filter_ctrl(uint8_t port_id, enum rte_filter_type filter_type, enum rte_filter_op filter_op, void * arg);
void fdir_get_infos(uint32_t port_id);

]]

local RTE_ETHTYPE_FLAGS_MAC		= 1
local RTE_ETHTYPE_FLAGS_DROP	= 2

local C = ffi.C


function dev:l2Filter(etype, queue)
	-- mlx5 based device do not support the ethertype filter
	if self.USE_GENERIC_FILTER then 
		self:l2GenericFilter(etype, queue)
	else	
		if type(queue) == "table" then
			if queue.dev.id ~= self.id then
				log:fatal("Queue must belong to the device being configured")
			end
			queue = queue.qid
		end
		local flags = 0
		if queue == self.DROP then
			flags = RTE_ETHTYPE_FLAGS_DROP
			log:err("DROP")
		end
		local filter = ffi.new("struct rte_eth_ethertype_filter", { ether_type = etype, flags = 0, queue = queue })
		local ok = C.rte_eth_dev_filter_ctrl(self.id, C.RTE_ETH_FILTER_ETHERTYPE, C.RTE_ETH_FILTER_ADD, filter)
		if ok ~= 0 and ok ~= -38 then -- -38 means duplicate filter for some reason
			log:warn("l2 filter error: " .. strError(ok))
		end
	end
end


--- Filter PTP UDP timestamp packets by inspecting the PTP version and type field.
--- Packets with PTP version 2 are matched with this filter.
--- You can also use the UDP port to filter timestamped packets if you do not send other
--- packets to this port.
--- Caution: broken on i40e, see i40e-driver docs and timestamper for a work-around
--- @param queue the queue to send packets to
--- @param type the PTP type to look for, default = 0
--- @param ver the PTP version to look for, default = 2
function dev:filterUdpTimestamps(queue, ptpType, ver)
	if type(queue) == "table" then
		queue = queue.qid
	end
	if queue == 0 then
		return
	end
	ptpType = ptpType or 0
	ver = ver or 2
	local filter = ffi.new("struct rte_eth_fdir_filter", {
		soft_id = 1,
		input = {
			-- explicitly only matching UDP flows here would be better
			-- however, this is no longer possible with the dpdk 2.x filter api :(
			-- it can no longer match only the protocol type while ignoring port numbers...
			-- (and reconfiguring the filter for ports all the time is annoying)
			flow_type = dpdkc.RTE_ETH_FLOW_IPV4,
			flow = {
			},
			flow_ext = {
				vlan_tci = 0,
				flexbytes = {ptpType, ver},
				is_vf = 0,
				dst_id = 0,
			},
		},
		action = {
			rx_queue = queue
		},
	})
	local err = C.rte_eth_dev_filter_ctrl(self.id, C.RTE_ETH_FILTER_FDIR, C.RTE_ETH_FILTER_ADD, filter)
	checkDpdkError(err, "setting fdir filter")
end

--- Prints all fdir filter informations for debugging purposes.
function dev:dumpFilters()
	C.fdir_get_infos(self.id)
end

--- Install a 5-tuple filter on the NIC.
--- @param filter, a table containing the following fields
---   all header fields default to 0 if not provided
---   all masks to all bits set if a value is provided, to 0 otherwise
---     srcIp, dstIp: IP addresses as strings
---     srcIpMask, dstIpMask: IP address masks as strings
---     srcPort, dstPort: L4 ports as numbers
---     srcPortMask, dstPortMask: port masks
---     proto: the L4 protocol id
---     protoMask: protocol mask
---     priority: the filter priority (see NIC specs for details), default = 1
--- @param queue the target queue (id or queue object)
function dev:fiveTupleFilter(filter, queue)
	local filter = ffi.new("struct rte_eth_ntuple_filter", {
		flags = 31, -- five-tuple
		dst_ip = filter.dstIp and parseIPAddress(filter.dstIp) or 0,
		dst_ip_mask = filter.dstIpMask and parseIPAddress(filter.dstIpMask) or filter.dstIp and 0xFFFFFFFF or 0,
		src_ip = filter.srcIp and parseIPAddress(filter.srcIp) or 0,
		src_ip_mask = filter.srcIpMask and parseIPAddress(filter.srcIpMask) or filter.srcIp and 0xFFFFFFFF or 0,
		dst_port = filter.dstPort or 0,
		dst_port_mask = filter.dstPortMask or filter.dstPort and 0xFFFF or 0,
		src_port = filter.srcPort or 0,
		src_port_mask = filter.srcPortMask or filter.srcPort and 0xFFFF or 0,
		proto = filter.proto or 0,
		proto_mask = filter.protoMask or filter.proto and 0xFF or 0,
		priority = filter.priority or 1,
		queue = type(queue) == "number" and queue or queue.qid
	})
	local err = C.rte_eth_dev_filter_ctrl(self.id, C.RTE_ETH_FILTER_NTUPLE, C.RTE_ETH_FILTER_ADD, filter)
	return checkDpdkError(err, "setting 5tuple filter")
end

local mod = {}


local ffi = require "ffi"
local log = require "log"
local device = require "device"

local dev = device.__devicePrototype

ffi.cdef[[

//---------------------------Generic flow API-------------------------------------------
//Full documentation in rte_flow.h

// Flow rule attributes
// Priorities are set on two levels: per group and per rule within groups.
// Lower values denote higher priority, the highest priority for both levels is 0, so that a rule with priority 0 in group 8 is always
// matched after a rule with priority 8 in group 0
//
// If a packet is matched by several rules of a given group for a given priority level, the outcome is undefined. It can take any path,
// may be duplicated or even cause unrecoverable errors
// One of ingress or egress must be specified, specifiying both may be supported
struct rte_flow_attr {
        uint32_t group; /**< Priority group */
        uint32_t priority; /**< Priority level within group */
        uint32_t ingress:1; /**< Rule applies to ingress traffic */
        uint32_t egress:1; /**< Rule applies to egress traffic */
        uint32_t reserved:30; /**< Reserved, must be zero */
};

// Action types
// Each possible action is represented by a type. Some have associated configuration structures. Several actions combined in a list can be affected
// to a flow rule. That list is not ordered.
// They fall in three categories:
//	- Terminating actions (such as QUEUE, DROP, RSS, PF, VF) that prevent processing matched packets by subsequent flow rules, unless overridden with PASSTHRU.
//	- Non terminating actions (PASSTHRU, DUP) that leave matched packets up for additional processing by subsequent flow rules.
//	- Other non terminating meta actions that do not affect the fate of packets (END, VOID, MARK, FLAG, COUNT).
//
// When several actions are combined in a flow rule, they should all have different types (e.g. dropping a packet twice is not possible).
// Only the last action of a given type is taken into account. PMDs still perform error checking on the entire list.
// Note that PASSTHRU is the only action able to override a terminating rule
enum rte_flow_action_type {
        RTE_FLOW_ACTION_TYPE_END, /**< META, End marker for action lists. Prevents further processing of actions, thereby ending the list */
        RTE_FLOW_ACTION_TYPE_VOID, /**< META, Used as a placeholder for convenience. It is ignored and simply discarded by PMDs */
        RTE_FLOW_ACTION_TYPE_PASSTHRU, /**< Leaves packets up for additional processing by subsequent flow rules. This is the default when a
	rule does not contain a terminating action, but can be specified to force a rule to become non-terminating */
        RTE_FLOW_ACTION_TYPE_MARK, /**< META, Attaches an integer value to packets and sets PKT_RX_FDIR and PKT_RX_FDIR_ID mbuf flags */
        RTE_FLOW_ACTION_TYPE_FLAG, /**< META, Flags packets. Similar to MARK without a specific value; only sets the PKT_RX_FDIR mbuf flag */
        RTE_FLOW_ACTION_TYPE_QUEUE, /**< Assigns packets to a given queue index */
        RTE_FLOW_ACTION_TYPE_DROP, /**< Drops packets. PASSTHRU overrides this action if both are specified */
        RTE_FLOW_ACTION_TYPE_COUNT, /**< Enables counters for this rule. These counters can be retrieved and reset through rte_flow_query(),
	see struct rte_flow_query_count */
        RTE_FLOW_ACTION_TYPE_DUP, /**< Duplicates packets to a given queue index. This is normally combined with QUEUE, however when used alone,
	it is actually similar to QUEUE + PASSTHRU */
        RTE_FLOW_ACTION_TYPE_RSS, /**< Similar to QUEUE, except RSS is additionally performed on packets to spread them among several queues
	according to the provided parameters */
        RTE_FLOW_ACTION_TYPE_PF, /**< Redirects packets to the physical function (PF) of the current device */
        RTE_FLOW_ACTION_TYPE_VF, /**< Redirects packets to the virtual function (VF) of the current device with the specified ID */
};

// Definition of a single action. A list of actions is terminated by a END action.
// For simple actions without a configuration structure, conf remains NULL
struct rte_flow_action {
        enum rte_flow_action_type type; /**< Action type */
        const void *conf; /**< ointer to action configuration structure */
};

// Assign packets to a given queue index. Terminating by default
struct rte_flow_action_queue {
        uint16_t index; /**< Queue index to use */
};

// Matching pattern item types
// Pattern items fall in two categories:
// 	- Matching protocol headers and packet data (ANY, RAW, ETH, VLAN, IPV4, IPV6, ICMP, UDP, TCP, SCTP, VXLAN and so on), usually associated
//	with a specification structure. These must be stacked in the same order as the protocol layers to match, starting from the lowest.
// 	- Matching meta-data or affecting pattern processing (END, VOID, INVERT, PF, VF, PORT and so on), often without a specification structure.
//	Since they do not match packet contents, these can be specified anywhere within item lists without affecting others.
//
// See the description of individual types for more information. Those marked with META fall into the second category
enum rte_flow_item_type {
        RTE_FLOW_ITEM_TYPE_END, /**< META, End marker for item lists. Prevents further processing of items, thereby ending the pattern */
        RTE_FLOW_ITEM_TYPE_VOID, /**< META, Used as a placeholder for convenience. It is ignored and simply discarded by PMDs */
        RTE_FLOW_ITEM_TYPE_INVERT, /**< META, Inverted matching, i.e. process packets that do not match the pattern */
        RTE_FLOW_ITEM_TYPE_ANY, /**< Matches any protocol in place of the current layer, a single ANY may also stand for several protocol layers */
        RTE_FLOW_ITEM_TYPE_PF, /**< META, Matches packets addressed to the physical function of the device.
	If the underlying device function differs from the one that would normally receive the matched traffic, specifying this item prevents it from
	reaching that device unless the flow rule contains a PF action. Packets are not duplicated between device instances by default */
        RTE_FLOW_ITEM_TYPE_VF, /**< META, Matches packets addressed to a virtual function ID of the device.
	If the underlying device function differs from the one that would normally receive the matched traffic, specifying this item prevents it from
	reaching that device unless the flow rule contains a VF action. Packets are not duplicated between device instances by default */
        RTE_FLOW_ITEM_TYPE_PORT, /**< META, Matches packets coming from the specified physical port of the underlying device.
	The first PORT item overrides the physical port normally associated with the specified DPDK input port (port_id). This item can be provided
	several times to match additional physical ports */
        RTE_FLOW_ITEM_TYPE_RAW, /**< Matches a byte string of a given length at a given offset */
        RTE_FLOW_ITEM_TYPE_ETH, /**< Matches an Ethernet header */
        RTE_FLOW_ITEM_TYPE_VLAN, /**< Matches an 802.1Q/ad VLAN tag */
        RTE_FLOW_ITEM_TYPE_IPV4, /**< Matches an IPv4 header */
        RTE_FLOW_ITEM_TYPE_IPV6, /**< Matches an IPv6 header */
        RTE_FLOW_ITEM_TYPE_ICMP, /**< Matches an ICMP header */
        RTE_FLOW_ITEM_TYPE_UDP, /**< Matches a UDP header */
        RTE_FLOW_ITEM_TYPE_TCP, /**< Matches a TCP header */
        RTE_FLOW_ITEM_TYPE_SCTP, /**< Matches a SCTP header */
        RTE_FLOW_ITEM_TYPE_VXLAN, /**< Matches a VXLAN header */
        RTE_FLOW_ITEM_TYPE_E_TAG, /**< Matches a E_TAG header */
        RTE_FLOW_ITEM_TYPE_NVGRE, /**< Matches a NVGRE header */
        RTE_FLOW_ITEM_TYPE_MPLS, /**< Matches a MPLS header */
        RTE_FLOW_ITEM_TYPE_GRE, /**< Matches a GRE header. */
	RTE_FLOW_ITEM_TYPE_FUZZY, /**< Fuzzy pattern match, normally faster than default.
	This is for devices that support fuzzy matching option. Usually a fuzzy matching is fast but the cost is accuracy */
};

// Matching pattern item definition
struct rte_flow_item {
        enum rte_flow_item_type type; /**< Item type */
        const void *spec; /**< Pointer to item specification structure */
        const void *last; /**< Defines an inclusive range (spec to last) */
        const void *mask; /**< Bit-mask applied to spec and last */
};

// Matches a byte string of a given length at a given offset
struct rte_flow_item_raw {
        uint32_t relative:1;
	/**< Interpret offset either absolute (start of packet) or relative to the
	previous flow item */
        uint32_t search:1; /**< Search for the pattern beginning from offset as the starting point */
        uint32_t reserved:30; /**< Reserved must be set to zero */
        int32_t offset; /**< Absolute or relative offset for pattern */
        uint16_t limit; /**< Limit for search area. Ignored if search is not enabled */
        uint16_t length; /**< Length of the pattern */
        uint8_t pattern[]; /**< Byte string to look for */
};


struct ether_addr {
        uint8_t addr_bytes[6]; /**< Ethernet address */
} __attribute__((__packed__));

// Matches an ethernet header
struct rte_flow_item_eth {
        struct ether_addr dst; /**< Destination MAC */
        struct ether_addr src; /**< Source MAC */
        uint16_t type; /**< EtherType */
};

// UDP header
struct udp_hdr {
	uint16_t src_port; /**< UDP source port */
	uint16_t dst_port; /**< UDP destination port */
	uint16_t dgram_len; /**< UDP datagram length */
	uint16_t dgram_cksum; /**< UDP datagram checksum */
} __attribute__((__packed__));

// Matches an UDP header
struct rte_flow_item_udp {
	struct udp_hdr hdr; /**< Header definition */
};

// IPv4 header
struct ipv4_hdr {
	uint8_t  version_ihl; /**< Version and header length. 4 bit each */
	uint8_t  type_of_service; /**< Type of service */
	uint16_t total_length; /**< Length of packet */
	uint16_t packet_id; /**< Identification */
	uint16_t fragment_offset; /**< Fragmentation offset */
	uint8_t  time_to_live; /**< Time to live (TTL) */
	uint8_t  next_proto_id; /**< Next protocols ID */
	uint16_t hdr_checksum; /**< Header checksum */
	uint32_t src_addr; /**< Source IP address */
	uint32_t dst_addr; /**< Destination IP address */
} __attribute__((__packed__));

// Matches an IPv4 header
struct rte_flow_item_ipv4 {
	struct ipv4_hdr hdr; /**< Header definition */
};

// Matches any protocol in place of the current layer. Can cover multiple layers
struct rte_flow_item_any {
        uint32_t num; /**< Number of layers covered */
};

enum rte_flow_error_type {
        RTE_FLOW_ERROR_TYPE_NONE, /**< No error */
        RTE_FLOW_ERROR_TYPE_UNSPECIFIED, /**< Cause is unspecified */
        RTE_FLOW_ERROR_TYPE_HANDLE, /**< Handle of flow rule */
        RTE_FLOW_ERROR_TYPE_ATTR_GROUP, /**< Group field */
        RTE_FLOW_ERROR_TYPE_ATTR_PRIORITY, /**< Priority field */
        RTE_FLOW_ERROR_TYPE_ATTR_INGRESS, /**< Ingress field */
        RTE_FLOW_ERROR_TYPE_ATTR_EGRESS, /**< Egress field */
        RTE_FLOW_ERROR_TYPE_ATTR, /**< Attributes structure */
        RTE_FLOW_ERROR_TYPE_ITEM_NUM, /**< Pattern length */
        RTE_FLOW_ERROR_TYPE_ITEM, /**< Specific pattern item */
        RTE_FLOW_ERROR_TYPE_ACTION_NUM, /**< Number of actions */
        RTE_FLOW_ERROR_TYPE_ACTION, /**< Specific action */
};

// Verbose error structure definition
struct rte_flow_error {
        enum rte_flow_error_type type; /**< Cause field and error types */
        const void *cause; /**< Object responsible for the error */
        const char *message; /**< Human-readable error message */
};

// Handle which is returned by rte_flow_create. Can be used by rte_flow_destroy to delete the associated flow rule
struct rte_flow;

//Destroy a flow rule on a given port
int rte_flow_destroy(uint8_t port_id, struct rte_flow *flow, struct rte_flow_error *error);

// Flush all filters on a device
int rte_flow_flush(uint8_t port_id, struct rte_flow_error * error);

// Check whether a flow rule can be created on a given port
int rte_flow_validate(uint8_t port_id, const struct rte_flow_attr * attr, const struct rte_flow_item pattern[], const struct rte_flow_action actions[], struct rte_flow_error * error);

// Create a flow rule on a given port
struct rte_flow* rte_flow_create(uint8_t port_id, const struct rte_flow_attr *  attr, const struct rte_flow_item pattern[], const struct rte_flow_action actions[], struct rte_flow_error * error);

]]

local C = ffi.C

local flowError = {
        [C.RTE_FLOW_ERROR_TYPE_NONE] = "No error",
        [C.RTE_FLOW_ERROR_TYPE_UNSPECIFIED] = "Cause unspecified",
        [C.RTE_FLOW_ERROR_TYPE_HANDLE] = "Flow rule (handle)",
        [C.RTE_FLOW_ERROR_TYPE_ATTR_GROUP] = "Group field",
        [C.RTE_FLOW_ERROR_TYPE_ATTR_PRIORITY] = "Priority field",
        [C.RTE_FLOW_ERROR_TYPE_ATTR_INGRESS] = "Ingress field",
        [C.RTE_FLOW_ERROR_TYPE_ATTR_EGRESS] = "Egress field",
        [C.RTE_FLOW_ERROR_TYPE_ATTR] = "Attributes structure",
        [C.RTE_FLOW_ERROR_TYPE_ITEM_NUM] = "Pattern length",
        [C.RTE_FLOW_ERROR_TYPE_ITEM] = "Specific pattern item",
        [C.RTE_FLOW_ERROR_TYPE_ACTION_NUM] = "Number of actions",
        [C.RTE_FLOW_ERROR_TYPE_ACTION] = "Specific action"
}


--- Generic filter which can filter packets by their ethertype
--- This filter can be easily changed to also match based on IP addresses
--- Caution: This uses the relativly new filter API, it might be unsupported on some devices
--- @param etype the ethertype to be matched (host byte order for compatability)
--- @param queue the recieve queue to which the packet should be directed
--- @param etypemask all unmasked bits can have any values, default = 0xffff (perfect matching) (host byte order)
--- @param priority the priority within a group, 0 is highest priority, default 0
--- @param group all groups are checked squentially starting with group 0, default 0
function dev:l2GenericFilter(etype, queue, etypemask, priority, group)
        log:info("Using generic filter")
        if type(queue) == "table" then
                if queue.dev.id ~= self.id then
                        log:fatal("Queue must belong to the device being configured")
                end
                queue = queue.qid
        end

	priority = priority or 0
	group = group or 0
	etypemask = etypemask or 0xffff

	if queue == self.DROP then
		flags = RTE_ETHTYPE_FLAGS_DROP
		log:err("DROP")
	end

	-- set attributes
	-- more than one group and priority might be unsupported
        local flow_attr = ffi.new("struct rte_flow_attr", { group = group, priority = priority, ingress = 1, egress = 0, reserved = 0 })

	-- set appropriate actions
        local action_array = ffi.new("struct rte_flow_action[2]", {
                ffi.new("struct rte_flow_action",
                {
                        type = C.RTE_FLOW_ACTION_TYPE_QUEUE,
                        conf = ffi.new("struct rte_flow_action_queue", { index = queue })
                }),
                ffi.new("struct rte_flow_action", { type = C.RTE_FLOW_ACTION_TYPE_END })
        })

	-- set the flow items (filters)
	-- we do not want to match based on IP addresses, default of the flow API would be perfect matching
        local ether_addr = ffi.new("struct ether_addr", { addr_bytes = "\x00\x00\x00\x00\x00\x00" })

        local item_array = ffi.new("struct rte_flow_item[2]", {
                ffi.new("struct rte_flow_item", {
                        type = C.RTE_FLOW_ITEM_TYPE_ETH,
			-- for interesting reasons we must convert etype to network byte order and must not do the same for etypemask
                        spec = ffi.new("struct rte_flow_item_eth", { dst = ether_addr, src = ether_addr, type = hton16(etype) }),
                        mask = ffi.new("struct rte_flow_item_eth", { dst = ether_addr, src = ether_addr, type = etypemask })
                }),
                ffi.new("struct rte_flow_item", { type = C.RTE_FLOW_ITEM_TYPE_END })
        })

	-- error struct
        local flow_error = ffi.new("struct rte_flow_error")

        local ok = C.rte_flow_validate(self.id, flow_attr, item_array, action_array, flow_error)
        if ok ~= 0 then
                log:warn("Filter validation failed. Exit code: " .. ok .. ". Root cause: " .. flowError[tonumber(flow_error.type)])
                if flow_error.message ~= nil then
                        log:warn("Error message:")
                        log:warn("\t" .. ffi.string(flow_error.message))
                end
        end
        if ok == 0 then
                log:info("Setting up filter")
                local handle = C.rte_flow_create(self.id, flow_attr, item_array, action_array, flow_error)
                log:info( handle ~= nil and green("SUCCESS") or red("FAILED") )
        end
end


--- Generic filter which can filter UDP over IPv4 packets
--- See the sections which were commented out for more exact matching
--- Caution: This uses the relativly new filter API, it might be unsupported on some devices
--- @param queue the recieve queue to which the packet should be directed
--- @param priority the priority within a group, 0 is highest priority, default 0
--- @param group all groups are checked squentially starting with group 0, default 0
function dev:UdpGenericFilter(queue, priority, group)
        log:info("Using generic filter")
        if type(queue) == "table" then
                if queue.dev.id ~= self.id then
                        log:fatal("Queue must belong to the device being configured")
                end
                queue = queue.qid
        end

	priority = priority or 0
	group = group or 0

	if queue == self.DROP then
		flags = RTE_ETHTYPE_FLAGS_DROP
		log:err("DROP")
	end

	-- set attributes

        local flow_attr = ffi.new("struct rte_flow_attr", { group = 0, priority = priority, ingress = 1, egress = 0, reserved = 0 })

	-- set appropriate actions
        local action_array = ffi.new("struct rte_flow_action[2]", {
                ffi.new("struct rte_flow_action",
                {
                        type = C.RTE_FLOW_ACTION_TYPE_QUEUE,
                        conf = ffi.new("struct rte_flow_action_queue", { index = queue })
                }),
                ffi.new("struct rte_flow_action", { type = C.RTE_FLOW_ACTION_TYPE_END })
        })

	-- some NICs may support omitting underlying layers, e.g. just use UDP, END instead of ETH, IPV4, UDP, END
	-- at least for the ConnectX4-Lx this is not supported and results in an unsupported item error which is misleading
	local item_array = ffi.new("struct rte_flow_item[4]", {
		ffi.new("struct rte_flow_item", {type = C.RTE_FLOW_ITEM_TYPE_ETH}),
		ffi.new("struct rte_flow_item", {type = C.RTE_FLOW_ITEM_TYPE_IPV4}),
		ffi.new("struct rte_flow_item", {
			type = C.RTE_FLOW_ITEM_TYPE_UDP,

		-- uncomment this section for more specific filtering
--			spec = ffi.new("struct rte_flow_item_ipv4", {
--				hdr = {
--					src_port = 0x0000,
--					dst_port = 0x0000,
--					dgram_len = 0x0000,
--					dgram_cksum = 0x0000
--				}
--			}),
--			mask = ffi.new("struct rte_flow_item_udp", {
--				hdr = {
--					src_port = 0x0000,
--					dst_port = 0x0000,
--					dgram_len = 0x0000,
--					dgram_cksum = 0x0000
--				}
--			})
		}),
		ffi.new("struct rte_flow_item", { type = C.RTE_FLOW_ITEM_TYPE_END })
	})

	-- error struct
        local flow_error = ffi.new("struct rte_flow_error")

        local ok = C.rte_flow_validate(self.id, flow_attr, item_array, action_array, flow_error)
        if ok ~= 0 then
                log:warn("Filter validation failed. Exit code: " .. ok .. ". Root cause: " .. flowError[tonumber(flow_error.type)])
                if flow_error.message ~= nil then
                        log:warn("Error message:")
                        log:warn("\t" .. ffi.string(flow_error.message))
                end
        end
        if ok == 0 then
                log:info("Setting up filter")
                local handle = C.rte_flow_create(self.id, flow_attr, item_array, action_array, flow_error)
                log:info( handle ~= nil and green("SUCCESS") or red("FAILED") )
        end
end


return mod


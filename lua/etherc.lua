---------------------------------
--- @file etherc.lua
--- @brief Structs and functions from rte_ether.h
---------------------------------

local ffi = require "ffi"

ffi.cdef[[

//-------------------------------structs---------------------------------

/**
 * Ethernet address:
 * A universally administered address is uniquely assigned to a device by its
 * manufacturer. The first three octets (in transmission order) contain the
 * Organizationally Unique Identifier (OUI). The following three (MAC-48 and
 * EUI-48) octets are assigned by that organization with the only constraint
 * of uniqueness.
 * A locally administered address is assigned to a device by a network
 * administrator and does not contain OUIs.
 * See http://standards.ieee.org/regauth/groupmac/tutorial.html
 */
struct ether_addr {
	uint8_t addr_bytes[6]; /**< Addr bytes in tx order */
} __attribute__((__packed__));


/**
 * Ethernet header: Contains the destination address, source address
 * and frame type.
 */
struct ether_hdr {
	struct ether_addr d_addr; /**< Destination address. */
	struct ether_addr s_addr; /**< Source address. */
	uint16_t ether_type;      /**< Frame type. */
} __attribute__((__packed__));


/**
 * Ethernet VLAN Header.
 * Contains the 16-bit VLAN Tag Control Identifier and the Ethernet type
 * of the encapsulated frame.
 */
struct vlan_hdr {
	uint16_t vlan_tci; /**< Priority (3) + CFI (1) + Identifier Code (12) */
	uint16_t eth_proto;/**< Ethernet type of encapsulated frame. */
} __attribute__((__packed__));


/**
 * VXLAN protocol header.
 * Contains the 8-bit flag, 24-bit VXLAN Network Identifier and
 * Reserved fields (24 bits and 8 bits)
 */
struct vxlan_hdr {
	uint32_t vx_flags; /**< flag (8) + Reserved (24). */
	uint32_t vx_vni;   /**< VNI (24) + Reserved (8). */
} __attribute__((__packed__));


//--------------------------------functions------------------------------

/**
 * Check if two Ethernet addresses are the same.
 *
 * @param ea1
 *  A pointer to the first ether_addr structure containing
 *  the ethernet address.
 * @param ea2
 *  A pointer to the second ether_addr structure containing
 *  the ethernet address.
 *
 * @return
 *  True  (1) if the given two ethernet address are the same;
 *  False (0) otherwise.
 */
static inline int is_same_ether_addr(const struct ether_addr *ea1,
				     const struct ether_addr *ea2);


/**
 * Check if an Ethernet address is filled with zeros.
 *
 * @param ea
 *   A pointer to a ether_addr structure containing the ethernet address
 *   to check.
 * @return
 *   True  (1) if the given ethernet address is filled with zeros;
 *   false (0) otherwise.
 */
static inline int is_zero_ether_addr(const struct ether_addr *ea);


/**
 * Check if an Ethernet address is a unicast address.
 *
 * @param ea
 *   A pointer to a ether_addr structure containing the ethernet address
 *   to check.
 * @return
 *   True  (1) if the given ethernet address is a unicast address;
 *   false (0) otherwise.
 */
static inline int is_unicast_ether_addr(const struct ether_addr *ea);


/**
 * Check if an Ethernet address is a multicast address.
 *
 * @param ea
 *   A pointer to a ether_addr structure containing the ethernet address
 *   to check.
 * @return
 *   True  (1) if the given ethernet address is a multicast address;
 *   false (0) otherwise.
 */
static inline int is_multicast_ether_addr(const struct ether_addr *ea);


/**
 * Check if an Ethernet address is a broadcast address.
 *
 * @param ea
 *   A pointer to a ether_addr structure containing the ethernet address
 *   to check.
 * @return
 *   True  (1) if the given ethernet address is a broadcast address;
 *   false (0) otherwise.
 */
static inline int is_broadcast_ether_addr(const struct ether_addr *ea);


/**
 * Check if an Ethernet address is a universally assigned address.
 *
 * @param ea
 *   A pointer to a ether_addr structure containing the ethernet address
 *   to check.
 * @return
 *   True  (1) if the given ethernet address is a universally assigned address;
 *   false (0) otherwise.
 */
static inline int is_universal_ether_addr(const struct ether_addr *ea);


/**
 * Check if an Ethernet address is a locally assigned address.
 *
 * @param ea
 *   A pointer to a ether_addr structure containing the ethernet address
 *   to check.
 * @return
 *   True  (1) if the given ethernet address is a locally assigned address;
 *   false (0) otherwise.
 */
static inline int is_local_admin_ether_addr(const struct ether_addr *ea);


/**
 * Check if an Ethernet address is a valid address. Checks that the address is a
 * unicast address and is not filled with zeros.
 *
 * @param ea
 *   A pointer to a ether_addr structure containing the ethernet address
 *   to check.
 * @return
 *   True  (1) if the given ethernet address is valid;
 *   false (0) otherwise.
 */
static inline int is_valid_assigned_ether_addr(const struct ether_addr *ea);


/**
 * Generate a random Ethernet address that is locally administered
 * and not multicast.
 * @param addr
 *   A pointer to Ethernet address.
 */
static inline void eth_random_addr(uint8_t *addr);


/**
 * Fast copy an Ethernet address.
 *
 * @param ea_from
 *   A pointer to a ether_addr structure holding the Ethernet address to copy.
 * @param ea_to
 *   A pointer to a ether_addr structure where to copy the Ethernet address.
 */
static inline void ether_addr_copy(const struct ether_addr *ea_from,
				   struct ether_addr *ea_to);


/**
 * Format 48bits Ethernet address in pattern xx:xx:xx:xx:xx:xx.
 *
 * @param buf
 *   A pointer to buffer contains the formatted MAC address.
 * @param size
 *   The format buffer size.
 * @param eth_addr
 *   A pointer to a ether_addr structure.
 */
static inline void
ether_format_addr(char *buf, uint16_t size,
		  const struct ether_addr *eth_addr);


/**
 * Extract VLAN tag information into mbuf
 *
 * Software version of VLAN stripping
 *
 * @param m
 *   The packet mbuf.
 * @return
 *   - 0: Success
 *   - 1: not a vlan packet
 */
static inline int rte_vlan_strip(struct rte_mbuf *m);


/**
 * Insert VLAN tag into mbuf.
 *
 * Software version of VLAN unstripping
 *
 * @param m
 *   The packet mbuf.
 * @return
 *   - 0: On success
 *   -EPERM: mbuf is is shared overwriting would be unsafe
 *   -ENOSPC: not enough headroom in mbuf
 */
static inline int rte_vlan_insert(struct rte_mbuf **m);


]]

return ffi.C

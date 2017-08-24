---------------------------------
--- @file headerc.lua
--- @brief Structures and functions (checksum computation) related to headers
---------------------------------

local ffi = require "ffi"

ffi.cdef[[

//Contains code from these files: 
//rte_ip.h
//rte_icmp.h
//rte_udp.h
//rte_tcp.h
//rte_sctp.h

//--------------------------structs-----------------------

/**
 * IPv4 Header
 */
struct ipv4_hdr {
	uint8_t  version_ihl;		/**< version and header length */
	uint8_t  type_of_service;	/**< type of service */
	uint16_t total_length;		/**< length of packet */
	uint16_t packet_id;		/**< packet ID */
	uint16_t fragment_offset;	/**< fragmentation offset */
	uint8_t  time_to_live;		/**< time to live */
	uint8_t  next_proto_id;		/**< protocol ID */
	uint16_t hdr_checksum;		/**< header checksum */
	uint32_t src_addr;		/**< source address */
	uint32_t dst_addr;		/**< destination address */
} __attribute__((__packed__));


/**
 * IPv6 Header
 */
struct ipv6_hdr {
	uint32_t vtc_flow;     /**< IP version, traffic class & flow label. */
	uint16_t payload_len;  /**< IP packet length - includes sizeof(ip_header). */
	uint8_t  proto;        /**< Protocol, next header. */
	uint8_t  hop_limits;   /**< Hop limits. */
	uint8_t  src_addr[16]; /**< IP address of source host. */
	uint8_t  dst_addr[16]; /**< IP address of destination host(s). */
} __attribute__((__packed__));


/**
 * ICMP Header
 */
struct icmp_hdr {
	uint8_t  icmp_type;   /* ICMP packet type. */
	uint8_t  icmp_code;   /* ICMP packet code. */
	uint16_t icmp_cksum;  /* ICMP packet checksum. */
	uint16_t icmp_ident;  /* ICMP packet identifier. */
	uint16_t icmp_seq_nb; /* ICMP packet sequence number. */
} __attribute__((__packed__));


/**
 * UDP Header
 */
struct udp_hdr {
	uint16_t src_port;    /**< UDP source port. */
	uint16_t dst_port;    /**< UDP destination port. */
	uint16_t dgram_len;   /**< UDP datagram length */
	uint16_t dgram_cksum; /**< UDP datagram checksum */
} __attribute__((__packed__));


/**
 * TCP Header
 */
struct tcp_hdr {
	uint16_t src_port;  /**< TCP source port. */
	uint16_t dst_port;  /**< TCP destination port. */
	uint32_t sent_seq;  /**< TX data sequence number. */
	uint32_t recv_ack;  /**< RX data acknowledgement sequence number. */
	uint8_t  data_off;  /**< Data offset. */
	uint8_t  tcp_flags; /**< TCP flags */
	uint16_t rx_win;    /**< RX flow control window. */
	uint16_t cksum;     /**< TCP checksum. */
	uint16_t tcp_urp;   /**< TCP urgent pointer, if any. */
} __attribute__((__packed__));


/**
 * SCTP Header
 */
struct sctp_hdr {
	uint16_t src_port; /**< Source port. */
	uint16_t dst_port; /**< Destin port. */
	uint32_t tag;      /**< Validation tag. */
	uint32_t cksum;    /**< Checksum. */
} __attribute__((__packed__));

//-------------------------functions-----------------------


//-----------------BEGIN-IP--------------------------------

/**
 * Process the non-complemented checksum of a buffer.
 *
 * @param buf
 *   Pointer to the buffer.
 * @param len
 *   Length of the buffer.
 * @return
 *   The non-complemented checksum.
 */
static inline uint16_t
rte_raw_cksum(const void *buf, size_t len);


/**
 * Compute the raw (non complemented) checksum of a packet.
 *
 * @param m
 *   The pointer to the mbuf.
 * @param off
 *   The offset in bytes to start the checksum.
 * @param len
 *   The length in bytes of the data to ckecksum.
 * @param cksum
 *   A pointer to the checksum, filled on success.
 * @return
 *   0 on success, -1 on error (bad length or offset).
 */
static inline int
rte_raw_cksum_mbuf(const struct rte_mbuf *m, uint32_t off, uint32_t len,
	uint16_t *cksum);


/**
 * Process the IPv4 checksum of an IPv4 header.
 *
 * The checksum field must be set to 0 by the caller.
 *
 * @param ipv4_hdr
 *   The pointer to the contiguous IPv4 header.
 * @return
 *   The complemented checksum to set in the IP packet.
 */
static inline uint16_t
rte_ipv4_cksum(const struct ipv4_hdr *ipv4_hdr);


/**
 * Process the pseudo-header checksum of an IPv4 header.
 *
 * The checksum field must be set to 0 by the caller.
 *
 * Depending on the ol_flags, the pseudo-header checksum expected by the
 * drivers is not the same. For instance, when TSO is enabled, the IP
 * payload length must not be included in the packet.
 *
 * When ol_flags is 0, it computes the standard pseudo-header checksum.
 *
 * @param ipv4_hdr
 *   The pointer to the contiguous IPv4 header.
 * @param ol_flags
 *   The ol_flags of the associated mbuf.
 * @return
 *   The non-complemented checksum to set in the L4 header.
 */
static inline uint16_t
rte_ipv4_phdr_cksum(const struct ipv4_hdr *ipv4_hdr, uint64_t ol_flags);


/**
 * Process the IPv4 UDP or TCP checksum.
 *
 * The IPv4 header should not contains options. The IP and layer 4
 * checksum must be set to 0 in the packet by the caller.
 *
 * @param ipv4_hdr
 *   The pointer to the contiguous IPv4 header.
 * @param l4_hdr
 *   The pointer to the beginning of the L4 header.
 * @return
 *   The complemented checksum to set in the IP packet.
 */
static inline uint16_t
rte_ipv4_udptcp_cksum(const struct ipv4_hdr *ipv4_hdr, const void *l4_hdr);


/**
 * Process the pseudo-header checksum of an IPv6 header.
 *
 * Depending on the ol_flags, the pseudo-header checksum expected by the
 * drivers is not the same. For instance, when TSO is enabled, the IPv6
 * payload length must not be included in the packet.
 *
 * When ol_flags is 0, it computes the standard pseudo-header checksum.
 *
 * @param ipv6_hdr
 *   The pointer to the contiguous IPv6 header.
 * @param ol_flags
 *   The ol_flags of the associated mbuf.
 * @return
 *   The non-complemented checksum to set in the L4 header.
 */
static inline uint16_t
rte_ipv6_phdr_cksum(const struct ipv6_hdr *ipv6_hdr, uint64_t ol_flags);


/**
 * Process the IPv6 UDP or TCP checksum.
 *
 * The IPv4 header should not contains options. The layer 4 checksum
 * must be set to 0 in the packet by the caller.
 *
 * @param ipv6_hdr
 *   The pointer to the contiguous IPv6 header.
 * @param l4_hdr
 *   The pointer to the beginning of the L4 header.
 * @return
 *   The complemented checksum to set in the IP packet.
 */
static inline uint16_t
rte_ipv6_udptcp_cksum(const struct ipv6_hdr *ipv6_hdr, const void *l4_hdr);

//-----------------END-IP--------------------------------
]]

return ffi.C


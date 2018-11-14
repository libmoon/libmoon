#ifndef MG_PKTSIZEDRING_H
#define MG_PKTSIZEDRING_H

#include <cstdint>

#include <rte_config.h>
#include <rte_common.h>
#include <rte_ring.h>
#include <rte_mbuf.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PS_RING_SIZE_LIMIT 268435455

struct ps_ring
{
	struct rte_ring* ring;
	uint32_t capacity;
};

struct ps_ring* create_psring(uint32_t capacity, int32_t socket);

/**
 * The difference between bulk and burst is when n>1.  In those
 * cases bulk mode will only en/dequeue a full batch.  In burst
 * mode it will enqueue whatever there is space for, or dequeue
 * as many as are available, up to n.
 */
int psring_enqueue_bulk(struct ps_ring* psr, struct rte_mbuf** obj, uint32_t n);
int psring_enqueue_burst(struct ps_ring* psr, struct rte_mbuf** obj, uint32_t n);
int psring_enqueue(struct ps_ring* psr, struct rte_mbuf* obj);
int psring_dequeue_bulk(struct ps_ring* psr, struct rte_mbuf** obj, uint32_t n);
int psring_dequeue_burst(struct ps_ring* psr, struct rte_mbuf** obj, uint32_t n);
int psring_dequeue(struct ps_ring* psr, struct rte_mbuf** obj);
int psring_count(struct ps_ring* psr);
int psring_capacity(struct ps_ring* psr);


#ifdef __cplusplus
}
#endif

#endif



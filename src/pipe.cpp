#include <cstdint>
#include <string>
#include <cstring>

#include "spsc-queue/readerwriterqueue.h"
#include "concurrentqueue/concurrentqueue.h"

using namespace moodycamel;

extern "C" {

	ReaderWriterQueue<void*>* pipe_spsc_new(int capacity) {
		return new ReaderWriterQueue<void*>(capacity);
	}

	void pipe_spsc_delete(ReaderWriterQueue<void*>* queue) {
		delete queue;
	}

	void pipe_spsc_enqueue(ReaderWriterQueue<void*>* queue, void* data) {
		queue->enqueue(data);
	}

	bool pipe_spsc_try_enqueue(ReaderWriterQueue<void*>* queue, void* data) {
		return queue->try_enqueue(data);
	}

	void* pipe_spsc_try_dequeue(ReaderWriterQueue<void*>* queue) {
		void* data;
		bool ok = queue->try_dequeue(data);
		return ok ? data : nullptr;
	}

	size_t pipe_spsc_count(ReaderWriterQueue<void*>* queue) {
		return queue->size_approx();
	}

	ConcurrentQueue<void*>* pipe_mpmc_new(int capacity) {
		return new ConcurrentQueue<void*>(capacity);
	}

	void pipe_mpmc_delete(ConcurrentQueue<void*>* queue) {
		delete queue;
	}

	void pipe_mpmc_enqueue(ConcurrentQueue<void*>* queue, void* data) {
		queue->enqueue(data);
	}

	bool pipe_mpmc_try_enqueue(ConcurrentQueue<void*>* queue, void* data) {
		return queue->try_enqueue(data);
	}

	void* pipe_mpmc_try_dequeue(ConcurrentQueue<void*>* queue) {
		void* data;
		bool ok = queue->try_dequeue(data);
		return ok ? data : nullptr;
	}

	size_t pipe_mpmc_count(ConcurrentQueue<void*>* queue) {
		return queue->size_approx();
	}
}


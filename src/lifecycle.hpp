#ifndef LIFECYCLE_H__
#define LIFECYCLE_H__

namespace libmoon {
	void install_signal_handlers();
	uint8_t is_running(uint32_t extra_time);
}

#endif

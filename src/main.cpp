#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <iostream>

extern "C" {
#include <lauxlib.h>
#include <lualib.h>
}

#include "task.hpp"
#include "lifecycle.hpp"

namespace phobos {
	void print_usage() {
		std::cout << "Usage: phobos <script> [--dpdk-config=<config>] [script args...]\n" << std::endl;
	}
}

int main(int argc, char **argv) {
	if (argc < 2) {
		phobos::print_usage();
		return 1;
	}
	phobos::install_signal_handlers();
	lua_State* L = phobos::launch_lua();
	if (!L) {
		return -1;
	}
	lua_getglobal(L, "main");
	lua_pushstring(L, "master");
	for (int i = 0; i < argc; i++) {
		lua_pushstring(L, argv[i]);
	}
	if (lua_pcall(L, argc + 1, 0, 0)) {
		std::cerr << "Lua error: " << lua_tostring(L, -1) << std::endl;
		return -1;
	}
	return 0;
}


// vim:ts=4:sw=4:noexpandtab

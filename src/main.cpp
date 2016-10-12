#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <limits.h>
#include <sys/stat.h>

#include <iostream>
#include <vector>
#include <sstream>
#include <stdexcept>

extern "C" {
#include <lauxlib.h>
#include <lualib.h>
}

#include "main.hpp"
#include "task.hpp"
#include "lifecycle.hpp"

namespace libmoon {

	const char* base_dir;
	const char* extra_lua_path;

	void find_base_dir_fail() {
		std::cerr << "Could not find base dir" << std::endl;
		std::abort();
	}

	bool is_base_dir(std::string const& path) {
		struct stat buf;
		// having one of these files in some random folder might be just co-incidence
		// these are reasonable filenames for some libmoon-related scripts...
		// so we just check for both
		return ::stat((path + "/lua/libmoon.lua").c_str(), &buf) == 0
		    && ::stat((path + "/lua/main.lua").c_str(), &buf) == 0;
	}

	// can't be done in Lua because we know nothing, not even where ljsyscall is
	std::string find_base_dir(std::vector<std::string> check_dirs) {
		char buf[PATH_MAX];
		if (::readlink("/proc/self/exe", buf, PATH_MAX) == -1) {
			find_base_dir_fail();
		}
		std::string exec_path(buf);
		// strip the binary name
		size_t dir_pos = exec_path.find_last_of("/");
		if (dir_pos == std::string::npos) {
			find_base_dir_fail();
		}
		exec_path = exec_path.substr(0, dir_pos + 1);
		for (auto dir: check_dirs) {
			std::string path = (dir[0] == '/') ? dir : exec_path + dir;
			if (is_base_dir(path)) {
				return path;
			}
		}
		find_base_dir_fail();
		__builtin_unreachable();
	}

	void setup_base_dir(std::vector<std::string> check_dirs, bool check_cwd = false) {
		if (check_cwd) {
			char buf[PATH_MAX];
			if (!getcwd(buf, PATH_MAX)) {
				find_base_dir_fail();
			}
			check_dirs.insert(check_dirs.begin(), buf);
		}
		// make a copy, we need this in all new threads
		base_dir = (new std::string(find_base_dir(check_dirs)))->c_str();
	}

	void setup_extra_lua_path(std::vector<std::string> paths) {
		if (!base_dir) {
			throw std::logic_error("base_dir must be set first");
		}
		std::stringstream ss;
		for (auto path: paths) {
			ss << base_dir << "/" << path << ";";
		}
		extra_lua_path = (new std::string(ss.str()))->c_str();
	}

	void print_usage(const std::string app_name) {
		std::cout << "Usage: " << app_name << " <script> [--dpdk-config=<config>] [script args...]\n" << std::endl;
	}

	int main(int argc, char** argv) {
		if (argc < 2) {
			libmoon::print_usage(argv[0]);
			return 1;
		}
		libmoon::install_signal_handlers();
		lua_State* L = libmoon::launch_lua();
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
}

#ifndef LIBMOON_BUILD_LIB
int main(int argc, char** argv) {
	// TODO: get the install-path via cmake
	libmoon::setup_base_dir({".", "..", "/usr/local/lib/libmoon"}, true);
	return libmoon::main(argc, argv);
}
#endif


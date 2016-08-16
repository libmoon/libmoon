#include <cstdint>
#include <cstring>
#include <iostream>
#include <memory>
#include <string>
#include <sstream>

#include <unistd.h>
#include <limits.h>
#include <sys/stat.h>

extern "C" {
#include <lauxlib.h>
#include <lualib.h>
}

#include <rte_launch.h>

#include "task.hpp"

namespace phobos {

	void find_base_dir_fail() {
		std::cerr << "Could not find base dir" << std::endl;
		std::abort();
	}

	bool is_base_dir(std::string const& path) {
		struct stat buf;
		// having one of these files in some random folder might be just co-incidence
		// these are reasonable filenames for some phobos-related scripts...
		// so we just check for both
		return ::stat((path + "/lua/phobos.lua").c_str(), &buf) == 0
		    && ::stat((path + "/lua/main.lua").c_str(), &buf) == 0;
	}

	// can't be done in Lua because we know nothing, not even where ljsyscall is
	std::string find_base_dir() {
		char buf[PATH_MAX];
		if (::readlink("/proc/self/exe", buf, PATH_MAX) == -1) {
			find_base_dir_fail();
		}
		std::string path(buf);
		// check dir with the binary first
		size_t dir_pos = path.find_last_of("/");
		if (dir_pos == std::string::npos) {
			find_base_dir_fail();
		}
		path = path.substr(0, dir_pos);
		if (is_base_dir(path)) {
			return path;
		}
		// check parent dir (where we'll find it when compiling in the build dir)
		dir_pos = path.find_last_of("/");
		if (dir_pos == std::string::npos) {
			find_base_dir_fail();
		}
		path = path.substr(0, dir_pos);
		if (is_base_dir(path)) {
			return path;
		}
		// check cwd last
		if (!getcwd(buf, PATH_MAX)) {
			find_base_dir_fail();
		}
		path = buf;
		if (is_base_dir(path)) {
			return path;
		}
		find_base_dir_fail();
		__builtin_unreachable();
	}

	std::string build_lua_path() {
		std::string base = find_base_dir();
		std::stringstream ss;
		ss << "'";
		ss << base << "/lua/?.lua;";
		ss << base << "/lua/?/init.lua;";
		ss << base << "/lua/lib/?.lua;";
		ss << base << "/lua/lib/?/init.lua";
		ss << "'";
		return ss.str();
	}

	lua_State* launch_lua() {
		lua_State* L = luaL_newstate();
		luaL_openlibs(L);
		luaL_dostring(L, (std::string("package.path = package.path .. ';' .. ") + build_lua_path()).c_str());
		if (luaL_dostring(L, "require 'main'")) {
			std::cerr << "Could not run main script: " << lua_tostring(L, -1) << std::endl;
			std::abort();
		}
		return L;
	}

	int lua_core_main(void* arg) {
		std::unique_ptr<const char[]> arg_str;
		arg_str.reset(reinterpret_cast<const char*>(arg));
		lua_State* L = launch_lua();
		if (!L) {
			return -1;
		}
		lua_getglobal(L, "main");
		lua_pushstring(L, "slave");
		lua_pushstring(L, arg_str.get());
		if (lua_pcall(L, 2, 0, 0)) {
			std::cerr << "Lua error: " << lua_tostring(L, -1) << std::endl;
			return -1;
		}
		return 0;
	}

}

extern "C" {
	void launch_lua_core(int core, const char* arg) {
		size_t arg_len = strlen(arg);
		char* arg_copy = new char[arg_len + 1];
		strcpy(arg_copy, arg);
		rte_eal_remote_launch(&phobos::lua_core_main, arg_copy, core);
	}
}


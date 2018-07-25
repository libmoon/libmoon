#include <cstdint>
#include <cstring>
#include <iostream>
#include <memory>
#include <string>
#include <sstream>

extern "C" {
#include <lauxlib.h>
#include <lualib.h>
}

#include <rte_launch.h>

#include "config.h"
#include "task.hpp"
#include "main.hpp"

namespace libmoon {

	std::string build_lua_path() {
		std::string base = base_dir;
		std::stringstream ss;
		ss << "'";
		if (extra_lua_path)
			ss << extra_lua_path;
		ss << base << "/lua/?.lua;";
		ss << base << "/lua/?/init.lua;";
		ss << base << "/lua/lib/?.lua;";
		ss << base << "/lua/lib/turbo/?.lua;";
		ss << base << "/lua/lib/?/init.lua;";
		ss << "'";
		return ss.str();
	}

	lua_State* launch_lua() {
		lua_State* L = luaL_newstate();
		luaL_openlibs(L);
		luaL_dostring(L, (std::string("package.path = ") + build_lua_path() + " .. package.path" ).c_str());
		if (luaL_dostring(L, "require '" LIBMOON_LUA_MAIN_MODULE "'")) {
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
		lua_close(L);
		return 0;
	}

}

extern "C" {
	void launch_lua_core(int core, const char* arg) {
		size_t arg_len = strlen(arg);
		char* arg_copy = new char[arg_len + 1];
		strcpy(arg_copy, arg);
		rte_eal_remote_launch(&libmoon::lua_core_main, arg_copy, core);
	}
}


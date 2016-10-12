#pragma once

#include <vector>
#include <string>

namespace libmoon {
	extern const char* base_dir;
	extern const char* extra_lua_path;

	int main(int argc, char** argv);
	void setup_base_dir(std::vector<std::string> check_dirs, bool check_cwd);
	void setup_extra_lua_path(std::vector<std::string> paths);
}


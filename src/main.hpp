#pragma once

#include <vector>
#include <string>

namespace phobos {
	extern const char* base_dir;
	int main(int argc, char** argv);
	void setup_base_dir(std::vector<std::string> check_dirs, bool check_cwd);
}


CMAKE_MINIMUM_REQUIRED(VERSION 2.8)

SET(CMAKE_CXX_FLAGS "-fno-stack-protector -Wall -Wextra -Wno-unused-parameter -g -O3 -std=gnu++11 -march=native -I${CMAKE_CURRENT_SOURCE_DIR}/src")
SET(CMAKE_C_FLAGS "-fno-stack-protector -Wall -Wextra -Wno-unused-parameter -g -O3 -std=gnu11 -march=native")

SET(PRJ swap-macs)

file(GLOB SOURCES *.c *.cpp)

SET(LIBMOON_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../)

# header files for stuff that is available in libmoon
INCLUDE_DIRECTORIES(
	${LIBMOON_DIR}/deps/dpdk/x86_64-native-linuxapp-gcc/include
	${LIBMOON_DIR}/deps/luajit/src
	${LIBMOON_DIR}/lib
)

ADD_LIBRARY(${PRJ} SHARED ${SOURCES})


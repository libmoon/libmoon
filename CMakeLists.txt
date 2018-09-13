CMAKE_MINIMUM_REQUIRED(VERSION 2.8)
PROJECT(libmoon C CXX)

option(USE_MLX5 "Compile with mlx5 driver" OFF)
option(USE_MLX4 "Compile with mlx4 driver" OFF)

SET(CMAKE_CXX_FLAGS "-fno-stack-protector -Wall -Wextra -Wno-unused-parameter -g -O3 -std=gnu++11 -march=native -msse4.2")
SET(CMAKE_C_FLAGS "-fno-stack-protector -Wall -Wextra -Wno-unused-parameter -g -O3 -std=gnu11 -march=native -msse4.2")
SET(CMAKE_EXE_LINKER_FLAGS "-rdynamic") # to access functions from luajit

SET(FILES
	src/main
	src/memory
	src/task
	src/device
	src/i40e
	src/util
	src/lifecycle
	src/barrier
	src/task-results
	src/pipe
	src/lock
	src/namespaces
	src/ring
	src/kni
	src/filter
	src/pcap
	src/timestamping
	src/timestamping_i40e
	src/timestamping_ixgbe
	src/timestamping_igb
)

SET(DPDK_LIBS
	rte_net	     rte_ethdev       rte_distributor 	 rte_kni       rte_mbuf       	  rte_pmd_bond         rte_pmd_ring  	rte_power  
	rte_acl      rte_eal          rte_kvargs   	 rte_mempool   rte_mempool_ring	  rte_pmd_e1000        rte_pmd_virtio   rte_ring
	rte_cfgfile  rte_hash         rte_lpm      	 rte_meter     rte_pmd_i40e   	  rte_pmd_vmxnet3_uio  rte_sched        rte_timer
	rte_cmdline  rte_ip_frag      rte_pipeline 	 rte_pmd_ixgbe rte_mempool_stack  rte_port             rte_table        rte_pmd_bnxt
	rte_pmd_ena  rte_pmd_nfp
)

#Add Mellanox libraries if options are specified
if(USE_MLX5 OR USE_MLX4)
	SET(DPDK_LIBS ${DPDK_LIBS} ibverbs)
endif()

if(USE_MLX5)
	SET(DPDK_LIBS ${DPDK_LIBS} rte_pmd_mlx5)
endif()

if(USE_MLX4)
	SET(DPDK_LIBS ${DPDK_LIBS} rte_pmd_mlx4)
endif()

SET(LUAJIT_LIBS
	luajit-5.1
)

SET(HIGHWAYHASH_LIBS
	highwayhash
)

# add tbb
include(${CMAKE_CURRENT_SOURCE_DIR}/deps/tbb/cmake/TBBBuild.cmake)
tbb_build(TBB_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/deps/tbb CONFIG_DIR TBB_DIR)
# find the cmake configuration file
find_package(TBB)

SET(ALL_LIBS
	-Wl,--whole-archive
	${LUAJIT_LIBS}
	${HIGHWAYHASH_LIBS}
	${TBB_IMPORTED_TARGETS}
	-Wl,--start-group ${DPDK_LIBS} numa -Wl,--end-group
	pthread dl rt
	-Wl,--no-whole-archive
)

INCLUDE_DIRECTORIES(
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/x86_64-native-linuxapp-gcc/include
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/bnxt
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/ixgbe/base
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/ixgbe
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/i40e/base
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/i40e
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/e1000
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/e1000/base
	${CMAKE_CURRENT_SOURCE_DIR}/deps/luajit/src
	${CMAKE_CURRENT_SOURCE_DIR}/deps/highwayhash/highwayhash
	${CMAKE_CURRENT_SOURCE_DIR}/deps/tbb/include
	${CMAKE_CURRENT_SOURCE_DIR}/lib
	${CMAKE_CURRENT_SOURCE_DIR}/src
)

LINK_DIRECTORIES(
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/x86_64-native-linuxapp-gcc/lib
	${CMAKE_CURRENT_SOURCE_DIR}/deps/luajit/usr/local/lib
	${CMAKE_CURRENT_SOURCE_DIR}/deps/highwayhash/lib
)

IF(LIBMOON_BUILD_LIBRARY)
	ADD_DEFINITIONS(-DLIBMOON_BUILD_LIB)
	# we want libmoon.a, not liblibmoon.a
	ADD_LIBRARY(moon STATIC ${FILES})
	TARGET_LINK_LIBRARIES(moon ${ALL_LIBS})
ELSE()
	ADD_EXECUTABLE(libmoon ${FILES})
	TARGET_LINK_LIBRARIES(libmoon ${ALL_LIBS})
ENDIF()


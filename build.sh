#!/bin/bash

# TODO: this should probably be a makefile
(
cd $(dirname "${BASH_SOURCE[0]}")
git submodule update --init --recursive

NUM_CPUS=$(cat /proc/cpuinfo  | grep "processor\\s: " | wc -l)

(
cd deps/luajit
make -j $NUM_CPUS BUILDMODE=static 'CFLAGS=-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT'
make install DESTDIR=$(pwd)
)

(
cd deps/dpdk
make -j $NUM_CPUS install T=x86_64-native-linuxapp-gcc
)

(
cd lua/lib/turbo
make 2> /dev/null
if [[ $? > 0 ]]
then
	echo "Could not compile Turbo with TLS support, disabling TLS"
	echo "Install libssl-dev and OpenSSL to enable TLS support"
	make SSL=none
fi
)

(
cd build
cmake ..
make -j $NUM_CPUS
)

echo Trying to bind interfaces, this will fail if you are not root
echo Try "sudo ./bind-interfaces.sh" if this step fails
./bind-interfaces.sh
)


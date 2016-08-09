#!/bin/bash

(
cd $(dirname "${BASH_SOURCE[0]}")
cd deps/dpdk

modprobe uio
(lsmod | grep igb_uio > /dev/null) || insmod ./x86_64-native-linuxapp-gcc/kmod/igb_uio.ko

i=0
for id in $(tools/dpdk-devbind.py --status | grep -v Active | grep unused=igb_uio | cut -f 1 -d " ")
do
	if tools/dpdk-devbind.py --status | grep $id | grep -i virtio > /dev/null
	then
		echo "Found VirtIO NIC $id"
		echo "Not binding VirtIO NIC to DPDK due to buggy activity detection in dpdk-devbind.py"
		echo "Use deps/dpdk/tools/dpdk-devbind.py to bind VirtIO NICs manually"
	else
		echo "Binding interface $id to DPDK"
		tools/dpdk-devbind.py  --bind=igb_uio $id
		i=$(($i+1))
	fi
done

if [[ $i == 0 ]]
then
	echo "Could not find any inactive interfaces to bind to DPDK. Note that this script does not bind interfaces that are in use by the OS."
	echo "Delete IP addresses from interfaces you would like to use with Phobos and run this script again."
	echo "You can also use the script dpdk-devbind.py in deps/dpdk/tools manually to manage interfaces used by Phobos and the OS."
	echo "VirtIO interfaces are also ignored due to the buggy activity detection in DPDK."
fi

)


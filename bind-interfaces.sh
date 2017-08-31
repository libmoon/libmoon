#!/bin/bash

MLX5=false
MLX4=false

while :; do
        case $1 in
                -h|--help)
                        echo "Usage: <no option> bind only to uio drivers; <-m|--mlx5> additionally bind ConnectX-4 (Lx) to mlx5_core; <-n|--mlx4> additionally bind ConnectX-3 Pro to mlx4_core; <-h|--help> help"
                        exit
                        ;;
                -m|--mlx5)
                        echo "Binding applicable NICs to mlx5_core"
                        MLX5=true
                        ;;
                -n|--mlx4)
                        echo "Binding applicable NICS to mlx4_core"
                        MLX4=true
                        ;;
                -?*)
                        printf 'WARN: Unknown option (abort): %s\n' "$1" >&2
                        exit
                        ;;
                *)
                        break
        esac
        shift
done

(
cd $(dirname "${BASH_SOURCE[0]}")
cd deps/dpdk

modprobe uio
(lsmod | grep igb_uio > /dev/null) || insmod ./x86_64-native-linuxapp-gcc/kmod/igb_uio.ko

i=0
for id in $(usertools/dpdk-devbind.py --status | grep -v Active | grep -v ConnectX | grep unused=igb_uio | cut -f 1 -d " ")
do
	echo "Binding interface $id to DPDK"
	usertools/dpdk-devbind.py  --bind=igb_uio $id
	i=$(($i+1))
done


if $MLX5 ; then
	modprobe -a ib_uverbs mlx5_core mlx5_ib
	if [ $? -ne 0 ]; then
		printf "WARN: Could not load mlx5 kernel modules. Try to load them manually by executing: modprobe -a ib_uverbs mlx5_core mlx5_ib"  >&2
	fi

	for id in $(usertools/dpdk-devbind.py --status | grep -v Active | grep ConnectX-4 | cut -f 1 -d " ")
	do
		echo "Binding interface $id to DPDK (kernel module mlx5_core)"
		usertools/dpdk-devbind.py  --bind=mlx5_core $id
		i=$(($i+1))
	done
fi
if $MLX4 ; then
	modprobe -a ib_uverbs mlx4_en mlx4_core mlx4_ib
	if [ $? -ne 0 ]; then
		printf "WARN: Could not load mlx5 kernel modules. Try to load them manually by executing: modprobe -a ib_uverbs mlx4_en mlx4_core mlx4_ib"  >&2
	fi

	for id in $(usertools/dpdk-devbind.py --status | grep -v Active | grep ConnectX-3 |  cut -f 1 -d " ")
	do
		echo "Binding interface $id to DPDK (kernel module mlx4_core)"
		usertools/dpdk-devbind.py  --bind=mlx4_core $id
		i=$(($i+1))
	done
fi

if [[ $i == 0 ]]
then
	echo "Could not find any inactive interfaces to bind to DPDK. Note that this script does not bind interfaces that are in use by the OS."
	echo "Delete IP addresses from interfaces you would like to use with libmoon and run this script again."
	echo "You can also use the script dpdk-devbind.py in ${ERROR_MSG_SUBDIR}deps/dpdk/usertools manually to manage interfaces used by libmoon and the OS."
fi

)


MoonGen/libmoon with Mellanox NICs
==================================

Instructions apply to DPDK version: 17.08

In order to use MoonGen/libmoon with Mellanox NICs some addtional steps are necessary as the PMDs for those NICs have external dependecies.

Additional prerequisites
------------------------

 - Mellanox OFED version: ``4.1``; Download from [here](http://www.mellanox.com/page/products_dyn?product_family=26&mtag=linux). Other versions may work (check the [driver compatibility matrix](http://www.mellanox.com/page/mlnx_ofed_matrix?mtag=linux_sw_drivers)), though that has not been tested.
	
	Use one of the following options for installation:

	- install the **complete** Mellanox OFED. For installation refer to the installation manual from the [related documents](http://www.mellanox.com/page/products_dyn?product_family=26&mtag=linux) section. The install procedure will also guide you through the firmware update. **Caution**: The installation will uninstall certain software which conflicts with Mellnox OFED such as previous versions of itself.

	- install **only the required** packages. The required packages are: ``libibverbs, libmlx5, mlnx-ofed-kernel packages``. These packages can be found in the ``DEBS`` folder of Mellanox DPDK. Install the by executing:

			sudo apt install /<Path to MLNX_OFED>/DEBS/<packetname>.deb 

		Complete List of the names of the required .deb files:
	
			libibverbs1[...].deb
			libibverbs1-dev[...].deb
			<OPTIONAL> libibverbs1-dbg[...].deb
		
			libmlx5[...].deb
			libmlx5-dev[...].deb
			<OPTIONAL> libmlx5-dbg[...].deb
		
			mlnx-ofed-kernel-only[...].deb
			mlnx-ofed-kernel-dkms[...].deb
			mlnx-ofed-kernel-utils[...].deb
		
 
 - Required firmware versions:
 	- ConnectX-3: 2.40.7000 (or higher)
	- ConnectX-4: 12.20.1010 (or higher)
	- ConnectX-4 Lx: 14.20.1010 (or higher)
	- ConnectX-5: 16.20.1010 (or higher)
	- ConnectX-5 Ex: 16.20.1010 (or higher)

	The firmware must be updated manually if installation without Mellanox OFED was chosen. See this [site](http://www.mellanox.com/page/firmware_HCA_FW_update) for updating instructions.
	
	


Compilation
-----------

If all prerequisites are fulfilled, install MoonGen/libmoon by executing:

	build.sh --mlx5 --mlx4

Leave out Flags which are not needed. Currently only mlx5 is tested and has custom driver patches. However, user reported success with mlx4 devices.


Troubleshooting
---------------

Some troubleshooting information can be found [here](https://community.mellanox.com/docs/DOC-2688). Also check DPDKs website dedicated to the [mlx5](http://dpdk.org/doc/guides/nics/mlx5.html) and [mlx4](http://dpdk.org/doc/guides/nics/mlx4.html) drivers.


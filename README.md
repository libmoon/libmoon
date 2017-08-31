### Abstract
LuaJIT + DPDK = fast and flexible packet processing at speeds above 100 Gbit/s.

Read and try out one of the [examples](https://github.com/libmoon/libmoon/tree/master/examples) to get started.

libmoon started out as the packet generator [MoonGen](https://github.com/emmericp/MoonGen) which evolved into a more general framework for packet processing.
You can read our [IMC 2015 Research Paper](http://www.net.in.tum.de/fileadmin/bibtex/publications/papers/MoonGen_IMC2015.pdf) ([BibTeX](http://www.net.in.tum.de/fileadmin/bibtex/publications/papers/MoonGen_IMC2015-BibTeX.txt)) for a discussion of our architecture which remained unchanged in libmoon.
Please use this paper as a canonical reference to libmoon if you are writing a paper or thesis.



# The libmoon Framework
libmoon is a high-speed framework to develop DPDK applications in Lua and C/C++.
Its main goal is to simplify the initial creation of new DPDK applications by providing a concise and solid framework to build upon.
The core is a Lua wrapper for DPDK that simplifies operations that are typically extremely verbose in DPDK, e.g., device initialization.
libmoon also simplifies protocol implementations and tests by providing an extensible packet header processing and parsing library.

Explicit multi-core support is at the heart of libmoon.
Scripts define a *master task* that is executed on startup.
This task configures devices and queues and then starts one or more *slave tasks* that then handle packet IO.

Note that Lua does not have any native support for multi-threading.
libmoon therefore starts a new and completely independent LuaJIT VM for each task.
Tasks can only share state through communication primitives provided by libmoon.
The example script [inter-task-communication.lua](https://github.com/libmoon/libmoon/blob/master/examples/inter-task-communication.lua?ts=4) showcases the available communication methods.

# Further Examples and Applications Built on libmoon
The [MoonGen](https://github.com/emmericp/MoonGen) packet generator features user scripts that are essentially small libmoon applications.
Hence, [MoonGen's examples](https://github.com/emmericp/MoonGen/blob/master/examples) may be useful.

[FlowScope](https://github.com/emmericp/FlowScope) is a traffic analysis tool using libmoon. It's a good example on integration libmoon with custom C++ code.

# Installation

Just run `build.sh`, `bind-interfaces.sh`, and `setup-hugetlbfs.sh`. When using Mellanox NICs [additional steps](install-mlx.md) are neccessary.

```
# install dependencies and compile libmoon
sudo apt-get install git build-essential cmake linux-headers-`uname -r` lshw libnuma-dev
git clone https://github.com/libmoon/libmoon
cd libmoon
./build.sh
# bind all NICs that are not actively used (no IP configured) to DPDK
sudo ./bind-interfaces.sh
# configure hugetlbfs
sudo ./setup-hugetlbfs.sh
# run the hello-world example
sudo ./build/libmoon examples/hello-world.lua
```

Note: Use `deps/dpdk/tools/dpdk-devbind.py` to manage NIC drivers manually to get them back into the OS.

### Dependencies
* gcc >= 4.8
* make
* cmake
* kernel headers (for the DPDK igb-uio driver)
* lspci (for dpdk-devbind.py)
* libnuma-dev

# FAQ

### Which NICs do you support?
libmoon supports all [NICs supported by DPDK](http://dpdk.org/doc/nics).
Note that some NICs (e.g., [Mellanox](install-mlx.md)) require external components to work with DPDK.
Refer to the DPDK documentation for further information.
We test and develop libmoon on various NICs of the ixgbe, i40e, and igb family.

### Why should I use this instead of DPDK directly?
It's easier to get started. Seriously, have you tried reading one of the DPDK examples?

### Why should I use this instead of Snabb?
[Snabb](https://github.com/snabbco/snabb) has a completely different approach.
They build their own drivers and generally do not rely on hardware capabilities (e.g., filtering and offloading).
libmoon is just a wrapper for DPDK and heavily uses hardware-specific features.


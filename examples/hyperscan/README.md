## Hyperscan
[Hyperscan](https://01.org/hyperscan) is a high-performance regular expression matching library developed by Intel.

## Requirements
You'll have to install Hyperscan yourself, libmoon will check all the usual locations for `libhs.so`.

### Dependencies
Hyperscan itself has some dependencies.
Please check the official [documentation](http://01org.github.io/hyperscan/dev-reference/getting_started.html) of Hyperscan.

The following is sufficient for Debiand and Ubuntu in addition to the libmoon dependencies:

```
sudo apt -y install libboost-all-dev ragel
```

### Building Hyperscan
Clone the git repository:

```
git clone https://github.com/01org/hyperscan.git
```

Create a build folder and build it there as a shared library:

```
cd hyperscan
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=1 ..
make
sudo make install
```



## Example
The example script `filter_hyperscan.lua` demonstrates the basics of Hyperscan and our wrapper API.
It receives packets from a port, filters them, and forwards them to a port dropping all packets that match filters given in a file.
Moreover, it can generate test traffic by replaying a pcap file on a different port.
The simplest test setup consists of two directly connected ports `0` and `1`:

```
sudo ./build/libmoon examples/hyperscan/filter_hyperscan.lua examples/hyperscan/patterns.txt 0 0 -p 1 -f some-pcap-file.pcap 
```

This sends out `some-pcap-file.pcap` on port 1.
It then receives the packets on port 0 (physically connected to port 0), applies the example filters and echoes the packets back on the same port.

Additionally, have a look at the documentation of Hyperscan for the wrapped methods.
Generally, a parameter extended with `_ptr` means that a C pointer is expected, `_ptr_ptr` indicates a double pointer and `_array` an array.

The most important methods are:

```
hs:new(pattern_file, mode)
```

`pattern_file` has to contain the patterns to scan in the following format: `<ID>:/<pattern>/<flags>`, see `pattern.txt` as an example.


```
hs:filter(packet_ptr, stream_ptr)
```

`stream_ptr` is optional and only needed for streaming mode scans.
`packet_ptr` is a pointer to a packet buf (or any object which implements `getData()` and  `getLength()`)




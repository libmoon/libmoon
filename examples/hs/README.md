### Hyperscan
[Hyperscan](https://01.org/hyperscan) is a high performant regular expression matching library originally developed by Intel(R). 
It is published under 3-BSD-license.

### Usage
Hyperscan is (at the moment) not integrated into the build-system of libmoon since it is not a core feature of it.
If you want to use the wrapped library in libmoon, Hyperscan has to be installed by yourself before as an shared library in `/usr/local/lib/libhs.so`.


### Example of usage
Look at the example "filter_hyperscan.lua". Additionally, have a look at the documentation of Hyperscan for the wrapped methods.
Generally, a parameter extended with `_ptr` means that a C-pointer have to be passed. Accordingly `_ptr_ptr` requires a double pointer and `_array` an array.
For usage of the wrapper themselves or some abstract methods for common use, see "test.lua".

Most important are the following methods:

```
hs:new(pattern_file, mode)
```
`pattern_file` has to contain the patterns for scanning in the following format: `<ID>/<pattern>/<flags>\n`


```
hs:filter(packet_ptr, stream_ptr)
```
`stream_ptr` is optional and only needed for streaming mode scans.
`packet_ptr` is a pointer to a packet of libmoon, or any data which support the interface: `getData(), getLength()`



### Dependencies
Hyperscan itself has some dependencies. For a list of all, please check out the official [documentation](http://01org.github.io/hyperscan/dev-reference/getting_started.html) of Hyperscan.
The usual ones can be installed with:

```
apt -y install cmake
apt -y install libboost-all-dev
apt -y install ragel
```

### Building Hyperscan
Firstly clone the git-repository in a folder where you want.

```
git clone https://github.com/01org/hyperscan.git
```

Change to the downloaded folder and Create a new directory for building and change into it:

```
cd hyperscan
mkdir build
cd build
```

Start cmake with the options to create the shared libraries and the building type release. Then build the library and install it:

```
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=1 ../
make
make install
```


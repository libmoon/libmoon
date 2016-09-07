local ffi 	= require "ffi"
local dpdkc = require "dpdkc"
local dpdk 	= require "dpdk"
require "utils"

local mod = {}

local mg_kni = {}
mod.mg_kni = mg_kni
mg_kni.__index = mg_kni

ffi.cdef[[
struct rte_kni;
struct rte_kni * mg_create_kni(uint8_t port_id, uint8_t core_id, void* mempool_ptr, const char name[]);
unsigned mg_kni_tx_burst 	( 	struct rte_kni *  	kni,
		struct rte_mbuf **  	mbufs,
		unsigned  	num 
	);
unsigned rte_kni_rx_burst 	( 	struct rte_kni *  	kni,
		struct rte_mbuf **  	mbufs,
		unsigned  	num 
	);
int rte_kni_handle_request 	( 	struct rte_kni *  	kni	);
unsigned mg_kni_tx_single(struct rte_kni * kni, struct rte_mbuf * mbuf);
void rte_kni_close 	( 	void  		);
int rte_kni_release 	( 	struct rte_kni *  	kni	);
void rte_kni_init(unsigned int max_kni_ifaces);
]]

-- only works with "insmod deps/dpdk/x86_64-native-linuxapp-gcc/kmod/rte_kni.ko"
function mod.createKni(core, device, mempool, name)
	core = core or 0
	local kni = ffi.C.mg_create_kni(device.id, core, mempool, name)
	return setmetatable({
		kni = kni,
		core = core,
		device = device,
		name = name
	}, mg_kni)
end

-- not blocking recv
function mg_kni:recv(bufs, nmax)
	return ffi.C.rte_kni_rx_burst(self.kni, bufs.array, nmax)
end

function mg_kni:sendN(bufs, nmax)
	return ffi.C.mg_kni_tx_burst(self.kni, bufs.array, nmax)
end

function mg_kni:send(bufs)
	return ffi.C.mg_kni_tx_burst(self.kni, bufs.array, bufs.size)
end

function mg_kni:sendSingle(mbuf)
	ffi.C.mg_kni_tx_single(self.kni, mbuf)
end

function mg_kni:handleRequest()
	ffi.C.rte_kni_handle_request(self.kni)
end

function mg_kni:setIP(ip, net)
	ip = ip or "192.168.1.1"
	net = net or 24

	-- TODO make this nicer
	io.popen("/sbin/ifconfig " .. self.name .. " " .. ip .. "/" .. net)
	self:handleRequest()	
	dpdk.sleepMillisIdle(1)
end

function mg_kni:release()
	return ffi.C.rte_kni_release(self.kni)
end

function mod.init(num)
	return ffi.C.rte_kni_init(num)
end

function mod.close()
 	ffi.C.rte_kni_close()
end

return mod

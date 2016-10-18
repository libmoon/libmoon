--- Output data to graphite
local mod = {}

local log = require "log"
local S   = require "syscall"
local ffi = require "ffi"
local C   = ffi.C

ffi.cdef[[
	struct hostent {
	    char  *h_name;
	    char **h_aliases;
	    int    h_addrtype;
	    int    h_length;
	    uint8_t **h_addr_list;
	};
	struct hostent *gethostbyname(const char *name);
]]

local writer = {}
writer.__index = writer

--- Create a new TCP writer that feeds Graphite via the plaintext protocol.
-- @param target, destination host and port
-- @param prefix, prefix that will be prepended to each metric name
function mod.newWriter(target, prefix)
	local obj = setmetatable({
		prefix = prefix
	}, writer)
	obj:connect(target)
	return obj
end

function writer:connect(target)
	local host, port, ip
	if target:match(":") then
		host, port = target:match("^([^:]+):([^:]+)$")
		if not host or not port then
			log:fatal("could not parse target, format is host[:port]")
		end
	else
		host = target
	end
	-- TODO: ipv6
	if parseIP4Address(host) then
		ip = host
	else
		local hostEnt = C.gethostbyname(host)
		if not hostEnt or hostEnt.h_length < 1 then
			log:fatal("could not resolve %s", host)
		end
		ip = ("%d.%d.%d.%d"):format(hostEnt.h_addr_list[0][0], hostEnt.h_addr_list[0][1], hostEnt.h_addr_list[0][2], hostEnt.h_addr_list[0][3])
	end
	port = tonumber(port or "") or 2003
	self.socket = S.socket("inet", "stream")
	local sa = S.t.sockaddr_in(port, ip)
	local ok, err = S.connect(self.socket, sa)
	if not ok then
		log:error("could not connect to %s: %s", target, err)
	end
end

--- Write a data point to graphite.
--- @param metric the metric name to write
--- @param the value to write
-- TODO: check if socket died and try to reconnect
function writer:write(metric, value)
	local str = self.prefix and self.prefix .. "." or ""
	str = str .. ("%s %.18f %d\n"):format(metric, tonumber(value) or 0, time())
	self.socket:write(str)
end


return mod


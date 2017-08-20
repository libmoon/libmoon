local ffi = require "ffi"
local hslib = ffi.load("/usr/local/lib/libhs.so") --requires Hyperscan to be installed.

ffi.cdef[[
	typedef int hs_error_t; 
	typedef struct hs_platform_info_t hs_platform_info_t;
	typedef struct hs_expr_ext_t hs_expr_ext_t;
	typedef struct hs_scratch_t hs_scratch_t;
	typedef struct hs_stream hs_stream_t;
	typedef struct hs_database hs_database_t;
	typedef struct {char* message; int expression;} hs_compile_error_t;

	typedef int (* match_event_handler)(unsigned int id, unsigned long long from, unsigned long long to, unsigned int flags, void *context);

	hs_error_t hs_free_database(hs_database_t *db);
	hs_error_t hs_serialize_database(const hs_database_t * db, char ** bytes, size_t * length);
	hs_error_t hs_deserialize_database(const char * bytes, const size_t length, hs_database_t ** db);
	hs_error_t hs_stream_size(const hs_database_t * database, size_t * stream_size);
	hs_error_t hs_database_size(const hs_database_t * database, size_t * database_size);
	hs_error_t hs_serialized_database_size(const char * bytes, const size_t length, size_t * deserialized_size);
	hs_error_t hs_valid_platform(void);
	hs_error_t hs_compile(const char * expression, unsigned int flags, unsigned int mode, const hs_platform_info_t * platform, hs_database_t ** db, hs_compile_error_t ** error);
	hs_error_t hs_compile_multi(const char *const * expressions, const unsigned int * flags, const unsigned int * ids, unsigned int elements, unsigned int mode, const hs_platform_info_t * platform, hs_database_t ** db, hs_compile_error_t ** error);
	hs_error_t hs_compile_ext_multi(const char *const * expressions, const unsigned int * flags, const unsigned int * ids, const hs_expr_ext_t *const * ext, unsigned int elements, unsigned int mode, const hs_platform_info_t * platform, hs_database_t ** db, hs_compile_error_t ** error);
	hs_error_t hs_free_compile_error(hs_compile_error_t * error);

	hs_error_t hs_open_stream(const hs_database_t * db, unsigned int flags, hs_stream_t ** stream);
	hs_error_t hs_close_stream(hs_stream_t * id, hs_scratch_t * scratch, match_event_handler onEvent, void * ctxt);
	hs_error_t hs_scan_stream(hs_stream_t * id, const char * data, unsigned int length, unsigned int flags, hs_scratch_t * scratch, match_event_handler onEvent, void * ctxt);
	hs_error_t hs_reset_stream(hs_stream_t * id, unsigned int flags, hs_scratch_t * scratch, match_event_handler onEvent, void * context);
	hs_error_t hs_copy_stream(hs_stream_t ** to_id, const hs_stream_t * from_id);
	hs_error_t hs_reset_and_copy_stream(hs_stream_t * to_id, const hs_stream_t * from_id, hs_scratch_t * scratch, match_event_handler onEvent, void * context);

	hs_error_t hs_scan(const hs_database_t * db, const char * data, unsigned int length, unsigned int flags, hs_scratch_t * scratch, match_event_handler onEvent, void * context);
	hs_error_t hs_scan_vector(const hs_database_t * db, const char *const * data, const unsigned int * length, unsigned int count, unsigned int flags, hs_scratch_t * scratch, match_event_handler onEvent, void * context);
	hs_error_t hs_alloc_scratch(const hs_database_t * db, hs_scratch_t ** scratch);
	hs_error_t hs_free_scratch(hs_scratch_t * scratch);	
	hs_error_t hs_clone_scratch(const hs_scratch_t * src, hs_scratch_t ** dest);
]]


local hs = {}

hs.__index = hs
hs.__type = "hs"


--constants
hs.HS_SUCCESS = 0
hs.HS_INVALID = -1
hs.HS_NOMEM = -2
hs.HS_SCAN_TERMINATED = -3
hs.HS_COMPILER_EROOR = -4
hs.HS_DB_VERSION_ERROR = -5
hs.HS_DB_PLATFORM_ERROR = -6
hs.HS_DB_MODE_ERROR = -7
hs.HS_BAD_ALIGN = -8
hs.HS_BAD_ALLOC = -9
hs.HS_SCRATCH_IN_USE = -10
hs.HS_ARCH_ERROR = -11

hs.HS_FLAG_CASELESS = 1
hs.HS_FLAG_DOTALL = 2
hs.HS_FLAG_MULTILINE = 4
hs.HS_FLAG_SINGLEMATCH = 8
hs.HS_FLAG_ALLOWEMPTY = 16
hs.HS_FLAG_UTF8 = 32
hs.HS_FLAG_UCP = 64
hs.HS_FLAG_PREFILTER = 128
hs.HS_FLAG_SOM_LEFTMOST = 256

hs.HS_MODE_BLOCK = 1
hs.HS_MODE_NOSTREAM = 1
hs.HS_MODE_STREAM = 2
hs.HS_MODE_VECTORED = 4

local C = ffi.C

hs.scratch_ptr_ptr = ffi.typeof("hs_scratch_t*[1]")
hs.database_ptr_ptr = ffi.typeof("hs_database_t*[1]")
hs.err_ptr_ptr = ffi.typeof("hs_compile_error_t*[1]")
hs.stream_ptr_ptr = ffi.typeof("hs_stream_t*[1]")
local void_ptr = ffi.typeof("void*")
local bool_ptr = ffi.typeof("bool[1]")


--simple wrappers
--for usage, look in the documentation: http://01org.github.io/hyperscan/dev-reference/

function hs.free_database(database_ptr)
	return hslib.hs_free_database(database_ptr)
end

function hs.free_scratch(scratch_ptr)
	return hslib.hs_free_scratch(scratch_ptr)
end

function hs.alloc_scratch(database_ptr, scratch_ptr_ptr)
	return hslib.hs_alloc_scratch(database_ptr, scratch_ptr_ptr)
end

function hs.clone_scratch(source_ptr, destination_ptr_ptr)
	return hslib.hs_clone_scratch(source_ptr, destination_ptr_ptr)
end

function hs.serialize_database(database_ptr, bytes_ptr_ptr, length_ptr)
	return hslib.hs_serialize_database(database_ptr, bytes_ptr_ptr, length_ptr)
end

function hs.deserialize_database(bytes_ptr, length, database_ptr_ptr)
	return hslib.hs_deserialize_database(bytes_ptr, length, database_ptr_ptr)
end

function hs.compile(expression, flags, mode, db_ptr_ptr, err_ptr_ptr, platform_ptr)
	return hslib.hs_compile(expression, flags, mode, platform_ptr, db_ptr_ptr, err_ptr_ptr)
end

function hs.compile_multi(expressions, flags_array, ids_array, elements, mode, db_ptr_ptr, err_ptr_ptr, platform_ptr)
	return hslib.hs_compile_multi(expressions, flags_array, ids_array, elements, mode, platform_ptr, db_ptr_ptr, err_ptr_ptr)
end

function hs.scan(database_ptr, data, length, flags, scratch_ptr, callback, context_ptr)
	return hslib.hs_scan(database_ptr, data, length, flags, scratch_ptr, callback, context_ptr)
end

function hs.scan_vector(database_ptr, data, length_array, count, flags, scratch_ptr, callback, context)
	return hslib.hs_scan_vector(database_ptr, data, length_array, count, flags, scratch_ptr, callback, context)
end

function hs.open_stream(database_ptr, flags, stream_ptr_ptr)
	return hslib.hs_open_stream(database_ptr, flags, stream_ptr_ptr)
end

function hs.scan_stream(id_ptr, data, length, flags, scratch_ptr, callback, context_ptr)
	return hslib.hs_scan_stream(id_ptr, data, length, flags, scratch_ptr, callback, context_ptr)
end

function hs.close_stream(id_ptr, scratch_ptr, callback, context_ptr)
	return hslib.hs_close_stream(id_ptr, scratch_ptr, callback, context)
end

function hs.reset_stream(id_ptr, flags, scratch_ptr, callback, context_ptr)
	return hslib.hs_reset_stream(id_ptr, flags, scratch_ptr, callback, context)
end

function hs.copy_stream(to_id_ptr_ptr, from_id_ptr)
	return hslib.hs_copy_stream(to_id_ptr_ptr, from_id_ptr)
end

function hs.reset_and_copy_stream(to_id_ptr, from_id_ptr, scratch_ptr, callback, context_ptr)
	return hslib.hs_reset_and_copy_stream(to_id_ptr, from_id_ptr, scratch_ptr, callback, context_ptr)
end


--match handler callback function dummy
local function matchHandlerDummy(id, from, to, flags, context)
	--print(id, from, to, flags, context)
	print("Found match! Pattern with ID: ", tonumber(id), "match ends: ", tonumber(to))
	return 0
end

--abort scan if match is found
local function matchHandlerDummyAbort(id, from, to, flags, context)
	print("Found match! Pattern with ID: ", tonumber(id), "match ends ", tonumber(to))
	return 1
end

hs.matchHandlerDummy_ptr = ffi.cast("match_event_handler", matchHandlerDummy)
hs.matchHandlerDummyAbort_ptr = ffi.cast("match_event_handler", matchHandlerDummyAbort)



-- more abstract methods

--Inits a new database and scratch for scanning
--@param mode: HS_MODE_BLOCK or HS_MODE_STREAM
--@param pattern_table: Table of the patterns
--@param flags_table: Table of the flags in same order as patterns
--@param ids_table: IDs of patterns in same order as patterns
--
--@return single pointers to the compiled database and to the allocated scratch space.
function hs.init(mode, pattern_table, flags_table, ids_table)
	local db = hs.database_ptr_ptr()
	local err = hs.err_ptr_ptr()
	local scr = hs.scratch_ptr_ptr()

	
	if (#pattern_table ~= #flags_table or #flags_table ~= #ids_table) then
		print("Sizes have to be the same!")
		return nil
	end
		--? operator not working?
	if hs.compile_multi(ffi.new(("const char*[".. #pattern_table .. "]") ,pattern_table),ffi.new("int[".. #flags_table .. "]" , flags_table) , ffi.new(("int [" .. #ids_table .. "]"), ids_table) , #pattern_table, mode,  db, err) ~= hs.HS_SUCCESS then
		print(ffi.string(err[0][0].message)) 
		print("Expr. ID: ", err[0][0].expression)
		hs.free_database(db[0])

		return nil
	end

	hs.alloc_scratch(db[0], scr)

	return db[0], scr[0]
end

-- Scans in streaming mode
function hs.doscan_stream(input, input_length, stream_ptr, scratch_ptr, callback, context_ptr)
	local res = hs.scan_stream(stream_ptr, input, input_length, 0, scratch_ptr, callback or hs.matchHandlerDummy_ptr, context_ptr)
	
	if	res ~= hs.HS_SUCCESS then
		print("Error while scanning:", res)
		return -1
	end
	return 0
end
jit.off(hs.doscan_stream)

-- Scans in block mode
function hs.doscan_block(input, input_length, database_ptr, scratch_ptr, callback, context_ptr)
	local res = hs.scan(database_ptr, input, input_length, 0, scratch_ptr, callback or hs.matchHandlerDummy_ptr, context_ptr)
	if res ~= hs.HS_SUCCESS then
		print("Error while scanning:", res)
		return -1
	end
	return 0
end
jit.off(hs.doscan_block)

-- Returns a single pointer to a new stream
function hs.new_stream(database_ptr)
	local str_ptr_ptr = hs.stream_ptr_ptr()
	local res = hs.open_stream(database_ptr, 0, str_ptr_ptr)
	if res ~= hs.HS_SUCCESS then
		print("Error opening stream:", res)
		return nil
	end

	return str_ptr_ptr[0]
end


-- helper functions

local function parseflags(flag_string)
	if not flag_string then
		return 0
	end

	flag = 0
	for c in string.gmatch(flag_string, ".") do
		if c == 'i' then
			flag = bit.bor(flag, hs.HS_FLAG_CASELESS)
		elseif c == 'm' then
			flag = bit.bor(flag, hs.HS_FLAG_MULTILINE)
		elseif c == 's' then
			flag = bit.bor(flag, hs.HS_FLAG_DOTALL)
		elseif c == 'H' then
			flag = bit.bor(flag, hs.HS_FLAG_SINGLEMATCH)
		elseif c == 'V' then
			flag = bit.bor(flag, hs.HS_FLAG_ALLOWEMPTY)
		elseif c == '8' then
			flag = bit.bor(flag, hs.HS_FLAG_UTF8)
		elseif c == 'W' then
			flag = bit.bor(flag, hs.HS_FLAG_UCP)
		elseif c == 'p' then
			flag = bit.bor(flag, hs.HS_FLAG_PREFILTER)
		else
			print("Unsupported flag \'".. c .. "\' ignored")
		end
	end

	return flag
end

--Returns the tables required by init()
--@param input: rules as string in format: <ID>:/<pattern>/<flags>
function hs.parse(input)
	local ids = {}
	local patterns = {}
	local flags = {}
	for line in string.gmatch(input, "[^\r\n]+") do
		if string.sub(line, 1, 1) ~= "#" then
			first_doublecolon = string.find(line, ":")
			id = tonumber(string.sub(line, 1, first_doublecolon-1))

			otherpart = string.sub(line, first_doublecolon+1)

			last_slash_reversed = string.find(string.reverse(otherpart), "/")

			pattern = string.sub(otherpart, 2, -last_slash_reversed-1)
			flag = string.sub(otherpart, #otherpart-(last_slash_reversed-2))

			table.insert(ids, tonumber(id))
			table.insert(patterns, pattern)
			table.insert(flags, parseflags(flag))
		end
	end
	return patterns, flags, ids
	
end

--Returns the tables required by init()
--@param filename: path to file where rules are saved in format: <ID>:/<pattern>/<flags>
function hs.parse_from_file(filename)
	local file = io.open(filename, "r")
	local input = file:read("*all")
	file:close()

	return hs.parse(input)
end



--Filter class

local function callbackFilter(id, from, to, flags, context)
		return 1 --end when match was found 
end

local callbackFilter_ptr = ffi.cast("match_event_handler", callbackFilter)


--- Creates new filter
--- @param pattern_file: path to file
--- @param mode: HS_MODE_BLOCK or HS_MODE_STREAM
function hs:create(pattern_file, mode)
        local filto = setmetatable({}, hs)
        local d, s = hs.init(mode or hs.HS_MODE_BLOCK, hs.parse_from_file(pattern_file))
        filto.filto = {}
        filto.database_ptr = d
        filto.scratch_ptr = s
        filto.mode = mode or hs.HS_MODE_BLOCK
     
        return filto
end


hs.new = hs.create
setmetatable(hs, {__call = hs.create})


function hs:__tostring()
	return ("[hs: mode=%d]"):format(self.mode)
end


function hs:__serialize()
	local serpent = require "Serpent"
	return "require 'hs'; return " .. serpent.addMt(serpent.dumpRaw(self), "require 'hs'"), true
end

--- Filters a packet 
--- @param packet_ptr: pointer to packet
--- @param stream_ptr: pointer to stream of packet; optional, only needed in streaming-mode
function hs:filter(packet_ptr, stream_ptr)
	local res = nil 
	
	if self.mode == hs.HS_MODE_BLOCK then
		res = hs.scan(self.database_ptr, packet_ptr:getData(), packet_ptr:getSize(), 0, self.scratch_ptr, callbackFilter_ptr)
	elseif self.mode == hs.HS_MODE_STREAM then
		res = hs.scan_stream(stream_ptr, packet_ptr:getData(), packet_ptr:getSize(), 0, self.scratch_ptr, callbackFilter_ptr)
	else
		print("bad mode", self.mode)
				return nil
	end

	return res ~= hs.HS_SUCCESS -- match -> callback -> cb terminates -> HS_SCAN_TERMINATED
end
jit.off(hs.filter) -- see luajit documentation

-- Returns a newly opened stream
function hs:newStream()
		hs.open_stream(self.database_ptr, alloc_scratch())
end

-- Frees the filter
function hs:free()
	hs.free_database(self.database_ptr)
	hs.free_scratch(self.scratch)
end


function hs:getDatabase()
	return self.database_ptr
end

function hs:getScratch()
	return self.scratch_ptr
end

function hs:getMode()
	return self.mode
end	


return hs


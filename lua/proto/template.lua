local fill
local get
local getString
local resolveNextHeader
local setDefaultNamedArgs
local getVariableLength
local getSubType


--- Initialize a new header structure.
--- Adds automatic generated set/get/getString for all members
--- Works for uint8_t, uint16_t and uint32_t
--- For all other types the created functions have to be manualy overwritten
--- Adds empty template functions for all required functions on the complete header
--- fill/get/getString have to be filled in manually
--- All other functions only when required for this protocol
--- @param struct The header format as string
--- @return metatable for the header structure
function initHeader(struct)
	local mod = {}
	mod.__index = mod
	
	-- create setter and getter for all members of the defined C struct
	if struct then
		for line in string.gmatch(struct, "(.-)\n") do
			-- skip empty lines
			if not (line == '') then
				-- get name of member: at the end must be a ';', before that might be [<int>] which is ignored
				local member = string.match(line, "([^%s%[%]]*)%[?%d*%]?%s*;")
				local func_name = member:gsub("^%l", string.upper)
				local type = string.match(line, "%s*(.-)%s+([^%s]*)%s*;")
				if not (member == '') and not (type == '') then 
					-- automatically set byte order for integers
					local conversion = ''
					local close_conversion = ''
					if type == 'uint16_t' then
						conversion = 'hton16('
						close_conversion = ')'
					elseif type == 'uint32_t' then
						conversion = 'hton('
						close_conversion = ')'
					end

					-- set
					local str = [[
return function(self, val)
	val = val or 0
	self.]] .. member .. [[ = ]] .. conversion .. [[val]] .. close_conversion .. [[ 
end]]

					-- load new function and return it
					local func = assert(loadstring(str))()
					mod['set' .. func_name] = func
					
					-- get
					local str = [[
return function(self)
	return ]] .. conversion .. [[self.]] .. member .. close_conversion .. [[ 
end]]

					-- load new function and return it
					local func = assert(loadstring(str))()
					mod['get' .. func_name] = func
					
					-- getFooString
					local str = [[
return function(self)
	return tostring(self:get]] .. func_name .. [[()) 
end]]

					-- load new function and return it
					local func = assert(loadstring(str))()
					mod['get' .. func_name .. 'String'] = func
				else
					print('Warning: empty or malicious line cannot be parsed')
				end
			end
		end
	end

	-- add templates for header-wide functions
	mod.fill = fill 
	mod.get = get 
	mod.getString = getString
	mod.resolveNextHeader = resolveNextHeader
	mod.setDefaultNamedArgs = setDefaultNamedArgs
	mod.getVariableLength = getVariableLength
	mod.getSubType = getSubType
	
	return setmetatable({}, mod)
end

function fill(self, args, pre)
end

function get(self, pre)
	return {}
end

function getString(self)
	return ""
end

--- Defines how, based on the data of this header, the next following protocol in the stack can be resolved
function resolveNextHeader(self)
	return nil
end

--- Defines how, based on the data of this header and the complete stack, the default values of this headers member change
function setDefaultNamedArgs(self, pre, namedArgs, nextHeader, accumulatedLength, headerLength)
	return namedArgs
end

--- Defines how, based on the data of this header, the length of the variable sized member can be determined
function getVariableLength(self)
	return nil
end

--- Defines how, based on the data of this header, the protocol subtype can be determined
function getSubType(self)
	return nil
end

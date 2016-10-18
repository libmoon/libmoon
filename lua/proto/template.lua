local fill
local get
local getString
local resolveNextHeader
local setDefaultNamedArgs
local getVariableLength
local getSubType
local testing


function initHeader()
	local mod = {}
	mod.__index = mod

	mod.fill = fill 
	mod.get = get 
	mod.getString = getString
	mod.resolveNextHeader = resolveNextHeader
	mod.setDefaultNamedArgs = setDefaultNamedArgs
	mod.getVariableLength = getVariableLength
	mod.getSubType = getSubType
	mod.testing = testing
	
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

function resolveNextHeader(self)
	return nil
end

function setDefaultNamedArgs(self, pre, namedArgs, nextHeader, accumulatedLength, headerLength)
	return namedArgs
end

function getVariableLength(self)
	return nil
end

function getSubType(self)
	return nil
end

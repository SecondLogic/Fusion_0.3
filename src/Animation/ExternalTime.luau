--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Outputs the current external time as a state object.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Graph
local change = require(Package.Graph.change)
-- Utility
local nicknames = require(Package.Utility.nicknames)

export type ExternalTime = Types.StateObject<number> & {
	setActive: (ExternalTime, boolean) -> (),
	isActive: (ExternalTime) -> boolean,
}

type Self = ExternalTime & {
	_active: boolean,
}

local class = {}
class.type = "State"
class.kind = "ExternalTime"
class.timeliness = "lazy"
class.dependencySet = table.freeze {}

local METATABLE = table.freeze {__index = class}

local allTimers: {Self} = {}

local function ExternalTime(
	scope: Types.Scope<unknown>
): ExternalTime
	local createdAt = os.clock()
	local self: Self = setmetatable(
		{
			createdAt = createdAt,
			dependentSet = {},
			lastChange = nil,
			scope = scope,
			validity = "invalid",
			_EXTREMELY_DANGEROUS_usedAsValue = External.lastUpdateStep(),
			_active = false
		},
		METATABLE
	) :: any
	local destroy = function()
		self.scope = nil
		local index = table.find(allTimers, self)
		if index ~= nil then
			table.remove(allTimers, index)
		end
	end
	self.oldestTask = destroy
	nicknames[self.oldestTask] = "ExternalTime"
	table.insert(scope, destroy)
	table.insert(allTimers, self)
	return self
end

function class.setActive(
	self: Self,
	active: boolean
)
	if active ~= self._active then
		self._active = active
		if active then
			change(self)
		end
	end
end

function class.isActive(
	self: Self,
	active: boolean
): boolean
	return self._active
end


function class._evaluate(
	self: Self
): boolean
	-- While someone else could call `change()` on this object, it wouldn't be
	-- idiomatic. So, since the only idiomatic time this function runs is when
	-- the external update step runs, it's safe enough to assume that the result
	-- has always meaningfully changed. The worst that can happen is unexpected
	-- refreshing for people doing unorthodox shenanigans, which is an OK trade.
	self._EXTREMELY_DANGEROUS_usedAsValue = External.lastUpdateStep()
	return true
end

External.bindToUpdateStep(function(
	externalNow: number
): ()
	for _, timer in allTimers do
		if timer:isActive() then
			change(timer)
		end
	end
end)

-- Do *not* freeze the class table, because it stores the shared value of all
-- external time objects, and is updated every frame because of that.
-- table.freeze(class)
return ExternalTime
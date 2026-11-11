--!strict
-- WorldModifierService (Phase 3, server only): the only writer of shared world properties.
-- Patches never set Workspace.Gravity (or other shared properties) directly. They add modifier
-- tokens; the effective value is recomputed from the baseline and every live token whenever a
-- token is added or removed, and written once.
--
-- Deterministic resolution for a property:
--   1. Start from the "set" token with the highest priority (ties: the earliest token);
--      if there is none, start from the baseline captured at Init.
--   2. Multiply by every "multiply" token.
--   3. Add every "add" token.
--   4. Clamp to Config.WorldModifiers[property].Min/Max. Finite tokens can still combine into a
--      non-finite value: +/-infinity clamps to Max/Min, NaN falls back to the baseline. The world
--      never receives a non-finite value.
-- Removing the last token restores the exact baseline value.
-- Properties: Workspace.Gravity (Phase 3); Lighting.Brightness and Lighting.ExposureCompensation
-- (Phase 7A, BLACKOUT).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))

export type Operation = "set" | "multiply" | "add"

type Token = {
	id: string,
	property: string,
	op: Operation,
	value: number,
	priority: number,
	owner: string,
	seq: number,
}

type Property = {
	get: () -> number,
	set: (number) -> (),
}

local PROPERTIES: { [string]: Property } = {
	Gravity = {
		get = function()
			return workspace.Gravity
		end,
		set = function(value: number)
			workspace.Gravity = value
		end,
	},
	Brightness = {
		get = function()
			return Lighting.Brightness
		end,
		set = function(value: number)
			Lighting.Brightness = value
		end,
	},
	ExposureCompensation = {
		get = function()
			return Lighting.ExposureCompensation
		end,
		set = function(value: number)
			Lighting.ExposureCompensation = value
		end,
	},
}

local VALID_OPS = { set = true, multiply = true, add = true }

local WorldModifierService = {}

local baseline: { [string]: number } = {}
local tokens: { [string]: Token } = {}
local sequence = 0
local initialized = false

local function isFinite(value: any): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function resolve(property: string): number
	local list = {}
	for _, token in tokens do
		if token.property == property then
			table.insert(list, token)
		end
	end
	table.sort(list, function(a, b)
		return a.seq < b.seq
	end)
	local chosen: Token? = nil
	local multiplier, offset = 1, 0
	for _, token in list do
		if token.op == "set" then
			if chosen == nil or token.priority > chosen.priority then
				chosen = token
			end
		elseif token.op == "multiply" then
			multiplier *= token.value
		else
			offset += token.value
		end
	end
	local start = if chosen then chosen.value else baseline[property]
	local limits = Config.WorldModifiers[property]
	local value = start * multiplier + offset
	if value ~= value then
		-- NaN from finite tokens (e.g. overflowed multiplier x 0, or +inf and -inf offsets):
		-- fail safe to the baseline instead of writing NaN into the world.
		warn(`[WORLD_EXE] WorldModifier {property}: non-finite result, using baseline`)
		value = baseline[property]
	elseif value == math.huge then
		value = limits.Max
	elseif value == -math.huge then
		value = limits.Min
	end
	return math.clamp(value, limits.Min, limits.Max)
end

local function apply(property: string)
	PROPERTIES[property].set(resolve(property))
end

-- Captures baseline values (call once at server start, before any patch runs).
function WorldModifierService.Init()
	for name, property in PROPERTIES do
		baseline[name] = property.get()
	end
	initialized = true
end

-- Adds a token and re-applies the property. Returns the token id. `owner` is a label used for
-- leak checks (patch runtime id).
function WorldModifierService.AddModifier(property: string, op: Operation, value: number, priority: number?, owner: string?): string
	assert(initialized, "WorldModifierService not initialized")
	assert(PROPERTIES[property] and Config.WorldModifiers[property], `unknown world property {tostring(property)}`)
	assert(VALID_OPS[op], `invalid modifier operation {tostring(op)}`)
	assert(isFinite(value), "modifier value must be a finite number")
	sequence += 1
	local id = `MOD-{sequence}`
	tokens[id] = {
		id = id,
		property = property,
		op = op,
		value = value,
		priority = if isFinite(priority) then priority :: number else 0,
		owner = owner or "unknown",
		seq = sequence,
	}
	apply(property)
	return id
end

-- Removes a token (idempotent). Returns true when a token was removed.
function WorldModifierService.RemoveModifier(id: string): boolean
	local token = tokens[id]
	if token == nil then
		return false
	end
	tokens[id] = nil
	apply(token.property)
	return true
end

-- Removes every token and restores every baseline. Returns how many tokens were removed.
function WorldModifierService.ClearAll(): number
	local removed = 0
	for id in tokens do
		tokens[id] = nil
		removed += 1
	end
	if initialized then
		for name in PROPERTIES do
			apply(name)
		end
	end
	return removed
end

function WorldModifierService.GetEffective(property: string): number
	return resolve(property)
end

function WorldModifierService.GetBaseline(property: string): number
	return baseline[property]
end

-- Number of live tokens, optionally only those owned by `owner`.
function WorldModifierService.GetTokenCount(owner: string?): number
	local count = 0
	for _, token in tokens do
		if owner == nil or token.owner == owner then
			count += 1
		end
	end
	return count
end

-- True when no tokens exist and every property currently equals its baseline.
function WorldModifierService.IsAtBaseline(): boolean
	if next(tokens) ~= nil then
		return false
	end
	for name, property in PROPERTIES do
		if property.get() ~= baseline[name] then
			return false
		end
	end
	return true
end

return WorldModifierService

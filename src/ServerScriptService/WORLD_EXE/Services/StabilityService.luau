--!strict
-- StabilityService (Phase 5, server only): the match's shared Simulation Stability value.
-- * Server-authoritative: no remote can change it. Only server code calls Adjust().
-- * Range Config.Stability.Min..Max, starts at Config.Stability.Initial each match.
-- * Phase 5 sources (provisional tuning, see docs/PROJECT_STATUS.md):
--     patch goes ACTIVE      -> cost by catalog Severity (Phase 7A: mild -4, standard -5,
--                               severe -6; PATCH_ACTIVATION_COST for non-catalog test patches).
--                               Scaled down with the faster Architect cadence so the total
--                               stability pressure per match stays about the same.
--     combination starts     -> INTERACTION_COST once (PatchInteractionService, Phase 7A)
--     stabilizer repaired    -> REPAIR_GAIN (applied by ObjectiveService)
-- * Stability does not change match flow in Phase 5 (no early FINAL_PHASE, no early end): that
--   rule is an open owner decision. It feeds the team outcome at RESULTS.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local PatchCatalog = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("PatchCatalog"))

local Settings = Config.Stability

-- Server-only tuning (provisional).
local PATCH_ACTIVATION_COST = -8
local SEVERITY_COST = table.freeze({ mild = -4, standard = -5, severe = -6 })
local INTERACTION_COST = -4
local REPAIR_GAIN = 15
local LOG_LIMIT = 50

local StabilityService = {}

local value = Settings.Initial
local log: { string } = {}
local onChanged: () -> () = function() end

local function isFinite(n: any): boolean
	return typeof(n) == "number" and n == n and n > -math.huge and n < math.huge
end

-- Applies a change, clamped to the range. Returns the change actually applied.
function StabilityService.Adjust(delta: number, reason: string): number
	assert(isFinite(delta), "stability delta must be a finite number")
	local before = value
	value = math.clamp(value + delta, Settings.Min, Settings.Max)
	local applied = value - before
	table.insert(log, `{reason}:{applied}`)
	if #log > LOG_LIMIT then
		table.remove(log, 1)
	end
	if applied ~= 0 then
		onChanged()
	end
	return applied
end

function StabilityService.Get(): number
	return value
end

-- Back to the initial value (match start, reset, recovery). Idempotent.
function StabilityService.Reset()
	local changed = value ~= Settings.Initial
	value = Settings.Initial
	table.clear(log)
	if changed then
		onChanged()
	end
end

function StabilityService.GetLog(): { string }
	return table.clone(log)
end

function StabilityService.Init(changed: () -> ())
	onChanged = changed
end

-- Stability cost of one patch activation (by catalog Severity).
function StabilityService.CostFor(patchId: string): number
	local def = PatchCatalog.Get(patchId)
	return if def and SEVERITY_COST[def.Severity] then SEVERITY_COST[def.Severity] else PATCH_ACTIVATION_COST
end

StabilityService.Tuning = table.freeze({
	PatchActivationCost = PATCH_ACTIVATION_COST,
	SeverityCost = SEVERITY_COST,
	InteractionCost = INTERACTION_COST,
	RepairGain = REPAIR_GAIN,
})

return StabilityService

--!strict
-- PatchInteractionService (Phase 7A, server only): approved patch combinations.
-- * Only combinations listed in InteractionCatalog exist; any other pair of patches does nothing.
-- * A combination starts when both of its source patches are ACTIVE in the same live match
--   (PatchService notifies activations and endings). It starts at most ONCE per match (approved
--   P4), even if its sources end and run again, and never more than MAX_PER_MATCH per match.
-- * It is a sub-effect of its sources: it holds no patch slot (the major-patch cap is untouched)
--   and ends as soon as either source ends, for any reason (expiry, cancel, match end, reset,
--   recovery, shutdown).
-- * Behaviours use the shared BehaviorRuntime contract: non-yielding Activate/Deactivate, tracked
--   resources in a CleanupService bag, inert context after cleanup. A failed or yielding Activate
--   is rolled back completely and the combination does not retry that match.
-- * On a successful start (approved P4/P7): stability INTERACTION_COST once; +Discovery points once
--   to each living Participant (one unique score key per combination, player and match); an
--   announcement to all clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local InteractionCatalog = require(shared:WaitForChild("InteractionCatalog"))
local services = script.Parent
local BehaviorRuntime = require(services:WaitForChild("BehaviorRuntime"))
local CleanupService = require(services:WaitForChild("CleanupService"))
local NetService = require(services:WaitForChild("NetService"))
local PlayerStateService = require(services:WaitForChild("PlayerStateService"))
local ScoreService = require(services:WaitForChild("ScoreService"))
local StabilityService = require(services:WaitForChild("StabilityService"))
local patchModules = services.Parent:WaitForChild("Patches")

local MAX_PER_MATCH = 5
local HISTORY_LIMIT = 50

type Running = {
	Id: string,
	RuntimeId: string,
	MatchId: number,
	Sources: { string }, -- source runtime ids
	bag: CleanupService.Bag,
	ctx: any,
	behavior: any,
}

local PatchInteractionService = {}

local behaviors: { [string]: any } = {}
local activePatches: { [string]: { PatchId: string, MatchId: number } } = {} -- runtime id -> info
local triggered: { [string]: boolean } = {} -- "<match>:<combination>"
local startedThisMatch: { [number]: number } = {}
local running: { [string]: Running } = {} -- combination id -> running record
local history: { { [string]: any } } = {}
local isMatchLive: (number) -> boolean = function()
	return false
end
local onChanged: () -> () = function() end

local function record(entry: { [string]: any })
	table.insert(history, entry)
	if #history > HISTORY_LIMIT then
		table.remove(history, 1)
	end
end

local function stop(rec: Running, reason: string)
	if running[rec.Id] ~= rec then
		return
	end
	running[rec.Id] = nil
	if rec.behavior.Deactivate then
		local ok, _, message = BehaviorRuntime.RunHook(rec.behavior.Deactivate, rec.ctx)
		if not ok then
			warn(`[WORLD_EXE] Combination {rec.RuntimeId} Deactivate failed: {message}`)
		end
	end
	local released, errors = rec.bag:Cleanup()
	for _, err in errors do
		warn(`[WORLD_EXE] Combination {rec.RuntimeId} cleanup error: {err}`)
	end
	record({ Id = rec.Id, RuntimeId = rec.RuntimeId, MatchId = rec.MatchId, Ended = reason, Released = released, Errors = #errors })
	print(`[WORLD_EXE] Combination {rec.RuntimeId} ended: {reason} (released {released})`)
	onChanged()
end

local function start(def: InteractionCatalog.InteractionDefinition, matchId: number, sources: { string })
	local key = `{matchId}:{def.Id}`
	if triggered[key] or running[def.Id] or (startedThisMatch[matchId] or 0) >= MAX_PER_MATCH or not isMatchLive(matchId) then
		return
	end
	triggered[key] = true -- once per match, even if activation fails
	startedThisMatch[matchId] = (startedThisMatch[matchId] or 0) + 1
	local behavior = behaviors[def.Id]
	local runtimeId = `I{matchId}-{def.Id}`
	local bag = CleanupService.new(runtimeId)
	local rec: Running = { Id = def.Id, RuntimeId = runtimeId, MatchId = matchId, Sources = sources, bag = bag, ctx = nil, behavior = behavior }
	rec.ctx = BehaviorRuntime.NewContext({
		RuntimeId = runtimeId,
		PatchId = def.Id,
		MatchId = matchId,
		CreatorUserId = 0,
		Bag = bag,
		IsLive = function(): boolean
			return running[def.Id] == rec and isMatchLive(matchId)
		end,
	})
	running[def.Id] = rec
	local ok, kind, message = BehaviorRuntime.RunHook(behavior.Activate, rec.ctx)
	if not ok then
		running[def.Id] = nil
		local released = bag:Cleanup()
		warn(`[WORLD_EXE] Combination {runtimeId} activation failed: {message}`)
		record({ Id = def.Id, RuntimeId = runtimeId, MatchId = matchId, Ended = if kind == "yielded" then "activation_yielded" else "activation_failed", Released = released, Errors = 0 })
		return
	end
	StabilityService.Adjust(StabilityService.Tuning.InteractionCost, `combination:{def.Id}`)
	local awarded = 0
	for _, player in PlayerStateService.GetPlayersWithRole(Config.Roles.Participant) do
		if PlayerStateService.IsAlive(player)
			and ScoreService.Award(player.UserId, "discovery", ScoreService.Points.Discovery, `discovery:{matchId}:{def.Id}:{player.UserId}`)
		then
			awarded += 1
		end
	end
	NetService.Get(Config.Remotes.PatchAnnouncement):FireAllClients({
		MatchId = matchId,
		Outcome = "interaction",
		InteractionId = def.Id,
		DisplayName = def.DisplayName,
		Warning = def.Warning,
		DiscoveryPoints = ScoreService.Points.Discovery,
	})
	print(`[WORLD_EXE] Combination {runtimeId} started from {table.concat(sources, " + ")} (discovery awarded to {awarded})`)
	onChanged()
end

-- PatchService: a patch became ACTIVE.
function PatchInteractionService.OnPatchActivated(patchId: string, matchId: number, runtimeId: string)
	activePatches[runtimeId] = { PatchId = patchId, MatchId = matchId }
	for _, def in InteractionCatalog.ForPatch(patchId) do
		local partner = if def.Sources[1] == patchId then def.Sources[2] else def.Sources[1]
		for otherId, info in activePatches do
			if otherId ~= runtimeId and info.PatchId == partner and info.MatchId == matchId then
				start(def, matchId, { runtimeId, otherId })
				break
			end
		end
	end
end

-- PatchService: a patch ended (any reason). Ends every combination it feeds.
function PatchInteractionService.OnPatchEnded(_patchId: string, runtimeId: string, _matchId: number, reason: string)
	activePatches[runtimeId] = nil
	for _, rec in table.clone(running) do
		if table.find(rec.Sources, runtimeId) then
			stop(rec, `source_ended:{reason}`)
		end
	end
end

-- Ends every running combination (idempotent).
function PatchInteractionService.StopAll(reason: string): number
	local n = 0
	for _, rec in table.clone(running) do
		stop(rec, reason)
		n += 1
	end
	return n
end

-- StopAll plus forgetting active sources and per-match triggers (RESET, recovery, shutdown).
function PatchInteractionService.Reset(reason: string?)
	PatchInteractionService.StopAll(reason or "reset")
	table.clear(activePatches)
	table.clear(triggered)
	table.clear(startedThisMatch)
end

-- Bounded snapshot entries for clients.
function PatchInteractionService.GetSnapshot(): { { [string]: any } }
	local list = {}
	for _, rec in running do
		local def = InteractionCatalog.Get(rec.Id)
		table.insert(list, { Id = rec.Id, DisplayName = def and def.DisplayName or rec.Id, Sources = def and def.Sources or {} })
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

function PatchInteractionService.GetHistory(): { { [string]: any } }
	return table.clone(history)
end

function PatchInteractionService.IsRunning(id: string): boolean
	return running[id] ~= nil
end

-- deps.isMatchLive(matchId): true while that match is ACTIVE or FINAL_PHASE.
function PatchInteractionService.Init(deps: { isMatchLive: (number) -> boolean, onChanged: () -> () })
	isMatchLive = deps.isMatchLive
	onChanged = deps.onChanged
	for _, id in InteractionCatalog.Ids() do
		local def = InteractionCatalog.Get(id) :: InteractionCatalog.InteractionDefinition
		behaviors[id] = require(patchModules:WaitForChild(def.Behavior)) :: any
	end
end

PatchInteractionService.MaxPerMatch = MAX_PER_MATCH

return PatchInteractionService

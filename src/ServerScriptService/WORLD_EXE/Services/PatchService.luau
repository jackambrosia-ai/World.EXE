--!strict
-- PatchService (Phase 3, server only): owns every runtime patch.
--
-- Lifecycle: validate -> reserve slot -> (announce, by the caller) -> WARNING -> revalidate ->
-- ACTIVE -> ENDING -> ENDED.
-- * At most Config.Patches.MaxActiveMajor patches hold a slot (WARNING, ACTIVE or ENDING). Over-cap
--   requests are rejected with "capacity_full"; nothing already running is ever displaced.
-- * Each runtime patch has a unique RuntimeId, PatchId, server-assigned CreatorUserId, MatchId,
--   timings, state, and a CleanupService bag holding everything its behaviour created
--   (instances, connections, threads, WorldModifierService tokens, callbacks).
-- * Cleanup is idempotent and runs on expiry, failed activation (full rollback), cancellation,
--   match end, reset, recovery and shutdown. Ending a patch always releases its slot.
-- * Behaviours never touch shared world properties directly; they use ctx.AddModifier.
-- * Non-yielding hook contract: Activate and Deactivate run synchronously inside the match tick
--   and must not yield. Each hook runs in its own coroutine; if it yields (task.wait, WaitForChild,
--   a web call...) the coroutine is cancelled at once so it can never resume, the tick continues,
--   and the hook counts as failed (Activate -> full rollback, reason "activation_yielded").
--   Long-running or slow work goes in ctx.Spawn / ctx.Delay: tracked threads that are cancelled
--   when the patch ends for any reason (expiry, cancel, match end, reset, recovery, shutdown).
-- Phase 3 runs the four approved patches with a no-effect placeholder behaviour; Studio-only test
-- patches (never in PatchCatalog) exercise resources, modifiers and failure paths.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local PatchCatalog = require(shared:WaitForChild("PatchCatalog"))
local services = script.Parent
local CleanupService = require(services:WaitForChild("CleanupService"))
local WorldModifierService = require(services:WaitForChild("WorldModifierService"))
local patchModules = services.Parent:WaitForChild("Patches")

local States = Config.PatchStates
local Settings = Config.Patches

-- Activate / Deactivate must not yield (see the hook contract above).
export type Behavior = {
	Activate: (ctx: any) -> (),
	Deactivate: ((ctx: any) -> ())?,
}

export type PatchView = {
	RuntimeId: string,
	PatchId: string,
	State: string,
	MatchId: number,
	CreatorUserId: number,
	WarningEndsAt: number,
	ExpiresAt: number,
}

type Record = {
	RuntimeId: string,
	PatchId: string,
	DisplayName: string,
	CreatorUserId: number,
	MatchId: number,
	SourceKey: string?,
	State: string,
	RequestedAt: number,
	WarningEndsAt: number,
	Duration: number,
	StartedAt: number,
	ExpiresAt: number,
	EndReason: string?,
	EndedAt: number?,
	ReleasedItems: number?,
	CleanupErrors: { string }?,
	behavior: Behavior,
	bag: CleanupService.Bag,
	ctx: any,
}

local PatchService = {}

local behaviors: { [string]: Behavior } = {}
local testDefinitions: { [string]: { DisplayName: string, WarningSeconds: number, DurationSeconds: number } } = {}
local records: { Record } = {} -- slot holders, in request order
local history: { Record } = {} -- ended records (most recent last)
local usedSourceKeys: { [string]: string } = {} -- SourceKey -> RuntimeId (duplicate guard)
local counter = 0
local isMatchLive: (number) -> boolean = function()
	return false
end
local onChanged: () -> () = function() end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function runtimeFolder(): Instance?
	local root = workspace:FindFirstChild(Config.RootName)
	return root and root:FindFirstChild("ActivePatchInstances")
end

local function view(record: Record): PatchView
	return {
		RuntimeId = record.RuntimeId,
		PatchId = record.PatchId,
		State = record.State,
		MatchId = record.MatchId,
		CreatorUserId = record.CreatorUserId,
		WarningEndsAt = record.WarningEndsAt,
		ExpiresAt = record.ExpiresAt,
	}
end

---------------------------------------------------------------------------------------------------
-- Hooks

-- Runs a behaviour hook under the non-yielding contract. Returns (true) or (false, kind, message)
-- where kind is "error" or "yielded". A yielded hook is cancelled and never resumes.
local function runHook(hook: (any) -> (), ctx: any): (boolean, string?, string?)
	local thread = coroutine.create(hook)
	local ok, err = coroutine.resume(thread, ctx)
	if not ok then
		return false, "error", tostring(err)
	end
	if coroutine.status(thread) ~= "dead" then
		task.cancel(thread)
		return false, "yielded", "hook yielded; Activate/Deactivate must not yield (use ctx.Spawn / ctx.Delay)"
	end
	return true
end

---------------------------------------------------------------------------------------------------
-- Ending

-- Ends a patch exactly once: ENDING -> behaviour Deactivate -> bag cleanup -> ENDED, slot released.
local function finish(record: Record, reason: string)
	if record.State == States.Ending or record.State == States.Ended then
		return
	end
	record.State = States.Ending
	if record.behavior.Deactivate and record.ctx then
		local ok, _, message = runHook(record.behavior.Deactivate :: any, record.ctx)
		if not ok then
			warn(`[WORLD_EXE] Patch {record.RuntimeId} Deactivate failed: {message}`)
		end
	end
	local released, errors = record.bag:Cleanup()
	for _, err in errors do
		warn(`[WORLD_EXE] Patch {record.RuntimeId} cleanup error: {err}`)
	end
	record.ReleasedItems = released
	record.CleanupErrors = errors
	record.State = States.Ended
	record.EndReason = reason
	record.EndedAt = now()
	local index = table.find(records, record)
	if index then
		table.remove(records, index)
	end
	table.insert(history, record)
	if #history > Settings.HistoryLimit then
		table.remove(history, 1)
	end
	print(`[WORLD_EXE] Patch {record.RuntimeId} {record.PatchId} ended: {reason} (released {released})`)
	onChanged()
end

---------------------------------------------------------------------------------------------------
-- Requests

local function newContext(record: Record): any
	local ctx = {
		RuntimeId = record.RuntimeId,
		PatchId = record.PatchId,
		MatchId = record.MatchId,
		CreatorUserId = record.CreatorUserId,
		Folder = runtimeFolder(),
	}
	-- Tracks an instance / connection / thread / callback for cleanup; returns it.
	function ctx.Add(item: any): any
		return record.bag:Add(item)
	end
	-- Adds a WorldModifierService token owned by this patch; removed automatically at cleanup.
	-- Returns nil (and changes nothing) once the patch has been cleaned up.
	function ctx.AddModifier(property: string, op: any, value: number, priority: number?): string?
		if record.bag:IsCleaned() then
			return nil
		end
		local id = WorldModifierService.AddModifier(property, op, value, priority, record.RuntimeId)
		record.bag:Add(function()
			WorldModifierService.RemoveModifier(id)
		end)
		return id
	end
	-- Tracked task: runs fn(...) on the next resumption cycle (never inside the tick). The thread
	-- may yield freely and is cancelled when the patch ends. Returns nil once cleaned up.
	function ctx.Spawn(fn: (...any) -> (), ...: any): thread?
		if record.bag:IsCleaned() then
			return nil
		end
		return record.bag:Add(task.defer(fn, ...))
	end
	-- Tracked delayed call: cancelled if the patch ends before it fires.
	function ctx.Delay(seconds: number, fn: (...any) -> (), ...: any): thread?
		if record.bag:IsCleaned() then
			return nil
		end
		return record.bag:Add(task.delay(seconds, fn, ...))
	end
	-- True while the patch is ACTIVE in a live match; loops in behaviours must check this.
	function ctx.IsLive(): boolean
		return record.State == States.Active and isMatchLive(record.MatchId)
	end
	return ctx
end

-- Reserves a slot and starts the WARNING period. Returns (true, runtimeId) or (false, reason).
-- Reasons: "unknown_patch", "match_not_live", "duplicate", "capacity_full".
-- options.SourceKey: unique key per accepted submission (e.g. "turn:<match>:<turn>") so one
-- submission can never create two patches.
-- options.Test: Studio-only test patches (never reachable from player input).
function PatchService.Request(patchId: string, creatorUserId: number, matchId: number, scale: number, options: { SourceKey: string?, Test: boolean? }?): (boolean, string)
	local opts = options or {}
	local definition: { DisplayName: string, WarningSeconds: number?, DurationSeconds: number }
	if opts.Test then
		if not RunService:IsStudio() or testDefinitions[patchId] == nil then
			return false, "unknown_patch"
		end
		definition = testDefinitions[patchId]
	else
		local def = PatchCatalog.Get(patchId)
		if def == nil or behaviors[patchId] == nil then
			return false, "unknown_patch"
		end
		definition = def
	end
	if not isMatchLive(matchId) then
		return false, "match_not_live"
	end
	if opts.SourceKey and usedSourceKeys[opts.SourceKey] then
		return false, "duplicate"
	end
	if #records >= Settings.MaxActiveMajor then
		return false, "capacity_full"
	end

	counter += 1
	local runtimeId = `P{matchId}-{counter}`
	local t = now()
	local warningSeconds = definition.WarningSeconds or Settings.DefaultWarningSeconds
	local record: Record = {
		RuntimeId = runtimeId,
		PatchId = patchId,
		DisplayName = definition.DisplayName,
		CreatorUserId = creatorUserId,
		MatchId = matchId,
		SourceKey = opts.SourceKey,
		State = States.Warning,
		RequestedAt = t,
		WarningEndsAt = t + warningSeconds * scale,
		Duration = definition.DurationSeconds * scale,
		StartedAt = 0,
		ExpiresAt = 0,
		behavior = behaviors[patchId],
		bag = CleanupService.new(runtimeId),
		ctx = nil,
	}
	if opts.SourceKey then
		usedSourceKeys[opts.SourceKey] = runtimeId
	end
	table.insert(records, record)
	print(`[WORLD_EXE] Patch {runtimeId} {patchId} requested (warning {string.format("%.1f", warningSeconds * scale)}s, active {string.format("%.1f", record.Duration)}s)`)
	onChanged()
	return true, runtimeId
end

-- Advances lifecycles. Called by MatchService every tick.
function PatchService.Update()
	local t = now()
	for _, record in table.clone(records) do
		if record.State == States.Warning and t >= record.WarningEndsAt then
			-- Revalidate before activating: same live match, creator still present.
			if not isMatchLive(record.MatchId) then
				finish(record, "match_not_live")
				continue
			end
			if record.CreatorUserId > 0 and Players:GetPlayerByUserId(record.CreatorUserId) == nil then
				finish(record, "creator_left")
				continue
			end
			record.State = States.Active
			record.StartedAt = t
			record.ExpiresAt = t + record.Duration
			record.ctx = newContext(record)
			local ok, kind, message = runHook(record.behavior.Activate, record.ctx)
			if not ok then
				warn(`[WORLD_EXE] Patch {record.RuntimeId} {record.PatchId} activation failed: {message}`)
				finish(record, if kind == "yielded" then "activation_yielded" else "activation_failed")
				continue
			end
			print(`[WORLD_EXE] Patch {record.RuntimeId} {record.PatchId} active`)
			onChanged()
		elseif record.State == States.Active and t >= record.ExpiresAt then
			finish(record, "expired")
		end
	end
end

-- Ends one patch (idempotent). Returns true if it was running.
function PatchService.Cancel(runtimeId: string, reason: string): boolean
	for _, record in records do
		if record.RuntimeId == runtimeId then
			finish(record, reason)
			return true
		end
	end
	return false
end

-- Ends every running patch (idempotent). Returns how many were ended.
function PatchService.CancelAll(reason: string): number
	local ended = 0
	for _, record in table.clone(records) do
		finish(record, reason)
		ended += 1
	end
	return ended
end

-- Forgets duplicate-guard keys between matches (keys include the match id, so this only bounds memory).
function PatchService.ResetMatchKeys()
	table.clear(usedSourceKeys)
end

---------------------------------------------------------------------------------------------------
-- Queries

function PatchService.HasCapacity(): boolean
	return #records < Settings.MaxActiveMajor
end

function PatchService.GetSnapshot(): { PatchView }
	local list = {}
	for _, record in records do
		table.insert(list, view(record))
	end
	return list
end

-- Read-only copies of ended records (for tests and results).
function PatchService.GetHistory(): { { [string]: any } }
	local list = {}
	for _, record in history do
		local entry: { [string]: any } = view(record)
		entry.EndReason = record.EndReason
		entry.ReleasedItems = record.ReleasedItems
		entry.CleanupErrorCount = if record.CleanupErrors then #record.CleanupErrors else 0
		entry.StartedAt = record.StartedAt
		entry.EndedAt = record.EndedAt
		table.insert(list, entry)
	end
	return list
end

-- Resources still tracked by running patches (0 when nothing is running).
function PatchService.GetTrackedResourceCount(): number
	local total = 0
	for _, record in records do
		total += record.bag:Count()
	end
	return total
end

---------------------------------------------------------------------------------------------------
-- Setup

-- deps.isMatchLive(matchId): true while that match is ACTIVE or FINAL_PHASE.
-- deps.onChanged(): called after any lifecycle change (MatchService republishes its snapshot).
function PatchService.Init(deps: { isMatchLive: (number) -> boolean, onChanged: () -> () })
	isMatchLive = deps.isMatchLive
	onChanged = deps.onChanged
	local placeholder = require(patchModules:WaitForChild("Placeholder")) :: any
	for _, id in PatchCatalog.Ids() do
		behaviors[id] = placeholder
	end
	if RunService:IsStudio() then
		local tests = require(patchModules:WaitForChild("TestBehaviors")) :: any
		for id, entry in tests do
			assert(PatchCatalog.Get(id) == nil, `test patch {id} collides with an approved patch id`)
			behaviors[id] = entry
			testDefinitions[id] = entry.Definition
		end
	end
end

return PatchService

--!strict
-- BehaviorRuntime (Phase 7A, server only): the lifecycle contract shared by patch behaviours
-- (PatchService) and combination behaviours (PatchInteractionService). Extracted unchanged from
-- the Phase 3 PatchService so both owners get the same guarantees:
-- * RunHook: Activate / Deactivate run in their own coroutine, resumed once. A hook that yields is
--   cancelled at once (it can never resume) and reported as "yielded"; an error is "error".
-- * NewContext: the ctx handed to a behaviour. Everything it creates is tracked in the owner's
--   CleanupService bag — ctx.Add (instances, connections, threads, callbacks), ctx.AddModifier
--   (WorldModifierService tokens, owned by RuntimeId), ctx.Spawn / ctx.Delay (tracked threads).
--   After the bag is cleaned the context is inert: Spawn, Delay and AddModifier return nil and
--   Add releases its item immediately. ctx.IsLive is supplied by the owner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local services = script.Parent
local CleanupService = require(services:WaitForChild("CleanupService"))
local WorldModifierService = require(services:WaitForChild("WorldModifierService"))

export type ContextSpec = {
	RuntimeId: string,
	PatchId: string,
	MatchId: number,
	CreatorUserId: number,
	Bag: CleanupService.Bag,
	IsLive: () -> boolean,
}

local BehaviorRuntime = {}

-- Runs a behaviour hook under the non-yielding contract. Returns (true) or (false, kind, message)
-- where kind is "error" or "yielded". A yielded hook is cancelled and never resumes.
function BehaviorRuntime.RunHook(hook: (any) -> (), ctx: any): (boolean, string?, string?)
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

local function runtimeFolder(): Instance?
	local root = workspace:FindFirstChild(Config.RootName)
	return root and root:FindFirstChild("ActivePatchInstances")
end

function BehaviorRuntime.NewContext(spec: ContextSpec): any
	local bag = spec.Bag
	local ctx = {
		RuntimeId = spec.RuntimeId,
		PatchId = spec.PatchId,
		MatchId = spec.MatchId,
		CreatorUserId = spec.CreatorUserId,
		Folder = runtimeFolder(),
	}
	-- Tracks an instance / connection / thread / callback for cleanup; returns it.
	function ctx.Add(item: any): any
		return bag:Add(item)
	end
	-- Adds a WorldModifierService token owned by this behaviour; removed automatically at cleanup.
	-- Returns nil (and changes nothing) once the bag has been cleaned up.
	function ctx.AddModifier(property: string, op: any, value: number, priority: number?): string?
		if bag:IsCleaned() then
			return nil
		end
		local id = WorldModifierService.AddModifier(property, op, value, priority, spec.RuntimeId)
		bag:Add(function()
			WorldModifierService.RemoveModifier(id)
		end)
		return id
	end
	-- Tracked task: runs fn(...) on the next resumption cycle (never inside the tick). The thread
	-- may yield freely and is cancelled when the owner ends. Returns nil once cleaned up.
	function ctx.Spawn(fn: (...any) -> (), ...: any): thread?
		if bag:IsCleaned() then
			return nil
		end
		return bag:Add(task.defer(fn, ...))
	end
	-- Tracked delayed call: cancelled if the owner ends before it fires.
	function ctx.Delay(seconds: number, fn: (...any) -> (), ...: any): thread?
		if bag:IsCleaned() then
			return nil
		end
		return bag:Add(task.delay(seconds, fn, ...))
	end
	-- True while the owner is running in a live match; loops in behaviours must check this.
	ctx.IsLive = spec.IsLive
	return ctx
end

return table.freeze(BehaviorRuntime)

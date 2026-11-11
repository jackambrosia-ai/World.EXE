-- WORLD.EXE Phase 8A-2b targeted regression (SERVER side, solo Play only; nothing is saved).
-- The Studio MCP runner creates a Script "ZZ_Regress8A2B" in ServerScriptService with this Source
-- right after starting Play (an injected Script is needed: MCP code gets its own module instances).
--   1. ArenaService.Validate() and the baseline comparison at the start of match 1.
--   2. Each of the ten patches on its own (scale 0.3: about 1.4 s warning, 9-12 s active), through
--      PatchService.Request on the live match: accepted, reached ACTIVE, ended and released its slot.
--   3. The five combinations (both sources requested together): combination started, then
--      everything ended.
--   4. Baseline comparison after all patches.
--   5. The match runs out on its own: RESULTS -> RESET -> LOBBY -> next match; baseline at LOBBY,
--      the second match reaching ACTIVE and Validate there. StudioTimeScale 0.7 is set before
--      ACTIVE starts (the ACTIVE length is fixed on entry), giving about 4.9 minutes of ACTIVE play.
-- Before each request any Architect-started patch is cancelled so the test owns the slots.
--
-- Results (attributes on this Script):
--   Log      every step, one line each (PASS/FAIL marked per line)
--   Result   "PASS" only when every step passed; otherwise "FAIL"
--   Failures the failing steps (empty on PASS)
--   Done     true when execution finished (it does NOT mean the run passed; read Result)
-- Any rejected request, skipped test, missing ACTIVE, missing end, failed slot cleanup, baseline
-- mismatch, missed RESULTS/LOBBY or failed second match makes the overall Result FAIL.
-- Correction 2026-11-11: explicit overall Result (review of PR #15).
local ServerScriptService = game:GetService("ServerScriptService")
local root = ServerScriptService:WaitForChild("WORLD_EXE")
local svc = root:WaitForChild("Services")
local MatchService = require(svc:WaitForChild("MatchService"))
local PatchService = require(svc:WaitForChild("PatchService"))
local PIS = require(svc:WaitForChild("PatchInteractionService"))
local ArenaService = require(svc:WaitForChild("ArenaService"))

local me = script
local lines, failures = {}, {}
local function L(s: string)
	table.insert(lines, s)
	me:SetAttribute("Log", table.concat(lines, "\n"))
end
local function check(ok: boolean, label: string, detail: string?)
	L((if ok then "PASS " else "FAIL ") .. label .. (if detail then " | " .. detail else ""))
	if not ok then
		table.insert(failures, label)
		me:SetAttribute("Failures", table.concat(failures, "; "))
	end
	return ok
end
local function finish()
	me:SetAttribute("Result", if #failures == 0 then "PASS" else "FAIL")
	me:SetAttribute("Failures", table.concat(failures, "; "))
	me:SetAttribute("Done", true)
end
local function waitFor(pred: () -> boolean, timeout: number): boolean
	local t = os.clock() + timeout
	while os.clock() < t do
		if pred() then
			return true
		end
		task.wait(0.1)
	end
	return pred()
end
local function stateOf(rid: string): string?
	for _, v in PatchService.GetSnapshot() do
		if v.RuntimeId == rid then
			return v.State
		end
	end
	return nil
end
local function live(): boolean
	local s = MatchService.GetState()
	return s == "ACTIVE" or s == "FINAL_PHASE"
end

me:SetAttribute("Result", "RUNNING")
root:SetAttribute("StudioTimeScale", 0.7)
if not check(waitFor(function() return MatchService.GetState() == "ACTIVE" end, 120), "match 1 reached ACTIVE", MatchService.GetState()) then
	finish()
	return
end
local mid = MatchService.GetMatchId()
local v = ArenaService.Validate()
check(v.ok, "Validate at start", string.format("errors=%d%s", #v.errors, if #v.errors > 0 then " (" .. v.errors[1] .. ")" else ""))
check(ArenaService.MatchesBaseline(), "baseline at start")
me:SetAttribute("Phase", "patches")

local function clearSlots(label: string)
	PatchService.CancelAll("regression")
	local ok = waitFor(function() return #PatchService.GetSnapshot() == 0 and #PIS.GetSnapshot() == 0 end, 15)
	if not ok then
		check(false, "slot cleanup before " .. label, string.format("patches=%d combinations=%d", #PatchService.GetSnapshot(), #PIS.GetSnapshot()))
	end
	return ok
end

local PATCHES = { "ZERO_G", "DECAY", "DRONE_SWARM", "SUPPLY_DROP", "BOUNCY", "SLIPPERY", "BLACKOUT", "MAGNETIC", "CORRUPTION", "FLOOD" }
for _, id in PATCHES do
	if not live() then
		check(false, id, "SKIPPED: match not live")
		continue
	end
	clearSlots(id)
	local ok, rid = PatchService.Request(id, 0, mid, 0.3)
	if not ok then
		check(false, id, "REJECTED " .. tostring(rid))
	else
		local active = waitFor(function() return stateOf(rid) == "ACTIVE" end, 10)
		local ended = waitFor(function() return stateOf(rid) == nil end, 30)
		check(active and ended, id, string.format("%s active=%s ended=%s", rid, tostring(active), tostring(ended)))
	end
end

local COMBOS = { { "ZERO_G", "BOUNCY", "SUPER_BOUNCE" }, { "BLACKOUT", "DRONE_SWARM", "HUNTER_SCAN" }, { "FLOOD", "MAGNETIC", "FLOATING_DEBRIS" }, { "DECAY", "CORRUPTION", "RAPID_DECAY" }, { "SLIPPERY", "MAGNETIC", "SLIDE_FIELD" } }
for _, c in COMBOS do
	if not live() then
		check(false, c[3], "SKIPPED: match not live")
		continue
	end
	clearSlots(c[3])
	local before = #PIS.GetHistory()
	local ok1, r1 = PatchService.Request(c[1], 0, mid, 0.3)
	local ok2, r2 = PatchService.Request(c[2], 0, mid, 0.3)
	local started = waitFor(function()
		for _, e in PIS.GetSnapshot() do
			if e.Id == c[3] then
				return true
			end
		end
		return false
	end, 12)
	local ended = waitFor(function()
		return (not ok1 or stateOf(r1) == nil) and (not ok2 or stateOf(r2) == nil) and #PIS.GetSnapshot() == 0
	end, 40)
	check(ok1 and ok2 and started and ended, c[3], string.format("%s + %s: requests %s/%s, combination started=%s, all ended=%s, history +%d", c[1], c[2], tostring(ok1), tostring(ok2), tostring(started), tostring(ended), #PIS.GetHistory() - before))
end
check(ArenaService.MatchesBaseline(), "baseline after patches")
check(#PatchService.GetSnapshot() == 0, "no patches tracked after the tests", "tracked=" .. #PatchService.GetSnapshot())

me:SetAttribute("Phase", "cleanup")
check(waitFor(function() return MatchService.GetState() == "RESULTS" end, 360), "match 1 reached RESULTS", MatchService.GetState())
check(waitFor(function() return MatchService.GetState() == "LOBBY" end, 120), "RESET -> LOBBY", MatchService.GetState())
local cmp = ArenaService.CompareToBaseline()
check(cmp.matches, "baseline at LOBBY", string.format("differences %d%s", cmp.total, if cmp.total > 0 then " first: " .. cmp.differences[1] else ""))
local second = waitFor(function() return MatchService.GetMatchId() > mid and MatchService.GetState() == "ACTIVE" end, 120)
check(second, "second match reached ACTIVE", "match " .. MatchService.GetMatchId())
check(ArenaService.Validate().ok, "Validate in the second match")
finish()

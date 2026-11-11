-- WORLD.EXE Phase 8A-2b targeted regression (SERVER side, solo Play only; nothing is saved).
-- The Studio MCP runner creates a Script "ZZ_Regress8A2B" in ServerScriptService with this Source
-- right after starting Play (an injected Script is needed: MCP code gets its own module instances).
-- Results are written to the Script's "Log" attribute; the runner reads them through MCP.
--   1. ArenaService.Validate() and the baseline comparison at the start of match 1.
--   2. Each of the ten patches on its own (scale 0.3: about 1.4 s warning, 9-12 s active), through
--      PatchService.Request on the live match: accepted, reached ACTIVE, ended and released its slot.
--   3. The five combinations (both sources requested together): combination started, then
--      everything ended.
--   4. Baseline comparison after all patches.
--   5. The match then runs out on its own: RESULTS -> RESET -> LOBBY -> next match; baseline at
--      LOBBY and the second match reaching ACTIVE. StudioTimeScale 0.7 is set before ACTIVE starts
--      (the ACTIVE length is fixed on entry), giving about 4.9 minutes of ACTIVE play.
-- Before each request any Architect-started patch is cancelled so the test owns the slots.
local ServerScriptService = game:GetService("ServerScriptService")
local root = ServerScriptService:WaitForChild("WORLD_EXE")
local svc = root:WaitForChild("Services")
local MatchService = require(svc:WaitForChild("MatchService"))
local PatchService = require(svc:WaitForChild("PatchService"))
local PIS = require(svc:WaitForChild("PatchInteractionService"))
local ArenaService = require(svc:WaitForChild("ArenaService"))

local me = script
local lines = {}
local function L(s: string)
	table.insert(lines, s)
	me:SetAttribute("Log", table.concat(lines, "\n"))
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

root:SetAttribute("StudioTimeScale", 0.7)
L("waiting for ACTIVE")
if not waitFor(function() return MatchService.GetState() == "ACTIVE" end, 120) then
	L("ERROR: match did not reach ACTIVE (" .. MatchService.GetState() .. ")")
	me:SetAttribute("Done", true)
	return
end
local mid = MatchService.GetMatchId()
local v = ArenaService.Validate()
L(string.format("match %d ACTIVE | Validate ok=%s errors=%d%s | baseline at start: %s", mid, tostring(v.ok), #v.errors, if #v.errors > 0 then " (" .. v.errors[1] .. ")" else "", tostring(ArenaService.MatchesBaseline())))
me:SetAttribute("Phase", "patches")

local function clearSlots()
	PatchService.CancelAll("regression")
	waitFor(function() return #PatchService.GetSnapshot() == 0 and #PIS.GetSnapshot() == 0 end, 15)
end
local PATCHES = { "ZERO_G", "DECAY", "DRONE_SWARM", "SUPPLY_DROP", "BOUNCY", "SLIPPERY", "BLACKOUT", "MAGNETIC", "CORRUPTION", "FLOOD" }
for _, id in PATCHES do
	if not live() then
		L(id .. ": SKIPPED (match not live)")
		continue
	end
	clearSlots()
	local ok, rid = PatchService.Request(id, 0, mid, 0.3)
	if not ok then
		L(id .. ": REJECTED " .. tostring(rid))
	else
		local active = waitFor(function() return stateOf(rid) == "ACTIVE" end, 10)
		local ended = waitFor(function() return stateOf(rid) == nil end, 30)
		L(string.format("%s: %s active=%s ended=%s", id, rid, tostring(active), tostring(ended)))
	end
end

local COMBOS = { { "ZERO_G", "BOUNCY", "SUPER_BOUNCE" }, { "BLACKOUT", "DRONE_SWARM", "HUNTER_SCAN" }, { "FLOOD", "MAGNETIC", "FLOATING_DEBRIS" }, { "DECAY", "CORRUPTION", "RAPID_DECAY" }, { "SLIPPERY", "MAGNETIC", "SLIDE_FIELD" } }
for _, c in COMBOS do
	if not live() then
		L(c[3] .. ": SKIPPED (match not live)")
		continue
	end
	clearSlots()
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
	L(string.format("%s (%s + %s): requests %s/%s, combination started=%s, all ended=%s, history +%d", c[3], c[1], c[2], tostring(ok1), tostring(ok2), tostring(started), tostring(ended), #PIS.GetHistory() - before))
end
L("baseline after patches: " .. tostring(ArenaService.MatchesBaseline()) .. " | patches still tracked: " .. #PatchService.GetSnapshot())

me:SetAttribute("Phase", "cleanup")
local sawResults = waitFor(function() return MatchService.GetState() == "RESULTS" end, 360)
local sawLobby = waitFor(function() return MatchService.GetState() == "LOBBY" end, 120)
local cmp = ArenaService.CompareToBaseline()
L(string.format("match end: RESULTS=%s LOBBY=%s | baseline at LOBBY matches=%s (differences %d)%s", tostring(sawResults), tostring(sawLobby), tostring(cmp.matches), cmp.total, if cmp.total > 0 then " first: " .. cmp.differences[1] else ""))
local second = waitFor(function() return MatchService.GetMatchId() > mid and MatchService.GetState() == "ACTIVE" end, 120)
L(string.format("second match %d ACTIVE=%s | Validate ok=%s", MatchService.GetMatchId(), tostring(second), tostring(ArenaService.Validate().ok)))
me:SetAttribute("Done", true)

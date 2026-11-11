-- WORLD.EXE Phase 8A-2: FPS benchmark pass B (SERVER side): server Heartbeat under a 3-patch load.
--
-- How to run (docs/PHASE_8A2_ARCHITECTURE_DESIGN.md section 9.3):
--   Immediately after starting Play (solo), the Studio MCP runner creates a Script in
--   ServerScriptService named "ZZ_FPSBenchServer" with this file as its Source and enables it.
--   (Code executed directly through MCP gets its own module instances, so the load must be
--   applied from an injected Script that shares the game's modules.)
--   Results are written as attributes on that Script; the runner reads them, then stops Play.
--   Nothing is saved: the Script exists only inside the Play session.
--
-- Sequence: StudioTimeScale 3 (a long ACTIVE phase) -> wait for ACTIVE -> request ZERO_G,
-- CORRUPTION and FLOOD -> wait until all three are active -> sample Heartbeat for 30 s ->
-- cancel the benchmark patches -> report.

local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local root = ServerScriptService:WaitForChild("WORLD_EXE")
local services = root:WaitForChild("Services")
local MatchService = require(services:WaitForChild("MatchService"))
local PatchService = require(services:WaitForChild("PatchService"))

local SAMPLE_SECONDS = 30
local PATCHES = { "ZERO_G", "CORRUPTION", "FLOOD" }

local me = script
me:SetAttribute("Status", "waiting_for_active")
root:SetAttribute("StudioTimeScale", 3)

local deadline = os.clock() + 120
while MatchService.GetState() ~= "ACTIVE" and os.clock() < deadline do
	task.wait(0.25)
end
if MatchService.GetState() ~= "ACTIVE" then
	me:SetAttribute("Status", "error")
	me:SetAttribute("Error", "match did not reach ACTIVE within 120 s (state " .. MatchService.GetState() .. ")")
	return
end

local player = Players:GetPlayers()[1]
local creator = if player then player.UserId else 0
local matchId = MatchService.GetMatchId()
-- Free all 3 slots first, so a turn patch that is already running cannot cause "capacity_full".
PatchService.CancelAll("fps_benchmark_start")
local accepted = {}
for _, id in PATCHES do
	local ok, info = PatchService.Request(id, creator, matchId, 1, { SourceKey = "fpsbench:" .. matchId .. ":" .. id })
	table.insert(accepted, id .. "=" .. (if ok then "ok" else info))
end
me:SetAttribute("Requests", table.concat(accepted, ","))
me:SetAttribute("Status", "warning_period")

-- Wait until all requested patches are ACTIVE (warning is 4.5 s at scale 1), at most 15 s.
local function activeCount(): number
	local n = 0
	for _, view in PatchService.GetSnapshot() do
		if view.State == "ACTIVE" then
			n += 1
		end
	end
	return n
end
local t0 = os.clock()
while activeCount() < #PATCHES and os.clock() - t0 < 15 do
	task.wait(0.25)
end
me:SetAttribute("ActivePatchesAtStart", activeCount())
me:SetAttribute("Status", "sampling")

local steps = {}
local conn = RunService.Heartbeat:Connect(function(dt)
	table.insert(steps, dt)
end)
task.wait(SAMPLE_SECONDS)
conn:Disconnect()

local sum = 0
for _, dt in steps do
	sum += dt
end
table.sort(steps)
local n = #steps
me:SetAttribute("ActivePatchesAtEnd", activeCount())
me:SetAttribute("HeartbeatSamples", n)
me:SetAttribute("HeartbeatAvgMs", if n > 0 then sum / n * 1000 else 0)
me:SetAttribute("HeartbeatP99Ms", if n > 0 then steps[math.max(1, math.ceil(n * 0.99))] * 1000 else 0)
me:SetAttribute("ServerFps", if sum > 0 then n / sum else 0)

PatchService.CancelAll("fps_benchmark_end")
root:SetAttribute("StudioTimeScale", nil)
me:SetAttribute("Status", "done")

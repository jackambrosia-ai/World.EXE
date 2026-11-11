-- WORLD.EXE Phase 8A-2: FPS benchmark (SERVER side). Hardened for Stage 0 (2026-11-11).
--
-- Run (docs/PHASE_8A2_ARCHITECTURE_DESIGN.md section 9.3):
--   Right after starting Play (solo), the Studio MCP runner creates a Script named
--   "ZZ_FPSBenchServer" in ServerScriptService with this file as its Source. An injected Script is
--   needed because code executed through MCP gets its own module instances.
--   Everything happens inside the Play session; nothing is saved or persisted.
--
-- Protocol:
--   1. Sets StudioTimeScale 3 (a long ACTIVE phase) and creates a test-only RemoteEvent
--      ReplicatedStorage.ZZ_FPSBenchSignal (Play session only; not part of the game).
--   2. Waits for the match to reach ACTIVE, then publishes workspace attribute ZZ_FPSBench_Phase = "ready_for_A".
--   3. Waits for the client to fire "A_done" (the client runs pass A on its own).
--   4. Pass B: cancels running patches, requests ZERO_G, CORRUPTION and FLOOD at scale 2
--      (warning 9 s, duration 70 s), waits until all three are ACTIVE, then samples Heartbeat for
--      30 s. Every 0.1 s it verifies that the three SPECIFIC runtime ids are all still ACTIVE.
--   5. The measurement is VALID only if all three requests were accepted, all three were ACTIVE at
--      the start, and all three stayed ACTIVE for the whole sampling window. Otherwise it is
--      INVALID, and the reason is recorded.
--   Results are written as attributes on this Script; the runner reads them through MCP.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local root = ServerScriptService:WaitForChild("WORLD_EXE")
local services = root:WaitForChild("Services")
local MatchService = require(services:WaitForChild("MatchService"))
local PatchService = require(services:WaitForChild("PatchService"))

local SAMPLE_SECONDS = 30
local PATCH_SCALE = 2
local CHECK_INTERVAL = 0.1
local PATCHES = { "ZERO_G", "CORRUPTION", "FLOOD" }

local me = script
local function phase(p: string)
	me:SetAttribute("Status", p)
	workspace:SetAttribute("ZZ_FPSBench_Phase", p)
end

root:SetAttribute("StudioTimeScale", 3)
local signal = Instance.new("RemoteEvent")
signal.Name = "ZZ_FPSBenchSignal"
signal.Parent = ReplicatedStorage

local clientAState: string? = nil
signal.OnServerEvent:Connect(function(_player, message)
	if type(message) == "string" then
		clientAState = message
	end
end)

phase("waiting_for_active")
local deadline = os.clock() + 180
while MatchService.GetState() ~= "ACTIVE" and os.clock() < deadline do
	task.wait(0.25)
end
if MatchService.GetState() ~= "ACTIVE" then
	me:SetAttribute("Valid", false)
	me:SetAttribute("InvalidReason", "match did not reach ACTIVE within 180 s (state " .. MatchService.GetState() .. ")")
	phase("error")
	return
end
phase("ready_for_A")

-- Wait for the client's pass A (it starts when the owner clicks into Studio), at most 10 minutes.
local waitA = os.clock() + 600
while clientAState == nil and os.clock() < waitA do
	task.wait(0.25)
end
me:SetAttribute("ClientPassA", clientAState or "timeout")
if clientAState == nil or MatchService.GetState() ~= "ACTIVE" then
	me:SetAttribute("Valid", false)
	me:SetAttribute("InvalidReason", "client pass A did not finish while the match was ACTIVE")
	phase("error")
	return
end

-- Pass B: the three-patch load.
phase("requesting")
PatchService.CancelAll("fps_benchmark_start")
local player = Players:GetPlayers()[1]
local creator = if player then player.UserId else 0
local matchId = MatchService.GetMatchId()
local runtimeIds: { [string]: string } = {}
local requestLog = {}
local allAccepted = true
for _, id in PATCHES do
	local ok, info = PatchService.Request(id, creator, matchId, PATCH_SCALE, { SourceKey = "fpsbench:" .. matchId .. ":" .. id })
	table.insert(requestLog, id .. "=" .. (if ok then info else "REJECTED:" .. info))
	if ok then
		runtimeIds[id] = info
	else
		allAccepted = false
	end
end
me:SetAttribute("Requests", table.concat(requestLog, ","))

-- Returns how many of OUR three runtime ids are ACTIVE right now, plus a list of the others' states.
local function ourActive(): (number, string)
	local states = {}
	for _, view in PatchService.GetSnapshot() do
		states[view.RuntimeId] = view.State
	end
	local n = 0
	local detail = {}
	for _, id in PATCHES do
		local rid = runtimeIds[id]
		local st = if rid then (states[rid] or "GONE") else "NOT_REQUESTED"
		if st == "ACTIVE" then
			n += 1
		end
		table.insert(detail, id .. ":" .. st)
	end
	return n, table.concat(detail, ",")
end

phase("warning_period")
local t0 = os.clock()
local count = 0
while os.clock() - t0 < 20 do
	count = ourActive()
	if count == #PATCHES then
		break
	end
	task.wait(0.1)
end
local _, startDetail = ourActive()
me:SetAttribute("ActiveAtStart", count)
me:SetAttribute("StatesAtStart", startDetail)

-- Sampling window, with continuous verification.
phase("sampling")
local steps = {}
local minActive = #PATCHES
local firstBreak: string? = nil
local sinceCheck = 0
local sampleStart = os.clock()
local conn = RunService.Heartbeat:Connect(function(dt)
	table.insert(steps, dt)
	sinceCheck += dt
	if sinceCheck >= CHECK_INTERVAL then
		sinceCheck = 0
		local n, detail = ourActive()
		if n < minActive then
			minActive = n
		end
		if n < #PATCHES and firstBreak == nil then
			firstBreak = string.format("%.2f s into sampling: %s", os.clock() - sampleStart, detail)
		end
	end
end)
task.wait(SAMPLE_SECONDS)
conn:Disconnect()
local endCount, endDetail = ourActive()
phase("done_sampling")

local sum = 0
for _, dt in steps do
	sum += dt
end
table.sort(steps)
local n = #steps
me:SetAttribute("HeartbeatSamples", n)
me:SetAttribute("HeartbeatAvgMs", if n > 0 then sum / n * 1000 else 0)
me:SetAttribute("HeartbeatP99Ms", if n > 0 then steps[math.max(1, math.ceil(n * 0.99))] * 1000 else 0)
me:SetAttribute("HeartbeatMaxMs", if n > 0 then steps[n] * 1000 else 0)
me:SetAttribute("ServerFps", if sum > 0 then n / sum else 0)
me:SetAttribute("MinOurActiveDuringSampling", minActive)
me:SetAttribute("ActiveAtEnd", endCount)
me:SetAttribute("StatesAtEnd", endDetail)
me:SetAttribute("MatchStateAtEnd", MatchService.GetState())

local reason: string? = nil
if not allAccepted then
	reason = "not all three patches were accepted: " .. table.concat(requestLog, ",")
elseif count < #PATCHES then
	reason = "not all three patches were ACTIVE when sampling began: " .. startDetail
elseif firstBreak then
	reason = "a requested patch left ACTIVE during sampling at " .. firstBreak
elseif minActive < #PATCHES or endCount < #PATCHES then
	reason = "fewer than three requested patches ACTIVE at the end: " .. endDetail
elseif n < SAMPLE_SECONDS * 30 then
	reason = "too few Heartbeat samples (" .. n .. ")"
end
me:SetAttribute("Valid", reason == nil)
me:SetAttribute("InvalidReason", reason or "")

PatchService.CancelAll("fps_benchmark_end")
root:SetAttribute("StudioTimeScale", nil)
phase("done")

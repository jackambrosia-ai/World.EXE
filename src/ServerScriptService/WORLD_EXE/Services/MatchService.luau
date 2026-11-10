--!strict
-- MatchService (Phase 2, server only). The ONLY module that changes match state.
--
-- LOBBY -> COUNTDOWN -> INITIALIZING -> ACTIVE -> FINAL_PHASE -> RESULTS -> RESET -> LOBBY
-- Also: COUNTDOWN -> LOBBY (not enough players), INITIALIZING/ACTIVE -> RESULTS (no participants).
--
-- A single server loop evaluates deadlines every Config.Match.TickSeconds, so there are no
-- per-state timer callbacks that could fire into a later match. MatchId increments when a
-- match initializes; everything match-scoped (Architect turns, results) carries it.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local services = script.Parent
local ArenaService = require(services:WaitForChild("ArenaService"))
local NetService = require(services:WaitForChild("NetService"))
local PlayerStateService = require(services:WaitForChild("PlayerStateService"))
local ArchitectService = require(services:WaitForChild("ArchitectService"))

local S = Config.MatchStates
local Roles = Config.Roles
local Timing = Config.Match

local ALLOWED: { [string]: { [string]: boolean } } = {
	[S.Lobby] = { [S.Countdown] = true },
	[S.Countdown] = { [S.Lobby] = true, [S.Initializing] = true },
	[S.Initializing] = { [S.Active] = true, [S.Results] = true },
	[S.Active] = { [S.FinalPhase] = true, [S.Results] = true },
	[S.FinalPhase] = { [S.Results] = true },
	[S.Results] = { [S.Reset] = true },
	[S.Reset] = { [S.Lobby] = true },
}

local MatchService = {}

local stateFolder: Folder = nil :: any
local controls: Instance? = nil -- ServerScriptService.WORLD_EXE (Studio-only test controls)
local state = S.Lobby
local matchId = 0
local stateStartedAt = 0
local stateEndsAt = 0
local activeStartedAt = 0
local outcome = ""
local outcomeReason = ""
local participants: { Player } = {}
local transitionLog: { string } = {}
local running = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function studioNumber(name: string, default: number): number
	if RunService:IsStudio() and controls then
		local value = controls:GetAttribute(name)
		if typeof(value) == "number" and value == value and value > 0 and value < math.huge then
			return value
		end
	end
	return default
end

local function timeScale(): number
	return studioNumber(Config.StudioControls.TimeScale, 1)
end

local function minPlayers(): number
	if RunService:IsStudio() then
		return math.floor(studioNumber(Config.StudioControls.MinPlayers, Timing.StudioMinPlayers))
	end
	return Timing.MinPlayers
end

local function snapshot(reason: string): { [string]: any }
	return {
		State = state,
		MatchId = matchId,
		StateStartedAt = stateStartedAt,
		StateEndsAt = stateEndsAt,
		ParticipantCount = #participants,
		MinPlayers = minPlayers(),
		Reason = reason,
	}
end

local function publish(reason: string)
	for key, value in snapshot(reason) do
		stateFolder:SetAttribute(key, value)
	end
	NetService.Get(Config.Remotes.MatchStateChanged):FireAllClients(snapshot(reason))
end

local function lobbyCount(): number
	return #PlayerStateService.GetPlayersWithRole(Roles.Lobby)
end

local function removeParticipant(player: Player)
	local index = table.find(participants, player)
	if index then
		table.remove(participants, index)
	end
end

local function buildResults(): string
	local names = {}
	for _, player in participants do
		table.insert(names, player.DisplayName)
	end
	local accepted, skipped = 0, 0
	local turns = {}
	for _, result in ArchitectService.GetHistory() do
		if result.Outcome == "accepted" then
			accepted += 1
		else
			skipped += 1
		end
		table.insert(turns, { Turn = result.Turn, Architect = result.ArchitectName, Outcome = result.Outcome, PatchId = result.PatchId })
	end
	return HttpService:JSONEncode({
		MatchId = matchId,
		Outcome = outcome,
		Reason = outcomeReason,
		DurationSeconds = if activeStartedAt > 0 then math.floor(now() - activeStartedAt) else 0,
		Participants = names,
		TurnsAccepted = accepted,
		TurnsSkipped = skipped,
		Turns = turns,
	})
end

---------------------------------------------------------------------------------------------------
-- Transitions

local enter: { [string]: () -> () } = {}

local function transition(to: string, reason: string)
	local from = state
	assert(ALLOWED[from] and ALLOWED[from][to], `illegal match transition {from} -> {to}`)
	state = to
	stateStartedAt = now()
	stateEndsAt = 0
	table.insert(transitionLog, `{matchId}:{from}->{to}:{reason}`)
	if #transitionLog > 50 then
		table.remove(transitionLog, 1)
	end
	print(`[WORLD_EXE] Match {matchId}: {from} -> {to} ({reason})`)
	local hook = enter[to]
	if hook then
		hook()
	end
	publish(reason)
end

local function deadline(seconds: number)
	stateEndsAt = now() + seconds * timeScale()
end

enter[S.Lobby] = function()
	participants = {}
	outcome, outcomeReason = "", ""
	activeStartedAt = 0
end

enter[S.Countdown] = function()
	deadline(Timing.CountdownSeconds)
end

enter[S.Initializing] = function()
	matchId += 1
	participants = {}
	for _, player in PlayerStateService.GetPlayersWithRole(Roles.Lobby) do
		if #participants < Timing.MaxParticipants then
			table.insert(participants, player)
		end
	end
	PlayerStateService.SetArenaPhase(true)
	for _, player in Players:GetPlayers() do
		local role = if table.find(participants, player) then Roles.Participant else Roles.Spectator
		PlayerStateService.SetRole(player, role)
	end
	PlayerStateService.SetSpawnProtection(true)
	PlayerStateService.SpawnParticipants(participants)
	deadline(Timing.InitializingSeconds)
end

enter[S.Active] = function()
	PlayerStateService.SetSpawnProtection(false)
	activeStartedAt = now()
	ArchitectService.StartMatch(matchId, participants, timeScale())
	deadline(Timing.ActiveSeconds)
end

enter[S.FinalPhase] = function()
	-- Phase 2 policy: no new Architect turns in the final phase.
	ArchitectService.StopMatch("cancelled")
	deadline(Timing.FinalPhaseSeconds)
end

enter[S.Results] = function()
	ArchitectService.StopMatch("cancelled")
	PlayerStateService.SetSpawnProtection(false)
	PlayerStateService.SetArenaPhase(false)
	stateFolder:SetAttribute("LastResult", buildResults())
	deadline(Timing.ResultsSeconds)
end

enter[S.Reset] = function()
	local removed, problems = ArenaService.ResetRuntime()
	for _, problem in problems do
		warn(`[WORLD_EXE] Reset: {problem}`)
	end
	local baseline = ArenaService.CompareToBaseline()
	if not baseline.matches then
		warn(`[WORLD_EXE] Reset: arena differs from baseline ({baseline.total} differences): {baseline.differences[1]}`)
	end
	stateFolder:SetAttribute("LastResetRemoved", removed)
	stateFolder:SetAttribute("LastResetBaselineMatches", baseline.matches)
	participants = {}
	for _, player in Players:GetPlayers() do
		PlayerStateService.SetRole(player, Roles.Lobby)
	end
	PlayerStateService.ReturnAllToLobby()
	deadline(Timing.ResetSeconds)
end

local function finish(result: string, reason: string)
	outcome, outcomeReason = result, reason
	transition(S.Results, reason)
end

---------------------------------------------------------------------------------------------------
-- Loop

local function tick()
	local t = now()
	if state == S.Lobby then
		if lobbyCount() >= minPlayers() then
			transition(S.Countdown, "enough players")
		end
	elseif state == S.Countdown then
		if lobbyCount() < minPlayers() then
			transition(S.Lobby, "countdown cancelled: not enough players")
		elseif t >= stateEndsAt then
			transition(S.Initializing, "countdown complete")
		end
	elseif state == S.Initializing then
		if #participants == 0 then
			finish("aborted", "no participants")
		elseif t >= stateEndsAt then
			transition(S.Active, "initialized")
		end
	elseif state == S.Active then
		if #participants == 0 then
			finish("aborted", "no participants")
		elseif t >= stateEndsAt then
			transition(S.FinalPhase, "time")
		else
			ArchitectService.Update(timeScale())
		end
	elseif state == S.FinalPhase then
		if #participants == 0 then
			finish("aborted", "no participants")
		elseif t >= stateEndsAt then
			finish("completed", "time")
		end
	elseif state == S.Results then
		if t >= stateEndsAt then
			transition(S.Reset, "results shown")
		end
	elseif state == S.Reset then
		if t >= stateEndsAt then
			transition(S.Lobby, "reset complete")
		end
	end
end

local function onPlayerLeft(player: Player)
	ArchitectService.OnPlayerLeft(player)
	if table.find(participants, player) then
		removeParticipant(player)
		stateFolder:SetAttribute("ParticipantCount", #participants)
	end
end

---------------------------------------------------------------------------------------------------
-- Public

function MatchService.GetState(): string
	return state
end

function MatchService.GetMatchId(): number
	return matchId
end

function MatchService.GetTransitionLog(): { string }
	return table.clone(transitionLog)
end

function MatchService.Init(controlFolder: Instance)
	controls = controlFolder
	local shared = ReplicatedStorage:WaitForChild("WORLD_EXE")
	local existing = shared:FindFirstChild(Config.MatchStateFolder)
	if existing then
		assert(existing:IsA("Folder"), "ReplicatedStorage.WORLD_EXE.MatchState must be a Folder")
		stateFolder = existing
	else
		local folder = Instance.new("Folder")
		folder.Name = Config.MatchStateFolder
		folder.Parent = shared
		stateFolder = folder
	end
	stateFolder:SetAttribute("LastResult", "")
	ArchitectService.Init(stateFolder)
	PlayerStateService.SetJoinPolicy(function()
		return if state == S.Lobby or state == S.Countdown then Roles.Lobby else Roles.Spectator
	end)
	PlayerStateService.OnPlayerLeft(onPlayerLeft)
	enter[S.Lobby]()
	publish("server start")
end

function MatchService.Start()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while running do
			task.wait(Timing.TickSeconds)
			local ok, err = pcall(tick)
			if not ok then
				warn(`[WORLD_EXE] MatchService tick error: {err}`)
			end
		end
	end)
end

-- Server shutdown: stop turns and clear runtime objects.
function MatchService.Shutdown()
	running = false
	ArchitectService.StopMatch("cancelled")
	ArenaService.ResetRuntime()
end

return MatchService

--!strict
-- MatchService (Phase 2, server only). The ONLY module that changes match state.
--
-- LOBBY -> COUNTDOWN -> INITIALIZING -> ACTIVE -> FINAL_PHASE -> RESULTS -> RESET -> LOBBY
-- Also: COUNTDOWN -> LOBBY (not enough players), INITIALIZING/ACTIVE/FINAL_PHASE -> RESULTS
-- (no participants), and any state -> LOBBY via recovery when a state's entry hook fails.
--
-- A single server loop evaluates deadlines every Config.Match.TickSeconds, so there are no
-- per-state timer callbacks that could fire into a later match. MatchId increments when a
-- match initializes; everything match-scoped (Architect turns, results) carries it.
--
-- Replication: the whole state (match + Architect turn + last result) is published as ONE JSON
-- attribute with a monotonically increasing Version, so clients never observe a half-updated
-- state. Publishing is suppressed while a transition is in progress and done once at the end.

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
local PatchService = require(services:WaitForChild("PatchService"))
local WorldModifierService = require(services:WaitForChild("WorldModifierService"))

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
local lastReason = ""
local lastResult: { [string]: any }? = nil
local lastResetRemoved = 0
local lastResetBaselineMatches = true
local lastResetPatchesCancelled = 0
local lastResetModifiersCleared = 0
local lastResetWorldAtBaseline = true
local recoveries = 0
local version = 0
local inTransition = false
local participants: { Player } = {}
local transitionLog: { string } = {}
local running = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function studioValue(name: string): any
	if RunService:IsStudio() and controls then
		return controls:GetAttribute(name)
	end
	return nil
end

local function studioNumber(name: string, default: number): number
	local value = studioValue(name)
	if typeof(value) == "number" and value == value and value > 0 and value < math.huge then
		return value
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

---------------------------------------------------------------------------------------------------
-- Snapshot

local function snapshot(): { [string]: any }
	return {
		Version = version,
		State = state,
		MatchId = matchId,
		StateStartedAt = stateStartedAt,
		StateEndsAt = stateEndsAt,
		ParticipantCount = #participants,
		MinPlayers = minPlayers(),
		Reason = lastReason,
		Recoveries = recoveries,
		Turn = ArchitectService.GetTurnSnapshot(),
		LastResult = lastResult,
		LastResetRemoved = lastResetRemoved,
		LastResetBaselineMatches = lastResetBaselineMatches,
		LastResetPatchesCancelled = lastResetPatchesCancelled,
		LastResetModifiersCleared = lastResetModifiersCleared,
		LastResetWorldAtBaseline = lastResetWorldAtBaseline,
		Patches = PatchService.GetSnapshot(),
		PatchCapacity = Config.Patches.MaxActiveMajor,
	}
end

-- Publishes one consistent, versioned snapshot (skipped mid-transition; the transition publishes).
local function publish()
	if inTransition or stateFolder == nil then
		return
	end
	version += 1
	local snap = snapshot()
	stateFolder:SetAttribute(Config.MatchSnapshotAttribute, HttpService:JSONEncode(snap))
	NetService.Get(Config.Remotes.MatchStateChanged):FireAllClients(snap)
end

local function lobbyCount(): number
	return #PlayerStateService.GetPlayersWithRole(Roles.Lobby)
end

local function buildResults(): { [string]: any }
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
	return {
		MatchId = matchId,
		Outcome = outcome,
		Reason = outcomeReason,
		DurationSeconds = if activeStartedAt > 0 then math.floor(now() - activeStartedAt) else 0,
		Participants = names,
		TurnsAccepted = accepted,
		TurnsSkipped = skipped,
		Turns = turns,
	}
end

---------------------------------------------------------------------------------------------------
-- Transitions

local enter: { [string]: () -> () } = {}

local function logTransition(from: string, to: string, reason: string)
	table.insert(transitionLog, `{matchId}:{from}->{to}:{reason}`)
	if #transitionLog > 50 then
		table.remove(transitionLog, 1)
	end
	print(`[WORLD_EXE] Match {matchId}: {from} -> {to} ({reason})`)
end

-- Returns every player to a clean lobby state after a failed entry hook. Each step is isolated
-- so one failure cannot stop the rest; the state always ends in LOBBY with no participants.
local function recover(failedState: string, err: any)
	warn(`[WORLD_EXE] Match {matchId}: entering {failedState} failed: {err}. Recovering to LOBBY.`)
	local steps: { () -> () } = {
		function()
			ArchitectService.StopMatch("cancelled")
		end,
		function()
			PatchService.CancelAll("recovery")
		end,
		function()
			WorldModifierService.ClearAll()
		end,
		function()
			PlayerStateService.SetSpawnProtection(false)
		end,
		function()
			PlayerStateService.SetArenaPhase(false)
		end,
		function()
			for _, player in Players:GetPlayers() do
				PlayerStateService.SetRole(player, Roles.Lobby)
			end
		end,
		function()
			PlayerStateService.ReturnAllToLobby()
		end,
		function()
			ArenaService.ResetRuntime()
		end,
	}
	for _, step in steps do
		local ok, stepErr = pcall(step)
		if not ok then
			warn(`[WORLD_EXE] Recovery step failed: {stepErr}`)
		end
	end
	participants = {}
	outcome, outcomeReason = "", ""
	activeStartedAt = 0
	recoveries += 1
	logTransition(failedState, S.Lobby, "recovery")
	state = S.Lobby
	stateStartedAt = now()
	stateEndsAt = 0
	lastReason = `recovered: entering {failedState} failed`
end

local function transition(to: string, reason: string)
	local from = state
	assert(ALLOWED[from] and ALLOWED[from][to], `illegal match transition {from} -> {to}`)
	inTransition = true
	state = to
	stateStartedAt = now()
	stateEndsAt = 0
	lastReason = reason
	logTransition(from, to, reason)
	local ok, err = pcall(function()
		local hook = enter[to]
		if hook then
			hook()
		end
		-- Studio-only fault injection for tests: fail after the hook has done its work.
		if studioValue(Config.StudioControls.FailOnEnter) == to then
			error("injected test failure")
		end
	end)
	if not ok then
		recover(to, err)
	end
	inTransition = false
	publish()
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
	-- Approved policy: no new Architect turns in the final phase.
	ArchitectService.StopMatch("cancelled")
	deadline(Timing.FinalPhaseSeconds)
end

enter[S.Results] = function()
	ArchitectService.StopMatch("cancelled")
	-- Patches never outlive their match.
	PatchService.CancelAll("match_end")
	WorldModifierService.ClearAll()
	PlayerStateService.SetSpawnProtection(false)
	PlayerStateService.SetArenaPhase(false)
	lastResult = buildResults()
	deadline(Timing.ResultsSeconds)
end

enter[S.Reset] = function()
	-- Patch resources first (idempotent; normally already ended at RESULTS), then shared world
	-- properties, then any leftover runtime objects.
	lastResetPatchesCancelled = PatchService.CancelAll("reset")
	lastResetModifiersCleared = WorldModifierService.ClearAll()
	lastResetWorldAtBaseline = WorldModifierService.IsAtBaseline()
	PatchService.ResetMatchKeys()
	if not lastResetWorldAtBaseline then
		warn("[WORLD_EXE] Reset: shared world properties are not at baseline")
	end
	local removed, problems = ArenaService.ResetRuntime()
	for _, problem in problems do
		warn(`[WORLD_EXE] Reset: {problem}`)
	end
	local baseline = ArenaService.CompareToBaseline()
	if not baseline.matches then
		warn(`[WORLD_EXE] Reset: arena differs from baseline ({baseline.total} differences): {baseline.differences[1]}`)
	end
	lastResetRemoved = removed
	lastResetBaselineMatches = baseline.matches
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
	PatchService.Update()
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
	local index = table.find(participants, player)
	if index then
		table.remove(participants, index)
		publish()
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
	PatchService.Init({
		isMatchLive = function(id: number): boolean
			return id == matchId and (state == S.Active or state == S.FinalPhase)
		end,
		onChanged = publish,
	})
	ArchitectService.Init(publish)
	PlayerStateService.SetJoinPolicy(function()
		return if state == S.Lobby or state == S.Countdown then Roles.Lobby else Roles.Spectator
	end)
	PlayerStateService.OnPlayerLeft(onPlayerLeft)
	enter[S.Lobby]()
	lastReason = "server start"
	publish()
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

-- Server shutdown: stop turns, end patches, restore shared properties, clear runtime objects.
function MatchService.Shutdown()
	running = false
	ArchitectService.StopMatch("cancelled")
	PatchService.CancelAll("shutdown")
	WorldModifierService.ClearAll()
	ArenaService.ResetRuntime()
end

return MatchService

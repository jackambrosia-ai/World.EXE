--!strict
-- ScoreService (Phase 5, server only): match-scoped scores, team outcome, placements, rewards.
-- * One ledger entry per participant (by UserId), created when the match initializes. Spectators
--   and mid-match joiners have no entry and can never score.
-- * Award(userId, reason, points, key): every award carries a unique key; a key already used this
--   match is ignored, so no event can be scored twice.
-- * Finalize() runs once at RESULTS: team outcome, placements and match-scoped rewards. Nothing is
--   persisted (no XP, currency or DataStores until Phase 9).
-- * Completed matches: team success if stability >= target OR repairs >= TEAM_REPAIR_TARGET.
--   Aborted matches (any outcome other than "completed"): never a team success; Team.Aborted is
--   true; players get the participation reward only (no team bonus, no placement bonus) and are
--   listed unplaced (Placement 0), still ordered by score.
-- * Players who leave keep a "Left" row with the score they had when they left; no further awards,
--   no placement, no rewards.
-- * Each participant's running score is mirrored to a server-set player attribute for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

local SCORE_ATTR = Config.PlayerAttributes.Score

-- Server-only tuning (provisional).
local POINTS = table.freeze({
	Fragment = 10,
	Repair = 50,
	Assist = 25,
	Survival = 5, -- per SURVIVAL_INTERVAL seconds alive as a participant
	Architect = 5, -- per accepted Architect patch (kept modest per docs/01_GAME_DESIGN.md §6)
	Discovery = 10, -- Phase 7A: once per combination per participant per match (approved P7)
})
local SURVIVAL_INTERVAL = 60
local REWARDS = table.freeze({
	Participation = 20,
	TeamSuccess = 100,
	Placement = table.freeze({ 50, 30, 15 }),
})
local TEAM_REPAIR_TARGET = 3
local MAX_RESULT_ROWS = 16

type Entry = {
	UserId: number,
	Name: string,
	Score: number,
	Fragments: number,
	Repairs: number,
	Assists: number,
	ArchitectPatches: number,
	AliveSeconds: number,
	SurvivalAwards: number,
	Left: boolean,
}

local ScoreService = {}

local active = false
local matchId = 0
local entries: { [number]: Entry } = {}
local order: { number } = {} -- UserIds in join order (stable output)
local usedKeys: { [string]: boolean } = {}
local finalized: { [string]: any }? = nil
local lastUpdate = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setAttribute(userId: number, score: number?)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		player:SetAttribute(SCORE_ATTR, score)
	end
end

-- Starts a fresh ledger for the match's participants.
function ScoreService.Begin(id: number, participants: { Player })
	ScoreService.Reset()
	active = true
	matchId = id
	lastUpdate = now()
	for _, player in participants do
		entries[player.UserId] = {
			UserId = player.UserId,
			Name = player.DisplayName,
			Score = 0,
			Fragments = 0,
			Repairs = 0,
			Assists = 0,
			ArchitectPatches = 0,
			AliveSeconds = 0,
			SurvivalAwards = 0,
			Left = false,
		}
		table.insert(order, player.UserId)
		player:SetAttribute(SCORE_ATTR, 0)
	end
end

-- Adds points once per key. reason: "fragment" | "repair" | "assist" | "survival" | "architect".
-- Returns true when awarded.
function ScoreService.Award(userId: number, reason: string, points: number, key: string): boolean
	if not active or usedKeys[key] then
		return false
	end
	local entry = entries[userId]
	if entry == nil or entry.Left then
		return false
	end
	usedKeys[key] = true
	entry.Score += points
	if reason == "fragment" then
		entry.Fragments += 1
	elseif reason == "repair" then
		entry.Repairs += 1
	elseif reason == "assist" then
		entry.Assists += 1
	elseif reason == "architect" then
		entry.ArchitectPatches += 1
	end
	setAttribute(userId, entry.Score)
	return true
end

-- Survival points: every SURVIVAL_INTERVAL seconds a participant spends alive in the arena.
function ScoreService.Update()
	if not active then
		return
	end
	local t = now()
	local dt = math.clamp(t - lastUpdate, 0, 1)
	lastUpdate = t
	for _, userId in order do
		local entry = entries[userId]
		local player = Players:GetPlayerByUserId(userId)
		if not entry.Left and player and PlayerStateService.GetRole(player) == Config.Roles.Participant and PlayerStateService.IsAlive(player) then
			entry.AliveSeconds += dt
			local due = math.floor(entry.AliveSeconds / SURVIVAL_INTERVAL)
			while entry.SurvivalAwards < due do
				entry.SurvivalAwards += 1
				ScoreService.Award(userId, "survival", POINTS.Survival, `survival:{matchId}:{userId}:{entry.SurvivalAwards}`)
			end
		end
	end
end

function ScoreService.MarkLeft(userId: number)
	local entry = entries[userId]
	if entry and not entry.Left then
		entry.Left = true
	end
end

-- Team outcome, placements and rewards, computed once. Later calls return the same table.
-- outcome: the match outcome ("completed", or "aborted" and similar); outcomeReason: its reason.
function ScoreService.Finalize(stability: number, repairsCompleted: number, outcome: string, outcomeReason: string?): { [string]: any }
	if finalized then
		return finalized
	end
	active = false
	local completed = outcome == "completed"
	local success = completed and (stability >= Config.Stability.SuccessTarget or repairsCompleted >= TEAM_REPAIR_TARGET)
	local reason = if not completed
		then `match {outcome} ({outcomeReason or "no reason"}): no team result`
		elseif stability >= Config.Stability.SuccessTarget then `stability {stability} >= {Config.Stability.SuccessTarget}`
		elseif repairsCompleted >= TEAM_REPAIR_TARGET then `{repairsCompleted} repairs >= {TEAM_REPAIR_TARGET}`
		else `stability {stability} < {Config.Stability.SuccessTarget} and {repairsCompleted} repairs < {TEAM_REPAIR_TARGET}`

	local ranked: { Entry } = {}
	local left: { Entry } = {}
	for _, userId in order do
		local entry = entries[userId]
		table.insert(if entry.Left then left else ranked, entry)
	end
	-- Ties: score, then repairs, then fragments, then lower UserId (deterministic).
	table.sort(ranked, function(a, b)
		if a.Score ~= b.Score then
			return a.Score > b.Score
		elseif a.Repairs ~= b.Repairs then
			return a.Repairs > b.Repairs
		elseif a.Fragments ~= b.Fragments then
			return a.Fragments > b.Fragments
		end
		return a.UserId < b.UserId
	end)

	local rows = {}
	for i, entry in ranked do
		local placementBonus = if completed then REWARDS.Placement[i] or 0 else 0
		local teamBonus = if success then REWARDS.TeamSuccess else 0
		local rewards = REWARDS.Participation + teamBonus + placementBonus
		table.insert(rows, {
			Placement = if completed then i else 0,
			UserId = entry.UserId,
			Name = entry.Name,
			Score = entry.Score,
			Fragments = entry.Fragments,
			Repairs = entry.Repairs,
			Assists = entry.Assists,
			ArchitectPatches = entry.ArchitectPatches,
			Rewards = rewards,
			RewardBreakdown = { Participation = REWARDS.Participation, Team = teamBonus, Placement = placementBonus },
			Total = entry.Score + rewards,
			Left = false,
		})
	end
	for _, entry in left do
		table.insert(rows, {
			Placement = 0,
			UserId = entry.UserId,
			Name = entry.Name,
			Score = entry.Score,
			Fragments = entry.Fragments,
			Repairs = entry.Repairs,
			Assists = entry.Assists,
			ArchitectPatches = entry.ArchitectPatches,
			Rewards = 0,
			RewardBreakdown = { Participation = 0, Team = 0, Placement = 0 },
			Total = entry.Score,
			Left = true,
		})
	end
	while #rows > MAX_RESULT_ROWS do
		table.remove(rows)
	end

	finalized = {
		Team = {
			Success = success,
			Aborted = not completed,
			Reason = reason,
			Stability = stability,
			StabilityTarget = Config.Stability.SuccessTarget,
			Repairs = repairsCompleted,
			RepairTarget = TEAM_REPAIR_TARGET,
		},
		Players = rows,
	}
	return finalized :: { [string]: any }
end

-- Clears the ledger and every player's score attribute (match start, reset, recovery). Idempotent.
function ScoreService.Reset()
	active = false
	finalized = nil
	table.clear(entries)
	table.clear(order)
	table.clear(usedKeys)
	for _, player in Players:GetPlayers() do
		player:SetAttribute(SCORE_ATTR, nil)
	end
end

-- Read-only copy of one entry (for tests).
function ScoreService.GetEntry(userId: number): { [string]: any }?
	local entry = entries[userId]
	return if entry then table.clone(entry) :: any else nil
end

function ScoreService.IsActive(): boolean
	return active
end

ScoreService.Points = POINTS
ScoreService.Rewards = REWARDS
ScoreService.TeamRepairTarget = TEAM_REPAIR_TARGET
ScoreService.SurvivalInterval = SURVIVAL_INTERVAL

return ScoreService

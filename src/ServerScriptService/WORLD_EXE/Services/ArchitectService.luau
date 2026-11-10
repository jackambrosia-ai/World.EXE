--!strict
-- ArchitectService (Phase 2, server only).
-- Fair Architect rotation, submission windows, and validation of patch submissions. Only the
-- current Architect, during the open window of the current match, may submit one approved patch
-- id from the cards offered to them. Phase 2 records and announces accepted submissions; patch
-- activation is Phase 3. A timed-out, abandoned, or cancelled turn is skipped (nothing activates).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local PatchCatalog = require(shared:WaitForChild("PatchCatalog"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

local Settings = Config.Architect

export type TurnResult = {
	MatchId: number,
	Turn: number,
	ArchitectUserId: number,
	ArchitectName: string,
	Outcome: string, -- "accepted" | "timeout" | "architect_left" | "cancelled"
	PatchId: string?,
}

type Turn = {
	matchId: number,
	number: number,
	architect: Player,
	offered: { string },
	offeredSet: { [string]: boolean },
	endsAt: number,
}

local ArchitectService = {}

local rng = Random.new()
local stateFolder: Instance? = nil
local matchId = 0 -- 0 = no match running
local order: { Player } = {}
local lastArchitect: Player? = nil
local current: Turn? = nil
local turnCount = 0
local nextTurnAt = math.huge
local history: { TurnResult } = {}
local buckets: { [Player]: { tokens: number, updated: number } } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------------------------------------
-- Pure helpers (exported for tests)

-- Round-robin over a shuffled roster: picks the first eligible player in `queue` who is not
-- `last`, falling back to `last` only when they are the sole eligible player, and moves the
-- chosen player to the back. Mutates `queue`.
function ArchitectService.PickNext<T>(queue: { T }, isEligible: (T) -> boolean, last: T?): T?
	local fallback: number? = nil
	for i, candidate in queue do
		if isEligible(candidate) then
			if candidate ~= last then
				table.remove(queue, i)
				table.insert(queue, candidate)
				return candidate
			elseif fallback == nil then
				fallback = i
			end
		end
	end
	if fallback then
		local candidate = table.remove(queue, fallback) :: T
		table.insert(queue, candidate)
		return candidate
	end
	return nil
end

-- Validates the shape of a RequestPatchSubmission payload. Returns the raw text or nil + reason.
function ArchitectService.ParsePayload(payload: any): (string?, string?)
	if typeof(payload) ~= "table" then
		return nil, "bad_payload"
	end
	local keys = 0
	for key in payload do
		keys += 1
		if key ~= "patchId" then
			return nil, "bad_payload"
		end
	end
	if keys ~= 1 then
		return nil, "bad_payload"
	end
	local raw = payload.patchId
	if typeof(raw) ~= "string" or #raw == 0 or #raw > Settings.MaxInputLength then
		return nil, "bad_patch_id"
	end
	if not string.match(raw, "^[%w _%-]+$") then
		return nil, "bad_patch_id"
	end
	return raw, nil
end

---------------------------------------------------------------------------------------------------
-- Turn state

local function publishTurn()
	local folder = stateFolder
	if folder == nil then
		return
	end
	local turn = current
	folder:SetAttribute("ArchitectUserId", if turn then turn.architect.UserId else 0)
	folder:SetAttribute("ArchitectName", if turn then turn.architect.DisplayName else "")
	folder:SetAttribute("TurnNumber", turnCount)
	folder:SetAttribute("TurnEndsAt", if turn then turn.endsAt else 0)
	folder:SetAttribute("OfferedPatches", if turn then table.concat(turn.offered, ",") else "")
	folder:SetAttribute("NextTurnAt", if matchId ~= 0 and nextTurnAt < math.huge then nextTurnAt else 0)
end

local function isEligible(player: Player): boolean
	return player.Parent == Players
		and PlayerStateService.GetRole(player) == Config.Roles.Participant
		and PlayerStateService.IsAlive(player)
end

local function chooseCards(): { string }
	local pool = table.clone(PatchCatalog.Ids())
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local cards = {}
	for i = 1, math.min(Settings.CardsOffered, #pool) do
		table.insert(cards, pool[i])
	end
	return cards
end

local function resolveTurn(outcome: string, patchId: string?, scale: number)
	local turn = current
	if turn == nil then
		return
	end
	current = nil
	local result: TurnResult = {
		MatchId = turn.matchId,
		Turn = turn.number,
		ArchitectUserId = turn.architect.UserId,
		ArchitectName = turn.architect.DisplayName,
		Outcome = outcome,
		PatchId = patchId,
	}
	table.insert(history, result)
	nextTurnAt = now() + Settings.TurnIntervalSeconds * scale
	publishTurn()

	local announcement: { [string]: any } = {
		MatchId = turn.matchId,
		Turn = turn.number,
		ArchitectName = turn.architect.DisplayName,
		Outcome = outcome,
	}
	local def = patchId and PatchCatalog.Get(patchId)
	if def then
		announcement.PatchId = def.Id
		announcement.DisplayName = def.DisplayName
		announcement.Warning = def.Warning
	end
	NetService.Get(Config.Remotes.PatchAnnouncement):FireAllClients(announcement)
	print(`[WORLD_EXE] Match {turn.matchId} turn {turn.number}: {turn.architect.Name} -> {outcome}{if patchId then " " .. patchId else ""}`)
end

local function startTurn(t: number, scale: number)
	local architect = ArchitectService.PickNext(order, isEligible, lastArchitect)
	if architect == nil then
		nextTurnAt = t + Settings.NoEligibleRetrySeconds * scale
		publishTurn()
		return
	end
	lastArchitect = architect
	turnCount += 1
	local cards = chooseCards()
	local set = {}
	for _, id in cards do
		set[id] = true
	end
	current = {
		matchId = matchId,
		number = turnCount,
		architect = architect,
		offered = cards,
		offeredSet = set,
		endsAt = t + Settings.SubmissionWindowSeconds, -- never scaled: players need the full window
	}
	nextTurnAt = math.huge
	publishTurn()
	print(`[WORLD_EXE] Match {matchId} turn {turnCount}: Architect {architect.Name}, cards {table.concat(cards, ",")}`)
end

---------------------------------------------------------------------------------------------------
-- Submissions

local function allowRequest(player: Player): boolean
	local t = os.clock()
	local bucket = buckets[player]
	if bucket == nil then
		bucket = { tokens = Settings.RateLimitBurst, updated = t }
		buckets[player] = bucket
	end
	bucket.tokens = math.min(Settings.RateLimitBurst, bucket.tokens + (t - bucket.updated) * Settings.RateLimitPerSecond)
	bucket.updated = t
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function reply(player: Player, ok: boolean, reason: string, patchId: string?)
	NetService.Get(Config.Remotes.SubmissionResult):FireClient(player, { ok = ok, reason = reason, patchId = patchId })
end

local lastScale = 1

local function onSubmission(player: Player, payload: any)
	if not allowRequest(player) then
		return reply(player, false, "rate_limited")
	end
	local raw, problem = ArchitectService.ParsePayload(payload)
	if raw == nil then
		return reply(player, false, problem or "bad_payload")
	end
	local turn = current
	if turn == nil or matchId == 0 then
		return reply(player, false, "no_open_turn")
	end
	if turn.architect ~= player then
		return reply(player, false, "not_architect")
	end
	if turn.matchId ~= matchId then
		return reply(player, false, "stale_turn")
	end
	if now() >= turn.endsAt then
		return reply(player, false, "window_closed")
	end
	local patchId = PatchCatalog.Resolve(raw)
	if patchId == nil then
		return reply(player, false, "unknown_patch")
	end
	if not turn.offeredSet[patchId] then
		return reply(player, false, "not_offered")
	end
	resolveTurn("accepted", patchId, lastScale)
	reply(player, true, "accepted", patchId)
end

---------------------------------------------------------------------------------------------------
-- Match integration (called by MatchService only)

function ArchitectService.StartMatch(id: number, participants: { Player }, scale: number)
	matchId = id
	order = table.clone(participants)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	lastArchitect = nil
	current = nil
	turnCount = 0
	history = {}
	lastScale = scale
	nextTurnAt = now() + Settings.FirstTurnDelaySeconds * scale
	publishTurn()
end

-- Ends the current turn (skipped, nothing activates) and stops new turns.
function ArchitectService.StopMatch(reason: string)
	if current then
		resolveTurn(reason, nil, lastScale)
	end
	nextTurnAt = math.huge
	matchId = 0
	order = {}
	publishTurn()
end

-- Called every MatchService tick while the match is ACTIVE.
function ArchitectService.Update(scale: number)
	lastScale = scale
	if matchId == 0 then
		return
	end
	local t = now()
	local turn = current
	if turn then
		if turn.architect.Parent ~= Players then
			resolveTurn("architect_left", nil, scale)
		elseif t >= turn.endsAt then
			resolveTurn("timeout", nil, scale)
		end
	elseif t >= nextTurnAt then
		startTurn(t, scale)
	end
end

function ArchitectService.OnPlayerLeft(player: Player)
	buckets[player] = nil
	local index = table.find(order, player)
	if index then
		table.remove(order, index)
	end
	if current and current.architect == player then
		resolveTurn("architect_left", nil, lastScale)
	end
end

function ArchitectService.GetHistory(): { TurnResult }
	return table.clone(history)
end

function ArchitectService.GetCurrentArchitect(): Player?
	return if current then current.architect else nil
end

function ArchitectService.Init(folder: Instance)
	stateFolder = folder
	publishTurn()
	NetService.Get(Config.Remotes.RequestPatchSubmission).OnServerEvent:Connect(onSubmission)
end

return ArchitectService

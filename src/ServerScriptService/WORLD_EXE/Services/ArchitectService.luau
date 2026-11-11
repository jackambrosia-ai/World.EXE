--!strict
-- ArchitectService (server only).
-- Fair Architect rotation, submission windows, and validation of patch submissions. Only the
-- current Architect, during the open window of the current match, may submit one approved patch
-- id from the cards offered to them. A valid submission is handed to PatchService (Phase 3), which
-- reserves a slot and runs the patch lifecycle. A timed-out, abandoned, cancelled or
-- capacity-rejected turn is skipped (nothing activates). No new turn starts while every patch
-- slot is taken (turns are deferred, not wasted).
-- Phase 7A rotation (approved P6): cards are drawn by catalog Weight without replacement,
-- excluding patches already running, patches accepted in the latest NoRepeatTurns turns of the
-- match, and any "severe" card beyond MaxSevereCards. A short pool offers fewer cards; an empty
-- pool defers the turn (no Architect is used up).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local PatchCatalog = require(shared:WaitForChild("PatchCatalog"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))
local PatchService = require(script.Parent:WaitForChild("PatchService"))

local Settings = Config.Architect

export type TurnResult = {
	MatchId: number,
	Turn: number,
	ArchitectUserId: number,
	ArchitectName: string,
	-- "accepted" | "timeout" | "architect_left" | "architect_ineligible" | "cancelled" |
	-- PatchService rejection ("capacity_full", "match_not_live", "duplicate", "unknown_patch")
	Outcome: string,
	PatchId: string?,
	RuntimeId: string?,
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
local onChanged: () -> () = function() end -- MatchService republishes its snapshot
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

-- Turn fields included in MatchService's versioned snapshot.
function ArchitectService.GetTurnSnapshot(): { [string]: any }
	local turn = current
	return {
		ArchitectUserId = if turn then turn.architect.UserId else 0,
		ArchitectName = if turn then turn.architect.DisplayName else "",
		TurnMatchId = if turn then turn.matchId else matchId,
		TurnNumber = if turn then turn.number else turnCount,
		TurnEndsAt = if turn then turn.endsAt else 0,
		OfferedPatches = if turn then table.clone(turn.offered) else {},
		NextTurnAt = if matchId ~= 0 and nextTurnAt < math.huge then nextTurnAt else 0,
	}
end

local function publishTurn()
	onChanged()
end

local function isEligible(player: Player): boolean
	return player.Parent == Players
		and PlayerStateService.GetRole(player) == Config.Roles.Participant
		and PlayerStateService.IsAlive(player)
end

-- Weighted draw without replacement (pure; exported for tests). `excluded` ids are never offered;
-- at most `maxSevere` cards have Severity "severe". Returns 0..count cards.
function ArchitectService.ChooseCards(ids: { string }, excluded: { [string]: boolean }, count: number, maxSevere: number, random: Random): { string }
	local pool = {}
	for _, id in ids do
		local def = PatchCatalog.Get(id)
		if def and not excluded[id] and def.Weight > 0 then
			table.insert(pool, def)
		end
	end
	local cards: { string } = {}
	local severe = 0
	while #cards < count and #pool > 0 do
		local total = 0
		for _, def in pool do
			total += def.Weight
		end
		local roll = random:NextNumber() * total
		local pick = #pool
		for i, def in pool do
			roll -= def.Weight
			if roll <= 0 then
				pick = i
				break
			end
		end
		local def = table.remove(pool, pick) :: PatchCatalog.PatchDefinition
		if def.Severity == "severe" then
			if severe >= maxSevere then
				continue
			end
			severe += 1
		end
		table.insert(cards, def.Id)
	end
	return cards
end

local function chooseCards(): { string }
	local excluded: { [string]: boolean } = {}
	for _, view in PatchService.GetSnapshot() do
		excluded[view.PatchId] = true
	end
	local seen = 0
	for i = #history, 1, -1 do
		local result = history[i]
		if result.MatchId ~= matchId or seen >= Settings.NoRepeatTurns then
			break
		end
		seen += 1
		if result.Outcome == "accepted" and result.PatchId then
			excluded[result.PatchId] = true
		end
	end
	return ArchitectService.ChooseCards(PatchCatalog.Ids(), excluded, Settings.CardsOffered, Settings.MaxSevereCards, rng)
end

local function resolveTurn(outcome: string, patchId: string?, scale: number, runtimeId: string?)
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
		RuntimeId = runtimeId,
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
		announcement.RuntimeId = runtimeId
		announcement.WarningSeconds = def.WarningSeconds * scale
		announcement.DurationSeconds = def.DurationSeconds * scale
	end
	NetService.Get(Config.Remotes.PatchAnnouncement):FireAllClients(announcement)
	print(`[WORLD_EXE] Match {turn.matchId} turn {turn.number}: {turn.architect.Name} -> {outcome}{if patchId then " " .. patchId else ""}`)
end

local function startTurn(t: number, scale: number)
	if not PatchService.HasCapacity() then
		-- Every patch slot is taken: defer the turn instead of offering cards that cannot run.
		nextTurnAt = t + Settings.NoEligibleRetrySeconds * scale
		publishTurn()
		return
	end
	local cards = chooseCards()
	if #cards == 0 then
		-- Nothing eligible to offer (all running or recently used): defer, keep the rotation.
		nextTurnAt = t + Settings.NoEligibleRetrySeconds * scale
		publishTurn()
		return
	end
	local architect = ArchitectService.PickNext(order, isEligible, lastArchitect)
	if architect == nil then
		nextTurnAt = t + Settings.NoEligibleRetrySeconds * scale
		publishTurn()
		return
	end
	lastArchitect = architect
	turnCount += 1
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

-- Every response names the match and turn it refers to, so the client can ignore responses that
-- arrive after its UI has moved on to a different turn or match.
local function reply(player: Player, matchRef: number, turnRef: number, ok: boolean, reason: string, patchId: string?)
	NetService.Get(Config.Remotes.SubmissionResult):FireClient(player, {
		ok = ok,
		reason = reason,
		patchId = patchId,
		MatchId = matchRef,
		TurnNumber = turnRef,
	})
end

local lastScale = 1

local function onSubmission(player: Player, payload: any)
	local turn = current
	local matchRef = if turn then turn.matchId else matchId
	local turnRef = if turn then turn.number else turnCount
	if not allowRequest(player) then
		return reply(player, matchRef, turnRef, false, "rate_limited")
	end
	local raw, problem = ArchitectService.ParsePayload(payload)
	if raw == nil then
		return reply(player, matchRef, turnRef, false, problem or "bad_payload")
	end
	if turn == nil or matchId == 0 then
		return reply(player, matchRef, turnRef, false, "no_open_turn")
	end
	if turn.architect ~= player then
		return reply(player, matchRef, turnRef, false, "not_architect")
	end
	if not isEligible(player) then
		-- The Architect died or stopped being a participant: the turn is skipped, nothing activates.
		resolveTurn("architect_ineligible", nil, lastScale)
		return reply(player, matchRef, turnRef, false, "architect_ineligible")
	end
	if turn.matchId ~= matchId then
		return reply(player, matchRef, turnRef, false, "stale_turn")
	end
	if now() >= turn.endsAt then
		return reply(player, matchRef, turnRef, false, "window_closed")
	end
	local patchId = PatchCatalog.Resolve(raw)
	if patchId == nil then
		return reply(player, matchRef, turnRef, false, "unknown_patch")
	end
	if not turn.offeredSet[patchId] then
		return reply(player, matchRef, turnRef, false, "not_offered")
	end
	-- Hand the validated submission to the patch engine; one turn can create at most one patch.
	local ok, result = PatchService.Request(patchId, player.UserId, turn.matchId, lastScale, {
		SourceKey = `turn:{turn.matchId}:{turn.number}`,
	})
	if not ok then
		resolveTurn(result, nil, lastScale)
		return reply(player, matchRef, turnRef, false, result)
	end
	resolveTurn("accepted", patchId, lastScale, result)
	reply(player, matchRef, turnRef, true, "accepted", patchId)
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
		elseif not isEligible(turn.architect) then
			resolveTurn("architect_ineligible", nil, scale)
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

-- The RemoteEvent handler, exported so tests can drive the exact accept path on a module clone.
ArchitectService.HandleSubmission = onSubmission

function ArchitectService.GetHistory(): { TurnResult }
	return table.clone(history)
end

function ArchitectService.GetCurrentArchitect(): Player?
	return if current then current.architect else nil
end

function ArchitectService.Init(changedCallback: () -> ())
	onChanged = changedCallback
	NetService.Get(Config.Remotes.RequestPatchSubmission).OnServerEvent:Connect(onSubmission)
end

return ArchitectService

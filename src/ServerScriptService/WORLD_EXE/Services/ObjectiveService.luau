--!strict
-- ObjectiveService (Phase 5, server only): the three stabilizer repair objectives.
-- * Discovers the existing Stabilizer models (tag Stabilizer: StabilizerId, Zone,
--   InteractionRadius, an InteractionPoint attachment). The arena is not redesigned: each match a
--   prompt is placed on an invisible anchor part in Workspace.WORLD_EXE.RuntimeEffects at the
--   InteractionPoint, so the Map itself only ever has its StatusRing colour changed (visual only,
--   restored at reset).
-- * States: IDLE -> REPAIRING <-> PAUSED -> COOLDOWN -> IDLE.
-- * Starting a repair: a living Participant inside InteractionRadius presses the prompt while
--   carrying FRAGMENT_COST fragments, which are spent. Joining a running or paused repair is free.
--   Co-op: up to MAX_CONTRIBUTORS players; each extra player adds COOP_BONUS to the repair rate.
-- * Every tick, contributors who leave the radius, die, stop being Participants or disconnect are
--   dropped. With nobody left the repair PAUSES and keeps its progress (provisional rule).
-- * Completion happens exactly once per repair: stability +REPAIR_GAIN, the player who started it
--   gets the repair award, every other contributor with at least ASSIST_MIN_SECONDS gets an assist
--   (unique score keys per repair). Then COOLDOWN_SECONDS before the stabilizer can be repaired
--   again.
-- * Stop() at RESULTS freezes everything; Reset() clears all match state and restores the rings.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local services = script.Parent
local PlayerStateService = require(services:WaitForChild("PlayerStateService"))
local ScoreService = require(services:WaitForChild("ScoreService"))
local StabilityService = require(services:WaitForChild("StabilityService"))
local CollectibleService = require(services:WaitForChild("CollectibleService"))

local States = Config.ObjectiveStates

-- Server-only tuning (provisional).
local REPAIR_SECONDS = 6 -- with one player
local COOP_BONUS = 0.5 -- extra rate per additional contributor
local MAX_CONTRIBUTORS = 3
local COOLDOWN_SECONDS = 60
local FRAGMENT_COST = 3
local ASSIST_MIN_SECONDS = 1
local PROMPT_DISTANCE = 10
local REPAIRING_COLOR = Config.Palette.AmberWarning
local COOLDOWN_COLOR = Config.Palette.NeonCyan -- the rings' own colour (idle) is already green

type Stabilizer = {
	id: string,
	zone: string,
	model: Model,
	point: Vector3,
	radius: number,
	ring: BasePart?,
	ringColor: Color3?,
	state: string,
	progress: number,
	session: number,
	starter: number, -- UserId who started (paid for) the current repair
	contributors: { [Player]: boolean },
	contributed: { [number]: number }, -- UserId -> seconds this repair
	cooldownUntil: number,
	anchor: BasePart?,
	prompt: ProximityPrompt?,
}

local ObjectiveService = {}

local stabilizers: { Stabilizer } = {}
local active = false
local matchId = 0
local repairsCompleted = 0
local lastUpdate = 0
local isLive: () -> boolean = function()
	return false
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function count(set: { [any]: any }): number
	local n = 0
	for _ in set do
		n += 1
	end
	return n
end

local function setRing(stab: Stabilizer, color: Color3?)
	if stab.ring and stab.ring.Parent then
		stab.ring.Color = color or stab.ringColor :: Color3
	end
end

local function refreshPrompt(stab: Stabilizer)
	local prompt = stab.prompt
	if prompt == nil then
		return
	end
	prompt.Enabled = active and stab.state ~= States.Cooldown
	prompt.ActionText = if stab.state == States.Idle then `Repair ({FRAGMENT_COST} fragments)` else "Join repair"
	prompt.ObjectText = `Stabilizer {stab.zone}`
end

local function inRange(stab: Stabilizer, player: Player): boolean
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	return rootPart ~= nil and rootPart:IsA("BasePart") and (rootPart.Position - stab.point).Magnitude <= stab.radius
end

local function eligible(player: Player): boolean
	return player.Parent == Players
		and PlayerStateService.GetRole(player) == Config.Roles.Participant
		and PlayerStateService.IsAlive(player)
end

local function find(id: string): Stabilizer?
	for _, stab in stabilizers do
		if stab.id == id then
			return stab
		end
	end
	return nil
end

-- Validates a prompt press. Returns (true, "started" | "joined" | "resumed") or (false, reason).
function ObjectiveService.TryJoin(id: string, player: Player): (boolean, string)
	local stab = find(id)
	if stab == nil or not active or not isLive() then
		return false, "unavailable"
	end
	if not eligible(player) then
		return false, if PlayerStateService.GetRole(player) ~= Config.Roles.Participant then "not_participant" else "not_alive"
	end
	if not inRange(stab, player) then
		return false, "too_far"
	end
	if stab.state == States.Cooldown then
		return false, "cooldown"
	end
	if stab.contributors[player] then
		return false, "already_repairing"
	end
	if count(stab.contributors) >= MAX_CONTRIBUTORS then
		return false, "full"
	end
	local result = "joined"
	if stab.state == States.Idle then
		if not CollectibleService.Spend(player, FRAGMENT_COST) then
			return false, "need_fragments"
		end
		stab.session += 1
		stab.progress = 0
		stab.starter = player.UserId
		table.clear(stab.contributed)
		result = "started"
	elseif stab.state == States.Paused then
		result = "resumed"
	end
	stab.state = States.Repairing
	stab.contributors[player] = true
	setRing(stab, REPAIRING_COLOR)
	refreshPrompt(stab)
	return true, result
end

local function complete(stab: Stabilizer)
	stab.state = States.Cooldown
	stab.progress = 1
	stab.cooldownUntil = now() + COOLDOWN_SECONDS
	table.clear(stab.contributors)
	repairsCompleted += 1
	StabilityService.Adjust(StabilityService.Tuning.RepairGain, `repair:{stab.id}`)
	local keyBase = `{matchId}:{stab.id}:{stab.session}`
	ScoreService.Award(stab.starter, "repair", ScoreService.Points.Repair, `repair:{keyBase}`)
	for userId, seconds in stab.contributed do
		if userId ~= stab.starter and seconds >= ASSIST_MIN_SECONDS then
			ScoreService.Award(userId, "assist", ScoreService.Points.Assist, `assist:{keyBase}:{userId}`)
		end
	end
	setRing(stab, COOLDOWN_COLOR)
	refreshPrompt(stab)
	print(`[WORLD_EXE] Stabilizer {stab.id} repaired (match {matchId}, repair {stab.session})`)
end

-- Advances repairs and cooldowns. Returns true when anything visible changed (state, or progress
-- crossing a 5% step), so MatchService can republish its snapshot.
function ObjectiveService.Update(): boolean
	if not active then
		return false
	end
	local t = now()
	local dt = math.clamp(t - lastUpdate, 0, 1)
	lastUpdate = t
	local changed = false
	for _, stab in stabilizers do
		local beforeState, beforeStep = stab.state, math.floor(stab.progress * 20)
		if stab.state == States.Repairing or stab.state == States.Paused then
			for player in table.clone(stab.contributors) do
				if not eligible(player) or not inRange(stab, player) then
					stab.contributors[player] = nil
				end
			end
			local n = count(stab.contributors)
			if n == 0 then
				stab.state = States.Paused
			else
				stab.state = States.Repairing
				stab.progress = math.min(1, stab.progress + dt * (1 + COOP_BONUS * (n - 1)) / REPAIR_SECONDS)
				for player in stab.contributors do
					stab.contributed[player.UserId] = (stab.contributed[player.UserId] or 0) + dt
				end
				if stab.progress >= 1 then
					complete(stab)
				end
			end
			refreshPrompt(stab)
		elseif stab.state == States.Cooldown and t >= stab.cooldownUntil then
			stab.state = States.Idle
			stab.progress = 0
			setRing(stab, nil)
			refreshPrompt(stab)
		end
		if stab.state ~= beforeState or math.floor(stab.progress * 20) ~= beforeStep then
			changed = true
		end
	end
	return changed
end

-- Creates the prompts and opens the objectives for a live match.
function ObjectiveService.Begin(id: number)
	ObjectiveService.Reset()
	active = true
	matchId = id
	lastUpdate = now()
	local root = workspace:FindFirstChild(Config.RootName)
	local effects = root and root:FindFirstChild("RuntimeEffects")
	for _, stab in stabilizers do
		local anchor = Instance.new("Part")
		anchor.Name = `StabilizerPrompt_{stab.id}`
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Position = stab.point
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		local prompt = Instance.new("ProximityPrompt")
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = math.min(PROMPT_DISTANCE, stab.radius)
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		local stabId = stab.id
		prompt.Triggered:Connect(function(player: Player)
			ObjectiveService.TryJoin(stabId, player)
		end)
		anchor.Parent = effects
		stab.anchor = anchor
		stab.prompt = prompt
		refreshPrompt(stab)
	end
end

-- Freezes objectives at RESULTS (no more progress or joins). Idempotent.
function ObjectiveService.Stop()
	active = false
	for _, stab in stabilizers do
		table.clear(stab.contributors)
		refreshPrompt(stab)
	end
end

-- Clears all match state, removes prompts and restores ring colours. Idempotent.
function ObjectiveService.Reset()
	active = false
	repairsCompleted = 0
	for _, stab in stabilizers do
		stab.state = States.Idle
		stab.progress = 0
		stab.starter = 0
		stab.cooldownUntil = 0
		table.clear(stab.contributors)
		table.clear(stab.contributed)
		if stab.anchor then
			stab.anchor:Destroy()
		end
		stab.anchor = nil
		stab.prompt = nil
		setRing(stab, nil)
	end
end

function ObjectiveService.GetRepairsCompleted(): number
	return repairsCompleted
end

-- Bounded snapshot entries for clients.
function ObjectiveService.GetSnapshot(): { { [string]: any } }
	local list = {}
	for _, stab in stabilizers do
		table.insert(list, {
			Id = stab.id,
			Zone = stab.zone,
			State = stab.state,
			Progress = math.floor(stab.progress * 100 + 0.5),
			Contributors = count(stab.contributors),
		})
	end
	return list
end

-- Read-only state for tests.
function ObjectiveService.GetStabilizer(id: string): { [string]: any }?
	local stab = find(id)
	if stab == nil then
		return nil
	end
	return {
		State = stab.state,
		Progress = stab.progress,
		Session = stab.session,
		Starter = stab.starter,
		Contributors = count(stab.contributors),
		Point = stab.point,
		Radius = stab.radius,
		RingColor = stab.ring and stab.ring.Color,
		OriginalRingColor = stab.ringColor,
		HasPrompt = stab.prompt ~= nil and stab.prompt.Parent ~= nil,
	}
end

-- Finds the stabilizers. deps.isLive(): true while the current match is ACTIVE or FINAL_PHASE.
function ObjectiveService.Init(deps: { isLive: () -> boolean }): { string }
	isLive = deps.isLive
	local problems = {}
	local root = workspace:WaitForChild(Config.RootName)
	local map = root:WaitForChild("Map")
	for _, inst in CollectionService:GetTagged(Config.Tags.Stabilizer) do
		if inst:IsA("Model") and inst:IsDescendantOf(map) then
			local id = inst:GetAttribute("StabilizerId")
			local zone = inst:GetAttribute("Zone")
			local radius = inst:GetAttribute("InteractionRadius")
			local attachment = inst:FindFirstChild("InteractionPoint", true)
			if typeof(id) == "string" and typeof(zone) == "string" and typeof(radius) == "number" and attachment and attachment:IsA("Attachment") then
				local ring = inst:FindFirstChild("StatusRing", true)
				table.insert(stabilizers, {
					id = id,
					zone = zone,
					model = inst,
					point = attachment.WorldPosition,
					radius = radius,
					ring = if ring and ring:IsA("BasePart") then ring else nil,
					ringColor = if ring and ring:IsA("BasePart") then ring.Color else nil,
					state = States.Idle,
					progress = 0,
					session = 0,
					starter = 0,
					contributors = {},
					contributed = {},
					cooldownUntil = 0,
					anchor = nil,
					prompt = nil,
				})
			else
				table.insert(problems, `{inst:GetFullName()}: stabilizer is missing StabilizerId/Zone/InteractionRadius/InteractionPoint`)
			end
		end
	end
	table.sort(stabilizers, function(a, b)
		return a.id < b.id
	end)
	if #stabilizers == 0 then
		table.insert(problems, "no stabilizers in the arena")
	end
	return problems
end

ObjectiveService.Tuning = table.freeze({
	RepairSeconds = REPAIR_SECONDS,
	CoopBonus = COOP_BONUS,
	MaxContributors = MAX_CONTRIBUTORS,
	CooldownSeconds = COOLDOWN_SECONDS,
	FragmentCost = FRAGMENT_COST,
	AssistMinSeconds = ASSIST_MIN_SECONDS,
})

return ObjectiveService

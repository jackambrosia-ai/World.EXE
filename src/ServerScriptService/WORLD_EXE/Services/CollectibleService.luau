--!strict
-- CollectibleService (Phase 5, server only): data fragments.
-- * Spawn points: the 12 approved FragmentSpawn markers in the arena Map (never client input).
-- * Bounded waves: at most MAX_ACTIVE fragments exist at once, one per free marker; the field is
--   topped up every WAVE_SECONDS while the match is live.
-- * Pickup by touch, validated on the server in TryCollect: match live, fragment still present,
--   living Participant, character within PICKUP_RANGE of the server-side fragment position. The
--   fragment leaves the table before anything else happens, so it can be collected exactly once.
-- * A pickup adds one carried fragment (spent on stabilizer repairs) and scores via ScoreService.
--   Carried fragments are kept on death (provisional) and cleared at match end and on departure.
-- * Fragments live in Workspace.WORLD_EXE.Collectibles and are removed by Stop()/Reset() and by the
--   runtime-folder clear at RESET. Placeholder parts until artwork is approved.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))
local ScoreService = require(script.Parent:WaitForChild("ScoreService"))

local FRAGMENTS_ATTR = Config.PlayerAttributes.Fragments

-- Server-only tuning (provisional).
local MAX_ACTIVE = 12 -- Phase 8A-1: larger arena (was 8)
local WAVE_SECONDS = 20
local PICKUP_RANGE = 8
local FRAGMENT_SIZE = 1.6

type Fragment = { id: number, point: BasePart, connection: RBXScriptConnection }

local CollectibleService = {}

local active = false
local matchId = 0
local counter = 0
local nextWaveAt = 0
local points: { BasePart } = {}
local fragments: { [BasePart]: Fragment } = {}
local occupied: { [BasePart]: BasePart } = {} -- spawn marker -> fragment
local carried: { [number]: number } = {}
local collectedTotal = 0
local isLive: () -> boolean = function()
	return false
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function folder(): Instance?
	local root = workspace:FindFirstChild(Config.RootName)
	return root and root:FindFirstChild("Collectibles")
end

local function setCarried(player: Player, n: number?)
	carried[player.UserId] = n
	player:SetAttribute(FRAGMENTS_ATTR, n)
end

local function removeFragment(part: BasePart)
	local fragment = fragments[part]
	if fragment == nil then
		return
	end
	fragments[part] = nil
	fragment.connection:Disconnect()
	if occupied[fragment.point] == part then
		occupied[fragment.point] = nil
	end
	part:Destroy()
end

-- Validates and applies one pickup. Returns (true, "collected") or (false, reason).
function CollectibleService.TryCollect(part: BasePart, player: Player): (boolean, string)
	local fragment = fragments[part]
	if fragment == nil or not active or not isLive() then
		return false, "unavailable"
	end
	if PlayerStateService.GetRole(player) ~= Config.Roles.Participant then
		return false, "not_participant"
	end
	if not PlayerStateService.IsAlive(player) then
		return false, "not_alive"
	end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return false, "not_alive"
	end
	if (rootPart.Position - fragment.point.Position).Magnitude > PICKUP_RANGE then
		return false, "too_far"
	end
	removeFragment(part)
	collectedTotal += 1
	setCarried(player, (carried[player.UserId] or 0) + 1)
	ScoreService.Award(player.UserId, "fragment", ScoreService.Points.Fragment, `fragment:{matchId}:{fragment.id}`)
	return true, "collected"
end

local function spawnFragment(point: BasePart)
	local parent = folder()
	if parent == nil then
		return
	end
	counter += 1
	local part = Instance.new("Part")
	part.Name = `Fragment_{counter}`
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(FRAGMENT_SIZE, FRAGMENT_SIZE, FRAGMENT_SIZE)
	part.Material = Enum.Material.Neon
	part.Color = Config.Palette.NeonCyan
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = true
	part.CastShadow = false
	part.Position = point.Position
	part:SetAttribute("FragmentSpawnId", point:GetAttribute("FragmentSpawnId"))
	local id = counter
	local connection = part.Touched:Connect(function(hit: BasePart)
		local model = hit:FindFirstAncestorOfClass("Model")
		local player = model and Players:GetPlayerFromCharacter(model)
		if player then
			CollectibleService.TryCollect(part, player)
		end
	end)
	fragments[part] = { id = id, point = point, connection = connection }
	occupied[point] = part
	part.Parent = parent
end

local function topUp(rng: Random)
	local free = {}
	for _, point in points do
		if occupied[point] == nil and point.Parent ~= nil then
			table.insert(free, point)
		end
	end
	local count = 0
	for _ in fragments do
		count += 1
	end
	while count < MAX_ACTIVE and #free > 0 do
		spawnFragment(table.remove(free, rng:NextInteger(1, #free)) :: BasePart)
		count += 1
	end
end

local rng = Random.new()

-- Starts fragment waves for a live match.
function CollectibleService.Begin(id: number)
	CollectibleService.Stop()
	active = true
	matchId = id
	collectedTotal = 0
	topUp(rng)
	nextWaveAt = now() + WAVE_SECONDS
end

function CollectibleService.Update()
	if active and now() >= nextWaveAt then
		nextWaveAt = now() + WAVE_SECONDS
		topUp(rng)
	end
end

-- Spends carried fragments (stabilizer repairs). Returns true when the player had enough.
function CollectibleService.Spend(player: Player, amount: number): boolean
	local have = carried[player.UserId] or 0
	if have < amount then
		return false
	end
	setCarried(player, have - amount)
	return true
end

function CollectibleService.GetCarried(player: Player): number
	return carried[player.UserId] or 0
end

function CollectibleService.OnPlayerLeft(player: Player)
	carried[player.UserId] = nil
end

-- Ends pickups and removes every fragment (RESULTS). Idempotent.
function CollectibleService.Stop()
	active = false
	for part in table.clone(fragments) do
		removeFragment(part)
	end
end

-- Stop() plus carried fragments and attributes (reset, recovery, shutdown). Idempotent.
function CollectibleService.Reset()
	CollectibleService.Stop()
	table.clear(carried)
	for _, player in Players:GetPlayers() do
		player:SetAttribute(FRAGMENTS_ATTR, nil)
	end
end

function CollectibleService.GetActiveCount(): number
	local n = 0
	for _ in fragments do
		n += 1
	end
	return n
end

function CollectibleService.GetFragments(): { BasePart }
	local list = {}
	for part in fragments do
		table.insert(list, part)
	end
	return list
end

function CollectibleService.GetCollectedTotal(): number
	return collectedTotal
end

-- deps.isLive(): true while the current match is ACTIVE or FINAL_PHASE.
function CollectibleService.Init(deps: { isLive: () -> boolean }): { string }
	isLive = deps.isLive
	local problems = {}
	local root = workspace:WaitForChild(Config.RootName)
	local map = root:WaitForChild("Map")
	for _, inst in CollectionService:GetTagged(Config.Tags.FragmentSpawn) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(map) then
			table.insert(points, inst)
		end
	end
	if #points == 0 then
		table.insert(problems, "no FragmentSpawn markers in the arena")
	end
	return problems
end

CollectibleService.Tuning = table.freeze({
	MaxActive = MAX_ACTIVE,
	WaveSeconds = WAVE_SECONDS,
	PickupRange = PICKUP_RANGE,
})

return CollectibleService

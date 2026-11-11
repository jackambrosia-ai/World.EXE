--!strict
-- CORRUPTION (Phase 7B): a damaging trail spreads node by node along a designated path.
-- * Paths: BaseParts tagged CorruptionNode inside Workspace.WORLD_EXE.Map, grouped by Zone and
--   ordered by Order. Each activation picks one path at random.
-- * Spread: a new node every NODE_INTERVAL seconds. Each node is first WARNED (amber disc) for
--   WARN_SECONDS, then CORRUPTED (magenta disc). At most MAX_ACTIVE nodes (warned + corrupted), across
--   every CORRUPTION patch.
-- * Damage: living Participants standing on a corrupted node take DAMAGE_PER_SECOND, applied every
--   DAMAGE_TICK. Spawn protection (ForceField) blocks it. Never more than one node's damage per tick.
-- * Counterplay: step off amber discs before they turn magenta; the trail never covers more than
--   MAX_ACTIVE 6-stud discs, so free floor is always next to it. SCANNER shows the discs.
-- * The discs are runtime parts (no collision, no queries, no touch) in ActivePatchInstances and
--   are removed when the patch ends for any reason. The markers themselves never change.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerStateService = require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))

-- Server-only tuning (approved P8: 4 damage per second; max 6 active nodes).
local NODE_INTERVAL = 3
local WARN_SECONDS = 2
local MAX_ACTIVE = 6
local DAMAGE_PER_SECOND = 4
local DAMAGE_TICK = 0.5
local REACH_HEIGHT = 7 -- studs above the node a root part still counts as standing on it
local WARN_COLOR = Config.Palette.AmberWarning
local CORRUPT_COLOR = Color3.fromRGB(255, 40, 200)

type Disc = { part: BasePart, marker: BasePart, corrupted: boolean, runtimeId: string }

local discs: { Disc } = {}
local stats = { Ticks = 0, Damage = 0, Protected = 0 }

local function paths(): { [string]: { BasePart } }
	local root = workspace:FindFirstChild(Config.RootName)
	local map = root and root:FindFirstChild("Map")
	local byZone: { [string]: { BasePart } } = {}
	if map then
		for _, inst in CollectionService:GetTagged(Config.Tags.CorruptionNode) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(map) then
				local zone = tostring(inst:GetAttribute("Zone"))
				byZone[zone] = byZone[zone] or {}
				table.insert(byZone[zone], inst)
			end
		end
	end
	for _, list in byZone do
		table.sort(list, function(a, b)
			return (tonumber(a:GetAttribute("Order")) or 0) < (tonumber(b:GetAttribute("Order")) or 0)
		end)
	end
	return byZone
end

local function activeCount(): number
	return #discs
end

local Corruption = {}

function Corruption.Activate(ctx: any)
	local byZone = paths()
	local zones = {}
	for zone in byZone do
		table.insert(zones, zone)
	end
	table.sort(zones)
	if #zones == 0 then
		error("no CorruptionNode markers in the arena")
	end
	local path = byZone[zones[Random.new():NextInteger(1, #zones)]]
	local mine: { Disc } = {}

	-- Registered first, so it runs last at cleanup (after the loops are cancelled).
	ctx.Add(function()
		for _, disc in mine do
			local index = table.find(discs, disc)
			if index then
				table.remove(discs, index)
			end
			pcall(function()
				disc.part:Destroy()
			end)
		end
		table.clear(mine)
	end)

	local function spread(marker: BasePart)
		if activeCount() >= MAX_ACTIVE or marker.Parent == nil then
			return
		end
		local diameter = math.min(marker.Size.X, marker.Size.Z)
		local part = Instance.new("Part")
		part.Name = "Corruption_" .. tostring(marker:GetAttribute("NodeId"))
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.3, diameter, diameter)
		part.CFrame = CFrame.new(marker.Position.X, marker.Position.Y + 0.1, marker.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = WARN_COLOR
		part.Transparency = 0.25
		part.Parent = ctx.Folder
		ctx.Add(part)
		local disc: Disc = { part = part, marker = marker, corrupted = false, runtimeId = ctx.RuntimeId }
		table.insert(discs, disc)
		table.insert(mine, disc)
		ctx.Delay(WARN_SECONDS, function()
			if ctx.IsLive() and part.Parent ~= nil then
				disc.corrupted = true
				part.Color = CORRUPT_COLOR
				part.Material = Enum.Material.ForceField
				part.Transparency = 0
			end
		end)
	end

	spread(path[1]) -- the first node is warned immediately (no yielding here)
	ctx.Spawn(function()
		for i = 2, #path do
			task.wait(NODE_INTERVAL)
			if not ctx.IsLive() then
				return
			end
			spread(path[i])
		end
	end)

	ctx.Spawn(function()
		while ctx.IsLive() do
			task.wait(DAMAGE_TICK)
			if not ctx.IsLive() then
				break
			end
			stats.Ticks += 1
			for _, player in PlayerStateService.GetPlayersWithRole(Config.Roles.Participant) do
				if not PlayerStateService.IsAlive(player) then
					continue
				end
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
					continue
				end
				local onNode = false
				for _, disc in mine do
					if disc.corrupted then
						local m = disc.marker.Position
						local flat = Vector2.new(root.Position.X - m.X, root.Position.Z - m.Z).Magnitude
						local rise = root.Position.Y - m.Y
						if flat <= disc.part.Size.Y / 2 and rise >= -1 and rise <= REACH_HEIGHT then
							onNode = true
							break
						end
					end
				end
				if onNode then
					if (character :: Model):FindFirstChildOfClass("ForceField") then
						stats.Protected += 1
					else
						local amount = DAMAGE_PER_SECOND * DAMAGE_TICK
						humanoid:TakeDamage(amount)
						stats.Damage += amount
					end
				end
			end
		end
	end)
end

-- Discs currently warned or corrupted (SCANNER and tests).
function Corruption.GetActiveNodes(): { BasePart }
	local list = {}
	for _, disc in discs do
		table.insert(list, disc.part)
	end
	return list
end

function Corruption.GetCorruptedCount(): number
	local n = 0
	for _, disc in discs do
		if disc.corrupted then
			n += 1
		end
	end
	return n
end

function Corruption.GetStats(): { Ticks: number, Damage: number, Protected: number }
	return table.clone(stats)
end

Corruption.Tuning = table.freeze({
	NodeInterval = NODE_INTERVAL,
	WarnSeconds = WARN_SECONDS,
	MaxActive = MAX_ACTIVE,
	DamagePerSecond = DAMAGE_PER_SECOND,
	DamageTick = DAMAGE_TICK,
})

return table.freeze(Corruption)

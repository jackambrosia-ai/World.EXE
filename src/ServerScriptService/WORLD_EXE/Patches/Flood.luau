--!strict
-- FLOOD (Phase 7B): water rises predictably over the low ground and slows anyone wading in it.
-- * Zones: BaseParts tagged FloodZone inside Workspace.WORLD_EXE.Map (invisible footprints over the
--   Central Core deck and the Research Yard). The marker's bottom face is the water base and its
--   MaxRise attribute caps the water height.
-- * Predictable: the water rises linearly from the base to MaxRise over RISE_SECONDS after
--   activation, then holds. The water is a runtime part (no collision, no queries, no touch).
-- * Non-lethal (approved P8): living Participants whose feet are below the surface inside a zone
--   walk at SLOW_FACTOR of their speed (40% slower); leaving the water restores it. No damage.
-- * Escape routes stay dry: the Skybridge ramp and steps, the Lookout ramp, the Bridge and the
--   North Annex are outside every zone, and the water (2.5 studs) never reaches them.
-- * WalkSpeed is restored for everyone this patch slowed when they leave the water, stop being a
--   living Participant, or when the patch ends for any reason.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerStateService = require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))

-- Server-only tuning (approved: 40% slow, non-lethal).
local RISE_SECONDS = 10
local UPDATE_SECONDS = 0.1
local SLOW_FACTOR = 0.6
local FEET_MARGIN = 0.3 -- feet must be this far below the surface to count as wading
local MIN_THICKNESS = 0.05
local WATER_COLOR = Color3.fromRGB(40, 120, 255)

type Zone = {
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	baseY: number,
	maxRise: number,
	level: number, -- current water height above baseY
	part: BasePart,
}

type Slow = { base: number, owner: string }

local zonesByRuntime: { [string]: { Zone } } = {}
local slowed: { [Humanoid]: Slow } = {}
local stats = { Slowed = 0, Restored = 0 }

local function floodMarkers(): { BasePart }
	local root = workspace:FindFirstChild(Config.RootName)
	local map = root and root:FindFirstChild("Map")
	local list = {}
	if map then
		for _, inst in CollectionService:GetTagged(Config.Tags.FloodZone) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(map) then
				table.insert(list, inst)
			end
		end
	end
	return list
end

local function restore(humanoid: Humanoid)
	local entry = slowed[humanoid]
	if entry == nil then
		return
	end
	slowed[humanoid] = nil
	stats.Restored += 1
	pcall(function()
		humanoid.WalkSpeed = entry.base
	end)
end

local function setWater(zone: Zone)
	local h = math.max(zone.level, MIN_THICKNESS)
	zone.part.Size = Vector3.new(zone.maxX - zone.minX, h, zone.maxZ - zone.minZ)
	zone.part.CFrame = CFrame.new((zone.minX + zone.maxX) / 2, zone.baseY + h / 2, (zone.minZ + zone.maxZ) / 2)
end

local Flood = {}

function Flood.Activate(ctx: any)
	local markers = floodMarkers()
	if #markers == 0 then
		error("no FloodZone markers in the arena")
	end
	local zones: { Zone } = {}
	-- Registered first, so it runs last at cleanup (after the update loop is cancelled).
	ctx.Add(function()
		zonesByRuntime[ctx.RuntimeId] = nil
		for humanoid, entry in table.clone(slowed) do
			if entry.owner == ctx.RuntimeId then
				restore(humanoid)
			end
		end
	end)
	for _, marker in markers do
		local rise = tonumber(marker:GetAttribute("MaxRise")) or 0
		local half = marker.Size / 2
		local part = Instance.new("Part")
		part.Name = "FloodWater_" .. tostring(marker:GetAttribute("FloodZoneId"))
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Glass
		part.Color = WATER_COLOR
		part.Transparency = 0.55
		local zone: Zone = {
			minX = marker.Position.X - half.X,
			maxX = marker.Position.X + half.X,
			minZ = marker.Position.Z - half.Z,
			maxZ = marker.Position.Z + half.Z,
			baseY = marker.Position.Y - half.Y,
			maxRise = math.clamp(rise, 0, 6),
			level = 0,
			part = part,
		}
		setWater(zone)
		part.Parent = ctx.Folder
		ctx.Add(part)
		table.insert(zones, zone)
	end
	zonesByRuntime[ctx.RuntimeId] = zones
	local started = os.clock()

	ctx.Spawn(function()
		while ctx.IsLive() do
			task.wait(UPDATE_SECONDS)
			if not ctx.IsLive() then
				break
			end
			local progress = math.clamp((os.clock() - started) / RISE_SECONDS, 0, 1)
			for _, zone in zones do
				local level = zone.maxRise * progress
				if level - zone.level > 0.01 or (progress >= 1 and zone.level < zone.maxRise) then
					zone.level = level
					setWater(zone)
				end
			end
			-- Who is wading this tick.
			local wading: { [Humanoid]: boolean } = {}
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
				local p = root.Position
				local feet = p.Y - root.Size.Y / 2 - humanoid.HipHeight
				for _, zone in zones do
					if p.X >= zone.minX and p.X <= zone.maxX and p.Z >= zone.minZ and p.Z <= zone.maxZ and feet < zone.baseY + zone.level - FEET_MARGIN then
						wading[humanoid] = true
						break
					end
				end
			end
			for humanoid in wading do
				if slowed[humanoid] == nil then
					slowed[humanoid] = { base = humanoid.WalkSpeed, owner = ctx.RuntimeId }
					humanoid.WalkSpeed = humanoid.WalkSpeed * SLOW_FACTOR
					stats.Slowed += 1
				end
			end
			for humanoid, entry in table.clone(slowed) do
				if entry.owner == ctx.RuntimeId and not wading[humanoid] then
					restore(humanoid)
				end
			end
		end
	end)
end

-- Water surface Y at a position inside a running FLOOD zone, or nil (FLOATING_DEBRIS).
function Flood.GetWaterLevel(position: Vector3): number?
	local best: number? = nil
	for _, zones in zonesByRuntime do
		for _, zone in zones do
			if position.X >= zone.minX and position.X <= zone.maxX and position.Z >= zone.minZ and position.Z <= zone.maxZ then
				local y = zone.baseY + zone.level
				if best == nil or y > best then
					best = y
				end
			end
		end
	end
	return best
end

-- Humanoids currently slowed (tests).
function Flood.GetSlowedCount(): number
	local n = 0
	for _ in slowed do
		n += 1
	end
	return n
end

function Flood.GetStats(): { Slowed: number, Restored: number }
	return table.clone(stats)
end

Flood.Tuning = table.freeze({
	RiseSeconds = RISE_SECONDS,
	SlowFactor = SLOW_FACTOR,
	UpdateSeconds = UPDATE_SECONDS,
})

return table.freeze(Flood)

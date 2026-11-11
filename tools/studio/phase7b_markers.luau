--!strict
-- Phase 7B (Studio Edit mode, run once via Studio MCP): adds the dedicated MAGNETIC, CORRUPTION and
-- FLOOD arena content under Map.PatchMarkers. Only new tagged parts are created; no existing
-- geometry changes.
-- * 8 MagneticProp crates (3x3x3, anchored, collidable): the server moves them (anchored,
--   kinematic), so physics ownership never leaves the server.
-- * 4 MagneticPoint markers (invisible, no collision or queries): the safe points props move to.
-- * 12 CorruptionNode markers (invisible, no collision or queries): two 6-node paths, one per zone
--   (CentralCore, ResearchYard), ordered by the Order attribute.
-- * 2 FloodZone volumes (invisible, no collision or queries): low-ground footprints. The marker's
--   bottom face is the water base; MaxRise caps the water height. Elevated routes stay outside.
-- Yard items sit on DecayTile centres (tiles are 10 studs apart with 0.2-stud gaps).
-- Every item is verified before anything is created. Any failure aborts with no changes:
-- * floor beneath every crate and node;
-- * crate volume and headroom free of other Map parts;
-- * each crate's straight path to its nearest point (same zone) free of collidable parts;
-- * paths and nodes kept clear of spawns, stabilizers, supply points, fragment markers and pads.
-- Idempotent: an existing PatchMarkers folder is left untouched.

local CollectionService = game:GetService("CollectionService")

local map = workspace:WaitForChild("WORLD_EXE"):WaitForChild("Map")
if map:FindFirstChild("PatchMarkers") then
	return "PatchMarkers already exists; nothing changed"
end

local PROP_SIZE = 3
local NODE_SIZE = 6
local CLEARANCE = 1.5 -- extra distance kept from sensitive markers

-- { id, zone, x, z }
local PROPS = {
	{ "PROP_CORE_1", "CentralCore", 24, -8 },
	{ "PROP_CORE_2", "CentralCore", 12, -30 },
	{ "PROP_CORE_3", "CentralCore", -24, 8 },
	{ "PROP_CORE_4", "CentralCore", -16, 30 },
	{ "PROP_YARD_1", "ResearchYard", -125, 35 },
	{ "PROP_YARD_2", "ResearchYard", -155, 5 },
	{ "PROP_YARD_3", "ResearchYard", -115, -25 },
	{ "PROP_YARD_4", "ResearchYard", -85, -15 },
}
local POINTS = {
	{ "MAGNET_CORE_E", "CentralCore", 34, -18 },
	{ "MAGNET_CORE_W", "CentralCore", -34, 18 },
	{ "MAGNET_YARD_W", "ResearchYard", -155, 25 },
	{ "MAGNET_YARD_E", "ResearchYard", -95, -35 },
}
-- { id, zone, order, x, z }
local NODES = {}
for i, x in { -22, -15, -8, 8, 15, 22 } do
	table.insert(NODES, { `CORRUPT_CORE_{i}`, "CentralCore", i, x, -36 })
end
for i, x in { -155, -145, -135, -125, -115, -105 } do
	table.insert(NODES, { `CORRUPT_YARD_{i}`, "ResearchYard", i, x, -5 })
end
-- { id, zone, centreX, centreZ, sizeX, sizeZ, floorY, maxRise }
local FLOODS = {
	{ "FLOOD_CORE", "CentralCore", 0, 0, 80, 80, 0, 2.5 },
	{ "FLOOD_YARD", "ResearchYard", -120, 0, 104, 104, 0, 2.5 },
}

local rays = RaycastParams.new()
rays.FilterType = Enum.RaycastFilterType.Include
rays.FilterDescendantsInstances = { map }
rays.RespectCanCollide = true
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { map }
overlap.RespectCanCollide = true

-- Sensitive markers: { position (XZ), keep-out radius }.
local sensitive: { { p: Vector2, r: number, name: string } } = {}
local function addSensitive(tag: string, radius: number)
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(map) then
			local pos = if inst:IsA("Model") then inst:GetPivot().Position else (inst :: BasePart).Position
			local r = radius
			if inst:IsA("BasePart") and (tag == "BounceSurface" or tag == "SlipSurface") then
				r = math.max(inst.Size.X, inst.Size.Z) / 2
			elseif tag == "Stabilizer" then
				r = tonumber(inst:GetAttribute("InteractionRadius")) or 10
			end
			table.insert(sensitive, { p = Vector2.new(pos.X, pos.Z), r = r, name = inst:GetFullName() })
		end
	end
end
addSensitive("ArenaSpawn", 4.3)
addSensitive("Stabilizer", 10)
addSensitive("SupplyLandingPoint", 4)
addSensitive("FragmentSpawn", 2)
addSensitive("BounceSurface", 3)
addSensitive("SlipSurface", 5)

local function segmentDistance(p: Vector2, a: Vector2, b: Vector2): number
	local ab = b - a
	local t = if ab.Magnitude > 0 then math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
	return (a + ab * t - p).Magnitude
end

local function checkClear(label: string, a: Vector2, b: Vector2, halfWidth: number)
	for _, s in sensitive do
		local d = segmentDistance(s.p, a, b)
		assert(d >= s.r + halfWidth + CLEARANCE, `{label}: too close to {s.name} ({string.format("%.1f", d)} studs)`)
	end
end

local function floorTop(label: string, x: number, z: number, half: number): number
	local centre = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -250, 0), rays)
	assert(centre, `{label}: no floor`)
	local top = centre.Position.Y
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local hit = workspace:Raycast(Vector3.new(x + c[1] * half * 0.95, top + 5, z + c[2] * half * 0.95), Vector3.new(0, -10, 0), rays)
		assert(hit and math.abs(hit.Position.Y - top) < 0.01, `{label}: floor does not cover it`)
	end
	return top
end

local plans = {}
local pointsByZone: { [string]: { Vector2 } } = {}
for _, pt in POINTS do
	local top = floorTop(pt[1], pt[3], pt[4], 1)
	checkClear(pt[1], Vector2.new(pt[3], pt[4]), Vector2.new(pt[3], pt[4]), PROP_SIZE / 2)
	pointsByZone[pt[2]] = pointsByZone[pt[2]] or {}
	table.insert(pointsByZone[pt[2]], Vector2.new(pt[3], pt[4]))
	table.insert(plans, { kind = "point", id = pt[1], zone = pt[2], cf = CFrame.new(pt[3], top + 0.1, pt[4]), size = Vector3.new(2, 0.2, 2) })
end
-- Corruption nodes first, so crate paths are also checked against them.
for _, n in NODES do
	local top = floorTop(n[1], n[4], n[5], NODE_SIZE / 2)
	checkClear(n[1], Vector2.new(n[4], n[5]), Vector2.new(n[4], n[5]), NODE_SIZE / 2)
	table.insert(plans, { kind = "node", id = n[1], zone = n[2], order = n[3], cf = CFrame.new(n[4], top + 0.1, n[5]), size = Vector3.new(NODE_SIZE, 0.2, NODE_SIZE) })
end
for _, n in NODES do
	table.insert(sensitive, { p = Vector2.new(n[4], n[5]), r = NODE_SIZE / 2, name = n[1] })
end
for _, pr in PROPS do
	local top = floorTop(pr[1], pr[3], pr[4], PROP_SIZE / 2)
	local start = Vector2.new(pr[3], pr[4])
	local best: Vector2? = nil
	for _, p in pointsByZone[pr[2]] or {} do
		if best == nil or (p - start).Magnitude < (best - start).Magnitude then
			best = p
		end
	end
	assert(best, `{pr[1]}: no MagneticPoint in its zone`)
	local target = best :: Vector2
	checkClear(pr[1], start, target, PROP_SIZE / 2)
	-- Volume and headroom at the start, and a box sweep along the path (raised off the floor).
	local blocking = workspace:GetPartBoundsInBox(CFrame.new(pr[3], top + PROP_SIZE / 2 + 3.2, pr[4]), Vector3.new(PROP_SIZE, PROP_SIZE + 6, PROP_SIZE), overlap)
	assert(#blocking == 0, `{pr[1]}: blocked by {blocking[1] and blocking[1]:GetFullName()}`)
	local steps = math.ceil((target - start).Magnitude)
	for i = 0, steps do
		local p = start:Lerp(target, i / steps)
		local hits = workspace:GetPartBoundsInBox(CFrame.new(p.X, top + PROP_SIZE / 2 + 0.2, p.Y), Vector3.new(PROP_SIZE, PROP_SIZE, PROP_SIZE), overlap)
		assert(#hits == 0, `{pr[1]}: path blocked by {hits[1] and hits[1]:GetFullName()}`)
	end
	table.insert(plans, { kind = "prop", id = pr[1], zone = pr[2], cf = CFrame.new(pr[3], top + PROP_SIZE / 2, pr[4]), size = Vector3.new(PROP_SIZE, PROP_SIZE, PROP_SIZE) })
end
for _, f in FLOODS do
	table.insert(plans, { kind = "flood", id = f[1], zone = f[2], maxRise = f[8], cf = CFrame.new(f[3], f[7] + 0.5, f[4]), size = Vector3.new(f[5], 1, f[6]) })
end

local folder = Instance.new("Folder")
folder.Name = "PatchMarkers"
for _, plan in plans do
	local part = Instance.new("Part")
	part.Name = plan.id
	part.Size = plan.size
	part.CFrame = plan.cf
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("Zone", plan.zone)
	if plan.kind == "prop" then
		part.CanCollide = true
		part.Material = Enum.Material.DiamondPlate
		part.Color = Color3.fromRGB(70, 78, 96)
		part:SetAttribute("PropId", plan.id)
		CollectionService:AddTag(part, "MagneticProp")
	else
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.CastShadow = false
		if plan.kind == "point" then
			part:SetAttribute("PointId", plan.id)
			CollectionService:AddTag(part, "MagneticPoint")
		elseif plan.kind == "node" then
			part:SetAttribute("NodeId", plan.id)
			part:SetAttribute("Order", plan.order)
			CollectionService:AddTag(part, "CorruptionNode")
		else
			part:SetAttribute("FloodZoneId", plan.id)
			part:SetAttribute("MaxRise", plan.maxRise)
			CollectionService:AddTag(part, "FloodZone")
		end
	end
	part.Parent = folder
end
folder.Parent = map
return `created {#plans} patch markers`

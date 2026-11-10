--!strict
-- WORLD.EXE Phase 1 arena builder.
-- Run once in Studio (command bar or Studio MCP execute_luau, Edit DataModel).
-- The resulting geometry is Studio-owned; this file records exactly how it was generated.
-- Refuses to run if Workspace.WORLD_EXE already exists, so it never overwrites work.
--
-- Coordinates: +X east, -Z north. Floor tops: ground level Y=0, Skybridge Y=24.
-- The arena floats over the void; falling below Workspace.FallenPartsDestroyHeight respawns the player.

local CollectionService = game:GetService("CollectionService")

assert(workspace:FindFirstChild("WORLD_EXE") == nil, "Workspace.WORLD_EXE already exists; refusing to overwrite")

local Palette = {
	Floor = Color3.fromRGB(38, 46, 74),
	FloorAlt = Color3.fromRGB(30, 36, 60),
	Cover = Color3.fromRGB(58, 68, 104),
	Cyan = Color3.fromRGB(0, 225, 255),
	Violet = Color3.fromRGB(138, 43, 226),
	Decay = Color3.fromRGB(72, 60, 112),
	DecayAlt = Color3.fromRGB(62, 52, 98),
	Green = Color3.fromRGB(60, 220, 140),
	Spawn = Color3.fromRGB(20, 110, 140),
}

local function newFolder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function newPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Visual-only part: no collision, queries, or touch events.
local function decorative(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-- Invisible server-side data point (landing points, drone waypoints).
local function marker(p: BasePart)
	decorative(p)
	p.Transparency = 1
end

-- Floor slab whose TOP surface is at topY.
local function slab(parent: Instance, name: string, cx: number, topY: number, cz: number, sx: number, sz: number, color: Color3, thickness: number?): Part
	local t = thickness or 4
	return newPart(parent, name, Vector3.new(sx, t, sz), CFrame.new(cx, topY - t / 2, cz), color)
end

-- Neon trim strips on the four side faces of an axis-aligned slab (never on the walking surface).
local function trim(parent: Instance, slabPart: BasePart, color: Color3)
	local s = slabPart.Size
	local cf = slabPart.CFrame
	local y = s.Y / 2 - 0.35
	local specs = {
		{ Vector3.new(s.X, 0.5, 0.3), Vector3.new(0, y, s.Z / 2 + 0.15) },
		{ Vector3.new(s.X, 0.5, 0.3), Vector3.new(0, y, -s.Z / 2 - 0.15) },
		{ Vector3.new(0.3, 0.5, s.Z), Vector3.new(s.X / 2 + 0.15, y, 0) },
		{ Vector3.new(0.3, 0.5, s.Z), Vector3.new(-s.X / 2 - 0.15, y, 0) },
	}
	for i, spec in specs do
		local strip = newPart(parent, slabPart.Name .. "_Trim" .. i, spec[1], cf * CFrame.new(spec[2]), color, Enum.Material.Neon)
		decorative(strip)
	end
end

-- Walkable ramp whose top surface runs exactly from fromTop to toTop.
local function ramp(parent: Instance, name: string, fromTop: Vector3, toTop: Vector3, width: number, color: Color3): Part
	local thickness = 2
	local length = (toTop - fromTop).Magnitude
	local cf = CFrame.lookAt((fromTop + toTop) / 2, toTop)
	cf -= cf.UpVector * (thickness / 2)
	return newPart(parent, name, Vector3.new(width, thickness, length), cf, color)
end

local function verticalCylinder(parent: Instance, name: string, center: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?): Part
	local p = newPart(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function decayTile(parent: Instance, name: string, tileId: string, zone: string, cx: number, topY: number, cz: number, size: number, color: Color3, thickness: number?): Part
	local t = slab(parent, name, cx, topY, cz, size, size, color, thickness)
	t:SetAttribute("TileId", tileId)
	t:SetAttribute("Zone", zone)
	CollectionService:AddTag(t, "DecayTile")
	return t
end

-- Hierarchy -------------------------------------------------------------------
local root = Instance.new("Folder")
root.Name = "WORLD_EXE"
root:SetAttribute("ArenaVersion", 1)

local map = newFolder(root, "Map")
local core = newFolder(map, "CentralCore")
local yard = newFolder(map, "ResearchYard")
local sky = newFolder(map, "Skybridge")
local routes = newFolder(map, "Routes")
local stabilizers = newFolder(map, "Stabilizers")
local spawns = newFolder(map, "SpawnLocations")
local landing = newFolder(map, "SupplyLandingPoints")
local waypoints = newFolder(map, "DroneWaypoints")

-- Central Core (centre 0,0,0) ---------------------------------------------------
local coreDeck = slab(core, "CoreDeck", 0, 0, 0, 80, 80, Palette.Floor)
trim(core, coreDeck, Palette.Cyan)
verticalCylinder(core, "ReactorBase", Vector3.new(0, 1.5, 0), 3, 24, Palette.Cover)
local column = verticalCylinder(core, "ReactorColumn", Vector3.new(0, 28, 0), 50, 8, Palette.Cyan, Enum.Material.Neon)
decorative(column)
local shell = verticalCylinder(core, "ReactorShell", Vector3.new(0, 28, 0), 50, 13, Palette.Violet, Enum.Material.Glass)
shell.Transparency = 0.6
verticalCylinder(core, "ReactorCap", Vector3.new(0, 54, 0), 2, 16, Palette.Cover)
newPart(core, "CoverWall_W", Vector3.new(2, 4, 12), CFrame.new(-20, 2, 0), Palette.Cover)
newPart(core, "CoverWall_E", Vector3.new(2, 4, 12), CFrame.new(20, 2, 0), Palette.Cover)

-- Research Yard (centre -120,0,0): solid frame around an 8x8 DecayTile field ----
for _, def in {
	{ "YardFrame_N", -120, -46, 104, 12 },
	{ "YardFrame_S", -120, 46, 104, 12 },
	{ "YardFrame_W", -166, 0, 12, 80 },
	{ "YardFrame_E", -74, 0, 12, 80 },
} do
	local frame = slab(yard, def[1], def[2], 0, def[3], def[4], def[5], Palette.FloorAlt)
	trim(yard, frame, Palette.Cyan)
end
local yardTiles = newFolder(yard, "DecayTiles")
for row = 0, 7 do
	for col = 0, 7 do
		local x = -160 + 5 + col * 10
		local z = -40 + 5 + row * 10
		local color = if (row + col) % 2 == 0 then Palette.Decay else Palette.DecayAlt
		decayTile(yardTiles, string.format("Tile_R%dC%d", row, col), string.format("YARD_R%dC%d", row, col), "ResearchYard", x, 0, z, 9.8, color)
	end
end
newPart(yard, "Barrier_1", Vector3.new(2, 4, 14), CFrame.new(-140, 2, -20), Palette.Cover)
newPart(yard, "Barrier_2", Vector3.new(2, 4, 14), CFrame.new(-100, 2, 20), Palette.Cover)
newPart(yard, "Barrier_3", Vector3.new(14, 4, 2), CFrame.new(-140, 2, 20), Palette.Cover)
newPart(yard, "Barrier_4", Vector3.new(14, 4, 2), CFrame.new(-100, 2, -20), Palette.Cover)

-- Skybridge (deck centre 130,24,0) ----------------------------------------------
local skyDeck = slab(sky, "SkyDeck", 130, 24, 0, 60, 48, Palette.Floor)
trim(sky, skyDeck, Palette.Violet)
newPart(sky, "CoverWall_N", Vector3.new(10, 3, 2), CFrame.new(135, 25.5, -10), Palette.Cover)
newPart(sky, "CoverWall_S", Vector3.new(10, 3, 2), CFrame.new(135, 25.5, 10), Palette.Cover)
local spanA = slab(sky, "NorthSpan_A", 110, 24, -46, 10, 46, Palette.FloorAlt, 2)
local spanB = slab(sky, "NorthSpan_B", 47.5, 24, -64, 135, 10, Palette.FloorAlt, 2)
trim(sky, spanA, Palette.Violet)
trim(sky, spanB, Palette.Violet)
-- Jump route: descending stepping platforms from the deck to the Core's south-east corner.
-- 4-stud gaps and 4-stud drops (a default jump clears ~9 studs on a 4-stud drop; 8-stud gaps failed playtest).
-- Deliberately NOT DecayTiles: this is the only jump route and it sits over a lethal void, so DECAY stays
-- on the Research Yard field (see docs/PROJECT_STATUS.md, "SkySteps decision"). Colored as solid floor.
local steps = newFolder(sky, "SkySteps")
for i, p in { Vector3.new(104, 20, 33), Vector3.new(90, 16, 37), Vector3.new(76, 12, 41), Vector3.new(62, 8, 45), Vector3.new(48, 4, 46) } do
	local step = slab(steps, "Step_" .. i, p.X, p.Y, p.Z, 10, 10, Palette.FloorAlt, 2)
	step:SetAttribute("Zone", "Skybridge")
end

-- Connecting routes -------------------------------------------------------------
local bridge = slab(routes, "Bridge_CoreYard", -54, 0, 0, 30, 16, Palette.Floor)
trim(routes, bridge, Palette.Cyan)
ramp(routes, "Ramp_CoreSky", Vector3.new(40, 0, 0), Vector3.new(100, 24, 0), 14, Palette.Floor)
local lookout = slab(routes, "Lookout", -30, 24, -64, 24, 24, Palette.Floor)
trim(routes, lookout, Palette.Violet)
ramp(routes, "Ramp_LookoutYard", Vector3.new(-42, 24, -64), Vector3.new(-90, 0, -64), 12, Palette.Floor)
local annex = slab(routes, "YardNorthAnnex", -110, 0, -64, 40, 24, Palette.FloorAlt)
trim(routes, annex, Palette.Cyan)

-- Stabilizer placeholders -------------------------------------------------------
local function stabilizer(id: string, zone: string, base: Vector3)
	local m = Instance.new("Model")
	m.Name = "Stabilizer_" .. zone
	local basePart = verticalCylinder(m, "Base", base + Vector3.new(0, 0.5, 0), 1, 8, Palette.Cover)
	local ring = verticalCylinder(m, "StatusRing", base + Vector3.new(0, 1.1, 0), 0.2, 8.4, Palette.Green, Enum.Material.Neon)
	decorative(ring)
	local console = newPart(m, "Console", Vector3.new(3, 4, 2), CFrame.new(base + Vector3.new(0, 3, 0)), Palette.Cover)
	local beacon = verticalCylinder(m, "Beacon", base + Vector3.new(0, 9, 0), 8, 1.2, Palette.Green, Enum.Material.Neon)
	decorative(beacon)
	local point = Instance.new("Attachment")
	point.Name = "InteractionPoint"
	point.Position = Vector3.new(0, 0, -1.2)
	point.Parent = console
	m.PrimaryPart = basePart
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m:SetAttribute("StabilizerId", id)
	m:SetAttribute("Zone", zone)
	m:SetAttribute("InteractionRadius", 10)
	CollectionService:AddTag(m, "Stabilizer")
	m.Parent = stabilizers
end
stabilizer("STAB_CORE", "CentralCore", Vector3.new(0, 0, 26))
stabilizer("STAB_YARD", "ResearchYard", Vector3.new(-120, 0, -46))
stabilizer("STAB_SKY", "Skybridge", Vector3.new(152, 24, 0))

-- Player spawns: real SpawnLocations (12), on solid non-decay floor -------------
for _, def in {
	{ "CORE_1", "CentralCore", Vector3.new(-30, 0, -30) },
	{ "CORE_2", "CentralCore", Vector3.new(30, 0, -30) },
	{ "CORE_3", "CentralCore", Vector3.new(-30, 0, 30) },
	{ "CORE_4", "CentralCore", Vector3.new(30, 0, 30) },
	{ "YARD_1", "ResearchYard", Vector3.new(-150, 0, -46) },
	{ "YARD_2", "ResearchYard", Vector3.new(-90, 0, -46) },
	{ "YARD_3", "ResearchYard", Vector3.new(-150, 0, 46) },
	{ "YARD_4", "ResearchYard", Vector3.new(-90, 0, 46) },
	{ "SKY_1", "Skybridge", Vector3.new(120, 24, -14) },
	{ "SKY_2", "Skybridge", Vector3.new(120, 24, 14) },
	{ "SKY_3", "Skybridge", Vector3.new(150, 24, -14) },
	{ "SKY_4", "Skybridge", Vector3.new(150, 24, 14) },
} do
	local s = Instance.new("SpawnLocation")
	s.Name = "Spawn_" .. def[1]
	s.Anchored = true
	s.Size = Vector3.new(6, 1, 6)
	s.CFrame = CFrame.new(def[3] + Vector3.new(0, 0.5, 0))
	s.Color = Palette.Spawn
	s.Material = Enum.Material.SmoothPlastic
	s.TopSurface = Enum.SurfaceType.Smooth
	s.BottomSurface = Enum.SurfaceType.Smooth
	s.Enabled = true
	s.Neutral = true
	s.AllowTeamChangeOnTouch = false
	s.Duration = 0 -- no spawn forcefield; match-start protection is a Phase 2 concern
	s:SetAttribute("SpawnId", def[1])
	s:SetAttribute("Zone", def[2])
	CollectionService:AddTag(s, "ArenaSpawn")
	s.Parent = spawns
end

-- Supply landing points (invisible, server-read) --------------------------------
for _, def in {
	{ "SUP_CORE", "CentralCore", Vector3.new(0, 0, -28) },
	{ "SUP_YARD", "ResearchYard", Vector3.new(-120, 0, 46) },
	{ "SUP_ANNEX", "ResearchYard", Vector3.new(-110, 0, -64) },
	{ "SUP_LOOKOUT", "Routes", Vector3.new(-30, 24, -64) },
	{ "SUP_SKY", "Skybridge", Vector3.new(135, 24, 0) },
} do
	local p = newPart(landing, def[1], Vector3.new(10, 0.2, 10), CFrame.new(def[3] + Vector3.new(0, 0.1, 0)), Color3.fromRGB(255, 193, 7))
	marker(p)
	p:SetAttribute("PointId", def[1])
	p:SetAttribute("Zone", def[2])
	CollectionService:AddTag(p, "SupplyLandingPoint")
end

-- Drone waypoint graph (invisible, server-read). Links are symmetric. -----------
for _, def in {
	{ "WP_C1", "CentralCore", Vector3.new(-28, 10, -28), "WP_C2,WP_C4,WP_B1" },
	{ "WP_C2", "CentralCore", Vector3.new(28, 10, -28), "WP_C1,WP_C3,WP_R1" },
	{ "WP_C3", "CentralCore", Vector3.new(28, 10, 28), "WP_C2,WP_C4,WP_R1" },
	{ "WP_C4", "CentralCore", Vector3.new(-28, 10, 28), "WP_C3,WP_C1,WP_B1" },
	{ "WP_B1", "Routes", Vector3.new(-54, 10, 0), "WP_C1,WP_C4,WP_Y2,WP_Y4" },
	{ "WP_Y1", "ResearchYard", Vector3.new(-150, 10, -30), "WP_Y2,WP_Y3,WP_A1" },
	{ "WP_Y2", "ResearchYard", Vector3.new(-90, 10, -30), "WP_Y1,WP_Y4,WP_B1,WP_A1" },
	{ "WP_Y3", "ResearchYard", Vector3.new(-150, 10, 30), "WP_Y1,WP_Y4" },
	{ "WP_Y4", "ResearchYard", Vector3.new(-90, 10, 30), "WP_Y2,WP_Y3,WP_B1" },
	{ "WP_R1", "Routes", Vector3.new(70, 22, 0), "WP_C2,WP_C3,WP_S1" },
	{ "WP_S1", "Skybridge", Vector3.new(115, 34, -10), "WP_R1,WP_S2,WP_N1" },
	{ "WP_S2", "Skybridge", Vector3.new(145, 34, 10), "WP_S1" },
	{ "WP_N1", "Skybridge", Vector3.new(46, 34, -64), "WP_S1,WP_L1" },
	{ "WP_L1", "Routes", Vector3.new(-30, 34, -64), "WP_N1,WP_A1" },
	{ "WP_A1", "ResearchYard", Vector3.new(-110, 10, -64), "WP_L1,WP_Y1,WP_Y2" },
} do
	local p = newPart(waypoints, def[1], Vector3.new(1, 1, 1), CFrame.new(def[3]), Palette.Cyan)
	marker(p)
	p:SetAttribute("WaypointId", def[1])
	p:SetAttribute("Zone", def[2])
	p:SetAttribute("Links", def[4])
	CollectionService:AddTag(p, "DroneWaypoint")
end

root.Parent = workspace

local parts = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return `built Workspace.WORLD_EXE with {parts} parts`

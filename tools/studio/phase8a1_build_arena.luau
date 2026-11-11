--!strict
-- WORLD.EXE Phase 8A-1 arena builder (Studio Edit mode, run once via Studio MCP execute_luau).
-- Replaces the Phase 1 prototype arena with the approved larger greybox facility (design:
-- docs/PHASE_8A_ARENA_DESIGN.md, decisions M1–M8).
--
-- 1. Moves the current Workspace.WORLD_EXE.Map and .Lobby into ServerStorage.WORLD_EXE_RollbackArena_v1
--    (an isolated rollback copy; every gameplay system only reads Workspace.WORLD_EXE.Map/.Lobby).
--    The external .rbxl backup stays authoritative.
-- 2. Builds the new Map (greybox: navy slabs, cyan/violet neon trims) and the relocated Lobby.
-- 3. Places every tagged gameplay marker and validates it before anything is kept:
--    floors, headroom, crate lanes, drone-waypoint lines of sight, supply-drop sky clearance,
--    and the Phase 8A spawn-safety rules. On any failure the new content is destroyed and the
--    old Map/Lobby are moved back, so the place is left exactly as it was.
--
-- Coordinates: +X east, -Z north. Tiers: T0 Y0, T1 Y24, T2 Y48, T3 Y72; reservoir basin Y-10.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local root = workspace:WaitForChild("WORLD_EXE")
assert(root:GetAttribute("ArenaVersion") == 1, "expected the Phase 1 arena (ArenaVersion 1)")
assert(ServerStorage:FindFirstChild("WORLD_EXE_RollbackArena_v1") == nil, "rollback copy already exists")
local oldMap = root:FindFirstChild("Map")
local oldLobby = root:FindFirstChild("Lobby")
assert(oldMap and oldLobby, "current Map/Lobby not found")

local C = {
	Floor = Color3.fromRGB(38, 46, 74),
	FloorAlt = Color3.fromRGB(30, 36, 60),
	Deep = Color3.fromRGB(22, 28, 50),
	Cover = Color3.fromRGB(58, 68, 104),
	Cyan = Color3.fromRGB(0, 225, 255),
	Violet = Color3.fromRGB(138, 43, 226),
	Decay = Color3.fromRGB(72, 60, 112),
	DecayAlt = Color3.fromRGB(62, 52, 98),
	Green = Color3.fromRGB(60, 220, 140),
	Spawn = Color3.fromRGB(20, 110, 140),
	Bounce = Color3.fromRGB(88, 52, 140),
	Slip = Color3.fromRGB(120, 150, 175),
	Crate = Color3.fromRGB(70, 78, 96),
}

---------------------------------------------------------------------------------------------------
-- Part helpers

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function decorative(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local function invisibleMarker(p: BasePart)
	decorative(p)
	p.Transparency = 1
end

-- Axis-aligned slab from bounds; top surface at `top`.
local function slab(parent: Instance, name: string, x0: number, x1: number, z0: number, z1: number, top: number, thick: number, color: Color3): Part
	return part(parent, name, Vector3.new(x1 - x0, thick, z1 - z0), CFrame.new((x0 + x1) / 2, top - thick / 2, (z0 + z1) / 2), color)
end

-- Neon strips on the four side faces of a slab (never on the walking surface).
local function trim(parent: Instance, s: BasePart, color: Color3)
	local size, cf = s.Size, s.CFrame
	local y = size.Y / 2 - 0.35
	for i, spec in {
		{ Vector3.new(size.X, 0.5, 0.3), Vector3.new(0, y, size.Z / 2 + 0.15) },
		{ Vector3.new(size.X, 0.5, 0.3), Vector3.new(0, y, -size.Z / 2 - 0.15) },
		{ Vector3.new(0.3, 0.5, size.Z), Vector3.new(size.X / 2 + 0.15, y, 0) },
		{ Vector3.new(0.3, 0.5, size.Z), Vector3.new(-size.X / 2 - 0.15, y, 0) },
	} do
		decorative(part(parent, s.Name .. "_Trim" .. i, spec[1], cf * CFrame.new(spec[2]), color, Enum.Material.Neon))
	end
end

-- Walkable ramp whose top surface runs exactly from fromTop to toTop.
local function ramp(parent: Instance, name: string, fromTop: Vector3, toTop: Vector3, width: number, color: Color3): Part
	local length = (toTop - fromTop).Magnitude
	local cf = CFrame.lookAt((fromTop + toTop) / 2, toTop)
	cf -= cf.UpVector
	return part(parent, name, Vector3.new(width, 2, length), cf, color)
end

local function cylinder(parent: Instance, name: string, center: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?): Part
	local p = part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function wallBox(parent: Instance, name: string, x0: number, x1: number, z0: number, z1: number, y0: number, y1: number, color: Color3): Part
	return part(parent, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color)
end

---------------------------------------------------------------------------------------------------
-- Swap: old content to the isolated rollback folder, new content in its place

local rollback = Instance.new("Folder")
rollback.Name = "WORLD_EXE_RollbackArena_v1"
rollback:SetAttribute("Note", "Phase 1 arena + lobby, moved here by phase8a1_build_arena.luau. Not read by any game system. External .rbxl backup is authoritative.")
rollback.Parent = ServerStorage
oldMap.Parent = rollback
oldLobby.Parent = rollback

local map = Instance.new("Folder")
map.Name = "Map"
local lobby = Instance.new("Folder")
lobby.Name = "Lobby"

local ok, err = pcall(function()
	map.Parent = root

	-------------------------------------------------------------------------------------------
	-- CENTRAL CORE (centre 0,0): plaza T0, reactor spire, mezzanine ring T1, gantries
	local core = folder(map, "CentralCore")
	trim(core, slab(core, "CorePlaza", -100, 100, -100, 100, 0, 4, C.Floor), C.Cyan)
	cylinder(core, "ReactorDrum", Vector3.new(0, 6, 0), 12, 36, C.Cover)
	decorative(cylinder(core, "ReactorShaft", Vector3.new(0, 72, 0), 120, 12, C.Cyan, Enum.Material.Neon))
	local shell = cylinder(core, "ReactorShell", Vector3.new(0, 72, 0), 120, 20, C.Violet, Enum.Material.Glass)
	shell.Transparency = 0.55
	decorative(shell)
	for i, y in { 40, 80, 120 } do
		decorative(cylinder(core, "ReactorRing_" .. i, Vector3.new(0, y, 0), 1, 30, C.Violet, Enum.Material.Neon))
	end
	cylinder(core, "ReactorCap", Vector3.new(0, 133, 0), 2, 26, C.Cover)
	local mezz = folder(core, "Mezzanine")
	for _, d in {
		{ "Mezz_N", -55, 55, -55, -40 },
		{ "Mezz_S", -55, 55, 40, 55 },
		{ "Mezz_E", 40, 55, -40, 40 },
		{ "Mezz_W", -55, -40, -40, 40 },
	} do
		trim(mezz, slab(mezz, d[1], d[2], d[3], d[4], d[5], 24, 2, C.FloorAlt), C.Violet)
	end
	for i, p in { Vector3.new(-47.5, 11, -47.5), Vector3.new(47.5, 11, -47.5), Vector3.new(47.5, 11, 47.5), Vector3.new(-47.5, 11, 47.5) } do
		part(mezz, "MezzPillar_" .. i, Vector3.new(3, 22, 3), CFrame.new(p), C.Cover)
	end
	ramp(core, "Ramp_MezzW", Vector3.new(-61, 0, -50), Vector3.new(-61, 24, 10), 12, C.Floor)
	ramp(core, "Ramp_MezzS", Vector3.new(-50, 0, 61), Vector3.new(10, 24, 61), 12, C.Floor)
	for i, p in { Vector3.new(-88, 6, -30), Vector3.new(88, 6, -30), Vector3.new(88, 6, 30), Vector3.new(-88, 6, 30) } do
		part(core, "Pylon_" .. i, Vector3.new(10, 12, 10), CFrame.new(p), C.Cover)
	end
	part(core, "CoverWall_W", Vector3.new(2, 4, 16), CFrame.new(-75, 2, 0), C.Cover)
	part(core, "CoverWall_E", Vector3.new(2, 4, 16), CFrame.new(75, 2, 0), C.Cover)
	-- Gantries: east T1->T2 to the SkyDeck; north T1 to the Archive south walkway.
	ramp(core, "Gantry_E_Ramp", Vector3.new(55, 24, 0), Vector3.new(115, 48, 0), 12, C.FloorAlt)
	trim(core, slab(core, "Gantry_E_Bridge", 115, 160, -6, 6, 48, 2, C.FloorAlt), C.Violet)
	trim(core, slab(core, "Gantry_N_Bridge", -6, 6, -146, -55, 24, 2, C.FloorAlt), C.Violet)

	-------------------------------------------------------------------------------------------
	-- SPOKES (T0 corridors, 24 wide)
	local routes = folder(map, "Routes")
	for _, d in {
		{ "Spoke_W", -140, -100, -12, 12 },
		{ "Spoke_E", 100, 140, -12, 12 },
		{ "Spoke_N", -12, 12, -140, -100 },
		{ "Spoke_S", -12, 12, 100, 140 },
	} do
		trim(routes, slab(routes, d[1], d[2], d[3], d[4], d[5], 0, 4, C.Floor), C.Cyan)
	end

	-------------------------------------------------------------------------------------------
	-- OUTER RING (T1, 14 wide, centre line +-230)
	local ring = folder(map, "OuterRing")
	for _, d in {
		{ "Ring_N", -237, 237, -237, -223 },
		{ "Ring_S", -237, 237, 223, 237 },
		{ "Ring_W", -237, -223, -223, 223 },
		{ "Ring_E", 223, 237, -223, 223 },
	} do
		trim(ring, slab(ring, d[1], d[2], d[3], d[4], d[5], 24, 2, C.FloorAlt), C.Cyan)
	end

	-------------------------------------------------------------------------------------------
	-- RESEARCH YARD (west): 10x10 DecayTile test grid, test chambers, T1 catwalks
	local yard = folder(map, "ResearchYard")
	for _, d in {
		{ "YardFloor_N", -260, -140, -130, -50 },
		{ "YardFloor_S", -260, -140, 50, 130 },
		{ "YardFloor_W", -260, -250, -50, 50 },
		{ "YardFloor_E", -150, -140, -50, 50 },
	} do
		trim(yard, slab(yard, d[1], d[2], d[3], d[4], d[5], 0, 4, C.FloorAlt), C.Cyan)
	end
	local tiles = folder(yard, "DecayTiles")
	for row = 0, 9 do
		for col = 0, 9 do
			local t = slab(tiles, string.format("Tile_R%dC%d", row, col), -250 + col * 10 + 0.1, -250 + col * 10 + 9.9, -50 + row * 10 + 0.1, -50 + row * 10 + 9.9, 0, 4, if (row + col) % 2 == 0 then C.Decay else C.DecayAlt)
			t:SetAttribute("TileId", string.format("YARD_R%dC%d", row, col))
			t:SetAttribute("Zone", "ResearchYard")
			CollectionService:AddTag(t, "DecayTile")
		end
	end
	local function chamber(name: string, cz: number)
		local f = folder(yard, name)
		local x0, x1, z0, z1 = -215, -185, cz - 15, cz + 15
		wallBox(f, "Wall_N", x0, x1, z0, z0 + 2, 0, 12, C.Cover)
		wallBox(f, "Wall_S", x0, x1, z1 - 2, z1, 0, 12, C.Cover)
		wallBox(f, "Wall_W1", x0, x0 + 2, z0 + 2, cz - 4, 0, 12, C.Cover)
		wallBox(f, "Wall_W2", x0, x0 + 2, cz + 4, z1 - 2, 0, 12, C.Cover)
		wallBox(f, "Wall_E1", x1 - 2, x1, z0 + 2, cz - 4, 0, 12, C.Cover)
		wallBox(f, "Wall_E2", x1 - 2, x1, cz + 4, z1 - 2, 0, 12, C.Cover)
	end
	chamber("TestChamber_N", -90)
	chamber("TestChamber_S", 90)
	trim(yard, slab(yard, "Catwalk_N", -255, -145, -128, -118, 24, 2, C.FloorAlt), C.Violet)
	trim(yard, slab(yard, "Catwalk_S", -255, -145, 118, 128, 24, 2, C.FloorAlt), C.Violet)
	ramp(yard, "Ramp_CatwalkN", Vector3.new(-170, 24, -118), Vector3.new(-170, 0, -58), 12, C.Floor)
	ramp(yard, "Ramp_CatwalkS", Vector3.new(-170, 24, 118), Vector3.new(-170, 0, 58), 12, C.Floor)

	-------------------------------------------------------------------------------------------
	-- SKYBRIDGE DISTRICT (east): base T0, landings T1, SkyDeck T2, floating islands T3
	local sky = folder(map, "Skybridge")
	trim(sky, slab(sky, "SkyBase", 140, 200, -130, 130, 0, 4, C.Floor), C.Cyan)
	trim(sky, slab(sky, "SkyDeck", 160, 230, -40, 40, 48, 4, C.Floor), C.Violet)
	for i, p in { Vector3.new(165, 22, -35), Vector3.new(195, 22, -35), Vector3.new(195, 22, 35), Vector3.new(165, 22, 35) } do
		part(sky, "DeckPillar_" .. i, Vector3.new(3, 44, 3), CFrame.new(p), C.Cover)
	end
	part(sky, "DeckCover_N", Vector3.new(10, 3, 2), CFrame.new(190, 49.5, -15), C.Cover)
	part(sky, "DeckCover_S", Vector3.new(10, 3, 2), CFrame.new(190, 49.5, 15), C.Cover)
	trim(sky, slab(sky, "SkyLanding_N", 150, 237, -140, -118, 24, 2, C.FloorAlt), C.Cyan)
	trim(sky, slab(sky, "SkyLanding_S", 150, 237, 118, 140, 24, 2, C.FloorAlt), C.Cyan)
	ramp(sky, "SkyClimb_N", Vector3.new(170, 0, -60), Vector3.new(170, 24, -120), 12, C.Floor)
	ramp(sky, "SkyClimb_S", Vector3.new(170, 0, 60), Vector3.new(170, 24, 120), 12, C.Floor)
	ramp(sky, "DeckRamp_N", Vector3.new(216, 24, -118), Vector3.new(216, 48, -40), 12, C.FloorAlt)
	ramp(sky, "DeckRamp_S", Vector3.new(216, 24, 118), Vector3.new(216, 48, 40), 12, C.FloorAlt)
	for _, sgn in { -1, 1 } do
		local tag = if sgn < 0 then "N" else "S"
		local steps = folder(sky, "IslandSteps_" .. tag)
		for i = 1, 5 do
			local z = sgn * (47 + 14 * (i - 1))
			slab(steps, "Step_" .. i, 180, 190, z - 5, z + 5, 48 + 4 * i, 2, C.FloorAlt)
		end
		trim(sky, slab(sky, "Island_" .. tag, 173, 197, sgn * 124 - 12, sgn * 124 + 12, 72, 4, C.Deep), C.Violet)
	end

	-------------------------------------------------------------------------------------------
	-- DATA ARCHIVE (north): server-rack canyons, atrium, T1 rack-top decks
	local archive = folder(map, "DataArchive")
	trim(archive, slab(archive, "ArchiveFloor", -130, 130, -260, -140, 0, 4, C.FloorAlt), C.Cyan)
	local racks = folder(archive, "Racks")
	for _, x in { -110, -88, -66, 66, 88, 110 } do
		for _, span in { { -215, -190, "A" }, { -180, -155, "B" } } do
			local r = wallBox(racks, string.format("Rack_%d%s", x, span[3]), x - 4, x + 4, span[1], span[2], 0, 24, C.Deep)
			decorative(part(racks, r.Name .. "_Strip", Vector3.new(0.3, 18, 23), CFrame.new(x + (if x < 0 then 4.15 else -4.15), 12, (span[1] + span[2]) / 2), C.Cyan, Enum.Material.Neon))
		end
	end
	trim(archive, slab(archive, "RackDeck_NW", -121, -56, -223, -215, 24, 2, C.FloorAlt), C.Violet)
	trim(archive, slab(archive, "RackDeck_NE", 56, 121, -223, -215, 24, 2, C.FloorAlt), C.Violet)
	trim(archive, slab(archive, "ArchiveWalk_S", -121, 121, -155, -146, 24, 2, C.FloorAlt), C.Violet)
	ramp(archive, "ArchiveRamp_W", Vector3.new(-50, 24, -223), Vector3.new(-50, 0, -163), 12, C.Floor)
	ramp(archive, "ArchiveRamp_E", Vector3.new(50, 24, -223), Vector3.new(50, 0, -163), 12, C.Floor)
	part(archive, "AtriumWall_W", Vector3.new(12, 4, 2), CFrame.new(-25, 2, -175), C.Cover)
	part(archive, "AtriumWall_E", Vector3.new(12, 4, 2), CFrame.new(25, 2, -175), C.Cover)

	-------------------------------------------------------------------------------------------
	-- COOLANT RESERVOIR (south): sunken basin Y-10, rims T0, pump towers, T1 bridge with a gap
	local res = folder(map, "CoolantReservoir")
	for _, d in {
		{ "Rim_N", -130, 130, 140, 155 },
		{ "Rim_S", -130, 130, 245, 260 },
		{ "Rim_W", -130, -75, 155, 245 },
		{ "Rim_E", 75, 130, 155, 245 },
	} do
		trim(res, slab(res, d[1], d[2], d[3], d[4], d[5], 0, 4, C.Floor), C.Cyan)
	end
	slab(res, "BasinFloor", -75, 75, 155, 245, -10, 4, C.Deep)
	wallBox(res, "BasinWall_N", -77, 77, 153, 155, -14, 0, C.Cover)
	wallBox(res, "BasinWall_S", -77, 77, 245, 247, -14, 0, C.Cover)
	wallBox(res, "BasinWall_W", -77, -75, 155, 245, -14, 0, C.Cover)
	wallBox(res, "BasinWall_E", 75, 77, 155, 245, -14, 0, C.Cover)
	ramp(res, "BasinRamp_W", Vector3.new(-45, -10, 200), Vector3.new(-75, 0, 200), 10, C.Floor)
	ramp(res, "BasinRamp_E", Vector3.new(45, -10, 200), Vector3.new(75, 0, 200), 10, C.Floor)
	ramp(res, "BasinRamp_N", Vector3.new(0, -10, 185), Vector3.new(0, 0, 155), 10, C.Floor)
	for i, x in { -30, 30 } do
		cylinder(res, "PumpTower_" .. i, Vector3.new(x, 10, 225), 40, 14, C.Cover)
		decorative(cylinder(res, "PumpRing_" .. i, Vector3.new(x, 26, 225), 1, 15, C.Cyan, Enum.Material.Neon))
	end
	trim(res, slab(res, "Bridge_W", -75, -7, 194, 206, 24, 2, C.FloorAlt), C.Violet)
	trim(res, slab(res, "Bridge_E", 7, 75, 194, 206, 24, 2, C.FloorAlt), C.Violet)
	slab(res, "BridgeLink_W", -46, -34, 206, 223, 24, 2, C.FloorAlt)
	slab(res, "BridgeLink_E", 34, 46, 206, 223, 24, 2, C.FloorAlt)
	ramp(res, "RingRamp_W", Vector3.new(-100, 24, 223), Vector3.new(-100, 0, 163), 12, C.Floor)
	ramp(res, "RingRamp_E", Vector3.new(100, 24, 223), Vector3.new(100, 0, 163), 12, C.Floor)

	-------------------------------------------------------------------------------------------
	-- STABILIZERS (same model as Phase 1: ObjectiveService reads Console/InteractionPoint)
	local stabilizers = folder(map, "Stabilizers")
	local function stabilizer(id: string, zone: string, base: Vector3)
		local m = Instance.new("Model")
		m.Name = "Stabilizer_" .. zone
		local basePart = cylinder(m, "Base", base + Vector3.new(0, 0.5, 0), 1, 8, C.Cover)
		decorative(cylinder(m, "StatusRing", base + Vector3.new(0, 1.1, 0), 0.2, 8.4, C.Green, Enum.Material.Neon))
		local console = part(m, "Console", Vector3.new(3, 4, 2), CFrame.new(base + Vector3.new(0, 3, 0)), C.Cover)
		decorative(cylinder(m, "Beacon", base + Vector3.new(0, 9, 0), 8, 1.2, C.Green, Enum.Material.Neon))
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
	stabilizer("STAB_CORE", "CentralCore", Vector3.new(-28, 0, -80))
	stabilizer("STAB_YARD", "ResearchYard", Vector3.new(-215, 0, -62))
	stabilizer("STAB_SKY", "Skybridge", Vector3.new(210, 48, 0))

	-------------------------------------------------------------------------------------------
	-- MARKERS
	local spawns = folder(map, "SpawnLocations")
	for _, d in {
		{ "CORE_1", "CentralCore", -85, 0, -85 }, { "CORE_2", "CentralCore", 85, 0, -85 },
		{ "CORE_3", "CentralCore", 85, 0, 85 }, { "CORE_4", "CentralCore", -85, 0, 85 },
		{ "YARD_1", "ResearchYard", -245, 0, -70 }, { "YARD_2", "ResearchYard", -150, 0, -90 },
		{ "YARD_3", "ResearchYard", -245, 0, 70 },
		{ "SKY_1", "Skybridge", 175, 48, -20 }, { "SKY_2", "Skybridge", 175, 48, 20 },
		{ "SKY_3", "Skybridge", 150, 0, 100 },
		{ "ARCH_1", "DataArchive", 0, 0, -250 }, { "ARCH_2", "DataArchive", -95, 0, -250 },
		{ "ARCH_3", "DataArchive", 95, 0, -250 },
		{ "RES_1", "CoolantReservoir", -110, 0, 250 }, { "RES_2", "CoolantReservoir", 110, 0, 250 },
		{ "RES_3", "CoolantReservoir", 0, 0, 147 },
	} do
		local s = Instance.new("SpawnLocation")
		s.Name = "Spawn_" .. d[1]
		s.Anchored = true
		s.Size = Vector3.new(6, 1, 6)
		s.CFrame = CFrame.new(d[3], d[4] + 0.5, d[5])
		s.Color = C.Spawn
		s.Material = Enum.Material.SmoothPlastic
		s.TopSurface = Enum.SurfaceType.Smooth
		s.BottomSurface = Enum.SurfaceType.Smooth
		s.Enabled = true
		s.Neutral = true
		s.AllowTeamChangeOnTouch = false
		s.Duration = 0
		s:SetAttribute("SpawnId", d[1])
		s:SetAttribute("Zone", d[2])
		CollectionService:AddTag(s, "ArenaSpawn")
		s.Parent = spawns
	end

	local landing = folder(map, "SupplyLandingPoints")
	for _, d in {
		{ "SUP_CORE", "CentralCore", 60, 0, 80 }, { "SUP_YARD", "ResearchYard", -150, 0, 90 },
		{ "SUP_SKY", "Skybridge", 195, 48, -25 }, { "SUP_ISLAND", "Skybridge", 185, 72, -124 },
		{ "SUP_ARCHIVE", "DataArchive", 0, 0, -200 }, { "SUP_RES", "CoolantReservoir", 0, 0, 252 },
		{ "SUP_RING_NW", "OuterRing", -230, 24, -230 }, { "SUP_RING_SE", "OuterRing", 230, 24, 230 },
	} do
		local p = part(landing, d[1], Vector3.new(10, 0.2, 10), CFrame.new(d[3], d[4] + 0.1, d[5]), Color3.fromRGB(255, 193, 7))
		invisibleMarker(p)
		p:SetAttribute("PointId", d[1])
		p:SetAttribute("Zone", d[2])
		CollectionService:AddTag(p, "SupplyLandingPoint")
	end

	local waypoints = folder(map, "DroneWaypoints")
	for _, d in {
		{ "WP_C1", "CentralCore", -75, 10, -75, "WP_C2,WP_C4,WP_SW,WP_SN" },
		{ "WP_C2", "CentralCore", 75, 10, -75, "WP_C1,WP_C3,WP_SN,WP_SE,WP_M2" },
		{ "WP_C3", "CentralCore", 75, 10, 75, "WP_C2,WP_C4,WP_SE,WP_SS" },
		{ "WP_C4", "CentralCore", -75, 10, 75, "WP_C3,WP_C1,WP_SS,WP_SW,WP_M4" },
		{ "WP_M1", "CentralCore", 0, 34, -47.5, "WP_M2,WP_M4" },
		{ "WP_M2", "CentralCore", 47.5, 34, 0, "WP_M1,WP_M3,WP_G1,WP_C2" },
		{ "WP_M3", "CentralCore", 0, 34, 47.5, "WP_M2,WP_M4" },
		{ "WP_M4", "CentralCore", -47.5, 34, 0, "WP_M3,WP_M1,WP_C4" },
		{ "WP_SW", "Routes", -120, 10, 0, "WP_C1,WP_C4,WP_Y2,WP_Y3" },
		{ "WP_SE", "Routes", 120, 10, 0, "WP_C2,WP_C3,WP_K1" },
		{ "WP_SN", "Routes", 0, 10, -120, "WP_C1,WP_C2,WP_A1" },
		{ "WP_SS", "Routes", 0, 10, 120, "WP_C3,WP_C4,WP_R1,WP_R2" },
		{ "WP_Y1", "ResearchYard", -230, 10, -30, "WP_Y2,WP_Y4" },
		{ "WP_Y2", "ResearchYard", -170, 10, -30, "WP_Y1,WP_Y3,WP_SW" },
		{ "WP_Y3", "ResearchYard", -170, 10, 30, "WP_Y2,WP_Y4,WP_SW" },
		{ "WP_Y4", "ResearchYard", -230, 10, 30, "WP_Y3,WP_Y1" },
		{ "WP_K1", "Skybridge", 150, 10, 0, "WP_SE" },
		{ "WP_G1", "Skybridge", 130, 58, 0, "WP_M2,WP_K2" },
		{ "WP_K2", "Skybridge", 195, 58, 0, "WP_G1,WP_K3,WP_K4" },
		{ "WP_K3", "Skybridge", 185, 82, -124, "WP_K2" },
		{ "WP_K4", "Skybridge", 185, 82, 124, "WP_K2" },
		{ "WP_A1", "DataArchive", 0, 10, -185, "WP_SN,WP_A2,WP_A3" },
		{ "WP_A2", "DataArchive", -77, 10, -185, "WP_A1,WP_A4" },
		{ "WP_A3", "DataArchive", 77, 10, -185, "WP_A1,WP_A5" },
		{ "WP_A4", "DataArchive", -77, 10, -240, "WP_A2,WP_A5" },
		{ "WP_A5", "DataArchive", 77, 10, -240, "WP_A3,WP_A4" },
		{ "WP_R1", "CoolantReservoir", -100, 10, 180, "WP_SS,WP_R3" },
		{ "WP_R2", "CoolantReservoir", 100, 10, 180, "WP_SS,WP_R3" },
		{ "WP_R3", "CoolantReservoir", 0, 6, 200, "WP_R1,WP_R2,WP_R4" },
		{ "WP_R4", "CoolantReservoir", 0, 10, 252, "WP_R3" },
	} do
		local p = part(waypoints, d[1], Vector3.new(1, 1, 1), CFrame.new(d[3], d[4], d[5]), C.Cyan)
		invisibleMarker(p)
		p:SetAttribute("WaypointId", d[1])
		p:SetAttribute("Zone", d[2])
		p:SetAttribute("Links", d[6])
		CollectionService:AddTag(p, "DroneWaypoint")
	end

	local fragments = folder(map, "FragmentSpawns")
	for i, d in {
		{ "CentralCore", -90, 0, 50 }, { "CentralCore", 90, 0, -50 }, { "CentralCore", 30, 0, 90 },
		{ "CentralCore", 60, 0, -60 }, { "CentralCore", 0, 24, 47.5 },
		{ "ResearchYard", -200, 0, -90 }, { "ResearchYard", -200, 0, 90 }, { "ResearchYard", -150, 24, -123 },
		{ "ResearchYard", -255, 0, 0 },
		{ "Skybridge", 190, 72, -130 }, { "Skybridge", 185, 72, 124 }, { "Skybridge", 220, 48, 25 },
		{ "Skybridge", 150, 0, -40 }, { "Skybridge", 200, 24, -129 },
		{ "DataArchive", -110, 24, -203 }, { "DataArchive", 110, 24, -167 }, { "DataArchive", 0, 0, -215 },
		{ "DataArchive", -20, 0, -185 }, { "DataArchive", 77, 0, -240 },
		{ "CoolantReservoir", 0, -10, 230 }, { "CoolantReservoir", -120, 0, 170 },
		{ "CoolantReservoir", 100, 0, 240 }, { "CoolantReservoir", 40, 24, 200 },
		{ "OuterRing", 0, 24, -230 },
	} do
		local p = part(fragments, "FragmentSpawn_" .. i, Vector3.new(1, 1, 1), CFrame.new(d[2], d[3] + 2.5, d[4]), C.Cyan)
		invisibleMarker(p)
		p:SetAttribute("FragmentSpawnId", string.format("FRAG_%02d", i))
		p:SetAttribute("Zone", d[1])
		CollectionService:AddTag(p, "FragmentSpawn")
	end

	local surfaces = folder(map, "PatchSurfaces")
	for _, d in {
		{ "BOUNCE_CORE_1", "BounceSurface", "CentralCore", -78, -18, 6, 6 },
		{ "BOUNCE_CORE_2", "BounceSurface", "CentralCore", 78, 18, 6, 6 },
		{ "BOUNCE_CORE_3", "BounceSurface", "CentralCore", 30, 61, 6, 6 },
		{ "BOUNCE_CORE_4", "BounceSurface", "CentralCore", -62, 30, 6, 6 },
		{ "BOUNCE_YARD_1", "BounceSurface", "ResearchYard", -200, -112, 6, 6 },
		{ "BOUNCE_YARD_2", "BounceSurface", "ResearchYard", -200, 112, 6, 6 },
		{ "BOUNCE_ARCH_1", "BounceSurface", "DataArchive", -77, -165, 6, 6 },
		{ "BOUNCE_ARCH_2", "BounceSurface", "DataArchive", 77, -205, 6, 6 },
		{ "SLIP_RES_W", "SlipSurface", "CoolantReservoir", -112, 180, 8, 12 },
		{ "SLIP_RES_E", "SlipSurface", "CoolantReservoir", 112, 180, 8, 12 },
		{ "SLIP_RES_N1", "SlipSurface", "CoolantReservoir", -50, 147.5, 12, 8 },
		{ "SLIP_RES_N2", "SlipSurface", "CoolantReservoir", 50, 147.5, 12, 8 },
		{ "SLIP_ARCH_W", "SlipSurface", "DataArchive", -77, -185, 10, 8 },
		{ "SLIP_ARCH_E", "SlipSurface", "DataArchive", 77, -185, 10, 8 },
		{ "SLIP_CORE_W", "SlipSurface", "CentralCore", -61, -57, 10, 8 },
		{ "SLIP_CORE_S", "SlipSurface", "CentralCore", -58, 61, 8, 10 },
	} do
		local thick = if d[2] == "BounceSurface" then 0.4 else 0.2
		local p = part(surfaces, d[1], Vector3.new(d[6], thick, d[7]), CFrame.new(d[4], thick / 2, d[5]), if d[2] == "BounceSurface" then C.Bounce else C.Slip)
		p:SetAttribute("SurfaceId", d[1])
		p:SetAttribute("Zone", d[3])
		CollectionService:AddTag(p, d[2])
	end

	local markers = folder(map, "PatchMarkers")
	for _, d in {
		{ "PROP_RES_1", "CoolantReservoir", 85, 170 }, { "PROP_RES_2", "CoolantReservoir", 85, 240 },
		{ "PROP_RES_3", "CoolantReservoir", -60, 238, -10 }, { "PROP_RES_4", "CoolantReservoir", 60, 238, -10 },
		{ "PROP_ARCH_1", "DataArchive", -30, -225 }, { "PROP_ARCH_2", "DataArchive", 30, -225 },
		{ "PROP_YARD_1", "ResearchYard", -235, 62 }, { "PROP_YARD_2", "ResearchYard", -185, 62 },
	} do
		-- d[5]: floor height (the two basin crates rest on the basin floor, inside FLOOD_RES, so
		-- FLOATING_DEBRIS floats them as stepping stones over the water).
		local p = part(markers, d[1], Vector3.new(3, 3, 3), CFrame.new(d[3], (d[5] or 0) + 1.5, d[4]), C.Crate, Enum.Material.DiamondPlate)
		p:SetAttribute("PropId", d[1])
		p:SetAttribute("Zone", d[2])
		CollectionService:AddTag(p, "MagneticProp")
	end
	for _, d in {
		{ "MAGNET_RES_A", "CoolantReservoir", 85, 205 }, { "MAGNET_RES_BASIN", "CoolantReservoir", 0, 238, -10 },
		{ "MAGNET_ARCH", "DataArchive", 0, -225 }, { "MAGNET_YARD", "ResearchYard", -210, 62 },
	} do
		local p = part(markers, d[1], Vector3.new(2, 0.2, 2), CFrame.new(d[3], (d[5] or 0) + 0.1, d[4]), C.Cyan)
		invisibleMarker(p)
		p:SetAttribute("PointId", d[1])
		p:SetAttribute("Zone", d[2])
		CollectionService:AddTag(p, "MagneticPoint")
	end
	local nodePaths = {
		{ "CORE", "CentralCore", { { 15, 0, -90 }, { 25, 0, -90 }, { 35, 0, -90 }, { 45, 0, -90 }, { 55, 0, -90 }, { 65, 0, -90 } } },
		{ "YARD", "ResearchYard", { { -245, 0, 45 }, { -235, 0, 45 }, { -225, 0, 45 }, { -215, 0, 45 }, { -205, 0, 45 }, { -195, 0, 45 } } },
		{ "ARCH", "DataArchive", { { -99, 0, -160 }, { -99, 0, -170 }, { -99, 0, -180 }, { -99, 0, -190 }, { -99, 0, -200 }, { -99, 0, -210 } } },
	}
	for _, path in nodePaths do
		for i, n in path[3] do
			local p = part(markers, string.format("CORRUPT_%s_%d", path[1], i), Vector3.new(6, 0.2, 6), CFrame.new(n[1], n[2] + 0.1, n[3]), C.Violet)
			invisibleMarker(p)
			p:SetAttribute("NodeId", string.format("CORRUPT_%s_%d", path[1], i))
			p:SetAttribute("Zone", path[2])
			p:SetAttribute("Order", i)
			CollectionService:AddTag(p, "CorruptionNode")
		end
	end
	for _, d in {
		{ "FLOOD_CORE", "CentralCore", -70, 70, -70, 70, 0, 2.5 },
		{ "FLOOD_YARD", "ResearchYard", -250, -150, -50, 50, 0, 2.5 },
		{ "FLOOD_RES", "CoolantReservoir", -75, 75, 155, 245, -10, 6 },
	} do
		local p = part(markers, d[1], Vector3.new(d[4] - d[3], 1, d[6] - d[5]), CFrame.new((d[3] + d[4]) / 2, d[7] + 0.5, (d[5] + d[6]) / 2), C.Cyan)
		invisibleMarker(p)
		p:SetAttribute("FloodZoneId", d[1])
		p:SetAttribute("Zone", d[2])
		p:SetAttribute("MaxRise", d[8])
		CollectionService:AddTag(p, "FloodZone")
	end

	-------------------------------------------------------------------------------------------
	-- LOBBY (relocated outside the new arena bounds)
	local CENTER = Vector3.new(0, 160, 420)
	local SIZE, WALL = 48, 5
	part(lobby, "LobbyFloor", Vector3.new(SIZE, 4, SIZE), CFrame.new(CENTER - Vector3.new(0, 2, 0)), C.FloorAlt)
	local half = SIZE / 2
	for _, d in {
		{ "Wall_N", Vector3.new(SIZE, WALL, 1), Vector3.new(0, 0, -half + 0.5) },
		{ "Wall_S", Vector3.new(SIZE, WALL, 1), Vector3.new(0, 0, half - 0.5) },
		{ "Wall_E", Vector3.new(1, WALL, SIZE), Vector3.new(half - 0.5, 0, 0) },
		{ "Wall_W", Vector3.new(1, WALL, SIZE), Vector3.new(-half + 0.5, 0, 0) },
	} do
		local w = part(lobby, d[1], d[2], CFrame.new(CENTER + d[3] + Vector3.new(0, WALL / 2, 0)), C.Cover)
		decorative(part(lobby, d[1] .. "_Trim", Vector3.new(math.max(d[2].X, 0.4), 0.3, math.max(d[2].Z, 0.4)), w.CFrame + Vector3.new(0, WALL / 2 + 0.15, 0), C.Cyan, Enum.Material.Neon))
	end
	for i, o in { Vector3.new(-10, 0, -10), Vector3.new(10, 0, -10), Vector3.new(-10, 0, 10), Vector3.new(10, 0, 10) } do
		local s = Instance.new("SpawnLocation")
		s.Name = "LobbySpawn_" .. i
		s.Anchored = true
		s.Size = Vector3.new(6, 1, 6)
		s.CFrame = CFrame.new(CENTER + o + Vector3.new(0, 0.5, 0))
		s.Color = C.Spawn
		s.Material = Enum.Material.SmoothPlastic
		s.TopSurface = Enum.SurfaceType.Smooth
		s.BottomSurface = Enum.SurfaceType.Smooth
		s.Enabled = true
		s.Neutral = true
		s.AllowTeamChangeOnTouch = false
		s.Duration = 0
		s:SetAttribute("SpawnId", "LOBBY_" .. i)
		CollectionService:AddTag(s, "LobbySpawn")
		s.Parent = lobby
	end
	lobby.Parent = root

	-------------------------------------------------------------------------------------------
	-- VALIDATION (new map only)
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Include
	rays.FilterDescendantsInstances = { map }
	rays.RespectCanCollide = true
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { map }
	overlap.RespectCanCollide = true
	local problems = {}
	local function check(cond: boolean, msg: string)
		if not cond then
			table.insert(problems, msg)
		end
	end
	local function floorAt(x: number, y: number, z: number): (number?, BasePart?)
		local hit = workspace:Raycast(Vector3.new(x, y + 3, z), Vector3.new(0, -8, 0), rays)
		if hit then
			return hit.Position.Y, hit.Instance :: BasePart
		end
		return nil, nil
	end
	local function tagged(tag: string): { Instance }
		local list = {}
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsDescendantOf(map) then
				table.insert(list, inst)
			end
		end
		return list
	end
	-- Floors under spawns (corners), pads (corners), nodes (corners), crates and points.
	local function floorCorners(label: string, p: BasePart, expectTop: number, half: Vector3)
		for _, c in { { 0, 0 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			local x, z = p.Position.X + c[1] * half.X * 0.9, p.Position.Z + c[2] * half.Z * 0.9
			local y, inst = floorAt(x, expectTop + 1, z)
			check(y ~= nil and math.abs((y :: number) - expectTop) < 0.05, `{label}: floor not at {expectTop} under ({x},{z}) (got {y} {inst and inst.Name})`)
		end
	end
	for _, s in tagged("ArenaSpawn") do
		local p = s :: BasePart
		local bottom = p.Position.Y - 0.5
		local saved = p.CanCollide
		p.CanCollide = false
		floorCorners(p.Name, p, bottom, p.Size / 2)
		local _, under = floorAt(p.Position.X, bottom + 1, p.Position.Z)
		check(not (under and CollectionService:HasTag(under, "DecayTile")), `{p.Name}: on a DecayTile`)
		p.CanCollide = saved
		local hits = workspace:GetPartBoundsInBox(p.CFrame + Vector3.new(0, 4, 0), Vector3.new(4, 6, 4), overlap)
		check(#hits == 0, `{p.Name}: headroom blocked by {hits[1] and hits[1].Name}`)
	end
	for _, tag in { "BounceSurface", "SlipSurface" } do
		for _, s in tagged(tag) do
			local p = s :: BasePart
			p.CanCollide = false
			floorCorners(p.Name, p, 0, p.Size / 2)
			p.CanCollide = true
			local hits = workspace:GetPartBoundsInBox(p.CFrame + Vector3.new(0, 3.5, 0), Vector3.new(p.Size.X, 6, p.Size.Z), overlap)
			check(#hits == 0, `{p.Name}: headroom blocked by {hits[1] and hits[1].Name}`)
		end
	end
	for _, s in tagged("CorruptionNode") do
		local p = s :: BasePart
		floorCorners(p.Name, p, p.Position.Y - 0.1, p.Size / 2)
	end
	for _, s in tagged("FragmentSpawn") do
		local p = s :: BasePart
		local y = floorAt(p.Position.X, p.Position.Y - 2.5, p.Position.Z)
		check(y ~= nil and math.abs((y :: number) - (p.Position.Y - 2.5)) < 0.05, `{p.Name}: no floor 2.5 below`)
	end
	for _, s in tagged("SupplyLandingPoint") do
		local p = s :: BasePart
		floorCorners(p.Name, p, p.Position.Y - 0.1, Vector3.new(5, 0, 5))
		for _, c in { { 0, 0 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			local up = workspace:Raycast(p.Position + Vector3.new(c[1] * 4.5, 1, c[2] * 4.5), Vector3.new(0, 160, 0), rays)
			check(up == nil, `{p.Name}: sky blocked by {up and up.Instance.Name}`)
		end
	end
	for _, w in tagged("DroneWaypoint") do
		local a = (w :: BasePart).Position
		for _, id in string.split(tostring(w:GetAttribute("Links")), ",") do
			local other = waypoints:FindFirstChild(id) :: BasePart?
			check(other ~= nil, `{w.Name}: unknown link {id}`)
			if other then
				local hit = workspace:Raycast(a, other.Position - a, rays)
				check(hit == nil, `{w.Name}->{id}: line blocked by {hit and hit.Instance.Name}`)
			end
		end
	end
	-- Crate lanes: floor under crates and a box sweep to the nearest same-zone point.
	local points = tagged("MagneticPoint")
	local lanes = {}
	for _, s in tagged("MagneticProp") do
		local p = s :: BasePart
		p.CanCollide = false
		local floorY = p.Position.Y - p.Size.Y / 2
		floorCorners(p.Name, p, floorY, p.Size / 2)
		local best: BasePart? = nil
		for _, q in points do
			if q:GetAttribute("Zone") == p:GetAttribute("Zone") and (best == nil or ((q :: BasePart).Position - p.Position).Magnitude < ((best :: BasePart).Position - p.Position).Magnitude) then
				best = q :: BasePart
			end
		end
		check(best ~= nil, `{p.Name}: no point in its zone`)
		if best then
			local a, b = Vector2.new(p.Position.X, p.Position.Z), Vector2.new(best.Position.X, best.Position.Z)
			local dest = b + (a - b).Unit * 3.5
			table.insert(lanes, { a = a, b = dest, name = p.Name })
			local steps = math.ceil((dest - a).Magnitude)
			for i = 0, steps do
				local q = a:Lerp(dest, i / steps)
				local hits = workspace:GetPartBoundsInBox(CFrame.new(q.X, floorY + 1.7, q.Y), Vector3.new(3, 3, 3), overlap)
				check(#hits == 0, `{p.Name}: lane blocked by {hits[1] and hits[1].Name}`)
			end
		end
		p.CanCollide = true
	end
	-- Spawn safety (Phase 8A rules): outside flood footprints (3-stud margin) and at least 8 studs
	-- from corruption nodes, bounce/slip pads and crate lanes.
	local function segDist(p: Vector2, a: Vector2, b: Vector2): number
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		return (a + ab * t - p).Magnitude
	end
	for _, s in tagged("ArenaSpawn") do
		local sp = (s :: BasePart).Position
		local p2 = Vector2.new(sp.X, sp.Z)
		for _, f in tagged("FloodZone") do
			local fp = f :: BasePart
			local inside = math.abs(sp.X - fp.Position.X) < fp.Size.X / 2 + 3 and math.abs(sp.Z - fp.Position.Z) < fp.Size.Z / 2 + 3
			check(not inside, `{s.Name}: inside or within 3 studs of {f.Name}`)
		end
		for _, tag in { "CorruptionNode", "BounceSurface", "SlipSurface" } do
			for _, h in tagged(tag) do
				local hp = h :: BasePart
				local d = (Vector2.new(hp.Position.X, hp.Position.Z) - p2).Magnitude - math.max(hp.Size.X, hp.Size.Z) / 2
				check(d >= 8, `{s.Name}: {string.format("%.1f", d)} studs from {h.Name}`)
			end
		end
		for _, lane in lanes do
			local d = segDist(p2, lane.a, lane.b) - 1.5
			check(d >= 8, `{s.Name}: {string.format("%.1f", d)} studs from crate lane {lane.name}`)
		end
	end
	-- Stabilizers: clear of hazards by their interaction radius.
	for _, m in tagged("Stabilizer") do
		local sp = (m :: Model):GetPivot().Position
		local r = tonumber(m:GetAttribute("InteractionRadius")) or 10
		for _, tag in { "CorruptionNode", "BounceSurface", "SlipSurface", "FloodZone" } do
			for _, h in tagged(tag) do
				local hp = h :: BasePart
				local dx = math.max(math.abs(sp.X - hp.Position.X) - hp.Size.X / 2, 0)
				local dz = math.max(math.abs(sp.Z - hp.Position.Z) - hp.Size.Z / 2, 0)
				check(math.sqrt(dx * dx + dz * dz) >= r, `{m.Name}: hazard {h.Name} inside its interaction radius`)
			end
		end
	end
	if #problems > 0 then
		error(table.concat(problems, "\n"), 0)
	end
	root:SetAttribute("ArenaVersion", 2)
end)

if not ok then
	map:Destroy()
	lobby:Destroy()
	oldMap.Parent = root
	oldLobby.Parent = root
	rollback:Destroy()
	error("Phase 8A-1 build failed; the original arena was restored:\n" .. tostring(err), 0)
end

local parts = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return `built Phase 8A-1 arena (ArenaVersion 2): {parts} map parts; old Map/Lobby kept in ServerStorage.{rollback.Name}`

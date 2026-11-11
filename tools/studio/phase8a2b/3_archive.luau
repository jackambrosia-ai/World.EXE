-- WORLD.EXE Phase 8A-2b step 3: Data Archive "Server Canyons" (Architecture.ServerCanyons).
-- ArchiveFloor x -130..130, z -260..-140. Racks (8x24x25) at x +-66/+-88/+-110, z A -215..-190,
-- B -180..-155. RackDeck_NW/NE z -223..-215 (Y 24), ArchiveWalk_S z -154.5..-145.5 (Y 24), Ring_N
-- z -237..-223 (Y 24). SUP_ARCHIVE column x -6..6, z -206..-194 (kept clear to Y 160).
-- * Vault walls to Y 70 on the north, west and east floor edges (outside the floor footprint; the
--   Ring_N passes through arched openings). Collidable BoundaryWall: they face the void.
-- * Ribbed roof: four arched ribs, purlins, an open oculus (Y 76, r 18) around the drop
--   column, roof panels only over the north bay behind the spawns.
-- * Ring_N and ArchiveWalk_S hang from the ribs (yokes, rods, bearers); RackDecks and the walk also
--   rest on columns tucked against the rack faces.
-- * The twelve flat cyan rack strips are hidden; each rack face gets a dark recessed face plate,
--   three segmented light bars, a static monitor; four racks carry a corrupted-data block.
-- * Cable trays at Y 42 (above the bounce apex limit), cooling stacks on the north edge, cornices.
local W = assert(_G.W8A2B, "run 0_lib first")
local C, M = W.C, W.M
local A = "DataArchive"
local d, S, D = W.District("ServerCanyons")
local V = Vector3.new
local map = W.map
local archive = map.DataArchive

-- Vault walls (BoundaryWall: outside the floor, against edges that drop to the void).
local walls = W.Model(S, "VaultWalls", "Atomic")
W.Box(A, walls, "VaultWall_N", V(-131.5, -4, -261.5), V(131.5, 70, -260), C.Navy2, M.Concrete, { role = "BoundaryWall", support = true })
for _, sgn in { -1, 1 } do
	local x0, x1 = 130 * sgn, 131.5 * sgn
	local tag = if sgn < 0 then "W" else "E"
	W.Box(A, walls, "VaultWall_" .. tag .. "1", V(x0, -4, -261.5), V(x1, 70, -238.5), C.Navy1, M.Concrete, { role = "BoundaryWall", support = true })
	W.Box(A, walls, "VaultWall_" .. tag .. "2", V(x0, -4, -221.5), V(x1, 70, -140), C.Navy1, M.Concrete, { role = "BoundaryWall", support = true })
	W.Box(A, walls, "VaultLintel_" .. tag, V(x0, 36, -238.5), V(x1, 70, -221.5), C.Navy2, M.Concrete, { support = true })
	W.Box(A, walls, "Cornice_" .. tag, V(x0 - 0.6 * sgn, 44, -260), V(x0, 45.5, -140), C.SteelLt, M.Metal)
end
W.Box(A, walls, "Cornice_N", V(-130, 44, -260), V(130, 45.5, -259.4), C.SteelLt, M.Metal)

-- Ribs (arched: wall top Y 70 to crown Y 82), purlins, north-bay roof, oculus.
local function ribY(x: number): number
	return 70 + 12 * (1 - math.abs(x) / 131)
end
local roof = W.Model(S, "VaultRoof", "Atomic")
for _, z in { -252, -230, -172, -150 } do
	for _, sgn in { -1, 1 } do
		W.Strut(A, roof, "Rib", V(131 * sgn, 70, z), V(0, 82, z), 1.5, 2.5, C.Steel, M.Metal, { support = true })
	end
end
for _, x in { -60, 60 } do
	W.Box(A, roof, "Purlin", V(x - 0.6, ribY(x) + 1, -252), V(x + 0.6, ribY(x) + 2, -150), C.Steel, M.Metal)
end
W.Box(A, roof, "Ridge", V(-0.6, 83, -252), V(0.6, 84, -218), C.Steel, M.Metal)
W.Box(A, roof, "Ridge", V(-0.6, 83, -182), V(0.6, 84, -150), C.Steel, M.Metal)
for _, sgn in { -1, 1 } do
	W.Strut(A, roof, "RoofPanel_N", V(131 * sgn, 70.5, -246), V(0, 82.5, -246), 30, 1, C.Navy0, M.Metal)
end
for i = 0, 7 do
	local a = i / 8 * math.pi * 2
	local pos = V(math.cos(a) * 18, 76, -200 + math.sin(a) * 18)
	W.P(A, roof, "OculusRing", V(15.2, 1.6, 1.5), CFrame.lookAt(pos, V(0, 76, -200)), C.SteelLt, M.Metal, { support = true })
end
-- Two lamps hung from the ribs (x +-12: off the ARCH spawns' sightlines and the drop column), low
-- enough for their light to reach the aisle floor, including under BLACKOUT.
for _, l in { { 12, 32, -172, C.White, 50, 2.5 }, { -12, 34, -230, C.Cyan, 46, 2.0 } } do
	W.Box(A, roof, "LampRod", V(l[1] - 0.2, l[2] + 0.5, l[3] - 0.2), V(l[1] + 0.2, ribY(l[1]) - 1, l[3] + 0.2), C.SteelLt, M.Metal)
	local lamp = W.Box(A, roof, "ArchiveLamp", V(l[1] - 1, l[2] - 0.5, l[3] - 1), V(l[1] + 1, l[2] + 0.5, l[3] + 1), C.White, M.Neon)
	W.Light(A, lamp, "PointLight", { Color = l[4], Range = l[5], Brightness = l[6] })
end

-- Hangers: Ring_N from rib z -230 (x -100/-30/30/100); ArchiveWalk_S from rib z -150 (x -30/30).
local hang = W.Model(S, "Hangers", "Atomic")
local function hanger(x: number, zRib: number, zA: number, zB: number)
	local top = ribY(x) - 1.3
	W.Box(A, hang, "Yoke", V(x - 0.4, top - 1, zA - 0.3), V(x + 0.4, top, zB + 0.3), C.Steel, M.Metal, { support = true })
	W.Box(A, hang, "HangerRod", V(x - 0.3, 21, zA - 0.3), V(x + 0.3, top - 1, zA), C.SteelLt, M.Metal, { support = true })
	W.Box(A, hang, "HangerRod", V(x - 0.3, 21, zB), V(x + 0.3, top - 1, zB + 0.3), C.SteelLt, M.Metal, { support = true })
	return W.Box(A, hang, "Bearer", V(x - 0.6, 21, zA - 0.3), V(x + 0.6, 22, zB + 0.3), C.Steel, M.Metal, { support = true })
end
for _, x in { -100, -30, 30, 100 } do
	hanger(x, -230, -237.5, -222.5)
end
local entryBearer
for _, x in { -30, 30 } do
	entryBearer = hanger(x, -150, -155, -145)
end
-- Correction 2026-11-11: the eighth Archive light, a low pool at the Archive entrance under the walk.
W.Light(A, entryBearer, "PointLight", { Color = C.White, Range = 30, Brightness = 2 })

-- Columns tucked against the rack faces under the RackDecks and the ArchiveWalk.
for _, x in { -110, -88, -66, 66, 88, 110 } do
	W.Box(A, S, "DeckColumn", V(x - 1, 0, -217), V(x + 1, 22, -215.1), C.Steel, M.Metal, { role = "FloorStructure", support = true })
end
for _, x in { -110, -66, 66, 110 } do
	W.Box(A, S, "WalkColumn", V(x - 1, 0, -154.9), V(x + 1, 22, -153), C.Steel, M.Metal, { role = "FloorStructure", support = true })
end

-- Rack faces: hide the flat strips; recessed plate, segmented light bars, static monitor.
local racks = W.Model(D, "RackFaces", "Default")
local corruptSet = { ["Rack_-88A"] = true, ["Rack_110B"] = true, ["Rack_66A"] = true, ["Rack_-110B"] = true }
local hidden = 0
local monitor
local plates = {}
for _, rack in archive:GetDescendants() do
	local strip = archive:FindFirstChild(rack.Name .. "_Strip", true)
	if rack:IsA("BasePart") and string.match(rack.Name, "^Rack_%-?%d+[AB]$") and strip then
		W.Hide(strip)
		hidden += 1
		local face = strip.Position.X
		local out = if face > rack.Position.X then 1 else -1
		local z0 = rack.Position.Z
		plates[rack.Name] = W.Box(A, racks, "FacePlate", V(face, 2, z0 - 11.5), V(face + 0.2 * out, 21, z0 + 11.5), C.Slate, M.Glass)
		for k, spec in { { -8, 15 }, { 0, 9 }, { 8, 12 } } do
			W.Box(A, racks, "RackLightBar", V(face + 0.2 * out, 4, z0 + spec[1] - 0.15), V(face + 0.35 * out, 4 + spec[2], z0 + spec[1] + 0.15), if k == 2 then C.CyanDim else C.Cyan, M.Neon)
		end
		-- Correction 2026-11-11: thin dim kick strip at the base of each rack face (aisle edge cue that
		-- stays readable under BLACKOUT; 0.3 x 0.3 cross-section).
		W.Box(A, racks, "RackKickStrip", V(face, 0, z0 - 11.5), V(face + 0.3 * out, 0.3, z0 + 11.5), C.CyanDim, M.Neon)
		if string.sub(rack.Name, -1) == "B" then
			-- South end of the B row (faces the core entrance and the walk).
			local zs = z0 + rack.Size.Z / 2
			W.Box(A, racks, "RackEndStrip", V(rack.Position.X - 4, 0, zs), V(rack.Position.X + 4, 0.3, zs + 0.3), C.CyanDim, M.Neon)
		end
		monitor = W.Box(A, racks, "StaticMonitor", V(face + 0.2 * out, 16.5, z0 - 6), V(face + 0.45 * out, 19.5, z0 - 2), C.Static, M.Glass)
		if corruptSet[rack.Name] then
			W.Box(A, racks, "CorruptBlock", V(face + 0.45 * out, 17.2, z0 - 5.2), V(face + 0.6 * out, 17.8, z0 - 4), C.Magenta, M.Neon)
		end
	end
end
assert(hidden == 12, "expected 12 rack strips, found " .. hidden)
W.Light(A, monitor, "PointLight", { Color = C.Magenta, Range = 8, Brightness = 0.6 })
-- Aisle lights at mid-rack height (one per aisle, alternating rows) so the aisle floors stay
-- readable, including under BLACKOUT (lights at tray height did not reach the floor).
for _, n in { "Rack_-110A", "Rack_-88B", "Rack_88A", "Rack_110B" } do
	W.Light(A, plates[n], "PointLight", { Color = C.Cyan, Range = 26, Brightness = 2.4 })
end
-- Correction 2026-11-11: edge strips along both sides of the two Archive ramps (decorative, on the
-- ramp top surface; the ramps themselves are unchanged).
for _, n in { "ArchiveRamp_W", "ArchiveRamp_E" } do
	local r = archive:FindFirstChild(n, true)
	for _, sd in { -1, 1 } do
		W.P(A, racks, "RampEdgeStrip", V(0.3, 0.15, r.Size.Z - 1), r.CFrame * CFrame.new(sd * (r.Size.X / 2 - 0.25), r.Size.Y / 2 + 0.075, 0), C.CyanDim, M.Neon)
	end
end

-- Cable trays (Y 42, above the bounce apex limit of 40).
local trays = W.Model(D, "CableTrays", "Default")
for _, x in { -99, -77, 77, 99 } do
	W.Box(A, trays, "CableTray", V(x - 1, 42, -255), V(x + 1, 42.6, -150), C.Charcoal, M.DiamondPlate)
end
W.Box(A, trays, "CableTray", V(-125, 42, -246), V(125, 42.6, -244), C.Charcoal, M.DiamondPlate)

-- Cooling stacks on the north edge (collidable, against the floor edge).
for _, x in { -118, -40, 40, 118 } do
	W.Cyl(A, S, "CoolingStack", V(x, 35, -256.9), 70, 6, C.ConcreteDk, M.Concrete, { role = "FloorStructure" })
	W.Cyl(A, S, "StackBand", V(x, 52, -256.9), 1.2, 6.6, C.SteelLt, M.Metal)
end

local c = W.counts[A]
return string.format("ServerCanyons: %d parts, %d collidable, %d lights, %d strips hidden", c.parts, c.collide, c.lights, hidden)

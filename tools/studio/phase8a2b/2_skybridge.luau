-- WORLD.EXE Phase 8A-2b step 2: Skybridge "Elevated Control Facility" (Architecture.ControlFacility).
-- SkyDeck x 160..230, z -40..40, top Y 48. Stepping blocks x 180..190 at z +-47..+-103, islands
-- (185, 72, +-124). SUP_SKY column x 189..201, z -31..-19; SUP_ISLAND column x 179..191, z -130..-118.
-- * Two lattice command spires on the deck's east corners (tops Y 110 and Y 92), legs within
--   4 studs of the deck edges.
-- * A glass control room raised between them (floor Y 60, open west side facing play), on two
--   slender edge posts and girders to the spires; the deck below stays clear.
-- * Overhead trusses (Y 110-116, x 193) north and south carry hanger rods to every stepping block;
--   their inner ends hang from booms off the spires, their outer ends rest on pylons from the shaft.
-- * Beam cables from the spire masts to the relay islands; thruster nacelles under the islands;
--   counterweight and knee braces under the deck; pylons continue the deck pillars down to the shaft floor.
local W = assert(_G.W8A2B, "run 0_lib first")
local C, M = W.C, W.M
local A = "Skybridge"
local d, S, D = W.District("ControlFacility")
local V = Vector3.new

-- Command spires.
local spires = {}
for _, sp in { { name = "SpireNorth", z = -37, legTop = 98, levels = { 62, 76, 90 }, capTop = 104, top = 110 }, { name = "SpireSouth", z = 37, legTop = 80, levels = { 62, 74 }, capTop = 86, top = 92 } } do
	local m = W.Model(S, sp.name, "Atomic")
	local xs, zs = { 225.8, 229.2 }, { sp.z - 1.8, sp.z + 1.8 }
	for _, x in xs do
		for _, z in zs do
			W.Box(A, m, "SpireLeg", V(x - 0.6, 48, z - 0.6), V(x + 0.6, sp.legTop, z + 0.6), C.Silver, M.Metal, { role = "FloorStructure", support = true })
			W.Strut(A, m, "SpireCap", V(x, sp.legTop, z), V(227.5, sp.capTop, sp.z), 0.6, 0.6, C.Silver, M.Metal)
		end
	end
	for _, y in sp.levels do
		for _, x in xs do
			W.Box(A, m, "SpireTie", V(x - 0.35, y - 0.35, zs[1]), V(x + 0.35, y + 0.35, zs[2]), C.SteelLt, M.Metal)
		end
	end
	local prev = 48
	for k, y in sp.levels do
		if k > 2 then
			break
		end
		local z = if k % 2 == 1 then zs[1] else zs[2]
		W.Strut(A, m, "SpireBrace", V(xs[1], prev, z), V(xs[2], y, z), 0.4, 0.4, C.SteelLt, M.Metal)
		prev = y
	end
	local mast = W.Box(A, m, "SpireMast", V(227.2, sp.capTop, sp.z - 0.3), V(227.8, sp.top, sp.z + 0.3), C.SteelLt, M.Metal)
	local beacon = W.P(A, m, "SpireBeacon", V(1.2, 1.2, 1.2), CFrame.new(227.5, sp.top + 0.6, sp.z), C.Violet, M.Neon, { shape = "Ball" })
	W.Light(A, beacon, "PointLight", { Color = C.Violet, Range = 18, Brightness = 1.4 })
	spires[sp.name] = { mast = mast, legTop = sp.legTop, z = sp.z }
end

-- Raised control room.
local room = W.Model(S, "ControlRoom", "Atomic")
W.Box(A, room, "RoomFloor", V(218, 60, -14), V(230, 61, 14), C.Steel, M.DiamondPlate, { support = true })
W.Box(A, room, "RoomRoof", V(217, 69, -15), V(231, 70, 15), C.Silver, M.Metal)
for _, sgn in { -1, 1 } do
	W.Box(A, room, "RoomGlass", V(218, 61, 14 * sgn - 0.2), V(230, 69, 14 * sgn + 0.2), C.Glass, M.Glass, { transparency = 0.5 })
	W.Box(A, room, "RoomPost", V(228.5, 48, 13 * sgn - 0.5), V(229.5, 60, 13 * sgn + 0.5), C.Silver, M.Metal, { role = "FloorStructure", support = true })
	W.Box(A, room, "RoomGirder", V(226.5, 59.4, 14 * sgn), V(228.5, 61, 35.2 * sgn), C.Steel, M.Metal, { support = true })
	W.Box(A, room, "Console", V(226, 61, 2 * sgn), V(229, 63.5, 10 * sgn), C.Steel, M.Metal)
	W.Box(A, room, "DisplayRecess", V(227.2, 64, 3 * sgn), V(227.6, 68, 9 * sgn), C.Slate, M.Glass)
end
local roomLight = W.Box(A, room, "RoomGlassBack", V(229.6, 61, -14), V(230, 69, 14), C.Glass, M.Glass, { transparency = 0.5 })
for k, col in { C.Violet, C.Cyan, C.Magenta } do
	local z = -7 + k * 2.6
	W.Box(A, room, "SignalBar", V(227.0, 64.4, z), V(227.15, 64.4 + k * 0.8, z + 0.6), col, M.Neon)
end
W.Light(A, roomLight, "PointLight", { Color = C.White, Range = 16, Brightness = 1.1 })

-- Overhead trusses, booms, end pylons and stepping-block hangers.
for _, sgn in { -1, 1 } do
	local tag = if sgn < 0 then "N" else "S"
	local t = W.Model(S, "Truss_" .. tag, "Atomic")
	W.Box(A, t, "TrussTop", V(192, 114.5, 44 * sgn), V(194, 116, 145 * sgn), C.Silver, M.Metal, { support = true })
	W.Box(A, t, "TrussBottom", V(192.2, 110, 44 * sgn), V(193.8, 111.5, 145 * sgn), C.SteelLt, M.Metal, { support = true })
	for _, z in { 60, 92, 124 } do
		W.Box(A, t, "TrussPost", V(192.6, 111.5, z * sgn - 0.4), V(193.4, 114.5, z * sgn + 0.4), C.SteelLt, M.Metal)
	end
	local sp = spires[if sgn < 0 then "SpireNorth" else "SpireSouth"]
	W.Strut(A, t, "Boom", V(227.5, sp.legTop, sp.z), V(193, 110.8, 44 * sgn), 1.2, 1.2, C.Silver, M.Metal, { support = true })
	W.Box(A, t, "TrussPylon", V(192, -90, 143 * sgn), V(194, 110, 145 * sgn), C.Steel, M.Metal, { support = true })
	for i = 1, 5 do
		local z = (47 + 14 * (i - 1)) * sgn
		local top = 52 + 4 * (i - 1)
		W.Box(A, t, "StepHanger", V(190.1, top - 1, z - 0.25), V(190.6, 110, z + 0.25), C.SteelLt, M.Metal, { support = true })
	end
	-- Relay island: anchor plates, Beam cables to the spire mast, thruster nacelles.
	local iz = 124 * sgn
	for _, dz in { -8, 8 } do
		local plate = W.Box(A, D, "CableAnchor", V(197.05, 69, iz + dz - 1), V(198.05, 71, iz + dz + 1), C.Steel, M.Metal, { support = true })
		W.Beam(sp.mast, V(0, sp.mast.Size.Y / 2, 0), plate, V(0.5, 0, 0), C.Silver, 0.25, 0.1)
	end
	for _, x in { 179, 191 } do
		W.P(A, D, "Nacelle", V(10, 3, 3), CFrame.new(x, 66, iz) * CFrame.Angles(0, math.rad(90), 0), C.Steel, M.Metal, { shape = "Cylinder" })
		local glow = W.P(A, D, "NacelleGlow", V(0.3, 2.4, 2.4), CFrame.new(x, 66, iz - 5.2 * sgn) * CFrame.Angles(0, math.rad(90), 0), C.Violet, M.Neon, { shape = "Cylinder" })
		if x == 179 then
			W.Light(A, glow, "PointLight", { Color = C.Violet, Range = 10, Brightness = 1 })
		end
	end
end

-- Counterweight under the deck and the deck pillars continued to the shaft floor.
W.Box(A, S, "Counterweight", V(172, 30, -8), V(188, 38, 8), C.Charcoal, M.Concrete)
for _, x in { 176, 184 } do
	W.Box(A, S, "CounterweightRod", V(x - 0.3, 38, -0.3), V(x + 0.3, 44, 0.3), C.SteelLt, M.Metal)
end
for _, sgn in { -1, 1 } do
	W.Strut(A, S, "DeckKneeBrace", V(165, 30, 35 * sgn), V(161, 43.9, 10 * sgn), 0.8, 0.8, C.Steel, M.Metal, { support = true })
end
for _, x in { 165, 195 } do
	for _, z in { -35, 35 } do
		W.Box(A, S, "DeckPylon", V(x - 1.5, -90, z - 1.5), V(x + 1.5, -4, z + 1.5), C.Steel, M.Metal, { support = true })
	end
end

local c = W.counts[A]
return string.format("ControlFacility: %d parts, %d collidable, %d lights, beams %d", c.parts, c.collide, c.lights, W.beams or 0)

-- WORLD.EXE Phase 8A-2a builder, step 2: Central Reactor ("Simulation Core").
-- Keeps the gameplay ReactorDrum (Y 0..12, collidable). Moves the 8A-1 thin shaft, shell, rings and
-- cap into the rollback store. Builds: containment cradle, glass containment column with a cyan
-- energy core (Y 15..172), three tapering coil rings (Y 50/95/140, violet only on the inner face)
-- with support arms, four lattice buttresses from collidable plinths on the mezzanine inner corners
-- to the middle coil, two service galleries, an emitter crown to Y 190 and a beam to the ceiling hub.
local W = assert(_G.W8A2A, "run 0_lib first")
local C, M, P, Strut = W.C, W.M, W.P, W.Strut
local A = "Reactor"
local core = W.map:WaitForChild("CentralCore")

for _, name in { "ReactorShaft", "ReactorShell", "ReactorRing_1", "ReactorRing_2", "ReactorRing_3", "ReactorCap" } do
	local p = core:FindFirstChild(name)
	assert(p, "missing " .. name)
	W.Remove(p)
end

local coreFolder = W.arch:FindFirstChild("CentralCore") or Instance.new("Folder")
coreFolder.Name = "CentralCore"
coreFolder.Parent = W.arch
W.coreFolder = coreFolder
local sil = W.Model(coreFolder, "ReactorSilhouette", "Persistent")
local struct = W.Model(coreFolder, "ReactorStructure", "Atomic")

local VERT = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> vertical
local function cyl(parent, name, y0: number, y1: number, d: number, color, mat, opts)
	return P(A, parent, name, Vector3.new(y1 - y0, d, d), CFrame.new(0, (y0 + y1) / 2, 0) * VERT, color, mat, opts)
end

-- Cradle on top of the drum.
cyl(struct, "DrumCollar", 12, 15, 32, C.Steel, M.Metal)
for i = 0, 7 do
	local a = i * math.pi / 4 + math.pi / 8
	local d = Vector3.new(math.cos(a), 0, math.sin(a))
	Strut(A, struct, "CradleRib_" .. (i + 1), d * 15 + Vector3.new(0, 13, 0), d * 11 + Vector3.new(0, 37, 0), 3, 4, C.Navy2, M.Metal)
end
cyl(struct, "CradleCollar", 36, 39, 25, C.SteelLt, M.Metal)

-- Containment column + energy core (the brightest element).
cyl(sil, "ContainmentColumn", 15, 170, 18, C.Glass, M.Glass, { transparency = 0.45 })
local energy = cyl(sil, "EnergyCore", 14, 172, 6, C.Cyan, M.Neon)
W.Light(A, energy, "PointLight", { Color = C.Cyan, Range = 60, Brightness = 2.5, Shadows = true })

-- Coil rings.
local rings = {
	{ y = 50, r = 24, h = 6, depth = 8 },
	{ y = 95, r = 20, h = 5, depth = 7 },
	{ y = 140, r = 16, h = 4, depth = 6 },
}
for k, ring in rings do
	local seg = 2 * math.pi * ring.r / 16 * 1.04
	W.Ring(A, sil, "Coil" .. k, Vector3.new(0, ring.y, 0), ring.r, 16, Vector3.new(seg, ring.h, ring.depth), if k == 2 then C.Steel else C.Navy2, M.Metal)
	local inner = ring.r - ring.depth / 2 - 0.3
	local windings = W.Ring(A, sil, "Coil" .. k .. "Winding", Vector3.new(0, ring.y, 0), inner, 4, Vector3.new(4, ring.h - 1.5, 0.6), C.Violet, M.Neon, nil, math.pi / 16)
	W.Light(A, windings[1], "PointLight", { Color = C.Violet, Range = ring.r + 4, Brightness = 1.6, Shadows = false })
	for j = 0, 3 do
		local a = j * math.pi / 2 + math.pi / 4
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		Strut(A, struct, "Coil" .. k .. "Arm_" .. (j + 1), d * 9.5 + Vector3.new(0, ring.y, 0), d * (ring.r - ring.depth / 2) + Vector3.new(0, ring.y, 0), 2, 2, C.Steel, M.Metal)
	end
end

-- Four lattice buttresses (diagonals) from collidable plinths on the mezzanine inner corners
-- (deck top Y 24) to the middle coil (Y 95).
for i, sgn in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
	local foot = Vector3.new(sgn[1] * 43, 28, sgn[2] * 43)
	P(A, struct, "ButtressPlinth_" .. i, Vector3.new(5, 4, 5), CFrame.new(foot - Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(45), 0), C.ConcreteDk, M.Concrete, { collide = true })
	local dir = Vector3.new(sgn[1], 0, sgn[2]).Unit
	local head = dir * 20 + Vector3.new(0, 92, 0)
	local side = Vector3.new(-dir.Z, 0, dir.X) * 2.2
	Strut(A, struct, "ButtressMain_" .. i, foot + Vector3.new(0, 0.5, 0), head, 3.5, 5, C.Navy2, M.Metal, { shadow = true })
	Strut(A, struct, "ButtressChord_" .. i, foot + side * 1.2 + Vector3.new(0, 5, 0) - dir * 2, head + side - Vector3.new(0, 6, 0) + dir * 2, 1.6, 1.6, C.Steel, M.Metal)
	for t = 1, 3 do
		local f = t / 4
		local a = (foot + Vector3.new(0, 0.5, 0)):Lerp(head, f)
		local b = (foot + side * 1.2 + Vector3.new(0, 5, 0) - dir * 2):Lerp(head + side - Vector3.new(0, 6, 0) + dir * 2, f + 0.08)
		Strut(A, struct, "ButtressTie_" .. i .. "_" .. t, a, b, 1, 1, C.SteelLt, M.Metal)
	end
end

-- Service galleries (decorative, above all reachable heights).
for _, y in { 60, 120 } do
	W.Ring(A, struct, "Gallery" .. y, Vector3.new(0, y, 0), 13, 8, Vector3.new(10.8, 0.8, 5), C.Steel, M.DiamondPlate)
end

-- Emitter crown (Y 170..190) and the beam to the ceiling hub.
cyl(sil, "CrownCollar", 170, 174, 30, C.Steel, M.Metal)
for i = 0, 7 do
	local a = i * math.pi / 4
	local d = Vector3.new(math.cos(a), 0, math.sin(a))
	local base = d * 12 + Vector3.new(0, 173, 0)
	local tip = d * 15 + Vector3.new(0, 190, 0)
	Strut(A, sil, "CrownFin_" .. (i + 1), base, tip, 1.5, 7, C.Navy2, M.Metal)
end
cyl(sil, "CrownCap", 187, 189, 14, C.SteelLt, M.Metal)
local emitter = cyl(sil, "CrownEmitter", 189, 190, 6, C.Cyan, M.Neon)
W.Light(A, emitter, "PointLight", { Color = C.Cyan, Range = 30, Brightness = 1.5, Shadows = false })
if W.hubCore then
	W.Beam(emitter, Vector3.new(0, 0, 0), W.hubCore, Vector3.new(0, 0, 0), C.Cyan, 1.4, 0.35, 1)
end

-- Two floor uplights washing the cradle and column (flush fixtures, decorative).
for i, pos in { Vector3.new(26, 0.25, 26), Vector3.new(-26, 0.25, -26) } do
	local fx = P(A, struct, "Uplight_" .. i, Vector3.new(2, 0.5, 2), CFrame.new(pos), C.Navy0, M.Metal)
	W.Light(A, fx, "SpotLight", { Face = Enum.NormalId.Top, Angle = 35, Range = 60, Brightness = 2, Color = C.Warm, Shadows = false })
end

local c = W.count(A)
return string.format("reactor built: parts=%d collide=%d lights=%d shadows=%d beams=%d", c.parts, c.collide, c.lights, c.shadows, W.beams or 0)

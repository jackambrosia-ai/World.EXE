-- WORLD.EXE Phase 8A-2b step 5: Outer Ring "Transit Ring" (Architecture.TransitRing), shared
-- supports (Architecture.SharedSupports) and void-edge rails.
-- Ring: Ring_N/S z +-(223..237), Ring_W/E x +-(223..237), deck Y 22-24.
-- * Box-girder underside (two webs, Y 18-22) wherever the ring spans the void.
-- * Pylons to the shaft floor (Y -90) where the ring crosses the void (every ~60 studs, corners).
--   Over districts the ring is carried by the hangar frames (yard), vault ribs (archive), pump
--   towers and four rim columns (reservoir).
-- * Five signal arches at the district entries (N archive west portal x -150, S reservoir, W yard, E +-150 skybridge):
--   posts outside the deck edges, lintel above head height, dark sign with a directional chevron.
-- * Rails: long single-part EdgeRails (1.2 high, jumpable) only where an edge drops to the void.
--   An edge point counts as a drop-down (no rail) when any existing collidable floor lies below it
--   within 40 studs, or a floor/ramp/wall continues at or above that level. Applied to the four
--   ring segments and the reservoir rims.
-- * Shared supports: girders and pylons under the T0 slabs (yard, archive, sky base, rims, spokes)
--   and pylons under the sky landings. All decorative.
local W = assert(_G.W8A2B, "run 0_lib first")
local C, M = W.C, W.M
local V = Vector3.new
local map = W.map

local _, RS, RD = W.District("TransitRing")
local AR = "OuterRing"

-- Box girders.
-- Only where the ring crosses the void: over the yard, archive and reservoir the deck is carried by
-- the hangar frames, vault ribs, pump towers and rim columns, and a girder there would hide the
-- reactor from the district spawns (found by 6_audit: YARD_1/YARD_3 strict AC2).
local RUNS = { { -237, -130 }, { 130, 237 } }
for _, sgn in { -1, 1 } do
	for _, off in { 1.5, 12.5 } do
		local z = sgn * 237 + (if sgn < 0 then off else -off)
		local x = sgn * 237 + (if sgn < 0 then off else -off)
		for _, r in RUNS do
			W.Box(AR, RS, "BoxGirder", V(r[1], 18, z - 0.4), V(r[2], 22, z + 0.4), C.Steel, M.Metal, { support = true })
			W.Box(AR, RS, "BoxGirder", V(x - 0.4, 18, math.max(r[1], -223)), V(x + 0.4, 22, math.min(r[2], 223)), C.Steel, M.Metal, { support = true })
		end
		if sgn > 0 then
			W.Box(AR, RS, "BoxGirder", V(x - 0.4, 18, -130), V(x + 0.4, 22, 130), C.Steel, M.Metal, { support = true })
		end
	end
end

-- Pylons where the ring crosses the void.
local pylons = W.Model(RS, "Pylons", "Atomic")
local function pylon(x: number, z: number)
	W.Box(AR, pylons, "RingPylon", V(x - 1.5, -90, z - 1.5), V(x + 1.5, 18, z + 1.5), C.Steel, M.Metal, { support = true })
end
for _, z in { -210, -170, -95, -35, 0, 35, 95, 170, 210 } do
	pylon(230, z)
end
for _, s in { -1, 1 } do
	for _, x in { 160, 205 } do
		pylon(x * s, -230)
		pylon(x * s, 230)
	end
	for _, z in { 165, 205 } do
		pylon(-230, z * s)
	end
end
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		pylon(230 * sx, 230 * sz)
	end
end

-- Rim columns under Ring_S (collidable, at the rim edges).
for _, x in { -127, -77, 77, 127 } do
	W.Box(AR, RS, "RimColumn", V(x - 1, 0, 229), V(x + 1, 18, 231), C.Steel, M.Metal, { role = "FloorStructure", support = true })
end

-- Signal arches. axis "x": the deck runs along x (N/S segments); "z": along z (W/E segments).
local arches = W.Model(RD, "SignalArches", "Default")
local function arch(name: string, center: Vector3, axis: string, dir: number)
	local across = if axis == "x" then V(0, 0, 1) else V(1, 0, 0)
	local along = if axis == "x" then V(1, 0, 0) else V(0, 0, 1)
	for _, s in { -1, 1 } do
		local p = center + across * (8 * s)
		W.Box(AR, arches, name .. "_Post", p - across * 0.4 - along * 0.6 + V(0, -10, 0), p + across * 0.4 + along * 0.6 + V(0, 16, 0), C.SteelLt, M.Metal)
	end
	local l0 = center + V(0, 14, 0)
	W.Box(AR, arches, name .. "_Lintel", l0 - across * 8.4 - along * 0.8 - V(0, 1.5, 0), l0 + across * 8.4 + along * 0.8 + V(0, 1.5, 0), C.Steel, M.Metal)
	local sign = W.Box(AR, arches, name .. "_Sign", l0 - across * 4 - along * 0.9 - V(0, 1.2, 0), l0 + across * 4 + along * 0.9 + V(0, 1.2, 0), C.Slate, M.Glass)
	-- Chevron pointing along the ring (dir): two short neon bars on each sign face.
	for _, f in { -1, 1 } do
		local face = l0 + along * (0.95 * f)
		local tip = face + across * (1.2 * dir)
		W.Strut(AR, arches, name .. "_Chevron", tip, face + across * (-0.4 * dir) + V(0, 0.9, 0), 0.15, 0.2, C.Cyan, M.Neon)
		W.Strut(AR, arches, name .. "_Chevron", tip, face + across * (-0.4 * dir) - V(0, 0.9, 0), 0.15, 0.2, C.Cyan, M.Neon)
	end
	W.Light(AR, sign, "PointLight", { Color = C.CyanDim, Range = 12, Brightness = 0.7 })
end
-- The arch posts stand just outside the deck edges (deck 14 wide: edges at +-7 from the centreline).
arch("ArchNorth", V(-150, 24, -230), "x", 1) -- west of the archive vault opening, clear of ARCH_1
arch("ArchSouth", V(0, 24, 230), "x", -1)
arch("ArchWest", V(-230, 24, 0), "z", -1)
arch("ArchEastN", V(230, 24, -150), "z", 1)
arch("ArchEastS", V(230, 24, 150), "z", 1)

-- Void-edge rails.
local existing = {}
for _, p in map:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide and p:GetAttribute("Arch8A2B") == nil and p:GetAttribute("Arch8A2A") == nil then
		table.insert(existing, p)
	end
end
local newSolid = {}
for _, p in W.newParts do
	if p.CanCollide then
		table.insert(newSolid, p)
	end
end
local function aabb(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size / 2
	local r = cf - cf.Position
	local ex = V(math.abs(r.XVector.X) * s.X + math.abs(r.YVector.X) * s.Y + math.abs(r.ZVector.X) * s.Z, math.abs(r.XVector.Y) * s.X + math.abs(r.YVector.Y) * s.Y + math.abs(r.ZVector.Y) * s.Z, math.abs(r.XVector.Z) * s.X + math.abs(r.YVector.Z) * s.Y + math.abs(r.ZVector.Z) * s.Z)
	return cf.Position - ex, cf.Position + ex
end
local function covered(floor: BasePart, pt: Vector3, inside: Vector3, top: number): boolean
	for _, p in existing do
		if p ~= floor then
			local a, b = aabb(p)
			if pt.X >= a.X and pt.X <= b.X and pt.Z >= a.Z and pt.Z <= b.Z and b.Y >= top - 40 and a.Y <= top + 6 then
				return true
			end
		end
	end
	for _, p in newSolid do
		local a, b = aabb(p)
		local hitOut = pt.X >= a.X and pt.X <= b.X and pt.Z >= a.Z and pt.Z <= b.Z and p:GetAttribute("BoundaryWall")
		local hitIn = inside.X >= a.X - 0.5 and inside.X <= b.X + 0.5 and inside.Z >= a.Z - 0.5 and inside.Z <= b.Z + 0.5 and a.Y <= top + 2 and b.Y >= top
		if hitOut or hitIn then
			return true
		end
	end
	return false
end
local railCount = {}
local function rails(floor: BasePart, area: string, parent: Instance)
	local a, b = aabb(floor)
	local top = b.Y
	local edges = {
		{ n = V(0, 0, -1), from = V(a.X, top, a.Z), to = V(b.X, top, a.Z) },
		{ n = V(0, 0, 1), from = V(a.X, top, b.Z), to = V(b.X, top, b.Z) },
		{ n = V(-1, 0, 0), from = V(a.X, top, a.Z), to = V(a.X, top, b.Z) },
		{ n = V(1, 0, 0), from = V(b.X, top, a.Z), to = V(b.X, top, b.Z) },
	}
	for _, e in edges do
		local len = (e.to - e.from).Magnitude
		local dir = (e.to - e.from).Unit
		local runStart, last = nil, nil
		local function flush()
			if runStart and last and (last - runStart) >= 6 then
				local p0 = e.from + dir * math.max(runStart - 1, 0.5)
				local p1 = e.from + dir * math.min(last + 1, len - 0.5)
				local lo = p0 - e.n * 0.4
				local hi = p1 + V(0, 1.2, 0)
				W.Box(area, parent, "EdgeRail", lo, hi, C.SteelLt, M.Metal, { role = "EdgeRail" })
				railCount[area] = (railCount[area] or 0) + 1
			end
			runStart, last = nil, nil
		end
		local t = 1
		while t <= len - 1 do
			local edgePt = e.from + dir * t
			local out = edgePt + e.n * 1.0
			local inside = edgePt - e.n * 0.5
			if covered(floor, out, inside, top) then
				flush()
			else
				runStart = runStart or t
				last = t
			end
			t += 2
		end
		flush()
	end
end
local ringRails = W.Model(RS, "Rails", "Default")
for _, n in { "Ring_N", "Ring_S", "Ring_W", "Ring_E" } do
	rails(map.OuterRing[n], AR, ringRails)
end
local station = W.arch:FindFirstChild("PumpStation")
local rimRails = W.Model(station, "RimRails", "Default")
for _, n in { "Rim_N", "Rim_S", "Rim_W", "Rim_E" } do
	rails(map.CoolantReservoir[n], "CoolantReservoir", rimRails)
end

-- Shared supports (decorative).
local _, SS = W.District("SharedSupports")
local AS = "SharedSupports"
local function spy(x: number, z: number, topY: number)
	W.Box(AS, SS, "SupportPylon", V(x - 1.5, -90, z - 1.5), V(x + 1.5, topY, z + 1.5), C.Steel, M.Metal, { support = true })
end
local function girderX(x0: number, x1: number, z: number)
	W.Box(AS, SS, "UnderGirder", V(x0, -8, z - 1), V(x1, -4, z + 1), C.Steel, M.Metal, { support = true })
end
local function girderZ(z0: number, z1: number, x: number)
	W.Box(AS, SS, "UnderGirder", V(x - 1, -8, z0), V(x + 1, -4, z1), C.Steel, M.Metal, { support = true })
end
-- Research Yard (x -260..-140, z -130..130).
for _, z in { -90, 0, 90 } do
	girderX(-259, -141, z)
end
for _, x in { -255, -145 } do
	for _, z in { -125, 0, 125 } do
		spy(x, z, -4)
	end
end
-- Data Archive (x -130..130, z -260..-140).
for _, z in { -250, -200, -150 } do
	girderX(-129, 129, z)
end
for _, x in { -125, 0, 125 } do
	spy(x, -145, -4)
end
spy(-125, -255, -4)
spy(125, -255, -4)
-- Sky base (x 140..200, z -130..130) and the sky landings (Y 22).
for _, x in { 145, 195 } do
	girderZ(-129, 129, x)
	spy(x, -125, -4)
	spy(x, 125, -4)
end
for _, sgn in { -1, 1 } do
	spy(155, 137 * sgn, 22)
	spy(210, 137 * sgn, 22)
end
-- Reservoir rims and basin.
girderX(-129, 129, 148)
girderX(-129, 129, 252)
for _, x in { -125, 125 } do
	spy(x, 148, -4)
	spy(x, 252, -4)
end
spy(-50, 200, -14)
spy(50, 200, -14)
-- Spokes.
for _, p in { V(-120, 0, 0), V(120, 0, 0), V(0, 0, -120), V(0, 0, 120) } do
	spy(p.X, p.Z, -4)
end

local out = {}
for area, c in W.counts do
	table.insert(out, string.format("%s %d/%d/%d", area, c.parts, c.collide, c.lights))
end
table.sort(out)
return "rails: ring " .. (railCount.OuterRing or 0) .. ", rims " .. (railCount.CoolantReservoir or 0) .. " | " .. table.concat(out, "; ")

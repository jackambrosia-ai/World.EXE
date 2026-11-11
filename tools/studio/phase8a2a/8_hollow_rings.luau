-- WORLD.EXE Phase 8A-2a review-correction round 2 (Studio EDIT mode), after 7_correction.
-- Replaces the solid reactor discs from 7_correction with genuinely hollow, parts-only rings:
--   * CoilBand1..3 / CoilViolet1..3 (solid cylinders) -> segmented annular coils
--     (18 / 16 / 14 tangential segments, 6 deep, open interiors) with narrow violet neon trims on
--     the outer face of every other segment (1.0 x 0.3 strips, dashed "windings"); the violet coil
--     lights are re-hosted on a trim. Four radial arms per coil tie each ring to the column, so no
--     ring floats.
--   * GalleryRing60/120 (transparent solid discs) -> open service-gallery rings: 8 deck segments
--     each, between the column (r 13) and r 19, leaving the column visible above and below.
-- Decorative only (no collision, query, touch or shadow). The 4 collidable buttress plinths, the
-- gameplay ReactorDrum and every gameplay part are untouched. Removed parts move to
-- ServerStorage.WORLD_EXE_Rollback8A2A.CorrectionRemoved. Central Core stays <= 320 parts.
local ServerStorage = game:GetService("ServerStorage")
local root = workspace:WaitForChild("WORLD_EXE")
local map = root.Map
assert(map:GetAttribute("Correction8A2A") ~= nil, "run 7_correction first")
assert(map:GetAttribute("Correction8A2A_R2") == nil, "round 2 already applied")
local removedStore = ServerStorage:WaitForChild("WORLD_EXE_Rollback8A2A"):WaitForChild("CorrectionRemoved")
local core = map.Architecture.CentralCore
local sil, struct = core.ReactorSilhouette, core.ReactorStructure
local M = Enum.Material
local C = {
	Gunmetal = Color3.fromRGB(44, 48, 62),
	GunmetalLt = Color3.fromRGB(62, 68, 86),
	Steel = Color3.fromRGB(58, 68, 100),
	SteelLt = Color3.fromRGB(110, 118, 140),
	Violet = Color3.fromRGB(138, 43, 226),
}
local log = { removed = 0, added = 0 }

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Transparency = transparency or 0
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Arch8A2A", "Reactor")
	p:SetAttribute("Correction8A2A", true)
	p.Parent = parent
	log.added += 1
	return p
end
local function remove(p: Instance)
	p:SetAttribute("Rollback8A2A_Parent", p.Parent:GetFullName())
	p.Parent = removedStore
	log.removed += 1
end
-- A segment tangent to a circle of radius r at angle a, centred at height y.
local function ringCF(r: number, a: number, y: number): CFrame
	local pos = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
	return CFrame.lookAt(pos, Vector3.new(0, y, 0)) -- local Z points at the axis (radial)
end

-- 1. Remove the solid discs (their child lights go with them).
for _, n in { "CoilBand1", "CoilBand2", "CoilBand3", "CoilViolet1", "CoilViolet2", "CoilViolet3" } do
	local p = sil:FindFirstChild(n)
	assert(p, "missing " .. n)
	remove(p)
end
for _, n in { "GalleryRing60", "GalleryRing120" } do
	local p = struct:FindFirstChild(n)
	assert(p, "missing " .. n)
	remove(p)
end

-- 2. Hollow coils.
local COLUMN_R = 13
local rings = {
	{ y = 50, r = 32, h = 8, n = 18 },
	{ y = 95, r = 27, h = 7, n = 16 },
	{ y = 140, r = 22, h = 6, n = 14 },
}
local DEPTH = 6
for k, ring in rings do
	local outer = ring.r + DEPTH / 2
	local segLen = 2 * outer * math.tan(math.pi / ring.n) * 1.005 -- closes the outer edge
	local firstTrim
	for i = 0, ring.n - 1 do
		local a = (i / ring.n) * math.pi * 2
		part(sil, "Coil" .. k .. "Seg_" .. (i + 1), Vector3.new(segLen, ring.h, DEPTH), ringCF(ring.r, a, ring.y), if i % 2 == 0 then C.Gunmetal else C.GunmetalLt, M.Metal)
		if i % 2 == 0 then
			local trim = part(sil, "Coil" .. k .. "Trim_" .. (i // 2 + 1), Vector3.new(segLen * 0.7, 1.0, 0.3), ringCF(outer + 0.15, a, ring.y), C.Violet, M.Neon)
			firstTrim = firstTrim or trim
		end
	end
	local l = Instance.new("PointLight")
	l.Color = C.Violet
	l.Range = ring.r + 10
	l.Brightness = 2
	l.Shadows = false
	l.Parent = firstTrim
	for j = 0, 3 do
		-- 22.5 degrees off the diagonals: arms on the diagonals stood between the four CORE spawns
		-- and the column axis (found by 6_audit).
		local a = j * math.pi / 2 + math.rad(22.5)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local a0 = d * (COLUMN_R + 0.5) + Vector3.new(0, ring.y, 0)
		local a1 = d * (ring.r - DEPTH / 2 + 0.5) + Vector3.new(0, ring.y, 0)
		part(struct, "Coil" .. k .. "Arm_" .. (j + 1), Vector3.new(2, 2, (a1 - a0).Magnitude), CFrame.lookAt((a0 + a1) / 2, a1), C.Steel, M.Metal)
	end
end

-- 3. Open service galleries (8 deck segments between the column and r 19).
for _, y in { 60, 120 } do
	local inner, outerR = COLUMN_R + 1, 19
	local mid = (inner + outerR) / 2
	local segLen = 2 * outerR * math.tan(math.pi / 8) * 1.005
	for i = 0, 7 do
		local a = (i / 8) * math.pi * 2 + math.pi / 8
		part(struct, "Gallery" .. y .. "Seg_" .. (i + 1), Vector3.new(segLen, 0.8, outerR - inner), ringCF(mid, a, y), C.SteelLt, M.DiamondPlate)
	end
end

map:SetAttribute("Correction8A2A_R2", "2026-11-11")
return string.format("round 2 applied: removed %d, added %d", log.removed, log.added)

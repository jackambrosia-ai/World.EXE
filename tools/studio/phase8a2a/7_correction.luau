-- WORLD.EXE Phase 8A-2a review-correction stage (Studio EDIT mode). Runs on the saved 8A-2a build
-- (ArenaVersion 3); needs no builder state. Run once, after 5_validate (or on the saved place), then
-- run 6_audit (read-only) to verify the final state.
--
-- Changes (all decorative; no collidable part is added, moved or resized):
--   1. Reactor massing: containment column Ø18 -> Ø26, energy core Ø6 -> Ø9; the faceted 16-block coil
--      rings + small violet windings + support arms are replaced by smooth cylinder coil bands
--      (Ø64 / Ø54 / Ø44) with a continuous violet band each; a lower shroud adds base mass; crown, cradle ribs and galleries are refitted to the wider column;
--      buttress heads move to the middle coil's new radius. The 4 collidable buttress plinths are
--      untouched. Net part count goes DOWN.
--   2. Value separation: lighter concrete/steel for structure (plinth, coping, pilasters, vessel,
--      fascia, colonnade, mezzanine cladding) against the darker navy walls and roof.
--   3. Roof (A' in the A/B review): tinted glass (Transparency 0.35) so the bays between the ribs read as
--      a dark upper atmosphere instead of a solid low ceiling. The roof itself remains a design
--      deviation awaiting approval.
--   4. Readability: OutdoorAmbient 76,84,124 -> 88,96,140 and ExposureCompensation 0 -> 0.3 (lifts dark
--      floors such as the Reservoir basin; BLACKOUT applies its -1.2 from this baseline and restores it).
-- Reversibility: every changed property's original value is stored as an attribute
-- ("Orig8A2A_<Prop>") on the part; removed parts move to
-- ServerStorage.WORLD_EXE_Rollback8A2A.CorrectionRemoved. The authoritative rollback remains the
-- post-8A-2a .rbxl backup.
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local root = workspace:WaitForChild("WORLD_EXE")
local map = root.Map
assert(root:GetAttribute("ArenaVersion") == 3, "expected the 8A-2a build (ArenaVersion 3)")
assert(map:GetAttribute("Correction8A2A") == nil, "correction already applied")
local store = ServerStorage:WaitForChild("WORLD_EXE_Rollback8A2A")
local removedStore = Instance.new("Folder")
removedStore.Name = "CorrectionRemoved"
removedStore.Parent = store

local M = Enum.Material
local C = {
	Gunmetal = Color3.fromRGB(44, 48, 62),
	Steel = Color3.fromRGB(58, 68, 100),
	SteelLt = Color3.fromRGB(110, 118, 140),
	SteelPale = Color3.fromRGB(124, 132, 150),
	Concrete = Color3.fromRGB(92, 96, 108),
	ConcreteDk = Color3.fromRGB(72, 76, 90),
	Navy2 = Color3.fromRGB(38, 48, 82),
	Glass = Color3.fromRGB(159, 220, 255),
	Cyan = Color3.fromRGB(0, 225, 255),
	Violet = Color3.fromRGB(138, 43, 226),
	RoofGlass = Color3.fromRGB(16, 22, 52),
}
local VERT = CFrame.Angles(0, 0, math.rad(90))
local log = { removed = 0, added = 0, recolored = 0 }

local function remember(p: Instance, prop: string)
	local key = "Orig8A2A_" .. prop
	if p:GetAttribute(key) == nil then
		local v = (p :: any)[prop]
		p:SetAttribute(key, if typeof(v) == "EnumItem" then v.Name else v)
	end
end
local function set(p: BasePart, prop: string, value: any)
	remember(p, prop)
	local target: any = p
	target[prop] = value
end
local function remove(p: Instance)
	p:SetAttribute("Rollback8A2A_Parent", p.Parent:GetFullName())
	p.Parent = removedStore
	log.removed += 1
end
local function part(area: string, parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, shape: string?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	if shape then
		p.Shape = Enum.PartType[shape]
	end
	p.Transparency = transparency or 0
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Arch8A2A", area)
	p:SetAttribute("Correction8A2A", true)
	p.Parent = parent
	log.added += 1
	return p
end
local function cyl(parent, name, y0, y1, d, color, mat, area, transparency)
	return part(area or "Reactor", parent, name, Vector3.new(y1 - y0, d, d), CFrame.new(0, (y0 + y1) / 2, 0) * VERT, color, mat, "Cylinder", transparency)
end
local function strut(parent, name, a: Vector3, b: Vector3, w: number, h: number, color, mat)
	return part("Reactor", parent, name, Vector3.new(w, h, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, mat)
end

local core = map.Architecture.CentralCore
local sil, struct = core.ReactorSilhouette, core.ReactorStructure

-- 1. Reactor massing.
local column = sil.ContainmentColumn
set(column, "Size", Vector3.new(column.Size.X, 26, 26))
local energy = sil.EnergyCore
set(energy, "Size", Vector3.new(energy.Size.X, 9, 9))
for _, p in sil:GetChildren() do
	if p:IsA("BasePart") and (string.find(p.Name, "^Coil%d+_") or string.find(p.Name, "^Coil%d+Winding_")) then
		remove(p)
	end
end
for _, p in struct:GetChildren() do
	if p:IsA("BasePart") and (string.find(p.Name, "^Coil%d+Arm_") or string.find(p.Name, "^Buttress") and not string.find(p.Name, "Plinth") or string.find(p.Name, "^CradleRib_") or string.find(p.Name, "^Gallery")) then
		remove(p)
	end
end
local rings = { { y = 50, r = 32, h = 8 }, { y = 95, r = 27, h = 7 }, { y = 140, r = 22, h = 6 } }
for k, ring in rings do
	cyl(sil, "CoilBand" .. k, ring.y - ring.h / 2, ring.y + ring.h / 2, ring.r * 2, C.Gunmetal, M.Metal)
	local band = cyl(sil, "CoilViolet" .. k, ring.y - 0.8, ring.y + 0.8, ring.r * 2 + 1.2, C.Violet, M.Neon)
	local l = Instance.new("PointLight")
	l.Color = C.Violet
	l.Range = ring.r + 10
	l.Brightness = 2
	l.Shadows = false
	l.Parent = band
end
cyl(struct, "LowerShroud", 15, 30, 44, C.Steel, M.Metal)
cyl(struct, "CradleCollar2", 36, 39, 34, C.SteelPale, M.Metal)
for i = 0, 3 do
	local a = i * math.pi / 2 + math.pi / 4
	local d = Vector3.new(math.cos(a), 0, math.sin(a))
	-- (Vertical conduits were tried and removed: 6_audit showed they stood between several spawns
	-- and the column axis, reducing reactor readability.)
	strut(struct, "CradleRib_" .. (i + 1), d * 21 + Vector3.new(0, 30, 0), d * 15 + Vector3.new(0, 38, 0), 3, 4, C.Navy2, M.Metal)
end
for _, y in { 60, 120 } do
	-- Grating (Transparency 0.5): a solid disc hid the column from the CORE spawns.
	part("Reactor", struct, "GalleryRing" .. y, Vector3.new(1, 40, 40), CFrame.new(0, y, 0) * VERT, C.Steel, M.DiamondPlate, "Cylinder", 0.5)
end
for i, sgn in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
	local foot = Vector3.new(sgn[1] * 43, 28.5, sgn[2] * 43)
	local dir = Vector3.new(sgn[1], 0, sgn[2]).Unit
	local head = dir * 27 + Vector3.new(0, 91, 0)
	local side = Vector3.new(-dir.Z, 0, dir.X) * 2.4
	strut(struct, "ButtressMain_" .. i, foot, head, 4, 6, C.Navy2, M.Metal)
	strut(struct, "ButtressChord_" .. i, foot + side + Vector3.new(0, 5, 0) - dir * 2, head + side - Vector3.new(0, 6, 0) + dir * 2, 1.6, 1.6, C.SteelLt, M.Metal)
	for t = 1, 3 do
		local f = t / 4
		strut(struct, "ButtressTie_" .. i .. "_" .. t, foot:Lerp(head, f), (foot + side + Vector3.new(0, 5, 0) - dir * 2):Lerp(head + side - Vector3.new(0, 6, 0) + dir * 2, f + 0.08), 1, 1, C.SteelLt, M.Metal)
	end
end
-- Crown refit (Ø30 -> Ø38 collar, fins pushed out, larger cap and emitter).
local crownCollar = sil.CrownCollar
set(crownCollar, "Size", Vector3.new(crownCollar.Size.X, 38, 38))
for i = 0, 7 do
	local fin = sil:FindFirstChild("CrownFin_" .. (i + 1))
	if fin then
		local a = i * math.pi / 4
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local base, tip = d * 16 + Vector3.new(0, 173, 0), d * 20 + Vector3.new(0, 191, 0)
		set(fin, "Size", Vector3.new(2, 8, (tip - base).Magnitude))
		set(fin, "CFrame", CFrame.lookAt((base + tip) / 2, tip))
	end
end
set(sil.CrownCap, "Size", Vector3.new(sil.CrownCap.Size.X, 18, 18))
set(sil.CrownEmitter, "Size", Vector3.new(sil.CrownEmitter.Size.X, 8, 8))

-- 2. Value separation (existing parts only).
local recolor = {
	{ "^Plinth_.*_%d*[13579]$", C.Concrete, M.Concrete },
	{ "^Plinth_.*_%d*[02468]$", C.ConcreteDk, M.Concrete },
	{ "^PlinthCoping_", C.SteelPale, M.Concrete },
	{ "^Pilaster_", C.SteelLt, M.Metal },
	{ "^CornerTowerCap", C.SteelPale, M.Metal },
	{ "^VesselUpper_", C.Concrete, M.Concrete },
	{ "^Fascia_", C.SteelPale, M.Metal },
	{ "^Column_", C.SteelLt, M.Metal },
	{ "^PillarCladding", C.SteelLt, M.Metal },
	{ "^PillarCapital", C.SteelPale, M.Metal },
	{ "^Base$", C.ConcreteDk, M.Concrete },
}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute("Arch8A2A") and not d:GetAttribute("Correction8A2A") then
		for _, rule in recolor do
			if string.find(d.Name, rule[1]) then
				set(d, "Color", rule[2])
				set(d, "Material", rule[3])
				log.recolored += 1
				break
			end
		end
	end
end

-- 3. Roof A': tinted glass.
for _, p in map.Megastructure.Silhouette:GetChildren() do
	if p:IsA("BasePart") and (string.find(p.Name, "^RoofPlate") or string.find(p.Name, "^RoofWedge")) then
		set(p, "Material", M.Glass)
		set(p, "Color", C.RoofGlass)
		set(p, "Transparency", 0.35)
	end
end

-- 4. Readability fill.
if Lighting:GetAttribute("Orig8A2A_OutdoorAmbient") == nil then
	Lighting:SetAttribute("Orig8A2A_OutdoorAmbient", Lighting.OutdoorAmbient)
end
Lighting.OutdoorAmbient = Color3.fromRGB(88, 96, 140)
if Lighting:GetAttribute("Orig8A2A_ExposureCompensation") == nil then
	Lighting:SetAttribute("Orig8A2A_ExposureCompensation", Lighting.ExposureCompensation)
end
Lighting.ExposureCompensation = 0.3 -- BLACKOUT adds -1.2 from this baseline and restores it exactly
-- 5. Restrained bloom: 0.9/1.0/28 smeared neon rack faces into blobs in the actual Play camera.
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then
	if Lighting:GetAttribute("Orig8A2A_BloomIntensity") == nil then
		Lighting:SetAttribute("Orig8A2A_BloomIntensity", bloom.Intensity)
		Lighting:SetAttribute("Orig8A2A_BloomThreshold", bloom.Threshold)
		Lighting:SetAttribute("Orig8A2A_BloomSize", bloom.Size)
	end
	bloom.Intensity, bloom.Threshold, bloom.Size = 0.4, 1.3, 20
end

map:SetAttribute("Correction8A2A", "2026-11-11")
return string.format("correction applied: removed %d, added %d, recolored %d", log.removed, log.added, log.recolored)

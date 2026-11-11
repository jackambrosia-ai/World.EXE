-- WORLD.EXE Phase 8A-2b builder, step 0: shared library and rollback store (Studio EDIT mode).
-- Order: 0_lib -> 1_yard -> 2_skybridge -> 3_archive -> 4_coolant -> 5_ring_supports -> 6_audit
--        (read-only) -> 7_finalize. Recovery: _G.W8A2B.Restore("reason") or the standalone 9_restore.
-- Design: docs/PHASE_8A2_ARCHITECTURE_DESIGN.md (PR #13 at f623a4e); 8A-2a decisions take
-- precedence (five-spawn AC2 waiver, roof/lighting A'). Nothing here changes gameplay geometry:
-- every new part is tagged Arch8A2B=<area>; decorative parts have no collision, query, touch or
-- shadow. The only existing parts touched are the twelve 8A-1 rack-face neon strips, which are
-- hidden (Transparency 1, original kept as Orig8A2B_Transparency). Their Transparency is visual
-- only (not in the ArenaService baseline); size, CFrame, material and collision are unchanged.
-- Collidable roles (checked by 6_audit):
--   FloorStructure: stands on a walkable floor, within 4 studs of that floor's edge or within 1.5
--                   of an existing collidable wall/rack; >= 2 studs from every gameplay marker.
--   EdgeRail:       low jumpable rail on a floor's top, within 1.5 of an edge that drops to void.
--   BoundaryWall:   outside every walkable footprint, against a floor edge that drops to void.
local ServerStorage = game:GetService("ServerStorage")

local root = workspace:WaitForChild("WORLD_EXE")
local map = root:WaitForChild("Map")
local arch = map:WaitForChild("Architecture")
assert(root:GetAttribute("ArenaVersion") == 3, "expected the Phase 8A-2a arena (ArenaVersion 3)")
assert(map:GetAttribute("Correction8A2A_R2") ~= nil, "expected the final Phase 8A-2a build")
assert(map:GetAttribute("Phase8A2B") == nil, "Phase 8A-2b already finalized")
assert(ServerStorage:FindFirstChild("WORLD_EXE_Rollback8A2B") == nil, "8A-2b rollback store already exists")
for _, d in map:GetDescendants() do
	assert(d:GetAttribute("Arch8A2B") == nil, "8A-2b content already present: " .. d:GetFullName())
end

local W = {}
_G.W8A2B = W
W.root, W.map, W.arch = root, map, arch
W.MODELS = { "TestHangar", "ControlFacility", "ServerCanyons", "PumpStation", "TransitRing", "SharedSupports" }

W.C = {
	Slate = Color3.fromRGB(14, 18, 32),
	Navy0 = Color3.fromRGB(20, 26, 46),
	Navy1 = Color3.fromRGB(28, 36, 64),
	Navy2 = Color3.fromRGB(38, 48, 82),
	Charcoal = Color3.fromRGB(34, 36, 44),
	Steel = Color3.fromRGB(58, 68, 100),
	SteelLt = Color3.fromRGB(84, 96, 130),
	Silver = Color3.fromRGB(150, 158, 176),
	LabPanel = Color3.fromRGB(178, 186, 204),
	Concrete = Color3.fromRGB(66, 72, 92),
	ConcreteDk = Color3.fromRGB(46, 51, 68),
	Glass = Color3.fromRGB(159, 220, 255),
	GlassDk = Color3.fromRGB(40, 70, 110),
	Cyan = Color3.fromRGB(0, 225, 255),
	CyanDim = Color3.fromRGB(0, 140, 170),
	Teal = Color3.fromRGB(0, 190, 170),
	TealDk = Color3.fromRGB(16, 70, 78),
	Violet = Color3.fromRGB(138, 43, 226),
	Magenta = Color3.fromRGB(200, 40, 200),
	Static = Color3.fromRGB(120, 128, 150),
	White = Color3.fromRGB(225, 235, 255),
	Amber = Color3.fromRGB(255, 176, 0), -- reserved: warnings only (ReservedUse attribute)
}
local M = Enum.Material
W.M = M

local store = Instance.new("Folder")
store.Name = "WORLD_EXE_Rollback8A2B"
store:SetAttribute("Models", table.concat(W.MODELS, ","))
store:SetAttribute("CreatedFrom", "ArenaVersion 3 / Correction8A2A_R2")
store.Parent = ServerStorage
W.store = store

W.newParts = {}
W.counts = {}
local function count(area: string)
	local c = W.counts[area]
	if not c then
		c = { parts = 0, collide = 0, lights = 0, shadows = 0 }
		W.counts[area] = c
	end
	return c
end
W.count = count

function W.Model(parent: Instance, name: string, mode: string?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode[mode or "Default"]
	m.Parent = parent
	return m
end

-- District container: Architecture.<name> with an Atomic "Structure" and a Default "Dressing".
function W.District(name: string)
	assert(arch:FindFirstChild(name) == nil, name .. " already exists")
	local d = W.Model(arch, name, "Default")
	return d, W.Model(d, "Structure", "Atomic"), W.Model(d, "Dressing", "Default")
end

-- Part helper. opts: role = "FloorStructure" | "EdgeRail" | "BoundaryWall" (collidable),
-- support = true (structural support for the span audit), shape, wedge, transparency,
-- reflectance, reservedUse = "Warning".
function W.P(area: string, parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, opts: { [string]: any }?): BasePart
	local o = opts or {}
	local p: BasePart
	if o.wedge then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if o.shape then
			part.Shape = Enum.PartType[o.shape]
		end
		p = part
	end
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Transparency = o.transparency or 0
	p.Reflectance = o.reflectance or 0
	local solid = o.role ~= nil
	p.CanCollide = solid
	p.CanQuery = solid
	p.CanTouch = solid
	p.CastShadow = false
	p:SetAttribute("Arch8A2B", area)
	if o.role then
		p:SetAttribute(o.role, true)
		if o.role == "EdgeRail" then
			p:SetAttribute("EdgeRail", true)
		end
	end
	if o.support then
		p:SetAttribute("Support8A2B", true)
	end
	if o.reservedUse then
		p:SetAttribute("ReservedUse", o.reservedUse)
	end
	p.Parent = parent
	local c = count(area)
	c.parts += 1
	if solid then
		c.collide += 1
	end
	table.insert(W.newParts, p)
	return p
end

-- Axis-aligned box from two corners.
function W.Box(area: string, parent: Instance, name: string, lo: Vector3, hi: Vector3, color: Color3, material: Enum.Material?, opts: { [string]: any }?): BasePart
	local a = Vector3.new(math.min(lo.X, hi.X), math.min(lo.Y, hi.Y), math.min(lo.Z, hi.Z))
	local b = Vector3.new(math.max(lo.X, hi.X), math.max(lo.Y, hi.Y), math.max(lo.Z, hi.Z))
	return W.P(area, parent, name, b - a, CFrame.new((a + b) / 2), color, material, opts)
end

-- Box beam between two points (w across, h up, length along a->b).
function W.Strut(area: string, parent: Instance, name: string, a: Vector3, b: Vector3, w: number, h: number, color: Color3, material: Enum.Material?, opts: { [string]: any }?): BasePart
	local mid = (a + b) / 2
	local dir = b - a
	local up = if math.abs(dir.Unit.Y) > 0.99 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	return W.P(area, parent, name, Vector3.new(w, h, dir.Magnitude), CFrame.lookAt(mid, b, up), color, material, opts)
end

-- Vertical cylinder centred at pos.
function W.Cyl(area: string, parent: Instance, name: string, pos: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?, opts: { [string]: any }?): BasePart
	local o = table.clone(opts or {})
	o.shape = "Cylinder"
	return W.P(area, parent, name, Vector3.new(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material, o)
end

function W.Light(area: string, host: BasePart, class: string, props: { [string]: any }): Light
	local l = Instance.new(class) :: any
	l.Shadows = false
	for k, v in props do
		l[k] = v
	end
	l.Parent = host
	local c = count(area)
	c.lights += 1
	if l.Shadows then
		c.shadows += 1
	end
	return l
end

function W.Beam(host0: BasePart, off0: Vector3, host1: BasePart, off1: Vector3, color: Color3, width: number, transparency: number)
	local a0 = Instance.new("Attachment")
	a0.Position = off0
	a0.Parent = host0
	local a1 = Instance.new("Attachment")
	a1.Position = off1
	a1.Parent = host1
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(color)
	b.Width0 = width
	b.Width1 = width
	b.Transparency = NumberSequence.new(transparency)
	b.LightEmission = 0
	b.FaceCamera = true
	b.Segments = 1
	b.Parent = host0
	W.beams = (W.beams or 0) + 1
	return b
end

-- Hide an existing 8A-1 decorative part (visual property only; original kept as an attribute).
function W.Hide(p: BasePart)
	assert(not p.CanCollide, "only decorative parts may be hidden: " .. p:GetFullName())
	if p:GetAttribute("Orig8A2B_Transparency") == nil then
		p:SetAttribute("Orig8A2B_Transparency", p.Transparency)
	end
	p.Transparency = 1
end

-- Full rollback to the pre-8A-2b state (the same logic as 9_restore).
function W.Restore(reason: string?)
	local n = 0
	for _, name in W.MODELS do
		local m = arch:FindFirstChild(name)
		if m then
			m:Destroy()
			n += 1
		end
	end
	local restored = 0
	for _, d in map:GetDescendants() do
		local t = d:GetAttribute("Orig8A2B_Transparency")
		if t ~= nil then
			(d :: BasePart).Transparency = t
			d:SetAttribute("Orig8A2B_Transparency", nil)
			restored += 1
		end
	end
	map:SetAttribute("Phase8A2B", nil)
	store:Destroy()
	_G.W8A2B = nil
	return string.format("8A-2b restored (%s): %d district models removed, %d hidden parts restored", reason or "manual", n, restored)
end

return "8A-2b lib ready; rollback store created"

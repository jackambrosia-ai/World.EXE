-- WORLD.EXE Phase 8A-2a builder, step 0: shared library, rollback capture, budget counters.
-- Run the steps in order in Studio EDIT mode via Studio MCP execute_luau:
--   0_lib -> 1_hall -> 2_reactor -> 3_core -> 4_lobby_lighting -> 5_validate
-- Each step uses _G.W8A2A, which this step creates. 5_validate checks every gameplay clearance and
-- the budget. On any failure it calls W.Restore(), which returns the place exactly to its
-- pre-8A-2a state (ArenaVersion 2). Manual rollback: run 9_restore.
-- Design: docs/PHASE_8A2_ARCHITECTURE_DESIGN.md (revision 2, approved at f623a4e).
-- Coordinates: +X east, -Z north; T0 Y0, T1 Y24, T2 Y48, T3 Y72.

local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")

local root = workspace:WaitForChild("WORLD_EXE")
local map = root:WaitForChild("Map")
local lobby = root:WaitForChild("Lobby")
assert(root:GetAttribute("ArenaVersion") == 2, "expected the Phase 8A-1 arena (ArenaVersion 2)")
assert(ServerStorage:FindFirstChild("WORLD_EXE_Rollback8A2A") == nil, "8A-2a rollback store already exists")
assert(map:FindFirstChild("Architecture") == nil and map:FindFirstChild("Megastructure") == nil, "8A-2a content already present")

local W = {}
_G.W8A2A = W
W.root, W.map, W.lobby = root, map, lobby

-- Palette (navy/charcoal structure with value variation; cyan = system; violet = simulation).
W.C = {
	Slate = Color3.fromRGB(14, 18, 32), -- darkest: shaft floor, deep recesses
	Navy0 = Color3.fromRGB(20, 26, 46),
	Navy1 = Color3.fromRGB(28, 36, 64),
	Navy2 = Color3.fromRGB(38, 48, 82),
	Steel = Color3.fromRGB(58, 68, 100), -- mid metal
	SteelLt = Color3.fromRGB(84, 96, 130), -- light metal edges
	Concrete = Color3.fromRGB(66, 72, 92), -- lighter concrete masses
	ConcreteDk = Color3.fromRGB(46, 51, 68),
	Glass = Color3.fromRGB(159, 220, 255),
	Cyan = Color3.fromRGB(0, 225, 255),
	Violet = Color3.fromRGB(138, 43, 226),
	Warm = Color3.fromRGB(255, 236, 214),
}
local M = Enum.Material
W.M = M

-- Rollback store: original parts that 8A-2a removes, plus the original property values it changes.
local store = Instance.new("Folder")
store.Name = "WORLD_EXE_Rollback8A2A"
store.Parent = ServerStorage
W.store = store
local removed = Instance.new("Folder")
removed.Name = "RemovedMapParts"
removed.Parent = store
W.removedFolder = removed

-- Lighting snapshot: properties as attributes, children as clones.
local lightProps = { "Brightness", "ExposureCompensation", "ClockTime", "Ambient", "OutdoorAmbient", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "GlobalShadows", "FogEnd", "FogStart", "FogColor", "ColorShift_Top", "ColorShift_Bottom", "GeographicLatitude" }
W.lightProps = lightProps
local lightSnap = Instance.new("Folder")
lightSnap.Name = "Lighting"
lightSnap.Parent = store
for _, prop in lightProps do
	lightSnap:SetAttribute(prop, (Lighting :: any)[prop])
end
for _, child in Lighting:GetChildren() do
	child:Clone().Parent = lightSnap
end

-- Lobby Wall_N snapshot (the only lobby part 8A-2a changes; visual properties only).
local wallN = lobby:WaitForChild("Wall_N") :: BasePart
local wallSnap = Instance.new("Folder")
wallSnap.Name = "LobbyWallN"
wallSnap.Parent = store
wallSnap:SetAttribute("Material", wallN.Material.Name)
wallSnap:SetAttribute("Transparency", wallN.Transparency)
wallSnap:SetAttribute("Color", wallN.Color)
wallSnap:SetAttribute("Reflectance", wallN.Reflectance)
W.wallN = wallN

-- Containers. Built content is assembled outside the DataModel and parented per section.
local arch = Instance.new("Folder")
arch.Name = "Architecture"
local mega = Instance.new("Folder")
mega.Name = "Megastructure"
W.arch, W.mega = arch, mega
W.newParts = {} -- every part 8A-2a creates
W.counts = {} -- [area] = { parts, collide, lights, shadows }

local function count(area: string)
	local c = W.counts[area]
	if not c then
		c = { parts = 0, collide = 0, lights = 0, shadows = 0 }
		W.counts[area] = c
	end
	return c
end
W.count = count

-- Model helper with a streaming mode ("Persistent", "Atomic" or "Default").
function W.Model(parent: Instance, name: string, mode: string?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode[mode or "Default"]
	m.Parent = parent
	return m
end

-- Part helper. Decorative by default: no collision, query, touch or shadow.
-- opts: collide=true (gameplay-solid, also queryable/touchable), shadow=true, shape="Cylinder"|"Ball",
-- wedge=true, transparency=n, reflectance=n, edgeRail=true (allowed at walkable edges).
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
	local solid = o.collide == true
	p.CanCollide = solid
	p.CanQuery = solid
	p.CanTouch = solid
	p.CastShadow = o.shadow == true
	p:SetAttribute("Arch8A2A", area)
	if o.edgeRail then
		p:SetAttribute("EdgeRail", true)
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

-- Light helper (PointLight / SpotLight / SurfaceLight) hosted in a part.
function W.Light(area: string, host: BasePart, class: string, props: { [string]: any }): Light
	local l = Instance.new(class) :: any
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

-- Beam between two parts (decorative energy links / cables; Beams are not parts).
function W.Beam(host0: BasePart, off0: Vector3, host1: BasePart, off1: Vector3, color: Color3, width: number, transparency: number, lightEmission: number?)
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
	b.LightEmission = lightEmission or 1
	b.FaceCamera = true
	b.Segments = 1
	b.Parent = host0
	W.beams = (W.beams or 0) + 1
	return b
end

-- A box beam between two points (used for ribs, braces, girders, cables).
function W.Strut(area: string, parent: Instance, name: string, a: Vector3, b: Vector3, w: number, h: number, color: Color3, material: Enum.Material?, opts: { [string]: any }?): BasePart
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, b)
	return W.P(area, parent, name, Vector3.new(w, h, len), cf, color, material, opts)
end

-- Ring of segment blocks around a vertical axis at `center`.
function W.Ring(area: string, parent: Instance, name: string, center: Vector3, radius: number, segments: number, segSize: Vector3, color: Color3, material: Enum.Material?, opts: { [string]: any }?, phase: number?): { BasePart }
	local list = {}
	for i = 0, segments - 1 do
		local a = (i / segments) * math.pi * 2 + (phase or 0)
		local pos = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local cf = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
		table.insert(list, W.P(area, parent, name .. "_" .. (i + 1), segSize, cf, color, material, opts))
	end
	return list
end

-- Removes a Map part into the rollback store (kept, not destroyed).
function W.Remove(inst: Instance)
	local pathAttr = inst:GetFullName()
	inst:SetAttribute("Rollback8A2A_Parent", inst.Parent and inst.Parent:GetFullName() or "")
	inst.Parent = W.removedFolder
	return pathAttr
end

-- Full rollback to the pre-8A-2a state.
function W.Restore(reason: string?)
	local log = {}
	for _, f in { map:FindFirstChild("Architecture"), map:FindFirstChild("Megastructure"), W.arch, W.mega } do
		if f then
			f:Destroy()
		end
	end
	for _, inst in W.removedFolder:GetChildren() do
		local parentPath = inst:GetAttribute("Rollback8A2A_Parent")
		local parent: Instance? = game
		for _, seg in string.split(parentPath, ".") do
			parent = parent and parent:FindFirstChild(seg)
		end
		if parent then
			inst:SetAttribute("Rollback8A2A_Parent", nil)
			inst.Parent = parent
		else
			table.insert(log, "could not restore " .. inst.Name)
		end
	end
	for _, prop in lightProps do
		(Lighting :: any)[prop] = lightSnap:GetAttribute(prop)
	end
	for _, child in Lighting:GetChildren() do
		child:Destroy()
	end
	for _, child in lightSnap:GetChildren() do
		child:Clone().Parent = Lighting
	end
	wallN.Material = M[wallSnap:GetAttribute("Material")]
	wallN.Transparency = wallSnap:GetAttribute("Transparency")
	wallN.Color = wallSnap:GetAttribute("Color")
	wallN.Reflectance = wallSnap:GetAttribute("Reflectance")
	for _, extra in lobby:GetChildren() do
		if extra:GetAttribute("Arch8A2A") then
			extra:Destroy()
		end
	end
	root:SetAttribute("ArenaVersion", 2)
	store:Destroy()
	_G.W8A2A = nil
	return "restored (" .. (reason or "manual") .. ")" .. (if #log > 0 then " WITH ISSUES: " .. table.concat(log, "; ") else "")
end

return "8A-2a lib ready; rollback store captured (Lighting props/children, Lobby Wall_N)"

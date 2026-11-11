-- WORLD.EXE Phase 8A-2c builder (Studio Edit, via Studio MCP). Patch-responsive environment hooks.
-- Run AFTER the 8A-2b place (Map.Phase8A2B present). Idempotence: refuses to run if any 8A-2c work
-- exists (use 2_rollback.luau first, on a working session only). A failed build undoes itself.
--
-- What it does (decorative only; never touches gameplay-tagged objects, collision or geometry of
-- existing parts):
--   1. Tags existing decorative parts/lights with CollectionService tags "EnvFX_<EFFECT_ID>" and
--      writes their immutable baseline as attributes (Base_Color, Base_Transparency, Base_Material,
--      Base_Brightness, Base_Range, Base_LightEnabled, Base_BeamEnabled), plus "EnvFX_Role" (which
--      style the client applies) and "Env8A2C" = "hook".
--   2. Builds the Option B extras in Map.EnvFX8A2C (all hidden at baseline, Transparency 1, and
--      CanCollide/CanQuery/CanTouch/CastShadow false), 3 normally-disabled PointLights and 1 static
--      normally-disabled scan Beam. Every new instance carries "Env8A2C" = "new".
--   3. Records a rollback summary in ServerStorage.WORLD_EXE_Rollback8A2C.
-- Only the properties named in a hook's role are recorded/managed. Collidable hooks get Color only.
-- Limits (owner Option B): new BaseParts <= 40, new collidable 0, new Lights <= 4 (disabled),
-- new Beams <= 1, no emitters, no gameplay objects.
local CS = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local root = workspace:WaitForChild("WORLD_EXE")
local map = root:WaitForChild("Map")
assert(map:GetAttribute("Phase8A2B"), "8A-2b place required")
assert(not ServerStorage:FindFirstChild("WORLD_EXE_Rollback8A2C"), "8A-2c already built (rollback first)")
assert(not map:FindFirstChild("EnvFX8A2C"), "EnvFX8A2C already exists")
for _, d in root:GetDescendants() do
	assert(d:GetAttribute("Env8A2C") == nil, "8A-2c marker already present: " .. d:GetFullName())
	for _, t in CS:GetTags(d) do
		assert(t:sub(1, 6) ~= "EnvFX_", "EnvFX tag already present: " .. d:GetFullName())
	end
	for k in d:GetAttributes() do
		assert(k:sub(1, 5) ~= "Base_", "Base_ attribute already present: " .. d:GetFullName())
	end
end

-- Gameplay tags (server-owned objects) must never be hooked.
local GAMEPLAY_TAGS = {}
for _, t in { "DecayTile", "ArenaSpawn", "Stabilizer", "SupplyLandingPoint", "DroneWaypoint", "FragmentSpawn", "BounceSurface", "SlipSurface", "MagneticProp", "MagneticPoint", "CorruptionNode", "FloodZone", "LobbySpawn" } do
	GAMEPLAY_TAGS[t] = true
end
local function assertDecorative(inst: Instance)
	local cur: Instance? = inst
	while cur and cur ~= map do
		for _, t in CS:GetTags(cur) do
			assert(not GAMEPLAY_TAGS[t], "gameplay-tagged object cannot be a hook: " .. inst:GetFullName())
		end
		assert(cur.Name ~= "PatchMarkers" and cur.Name ~= "PatchSurfaces" and cur.Name:sub(1, 11) ~= "Stabilizer_", "gameplay container: " .. inst:GetFullName())
		cur = cur.Parent
	end
end

local function path(...): Instance
	local cur: Instance = map
	for _, n in { ... } do
		local nxt = cur:FindFirstChild(n)
		assert(nxt, "missing " .. cur:GetFullName() .. "." .. n)
		cur = nxt
	end
	return cur
end

-- Role -> managed properties (must match EnvironmentResponseClient STYLES).
local ROLE_PROPS = {
	CoilTrim = { "Color" }, CoilLight = { "Color", "Brightness" },
	Skylight = { "Color", "Transparency" }, Inlay = { "Color", "Material" },
	SpireBeacon = { "Color" }, SpireLight = { "Color", "Brightness" },
	HubRing = { "Color" }, Oculus = { "Color" },
	Pipe = { "Color", "Material", "Transparency" },
	Seam = { "Color", "Material" },
	CableTray = { "Color" }, MagCoil = { "Transparency" }, MagLight = { "Enabled" },
	IntakeGrate = { "Color" }, IntakeLight = { "Brightness", "Range" }, PumpRing = { "Color" }, TurbineCasing = { "Color" },
	CraneWarning = { "Color" }, CraneLight = { "Brightness", "Range" },
	BounceRim = { "Color", "Transparency" }, SlipRim = { "Color", "Material", "Transparency" },
	GlitchA = { "Transparency" }, GlitchB = { "Transparency" },
	Debris = { "Transparency" }, DebrisChip = { "Transparency" }, DebrisLight = { "Enabled" },
	ScanBeam = { "Enabled" },
}

local hookCount, newParts, newLights, newBeams, newOther = 0, 0, 0, 0, 0
local roleCounts: { [string]: number } = {}

local function writeBase(inst: Instance, role: string)
	local props = ROLE_PROPS[role]
	assert(props, "unknown role " .. role)
	for _, p in props do
		if inst:IsA("BasePart") then
			if p == "Color" then
				inst:SetAttribute("Base_Color", inst.Color)
			elseif p == "Transparency" then
				inst:SetAttribute("Base_Transparency", inst.Transparency)
			elseif p == "Material" then
				inst:SetAttribute("Base_Material", inst.Material.Name)
			else
				error("bad part prop " .. p)
			end
			if p ~= "Color" then
				assert(not inst.CanCollide, "collidable hook may only manage Color: " .. inst:GetFullName())
			end
		elseif inst:IsA("Light") then
			if p == "Enabled" then
				inst:SetAttribute("Base_LightEnabled", inst.Enabled)
			elseif p == "Color" then
				inst:SetAttribute("Base_Color", inst.Color)
			elseif p == "Brightness" then
				inst:SetAttribute("Base_Brightness", inst.Brightness)
			elseif p == "Range" then
				inst:SetAttribute("Base_Range", inst.Range)
			else
				error("bad light prop " .. p)
			end
		elseif inst:IsA("Beam") then
			assert(p == "Enabled", "bad beam prop " .. p)
			inst:SetAttribute("Base_BeamEnabled", inst.Enabled)
		else
			error("unsupported hook class " .. inst.ClassName)
		end
	end
end

local function hook(inst: Instance, role: string, effects: { string }, marker: string?)
	assertDecorative(inst)
	inst:SetAttribute("EnvFX_Role", role)
	inst:SetAttribute("Env8A2C", marker or "hook")
	writeBase(inst, role)
	for _, e in effects do
		CS:AddTag(inst, "EnvFX_" .. e)
	end
	roleCounts[role] = (roleCounts[role] or 0) + 1
	if (marker or "hook") == "hook" then
		hookCount += 1
	end
end

local function lightOf(part: Instance): Light?
	for _, c in part:GetChildren() do
		if c:IsA("Light") then
			return c
		end
	end
	return nil
end

-- Undo for a failed build: removes exactly what this builder added (same rules as 2_rollback.luau).
local function undo()
	for _, d in root:GetDescendants() do
		if d.Parent and d:GetAttribute("Env8A2C") == "new" then
			d:Destroy()
		end
	end
	for _, d in root:GetDescendants() do
		if d:GetAttribute("Env8A2C") == "hook" then
			for _, t in CS:GetTags(d) do
				if t:sub(1, 6) == "EnvFX_" then
					CS:RemoveTag(d, t)
				end
			end
			for k in d:GetAttributes() do
				if k:sub(1, 5) == "Base_" or k == "EnvFX_Role" or k == "Env8A2C" then
					d:SetAttribute(k, nil)
				end
			end
		end
	end
	local fxModel = map:FindFirstChild("EnvFX8A2C")
	if fxModel then
		fxModel:Destroy()
	end
	local s = ServerStorage:FindFirstChild("WORLD_EXE_Rollback8A2C")
	if s then
		s:Destroy()
	end
end

local function build(): string
---------------------------------------------------------------------------------------------------
-- 1. Existing decorative hooks

-- ZERO_G / SUPER_BOUNCE: reactor coil trims (+ their PointLights)
local reactor = path("Architecture", "CentralCore", "ReactorSilhouette")
for _, d in reactor:GetChildren() do
	if d:IsA("BasePart") and d.Name:match("^Coil%dTrim_%d+$") then
		hook(d, "CoilTrim", { "ZERO_G", "SUPER_BOUNCE" })
		local l = lightOf(d)
		if l then
			hook(l, "CoilLight", { "ZERO_G", "SUPER_BOUNCE" })
		end
	end
end

-- DECAY / RAPID_DECAY: Research Yard skylights; DECAY: Core floor inlays
for _, d in path("Architecture", "TestHangar", "Structure"):GetChildren() do
	if d:IsA("BasePart") and d.Name == "Skylight" then
		hook(d, "Skylight", { "DECAY", "RAPID_DECAY" })
	end
end
for i = 1, 4 do
	hook(path("Architecture", "CentralCore", "Dressing", "Inlay_" .. i), "Inlay", { "DECAY" })
end

-- DRONE_SWARM: Skybridge spire beacons
local beacons = {}
for _, s in { "SpireNorth", "SpireSouth" } do
	local b = path("Architecture", "ControlFacility", "Structure", s, "SpireBeacon")
	hook(b, "SpireBeacon", { "DRONE_SWARM" })
	local l = lightOf(b)
	assert(l, "spire beacon light missing")
	hook(l, "SpireLight", { "DRONE_SWARM" })
	table.insert(beacons, b)
end

-- SUPPLY_DROP: ceiling hub ring + Archive oculus ring
for i = 1, 12 do
	hook(path("Megastructure", "Silhouette", "HubRing_" .. i), "HubRing", { "SUPPLY_DROP" })
end
for _, d in path("Architecture", "ServerCanyons"):GetDescendants() do
	if d:IsA("BasePart") and d.Name == "OculusRing" then
		hook(d, "Oculus", { "SUPPLY_DROP" })
	end
end

-- SLIPPERY: Reservoir pipe runs, elbows, drops and flanges (non-collidable; the collidable IntakeUnit,
-- the posts and valve wheels in the same folder are not hooks)
for _, d in path("Architecture", "PumpStation", "Dressing", "PipeRuns"):GetChildren() do
	if d:IsA("BasePart") and (d.Name == "PipeRun" or d.Name == "PipeElbow" or d.Name == "PipeDrop" or d.Name == "PipeFlange") then
		assert(not d.CanCollide, "pipe is collidable: " .. d:GetFullName())
		hook(d, "Pipe", { "SLIPPERY" })
	end
end

-- BLACKOUT: selected hall seams switch off by sector (one lit seam stays on each wall)
for _, n in { "Seam_N-3", "Seam_N3", "Seam_E2", "Seam_S-2", "Seam_W-2" } do
	hook(path("Megastructure", "Detail", n), "Seam", { "BLACKOUT" })
end

-- MAGNETIC: Archive overhead cable trays
local trays = {}
for _, d in path("Architecture", "ServerCanyons", "Dressing", "CableTrays"):GetChildren() do
	if d:IsA("BasePart") then
		hook(d, "CableTray", { "MAGNETIC" })
		table.insert(trays, d)
	end
end

-- FLOOD: intake grates (+ light), pump rings, turbine casings (collidable: Color only)
for _, d in path("Architecture", "PumpStation", "Dressing"):GetChildren() do
	if d:IsA("BasePart") and d.Name == "IntakeGrate" then
		hook(d, "IntakeGrate", { "FLOOD" })
		local l = lightOf(d)
		if l then
			hook(l, "IntakeLight", { "FLOOD" })
		end
	end
end
hook(path("CoolantReservoir", "PumpRing_1"), "PumpRing", { "FLOOD" })
hook(path("CoolantReservoir", "PumpRing_2"), "PumpRing", { "FLOOD" })
for _, d in path("Architecture", "PumpStation", "Structure", "PumpHall"):GetChildren() do
	if d:IsA("BasePart") and d.Name == "TurbineCasing" then
		hook(d, "TurbineCasing", { "FLOOD" })
	end
end

-- RAPID_DECAY: crane warning indicator (+ light)
local crane = path("Architecture", "TestHangar", "Structure", "GantryCrane", "CraneWarning")
hook(crane, "CraneWarning", { "RAPID_DECAY" })
hook(assert(lightOf(crane), "crane light missing"), "CraneLight", { "RAPID_DECAY" })

---------------------------------------------------------------------------------------------------
-- 2. Option B extras
local VIOLET = Color3.fromRGB(138, 43, 226)
local MAGENTA = Color3.fromRGB(214, 38, 170)
local ICE = Color3.fromRGB(190, 235, 255)
local DEBRIS = Color3.fromRGB(46, 50, 66)

local fx = Instance.new("Model")
fx.Name = "EnvFX8A2C"
fx.ModelStreamingMode = Enum.ModelStreamingMode.Default
fx:SetAttribute("Env8A2C", "new")
local function group(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Default
	m:SetAttribute("Env8A2C", "new")
	m.Parent = fx
	return m
end
local function newPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = 1 -- hidden at baseline; shown only by its effect
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	newParts += 1
	return p
end

-- BOUNCY / SUPER_BOUNCE: perimeter rims under each bounce pad (top 0.12 above the pad's base, below
-- the pad top; nothing above the pad surface, so the bounce clearance column is untouched).
local rims = group("BouncePerimeter")
for _, pad in CS:GetTagged("BounceSurface") do
	if pad:IsA("BasePart") and pad:IsDescendantOf(workspace) then
		local bottom = pad.Position.Y - pad.Size.Y / 2
		local cf = CFrame.new(pad.Position.X, bottom + 0.06, pad.Position.Z) * pad.CFrame.Rotation
		local r = newPart(rims, "BounceRim_" .. pad.Name, Vector3.new(pad.Size.X + 1.6, 0.12, pad.Size.Z + 1.6), cf, VIOLET, Enum.Material.Neon)
		hook(r, "BounceRim", { "BOUNCY", "SUPER_BOUNCE" }, "new")
	end
end

-- SLIPPERY / SLIDE_FIELD: floor-edge rims around the four Reservoir slip pads
local slips = group("SlipPerimeter")
for _, pad in CS:GetTagged("SlipSurface") do
	if pad:IsA("BasePart") and pad:IsDescendantOf(workspace) and pad.Name:sub(1, 9) == "SLIP_RES_" then
		local bottom = pad.Position.Y - pad.Size.Y / 2
		local cf = CFrame.new(pad.Position.X, bottom + 0.04, pad.Position.Z) * pad.CFrame.Rotation
		local r = newPart(slips, "SlipRim_" .. pad.Name, Vector3.new(pad.Size.X + 1.6, 0.08, pad.Size.Z + 1.6), cf, ICE, Enum.Material.Glass)
		hook(r, "SlipRim", { "SLIPPERY", "SLIDE_FIELD" }, "new")
	end
end

-- CORRUPTION: static glitch bands crossing one seam on each hall wall (hall-wide, deterministic)
local glitch = group("HallGlitch")
local SEAMS = {
	{ "Seam_N0", Vector3.new(0, 0, 1) }, -- inward normal
	{ "Seam_E-1", Vector3.new(-1, 0, 0) },
	{ "Seam_S2", Vector3.new(0, 0, -1) },
	{ "Seam_W1", Vector3.new(1, 0, 0) },
}
for _, s in SEAMS do
	local seam = path("Megastructure", "Detail", s[1]) :: BasePart
	local n: Vector3 = s[2]
	local along = Vector3.new(0, 1, 0):Cross(n) -- horizontal along the wall
	local base = Vector3.new(seam.Position.X, 0, seam.Position.Z) + n * 0.35
	local function band(name: string, len: number, h: number, y: number, shift: number, color: Color3, role: string)
		local pos = base + along * shift + Vector3.new(0, y, 0)
		local cf = CFrame.fromMatrix(pos, along, Vector3.new(0, 1, 0))
		local p = newPart(glitch, name, Vector3.new(len, h, 0.3), cf, color, Enum.Material.Neon)
		hook(p, role, { "CORRUPTION" }, "new")
	end
	-- three offset bars per wall (hall scale: readable from the arena floor, still thin bars, not panels)
	band("GlitchBandA_" .. s[1], 64, 2.4, 104, -10, MAGENTA, "GlitchA")
	band("GlitchBandB_" .. s[1], 40, 1.4, 109, 14, VIOLET, "GlitchB")
	band("GlitchBandC_" .. s[1], 24, 0.8, 99.5, 26, MAGENTA, "GlitchB")
end

-- FLOATING_DEBRIS: one small anchored grouping above the Reservoir basin (north-east, clear of the
-- bridges at Y 23-24, the supply column at (0, 252) and the pump rings at Z 225)
local debris = group("ReservoirDebris")
local DEBRIS_SPEC = {
	-- offset from centre, size, rotation (deg), chip?
	{ Vector3.new(0, 0, 0), Vector3.new(4, 1.2, 3), Vector3.new(12, 30, 8), false },
	{ Vector3.new(5, 2.5, -3), Vector3.new(2.5, 2, 2), Vector3.new(35, 10, 20), false },
	{ Vector3.new(-5, 1.5, 3), Vector3.new(3, 0.8, 2.2), Vector3.new(-15, 60, 5), false },
	{ Vector3.new(2, 5, 4), Vector3.new(1.6, 1.6, 1.6), Vector3.new(45, 45, 0), false },
	{ Vector3.new(-3, 4.5, -4), Vector3.new(2.2, 1, 1.4), Vector3.new(0, 20, 40), false },
	{ Vector3.new(8, -1, 2), Vector3.new(1.4, 1.4, 2.6), Vector3.new(20, -30, 15), false },
	{ Vector3.new(-1, 2.5, 1), Vector3.new(0.8, 0.8, 0.8), Vector3.new(30, 15, 45), true },
	{ Vector3.new(4, 6.5, 0), Vector3.new(0.6, 0.6, 0.6), Vector3.new(10, 50, 25), true },
}
local DEBRIS_CENTRE = Vector3.new(38, 36, 172)
local debrisLightHost: BasePart? = nil
for i, s in DEBRIS_SPEC do
	local rot = s[3] :: Vector3
	local cf = CFrame.new(DEBRIS_CENTRE + s[1]) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	local chip = s[4]
	local p = newPart(debris, (if chip then "DebrisChip_" else "Debris_") .. i, s[2], cf, if chip then VIOLET else DEBRIS, if chip then Enum.Material.Neon else Enum.Material.Metal)
	hook(p, if chip then "DebrisChip" else "Debris", { "FLOATING_DEBRIS" }, "new")
	if i == 1 then
		debrisLightHost = p
	end
end
local function newLight(parent: Instance, name: string, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Name = name
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Enabled = false -- normally disabled
	l:SetAttribute("Env8A2C", "new")
	l.Parent = parent
	newLights += 1
	return l
end
hook(newLight(assert(debrisLightHost), "EnvFX_DebrisLight", VIOLET, 18, 1.5), "DebrisLight", { "FLOATING_DEBRIS" }, "new")

-- MAGNETIC: a coil clamp around the middle of each outer Archive cable tray (hidden at baseline),
-- each hosting a normally-disabled violet light. The lights live on the new EnvFX parts, so the
-- Data Archive's own 8A-2b light cap (8) is unchanged.
table.sort(trays, function(a, b)
	return (a :: BasePart).Position.X < (b :: BasePart).Position.X
end)
local coils = group("ArchiveCoils")
for i, tray in { trays[1], trays[#trays] } do
	local t = tray :: BasePart
	local cf = t.CFrame * CFrame.Angles(0, math.rad(90), 0) -- cylinder axis (X) along the tray length
	local c = newPart(coils, "MagCoil_" .. i, Vector3.new(1.2, 3.2, 3.2), cf, VIOLET, Enum.Material.Neon)
	c.Shape = Enum.PartType.Cylinder
	hook(c, "MagCoil", { "MAGNETIC" }, "new")
	hook(newLight(c, "EnvFX_MagLight", VIOLET, 30, 1.6), "MagLight", { "MAGNETIC" }, "new")
end

-- HUNTER_SCAN: one static scan Beam between the spire beacons (disabled at baseline; no motion)
local a0 = Instance.new("Attachment")
a0.Name = "EnvFX_ScanA"
a0:SetAttribute("Env8A2C", "new")
a0.Parent = beacons[1]
local a1 = Instance.new("Attachment")
a1.Name = "EnvFX_ScanB"
a1:SetAttribute("Env8A2C", "new")
a1.Parent = beacons[2]
newOther += 2
local beam = Instance.new("Beam")
beam.Name = "EnvFX_ScanBeam"
beam.Attachment0 = a0
beam.Attachment1 = a1
beam.Color = ColorSequence.new(Color3.fromRGB(255, 111, 97))
beam.Transparency = NumberSequence.new(0.25)
beam.LightEmission = 1
beam.Width0 = 1.1
beam.Width1 = 1.1
beam.FaceCamera = true
beam.Segments = 1
beam.Enabled = false
beam:SetAttribute("Env8A2C", "new")
beam.Parent = beacons[1]
newBeams += 1
hook(beam, "ScanBeam", { "HUNTER_SCAN" }, "new")

fx.Parent = map

assert(newParts <= 40, "new part limit")
assert(newLights <= 4, "new light limit")
assert(newBeams <= 1, "new beam limit")

---------------------------------------------------------------------------------------------------
-- 3. Rollback record
local store = Instance.new("Folder")
store.Name = "WORLD_EXE_Rollback8A2C"
store:SetAttribute("BuiltAt", DateTime.now():ToIsoDate())
store:SetAttribute("ExistingHooks", hookCount)
store:SetAttribute("NewParts", newParts)
store:SetAttribute("NewLights", newLights)
store:SetAttribute("NewBeams", newBeams)
store:SetAttribute("NewAttachments", newOther)
store:SetAttribute("PreexistingBaseAttributes", 0)
store:SetAttribute("PreexistingEnvFXTags", 0)
store:SetAttribute("Note", "8A-2c work is marked Env8A2C=hook|new; 2_rollback.luau removes exactly that")
store.Parent = ServerStorage

local rc = {}
for k, v in roleCounts do
	table.insert(rc, k .. "=" .. v)
end
table.sort(rc)
return string.format("8A-2c built: hooks %d existing, new parts %d, lights %d, beams %d, attachments %d | %s", hookCount, newParts, newLights, newBeams, newOther, table.concat(rc, ", "))
end

-- Any failure undoes the partial build before reporting the error.
local ok, result = pcall(build)
if not ok then
	undo()
	error("8A-2c build failed and was undone: " .. tostring(result))
end
return result

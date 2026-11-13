-- WORLD.EXE ENV_SLICE1 step 1: idempotent construction (Studio EDIT mode, via Studio MCP execute_luau).
-- Builds exactly the owner-approved first production map slice (approval 2026-11-13, evidence
-- WORLD-EXE-Dev-HQ PR #11 and PR #12):
--   Map.EnvSlice1.TraversalLink_SkyLandingS_BridgeE   17 parts, 9 collidable  (EnvSlice1 = "TraversalLinks")
--   Map.EnvSlice1.ExteriorScenery_E10Spire            24 parts, 0 collidable  (EnvSlice1 = "ExteriorScenery")
-- Changes against the reviewed prototype (PR #11):
--   v1 (owner-approved before construction): EdgeRail_North is 18 studs (X 122..140) instead of 28,
--      because east of X 140 it blocked the drop-down onto SkyBase (C13); SupportPylon_A / _B
--      (non-collidable, like the existing SharedSupports pylons) carry three slabs that had no support
--      within 30 studs (AC6).
--   v2 (review correction, 2026-11-13): Spawn_RES_2 sightline. Walk_4's west edge moves from X 82 to
--      82.5 (Walk_3 trimmed to match) and ReservoirLanding is trimmed to X 75..90.5, Z 188..202 (was
--      75..93, 188..206), with its edge trim and beacon moved with it. This clears two of the four
--      reactor-benchmark sight lines the slice blocked from Spawn_RES_2 (13% -> 18%; pre-slice 23%).
--      The other two cross the only possible join between Walk_4 and Bridge_E (see README).
-- Rules:
--   * Creates only Map.EnvSlice1 and the Map attribute "EnvSlice1". No existing instance is moved,
--     resized, re-tagged, re-attributed or deleted. No scripts, tags or lights are created.
--   * Every new part carries EnvSlice1 = <category>. Collidable parts carry exactly one role:
--     WalkSurface (walkable floor slab) or EdgeRail (4-stud safety rail on a void-facing edge).
--     Decorative parts have CanCollide, CanQuery, CanTouch and CastShadow off.
--   * Idempotent: if Map.EnvSlice1 already matches this specification exactly (geometry, appearance,
--     physics and query flags, attributes, no extra instances) nothing is changed. If slice content
--     exists in any other form, including an older version, the script stops with an error and
--     changes nothing (run 9_rollback.luau first).
--   * Geometry is absolute; the anchors it joins or must clear are asserted first.
-- Order: 1_build -> phase8a2b/6_audit (read-only, EnvSlice1-aware) -> focused Play tests (README).
-- Recovery: 9_rollback.luau.
local root = workspace:WaitForChild("WORLD_EXE")
local map = root:WaitForChild("Map")
local V = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material
local VERSION = "v2 2026-11-13"

assert(root:GetAttribute("ArenaVersion") == 3, "expected ArenaVersion 3")
assert(map:GetAttribute("Phase8A2B") ~= nil, "expected the finalized Phase 8A-2b arena")

-- Anchors. A moved or resized anchor invalidates the reviewed geometry.
local function anchor(name: string, pos: Vector3, size: Vector3)
	local found
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d.Name == name and (d.Position - pos).Magnitude < 0.01 then
			assert(found == nil, "duplicate anchor " .. name)
			found = d
		end
	end
	assert(found, "anchor missing or moved: " .. name)
	assert((found.Size - size).Magnitude < 0.01, "anchor resized: " .. name)
end
anchor("SkyLanding_S", V(193.5, 23, 129), V(87, 2, 22)) -- west face X 150: joined by Walk_1
anchor("Bridge_E", V(41, 23, 200), V(68, 2, 12)) -- east end X 75: joined by ReservoirLanding
anchor("RingRamp_E", V(100, 11.0715, 193.3714), V(12, 2, 64.622)) -- cleared by Walk_3 / Walk_4
anchor("Rim_N", V(0, -2, 147.5), V(260, 4, 15)) -- rim edge X 130: Walk_2 east edge
anchor("Rim_E", V(102.5, -2, 200), V(55, 4, 90))
anchor("SkyBase", V(170, -2, 0), V(60, 4, 260))
anchor("WinSill_E10", V(407, 72.5, 191.0769), V(63.2923, 25, 14)) -- window the spire is framed by

local FLOOR = { RGB(30, 36, 60), M.SmoothPlastic }
local RAIL = { RGB(84, 96, 130), M.Metal }
local PYLON = { RGB(58, 68, 100), M.Metal }
local CYAN = { RGB(0, 200, 255), M.Neon }
local VIOLET = { RGB(120, 70, 255), M.Neon }
local STONE = { RGB(138, 134, 138), M.Slate }
local DEEP = { RGB(48, 66, 112), M.Slate }
local PLATE = { RGB(104, 130, 172), M.Metal }
local FRAME = { RGB(198, 204, 216), M.Metal }

-- { name, size, position, look, role?, orientation (degrees, CFrame.fromOrientation order)? }
local SPEC = {
	{
		model = "TraversalLink_SkyLandingS_BridgeE",
		category = "TraversalLinks",
		parts = {
			{ "CutThrough_Walk_1", V(20, 2, 8), V(140, 23, 135), FLOOR, "WalkSurface" },
			{ "CutThrough_Walk_2", V(8, 2, 30), V(126, 23, 146), FLOOR, "WalkSurface" },
			{ "CutThrough_Walk_3", V(39.5, 2, 8), V(102.25, 23, 157), FLOOR, "WalkSurface" },
			{ "CutThrough_Walk_4", V(8, 2, 27), V(86.5, 23, 174.5), FLOOR, "WalkSurface" },
			{ "ReservoirLanding", V(15.5, 2, 14), V(82.75, 23, 195), FLOOR, "WalkSurface" },
			{ "EdgeRail_North", V(18, 4, 0.4), V(131, 26, 131.2), RAIL, "EdgeRail" },
			{ "EdgeRail_South", V(20, 4, 0.4), V(140, 26, 138.8), RAIL, "EdgeRail" },
			{ "EdgeRail_West", V(0.4, 4, 8.6), V(122.2, 26, 135.7), RAIL, "EdgeRail" },
			{ "EdgeRail_East", V(0.4, 4, 22), V(129.8, 26, 150), RAIL, "EdgeRail" },
			{ "GuideTrim_Walk_1", V(24, 0.2, 0.3), V(138, 24.05, 135), CYAN },
			{ "GuideTrim_Walk_2", V(0.3, 0.2, 21.85), V(126, 24.05, 146.075), CYAN },
			{ "GuideTrim_Walk_3", V(39.35, 0.2, 0.3), V(106.175, 24.05, 157), CYAN },
			{ "GuideTrim_Walk_4", V(0.3, 0.2, 30.85), V(86.5, 24.05, 172.575), CYAN },
			{ "EdgeTrim_Landing_N", V(15.5, 0.2, 0.3), V(82.75, 24.05, 201.85), CYAN },
			{ "LandingBeacon", V(1, 10, 1), V(90, 29, 201), CYAN },
			{ "SupportPylon_A", V(3, 22, 3), V(126, 11, 157), PYLON },
			{ "SupportPylon_B", V(3, 22, 3), V(86, 11, 159), PYLON },
		},
	},
	{
		model = "ExteriorScenery_E10Spire",
		category = "ExteriorScenery",
		parts = {
			{ "Spire_Lower", V(22, 68, 22), V(447, 74, 208), STONE },
			{ "Spire_Band_1", V(24, 3, 24), V(447, 90, 208), PLATE },
			{ "Spire_Band_2", V(24, 3, 24), V(447, 102, 208), PLATE },
			{ "Spire_Upper", V(20, 34, 20), V(449, 136, 212), DEEP, nil, V(6.8931, 10.0736, 1.2214) },
			{ "Lattice_Vert_1", V(2, 12, 2), V(439, 113.5, 200), FRAME },
			{ "Lattice_Vert_2", V(2, 12, 2), V(455, 113.5, 200), FRAME },
			{ "Lattice_Vert_3", V(2, 12, 2), V(455, 113.5, 216), FRAME },
			{ "Lattice_Vert_4", V(2, 12, 2), V(439, 113.5, 216), FRAME },
			{ "Lattice_Front", V(1.6, 1.6, 20), V(439, 113, 208), FRAME },
			{ "Lattice_Back", V(1.6, 1.6, 20), V(455, 113, 208), FRAME },
			{ "Lattice_Left", V(16, 1.6, 1.6), V(447, 113, 200), FRAME },
			{ "Lattice_Right", V(16, 1.6, 1.6), V(447, 113, 216), FRAME },
			{ "Lattice_Stub", V(1.6, 1.6, 9), V(439, 110, 221.5), FRAME },
			{ "Fragment_1", V(7, 7, 7), V(443, 124, 221), STONE },
			{ "Fragment_2", V(5, 5, 5), V(441, 136, 223), PLATE },
			{ "Fragment_3", V(3.5, 3.5, 3.5), V(440, 148, 220), STONE },
			{ "Fragment_4", V(2.5, 2.5, 2.5), V(439, 158, 224), PLATE },
			{ "Signal_Trunk", V(0.6, 60, 1), V(435.7, 78, 205), CYAN },
			{ "Signal_Tick_1", V(0.6, 0.8, 6), V(435.7, 92, 208), CYAN },
			{ "Signal_Tick_2", V(0.6, 0.8, 6), V(435.7, 100, 208), CYAN },
			{ "Signal_DeadDash", V(0.6, 4, 1), V(438, 113, 205), VIOLET },
			{ "Signal_DeadLine", V(0.6, 20, 1), V(438.6, 136, 209), VIOLET, nil, V(7, 0, 0) },
			{ "Ghost_Edge_1", V(0.6, 0.6, 10), V(441, 108, 223), VIOLET },
			{ "Ghost_Edge_2", V(0.6, 10, 0.6), V(441, 113, 228), VIOLET },
		},
	},
}

local function cframeOf(row): CFrame
	local o = row[6]
	if o then
		return CFrame.new(row[3]) * CFrame.fromOrientation(math.rad(o.X), math.rad(o.Y), math.rad(o.Z))
	end
	return CFrame.new(row[3])
end

-- The single source of every non-geometric property. build() applies it; matches() compares to it,
-- so the idempotency check cannot drift from what the builder creates.
local function expected(row, category: string)
	local role = row[5]
	local attrs = { EnvSlice1 = category }
	if role then
		attrs[role] = true
	end
	return {
		props = {
			Color = row[4][1],
			Material = row[4][2],
			Anchored = true,
			CanCollide = role ~= nil,
			CanQuery = role ~= nil,
			CanTouch = false,
			CastShadow = false,
			Transparency = 0,
			Reflectance = 0,
			Massless = false,
			Locked = false,
			Shape = Enum.PartType.Block,
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
		},
		attrs = attrs,
	}
end
local PROP_ORDER = { "Color", "Material", "Anchored", "CanCollide", "CanQuery", "CanTouch", "CastShadow", "Transparency", "Reflectance", "Massless", "Locked", "Shape", "TopSurface", "BottomSurface" }

-- Existing slice content: accept only an exact match of this specification.
local function sameAttrs(inst: Instance, want: { [string]: any }): boolean
	local have = inst:GetAttributes()
	for k, v in want do
		if have[k] ~= v then
			return false
		end
	end
	for k in have do
		if want[k] == nil then
			return false
		end
	end
	return true
end
local function matches(folder: Instance): (boolean, string)
	if not folder:IsA("Folder") or #folder:GetChildren() ~= #SPEC or next(folder:GetAttributes()) ~= nil then
		return false, "unexpected container"
	end
	local CS = game:GetService("CollectionService")
	if #CS:GetTags(folder) > 0 then
		return false, "container has tags"
	end
	for _, group in SPEC do
		local model = folder:FindFirstChild(group.model)
		if not (model and model.ClassName == "Model") or #model:GetChildren() ~= #group.parts then
			return false, "model " .. group.model
		end
		if not sameAttrs(model, { EnvSlice1Category = group.category }) or #CS:GetTags(model) > 0 then
			return false, "attributes or tags of model " .. group.model
		end
		for _, row in group.parts do
			local found = 0
			for _, c in model:GetChildren() do
				if c.Name == row[1] then
					found += 1
				end
			end
			local p = model:FindFirstChild(row[1])
			if found ~= 1 or not (p and p.ClassName == "Part") then
				return false, "missing or duplicate " .. row[1]
			end
			local cf = cframeOf(row)
			if (p.Size - row[2]).Magnitude > 0.001 or (p.Position - cf.Position).Magnitude > 0.001 or (p.CFrame.LookVector - cf.LookVector).Magnitude > 0.001 or (p.CFrame.UpVector - cf.UpVector).Magnitude > 0.001 then
				return false, "geometry of " .. row[1]
			end
			local want = expected(row, group.category)
			for _, k in PROP_ORDER do
				if (p :: any)[k] ~= want.props[k] then
					return false, k .. " of " .. row[1]
				end
			end
			if not sameAttrs(p, want.attrs) then
				return false, "attributes of " .. row[1]
			end
			if #p:GetChildren() ~= 0 or #CS:GetTags(p) > 0 then
				return false, "children or tags on " .. row[1]
			end
		end
	end
	return true, ""
end

local existing = map:FindFirstChild("EnvSlice1")
local stray = 0
for _, d in workspace:GetDescendants() do
	if (d:GetAttribute("EnvSlice1") ~= nil or string.find(d.Name, "^EnvSlice1")) and d ~= map and not (existing and (d == existing or d:IsDescendantOf(existing))) then
		stray += 1
	end
end
assert(stray == 0, string.format("%d EnvSlice1 instance(s) exist outside Map.EnvSlice1; run 9_rollback.luau first", stray))
if existing then
	local ok, why = matches(existing)
	assert(ok, "Map.EnvSlice1 exists but differs from the " .. VERSION .. " specification (" .. why .. "); nothing changed; run 9_rollback.luau first")
	assert(map:GetAttribute("EnvSlice1") == VERSION, "Map.EnvSlice1 matches the specification but the Map attribute reads " .. tostring(map:GetAttribute("EnvSlice1")))
	return string.format("ENV_SLICE1 already built (%s); nothing changed", VERSION)
end

-- Build off-tree, then parent once.
local folder = Instance.new("Folder")
folder.Name = "EnvSlice1"
local parts, collidable = 0, 0
for _, group in SPEC do
	local model = Instance.new("Model")
	model.Name = group.model
	model:SetAttribute("EnvSlice1Category", group.category)
	for _, row in group.parts do
		local want = expected(row, group.category)
		local p = Instance.new("Part")
		p.Name = row[1]
		p.Size = row[2]
		p.CFrame = cframeOf(row)
		for _, k in PROP_ORDER do
			(p :: any)[k] = want.props[k]
		end
		for k, v in want.attrs do
			p:SetAttribute(k, v)
		end
		if p.CanCollide then
			collidable += 1
		end
		p.Parent = model
		parts += 1
	end
	model.Parent = folder
end
local ok, why = matches(folder)
assert(ok, "internal: freshly built slice does not match its own specification (" .. why .. ")")
folder.Parent = map
map:SetAttribute("EnvSlice1", VERSION)
return string.format("ENV_SLICE1 built (%s): %d parts, %d collidable, in %s", VERSION, parts, collidable, folder:GetFullName())

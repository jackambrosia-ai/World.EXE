-- WORLD.EXE ENV_SPRINT2 step 1: idempotent construction (Studio EDIT mode, via Studio MCP execute_luau).
-- THIS IS A TEMPLATE. Do not run it directly: `node assemble.js` inlines traversal_spec.luau and
-- exterior_spec.luau at the two --@@...@@ markers below and writes 1_build.luau. Run that file.
-- Run the assembled file inside task.spawn and poll _G.ENVSPRINT2_BUILD (it yields once per model
-- while parenting); a direct call also works when the runner allows yielding.
--
-- Builds Map.EnvSprint2 (Folder) -> Models Traversal_<Route> (EnvSprint2Category = SprintTraversal)
-- and Exterior_<Scene> (EnvSprint2Category = SprintExterior). Every part carries EnvSprint2 = <category>.
-- Rules (SPRINT_BRIEF.md, owner-approved sprint 2026-11-13):
--   * Creates only Map.EnvSprint2 and the Map attribute "EnvSprint2" = VERSION. No existing instance is
--     moved, resized, re-tagged, re-attributed or deleted. No scripts, tags, meshes or unions.
--   * Collidable iff a role is given: WalkSurface (level, unrotated Block slab >= 4 x 4, joined flush),
--     EdgeRail (unrotated Block, >= 4 studs high) or JumpStep (level, unrotated Block slab >= 4 x 4 in a
--     jump chain; jump-link, chain, headroom and no-void rules are enforced by the audit: C9, C6s, C6j).
--     Roles only in SprintTraversal. CanQuery = CanCollide.
--     CanTouch and CastShadow are always false (CastShadow false also for WalkSurfaces, as in ENV_SLICE1:
--     thin floating slabs would throw new hard shadows across existing gameplay floors and patch
--     telegraphs; consistency with the approved slice; zero shadow-map cost).
--   * Lights: only in SprintExterior, at most one per part, PointLight or SpotLight, Shadows = false.
--   * Budgets enforced before anything is created: SprintTraversal <= 95 parts / 42 collidable / 0 lights,
--     SprintExterior <= 105 / 0 / 2, sprint total <= 200 / 42 / 2, map after <= 2,102 parts / 421
--     collidable / 53 lights.
--   * Idempotent: if Map.EnvSprint2 already matches this specification exactly (geometry; Color, Material,
--     Anchored, CanCollide, CanQuery, CanTouch, CastShadow, Transparency, Reflectance, Massless, Locked,
--     Archivable, CollisionGroup, CustomPhysicalProperties, Shape, all six surfaces; exact attribute sets;
--     no tags; exactly the specified children incl. lights and their properties; model streaming mode;
--     Map attribute = VERSION) nothing is changed. Any other EnvSprint2 content, including an older
--     version or stray content anywhere in Workspace, stops the script with an error and changes nothing
--     (run 9_rollback.luau first).
--   * Builds off-tree, self-checks, then parents model by model (task.wait() between models) and checks
--     the parented result once more before setting the Map attribute.
-- Order: 1_build -> phase8a2b/6_audit (read-only, EnvSprint2-aware) -> focused Play tests (README).
-- Recovery: 9_rollback.luau.
local CS = game:GetService("CollectionService")
local root = workspace:WaitForChild("WORLD_EXE")
local map = root:WaitForChild("Map")
local V = Vector3.new
local VERSION = "v1 2026-11-13" -- bump on every geometry change (an older build is then refused)
local SLICE_VERSION = "v2 2026-11-13" -- the ENV_SLICE1 build the sprint was designed against

local TRAVERSAL_SPEC = (function()
--@@TRAVERSAL_SPEC@@
end)()
local EXTERIOR_SPEC = (function()
--@@EXTERIOR_SPEC@@
end)()

_G.ENVSPRINT2_BUILD = { status = "running" }
local function fail(msg: string)
	_G.ENVSPRINT2_BUILD = { status = "refused", result = msg }
	error(msg, 0)
end

assert(root:GetAttribute("ArenaVersion") == 3, "expected ArenaVersion 3")
assert(map:GetAttribute("Phase8A2B") ~= nil, "expected the finalized Phase 8A-2b arena")
if map:GetAttribute("EnvSlice1") ~= SLICE_VERSION then
	fail("expected ENV_SLICE1 " .. SLICE_VERSION .. " in the map (found " .. tostring(map:GetAttribute("EnvSlice1")) .. ")")
end
if type(TRAVERSAL_SPEC) ~= "table" or type(EXTERIOR_SPEC) ~= "table" then
	fail("spec tables missing: run `node assemble.js` and execute the generated 1_build.luau, not the template")
end

---------------------------------------------------------------------------------------------------
-- Policy tables (kept in one place; the audit enforces the same values independently).
local CATEGORY_OF_PREFIX = { Traversal = "SprintTraversal", Exterior = "SprintExterior" }
local STREAMING = { -- see agentC/REVIEW_NOTES.md (streaming)
	SprintTraversal = Enum.ModelStreamingMode.Default,
	SprintExterior = Enum.ModelStreamingMode.Atomic,
}
local CAP = { SprintTraversal = { 95, 42, 0 }, SprintExterior = { 105, 0, 2 } }
local SPRINT_CAP = { 200, 42, 2 }
local MAP_CAP = { 2102, 421, 53 }
local BOUNDS_MIN, BOUNDS_MAX = V(-275, -40, -275), V(275, 160, 275) -- Config.ArenaBoundsMin / Max
local SHAPES = { Block = Enum.PartType.Block, Wedge = Enum.PartType.Wedge, Cylinder = Enum.PartType.Cylinder, Ball = Enum.PartType.Ball }
local CLASSES = { Part = true, WedgePart = true, CornerWedgePart = true }
local LIGHT_CLASSES = { PointLight = true, SpotLight = true }
local BANNED_MATERIALS = { Air = true, Water = true, ForceField = true }
local ROW_EXTRA_KEYS = { light = true, shape = true, class = true, transparency = true, reservedUse = true }
local LIGHT_KEYS = { class = true, range = true, brightness = true, color = true, angle = true, face = true }
local GROUP_KEYS = { model = true, category = true, parts = true, anchors = true }
-- Names the audit or gameplay code treat specially (C11 neon exemption, C6 structure exemption,
-- AC6 slab list, C12 rack gaps). A sprint part must never inherit those meanings by name.
local RESERVED_NAMES = { EnergyCore = true, HubEmitter = true, CrownEmitter = true }
for _, n in { "Catwalk_N", "Catwalk_S", "RackDeck_NW", "RackDeck_NE", "ArchiveWalk_S", "SkyDeck", "SkyLanding_N", "SkyLanding_S", "Island_N", "Island_S", "Bridge_W", "Bridge_E", "BridgeLink_W", "BridgeLink_E", "Ring_N", "Ring_S", "Ring_W", "Ring_E", "CorePlaza", "Mezz_N", "Mezz_S", "Mezz_E", "Mezz_W", "Gantry_N_Bridge", "Gantry_E_Bridge" } do
	RESERVED_NAMES[n] = true
end
local RESERVED_PATTERNS = { "^Step_%d", "^Rack_", "^Column_", "^ButtressPlinth_", "^EnvSlice1", "^EnvSprint2", "^SupplyCrate_", "^Spawn_" }

---------------------------------------------------------------------------------------------------
-- Spec validation and normalisation. Collects every problem, then refuses with the list.
local problems = {}
local function problem(s: string)
	table.insert(problems, s)
end
local function finite(n: any): boolean
	return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
local function isVec(v: any): boolean
	return typeof(v) == "Vector3" and finite(v.X) and finite(v.Y) and finite(v.Z)
end
local function rgb(c: any, where: string): Color3?
	if type(c) ~= "table" or #c ~= 3 then
		problem(where .. ": colour must be {r, g, b}")
		return nil
	end
	for i = 1, 3 do
		local x = c[i]
		if not finite(x) or x < 0 or x > 255 or x % 1 ~= 0 then
			problem(where .. ": colour component " .. i .. " must be an integer 0..255")
			return nil
		end
	end
	return Color3.fromRGB(c[1], c[2], c[3])
end
local function sortedDims(s: Vector3): { number }
	local d = { s.X, s.Y, s.Z }
	table.sort(d)
	return d
end

type Rec = { name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, role: string?, class: string, shape: Enum.PartType?, transparency: number, reservedUse: string?, light: { [string]: any }? }
type Group = { model: string, category: string, recs: { Rec }, anchors: { any }? }

local GROUPS: { Group } = {}
local modelNames = {}
local function readSpec(spec: any, expectCategory: string, label: string)
	if type(spec) ~= "table" or #spec == 0 then
		problem(label .. ": must return a non-empty list of model groups")
		return
	end
	for k in spec do
		if type(k) ~= "number" or k < 1 or k > #spec or k % 1 ~= 0 then
			problem(label .. ": unexpected top-level key " .. tostring(k))
		end
	end
	for gi, g in ipairs(spec) do
		local gw = label .. " group " .. gi
		if type(g) ~= "table" then
			problem(gw .. ": not a table")
			continue
		end
		for k in g do
			if not GROUP_KEYS[k] then
				problem(gw .. ": unknown key " .. tostring(k))
			end
		end
		local mname = g.model
		if type(mname) ~= "string" then
			problem(gw .. ": model name missing")
			continue
		end
		gw = label .. " " .. mname
		local prefix = string.match(mname, "^(%a+)_[%w_]+$")
		if not prefix or CATEGORY_OF_PREFIX[prefix] ~= g.category or g.category ~= expectCategory or #mname > 60 then
			problem(gw .. ": model must be named " .. (if expectCategory == "SprintTraversal" then "Traversal_<Name>" else "Exterior_<Name>") .. " with category " .. expectCategory .. " (got " .. tostring(g.category) .. ")")
		end
		if modelNames[mname] then
			problem(gw .. ": duplicate model name")
		end
		modelNames[mname] = true
		if g.anchors ~= nil and type(g.anchors) ~= "table" then
			problem(gw .. ": anchors must be a list of { name, position, size }")
		end
		if type(g.parts) ~= "table" or #g.parts == 0 then
			problem(gw .. ": parts must be a non-empty list")
			continue
		end
		local group: Group = { model = mname, category = expectCategory, recs = {}, anchors = g.anchors }
		local names = {}
		for ri, row in ipairs(g.parts) do
			local w = gw .. " row " .. ri
			if type(row) ~= "table" then
				problem(w .. ": not a table")
				continue
			end
			for k in row do
				if type(k) ~= "number" or k < 1 or k > 8 or k % 1 ~= 0 then
					problem(w .. ": unexpected key " .. tostring(k))
				end
			end
			local name, size, pos, col, mat, role, orient, extra = row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8]
			if type(name) ~= "string" or not string.match(name, "^%a[%w_]*$") or #name > 60 then
				problem(w .. ": part name must match ^%a[%w_]*$ (max 60)")
				continue
			end
			w = gw .. "." .. name
			if names[name] then
				problem(w .. ": duplicate part name in model")
			end
			names[name] = true
			if RESERVED_NAMES[name] then
				problem(w .. ": reserved name")
			end
			for _, pat in RESERVED_PATTERNS do
				if string.find(name, pat) then
					problem(w .. ": reserved name pattern " .. pat)
				end
			end
			if not isVec(size) or size.X < 0.05 or size.Y < 0.05 or size.Z < 0.05 or size.X > 2048 or size.Y > 2048 or size.Z > 2048 then
				problem(w .. ": size must be a Vector3 with components 0.05..2048")
				continue
			end
			if not isVec(pos) then
				problem(w .. ": position must be a finite Vector3")
				continue
			end
			if orient ~= nil and not isVec(orient) then
				problem(w .. ": orientation must be nil or a finite Vector3 (degrees)")
				continue
			end
			local color = rgb(col, w)
			local material: Enum.Material? = nil
			if type(mat) == "string" and not BANNED_MATERIALS[mat] then
				local ok, m = pcall(function()
					return (Enum.Material :: any)[mat]
				end)
				if ok and typeof(m) == "EnumItem" then
					material = m
				end
			end
			if not material then
				problem(w .. ": invalid material " .. tostring(mat))
			end
			if role ~= nil and role ~= "WalkSurface" and role ~= "EdgeRail" and role ~= "JumpStep" then
				problem(w .. ": role must be nil, WalkSurface, EdgeRail or JumpStep (got " .. tostring(role) .. ")")
			end
			if extra ~= nil and type(extra) ~= "table" then
				problem(w .. ": extra must be nil or a table")
				extra = nil
			end
			extra = extra or {}
			for k in extra do
				if not ROW_EXTRA_KEYS[k] then
					problem(w .. ": unknown extra key " .. tostring(k))
				end
			end
			local class = extra.class or "Part"
			if not CLASSES[class] then
				problem(w .. ": class must be Part, WedgePart or CornerWedgePart")
			end
			local shape: Enum.PartType? = nil
			if class == "Part" then
				shape = SHAPES[extra.shape or "Block"]
				if not shape then
					problem(w .. ": shape must be Block, Wedge, Cylinder or Ball")
				end
			elseif extra.shape ~= nil then
				problem(w .. ": shape is only valid for class Part")
			end
			if shape == Enum.PartType.Ball and (math.abs(size.X - size.Y) > 1e-6 or math.abs(size.X - size.Z) > 1e-6) then
				problem(w .. ": a Ball must have a uniform size (Roblox would resize it)")
			end
			local transparency = extra.transparency or 0
			if not finite(transparency) or transparency < 0 or transparency >= 1 then
				problem(w .. ": transparency must be in [0, 1)")
				transparency = 0
			end
			if extra.reservedUse ~= nil and (type(extra.reservedUse) ~= "string" or extra.reservedUse == "") then
				problem(w .. ": reservedUse must be a non-empty string")
			end
			if material == Enum.Material.Neon and sortedDims(size)[2] > 4 then
				problem(w .. ": Neon with two dimensions > 4 (audit C11)")
			end
			local cf = CFrame.new(pos)
			if orient then
				cf = cf * CFrame.fromOrientation(math.rad(orient.X), math.rad(orient.Y), math.rad(orient.Z))
			end
			if role then
				if expectCategory ~= "SprintTraversal" then
					problem(w .. ": collidable roles are only allowed in SprintTraversal")
				end
				if class ~= "Part" or shape ~= Enum.PartType.Block then
					problem(w .. ": a " .. role .. " must be a Block Part")
				end
				if orient and orient.Magnitude > 1e-9 then
					problem(w .. ": a " .. role .. " must be unrotated")
				end
				if transparency ~= 0 then
					problem(w .. ": a " .. role .. " must be opaque")
				end
				if (role == "WalkSurface" or role == "JumpStep") and (size.X < 4 or size.Z < 4) then
					problem(w .. ": a " .. role .. " must be at least 4 x 4")
				end
				if role == "EdgeRail" and size.Y < 4 then
					problem(w .. ": an EdgeRail must be at least 4 studs high (1.2-stud rails do not stop a character)")
				end
				local lo, hi = pos - size / 2, pos + size / 2
				local headroom = if role == "EdgeRail" then 0 else 6
				if lo.X < BOUNDS_MIN.X or lo.Y < BOUNDS_MIN.Y or lo.Z < BOUNDS_MIN.Z or hi.X > BOUNDS_MAX.X or hi.Y + headroom > BOUNDS_MAX.Y or hi.Z > BOUNDS_MAX.Z then
					problem(w .. ": collidable outside Config.ArenaBounds")
				end
			end
			local light = nil
			if extra.light ~= nil then
				local L = extra.light
				if expectCategory ~= "SprintExterior" then
					problem(w .. ": lights are only allowed in SprintExterior (SprintTraversal cap is 0)")
				end
				if type(L) ~= "table" then
					problem(w .. ": light must be a table")
				else
					for k in L do
						if not LIGHT_KEYS[k] then
							problem(w .. ": unknown light key " .. tostring(k))
						end
					end
					if not LIGHT_CLASSES[L.class] then
						problem(w .. ": light class must be PointLight or SpotLight")
					end
					if not finite(L.range) or L.range <= 0 or L.range > 60 then
						problem(w .. ": light range must be in (0, 60]")
					end
					if not finite(L.brightness) or L.brightness <= 0 or L.brightness > 10 then
						problem(w .. ": light brightness must be in (0, 10]")
					end
					local lc = rgb(L.color, w .. " light")
					local angle, face = nil, nil
					if L.class == "SpotLight" then
						angle = L.angle or 90
						if not finite(angle) or angle < 0 or angle > 180 then
							problem(w .. ": spot angle must be in [0, 180]")
						end
						local fname = L.face or "Front"
						local ok, f = pcall(function()
							return (Enum.NormalId :: any)[fname]
						end)
						if ok and typeof(f) == "EnumItem" then
							face = f
						else
							problem(w .. ": invalid spot face " .. tostring(fname))
						end
					elseif L.angle ~= nil or L.face ~= nil then
						problem(w .. ": angle / face are only valid for a SpotLight")
					end
					light = { class = L.class, range = L.range, brightness = L.brightness, color = lc, angle = angle, face = face }
				end
			end
			if color and material then
				table.insert(group.recs, { name = name, size = size, cf = cf, color = color, material = material, role = role, class = class, shape = shape, transparency = transparency, reservedUse = extra.reservedUse, light = light })
			end
		end
		table.insert(GROUPS, group)
	end
end
readSpec(TRAVERSAL_SPEC, "SprintTraversal", "traversal_spec")
readSpec(EXTERIOR_SPEC, "SprintExterior", "exterior_spec")

-- Budgets (spec only; the map-after check follows once the map is known to hold no sprint content).
local used = { SprintTraversal = { 0, 0, 0 }, SprintExterior = { 0, 0, 0 } }
for _, g in GROUPS do
	local u = used[g.category]
	for _, r in g.recs do
		u[1] += 1
		if r.role then
			u[2] += 1
		end
		if r.light then
			u[3] += 1
		end
	end
end
local sprint = { 0, 0, 0 }
for cat, u in used do
	for i = 1, 3 do
		sprint[i] += u[i]
		if u[i] > CAP[cat][i] then
			problem(string.format("budget %s %d/%d/%d exceeds %d/%d/%d", cat, u[1], u[2], u[3], CAP[cat][1], CAP[cat][2], CAP[cat][3]))
			break
		end
	end
end
if sprint[1] > SPRINT_CAP[1] or sprint[2] > SPRINT_CAP[2] or sprint[3] > SPRINT_CAP[3] then
	problem(string.format("sprint total %d/%d/%d exceeds %d/%d/%d", sprint[1], sprint[2], sprint[3], SPRINT_CAP[1], SPRINT_CAP[2], SPRINT_CAP[3]))
end
if #problems > 0 then
	fail("ENV_SPRINT2 spec refused, nothing changed (" .. #problems .. " problem(s)): " .. table.concat(problems, "; ", 1, math.min(#problems, 12)))
end

-- Optional anchors per group: { { "PartName", Vector3 position, Vector3 size }, ... }. A moved or
-- resized anchor invalidates the reviewed geometry.
for _, g in GROUPS do
	for _, a in (g.anchors or {}) :: { any } do
		local found = nil
		for _, d in map:GetDescendants() do
			if d:IsA("BasePart") and d.Name == a[1] and isVec(a[2]) and (d.Position - a[2]).Magnitude < 0.01 then
				if found then
					fail("duplicate anchor " .. tostring(a[1]) .. " for " .. g.model)
				end
				found = d
			end
		end
		if not found then
			fail("anchor missing or moved: " .. tostring(a[1]) .. " for " .. g.model)
		end
		if not isVec(a[3]) or ((found :: BasePart).Size - a[3]).Magnitude > 0.01 then
			fail("anchor resized: " .. tostring(a[1]) .. " for " .. g.model)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The single source of every property. build applies it; matches compares to it.
local SURFACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }
local function expected(r: Rec, category: string)
	local attrs: { [string]: any } = { EnvSprint2 = category }
	if r.role then
		attrs[r.role] = true
	end
	if r.reservedUse then
		attrs.ReservedUse = r.reservedUse
	end
	local order = {}
	local props: { [string]: any } = {}
	local function set(k: string, v: any)
		table.insert(order, k)
		props[k] = v
	end
	if r.class == "Part" then
		set("Shape", r.shape) -- first: Shape can resize a part
	end
	set("Color", r.color)
	set("Material", r.material)
	set("Anchored", true)
	set("CanCollide", r.role ~= nil)
	set("CanQuery", r.role ~= nil)
	set("CanTouch", false)
	set("CastShadow", false)
	set("Transparency", r.transparency)
	set("Reflectance", 0)
	set("Massless", false)
	set("Locked", false)
	set("Archivable", true)
	set("CollisionGroup", "Default")
	for _, s in SURFACES do
		set(s, Enum.SurfaceType.Smooth)
	end
	local light = nil
	if r.light then
		local L = r.light
		local lorder = { "Name", "Enabled", "Shadows", "Range", "Brightness", "Color" }
		local lprops: { [string]: any } = { Name = L.class, Enabled = true, Shadows = false, Range = L.range, Brightness = L.brightness, Color = L.color }
		if L.class == "SpotLight" then
			table.insert(lorder, "Angle")
			table.insert(lorder, "Face")
			lprops.Angle = L.angle
			lprops.Face = L.face
		end
		light = { class = L.class, order = lorder, props = lprops }
	end
	return { order = order, props = props, attrs = attrs, light = light }
end

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
local function near(a: number, b: number): boolean
	return math.abs(a - b) <= 1e-3
end
local function sameValue(a: any, b: any): boolean
	if typeof(a) == "number" and typeof(b) == "number" then
		return near(a, b)
	elseif typeof(a) == "Color3" and typeof(b) == "Color3" then
		return near(a.R, b.R) and near(a.G, b.G) and near(a.B, b.B)
	end
	return a == b
end

local function matches(folder: Instance): (boolean, string)
	if not folder:IsA("Folder") or #folder:GetChildren() ~= #GROUPS or next(folder:GetAttributes()) ~= nil or #CS:GetTags(folder) > 0 then
		return false, "unexpected container (class, child count, attributes or tags)"
	end
	for _, g in GROUPS do
		local count = 0
		for _, c in folder:GetChildren() do
			if c.Name == g.model then
				count += 1
			end
		end
		local model = folder:FindFirstChild(g.model)
		if count ~= 1 or not (model and model.ClassName == "Model") then
			return false, "missing or duplicate model " .. g.model
		end
		local m = model :: Model
		if #m:GetChildren() ~= #g.recs or not sameAttrs(m, { EnvSprint2Category = g.category }) or #CS:GetTags(m) > 0 then
			return false, "children, attributes or tags of model " .. g.model
		end
		if m.ModelStreamingMode ~= STREAMING[g.category] or m.PrimaryPart ~= nil then
			return false, "streaming mode or primary part of model " .. g.model
		end
		for _, r in g.recs do
			local n = 0
			for _, c in m:GetChildren() do
				if c.Name == r.name then
					n += 1
				end
			end
			local p = m:FindFirstChild(r.name)
			if n ~= 1 or not (p and p.ClassName == r.class) then
				return false, "missing, duplicate or wrong class " .. g.model .. "." .. r.name
			end
			local part = p :: BasePart
			if (part.Size - r.size).Magnitude > 1e-3 or (part.Position - r.cf.Position).Magnitude > 1e-3 or (part.CFrame.LookVector - r.cf.LookVector).Magnitude > 1e-3 or (part.CFrame.UpVector - r.cf.UpVector).Magnitude > 1e-3 then
				return false, "geometry of " .. r.name
			end
			if part.AssemblyLinearVelocity.Magnitude > 1e-6 or part.AssemblyAngularVelocity.Magnitude > 1e-6 or part.CustomPhysicalProperties ~= nil then
				return false, "velocity or physical properties of " .. r.name
			end
			local want = expected(r, g.category)
			for _, k in want.order do
				if not sameValue((part :: any)[k], want.props[k]) then
					return false, k .. " of " .. r.name
				end
			end
			if not sameAttrs(part, want.attrs) or #CS:GetTags(part) > 0 then
				return false, "attributes or tags of " .. r.name
			end
			local kids = part:GetChildren()
			if want.light then
				local l = kids[1]
				if #kids ~= 1 or l.ClassName ~= want.light.class or #l:GetChildren() ~= 0 or next(l:GetAttributes()) ~= nil or #CS:GetTags(l) > 0 then
					return false, "light under " .. r.name
				end
				for _, k in want.light.order do
					if not sameValue((l :: any)[k], want.light.props[k]) then
						return false, "light " .. k .. " of " .. r.name
					end
				end
			elseif #kids ~= 0 then
				return false, "children under " .. r.name
			end
		end
	end
	return true, ""
end

---------------------------------------------------------------------------------------------------
-- Existing content.
local existing = map:FindFirstChild("EnvSprint2")
local stray = {}
for _, d in workspace:GetDescendants() do
	if (d:GetAttribute("EnvSprint2") ~= nil or d:GetAttribute("EnvSprint2Category") ~= nil or string.find(d.Name, "^EnvSprint2")) and d ~= map and not (existing and (d == existing or d:IsDescendantOf(existing))) then
		table.insert(stray, d:GetFullName())
	end
end
if #stray > 0 then
	fail(string.format("%d EnvSprint2 instance(s) exist outside Map.EnvSprint2 (%s); nothing changed; run 9_rollback.luau first", #stray, table.concat(stray, ", ", 1, math.min(#stray, 6))))
end
if existing then
	local ok, why = matches(existing)
	if not ok then
		fail("Map.EnvSprint2 exists but differs from the " .. VERSION .. " specification (" .. why .. "); nothing changed; run 9_rollback.luau first")
	end
	if map:GetAttribute("EnvSprint2") ~= VERSION then
		fail("Map.EnvSprint2 matches the specification but the Map attribute reads " .. tostring(map:GetAttribute("EnvSprint2")))
	end
	local msg = string.format("ENV_SPRINT2 already built (%s); nothing changed", VERSION)
	_G.ENVSPRINT2_BUILD = { status = "done", result = msg }
	return msg
end
if map:GetAttribute("EnvSprint2") ~= nil then
	fail("Map attribute EnvSprint2 is set but Map.EnvSprint2 is missing; run 9_rollback.luau first")
end

local function mapCounts(): (number, number, number)
	local parts, collide, lights = 0, 0, 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d.CanCollide then
				collide += 1
			end
		elseif d:IsA("Light") then
			lights += 1
		end
	end
	return parts, collide, lights
end
local p0, c0, l0 = mapCounts()
if p0 + sprint[1] > MAP_CAP[1] or c0 + sprint[2] > MAP_CAP[2] or l0 + sprint[3] > MAP_CAP[3] then
	fail(string.format("map after would be %d/%d/%d, cap %d/%d/%d; nothing changed", p0 + sprint[1], c0 + sprint[2], l0 + sprint[3], MAP_CAP[1], MAP_CAP[2], MAP_CAP[3]))
end

---------------------------------------------------------------------------------------------------
-- Build off-tree.
local folder = Instance.new("Folder")
folder.Name = "EnvSprint2"
local models = {}
for _, g in GROUPS do
	local model = Instance.new("Model")
	model.Name = g.model
	model.ModelStreamingMode = STREAMING[g.category]
	model:SetAttribute("EnvSprint2Category", g.category)
	for _, r in g.recs do
		local want = expected(r, g.category)
		local p = Instance.new(r.class) :: BasePart
		p.Name = r.name
		for _, k in want.order do
			(p :: any)[k] = want.props[k]
		end
		p.Size = r.size
		p.CFrame = r.cf
		for k, v in want.attrs do
			p:SetAttribute(k, v)
		end
		if want.light then
			local l = Instance.new(want.light.class)
			for _, k in want.light.order do
				(l :: any)[k] = want.light.props[k]
			end
			l.Parent = p
		end
		p.Parent = model
	end
	model.Parent = folder
	table.insert(models, model)
end
local ok, why = matches(folder)
if not ok then
	folder:Destroy()
	fail("internal: freshly built sprint does not match its own specification (" .. why .. "); nothing changed")
end

-- Parent model by model so Studio stays responsive.
for _, m in models do
	m.Parent = nil
end
folder.Parent = map
for i, m in models do
	m.Parent = folder
	_G.ENVSPRINT2_BUILD = { status = "parenting", done = i, of = #models }
	task.wait()
end
ok, why = matches(folder)
if not ok then
	fail("parented sprint differs from the specification (" .. why .. "); Map attribute NOT set; run 9_rollback.luau")
end
map:SetAttribute("EnvSprint2", VERSION)
local p1, c1, l1 = mapCounts()
local msg = string.format("ENV_SPRINT2 built (%s): SprintTraversal %d/%d/%d, SprintExterior %d/%d/%d; Map %d -> %d parts, %d -> %d collidable, %d -> %d lights", VERSION, used.SprintTraversal[1], used.SprintTraversal[2], used.SprintTraversal[3], used.SprintExterior[1], used.SprintExterior[2], used.SprintExterior[3], p0, p1, c0, c1, l0, l1)
_G.ENVSPRINT2_BUILD = { status = "done", result = msg }
return msg

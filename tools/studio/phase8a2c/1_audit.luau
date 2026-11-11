-- WORLD.EXE Phase 8A-2c audit (Studio Edit, READ-ONLY). Returns a JSON report; "errors" must be empty.
-- Checks: every EnvFX-tagged instance has a role, the 8A-2c marker and valid, type-correct Base_*
-- attributes that equal its current value (the place is at baseline); no hook is a gameplay-tagged or
-- server-owned object; collidable hooks manage Color only; every effect has hooks; new extras are
-- hidden, non-collidable, non-queryable, non-touchable and shadowless; new lights/beam are disabled;
-- Option B limits and the map totals.
local CS = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local root = workspace:WaitForChild("WORLD_EXE")
local map = root:WaitForChild("Map")

local EFFECTS = { "ZERO_G", "DECAY", "DRONE_SWARM", "SUPPLY_DROP", "BOUNCY", "SLIPPERY", "BLACKOUT", "MAGNETIC", "CORRUPTION", "FLOOD", "SUPER_BOUNCE", "HUNTER_SCAN", "FLOATING_DEBRIS", "RAPID_DECAY", "SLIDE_FIELD" }
local GAMEPLAY = { "DecayTile", "ArenaSpawn", "Stabilizer", "SupplyLandingPoint", "DroneWaypoint", "FragmentSpawn", "BounceSurface", "SlipSurface", "MagneticProp", "MagneticPoint", "CorruptionNode", "FloodZone", "LobbySpawn" }
local errors, report = {}, {}
local function err(s: string)
	table.insert(errors, s)
end
local function name(i: Instance): string
	return (i:GetFullName():gsub("^Workspace%.WORLD_EXE%.Map%.", ""))
end

local hooks: { [Instance]: boolean } = {}
local perEffect = {}
for _, e in EFFECTS do
	local n = 0
	for _, i in CS:GetTagged("EnvFX_" .. e) do
		if i:IsDescendantOf(workspace) then
			hooks[i] = true
			n += 1
		end
	end
	perEffect[e] = n
	if n == 0 then
		err("effect without hooks: " .. e)
	end
end
report.hooksPerEffect = perEffect

local roles, managed = {}, 0
local function check(i: Instance, attr: string, current: any, kind: string)
	local v = i:GetAttribute(attr)
	if v == nil then
		return
	end
	managed += 1
	if kind == "material" then
		if typeof(v) ~= "string" or not pcall(function()
			return (Enum.Material :: any)[v]
		end) then
			err("invalid " .. attr .. " on " .. name(i))
		elseif (current :: EnumItem).Name ~= v then
			err("not at baseline " .. attr .. " on " .. name(i))
		end
	elseif typeof(v) ~= kind then
		err(string.format("%s on %s is %s, expected %s", attr, name(i), typeof(v), kind))
	elseif kind == "number" then
		if math.abs(v - current) > 1e-4 then
			err("not at baseline " .. attr .. " on " .. name(i))
		end
	elseif v ~= current then
		err("not at baseline " .. attr .. " on " .. name(i))
	end
end
for i in hooks do
	local role = i:GetAttribute("EnvFX_Role")
	if typeof(role) ~= "string" then
		err("hook without role: " .. name(i))
		continue
	end
	roles[role] = (roles[role] or 0) + 1
	local marker = i:GetAttribute("Env8A2C")
	if marker ~= "hook" and marker ~= "new" then
		err("hook without Env8A2C marker: " .. name(i))
	end
	local cur: Instance? = i
	while cur and cur ~= map do
		for _, t in GAMEPLAY do
			if CS:HasTag(cur, t) then
				err("gameplay-tagged hook: " .. name(i))
			end
		end
		cur = cur.Parent
	end
	local nBase = 0
	for k in i:GetAttributes() do
		if k:sub(1, 5) == "Base_" then
			nBase += 1
		end
	end
	if nBase == 0 then
		err("hook without Base_ attributes: " .. name(i))
	end
	if i:IsA("BasePart") then
		check(i, "Base_Color", i.Color, "Color3")
		check(i, "Base_Transparency", i.Transparency, "number")
		check(i, "Base_Material", i.Material, "material")
		if i.CanCollide and (i:GetAttribute("Base_Transparency") ~= nil or i:GetAttribute("Base_Material") ~= nil) then
			err("collidable hook manages more than Color: " .. name(i))
		end
	elseif i:IsA("Light") then
		check(i, "Base_Color", i.Color, "Color3")
		check(i, "Base_Brightness", i.Brightness, "number")
		check(i, "Base_Range", i.Range, "number")
		check(i, "Base_LightEnabled", i.Enabled, "boolean")
	elseif i:IsA("Beam") then
		check(i, "Base_BeamEnabled", i.Enabled, "boolean")
	else
		err("unsupported hook class: " .. name(i))
	end
end
report.roles = roles
report.managedBaseAttributes = managed

-- New 8A-2c instances
local newParts, newCollide, newLights, newBeams, emitters = 0, 0, 0, 0, 0
local collidableHooks = {}
for _, d in root:GetDescendants() do
	if d:IsA("ParticleEmitter") then
		emitters += 1
	end
	if d:GetAttribute("Env8A2C") == "new" then
		if d:IsA("BasePart") then
			newParts += 1
			if d.CanCollide then
				newCollide += 1
			end
			if d.CanQuery or d.CanTouch or d.CastShadow or not d.Anchored then
				err("extra flags wrong: " .. name(d))
			end
			if d.Transparency < 1 then
				err("extra visible at baseline: " .. name(d))
			end
		elseif d:IsA("Light") then
			newLights += 1
			if d.Enabled then
				err("new light enabled at baseline: " .. name(d))
			end
		elseif d:IsA("Beam") then
			newBeams += 1
			if d.Enabled then
				err("scan beam enabled at baseline")
			end
		end
	elseif d:GetAttribute("Env8A2C") == "hook" and d:IsA("BasePart") and d.CanCollide then
		table.insert(collidableHooks, name(d))
	end
end
if newParts > 40 or newCollide > 0 or newLights > 4 or newBeams > 1 or emitters > 0 then
	err(string.format("Option B limit exceeded: parts %d collide %d lights %d beams %d emitters %d", newParts, newCollide, newLights, newBeams, emitters))
end
report.newInstances = { parts = newParts, collidable = newCollide, lights = newLights, beams = newBeams, emitters = emitters }
report.collidableHooks = collidableHooks

local parts, collide, lights, shadows = 0, 0, 0, 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		if d.CanCollide then
			collide += 1
		end
	elseif d:IsA("Light") then
		lights += 1
		if d.Shadows then
			shadows += 1
		end
	end
end
report.mapTotals = { parts = parts, collidable = collide, lights = lights, shadowLights = shadows }
local markers = {}
for _, t in GAMEPLAY do
	local n = 0
	for _, i in CS:GetTagged(t) do
		if i:IsDescendantOf(workspace) then
			n += 1
		end
	end
	markers[t] = n
end
report.markerCounts = markers
local L = game:GetService("Lighting")
report.lighting = string.format("%.2f/%.2f", L.Brightness, L.ExposureCompensation)
report.errors = errors
report.result = if #errors == 0 then "PASS" else "FAIL"
return HttpService:JSONEncode(report)

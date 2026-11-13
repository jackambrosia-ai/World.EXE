-- WORLD.EXE ENV_SLICE1 step 9: standalone rollback (Studio EDIT mode). Needs no builder state.
-- Removes Map.EnvSlice1 and the Map attribute "EnvSlice1". 1_build.luau never modifies an existing
-- instance, so removing the folder restores the pre-slice map exactly.
-- Deletes only content it recognizes as the slice (any version: v1 and v2 share part names). It
-- refuses, deletes nothing and lists the reasons when:
--   * a slice-marked instance exists outside Map.EnvSlice1;
--   * Map.EnvSlice1 is not a Folder, or holds anything other than the two slice models;
--   * a model holds anything other than its known, uniquely named Parts, or any part has children;
--   * a part lacks EnvSlice1 = <its model's category>, or carries attributes or tags the builder
--     never sets.
-- Geometry and appearance are not checked here: a moved or recoloured slice part is still slice content.
local CS = game:GetService("CollectionService")
local map = workspace:WaitForChild("WORLD_EXE"):WaitForChild("Map")
local folder = map:FindFirstChild("EnvSlice1")

local KNOWN = {
	TraversalLink_SkyLandingS_BridgeE = {
		category = "TraversalLinks",
		names = { "CutThrough_Walk_1", "CutThrough_Walk_2", "CutThrough_Walk_3", "CutThrough_Walk_4", "ReservoirLanding", "EdgeRail_North", "EdgeRail_South", "EdgeRail_West", "EdgeRail_East", "GuideTrim_Walk_1", "GuideTrim_Walk_2", "GuideTrim_Walk_3", "GuideTrim_Walk_4", "EdgeTrim_Landing_N", "LandingBeacon", "SupportPylon_A", "SupportPylon_B" },
	},
	ExteriorScenery_E10Spire = {
		category = "ExteriorScenery",
		names = { "Spire_Lower", "Spire_Band_1", "Spire_Band_2", "Spire_Upper", "Lattice_Vert_1", "Lattice_Vert_2", "Lattice_Vert_3", "Lattice_Vert_4", "Lattice_Front", "Lattice_Back", "Lattice_Left", "Lattice_Right", "Lattice_Stub", "Fragment_1", "Fragment_2", "Fragment_3", "Fragment_4", "Signal_Trunk", "Signal_Tick_1", "Signal_Tick_2", "Signal_DeadDash", "Signal_DeadLine", "Ghost_Edge_1", "Ghost_Edge_2" },
	},
}
local ALLOWED_ATTRS = { EnvSlice1 = true, WalkSurface = true, EdgeRail = true }

local problems = {}
local function problem(s: string)
	table.insert(problems, s)
end

for _, d in workspace:GetDescendants() do
	if (d:GetAttribute("EnvSlice1") ~= nil or string.find(d.Name, "^EnvSlice1")) and d ~= map and not (folder and (d == folder or d:IsDescendantOf(folder))) then
		problem("slice-marked instance outside Map.EnvSlice1: " .. d:GetFullName())
	end
end

if folder then
	if not folder:IsA("Folder") then
		problem("Map.EnvSlice1 is a " .. folder.ClassName .. ", not a Folder")
	end
	if #CS:GetTags(folder) > 0 then
		problem("Map.EnvSlice1 carries tags")
	end
	for _, model in folder:GetChildren() do
		local spec = KNOWN[model.Name]
		if not spec or model.ClassName ~= "Model" then
			problem("unrecognized child of Map.EnvSlice1: " .. model.Name .. " (" .. model.ClassName .. ")")
			continue
		end
		if #CS:GetTags(model) > 0 then
			problem("tags on " .. model:GetFullName())
		end
		local seen = {}
		for _, p in model:GetChildren() do
			if p.ClassName ~= "Part" or not table.find(spec.names, p.Name) then
				problem("unrecognized instance: " .. p:GetFullName() .. " (" .. p.ClassName .. ")")
				continue
			end
			if seen[p.Name] then
				problem("duplicate part name: " .. p:GetFullName())
			end
			seen[p.Name] = true
			if p:GetAttribute("EnvSlice1") ~= spec.category then
				problem("part without EnvSlice1 = " .. spec.category .. ": " .. p:GetFullName())
			end
			for k in p:GetAttributes() do
				if not ALLOWED_ATTRS[k] then
					problem("unexpected attribute " .. k .. " on " .. p:GetFullName())
				end
			end
			if #CS:GetTags(p) > 0 then
				problem("tags on " .. p:GetFullName())
			end
			for _, c in p:GetChildren() do
				problem("unrecognized instance: " .. c:GetFullName() .. " (" .. c.ClassName .. ")")
			end
		end
	end
end

if #problems > 0 then
	error("ENV_SLICE1 rollback refused, nothing deleted (" .. #problems .. " problem(s)): " .. table.concat(problems, "; ", 1, math.min(#problems, 6)))
end

local function count(): (number, number)
	local parts, collide = 0, 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d.CanCollide then
				collide += 1
			end
		end
	end
	return parts, collide
end
local p0, c0 = count()
local removed = 0
if folder then
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			removed += 1
		end
	end
	folder:Destroy()
end
map:SetAttribute("EnvSlice1", nil)
local p1, c1 = count()
return string.format("ENV_SLICE1 rollback: %d slice parts removed; Map parts %d -> %d, collidable %d -> %d", removed, p0, p1, c0, c1)

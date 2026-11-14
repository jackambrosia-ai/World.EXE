-- WORLD.EXE ENV_SPRINT2 step 9: standalone rollback (Studio EDIT mode). Needs no builder state and no
-- spec: part names are not known in advance, so recognition is structural.
-- Removes Map.EnvSprint2 and the Map attribute "EnvSprint2". The builder never modifies an existing
-- instance, so removing the folder restores the pre-sprint map exactly.
-- Deletes only content it recognizes as the sprint (any version). It refuses, deletes nothing and lists
-- the reasons when:
--   * an instance outside Map.EnvSprint2 carries EnvSprint2 / EnvSprint2Category or is named EnvSprint2*;
--   * Map.EnvSprint2 is not a Folder, or carries attributes or tags;
--   * a child of the folder is not a Model named Traversal_<Name> (EnvSprint2Category = SprintTraversal)
--     or Exterior_<Name> (EnvSprint2Category = SprintExterior), carries other attributes or tags, or the
--     model name is duplicated;
--   * a model holds anything other than uniquely named Part / WedgePart / CornerWedgePart instances;
--   * a part lacks EnvSprint2 = <its model's category>, carries an attribute the builder never sets
--     (allowed: EnvSprint2, WalkSurface, EdgeRail, JumpStep, ReservedUse) or any tag;
--   * a part has a child other than one PointLight / SpotLight (only under SprintExterior parts) with no
--     attributes, tags or children of its own.
-- Geometry and appearance are not checked: a moved or recoloured sprint part is still sprint content.
local CS = game:GetService("CollectionService")
local map = workspace:WaitForChild("WORLD_EXE"):WaitForChild("Map")
local folder = map:FindFirstChild("EnvSprint2")

local CATEGORY_OF_PREFIX = { Traversal = "SprintTraversal", Exterior = "SprintExterior" }
local PART_CLASSES = { Part = true, WedgePart = true, CornerWedgePart = true }
local LIGHT_CLASSES = { PointLight = true, SpotLight = true }
local ALLOWED_ATTRS = { EnvSprint2 = true, WalkSurface = true, EdgeRail = true, JumpStep = true, ReservedUse = true }

local problems = {}
local function problem(s: string)
	table.insert(problems, s)
end

for _, d in workspace:GetDescendants() do
	if (d:GetAttribute("EnvSprint2") ~= nil or d:GetAttribute("EnvSprint2Category") ~= nil or string.find(d.Name, "^EnvSprint2")) and d ~= map and not (folder and (d == folder or d:IsDescendantOf(folder))) then
		problem("sprint-marked instance outside Map.EnvSprint2: " .. d:GetFullName())
	end
end

if folder then
	if not folder:IsA("Folder") then
		problem("Map.EnvSprint2 is a " .. folder.ClassName .. ", not a Folder")
	end
	if next(folder:GetAttributes()) ~= nil or #CS:GetTags(folder) > 0 then
		problem("Map.EnvSprint2 carries attributes or tags")
	end
	local modelNames = {}
	for _, model in folder:GetChildren() do
		local prefix = string.match(model.Name, "^(%a+)_[%w_]+$")
		local category = prefix and CATEGORY_OF_PREFIX[prefix]
		if model.ClassName ~= "Model" or not category then
			problem("unrecognized child of Map.EnvSprint2: " .. model.Name .. " (" .. model.ClassName .. ")")
			continue
		end
		if modelNames[model.Name] then
			problem("duplicate model name: " .. model:GetFullName())
		end
		modelNames[model.Name] = true
		if model:GetAttribute("EnvSprint2Category") ~= category then
			problem("model without EnvSprint2Category = " .. category .. ": " .. model:GetFullName())
		end
		for k in model:GetAttributes() do
			if k ~= "EnvSprint2Category" then
				problem("unexpected attribute " .. k .. " on " .. model:GetFullName())
			end
		end
		if #CS:GetTags(model) > 0 then
			problem("tags on " .. model:GetFullName())
		end
		local seen = {}
		for _, p in model:GetChildren() do
			if not PART_CLASSES[p.ClassName] then
				problem("unrecognized instance: " .. p:GetFullName() .. " (" .. p.ClassName .. ")")
				continue
			end
			if seen[p.Name] then
				problem("duplicate part name: " .. p:GetFullName())
			end
			seen[p.Name] = true
			if p:GetAttribute("EnvSprint2") ~= category then
				problem("part without EnvSprint2 = " .. category .. ": " .. p:GetFullName())
			end
			for k in p:GetAttributes() do
				if not ALLOWED_ATTRS[k] then
					problem("unexpected attribute " .. k .. " on " .. p:GetFullName())
				end
			end
			if #CS:GetTags(p) > 0 then
				problem("tags on " .. p:GetFullName())
			end
			local kids = p:GetChildren()
			for i, c in kids do
				local okLight = i == 1 and #kids == 1 and category == "SprintExterior" and LIGHT_CLASSES[c.ClassName] and #c:GetChildren() == 0 and next(c:GetAttributes()) == nil and #CS:GetTags(c) == 0
				if not okLight then
					problem("unrecognized instance: " .. c:GetFullName() .. " (" .. c.ClassName .. ")")
				end
			end
		end
	end
end

if #problems > 0 then
	error("ENV_SPRINT2 rollback refused, nothing deleted (" .. #problems .. " problem(s)): " .. table.concat(problems, "; ", 1, math.min(#problems, 8)), 0)
end

local function count(): (number, number, number)
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
local p0, c0, l0 = count()
local removed = 0
if folder then
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			removed += 1
		end
	end
	folder:Destroy()
end
map:SetAttribute("EnvSprint2", nil)
local p1, c1, l1 = count()
return string.format("ENV_SPRINT2 rollback: %d sprint parts removed; Map parts %d -> %d, collidable %d -> %d, lights %d -> %d", removed, p0, p1, c0, c1, l0, l1)

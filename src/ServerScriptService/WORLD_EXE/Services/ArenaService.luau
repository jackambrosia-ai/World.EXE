--!strict
-- ArenaService (Phase 1, server only).
-- * Validate(): type/value checks for every tagged instance and attribute, spawn safety, waypoint graph.
-- * Runtime folders: created and marked by the server; only marked Folders are ever emptied.
-- * Baseline: a per-instance snapshot of the map captured at Init, compared field by field.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))

export type ValidationReport = {
	ok: boolean,
	counts: { [string]: number },
	errors: { string },
}

export type BaselineReport = {
	matches: boolean,
	total: number, -- number of differences found
	differences: { string }, -- first MAX_REPORTED_DIFFERENCES, human-readable
}

local MAX_REPORTED_DIFFERENCES = 25

local ArenaService = {}

local root: Instance? = nil
local map: Instance? = nil
local baseline: { [Instance]: string }? = nil

local validZones: { [string]: boolean } = {}
for _, zone in Config.Zones do
	validZones[zone] = true
end

---------------------------------------------------------------------------------------------------
-- Snapshot

-- Quantize to thousandths so float noise never registers, without printing "-0".
local function q(n: number): string
	local r = math.round(n * 1000)
	if r == 0 then
		return "0"
	end
	return tostring(r)
end

local function cframeKey(cf: CFrame): string
	local c = { cf:GetComponents() }
	local out = table.create(#c)
	for i, v in c do
		out[i] = q(v)
	end
	return table.concat(out, ",")
end

local function attributeKey(inst: Instance): string
	local parts = {}
	for name, value in inst:GetAttributes() do
		table.insert(parts, `{name}={typeof(value)}:{tostring(value)}`)
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

local function tagKey(inst: Instance): string
	local tags = inst:GetTags()
	table.sort(tags)
	return table.concat(tags, ",")
end

local function vectorKey(v: Vector3): string
	return `{q(v.X)},{q(v.Y)},{q(v.Z)}`
end

local function physicalPropertiesKey(props: PhysicalProperties?): string
	if props == nil then
		return "material-default"
	end
	return `{q(props.Density)},{q(props.Friction)},{q(props.Elasticity)},{q(props.FrictionWeight)},{q(props.ElasticityWeight)}`
end

-- Everything about an instance that the arena contract depends on.
--
-- Compared for BaseParts: CFrame (position + rotation), Size, Part.Shape, Material (sets default
-- friction/density), CustomPhysicalProperties, CollisionGroup, Anchored, CanCollide, CanQuery,
-- CanTouch, Massless, AssemblyLinearVelocity / AssemblyAngularVelocity (an anchored part with
-- velocity acts as a conveyor), CollisionFidelity for mesh/union parts, MeshId for MeshParts.
--
-- Intentionally NOT compared (visual-only or irrelevant to anchored arena geometry): Color,
-- Transparency, Reflectance, CastShadow, Locked, Archivable, surface types (no physics effect),
-- RootPriority (only affects unanchored assemblies; Anchored is compared), network ownership
-- (runtime state), and the internal geometry of unions (not readable from Luau; none in the map).
local function describe(inst: Instance): string
	local fields = {
		inst.ClassName,
		inst:GetFullName(),
		`attrs[{attributeKey(inst)}]`,
		`tags[{tagKey(inst)}]`,
	}
	if inst:IsA("BasePart") then
		table.insert(fields, `cf[{cframeKey(inst.CFrame)}]`)
		table.insert(fields, `size[{vectorKey(inst.Size)}]`)
		if inst:IsA("Part") then
			table.insert(fields, `shape={inst.Shape.Name}`)
		end
		table.insert(fields, `material={inst.Material.Name} physics[{physicalPropertiesKey(inst.CustomPhysicalProperties)}] group={inst.CollisionGroup}`)
		table.insert(fields, `anchored={inst.Anchored} collide={inst.CanCollide} query={inst.CanQuery} touch={inst.CanTouch} massless={inst.Massless}`)
		table.insert(fields, `vel[{vectorKey(inst.AssemblyLinearVelocity)}] angvel[{vectorKey(inst.AssemblyAngularVelocity)}]`)
		if inst:IsA("TriangleMeshPart") then
			table.insert(fields, `fidelity={inst.CollisionFidelity.Name}`)
		end
		if inst:IsA("MeshPart") then
			table.insert(fields, `mesh={inst.MeshId}`)
		end
		if inst:IsA("SpawnLocation") then
			table.insert(fields, `spawn[enabled={inst.Enabled} neutral={inst.Neutral} duration={inst.Duration}]`)
		end
	elseif inst:IsA("Attachment") then
		table.insert(fields, `cf[{cframeKey(inst.CFrame)}]`)
	elseif inst:IsA("Model") then
		local primary = inst.PrimaryPart
		table.insert(fields, `primary={if primary then primary:GetFullName() else "nil"}`)
	end
	return table.concat(fields, " | ")
end

local function snapshot(container: Instance): { [Instance]: string }
	local snap: { [Instance]: string } = { [container] = describe(container) }
	for _, d in container:GetDescendants() do
		snap[d] = describe(d)
	end
	return snap
end

---------------------------------------------------------------------------------------------------
-- Helpers

local function inMap(inst: Instance): boolean
	return map ~= nil and (inst == map or inst:IsDescendantOf(map))
end

local function taggedInMap(tag: string): { Instance }
	local result = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inMap(inst) then
			table.insert(result, inst)
		end
	end
	return result
end

local function belongsToCharacter(part: BasePart): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function isFinitePositive(value: any): boolean
	return typeof(value) == "number" and value == value and value > 0 and value < math.huge
end

-- Returns the parsed list, or nil plus a reason.
local function parseLinks(raw: string): ({ string }?, string?)
	if raw == "" then
		return nil, "is empty"
	end
	local list = string.split(raw, ",")
	local seen: { [string]: boolean } = {}
	for _, id in list do
		if id == "" then
			return nil, "has an empty entry"
		end
		if string.find(id, "%s") then
			return nil, `entry "{id}" contains whitespace`
		end
		if seen[id] then
			return nil, `lists "{id}" more than once`
		end
		seen[id] = true
	end
	return list, nil
end

---------------------------------------------------------------------------------------------------
-- Validation

local function validateSpawn(pad: SpawnLocation, errors: { string })
	local name = pad:GetFullName()
	if not pad.Enabled or not pad.Neutral then
		table.insert(errors, `{name}: SpawnLocation must be Enabled and Neutral`)
	end
	if not pad.Anchored then
		table.insert(errors, `{name}: SpawnLocation must be Anchored`)
	end
	if not pad.CanCollide then
		table.insert(errors, `{name}: SpawnLocation must have CanCollide enabled`)
	end

	-- Floor support: the centre and four inset corners must rest on anchored, collidable,
	-- non-DecayTile floor directly beneath the pad.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { pad }
	rayParams.RespectCanCollide = true
	local half = pad.Size / 2
	local insetX, insetZ = math.max(half.X - 0.5, 0), math.max(half.Z - 0.5, 0)
	for _, offset in { Vector2.zero, Vector2.new(insetX, insetZ), Vector2.new(-insetX, insetZ), Vector2.new(insetX, -insetZ), Vector2.new(-insetX, -insetZ) } do
		local bottom = pad.CFrame:PointToWorldSpace(Vector3.new(offset.X, -half.Y, offset.Y))
		local hit = workspace:Raycast(bottom + Vector3.new(0, 0.01, 0), Vector3.new(0, -5, 0), rayParams)
		if not hit then
			table.insert(errors, `{name}: no floor beneath pad at offset {offset}`)
			return
		end
		local floor = hit.Instance
		local gap = bottom.Y - hit.Position.Y
		if gap > Config.SpawnFloorTolerance then
			table.insert(errors, `{name}: pad floats {string.format("%.2f", gap)} studs above {floor:GetFullName()}`)
			return
		end
		if not floor.Anchored then
			table.insert(errors, `{name}: supporting floor {floor:GetFullName()} is not anchored`)
			return
		end
		if CollectionService:HasTag(floor, Config.Tags.DecayTile) then
			table.insert(errors, `{name}: rests on DecayTile {floor:GetFullName()}`)
			return
		end
	end

	-- Overhead clearance where the character appears.
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { pad }
	overlap.RespectCanCollide = true
	local box = pad.CFrame + Vector3.new(0, half.Y + 3.5, 0)
	for _, hit in workspace:GetPartBoundsInBox(box, Vector3.new(4, 6, 4), overlap) do
		if not belongsToCharacter(hit) then
			table.insert(errors, `{name}: obstructed by {hit:GetFullName()}`)
			return
		end
	end
end

function ArenaService.Validate(): ValidationReport
	assert(map, "ArenaService.Validate called before Init")
	local errors: { string } = {}
	local counts: { [string]: number } = {}
	local waypointLinks: { [string]: { string } } = {}
	local waypointIds: { [string]: boolean } = {}

	for key, tag in Config.Tags do
		local schema = Config.AttributeSchema[key]
		local requiredClass = Config.TagClasses[key]
		local items = taggedInMap(tag)
		counts[key] = #items
		local seenIds: { [string]: string } = {}

		for _, inst in items do
			local where = inst:GetFullName()
			if not inst:IsA(requiredClass) then
				table.insert(errors, `{where}: tagged {tag} but is a {inst.ClassName}, expected {requiredClass}`)
			end
			local instId: string? = nil
			for _, field in schema do
				local value = inst:GetAttribute(field.name)
				if field.kind == "id" then
					if typeof(value) ~= "string" or value == "" then
						table.insert(errors, `{where}: {field.name} must be a non-empty string (got {typeof(value)})`)
					elseif seenIds[value] then
						table.insert(errors, `{where}: duplicate {field.name} "{value}" (also on {seenIds[value]})`)
					else
						seenIds[value] = where
						instId = value
					end
				elseif field.kind == "zone" then
					if typeof(value) ~= "string" or not validZones[value] then
						table.insert(errors, `{where}: {field.name} must be one of Config.Zones (got {tostring(value)})`)
					end
				elseif field.kind == "positive" then
					if not isFinitePositive(value) then
						table.insert(errors, `{where}: {field.name} must be a finite number > 0 (got {tostring(value)})`)
					end
				elseif field.kind == "links" then
					if typeof(value) ~= "string" then
						table.insert(errors, `{where}: {field.name} must be a string (got {typeof(value)})`)
					else
						local list, problem = parseLinks(value)
						if problem then
							table.insert(errors, `{where}: {field.name} {problem}`)
						elseif list and instId then
							waypointLinks[instId] = list
						end
					end
				end
			end
			if key == "DroneWaypoint" and instId then
				waypointIds[instId] = true
			end
		end

		local expected = Config.ExpectedTagCounts[key]
		if #items ~= expected then
			table.insert(errors, `{tag}: expected {expected}, found {#items}`)
		end
	end

	for _, inst in taggedInMap(Config.Tags.ArenaSpawn) do
		if inst:IsA("SpawnLocation") then
			validateSpawn(inst, errors)
		end
	end

	-- Waypoint graph: links reference known ids, never self, and are symmetric.
	local linkSets: { [string]: { [string]: boolean } } = {}
	for id, list in waypointLinks do
		local set = {}
		for _, other in list do
			set[other] = true
		end
		linkSets[id] = set
	end
	for id, list in waypointLinks do
		for _, other in list do
			if other == id then
				table.insert(errors, `waypoint {id} links to itself`)
			elseif not waypointIds[other] then
				table.insert(errors, `waypoint {id} links to unknown id "{other}"`)
			elseif linkSets[other] and not linkSets[other][id] then
				table.insert(errors, `waypoint link {id}->{other} is not symmetric`)
			end
		end
	end

	return { ok = #errors == 0, counts = counts, errors = errors }
end

---------------------------------------------------------------------------------------------------
-- Runtime folders

-- Children of root with this name (more than one is a conflict).
local function namedChildren(name: string): { Instance }
	assert(root, "ArenaService not initialized")
	local found = {}
	for _, child in root:GetChildren() do
		if child.Name == name then
			table.insert(found, child)
		end
	end
	return found
end

local function isRuntimeFolder(inst: Instance): boolean
	return inst:IsA("Folder") and inst:GetAttribute(Config.RuntimeFolderMarker) == true
end

-- Creates missing runtime folders. Never touches a same-named object it did not create.
function ArenaService.EnsureRuntimeFolders(): { string }
	assert(root, "ArenaService not initialized")
	local problems = {}
	for _, name in Config.RuntimeFolders do
		local found = namedChildren(name)
		if #found == 0 then
			local folder = Instance.new("Folder")
			folder.Name = name
			folder:SetAttribute(Config.RuntimeFolderMarker, true)
			folder.Parent = root
		elseif #found > 1 or not isRuntimeFolder(found[1]) then
			table.insert(problems, `runtime folder name "{name}" is taken by {#found} unexpected object(s) ({found[1].ClassName}); left untouched`)
		end
	end
	return problems
end

-- Empties marked runtime folders (idempotent). Returns how many instances were removed and any
-- conflicts that were skipped instead of deleted.
function ArenaService.ResetRuntime(): (number, { string })
	assert(root, "ArenaService not initialized")
	local removed = 0
	for _, name in Config.RuntimeFolders do
		local found = namedChildren(name)
		if #found == 1 and isRuntimeFolder(found[1]) then
			for _, child in found[1]:GetChildren() do
				child:Destroy()
				removed += 1
			end
		end
	end
	return removed, ArenaService.EnsureRuntimeFolders()
end

---------------------------------------------------------------------------------------------------
-- Baseline

-- Compares the map with the snapshot captured at Init: added, removed, re-created
-- (identity), and changed instances (every field listed above describe()).
function ArenaService.CompareToBaseline(): BaselineReport
	assert(map and baseline, "ArenaService not initialized")
	local current = snapshot(map)
	local differences: { string } = {}
	local total = 0
	local function note(message: string)
		total += 1
		if #differences < MAX_REPORTED_DIFFERENCES then
			table.insert(differences, message)
		end
	end
	for inst, before in baseline do
		local now = current[inst]
		if now == nil then
			note(`removed: {before}`)
		elseif now ~= before then
			note(`changed: {before}  =>  {now}`)
		end
	end
	for inst, now in current do
		if baseline[inst] == nil then
			note(`added: {now}`)
		end
	end
	return { matches = total == 0, total = total, differences = differences }
end

function ArenaService.MatchesBaseline(): boolean
	return ArenaService.CompareToBaseline().matches
end

function ArenaService.GetSpawns(): { SpawnLocation }
	local result = {}
	for _, inst in taggedInMap(Config.Tags.ArenaSpawn) do
		if inst:IsA("SpawnLocation") then
			table.insert(result, inst)
		end
	end
	return result
end

function ArenaService.Init(): ValidationReport
	local foundRoot = workspace:WaitForChild(Config.RootName, 10)
	local foundMap = foundRoot and foundRoot:WaitForChild("Map", 10)
	if not foundRoot or not foundMap then
		error("Workspace.WORLD_EXE.Map not found")
	end
	root = foundRoot
	map = foundMap
	baseline = snapshot(foundMap)
	local _, problems = ArenaService.ResetRuntime()
	local report = ArenaService.Validate()
	for _, problem in problems do
		table.insert(report.errors, problem)
	end
	report.ok = #report.errors == 0
	return report
end

return ArenaService

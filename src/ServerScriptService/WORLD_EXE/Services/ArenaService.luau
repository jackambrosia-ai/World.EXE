--!strict
-- ArenaService (Phase 1, server only).
-- Validates the Studio-owned arena (tags, counts, attributes, spawn clearance, waypoint graph),
-- owns the WORLD_EXE runtime folders, and checks that map geometry still matches its boot baseline.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))

export type ValidationReport = {
	ok: boolean,
	counts: { [string]: number },
	errors: { string },
}

local ArenaService = {}

local root: Instance? = nil
local map: Instance? = nil
local baselineFingerprint: string? = nil

-- Deterministic summary of map geometry: instance count, rounded positions/sizes, collidable parts.
local function fingerprint(container: Instance): string
	local count, sx, sy, sz, collidable = 0, 0, 0, 0, 0
	for _, d in container:GetDescendants() do
		count += 1
		if d:IsA("BasePart") then
			local p, s = d.Position, d.Size
			sx += math.round(p.X * 10) + math.round(s.X * 10)
			sy += math.round(p.Y * 10) + math.round(s.Y * 10)
			sz += math.round(p.Z * 10) + math.round(s.Z * 10)
			if d.CanCollide then
				collidable += 1
			end
		end
	end
	return string.format("%d|%d|%d|%d|%d", count, sx, sy, sz, collidable)
end

local function inMap(inst: Instance): boolean
	return map ~= nil and inst:IsDescendantOf(map)
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

function ArenaService.Validate(): ValidationReport
	assert(map, "ArenaService.Validate called before Init")
	local errors: { string } = {}
	local counts: { [string]: number } = {}

	for key, tag in Config.Tags do
		local required = Config.RequiredAttributes[key]
		local seen: { [any]: boolean } = {}
		local items = taggedInMap(tag)
		counts[key] = #items
		for _, inst in items do
			for _, attr in required do
				if inst:GetAttribute(attr) == nil then
					table.insert(errors, `{inst:GetFullName()} missing attribute {attr}`)
				end
			end
			local id = inst:GetAttribute(required[1])
			if id ~= nil then
				if seen[id] then
					table.insert(errors, `duplicate {tag} id {tostring(id)}`)
				end
				seen[id] = true
			end
		end
		local expected = Config.ExpectedTagCounts[key]
		if #items ~= expected then
			table.insert(errors, `{tag}: expected {expected}, found {#items}`)
		end
	end

	-- Spawns must be real, enabled, neutral SpawnLocations with clear space above the pad.
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.RespectCanCollide = true
	for _, inst in taggedInMap(Config.Tags.ArenaSpawn) do
		if not inst:IsA("SpawnLocation") then
			table.insert(errors, `{inst:GetFullName()} is tagged ArenaSpawn but is not a SpawnLocation`)
			continue
		end
		local spawnPad = inst :: SpawnLocation
		if not spawnPad.Enabled or not spawnPad.Neutral then
			table.insert(errors, `{spawnPad.Name} must be Enabled and Neutral`)
		end
		overlap.FilterDescendantsInstances = { spawnPad }
		local box = spawnPad.CFrame + Vector3.new(0, spawnPad.Size.Y / 2 + 3.5, 0)
		for _, hit in workspace:GetPartBoundsInBox(box, Vector3.new(4, 6, 4), overlap) do
			if not belongsToCharacter(hit) then
				table.insert(errors, `{spawnPad.Name} obstructed by {hit:GetFullName()}`)
				break
			end
		end
	end

	-- Drone waypoint links must reference existing waypoints and be symmetric.
	local links: { [string]: { [string]: boolean } } = {}
	for _, wp in taggedInMap(Config.Tags.DroneWaypoint) do
		local id = wp:GetAttribute("WaypointId")
		local raw = wp:GetAttribute("Links")
		if typeof(id) == "string" and typeof(raw) == "string" then
			local set = {}
			for _, other in string.split(raw, ",") do
				set[other] = true
			end
			links[id] = set
		end
	end
	for id, set in links do
		for other in set do
			if links[other] == nil then
				table.insert(errors, `waypoint {id} links to unknown {other}`)
			elseif not links[other][id] then
				table.insert(errors, `waypoint link {id}->{other} is not symmetric`)
			end
		end
	end

	return { ok = #errors == 0, counts = counts, errors = errors }
end

function ArenaService.EnsureRuntimeFolders()
	assert(root, "ArenaService not initialized")
	for _, name in Config.RuntimeFolders do
		if not root:FindFirstChild(name) then
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = root
		end
	end
end

-- Empties every runtime folder (idempotent). Returns how many instances were removed.
function ArenaService.ResetRuntime(): number
	assert(root, "ArenaService not initialized")
	local removed = 0
	for _, name in Config.RuntimeFolders do
		local folder = root:FindFirstChild(name)
		if folder then
			for _, child in folder:GetChildren() do
				child:Destroy()
				removed += 1
			end
		end
	end
	ArenaService.EnsureRuntimeFolders()
	return removed
end

-- True when map geometry matches the fingerprint captured at Init.
function ArenaService.MatchesBaseline(): boolean
	assert(map, "ArenaService not initialized")
	return baselineFingerprint ~= nil and fingerprint(map) == baselineFingerprint
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
	baselineFingerprint = fingerprint(foundMap)
	ArenaService.ResetRuntime()
	return ArenaService.Validate()
end

return ArenaService

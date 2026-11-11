--!strict
-- Phase 5 (Studio Edit mode, run once via Studio MCP): adds the 12 approved data-fragment spawn
-- markers to the arena. This is a documented, additive map change: invisible, anchored,
-- non-colliding, non-queryable, non-touchable 1-stud parts under Map.FragmentSpawns, tagged
-- FragmentSpawn with FragmentSpawnId and Zone attributes. No existing geometry is moved or edited.
-- Each marker sits 2.5 studs above a floor surface verified by a downward raycast (2026-11-10).
-- Idempotent: an existing FragmentSpawns folder is left untouched.

local CollectionService = game:GetService("CollectionService")

local map = workspace:WaitForChild("WORLD_EXE"):WaitForChild("Map")
if map:FindFirstChild("FragmentSpawns") then
	return "FragmentSpawns already exists; nothing changed"
end

-- { id, zone, x, floorY, z }
local POINTS = {
	{ "FRAG_CORE_1", "CentralCore", 18, 0, 18 },
	{ "FRAG_CORE_2", "CentralCore", -18, 0, -18 },
	{ "FRAG_CORE_3", "CentralCore", 34, 0, 0 },
	{ "FRAG_YARD_1", "ResearchYard", -115, 0, 15 }, -- on a DecayTile (risk/reward)
	{ "FRAG_YARD_2", "ResearchYard", -145, 0, -15 }, -- on a DecayTile (risk/reward)
	{ "FRAG_YARD_3", "ResearchYard", -160, 0, 0 },
	{ "FRAG_YARD_4", "ResearchYard", -80, 0, 0 },
	{ "FRAG_SKY_1", "Skybridge", 135, 24, 12 },
	{ "FRAG_SKY_2", "Skybridge", 112, 24, 0 },
	{ "FRAG_SKY_3", "Skybridge", 90, 24, -64 },
	{ "FRAG_ROUTE_1", "Routes", -60, 0, 8 },
	{ "FRAG_ROUTE_2", "Routes", 60, 8, 0 },
}

local folder = Instance.new("Folder")
folder.Name = "FragmentSpawns"
for _, point in POINTS do
	local part = Instance.new("Part")
	part.Name = point[1]
	part.Size = Vector3.new(1, 1, 1)
	part.Position = Vector3.new(point[3], point[4] + 2.5, point[5])
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part:SetAttribute("FragmentSpawnId", point[1])
	part:SetAttribute("Zone", point[2])
	CollectionService:AddTag(part, "FragmentSpawn")
	part.Parent = folder
end
folder.Parent = map
return `created {#POINTS} FragmentSpawn markers`

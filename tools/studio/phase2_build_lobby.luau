--!strict
-- WORLD.EXE Phase 2 lobby builder.
-- Run once in Studio (command bar or Studio MCP execute_luau, Edit DataModel).
-- Creates Workspace.WORLD_EXE.Lobby: an enclosed platform south of the arena (top Y=80) that
-- overlooks the arena. Lobby players and spectators (re)spawn here. It is outside
-- Workspace.WORLD_EXE.Map, so Phase 1 arena validation and the map baseline are unaffected.
-- Refuses to run if the Lobby already exists.

local CollectionService = game:GetService("CollectionService")

local root = workspace:FindFirstChild("WORLD_EXE")
assert(root, "Workspace.WORLD_EXE missing; build the Phase 1 arena first")
assert(root:FindFirstChild("Lobby") == nil, "Workspace.WORLD_EXE.Lobby already exists; refusing to overwrite")

local NAVY = Color3.fromRGB(30, 36, 60)
local COVER = Color3.fromRGB(58, 68, 104)
local CYAN = Color3.fromRGB(0, 225, 255)
local SPAWN = Color3.fromRGB(20, 110, 140)

local CENTER = Vector3.new(0, 80, 150) -- top surface centre
local SIZE = 48
local WALL_HEIGHT = 5

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local lobby = Instance.new("Folder")
lobby.Name = "Lobby"

part(lobby, "LobbyFloor", Vector3.new(SIZE, 4, SIZE), CFrame.new(CENTER - Vector3.new(0, 2, 0)), NAVY)

-- Enclosing walls (players cannot fall out); low enough to watch the arena.
local half = SIZE / 2
for _, def in {
	{ "Wall_N", Vector3.new(SIZE, WALL_HEIGHT, 1), Vector3.new(0, 0, -half + 0.5) },
	{ "Wall_S", Vector3.new(SIZE, WALL_HEIGHT, 1), Vector3.new(0, 0, half - 0.5) },
	{ "Wall_E", Vector3.new(1, WALL_HEIGHT, SIZE), Vector3.new(half - 0.5, 0, 0) },
	{ "Wall_W", Vector3.new(1, WALL_HEIGHT, SIZE), Vector3.new(-half + 0.5, 0, 0) },
} do
	local wall = part(lobby, def[1], def[2], CFrame.new(CENTER + def[3] + Vector3.new(0, WALL_HEIGHT / 2, 0)), COVER)
	local trimSize = Vector3.new(math.max(def[2].X, 0.4), 0.3, math.max(def[2].Z, 0.4))
	local trimPart = part(lobby, def[1] .. "_Trim", trimSize, wall.CFrame + Vector3.new(0, WALL_HEIGHT / 2 + 0.15, 0), CYAN, Enum.Material.Neon)
	trimPart.CanCollide = false
	trimPart.CanQuery = false
	trimPart.CanTouch = false
end

-- Lobby spawn pads (real SpawnLocations; the server chooses one per player via RespawnLocation).
for i, offset in { Vector3.new(-10, 0, -10), Vector3.new(10, 0, -10), Vector3.new(-10, 0, 10), Vector3.new(10, 0, 10) } do
	local s = Instance.new("SpawnLocation")
	s.Name = "LobbySpawn_" .. i
	s.Anchored = true
	s.Size = Vector3.new(6, 1, 6)
	s.CFrame = CFrame.new(CENTER + offset + Vector3.new(0, 0.5, 0))
	s.Color = SPAWN
	s.Material = Enum.Material.SmoothPlastic
	s.TopSurface = Enum.SurfaceType.Smooth
	s.BottomSurface = Enum.SurfaceType.Smooth
	s.Enabled = true
	s.Neutral = true
	s.AllowTeamChangeOnTouch = false
	s.Duration = 0
	s:SetAttribute("SpawnId", "LOBBY_" .. i)
	CollectionService:AddTag(s, "LobbySpawn")
	s.Parent = lobby
end

lobby.Parent = root
return `built Workspace.WORLD_EXE.Lobby with {#lobby:GetChildren()} children`

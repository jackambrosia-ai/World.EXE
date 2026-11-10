--!strict
-- PlayerStateService (Phase 2, server only).
-- Owns each player's match role (Lobby / Participant / Spectator), alive state, where they
-- (re)spawn, spawn protection, out-of-bounds elimination, and keeping non-participants out of
-- the arena. MatchService decides roles and phases; this service applies them.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local ArenaService = require(script.Parent:WaitForChild("ArenaService"))

local Roles = Config.Roles
local ROLE_ATTR = Config.PlayerAttributes.Role
local ALIVE_ATTR = Config.PlayerAttributes.Alive
local LAST_SPAWN_ATTR = "WORLD_EXE_LastSpawn"
local WATCHDOG_SECONDS = 0.5

local PlayerStateService = {}

local rng = Random.new()
local lobbySpawns: { SpawnLocation } = {}
local arenaSpawns: { SpawnLocation } = {}
local arenaPhase = false -- true while participants should (re)spawn in the arena
local protectionActive = false
local lastArenaPad: { [Player]: SpawnLocation } = {}
-- Per-player spawn generation. Every scheduled LoadCharacter remembers the generation it was
-- issued under; any later spawn request, role change, phase change, or departure bumps it, so a
-- stale request is dropped instead of loading the character in the wrong place.
local spawnGeneration: { [Player]: number } = {}
local loadsPerformed: { [Player]: number } = {}
-- Loads are serialized per player: the engine ignores a LoadCharacter issued while that player's
-- previous load is still finishing, so at most one load runs and only the newest request waits.
type SpawnRequest = { generation: number, intent: string, pad: SpawnLocation }
local pendingSpawn: { [Player]: SpawnRequest } = {}
local loadRunning: { [Player]: boolean } = {}
local joinRole: () -> string = function()
	return Roles.Lobby
end
local leftCallbacks: { (Player) -> () } = {}
local diedCallbacks: { (Player) -> () } = {}

---------------------------------------------------------------------------------------------------
-- Queries

function PlayerStateService.GetRole(player: Player): string
	local role = player:GetAttribute(ROLE_ATTR)
	return if typeof(role) == "string" then role else Roles.Lobby
end

function PlayerStateService.IsAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and player.Parent == Players
end

function PlayerStateService.GetPlayersWithRole(role: string): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if PlayerStateService.GetRole(player) == role then
			table.insert(result, player)
		end
	end
	return result
end

---------------------------------------------------------------------------------------------------
-- Shield (Phase 4, SUPPLY_DROP reward): blocks the next drone hit until it expires. Match-scoped:
-- cleared on death and on every role change (so RESET, recovery and departures clear it).
-- Stored as a replicated server-time expiry so the HUD can show it; clients only read it.

local SHIELD_ATTR = Config.PlayerAttributes.Shield

local function clearShield(player: Player)
	player:SetAttribute(SHIELD_ATTR, nil)
end

function PlayerStateService.GrantShield(player: Player, seconds: number)
	player:SetAttribute(SHIELD_ATTR, workspace:GetServerTimeNow() + seconds)
end

function PlayerStateService.HasShield(player: Player): boolean
	local untilTime = player:GetAttribute(SHIELD_ATTR)
	return typeof(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
end

-- Uses the shield if one is active. Returns true when it blocked something.
function PlayerStateService.ConsumeShield(player: Player): boolean
	local active = PlayerStateService.HasShield(player)
	clearShield(player)
	return active
end

local function insideArena(position: Vector3): boolean
	local lo, hi = Config.ArenaBoundsMin, Config.ArenaBoundsMax
	return position.X >= lo.X and position.X <= hi.X and position.Y >= lo.Y and position.Y <= hi.Y and position.Z >= lo.Z and position.Z <= hi.Z
end
PlayerStateService.InsideArena = insideArena

---------------------------------------------------------------------------------------------------
-- Spawning

local function pickLobbyPad(): SpawnLocation
	return lobbySpawns[rng:NextInteger(1, #lobbySpawns)]
end

local function pickArenaPad(player: Player): SpawnLocation
	local last = lastArenaPad[player]
	local choices = {}
	for _, pad in arenaSpawns do
		if pad ~= last then
			table.insert(choices, pad)
		end
	end
	if #choices == 0 then
		choices = arenaSpawns
	end
	local pad = choices[rng:NextInteger(1, #choices)]
	lastArenaPad[player] = pad
	return pad
end

-- Points the player's next spawn at the arena (participants during a match) or the lobby.
function PlayerStateService.RefreshRespawnLocation(player: Player)
	if arenaPhase and PlayerStateService.GetRole(player) == Roles.Participant then
		player.RespawnLocation = pickArenaPad(player)
	else
		player.RespawnLocation = pickLobbyPad()
	end
end

local function bumpSpawnGeneration(player: Player): number
	local generation = (spawnGeneration[player] or 0) + 1
	spawnGeneration[player] = generation
	return generation
end

function PlayerStateService.GetSpawnGeneration(player: Player): number
	return spawnGeneration[player] or 0
end

-- Number of LoadCharacter calls this service actually performed for the player (for tests).
function PlayerStateService.GetLoadsPerformed(player: Player): number
	return loadsPerformed[player] or 0
end

-- Runs pending spawn requests for one player, one LoadCharacter at a time. Each request is
-- re-checked immediately before loading: still connected, no newer spawn generation, and the
-- intent still matches the player's role and the current phase. Otherwise it is dropped.
local function processSpawns(player: Player)
	if loadRunning[player] then
		return -- the running loop picks up the newest request when its load returns
	end
	loadRunning[player] = true
	while player.Parent == Players do
		local request = pendingSpawn[player]
		if request == nil then
			break
		end
		pendingSpawn[player] = nil
		-- Diagnostic outcome (server-set, read by tests): "<intent>#<generation>:<result>".
		local label = `{request.intent}#{request.generation}`
		if spawnGeneration[player] ~= request.generation then
			player:SetAttribute(LAST_SPAWN_ATTR, label .. ":superseded")
			continue
		end
		local wantsArena = arenaPhase and PlayerStateService.GetRole(player) == Roles.Participant
		if (request.intent == "arena") ~= wantsArena then
			player:SetAttribute(LAST_SPAWN_ATTR, label .. ":intent_mismatch")
			continue
		end
		player.RespawnLocation = request.pad
		loadsPerformed[player] = (loadsPerformed[player] or 0) + 1
		player:SetAttribute(LAST_SPAWN_ATTR, label .. ":loading")
		local ok, err = pcall(player.LoadCharacter, player)
		if not ok then
			warn(`[WORLD_EXE] LoadCharacter failed for {player.Name}: {err}`)
		elseif player.Parent == Players then
			player:SetAttribute(LAST_SPAWN_ATTR, label .. ":loaded")
		end
	end
	loadRunning[player] = nil
end

-- Requests a fresh character at `pad`. `intent` is "arena" or "lobby". The newest request wins.
local function requestLoad(player: Player, intent: string, pad: SpawnLocation)
	pendingSpawn[player] = { generation = bumpSpawnGeneration(player), intent = intent, pad = pad }
	task.defer(processSpawns, player)
end

function PlayerStateService.SetRole(player: Player, role: string)
	assert(role == Roles.Lobby or role == Roles.Participant or role == Roles.Spectator, "invalid role " .. tostring(role))
	bumpSpawnGeneration(player)
	clearShield(player)
	player:SetAttribute(ROLE_ATTR, role)
	PlayerStateService.RefreshRespawnLocation(player)
end

function PlayerStateService.SetArenaPhase(enabled: boolean)
	arenaPhase = enabled
	for _, player in Players:GetPlayers() do
		bumpSpawnGeneration(player)
		PlayerStateService.RefreshRespawnLocation(player)
	end
end

local function applyProtection(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local existing = character:FindFirstChild(Config.SpawnProtectionName)
	local wanted = protectionActive and PlayerStateService.GetRole(player) == Roles.Participant
	if wanted and existing == nil then
		local field = Instance.new("ForceField")
		field.Name = Config.SpawnProtectionName
		field.Visible = true
		field.Parent = character
	elseif not wanted and existing then
		existing:Destroy()
	end
end

-- Spawn protection covers match initialization only (docs/01_GAME_DESIGN.md §9).
function PlayerStateService.SetSpawnProtection(enabled: boolean)
	protectionActive = enabled
	for _, player in Players:GetPlayers() do
		applyProtection(player)
	end
end

-- Respawns each participant on a distinct arena pad (fresh character, full health).
function PlayerStateService.SpawnParticipants(participants: { Player })
	local pads = table.clone(arenaSpawns)
	for i = #pads, 2, -1 do
		local j = rng:NextInteger(1, i)
		pads[i], pads[j] = pads[j], pads[i]
	end
	for i, player in participants do
		local pad = pads[((i - 1) % #pads) + 1]
		lastArenaPad[player] = pad
		requestLoad(player, "arena", pad)
	end
end

-- Respawns every player in the lobby.
function PlayerStateService.ReturnAllToLobby()
	for _, player in Players:GetPlayers() do
		requestLoad(player, "lobby", pickLobbyPad())
	end
end

---------------------------------------------------------------------------------------------------
-- Player lifecycle

local function onCharacterAdded(player: Player, character: Model)
	player:SetAttribute(ALIVE_ATTR, true)
	applyProtection(player)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Connect(function()
		if player.Character ~= character then
			return -- stale character
		end
		player:SetAttribute(ALIVE_ATTR, false)
		clearShield(player)
		PlayerStateService.RefreshRespawnLocation(player)
		for _, callback in diedCallbacks do
			task.spawn(callback, player)
		end
	end)
end

local function onPlayerAdded(player: Player)
	-- Set the role and spawn point before the first character loads.
	PlayerStateService.SetRole(player, joinRole())
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
		-- Joined before the server was ready: make sure they are standing in the right place.
		if arenaPhase and PlayerStateService.GetRole(player) == Roles.Participant then
			requestLoad(player, "arena", pickArenaPad(player))
		else
			requestLoad(player, "lobby", pickLobbyPad())
		end
	end
end

local function onPlayerRemoving(player: Player)
	bumpSpawnGeneration(player) -- invalidates any pending load
	spawnGeneration[player] = nil
	loadsPerformed[player] = nil
	pendingSpawn[player] = nil
	lastArenaPad[player] = nil
	for _, callback in leftCallbacks do
		task.spawn(callback, player)
	end
end

-- Out-of-bounds elimination and spectator containment.
local function watchdog()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if rootPart and rootPart:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local position = rootPart.Position
			if position.Y < Config.OutOfBoundsY then
				humanoid.Health = 0
			elseif PlayerStateService.GetRole(player) ~= Roles.Participant and insideArena(position) then
				local pad = pickLobbyPad()
				character:PivotTo(pad.CFrame + Vector3.new(0, pad.Size.Y / 2 + 3, 0))
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Setup

function PlayerStateService.OnPlayerLeft(callback: (Player) -> ())
	table.insert(leftCallbacks, callback)
end

function PlayerStateService.OnPlayerDied(callback: (Player) -> ())
	table.insert(diedCallbacks, callback)
end

-- MatchService supplies the role given to players who join (Lobby, or Spectator mid-match).
function PlayerStateService.SetJoinPolicy(policy: () -> string)
	joinRole = policy
end

-- Returns a list of problems (empty when the lobby spawns are usable).
function PlayerStateService.Init(): { string }
	local problems = {}
	local root = workspace:WaitForChild(Config.RootName)
	local lobby = root:WaitForChild("Lobby", 10)
	for _, inst in CollectionService:GetTagged(Config.LobbySpawnTag) do
		if lobby and inst:IsDescendantOf(lobby) then
			if inst:IsA("SpawnLocation") and inst.Enabled and inst.Neutral and inst.Anchored and inst.CanCollide then
				table.insert(lobbySpawns, inst)
			else
				table.insert(problems, `{inst:GetFullName()}: LobbySpawn must be an enabled, neutral, anchored, collidable SpawnLocation`)
			end
		end
	end
	if #lobbySpawns == 0 then
		table.insert(problems, "no usable LobbySpawn under Workspace.WORLD_EXE.Lobby")
	end
	arenaSpawns = ArenaService.GetSpawns()
	if #arenaSpawns == 0 then
		table.insert(problems, "no arena spawns")
	end
	return problems
end

function PlayerStateService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	task.spawn(function()
		while true do
			task.wait(WATCHDOG_SECONDS)
			local ok, err = pcall(watchdog)
			if not ok then
				warn(`[WORLD_EXE] PlayerStateService watchdog error: {err}`)
			end
		end
	end)
end

return PlayerStateService

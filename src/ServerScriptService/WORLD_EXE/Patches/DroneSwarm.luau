--!strict
-- DRONE_SWARM (Phase 4): a small, capped group of hostile drones, fully server-owned.
-- * Capacity policy: all or nothing. A swarm spawns exactly DRONES_PER_PATCH drones at distinct
--   DroneWaypoint parts, or none: if fewer than DRONES_PER_PATCH drone slots (MAX_DRONES across
--   every DRONE_SWARM patch) or waypoints are free, activation fails (full rollback, slot freed).
--   Partial swarms are never spawned.
-- * One tracked loop per patch steps every drone at a bounded rate (STEP_SECONDS) and re-picks
--   targets every RETARGET_SECONDS. There is no per-frame work and no pathfinding: drones patrol
--   the waypoint graph (Links) and chase only a target they can see.
-- * Targets: living Participants only (never Lobby, Spectators or dead players), within
--   AGGRO_RANGE with clear line of sight. A lock is dropped when the target becomes ineligible,
--   moves beyond DISENGAGE_RANGE (checked every step), or breaks line of sight (checked every
--   retarget). Drones are slower than players, so running away always escapes.
-- * Damage is telegraphed and bounded: a locked drone turns amber, and a hit needs range, line of
--   sight, the drone's own cooldown and a per-player cooldown shared by all drones. HIT_DAMAGE is
--   far below max health, never an instant elimination. Protection order: spawn protection
--   (ForceField) blocks the hit without using anything; otherwise a supply-drop shield blocks it
--   and is used up; otherwise the player takes damage.
-- * Drones are placeholder neon spheres built in code (anchored, no collision, ignored by
--   raycasts) until drone artwork is approved. Everything is in the patch's cleanup bag.
-- * HUNTER_SCAN (Phase 7A combination, BLACKOUT + DRONE_SWARM) adds a hunter token while it runs:
--   drones show a scan cone (cyan idle, amber when focusing), acquire from HUNTER_AGGRO_MULTIPLIER
--   farther, and every new lock first shows an amber pre-lock warning for PRELOCK_SECONDS. Damage
--   rules are unchanged.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerStateService = require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))

-- Server-only tuning (initial proposals; tune in playtests).
local DRONES_PER_PATCH = 3
local MAX_DRONES = 6
local STEP_SECONDS = 0.1
local RETARGET_SECONDS = 1
local SPEED = 14 -- studs/s; default walk speed is 16, so a player can always outrun a drone
local AGGRO_RANGE = 70 -- a new lock needs the target within this distance
local DISENGAGE_RANGE = 90 -- an existing lock is dropped beyond this distance
local HIT_RANGE = 5
local HIT_DAMAGE = 15
local DRONE_HIT_COOLDOWN = 1.5
local PLAYER_HIT_COOLDOWN = 0.75
local HOVER_OFFSET = Vector3.new(0, 2, 0)
local KEEP_DISTANCE = 2.5
local ARRIVE_DISTANCE = 1
local IDLE_COLOR = Color3.fromRGB(255, 70, 70)
local LOCKED_COLOR = Config.Palette.AmberWarning
local HUNTER_AGGRO_MULTIPLIER = 1.2
local PRELOCK_SECONDS = 1.5
local SCAN_COLOR = Config.Palette.NeonCyan

type Waypoint = { id: string, position: Vector3, links: { string } }
type Drone = {
	part: BasePart,
	waypoint: string,
	target: Player?,
	nextHit: number,
	pending: Player?, -- HUNTER_SCAN pre-lock candidate
	pendingAt: number,
	cone: BasePart?,
}

local activeDrones = 0
local playerNextHit: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
local stats = { Hits = 0, Blocked = 0, Protected = 0, Disengaged = 0, PreLockWarnings = 0 }
local hunters: { [string]: boolean } = {}

local function hunting(): boolean
	return next(hunters) ~= nil
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function loadWaypoints(): { [string]: Waypoint }
	local root = workspace:FindFirstChild(Config.RootName)
	local map = root and root:FindFirstChild("Map")
	local waypoints: { [string]: Waypoint } = {}
	if map then
		for _, inst in CollectionService:GetTagged(Config.Tags.DroneWaypoint) do
			local id = inst:GetAttribute("WaypointId")
			local links = inst:GetAttribute("Links")
			if inst:IsA("BasePart") and inst:IsDescendantOf(map) and typeof(id) == "string" and typeof(links) == "string" then
				waypoints[id] = { id = id, position = inst.Position, links = string.split(links, ",") }
			end
		end
	end
	return waypoints
end

local function rootPartOf(player: Player): BasePart?
	local character = player.Character
	local part = character and character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

local function isEligible(player: Player): boolean
	return player.Parent == Players
		and PlayerStateService.GetRole(player) == Config.Roles.Participant
		and PlayerStateService.IsAlive(player)
		and rootPartOf(player) ~= nil
end

local DroneSwarm = {}

function DroneSwarm.Activate(ctx: any)
	local waypoints = loadWaypoints()
	local ids = {}
	for id in waypoints do
		table.insert(ids, id)
	end
	if #ids == 0 then
		error("no DroneWaypoint parts in the arena")
	end
	if MAX_DRONES - activeDrones < DRONES_PER_PATCH then
		error(`drone cap reached ({activeDrones}/{MAX_DRONES}, a swarm needs {DRONES_PER_PATCH})`)
	end
	if #ids < DRONES_PER_PATCH then
		error(`not enough DroneWaypoints ({#ids}, a swarm needs {DRONES_PER_PATCH})`)
	end
	local count = DRONES_PER_PATCH
	local rng = Random.new()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true

	local function lineOfSight(from: Vector3, to: Vector3): boolean
		local exclude: { Instance } = { ctx.Folder }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(exclude, player.Character)
			end
		end
		params.FilterDescendantsInstances = exclude
		return workspace:Raycast(from, to - from, params) == nil
	end

	local drones: { Drone } = {}
	for i = 1, count do
		local id = table.remove(ids, rng:NextInteger(1, #ids)) :: string
		local part = Instance.new("Part")
		part.Name = `Drone_{ctx.RuntimeId}_{i}`
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(3, 3, 3)
		part.Material = Enum.Material.Neon
		part.Color = IDLE_COLOR
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CFrame = CFrame.new(waypoints[id].position)
		local light = Instance.new("PointLight")
		light.Color = IDLE_COLOR
		light.Range = 12
		light.Parent = part
		part.Parent = ctx.Folder
		ctx.Add(part)
		activeDrones += 1
		ctx.Add(function()
			activeDrones -= 1
		end)
		table.insert(drones, { part = part, waypoint = id, target = nil, nextHit = 0, pending = nil, pendingAt = 0, cone = nil })
	end

	local function nearestWaypoint(position: Vector3): string
		local best, bestDistance = nil, math.huge
		for id, waypoint in waypoints do
			local distance = (waypoint.position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = id, distance
			end
		end
		return best :: string
	end

	local function pickTarget(drone: Drone): Player?
		local position = drone.part.Position
		local best, bestDistance = nil, AGGRO_RANGE * (if hunting() then HUNTER_AGGRO_MULTIPLIER else 1)
		for _, player in Players:GetPlayers() do
			local rootPart = rootPartOf(player)
			if rootPart and isEligible(player) then
				local distance = (rootPart.Position - position).Magnitude
				if distance <= bestDistance and lineOfSight(position, rootPart.Position) then
					best, bestDistance = player, distance
				end
			end
		end
		return best
	end

	local function setTarget(drone: Drone, target: Player?)
		if drone.target == target then
			return
		end
		if drone.target ~= nil and target == nil then
			drone.waypoint = nearestWaypoint(drone.part.Position)
		end
		drone.target = target
		local color = if target then LOCKED_COLOR else IDLE_COLOR
		drone.part.Color = color
		local light = drone.part:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = color
		end
	end

	local function hit(drone: Drone, player: Player)
		local t = now()
		drone.nextHit = t + DRONE_HIT_COOLDOWN
		playerNextHit[player] = t + PLAYER_HIT_COOLDOWN
		-- Spawn protection first: it blocks the hit without using up a supply shield.
		if player.Character and player.Character:FindFirstChildOfClass("ForceField") then
			stats.Protected += 1
			return
		end
		if PlayerStateService.ConsumeShield(player) then
			stats.Blocked += 1
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			stats.Hits += 1
			humanoid:TakeDamage(HIT_DAMAGE)
		end
	end

	-- HUNTER_SCAN scan cone: points at the focused player (amber) or straight down (cyan).
	local function updateCone(drone: Drone)
		if not hunting() then
			if drone.cone then
				drone.cone:Destroy()
				drone.cone = nil
			end
			drone.pending = nil
			return
		end
		local cone = drone.cone
		if cone == nil or cone.Parent == nil then
			local newCone = Instance.new("Part")
			newCone.Name = "ScanCone"
			newCone.Anchored = true
			newCone.CanCollide = false
			newCone.CanQuery = false
			newCone.CanTouch = false
			newCone.CastShadow = false
			newCone.Material = Enum.Material.Neon
			newCone.Transparency = 0.6
			newCone.Parent = drone.part
			drone.cone = newCone
			cone = newCone
		end
		local focus = drone.target or drone.pending
		local focusRoot = focus and rootPartOf(focus)
		local from = drone.part.Position
		local to = if focusRoot then focusRoot.Position else from + Vector3.new(0, -10, 0)
		local length = math.clamp((to - from).Magnitude, 1, AGGRO_RANGE * HUNTER_AGGRO_MULTIPLIER)
		local beam = cone :: BasePart
		beam.Size = Vector3.new(1.2, 1.2, length)
		beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
		beam.Color = if focus then LOCKED_COLOR else SCAN_COLOR
	end

	local function step(drone: Drone, dt: number, retarget: boolean)
		if drone.part.Parent == nil then
			return
		end
		local target = drone.target
		if target and not isEligible(target) then
			setTarget(drone, nil)
			target = nil
		end
		if target then
			local targetRoot = rootPartOf(target)
			if targetRoot == nil or (targetRoot.Position - drone.part.Position).Magnitude > DISENGAGE_RANGE then
				stats.Disengaged += 1
				setTarget(drone, nil)
				target = nil
			end
		end
		if retarget then
			local rootPart = target and rootPartOf(target)
			if target == nil or rootPart == nil or not lineOfSight(drone.part.Position, rootPart.Position) then
				local candidate = pickTarget(drone)
				local lock = candidate
				if candidate and candidate ~= target and hunting() then
					-- HUNTER_SCAN: a visible amber pre-lock warning precedes every new lock.
					if drone.pending ~= candidate then
						drone.pending, drone.pendingAt = candidate, now()
						stats.PreLockWarnings += 1
					end
					if now() - drone.pendingAt < PRELOCK_SECONDS then
						lock = nil
					end
				end
				if candidate == nil or lock ~= nil then
					drone.pending = nil
				end
				setTarget(drone, lock)
				target = drone.target
			end
		end
		local position = drone.part.Position
		local goal: Vector3
		local stopAt = 0
		local rootPart = target and rootPartOf(target)
		if target and rootPart then
			goal = rootPart.Position + HOVER_OFFSET
			stopAt = KEEP_DISTANCE
		else
			local waypoint = waypoints[drone.waypoint]
			if (waypoint.position - position).Magnitude <= ARRIVE_DISTANCE then
				local links = waypoint.links
				local nextId = links[rng:NextInteger(1, #links)]
				drone.waypoint = if waypoints[nextId] then nextId else drone.waypoint
				waypoint = waypoints[drone.waypoint]
			end
			goal = waypoint.position
		end
		local offset = goal - position
		local distance = offset.Magnitude
		if distance > stopAt then
			local move = math.min(SPEED * dt, distance - stopAt)
			drone.part.CFrame = CFrame.new(position + offset.Unit * move)
		end
		if target and rootPart then
			local t = now()
			if (drone.part.Position - rootPart.Position).Magnitude <= HIT_RANGE
				and t >= drone.nextHit
				and t >= (playerNextHit[target] or 0)
				and lineOfSight(drone.part.Position, rootPart.Position)
			then
				hit(drone, target)
			end
		end
		updateCone(drone)
	end

	ctx.Spawn(function()
		local sinceRetarget = RETARGET_SECONDS
		local warned = false
		while ctx.IsLive() do
			local dt = task.wait(STEP_SECONDS)
			if not ctx.IsLive() then
				break
			end
			sinceRetarget += dt
			local retarget = sinceRetarget >= RETARGET_SECONDS
			if retarget then
				sinceRetarget = 0
			end
			local ok, err = pcall(function()
				for _, drone in drones do
					step(drone, dt, retarget)
				end
			end)
			if not ok and not warned then
				warned = true
				warn(`[WORLD_EXE] Patch {ctx.RuntimeId} drone step failed: {err}`)
			end
		end
	end)
end

-- HUNTER_SCAN tokens (Phase 7A combination).
function DroneSwarm.AddHunter(token: string)
	hunters[token] = true
end

function DroneSwarm.RemoveHunter(token: string)
	hunters[token] = nil
end

function DroneSwarm.IsHunting(): boolean
	return hunting()
end

-- Drones alive across every DRONE_SWARM patch (for tests and diagnostics).
function DroneSwarm.GetActiveCount(): number
	return activeDrones
end

-- Server-side hit counters since server start (for tests).
function DroneSwarm.GetStats(): { Hits: number, Blocked: number, Protected: number, Disengaged: number, PreLockWarnings: number }
	return table.clone(stats)
end

DroneSwarm.Tuning = table.freeze({
	DronesPerPatch = DRONES_PER_PATCH,
	MaxDrones = MAX_DRONES,
	StepSeconds = STEP_SECONDS,
	RetargetSeconds = RETARGET_SECONDS,
	Speed = SPEED,
	AggroRange = AGGRO_RANGE,
	DisengageRange = DISENGAGE_RANGE,
	HitRange = HIT_RANGE,
	HitDamage = HIT_DAMAGE,
	DroneHitCooldown = DRONE_HIT_COOLDOWN,
	PlayerHitCooldown = PLAYER_HIT_COOLDOWN,
})

return table.freeze(DroneSwarm)

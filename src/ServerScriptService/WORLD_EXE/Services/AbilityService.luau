--!strict
-- AbilityService (Phase 6, server only): PHASE_DASH, ANCHOR and SCANNER.
-- * Clients send intent only: RequestAbility { abilityId = "<id>" } — exactly that one key. Every
--   request is rate-limited, validated (payload, match live, living Participant, cooldown) and
--   answered on AbilityFeedback. The server computes every effect; no client position, direction,
--   target or duration is accepted.
-- * Cooldowns are match-scoped (all ready when ACTIVE begins) and start only on success. The
--   ready time and active-until time are mirrored to server-set player attributes for the HUD.
-- * PHASE_DASH: instant horizontal move along the character's facing. Checks: the start is not
--   inside geometry, a character-sized blockcast sweep stops before obstacles, and the landing is
--   inside the arena bounds, has collidable floor below it and is not inside geometry. Otherwise it
--   steps back toward the start; under DASH_MIN it is rejected without using the cooldown.
-- * ANCHOR (approved A1 + P5): counters movement disturbances only — reduced gravity, BOUNCY
--   launches (Bouncy skips anchored players) and SLIPPERY pads (horizontal damping force while on
--   an active pad). Never a shield.
--   A VectorForce in world coordinates at the assembly's centre of mass cancels reduced
--   gravity for that character only (force = mass x (baseline - current gravity), downward). It
--   never touches Workspace.Gravity. Updated when gravity or the character's parts change.
-- * SCANNER: the server picks up to SCAN_MAX nearby fragments, drones, supply crates and unsafe
--   DECAY tiles (closest first) and sends them to that player only; the client shows temporary
--   highlights. No gameplay effect.
-- * Effects end on expiry, death, role change, character removal, departure, RESULTS, RESET,
--   recovery and shutdown. Each effect owns a CleanupService bag; an early end tells the client.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local AbilityCatalog = require(shared:WaitForChild("AbilityCatalog"))
local services = script.Parent
local NetService = require(services:WaitForChild("NetService"))
local PlayerStateService = require(services:WaitForChild("PlayerStateService"))
local CleanupService = require(services:WaitForChild("CleanupService"))
local WorldModifierService = require(services:WaitForChild("WorldModifierService"))
local CollectibleService = require(services:WaitForChild("CollectibleService"))
local patchModules = services.Parent:WaitForChild("Patches")
local Decay = require(patchModules:WaitForChild("Decay"))
local Bouncy = require(patchModules:WaitForChild("Bouncy"))
local Slippery = require(patchModules:WaitForChild("Slippery"))
local Corruption = require(patchModules:WaitForChild("Corruption"))
local Magnetic = require(patchModules:WaitForChild("Magnetic"))

-- Server-only tuning (provisional).
local RATE_BURST = 4
local RATE_PER_SECOND = 2
local MAX_ID_LENGTH = 32
local DASH_DISTANCE = 16
local DASH_MIN = 3
local DASH_STEP = 2
local DASH_SKIN = 1.5 -- stop this far before an obstacle
local DASH_FLOOR_RAY = 12 -- floor must be within this distance below the root part
local BODY_SIZE = Vector3.new(2, 4, 2) -- check box centred on the root part (clears the floor)
local SCAN_RANGE = 60
local SCAN_MAX = 20
local ANCHOR_SLIP_DAMPING = 8 -- 1/s; sliding on an active SLIPPERY pad decays fast while anchored
local ANCHOR_FLOOR_RAY = 6

type Effect = { seq: number, bag: CleanupService.Bag, endsAt: number }
type State = {
	ready: { [string]: number },
	effects: { [string]: Effect },
	seq: number,
	tokens: number,
	updated: number,
}

local AbilityService = {}

local states: { [Player]: State } = {}
local active = false
local feedback: RemoteEvent? = nil
local isLive: () -> boolean = function()
	return false
end
local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.RespectCanCollide = true
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.RespectCanCollide = true

local function now(): number
	return workspace:GetServerTimeNow()
end

local function readyAttr(id: string): string
	return Config.PlayerAttributes.AbilityReadyPrefix .. id
end

local function activeAttr(id: string): string
	return Config.PlayerAttributes.AbilityActivePrefix .. id
end

local function getState(player: Player): State
	local st = states[player]
	if st == nil then
		st = { ready = {}, effects = {}, seq = 0, tokens = RATE_BURST, updated = now() }
		states[player] = st
	end
	return st
end

local function send(player: Player, data: { [string]: any })
	if feedback and player.Parent == Players then
		feedback:FireClient(player, data)
	end
end

local function endEffect(player: Player, id: string, reason: string)
	local st = states[player]
	local effect = st and st.effects[id]
	if st == nil or effect == nil then
		return
	end
	st.effects[id] = nil
	effect.bag:Cleanup()
	if player.Parent == Players then
		player:SetAttribute(activeAttr(id), nil)
	end
	if reason ~= "expired" then
		send(player, { abilityId = id, ok = true, cancelled = true, seq = effect.seq, reason = reason })
	end
end

local function endAll(player: Player, reason: string)
	local st = states[player]
	if st then
		for id in table.clone(st.effects) do
			endEffect(player, id, reason)
		end
	end
end

-- Returns the ability id for a well-formed payload: a table with exactly one key, abilityId,
-- naming a catalog ability.
local function validatePayload(payload: any): string?
	if typeof(payload) ~= "table" then
		return nil
	end
	local keys = 0
	for key in payload do
		keys += 1
		if key ~= "abilityId" then
			return nil
		end
	end
	local id = payload.abilityId
	if keys ~= 1 or typeof(id) ~= "string" or #id > MAX_ID_LENGTH or AbilityCatalog.Get(id) == nil then
		return nil
	end
	return id
end

local function body(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and root and root:IsA("BasePart") and humanoid then
		return character, root, humanoid
	end
	return nil, nil, nil
end

-- Ends the effect when its owner dies, changes role or loses the character.
local function watch(player: Player, id: string, bag: CleanupService.Bag, character: Model, humanoid: Humanoid)
	bag:Add(humanoid.Died:Connect(function()
		endEffect(player, id, "died")
	end))
	bag:Add(player:GetAttributeChangedSignal(Config.PlayerAttributes.Role):Connect(function()
		endEffect(player, id, "role_changed")
	end))
	bag:Add(character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			endEffect(player, id, "character_removed")
		end
	end))
end

---------------------------------------------------------------------------------------------------
-- PHASE_DASH

local function exclusions(): { Instance }
	local list: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	local root = workspace:FindFirstChild(Config.RootName)
	if root then
		for _, name in Config.RuntimeFolders do
			local folder = root:FindFirstChild(name)
			if folder then
				table.insert(list, folder)
			end
		end
	end
	return list
end

local function occupied(position: Vector3): boolean
	return #workspace:GetPartBoundsInBox(CFrame.new(position), BODY_SIZE, overlapParams) > 0
end

local function hasFloor(position: Vector3): boolean
	return workspace:Raycast(position, Vector3.new(0, -DASH_FLOOR_RAY, 0), castParams) ~= nil
end

local function inBounds(position: Vector3): boolean
	local lo, hi = Config.ArenaBoundsMin, Config.ArenaBoundsMax
	return position.X >= lo.X and position.X <= hi.X and position.Y >= lo.Y and position.Y <= hi.Y and position.Z >= lo.Z and position.Z <= hi.Z
end

local function dash(character: Model, root: BasePart): (boolean, string, number?)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		return false, "blocked", nil
	end
	local direction = flat.Unit
	local exclude = exclusions()
	castParams.FilterDescendantsInstances = exclude
	overlapParams.FilterDescendantsInstances = exclude
	local start = root.Position
	if occupied(start) then
		return false, "start_blocked", nil
	end
	local reach = DASH_DISTANCE
	local hit = workspace:Blockcast(CFrame.new(start), BODY_SIZE, direction * DASH_DISTANCE, castParams)
	if hit then
		reach = math.max(0, hit.Distance - DASH_SKIN)
	end
	local distance = reach
	while distance >= DASH_MIN do
		local landing = start + direction * distance
		if inBounds(landing) and hasFloor(landing) and not occupied(landing) then
			local rotation = root.CFrame - root.CFrame.Position
			character:PivotTo(CFrame.new(landing) * rotation)
			root.AssemblyLinearVelocity = Vector3.zero
			return true, "dashed", distance
		end
		distance -= DASH_STEP
	end
	return false, if reach < DASH_MIN then "blocked" else "no_ground", nil
end

---------------------------------------------------------------------------------------------------
-- ANCHOR

local function anchor(player: Player, character: Model, root: BasePart, humanoid: Humanoid): CleanupService.Bag
	local bag = CleanupService.new(`Anchor_{player.UserId}`)
	local attachment = Instance.new("Attachment")
	attachment.Name = "WORLD_EXE_AnchorAttachment"
	local force = Instance.new("VectorForce")
	force.Name = "WORLD_EXE_Anchor"
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.zero
	attachment.Parent = root
	force.Parent = root
	bag:Add(force)
	bag:Add(attachment)
	-- Approved P5: on an active SLIPPERY pad, a second world-space force at the centre of mass damps
	-- horizontal sliding (F = -mass x ANCHOR_SLIP_DAMPING x horizontal velocity). Zero elsewhere.
	local grip = Instance.new("VectorForce")
	grip.Name = "WORLD_EXE_AnchorGrip"
	grip.Attachment0 = attachment
	grip.RelativeTo = Enum.ActuatorRelativeTo.World
	grip.ApplyAtCenterOfMass = true
	grip.Force = Vector3.zero
	grip.Parent = root
	bag:Add(grip)
	local floorParams = RaycastParams.new()
	floorParams.FilterType = Enum.RaycastFilterType.Exclude
	floorParams.FilterDescendantsInstances = { character }
	bag:Add(RunService.Heartbeat:Connect(function()
		if grip.Parent == nil or root.Parent == nil then
			return
		end
		local floor = workspace:Raycast(root.Position, Vector3.new(0, -ANCHOR_FLOOR_RAY, 0), floorParams)
		if floor and Slippery.IsActive(floor.Instance) then
			local v = root.AssemblyLinearVelocity
			grip.Force = Vector3.new(-v.X, 0, -v.Z) * root.AssemblyMass * ANCHOR_SLIP_DAMPING
		elseif grip.Force ~= Vector3.zero then
			grip.Force = Vector3.zero
		end
	end))
	local function update()
		if force.Parent == nil or root.Parent == nil then
			return
		end
		local missing = math.max(0, WorldModifierService.GetBaseline("Gravity") - workspace.Gravity)
		force.Force = Vector3.new(0, -missing * root.AssemblyMass, 0)
	end
	update()
	bag:Add(workspace:GetPropertyChangedSignal("Gravity"):Connect(update))
	bag:Add(character.DescendantAdded:Connect(function()
		task.defer(update)
	end))
	bag:Add(character.DescendantRemoving:Connect(function()
		task.defer(update)
	end))
	watch(player, "ANCHOR", bag, character, humanoid)
	return bag
end

---------------------------------------------------------------------------------------------------
-- SCANNER

local function scan(root: BasePart): { { Target: BasePart, Kind: string } }
	local origin = root.Position
	local found: { { Target: BasePart, Kind: string, Distance: number } } = {}
	local function consider(inst: Instance, kind: string)
		if inst:IsA("BasePart") and inst.Parent ~= nil then
			local distance = (inst.Position - origin).Magnitude
			if distance <= SCAN_RANGE then
				table.insert(found, { Target = inst, Kind = kind, Distance = distance })
			end
		end
	end
	for _, fragment in CollectibleService.GetFragments() do
		consider(fragment, "fragment")
	end
	local wsRoot = workspace:FindFirstChild(Config.RootName)
	local patchFolder = wsRoot and wsRoot:FindFirstChild("ActivePatchInstances")
	if patchFolder then
		for _, child in patchFolder:GetChildren() do
			if string.sub(child.Name, 1, 6) == "Drone_" then
				consider(child, "drone")
			elseif string.sub(child.Name, 1, 12) == "SupplyCrate_" then
				consider(child, "crate")
			end
		end
	end
	for _, tile in Decay.GetClaimedTiles() do
		consider(tile, "decay")
	end
	for _, pad in Bouncy.GetActivePads() do
		consider(pad, "bounce")
	end
	for _, pad in Slippery.GetActivePads() do
		consider(pad, "slip")
	end
	for _, node in Corruption.GetActiveNodes() do
		consider(node, "corrupt")
	end
	for _, prop in Magnetic.GetActiveProps() do
		consider(prop, "prop")
	end
	table.sort(found, function(a, b)
		return a.Distance < b.Distance
	end)
	local list = {}
	for i = 1, math.min(SCAN_MAX, #found) do
		table.insert(list, { Target = found[i].Target, Kind = found[i].Kind })
	end
	return list
end

---------------------------------------------------------------------------------------------------
-- Requests

local function reject(player: Player, id: string?, reason: string): (boolean, string)
	send(player, { abilityId = id, ok = false, reason = reason })
	return false, reason
end

-- Validates and runs one request (also used directly by tests). Returns (ok, reason).
function AbilityService.Request(player: Player, payload: any): (boolean, string)
	local st = getState(player)
	local t = now()
	st.tokens = math.min(RATE_BURST, st.tokens + (t - st.updated) * RATE_PER_SECOND)
	st.updated = t
	if st.tokens < 1 then
		return reject(player, nil, "rate_limited")
	end
	st.tokens -= 1
	local id = validatePayload(payload)
	if id == nil then
		return reject(player, nil, "bad_payload")
	end
	if not active or not isLive() then
		return reject(player, id, "not_live")
	end
	if PlayerStateService.GetRole(player) ~= Config.Roles.Participant then
		return reject(player, id, "not_participant")
	end
	local character, root, humanoid = body(player)
	if character == nil or root == nil or humanoid == nil or not PlayerStateService.IsAlive(player) then
		return reject(player, id, "not_alive")
	end
	if t < (st.ready[id] or 0) or st.effects[id] then
		return reject(player, id, "cooldown")
	end
	local def = AbilityCatalog.Get(id) :: AbilityCatalog.AbilityDefinition
	st.seq += 1
	local seq = st.seq
	local bag: CleanupService.Bag? = nil
	local targets = nil
	local result = "activated"
	if id == "PHASE_DASH" then
		local ok, reason, distance = dash(character, root)
		if not ok then
			return reject(player, id, reason)
		end
		result = `dashed {string.format("%.1f", distance or 0)}`
	elseif id == "ANCHOR" then
		bag = anchor(player, character, root, humanoid)
	elseif id == "SCANNER" then
		local scanBag = CleanupService.new(`Scanner_{player.UserId}`)
		watch(player, id, scanBag, character, humanoid)
		bag = scanBag
		targets = scan(root)
	end
	st.ready[id] = t + def.CooldownSeconds
	player:SetAttribute(readyAttr(id), st.ready[id])
	local activeUntil = nil
	if bag then
		local effect: Effect = { seq = seq, bag = bag, endsAt = t + def.DurationSeconds }
		st.effects[id] = effect
		activeUntil = effect.endsAt
		player:SetAttribute(activeAttr(id), activeUntil)
		task.delay(def.DurationSeconds, function()
			local current = states[player]
			if current and current.effects[id] == effect then
				endEffect(player, id, "expired")
			end
		end)
	end
	send(player, { abilityId = id, ok = true, reason = result, seq = seq, readyAt = st.ready[id], activeUntil = activeUntil, targets = targets })
	return true, result
end

---------------------------------------------------------------------------------------------------
-- Lifecycle

-- Opens abilities for a live match with every cooldown ready.
function AbilityService.Begin()
	AbilityService.Reset()
	active = true
end

-- Ends every running effect and blocks requests (RESULTS). Idempotent.
function AbilityService.Stop()
	active = false
	for player in table.clone(states) do
		endAll(player, "match_end")
	end
end

-- Stop() plus cooldowns and attributes (RESET, recovery, shutdown). Idempotent.
function AbilityService.Reset()
	AbilityService.Stop()
	for _, st in states do
		table.clear(st.ready)
	end
	for _, player in Players:GetPlayers() do
		for _, id in AbilityCatalog.Ids() do
			player:SetAttribute(readyAttr(id), nil)
			player:SetAttribute(activeAttr(id), nil)
		end
	end
end

function AbilityService.OnPlayerLeft(player: Player)
	endAll(player, "left")
	states[player] = nil
end

-- Running effects (for tests and diagnostics).
function AbilityService.GetActiveEffectCount(): number
	local n = 0
	for _, st in states do
		for _ in st.effects do
			n += 1
		end
	end
	return n
end

-- deps.isLive(): true while the current match is ACTIVE or FINAL_PHASE.
function AbilityService.Init(deps: { isLive: () -> boolean })
	isLive = deps.isLive
	feedback = NetService.Get(Config.Remotes.AbilityFeedback)
	NetService.Get(Config.Remotes.RequestAbility).OnServerEvent:Connect(function(player: Player, payload: any)
		local ok, err = pcall(AbilityService.Request, player, payload)
		if not ok then
			warn(`[WORLD_EXE] Ability request from {player.Name} failed: {err}`)
		end
	end)
end

AbilityService.Tuning = table.freeze({
	DashDistance = DASH_DISTANCE,
	DashMin = DASH_MIN,
	ScanRange = SCAN_RANGE,
	ScanMax = SCAN_MAX,
	RateBurst = RATE_BURST,
	RatePerSecond = RATE_PER_SECOND,
})

return AbilityService

--!strict
-- HackEffects (wrist-hacking prototype, server): the four effects. Called only by HackService after
-- validation and a passed activation challenge. Every effect is temporary and always restores.
--
-- FLING_SELF  The server computes the launch velocity (fixed Up/Forward along the sanitised
--             direction) and sends it to the OWNING client, which applies it (a player's character
--             is simulated by its own client; server-set velocity would be overwritten). The client
--             keeps normal Humanoid control, adds a bounded steer and releases on landing. No
--             ragdoll, no state change other than a jump.
-- FLING_TARGET Temporary ragdoll: every Motor6D except the root joint is disabled and mirrored by a
--             BallSocketConstraint; limbs collide; the server owns the physics during the ragdoll
--             (SetNetworkOwner(nil)) and applies the launch. Recovery re-enables the motors, removes
--             the constraints, stands the root upright, restores collisions, RequiresNeck and network
--             ownership (back to the player, or the server for NPCs). Recovery always runs by
--             MaxRagdollSeconds and is skipped only if the character died or was removed.
--             Bosses never ragdoll: the boss module staggers instead.
-- FREEZE      Anchors the target's root for Seconds, shows an ice highlight and a countdown label,
--             then unanchors and grants a short freeze immunity. Bosses: shorter, via boss module.
-- SHIELD      Player attribute WORLD_EXE_HackShieldUntil + a visual bubble welded to the root.
--             Only the prototype boss's attacks check it (not general invulnerability).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HackCatalog = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("HackCatalog"))
local HackTargets = require(script.Parent:WaitForChild("HackTargets"))

local A = HackCatalog.Attr
local T = HackCatalog.Tuning

local HackEffects = {}

local send: (player: Player, payload: { [string]: any }) -> () = function() end
function HackEffects.SetSender(fn: (Player, { [string]: any }) -> ())
	send = fn
end

-- Cosmetic broadcast to every client (launch VFX); never carries gameplay state.
local broadcast: (payload: { [string]: any }) -> () = function() end
function HackEffects.SetBroadcaster(fn: ({ [string]: any }) -> ())
	broadcast = fn
end
HackEffects.Broadcast = function(payload: { [string]: any })
	broadcast(payload)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function horizontal(v: Vector3): Vector3?
	local h = Vector3.new(v.X, 0, v.Z)
	if h.Magnitude < 0.05 or h.Magnitude ~= h.Magnitude then
		return nil
	end
	return h.Unit
end

---------------------------------------------------------------------------------------------------
-- FLING SELF

local ragdollLaunch: (Model, Humanoid, BasePart, Player?, Vector3, number) -> (boolean, string?) -- defined below

function HackEffects.FlingSelf(player: Player, dirHint: any): (boolean, string?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not hum or hum.Health <= 0 then
		return false, "no_character"
	end
	-- Direction: client hint (camera-relative move intent or facing) if it is a finite horizontal
	-- vector, else the Humanoid's move direction, else the character's facing.
	local dir: Vector3? = nil
	if typeof(dirHint) == "Vector3" then
		dir = horizontal(dirHint)
	end
	dir = dir or horizontal(hum.MoveDirection) or horizontal(root.CFrame.LookVector)
	local tune = HackCatalog.Tune
	local v = (dir :: Vector3) * tune("FlingSelf", "Forward") + Vector3.new(0, tune("FlingSelf", "Up"), 0)
	send(player, { op = "fling_self", v = v, steer = tune("FlingSelf", "SteerSpeed"), minAir = tune("FlingSelf", "MinAirSeconds"), maxT = tune("FlingSelf", "MaxFlightSeconds"), blocked = tune("FlingSelf", "BlockedSpeedFraction") })
	broadcast({ op = "vfx", kind = "launch", model = character, pos = root.Position, scale = 1 })
	return true, nil
end

---------------------------------------------------------------------------------------------------
-- RAGDOLL (FLING TARGET)

type RagdollState = {
	motors: { Motor6D },
	made: { Instance },
	collide: { [BasePart]: boolean },
	requiresNeck: boolean,
	player: Player?,
	done: boolean,
}
local ragdolls: { [Model]: RagdollState } = {}

local function isRootJoint(m: Motor6D): boolean
	return m.Name == "RootJoint" or m.Name == "Root" or (m.Part0 ~= nil and m.Part0.Name == "HumanoidRootPart")
end

local function setOwner(model: Model, owner: Player?)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not d.Anchored then
			pcall(function()
				if owner then
					if d:CanSetNetworkOwnership() then
						d:SetNetworkOwner(owner)
					end
				else
					d:SetNetworkOwner(nil)
				end
			end)
		end
	end
end

function HackEffects.IsRagdolled(model: Model): boolean
	local s = ragdolls[model]
	return s ~= nil and not s.done
end

local function recover(model: Model)
	local s = ragdolls[model]
	if not s or s.done then
		return
	end
	s.done = true
	ragdolls[model] = nil
	model:SetAttribute(A.RagdollUntil, nil)
	model:SetAttribute(A.FlingImmuneUntil, now() + HackCatalog.Tune("FlingTarget", "ImmunitySeconds"))
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not model.Parent or not hum or hum.Health <= 0 or not root then
		for _, inst in s.made do
			inst:Destroy()
		end
		return -- died or removed: nothing to stand up
	end
	for _, inst in s.made do
		inst:Destroy()
	end
	for _, m in s.motors do
		if m.Parent then
			m.Enabled = true
		end
	end
	for part, was in s.collide do
		if part.Parent then
			part.CanCollide = was
		end
	end
	-- Stand upright where the body landed, keep the yaw, small lift so feet clear the floor.
	local look = root.CFrame.LookVector
	local flat = horizontal(look) or Vector3.zAxis
	local pos = root.Position + Vector3.new(0, 1.5, 0)
	root.CFrame = CFrame.lookAt(pos, pos + flat)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	hum.RequiresNeck = s.requiresNeck
	hum.PlatformStand = false
	if s.player then
		setOwner(model, s.player)
		send(s.player, { op = "ragdoll", on = false })
	else
		setOwner(model, nil)
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end
HackEffects.Recover = recover

-- Shared ragdoll launch (owner reference clip 2026-11-16): a tall, fast upward arc with the body
-- limp and tumbling for the whole flight; it gets up shortly AFTER landing (not on a fixed timer).
-- Used by FLING TARGET on players, NPCs and the boss. Owner rule (2026-11-16): FLING ragdolls only
-- OTHER players and boss-type enemies; FLING SELF never ragdolls you.
ragdollLaunch = function(model: Model, hum: Humanoid, root: BasePart, player: Player?, v: Vector3, vfxScale: number): (boolean, string?)
	if ragdolls[model] then
		return false, "target_busy"
	end
	if root.Anchored then
		return false, "target_frozen"
	end
	local tune = HackCatalog.Tune
	local minLimp = tune("FlingTarget", "RagdollSeconds")
	local minAir = tune("FlingTarget", "MinAirSeconds")
	local landDelay = tune("FlingTarget", "LandRecoverDelay")
	local maxRagdoll = math.max(minLimp + 0.5, tune("FlingTarget", "MaxRagdollSeconds"))
	local s: RagdollState = { motors = {}, made = {}, collide = {}, requiresNeck = hum.RequiresNeck, player = player, done = false }
	ragdolls[model] = s
	hum.RequiresNeck = false
	hum.PlatformStand = true
	for _, m in model:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 and not isRootJoint(m) then
			local a0 = Instance.new("Attachment")
			a0.Name = "HackRagdollA0"
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "HackRagdollA1"
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Name = "HackRagdollSocket"
			bs.Attachment0 = a0
			bs.Attachment1 = a1
			bs.LimitsEnabled = true
			bs.UpperAngle = 70
			bs.TwistLimitsEnabled = true
			bs.TwistLowerAngle = -45
			bs.TwistUpperAngle = 45
			bs.Parent = m.Part0
			table.insert(s.made, a0)
			table.insert(s.made, a1)
			table.insert(s.made, bs)
			local nc = Instance.new("NoCollisionConstraint")
			nc.Part0 = m.Part0
			nc.Part1 = m.Part1
			nc.Parent = m.Part0
			table.insert(s.made, nc)
			m.Enabled = false
			table.insert(s.motors, m)
		end
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root and p.Parent and p.Parent.Name ~= "WristDevice" then
			s.collide[p] = p.CanCollide
			p.CanCollide = true
		end
	end
	setOwner(model, nil)
	if player then
		send(player, { op = "ragdoll", on = true, seconds = minLimp })
	else
		hum:ChangeState(Enum.HumanoidStateType.Physics)
	end
	-- launch every limb, plus a tumble around a horizontal axis across the flight direction
	local flat = horizontal(v) or Vector3.zAxis
	local tumbleAxis = Vector3.yAxis:Cross(flat :: Vector3)
	local spin = tumbleAxis * tune("FlingTarget", "TumbleSpeed") * (if math.random() < 0.5 then 1 else -1)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and not p.Anchored then
			p.AssemblyLinearVelocity = v
			p.AssemblyAngularVelocity = spin
		end
	end
	model:SetAttribute(A.RagdollUntil, now() + maxRagdoll)
	broadcast({ op = "vfx", kind = "launch", model = model, pos = root.Position, scale = vfxScale })
	-- Recovery: limp for at least minLimp; get up landDelay after touching the ground; hard cap maxRagdoll.
	local torso = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or root) :: BasePart
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.RespectCanCollide = true
	local t0 = os.clock()
	task.spawn(function()
		local landedAt: number? = nil
		while not s.done do
			local el = os.clock() - t0
			if el >= maxRagdoll then
				break
			end
			if not landedAt and el >= minAir and torso.Parent then
				local vy = torso.AssemblyLinearVelocity.Y
				if vy > -4 and workspace:Raycast(torso.Position, Vector3.new(0, -4.5, 0), params) then
					landedAt = os.clock()
					model:SetAttribute("HackLandedAt", now())
				end
			end
			if landedAt and os.clock() - landedAt >= landDelay and el >= minLimp then
				break
			end
			task.wait(0.05)
		end
		recover(model)
	end)
	local diedConn: RBXScriptConnection? = nil
	diedConn = hum.Died:Connect(function()
		if diedConn then
			diedConn:Disconnect()
		end
		recover(model) -- cleans up constraints; no stand-up on a dead body
	end)
	return true, nil
end

-- Exposed for the boss module (it unanchors the boss first and re-homes it after recovery).
function HackEffects.RagdollLaunch(model: Model, hum: Humanoid, root: BasePart, v: Vector3, vfxScale: number): (boolean, string?)
	return ragdollLaunch(model, hum, root, nil, v, vfxScale)
end

function HackEffects.FlingTarget(target: HackTargets.Target, from: Vector3): (boolean, string?)
	local root = target.Root
	local tune = HackCatalog.Tune
	local dir = horizontal(root.Position - from) or horizontal(root.CFrame.LookVector) or Vector3.zAxis
	local v = (dir :: Vector3) * tune("FlingTarget", "Forward") + Vector3.new(0, tune("FlingTarget", "Up"), 0)
	return ragdollLaunch(target.Model, target.Humanoid, root, target.Player, v, 0.9)
end

---------------------------------------------------------------------------------------------------
-- FREEZE

type FreezeState = { model: Model, root: BasePart, made: { Instance }, serial: number, done: boolean, player: Player? }
local freezes: { [Model]: FreezeState } = {}
local freezeSerial = 0

function HackEffects.IsFrozen(model: Model): boolean
	local s = freezes[model]
	return s ~= nil and not s.done
end

local function unfreeze(model: Model, serial: number?)
	local s = freezes[model]
	if not s or s.done or (serial and s.serial ~= serial) then
		return
	end
	s.done = true
	freezes[model] = nil
	for _, inst in s.made do
		inst:Destroy()
	end
	if s.root.Parent then
		s.root.Anchored = false
	end
	model:SetAttribute(A.FrozenUntil, nil)
	model:SetAttribute(A.FreezeImmuneUntil, now() + HackCatalog.Tune("Freeze", "ImmunitySeconds"))
	if s.player then
		send(s.player, { op = "frozen", on = false })
	end
end
HackEffects.Unfreeze = unfreeze

function HackEffects.Freeze(target: HackTargets.Target): (boolean, string?)
	local model = target.Model
	if freezes[model] then
		return false, "already_frozen"
	end
	if ragdolls[model] then
		return false, "target_busy"
	end
	local seconds = HackCatalog.Tune("Freeze", "Seconds")
	freezeSerial += 1
	local s: FreezeState = { model = model, root = target.Root, made = {}, serial = freezeSerial, done = false, player = target.Player }
	freezes[model] = s
	target.Root.AssemblyLinearVelocity = Vector3.zero
	target.Root.Anchored = true
	local hl = Instance.new("Highlight")
	hl.Name = "HackFreezeHighlight"
	hl.FillColor = Color3.fromRGB(175, 230, 255)
	hl.FillTransparency = 0.45
	hl.OutlineColor = Color3.fromRGB(0, 225, 255)
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model
	table.insert(s.made, hl)
	local bb = Instance.new("BillboardGui")
	bb.Name = "HackFreezeLabel"
	bb.Size = UDim2.fromOffset(120, 26)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = target.Root
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(175, 230, 255)
	label.TextStrokeTransparency = 0.3
	label.Text = "❄ FROZEN"
	label.Parent = bb
	bb.Parent = model
	table.insert(s.made, bb)
	model:SetAttribute(A.FrozenUntil, now() + seconds)
	if target.Player then
		send(target.Player, { op = "frozen", on = true, seconds = seconds })
	end
	local serial = s.serial
	task.spawn(function()
		local endsAt = now() + seconds
		while not s.done and now() < endsAt do
			label.Text = string.format("❄ FROZEN %.1f", math.max(0, endsAt - now()))
			task.wait(0.1)
		end
		unfreeze(model, serial)
	end)
	local diedConn: RBXScriptConnection? = nil
	diedConn = target.Humanoid.Died:Connect(function()
		if diedConn then
			diedConn:Disconnect()
		end
		unfreeze(model, serial)
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			unfreeze(model, serial)
		end
	end)
	return true, nil
end

---------------------------------------------------------------------------------------------------
-- SHIELD

type ShieldState = { bubble: BasePart?, serial: number, endsAt: number }
local shields: { [Player]: ShieldState } = {}
local shieldSerial = 0

function HackEffects.HasShield(player: Player): boolean
	local untilT = player:GetAttribute(A.ShieldUntil)
	return typeof(untilT) == "number" and untilT > now()
end

local function endShield(player: Player, serial: number?)
	local s = shields[player]
	if not s or (serial and s.serial ~= serial) then
		return
	end
	shields[player] = nil
	if s.bubble then
		s.bubble:Destroy()
	end
	player:SetAttribute(A.ShieldUntil, nil)
end
HackEffects.EndShield = endShield

function HackEffects.Shield(player: Player): (boolean, string?)
	if shields[player] or HackEffects.HasShield(player) then
		return false, "already_active"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return false, "no_character"
	end
	local seconds = HackCatalog.Tune("Shield", "Seconds")
	shieldSerial += 1
	local bubble = Instance.new("Part")
	bubble.Name = "HackShieldBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(9, 9, 9)
	bubble.Material = Enum.Material.ForceField
	bubble.Color = Color3.fromRGB(60, 220, 140)
	bubble.Transparency = 0.15
	bubble.CanCollide = false
	bubble.CanTouch = false
	bubble.CanQuery = false
	bubble.Massless = true
	bubble.CastShadow = false
	bubble.CFrame = root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bubble
	weld.Part1 = root
	weld.Parent = bubble
	bubble.Parent = character
	local s: ShieldState = { bubble = bubble, serial = shieldSerial, endsAt = now() + seconds }
	shields[player] = s
	player:SetAttribute(A.ShieldUntil, s.endsAt)
	local serial = s.serial
	task.delay(seconds, function()
		endShield(player, serial)
	end)
	return true, nil
end

-- Flash the bubble when it blocks a hit (boss module calls this).
function HackEffects.ShieldBlocked(player: Player)
	local s = shields[player]
	if s and s.bubble then
		local b = s.bubble
		b.Color = Color3.fromRGB(245, 247, 255)
		task.delay(0.15, function()
			if b.Parent then
				b.Color = Color3.fromRGB(60, 220, 140)
			end
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- Cleanup on death / respawn / departure

function HackEffects.CleanupPlayer(player: Player)
	endShield(player)
	local character = player.Character
	if character then
		unfreeze(character)
		recover(character)
	end
end

function HackEffects.CleanupModel(model: Model)
	unfreeze(model)
	recover(model)
end

function HackEffects.Debug(): { [string]: number }
	local r, f, sh = 0, 0, 0
	for _ in ragdolls do
		r += 1
	end
	for _ in freezes do
		f += 1
	end
	for _ in shields do
		sh += 1
	end
	return { ragdolls = r, freezes = f, shields = sh }
end

return HackEffects

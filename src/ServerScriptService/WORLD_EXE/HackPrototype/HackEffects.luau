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
local RunService = game:GetService("RunService")

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
local flingSelfAt: { [Player]: number } = {} -- Rev 15b: last FLING SELF launch (landing-impact guard)

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
	-- Cyberware boots profile (Starter default). A live HackTune_FlingSelf_* attribute still overrides.
	local boots = (HackCatalog.Boots :: any)[player:GetAttribute(A.Boots) or "Starter"] or (HackCatalog.Boots :: any).Starter
	local function pick(key: string): number
		local live = workspace:GetAttribute("HackTune_FlingSelf_" .. key)
		if typeof(live) == "number" then
			return live
		end
		return boots[key] or tune("FlingSelf", key)
	end
	local v = (dir :: Vector3) * pick("Forward") + Vector3.new(0, pick("Up"), 0)
	send(player, { op = "fling_self", v = v, steer = pick("SteerSpeed"), minAir = tune("FlingSelf", "MinAirSeconds"), maxT = tune("FlingSelf", "MaxFlightSeconds"), blocked = tune("FlingSelf", "BlockedSpeedFraction"),
		turn = pick("TurnRate"), brake = tune("FlingSelf", "BrakeRate"), fallCap = tune("FlingSelf", "MaxFallSpeed"), glideCap = tune("FlingSelf", "GlideFallSpeed") })
	-- Rev 15b: resembles the regular fling — the same electric shock + cyan throw trail at launch and the
	-- same landing impact — with loose arms/legs in the air instead of a full ragdoll (control kept).
	broadcast({ op = "vfx", kind = "self_fling", model = character, pos = root.Position })
	flingSelfAt[player] = os.clock() -- the client loosens its own limbs (LooseLimbs, same frame as the launch)
	return true, nil
end

-- Client report: FLING SELF flight ended (landed / blocked / timeout). A landing gets the regular fling's landing impact (thud + dust + cyan sparks).
function HackEffects.FlingSelfEnd(player: Player, how: any, clientPos: any)
	local character = player.Character
	local at = flingSelfAt[player]
	if not character or not at or os.clock() - at > HackCatalog.Tune("FlingSelf", "MaxFlightSeconds") + 2 then
		return -- only right after a real FLING SELF (no free landing effects)
	end
	flingSelfAt[player] = nil
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if how == "landed" and root then
		-- the server's copy of a fast fall lags the owner by a few studs: use the client's landing point
		-- when it is plausibly close to the server position, else the server position
		local from = root.Position
		if typeof(clientPos) == "Vector3" and clientPos == clientPos and (clientPos - from).Magnitude < 25 then
			from = clientPos
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.RespectCanCollide = true
		local hit = workspace:Raycast(from + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
		if hit then
			broadcast({ op = "vfx", kind = "land", model = character, pos = hit.Position, strength = 0.55 })
		end
	end
end

---------------------------------------------------------------------------------------------------
-- RAGDOLL (FLING TARGET)

-- Rev 15b: newer Roblox avatars have no Motor6Ds. Each joint is an AnimationConstraint (e.g. "LeftWrist")
-- paired with a normally-disabled BallSocketConstraint ("LeftWristBallSocket"). Going limp = animation
-- joint off + ball socket on; restoring reverses it. (Found when FLING SELF's loose limbs did nothing
-- on the owner's avatar; the test dummies use Motor6Ds.)
type AnimSwap = { ac: AnimationConstraint, bs: BallSocketConstraint, bsWas: boolean }
local function animJointsLoose(model: Model, want: (string) -> boolean, made: { Instance }): { AnimSwap }
	local list: { AnimSwap } = {}
	for _, ac in model:GetDescendants() do
		if ac:IsA("AnimationConstraint") and ac.Enabled and want(ac.Name) and ac.Attachment0 and ac.Attachment1 and ac.Parent then
			local found = ac.Parent:FindFirstChild(ac.Name .. "BallSocket")
			local bs: BallSocketConstraint
			local was = false
			if found and found:IsA("BallSocketConstraint") then
				bs = found
				was = found.Enabled
			else
				bs = Instance.new("BallSocketConstraint")
				bs.Name = ac.Name .. "HackBallSocket"
				bs.Attachment0 = ac.Attachment0
				bs.Attachment1 = ac.Attachment1
				bs.LimitsEnabled = true
				bs.UpperAngle = 75
				bs.TwistLimitsEnabled = true
				bs.TwistLowerAngle = -45
				bs.TwistUpperAngle = 45
				bs.Parent = ac.Parent
				table.insert(made, bs)
			end
			bs.Enabled = true
			ac.Enabled = false
			table.insert(list, { ac = ac, bs = bs, bsWas = was })
		end
	end
	return list
end
local function animJointsRestore(list: { AnimSwap })
	for _, sw in list do
		if sw.ac.Parent then
			sw.ac.Enabled = true
		end
		if sw.bs.Parent then
			sw.bs.Enabled = sw.bsWas
		end
	end
end

type RagdollState = {
	motors: { Motor6D },
	anims: { AnimSwap },
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
	animJointsRestore(s.anims)
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


-- Shared ragdoll setup: limp joints (Motor6D -> BallSocket), limbs collide, server owns the physics.
local function ragdollBegin(model: Model, hum: Humanoid, root: BasePart, player: Player?): (RagdollState?, string?)
	if ragdolls[model] then
		return nil, "target_busy"
	end
	if root.Anchored then
		return nil, "target_frozen"
	end
	local minLimp = HackCatalog.Tune("FlingTarget", "RagdollSeconds")
	local s: RagdollState = { motors = {}, anims = {}, made = {}, collide = {}, requiresNeck = hum.RequiresNeck, player = player, done = false }
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
	s.anims = animJointsLoose(model, function(n: string): boolean
		return n ~= "Root" and n ~= "RootJoint"
	end, s.made)
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
	local diedConn: RBXScriptConnection? = nil
	diedConn = hum.Died:Connect(function()
		if diedConn then
			diedConn:Disconnect()
		end
		recover(model) -- cleans up constraints; no stand-up on a dead body
	end)
	return s, nil
end

-- Shared ragdoll launch (owner reference clip 2026-11-16): a tall, fast upward arc with the body
-- limp and tumbling for the whole flight; it gets up shortly AFTER landing (not on a fixed timer).
-- Used by FLING TARGET without a slide (players, NPCs, boss). Owner rule (2026-11-16): FLING ragdolls
-- only OTHER players and boss-type enemies; FLING SELF never ragdolls you.
ragdollLaunch = function(model: Model, hum: Humanoid, root: BasePart, player: Player?, v: Vector3, vfxScale: number): (boolean, string?)
	local s, why = ragdollBegin(model, hum, root, player)
	if not s then
		return false, why
	end
	local st = s :: RagdollState
	local tune = HackCatalog.Tune
	local minLimp = tune("FlingTarget", "RagdollSeconds")
	local minAir = tune("FlingTarget", "MinAirSeconds")
	local landDelay = tune("FlingTarget", "LandRecoverDelay")
	local maxRagdoll = math.max(minLimp + 0.5, tune("FlingTarget", "MaxRagdollSeconds"))
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
		while not st.done do
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
	return true, nil
end

-- Ragdoll GLIDE (owner 2026-11-16: the slide-throw "feels like an explosion"; banana-peel style
-- requested): the target's feet go out, it drops flat on its back with the feet leading, and it
-- glides ALONG THE GROUND in the slid direction, slowing smoothly (speed × (1 - t/T)^1.6). No spin
-- (an AlignOrientation keeps it flat), no blast; clients draw a dust scuff. It falls off ledges
-- naturally (only the horizontal plane is driven). It gets up GlideRestSeconds after stopping.
local ragdollGlide = function(model: Model, hum: Humanoid, root: BasePart, player: Player?, dir: Vector3, speed: number, seconds: number): (boolean, string?)
	local s, why = ragdollBegin(model, hum, root, player)
	if not s then
		return false, why
	end
	local st = s :: RagdollState
	local tune = HackCatalog.Tune
	local rest = tune("FlingTarget", "GlideRestSeconds")
	local minLimp = tune("FlingTarget", "RagdollSeconds")
	local maxRagdoll = math.max(minLimp + 0.5, seconds + rest + 2)
	-- tip over: lying on the back, head trailing, feet leading in the throw direction
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), params)
	local base = if hit then hit.Position else root.Position - Vector3.new(0, 2.5, 0)
	local pos = base + Vector3.new(0, 1.3, 0)
	local lying = CFrame.lookAt(pos, pos + Vector3.yAxis, -dir) -- front faces the sky, head points back
	root.CFrame = lying
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and not p.Anchored then
			p.AssemblyLinearVelocity = dir * speed
			p.AssemblyAngularVelocity = Vector3.zero
		end
	end
	local att = Instance.new("Attachment")
	att.Name = "HackGlideAttachment"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "HackGlideVelocity"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	lv.MaxForce = root.AssemblyMass * 4000
	lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * speed
	lv.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Name = "HackGlideUpright"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.CFrame = lying.Rotation
	ao.MaxTorque = root.AssemblyMass * 20000
	ao.Responsiveness = 40
	ao.Parent = root
	table.insert(st.made, att)
	table.insert(st.made, lv)
	table.insert(st.made, ao)
	model:SetAttribute(A.RagdollUntil, now() + maxRagdoll)
	broadcast({ op = "vfx", kind = "glide", model = model, dir = dir, seconds = seconds })
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		if st.done or not root.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local el = os.clock() - t0
		local k = math.max(0, 1 - el / seconds) ^ 1.6
		lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * speed * k
		if el >= seconds then
			if conn then
				conn:Disconnect()
			end
			lv.Enabled = false
			ao.Enabled = false
			model:SetAttribute("HackLandedAt", now())
			task.delay(math.max(rest, minLimp - el), function()
				recover(model)
			end)
		end
	end)
	task.delay(maxRagdoll, function()
		recover(model) -- hard cap
	end)
	return true, nil
end

---------------------------------------------------------------------------------------------------
-- FLING GRAB (owner 2026-11-16: "almost like the gravity gun"; the throw must not happen before the
-- attacker chooses). When FLING lands, the target goes limp and is HELD: lifted HoldHeight studs and
-- pulled smoothly (AlignPosition) toward the point the attacker's cursor points at, within HoldLeash
-- of the attacker. The attacker LEFT-CLICKS to throw it the way they are dragging the mouse (a
-- faster drag throws harder); no drag = straight away from the attacker. After HoldSeconds it is
-- thrown automatically in the last dragged direction. Server-authoritative: the client only sends
-- a hold point and a throw direction; both are validated and clamped here.
type Grab = {
	attacker: Player,
	model: Model,
	root: BasePart,
	st: RagdollState,
	att: Attachment,
	ap: AlignPosition,
	ao: AlignOrientation,
	boss: boolean,
	lastMode: string?,
	lastPoint: Vector3,
	anchor: Vector3, -- where it was grabbed (lifted); the hold may only sway HoldWiggle studs from here
	done: boolean,
}
local grabs: { [Player]: Grab } = {}

local function landRecovery(model: Model, root: BasePart, st: RagdollState, maxSeconds: number)
	local tune = HackCatalog.Tune
	local minLimp = tune("FlingTarget", "RagdollSeconds")
	local minAir = tune("FlingTarget", "MinAirSeconds")
	local landDelay = tune("FlingTarget", "LandRecoverDelay")
	local torso = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or root) :: BasePart
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.RespectCanCollide = true
	local t0 = os.clock()
	task.spawn(function()
		local landedAt: number? = nil
		while not st.done do
			local el = os.clock() - t0
			if el >= maxSeconds then
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
end

-- Rev 15d (owner 2026-11-16): "the fling should look as if they're getting dragged by their torso in the
-- direction they're flung". For DragSeconds from the throw (through the air AND the ground slide): the
-- CHEST is pulled along the horizontal throw direction (LinearVelocity, line mode; gravity untouched; the pull
-- eases off) and snapped to face it, pitched forward into the pull like a body yanked by the chest (measured:
-- leaning BACK put the legs ahead of the torso). Every other body
-- part is damped horizontally each frame, so head, arms, legs and hips TRAIL behind the torso. No spin.
local function torsoDrag(model: Model, torso: BasePart, flatDir: Vector3, speed: number)
	local tune = HackCatalog.Tune
	local att = Instance.new("Attachment")
	att.Name = "HackDragAttachment"
	att.Parent = torso
	local lv = Instance.new("LinearVelocity")
	lv.Name = "HackDragPull"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	lv.LineDirection = flatDir
	lv.LineVelocity = speed
	lv.MaxForce = 60000
	lv.Parent = torso
	local ao = Instance.new("AlignOrientation")
	ao.Name = "HackDragFacing"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.CFrame = CFrame.lookAt(Vector3.zero, flatDir) * CFrame.Angles(-math.rad(tune("FlingTarget", "DragLeanDegrees")), 0, 0) -- upper body pitched INTO the pull: legs trail behind and below
	ao.Responsiveness = 45
	ao.MaxTorque = 40000
	ao.Parent = torso
	local trailers: { BasePart } = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= torso and not p.Anchored and not p:IsDescendantOf(torso) then
			table.insert(trailers, p)
		end
	end
	local damp = tune("FlingTarget", "DragTrailDamping")
	local seconds = math.max(0.2, tune("FlingTarget", "DragSeconds"))
	-- snap the chest into the pull direction at release (the side throw is only ~0.5 s airborne)
	torso.CFrame = CFrame.new(torso.Position) * ao.CFrame -- moves its whole assembly (e.g. the root on R6)
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function(dt)
		local el = os.clock() - t0
		local phase = model:GetAttribute("HackFlingPhase")
		if not torso.Parent or el > seconds or (phase ~= "launched" and phase ~= "down") then
			if conn then
				conn:Disconnect()
			end
			lv:Destroy()
			ao:Destroy()
			att:Destroy()
			return
		end
		lv.LineVelocity = speed * (1 - 0.5 * el / seconds) -- eases to half, then the body slides on freely (keeps the throw distance)
		local k = math.clamp(1 - damp * dt, 0, 1)
		for _, p in trailers do
			if p.Parent then
				local v = p.AssemblyLinearVelocity
				p.AssemblyLinearVelocity = Vector3.new(v.X * k, v.Y, v.Z * k)
			end
		end
	end)
end

-- Rev 15: post-throw ragdoll for FLING TARGET, timed FROM THE THROW (owner-authorized).
-- Phases (attribute HackFlingPhase): "launched" (airborne, limp) -> "down" (first ground contact:
-- landing impact broadcast once) -> recovery. Recovery needs PostThrowSeconds elapsed AND the torso
-- grounded AND settled (speed < SettleSpeed for 0.15 s) — never mid-air, never mid-slide.
-- PostThrowCap always recovers (e.g. wedged on a ledge edge), and recover() lifts the body upright
-- by 1.5 studs so it cannot be trapped in the floor. A measurement string is left on the model.
local function postThrowRecovery(model: Model, root: BasePart, st: RagdollState, mode: string)
	local tune = HackCatalog.Tune
	local want = tune("FlingTarget", "PostThrowSeconds")
	local cap = math.max(want + 0.5, tune("FlingTarget", "PostThrowCap"))
	local minAir = tune("FlingTarget", "MinAirSeconds")
	local settle = tune("FlingTarget", "SettleSpeed")
	local torso = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or root) :: BasePart
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.RespectCanCollide = true
	local t0 = os.clock()
	local startPos = torso.Position
	local apex = startPos.Y
	task.spawn(function()
		local landedAt: number? = nil
		local calmFor = 0
		local last = os.clock()
		local ending = "cap"
		while not st.done do
			local tNow = os.clock()
			local dt = tNow - last
			last = tNow
			local el = tNow - t0
			if not torso.Parent then
				break
			end
			apex = math.max(apex, torso.Position.Y)
			local vel = torso.AssemblyLinearVelocity
			local hit = workspace:Raycast(torso.Position, Vector3.new(0, -4.5, 0), params)
			local grounded = hit ~= nil and vel.Y > -6
			if not landedAt and el >= minAir and grounded then
				landedAt = tNow
				model:SetAttribute("HackLandedAt", now())
				model:SetAttribute("HackFlingPhase", "down")
				local impact = math.clamp(-vel.Y / 60 + Vector3.new(vel.X, 0, vel.Z).Magnitude / 120, 0.3, 1)
				broadcast({ op = "vfx", kind = "land", model = model, pos = (hit :: RaycastResult).Position, strength = impact })
			end
			if grounded and vel.Magnitude < settle then
				calmFor += dt
			else
				calmFor = 0
			end
			if el >= cap then
				break
			end
			if landedAt and el >= want and calmFor >= 0.15 then
				ending = "settled"
				break
			end
			task.wait(0.05)
		end
		local total = os.clock() - t0
		local p = torso.Position
		model:SetAttribute("HackPostThrow", string.format("mode=%s air=%.2fs down=%.2fs total=%.2fs end=%s apex=%.1f horiz=%.1f",
			mode, if landedAt then landedAt - t0 else -1, if landedAt then os.clock() - landedAt else -1, total, ending,
			apex - startPos.Y, Vector3.new(p.X - startPos.X, 0, p.Z - startPos.Z).Magnitude))
		model:SetAttribute("HackFlingPhase", nil)
		recover(model)
	end)
end

local function groundY(at: Vector3, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(at + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else at.Y - 3
end

-- Allowed throw modes (owner 2026-11-16: "fling directions should only be sideways, backwards and
-- upwards"; backwards = toward and past the attacker, landing behind them). Directions come from the
-- attacker → target geometry on the server, so a client can never throw a target forward/away.
local THROW_MODES = { up = true, left = true, right = true, back = true }

local function grabThrow(g: Grab, mode: string?, power: number, useLast: boolean?)
	if g.done then
		return
	end
	g.done = true
	if grabs[g.attacker] == g then
		grabs[g.attacker] = nil
	end
	g.ap:Destroy()
	g.ao:Destroy()
	g.att:Destroy()
	local root = g.root
	local tune = HackCatalog.Tune
	local aRoot = g.attacker.Character and g.attacker.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local m = if mode and THROW_MODES[mode] then mode elseif useLast and g.lastMode then g.lastMode else "up"
	if mode == "drop" then
		m = "drop"
	end
	-- toMe: target → attacker (horizontal); right: the attacker's right while facing the target
	local toMe = (aRoot and horizontal(aRoot.Position - root.Position)) or horizontal(-root.CFrame.LookVector) or Vector3.zAxis
	local right = (-(toMe :: Vector3)):Cross(Vector3.yAxis).Unit
	local p = math.clamp(power, 0, 1)
	local scale = if g.boss then tune("FlingTarget", "BossThrowScale") else 1
	local speed = (tune("FlingTarget", "ThrowSpeed") + p * tune("FlingTarget", "ThrowBonus")) * scale
	local v: Vector3
	local d: Vector3
	if m == "drop" then
		d, v = right, Vector3.zero
	elseif m == "up" then
		-- owner 2026-11-16: "the upward fling should still launch the player forward" — up plus a push
		-- AWAY from the attacker (forward from the attacker's point of view), tumbling forward
		d = -(toMe :: Vector3)
		v = d * (tune("FlingTarget", "UpThrowForward") + p * tune("FlingTarget", "UpThrowForwardBonus")) * scale
			+ Vector3.new(0, (tune("FlingTarget", "UpThrowSpeed") + p * tune("FlingTarget", "UpThrowBonus")) * scale, 0)
	elseif m == "back" then
		d = toMe :: Vector3 -- over and past the attacker
		v = d * speed + Vector3.new(0, tune("FlingTarget", "BackThrowUp") * scale, 0)
	else
		d = if m == "right" then right else -right
		v = d * speed + Vector3.new(0, tune("FlingTarget", "ThrowUp") * scale, 0)
	end
	g.model:SetAttribute("HackLastThrow", m)
	-- Rev 15d: torso-led launch. The chest gets the full launch velocity; everything else starts slower
	-- (DragTrailStart) so the torso yanks the limbs after it; no tumble spin.
	local torso = (g.model:FindFirstChild("UpperTorso") or g.model:FindFirstChild("Torso") or root) :: BasePart
	local trail = tune("FlingTarget", "DragTrailStart")
	for _, part in g.model:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			part.AssemblyLinearVelocity = if part == torso then v else Vector3.new(v.X * trail, v.Y, v.Z * trail)
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
	local flatV = Vector3.new(v.X, 0, v.Z)
	if flatV.Magnitude > 5 then
		torsoDrag(g.model, torso, flatV.Unit, flatV.Magnitude)
	end
	broadcast({ op = "grab_end", attacker = g.attacker.Character, target = g.model, thrown = true })
	broadcast({ op = "vfx", kind = "throw", model = g.model })
	g.model:SetAttribute("HackFlingPhase", "launched") -- held (shock) -> launched -> down -> nil
	g.model:SetAttribute(A.RagdollUntil, now() + tune("FlingTarget", "PostThrowCap"))
	postThrowRecovery(g.model, root, g.st, m)
end

-- Starts a grab. attacker controls it; player = the target's Player (nil for NPCs / the boss).
local function grabStart(attacker: Player, model: Model, hum: Humanoid, root: BasePart, player: Player?, boss: boolean): (boolean, string?)
	if grabs[attacker] then
		return false, "already_holding"
	end
	local s, why = ragdollBegin(model, hum, root, player)
	if not s then
		return false, why
	end
	local st = s :: RagdollState
	local tune = HackCatalog.Tune
	local att = Instance.new("Attachment")
	att.Name = "HackGrabAttachment"
	att.Parent = root
	local ap = Instance.new("AlignPosition")
	ap.Name = "HackGrabHold"
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = root.AssemblyMass * 6000
	ap.MaxVelocity = tune("FlingTarget", "HoldMaxSpeed")
	ap.Responsiveness = tune("FlingTarget", "HoldResponsiveness")
	-- owner 2026-11-16: no levitation — the target is SHOCKED where it stands: held at its standing
	-- height (HoldHeight 0), kept upright (AlignOrientation, yaw kept), limbs limp and convulsing
	local start = root.Position + Vector3.new(0, tune("FlingTarget", "HoldHeight"), 0)
	ap.Position = start
	ap.Parent = root
	local yaw = horizontal(root.CFrame.LookVector) or Vector3.zAxis
	local upright = CFrame.lookAt(Vector3.zero, yaw :: Vector3)
	root.CFrame = CFrame.new(root.Position) * upright
	local ao = Instance.new("AlignOrientation")
	ao.Name = "HackGrabUpright"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.CFrame = upright
	ao.MaxTorque = root.AssemblyMass * 30000
	ao.Responsiveness = 30
	ao.Parent = root
	table.insert(st.made, ao)
	local g: Grab = { attacker = attacker, model = model, root = root, st = st, att = att, ap = ap, ao = ao, boss = boss, lastMode = nil, lastPoint = start, anchor = start, done = false }
	-- convulsions: limbs twitch with small random spins while the shock lasts
	local limbs: { BasePart } = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root and p.Parent and p.Parent.Name ~= "WristDevice" and not p.Anchored then
			table.insert(limbs, p)
		end
	end
	task.spawn(function()
		local jitter = tune("FlingTarget", "ShockJitter")
		while not g.done and root.Parent do
			for _, p in limbs do
				if p.Parent then
					p.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * jitter
				end
			end
			task.wait(0.07)
		end
	end)
	grabs[attacker] = g
	local holdFor = tune("FlingTarget", "HoldSeconds")
	model:SetAttribute(A.RagdollUntil, now() + holdFor + tune("FlingTarget", "MaxRagdollSeconds"))
	model:SetAttribute("HackFlingPhase", "held")
	broadcast({ op = "grab", attacker = attacker.Character, target = model, untilT = now() + holdFor })
	send(attacker, { op = "grab_control", target = model, boss = boss, untilT = now() + holdFor })
	task.delay(holdFor, function()
		grabThrow(g, nil, 0.4, true) -- auto-throw in the last dragged direction
	end)
	-- target died / removed while held: release cleanly
	task.spawn(function()
		while not g.done do
			if not model.Parent or hum.Health <= 0 or st.done then
				g.done = true
				if grabs[attacker] == g then
					grabs[attacker] = nil
				end
				if ap.Parent then
					ap:Destroy()
				end
				if att.Parent then
					att:Destroy()
				end
				broadcast({ op = "grab_end", attacker = attacker.Character, target = model, thrown = false })
				break
			end
			task.wait(0.1)
		end
	end)
	return true, nil
end

-- Hold point from the attacker's cursor (validated): clamped to HoldLeash from the attacker,
-- lifted HoldHeight above the ground under it. Also records the drag direction.
function HackEffects.GrabHold(attacker: Player, pos: any, dir: any)
	local g = grabs[attacker]
	if not g or g.done or typeof(pos) ~= "Vector3" or pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then
		return
	end
	local aRoot = attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not aRoot then
		return
	end
	local tune = HackCatalog.Tune
	-- owner 2026-11-16: the held target must not be dragged around much before the click; it only
	-- sways up to HoldWiggle studs from where it was grabbed, leaning toward the cursor
	local wiggle = tune("FlingTarget", "HoldWiggle")
	local off = Vector3.new(pos.X - g.anchor.X, 0, pos.Z - g.anchor.Z)
	if off.Magnitude > wiggle then
		off = off.Unit * wiggle
	end
	local point = g.anchor + off
	g.ap.Position = point
	g.lastPoint = point
	if typeof(dir) == "string" and THROW_MODES[dir] then
		g.lastMode = dir -- the mode currently being dragged (used by the auto-throw)
	end
end

function HackEffects.GrabThrow(attacker: Player, dir: any, power: any)
	local g = grabs[attacker]
	if not g then
		return
	end
	grabThrow(g, if typeof(dir) == "string" and THROW_MODES[dir] then dir else nil, if typeof(power) == "number" and power == power then power else 0)
end

-- Attacker died / left: drop what they hold (no throw).
function HackEffects.GrabDrop(attacker: Player)
	local g = grabs[attacker]
	if g then
		grabThrow(g, "drop", 0)
	end
end

function HackEffects.IsHolding(attacker: Player): boolean
	return grabs[attacker] ~= nil
end

function HackEffects.Grab(attacker: Player, target: HackTargets.Target): (boolean, string?)
	return grabStart(attacker, target.Model, target.Humanoid, target.Root, target.Player, false)
end

function HackEffects.GrabBoss(attacker: Player, model: Model, hum: Humanoid, root: BasePart): (boolean, string?)
	return grabStart(attacker, model, hum, root, nil, true)
end

-- Exposed for the boss module (it unanchors the boss first and re-homes it after recovery).
function HackEffects.RagdollLaunch(model: Model, hum: Humanoid, root: BasePart, v: Vector3, vfxScale: number): (boolean, string?)
	return ragdollLaunch(model, hum, root, nil, v, vfxScale)
end
function HackEffects.RagdollGlide(model: Model, hum: Humanoid, root: BasePart, dir: Vector3, speed: number, seconds: number): (boolean, string?)
	return ragdollGlide(model, hum, root, nil, dir, speed, seconds)
end

-- aim (owner 2026-11-16): the attacker's slide direction. Slide + AimedStyle 1 = glide (default);
-- AimedStyle 0 = the low-arc launch of rev 8. No slide (touch / gamepad / no flick): the tall launch,
-- straight away from the attacker.
function HackEffects.FlingTarget(target: HackTargets.Target, from: Vector3, aim: Vector3?): (boolean, string?)
	local root = target.Root
	local tune = HackCatalog.Tune
	local dir = (aim and horizontal(aim)) or horizontal(root.Position - from) or horizontal(root.CFrame.LookVector) or Vector3.zAxis
	local aimed = aim ~= nil and horizontal(aim) ~= nil
	if aimed and tune("FlingTarget", "AimedStyle") >= 1 then
		return ragdollGlide(target.Model, target.Humanoid, root, target.Player, dir :: Vector3, tune("FlingTarget", "GlideSpeed"), tune("FlingTarget", "GlideSeconds"))
	end
	local v = if aimed
		then (dir :: Vector3) * tune("FlingTarget", "AimedForward") + Vector3.new(0, tune("FlingTarget", "AimedUp"), 0)
		else (dir :: Vector3) * tune("FlingTarget", "Forward") + Vector3.new(0, tune("FlingTarget", "Up"), 0)
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
	player:SetAttribute(A.ShieldStart, nil)
end
HackEffects.EndShield = endShield

-- NPC shield (test-station dummy reactions): same bubble, model attributes instead of player ones.
function HackEffects.ShieldModel(model: Model, seconds: number): boolean
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (model:GetAttribute(A.NpcShieldUntil) or 0) > now() then
		return false
	end
	local bubble = Instance.new("Part")
	bubble.Name = "HackShieldBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(9, 9, 9)
	bubble.Material = Enum.Material.ForceField
	bubble.Color = Color3.fromRGB(60, 220, 140)
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
	bubble.Parent = model
	model:SetAttribute(A.NpcShieldUntil, now() + seconds)
	model:SetAttribute(A.NpcShieldStart, now())
	task.delay(seconds, function()
		bubble:Destroy()
		model:SetAttribute(A.NpcShieldUntil, nil)
		model:SetAttribute(A.NpcShieldStart, nil)
	end)
	return true
end

-- Shield state of any target model: (active, raised-at server time).
function HackEffects.ModelShieldInfo(model: Model): (boolean, number?)
	local player = Players:GetPlayerFromCharacter(model)
	local t = now()
	if player then
		local u = player:GetAttribute(A.ShieldUntil)
		return typeof(u) == "number" and u > t, player:GetAttribute(A.ShieldStart)
	end
	local u = model:GetAttribute(A.NpcShieldUntil)
	return typeof(u) == "number" and u > t, model:GetAttribute(A.NpcShieldStart)
end

-- Deflection flash on any shielded model (server side; clients also draw a burst).
function HackEffects.ShieldFlash(model: Model)
	local b = model:FindFirstChild("HackShieldBubble")
	if b and b:IsA("BasePart") then
		b.Color = Color3.fromRGB(245, 247, 255)
		task.delay(0.2, function()
			if b.Parent then
				b.Color = Color3.fromRGB(60, 220, 140)
			end
		end)
	end
end

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
	player:SetAttribute(A.ShieldStart, now())
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

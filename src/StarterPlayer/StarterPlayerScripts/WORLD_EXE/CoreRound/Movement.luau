--!strict
-- Movement (Core Round Step 1, client): fast baseline run, two-charge Super Dash, momentum carry.
--
-- Controls: one dash input (Q / gamepad B / touch DASH).
--   * Press      -> Dash: 1 charge, DashDistance studs in DashSeconds toward the move input (camera forward if none).
--   * Press again within SuperWindow (0.40 s) of the first press -> Super Dash: the 2nd charge, a SuperSeconds
--     steerable burst at SuperSpeed. Starts at once (during the dash or in its last 0.15 s grace). No timing test:
--     mashing simply works. With no charge left, nothing happens (soft deny tick).
--   * Charges regenerate one after the other (ChargeRegenSeconds each), on the ground or in the air.
-- Momentum: every dash ends at SlipSpeed, easing to RunSpeed over SlipSeconds while you keep moving; speed is
-- kept through jumps (decays slowly in the air); wall-jumps add WallJumpBoost; everything above SoftCap decays.
-- Physics stays on this (owning) client; the SERVER is the judge of charges (CoreMove) and rejects bursts it
-- did not allow (the client then stops the burst at once).
-- Velocity ownership: MoveState "dash" / "super" (WallRun: "wallrun" / "walljump").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CoreRound = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))
local CoreGeom = require(CoreRound:WaitForChild("CoreGeom"))
local MoveState = require(script.Parent:WaitForChild("MoveState"))
local Fx = require(script.Parent:WaitForChild("Fx"))

local Movement = {}

local player = Players.LocalPlayer
local function tune(k: string): number
	return CoreConfig.Tune("Move", k)
end

-- predicted charges (resynced from the server attributes)
local charges = 2
local regenAt = 0 -- os.clock() when the next charge arrives (0 = full)
local lastOwnPress = -100

-- current burst
type Burst = { kind: string, t0: number, until_: number, dir: Vector3, att: Attachment, lv: LinearVelocity, startPos: Vector3, n: number }
local burst: Burst? = nil
local firstPressT = -100 -- when the dash that may be extended was pressed
local superUsed = true
local boost = 30
local slipT = -100
local shieldSlow = false
local seq = 0

local send: (op: string, payload: { [string]: any }) -> () = function() end
local stunnedFn: () -> boolean = function()
	return false
end
local teamColor: () -> Color3 = function()
	return CoreConfig.NeutralColor
end
local onDash: () -> () = function() end

-- diagnostics (test kit / HUD)
Movement.Log = {} :: { { [string]: any } }
local function note(entry: { [string]: any })
	entry.t = os.clock()
	table.insert(Movement.Log, entry)
	if #Movement.Log > 300 then
		table.remove(Movement.Log, 1)
	end
end

local function regen()
	local max = math.floor(tune("Charges"))
	local t = os.clock()
	while charges < max and regenAt > 0 and t >= regenAt do
		charges += 1
		regenAt = if charges < max then regenAt + tune("ChargeRegenSeconds") else 0
	end
end

local function spend()
	local max = math.floor(tune("Charges"))
	if charges >= max then
		regenAt = os.clock() + tune("ChargeRegenSeconds")
	end
	charges -= 1
end

function Movement.Charges(): (number, number)
	regen()
	local max = math.floor(tune("Charges"))
	if charges >= max or regenAt == 0 then
		return charges, 1
	end
	local f = 1 - (regenAt - os.clock()) / tune("ChargeRegenSeconds")
	return charges, math.clamp(f, 0, 1)
end

function Movement.State(): string
	return if burst then burst.kind else (if MoveState.Owner() then MoveState.Owner() :: string else "run")
end

function Movement.HorizontalSpeed(): number
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return 0
	end
	local v = hrp.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

function Movement.SetShieldSlow(on: boolean)
	shieldSlow = on
end

local function parts(): (Humanoid?, BasePart?)
	local c = player.Character
	if not c then
		return nil, nil
	end
	return c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function wantDir(hum: Humanoid): Vector3
	local md = CoreGeom.Flat(hum.MoveDirection)
	if md and hum.MoveDirection.Magnitude > 0.1 then
		return md
	end
	return CoreGeom.Flat(workspace.CurrentCamera.CFrame.LookVector) or Vector3.new(0, 0, -1)
end

local function endBurst(reason: string, slip: boolean)
	local b = burst
	if not b then
		return
	end
	burst = nil
	local _, hrp = parts()
	b.lv:Destroy()
	b.att:Destroy()
	MoveState.Release(b.kind)
	if hrp then
		local endPos = hrp.Position
		note({ kind = b.kind .. "_end", reason = reason, dist = (Vector3.new(endPos.X, 0, endPos.Z) - Vector3.new(b.startPos.X, 0, b.startPos.Z)).Magnitude, secs = os.clock() - b.t0 })
		if slip then
			local v = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(b.dir.X * tune("SlipSpeed"), v.Y, b.dir.Z * tune("SlipSpeed"))
			boost = math.max(boost, tune("SlipSpeed"))
			slipT = os.clock()
		end
	end
end

local function startBurst(kind: string, dir: Vector3, speed: number, seconds: number, n: number)
	local hum, hrp = parts()
	if not hum or not hrp then
		return
	end
	if burst then
		-- a Super Dash replaces the running dash (same heading, no dip)
		local b = burst
		burst = nil
		b.lv:Destroy()
		b.att:Destroy()
		MoveState.Release(b.kind)
	end
	if not MoveState.Claim(kind, true) then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "CoreDashAttachment"
	att.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.MaxForce = math.huge
	lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * speed
	lv.Parent = hrp
	burst = { kind = kind, t0 = os.clock(), until_ = os.clock() + seconds, dir = dir, att = att, lv = lv, startPos = hrp.Position, n = n }
	note({ kind = kind, n = n, charges = charges, air = hum.FloorMaterial == Enum.Material.Air })
	Fx.Sound(kind)
	onDash()
end

-- the dash input
function Movement.Press(): string
	local hum, hrp = parts()
	if not hum or not hrp or hum.Health <= 0 then
		return "nochar"
	end
	local t = os.clock()
	if t - lastOwnPress < tune("MinPressGap") then
		return "spam"
	end
	if stunnedFn() then
		Fx.Sound("deny")
		return "stunned"
	end
	regen()
	lastOwnPress = t
	-- Step 1B comparison switches (the server enforces them too)
	if tune("DashEnabled") < 0.5 then
		Fx.Sound("deny")
		return "disabled"
	end
	-- Super Dash: a second press within SuperWindow of the dash press, once per dash
	if tune("SuperEnabled") >= 0.5 and not superUsed and t - firstPressT <= tune("SuperWindow") and (burst == nil or burst.kind == "dash") then
		if charges < 1 then
			Fx.Sound("deny")
			note({ kind = "deny", why = "no_charge_super" })
			return "no_charge"
		end
		spend()
		superUsed = true
		seq += 1
		local dir = if burst then burst.dir else (CoreGeom.Flat(hrp.AssemblyLinearVelocity) or wantDir(hum))
		send("super", { n = seq })
		startBurst("super", dir, tune("SuperSpeed"), tune("SuperSeconds"), seq)
		return "super"
	end
	if burst and burst.kind == "super" then
		return "busy"
	end
	if charges < 1 then
		Fx.Sound("deny")
		note({ kind = "deny", why = "no_charge" })
		return "no_charge"
	end
	spend()
	firstPressT = t
	superUsed = false
	seq += 1
	send("dash", { n = seq })
	startBurst("dash", wantDir(hum), tune("DashDistance") / tune("DashSeconds"), tune("DashSeconds"), seq)
	return "dash"
end

-- the server refused a burst: stop it now and trust the server's charge count
function Movement.OnReject(op: string, why: string?)
	note({ kind = "reject", op = op, why = why })
	if burst and burst.kind == op then
		endBurst("rejected", false)
	end
	local sc = player:GetAttribute("CR_Charges")
	if typeof(sc) == "number" then
		charges = sc
	end
end

-- Step 1B: momentum hand-off from a slide / wall-run exit (speed kept through the air, decays at AirCarryDecay;
-- anything above SoftCap still decays at SoftCapDecay, so chaining cannot accumulate speed without bound)
function Movement.SetBoost(v: number)
	if v == v then
		boost = math.max(boost, math.min(v, CoreConfig.Tune("Slide", "MaxSpeed")))
	end
end

-- wall-run hand-off (WallRun deps)
function Movement.OnWallRunEnd(how: string)
	local s = Movement.HorizontalSpeed()
	if how == "jump" then
		boost = math.min(tune("SoftCap") + tune("WallJumpBoost"), math.max(boost, s) + tune("WallJumpBoost"))
	else
		boost = math.max(boost, math.min(s, tune("SoftCap")))
	end
end

function Movement.Start(deps: { send: (string, { [string]: any }) -> (), stunned: () -> boolean, teamColor: () -> Color3, onDash: () -> () })
	send = deps.send
	stunnedFn = deps.stunned
	teamColor = deps.teamColor
	onDash = deps.onDash
	charges = math.floor(tune("Charges"))
	boost = tune("RunSpeed")

	-- resync predicted charges from the server's (authoritative) attributes when we have not pressed recently
	local function sync()
		if os.clock() - lastOwnPress < 0.4 then
			return
		end
		local sc, sr = player:GetAttribute("CR_Charges"), player:GetAttribute("CR_RegenAt")
		if typeof(sc) == "number" then
			charges = sc
		end
		if typeof(sr) == "number" then
			regenAt = if sr <= 0 then 0 else os.clock() + (sr - workspace:GetServerTimeNow())
		end
	end
	player:GetAttributeChangedSignal("CR_Charges"):Connect(sync)
	player:GetAttributeChangedSignal("CR_RegenAt"):Connect(sync)

	local trail: Trail? = nil
	local lastImage = 0
	local fov = tune("FovBase")

	player.CharacterAdded:Connect(function()
		if burst then
			burst = nil
		end
		MoveState.Release("dash")
		MoveState.Release("super")
		trail = nil
		boost = tune("RunSpeed")
	end)

	RunService.Heartbeat:Connect(function(dt)
		local hum, hrp = parts()
		if not hum or not hrp then
			return
		end
		local t = os.clock()
		regen()
		local base = tune("RunSpeed")
		local stunned = stunnedFn()

		-- burst control
		local b = burst
		if b then
			if MoveState.Owner() ~= b.kind then
				-- another state (wall-run) took the velocity: hand over without slip
				burst = nil
				b.lv:Destroy()
				b.att:Destroy()
				note({ kind = b.kind .. "_end", reason = "handover", secs = t - b.t0 })
			elseif stunned or hum.Health <= 0 then
				endBurst("stunned", false)
			elseif t >= b.until_ then
				endBurst("time", true)
			elseif b.kind == "super" then
				local want = wantDir(hum)
				local cur = b.dir
				local ang = math.acos(math.clamp(cur:Dot(want), -1, 1))
				local maxTurn = tune("SuperTurnRate") * dt
				if ang > 1e-3 then
					local k = math.min(1, maxTurn / ang)
					local nd = CoreGeom.Flat(cur:Lerp(want, k)) or cur
					b.dir = nd
				end
				b.lv.PlaneVelocity = Vector2.new(b.dir.X, b.dir.Z) * tune("SuperSpeed")
				if not Fx.Reduced and t - lastImage > 0.08 and player.Character then
					lastImage = t
					Fx.Afterimage(player.Character, teamColor())
				end
			end
		end

		-- speed: momentum carry, soft cap, shield slow, stun
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		local moving = hum.MoveDirection.Magnitude > 0.1
		if boost > base then
			if grounded then
				if not moving then
					boost = base
				else
					boost -= (tune("SlipSpeed") - base) / math.max(0.05, tune("SlipSeconds")) * dt
				end
			else
				boost -= tune("AirCarryDecay") * dt
			end
			if boost > tune("SoftCap") then
				boost -= tune("SoftCapDecay") * dt
			end
		end
		boost = math.max(boost, base)
		local walk = boost
		if shieldSlow then
			walk = base * CoreConfig.Tune("Shield", "SpeedScale")
			boost = base
		end
		if stunned then
			walk = 0
		end
		if hum.WalkSpeed ~= walk then
			hum.WalkSpeed = walk
		end

		-- trail while bursting / slipping
		if not trail or not trail.Parent then
			local a0 = Instance.new("Attachment")
			a0.Name = "CoreTrailA"
			a0.Position = Vector3.new(0, 0.9, 0)
			a0.Parent = hrp
			local a1 = Instance.new("Attachment")
			a1.Name = "CoreTrailB"
			a1.Position = Vector3.new(0, -1.6, 0)
			a1.Parent = hrp
			local tr = Instance.new("Trail")
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Lifetime = 0.25
			tr.LightEmission = 0.6
			tr.Transparency = NumberSequence.new(0.6, 1)
			tr.FaceCamera = true
			tr.Enabled = false
			tr.Parent = hrp
			trail = tr
		end
		local tr = trail :: Trail
		local col = teamColor()
		tr.Color = ColorSequence.new(col)
		tr.Enabled = burst ~= nil or (t - slipT < 0.4)

		-- FOV (eased, no shake)
		local cam = workspace.CurrentCamera
		local k = if Fx.Reduced then 0.5 else 1
		-- Step 1B: a gentle speed-based FOV (slides, wall-runs, carried momentum) on top of the burst kick; eased, no shake
		local hsNow = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude
		local speedFov = math.clamp((hsNow - base) * tune("SpeedFovPerStud"), 0, tune("SpeedFovMax"))
		local target = tune("FovBase") + ((if burst and burst.kind == "super" then tune("FovSuper") elseif burst then tune("FovDash") else 0) + speedFov) * k
		fov += (target - fov) * math.min(1, dt * 10)
		cam.FieldOfView = fov
	end)
end

function Movement.Reset()
	if burst then
		endBurst("reset", false)
	end
	charges = math.floor(tune("Charges"))
	regenAt = 0
	boost = tune("RunSpeed")
end

return Movement

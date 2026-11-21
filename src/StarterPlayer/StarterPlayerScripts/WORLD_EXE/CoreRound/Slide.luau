--!strict
-- Slide (Core Round Step 1B, client): momentum slide, the primary movement improvement (owner 2026-11-21).
-- References (mechanics only, no values copied): Fortnite (crouch while running starts a slide; downhill is faster),
-- Warframe (slide -> jump keeps the burst), Titanfall 2 (a slide is mostly ground movement with reduced steering and
-- a small starting boost; jumping out keeps the speed).
--
--   start   hold Slide (Left Shift / C, gamepad B, touch SLIDE toggles) while grounded and moving >= MinStartSpeed
--   entry   speed = max(current, RunSpeed) + EntryBoost (boost only once per BoostCooldown: no slide-spam acceleration),
--           capped by MaxEntrySpeed (a faster arrival, e.g. out of a Super Dash, is kept up to MaxSpeed)
--   on it   friction on flat ground, + SlopeAccel * sin(slope) downhill (- uphill), hard cap MaxSpeed, steering limited
--           to SteerRate; the Disc can be thrown; a short coyote time over bumps / ledges
--   ends    release, jump (Step 1D: Power Slide Jump - see below; PowerJump = 0 restores the 1C jump: speed +
--           JumpBoost), too slow (-> run, speed carried), time cap,
--           a dash (hands over), shield raised, stun, airborne longer than CoyoteSeconds (speed carried into the air)
-- Physics on this (owning) client; the server validates the start and publishes CR_MoveState for every client
-- (pose rendering, hit volumes, speed monitor).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CoreRound = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))
local CoreGeom = require(CoreRound:WaitForChild("CoreGeom"))
local MoveState = require(script.Parent:WaitForChild("MoveState"))
local Fx = require(script.Parent:WaitForChild("Fx"))

local Slide = {}

local player = Players.LocalPlayer
local function tune(k: string): number
	return CoreConfig.Tune("Slide", k)
end

type S = { t0: number, dir: Vector3, speed: number, att: Attachment, lv: LinearVelocity, lastGround: number, startPos: Vector3, peak: number, maxSlope: number }
local s: S? = nil
local held = false
local lastEnd = -10
local lastBoost = -10
local jumpQueued = false
-- landing buffer (Titanfall 2 reference: press slide in mid-air and the slide starts the moment you land)
local buffered = false
local sawAir = false

local deps = {
	send = function(_op: string, _p: { [string]: any }) end,
	stunned = function(): boolean
		return false
	end,
	setBoost = function(_v: number) end,
	onStart = function() end,
	onEnd = function(_how: string) end,
	onPowerJump = function(_up: number, _fwd: number) end,
	teamColor = function(): Color3
		return CoreConfig.NeutralColor
	end,
}

Slide.Log = {} :: { { [string]: any } }
local function note(e: { [string]: any })
	e.t = os.clock()
	table.insert(Slide.Log, e)
	if #Slide.Log > 200 then
		table.remove(Slide.Log, 1)
	end
end

local function parts(): (Humanoid?, BasePart?)
	local c = player.Character
	if not c then
		return nil, nil
	end
	return c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Slide.Active(): boolean
	return s ~= nil
end

function Slide.Speed(): number
	return if s then s.speed else 0
end

local scrape: Sound? = nil

-- Step 1D: Power Slide Jump (owner reference: Sojourn's Power Slide - a ground slide that cancels into a high jump;
-- original WORLD.EXE values). Jump while sliding: the slide ends at once and the character launches upward with
--   up      = PowerJumpUp + PowerJumpConvert * (slide speed - PowerJumpFrom), capped at PowerJumpMaxUp
--   forward = slide speed * PowerJumpKeep (at least PowerJumpMinForward) along the slide direction
-- i.e. part of the slide's speed is traded for height; faster slides jump higher, within the cap. No separate button,
-- no hold timing. The launch is re-asserted for PowerJumpHoldSeconds in case the Humanoid's own jump fires after it.
local launch: { vy: number, t0: number, untilT: number }? = nil

local function finish(how: string, carry: boolean)
	local cur = s
	if not cur then
		return
	end
	s = nil
	lastEnd = os.clock()
	cur.lv:Destroy()
	cur.att:Destroy()
	MoveState.Release("slide")
	if scrape then
		scrape:Stop()
	end
	local hum, hrp = parts()
	local power: { [string]: number }? = nil
	if hrp and carry then
		local v = hrp.AssemblyLinearVelocity
		if how == "jump" and tune("PowerJump") >= 0.5 then
			local sp = cur.speed
			local up = math.min(tune("PowerJumpMaxUp"), tune("PowerJumpUp") + tune("PowerJumpConvert") * math.max(0, sp - tune("PowerJumpFrom")))
			local fwd = math.max(tune("PowerJumpMinForward"), sp * tune("PowerJumpKeep"))
			hrp.AssemblyLinearVelocity = Vector3.new(cur.dir.X * fwd, up, cur.dir.Z * fwd)
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Freefall)
			end
			launch = { vy = up, t0 = os.clock(), untilT = os.clock() + tune("PowerJumpHoldSeconds") }
			deps.setBoost(fwd)
			power = { up = up, fwd = fwd, speed = sp }
			Fx.Sound("power_jump")
			if not Fx.Reduced then
				Fx.Burst(hrp.Position - Vector3.new(0, 2.6, 0), deps.teamColor(), 1.0)
			end
		else
			local sp = cur.speed + (if how == "jump" then tune("JumpBoost") else 0)
			hrp.AssemblyLinearVelocity = Vector3.new(cur.dir.X * sp, v.Y, cur.dir.Z * sp)
			deps.setBoost(sp)
		end
	end
	local dist = if hrp then (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(cur.startPos.X, 0, cur.startPos.Z)).Magnitude else 0
	note({ kind = "slide_end", how = how, secs = os.clock() - cur.t0, dist = dist, endSpeed = cur.speed, peak = cur.peak, maxSlope = cur.maxSlope, up = power and power.up, fwd = power and power.fwd })
	if power then
		deps.onPowerJump(power.up, power.fwd)
	end
	-- slide-hop: still holding slide when you jump / leave a ledge -> slide again on landing (bounded by the boost
	-- cooldown and MaxEntrySpeed, plus the soft cap)
	if (how == "jump" or how == "air") and held then
		buffered = true
		sawAir = false
	end
	deps.send("move", { state = "run" })
	deps.onEnd(how)
end

function Slide.Cancel(how: string)
	finish(how, true)
end

local function tryStart(): string
	local hum, hrp = parts()
	if not hum or not hrp or hum.Health <= 0 then
		return "nochar"
	end
	if s then
		return "active"
	end
	local t = os.clock()
	if deps.stunned() then
		return "stunned"
	end
	if t - lastEnd < tune("ReentryDelay") then
		return "reentry"
	end
	if hum.FloorMaterial == Enum.Material.Air then
		return "air"
	end
	local owner = MoveState.Owner()
	if owner ~= nil and owner ~= "dash" and owner ~= "super" then
		return "busy"
	end
	local v = hrp.AssemblyLinearVelocity
	local hs = Vector3.new(v.X, 0, v.Z).Magnitude
	if hs < tune("MinStartSpeed") then
		return "slow"
	end
	local dir = CoreGeom.Flat(v) or Vector3.new(0, 0, -1)
	local speed = math.max(hs, CoreConfig.Tune("Move", "RunSpeed"))
	local boosted = false
	if t - lastBoost >= tune("BoostCooldown") then
		speed += tune("EntryBoost")
		lastBoost = t
		boosted = true
	end
	if hs <= tune("MaxEntrySpeed") then
		speed = math.min(speed, tune("MaxEntrySpeed"))
	end
	speed = math.min(speed, tune("MaxSpeed"))
	if not MoveState.Claim("slide", true) then
		return "claim"
	end
	local att = Instance.new("Attachment")
	att.Name = "CoreSlideAttachment"
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
	s = { t0 = t, dir = dir, speed = speed, att = att, lv = lv, lastGround = t, startPos = hrp.Position, peak = speed, maxSlope = 0 }
	jumpQueued = false
	note({ kind = "slide", entry = speed, from = hs, boosted = boosted })
	deps.send("move", { state = "slide" })
	deps.onStart()
	if not scrape or not scrape.Parent then
		local sn = Instance.new("Sound")
		sn.Name = "CoreSlideScrape"
		sn.SoundId = "rbxasset://sounds/action_footsteps_plastic.mp3"
		sn.Looped = true
		sn.Volume = 0.35
		sn.PlaybackSpeed = 0.55
		sn.Parent = hrp
		scrape = sn
	end
	if scrape then
		scrape:Play()
	end
	return "slide"
end

-- hold semantics (desktop / gamepad); returns the start result on press
function Slide.Press(down: boolean): string
	held = down
	if down then
		local r = tryStart()
		buffered = (r == "air")
		return if buffered then "buffered" else r
	end
	buffered = false
	if s then
		finish("release", true)
	end
	return "released"
end

-- touch: tap starts / tap again ends
function Slide.Toggle(): string
	if s then
		held = false
		finish("release", true)
		return "released"
	end
	held = true
	local r = tryStart()
	buffered = (r == "air")
	return if buffered then "buffered" else r
end

-- the server refused the slide (implausible start): stop it, no carry
function Slide.OnReject()
	if s then
		finish("rejected", false)
	end
end

function Slide.Start(d: typeof(deps))
	deps = d
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	UserInputService.JumpRequest:Connect(function()
		if s then
			jumpQueued = true
		end
	end)
	player.CharacterAdded:Connect(function()
		if s then
			s = nil
			MoveState.Release("slide")
		end
		held = false
		scrape = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		-- Step 1D: keep the Power Slide Jump launch if the Humanoid's own jump overwrote it this frame
		-- (only restores the launch minus the gravity since then; measured in Step 1D: re-asserting the full launch speed
		-- every frame for 0.1 s cancelled gravity and added ~7 studs of height)
		local l = launch
		if l then
			local _, lhrp = parts()
			if not lhrp or os.clock() > l.untilT then
				launch = nil
			else
				local expected = l.vy - workspace.Gravity * (os.clock() - l.t0)
				local v = lhrp.AssemblyLinearVelocity
				if v.Y > 0 and v.Y < expected - 6 then
					lhrp.AssemblyLinearVelocity = Vector3.new(v.X, expected, v.Z)
				end
			end
		end
		local cur = s
		if not cur then
			-- landing buffer: still holding slide from the air -> slide on touchdown (once)
			if buffered and held then
				local hum = parts()
				-- only after we have actually been airborne (FloorMaterial lags a frame or two at take-off)
				if hum and hum.FloorMaterial == Enum.Material.Air then
					sawAir = true
				end
				if hum and sawAir and hum.FloorMaterial ~= Enum.Material.Air then
					sawAir = false
					buffered = false
					local r = tryStart()
					note({ kind = "slide_buffer", result = r })
				end
			end
			return
		end
		local hum, hrp = parts()
		if not hum or not hrp then
			s = nil
			MoveState.Release("slide")
			return
		end
		local t = os.clock()
		if MoveState.Owner() ~= "slide" then
			-- a dash / wall-run took the velocity: hand over without carry (the new owner sets its own speed)
			s = nil
			cur.lv:Destroy()
			cur.att:Destroy()
			if scrape then
				scrape:Stop()
			end
			lastEnd = t
			note({ kind = "slide_end", how = "handover", secs = t - cur.t0 })
			deps.send("move", { state = "run" })
			deps.onEnd("handover")
			return
		end
		if deps.stunned() then
			return finish("stunned", false)
		end
		if jumpQueued then
			jumpQueued = false
			return finish("jump", true)
		end
		if t - cur.t0 > tune("MaxSeconds") then
			return finish("time", true)
		end
		-- ground + slope
		local c = player.Character :: Model
		local fx = Fx.Folder()
		params.FilterDescendantsInstances = { c, fx }
		local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), params)
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		if grounded then
			cur.lastGround = t
		elseif t - cur.lastGround > tune("CoyoteSeconds") then
			return finish("air", true)
		end
		local accel = -tune("Friction")
		if hit and grounded then
			local n = hit.Normal
			-- gravity component along the slope surface, projected on the slide direction (= sin(slope) downhill)
			local g = Vector3.new(0, -1, 0)
			local gp = g - n * g:Dot(n)
			local along = gp:Dot(cur.dir)
			accel += tune("SlopeAccel") * along
			cur.maxSlope = math.max(cur.maxSlope, math.deg(math.acos(math.clamp(n.Y, -1, 1))))
		end
		cur.speed = math.clamp(cur.speed + accel * dt, 0, tune("MaxSpeed"))
		cur.peak = math.max(cur.peak, cur.speed)
		-- limited steering toward the move input
		local md = hum.MoveDirection
		local want = CoreGeom.Flat(md)
		if want and md.Magnitude > 0.1 then
			local ang = math.acos(math.clamp(cur.dir:Dot(want), -1, 1))
			if ang > 1e-3 and ang < math.rad(150) then
				local k = math.min(1, tune("SteerRate") * dt / ang)
				cur.dir = CoreGeom.Flat(cur.dir:Lerp(want, k)) or cur.dir
			end
		end
		cur.lv.PlaneVelocity = Vector2.new(cur.dir.X, cur.dir.Z) * cur.speed
		if scrape then
			scrape.PlaybackSpeed = 0.45 + cur.speed / 120
		end
		if cur.speed < tune("MinSpeed") then
			return finish("slow", true)
		end
		if not held then
			return finish("release", true)
		end
		-- sparks at the feet (pooled, Reduced FX aware)
		if not Fx.Reduced and math.random() < 0.12 then
			Fx.Burst(hrp.Position - Vector3.new(0, 2.6, 0) - cur.dir * 0.8, deps.teamColor(), 0.6)
		end
	end)
end

return Slide

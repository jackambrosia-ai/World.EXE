--!strict
-- WallRun2 (Core Round Step 1B, client): horizontal wall-run that keeps approach momentum.
-- Reference: Titanfall 2 (video "Mobility and Momentum" + Respawn's 2017 controls interview), translated into an
-- original third-person Roblox system. Principles kept, not values or camera:
--   * entry is automatic: jump at / along a wall while moving and you catch it (no extra button)
--   * speed is preserved and slightly rewarded, never replaced by a fixed velocity
--   * no upward climb: rising speed is capped on entry and a gentle "wall gravity" pulls you down over time
--   * the body eases into a small lean away from the wall (no snapping); the third-person camera eases away from the
--     wall instead of rolling (no unrequested view motion)
--   * wall jump pushes away and up and keeps (boosts) the forward speed; you can chain to the opposite wall
--   * every exit (wall end, time, peel, landing, jump) keeps the current velocity
-- WallRun2.Mode (CoreTune_WallRun2_Mode): 2 = this (default), 1 = the Step 1 climbing wall-run (comparison), 0 = off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CoreRound = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))
local CoreGeom = require(CoreRound:WaitForChild("CoreGeom"))
local MoveState = require(script.Parent:WaitForChild("MoveState"))

local WallRun2 = {}

local player = Players.LocalPlayer
local function tune(k: string): number
	return CoreConfig.Tune("WallRun2", k)
end

type Run = {
	t0: number,
	n: Vector3, -- wall normal (flat, away from the wall)
	t: Vector3, -- run direction along the wall
	speed: number,
	vy: number,
	wall: Instance,
	att: Attachment,
	lv: LinearVelocity,
	ao: AlignOrientation,
	track: AnimationTrack?,
	autoRotate: boolean,
	peel: number,
	startPos: Vector3,
	entrySpeed: number,
}
local run: Run? = nil
local lastEnd = -10
local lastWall: Instance? = nil
local lastWallT = -10
local jumpQueued = false
local camBias = Vector3.zero -- world-space camera push away from the wall (eased; read by Aim)
local camTarget = Vector3.zero
local carry: { att: Attachment, lv: LinearVelocity, untilT: number, t0: number }? = nil

local function endCarry()
	local cr = carry
	if cr then
		carry = nil
		cr.lv:Destroy()
		cr.att:Destroy()
		MoveState.Release("walljump2")
	end
end

local deps = {
	ignore = {} :: { Instance },
	send = function(_op: string, _p: { [string]: any }) end,
	setBoost = function(_v: number) end,
	onEnd = function(_how: string) end,
}

WallRun2.Log = {} :: { { [string]: any } }
local function note(e: { [string]: any })
	e.t = os.clock()
	table.insert(WallRun2.Log, e)
	if #WallRun2.Log > 200 then
		table.remove(WallRun2.Log, 1)
	end
end

function WallRun2.Active(): boolean
	return run ~= nil
end

function WallRun2.CamBias(): Vector3
	return camBias
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local function sideHit(origin: Vector3, dir: Vector3, reach: number): RaycastResult?
	local hit = workspace:Raycast(origin, dir * reach, params)
	if hit and math.abs(hit.Normal.Y) < 0.3 then
		return hit
	end
	return nil
end

local function finish(how: string)
	local r = run
	if not r then
		return
	end
	run = nil
	lastEnd = os.clock()
	lastWall = r.wall
	lastWallT = os.clock()
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local v = r.t * r.speed + Vector3.yAxis * r.vy
	if how == "jump" then
		local sp = r.speed + tune("JumpBoost")
		v = r.t * sp + r.n * tune("JumpOut") + Vector3.yAxis * tune("JumpUp")
	end
	r.lv:Destroy()
	r.ao:Destroy()
	r.att:Destroy()
	if r.track then
		r.track:Stop(0.15)
	end
	if hum then
		hum.AutoRotate = r.autoRotate
	end
	MoveState.Release("wallrun2")
	if hrp then
		hrp.AssemblyLinearVelocity = v -- keep the momentum (no loss on exit)
		deps.setBoost(Vector3.new(v.X, 0, v.Z).Magnitude)
		-- wall-jump carry: Roblox air control would otherwise steer the push-off back toward the held direction
		-- within a fraction of a second (measured: the outward push vanished), so the jump keeps its horizontal
		-- velocity for JumpCarrySeconds; the next wall can catch it (chaining)
		if how == "jump" and MoveState.Claim("walljump2", true) then
			local att = Instance.new("Attachment")
			att.Name = "CoreWallJumpCarry"
			att.Parent = hrp
			local lv = Instance.new("LinearVelocity")
			lv.Attachment0 = att
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
			lv.PrimaryTangentAxis = Vector3.xAxis
			lv.SecondaryTangentAxis = Vector3.zAxis
			lv.MaxForce = math.huge
			lv.PlaneVelocity = Vector2.new(v.X, v.Z)
			lv.Parent = hrp
			carry = { att = att, lv = lv, untilT = os.clock() + tune("JumpCarrySeconds"), t0 = os.clock() }
		end
		note({ kind = "wallrun2_end", how = how, secs = os.clock() - r.t0, entry = r.entrySpeed, exitH = Vector3.new(v.X, 0, v.Z).Magnitude, exitY = v.Y, rise = hrp.Position.Y - r.startPos.Y, along = (hrp.Position - r.startPos):Dot(r.t) })
	end
	camTarget = Vector3.zero
	deps.send("move", { state = "run" })
	deps.onEnd(how)
end

function WallRun2.Cancel(how: string)
	finish(how)
end

local function runTrack(c: Model, hum: Humanoid): AnimationTrack?
	local animate = c:FindFirstChild("Animate")
	local runFolder = animate and animate:FindFirstChild("run")
	local anim = runFolder and runFolder:FindFirstChildOfClass("Animation")
	local animator = hum:FindFirstChildOfClass("Animator")
	if not anim or not animator then
		return nil
	end
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim :: Animation)
	end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		return track
	end
	return nil
end

local function tryStart(c: Model, hum: Humanoid, hrp: BasePart)
	local t = os.clock()
	if t - lastEnd < 0.15 then
		return
	end
	local owner = MoveState.Owner()
	if owner ~= nil and owner ~= "dash" and owner ~= "super" and owner ~= "walljump2" then
		return
	end
	if hum.FloorMaterial ~= Enum.Material.Air or hum.Health <= 0 then
		return
	end
	local st = hum:GetState()
	if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Dead then
		return
	end
	local v = hrp.AssemblyLinearVelocity
	local hv = Vector3.new(v.X, 0, v.Z)
	if hv.Magnitude < tune("MinEntrySpeed") or v.Y < -60 then
		return
	end
	local vdir = hv.Unit
	local side = Vector3.yAxis:Cross(vdir) -- right of the velocity (works with aim lock: not the look direction)
	params.FilterDescendantsInstances = { c, table.unpack(deps.ignore) }
	for _, d in { side, -side } do
		-- Titanfall 2 reference: anything about waist high works as a short wall-run surface, so one contact at root
		-- (waist) height is enough; RequireTallWall = 1 also demands a contact 1.6 studs higher (Step 1 behaviour)
		local h1 = sideHit(hrp.Position, d, tune("Reach"))
		local h2 = if tune("RequireTallWall") >= 0.5 then (h1 and sideHit(hrp.Position + Vector3.new(0, 1.6, 0), d, tune("Reach") + 0.3)) else h1
		if h1 and h2 then
			local n = CoreGeom.Flat(h1.Normal)
			if n then
				if h1.Instance == lastWall and t - lastWallT < tune("SameWallDelay") then
					return
				end
				local md = hum.MoveDirection
				if md.Magnitude > 0.1 and md:Dot(n) > 0.3 then
					return -- steering away from the wall
				end
				local along = hv - n * hv:Dot(n)
				local tdir = CoreGeom.Flat(along)
				if not tdir or along.Magnitude < tune("MinEntrySpeed") then
					return
				end
				endCarry() -- a wall jump landing on the next wall continues as a wall run
				if not MoveState.Claim("wallrun2", true) then
					return
				end
				local speed = math.clamp(along.Magnitude + tune("EntryBoost"), tune("MinSpeed"), tune("MaxSpeed"))
				local att = Instance.new("Attachment")
				att.Name = "CoreWallRunAttachment"
				att.Parent = hrp
				local lv = Instance.new("LinearVelocity")
				lv.Attachment0 = att
				lv.RelativeTo = Enum.ActuatorRelativeTo.World
				lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
				lv.MaxForce = math.huge
				lv.VectorVelocity = v
				lv.Parent = hrp
				local ao = Instance.new("AlignOrientation")
				ao.Attachment0 = att
				ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
				ao.Responsiveness = tune("AlignResponsiveness")
				ao.MaxTorque = math.huge
				ao.CFrame = hrp.CFrame.Rotation
				ao.Parent = hrp
				local track = runTrack(c, hum)
				if track then
					track:Play(0.12)
				end
				run = {
					t0 = t,
					n = n,
					t = tdir,
					speed = speed,
					vy = math.min(v.Y, tune("RiseKeep")),
					wall = h1.Instance,
					att = att,
					lv = lv,
					ao = ao,
					track = track,
					autoRotate = hum.AutoRotate,
					peel = 0,
					startPos = hrp.Position,
					entrySpeed = Vector3.new(v.X, 0, v.Z).Magnitude,
				}
				hum.AutoRotate = false
				jumpQueued = false
				note({ kind = "wallrun2", entry = run.entrySpeed, speed = speed, vy = run.vy })
				deps.send("move", { state = "wallrun" })
				return
			end
		end
	end
end

function WallRun2.Start(d: typeof(deps))
	deps = d
	-- JumpRequest repeats every frame while jump is held, so the takeoff press would wall-jump the moment the wall is
	-- caught (measured: 0.017 s runs). A wall jump needs a fresh press: a gap of >0.1 s since the last request.
	local lastJumpReq = 0
	UserInputService.JumpRequest:Connect(function()
		local now = os.clock()
		local fresh = now - lastJumpReq > 0.1
		lastJumpReq = now
		if run and fresh then
			jumpQueued = true
		end
	end)
	player.CharacterAdded:Connect(function()
		if run then
			run = nil
			MoveState.Release("wallrun2")
		end
		camTarget = Vector3.zero
	end)
	RunService.Heartbeat:Connect(function(dt)
		camBias = camBias:Lerp(camTarget, math.min(1, dt * 6))
		local c = player.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not c or not hum or not hrp then
			return
		end
		if tune("Mode") < 1.5 then
			if run then
				finish("mode_off")
			end
			return
		end
		local cr = carry
		if cr then
			local o = MoveState.Owner()
			if o ~= "walljump2" or os.clock() >= cr.untilT or (hum.FloorMaterial ~= Enum.Material.Air and os.clock() - cr.t0 > 0.1) then
				if o == "walljump2" then
					endCarry()
				else
					carry = nil
					cr.lv:Destroy()
					cr.att:Destroy()
				end
			end
		end
		local r = run
		if not r then
			tryStart(c, hum, hrp)
			return
		end
		if MoveState.Owner() ~= "wallrun2" then
			-- a dash took over: clean up quietly, the dash owns the velocity now
			run = nil
			r.lv:Destroy()
			r.ao:Destroy()
			r.att:Destroy()
			if r.track then
				r.track:Stop(0.1)
			end
			hum.AutoRotate = r.autoRotate
			lastEnd = os.clock()
			camTarget = Vector3.zero
			deps.send("move", { state = "run" })
			return
		end
		local t = os.clock()
		if jumpQueued then
			jumpQueued = false
			return finish("jump")
		end
		if t - r.t0 > tune("Seconds") then
			return finish("time")
		end
		if hum.FloorMaterial ~= Enum.Material.Air and t - r.t0 > 0.12 then
			return finish("ground")
		end
		params.FilterDescendantsInstances = { c, table.unpack(deps.ignore) }
		local hit = sideHit(hrp.Position, -r.n, tune("Reach") + 0.6)
		if not hit then
			return finish("edge")
		end
		local n = CoreGeom.Flat(hit.Normal) or r.n
		r.n = n
		r.wall = hit.Instance
		r.t = CoreGeom.Flat(r.t - n * r.t:Dot(n)) or r.t
		-- peel: pushing away from the wall
		local md = hum.MoveDirection
		if md.Magnitude > 0.1 and md:Dot(n) > tune("PeelDot") then
			r.peel += dt
			if r.peel >= tune("PeelSeconds") then
				return finish("peel")
			end
		else
			r.peel = 0
		end
		if r.speed < tune("TargetSpeed") then
			r.speed = math.min(tune("TargetSpeed"), r.speed + tune("Accel") * dt)
		end
		r.speed = math.min(r.speed, tune("MaxSpeed"))
		r.vy = math.max(r.vy - tune("Gravity") * dt, -tune("MaxSink"))
		r.lv.VectorVelocity = r.t * r.speed - n * tune("Stick") + Vector3.yAxis * r.vy
		local up = (Vector3.yAxis + n * math.tan(math.rad(tune("TiltDegrees")))).Unit
		r.ao.CFrame = CFrame.lookAt(Vector3.zero, r.t, up)
		camTarget = n * tune("CamPush")
		if r.track then
			r.track:AdjustSpeed(math.clamp(r.speed / 16, 0.8, 3))
		end
	end)
end

return WallRun2

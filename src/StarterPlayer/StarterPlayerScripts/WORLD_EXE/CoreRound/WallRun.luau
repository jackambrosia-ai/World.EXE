--!strict
-- Core Round Step 1: copied from game PR #22 (Rev 15u, Controllers/WallRun.luau). Changes: tuning now reads CoreConfig.Tuning.WallRun
-- (CoreTune_WallRun_<Key> attributes), and a Super Dash ("super") may hand over to a wall run like a dash.
-- WallRun (wrist-hacking prototype, client) — Rev 15g, owner 2026-11-16: "the wall run still needs to be
-- implemented". Reference MOV-03 (owner video): a fast runner travels along building faces at window
-- height, then drops off. Original WORLD.EXE interpretation; uses the MoveState "wallrun" owner that Rev 15
-- reserved for it.
--
-- Start (owner 2026-11-16): a fresh Space / jump press, OR Space already HELD while airborne when the wall
--   comes within reach (Rev 15k; re-armed by releasing Space after a run that did not end in a wall jump), AND the wall must be at the player's SIDE
--   (character left / right: |look . normal| <= SideFacingMaxDot). Also needed: moving (WASD / stick) at
--   >= MinSpeed horizontally; from the ground or in the air; a near-vertical,
--   collidable, non-character wall within Reach on the LEFT or RIGHT side, tall enough (two rays); not
--   just after the last wall run (ReattachDelay); nothing else owns the velocity (FLING SELF, a drive).
-- While running: carried along the wall at max(current, Speed) with a short rise then a sinking arc
--   (Rev 15i: runs UP the wall first - ClimbSpeed easing to 0 over ClimbSeconds - then a gentle capped
--   descent; stops climbing at the top edge), kept close to the wall, body tilted away from it, the run animation playing.
--   The wall normal is re-read every frame, so gently curved walls are followed.
-- Corners (Rev 15j, owner): NO corner wrapping; the run ends at a corner or the wall's end.
-- Ends: Space = wall jump (out + up + along; also within EdgeJumpGrace after the run ends at the wall's end); landing; the wall ends; letting go of the movement keys;
--   (Rev 15m Flow) pushing away from the wall
--   Seconds elapsed; dash / super-speed / FLING SELF taking over (MoveState). Never ragdolls.
-- Rev 15m "Flow" (owner Rev 15l play-test: wall-running "needs work"; HackTune_WallRun_Flow = 1, 0 = the
--   exact Rev 15l behaviour for comparison). Same rules as above; only the feel changes:
--   * entry blends from the arrival velocity over EntryBlendSeconds (no yank) and keeps entry momentum
--     (capped at MaxEntrySpeed, settling toward Speed at SpeedSettle);
--   * input while attached: holding back along the wall brakes toward MinCruise, pushing away from the wall
--     for PeelSeconds peels off (no wall jump), forward / toward the wall keeps cruising;
--   * the body leans into the run (ForwardLeanDegrees) as well as away from the wall; the run animation
--     rate follows the speed;
--   * leaving at a wall end / corner / time limit / peel keeps the momentum for ExitCarrySeconds (Roblox air
--     control would otherwise cancel it at once);
--   * a fresh Space press during a grounded DASH next to a wall hands the dash over to a wall run.
-- Rev 15s (owner: Rev 15m Flow "still needs work"; presentation findings measured with the normal camera):
--   Flow 2 "Runner" (default) = Flow 1 plus: the run cycle plays at the ground-run rate for the speed
--   (speed / RunAnimStuds; it played ~38% too slow = feet sliding = "gliding"); the default Freefall wind
--   sound is muted and real footsteps play while on the wall (the Humanoid is in Freefall, so it played the
--   FALLING sound and no steps); the camera eases a little out from the wall (Humanoid.CameraOffset) so the
--   runner is seen against the wall instead of the wall filling half the screen.
--   Flow 3 "Planted" = Flow 2 with a stronger lean away from the wall (PlantedLeanDegrees) so the feet
--   reach the wall face. Flow 1 = Rev 15m, Flow 0 = Rev 15l (kept for comparison).
-- Physics stays on this (owning) client like all character movement, so others see it replicate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CoreConfig = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("CoreRound"):WaitForChild("CoreConfig"))
local MoveState = require(script.Parent:WaitForChild("MoveState"))

local WallRun = {}

local function tune(key: string): number
	return CoreConfig.Tune("WallRun", key)
end

local function flat(v: Vector3): Vector3?
	local h = Vector3.new(v.X, 0, v.Z)
	return if h.Magnitude > 0.05 then h.Unit else nil
end

export type Deps = {
	ignore: { Instance }, -- extra folders the wall rays skip (effects)
	onStart: ((dir: Vector3) -> ())?,
	onStep: ((footPos: Vector3, normal: Vector3) -> ())?,
	onEnd: ((how: string) -> ())?,
}

function WallRun.Start(deps: Deps)
	local player = Players.LocalPlayer
	type Run = {
		n: Vector3, -- wall normal (flat, pointing away from the wall)
		t: Vector3, -- run direction along the wall
		speed: number,
		t0: number,
		att: Attachment,
		lv: LinearVelocity,
		ao: AlignOrientation,
		track: AnimationTrack?,
		hum: Humanoid,
		hrp: BasePart,
		autoRotate: boolean,
		lastStep: number,
		startPos: Vector3,
		corners: number,
		lift: number, -- initial climb speed (a little less when latching from the air)
		v0: Vector3, -- Rev 15m: arrival velocity (into-wall part removed), blended out over EntryBlendSeconds
		base: number, -- Rev 15m: cruise target along the wall
		peelT: number, -- Rev 15m: how long the stick has pushed away from the wall
		flow: boolean,
		runner: boolean, -- Rev 15s Flow >= 2
		planted: boolean, -- Rev 15s Flow >= 3
		steps: Sound?,
		fallSound: Sound?,
		fallVolume: number,
	}
	local run: Run? = nil
	local camTarget = Vector3.zero -- Rev 15s: world-space camera offset wanted (eased in Heartbeat)
	local camNow = Vector3.zero
	local lastEnd = -10
	-- wall-jump carry: Roblox air control (holding a direction) cancels the jump-out push in ~0.25 s
	-- (measured 40 -> 0 studs/s), so the jump keeps its horizontal velocity for up to JumpCarrySeconds,
	-- or until the next wall run / landing / anything else takes the velocity.
	local carry: { lv: LinearVelocity, att: Attachment, untilT: number, t0: number, hum: Humanoid }? = nil
	local function endCarry()
		local cr = carry
		if cr then
			carry = nil
			cr.lv:Destroy()
			cr.att:Destroy()
			MoveState.Release("walljump")
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true

	local function wallHit(origin: Vector3, dir: Vector3, reach: number): RaycastResult?
		local hit = workspace:Raycast(origin, dir * reach, params)
		if not hit or math.abs(hit.Normal.Y) > 0.3 then
			return nil
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			return nil -- never wall-run on a character
		end
		return hit
	end

	-- Rev 15k (owner): the wall jump works from the END of the wall too. When a run ends at the wall's
	-- end / a corner / the wall ahead / the time limit, a jump press within EdgeJumpGrace still does the full
	-- wall jump from that wall.
	local edge: { n: Vector3, t: Vector3, speed: number, hrp: BasePart, hum: Humanoid, untilT: number }? = nil
	-- Rev 15k (owner): holding Space when reaching a wall starts the run too. After a run ends WITHOUT a wall
	-- jump, a held Space only counts again once it has been released (no endless re-latching onto the same
	-- wall); a wall jump keeps it armed so you can hold Space through a wall-to-wall chain.
	local heldArmed = true

	-- horizontal carry after leaving the wall (wall jump, Rev 15m: also a flowing exit); owner "walljump"
	local function startCarry(hrp: BasePart, hum: Humanoid, flatV: Vector3, seconds: number)
		endCarry()
		MoveState.Release("wallrun")
		if MoveState.Claim("walljump") then
			local att = Instance.new("Attachment")
			att.Name = "WallJumpAttachment"
			att.Parent = hrp
			local lv = Instance.new("LinearVelocity")
			lv.Name = "WallJumpCarry"
			lv.Attachment0 = att
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane -- horizontal only; gravity arcs it
			lv.PrimaryTangentAxis = Vector3.xAxis
			lv.SecondaryTangentAxis = Vector3.zAxis
			lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
			lv.MaxForce = hrp.AssemblyMass * 3000
			lv.PlaneVelocity = Vector2.new(flatV.X, flatV.Z)
			lv.Parent = hrp
			carry = { lv = lv, att = att, untilT = os.clock() + seconds, t0 = os.clock(), hum = hum }
		end
	end

	local function wallJump(hrp: BasePart, hum: Humanoid, n: Vector3, t: Vector3, speed: number)
		local flatV = n * tune("JumpOut") + t * (speed * 0.75)
		hrp.AssemblyLinearVelocity = flatV + Vector3.new(0, tune("JumpUp"), 0)
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		startCarry(hrp, hum, flatV, tune("JumpCarrySeconds"))
		heldArmed = true
		lastEnd = os.clock()
		if deps.onEnd then
			deps.onEnd("jump")
		end
	end

	local function finish(how: string)
		local r = run
		if not r then
			return
		end
		run = nil
		lastEnd = os.clock()
		r.lv:Destroy()
		r.ao:Destroy()
		r.att:Destroy()
		if r.track then
			r.track:Stop(0.15)
		end
		if r.steps then
			r.steps:Destroy()
		end
		if r.fallSound and r.fallSound.Parent then
			r.fallSound.Volume = r.fallVolume
		end
		camTarget = Vector3.zero
		if r.hum.Parent then
			r.hum.AutoRotate = r.autoRotate
		end
		local v = r.hrp.AssemblyLinearVelocity
		if how == "jump" then
			MoveState.Release("wallrun")
			wallJump(r.hrp, r.hum, r.n, r.t, r.speed)
		elseif how ~= "taken" then
			heldArmed = false -- release Space before a held Space starts another run
			if how == "wall_end" or how == "corner" or how == "wall_ahead" or how == "timeout" then
				edge = { n = r.n, t = r.t, speed = r.speed, hrp = r.hrp, hum = r.hum, untilT = os.clock() + tune("EdgeJumpGrace") }
			end
			-- keep the momentum along the wall, drop the wall-stick component
			local out = if how == "peel" then tune("PeelOut") else 4
			local flatV = r.t * r.speed * 0.9 + r.n * out
			r.hrp.AssemblyLinearVelocity = flatV + Vector3.new(0, math.min(v.Y, 6), 0)
			if r.flow and (how == "wall_end" or how == "corner" or how == "wall_ahead" or how == "timeout" or how == "peel") and r.hum.Health > 0 then
				startCarry(r.hrp, r.hum, flatV, tune("ExitCarrySeconds")) -- Rev 15m: no momentum cut at the exit
			end
		end
		MoveState.Release("wallrun")
		local c = r.hrp.Parent
		if c then
			local p = r.hrp.Position
			c:SetAttribute("WORLD_EXE_WallRunLast", string.format("%s after %.2fs, %.1f studs from start, dy %.1f, corners %d", how, os.clock() - r.t0,
				Vector3.new(p.X - r.startPos.X, 0, p.Z - r.startPos.Z).Magnitude, p.Y - r.startPos.Y, r.corners))
			c:SetAttribute("WORLD_EXE_WallRunning", nil)
		end
		if deps.onEnd and how ~= "jump" then
			deps.onEnd(how)
		end
	end

	local function orientation(r: Run): CFrame
		local lean = math.rad(if r.planted then tune("PlantedLeanDegrees") else tune("LeanDegrees"))
		if not r.flow then
			local up = (Vector3.yAxis * math.cos(lean) + r.n * math.sin(lean)).Unit
			return CFrame.lookAt(Vector3.zero, r.t, up)
		end
		-- Rev 15m: lean away from the wall AND into the run (a runner, not a sliding block)
		local fwd = math.rad(tune("ForwardLeanDegrees"))
		local up = (Vector3.yAxis + r.n * math.tan(lean) + r.t * math.tan(fwd)).Unit
		local look = (r.t - up * r.t:Dot(up)).Unit
		return CFrame.fromMatrix(Vector3.zero, look:Cross(up), up, -look)
	end

	local function tryStart(c: Model, hrp: BasePart, hum: Humanoid)
		-- Step 1B: this Step 1 (climbing) wall-run only runs as the comparison mode WallRun2.Mode = 1
		local mode = CoreConfig.Tune("WallRun2", "Mode")
		if mode < 0.5 or mode > 1.5 then
			return
		end
		local owner = MoveState.Owner()
		local level = tune("Flow")
		local flow = level >= 0.5
		local runner = level >= 1.5
		local planted = level >= 2.5
		-- Rev 15m: a grounded dash, or a FLING SELF flight (beside a wall), can hand over to a wall run
		local fromDash = flow and (owner == "dash" or owner == "super" or owner == "flingSelf")
		if (owner ~= nil and owner ~= "walljump" and not fromDash) or os.clock() - lastEnd < tune("ReattachDelay") then
			return
		end
		if hum:GetState() == Enum.HumanoidStateType.Physics then
			return
		end
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		local md = hum.MoveDirection
		local v = hrp.AssemblyLinearVelocity
		local vdir = flat(v)
		if md.Magnitude < 0.3 or not vdir or Vector3.new(v.X, 0, v.Z).Magnitude < tune("MinSpeed") or v.Y < -60 then
			return
		end
		params.FilterDescendantsInstances = { c, table.unpack(deps.ignore) }
		-- owner 2026-11-16: only when the SIDE of the player faces the wall (character's left / right, not
		-- the front or back)
		local look = flat(hrp.CFrame.LookVector)
		local side = flat(hrp.CFrame.RightVector)
		if not look or not side then
			return
		end
		local reach = tune("Reach")
		for _, d in { side, -side } do
			local hit = wallHit(hrp.Position, d, reach)
			if hit and math.abs(look:Dot(hit.Normal)) > tune("SideFacingMaxDot") then
				hit = nil -- the wall is in front of / behind the player, not at their side
			end
			if hit and wallHit(hrp.Position + Vector3.new(0, 1.8, 0), d, reach + 0.5) then
				local n = flat(hit.Normal)
				if n and md:Dot(n) < 0.35 then -- not steering away from the wall
					local t = flat(v - n * v:Dot(n)) or flat(md - n * md:Dot(n))
					if not t then
						return
					end
					endCarry() -- a wall jump landing on the next wall continues as a wall run
					if not MoveState.Claim("wallrun", fromDash) then
						return
					end
					local speed = math.max(Vector3.new(v.X, 0, v.Z).Magnitude, tune("Speed"))
					if flow then
						-- keep the momentum ALONG the wall (not the part going into it), within MaxEntrySpeed
						speed = math.clamp(math.abs(v:Dot(t)), tune("Speed"), math.max(tune("Speed"), tune("MaxEntrySpeed")))
					end
					local v0 = v - n * math.min(0, v:Dot(n))
					-- the Space press also starts a Humanoid jump AFTER this sample: never blend the climb down from
					-- below the climb speed (measured: vy 36 -> 9 -> 30 dip without this)
					if grounded then
						v0 = Vector3.new(v0.X, math.max(v0.Y, tune("ClimbSpeed")), v0.Z) -- mid-air entries blend from the real fall
					end
					local att = Instance.new("Attachment")
					att.Name = "WallRunAttachment"
					att.Parent = hrp
					local lv = Instance.new("LinearVelocity")
					lv.Name = "WallRunDrive"
					lv.Attachment0 = att
					lv.RelativeTo = Enum.ActuatorRelativeTo.World
					lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
					lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
					lv.MaxForce = hrp.AssemblyMass * 4000
					lv.VectorVelocity = if flow then v0 else t * speed + Vector3.new(0, tune("ClimbSpeed"), 0)
					lv.Parent = hrp
					local ao = Instance.new("AlignOrientation")
					ao.Name = "WallRunLean"
					ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
					ao.Attachment0 = att
					ao.Responsiveness = 30
					ao.MaxTorque = 1e6
					ao.Parent = hrp
					local track: AnimationTrack? = nil
					local animate = c:FindFirstChild("Animate")
					local runFolder = animate and animate:FindFirstChild("run")
					local anim = runFolder and runFolder:FindFirstChildOfClass("Animation")
					local animator = hum:FindFirstChildOfClass("Animator")
					if anim and animator then
						local ok, tr = pcall(function()
							return animator:LoadAnimation(anim)
						end)
						if ok and tr then
							track = tr
							tr.Priority = Enum.AnimationPriority.Action
							tr:Play(0.1)
							tr:AdjustSpeed(if runner then speed / tune("RunAnimStuds") elseif flow then tune("AnimRate") * speed / tune("Speed") else 1.5)
						end
					end
					local r: Run = { n = n, t = t, speed = speed, t0 = os.clock(), lift = tune("ClimbSpeed") * (if grounded then 1 else tune("AirClimbScale")), att = att, lv = lv, ao = ao, track = track, hum = hum, hrp = hrp,
						autoRotate = hum.AutoRotate, lastStep = 0, startPos = hrp.Position, corners = 0, v0 = v0, base = tune("Speed"), peelT = 0, flow = flow,
						runner = runner, planted = planted, steps = nil, fallSound = nil, fallVolume = 0 }
					if runner then
						-- footsteps on the wall; the Humanoid's own Freefall wind is muted for the run
						local fs = hrp:FindFirstChild("FreeFalling")
						if fs and fs:IsA("Sound") then
							r.fallSound = fs
							r.fallVolume = fs.Volume
							fs.Volume = 0
						end
						local st = Instance.new("Sound")
						st.Name = "WallRunSteps"
						st.SoundId = "rbxasset://sounds/action_footsteps_plastic.mp3"
						st.Looped = true
						st.Volume = tune("StepsVolume")
						st.PlaybackSpeed = speed / tune("Speed") * 1.1
						st.RollOffMode = Enum.RollOffMode.InverseTapered
						st.RollOffMinDistance = 8
						st.RollOffMaxDistance = 70
						st.Parent = hrp
						st:Play()
						r.steps = st
					end
					hum.AutoRotate = false
					ao.CFrame = orientation(r)
					run = r
					c:SetAttribute("WORLD_EXE_WallRunning", true)
					if deps.onStart then
						deps.onStart(t)
					end
					return
				end
			end
		end
	end

	local function step(r: Run, c: Model, dt: number)
		local el = os.clock() - r.t0
		if MoveState.Owner() ~= "wallrun" then
			finish("taken")
			return
		end
		if not r.hrp.Parent or r.hum.Health <= 0 then
			finish("dead")
			return
		end
		if el > tune("Seconds") then
			finish("timeout")
			return
		end
		if el > 0.35 and r.hum.FloorMaterial ~= Enum.Material.Air then
			finish("landed")
			return
		end
		local md = r.hum.MoveDirection
		-- you stay on while holding any direction
		-- and leave by letting go, Space (wall jump), the wall ending or the time limit
		if md.Magnitude < 0.2 then
			finish("released")
			return
		end
		if r.flow then
			-- Rev 15m directional control: away from the wall = peel off; back along it = brake; else cruise
			if md:Dot(r.n) > tune("PeelDot") then
				r.peelT += dt
				if r.peelT >= tune("PeelSeconds") then
					finish("peel")
					return
				end
			else
				r.peelT = 0
			end
			local braking = md:Dot(r.t) < -0.3
			local target = if braking then tune("MinCruise") else r.base
			if r.speed > target then
				r.speed = math.max(target, r.speed - (if braking then tune("BackBrake") else tune("SpeedSettle")) * dt)
			else
				r.speed = math.min(target, r.speed + tune("SpeedSettle") * dt)
			end
			if r.track then
				if r.runner then
					r.track:AdjustSpeed(math.max(0.8, r.speed / tune("RunAnimStuds"))) -- ground-run rate: no foot sliding
				else
					r.track:AdjustSpeed(tune("AnimRate") * math.max(0.6, r.speed / tune("Speed")))
				end
			end
			if r.steps then
				r.steps.PlaybackSpeed = math.max(0.7, r.speed / tune("Speed") * 1.1)
			end
			if r.runner then
				camTarget = r.n * tune("CamPushOut") + Vector3.new(0, tune("CamLift"), 0)
			end
		end

		params.FilterDescendantsInstances = { c, table.unpack(deps.ignore) }
		local pos = r.hrp.Position
		-- Rev 15j (owner 2026-11-16): the wall run does NOT take you around corners. A wall straight ahead
		-- (inside corner) or the face ending (outside corner) ends the run, and so does a sharp change of the
		-- wall normal (> 25 degrees): only gently curved walls are followed.
		local ahead = wallHit(pos, r.t, 2.4)
		if ahead then
			local na = flat(ahead.Normal)
			if na and na:Dot(r.t) < -0.7 then
				finish("wall_ahead")
				return
			end
		end
		local hit = wallHit(pos, -r.n, tune("Reach") + 1.2)
		if not hit then
			finish("wall_end")
			return
		end
		local hn = flat(hit.Normal)
		if hn and hn:Dot(r.n) < math.cos(math.rad(25)) then
			finish("corner")
			return
		end
		local h = hit :: RaycastResult
		local n = flat(h.Normal)
		if n then
			r.n = n
			r.t = flat(r.t - n * r.t:Dot(n)) or r.t -- follow gentle curves, keep the direction sign
		end
		-- Rev 15i, owner: "you shouldn't just glide across the wall without moving upward". MOV-03 (re-read
		-- frame by frame): on latching the runner RUNS UP the wall (sidewalk -> near the roofline in a
		-- fraction of a second), then travels along the face gradually coming down past the window rows.
		-- So: a strong climb easing to 0 over ClimbSeconds, then a gentle capped descent. Near the top of the
		-- wall (the upper ray finds no wall) the climb stops at the edge instead of running off the top.
		local climbT = tune("ClimbSeconds")
		local vy
		if el < climbT then
			local k = 1 - el / climbT
			vy = r.lift * k * k * (3 - 2 * k) -- smooth ease-out of the climb
		else
			vy = -math.min(tune("MaxSink"), tune("Gravity") * (el - climbT))
		end
		if vy > 0 and not wallHit(pos + Vector3.new(0, tune("TopClearance"), 0), -r.n, tune("Reach") + 1.5) then
			vy = 0 -- at the top edge: hold height
		end
		local stick = if h.Distance > 1.6 then tune("Stick") else 0
		hit = h
		local want = r.t * r.speed + Vector3.new(0, vy, 0) - r.n * stick
		local blend = tune("EntryBlendSeconds")
		if r.flow and el < blend then
			local a = math.clamp(el / blend, 0, 1)
			want = r.v0:Lerp(want, a * a * (3 - 2 * a)) -- Rev 15m: no velocity yank on latching
		end
		r.lv.VectorVelocity = want
		r.ao.CFrame = orientation(r)
		if deps.onStep and os.clock() - r.lastStep > 0.09 then
			r.lastStep = os.clock()
			deps.onStep(hit.Position - Vector3.new(0, 2, 0) + r.n * 0.3, r.n)
		end
	end

	-- Space (keyboard), A (gamepad) or the touch jump button: one fresh press = one action. JumpRequest
	-- repeats while the button is held, so only a request after a 0.2 s gap counts as a new press.
	local lastReq = 0
	UserInputService.JumpRequest:Connect(function()
		local now = os.clock()
		local fresh = now - lastReq > 0.2
		lastReq = now
		if not fresh then
			return
		end
		local r = run
		if r then
			if now - r.t0 > 0.08 then
				finish("jump")
			end
			return
		end
		local e = edge
		if e and now <= e.untilT and e.hrp.Parent and e.hum.Health > 0 then
			edge = nil
			wallJump(e.hrp, e.hum, e.n, e.t, e.speed) -- jump off from the end of the wall
			return
		end
		local c = player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if c and hrp and hum and hum.Health > 0 then
			tryStart(c, hrp, hum) -- owner: wall run starts ONLY on a Space press with the wall at your side
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local c = player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not c or not hrp or not hum then
			if run then
				finish("dead")
			end
			return
		end
		if camNow ~= camTarget or camTarget.Magnitude > 0 then
			local k = math.clamp(dt * (if camTarget.Magnitude > 0 then 5 else 3.5), 0, 1)
			camNow = camNow:Lerp(camTarget, k)
			if camTarget.Magnitude == 0 and camNow.Magnitude < 0.02 then
				camNow = Vector3.zero
			end
			hum.CameraOffset = hrp.CFrame:VectorToObjectSpace(camNow)
		end
		local cr = carry
		if cr and (os.clock() > cr.untilT or MoveState.Owner() ~= "walljump" or (cr.hum.FloorMaterial ~= Enum.Material.Air and os.clock() > cr.t0 + 0.15)) then
			endCarry()
		end
		if run then
			step(run :: Run, c, dt)
		else
			-- Rev 15k: Space already held when reaching a wall (side-on) starts the run as well
			local held = hum.Jump or UserInputService:IsKeyDown(Enum.KeyCode.Space)
			if not held then
				heldArmed = true
			elseif heldArmed and hum.FloorMaterial == Enum.Material.Air then
				tryStart(c, hrp, hum)
			end
		end
	end)

	player.CharacterAdded:Connect(function()
		if run then
			finish("dead")
		end
	end)
end

return WallRun

--!strict
-- WallRun (wrist-hacking prototype, client) — Rev 15g, owner 2026-11-16: "the wall run still needs to be
-- implemented". Reference MOV-03 (owner video): a fast runner travels along building faces at window
-- height, then drops off. Original WORLD.EXE interpretation; uses the MoveState "wallrun" owner that Rev 15
-- reserved for it.
--
-- Start (owner 2026-11-16): ONLY on a fresh Space / jump press, AND the wall must be at the player's SIDE
--   (character left / right: |look . normal| <= SideFacingMaxDot). Also needed: moving (WASD / stick) at
--   >= MinSpeed horizontally; from the ground or in the air; a near-vertical,
--   collidable, non-character wall within Reach on the LEFT or RIGHT side, tall enough (two rays); not
--   just after the last wall run (ReattachDelay); nothing else owns the velocity (FLING SELF, a drive).
-- While running: carried along the wall at max(current, Speed) with a short rise then a sinking arc
--   (Rev 15i: runs UP the wall first - ClimbSpeed easing to 0 over ClimbSeconds - then a gentle capped
--   descent; stops climbing at the top edge), kept close to the wall, body tilted away from it, the run animation playing.
--   The wall normal is re-read every frame, so gently curved walls are followed.
-- Corners (Rev 15j, owner): NO corner wrapping; the run ends at a corner or the wall's end.
-- Ends: Space = wall jump (out + up + along); landing; the wall ends; letting go of the movement keys
--   Seconds elapsed; dash / super-speed / FLING SELF taking over (MoveState). Never ragdolls.
-- Physics stays on this (owning) client like all character movement, so others see it replicate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HackCatalog = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("HackCatalog"))
local MoveState = require(script.Parent:WaitForChild("MoveState"))

local WallRun = {}

local function tune(key: string): number
	return HackCatalog.Tune("WallRun", key)
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
	}
	local run: Run? = nil
	local lastEnd = -10
	-- wall-jump carry: Roblox air control (holding a direction) cancels the jump-out push in ~0.25 s
	-- (measured 40 -> 0 studs/s), so the jump keeps its horizontal velocity for up to JumpCarrySeconds,
	-- or until the next wall run / landing / anything else takes the velocity.
	local carry: { lv: LinearVelocity, att: Attachment, untilT: number, hum: Humanoid }? = nil
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
		if r.hum.Parent then
			r.hum.AutoRotate = r.autoRotate
		end
		local v = r.hrp.AssemblyLinearVelocity
		if how == "jump" then
			local flatV = r.n * tune("JumpOut") + r.t * (r.speed * 0.75)
			r.hrp.AssemblyLinearVelocity = flatV + Vector3.new(0, tune("JumpUp"), 0)
			r.hum:ChangeState(Enum.HumanoidStateType.Jumping)
			MoveState.Release("wallrun")
			if MoveState.Claim("walljump") then
				local att = Instance.new("Attachment")
				att.Name = "WallJumpAttachment"
				att.Parent = r.hrp
				local lv = Instance.new("LinearVelocity")
				lv.Name = "WallJumpCarry"
				lv.Attachment0 = att
				lv.RelativeTo = Enum.ActuatorRelativeTo.World
				lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane -- horizontal only; gravity arcs it
				lv.PrimaryTangentAxis = Vector3.xAxis
				lv.SecondaryTangentAxis = Vector3.zAxis
				lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
				lv.MaxForce = r.hrp.AssemblyMass * 3000
				lv.PlaneVelocity = Vector2.new(flatV.X, flatV.Z)
				lv.Parent = r.hrp
				carry = { lv = lv, att = att, untilT = os.clock() + tune("JumpCarrySeconds"), hum = r.hum }
			end
		elseif how ~= "taken" then
			-- keep the momentum along the wall, drop the wall-stick component
			r.hrp.AssemblyLinearVelocity = r.t * r.speed * 0.9 + Vector3.new(0, math.min(v.Y, 6), 0) + r.n * 4
		end
		MoveState.Release("wallrun")
		local c = r.hrp.Parent
		if c then
			local p = r.hrp.Position
			c:SetAttribute("WORLD_EXE_WallRunLast", string.format("%s after %.2fs, %.1f studs from start, dy %.1f, corners %d", how, os.clock() - r.t0,
				Vector3.new(p.X - r.startPos.X, 0, p.Z - r.startPos.Z).Magnitude, p.Y - r.startPos.Y, r.corners))
			c:SetAttribute("WORLD_EXE_WallRunning", nil)
		end
		if deps.onEnd then
			deps.onEnd(how)
		end
	end

	local function orientation(r: Run): CFrame
		local lean = math.rad(tune("LeanDegrees"))
		local up = (Vector3.yAxis * math.cos(lean) + r.n * math.sin(lean)).Unit
		return CFrame.lookAt(Vector3.zero, r.t, up)
	end

	local function tryStart(c: Model, hrp: BasePart, hum: Humanoid)
		local owner = MoveState.Owner()
		if (owner ~= nil and owner ~= "walljump") or os.clock() - lastEnd < tune("ReattachDelay") then
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
					if not MoveState.Claim("wallrun") then
						return
					end
					local speed = math.max(Vector3.new(v.X, 0, v.Z).Magnitude, tune("Speed"))
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
					lv.VectorVelocity = t * speed + Vector3.new(0, tune("ClimbSpeed"), 0)
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
							tr:AdjustSpeed(1.5)
						end
					end
					local r: Run = { n = n, t = t, speed = speed, t0 = os.clock(), lift = tune("ClimbSpeed") * (if grounded then 1 else tune("AirClimbScale")), att = att, lv = lv, ao = ao, track = track, hum = hum, hrp = hrp,
						autoRotate = hum.AutoRotate, lastStep = 0, startPos = hrp.Position, corners = 0 }
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

	local function step(r: Run, c: Model)
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
		r.lv.VectorVelocity = r.t * r.speed + Vector3.new(0, vy, 0) - r.n * stick
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
		local c = player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if c and hrp and hum and hum.Health > 0 then
			tryStart(c, hrp, hum) -- owner: wall run starts ONLY on a Space press with the wall at your side
		end
	end)

	RunService.Heartbeat:Connect(function()
		local c = player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not c or not hrp or not hum then
			if run then
				finish("dead")
			end
			return
		end
		local cr = carry
		if cr and (os.clock() > cr.untilT or MoveState.Owner() ~= "walljump" or (cr.hum.FloorMaterial ~= Enum.Material.Air and os.clock() > cr.untilT - tune("JumpCarrySeconds") + 0.15)) then
			endCarry()
		end
		if run then
			step(run :: Run, c)
		end
	end)

	player.CharacterAdded:Connect(function()
		if run then
			finish("dead")
		end
	end)
end

return WallRun

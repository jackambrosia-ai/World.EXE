--!strict
-- Poses (Core Round Step 1B/1C, client): procedural movement poses, drawn on EVERY client for every character.
-- No animation assets or uploads: each pose is a weighted blend applied to the rig's joint Transforms after Roblox's
-- default animations each frame (RunService.PreSimulation). Only joints move: collision, the root part and root motion
-- are never changed by a pose.
--
-- Layers (Step 1C, owner-approved Phase A, item A4):
--   * slide   - lean-back slide, lead leg out, rear leg tucked, disc arm forward. Its weight uses the SAME eased curve
--               as the server's slide hit volumes (CoreGeom.SlideWeight), so the drawn body and the judged volumes
--               lower and rise together (item A1 fairness rule).
--   * wall    - wall-run: the body leans away from the wall and the wall-side hand reaches to the wall. (Step 1B tilted
--               the physical root with an AlignOrientation and it snapped upright on exit; 1C keeps the root upright
--               and draws the lean here, blended in and out.)
--   * reach   - after a wall jump or a slide jump the free (left) arm reaches forward-up for a moment.
-- Other players: states come from the replicated CR_MoveState attribute (no new remote traffic). Their pose clock starts
-- Disc.InterpPlayerSeconds after the attribute arrives: the delay with which their positions are drawn (Step 1
-- calibration), so pose and position stay in step with the server's rewound hit volumes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CoreRound = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))
local CoreGeom = require(CoreRound:WaitForChild("CoreGeom"))

local Poses = {}

local player = Players.LocalPlayer
local deps = {
	localSlide = function(): boolean
		return false
	end,
	localWall = function(): Vector3?
		return nil
	end,
	charging = function(): boolean
		return false
	end,
}

local R = math.rad
-- target joint transforms (local joint space). Sign conventions checked on captures: +X on a shoulder swings the arm
-- forward; -Z on the right shoulder / +Z on the left swings it out to the side (Step 1C); +Z on Root tilts the body
-- to its left (Step 1C).
local SLIDE_R15 = {
	-- torso / head targets are shared with the server (CoreGeom.SlidePoseR15) so it can compute the drawn head height
	Root = CoreGeom.SlidePoseR15.Root, -- lower + lean back
	Waist = CoreGeom.SlidePoseR15.Waist, -- curl the chest forward a little
	Neck = CoreGeom.SlidePoseR15.Neck, -- keep looking ahead
	RightHip = CFrame.Angles(R(34), 0, 0), -- lead leg extended forward
	RightKnee = CFrame.Angles(R(-6), 0, 0),
	LeftHip = CFrame.Angles(R(-8), 0, R(-6)), -- rear leg tucked under
	LeftKnee = CFrame.Angles(R(-105), 0, 0),
	RightShoulder = CFrame.Angles(R(55), 0, R(10)), -- disc arm forward
	LeftShoulder = CFrame.Angles(R(-25), 0, R(-40)), -- balance arm back / out
}
local SLIDE_R6 = {
	RootJoint = CFrame.new(0, 0, -1.2) * CFrame.Angles(R(-38), 0, 0), -- R6 RootJoint axes differ (Z is down)
}

type Joint = { m: any, name: string }
type State = {
	joints: { [string]: any },
	r6: boolean,
	-- slide clock (local os.clock times)
	slideOn: boolean,
	slideStart: number?,
	slideEnd: number?,
	-- wall layer
	wallW: number,
	wallSide: number, -- +1 wall on the character's right, -1 on its left
	wallOn: boolean,
	-- reach layer
	reachT: number,
	lastState: string,
	seenState: string,
	seenAt: number,
}
local states: { [Model]: State } = {}

local function stateFor(c: Model): State
	local s = states[c]
	if s then
		return s
	end
	local joints: { [string]: any } = {}
	for _, d in c:GetDescendants() do
		-- Step 1B finding (draft lesson L-0050): newer avatar rigs use AnimationConstraint joints instead of Motor6D;
		-- both expose .Transform, so both are posed.
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			joints[d.Name] = d
		end
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	local ns: State = {
		joints = joints,
		r6 = hum ~= nil and hum.RigType == Enum.HumanoidRigType.R6,
		slideOn = false,
		slideStart = nil,
		slideEnd = nil,
		wallW = 0,
		wallSide = 1,
		wallOn = false,
		reachT = -10,
		lastState = "run",
		seenState = "run",
		seenAt = 0,
	}
	states[c] = ns
	c.Destroying:Connect(function()
		states[c] = nil
	end)
	return ns
end

local function slideBlend(): number
	return math.max(0.02, CoreConfig.Tune("Slide", "PoseBlendSeconds"))
end

-- current slide weight of a character (0..1, eased; the same curve the server uses for hit volumes)
local function slideWeight(s: State, now: number): number
	return CoreGeom.SlideWeight(s.slideStart, s.slideEnd, now, slideBlend())
end

local function setSlide(s: State, on: boolean, at: number)
	if on == s.slideOn then
		return
	end
	if on then
		-- a quick re-slide continues from the current weight (same rule as the server)
		local cur = slideWeight(s, at)
		s.slideStart = at - cur * slideBlend()
		s.slideEnd = nil
	else
		s.slideEnd = at
	end
	s.slideOn = on
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

-- which side the wall is on for another player's character (they only replicate "wallrun")
local function wallSideOf(c: Model, hrp: BasePart): number?
	params.FilterDescendantsInstances = { c }
	local right = hrp.CFrame.RightVector
	local r = workspace:Raycast(hrp.Position, right * 4, params)
	local l = workspace:Raycast(hrp.Position, -right * 4, params)
	if r and (not l or r.Distance <= l.Distance) then
		return 1
	elseif l then
		return -1
	end
	return nil
end

local function lerpJoint(s: State, name: string, target: CFrame, w: number)
	local j = s.joints[name]
	if j and w > 0.001 then
		j.Transform = j.Transform:Lerp(target, w)
	end
end

Poses.Stats = { frames = 0, seconds = 0 } -- script time spent here (test hook: performance)

function Poses.Start(d: typeof(deps))
	deps = d
	RunService.PreSimulation:Connect(function(dt)
		local t0 = os.clock()
		local now = os.clock()
		local delay = CoreConfig.Tune("Disc", "InterpPlayerSeconds")
		for _, p in Players:GetPlayers() do
			local c = p.Character
			local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if c and c.Parent and hrp then
				local mine = p == player
				local st = c:GetAttribute("CR_MoveState")
				local stateNow = if typeof(st) == "string" then st else "run"
				local s = states[c]
				if not s and stateNow == "run" and not (mine and (deps.localSlide() or deps.localWall() ~= nil)) then
					continue -- nothing to draw and nothing to remember
				end
				s = s or stateFor(c)
				local ss = s :: State
				-- 1. inputs: this client's own state is local and immediate; others' come from the replicated attribute,
				--    applied after the same delay their positions are drawn with
				local sliding, wallNormalSide
				if mine then
					sliding = deps.localSlide()
					local n = deps.localWall()
					if n then
						wallNormalSide = if n:Dot(hrp.CFrame.RightVector) < 0 then 1 else -1
					end
				else
					if stateNow ~= ss.seenState then
						ss.seenState = stateNow
						ss.seenAt = now
					end
					local applied = if now - ss.seenAt >= delay then ss.seenState else ss.lastState
					if applied ~= ss.lastState then
						-- a jump out of a wall-run or a slide (airborne and rising) gets the reach
						if (ss.lastState == "wallrun" or ss.lastState == "slide") and applied == "run" and hrp.AssemblyLinearVelocity.Y > 8 then
							ss.reachT = now
						end
						ss.lastState = applied
					end
					sliding = applied == "slide"
					if applied == "wallrun" then
						wallNormalSide = wallSideOf(c, hrp) or ss.wallSide
					end
				end
				setSlide(ss, sliding, now)
				local wallOn = wallNormalSide ~= nil
				if wallOn then
					ss.wallSide = wallNormalSide :: number
				end
				local wIn, wOut = 0.2, 0.25
				ss.wallW = if wallOn then math.min(1, ss.wallW + dt / wIn) else math.max(0, ss.wallW - dt / wOut)

				-- 2. layers (in order: slide replaces most joints, wall leans and lifts one arm, reach lifts the left arm)
				local sw = slideWeight(ss, now)
				if sw > 0.001 then
					local map = if ss.r6 then SLIDE_R6 else SLIDE_R15
					for name, target in map :: any do
						lerpJoint(ss, name, target, sw)
					end
				end
				local ww = CoreGeom.Ease(ss.wallW)
				if ww > 0.001 and not ss.r6 then
					local side = ss.wallSide
					local lean = R(CoreConfig.Tune("WallRun2", "TiltDegrees"))
					lerpJoint(ss, "Root", CFrame.Angles(0, 0, lean * side), ww)
					-- wall-side hand to the wall (shoulder out to about shoulder height, slightly forward), unless that arm
					-- is holding a charging disc (right arm)
					local armName = if side > 0 then "RightShoulder" else "LeftShoulder"
					local holding = mine and side > 0 and deps.charging()
					if not holding then
						-- measured in Step 1C captures: -Z swings the RIGHT arm out to the side (+Z swung it across the chest)
					lerpJoint(ss, armName, CFrame.Angles(R(25), 0, R(-78) * side), ww)
						lerpJoint(ss, if side > 0 then "RightElbow" else "LeftElbow", CFrame.Angles(R(18), 0, 0), ww)
					end
				elseif ww > 0.001 and ss.r6 then
					lerpJoint(ss, "RootJoint", CFrame.Angles(0, R(CoreConfig.Tune("WallRun2", "TiltDegrees")) * -ss.wallSide, 0), ww)
				end
				local ra = now - ss.reachT
				if ra >= 0 and ra < 0.5 and not ss.r6 then
					local rw = if ra < 0.1 then CoreGeom.Ease(ra / 0.1) else CoreGeom.Ease(1 - (ra - 0.1) / 0.4)
					lerpJoint(ss, "LeftShoulder", CFrame.Angles(R(150), 0, R(-12)), rw)
					lerpJoint(ss, "LeftElbow", CFrame.Angles(R(10), 0, 0), rw)
				end
				-- forget idle characters (no layer active)
				if sw <= 0.001 and ss.wallW <= 0 and ra >= 0.5 and stateNow == "run" and ss.lastState == "run" and not ss.slideOn then
					states[c] = nil
				end
			end
		end
		Poses.Stats.frames += 1
		Poses.Stats.seconds += os.clock() - t0
	end)
end

-- this client's own jump out of a wall-run or slide (immediate; others see it from the replicated state)
function Poses.Reach()
	local c = player.Character
	if c then
		stateFor(c).reachT = os.clock()
	end
end

-- current slide weight of a character as drawn on THIS client (0..1); used by the client's "what I saw" hit record
function Poses.SlideWeight(c: Model): number
	local s = states[c]
	return if s then slideWeight(s, os.clock()) else 0
end

-- this rig's drawn slide-head height above the root (same computation the server uses); cached per character
local headCache: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
function Poses.SlideHead(c: Model): number
	local v = headCache[c]
	if v == nil then
		v = CoreGeom.PosedHeadOffset(c) or CoreConfig.Tune("Slide", "HeadHeight")
		headCache[c] = v
	end
	return v :: number
end

function Poses.Weight(c: Model): number
	return Poses.SlideWeight(c)
end

return Poses

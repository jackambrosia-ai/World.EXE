--!strict
-- Poses (Core Round client): the character animation controller, drawn on EVERY client for every character.
--
-- Step 1E replaces the Step 1B-1D procedural pose layers with original keyframed clips (AnimData, generated from the
-- Blender source WorldEXE_CoreRound_Anim_Step1E.blend by tools/animation). No animation assets, uploads or asset IDs:
-- this module samples the clips itself and writes each joint's Transform ONCE per frame, in RunService.PreSimulation
-- after the Animator (Roblox's default animations stay underneath for idle / walk / climb / swim and anything this
-- controller does not cover). Only joints move: collision, the root part and its motion are never changed (no root
-- motion), so gameplay never waits on an animation.
--
-- Layers, in order (each blends over what is below it):
--   base   one full-body clip at a time with crossfades: run (speed-scaled), fall, land, Power Slide Jump
--          (push -> rise -> apex -> fall), wall-run (wall side aware), wall-jump push -> recovery
--   slide  slide entry -> loop, exit; weight = CoreGeom.SlideWeight, the SAME eased curve the server uses for the slide
--          hit volumes (Step 1C fairness rule), so the drawn torso / head and the judged volumes move together
--   upper  disc charge / release (right arm + an additive chest twist) and shield raise / hold / lower (left arm)
-- Other players: their states come from replicated attributes (CR_MoveState, CR_ChargeStart, CR_ShieldUp) - no new
-- remotes - and are applied after Disc.InterpPlayerSeconds, the delay their positions are drawn with.
-- Stun / death: every layer fades out (0.1 s) and the character is forgotten; a respawned character starts clean.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CoreRound = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))
local CoreGeom = require(CoreRound:WaitForChild("CoreGeom"))
local AnimData = require(script.Parent:WaitForChild("AnimData")) :: any

local Poses = {}

local player = Players.LocalPlayer
local deps = {
	localSlide = function(): boolean
		return false
	end,
	localWall = function(): Vector3?
		return nil
	end,
	charging = function(): (boolean, number)
		return false, 0
	end,
	shieldUp = function(): boolean
		return false
	end,
	reduced = function(): boolean
		return false
	end,
}

---------------------------------------------------------------------------------------------------- clip library
type Clip = {
	name: string,
	loop: boolean,
	frames: number,
	len: number,
	speed: number?,
	mask: { string }?,
	cf: { [string]: { CFrame } },
}
local FPS = AnimData.fps
local clips: { [string]: Clip } = {}
for name, c in AnimData.clips do
	local n = if c.loop then c.frames else c.frames + 1
	local cf: { [string]: { CFrame } } = {}
	for j, d in c.j do
		local arr = table.create(n)
		for i = 0, n - 1 do
			local b = i * 4
			local tx, ty, tz = 0, 0, 0
			if d.t then
				tx, ty, tz = d.t[i * 3 + 1], d.t[i * 3 + 2], d.t[i * 3 + 3]
			end
			arr[i + 1] = CFrame.new(tx, ty, tz, d.q[b + 2], d.q[b + 3], d.q[b + 4], d.q[b + 1])
		end
		cf[j] = arr
	end
	clips[name] = { name = name, loop = c.loop, frames = c.frames, len = c.frames / FPS, speed = c.speed, mask = c.mask, cf = cf }
end
Poses.Clips = clips

local function sample(clip: Clip, t: number, j: string): CFrame?
	local arr = clip.cf[j]
	if not arr then
		return nil
	end
	local f = t * FPS
	if clip.loop then
		f = f % clip.frames
		local i = math.floor(f)
		local nxt = (i + 1) % clip.frames
		return arr[i + 1]:Lerp(arr[nxt + 1], f - i)
	end
	f = math.clamp(f, 0, clip.frames)
	local i = math.min(math.floor(f), clip.frames - 1)
	return arr[i + 1]:Lerp(arr[i + 2], f - i)
end

local FULL = { "Root", "Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist", "RightHip", "RightKnee", "RightAnkle", "LeftHip", "LeftKnee", "LeftAnkle" }
local R = math.rad
local SLIDE_R6 = { RootJoint = CFrame.new(0, 0, -1.2) * CFrame.Angles(R(-38), 0, 0) } -- R6 fallback (axes differ)

---------------------------------------------------------------------------------------------------- per character
type Track = { clip: Clip, t: number, rate: number, w: number, target: number, fadeIn: number, fadeOut: number }
type State = {
	joints: { [string]: any },
	r6: boolean,
	-- slide (local os.clock times)
	slideOn: boolean,
	slideStart: number?,
	slideEnd: number?,
	-- base layer
	base: { Track },
	baseName: string?,
	airT: number, -- seconds airborne
	wasAir: boolean,
	landT: number,
	wallSide: number, -- +1 wall on the character's right, -1 left
	wallOn: boolean,
	landPending: boolean,
	moveYaw: number, -- lower-body turn toward the move direction (aim lock keeps the body facing the camera)
	backward: boolean,
	psjT: number,
	wjT: number,
	wjSide: number,
	wjLean: number, -- extra roll toward the launch direction (camera-aimed wall jump)
	wjMeasured: boolean,
	-- upper layer
	disc: Track?,
	discOn: boolean,
	shield: Track?,
	shieldOn: boolean,
	-- other players' replicated state
	lastState: string,
	seenState: string,
	seenAt: number,
	dead: boolean,
	dirty: boolean, -- joints added / removed (avatar parts replaced): rebuild the joint map
	spin: number, -- owner request: the right hand spins while the disc charges (radians)
	lastWallT: number, -- correction pass: last frame on a wall (wall-arm check keeps running briefly after)
	reachR: number, -- security gate pass: raised wall-reach arm weight, right / left (own layer, see below)
	reachL: number,
	wallOnT: number,
	discWallP: Vector3?, -- security gate pass: wall plane beside the raised right arm (held-disc orientation)
	discWallN: Vector3?,
	discWallT: number,
	reachT: number, -- wall-run clip time used for the reach arm before the wall-run base track exists
	ovT: number, -- correction pass: Power Slide Jump push-off overlay start (PSJ straight into a wall-run)
	pendKind: string?, -- others: a slide / wall-run just ended; watching for the launch (psj / wj)
	pendT: number,
	dashT: number, -- owner request: regular dash start (front / side / back clip by direction)
	dashDir: Vector3,
	lastFlat: number,
}
local states: { [Model]: State } = {}
local JOINT_CHILD = {
	Root = "LowerTorso", Waist = "UpperTorso", Neck = "Head",
	RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm", RightWrist = "RightHand",
	LeftShoulder = "LeftUpperArm", LeftElbow = "LeftLowerArm", LeftWrist = "LeftHand",
	RightHip = "RightUpperLeg", RightKnee = "RightLowerLeg", RightAnkle = "RightFoot",
	LeftHip = "LeftUpperLeg", LeftKnee = "LeftLowerLeg", LeftAnkle = "LeftFoot",
}

-- Step 1B finding (L-0050): newer avatar rigs use AnimationConstraint joints instead of Motor6D; both expose .Transform.
-- Step 1E finding: the joint objects are NOT stable for a character's life - the measured avatar's head (with its Neck
-- joint) is replaced after spawn while the appearance loads, and a cached reference kept posing the destroyed Neck (the
-- head never took the slide pose, in Step 1C/1D too). The map is rebuilt whenever a joint is added or removed, and each
-- joint is matched to the part it drives (a live AnimationConstraint wins over a Motor6D of the same name).
local function scanJoints(c: Model): { [string]: any }
	local joints: { [string]: any } = {}
	local rank: { [string]: number } = {}
	for _, d in c:GetDescendants() do
		local child = JOINT_CHILD[d.Name]
		if child then
			local r = 0
			if d:IsA("AnimationConstraint") and d.Enabled and d.Attachment1 and d.Attachment1.Parent and d.Attachment1.Parent.Name == child then
				r = 2
			elseif d:IsA("Motor6D") and d.Enabled and d.Part1 and d.Part1.Name == child then
				r = 1
			end
			if r > (rank[d.Name] or 0) then
				rank[d.Name] = r
				joints[d.Name] = d
			end
		elseif d:IsA("Motor6D") and d.Name == "RootJoint" then
			joints.RootJoint = d -- R6 fallback
		end
	end
	return joints
end

local function stateFor(c: Model): State
	local s = states[c]
	if s then
		return s
	end
	local joints = scanJoints(c)
	local hum = c:FindFirstChildOfClass("Humanoid")
	local ns: State = {
		joints = joints,
		r6 = hum ~= nil and hum.RigType == Enum.HumanoidRigType.R6,
		slideOn = false,
		slideStart = nil,
		slideEnd = nil,
		base = {},
		baseName = nil,
		airT = 0,
		wasAir = false,
		landT = -10,
		landPending = false,
		moveYaw = 0,
		backward = false,
		wallSide = 1,
		wallOn = false,
		psjT = -10,
		wjT = -10,
		wjSide = 1,
		wjLean = 0,
		wjMeasured = true,
		disc = nil,
		discOn = false,
		shield = nil,
		shieldOn = false,
		lastState = "run",
		seenState = "run",
		seenAt = 0,
		dead = false,
		dirty = false,
		spin = 0,
		lastWallT = -10,
		reachR = 0,
		reachL = 0,
		reachT = 0,
		wallOnT = -10,
		discWallP = nil,
		discWallN = nil,
		discWallT = -10,
		ovT = -10,
		pendKind = nil,
		pendT = 0,
		dashT = -10,
		dashDir = Vector3.new(0, 0, -1),
		lastFlat = 0,
	}
	states[c] = ns
	c.Destroying:Connect(function()
		states[c] = nil
	end)
	local function touched(d: Instance)
		if d:IsA("AnimationConstraint") or d:IsA("Motor6D") or d:IsA("Attachment") then
			ns.dirty = true
		end
	end
	c.DescendantAdded:Connect(touched)
	c.DescendantRemoving:Connect(touched)
	if hum then
		hum.Died:Connect(function()
			ns.dead = true -- stop writing at once: the death / ragdoll belongs to Roblox
		end)
	end
	return ns
end

local function slideBlend(): number
	return math.max(0.02, CoreConfig.Tune("Slide", "PoseBlendSeconds"))
end

local function slideWeight(s: State, now: number): number
	return CoreGeom.SlideWeight(s.slideStart, s.slideEnd, now, slideBlend())
end

local function setSlide(s: State, on: boolean, at: number)
	if on == s.slideOn then
		return
	end
	if on then
		local cur = slideWeight(s, at) -- a quick re-slide continues from the current weight (same rule as the server)
		s.slideStart = at - cur * slideBlend()
		s.slideEnd = nil
	else
		s.slideEnd = at
	end
	s.slideOn = on
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function wallSideOf(c: Model, hrp: BasePart, reach: number): number?
	params.FilterDescendantsInstances = { c }
	local right = hrp.CFrame.RightVector
	local r = workspace:Raycast(hrp.Position, right * reach, params)
	local l = workspace:Raycast(hrp.Position, -right * reach, params)
	if r and (not l or r.Distance <= l.Distance) then
		return 1
	elseif l then
		return -1
	end
	return nil
end

local function grounded(c: Model, hrp: BasePart, hum: Humanoid?): RaycastResult?
	params.FilterDescendantsInstances = { c }
	local reach = (if hum then hum.HipHeight else 2) + hrp.Size.Y / 2 + 0.6
	return workspace:Raycast(hrp.Position, Vector3.new(0, -reach, 0), params)
end

---------------------------------------------------------------------------------------------------- foot contact
-- Step 1E correction pass (owner): while the run blends into / out of the slide (CoreGeom.SlideWeight, 0.22 s) the
-- joint-space blend of two poses whose feet are each on the floor can put a foot BELOW the floor (measured up to
-- 0.64 studs on the canonical avatar, 0.33 on a stock R15). After the final pose is composed, each grounded foot is
-- checked against the floor under the root using THIS rig's own joint attachments and foot size; a foot below the
-- floor is lifted by a 2-bone leg IK (hip + knee, bend plane kept, foot keeps its world orientation). Only the legs
-- change: the root, pelvis translation and the head (server-aligned) are untouched; nothing changes when no foot
-- is below the floor, so there is no jitter in normal play.
local function jointC(j: any): (CFrame, CFrame)
	if j:IsA("Motor6D") then
		return j.C0, j.C1
	end
	return j.Attachment0.CFrame, j.Attachment1.CFrame
end

local function rotBetween(a: Vector3, b: Vector3): CFrame
	local au, bu = a.Unit, b.Unit
	local cr = au:Cross(bu)
	local sn = cr.Magnitude
	if sn < 1e-6 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(cr / sn, math.atan2(sn, au:Dot(bu)))
end

local FOOT_CORNERS = {}
for _, x in { -0.5, 0.5 } do
	for _, y in { -0.5, 0.5 } do
		for _, z in { -0.5, 0.5 } do
			table.insert(FOOT_CORNERS, Vector3.new(x, y, z))
		end
	end
end

Poses.FootFix = { frames = 0, lifts = 0, maxLift = 0 } -- test hook
Poses.WallFix = { frames = 0, fixes = 0, residual = 0 } -- test hook
local DISC_RIM_REF: { Vector3 } = {} -- filled below (held-disc envelope, see reachContact)

-- Step 1E correction pass (owner): wall-side arm vs the real wall plane, per rig. The authored wall-run brace keeps the
-- canonical avatar's arm within ~0.06 of the wall, but a rig whose shoulders / arms sit further out (stock R15: hand
-- up to 1.5 studs inside the wall) needs more. The wall-side arm (shoulder, elbow, hand boxes from THIS rig's joints)
-- is tested against the wall the root is running on; if it is inside, the arm is rotated about the shoulder pivot -
-- first spun about the character's forward axis, then swung about the vertical - by bisection until it only touches
-- the wall. Torso, head, legs and the wall-run physics are untouched.
local function wallArmFix(c: Model, joints: { [string]: any }, hrpCF: CFrame, wp: Vector3, wn: Vector3, side: number, work: { [string]: CFrame }, holdingDisc: boolean?)
	local n = if side > 0 then "Right" else "Left"
	local rj, wj, sj, ej, hj = joints.Root, joints.Waist, joints[n .. "Shoulder"], joints[n .. "Elbow"], joints[n .. "Wrist"]
	local ua, la, hand = c:FindFirstChild(n .. "UpperArm") :: BasePart?, c:FindFirstChild(n .. "LowerArm") :: BasePart?, c:FindFirstChild(n .. "Hand") :: BasePart?
	if not (rj and wj and sj and ej and hj and ua and la and hand and work.Root and work.Waist) then
		return
	end
	local ts, te, tw = work[n .. "Shoulder"], work[n .. "Elbow"], work[n .. "Wrist"]
	if not (ts and te and tw) then
		return
	end
	local r0, r1 = jointC(rj)
	local w0, w1 = jointC(wj)
	local s0, s1 = jointC(sj)
	local e0, e1 = jointC(ej)
	local h0, h1 = jointC(hj)
	local lt = hrpCF * r0 * work.Root * r1:Inverse()
	local ut = lt * w0 * work.Waist * w1:Inverse()
	local fs = ut * s0
	local function pen(tsx: CFrame): number
		local u = fs * tsx * s1:Inverse()
		local l = u * e0 * te * e1:Inverse()
		local hd = l * h0 * tw * h1:Inverse()
		local worst = -math.huge
		for _, pr in { { u, ua.Size }, { l, la.Size }, { hd, hand.Size } } do
			local cf, sz = pr[1], pr[2]
			for _, k in FOOT_CORNERS do
				worst = math.max(worst, -((cf * Vector3.new(k.X * sz.X, k.Y * sz.Y, k.Z * sz.Z)) - wp):Dot(wn))
			end
		end
		if holdingDisc then
			for _, k in DISC_RIM_REF do
				worst = math.max(worst, -((hd * k) - wp):Dot(wn))
			end
		end
		return worst
	end
	Poses.WallFix.frames += 1
	if pen(ts) <= 0.03 then
		return
	end
	local fsR = fs.Rotation
	local function rotated(axis: Vector3, ang: number, base: CFrame): CFrame
		return (fsR:Inverse() * CFrame.fromAxisAngle(axis, ang) * fsR) * base
	end
	local best = ts
	for _, axis in { hrpCF.LookVector, Vector3.yAxis } do
		-- security gate pass: try BOTH directions (the +/-0.3 probe alone picked the wrong way at a flush take-off) and
		-- keep the smallest angle that clears; if neither clears, the best sampled angle, then the next axis
		local clearA: number? = nil
		local bestA, bestP = 0, pen(best)
		for _, sgn in { 1, -1 } do
			-- first clear sample along this direction, refined by bisection
			local prev = 0
			for i = 1, 12 do
				local ang = sgn * math.pi * i / 12
				local pv = pen(rotated(axis, ang, best))
				if pv < bestP then
					bestA, bestP = ang, pv
				end
				if pv <= 0.02 then
					local lo, hi = prev, ang
					for _ = 1, 6 do
						local mid = (lo + hi) / 2
						if pen(rotated(axis, mid, best)) > 0.02 then
							lo = mid
						else
							hi = mid
						end
					end
					if not clearA or math.abs(hi) < math.abs(clearA) then
						clearA = hi
					end
					break
				end
				prev = ang
			end
		end
		if clearA then
			best = rotated(axis, clearA, best)
			break
		end
		best = rotated(axis, bestA, best)
	end
	work[n .. "Shoulder"] = best
	Poses.WallFix.fixes += 1
	Poses.WallFix.residual = math.max(Poses.WallFix.residual, pen(best))
	Poses.WallFix.last = string.format("%.2f->%.2f", pen(ts), pen(best))
end

-- Security gate pass (owner direction): the wall-run arm is RAISED and reaches the wall; only the hand (and the feet)
-- touch it. The authored pose (cr_wall_reach_search.py) puts the canonical avatar's hand on a wall 0.9 from the root;
-- the real wall distance and other rigs' shoulders / arm lengths differ, so the raised arm is swung about the
-- character's FORWARD axis through the shoulder (sideways toward / away from the wall - it is never lowered) until
-- the hand just presses the real wall plane (0.02), the upper / lower arm stay out of it (<= 0.02) and, while this
-- arm holds a charging disc, the 2.2-stud spinning disc stays clear of the wall (the hand then hovers just off the
-- wall: a palm flat on the wall cannot also hold the disc). If the swing brings the arm against the head, it is also
-- carried forward (about the character's right axis) until clear. Bounded: +/- 0.7 rad sideways, 0.8 rad forward.
Poses.ReachFix = { frames = 0, handGap = 0, armPen = -1, discPen = -1, headFix = 0 } -- test hook (worst values)
-- held disc (DiscClient: 2.2-stud disc at hand * (0, -0.9, -0.4), spinning with the hand about the forearm): tested
-- as its spin-invariant envelope - a ring of radius 1.1 + 0.4 around the hand axis - so the result does not jitter
-- with the spin phase
local DISC_RIM = {}
for i = 0, 11 do
	local a = i / 12 * 2 * math.pi
	table.insert(DISC_RIM, Vector3.new(math.cos(a) * 1.5, -0.9, math.sin(a) * 1.5))
end
for _, v in DISC_RIM do
	table.insert(DISC_RIM_REF, v)
end
local function reachContact(c: Model, joints: { [string]: any }, hrpCF: CFrame, wp: Vector3, wn: Vector3, side: number, work: { [string]: CFrame }, holdingDisc: boolean): boolean
	local n = if side > 0 then "Right" else "Left"
	local rj, wj, nj, sj, ej, hj = joints.Root, joints.Waist, joints.Neck, joints[n .. "Shoulder"], joints[n .. "Elbow"], joints[n .. "Wrist"]
	local ua, la, hand, head = c:FindFirstChild(n .. "UpperArm") :: BasePart?, c:FindFirstChild(n .. "LowerArm") :: BasePart?, c:FindFirstChild(n .. "Hand") :: BasePart?, c:FindFirstChild("Head") :: BasePart?
	if not (rj and wj and sj and ej and hj and ua and la and hand and work.Root and work.Waist) then
		return true
	end
	local ts, te, tw = work[n .. "Shoulder"], work[n .. "Elbow"], work[n .. "Wrist"]
	if not (ts and te and tw) then
		return true
	end
	local r0, r1 = jointC(rj)
	local w0, w1 = jointC(wj)
	local s0, s1 = jointC(sj)
	local e0, e1 = jointC(ej)
	local h0, h1 = jointC(hj)
	local lt = hrpCF * r0 * work.Root * r1:Inverse()
	local ut = lt * w0 * work.Waist * w1:Inverse()
	local fs = ut * s0
	local headC: Vector3? = nil
	if nj and head and work.Neck then
		local n0, n1 = jointC(nj)
		headC = (ut * n0 * work.Neck * n1:Inverse()).Position
	end
	local headR = if head then math.max(head.Size.X, head.Size.Z) * 0.5 else 0.5
	local function boxPen(cf: CFrame, sz: Vector3): number
		local worst = -math.huge
		for _, k in FOOT_CORNERS do
			worst = math.max(worst, -((cf * Vector3.new(k.X * sz.X, k.Y * sz.Y, k.Z * sz.Z)) - wp):Dot(wn))
		end
		return worst
	end
	-- arm, hand, disc penetration and head clearance for a shoulder transform
	local function eval(tsx: CFrame): (number, number, number, number)
		local u = fs * tsx * s1:Inverse()
		local l = u * e0 * te * e1:Inverse()
		local hd = l * h0 * tw * h1:Inverse()
		-- the forearm's wrist end sits where the hand meets the wall (same rule as the Blender authoring QA): only its
		-- elbow half must stay off the wall; the wrist half may reach the hand's press depth
		local elbowEnd = if e1.Position.Y >= 0 then 1 else -1
		local lsz = la.Size
		local lowerP = -math.huge
		for _, k in FOOT_CORNERS do
			local d = -((l * Vector3.new(k.X * lsz.X, k.Y * lsz.Y, k.Z * lsz.Z)) - wp):Dot(wn)
			lowerP = math.max(lowerP, if k.Y * elbowEnd > 0 then d else d - 0.06)
		end
		local armP = math.max(boxPen(u, ua.Size), lowerP)
		-- the hand as a cylinder about the forearm axis: the charge spin turns the hand about that axis every frame,
		-- and a box test would make the contact angle (and so the arm) follow the spin phase
		local hs = hand.Size
		local handP = -((hd.Position - wp):Dot(wn)) + 0.5 * math.max(hs.X, hs.Z) + 0.5 * hs.Y * math.abs(hd.UpVector:Dot(wn))
		local discP = -math.huge -- the held disc is kept off the wall by DiscClient (edge-on, Poses.DiscWall)
		local clash = -math.huge
		if headC then
			-- upper / lower arm centre lines vs the head (capsule test: radii = half widths)
			for _, pr in { { u, ua.Size }, { l, la.Size } } do
				local cf, sz = pr[1] :: CFrame, pr[2] :: Vector3
				local half = math.max(0, sz.Y * 0.5 - sz.X * 0.4)
				local a, b = cf.Position + cf.UpVector * half, cf.Position - cf.UpVector * half
				local ab = b - a
				local k = math.clamp((headC - a):Dot(ab) / math.max(1e-6, ab:Dot(ab)), 0, 1)
				clash = math.max(clash, headR + ua.Size.X * 0.45 - (a + ab * k - headC).Magnitude)
			end
		end
		return armP, handP, discP, clash
	end
	local fsR = fs.Rotation
	local function rot(axis: Vector3, ang: number, base: CFrame): CFrame
		return (fsR:Inverse() * CFrame.fromAxisAngle(axis, ang) * fsR) * base
	end
	-- sideways axis = the horizontal direction ALONG the wall (positive angle moves the raised hand toward the wall); the
	-- character's own forward axis is not used: a Power Slide Jump meets the wall with the body still turned into it
	local alongW = wn:Cross(Vector3.yAxis)
	if alongW.Magnitude < 0.1 then
		alongW = hrpCF.LookVector
	end
	local fwdAxis = alongW.Unit
	local function towardWall(a: number): CFrame
		return rot(fwdAxis, a, ts)
	end
	local probe = select(2, eval(towardWall(0.1))) - select(2, eval(towardWall(-0.1)))
	if probe < 0 then
		fwdAxis = -fwdAxis
	end
	Poses.ReachFix.frames += 1
	-- 1. contact: hand press 0.02 (or disc clear by 0.03), by bisection on the sideways angle
		local function goal(a: number): number
		local _, handP = eval(towardWall(a))
		-- the hand presses the wall - also while holding the charging disc: DiscClient turns that disc edge-on to the
		-- wall and keeps it 0.3 off it (Poses.DiscWall), so the arm keeps the same stable pose. While the hand spins
		-- (charging) its box corners sweep 0.1 beyond the cylinder used here, so it is held 0.06 off instead
		return if holdingDisc then handP + 0.06 else handP - 0.02
	end
	local lo, hi = -0.7, 0.7
	local a = 0
	if goal(lo) > 0 then
		a = lo
	elseif goal(hi) < 0 then
		a = hi
	else
		for _ = 1, 12 do
			local mid = (lo + hi) / 2
			if goal(mid) > 0 then
				hi = mid
			else
				lo = mid
			end
		end
		a = (lo + hi) / 2
	end
	-- 2. the upper / lower arm must not be pushed into the wall to reach it. Rotating about the shoulder moves parts of
	-- the arm on either side of the pivot in opposite directions (not monotonic), so scan from the contact angle
	-- away from the wall and take the FIRST clear angle (the hand stays as close to the wall as the arm allows)
	if eval(towardWall(a)) > 0.02 then
		local found, bestA, bestP = false, a, math.huge
		local x = a
		while x > -0.7 - 1e-6 do
			local pv = eval(towardWall(x))
			if pv <= 0.02 then
				found, bestA = true, x
				break
			end
			if pv < bestP then
				bestA, bestP = x, pv
			end
			x -= 0.04
		end
		if not found and bestP > 0.06 then
			-- nothing near-clear sideways: take the least-penetrating and also swing it forward / back about the
			-- character's right axis
			local base = towardWall(bestA)
			local rv = wn
			local b2, p2 = base, bestP
			for i = -8, 8 do
				local cand = rot(rv, i * 0.1, base)
				local pv = eval(cand)
				if pv < p2 then
					b2, p2 = cand, pv
				end
			end
			ts = b2
			bestA = 0
			Poses.ReachFix.headFix += 0
		end
		a = bestA
	end
	local best = towardWall(a)
	-- 3. head clearance: carry the arm forward only when the sideways swing brought it closer to the head than the
	-- authored pose already is (the capsule test is approximate; the authored pose is the reference)
	local _, _, _, clash = eval(best)
	local allowed = math.max(0.02, select(4, eval(ts)))
	if clash > allowed + 0.03 then
		local rv = wn
		local sgn = if select(4, eval(rot(rv, -0.2, best))) < select(4, eval(rot(rv, 0.2, best))) then -1 else 1
		local l3, h3 = 0, 0.8
		for _ = 1, 8 do
			local mid = (l3 + h3) / 2
			if select(4, eval(rot(rv, sgn * mid, best))) > allowed then
				l3 = mid
			else
				h3 = mid
			end
		end
		best = rot(rv, sgn * h3, best)
		Poses.ReachFix.headFix += 1
	end
	work[n .. "Shoulder"] = best
	local armP, handP, discP = eval(best)
	if armP > 0.06 then
		-- the bounded raise-and-contact swing cannot clear this pose (e.g. the first frames of a Power Slide Jump into a
		-- wall-run, while the slide torso is still easing out): the caller falls back to the general clear-only fix
		return false
	end
	Poses.ReachFix.armPen = math.max(Poses.ReachFix.armPen, armP)
	Poses.ReachFix.handGap = math.max(Poses.ReachFix.handGap, math.abs(handP - (if holdingDisc then -0.06 else 0.02)))
	return true
end

local function fixFeet(c: Model, joints: { [string]: any }, hrpCF: CFrame, floor: RaycastResult, work: { [string]: CFrame })
	local rj = joints.Root
	if not rj or not work.Root then
		return
	end
	local r0, r1 = jointC(rj)
	local lt = hrpCF * r0 * work.Root * r1:Inverse()
	local fp, fn = floor.Position, floor.Normal
	for pass = 1, 4 do -- two passes per leg: the ankle lift re-swings the thigh, so the thigh check runs again
	local side = if pass % 2 == 1 then "Right" else "Left"
	do
		local hj, kj, aj = joints[side .. "Hip"], joints[side .. "Knee"], joints[side .. "Ankle"]
		local foot = c:FindFirstChild(side .. "Foot") :: BasePart?
		local th, tk, ta = work[side .. "Hip"], work[side .. "Knee"], work[side .. "Ankle"]
		if hj and kj and aj and foot and th and tk and ta then
			local h0, h1 = jointC(hj)
			local k0, k1 = jointC(kj)
			local a0, a1 = jointC(aj)
			local fh = lt * h0
			-- thigh / shin below the floor (e.g. the slide's folded rear leg on a rig with a lower hip height than the
			-- authoring rig): swing the thigh about the hip (bisection) until the leg rests on the floor; the knee bend
			-- is kept. The ankle lift below then handles the foot.
			local ulPart = c:FindFirstChild(side .. "UpperLeg") :: BasePart?
			local llPart = c:FindFirstChild(side .. "LowerLeg") :: BasePart?
			if ulPart and llPart then
				local function legPen(thx: CFrame): number
					local u = fh * thx * h1:Inverse()
					local l = u * k0 * tk * k1:Inverse()
					local worst = -math.huge
					for _, pr in { { u, ulPart.Size }, { l, llPart.Size } } do
						local cf, sz2 = pr[1], pr[2]
						for _, k in FOOT_CORNERS do
							local corner = cf * Vector3.new(k.X * sz2.X, k.Y * sz2.Y, k.Z * sz2.Z)
							worst = math.max(worst, -(corner - fp):Dot(fn))
						end
					end
					return worst
				end
				local p0 = legPen(th)
				if p0 > 0.01 then
					local sgn = if legPen(CFrame.Angles(0.2, 0, 0) * th) < legPen(CFrame.Angles(-0.2, 0, 0) * th) then 1 else -1
					local lo, hi = 0, 1.2
					if legPen(CFrame.Angles(sgn * hi, 0, 0) * th) > 0.005 then
						lo = hi
					else
						for _ = 1, 7 do
							local mid = (lo + hi) / 2
							if legPen(CFrame.Angles(sgn * mid, 0, 0) * th) > 0.005 then
								lo = mid
							else
								hi = mid
							end
						end
						lo = hi
					end
					th = CFrame.Angles(sgn * lo, 0, 0) * th
					work[side .. "Hip"] = th
				end
			end
			local ul = fh * th * h1:Inverse()
			local fk = ul * k0
			local ll = fk * tk * k1:Inverse()
			local fa = ll * a0
			local ft = fa * ta * a1:Inverse()
			local sz = foot.Size
			local low = math.huge
			for _, k in FOOT_CORNERS do
				local corner = ft * Vector3.new(k.X * sz.X, k.Y * sz.Y, k.Z * sz.Z)
				low = math.min(low, (corner - fp):Dot(fn))
			end
			-- the shin's lower (ankle-end) corners too: lifting the ankle lifts them as well
			local shin = c:FindFirstChild(side .. "LowerLeg") :: BasePart?
			if shin then
				local ss = shin.Size
				for _, k in FOOT_CORNERS do
					if k.Y < 0 then
						local corner = ll * Vector3.new(k.X * ss.X, k.Y * ss.Y, k.Z * ss.Z)
						low = math.min(low, (corner - fp):Dot(fn))
					end
				end
			end
			local lift = -low
			if lift > 0.005 then
				lift = math.min(lift, 1.2)
				local hp, kp, ap = fh.Position, fk.Position, fa.Position
				local L1, L2 = (kp - hp).Magnitude, (ap - kp).Magnitude
				local want = ap + Vector3.yAxis * (lift / math.max(0.5, fn.Y))
				local ht = want - hp
				local d = math.clamp(ht.Magnitude, math.abs(L1 - L2) + 1e-3, L1 + L2 - 1e-3)
				local u = ht.Unit
				local axis = (ap - hp):Cross(kp - hp)
				axis = if axis.Magnitude < 1e-4 then lt.RightVector else axis.Unit
				local w = axis:Cross(u).Unit
				if w:Dot(kp - hp) < 0 then
					w = -w
				end
				local cosA = math.clamp((L1 * L1 + d * d - L2 * L2) / (2 * L1 * d), -1, 1)
				local kNew = hp + u * (L1 * cosA) + w * (L1 * math.sqrt(1 - cosA * cosA))
				local rot1 = rotBetween(kp - hp, kNew - hp)
				local aAfter = hp + rot1:VectorToWorldSpace(ap - hp)
				local rot2 = rotBetween(aAfter - kNew, (hp + u * d) - kNew)
				local fhR = fh.Rotation
				work[side .. "Hip"] = (fhR:Inverse() * rot1 * fhR) * th
				local fkR = rot1 * fk.Rotation
				work[side .. "Knee"] = (fkR:Inverse() * rot2 * fkR) * tk
				local faR = fa.Rotation
				work[side .. "Ankle"] = (faR:Inverse() * (rot2 * rot1):Inverse() * faR) * ta
				Poses.FootFix.lifts += 1
				Poses.FootFix.maxLift = math.max(Poses.FootFix.maxLift, lift)
			end
		end
	end
	end
	Poses.FootFix.frames += 1
end

-- start (or keep) the base clip `name`; every other base track fades out
local FADE = {
	run = 0.15, fall = 0.2, land = 0.05, psj_push = 0.04, psj_rise = 0.08, psj_apex = 0.1,
	wallrun_r = 0.12, wallrun_l = 0.12, walljump_r = 0.04, walljump_l = 0.04, walljump_recover_r = 0.06, walljump_recover_l = 0.06,
}
local function want(s: State, name: string?, rate: number, weight: number)
	if name ~= s.baseName then
		s.baseName = name
		if name then
			local clip = clips[name]
			-- the run keeps its phase when it comes back within a moment (no stride restart)
			local t = 0
			for _, tr in s.base do
				if tr.clip == clip then
					t = tr.t
				end
			end
			table.insert(s.base, { clip = clip, t = t, rate = rate, w = 0, target = weight, fadeIn = FADE[name] or 0.1, fadeOut = 0.12 })
		end
		for i, tr in s.base do
			if i < #s.base or not name then
				tr.target = 0
			end
		end
	end
	local top = s.base[#s.base]
	if name and top then
		top.rate = rate
		top.target = weight
	end
end

local function stepTrack(tr: Track, dt: number)
	tr.t += dt * tr.rate
	if tr.w < tr.target then
		tr.w = math.min(tr.target, tr.w + dt / math.max(0.01, tr.fadeIn))
	elseif tr.w > tr.target then
		tr.w = math.max(tr.target, tr.w - dt / math.max(0.01, tr.fadeOut))
	end
end

---------------------------------------------------------------------------------------------------- frame update
local work: { [string]: CFrame } = {}

local function drawCharacter(c: Model, s: State, hrp: BasePart, hum: Humanoid?, mine: boolean, now: number, dt: number, delay: number)
	-- 1. inputs: this client's own state is local and immediate; others' come from replicated attributes, applied
	--    after the same delay their positions are drawn with
	local st = c:GetAttribute("CR_MoveState")
	local stateNow = if typeof(st) == "string" then st else "run"
	local sliding: boolean, wallSide: number? = false, nil
	local vel = hrp.AssemblyLinearVelocity
	local charging, chargeK, shieldUp = false, 0, false
	if mine then
		sliding = deps.localSlide()
		local n = deps.localWall()
		if n then
			-- security gate pass: the side of the wall relative to the direction of TRAVEL along it (the wall-run turns
			-- the body to that direction within a few frames); the body's own right vector alone picked the wrong side
			-- for ~0.1 s when a Power Slide Jump met the wall at an angle (body still facing partly into it)
			local along = vel - n * vel:Dot(n)
			along = Vector3.new(along.X, 0, along.Z)
			local right = if along.Magnitude > 8 then along.Unit:Cross(Vector3.yAxis) else hrp.CFrame.RightVector
			wallSide = if n:Dot(right) < 0 then 1 else -1
		end
		local on, k = deps.charging()
		charging, chargeK = on, k or 0
		shieldUp = deps.shieldUp()
	else
		if stateNow ~= s.seenState then
			s.seenState = stateNow
			s.seenAt = now
		end
		local applied = if now - s.seenAt >= delay then s.seenState else s.lastState
		if applied ~= s.lastState then
			-- a slide that ends while rising fast is a Power Slide Jump; leaving a wall-run while rising is a wall jump.
			-- Acceptance two-client finding: the replicated state change arrives ~0.2 s BEFORE the launch velocity, so
			-- the check stays open for 0.35 s after the change instead of testing only that instant.
			if s.lastState == "slide" and applied == "run" then
				s.pendKind, s.pendT = "psj", now
			elseif s.lastState == "slide" and applied == "wallrun" then
				-- correction pass: a Power Slide Jump straight into a wall-run replicates as slide -> wallrun with no run in
				-- between; show the push-off as a short overlay on the wall-run (no delay to the wall-run itself)
				s.ovT = now
			elseif s.lastState == "wallrun" and applied == "run" then
				s.pendKind, s.pendT = "wj", now
				s.wjSide = s.wallSide
			end
			s.lastState = applied
		end
		if s.pendKind then
			if s.pendKind == "psj" and applied == "wallrun" and now - s.pendT <= 0.35 then
				-- acceptance finding: a Power Slide Jump into a wall-run can replicate as slide -> run (a few frames) ->
				-- wallrun before the launch speed arrives: show the push-off overlay on the wall-run
				s.ovT = now
				s.pendKind = nil
			elseif now - s.pendT > 0.35 or applied ~= "run" then
				s.pendKind = nil
			elseif s.pendKind == "psj" and vel.Y > CoreConfig.Tune("Slide", "PowerJumpUp") * 0.6 then
				s.psjT = now
				s.pendKind = nil
			elseif s.pendKind == "wj" and vel.Y > 8 then
				s.wjT = now
				s.wjMeasured = false
				s.pendKind = nil
			end
		end
		sliding = applied == "slide"
		if applied == "wallrun" then
			-- correction pass (two-client finding): when a chained jump reaches the next wall, the replicated state says
			-- "wallrun" before the drawn position is within the 4-stud side ray, and the old side was kept (~0.12 s
			-- wrong-side flash). While the character still moves sideways fast (it is crossing to the new wall) the
			-- side is the direction of that sideways motion; otherwise the nearest ray hit; otherwise the last side.
			-- the side ray first; only when it finds no wall on either side (the drawn position has not reached the
			-- new wall yet) does the sideways motion decide (acceptance finding: using motion first picked the wrong
			-- side at wall-run ENTRY)
			-- final gate two-client finding: at ENTRY the state can arrive while the drawn body is still more than 4 studs
			-- from the wall; keeping the last side then started the OTHER side's pose (left-wall run, then right-wall run:
			-- the body leaned ~1 stud into the wall for ~0.1 s on the watching client). At entry look further (8 studs),
			-- and if no wall is found yet, wait (the pose starts when the wall is found) instead of guessing the side.
			local ray = wallSideOf(c, hrp, 4) or (if s.wallOn then nil else wallSideOf(c, hrp, 8))
			local lat = hrp.CFrame.RightVector:Dot(Vector3.new(vel.X, 0, vel.Z))
			if ray then
				wallSide = ray
			elseif math.abs(lat) > 12 then
				wallSide = if lat > 0 then 1 else -1
			elseif s.wallOn then
				wallSide = s.wallSide
			end
		end
		local cs = c:GetAttribute("CR_ChargeStart")
		if typeof(cs) == "number" then
			local tune = function(k: string): number
				return CoreConfig.Tune("Disc", k)
			end
			charging = true
			chargeK = math.clamp((workspace:GetServerTimeNow() - cs - tune("TapSeconds")) / math.max(0.05, tune("ChargeSeconds")), 0, 1)
		end
		shieldUp = c:GetAttribute("CR_ShieldUp") == true
	end
	local stunUntil = (c:GetAttribute("CR_StunUntil") :: number?) or 0
	local stunned = workspace:GetServerTimeNow() < stunUntil
	local off = s.dead or stunned or (hum ~= nil and hum.Health <= 0)
	setSlide(s, sliding and not off, now)
	if wallSide then
		s.wallSide = wallSide
		if s.psjT > 0 and now - s.psjT < 0.25 and s.ovT < s.psjT then
			s.ovT = s.psjT -- this client's own PSJ that reaches a wall: finish the push-off as an overlay (correction pass)
		end
		s.psjT = -10 -- a wall-run ends the Power Slide Jump sequence (the next jump is a wall jump)
	end
	if wallSide and not s.wallOn then
		s.wallOnT = now -- security gate pass: wall-run attach time (entry prediction below)
	end
	s.wallOn = wallSide ~= nil

	-- 2. base layer: pick the clip
	local flat = Vector3.new(vel.X, 0, vel.Z).Magnitude
	-- other players' regular dash: only a dash moves at ~104 studs/s (Move.DashDistance / DashSeconds; Super Dash 70,
	-- slide <= 58, wall-run <= 60), so a jump past 85 starts the dash clip in the direction they are moving
	if not mine and flat > 85 and s.lastFlat <= 85 and now - s.dashT > 0.3 then
		s.dashT = now
		s.dashDir = Vector3.new(vel.X, 0, vel.Z).Unit
	end
	s.lastFlat = flat
	local floorHit = grounded(c, hrp, hum)
	local air = floorHit == nil
	s.airT = if air then s.airT + dt else 0
	if s.wasAir and not air then
		local fellFast = vel.Y < 1
		if fellFast and (now - s.psjT > 0.25) and (now - s.wjT > 0.15) and s.landPending then
			s.landT = now
		end
	end
	if air and s.airT > 0.35 then
		s.landPending = true
	elseif not air then
		s.landPending = false
	end
	s.wasAir = air
	if not air and now - s.psjT > 0.3 then
		s.psjT = -10 -- Power Slide Jump sequence ends on landing
	end
	if not air and now - s.wjT > 0.3 then
		s.wjT = -10
	end
	-- camera-aimed wall jump: lean into the launch direction (measured once the launch has been applied)
	if not s.wjMeasured and now - s.wjT > 0.04 then
		s.wjMeasured = true
		local side = hrp.CFrame.RightVector:Dot(Vector3.new(vel.X, 0, vel.Z))
		s.wjLean = math.clamp(side / 50, -1, 1) * R(14)
	end
	local rateRun = math.clamp(flat / 36, 0.45, 1.8)
	-- directional run: with aim lock the body faces the camera, so the character often strafes or backpedals. The legs
	-- turn toward the move direction (up to 65 deg, chest and head counter-turn to stay on the aim) and a backpedal
	-- plays the cycle in reverse, so planted feet still travel with the ground.
	local yawTarget = 0
	if flat > 3 then
		local d = hrp.CFrame:VectorToObjectSpace(Vector3.new(vel.X, 0, vel.Z))
		local heading = math.atan2(d.X, -d.Z) -- 0 forward, + to the right
		local back = math.abs(heading) > R(110)
		if back ~= s.backward and math.abs(math.abs(heading) - R(110)) > R(10) then
			s.backward = back
		end
		local rel = if s.backward then heading - math.sign(heading) * math.pi else heading
		yawTarget = -math.clamp(rel, -R(65), R(65))
	end
	s.moveYaw += (yawTarget - s.moveYaw) * math.min(1, dt * 12)
	if s.backward then
		rateRun = -rateRun
	end
	local pa, wa = now - s.psjT, now - s.wjT
	local push, rise, apex = clips.psj_push, clips.psj_rise, clips.psj_apex
	if off then
		want(s, nil, 1, 0)
	elseif s.wallOn then
		want(s, if s.wallSide > 0 then "wallrun_r" else "wallrun_l", rateRun, 1)
	elseif pa >= 0 and pa < 2.5 and air then
		if pa < push.len then
			want(s, "psj_push", 1, 1)
		elseif vel.Y > 12 and pa < 1.2 then
			want(s, "psj_rise", 1, 1)
		elseif s.baseName ~= "fall" and (s.baseName ~= "psj_apex" or s.base[#s.base].t < apex.len) then
			want(s, "psj_apex", 1, 1)
		else
			want(s, "fall", 1, 1)
		end
	elseif s.pendKind and air and s.baseName then
		-- others: a slide / wall-run just ended and the launch has not replicated yet (<= 0.35 s): hold the current
		-- clip instead of flashing the fall pose (acceptance two-client finding)
		want(s, s.baseName, if s.baseName == "run" then rateRun else 1, 1)
	elseif wa >= 0 and wa < 1.5 and air then
		local side = if s.wjSide > 0 then "_r" else "_l"
		if wa < clips["walljump" .. side].len then
			want(s, "walljump" .. side, 1, 1)
		elseif wa < clips["walljump" .. side].len + clips["walljump_recover" .. side].len then
			want(s, "walljump_recover" .. side, 1, 1)
		else
			want(s, "fall", 1, 1)
		end
	elseif air and (s.airT > 0.15 or vel.Y < -12) then
		want(s, "fall", 1, 1)
	elseif not air and now - s.landT < clips.land.len then
		-- landing recovery: full on a standing landing, light while running (never blocks: no root motion)
		want(s, "land", 1, if flat > 10 then 0.4 else 1)
	elseif not air and flat >= 6 then
		want(s, "run", rateRun, math.clamp((flat - 6) / 10, 0, 1))
	else
		want(s, nil, 1, 0)
	end
	for i = #s.base, 1, -1 do
		local tr = s.base[i]
		stepTrack(tr, dt)
		if tr.target == 0 and tr.w <= 0 then
			table.remove(s.base, i)
		end
	end

	-- 3. upper body tracks
	if charging and not off and not s.discOn then
		s.discOn = true
		s.disc = { clip = clips.disc_charge, t = 0, rate = 1, w = 0, target = 1, fadeIn = 0.06, fadeOut = 0.1 }
	elseif s.discOn and (not charging or off) then
		s.discOn = false
		if not off and not shieldUp and s.disc then
			-- released: the throw follow-through (the disc itself is already on its way - combat never waits)
			s.disc = { clip = clips.disc_release, t = 0, rate = 1, w = 1, target = 1, fadeIn = 0.01, fadeOut = 0.12 }
		elseif s.disc then
			s.disc.target = 0
		end
	end
	local disc = s.disc
	if disc then
		stepTrack(disc, dt)
		if disc.clip.name == "disc_release" and disc.t > disc.clip.len - 0.12 then
			disc.target = 0
		end
		if disc.target == 0 and disc.w <= 0 then
			s.disc = nil
		end
	end
	if shieldUp and not off and not s.shieldOn then
		s.shieldOn = true
		s.shield = { clip = clips.shield_raise, t = 0, rate = 1, w = 1, target = 1, fadeIn = 0.01, fadeOut = 0.08 }
	elseif s.shieldOn and (not shieldUp or off) then
		s.shieldOn = false
		s.shield = if off then nil else { clip = clips.shield_lower, t = 0, rate = 1, w = 1, target = 1, fadeIn = 0.01, fadeOut = 0.06 }
	end
	local sh = s.shield
	if sh then
		stepTrack(sh, dt)
		if sh.clip.name == "shield_raise" and sh.t >= sh.clip.len then
			sh.clip, sh.t = clips.shield_hold, 0
		elseif sh.clip.name == "shield_lower" and sh.t >= sh.clip.len then
			sh.target = 0
		end
		if sh.target == 0 and sh.w <= 0 then
			s.shield = nil
		end
	end

	-- 4. compose: one Transform write per joint
	if s.dirty then
		s.dirty = false
		s.joints = scanJoints(c)
	end
	if s.r6 then
		local sw = slideWeight(s, now)
		local j = s.joints.RootJoint
		if j and sw > 0.001 then
			j.Transform = j.Transform:Lerp(SLIDE_R6.RootJoint, sw)
		end
		return
	end
	local joints = s.joints
	for _, name in FULL do
		local j = joints[name]
		if j then
			work[name] = j.Transform
		end
	end
	for _, tr in s.base do
		if tr.w > 0.001 then
			for _, name in FULL do
				local cur = work[name]
				local cf = sample(tr.clip, tr.t, name)
				if cur and cf then
					work[name] = cur:Lerp(cf, tr.w)
				end
			end
		end
	end
	-- owner request: regular dash. One clip per direction relative to the body (front / side / back; side is mirrored
	-- left / right), blended by the dash heading so diagonals sit between two clips. Fades in over 0.04 s, out over
	-- the last 0.1 s of the 0.35 s burst + recovery. No root motion: the dash itself is the movement code's.
	local da = now - s.dashT
	if da >= 0 and da < 0.35 and not off and not s.wallOn then
		local dw = CoreGeom.Ease(da / 0.04) * (1 - CoreGeom.Ease((da - 0.25) / 0.1))
		local d = hrp.CFrame:VectorToObjectSpace(s.dashDir)
		local h = math.atan2(d.X, -d.Z) -- 0 front, + right
		local fb = math.cos(h)
		local side = math.sin(h)
		local a = if fb >= 0 then clips.dash_f else clips.dash_b
		local b = if side >= 0 then clips.dash_r else clips.dash_l
		local mix = math.abs(side) / (math.abs(side) + math.abs(fb) + 1e-6) -- 0 = pure front/back, 1 = pure side
		if dw > 0.001 then
			for _, name in FULL do
				local cur = work[name]
				local ca, cb = sample(a, da, name), sample(b, da, name)
				if cur and ca and cb then
					work[name] = cur:Lerp(ca:Lerp(cb, mix), dw)
				end
			end
		end
	end
	-- correction pass: PSJ push-off overlay into a wall-run (full for 0.08 s, gone by 0.25 s)
	local oa = now - s.ovT
	if oa >= 0 and oa < 0.25 and not off then
		local ow = if oa < 0.08 then 1 else 1 - CoreGeom.Ease((oa - 0.08) / 0.17)
		for _, name in FULL do
			local cur = work[name]
			local cf = sample(clips.psj_push, math.min(clips.psj_push.len, 0.05 + oa), name)
			if cur and cf then
				work[name] = cur:Lerp(cf, ow)
			end
		end
	end
	local reachPass: (boolean) -> () = function() end
	-- security gate pass (owner direction): the wall-side arm REACHES UP to the wall as its own layer. The full-body
	-- crossfade into the wall-run takes 0.12 s and another player's body reaches the wall on this screen before their
	-- replicated state says "wallrun" (correction-pass finding: a one-frame 1.45 hand-in-wall flash), so the arm rises
	-- over 0.07 s as soon as the body is airborne, moving along a wall and at / closing on it - normally before
	-- contact. It lowers over 0.15 s when the wall-run ends (the wall-jump clip carries the push-off).
	do
		local tR, tL = 0, 0
		if not off and not s.r6 and now - s.wjT > 0.3 then
			if s.wallOn then
				if s.wallSide > 0 then
					tR = 1
				else
					tL = 1
				end
			else
				-- airborne and at / closing on a wall, or still flush against the wall the run just ended on (landing
				-- beside it: the arm stays up until the body leaves the wall - any lowered arm would be inside it)
				params.FilterDescendantsInstances = { c }
				local rv = hrp.CFrame.RightVector
				local best, bs = nil, 1
				for _, sd in { 1, -1 } do
					local h = workspace:Raycast(hrp.Position, rv * (2.5 * sd), params)
					if h and math.abs(h.Normal.Y) < 0.3 and (not best or h.Distance < best.Distance) then
						best, bs = h, sd
					end
				end
				if best then
					local closing = -vel:Dot(best.Normal)
					local along = vel - best.Normal * vel:Dot(best.Normal)
					local alongS = Vector3.new(along.X, 0, along.Z).Magnitude
					local nearing = air and alongS > 12 and (best.Distance < 1.4 or (closing > 4 and best.Distance - 1.0 < closing * 0.12))
					local flush = air and now - s.lastWallT < 1.0 and best.Distance < 1.6 and alongS > 6
					if nearing or flush then
						if bs > 0 then
							tR = 1
						else
							tL = 1
						end
					end
				end
			end
		end
		local function step(w: number, t: number): number
			return if t > w then math.min(t, w + dt / 0.07) else math.max(t, w - dt / 0.15)
		end
		s.reachR, s.reachL = step(s.reachR, tR), step(s.reachL, tL)
		s.reachT += dt * math.clamp(flat / 36, 0.45, 1.8)
		reachPass = function(armOnly: boolean)
			for _, pr in { { s.reachR, "Right", clips.wallrun_r }, { s.reachL, "Left", clips.wallrun_l } } do
				local w, n, clip = pr[1] :: number, pr[2] :: string, pr[3] :: Clip
				if w > 0.001 and clip then
					local t = s.reachT
					for _, tr in s.base do
						if tr.clip == clip then
							t = tr.t
						end
					end
					local ew = CoreGeom.Ease(w)
					-- the raised arm only fits beside a wall on the wall-run torso (pelvis eased off the wall, chest turned to it):
					-- the torso comes with the arm, at the same rate, ahead of the 0.12 s full-body crossfade
					for _, j in (if armOnly then { n .. "Shoulder", n .. "Elbow", n .. "Wrist" } else { "Root", "Waist", "Neck", n .. "Shoulder", n .. "Elbow", n .. "Wrist" }) do
						local cur = work[j]
						local cf = sample(clip, t, j)
						if cur and cf then
							work[j] = cur:Lerp(cf, ew)
						end
					end
				end
			end
		end
		reachPass(false)
	end
	-- lower-body turn (weighted by the run's share of the base layer)
	local runW = 0
	for _, tr in s.base do
		if tr.clip.name == "run" then
			runW = math.max(runW, tr.w)
		end
	end
	if runW > 0.001 and math.abs(s.moveYaw) > 0.001 and work.Root and work.Waist and work.Neck then
		local y = s.moveYaw * runW
		work.Root = CFrame.Angles(0, y, 0) * work.Root
		work.Waist = work.Waist * CFrame.Angles(0, -y * 0.7, 0)
		work.Neck = work.Neck * CFrame.Angles(0, -y * 0.3, 0)
	end
	-- wall-jump lean toward the launch direction (camera-aimed), fading over the recovery
	if wa >= 0 and wa < 0.6 and work.Root and s.wjLean ~= 0 then
		local k = if wa < 0.1 then wa / 0.1 else 1 - (wa - 0.1) / 0.5
		work.Root = work.Root * CFrame.Angles(0, 0, -s.wjLean * CoreGeom.Ease(k))
	end
	-- slide layer (weight = the server's hit-volume curve)
	local sw = slideWeight(s, now)
	if sw > 0.001 then
		local slideClip, st2
		if s.slideOn and s.slideStart then
			local ts = now - s.slideStart
			if ts < clips.slide_in.len then
				slideClip, st2 = clips.slide_in, ts
			else
				slideClip, st2 = clips.slide_loop, if deps.reduced() then 0 else ts - clips.slide_in.len
			end
		else
			local te = now - (s.slideEnd or now)
			if pa >= 0 and pa < 0.5 then
				slideClip, st2 = clips.slide_loop, 0 -- jumped out of the slide: the push-off below takes over
			else
				slideClip, st2 = clips.slide_out, te
			end
		end
		for _, name in FULL do
			local cur = work[name]
			local cf = sample(slideClip, st2, name)
			if cur and cf then
				work[name] = cur:Lerp(cf, sw)
			end
		end
	end
	-- the slide layer (still easing out for ~0.2 s after a Power Slide Jump into a wall-run) must not pull the raised
	-- reach arm back toward the slide pose: the reach ARM is applied again here (the torso keeps the slide curve, which
	-- the server's head volume follows)
	reachPass(true)
	-- upper body: arm joints override, the chest twist (Waist) adds on top so the slide / run torso stays
	for _, tr in { s.disc, s.shield } do
		if tr and tr.w > 0.001 then
			for _, name in tr.clip.mask :: { string } do
				-- correction pass: the disc arm is the right arm; on a wall to the RIGHT its wind-up would swing into the
				-- wall, so the wall-run brace arm is kept there (the chest twist, held disc and hand spin still show)
				-- security gate pass: with the raised right-wall reach the chest twist is kept off as well (it turned the
				-- shoulder into the wall); the held disc, its glow, the hand spin and the charge tremble still show
				if tr == s.disc and s.reachR > 0.5 and name ~= "RightWrist" then
					continue
				end
				local cur = work[name]
				local cf = sample(tr.clip, tr.t, name)
				if cur and cf then
					if name == "Waist" then
						work[name] = cur * CFrame.identity:Lerp(cf, tr.w)
					else
						work[name] = cur:Lerp(cf, tr.w)
					end
				end
			end
		end
	end
	-- owner request (Step 1E follow-up): while the disc charges (left click held) the right hand spins rapidly about the
	-- forearm, faster as the charge builds (3 -> 8 turns/s; half speed in Reduced FX). Drawn on every client.
	if s.discOn and work.RightWrist then
		local turns = 3 + 5 * chargeK
		if deps.reduced() then
			turns *= 0.5
		end
		s.spin = (s.spin + dt * turns * 2 * math.pi) % (2 * math.pi)
		work.RightWrist = work.RightWrist * CFrame.Angles(0, s.spin, 0)
	else
		s.spin = 0
	end
	-- charge tension: a small tremble that grows with the charge (off in Reduced FX)
	if s.discOn and chargeK > 0 and not deps.reduced() and work.RightShoulder then
		local a = R(1.6) * chargeK
		work.RightShoulder = work.RightShoulder * CFrame.Angles(math.sin(now * 53) * a, 0, math.sin(now * 41) * a)
	end
	-- wall-side arm vs the wall (correction pass)
	if s.wallOn then
		s.lastWallT = now
	end
	if not off and not s.r6 then
		-- whenever a wall is within reach of the root (not only while wall-running: another player's wall-run starts
		-- on this screen a few frames after their body reaches the wall, and the body stays there while clips blend out)
		params.FilterDescendantsInstances = { c }
		local rv = hrp.CFrame.RightVector
		local hr = workspace:Raycast(hrp.Position, rv * 2.5, params)
		local hl = workspace:Raycast(hrp.Position, -rv * 2.5, params)
		local hit, sd = hr, 1
		if hl and (not hr or hl.Distance < hr.Distance) then
			hit, sd = hl, -1
		end
		if hit then
			-- the pose is written before physics moves the root this frame: test against where the wall will be
			-- relative to the root after this step when the body is still closing on it
			local approach = math.max(0, -vel:Dot(hit.Normal)) * dt
			if s.wallOn and now - s.wallOnT < 0.12 and hit.Distance > 1.0 then
				-- attaching to a wall-run: the run pulls the root onto the wall (0.85 - 1.0 by rig) faster than its
				-- current velocity says; only for the first frames (afterwards the measured distance is the truth)
				approach = math.max(approach, hit.Distance - 0.95)
			end
			local wp = hit.Position + hit.Normal * approach
			local rw = if sd > 0 then s.reachR else s.reachL
			if sd > 0 and s.reachR > 0.5 then
				s.discWallP, s.discWallN, s.discWallT = wp, hit.Normal, now
			end
			if rw > 0.9 then
				-- raised reach arm (security gate pass): keep the pose, place the hand on the wall. While it rises /
				-- lowers (0.07 / 0.15 s) the general clear-only fix below keeps the part-raised arm out of the wall
				if not reachContact(c, joints, hrp.CFrame, wp, hit.Normal, sd, work, sd > 0 and s.discOn) then
					wallArmFix(c, joints, hrp.CFrame, wp, hit.Normal, sd, work, sd > 0 and s.discOn)
				end
			else
				wallArmFix(c, joints, hrp.CFrame, wp, hit.Normal, sd, work, sd > 0 and s.discOn)
			end
		end
	end
	-- feet vs floor (correction pass). The pose is written before physics moves the root this frame, so a falling
	-- character is checked where its root will be after this step (measured: a one-frame 0.33 dip at touchdown).
	if not off then
		local fall = math.min(0, vel.Y) * dt
		local probe = floorHit
		if not probe and fall < 0 then
			params.FilterDescendantsInstances = { c }
			local reach = (if hum then hum.HipHeight else 2) + hrp.Size.Y / 2 + 0.6 - fall * 1.5
			probe = workspace:Raycast(hrp.Position, Vector3.new(0, -reach, 0), params)
		end
		if probe then
			local stand = (if hum then hum.HipHeight else 2) + hrp.Size.Y / 2
			local y = math.max(hrp.Position.Y + fall, probe.Position.Y + stand - 0.5)
			fixFeet(c, joints, hrp.CFrame + Vector3.new(0, y - hrp.Position.Y, 0), probe, work)
		end
	end
	for _, name in FULL do
		local j = joints[name]
		local cf = work[name]
		if j and cf then
			j.Transform = cf
		end
	end
end

Poses.Stats = { frames = 0, seconds = 0 } -- script time spent here (test hook: performance)

function Poses.Start(d: any)
	for k, v in d do
		(deps :: any)[k] = v
	end
	RunService.PreSimulation:Connect(function(dt)
		local t0 = os.clock()
		local now = t0
		local delay = CoreConfig.Tune("Disc", "InterpPlayerSeconds")
		for _, p in Players:GetPlayers() do
			local c = p.Character
			local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if c and c.Parent and hrp then
				local s = stateFor(c)
				if s.dead then
					continue
				end
				local hum = c:FindFirstChildOfClass("Humanoid")
				drawCharacter(c, s, hrp, hum, p == player, now, dt, delay)
			end
		end
		Poses.Stats.frames += 1
		Poses.Stats.seconds += os.clock() - t0
	end)
end

-- this client's own jump out of a wall-run (immediate; others see it from the replicated state). side: +1 wall on the right
function Poses.WallJump(side: number?)
	local c = player.Character
	if c then
		local s = stateFor(c)
		s.wjT = os.clock()
		s.wjSide = side or s.wallSide
		s.wjMeasured = false
	end
end

-- owner request: this client's own regular dash (immediate). kind "super" ends the dash clip (the Super Dash keeps
-- the run / fall animation).
function Poses.Dash(kind: string, dir: Vector3)
	local c = player.Character
	if not c then
		return
	end
	local s = stateFor(c)
	if kind == "dash" then
		s.dashT = os.clock()
		s.dashDir = dir
	else
		s.dashT = -10
	end
end

-- kept for the Step 1C wiring: a plain slide jump has no separate clip (the slide exit + fall cover it)
function Poses.Reach() end

-- Step 1D: this client's own Power Slide Jump (immediate; others see it from the replicated state + rising speed)
function Poses.PowerJump()
	local c = player.Character
	if c then
		stateFor(c).psjT = os.clock()
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

-- test hook: what the controller is drawing for a character
-- security gate pass: the wall beside a character's raised RIGHT (disc) arm, if any (point, normal): DiscClient turns
-- the held charging disc edge-on to that wall so the spinning disc never cuts into it
function Poses.DiscWall(c: Model): (Vector3?, Vector3?)
	local s = states[c]
	if s and s.reachR > 0.5 and os.clock() - s.discWallT < 0.1 then
		return s.discWallP, s.discWallN
	end
	return nil, nil
end

function Poses.Debug(c: Model): { [string]: any }?
	local s = states[c]
	if not s then
		return nil
	end
	local base = {}
	for _, tr in s.base do
		table.insert(base, string.format("%s w%.2f t%.2f", tr.clip.name, tr.w, tr.t))
	end
	return {
		base = base,
		baseName = s.baseName,
		slideW = slideWeight(s, os.clock()),
		disc = if s.disc then s.disc.clip.name .. string.format(" w%.2f", s.disc.w) else nil,
		shield = if s.shield then s.shield.clip.name .. string.format(" w%.2f", s.shield.w) else nil,
		airT = s.airT,
		wall = s.wallOn,
		wallSide = s.wallSide,
		reachR = s.reachR,
		reachL = s.reachL,
		reachFix = Poses.ReachFix,
		wallFix = Poses.WallFix,
		dead = s.dead,
		dash = if os.clock() - s.dashT < 0.35 then string.format("%.2f", os.clock() - s.dashT) else nil,
	}
end

return Poses

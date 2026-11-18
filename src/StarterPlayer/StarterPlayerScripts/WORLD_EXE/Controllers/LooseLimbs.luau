--!strict
-- LooseLimbs (wrist-hacking prototype, client) — Rev 15b, owner 2026-11-16 ("loose limbs in air").
-- FLING SELF resembles the regular fling with LESS ragdoll and MORE control: only the arm and leg joints
-- go loose; root, waist and neck stay powered, the Humanoid keeps its normal state, so the body stays
-- upright and air steering is unchanged.
--
-- Runs on the OWNING client: the character's physics belongs to this client, so loosening here is in
-- the same frame as the launch and the limb motion replicates to other players like any other limb
-- movement. (A server-side version disturbed the client's launch: 2.2-stud flights instead of ~20.)
--
-- Supports both rigs:
--   new avatars: AnimationConstraint "LeftShoulder" + BallSocketConstraint "LeftShoulderBallSocket"
--                (go loose = AnimationConstraint off, ball socket on)
--   Motor6D rigs: Motor6D off + a temporary BallSocketConstraint with limits

local LooseLimbs = {}

local ARM_JOINTS: { [string]: boolean } = {
	LeftShoulder = true, RightShoulder = true, LeftElbow = true, RightElbow = true, LeftWrist = true, RightWrist = true,
	["Left Shoulder"] = true, ["Right Shoulder"] = true, -- R6
}
local LEG_JOINTS: { [string]: boolean } = {
	LeftHip = true, RightHip = true, LeftKnee = true, RightKnee = true, LeftAnkle = true, RightAnkle = true,
	["Left Hip"] = true, ["Right Hip"] = true, -- R6
}
local function isLimbJoint(name: string): boolean
	if ARM_JOINTS[name] then
		return true
	end
	return LEG_JOINTS[name] == true
end

export type Handle = {
	anims: { { ac: AnimationConstraint, bs: BallSocketConstraint, bsWas: boolean } },
	motors: { Motor6D },
	made: { Instance },
	collide: { [BasePart]: boolean },
	limbs: { BasePart },
	lastKick: number,
}

function LooseLimbs.Begin(character: Model): Handle
	local h: Handle = { anims = {}, motors = {}, made = {}, collide = {}, limbs = {}, lastKick = 0 }
	local function noCollide(p: Instance?)
		if p and p:IsA("BasePart") and h.collide[p] == nil then
			h.collide[p] = p.CanCollide
			p.CanCollide = false -- loose limbs never snag geometry (control first)
			table.insert(h.limbs, p)
		end
	end
	for _, j in character:GetDescendants() do
		if isLimbJoint(j.Name) then
			if j:IsA("AnimationConstraint") and j.Enabled and j.Attachment0 and j.Attachment1 and j.Parent then
				local found = j.Parent:FindFirstChild(j.Name .. "BallSocket")
				local bs: BallSocketConstraint
				local was = false
				if found and found:IsA("BallSocketConstraint") then
					bs = found
					was = found.Enabled
				else
					bs = Instance.new("BallSocketConstraint")
					bs.Name = j.Name .. "LooseSocket"
					bs.Attachment0 = j.Attachment0
					bs.Attachment1 = j.Attachment1
					bs.LimitsEnabled = true
					bs.UpperAngle = 80
					bs.Parent = j.Parent
					table.insert(h.made, bs)
				end
				bs.Enabled = true
				j.Enabled = false
				table.insert(h.anims, { ac = j, bs = bs, bsWas = was })
				noCollide(j.Parent)
			elseif j:IsA("Motor6D") and j.Enabled and j.Part0 and j.Part1 then
				local a0 = Instance.new("Attachment")
				a0.CFrame = j.C0
				a0.Parent = j.Part0
				local a1 = Instance.new("Attachment")
				a1.CFrame = j.C1
				a1.Parent = j.Part1
				local bs = Instance.new("BallSocketConstraint")
				bs.Attachment0 = a0
				bs.Attachment1 = a1
				bs.LimitsEnabled = true
				bs.UpperAngle = 80
				bs.TwistLimitsEnabled = true
				bs.TwistLowerAngle = -50
				bs.TwistUpperAngle = 50
				bs.Parent = j.Part0
				table.insert(h.made, a0)
				table.insert(h.made, a1)
				table.insert(h.made, bs)
				j.Enabled = false
				table.insert(h.motors, j)
				noCollide(j.Part1)
			end
		end
	end
	character:SetAttribute("WORLD_EXE_LooseLimbs", #h.anims + #h.motors)
	return h
end

-- In ballistic flight every part falls together, so free limbs barely move. A random spin kick at launch
-- (strength 1) and light kicks while airborne (about every 0.12 s) make them visibly flail; the root is
-- never touched, so steering and the upright body are unaffected.
function LooseLimbs.Flail(h: Handle?, strength: number)
	if not h then
		return
	end
	local t = os.clock()
	if strength < 1 and t - h.lastKick < 0.12 then
		return
	end
	h.lastKick = t
	local rad = 32 * strength
	for _, p in h.limbs do
		if p.Parent then
			p.AssemblyAngularVelocity = Vector3.new((math.random() - 0.5) * 2 * rad, (math.random() - 0.5) * 2 * rad, (math.random() - 0.5) * 2 * rad)
		end
	end
end

-- restore = false when the server has taken the joints over (a real ragdoll started): only drop our
-- temporary instances and leave the joint states alone.
function LooseLimbs.End(h: Handle?, character: Model?, restore: boolean)
	if not h then
		return
	end
	for _, inst in h.made do
		inst:Destroy()
	end
	if restore then
		for _, sw in h.anims do
			if sw.ac.Parent then
				sw.ac.Enabled = true
			end
			if sw.bs.Parent then
				sw.bs.Enabled = sw.bsWas
			end
		end
		for _, m in h.motors do
			if m.Parent then
				m.Enabled = true
			end
		end
	end
	for p, was in h.collide do
		if p.Parent then
			p.CanCollide = was
		end
	end
	if character then
		character:SetAttribute("WORLD_EXE_LooseLimbs", nil)
	end
end

return LooseLimbs

--!strict
-- Poses (Core Round Step 1B, client): procedural slide pose, drawn on EVERY client for every character whose
-- replicated CR_MoveState is "slide" (and for your own character at once, from the local slide state).
-- No animation assets or uploads: the pose is a blend applied to the rig's Motor6D.Transform after Roblox's default
-- animations each frame (RunService.PreSimulation). R15 gets the full pose; R6 a lowered, leaning torso.
-- Look: a lean-back "baseball" slide with the lead leg extended and the rear leg tucked, disc arm forward
-- (third person reads this better than the knee-slide Titanfall 2 chose for its first-person view).
-- Collision and the root part are unchanged (only joints move), so movement physics are not affected.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CoreRound = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))

local Poses = {}

local player = Players.LocalPlayer
local localSlide: () -> boolean = function()
	return false
end

local R = math.rad
-- target joint transforms (local joint space)
local R15 = {
	Root = CFrame.new(0, -1.35, 0.2) * CFrame.Angles(R(38), 0, 0), -- lower + lean back
	Waist = CFrame.Angles(R(-12), R(-8), 0), -- curl the chest forward a little
	Neck = CFrame.Angles(R(-22), 0, 0), -- keep looking ahead
	RightHip = CFrame.Angles(R(34), 0, 0), -- lead leg extended forward
	RightKnee = CFrame.Angles(R(-6), 0, 0),
	LeftHip = CFrame.Angles(R(-8), 0, R(-6)), -- rear leg tucked under
	LeftKnee = CFrame.Angles(R(-105), 0, 0),
	RightShoulder = CFrame.Angles(R(55), 0, R(10)), -- disc arm forward
	LeftShoulder = CFrame.Angles(R(-25), 0, R(-40)), -- balance arm back / out
}
local R6 = {
	RootJoint = CFrame.new(0, 0, -1.2) * CFrame.Angles(R(-38), 0, 0), -- R6 RootJoint axes differ (Z is down)
}

-- Step 1B finding (draft lesson L-0050): newer avatar rigs use AnimationConstraint joints instead of Motor6D; both
-- expose .Transform, so both are posed.
type Joint = { m: any, target: CFrame }
type Rig = { joints: { Joint }, w: number }
local rigs: { [Model]: Rig } = {}

local function rigFor(c: Model): Rig
	local existing = rigs[c]
	if existing then
		return existing
	end
	local joints: { Joint } = {}
	local hum = c:FindFirstChildOfClass("Humanoid")
	local map = if hum and hum.RigType == Enum.HumanoidRigType.R6 then R6 else R15
	for _, d in c:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			local target = (map :: any)[d.Name]
			if target then
				table.insert(joints, { m = d, target = target })
			end
		end
	end
	local rig = { joints = joints, w = 0 }
	rigs[c] = rig
	c.Destroying:Connect(function()
		rigs[c] = nil
	end)
	return rig
end

function Poses.Start(deps: { localSlide: () -> boolean })
	localSlide = deps.localSlide
	RunService.PreSimulation:Connect(function(dt)
		local blend = math.max(0.02, CoreConfig.Tune("Slide", "PoseBlendSeconds"))
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c and c.Parent then
				local sliding = if p == player then localSlide() else c:GetAttribute("CR_MoveState") == "slide"
				local rig = rigs[c]
				if sliding or (rig and rig.w > 0) then
					rig = rigFor(c)
					local target = if sliding then 1 else 0
					local step = dt / blend
					rig.w = if target > rig.w then math.min(1, rig.w + step) else math.max(0, rig.w - step)
					if rig.w > 0 then
						for _, j in rig.joints do
							j.m.Transform = j.m.Transform:Lerp(j.target, rig.w)
						end
					end
				end
			end
		end
	end)
end

function Poses.Weight(c: Model): number
	local rig = rigs[c]
	return if rig then rig.w else 0
end

return Poses

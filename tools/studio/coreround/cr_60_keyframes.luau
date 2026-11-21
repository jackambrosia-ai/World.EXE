-- Core Round Step 1E: build LOCAL KeyframeSequence objects from the generated AnimData module (no upload, no asset IDs).
--   Edit mode (command bar / MCP):   loadstring(HttpService:GetAsync(".../tools/cr_60_keyframes.luau"))()
--     -> ServerStorage.RBX_ANIMSAVES.CoreRound_AnimRig.<clip> (the Animation Editor's local-save location; open the
--        CoreRound_AnimRig model from ServerStorage in the Animation Editor to load / edit them) and a report string.
--   The same builder (CR_BuildKeyframes) runs in a Play client for the temp-ID test:
--     KeyframeSequenceProvider:RegisterKeyframeSequence(ks) -> a temporary, Studio-only id that Animator:LoadAnimation
--     accepts on THAT client. Temp ids are not assets: they do not replicate, do not work in a published game, and
--     vanish with the session. Shipping Animator-based playback would need uploaded animation assets (not authorized).
local JOINTS = { -- joint -> (parent part, child part)
	Root = { "HumanoidRootPart", "LowerTorso" },
	Waist = { "LowerTorso", "UpperTorso" },
	Neck = { "UpperTorso", "Head" },
	RightShoulder = { "UpperTorso", "RightUpperArm" },
	RightElbow = { "RightUpperArm", "RightLowerArm" },
	RightWrist = { "RightLowerArm", "RightHand" },
	LeftShoulder = { "UpperTorso", "LeftUpperArm" },
	LeftElbow = { "LeftUpperArm", "LeftLowerArm" },
	LeftWrist = { "LeftLowerArm", "LeftHand" },
	RightHip = { "LowerTorso", "RightUpperLeg" },
	RightKnee = { "RightUpperLeg", "RightLowerLeg" },
	RightAnkle = { "RightLowerLeg", "RightFoot" },
	LeftHip = { "LowerTorso", "LeftUpperLeg" },
	LeftKnee = { "LeftUpperLeg", "LeftLowerLeg" },
	LeftAnkle = { "LeftLowerLeg", "LeftFoot" },
}
local ORDER = { "Root", "Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist", "RightHip", "RightKnee", "RightAnkle", "LeftHip", "LeftKnee", "LeftAnkle" }

local function build(AD: any, name: string): KeyframeSequence
	local c = AD.clips[name]
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = c.loop
	ks.Priority = if c.layer == "upper" then Enum.AnimationPriority.Action else Enum.AnimationPriority.Movement
	local n = if c.loop then c.frames else c.frames + 1
	for i = 0, (if c.loop then c.frames else c.frames) do
		local fi = i % n
		local kf = Instance.new("Keyframe")
		kf.Time = i / AD.fps
		local poses: { [string]: Pose } = {}
		local root = Instance.new("Pose")
		root.Name = "HumanoidRootPart"
		root.Weight = 0
		root.Parent = kf
		poses.HumanoidRootPart = root
		for _, j in ORDER do
			local parentPart, childPart = JOINTS[j][1], JOINTS[j][2]
			local p = Instance.new("Pose")
			p.Name = childPart
			local d = c.j[j]
			if d then
				local b = fi * 4
				local tx, ty, tz = 0, 0, 0
				if d.t then
					tx, ty, tz = d.t[fi * 3 + 1], d.t[fi * 3 + 2], d.t[fi * 3 + 3]
				end
				p.CFrame = CFrame.new(tx, ty, tz, d.q[b + 2], d.q[b + 3], d.q[b + 4], d.q[b + 1])
				p.Weight = 1
			else
				p.Weight = 0 -- not part of this (masked) clip: keeps the hierarchy only
			end
			p.EasingStyle = Enum.PoseEasingStyle.Linear
			p.Parent = poses[parentPart]
			poses[childPart] = p
		end
		kf.Parent = ks
	end
	return ks
end
_G.CR_BuildKeyframes = build

-- Edit mode: save every clip locally where the Animation Editor looks for local saves
local RunService = game:GetService("RunService")
if RunService:IsEdit() then
	local SS = game:GetService("ServerStorage")
	-- require a fresh copy: Edit-mode require caches the module, so a just-synced AnimData would be missed
	local AD = require((game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("AnimData", true) :: ModuleScript):Clone())
	local saves = SS:FindFirstChild("RBX_ANIMSAVES") or Instance.new("Model")
	saves.Name = "RBX_ANIMSAVES"
	saves.Parent = SS
	local holder = saves:FindFirstChild("CoreRound_AnimRig")
	if holder then
		holder:Destroy()
	end
	holder = Instance.new("ObjectValue")
	holder.Name = "CoreRound_AnimRig"
	holder.Value = SS:FindFirstChild("CoreRound_AnimRig")
	holder.Parent = saves
	local names = {}
	for name in AD.clips do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		build(AD, name).Parent = holder
	end
	return "saved " .. #names .. " KeyframeSequences to ServerStorage.RBX_ANIMSAVES.CoreRound_AnimRig"
end
return "builder ready"

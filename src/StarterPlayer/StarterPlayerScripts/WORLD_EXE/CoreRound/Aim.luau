--!strict
-- Aim (Core Round Step 1, client): where the player is aiming, and the desktop "aim lock" camera.
--   * Aim always goes through the screen-centre crosshair (desktop aim lock, gamepad, touch), or through the
--     mouse cursor when the desktop player frees the cursor (Left Alt).
--   * Desktop aim lock (default on with a mouse): cursor locked to the centre, over-the-shoulder camera offset,
--     the character faces the camera yaw while running normally. Right mouse is then free for the shield.
--     No camera shake is added anywhere.
-- The character rig and avatar settings are not changed.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Aim = {}

Aim.LockEnabled = true -- user setting (desktop)
local lockActive = false
local player = Players.LocalPlayer
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local moveStateOwner: () -> string? = function()
	return nil
end
local isStunned: () -> boolean = function()
	return false
end

function Aim.UsesMouse(): boolean
	local last = UserInputService:GetLastInputType()
	return UserInputService.MouseEnabled and not UserInputService.TouchEnabled
		and last ~= Enum.UserInputType.Gamepad1 and last ~= Enum.UserInputType.Touch
end

function Aim.LockActive(): boolean
	return lockActive
end

-- ray from the camera through the crosshair (or the free cursor)
function Aim.Ray(): Ray
	local cam = workspace.CurrentCamera
	if Aim.UsesMouse() and not lockActive then
		local m = UserInputService:GetMouseLocation()
		return cam:ViewportPointToRay(m.X, m.Y)
	end
	local v = cam.ViewportSize
	return cam:ViewportPointToRay(v.X / 2, v.Y / 2)
end

-- world point under the crosshair (or far along the ray)
function Aim.Point(): Vector3
	local ray = Aim.Ray()
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local fx = workspace:FindFirstChild("CoreRoundFx")
	if fx then
		table.insert(ignore, fx)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * 400
end

-- flat camera look yaw (radians, same convention as the server shield: dir = (sin yaw, 0, cos yaw))
function Aim.Yaw(): number
	local look = workspace.CurrentCamera.CFrame.LookVector
	return math.atan2(look.X, look.Z)
end

-- Step 1B camera refinements (third person stays primary): the shoulder offset is eased (no snapping), shortened by a
-- raycast so the camera does not clip into walls, lowered during a slide, pushed away from the wall during a wall-run
-- and a small spring-back dip on hard landings (Titanfall 2 interview: the landing spring sells weight). No camera
-- shake. Reduced Effects disables the landing dip and (Step 1C) the optional wall-run roll.
local camOffset = Vector3.zero
local dip = 0
local lastVy = 0
local camParams = RaycastParams.new()
camParams.FilterType = Enum.RaycastFilterType.Exclude
local extra: {
	slideActive: () -> boolean,
	wallBias: () -> Vector3,
	reduced: () -> boolean,
	wallNormal: (() -> Vector3?)?,
	tiltEnabled: (() -> boolean)?,
} = {
	slideActive = function()
		return false
	end,
	wallBias = function()
		return Vector3.zero
	end,
	reduced = function()
		return false
	end,
}

-- Step 1C (A3): optional wall-run camera roll away from the wall. Eased in / out, applied after Roblox's camera
-- update each frame (never stored, so it cannot accumulate). Roll turns the view around its own look direction, so
-- the crosshair ray, the aim yaw (shield facing) and the camera position (collision) are unchanged.
local roll = 0 -- current roll (radians, + = horizon turns so the view's up leans to screen-left)
Aim.Roll = function(): number
	return roll
end

function Aim.SetExtra(e: typeof(extra))
	extra = e
end

local function desiredOffset(hum: Humanoid, hrp: BasePart, shoulder: boolean, dt: number): Vector3
	local tune = require(game:GetService("ReplicatedStorage"):WaitForChild("WORLD_EXE"):WaitForChild("CoreRound"):WaitForChild("CoreConfig")).Tune
	local off = if shoulder then Vector3.new(1.6, 0.4, 0) else Vector3.zero
	if extra.slideActive() then
		off += Vector3.new(0, -1.1, 0)
	end
	local wb = extra.wallBias()
	if wb.Magnitude > 0.01 then
		off += hrp.CFrame:VectorToObjectSpace(wb)
	end
	-- landing dip
	local vy = hrp.AssemblyLinearVelocity.Y
	if hum.FloorMaterial ~= Enum.Material.Air and lastVy < -tune("Move", "LandingDipFallSpeed") and not extra.reduced() then
		dip = tune("Move", "LandingDipStuds") * math.clamp(-lastVy / 90, 0.5, 1)
	end
	lastVy = vy
	dip = math.max(0, dip - dt * 2.2)
	off += Vector3.new(0, -dip, 0)
	-- clip guard: shorten the horizontal part if a wall is in the way
	if off.Magnitude > 0.05 then
		local headPos = hrp.Position + Vector3.new(0, 1.5, 0)
		local world = hrp.CFrame:VectorToWorldSpace(off)
		camParams.FilterDescendantsInstances = { hrp.Parent :: Instance, workspace:FindFirstChild("CoreRoundFx") :: Instance }
		local hit = workspace:Raycast(headPos, world.Unit * (world.Magnitude + 0.6), camParams)
		if hit then
			local k = math.max(0, (hit.Position - headPos).Magnitude - 0.6) / world.Magnitude
			off *= math.clamp(k, 0, 1)
		end
	end
	return off
end

function Aim.Start(deps: { owner: () -> string?, stunned: () -> boolean })
	moveStateOwner = deps.owner
	isStunned = deps.stunned
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.LeftAlt then
			Aim.LockEnabled = not Aim.LockEnabled
		end
	end)
	RunService:BindToRenderStep("CoreRoundAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local c = player.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local want = Aim.LockEnabled and Aim.UsesMouse() and hum ~= nil and hum.Health > 0
		local tune = require(game:GetService("ReplicatedStorage"):WaitForChild("WORLD_EXE"):WaitForChild("CoreRound"):WaitForChild("CoreConfig")).Tune
		if hum and hrp and hum.Health > 0 then
			local target = desiredOffset(hum, hrp, want, dt)
			-- Step 1C (A1): one tunable blend time for camera offset changes (slide drop, wall push, shoulder); the rate
			-- reaches ~95% of a change in Cam.BlendSeconds
			camOffset = camOffset:Lerp(target, math.min(1, dt * 3 / math.max(0.05, tune("Cam", "BlendSeconds"))))
			hum.CameraOffset = camOffset
		end
		-- Step 1C (A3): wall-run camera roll
		local cam = workspace.CurrentCamera
		local wantRoll = 0
		local n = extra.wallNormal and extra.wallNormal()
		local enabled = (extra.tiltEnabled == nil or extra.tiltEnabled()) and not extra.reduced()
		if n and enabled and hum and hum.Health > 0 then
			-- wall on the screen's right (normal points left) -> roll the up vector left, away from the wall
			local side = if n:Dot(cam.CFrame.RightVector) < 0 then 1 else -1
			wantRoll = math.rad(math.clamp(tune("WallRun2", "CamTiltDegrees"), 0, 20)) * side
		end
		local secs = if math.abs(wantRoll) > math.abs(roll) then tune("WallRun2", "CamTiltInSeconds") else tune("WallRun2", "CamTiltOutSeconds")
		-- constant rate: a full tilt eases in / out in CamTiltIn / OutSeconds (no long exponential tail)
		local full = math.max(math.rad(math.clamp(tune("WallRun2", "CamTiltDegrees"), 0, 20)), math.abs(roll), 1e-3)
		local step = full * dt / math.max(0.05, secs)
		roll = if roll < wantRoll then math.min(wantRoll, roll + step) else math.max(wantRoll, roll - step)
		if not enabled and not n then
			roll = if math.abs(roll) < 1e-3 then 0 else roll
		end
		if math.abs(roll) > 1e-4 then
			cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, roll)
		end
		if want and hum and hrp then
			lockActive = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			local owner = moveStateOwner()
			if owner == nil and not isStunned() then
				hum.AutoRotate = false
				local yaw = Aim.Yaw()
				hrp.CFrame = CFrame.new(hrp.Position) * CFrame.fromOrientation(0, yaw + math.pi, 0)
			end
		elseif lockActive then
			lockActive = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			if hum then
				hum.AutoRotate = true -- the eased offset above returns to centre on its own
			end
		end
	end)
end

return Aim

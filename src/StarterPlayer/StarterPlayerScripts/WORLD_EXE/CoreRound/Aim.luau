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

function Aim.Start(deps: { owner: () -> string?, stunned: () -> boolean })
	moveStateOwner = deps.owner
	isStunned = deps.stunned
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.LeftAlt then
			Aim.LockEnabled = not Aim.LockEnabled
		end
	end)
	RunService:BindToRenderStep("CoreRoundAim", Enum.RenderPriority.Camera.Value + 1, function()
		local c = player.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local want = Aim.LockEnabled and Aim.UsesMouse() and hum ~= nil and hum.Health > 0
		if want and hum and hrp then
			lockActive = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			hum.CameraOffset = Vector3.new(1.6, 0.4, 0)
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
				hum.CameraOffset = Vector3.zero
				hum.AutoRotate = true
			end
		end
	end)
end

return Aim

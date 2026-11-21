-- Core Round Step 1E: Play-mode (client) capture / log helpers for the animation review. Run in the CLIENT datamodel.
-- Hides the player list (it shows the account name), turns the aim lock off (so the body faces its run direction for
-- side views), and installs:
--   _G.CR_TP(pos, dir)              teleport the local character facing dir
--   _G.CR_LOG(seconds)              log the animation controller state every 0.1 s into _G.AL
--   _G.CR_CAMMODE = { off = Vector3, fov = number } | nil   follow camera at root + off (nil = game camera)
local RS = game:GetService("RunService")
local P = game:GetService("Players").LocalPlayer
local T = P.PlayerScripts:WaitForChild("CoreRoundClientTest")
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
T:Invoke("AimLock", false)
_G.CR_TP = function(pos: Vector3, dir: Vector3)
	local hrp = P.Character.HumanoidRootPart
	hrp.CFrame = CFrame.lookAt(pos, pos + dir)
	hrp.AssemblyLinearVelocity = Vector3.zero
end
_G.CR_LOG = function(sec: number)
	_G.AL = {}
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < sec do
			local d = T:Invoke("AnimDebug")
			local hrp = P.Character.HumanoidRootPart
			local v = hrp.AssemblyLinearVelocity
			table.insert(_G.AL, string.format("%.2f %s spd%.0f vy%.0f y%.1f sw%.2f [%s] disc=%s shield=%s wall=%s",
				os.clock() - t0, tostring(d and d.baseName), Vector3.new(v.X, 0, v.Z).Magnitude, v.Y, hrp.Position.Y,
				d and d.slideW or -1, d and table.concat(d.base, "; ") or "", tostring(d and d.disc), tostring(d and d.shield),
				tostring(d and d.wall)))
			task.wait(0.1)
		end
	end)
end
pcall(function()
	RS:UnbindFromRenderStep("CR_SideCam")
end)
RS:BindToRenderStep("CR_SideCam", Enum.RenderPriority.Last.Value + 50, function()
	local m = _G.CR_CAMMODE
	if not m then
		return
	end
	local cam = workspace.CurrentCamera
	local hrp = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local p = hrp.Position
		cam.CFrame = CFrame.lookAt(p + m.off, p + Vector3.new(0, 0.3, 0))
		cam.FieldOfView = m.fov
	end
end)
return "capture helpers ready"

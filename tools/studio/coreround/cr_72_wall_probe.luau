-- Core Round Step 1E correction pass: Play-client probe for wall contact during wall-runs (paste into the CLIENT
-- datamodel). Every frame the character's CR_MoveState is "wallrun", the nearest wall within 4 studs is found and the
-- deepest arm / hand corner and the deepest torso / leg / head corner behind the wall plane are recorded.
--   _G.WALLMON(character, seconds), _G.WALLSUM(), _G.RUNCHAIN() (PSJ -> wall-run -> wall-jump route, with a charge)
local Pl = game:GetService("Players")
local RS = game:GetService("RunService")
local P = Pl.LocalPlayer
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
_G.T = P.PlayerScripts:WaitForChild("CoreRoundClientTest")
_G.TP = function(pos, dir)
	local hrp = P.Character.HumanoidRootPart
	hrp.CFrame = CFrame.lookAt(pos, pos + dir)
	hrp.AssemblyLinearVelocity = Vector3.zero
	workspace.CurrentCamera.CFrame = CFrame.lookAt(pos - dir * 14 + Vector3.new(0, 5, 0), pos + dir * 10)
end
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
local PARTS = { "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand", "UpperTorso", "LowerTorso", "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot", "Head" }
_G.WALLMON = function(c, sec)
	_G.WM = {}
	task.spawn(function()
		local t0 = os.clock()
		local conn
		conn = RS.Heartbeat:Connect(function()
			local t = os.clock() - t0
			if t > sec then
				conn:Disconnect()
				return
			end
			if c:GetAttribute("CR_MoveState") ~= "wallrun" then
				return
			end
			local hrp = c.HumanoidRootPart
			rp.FilterDescendantsInstances = { c, workspace:FindFirstChild("CoreRoundFx") }
			local best
			for _, dir in { hrp.CFrame.RightVector, -hrp.CFrame.RightVector } do
				local h = workspace:Raycast(hrp.Position, dir * 4, rp)
				if h and (not best or h.Distance < best.Distance) then
					best = h
				end
			end
			if not best then
				return
			end
			local arm, body, armWho, bodyWho = -1e9, -1e9, "", ""
			for _, n in PARTS do
				local p = c:FindFirstChild(n)
				local cf, s = p.CFrame, p.Size
				for _, x in { -0.5, 0.5 } do
					for _, y in { -0.5, 0.5 } do
						for _, z in { -0.5, 0.5 } do
							local pen = -((cf * Vector3.new(x * s.X, y * s.Y, z * s.Z)) - best.Position):Dot(best.Normal)
							if n:find("Arm") or n:find("Hand") then
								if pen > arm then
									arm, armWho = pen, n
								end
							elseif pen > body then
								body, bodyWho = pen, n
							end
						end
					end
				end
			end
			table.insert(_G.WM, { t = t, gap = best.Distance, arm = arm, armWho = armWho, body = body, bodyWho = bodyWho, ch = _G.T:Invoke("Charging")[1] })
		end)
	end)
end
_G.WALLSUM = function()
	local a, b, g, w, bw = -1e9, -1e9, 1e9, "", ""
	local na, nc = 0, 0
	for _, m in _G.WM do
		if m.ch then
			nc += 1
		end
		if m.arm > a then
			a, w = m.arm, m.armWho
		end
		if m.body > b then
			b, bw = m.body, m.bodyWho
		end
		g = math.min(g, m.gap)
		if m.arm > 0.06 then
			na += 1
		end
	end
	return string.format("wallrun frames=%d (charging %d) rootToWall>=%.2f worst arm pen %.3f (%s) frames arm>0.06: %d  worst body/legs pen %.3f (%s)", #_G.WM, nc, g, a, w, na, b, bw)
end
_G.RUNCHAIN = function()
	_G.TP(Vector3.new(-169.3, 4, -25), Vector3.new(0, 0, -1))
	task.wait(1.0)
	_G.WALLMON(P.Character, 5)
	task.delay(1.6, function()
		_G.T:Invoke("ChargeBegin")
		task.wait(0.6)
		_G.T:Invoke("ChargeRelease")
	end)
end
return "wall probe ready"

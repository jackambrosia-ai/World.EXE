-- Core Round Step 1E correction pass: Play-client probe for leg / floor contact (paste into the CLIENT datamodel).
--   _G.SINKMON(character, seconds)  records, every frame, the lowest leg-part corner relative to the floor under
--                                   the root (after physics), with the controller's base clip and slide weight
--   _G.SINKSUM()                    lowest value per state + how many frames were below -0.06
local Pl = game:GetService("Players")
local RS = game:GetService("RunService")
local P = Pl.LocalPlayer
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
local T = P.PlayerScripts:WaitForChild("CoreRoundClientTest")
_G.T = T
_G.TP = function(pos, dir)
	local hrp = P.Character.HumanoidRootPart
	hrp.CFrame = CFrame.lookAt(pos, pos + dir)
	hrp.AssemblyLinearVelocity = Vector3.zero
	workspace.CurrentCamera.CFrame = CFrame.lookAt(pos - dir * 14 + Vector3.new(0, 5, 0), pos + dir * 10)
end
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
_G.SINKMON = function(c, sec)
	_G.SINK = {}
	task.spawn(function()
		local t0 = os.clock()
		local conn
		conn = RS.Heartbeat:Connect(function()
			local t = os.clock() - t0
			if t > sec then
				conn:Disconnect()
				return
			end
			local hrp = c.HumanoidRootPart
			rp.FilterDescendantsInstances = { c }
			local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), rp)
			if not hit then
				return
			end
			local lo, who = 1e9, ""
			for _, n in { "LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg", "LeftUpperLeg", "RightUpperLeg" } do
				local p = c:FindFirstChild(n)
				local cf, s = p.CFrame, p.Size
				for _, x in { -0.5, 0.5 } do
					for _, y in { -0.5, 0.5 } do
						for _, z in { -0.5, 0.5 } do
							local v = (cf * Vector3.new(x * s.X, y * s.Y, z * s.Z)).Y - hit.Position.Y
							if v < lo then
								lo, who = v, n
							end
						end
					end
				end
			end
			local d = T:Invoke("AnimDebug", c.Name) or {}
			table.insert(_G.SINK, { t = t, sw = d.slideW or 0, base = tostring(d.baseName), lo = lo, who = who })
		end)
	end)
end
_G.SINKSUM = function()
	local by, n6 = {}, 0
	for _, s in _G.SINK do
		if s.lo < -0.06 then
			n6 += 1
		end
		local k = s.base .. (if s.sw > 0.95 then "(slide full)" elseif s.sw > 0.02 then "(slide blend)" else "")
		local b = by[k] or { n = 0, min = 1e9, who = "" }
		b.n += 1
		if s.lo < b.min then
			b.min, b.who = s.lo, s.who
		end
		by[k] = b
	end
	local o = {}
	for k, b in by do
		table.insert(o, string.format("%s n=%d lowest=%.3f (%s)", k, b.n, b.min, b.who))
	end
	return table.concat(o, "\n") .. "\nframes below -0.06: " .. n6 .. " of " .. #_G.SINK
end
return "floor probe ready"

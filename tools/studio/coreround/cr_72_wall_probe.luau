-- Core Round Step 1E (correction pass; security gate pass revision): Play-client probe for wall contact during
-- wall-runs (paste into the CLIENT datamodel). Every frame next to a wall (4-stud side rays) it records, against the
-- nearest wall plane: the wall-side upper / lower arm (must stay out), the wall-side HAND (should touch: about 0),
-- torso / head / thighs (must stay out), shins / feet (contact), the held disc's rim (while charging), and how far
-- the hand is above the shoulder (raised reach).
--   _G.WALLMON(character, seconds), _G.WALLSUM(onlyWallrun), _G.WALLGO(seconds) (own character: teleport to the
--   WR2_WallA lane at x -169.3 facing -Z; then hold W, press Space after ~1 s next to the wall)
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
			local st = c:GetAttribute("CR_MoveState")
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
			local function pen(n)
				local p = c:FindFirstChild(n)
				local cf, s = p.CFrame, p.Size
				local w = -1e9
				for _, x in { -0.5, 0.5 } do
					for _, y in { -0.5, 0.5 } do
						for _, z in { -0.5, 0.5 } do
							w = math.max(w, -((cf * Vector3.new(x * s.X, y * s.Y, z * s.Z)) - best.Position):Dot(best.Normal))
						end
					end
				end
				return w
			end
			local side = if best.Normal:Dot(hrp.CFrame.RightVector) < 0 then "Right" else "Left"
			local arm = math.max(pen(side .. "UpperArm"), pen(side .. "LowerArm"))
			local hand = pen(side .. "Hand")
			local body = -1e9
			for _, n in { "UpperTorso", "LowerTorso", "Head", "RightUpperLeg", "LeftUpperLeg" } do
				body = math.max(body, pen(n))
			end
			local feet = math.max(pen("RightFoot"), pen("LeftFoot"), pen("RightLowerLeg"), pen("LeftLowerLeg"))
			local fx = workspace:FindFirstChild("CoreRoundFx")
			local disc = fx and fx:FindFirstChild("HeldDisc", true)
			local dp = -9
			if disc then
				local cf, s = disc.CFrame, disc.Size
				for i = 0, 11 do
					local a = i / 12 * 2 * math.pi
					dp = math.max(dp, -((cf * Vector3.new(0, math.cos(a) * s.Y / 2, math.sin(a) * s.Z / 2)) - best.Position):Dot(best.Normal))
				end
			end
			local v = c[side .. "Hand"].Position - c[side .. "UpperArm"].Position
			table.insert(_G.WM, { t = t, st = tostring(st), side = side, gap = best.Distance, arm = arm, hand = hand, body = body, feet = feet, disc = dp, up = v.Y })
		end)
	end)
end
_G.WALLSUM = function(onlyWall)
	local r = { n = 0, arm = -9, handMin = 9, handMax = -9, body = -9, feet = -9, disc = -9, up = 9, nArm = 0, nHandFar = 0 }
	for _, m in _G.WM do
		if not onlyWall or m.st == "wallrun" then
			r.n += 1
			r.arm = math.max(r.arm, m.arm)
			r.body = math.max(r.body, m.body)
			r.feet = math.max(r.feet, m.feet)
			r.disc = math.max(r.disc, m.disc)
			r.handMin = math.min(r.handMin, m.hand)
			r.handMax = math.max(r.handMax, m.hand)
			r.up = math.min(r.up, m.up)
			if m.arm > 0.06 then
				r.nArm += 1
			end
			if m.hand < -0.15 then
				r.nHandFar += 1
			end
		end
	end
	return string.format("frames %d arm(upper/lower) worst %.3f (>0.06: %d) hand %.3f..%.3f (gap>0.15: %d) body %.3f feet %.3f disc %.3f minUp %.2f", r.n, r.arm, r.nArm, r.handMin, r.handMax, r.nHandFar, r.body, r.feet, r.disc, r.up)
end
_G.WALLGO = function(sec)
	_G.TP(Vector3.new(-169.3, 4, -25), Vector3.new(0, 0, -1))
	task.wait(0.6)
	_G.WALLMON(P.Character, sec or 4)
end
return "wall probe ready"

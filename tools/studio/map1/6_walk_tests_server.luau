-- WORLD.EXE Map 1: solo Play walk tests (Server datamodel, Play mode only; mutates nothing in the place).
-- Teleports the first player's character to each route start and walks it with Humanoid:MoveTo along
-- the route waypoints (every leg < 8 s, MoveTo's timeout). A leg counts as reached when MoveToFinished
-- fires with true or the root part is within 2.5 studs (XZ) of the waypoint. Requires the player to be a
-- Participant (PlayerStateService's watchdog returns non-participants inside ArenaBounds to the lobby);
-- with StudioMinPlayers = 1 a solo Play session becomes Participant on its own.
-- In Play mode the assistant's server context has no HTTP access, so paste this file's text into
-- execute_luau (datamodel "Server") rather than loading it by URL. It runs in task.spawn: poll
-- _G.MAP1_WALK (state, results[]).
_G.MAP1_ROUTES = {
	-- hub start -> boss floor centre. Waypoints avoid cover and ramp rails (MoveTo never jumps).
	-- v7 paths (unchanged geometry on the ground routes; W_Gantry = the v7 W elevated path, still built)
	N_Ground = { start = Vector3.new(65, 3, -245), pts = { { 65, -262 }, { 65, -340 }, { 65, -420 }, { 30, -478 }, { 0, -510 }, { 20, -540 }, { 15, -598 } } },
	W_Ground = { start = Vector3.new(-254, 3, 32), pts = { { -340, 32 }, { -440, 32 }, { -490, 32 }, { -560, 32 }, { -600, 32 } } },
	E_Ground = { start = Vector3.new(196, 3, -20), pts = { { 300, -20 }, { 400, -20 }, { 500, -20 }, { 540, -20 }, { 590, -62 } } },
	W_Gantry = { start = Vector3.new(-231, 27, 32), pts = { { -320, 32 }, { -420, 32 }, { -520, 32 }, { -620, 32 }, { -720, 32 }, { -762, 32 }, { -812, 32 }, { -820, 32 }, { -805, 52 }, { -772, 52 }, { -700, 52 }, { -640, 40 } } },
	-- v8 elevated paths (same start points as v7 N/W/E_Elevated)
	N_Elevated = { start = Vector3.new(-65, 27, -231), pts = { { -65, -300 }, { -65, -400 }, { -70, -490 }, { -70, -506 }, { -57.5, -506 }, { -57.5, -514 }, { -57.5, -566 }, { 15, -598 } } },
	W_Elevated = { start = Vector3.new(-231, 27, 32), pts = { { -320, 32 }, { -412, 32 }, { -412, 46 }, { -430, 50 }, { -478, 50 }, { -500, 46 }, { -560, 36 }, { -600, 32 } } },
	E_Elevated = { start = Vector3.new(232, 27, 90), pts = { { 330, 90 }, { 430, 90 }, { 530, 90 }, { 600, 92 }, { 600, 64 }, { 620, 60 }, { 620, 2 }, { 620, -5 }, { 570, 10 } } },
	-- v8 junctions / drop-down (prove the split points connect both levels)
	N_Junction = { start = Vector3.new(-65, 27, -231), pts = { { -65, -300 }, { -65, -386 }, { -45, -386 }, { 10, -386 }, { 42, -386 }, { 65, -386 }, { 65, -420 }, { 30, -478 }, { 0, -510 }, { 20, -540 }, { 15, -598 } } },
	E_Junction = { start = Vector3.new(232, 27, 90), pts = { { 330, 90 }, { 417, 90 }, { 417, 70 }, { 417, 17 }, { 417, -5 }, { 417, -20 }, { 500, -20 }, { 540, -20 }, { 590, -62 } } },
	E_RingDrop = { start = Vector3.new(230, 27, -20), pts = { { 252, -20 }, { 300, -20 }, { 400, -20 }, { 500, -20 }, { 540, -20 }, { 590, -62 } } },
}
_G.MAP1_RUNWALK = function(order)
	_G.MAP1_WALK = { state = "running", results = {} }
	local ok, err = pcall(function()
		local plr = game.Players:GetPlayers()[1]
		for _, name in order do
			local r = _G.MAP1_ROUTES[name]
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local res = { route = name, legs = {}, role = plr:GetAttribute("WORLD_EXE_Role") }
			if not (hum and hrp and hum.Health > 0) then
				res.error = "no live character"
				table.insert(_G.MAP1_WALK.results, res)
				continue
			end
			char:PivotTo(CFrame.new(r.start))
			task.wait(1.0)
			local total, dist = 0, 0
			local prev = hrp.Position
			for i, pt in r.pts do
				local target = Vector3.new(pt[1], hrp.Position.Y, pt[2])
				local done, reached = false, false
				local conn = hum.MoveToFinished:Connect(function(r2)
					done, reached = true, r2
				end)
				local t0 = os.clock()
				hum:MoveTo(target)
				local function xz()
					local p = hrp.Position
					return (Vector3.new(p.X, 0, p.Z) - Vector3.new(pt[1], 0, pt[2])).Magnitude
				end
				while not done and os.clock() - t0 < 8.5 do
					if xz() < 2.5 then
						reached = true
						break
					end
					task.wait(0.05)
				end
				conn:Disconnect()
				local dt = os.clock() - t0
				local p = hrp.Position
				local miss = xz()
				total += dt
				dist += (Vector3.new(p.X, 0, p.Z) - Vector3.new(prev.X, 0, prev.Z)).Magnitude
				prev = p
				table.insert(res.legs, { i = i, t = math.floor(dt * 100) / 100, reached = reached, miss = math.floor(miss * 10) / 10, y = math.floor(p.Y * 10) / 10 })
				if not reached or miss > 4 then
					res.stuckAt = { math.floor(p.X), math.floor(p.Y), math.floor(p.Z) }
					break
				end
			end
			res.seconds = math.floor(total * 10) / 10
			res.studs = math.floor(dist)
			res.finalPos = { math.floor(hrp.Position.X), math.floor(hrp.Position.Y), math.floor(hrp.Position.Z) }
			res.completed = res.stuckAt == nil
			res.roleAfter = plr:GetAttribute("WORLD_EXE_Role")
			res.health = hum.Health
			table.insert(_G.MAP1_WALK.results, res)
		end
	end)
	_G.MAP1_WALK.state = ok and "done" or ("error: " .. tostring(err))
end
task.spawn(_G.MAP1_RUNWALK, _G.MAP1_WALK_ROUTES or { "N_Ground", "N_Elevated", "W_Ground", "W_Elevated", "E_Ground", "E_Elevated", "W_Gantry", "N_Junction", "E_Junction", "E_RingDrop" })

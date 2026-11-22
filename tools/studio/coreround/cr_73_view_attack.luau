-- Core Round Step 1E security gate (closeout revision): Play-client ADVERSARIAL harness for the reported view (paste into the
-- CLIENT datamodel of a solo Play session). It plays the role of a modified client: it fires the real "throw" request
-- directly with a forged `view` (and optionally a forged `t0`), using positions this client actually DREW for the
-- moving dummy in the past (exactly what a cheat could record). Server side, set Workspace attribute
-- CR_ViewTestDummies = true (Studio only) so the dummy counts as a view target, and D-MOVING CR_MoveSpeed = 50
-- (slide speed). Results are read from the server log (CoreRoundTest "Log": throw_view / throw / hit by n).
--   _G.ATK(past, back, opts) -> waits until the dummy is `past` studs beyond the z = -38 crossing and moving away,
--     then throws straight across its path from 6 studs away. back = seconds of drawn history to claim (0 = honest).
--     opts.t0 = seconds to subtract from the release timestamp (forged stale/future t0; negative = future)
--     opts.view = raw view table to send instead (invalid / duplicate / missing tests)
local Pl = game:GetService("Players")
local RS = game:GetService("RunService")
local P = Pl.LocalPlayer
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
local CoreNet = require(game:GetService("ReplicatedStorage"):FindFirstChild("CoreNet", true))
local Req = CoreNet.Request()
local dm = workspace.CoreRoundYard.Dummies["D-MOVING"]
local H = {}
if _G.VA_CONN then
	_G.VA_CONN:Disconnect()
end
_G.VA_CONN = RS.Heartbeat:Connect(function()
	table.insert(H, { t = os.clock(), p = dm.HumanoidRootPart.Position })
	if #H > 240 then
		table.remove(H, 1)
	end
end)
_G.VA_SEQ = _G.VA_SEQ or 9000
_G.ATK = function(past: number, back: number, opts: any?)
	opts = opts or {}
	local hrp = P.Character.HumanoidRootPart
	local y = hrp.Position.Y
	hrp.CFrame = CFrame.lookAt(Vector3.new(74, y, -38), Vector3.new(80, y, -38))
	hrp.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.8)
	local prev = dm.HumanoidRootPart.Position.Z + 38
	local t0 = os.clock()
	while os.clock() - t0 < 6 do
		RS.Heartbeat:Wait()
		local dz = dm.HumanoidRootPart.Position.Z + 38
		if math.abs(dz) >= past and math.abs(prev) < past and math.abs(dz) > math.abs(prev) then
			break
		end
		prev = dz
	end
	local now = os.clock()
	local pos = H[#H].p
	if back > 0 then
		for i = #H, 1, -1 do
			if now - H[i].t >= back then
				pos = H[i].p
				break
			end
		end
	end
	_G.VA_SEQ += 1
	local payload = { n = _G.VA_SEQ, origin = hrp.Position + Vector3.new(0, 1, 0), dir = Vector3.xAxis, charge = 0, view = opts.view or { { "D-MOVING", pos } } }
	if opts.t0 then
		payload.t0 = workspace:GetServerTimeNow() - opts.t0
	end
	if opts.noView then
		payload.view = nil
	end
	Req:FireServer("throw", payload)
	return { n = _G.VA_SEQ, drawnDz = dm.HumanoidRootPart.Position.Z + 38, claimDz = pos.Z + 38 }
end
-- Step 1E closeout: paired sweep. For each lead distance `past` it throws with the honest view, a 0.3 s forged view,
-- no view and an invalid view, `reps` times each (conditions interleaved so dummy timing is shared). Returns the seq
-- numbers per condition; join them with the server log (throw_view rewindPlayers / hit) to compare outcomes.
_G.ATKSWEEP = function(pasts: { number }, reps: number)
	local out = {}
	for _, past in pasts do
		for r = 1, reps do
			for _, cond in { "honest", "forged", "none", "invalid" } do
				local res
				if cond == "honest" then
					res = _G.ATK(past, 0)
				elseif cond == "forged" then
					res = _G.ATK(past, 0.3)
				elseif cond == "none" then
					res = _G.ATK(past, 0, { noView = true })
				else
					res = _G.ATK(past, 0, { view = { { "D-MOVING", Vector3.new(0 / 0, 0, 0) }, "x", { "D-MOVING", Vector3.zero } } })
				end
				table.insert(out, { cond = cond, past = past, n = res.n })
				task.wait(0.9)
			end
		end
	end
	_G.SWEEP = out
	return #out
end
-- sustained forgery: `count` throws in a row, every one claiming `back` s of drawn history (the 615ac22 drift attack)
_G.ATKDRIFT = function(past: number, back: number, count: number)
	local ns = {}
	for _ = 1, count do
		table.insert(ns, _G.ATK(past, back).n)
		task.wait(0.9)
	end
	_G.DRIFT = ns
	return #ns
end
return "view attack harness ready"

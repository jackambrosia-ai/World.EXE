--!nonstrict
-- Wrist-hacking prototype TEST KIT (Studio Play, CLIENT DataModel). Drives hacks through the SAME
-- remote and payloads the wrist terminal sends, and solves (or deliberately fails) the server's
-- challenges from the snapshots it receives. Results go to _G.HT.
--   _G.HackRun(hackId, targetId?, mode, opts) -> starts; poll _G.HT.done
--     mode: "solve" | "wrong" (all wrong arrows) | "idle" (no input -> timeout) | "cancel"
--     opts.delay: seconds between presses (default 0.18); opts.source / opts.text for typed runs
local RS = game:GetService("ReplicatedStorage")
local remotes = RS.WORLD_EXE.HackRemotes
local req, ev = remotes.HackRequest, remotes.HackEvent
local OTHER = { U = "D", D = "U", L = "R", R = "L" }
_G.HT = { done = true }
local current = nil
_G.HO = {} -- every incoming / incoming_result / hack_outcome event this client saw
ev.OnClientEvent:Connect(function(d)
	if d.op == "incoming" or d.op == "incoming_result" or d.op == "hack_outcome" or d.op == "boss" or d.op == "station" then
		table.insert(_G.HO, string.format("%.2f %s %s %s", workspace:GetServerTimeNow() % 1000, d.op, tostring(d.outcome or d.event or d.hackId or d.text), tostring(d.role or "")))
	end
	local h = _G.HT
	if not h or h.done then return end
	table.insert(h.log, string.format("%.2f %s %s", os.clock() - h.t0, tostring(d.op), d.op == "result" and (tostring(d.ok) .. " " .. tostring(d.reason)) or (d.op == "challenge_end" and tostring(d.result) or "")))
	if d.op == "challenge" then
		h.token = d.token
		h.snap = d.snap
		h.kind = d.snap.kind
	elseif d.op == "result" then
		h.result = d
		h.done = true
		h.seconds = os.clock() - h.t0
	end
end)
_G.HackRun = function(hackId, targetId, mode, opts)
	opts = opts or {}
	_G.HT = { done = false, log = {}, t0 = os.clock(), presses = 0 }
	local h = _G.HT
	req:FireServer({ op = "begin", hackId = hackId, targetId = targetId, source = opts.source or "chip", text = opts.text, dir = opts.dir })
	task.spawn(function()
		local delay = opts.delay or 0.18
		local lastSent = {}
		while not h.done and os.clock() - h.t0 < 20 do
			local s = h.snap
			if s and h.token then
				if mode == "cancel" then
					req:FireServer({ op = "cancel" })
					task.wait(0.5)
				elseif mode == "idle" then
					task.wait(0.1)
				elseif s.kind == "SignalLock" then
					-- press the first pending signal when it arrives (server clock)
					for i, sig in ipairs(s.signals) do
						if sig.state == "pending" and not lastSent[i] then
							local wait = sig.t - workspace:GetServerTimeNow() + (opts.lockBias or 0)
							if wait > 0 then task.wait(wait) end
							lastSent[i] = true
							local d = if mode == "wrong" then OTHER[sig.d] else sig.d
							req:FireServer({ op = "input", token = h.token, dir = d, t = workspace:GetServerTimeNow(), n = (opts.fixedN or (h.presses + 1)) })
							h.presses += 1
							break
						end
					end
					task.wait(0.03)
				else
					local nextDir
					if s.kind == "InputChase" then nextDir = s.seq[1] else nextDir = s.seq[s.index] end
					if nextDir then
						local d = if mode == "wrong" then OTHER[nextDir] else nextDir
						h.snap = nil -- wait for the server's next snapshot before pressing again
						req:FireServer({ op = "input", token = h.token, dir = d, t = workspace:GetServerTimeNow(), n = (opts.fixedN or (h.presses + 1)) })
						h.presses += 1
					end
					task.wait(delay)
				end
			else
				task.wait(0.03)
			end
		end
		h.done = true
	end)
	return "running " .. hackId
end
return "testkit ready"

--!strict
-- MovementService (wrist-hacking prototype, server) — Rev 15, owner-authorized 2026-11-16.
-- Fast baseline run + two-stage Q: first Q = short grounded dash; a SECOND, separate Q pressed
-- between SuperMin and SuperMax seconds after the dash = ~1 s steerable super-speed (long cooldown).
--
-- Server-authoritative timing and cooldowns (the client only reports "Q pressed", with an increasing
-- sequence number). The CLIENT executes the motion because it owns its character's physics.
--   t - dashT <  SuperMin  -> too early: ignored AND the window is voided (spamming can't slide into it)
--   SuperMin <= t - dashT <= SuperMax and window not voided -> super-speed (if its cooldown is ready)
--   otherwise -> a fresh first Q (dash, if the dash cooldown is ready)
-- Cooldown state is keyed by Player, so respawning does not reset it.
-- Rejected while frozen, ragdolled, held by a grab, or dead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HackCatalog = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("HackCatalog"))
local A = HackCatalog.Attr

local MovementService = {}

type State = {
	dashT: number?,
	voided: boolean,
	dashReady: number,
	superReady: number,
	superUntil: number,
	lastN: number,
	log: { string },
}
local states: { [Player]: State } = {}
local send: (Player, { [string]: any }) -> () = function() end
local logEvent: (string) -> () = function() end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function tune(key: string): number
	return HackCatalog.Tune("Move", key)
end

local function stateOf(player: Player): State
	local s = states[player]
	if not s then
		s = { dashT = nil, voided = false, dashReady = 0, superReady = 0, superUntil = 0, lastN = 0, log = {} }
		states[player] = s
	end
	return s
end

local function note(s: State, line: string)
	table.insert(s.log, line)
	if #s.log > 40 then
		table.remove(s.log, 1)
	end
end

local function blocked(player: Player): string?
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not c or not hum or hum.Health <= 0 then
		return "not_alive"
	end
	local t = now()
	local fu = c:GetAttribute(A.FrozenUntil)
	if typeof(fu) == "number" and fu > t then
		return "frozen"
	end
	local ru = c:GetAttribute(A.RagdollUntil)
	if typeof(ru) == "number" and ru > t then
		return "ragdolled"
	end
	return nil
end

local function publish(player: Player, s: State)
	player:SetAttribute("WORLD_EXE_DashReady", s.dashReady)
	player:SetAttribute("WORLD_EXE_SuperReady", s.superReady)
end

-- One Q press from the client. p = { op = "q", n = number }
function MovementService.Q(player: Player, p: { [string]: any })
	local s = stateOf(player)
	if typeof(p.n) ~= "number" or p.n <= s.lastN or p.n > s.lastN + 50 then
		return -- replayed / duplicated packet (key repeat sends nothing new)
	end
	s.lastN = p.n
	local t = now()
	local why = blocked(player)
	if why then
		note(s, string.format("%.3f Q rejected (%s)", t, why))
		return
	end
	if s.superUntil > t then
		note(s, string.format("%.3f Q ignored (already super)", t))
		return
	end
	local dt = if s.dashT then t - (s.dashT :: number) else math.huge
	if dt < tune("SuperMin") then
		s.voided = true -- too early: this window is gone
		note(s, string.format("%.3f Q too early (+%.3f) -> window voided", t, dt))
		send(player, { op = "move_fx", kind = "early" })
		return
	end
	if dt <= tune("SuperMax") and not s.voided then
		s.dashT = nil
		if s.superReady > t then
			note(s, string.format("%.3f Q in window (+%.3f) but super cooling (%.1f s)", t, dt, s.superReady - t))
			send(player, { op = "move_fx", kind = "super_cooldown", readyAt = s.superReady })
			return
		end
		local secs = tune("SuperSeconds")
		s.superUntil = t + secs
		s.superReady = t + tune("SuperCooldown")
		publish(player, s)
		local c = player.Character
		if c then
			c:SetAttribute("WORLD_EXE_SuperUntil", s.superUntil) -- every client draws the afterimages
		end
		send(player, { op = "super", seconds = secs, speed = tune("SuperSpeed"), turn = tune("SuperTurnRate") })
		note(s, string.format("%.3f SUPER (+%.3f after dash) for %.2f s; next at +%.1f", t, dt, secs, tune("SuperCooldown")))
		logEvent(string.format("%s super-speed (+%.2f s after dash)", player.Name, dt))
		return
	end
	-- a fresh first Q
	if s.dashReady > t then
		note(s, string.format("%.3f Q ignored (dash cooling %.2f s)", t, s.dashReady - t))
		return
	end
	s.dashT = t
	s.voided = false
	s.dashReady = t + tune("DashCooldown")
	publish(player, s)
	local c = player.Character
	if c then
		c:SetAttribute("WORLD_EXE_DashUntil", t + tune("DashSeconds"))
	end
	send(player, { op = "dash", seconds = tune("DashSeconds"), speed = tune("DashSpeed"), windowMin = tune("SuperMin"), windowMax = tune("SuperMax"), superReady = s.superReady })
	note(s, string.format("%.3f DASH", t))
end

function MovementService.Log(player: Player): { string }
	return stateOf(player).log
end

function MovementService.Reset(player: Player)
	states[player] = nil
end

local function applyRun(character: Model)
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	task.wait(0.5) -- after other spawn scripts have set their defaults
	if hum.Parent then
		hum.WalkSpeed = tune("RunSpeed")
	end
end

function MovementService.Start(deps: { send: (Player, { [string]: any }) -> (), log: (string) -> () })
	send = deps.send
	logEvent = deps.log
	local function hook(player: Player)
		if player.Character then
			task.spawn(applyRun, player.Character)
		end
		player.CharacterAdded:Connect(function(c)
			applyRun(c)
		end)
	end
	for _, pl in Players:GetPlayers() do
		hook(pl)
	end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(pl)
		states[pl] = nil
	end)
end

return MovementService

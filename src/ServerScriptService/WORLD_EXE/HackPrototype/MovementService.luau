--!strict
-- MovementService (wrist-hacking prototype, server) — Rev 15j owner design 2026-11-16; Rev 15l chaining
-- (Q during a super-speed starts the next one if a diamond is left); Rev 15m: the dash message carries the
-- check's server start time (check.startAt) so the client draws the sweep on the judge's clock.
-- Fast baseline run + Q:
--   Q (dash ready)           -> grounded dash, and a SKILL CHECK starts: a marker sweeps across a bar in
--                               CheckSweepSeconds; the target zone (CheckZoneSeconds wide) sits at a random
--                               spot each time. One Q inside the zone = HIT: +1 super charge (a diamond,
--                               max SuperChargesMax). A Q outside it, or no Q, = miss. One attempt per dash.
--   Q while the dash is cooling (skill check over) -> SUPER-SPEED if a charge is stored (uses one);
--                               otherwise a soft "no charge" tick.
-- Server-authoritative: the client only reports "Q pressed" (sequence-numbered); the server judges the
-- skill check on its own clock (a small LatencyAllowance after the zone), stores charges and cooldowns per
-- Player (respawns do not reset them), and publishes WORLD_EXE_SuperCharges for the diamond UI.
-- The CLIENT executes the motion because it owns its character's physics.
-- Rejected while frozen, ragdolled, held by a grab, or dead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HackCatalog = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("HackCatalog"))
local A = HackCatalog.Attr

local MovementService = {}

type Check = { start: number, zoneA: number, zoneB: number, done: boolean }
type State = {
	dashReady: number,
	superUntil: number,
	superStart: number,
	charges: number, -- stored super charges (diamonds)
	check: Check?, -- the skill check of the last dash
	lastN: number,
	log: { string },
}
local states: { [Player]: State } = {}
local send: (Player, { [string]: any }) -> () = function() end
local logEvent: (string) -> () = function() end
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function tune(key: string): number
	return HackCatalog.Tune("Move", key)
end

local function stateOf(player: Player): State
	local s = states[player]
	if not s then
		s = { dashReady = 0, superUntil = 0, superStart = 0, charges = 0, check = nil, lastN = 0, log = {} }
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
	player:SetAttribute("WORLD_EXE_SuperCharges", s.charges)
end

-- the skill check is open from its start until the marker finishes its sweep (+ latency allowance)
local function checkOpen(s: State, t: number): boolean
	local ck = s.check
	return ck ~= nil and not ck.done and t <= ck.start + tune("CheckSweepSeconds") + tune("CheckLatency")
end

local function startSuper(player: Player, s: State, t: number, chained: boolean)
	s.charges -= 1
	local secs = tune("SuperSeconds")
	s.superStart = t
	s.superUntil = t + secs
	publish(player, s)
	local c = player.Character
	if c then
		c:SetAttribute("WORLD_EXE_SuperUntil", s.superUntil) -- every client draws the afterimages
	end
	send(player, { op = "super", seconds = secs, speed = tune("SuperSpeed"), turn = tune("SuperTurnRate"), charges = s.charges, chained = chained })
	note(s, string.format("%.3f SUPER%s for %.2f s (charges left %d)", t, if chained then " (chained)" else "", secs, s.charges))
	logEvent(string.format("%s super-speed (charges left %d)", player.Name, s.charges))
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
		-- Rev 15l (owner: "super dashes should be able to be used in quick succession"): a Q during a
		-- super-speed starts the next one at once if a diamond is left (min SuperChainMinGap after the
		-- last start, so one accidental double-tap does not spend both diamonds)
		if s.charges > 0 and t - s.superStart >= tune("SuperChainMinGap") then
			startSuper(player, s, t, true)
			return
		end
		note(s, string.format("%.3f Q ignored (super running; charges %d)", t, s.charges))
		if s.charges <= 0 then
			send(player, { op = "move_fx", kind = "no_charge", readyAt = s.dashReady })
		end
		return
	end
	-- 1) skill check attempt (one per dash)
	if checkOpen(s, t) then
		local ck = s.check :: Check
		ck.done = true
		local rel = t - ck.start
		local hit = rel >= ck.zoneA and rel <= ck.zoneB + tune("CheckLatency") -- Rev 15k: no early tolerance
		if hit then
			s.charges = math.min(s.charges + 1, math.floor(tune("SuperChargesMax")))
			publish(player, s)
			note(s, string.format("%.3f CHECK HIT at %.3f (zone %.3f-%.3f) -> charges %d", t, rel, ck.zoneA, ck.zoneB, s.charges))
		else
			note(s, string.format("%.3f CHECK MISS at %.3f (zone %.3f-%.3f)", t, rel, ck.zoneA, ck.zoneB))
		end
		send(player, { op = "move_fx", kind = if hit then "check_hit" else "check_miss", charges = s.charges, at = rel })
		return
	end
	-- 2) dash cooling: super-speed on a stored charge
	if s.dashReady > t then
		if s.charges <= 0 then
			note(s, string.format("%.3f Q no charge (dash cooling %.2f s)", t, s.dashReady - t))
			send(player, { op = "move_fx", kind = "no_charge", readyAt = s.dashReady })
			return
		end
		startSuper(player, s, t, false)
		return
	end
	-- 3) dash + a new skill check
	s.dashReady = t + tune("DashCooldown")
	local sweep = tune("CheckSweepSeconds")
	local zone = tune("CheckZoneSeconds")
	local zoneA = rng:NextNumber(tune("CheckZoneEarliest"), math.max(tune("CheckZoneEarliest"), sweep - zone - 0.05))
	s.check = { start = t + tune("CheckDelay"), zoneA = zoneA, zoneB = zoneA + zone, done = false }
	publish(player, s)
	local c = player.Character
	if c then
		c:SetAttribute("WORLD_EXE_DashUntil", t + tune("DashSeconds"))
	end
	send(player, { op = "dash", seconds = tune("DashSeconds"), speed = tune("DashSpeed"), dashReady = s.dashReady, charges = s.charges,
		check = { delay = tune("CheckDelay"), sweep = sweep, zoneA = zoneA, zoneB = zoneA + zone, startAt = (s.check :: Check).start } })
	note(s, string.format("%.3f DASH; check zone %.3f-%.3f of %.2f s", t, zoneA, zoneA + zone, sweep))
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
	-- Rev 15g: afterimage clones keep a Humanoid (so clothing renders) and Humanoids force their body parts
	-- collidable every frame, which made the clones posed at the runner bump them (measured: 74 <-> 28
	-- studs/s flicker). Clones go in this group, which collides with nothing.
	local PhysicsService = game:GetService("PhysicsService")
	pcall(function()
		PhysicsService:RegisterCollisionGroup("WORLD_EXE_Afterimage")
	end)
	for _, g in PhysicsService:GetRegisteredCollisionGroups() do
		pcall(function()
			PhysicsService:CollisionGroupSetCollidable("WORLD_EXE_Afterimage", g.name, false)
		end)
	end
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

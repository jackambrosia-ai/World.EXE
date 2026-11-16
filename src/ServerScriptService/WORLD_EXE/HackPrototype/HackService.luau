--!strict
-- HackService (wrist-hacking prototype, server). Personal player hacks, fully separate from the
-- Architect patch system (own remotes, catalog, cooldowns; never consults Architect turns).
--
-- Protocol (ReplicatedStorage.WORLD_EXE.HackRemotes):
--   HackRequest (client -> server), intent only:
--     { op = "begin", hackId, targetId?, source = "chip" | "typed", text?, dir? }
--     { op = "input", token, dir = "U"|"D"|"L"|"R", t? (client server-clock press time) }
--     { op = "cancel" }
--   HackEvent (server -> one client):
--     result / challenge / challenge_end / fling_self / ragdoll / frozen
-- Validation on "begin": rate limit, payload shape, known hack id, typed text re-parsed to the same
-- id, living hacker who is not frozen or ragdolled, no challenge already running, per-hack cooldown
-- and retry delay, target resolved server-side (never self), alive, in range, line of sight, not
-- already frozen / ragdolled / immune. Then the challenge (none / sequence / boss variant) runs here;
-- on success the target is re-validated (range x1.3) and the effect applied. Cooldown starts only
-- when an effect is applied; a failed or cancelled challenge only costs RetrySeconds.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local sharedRoot = ReplicatedStorage:WaitForChild("WORLD_EXE")
local HackCatalog = require(sharedRoot:WaitForChild("Shared"):WaitForChild("HackCatalog"))
local HackTargets = require(script.Parent:WaitForChild("HackTargets"))
local HackEffects = require(script.Parent:WaitForChild("HackEffects"))
local HackChallenges = require(script.Parent:WaitForChild("HackChallenges"))
local Conductor = require(script.Parent:WaitForChild("ConductorPrototype"))
local HackDevice = require(script.Parent:WaitForChild("HackDevice"))
local HackIncoming = require(script.Parent:WaitForChild("HackIncoming"))

local A = HackCatalog.Attr
local T = HackCatalog.Tuning
local CH = HackCatalog.Challenge

local TICK = 0.05
local RESIST_SEND_EVERY = 0.15

type Session = {
	token: number,
	hackId: string,
	targetId: string?,
	targetKind: string,
	challenge: HackChallenges.Session,
	dir: Vector3?,
	lastSent: number,
	source: string,
	lastN: number, -- replay protection: input sequence numbers must increase
}

local HackService = {}

local requestRemote: RemoteEvent
local eventRemote: RemoteEvent
local sessions: { [Player]: Session } = {}
local ready: { [Player]: { [string]: number } } = {}
local retry: { [Player]: { [string]: number } } = {}
local buckets: { [Player]: { tokens: number, t: number } } = {}
-- FLING aim (owner 2026-11-16: "in the direction the cursor moves after casting"). After a FLING on
-- someone else is cast, a flick window opens (the warning window for players/NPCs, BossFlickWindow
-- for the boss). The client turns the direction of its mouse MOVEMENT into a horizontal world
-- direction and streams it; aims from before the cast are discarded. The latest one is read when
-- the throw happens. No flick: thrown straight away from the attacker.
local AIM_MIN_INTERVAL = 0.08 -- seconds between accepted aim updates (they bypass the input bucket)
local AIM_MAX_AGE = 3 -- the client re-sends every 1 s while aiming
local aims: { [Player]: { dir: Vector3, t: number } } = {}
local function setAim(player: Player, v: any): boolean
	if typeof(v) ~= "Vector3" or v.X ~= v.X or v.Z ~= v.Z then
		return false
	end
	local h = Vector3.new(v.X, 0, v.Z)
	if h.Magnitude < 0.1 or h.Magnitude > 1e4 then
		return false
	end
	local a = aims[player]
	local t = os.clock()
	if a and t - a.t < AIM_MIN_INTERVAL then
		return false
	end
	aims[player] = { dir = h.Unit, t = t }
	return true
end
local function getAim(player: Player): Vector3?
	local a = aims[player]
	if a and os.clock() - a.t <= AIM_MAX_AGE then
		return a.dir
	end
	return nil
end
local tokenSeq = 0
local rng = Random.new()
local events: { string } = {}
-- Lightweight profiling of the hot paths (Studio hook "Perf"; also MicroProfiler labels).
local perf: { [string]: { n: number, total: number, max: number } } = {}
local function timed<T...>(name: string, fn: () -> T...): T...
	debug.profilebegin("Hack." .. name)
	local t0 = os.clock()
	local r = table.pack(fn())
	local ms = (os.clock() - t0) * 1000
	debug.profileend()
	local p = perf[name] or { n = 0, total = 0, max = 0 }
	p.n += 1
	p.total += ms
	p.max = math.max(p.max, ms)
	perf[name] = p
	return table.unpack(r, 1, r.n)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function logEvent(s: string)
	table.insert(events, string.format("%.2f %s", os.clock(), s))
	if #events > 200 then
		table.remove(events, 1)
	end
end

local function send(player: Player, payload: { [string]: any })
	if player.Parent then
		eventRemote:FireClient(player, payload)
	end
end

local function rateOk(player: Player): boolean
	local b = buckets[player]
	local t = os.clock()
	if not b then
		b = { tokens = T.Rate.Burst, t = t }
		buckets[player] = b
	end
	b.tokens = math.min(T.Rate.Burst, b.tokens + (t - b.t) * T.Rate.PerSecond)
	b.t = t
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

local function reply(player: Player, hackId: string?, ok: boolean, reason: string, text: string?)
	send(player, { op = "result", ok = ok, reason = reason, hackId = hackId, text = text, readyAt = hackId and ready[player] and ready[player][hackId] or nil })
	logEvent(string.format("%s %s %s %s", player.Name, tostring(hackId), if ok then "OK" else "REJECT", reason))
end

local function characterState(player: Player): (Model?, string?)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not c or not hum or not root or hum.Health <= 0 then
		return nil, "not_alive"
	end
	if HackEffects.IsFrozen(c) then
		return nil, "you_are_frozen"
	end
	if HackEffects.IsRagdolled(c) then
		return nil, "you_are_ragdolled"
	end
	return c, nil
end

local function bossState(): string
	return Conductor.State()
end

-- Target checks shared by "begin" and the post-challenge re-validation.
local function checkTarget(player: Player, character: Model, hackId: string, targetId: any, rangeMult: number): (HackTargets.Target?, string?)
	local target = HackTargets.Resolve(targetId)
	if not target then
		return nil, "no_target"
	end
	if target.Player == player or target.Model == character then
		return nil, "cannot_target_self"
	end
	local range = if hackId == "FREEZE" then HackCatalog.Tune("Freeze", "Range") else HackCatalog.Tune("FlingTarget", "Range")
	local myRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if (target.Root.Position - myRoot.Position).Magnitude > range * rangeMult then
		return nil, "out_of_range"
	end
	if T.LineOfSight and not HackTargets.LineOfSight(character, target) then
		return nil, "no_line_of_sight"
	end
	local t = now()
	if HackIncoming.IsTargeted(target.Model) then
		return nil, "target_busy"
	end
	if target.Kind == "boss" then
		local st = Conductor.State()
		if st == "OFFLINE" or st == "DEFEATED" then
			return nil, "boss_offline"
		end
		local m = target.Model
		if hackId == "FREEZE" and (m:GetAttribute(A.FreezeImmuneUntil) or 0) > t then
			return nil, "target_immune"
		end
		if hackId == "FLING_TARGET" and (m:GetAttribute(A.FlingImmuneUntil) or 0) > t then
			return nil, "target_immune"
		end
		return target, nil
	end
	local m = target.Model
	if hackId == "FREEZE" then
		if HackEffects.IsFrozen(m) then
			return nil, "already_frozen"
		end
		if HackEffects.IsRagdolled(m) then
			return nil, "target_busy"
		end
		if (m:GetAttribute(A.FreezeImmuneUntil) or 0) > t then
			return nil, "target_immune"
		end
	elseif hackId == "FLING_TARGET" then
		if HackEffects.IsRagdolled(m) then
			return nil, "already_ragdolled"
		end
		if HackEffects.IsFrozen(m) then
			return nil, "target_frozen"
		end
		if (m:GetAttribute(A.FlingImmuneUntil) or 0) > t then
			return nil, "target_immune"
		end
	end
	return target, nil
end

local function setReady(player: Player, hackId: string, seconds: number)
	ready[player] = ready[player] or {}
	local at = now() + seconds
	ready[player][hackId] = at
	player:SetAttribute(A.ReadyPrefix .. hackId, at)
end

local function cooldownOf(hackId: string): number
	local group = if hackId == "FLING_SELF" then "FlingSelf" elseif hackId == "FLING_TARGET" then "FlingTarget" elseif hackId == "FREEZE" then "Freeze" else "Shield"
	return HackCatalog.Tune(group, "Cooldown")
end

local function apply(player: Player, hackId: string, targetId: string?, dir: Vector3?): (boolean, string, string?)
	local character, why = characterState(player)
	if not character then
		return false, why :: string, nil
	end
	local ok, reason, text = false, "no_effect", nil
	if hackId == "FLING_SELF" then
		ok, reason = HackEffects.FlingSelf(player, dir)
		text = "Launched."
	elseif hackId == "SHIELD" then
		ok, reason = HackEffects.Shield(player)
		text = "Shield up for 6 s."
	else
		local target, terr = checkTarget(player, character, hackId, targetId, 1.3)
		if not target then
			return false, terr :: string, nil
		end
		if target.Kind == "boss" then
			local myRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart
			if hackId == "FLING_TARGET" then
				-- flick window: the throw happens BossFlickWindow after the cast, in the flicked direction
				local window = HackCatalog.Tune("FlingTarget", "BossFlickWindow")
				aims[player] = nil
				send(player, { op = "flick", target = target.Model, boss = true, untilT = now() + window })
				task.delay(window, function()
					local c = player.Character
					local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
					local bossAim = getAim(player)
					logEvent(if bossAim then string.format("boss fling aim (%.2f, %.2f)", bossAim.X, bossAim.Z) else "boss fling aim none -> away from attacker")
					local okB, why = Conductor.ApplyHack(hackId, if r then r.Position else myRoot.Position, bossAim)
					aims[player] = nil
					if not okB then
						reply(player, hackId, false, why)
					end
				end)
				ok, reason, text = true, "applied", "Flick the mouse to aim the throw."
			else
				ok, text = Conductor.ApplyHack(hackId, myRoot.Position, nil)
				reason = if ok then "applied" else text :: string
				if not ok then
					text = nil
				end
			end
		else
			-- Targeted hack on a player / NPC: warning + counterplay window, resolved by HackIncoming.
			local okI, whyI = HackIncoming.Start(player, hackId, target, function(t, from)
				if hackId == "FREEZE" then
					return HackEffects.Freeze(t)
				end
				local aim = getAim(player) -- read at resolve time: the flick made during the window
				aims[player] = nil
				logEvent(if aim then string.format("fling aim (%.2f, %.2f)", aim.X, aim.Z) else "fling aim none -> away from attacker")
				return HackEffects.FlingTarget(t, from, aim)
			end)
			if okI and hackId == "FLING_TARGET" then
				aims[player] = nil -- only flicks made after the cast count
				send(player, { op = "flick", target = target.Model, boss = false,
					untilT = now() + HackCatalog.Tune("Incoming", "ReactionWindow") + HackCatalog.Tune("Incoming", "LatencyGrace") })
			end
			if okI then
				setReady(player, hackId, cooldownOf(hackId)) -- the attempt costs the cooldown even if defended
				HackDevice.SetState(player.Character, "hacking")
				return true, "incoming", "Hack sent — the target can still defend."
			end
			ok, reason = false, whyI
		end
	end
	if ok then
		setReady(player, hackId, cooldownOf(hackId))
		HackDevice.SetState(player.Character, "ok")
		return true, "applied", text
	end
	HackDevice.SetState(player.Character, "fail")
	return false, reason or "no_effect", nil
end

local function endSession(player: Player, result: string)
	local s = sessions[player]
	if not s then
		return
	end
	sessions[player] = nil
	send(player, { op = "challenge_end", token = s.token, result = result })
	logEvent(string.format("%s challenge %s %s -> %s (misses %d)", player.Name, s.challenge.Kind, s.hackId, result, s.challenge.Misses))
	if result == "success" then
		local ok, reason, text = apply(player, s.hackId, s.targetId, s.dir)
		reply(player, s.hackId, ok, reason, text)
	else
		HackDevice.SetState(player.Character, "fail")
		retry[player] = retry[player] or {}
		retry[player][s.hackId] = now() + (HackCatalog.Tuning :: any).RetrySeconds
		reply(player, s.hackId, false, result, nil)
	end
end

local function sendSnapshot(player: Player, s: Session)
	local snap = HackChallenges.Snapshot(s.challenge, now())
	send(player, { op = "challenge", token = s.token, hackId = s.hackId, targetId = s.targetId, snap = snap })
	s.lastSent = os.clock()
end

local function begin(player: Player, p: { [string]: any })
	local hackId = p.hackId
	if typeof(hackId) ~= "string" or #hackId > 32 then
		return reply(player, nil, false, "bad_payload")
	end
	local def = HackCatalog.Get(hackId)
	if not def then
		return reply(player, nil, false, "unknown_hack")
	end
	local source = p.source
	if source ~= "chip" and source ~= "typed" and source ~= "quick" then
		return reply(player, hackId, false, "bad_payload")
	end
	if source == "typed" then
		-- The typed path must reach the same hack through the same parser.
		local parsed = HackCatalog.Parse(p.text, p.targetId ~= nil)
		if parsed ~= hackId then
			return reply(player, hackId, false, "parse_mismatch")
		end
	end
	if sessions[player] then
		return reply(player, hackId, false, "busy")
	end
	local character, why = characterState(player)
	if not character then
		return reply(player, hackId, false, why :: string)
	end
	local t = now()
	if ready[player] and (ready[player][hackId] or 0) > t then
		return reply(player, hackId, false, "cooldown")
	end
	if retry[player] and (retry[player][hackId] or 0) > t then
		return reply(player, hackId, false, "retry_wait")
	end
	local dir: Vector3? = if typeof(p.dir) == "Vector3" then p.dir else nil
	local targetKind, targetId = "self", nil
	if def.Target == "other" then
		local target, terr = checkTarget(player, character, hackId, p.targetId, 1)
		if not target then
			return reply(player, hackId, false, terr :: string)
		end
		targetKind, targetId = target.Kind, target.Id
	elseif hackId == "SHIELD" and HackEffects.HasShield(player) then
		return reply(player, hackId, false, "already_active")
	end
	-- Challenge selection
	local kind, length = nil, 0
	if def.Target == "self" then
		length = CH.SelfLength[hackId] or 0
		if hackId == "SHIELD" and HackIncoming.IsTargeted(character) then
			length = 0 -- reactive shield: no arrows while a hack is incoming at you
		end
		kind = if length > 0 then "Sequence" else nil
	elseif targetKind == "boss" then
		local model = Conductor.Model()
		local variant = model and model:GetAttribute(A.BossChallenge)
		kind = if table.find(CH.BossVariants, variant) then variant else CH.BossVariants[1]
	else
		kind, length = "Sequence", CH.Target.Length
	end
	if not kind then
		local ok, reason, text = apply(player, hackId, targetId, dir)
		return reply(player, hackId, ok, reason, text)
	end
	tokenSeq += 1
	local s: Session = {
		token = tokenSeq,
		hackId = hackId,
		targetId = targetId,
		targetKind = targetKind,
		challenge = HackChallenges.New(kind, if length > 0 then length else nil, t, { bossState = bossState, rng = rng }),
		dir = dir,
		lastSent = 0,
		source = source,
		lastN = 0,
	}
	sessions[player] = s
	HackDevice.SetState(player.Character, "hacking")
	logEvent(string.format("%s begin %s via %s -> %s on %s", player.Name, hackId, source, kind, tostring(targetId)))
	sendSnapshot(player, s)
end

local function input(player: Player, p: { [string]: any })
	local s = sessions[player]
	if not s or p.token ~= s.token then
		return -- stale or unknown token: ignored
	end
	if typeof(p.dir) ~= "string" then
		return
	end
	if typeof(p.n) ~= "number" or p.n <= s.lastN or p.n > s.lastN + 50 then
		logEvent(player.Name .. " stale/replayed input rejected")
		return -- replayed or out-of-order input
	end
	s.lastN = p.n
	if typeof(p.aim) == "Vector3" then
		s.dir = p.aim
	end
	local recv = now()
	HackChallenges.Input(s.challenge, p.dir, p.t, recv)
	if s.challenge.Done then
		endSession(player, s.challenge.Result :: string)
	else
		sendSnapshot(player, s)
	end
end

function HackService.CancelFor(player: Player, reason: string)
	if sessions[player] then
		sessions[player].challenge.Done = true
		sessions[player].challenge.Result = reason
		endSession(player, reason)
	end
end

local function onPlayerHit(player: Player)
	local s = sessions[player]
	if s and s.targetKind == "boss" then
		HackService.CancelFor(player, "interrupted")
	end
end

-- Test station (owner directive 2026-11-16 section 2/11): ProximityPrompts on parts tagged
-- HackStationOption (attributes Setting, Value, Label) change prototype settings; a board shows them.
local function stationText(player: Player?): string
	local function w(k: string, d: any): any
		local v = workspace:GetAttribute(k)
		return if v == nil then d else v
	end
	local lines = {
		"TEST STATION — prototype settings",
		string.format("Reaction window: %.1f s", HackCatalog.Tune("Incoming", "ReactionWindow")),
		string.format("Perfect deflect: %s", if HackCatalog.Tune("Incoming", "PerfectWindow") > 0 then "ON" else "OFF"),
		"Dummy reaction: " .. string.upper(tostring(w("HackProto_DummyReaction", "none"))),
		"Boots: per player (step on a boots console)",
	}
	return table.concat(lines, "\n")
end

local function refreshBoards()
	for _, part in CollectionService:GetTagged("HackStationBoard") do
		local label = part:FindFirstChild("BoardText", true)
		if label and label:IsA("TextLabel") then
			label.Text = stationText(nil)
		end
	end
end

local function setupStation()
	for _, part in CollectionService:GetTagged("HackStationOption") do
		if part:IsA("BasePart") then
			local setting, value, label = part:GetAttribute("Setting"), part:GetAttribute("Value"), part:GetAttribute("Label")
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = tostring(label)
			prompt.ObjectText = "Test station"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
			prompt.Triggered:Connect(function(who: Player)
				if setting == "Boots" and typeof(value) == "string" and (HackCatalog.Boots :: any)[value] then
					who:SetAttribute(A.Boots, value)
					send(who, { op = "station", text = "Equipped: " .. (HackCatalog.Boots :: any)[value].Label })
				elseif setting == "ReactionWindow" and typeof(value) == "number" then
					workspace:SetAttribute("HackTune_Incoming_ReactionWindow", value)
				elseif setting == "PerfectDeflect" and typeof(value) == "number" then
					workspace:SetAttribute("HackTune_Incoming_PerfectWindow", value)
				elseif setting == "DummyReaction" and typeof(value) == "string" then
					workspace:SetAttribute("HackProto_DummyReaction", value)
				elseif setting == "ResetBoss" then
					Conductor.Reset("station")
				end
				logEvent(who.Name .. " station " .. tostring(setting) .. "=" .. tostring(value))
				refreshBoards()
			end)
		end
	end
	refreshBoards()
end

local function setupConsoles()
	for _, part in CollectionService:GetTagged("HackModeConsole") do
		if part:IsA("BasePart") then
			local mode = part:GetAttribute("Mode")
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Set boss hack mode"
			prompt.ObjectText = tostring(part:GetAttribute("Label") or mode)
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
			prompt.Triggered:Connect(function(who)
				local boss = Conductor.Model()
				if boss and table.find(CH.BossVariants, mode) then
					boss:SetAttribute(A.BossChallenge, mode)
					logEvent(who.Name .. " set boss mode " .. tostring(mode))
				end
			end)
		end
	end
end

-- Simple NPC behaviour: a model with PatrolA / PatrolB walks between them unless frozen or ragdolled.
local function patrolModel(m: Model)
	if typeof(m:GetAttribute("PatrolA")) ~= "Vector3" then
		return
	end
	task.spawn(function()
		local toB = true
		while m.Parent do
			local hum = m:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not HackEffects.IsFrozen(m) and not HackEffects.IsRagdolled(m) then
				local goal = (if toB then m:GetAttribute("PatrolB") else m:GetAttribute("PatrolA")) :: Vector3
				hum:MoveTo(goal)
				local root = m:FindFirstChild("HumanoidRootPart") :: BasePart
				if root and Vector3.new(root.Position.X - goal.X, 0, root.Position.Z - goal.Z).Magnitude < 3 then
					toB = not toB
				end
			end
			task.wait(0.4)
		end
	end)
end

-- Prototype convenience: dummies (not the boss) respawn at their start 3 s after dying, so the
-- owner can keep testing. Templates are cloned at start-up.
local function startRespawns()
	for _, m in CollectionService:GetTagged(HackCatalog.TargetTag) do
		if m:IsA("Model") and not CollectionService:HasTag(m, HackCatalog.BossTag) then
			local template = m:Clone()
			local parent = m.Parent
			local function watch(model: Model)
				local hum = model:FindFirstChildOfClass("Humanoid")
				if not hum then
					return
				end
				hum.Died:Connect(function()
					task.wait(3)
					HackEffects.CleanupModel(model)
					model:Destroy()
					local fresh = template:Clone()
					fresh.Parent = parent
					local r = fresh:FindFirstChild("HumanoidRootPart")
					if r and r:IsA("BasePart") then
						pcall(function()
							r:SetNetworkOwner(nil)
						end)
					end
					watch(fresh)
					patrolModel(fresh)
					logEvent("respawned " .. fresh.Name)
				end)
			end
			watch(m)
		end
	end
end

local function startPatrols()
	for _, m in CollectionService:GetTagged(HackCatalog.TargetTag) do
		-- NPC physics stays on the server (stable ragdoll/recovery, no client ownership hand-off).
		local r = m:IsA("Model") and m:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") and not r.Anchored then
			pcall(function()
				r:SetNetworkOwner(nil)
			end)
		end
	end
	for _, m in CollectionService:GetTagged(HackCatalog.TargetTag) do
		if m:IsA("Model") then
			patrolModel(m)
		end
	end
end

local function hookPlayer(player: Player)
	local function attachDevice(character: Model)
		task.spawn(function()
			local arm = character:WaitForChild("LeftLowerArm", 5) or character:FindFirstChild("Left Arm") or character:WaitForChild("Left Arm", 5)
			if arm then
				HackDevice.Attach(character)
			end
		end)
	end
	if player.Character then
		attachDevice(player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		attachDevice(character)
		HackService.CancelFor(player, "respawned")
		local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if hum then
			hum.Died:Connect(function()
				HackService.CancelFor(player, "died")
				HackEffects.CleanupPlayer(player)
			end)
		end
	end)
	player.CharacterRemoving:Connect(function()
		HackService.CancelFor(player, "respawned")
		HackEffects.CleanupPlayer(player)
	end)
end

function HackService.Start()
	local folder = sharedRoot:FindFirstChild(HackCatalog.RemoteFolder)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = HackCatalog.RemoteFolder
		folder.Parent = sharedRoot
	end
	local function remote(name: string): RemoteEvent
		local r = (folder :: Instance):FindFirstChild(name)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
		return r :: RemoteEvent
	end
	requestRemote = remote(HackCatalog.RequestRemote)
	eventRemote = remote(HackCatalog.EventRemote)
	HackEffects.SetSender(send)
	HackEffects.SetBroadcaster(function(payload)
		eventRemote:FireAllClients(payload)
	end)
	HackIncoming.Init({
		send = send,
		broadcast = function(payload)
			eventRemote:FireAllClients(payload)
		end,
		log = logEvent,
		onResolved = function(attacker: Player, hackId: string, outcome: string, defender: Player?)
			if typeof(attacker) == "Instance" then -- (the Studio SimulateIncoming hook passes a stand-in attacker)
				send(attacker, { op = "hack_outcome", hackId = hackId, outcome = outcome, role = "attacker" })
				HackDevice.SetState(attacker.Character, if outcome == "hit" then "ok" else "fail")
			end
			if defender then
				send(defender, { op = "hack_outcome", hackId = hackId, outcome = outcome, role = "defender" })
				if outcome == "perfect" then
					-- modest, measurable benefit: refund part of the remaining SHIELD cooldown
					local r = ready[defender] and ready[defender]["SHIELD"]
					if r and r > now() then
						setReady(defender, "SHIELD", (r - now()) * (1 - HackCatalog.Tune("Incoming", "PerfectShieldRefund")))
					end
				end
			end
		end,
	})
	Conductor.Start(onPlayerHit)
	setupConsoles()
	setupStation()
	startPatrols()
	startRespawns()
	requestRemote.OnServerEvent:Connect(function(player: Player, p: any)
		-- aim updates follow mouse movement: own throttle (AIM_MIN_INTERVAL), no reply, and they do not
		-- spend the input rate bucket
		if typeof(p) == "table" and p.op == "aim" then
			setAim(player, p.dir)
			return
		end
		if not rateOk(player) then
			return reply(player, nil, false, "rate_limited")
		end
		if typeof(p) ~= "table" then
			return reply(player, nil, false, "bad_payload")
		end
		local op = p.op
		if op == "begin" then
			timed("begin", function()
				begin(player, p)
			end)
		elseif op == "input" then
			timed("input", function()
				input(player, p)
			end)
		elseif op == "cancel" then
			HackService.CancelFor(player, "cancelled")
		else
			reply(player, nil, false, "bad_payload")
		end
	end)
	for _, pl in Players:GetPlayers() do
		hookPlayer(pl)
	end
	Players.PlayerAdded:Connect(hookPlayer)
	Players.PlayerRemoving:Connect(function(pl)
		HackService.CancelFor(pl, "left")
		HackEffects.CleanupPlayer(pl)
		sessions[pl] = nil
		ready[pl] = nil
		retry[pl] = nil
		buckets[pl] = nil
		aims[pl] = nil
	end)
	-- Session clock: drain, appends, missed signals, deadlines.
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		acc = 0
		local t = now()
		for player, s in sessions do
			local changed = HackChallenges.Tick(s.challenge, t)
			if s.challenge.Done then
				endSession(player, s.challenge.Result :: string)
			elseif changed and (s.challenge.Kind ~= "ResistanceBattle" or os.clock() - s.lastSent >= RESIST_SEND_EVERY) then
				sendSnapshot(player, s)
			end
		end
	end)
	-- Studio-only test hooks (same code paths as the remote). Exposed as a BindableFunction in
	-- ServerStorage (the command bar / test tools run in a different VM, so _G is not shared).
	if RunService:IsStudio() then
		local hooks: { [string]: any }
		hooks = {
			Begin = begin,
			Input = input,
			Cancel = HackService.CancelFor,
			Session = function(pl: Player)
				local s = sessions[pl]
				return s and { token = s.token, hackId = s.hackId, kind = s.challenge.Kind, snap = HackChallenges.Snapshot(s.challenge, now()) }
			end,
			Events = function()
				return events
			end,
			BossLog = Conductor.Log,
			Effects = HackEffects.Debug,
			Perf = function()
				local out = {}
				for k, v in perf do
					out[k] = string.format("n=%d avg=%.3fms max=%.3fms", v.n, v.total / math.max(1, v.n), v.max)
				end
				return out
			end,
			IncomingStats = HackIncoming.Stats,
			-- Solo stand-in for a second client: an NPC model "attacks" the player through the real
			-- incoming stage (same warning, window, defences and resolution as a player attacker).
			SimulateIncoming = function(pl: Player, hackId: string, attackerModel: Model)
				local target = HackTargets.Resolve("player:" .. pl.UserId)
				if not target then
					return "no target"
				end
				local fake: any = { Character = attackerModel, Name = attackerModel.Name, DisplayName = attackerModel.Name }
				return HackIncoming.Start(fake, hackId, target, function(t, from)
					if hackId == "FREEZE" then
						return HackEffects.Freeze(t)
					end
					return HackEffects.FlingTarget(t, from)
				end)
			end,
			ClearCooldowns = function(pl: Player)
				ready[pl] = {}
				retry[pl] = {}
				for _, id in HackCatalog.Ids() do
					pl:SetAttribute(A.ReadyPrefix .. id, nil)
				end
			end,
		}
		local bf = Instance.new("BindableFunction")
		bf.Name = "HackProtoTest"
		bf.OnInvoke = function(cmd: string, ...)
			local fn = hooks[cmd]
			if typeof(fn) ~= "function" then
				return "unknown hook " .. tostring(cmd)
			end
			return fn(...)
		end
		bf.Parent = game:GetService("ServerStorage")
	end
	logEvent("HackService started")
end

return HackService

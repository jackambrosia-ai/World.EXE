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
}

local HackService = {}

local requestRemote: RemoteEvent
local eventRemote: RemoteEvent
local sessions: { [Player]: Session } = {}
local ready: { [Player]: { [string]: number } } = {}
local retry: { [Player]: { [string]: number } } = {}
local buckets: { [Player]: { tokens: number, t: number } } = {}
local tokenSeq = 0
local rng = Random.new()
local events: { string } = {}

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
	if target.Kind == "boss" then
		local st = Conductor.State()
		if st == "OFFLINE" then
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
			ok, text = Conductor.ApplyHack(hackId)
			reason = if ok then "applied" else text :: string
			if not ok then
				text = nil
			end
		elseif hackId == "FREEZE" then
			ok, reason = HackEffects.Freeze(target)
			text = "Target frozen."
		else
			local myRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart
			ok, reason = HackEffects.FlingTarget(target, myRoot.Position)
			text = "Target flung."
		end
	end
	if ok then
		setReady(player, hackId, cooldownOf(hackId))
		return true, "applied", text
	end
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
	if source ~= "chip" and source ~= "typed" then
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
	}
	sessions[player] = s
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
	player.CharacterAdded:Connect(function(character)
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
	Conductor.Start(onPlayerHit)
	setupConsoles()
	startPatrols()
	startRespawns()
	requestRemote.OnServerEvent:Connect(function(player: Player, p: any)
		if not rateOk(player) then
			return reply(player, nil, false, "rate_limited")
		end
		if typeof(p) ~= "table" then
			return reply(player, nil, false, "bad_payload")
		end
		local op = p.op
		if op == "begin" then
			begin(player, p)
		elseif op == "input" then
			input(player, p)
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

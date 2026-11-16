--!strict
-- ConductorPrototype (wrist-hacking prototype, server): a MINIMAL placeholder boss to test hacks
-- under movement and attack pressure. Native-part humanoid (built by the place builder), NOT the
-- production Conductor. Anchored and stationary; it turns to face its target.
--
-- Loop (only while a living player is inside the arena radius):
--   CHARGING  telegraph 1.3-1.5 s: SLAM (amber ring on the target's position, radius 9) or
--             SWEEP (amber lane through the arena, 7 wide). Boss challenges are HARDER now.
--   strike    players inside the zone take damage unless SHIELD is active (blocked, bubble flash).
--             A hit (not blocked) interrupts that player's boss-hack challenge.
--   VULNERABLE 2.5 s cyan glow: boss challenges are EASIER; hack effects hit harder.
--   IDLE       1.2 s.
-- Reactions: FREEZE -> FROZEN for BossSeconds (an attack being charged is cancelled -> longer
-- vulnerability), then BossImmunitySeconds freeze immunity. FLING -> STAGGERED (pushed back,
-- attack cancelled), with fling immunity. INTEGRITY drops on each landed hack (doubled while
-- VULNERABLE); at 0 the boss goes OFFLINE for 8 s and resets.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HackCatalog = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("HackCatalog"))
local HackEffects = require(script.Parent:WaitForChild("HackEffects"))
local A = HackCatalog.Attr
local T = HackCatalog.Tuning

-- Prototype tuning (provisional).
local ARENA_RADIUS = 75
local SLAM_RADIUS = 9
local SLAM_TELEGRAPH = 1.3
local SWEEP_WIDTH = 7
local SWEEP_LENGTH = 110
local SWEEP_TELEGRAPH = 1.5
local DAMAGE = 20
local VULNERABLE_SECONDS = 2.5
local INTERRUPT_VULNERABLE_SECONDS = 3.5
local IDLE_SECONDS = 1.2
local OFFLINE_SECONDS = 8
local HACK_DAMAGE = { FREEZE = 10, FLING_TARGET = 15 }

local ConductorPrototype = {}

local boss: Model? = nil
local root: BasePart? = nil
local body: { BasePart } = {}
local baseColors: { [BasePart]: Color3 } = {}
local label: TextLabel? = nil
local home: CFrame = CFrame.identity
local onPlayerHit: (Player) -> () = function() end
local state = "IDLE"
local busyUntil = 0 -- FROZEN / STAGGERED end time
local interrupted = false
local zoneFolder: Folder? = nil
local log: { string } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function note(s: string)
	table.insert(log, string.format("%.1f %s", os.clock(), s))
	if #log > 60 then
		table.remove(log, 1)
	end
end

local function setState(s: string)
	state = s
	if boss then
		boss:SetAttribute(A.BossState, s)
	end
	local tint: Color3? = nil
	if s == "CHARGING" then
		tint = Color3.fromRGB(255, 193, 7)
	elseif s == "VULNERABLE" then
		tint = Color3.fromRGB(0, 225, 255)
	elseif s == "FROZEN" then
		tint = Color3.fromRGB(175, 230, 255)
	elseif s == "STAGGERED" then
		tint = Color3.fromRGB(214, 38, 170)
	elseif s == "OFFLINE" then
		tint = Color3.fromRGB(58, 66, 88)
	end
	for _, p in body do
		if p.Name == "CoreLight" then
			p.Color = tint or Color3.fromRGB(255, 111, 97)
		end
	end
end

function ConductorPrototype.State(): string
	return state
end

local function refreshLabel()
	if boss and label then
		local mode = boss:GetAttribute(A.BossChallenge)
		local names = { ResistanceBattle = "RESISTANCE BATTLE", InputChase = "INPUT CHASE", SignalLock = "SIGNAL LOCK" }
		label.Text = string.format("CONDUCTOR // PLACEHOLDER\n%s  ·  INTEGRITY %d\nHACK MODE: %s", state, boss:GetAttribute(A.BossIntegrity) or 0, names[mode] or tostring(mode))
	end
end

local function playersInArena(): { Player }
	local list = {}
	if not root then
		return list
	end
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 then
			local d = Vector3.new(r.Position.X - home.Position.X, 0, r.Position.Z - home.Position.Z).Magnitude
			if d <= ARENA_RADIUS then
				table.insert(list, p)
			end
		end
	end
	return list
end

local function face(pos: Vector3)
	if not boss or not root then
		return
	end
	local flat = Vector3.new(pos.X, home.Position.Y, pos.Z)
	if (flat - home.Position).Magnitude > 0.5 then
		boss:PivotTo(CFrame.lookAt(home.Position, flat))
	end
end

local function zonePart(name: string, size: Vector3, cf: CFrame, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 193, 7)
	p.Transparency = 0.55
	p.Size = size
	p.CFrame = cf
	if shape then
		p.Shape = shape
	end
	p.Parent = zoneFolder
	return p
end

-- Wait in small steps; returns false if the attack was interrupted (freeze/stagger/offline).
local function waitAttack(seconds: number): boolean
	local endsAt = os.clock() + seconds
	while os.clock() < endsAt do
		if interrupted then
			return false
		end
		task.wait(0.05)
	end
	return not interrupted
end

local function strike(isInside: (Vector3) -> boolean, what: string)
	for _, p in playersInArena() do
		local r = (p.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
		if isInside(r.Position) then
			if HackEffects.HasShield(p) then
				HackEffects.ShieldBlocked(p)
				note(what .. " BLOCKED by shield: " .. p.Name)
			else
				local h = (p.Character :: Model):FindFirstChildOfClass("Humanoid")
				if h then
					h:TakeDamage(DAMAGE)
				end
				note(what .. " hit " .. p.Name)
				onPlayerHit(p)
			end
		end
	end
end

local function attack(target: Player)
	local tr = ((target.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart).Position
	face(tr)
	setState("CHARGING")
	refreshLabel()
	local slam = math.random() < 0.55
	local floorY = ((boss :: Model):GetAttribute("ArenaFloorY") or 0) + 0.15 -- set by the place builder
	if slam then
		local center = Vector3.new(tr.X, floorY, tr.Z)
		local ring = zonePart("SlamTelegraph", Vector3.new(0.3, SLAM_RADIUS * 2, SLAM_RADIUS * 2), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
		note("SLAM telegraph on " .. target.Name)
		local ok = waitAttack(SLAM_TELEGRAPH)
		ring:Destroy()
		if not ok then
			return false
		end
		ring = zonePart("SlamStrike", Vector3.new(0.6, SLAM_RADIUS * 2, SLAM_RADIUS * 2), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
		ring.Color = Color3.fromRGB(255, 111, 97)
		ring.Transparency = 0.2
		strike(function(p)
			return Vector3.new(p.X - center.X, 0, p.Z - center.Z).Magnitude <= SLAM_RADIUS
		end, "SLAM")
		task.delay(0.25, function()
			ring:Destroy()
		end)
	else
		local dir = Vector3.new(tr.X - home.Position.X, 0, tr.Z - home.Position.Z)
		dir = if dir.Magnitude > 1 then dir.Unit else Vector3.zAxis
		local mid = Vector3.new(home.Position.X, floorY, home.Position.Z) + dir * (SWEEP_LENGTH / 2 - 8)
		local cf = CFrame.lookAt(mid, mid + dir)
		local lane = zonePart("SweepTelegraph", Vector3.new(SWEEP_WIDTH, 0.3, SWEEP_LENGTH), cf)
		note("SWEEP telegraph toward " .. target.Name)
		local ok = waitAttack(SWEEP_TELEGRAPH)
		lane:Destroy()
		if not ok then
			return false
		end
		lane = zonePart("SweepStrike", Vector3.new(SWEEP_WIDTH, 0.6, SWEEP_LENGTH), cf)
		lane.Color = Color3.fromRGB(255, 111, 97)
		lane.Transparency = 0.2
		strike(function(p)
			local rel = cf:PointToObjectSpace(Vector3.new(p.X, floorY, p.Z))
			return math.abs(rel.X) <= SWEEP_WIDTH / 2 and math.abs(rel.Z) <= SWEEP_LENGTH / 2
		end, "SWEEP")
		task.delay(0.25, function()
			lane:Destroy()
		end)
	end
	return true
end

local function damageIntegrity(amount: number)
	if not boss then
		return
	end
	local mult = if state == "VULNERABLE" then 2 else 1
	local v = math.max(0, (boss:GetAttribute(A.BossIntegrity) or 100) - amount * mult)
	boss:SetAttribute(A.BossIntegrity, v)
	note(string.format("integrity -%d -> %d", amount * mult, v))
end

-- Called by HackService after a boss hack succeeded. Returns a short description for feedback.
function ConductorPrototype.ApplyHack(hackId: string): (boolean, string)
	if not boss then
		return false, "no_boss"
	end
	if state == "OFFLINE" then
		return false, "boss_offline"
	end
	local t = now()
	if hackId == "FREEZE" then
		if (boss:GetAttribute(A.FreezeImmuneUntil) or 0) > t then
			return false, "boss_immune"
		end
		local wasCharging = state == "CHARGING"
		interrupted = true
		damageIntegrity(HACK_DAMAGE.FREEZE)
		local bossSeconds = HackCatalog.Tune("Freeze", "BossSeconds")
		busyUntil = os.clock() + bossSeconds
		boss:SetAttribute(A.FreezeImmuneUntil, t + bossSeconds + HackCatalog.Tune("Freeze", "BossImmunitySeconds"))
		setState("FROZEN")
		refreshLabel()
		note("FROZEN" .. (if wasCharging then " (attack interrupted)" else ""))
		return true, if wasCharging then "Conductor frozen — attack interrupted!" else "Conductor frozen (resists: 1.5 s)."
	elseif hackId == "FLING_TARGET" then
		if (boss:GetAttribute(A.FlingImmuneUntil) or 0) > t then
			return false, "boss_immune"
		end
		interrupted = true
		damageIntegrity(HACK_DAMAGE.FLING_TARGET)
		busyUntil = os.clock() + T.FlingTarget.BossStaggerSeconds
		boss:SetAttribute(A.FlingImmuneUntil, t + T.FlingTarget.BossStaggerSeconds + T.FlingTarget.ImmunitySeconds)
		setState("STAGGERED")
		refreshLabel()
		-- Visible knock-back and return (anchored boss: tween the pivot).
		local look = boss:GetPivot().LookVector
		local back = boss:GetPivot() - Vector3.new(look.X, 0, look.Z).Unit * T.FlingTarget.BossPushStuds
		local cv = Instance.new("CFrameValue")
		cv.Value = boss:GetPivot()
		cv.Changed:Connect(function(v)
			if boss then
				boss:PivotTo(v)
			end
		end)
		local tw = TweenService:Create(cv, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = back * CFrame.Angles(math.rad(-12), 0, 0) })
		tw:Play()
		task.delay(T.FlingTarget.BossStaggerSeconds, function()
			local tw2 = TweenService:Create(cv, TweenInfo.new(0.4), { Value = home })
			tw2:Play()
			tw2.Completed:Wait()
			cv:Destroy()
		end)
		note("STAGGERED by fling")
		return true, "Conductor staggered — knocked back."
	end
	return false, "no_effect"
end

function ConductorPrototype.Start(hit: (Player) -> ())
	onPlayerHit = hit
	for _, inst in CollectionService:GetTagged(HackCatalog.BossTag) do
		if inst:IsA("Model") and inst:IsDescendantOf(workspace) then
			boss = inst
		end
	end
	if not boss then
		warn("[HackPrototype] no HackBoss model; Conductor placeholder disabled")
		return
	end
	local b = boss :: Model
	root = b:FindFirstChild("HumanoidRootPart") :: BasePart
	home = b:GetPivot()
	for _, p in b:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(body, p)
			baseColors[p] = p.Color
		end
	end
	if b:GetAttribute(A.BossChallenge) == nil then
		b:SetAttribute(A.BossChallenge, HackCatalog.Challenge.BossVariants[1])
	end
	b:SetAttribute(A.BossIntegrity, 100)
	zoneFolder = Instance.new("Folder")
	zoneFolder.Name = "ConductorZones"
	zoneFolder.Parent = b.Parent
	local bb = Instance.new("BillboardGui")
	bb.Name = "ConductorLabel"
	bb.Size = UDim2.fromOffset(260, 60)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 160
	bb.Adornee = root
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 14
	l.TextColor3 = Color3.fromRGB(245, 247, 255)
	l.TextStrokeTransparency = 0.3
	l.Parent = bb
	bb.Parent = b
	label = l
	b:GetAttributeChangedSignal(A.BossChallenge):Connect(refreshLabel)
	b:GetAttributeChangedSignal(A.BossIntegrity):Connect(refreshLabel)
	setState("IDLE")
	refreshLabel()
	task.spawn(function()
		local turn = 0
		while b.Parent do
			-- Resolve FROZEN / STAGGERED / OFFLINE first.
			if os.clock() < busyUntil then
				task.wait(0.05)
				continue
			end
			if state == "FROZEN" or state == "STAGGERED" then
				interrupted = false
				setState("VULNERABLE")
				refreshLabel()
				task.wait(INTERRUPT_VULNERABLE_SECONDS)
				setState("IDLE")
				refreshLabel()
				continue
			end
			if (b:GetAttribute(A.BossIntegrity) or 100) <= 0 then
				setState("OFFLINE")
				refreshLabel()
				note("OFFLINE")
				task.wait(OFFLINE_SECONDS)
				b:SetAttribute(A.BossIntegrity, 100)
				setState("IDLE")
				refreshLabel()
				continue
			end
			local present = playersInArena()
			if #present == 0 then
				if state ~= "IDLE" then
					setState("IDLE")
					refreshLabel()
				end
				task.wait(0.5)
				continue
			end
			turn += 1
			local target = present[(turn % #present) + 1]
			interrupted = false
			local completed = attack(target)
			if not completed or interrupted then
				continue -- FROZEN / STAGGERED handled at the top of the loop
			end
			setState("VULNERABLE")
			refreshLabel()
			if waitAttack(VULNERABLE_SECONDS) then
				setState("IDLE")
				refreshLabel()
				waitAttack(IDLE_SECONDS)
			end
		end
	end)
end

function ConductorPrototype.Model(): Model?
	return boss
end

function ConductorPrototype.Log(): { string }
	return log
end

return ConductorPrototype

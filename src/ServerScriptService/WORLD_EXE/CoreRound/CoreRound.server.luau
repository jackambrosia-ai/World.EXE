--!strict
-- Core Round Step 1 prototype (server entry): movement + Rebound Disc + holographic shield.
-- INERT unless Workspace.WORLD_EXE_CoreRound == true (set only by tools/studio/coreround/cr_20_build_yard.luau).
-- Does not change the character rig, avatar settings or any production system.
--
-- Request ops (client -> server, CoreNet.Request):
--   "dash"   { n }                       spend a charge (CoreMove)
--   "super"  { n }                       extend the last dash into a Super Dash (CoreMove)
--   "throw"  { n, origin: V3, dir: V3 }  throw the Rebound Disc (CoreDisc)
--   "shield" { up: bool, yaw: number }   raise / lower the holographic shield (CoreCombat)
--   "aim"    { yaw }                     shield facing while raised
--   "pong"   { s }                       echo of a server ping (latency measurement)
-- Event kinds (server -> clients, CoreNet.Event):
--   disc_launch / disc_bounce / disc_turn / disc_block / disc_end, hit, nudge, reject, ping
-- Studio-only test hooks: ServerStorage.CoreRoundTest (BindableFunction), see CoreTest.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local CoreRound = game:GetService("ReplicatedStorage"):WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))

if not CoreConfig.Enabled() then
	return
end

local CoreNet = require(CoreRound:WaitForChild("CoreNet"))
local CoreCombat = require(script.Parent:WaitForChild("CoreCombat"))
local CoreDisc = require(script.Parent:WaitForChild("CoreDisc"))
local CoreMove = require(script.Parent:WaitForChild("CoreMove"))
local CoreDummies = require(script.Parent:WaitForChild("CoreDummies"))

local Request = CoreNet.Request()
local Event = CoreNet.Event()

local function now(): number
	return workspace:GetServerTimeNow()
end

-- ---------- event log (bounded) ----------
local LOG_MAX = 4000
local log: { { [string]: any } } = {}
local logBase = 0
local function logEvent(entry: { [string]: any })
	entry.t = now()
	table.insert(log, entry)
	if #log > LOG_MAX then
		table.remove(log, 1)
		logBase += 1
	end
end

local function fire(kind: string, data: { [string]: any })
	if kind == "nudge" then
		local p = Players:GetPlayerByUserId(data.to)
		if p then
			Event:FireClient(p, kind, data)
		end
		return
	end
	Event:FireAllClients(kind, data)
end

CoreDisc.Init({ fire = fire, log = logEvent })

-- ---------- latency (server-measured round trip) ----------
type Net = { rtt: number, samples: number, pending: { [number]: number }, seq: number, bucket: number, bucketT: number, throwT: { number } }
local net: { [Player]: Net } = {}
local function netOf(p: Player): Net
	local n = net[p]
	if not n then
		n = { rtt = 0.05, samples = 0, pending = {}, seq = 0, bucket = 0, bucketT = 0, throwT = {} }
		net[p] = n
	end
	return n
end

-- Step 1 measurement: this Heartbeat-quantised round trip read ~25-30 ms above Studio's NetworkPing at 150 and 250 ms,
-- so RttBiasSeconds is removed before halving (rewind accuracy).
local function oneWay(p: Player): number
	return math.max(0, netOf(p).rtt - CoreConfig.Tune("Net", "RttBiasSeconds")) / 2
end

-- token bucket: Net.RateLimitPerSecond requests per second per player
local function allow(p: Player): boolean
	local n = netOf(p)
	local t = os.clock()
	local rate = CoreConfig.Tune("Net", "RateLimitPerSecond")
	n.bucket = math.max(0, n.bucket - (t - n.bucketT) * rate)
	n.bucketT = t
	if n.bucket >= rate then
		return false
	end
	n.bucket += 1
	return true
end

-- ---------- characters ----------
local function onCharacter(p: Player, c: Model)
	-- CharacterAdded can fire before the character is parented to the workspace
	local waited = 0
	while not c:IsDescendantOf(workspace) and waited < 10 do
		waited += task.wait(0.05)
	end
	local hum = c:WaitForChild("Humanoid", 10) :: Humanoid?
	c:WaitForChild("HumanoidRootPart", 10)
	c:WaitForChild("Head", 10)
	if not hum or not c.Parent then
		return
	end
	hum.WalkSpeed = CoreConfig.Tune("Move", "RunSpeed")
	CoreCombat.Register(c, p)
	CoreMove.Get(p)
	hum.Died:Connect(function()
		CoreDisc.Clear(c)
		CoreCombat.Unregister(c)
		logEvent({ kind = "died", player = p.Name })
	end)
	logEvent({ kind = "spawn", player = p.Name })
end

-- deterministic teams for the two-player test: Cyan first, then whichever team has fewer players
local Teams = game:GetService("Teams")
local function assignTeam(p: Player)
	local cyan, orange = Teams:FindFirstChild("Cyan") :: Team?, Teams:FindFirstChild("Orange") :: Team?
	if not cyan or not orange then
		return
	end
	local nc, no = #cyan:GetPlayers(), #orange:GetPlayers()
	p.Team = if nc <= no then cyan else orange
end

local function onPlayer(p: Player)
	if not p.Team then
		assignTeam(p)
		if p.Character then
			p:LoadCharacter() -- respawn on the team pad
		end
	end
	if p.Character then
		task.spawn(onCharacter, p, p.Character)
	end
	p.CharacterAdded:Connect(function(c)
		onCharacter(p, c)
	end)
end
for _, p in Players:GetPlayers() do
	onPlayer(p)
end
Players.PlayerAdded:Connect(onPlayer)
Players.PlayerRemoving:Connect(function(p)
	if p.Character then
		CoreDisc.Clear(p.Character)
		CoreCombat.Unregister(p.Character)
	end
	net[p] = nil
	logEvent({ kind = "left", player = p.Name })
end)

-- ---------- requests ----------
local function reject(p: Player, op: string, n: any, why: string?)
	Event:FireClient(p, "reject", { op = op, n = n, why = why })
	logEvent({ kind = "reject", player = p.Name, op = op, n = n, why = why })
end

local function vec(v: any): Vector3?
	if typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e5 then
		return v
	end
	return nil
end

Request.OnServerEvent:Connect(function(p: Player, op: any, payload: any)
	if typeof(op) ~= "string" or typeof(payload) ~= "table" then
		return
	end
	if op == "pong" then
		local n = netOf(p)
		local s = payload.s
		local sent = typeof(s) == "number" and n.pending[s]
		if sent then
			n.pending[s] = nil
			local rtt = os.clock() - sent
			n.rtt = if n.samples == 0 then rtt else n.rtt * 0.8 + rtt * 0.2
			n.samples += 1
			p:SetAttribute("CR_RTT", math.floor(n.rtt * 1000 + 0.5))
		end
		return
	end
	if not allow(p) then
		return
	end
	local c = p.Character
	local e = c and CoreCombat.Get(c)
	if not c or not e then
		return
	end
	local stunned = CoreCombat.IsStunned(c)
	if op == "dash" or op == "super" then
		local ok, why = CoreMove.Request(p, op, stunned, oneWay(p))
		if ok then
			if e.shieldUp then
				CoreCombat.SetShield(e, false, nil) -- dashing lowers the shield
			end
			logEvent({ kind = op, player = p.Name, n = payload.n, charges = CoreMove.Get(p).charges })
		else
			reject(p, op, payload.n, why)
		end
	elseif op == "throw" then
		local origin, dir = vec(payload.origin), vec(payload.dir)
		local root = c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not origin or not dir or dir.Magnitude < 0.5 or not root then
			return reject(p, op, payload.n, "bad")
		end
		if stunned then
			return reject(p, op, payload.n, "stunned")
		end
		if e.shieldUp then
			return reject(p, op, payload.n, "shield")
		end
		local ok, why = CoreDisc.Ready(c)
		if not ok then
			return reject(p, op, payload.n, why)
		end
		-- fire-rate guard (also covered by readiness)
		local n = netOf(p)
		local t = os.clock()
		while #n.throwT > 0 and t - n.throwT[1] > 1 do
			table.remove(n.throwT, 1)
		end
		if #n.throwT >= CoreConfig.Tune("Disc", "FireRateLimit") then
			return reject(p, op, payload.n, "rate")
		end
		table.insert(n.throwT, t)
		-- origin must be near the server's view of the character (moving fast + latency allowed)
		local speed = root.AssemblyLinearVelocity.Magnitude
		local tol = CoreConfig.Tune("Disc", "OriginTolerance") + speed * math.min(0.3, oneWay(p) * 2 + 0.05)
		if (origin - root.Position).Magnitude > tol then
			logEvent({ kind = "origin_clamp", player = p.Name, off = (origin - root.Position).Magnitude, tol = tol })
			origin = root.Position + Vector3.new(0, 1, 0)
		end
		CoreDisc.Throw(c, p.Name, if typeof(payload.n) == "number" then payload.n else 0, origin, dir.Unit, oneWay(p))
	elseif op == "shield" then
		local yaw = if typeof(payload.yaw) == "number" then payload.yaw else nil
		local ok, why = CoreCombat.SetShield(e, payload.up == true, yaw)
		if not ok then
			reject(p, op, payload.n, why)
		end
		logEvent({ kind = "shield", player = p.Name, up = payload.up == true, ok = ok, why = why })
	elseif op == "aim" then
		if typeof(payload.yaw) == "number" then
			CoreCombat.SetYaw(e, payload.yaw)
		end
	end
end)

-- ---------- loop ----------
CoreDummies.Init()
local pingT = 0
RunService.Heartbeat:Connect(function(dt)
	CoreCombat.Record()
	CoreMove.Update()
	CoreCombat.Update(dt)
	CoreDisc.Step(dt)
	CoreDummies.Update(dt)
	-- stun: hold the humanoid still on the server too (the owning client also enforces it)
	for m, e in CoreCombat.All() do
		if e.player then
			local hum = m:FindFirstChildOfClass("Humanoid")
			if hum then
				local stunned = now() < e.stunUntil
				local want = if stunned then 0 else CoreConfig.Tune("Move", "RunSpeed")
				if hum.WalkSpeed ~= want and (stunned or hum.WalkSpeed == 0) then
					hum.WalkSpeed = want
				end
			end
		end
	end
	pingT += dt
	if pingT >= 1 then
		pingT = 0
		for _, p in Players:GetPlayers() do
			local n = netOf(p)
			n.seq += 1
			n.pending[n.seq] = os.clock()
			for s in n.pending do
				if s < n.seq - 10 then
					n.pending[s] = nil
				end
			end
			Event:FireClient(p, "ping", { s = n.seq })
		end
	end
end)

-- ---------- Studio-only test hooks ----------
if RunService:IsStudio() then
	local CoreTest = require(script.Parent:WaitForChild("CoreTest"))
	local bf = Instance.new("BindableFunction")
	bf.Name = "CoreRoundTest"
	bf.OnInvoke = function(op: string, ...)
		return CoreTest.Handle(op, {
			log = log,
			logBase = function()
				return logBase
			end,
			net = net,
			fire = fire,
			logEvent = logEvent,
		}, ...)
	end
	bf.Parent = ServerStorage
end

logEvent({ kind = "boot" })
print("[CoreRound] Step 1 server running")

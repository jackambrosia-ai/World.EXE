--!strict
-- Core Round Step 1 prototype (client entry). INERT unless Workspace.WORLD_EXE_CoreRound == true.
-- Wires Movement, Aim, DiscClient, ShieldClient, Hud, Input and WallRun (optional) together.
-- Studio only: PlayerScripts.CoreRoundClientTest (BindableFunction) for the scripted acceptance tests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CoreRound = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))
if not CoreConfig.Enabled() then
	return
end
local CoreNet = require(CoreRound:WaitForChild("CoreNet"))

local here = script.Parent
local Fx = require(here:WaitForChild("Fx"))
local Aim = require(here:WaitForChild("Aim"))
local MoveState = require(here:WaitForChild("MoveState"))
local Movement = require(here:WaitForChild("Movement"))
local DiscClient = require(here:WaitForChild("DiscClient"))
local ShieldClient = require(here:WaitForChild("ShieldClient"))
local Hud = require(here:WaitForChild("Hud"))
local Input = require(here:WaitForChild("Input"))
local WallRun = require(here:WaitForChild("WallRun"))
-- Step 1B
local Slide = require(here:WaitForChild("Slide"))
local WallRun2 = require(here:WaitForChild("WallRun2"))
local Poses = require(here:WaitForChild("Poses"))
-- Step 1C
local SpeedFx = require(here:WaitForChild("SpeedFx"))

local player = Players.LocalPlayer
local wallTilt = true -- Step 1C (A3): per-player toggle for the wall-run camera roll (settings panel)
local Request = CoreNet.Request()
local Event = CoreNet.Event()

local function send(op: string, payload: { [string]: any })
	Request:FireServer(op, payload)
end

local function stunned(): boolean
	local c = player.Character
	return c ~= nil and workspace:GetServerTimeNow() < ((c:GetAttribute("CR_StunUntil") :: number?) or 0)
end

local function teamColor(): Color3
	local team = if player.Team then player.Team.Name else ""
	return (CoreConfig.TeamColors :: any)[team] or CoreConfig.NeutralColor
end

Fx.Start()
Aim.Start({ owner = MoveState.Owner, stunned = stunned })

ShieldClient.Start({
	send = send,
	stunned = stunned,
	onChange = function(up)
		Movement.SetShieldSlow(up)
		if up then
			Slide.Cancel("shield") -- raising the shield ends a slide (no 58-stud/s moving wall)
			DiscClient.ChargeCancel("shield")
		end
	end,
})

Movement.Start({
	send = send,
	stunned = stunned,
	teamColor = teamColor,
	onDash = function(kind, dir)
		ShieldClient.ForceDown() -- dashing lowers the shield (the server lowers it too)
		Poses.Dash(kind, dir) -- Step 1E: directional dash clip
	end,
})

WallRun.Start({
	ignore = { Fx.Folder() },
	onEnd = function(how)
		Movement.OnWallRunEnd(how)
	end,
})

-- Step 1B: slide, horizontal wall-run v2, procedural slide pose, camera extras
Slide.Start({
	send = send,
	stunned = stunned,
	setBoost = Movement.SetBoost,
	onStart = function()
		ShieldClient.ForceDown()
		Fx.Sound("slide_start")
	end,
	onEnd = function(how)
		if how == "jump" then
			Poses.Reach() -- Step 1C: arm reach on a slide jump (suppressed while the Power Slide Jump pose plays)
		end
	end,
	onPowerJump = function(_up, _fwd)
		Poses.PowerJump() -- Step 1D: push-off -> tuck pose
	end,
	teamColor = teamColor,
})
WallRun2.Start({
	ignore = { Fx.Folder() },
	send = send,
	setBoost = Movement.SetBoost,
	onEnd = function(how)
		if how == "jump" then
			Fx.Sound("wall_jump")
			Poses.WallJump() -- Step 1E: wall-jump push-off -> recovery clips (side from the last wall seen)
		end
	end,
})
Poses.Start({
	localSlide = Slide.Active,
	localWall = WallRun2.WallNormal,
	charging = DiscClient.Charging, -- (charging, 0..1)
	shieldUp = ShieldClient.IsUp,
	reduced = function()
		return Fx.Reduced
	end,
})
Aim.SetExtra({
	slideActive = Slide.Active,
	wallBias = WallRun2.CamBias,
	reduced = function()
		return Fx.Reduced
	end,
	wallNormal = WallRun2.WallNormal,
	tiltEnabled = function()
		return wallTilt
	end,
})
SpeedFx.Start({
	reduced = function()
		return Fx.Reduced
	end,
	burst = function()
		local o = MoveState.Owner()
		return o == "dash" or o == "super"
	end,
	teamColor = teamColor,
})

-- visible-vs-server agreement over this client's own throws (diagnostic)
local function agreement(): string
	local same, diff, visOnly, srvOnly = 0, 0, 0, 0
	for _, rec in DiscClient.Records do
		if os.clock() - rec.t > 1 then -- settled
			for name, v in rec.visible do
				for _, pass in { "out", "ret" } do
					local vis = v[pass]
					local srv = rec.server[name .. ":" .. pass]
					if vis and srv then
						if srv.part == vis then
							same += 1
						else
							diff += 1
						end
					elseif vis then
						visOnly += 1
					end
				end
			end
			for key in rec.server do
				local name, pass = string.match(key, "^(.*):(%a+)$")
				if name and pass and not (rec.visible[name] and rec.visible[name][pass]) then
					srvOnly += 1
				end
			end
		end
	end
	return string.format("match %d  part-differs %d  seen-not-confirmed %d  confirmed-not-seen %d", same, diff, visOnly, srvOnly)
end

local reduced = false
local showSpeed = true
Hud.Start({
	charges = Movement.Charges,
	speed = Movement.HorizontalSpeed,
	state = Movement.State,
	discBusy = DiscClient.Busy,
	discReadyIn = DiscClient.ReadyIn,
	shieldUp = ShieldClient.IsUp,
	agreement = agreement,
	toggles = {
		{ name = "Reduced FX", get = function() return reduced end, set = function(v) reduced = v; Fx.Reduced = v end },
		{ name = "Aim lock", get = function() return Aim.LockEnabled end, set = function(v) Aim.LockEnabled = v end },
		{ name = "Wall-run tilt", get = function() return wallTilt end, set = function(v) wallTilt = v end },
		{ name = "Touch shield toggle", get = function() return ShieldClient.TouchToggle end, set = function(v) ShieldClient.TouchToggle = v end },
		{ name = "Speed readout", get = function() return showSpeed end, set = function(v) showSpeed = v; Hud.SetShowSpeed(v) end },
	},
	charging = DiscClient.Charging,
	threats = DiscClient.Threats,
})

DiscClient.Start({ send = send, shieldUp = ShieldClient.IsUp, stunned = stunned, hud = Hud })

Input.Start({
	dash = function()
		Movement.Press()
	end,
	-- Step 1B: hold to charge, release to throw (a quick tap is an uncharged throw)
	throwDown = function()
		DiscClient.ChargeBegin()
	end,
	throwUp = function()
		DiscClient.ChargeRelease(nil)
	end,
	shield = function(up)
		ShieldClient.Set(up)
	end,
	shieldToggle = ShieldClient.Toggle,
	touchToggle = function()
		return ShieldClient.TouchToggle
	end,
	slide = function(down)
		Slide.Press(down)
	end,
	slideToggle = function()
		Slide.Toggle()
	end,
})

Event.OnClientEvent:Connect(function(kind: string, d: { [string]: any })
	if kind == "ping" then
		send("pong", { s = d.s })
		return
	end
	if kind == "nudge" then
		local c = player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local o = MoveState.Owner()
		if hrp and (o == nil) then
			local dir = Vector3.new(d.dir.X, 0, d.dir.Z)
			if dir.Magnitude > 0.01 then
				local v = hrp.AssemblyLinearVelocity
				local push = dir.Unit * CoreConfig.Tune("Disrupt", "NudgeStuds") * 6
				hrp.AssemblyLinearVelocity = Vector3.new(v.X + push.X, v.Y, v.Z + push.Z)
			end
		end
		return
	end
	if kind == "reject" then
		if d.op == "dash" or d.op == "super" then
			Movement.OnReject(d.op, d.why)
		elseif d.op == "shield" then
			ShieldClient.OnReject()
		elseif d.op == "move" then
			Slide.OnReject()
		end
	end
	DiscClient.OnEvent(kind, d)
end)

-- ---------- Studio-only client test hooks ----------
if RunService:IsStudio() then
	local bf = Instance.new("BindableFunction")
	bf.Name = "CoreRoundClientTest"
	bf.OnInvoke = function(op: string, a: any, b: any)
		if op == "Press" then
			return Movement.Press()
		elseif op == "MoveLog" then
			return Movement.Log
		elseif op == "Charges" then
			return { Movement.Charges() }
		elseif op == "Speed" then
			return Movement.HorizontalSpeed()
		elseif op == "State" then
			return Movement.State()
		elseif op == "Throw" then
			return DiscClient.Throw(a)
		elseif op == "ThrowAt" then -- aim at a world point from the throw origin
			local c = player.Character
			local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then
				return false
			end
			return DiscClient.Throw((a :: Vector3) - (hrp.Position + Vector3.new(0, 1.2, 0)))
		elseif op == "Trace" then -- Step 1E correction pass: client hit trace for own throw n (a)
			return DiscClient.Trace[a :: number]
		elseif op == "Records" then
			return DiscClient.Records
		elseif op == "Agreement" then
			return agreement()
		elseif op == "Shield" then
			ShieldClient.Set(a == true)
			return ShieldClient.IsUp()
		elseif op == "ResetLocal" then
			Movement.Reset()
			table.clear(DiscClient.Records)
			return true
		elseif op == "Reduced" then
			reduced = a == true
			Fx.Reduced = reduced
			return reduced
		-- Step 1B
		elseif op == "Slide" then
			return Slide.Press(a == true)
		elseif op == "SlideLog" then
			return Slide.Log
		elseif op == "WallLog" then
			return WallRun2.Log
		elseif op == "ChargeBegin" then
			return DiscClient.ChargeBegin()
		elseif op == "ChargeRelease" then
			return DiscClient.ChargeRelease(a)
		elseif op == "ChargeReleaseAt" then
			local c = player.Character
			local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then
				return false
			end
			return DiscClient.ChargeRelease((a :: Vector3) - (hrp.Position + Vector3.new(0, 1.2, 0)))
		elseif op == "Charging" then
			return { DiscClient.Charging() }
		elseif op == "Threats" then
			return #DiscClient.Threats()
		-- Step 1C
		elseif op == "FxStats" then -- script time of the new per-frame work (performance)
			return { poses = table.clone(Poses.Stats), speedFx = table.clone(SpeedFx.Stats) }
		elseif op == "FxStatsReset" then
			Poses.Stats.frames, Poses.Stats.seconds = 0, 0
			SpeedFx.Stats.frames, SpeedFx.Stats.seconds, SpeedFx.Stats.maxVisible = 0, 0, 0
			return true
		elseif op == "Roll" then
			return math.deg(Aim.Roll())
		elseif op == "SpeedFx" then
			return { SpeedFx.Intensity() }
		elseif op == "SlideWeight" then -- as drawn on this client for a character (a = player name)
			local p = Players:FindFirstChild(a :: string)
			local c = p and (p :: Player).Character
			return if c then Poses.SlideWeight(c) else -1
		elseif op == "AimLock" then -- Step 1E capture helper: turn the aim lock off for side views
			Aim.LockEnabled = a == true
			return Aim.LockEnabled
		elseif op == "AnimDebug" then -- Step 1E: what the animation controller draws for a character (a = player name)
			local p = if a then Players:FindFirstChild(a :: string) else player
			local c = p and (p :: Player).Character
			return if c then Poses.Debug(c) else nil
		elseif op == "WallTilt" then
			wallTilt = a == true
			return wallTilt
		end
		local _ = b
		return "unknown"
	end
	bf.Parent = player:WaitForChild("PlayerScripts")
end

print("[CoreRound] Step 1E client running")

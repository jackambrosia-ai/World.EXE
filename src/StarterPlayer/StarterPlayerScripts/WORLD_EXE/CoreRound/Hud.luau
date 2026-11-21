--!strict
-- Hud (Core Round Step 1, client): the compact combat HUD (not the old hacking terminal).
--   centre:  crosshair; hit markers (white = body, gold = head, ring = stun); your disruption meter arc
--   bottom:  two Super Dash charge pills (next one filling), shield energy bar, disc state, optional speed
--   overhead: a disruption bar + STUN flag over every other entity that has a meter, team-colour outlines
--   F2:      diagnostics panel (latency, charges, last confirmed hit, visible-vs-server agreement, toggles)
-- Kept away from the bottom-right (touch jump button / thumb area) and the bottom-left (touch joystick).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CoreRound = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local Aim = require(script.Parent:WaitForChild("Aim"))

local Hud = {}

local player = Players.LocalPlayer
local CYAN = Color3.fromRGB(40, 220, 255)
local GOLD = Color3.fromRGB(255, 214, 64)
local DIM = Color3.fromRGB(20, 26, 34)

type Deps = {
	charges: () -> (number, number),
	speed: () -> number,
	state: () -> string,
	discBusy: () -> boolean,
	discReadyIn: () -> number,
	shieldUp: () -> boolean,
	agreement: () -> string,
	toggles: { { name: string, get: () -> boolean, set: (boolean) -> () } },
	-- Step 1B
	charging: () -> (boolean, number),
	threats: () -> { { pos: Vector3, eta: number, charge: number } },
}

-- Step 1B: charge segments around the crosshair + incoming-disc arrows (Knockout City border-warning reference,
-- adapted as a ring of arrows around the crosshair so it works on phones too)
local chargeDots: { Frame } = {}
local threatArrows: { TextLabel } = {}
local deps: Deps

local gui: ScreenGui
local hitMark: Frame
local hitT = -10
local hitColor = Color3.new(1, 1, 1)
local stunRingT = -10
local denyLabel: TextLabel
local denyT = -10
local diag: Frame
local diagText: TextLabel
local lastHitText = "-"
local showSpeed = true

local function corner(p: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function frame(parent: Instance, size: UDim2, pos: UDim2, color: Color3, transparency: number, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3, anchor: Vector2?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.AnchorPoint = anchor or Vector2.zero
	l.Text = text
	l.TextColor3 = color
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.Parent = parent
	return l
end

local pills: { { bg: Frame, fill: Frame } } = {}
local shieldBg: Frame
local shieldFill: Frame
local shieldLabel: TextLabel
local discDot: Frame
local discLabel: TextLabel
local speedLabel: TextLabel
local meterBg: Frame
local meterFill: Frame
local stunBanner: TextLabel
local crosshair: Frame

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "CoreRoundHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- crosshair
	crosshair = frame(gui, UDim2.fromOffset(6, 6), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1), 0.1, Vector2.new(0.5, 0.5))
	corner(crosshair, 3)
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.new(0, 0, 0)
	ring.Thickness = 1
	ring.Transparency = 0.4
	ring.Parent = crosshair

	-- hit marker: four short bars in an X around the centre
	hitMark = frame(gui, UDim2.fromOffset(34, 34), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1), 1, Vector2.new(0.5, 0.5))
	for i = 0, 3 do
		local b = frame(hitMark, UDim2.fromOffset(10, 3), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1), 0, Vector2.new(0.5, 0.5))
		local ang = 45 + i * 90
		b.Rotation = ang
		b.Position = UDim2.new(0.5, math.cos(math.rad(ang)) * 11, 0.5, math.sin(math.rad(ang)) * 11)
		b.Name = "Bar"
	end
	hitMark.Visible = false

	-- Step 1B charge ring (12 segments) and threat arrows (pooled)
	for i = 1, 12 do
		local a = (i - 1) / 12 * math.pi * 2 - math.pi / 2
		local dot = frame(gui, UDim2.fromOffset(5, 5), UDim2.new(0.5, math.cos(a) * 24, 0.5, math.sin(a) * 24), Color3.new(1, 1, 1), 1, Vector2.new(0.5, 0.5))
		corner(dot, 3)
		dot.Name = "ChargeDot"
		table.insert(chargeDots, dot)
	end
	for i = 1, 3 do
		local arrow = Instance.new("TextLabel")
		arrow.Name = "ThreatArrow"
		arrow.BackgroundTransparency = 1
		arrow.Size = UDim2.fromOffset(28, 28)
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.Text = "▲"
		arrow.TextScaled = true
		arrow.Font = Enum.Font.GothamBlack
		arrow.TextColor3 = Color3.fromRGB(255, 120, 80)
		arrow.TextStrokeTransparency = 0.3
		arrow.Visible = false
		arrow.Parent = gui
		table.insert(threatArrows, arrow)
	end

	-- own disruption meter (under the crosshair)
	meterBg = frame(gui, UDim2.fromOffset(90, 6), UDim2.new(0.5, 0, 0.5, 26), DIM, 0.3, Vector2.new(0.5, 0))
	corner(meterBg, 3)
	meterFill = frame(meterBg, UDim2.fromScale(0, 1), UDim2.fromScale(0, 0), GOLD, 0)
	corner(meterFill, 3)
	stunBanner = label(gui, "STUNNED", UDim2.fromOffset(200, 30), UDim2.new(0.5, 0, 0.5, 40), Color3.fromRGB(255, 90, 90), Vector2.new(0.5, 0))
	stunBanner.Visible = false

	-- bottom-centre cluster
	local bar = frame(gui, UDim2.fromOffset(260, 64), UDim2.new(0.5, 0, 1, -18), DIM, 0.35, Vector2.new(0.5, 1))
	corner(bar, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = bar
	label(bar, "DASH", UDim2.fromOffset(40, 12), UDim2.fromOffset(0, 8), Color3.fromRGB(170, 190, 205))
	for i = 1, 2 do
		local bg = frame(bar, UDim2.fromOffset(46, 10), UDim2.fromOffset(44 + (i - 1) * 52, 9), Color3.fromRGB(45, 55, 66), 0)
		corner(bg, 5)
		local fill = frame(bg, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), CYAN, 0)
		corner(fill, 5)
		table.insert(pills, { bg = bg, fill = fill })
	end
	discDot = frame(bar, UDim2.fromOffset(18, 18), UDim2.fromOffset(160, 5), CYAN, 0)
	corner(discDot, 9)
	discLabel = label(bar, "DISC", UDim2.fromOffset(60, 12), UDim2.fromOffset(182, 8), Color3.fromRGB(170, 190, 205))
	label(bar, "SHIELD", UDim2.fromOffset(52, 12), UDim2.fromOffset(0, 34), Color3.fromRGB(170, 190, 205))
	shieldBg = frame(bar, UDim2.fromOffset(150, 10), UDim2.fromOffset(56, 35), Color3.fromRGB(45, 55, 66), 0)
	corner(shieldBg, 5)
	shieldFill = frame(shieldBg, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(1, 1, 1), 0)
	corner(shieldFill, 5)
	shieldLabel = label(bar, "", UDim2.fromOffset(40, 12), UDim2.fromOffset(212, 34), Color3.fromRGB(255, 120, 120))
	speedLabel = label(gui, "", UDim2.fromOffset(110, 16), UDim2.new(0.5, 0, 1, -88), Color3.fromRGB(200, 220, 235), Vector2.new(0.5, 1))

	denyLabel = label(gui, "", UDim2.fromOffset(240, 18), UDim2.new(0.5, 0, 0.5, 70), Color3.fromRGB(255, 160, 120), Vector2.new(0.5, 0))

	-- diagnostics panel (F2)
	diag = frame(gui, UDim2.fromOffset(320, 300), UDim2.fromOffset(12, 60), Color3.fromRGB(10, 14, 20), 0.2)
	corner(diag, 8)
	diag.Visible = false
	diagText = Instance.new("TextLabel")
	diagText.BackgroundTransparency = 1
	diagText.Size = UDim2.new(1, -16, 0, 190)
	diagText.Position = UDim2.fromOffset(8, 6)
	diagText.TextXAlignment = Enum.TextXAlignment.Left
	diagText.TextYAlignment = Enum.TextYAlignment.Top
	diagText.Font = Enum.Font.Code
	diagText.TextSize = 13
	diagText.TextColor3 = Color3.fromRGB(210, 230, 240)
	diagText.Parent = diag
	for i, tg in deps.toggles do
		local b = Instance.new("TextButton")
		b.Name = "Toggle_" .. tg.name
		b.Size = UDim2.fromOffset(148, 24)
		b.Position = UDim2.fromOffset(8 + ((i - 1) % 2) * 156, 200 + math.floor((i - 1) / 2) * 30)
		b.BackgroundColor3 = Color3.fromRGB(35, 45, 58)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.Gotham
		b.TextSize = 12
		b.Parent = diag
		corner(b, 5)
		local function refresh()
			b.Text = tg.name .. ": " .. (if tg.get() then "ON" else "OFF")
		end
		refresh()
		b.Activated:Connect(function()
			tg.set(not tg.get())
			refresh()
		end)
	end
end

-- overhead meters for other entities
type Over = { bb: BillboardGui, fill: Frame, flag: TextLabel, hl: Highlight? }
local overs: { [Model]: Over } = {}

local function overFor(m: Model): Over?
	local o = overs[m]
	if o then
		return o
	end
	local head = m:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "CoreMeter"
	bb.Size = UDim2.fromOffset(70, 22)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 140
	bb.Adornee = head
	bb.Parent = gui
	local bg = frame(bb, UDim2.new(1, 0, 0, 6), UDim2.fromScale(0, 0), DIM, 0.2)
	corner(bg, 3)
	local fill = frame(bg, UDim2.fromScale(0, 1), UDim2.fromScale(0, 0), GOLD, 0)
	corner(fill, 3)
	local flag = label(bb, "", UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 8), Color3.fromRGB(255, 90, 90))
	o = { bb = bb, fill = fill, flag = flag, hl = nil }
	overs[m] = o
	return o
end

local function teamOf(m: Model): string
	local p = Players:GetPlayerFromCharacter(m)
	if p then
		return if p.Team then p.Team.Name else ""
	end
	return (m:GetAttribute("CR_Team") :: string?) or ""
end

function Hud.Hit(d: { [string]: any })
	if d.attacker == player.Name then
		hitT = os.clock()
		hitColor = if d.kind == "HEAD" then GOLD else Color3.new(1, 1, 1)
		if d.stunned then
			stunRingT = os.clock()
		end
		lastHitText = string.format("%s %s (%s) meter %d%s", d.target, d.kind, d.pass, d.meter, if d.stunned then " STUN" elseif d.immune then " immune" elseif d.ignored then " ignored" else "")
	end
end

function Hud.Blocked(d: { [string]: any })
	if d.holder == player.Name then
		denyT = os.clock()
		denyLabel.Text = if d.broke then "SHIELD BROKEN" else "BLOCKED"
	end
end

function Hud.Deny(why: string?)
	denyT = os.clock()
	denyLabel.Text = string.upper(string.gsub(why or "unavailable", "_", " "))
end

function Hud.ToggleDiag()
	diag.Visible = not diag.Visible
end

function Hud.SetShowSpeed(on: boolean)
	showSpeed = on
end

function Hud.Start(d: Deps)
	deps = d
	build()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			Hud.ToggleDiag()
		end
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local sNow = workspace:GetServerTimeNow()
		-- charges
		local ch, frac = deps.charges()
		for i, p in pills do
			if i <= ch then
				p.fill.Size = UDim2.fromScale(1, 1)
				p.fill.BackgroundColor3 = CYAN
			elseif i == ch + 1 then
				p.fill.Size = UDim2.fromScale(frac, 1)
				p.fill.BackgroundColor3 = Color3.fromRGB(70, 110, 130)
			else
				p.fill.Size = UDim2.fromScale(0, 1)
			end
		end
		-- shield
		local c = player.Character
		local energy = (c and c:GetAttribute("CR_ShieldEnergy") :: number?) or 100
		local broken = c and sNow < ((c:GetAttribute("CR_ShieldBrokenUntil") :: number?) or 0)
		shieldFill.Size = UDim2.fromScale(math.clamp(energy / 100, 0, 1), 1)
		shieldFill.BackgroundColor3 = if broken then Color3.fromRGB(255, 80, 80) elseif deps.shieldUp() then CYAN else Color3.new(1, 1, 1)
		shieldLabel.Text = if broken then "BROKEN" elseif deps.shieldUp() then "UP" else ""
		-- disc
		local busy = deps.discBusy()
		local wait = deps.discReadyIn()
		discDot.BackgroundTransparency = if busy or wait > 0 then 0.7 else 0
		discLabel.Text = if busy then "IN FLIGHT" elseif wait > 0 then string.format("%.1fs", wait) else "DISC READY"
		-- speed
		speedLabel.Text = if showSpeed then string.format("%d st/s  %s", math.floor(deps.speed() + 0.5), string.upper(deps.state())) else ""
		-- own meter + stun
		local meter = (c and c:GetAttribute("CR_Meter") :: number?) or 0
		meterBg.Visible = meter > 0
		meterFill.Size = UDim2.fromScale(math.clamp(meter / 100, 0, 1), 1)
		local stunned = c and sNow < ((c:GetAttribute("CR_StunUntil") :: number?) or 0)
		local immune = c and sNow < ((c:GetAttribute("CR_ImmuneUntil") :: number?) or 0)
		stunBanner.Visible = stunned == true or immune == true
		stunBanner.Text = if stunned then "STUNNED" else "PROTECTED"
		stunBanner.TextColor3 = if stunned then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(150, 220, 255)
		-- hit marker
		local k = (t - hitT) / 0.25
		hitMark.Visible = k < 1
		if k < 1 then
			for _, b in hitMark:GetChildren() do
				if b:IsA("Frame") then
					b.BackgroundColor3 = hitColor
					b.BackgroundTransparency = k
				end
			end
			local grow = if t - stunRingT < 0.4 then 18 else 0
			hitMark.Size = UDim2.fromOffset(34 + grow, 34 + grow)
		end
		-- crosshair follows the free cursor when aim lock is off
		if Aim.UsesMouse() and not Aim.LockActive() then
			local m = UserInputService:GetMouseLocation()
			crosshair.Position = UDim2.fromOffset(m.X, m.Y)
			hitMark.Position = crosshair.Position
		else
			crosshair.Position = UDim2.fromScale(0.5, 0.5)
			hitMark.Position = crosshair.Position
		end
		-- Step 1B: charge ring
		local on, ck = deps.charging()
		local lit = if on then math.floor(ck * 12 + 0.001) else 0
		for i, dot in chargeDots do
			dot.Position = UDim2.new(crosshair.Position.X.Scale, crosshair.Position.X.Offset + math.cos((i - 1) / 12 * math.pi * 2 - math.pi / 2) * 24, crosshair.Position.Y.Scale, crosshair.Position.Y.Offset + math.sin((i - 1) / 12 * math.pi * 2 - math.pi / 2) * 24)
			if on then
				dot.BackgroundTransparency = if i <= lit then 0 else 0.75
				dot.BackgroundColor3 = if ck >= 1 then Color3.new(1, 1, 1) else CYAN
				local pulse = if ck >= 1 then 6 + math.sin(t * 18) * 2 else 5
				dot.Size = UDim2.fromOffset(pulse, pulse)
			else
				dot.BackgroundTransparency = 1
			end
		end
		-- Step 1B: incoming enemy discs -> arrows around the crosshair pointing at them (closer = more opaque)
		local threats = deps.threats()
		local cam = workspace.CurrentCamera
		local vp = cam.ViewportSize
		for i, arrow in threatArrows do
			local th = threats[i]
			if th then
				local rel = cam.CFrame:PointToObjectSpace(th.pos)
				local ang = math.atan2(-rel.Y, rel.X) -- screen-space direction (x right, y down)
				local r = math.min(vp.X, vp.Y) * 0.16
				arrow.Position = UDim2.new(0.5, math.cos(ang) * r, 0.5, math.sin(ang) * r)
				arrow.Rotation = math.deg(ang) + 90
				arrow.TextTransparency = math.clamp(th.eta * 1.5, 0, 0.7)
				arrow.TextColor3 = if th.charge > 0.5 then Color3.fromRGB(255, 70, 70) else Color3.fromRGB(255, 160, 80)
				arrow.Visible = true
			else
				arrow.Visible = false
			end
		end
		-- deny / blocked text
		denyLabel.Visible = t - denyT < 0.8
		-- overhead meters + team outlines
		local mine = if player.Team then player.Team.Name else ""
		local present: { [Model]: boolean } = {}
		local models: { Model } = {}
		for _, p in Players:GetPlayers() do
			if p ~= player and p.Character then
				table.insert(models, p.Character)
			end
		end
		local yard = workspace:FindFirstChild("CoreRoundYard")
		local dum = yard and yard:FindFirstChild("Dummies")
		if dum then
			for _, m in dum:GetChildren() do
				if m:IsA("Model") then
					table.insert(models, m)
				end
			end
		end
		for _, m in models do
			present[m] = true
			local o = overFor(m)
			if o then
				local mv = (m:GetAttribute("CR_Meter") :: number?) or 0
				local st = sNow < ((m:GetAttribute("CR_StunUntil") :: number?) or 0)
				local im = sNow < ((m:GetAttribute("CR_ImmuneUntil") :: number?) or 0)
				o.bb.Enabled = mv > 0 or st or im
				o.fill.Size = UDim2.fromScale(math.clamp(mv / 100, 0, 1), 1)
				o.flag.Text = if st then "STUN" elseif im then "PROTECTED" else ""
				o.flag.TextColor3 = if st then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(150, 220, 255)
				local team = teamOf(m)
				if Players:GetPlayerFromCharacter(m) and not o.hl then
					local hl = Instance.new("Highlight")
					hl.FillTransparency = 1
					hl.OutlineTransparency = 0.2
					hl.DepthMode = Enum.HighlightDepthMode.Occluded
					hl.Adornee = m
					hl.Parent = Fx.Folder()
					o.hl = hl
				end
				if o.hl then
					o.hl.OutlineColor = (CoreConfig.TeamColors :: any)[team] or CoreConfig.NeutralColor
					o.hl.Enabled = team ~= mine or mine == ""
				end
			end
		end
		for m, o in overs do
			if not present[m] or not m.Parent then
				o.bb:Destroy()
				if o.hl then
					o.hl:Destroy()
				end
				overs[m] = nil
			end
		end
		-- diagnostics
		if diag.Visible then
			local sc = player:GetAttribute("CR_Charges")
			diagText.Text = table.concat({
				"CORE ROUND STEP 1 - DIAGNOSTICS (F2)",
				string.format("RTT (server-measured): %s ms", tostring(player:GetAttribute("CR_RTT") or "-")),
				string.format("charges: client %d  server %s", ch, tostring(sc)),
				string.format("speed %.1f  state %s", deps.speed(), deps.state()),
				string.format("disc: %s", discLabel.Text),
				string.format("shield energy %d%s", energy, if broken then " BROKEN" else ""),
				"last confirmed hit: " .. lastHitText,
				"visible vs server: " .. deps.agreement(),
				string.format("rewind mode %d  max %.2fs", CoreConfig.Tune("Disc", "RewindMode"), CoreConfig.Tune("Disc", "RewindMax")),
				"Alt: free / lock cursor   Reduced FX: " .. (if Fx.Reduced then "on" else "off"),
			}, "\n")
		end
	end)
end

return Hud

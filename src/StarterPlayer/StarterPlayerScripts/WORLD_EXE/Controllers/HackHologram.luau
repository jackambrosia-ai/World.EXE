--!strict
-- HackHologram (wrist-hacking prototype, client) — Rev 15u, owner reference VFX-02 (2026-11-17): "implement the
-- digital hologram looking thing so that it appears on enemies you're trying to hack".
-- VFX-02 (owner screen recording, SHA-256 5818b26b…, frames private; studied EVERY frame 60-247 at 30 fps):
-- a floating holographic comms card beside a character — translucent dark-teal card, thin cyan frame with
-- corner ticks, tiny monospace header with a blinking red record dot and a flickering red/white glitch block,
-- a scan-lined teal portrait with a bouncing signal-level meter, a status row (timer counting up, bold
-- status, thin progress line), a message box whose text types ~1 char per frame (sometimes 2), a thin
-- tether line and corner brackets on the character.
-- Its FEEL (frame-exact):
--   open  (~4 frames): a thin BROKEN horizontal line -> the portrait TEARS OPEN vertically from it (bright
--         tear band) while the message box arrives offset and narrow -> the whole card JOLTS sideways and the
--         status row appears -> the header pops in last and everything snaps into place; typing starts.
--   live: the meter bounces, the header glitch flickers, the portrait occasionally tears / jitters, and on a
--         new message the message box blinks dim before the new line types.
--   close (~6 frames): header gone -> status row gone -> the portrait SQUASHES toward its centre into a thin
--         torn band and the tether drops -> the message box goes last.
-- WORLD.EXE version (original text; nothing copied): only the HACKER sees it, from the start of a hack challenge
-- until it resolves. Portrait = live scan-lined hologram of the TARGET (ViewportFrame clone). The bar follows
-- the challenge; typed lines narrate the breach; success -> ACCESS GRANTED, failure / cancel -> LINK LOST.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local HackHologram = {}

local TEAL_BG = Color3.fromRGB(12, 46, 58)
local CYAN = Color3.fromRGB(120, 225, 245)
local CYAN_DIM = Color3.fromRGB(70, 150, 170)
local WHITE = Color3.fromRGB(225, 245, 250)
local RED = Color3.fromRGB(255, 70, 70)
local GREEN = Color3.fromRGB(110, 255, 160)
local CORAL = Color3.fromRGB(255, 110, 100)

local CARD_W = 210
local HEADER_H, PORTRAIT_H, STATUS_H, MSG_H = 12, 112, 30, 62
local CARD_H = HEADER_H + PORTRAIT_H + STATUS_H + 4 + MSG_H
local OFFSET = Vector3.new(-8.5, 4.6, 0) -- camera-relative: upper-left of the target, clear of it and of the incoming banner (reference layout; -7 overlapped the FLING INCOMING banner)
local FRAME = 1 / 30 -- the reference's animation steps are whole video frames at 30 fps

type Holo = {
	root: BasePart,
	card: BillboardGui,
	frame: Frame, -- whole card (jolt offset)
	header: Frame,
	portrait: Frame,
	status: Frame,
	mbox: Frame,
	tear: Frame,
	brackets: BillboardGui,
	anchor: Part,
	a1: Attachment,
	beam: Beam,
	bar: Frame,
	timer: TextLabel,
	statusText: TextLabel,
	msg: TextLabel,
	dot: Frame,
	glitch: Frame,
	scan: Frame,
	vp: ViewportFrame,
	meter: { Frame },
	t0: number,
	typed: string,
	want: string,
	nextChar: number,
	blinkUntil: number,
	closing: boolean,
	conn: RBXScriptConnection?,
}

local current: Holo? = nil

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local base = { BackgroundTransparency = 1, TextColor3 = CYAN, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base, parent)
end

local function boxed(f: Frame)
	f.BackgroundColor3 = TEAL_BG
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	new("UIStroke", { Color = CYAN, Thickness = 1, Transparency = 0.25 }, f)
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		new("Frame", { AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromOffset(7, 2), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 6 }, f)
		new("Frame", { AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromOffset(2, 7), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 6 }, f)
	end
end

local function hologramClone(model: Model): Model?
	local was = model.Archivable
	model.Archivable = true
	local ok, made = pcall(function()
		return model:Clone()
	end)
	model.Archivable = was
	if not ok or not made then
		return nil
	end
	local m = made :: Model
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Constraint") or d:IsA("BillboardGui") or d:IsA("Highlight") or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return m
end

-- portrait height as a centred squash (0 = a line, 1 = open)
local function setPortraitOpen(h: Holo, k: number)
	local hgt = math.max(2, math.floor(PORTRAIT_H * k))
	h.portrait.Size = UDim2.new(1, 0, 0, hgt)
	h.portrait.Position = UDim2.fromOffset(0, HEADER_H + (PORTRAIT_H - hgt) / 2)
end

function HackHologram.Open(model: Model, displayName: string, hackName: string)
	HackHologram.Close("cancel", true)
	local root = (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) :: BasePart?
	if not root then
		return
	end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local card = new("BillboardGui", { Name = "WORLD_EXE_HackHologram", Adornee = root, Size = UDim2.fromOffset(CARD_W, CARD_H), StudsOffset = OFFSET, AlwaysOnTop = true, LightInfluence = 0, ResetOnSpawn = false, MaxDistance = 400 }, pg)
	local frame = new("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, card)
	-- header (pops in LAST)
	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundTransparency = 1, Visible = false }, frame)
	local dot = new("Frame", { Position = UDim2.fromOffset(2, 3), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = RED, BorderSizePixel = 0 }, header)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
	text(header, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -10, 1, 0), Text = string.format("INTRUSION // WRIST UPLINK  %d.%03d", math.random(40, 89), math.random(0, 999)), TextColor3 = CYAN_DIM, TextSize = 8 })
	local glitch = new("Frame", { Position = UDim2.fromOffset(120, 3), Size = UDim2.fromOffset(9, 5), BackgroundColor3 = RED, BorderSizePixel = 0, Visible = false, ZIndex = 3 }, header)
	-- portrait: live hologram of the target, scanlines, scan band, tear band, level meter
	local portrait = new("Frame", { Name = "Portrait", ClipsDescendants = true, Visible = false }, frame)
	boxed(portrait)
	local inner = new("Frame", { Name = "Inner", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, PORTRAIT_H), BackgroundTransparency = 1 }, portrait)
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 40, 52), BackgroundTransparency = 0.2, Ambient = Color3.fromRGB(40, 120, 140), LightColor = Color3.fromRGB(140, 235, 255), LightDirection = Vector3.new(-0.4, -1, -0.6), ImageColor3 = Color3.fromRGB(150, 235, 255), ImageTransparency = 0.12 }, inner)
	local clone = hologramClone(model)
	if clone then
		local cr = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
		local cf = if cr then cr.CFrame else clone:GetPivot()
		clone.Parent = vp
		local cam = new("Camera", { FieldOfView = 30 }, vp)
		cam.CFrame = CFrame.lookAt((cf * CFrame.new(1.2, 1.4, -6.2)).Position, (cf * CFrame.new(0, 1.1, 0)).Position)
		vp.CurrentCamera = cam
	end
	for i = 0, 27 do
		new("Frame", { Position = UDim2.new(0, 0, i / 28, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(0, 20, 28), BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 3 }, inner)
	end
	local scan = new("Frame", { Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = CYAN, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 4 }, inner)
	local tear = new("Frame", { Name = "Tear", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = WHITE, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 7, Visible = false }, portrait)
	local meter = {}
	for i = 1, 6 do
		table.insert(meter, new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4 + (i - 1) * 3, 1, -4), Size = UDim2.fromOffset(2, 3), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 5 }, inner))
	end
	-- status row: target, timer, payload status, breach progress
	local status = new("Frame", { Name = "Status", Position = UDim2.fromOffset(0, HEADER_H + PORTRAIT_H), Size = UDim2.new(1, 0, 0, STATUS_H), BackgroundTransparency = 1, Visible = false }, frame)
	text(status, { Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -40, 0, 10), Text = "TARGET // " .. displayName, TextSize = 8 })
	local timer = text(status, { Position = UDim2.new(1, -38, 0, 2), Size = UDim2.fromOffset(36, 10), Text = "00:00", TextXAlignment = Enum.TextXAlignment.Right, TextSize = 8 })
	local statusText = text(status, { Position = UDim2.fromOffset(2, 12), Size = UDim2.new(1, -4, 0, 12), Text = string.upper(hackName) .. " PAYLOAD", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 10 })
	local track = new("Frame", { Position = UDim2.fromOffset(2, 26), Size = UDim2.new(1, -4, 0, 2), BackgroundColor3 = CYAN_DIM, BackgroundTransparency = 0.5, BorderSizePixel = 0 }, status)
	local bar = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = CYAN, BorderSizePixel = 0 }, track)
	-- message box: typed narration (arrives offset + narrow, then settles)
	local mbox = new("Frame", { Name = "Message", Position = UDim2.fromOffset(0, HEADER_H + PORTRAIT_H + STATUS_H + 4), Size = UDim2.new(1, 0, 0, MSG_H), Visible = false }, frame)
	boxed(mbox)
	text(mbox, { Position = UDim2.fromOffset(6, 2), Size = UDim2.new(1, -12, 0, 12), Text = "◆ WRIST OS   ·ıl  ENCRYPTED", Font = Enum.Font.GothamBold, TextSize = 8 })
	local msg = text(mbox, { Position = UDim2.fromOffset(6, 16), Size = UDim2.new(1, -12, 1, -18), Text = "", TextColor3 = WHITE, Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	-- brackets on the target
	local brackets = new("BillboardGui", { Name = "WORLD_EXE_HackBrackets", Adornee = root, Size = UDim2.new(5, 0, 6, 0), StudsOffset = Vector3.new(0, 0.6, 0), AlwaysOnTop = true, LightInfluence = 0, ResetOnSpawn = false }, pg)
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		new("Frame", { AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.new(0.18, 0, 0, 2), BackgroundColor3 = CYAN, BorderSizePixel = 0 }, brackets)
		new("Frame", { AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.new(0, 2, 0.15, 0), BackgroundColor3 = CYAN, BorderSizePixel = 0 }, brackets)
	end
	-- tether: card corner -> target chest
	local anchor = new("Part", { Name = "HackHologramAnchor", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) }, workspace.CurrentCamera)
	local a0 = new("Attachment", {}, anchor)
	local a1 = new("Attachment", { Position = Vector3.new(0, 0.6, 0) }, root)
	local beam = new("Beam", { Attachment0 = a0, Attachment1 = a1, Color = ColorSequence.new(CYAN), LightEmission = 1, Transparency = NumberSequence.new(0.35), Width0 = 0.05, Width1 = 0.05, FaceCamera = true, Segments = 1, Enabled = false }, anchor)
	local h: Holo = {
		root = root, card = card, frame = frame, header = header, portrait = portrait, status = status, mbox = mbox, tear = tear,
		brackets = brackets, anchor = anchor, a1 = a1, beam = beam, bar = bar, timer = timer, statusText = statusText, msg = msg,
		dot = dot, glitch = glitch, scan = scan, vp = vp, meter = meter,
		t0 = os.clock(), typed = "", want = "Handshake established.", nextChar = math.huge, blinkUntil = 0, closing = false, conn = nil,
	}
	current = h
	-- OPEN, staged like the reference (whole video frames)
	setPortraitOpen(h, 0)
	task.spawn(function()
		-- f0: a thin broken line
		portrait.Visible = true
		tear.Visible = true
		tear.BackgroundTransparency = 0.1
		task.wait(FRAME)
		-- f1: the portrait tears open from the line; the message box arrives offset and narrow; tether on
		setPortraitOpen(h, 0.62)
		mbox.Visible = true
		mbox.Position = UDim2.fromOffset(34, HEADER_H + PORTRAIT_H + STATUS_H + 4)
		mbox.Size = UDim2.new(0.62, 0, 0, MSG_H)
		beam.Enabled = true
		task.wait(FRAME)
		-- f2: the whole card jolts sideways; status row appears; portrait fully open
		setPortraitOpen(h, 1)
		frame.Position = UDim2.fromOffset(-9, 0)
		status.Visible = true
		mbox.Position = UDim2.fromOffset(0, HEADER_H + PORTRAIT_H + STATUS_H + 4)
		mbox.Size = UDim2.new(1, 0, 0, MSG_H)
		task.wait(FRAME)
		-- f3: header pops in, everything snaps; typing starts two frames later
		frame.Position = UDim2.fromOffset(0, 0)
		header.Visible = true
		tear.Visible = false
		h.nextChar = os.clock() + 2 * FRAME
	end)
	local frameN = 0
	h.conn = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if not root.Parent then
			HackHologram.Close("cancel", true)
			return
		end
		frameN += 1
		local el = now - h.t0
		timer.Text = string.format("%02d:%02d", math.floor(el / 60), math.floor(el % 60))
		dot.BackgroundTransparency = if math.floor(el * 2.5) % 2 == 0 then 0 else 0.8
		scan.Position = UDim2.new(0, 0, (el * 0.45) % 1.1 - 0.05, 0)
		-- level meter bounces (every 2 frames)
		if frameN % 2 == 0 then
			for _, b in meter do
				b.Size = UDim2.fromOffset(2, math.random(2, 9))
			end
		end
		-- header glitch block flickers now and then
		if math.random() < 0.06 then
			glitch.Visible = true
			glitch.BackgroundColor3 = if math.random() < 0.5 then RED else WHITE
			glitch.Position = UDim2.fromOffset(math.random(60, 170), 3)
		elseif math.random() < 0.3 then
			glitch.Visible = false
		end
		-- portrait: rare tear line + jitter (only while open)
		if not h.closing and header.Visible then
			if math.random() < 0.02 then
				tear.Visible = true
				tear.Position = UDim2.new(0, 0, math.random(15, 85) / 100, 0)
				vp.Position = UDim2.fromOffset(math.random(-4, 4), 0)
			elseif tear.Visible and math.random() < 0.5 then
				tear.Visible = false
				tear.Position = UDim2.fromScale(0, 0.5)
				vp.Position = UDim2.fromOffset(0, 0)
			end
		end
		-- message box blinks dim when a new message arrives, then types ~1 char per frame (sometimes 2)
		mbox.BackgroundTransparency = if now < h.blinkUntil then 0.75 else 0.25
		msg.TextTransparency = if now < h.blinkUntil then 0.6 else 0
		if now >= h.blinkUntil and #h.typed < #h.want and now >= h.nextChar then
			local step = if math.random() < 0.25 then 2 else 1
			h.typed = string.sub(h.want, 1, #h.typed + step)
			h.nextChar = now + FRAME
		end
		local cursor = if math.floor(el * 3) % 2 == 0 then "▌" else ""
		msg.Text = h.typed .. (if not h.closing or #h.typed < #h.want then cursor else "")
		local cam = workspace.CurrentCamera
		if cam then
			local cf = cam.CFrame
			anchor.CFrame = CFrame.new(root.Position + cf.RightVector * (OFFSET.X + 2.2) + cf.UpVector * (OFFSET.Y - 2.2))
		end
	end)
end

local LINES = { { 0, "Handshake established." }, { 0.3, "Bypassing firewall..." }, { 0.65, "Injecting payload..." }, { 0.95, "Overriding control..." } }

local function setMessage(h: Holo, line: string)
	if line ~= h.want then
		h.want, h.typed = line, ""
		h.blinkUntil = os.clock() + 0.12 -- the reference blinks the box dim before a new line
	end
end

-- p: challenge progress 0..1
function HackHologram.Progress(p: number)
	local h = current
	if not h or h.closing then
		return
	end
	p = math.clamp(p, 0, 1)
	TweenService:Create(h.bar, TweenInfo.new(0.15), { Size = UDim2.fromScale(p, 1) }):Play()
	local line = LINES[1][2]
	for _, l in LINES do
		if p >= l[1] then
			line = l[2]
		end
	end
	setMessage(h, line)
end

-- how: "success" | "fail" | "cancel". instant = remove at once (no closing sequence).
function HackHologram.Close(how: string, instant: boolean?)
	local h = current
	if not h then
		return
	end
	local function destroy()
		if h.conn then
			h.conn:Disconnect()
		end
		h.card:Destroy()
		h.brackets:Destroy()
		h.anchor:Destroy()
		h.a1:Destroy()
		if current == h then
			current = nil
		end
	end
	if instant then
		destroy()
		return
	end
	if h.closing then
		return
	end
	h.closing = true
	local ok = how == "success"
	h.bar.Size = UDim2.fromScale(if ok then 1 else h.bar.Size.X.Scale, 1)
	h.bar.BackgroundColor3 = if ok then GREEN else CORAL
	h.statusText.Text = if ok then "ACCESS GRANTED" else "LINK LOST"
	h.statusText.TextColor3 = if ok then GREEN else CORAL
	setMessage(h, if ok then "Target compromised." else "Uplink terminated.")
	task.delay(1.2, function()
		-- CLOSE, staged like the reference: header -> status -> portrait squashes into a torn band (tether
		-- drops) -> message box last
		h.header.Visible = false
		task.wait(2 * FRAME)
		h.status.Visible = false
		h.tear.Visible = true
		h.tear.Position = UDim2.fromScale(0, 0.5)
		setPortraitOpen(h, 0.55)
		task.wait(2 * FRAME)
		setPortraitOpen(h, 0.18)
		h.beam.Enabled = false
		task.wait(2 * FRAME)
		h.portrait.Visible = false
		task.wait(2 * FRAME)
		h.mbox.Visible = false
		destroy()
	end)
end

function HackHologram.IsOpen(): boolean
	return current ~= nil
end

return HackHologram

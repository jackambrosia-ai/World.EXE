--!strict
-- HackFeel (wrist-hacking prototype, client): the game-feel layer (owner directive 2026-11-16,
-- section 8). Each event has its own SOUND (built-in engine sounds only: no uploads, no
-- copyrighted audio; distinct cues come from pitch and rhythm), optional GAMEPAD HAPTIC (only when
-- the device reports support), a brief screen-EDGE glow (never covers the centre) and a short
-- POPUP word. Reduced Effects removes the glow and popups' motion; sounds stay (they carry meaning).
--
-- Cues: tick (correct arrow) · wrong · sequence (input complete — NOT a hit) · hit (hack landed) ·
--       incoming (you are targeted) · deflect · perfect · evaded · failed (rejection) · launch

local HapticService = game:GetService("HapticService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UITheme = require(script.Parent:WaitForChild("UITheme"))
local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local C = UITheme.Color
local F = UITheme.Font

local SND = {
	click = "rbxasset://sounds/volume_slider.ogg",
	boom = "rbxasset://sounds/impact_explosion_03.mp3",
	land = "rbxasset://sounds/action_jump_land.mp3",
	jump = "rbxasset://sounds/action_jump.mp3",
	getup = "rbxasset://sounds/action_get_up.mp3",
}

-- { sound, playbackSpeed, volume, delay }
local CUES: { [string]: { { any } } } = {
	tick = { { "click", 1.7, 0.55, 0 } },
	wrong = { { "click", 0.55, 0.7, 0 }, { "click", 0.5, 0.6, 0.07 } },
	sequence = { { "click", 1.3, 0.6, 0 }, { "click", 1.65, 0.6, 0.06 }, { "click", 2.1, 0.7, 0.12 } },
	hit = { { "boom", 1.9, 0.45, 0 }, { "click", 2.4, 0.7, 0.02 } },
	incoming = { { "click", 0.9, 0.8, 0 }, { "click", 0.9, 0.8, 0.16 }, { "click", 0.9, 0.8, 0.32 } },
	deflect = { { "boom", 1.25, 0.6, 0 }, { "land", 1.7, 0.8, 0 }, { "click", 2.0, 0.6, 0.05 } },
	perfect = { { "boom", 1.1, 0.7, 0 }, { "land", 1.5, 0.9, 0 }, { "click", 2.0, 0.7, 0.05 }, { "click", 2.5, 0.7, 0.11 }, { "click", 3.0, 0.7, 0.17 } },
	evaded = { { "jump", 1.4, 0.6, 0 }, { "click", 1.8, 0.5, 0.05 } },
	failed = { { "click", 0.45, 0.7, 0 } },
	launch = { { "boom", 1.4, 0.4, 0 } },
}

local HAPTIC: { [string]: { number } } = { -- { motor small, motor large, seconds }
	hit = { 0.4, 0, 0.08 },
	incoming = { 0.25, 0, 0.25 },
	deflect = { 0.6, 0.4, 0.12 },
	perfect = { 0.9, 0.8, 0.18 },
	failed = { 0, 0.2, 0.06 },
}

local EDGE: { [string]: Color3 } = {
	hit = C.Cyan, deflect = C.Green, perfect = C.Text, incoming = C.Coral, evaded = C.Ice, failed = C.Coral,
}

local HackFeel = {}

local gui: ScreenGui? = nil
local edge: Frame? = nil
local edgeStroke: UIStroke? = nil
local popup: TextLabel? = nil
local popupScale: UIScale? = nil
local soundPool: { [string]: Sound } = {}

local function ensure()
	if gui then
		return
	end
	local g, root = UIUtil.screen("WORLD_EXE_HackFeel", 9)
	g.IgnoreGuiInset = true
	gui = g
	local e = UIUtil.create("Frame", { Name = "Edge", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, root) :: Frame
	local st = UIUtil.stroke(e, C.Cyan, 10, 0.2)
	edge, edgeStroke = e, st
	local p = UIUtil.text("Popup", root, "", 30, C.Text, F.Display, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24), -- above the camera centre, never over the character
		TextStrokeTransparency = 0.2,
		Visible = false,
	})
	local s = Instance.new("UIScale")
	s.Parent = p
	popup, popupScale = p, s
end

local function play(name: string, speed: number, volume: number)
	local id = SND[name]
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed
	s.Volume = volume
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(4, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

local function haptic(cue: string)
	local h = HAPTIC[cue]
	if not h or not UserInputService.GamepadEnabled then
		return
	end
	local pad = Enum.UserInputType.Gamepad1
	local ok = pcall(function()
		if HapticService:IsVibrationSupported(pad) then
			if h[1] > 0 and HapticService:IsMotorSupported(pad, Enum.VibrationMotor.Small) then
				HapticService:SetMotor(pad, Enum.VibrationMotor.Small, h[1])
			end
			if h[2] > 0 and HapticService:IsMotorSupported(pad, Enum.VibrationMotor.Large) then
				HapticService:SetMotor(pad, Enum.VibrationMotor.Large, h[2])
			end
			task.delay(h[3], function()
				pcall(function()
					HapticService:SetMotor(pad, Enum.VibrationMotor.Small, 0)
					HapticService:SetMotor(pad, Enum.VibrationMotor.Large, 0)
				end)
			end)
		end
	end)
	local _ = ok
end

local edgeSerial = 0
local function edgeGlow(color: Color3, seconds: number)
	ensure()
	if UITheme.reducedEffects() or not edge or not edgeStroke then
		return
	end
	edgeSerial += 1
	local mine = edgeSerial
	edge.Visible = true
	edgeStroke.Color = color
	edgeStroke.Transparency = 0.15
	TweenService:Create(edgeStroke, TweenInfo.new(seconds), { Transparency = 1 }):Play()
	task.delay(seconds, function()
		if mine == edgeSerial and edge then
			edge.Visible = false
		end
	end)
end

local popSerial = 0
function HackFeel.Popup(text: string, color: Color3?, big: boolean?)
	ensure()
	if not popup or not popupScale then
		return
	end
	popSerial += 1
	local mine = popSerial
	popup.Text = text
	popup.TextColor3 = color or C.Text
	popup.TextSize = if big then 40 else 28
	popup.Visible = true
	popup.TextTransparency = 0
	if not UITheme.reducedEffects() then
		popupScale.Scale = 1.4
		TweenService:Create(popupScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	task.delay(0.9, function()
		if mine == popSerial and popup then
			TweenService:Create(popup, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			task.delay(0.32, function()
				if mine == popSerial and popup then
					popup.Visible = false
				end
			end)
		end
	end)
end

function HackFeel.Cue(cue: string)
	local list = CUES[cue]
	if list then
		for _, c in list do
			if (c[4] :: number) > 0 then
				task.delay(c[4] :: number, play, c[1] :: string, c[2] :: number, c[3] :: number)
			else
				play(c[1] :: string, c[2] :: number, c[3] :: number)
			end
		end
	end
	haptic(cue)
	local col = EDGE[cue]
	if col then
		edgeGlow(col, if cue == "perfect" then 0.45 elseif cue == "incoming" then 0.6 else 0.3)
	end
end

return HackFeel

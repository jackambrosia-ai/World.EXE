--!strict
-- UITheme (Phase 8B-1B): shared design tokens, layout modes, glyphs and the session-only
-- Reduced Effects switch for the WORLD.EXE client UI. Presentation only.
--
-- Layout modes (from the root frame's absolute size and the device's input):
--   "desktop"  wide screens with mouse/keyboard
--   "compact"  small desktop windows (height < 820 or width < 1280)
--   "touch"    touch-first devices (no mouse); landscape or portrait
-- Studio-only layout preview: set attribute "WORLD_EXE_UITest" on the LocalPlayer to
-- "844x390:touch" (WxH:mode). Every controller then lays out inside a frame of that size, and
-- the native touch-control zones are outlined for review. Ignored outside Studio.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UITheme = {}

local rgb = Color3.fromRGB
UITheme.Color = table.freeze({
	Navy = rgb(10, 15, 31),
	Charcoal = rgb(22, 27, 41),
	Surface2 = rgb(31, 37, 55),
	Steel = rgb(58, 66, 88),
	Text = rgb(245, 247, 255),
	Muted = rgb(163, 172, 198),
	Cyan = rgb(0, 225, 255),
	Violet = rgb(138, 43, 226),
	VioletText = rgb(180, 140, 255),
	Magenta = rgb(214, 38, 170),
	Amber = rgb(255, 193, 7),
	Coral = rgb(255, 111, 97),
	Green = rgb(60, 220, 140),
	Ice = rgb(175, 230, 255),
	Teal = rgb(0, 190, 170),
})
local C = UITheme.Color

UITheme.Font = table.freeze({
	Display = Enum.Font.GothamBlack,
	Title = Enum.Font.GothamBold,
	Label = Enum.Font.GothamBold,
	Body = Enum.Font.Gotham,
	Mono = Enum.Font.RobotoMono,
})

UITheme.SurfaceTransparency = 0.18

-- Patch categories: colour plus glyph and short code, so meaning never depends on colour alone.
UITheme.Category = table.freeze({
	Physics = table.freeze({ Color = C.Violet, Text = C.VioletText, Glyph = "◆", Code = "PHYS" }),
	Environment = table.freeze({ Color = C.Teal, Text = C.Teal, Glyph = "≈", Code = "ENV" }),
	Entity = table.freeze({ Color = C.Coral, Text = C.Coral, Glyph = "▲", Code = "THREAT" }),
	Beneficial = table.freeze({ Color = C.Green, Text = C.Green, Glyph = "+", Code = "AID" }),
	Hazard = table.freeze({ Color = C.Magenta, Text = rgb(255, 120, 215), Glyph = "!", Code = "HAZ" }),
})
local DEFAULT_CATEGORY = table.freeze({ Color = C.Cyan, Text = C.Cyan, Glyph = "•", Code = "SYS" })
function UITheme.category(name: string?): { [string]: any }
	return (name and UITheme.Category[name]) or DEFAULT_CATEGORY
end

-- Patch icon glyphs (rendered as text; no uploaded assets) and 2-letter codes.
UITheme.PatchIcon = table.freeze({
	ZERO_G = "◎",
	DECAY = "▤",
	DRONE_SWARM = "▲",
	SUPPLY_DROP = "▣",
	BOUNCY = "◈",
	SLIPPERY = "◇",
	BLACKOUT = "◐",
	MAGNETIC = "∩",
	CORRUPTION = "※",
	FLOOD = "≈",
})
UITheme.PatchCode = table.freeze({
	ZERO_G = "ZG", DECAY = "DC", DRONE_SWARM = "DR", SUPPLY_DROP = "SD", BOUNCY = "BN",
	SLIPPERY = "SL", BLACKOUT = "BO", MAGNETIC = "MG", CORRUPTION = "CR", FLOOD = "FL",
})
UITheme.ChipSerial = table.freeze({
	ZERO_G = "WX-01", DECAY = "WX-02", DRONE_SWARM = "WX-03", SUPPLY_DROP = "WX-04", BOUNCY = "WX-05",
	SLIPPERY = "WX-06", BLACKOUT = "WX-07", MAGNETIC = "WX-08", CORRUPTION = "WX-09", FLOOD = "WX-10",
})
UITheme.Severity = table.freeze({ mild = 1, standard = 2, severe = 3 })

-- Splits a catalog warning "HEADLINE — counterplay" into its two parts.
function UITheme.splitWarning(text: string): (string, string)
	local a, b = string.match(text, "^(.-)%s+—%s+(.+)$")
	if a and b then
		return a, b
	end
	return text, ""
end

---------------------------------------------------------------------------------------------------
-- Layout

export type Layout = {
	Mode: string, -- "desktop" | "compact" | "touch"
	Width: number,
	Height: number,
	Portrait: boolean,
	Scale: number, -- 1 desktop, smaller on compact/touch
}

local preview: { Width: number, Height: number, Mode: string }? = nil

local function readPreview()
	preview = nil
	if not RunService:IsStudio() then
		return
	end
	local player = Players.LocalPlayer
	local raw = player and player:GetAttribute("WORLD_EXE_UITest")
	if typeof(raw) == "string" then
		local w, h, m = string.match(raw, "^(%d+)x(%d+):?(%a*)$")
		if w and h then
			preview = { Width = tonumber(w) :: number, Height = tonumber(h) :: number, Mode = if m and m ~= "" then m else "touch" }
		end
	end
end

function UITheme.isTouchDevice(): boolean
	if preview then
		return preview.Mode == "touch"
	end
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- The preview frame size (Studio only) or nil for the real screen.
function UITheme.previewSize(): Vector2?
	return if preview then Vector2.new(preview.Width, preview.Height) else nil
end

function UITheme.layout(size: Vector2): Layout
	local w, h = size.X, size.Y
	local mode
	if UITheme.isTouchDevice() then
		mode = "touch"
	elseif h < 820 or w < 1280 then
		mode = "compact"
	else
		mode = "desktop"
	end
	local scale = if mode == "desktop" then 1 elseif mode == "compact" then 0.9 else 0.8
	return { Mode = mode, Width = w, Height = h, Portrait = h > w, Scale = scale }
end

-- Roblox's native touch controls (PlayerModule TouchJump / thumbstick) for a screen size:
-- the jump button rectangle and the movement zone, in pixels from the top-left.
function UITheme.nativeTouchZones(size: Vector2): { Jump: Rect, Move: Rect }
	local w, h = size.X, size.Y
	local small = math.min(w, h) <= 500
	local s = if small then 70 else 120
	local jx = w - (s * 1.5 - 10)
	local jy = if small then h - s - 20 else h - s * 1.75
	return {
		Jump = Rect.new(jx, jy, jx + s, jy + s),
		Move = Rect.new(0, h * 0.45, w * 0.4, h),
	}
end

---------------------------------------------------------------------------------------------------
-- Reduced Effects (session-only; there is no persistence)

local reduced = false
local reducedChanged = Instance.new("BindableEvent")
UITheme.ReducedEffectsChanged = reducedChanged.Event

function UITheme.reducedEffects(): boolean
	return reduced
end

function UITheme.setReducedEffects(on: boolean)
	if on ~= reduced then
		reduced = on
		reducedChanged:Fire(on)
	end
end

-- Tween that respects Reduced Effects (applies the end state instantly when reduced).
function UITheme.tween(inst: Instance, seconds: number, goal: { [string]: any }): Tween?
	if reduced or seconds <= 0 then
		for k, v in goal do
			(inst :: any)[k] = v
		end
		return nil
	end
	local t = TweenService:Create(inst, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local previewChanged = Instance.new("BindableEvent")
UITheme.PreviewChanged = previewChanged.Event

local initialised = false
function UITheme.init()
	if initialised then
		return
	end
	initialised = true
	readPreview()
	local player = Players.LocalPlayer
	if player and RunService:IsStudio() then
		player:GetAttributeChangedSignal("WORLD_EXE_UITest"):Connect(function()
			readPreview()
			previewChanged:Fire()
		end)
	end
end

return UITheme

--!strict
-- ArrowGlyph (wrist-hacking prototype): an unmistakable directional arrow built from native UI frames
-- (owner directive 2026-11-16, section 9): a visible SHAFT plus a two-stroke ARROWHEAD, rotated per
-- direction, so ↑ ↓ ← → read immediately at small sizes (the old triangles were ambiguous).
-- States never rely on colour alone:
--   current  : larger, bright, thick outline, direction word below ("UP"), gentle idle pulse
--   upcoming : normal size, muted
--   done     : dimmed arrow + "✓" badge
--   wrong    : brief coral outline + shake + "×" badge (restrained)
-- Pulse() is the small satisfying response to a correct press.

local TweenService = game:GetService("TweenService")
local UITheme = require(script.Parent:WaitForChild("UITheme"))
local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local C = UITheme.Color
local F = UITheme.Font

local ROT: { [string]: number } = { R = 0, D = 90, L = 180, U = -90 }
local WORD: { [string]: string } = { U = "UP", D = "DOWN", L = "LEFT", R = "RIGHT" }

export type Glyph = {
	Frame: Frame,
	SetState: (state: string) -> (),
	Pulse: () -> (),
	Shake: () -> (),
	SetDir: (dir: string) -> (),
}

local ArrowGlyph = {}

-- size: pixel edge of the square chip; showWord: draw the direction word under the current arrow
function ArrowGlyph.new(parent: Instance, dir: string, size: number, order: number?, showWord: boolean?): Glyph
	local chip = UIUtil.create("Frame", {
		Name = "Arrow_" .. dir,
		LayoutOrder = order or 0,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = C.Charcoal,
		BorderSizePixel = 0,
	}, parent) :: Frame
	UIUtil.corner(chip, math.max(4, math.floor(size * 0.18)))
	local stroke = UIUtil.stroke(chip, C.Steel, 1)
	local scale = Instance.new("UIScale")
	scale.Parent = chip
	-- inner square that rotates; the arrow is drawn pointing RIGHT inside it
	local inner = UIUtil.create("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.82, 0.82),
		Rotation = ROT[dir] or 0,
	}, chip) :: Frame
	local thick = 0.17
	local bars: { Frame } = {}
	local function bar(name: string, cx: number, cy: number, w: number, rot: number)
		local b = UIUtil.create("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(cx, cy),
			Size = UDim2.fromScale(w, thick),
			Rotation = rot,
			BorderSizePixel = 0,
			BackgroundColor3 = C.Muted,
		}, inner) :: Frame
		UIUtil.corner(b, 99)
		table.insert(bars, b)
	end
	-- shaft from x 0.10 to the tip region, head strokes meeting at the tip (0.88, 0.5)
	bar("Shaft", 0.46, 0.5, 0.70, 0)
	local L = 0.42
	local d = (L / 2) * 0.7071
	bar("HeadA", 0.88 - d, 0.5 - d, L, 45)
	bar("HeadB", 0.88 - d, 0.5 + d, L, -45)
	local badge = UIUtil.text("Badge", chip, "", math.max(10, math.floor(size * 0.32)), C.Green, F.Title, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -1, 0, -2),
		ZIndex = 3,
	})
	local word = UIUtil.text("Word", chip, "", math.max(9, math.floor(size * 0.24)), C.Cyan, F.Label, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Visible = false,
	})
	local currentDir = dir
	local idle: Tween? = nil

	local g: Glyph
	g = {
		Frame = chip,
		SetDir = function(nd: string)
			currentDir = nd
			inner.Rotation = ROT[nd] or 0
			word.Text = WORD[nd] or ""
		end,
		SetState = function(st: string)
			if idle then
				idle:Cancel()
				idle = nil
			end
			scale.Scale = 1
			local col, alpha, sc, strokeCol, strokeT, b = C.Muted, 0, 1, C.Steel, 1, ""
			word.Visible = false
			if st == "current" then
				col, sc, strokeCol, strokeT = C.Text, 1.12, C.Cyan, 3
				chip.BackgroundColor3 = C.Surface2
				word.Visible = showWord == true
				word.Text = WORD[currentDir] or ""
				if not UITheme.reducedEffects() then
					idle = TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.04 })
					;(idle :: Tween):Play()
				end
			elseif st == "done" then
				col, alpha, strokeCol, b = C.Green, 0.55, C.Green, "✓"
				chip.BackgroundColor3 = C.Navy
			elseif st == "wrong" then
				col, strokeCol, strokeT, b = C.Coral, C.Coral, 2, "×"
				chip.BackgroundColor3 = C.Charcoal
			elseif st == "locked" then
				col, strokeCol, strokeT, b = C.Green, C.Green, 2, "✓"
				chip.BackgroundColor3 = C.Surface2
			elseif st == "pad" then -- touch pad button face: always bright, no badge
				col, strokeCol, strokeT = C.Cyan, C.Cyan, 0
				chip.BackgroundTransparency = 1
			elseif st == "missed" then
				col, alpha, strokeCol, b = C.Coral, 0.5, C.Coral, "×"
				chip.BackgroundColor3 = C.Navy
			else -- upcoming
				col, alpha = C.Muted, 0.15
				chip.BackgroundColor3 = C.Charcoal
			end
			for _, bb in bars do
				bb.BackgroundColor3 = col
				bb.BackgroundTransparency = alpha
			end
			stroke.Color = strokeCol
			stroke.Thickness = strokeT
			scale.Scale = sc
			badge.Text = b
			badge.TextColor3 = if b == "×" then C.Coral else C.Green
		end,
		Pulse = function()
			if UITheme.reducedEffects() then
				return
			end
			scale.Scale = 1.35
			TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end,
		Shake = function()
			if UITheme.reducedEffects() then
				return
			end
			-- shake the inner arrow (the chip itself is positioned by a list layout)
			local base = UDim2.fromScale(0.5, 0.5)
			task.spawn(function()
				for _, dx in { -5, 5, -3, 3, 0 } do
					inner.Position = base + UDim2.fromOffset(dx, 0)
					task.wait(0.03)
				end
				inner.Position = base
			end)
		end,
	}
	g.SetDir(dir)
	g.SetState("upcoming")
	return g
end

return ArrowGlyph

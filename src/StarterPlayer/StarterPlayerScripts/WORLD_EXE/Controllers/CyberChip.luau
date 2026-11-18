--!strict
-- CyberChip (wrist-hacking prototype): the Phase 8B-1B "data chip" look (chamfer marks, serial,
-- icon tile, name, state label, contact pins) as a reusable builder, so the player wrist terminal
-- shares the Architect chips' visual identity without copying ArchitectController's turn logic.
-- ArchitectController itself is NOT changed by the prototype; migrating it onto this module would
-- be a separate, reviewed step.
--
-- States: default, focus, selected, pending, accepted, rejected, disabled, cooldown.

local UITheme = require(script.Parent:WaitForChild("UITheme"))
local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local C = UITheme.Color
local F = UITheme.Font

export type Chip = {
	Button: TextButton,
	SetState: (state: string, label: string?) -> (),
	SetCooldown: (fraction: number, text: string?) -> (),
	State: string,
}

local CyberChip = {}

export type Options = {
	Name: string,
	Serial: string,
	Icon: string,
	Category: string?,
	Effect: string?,
	Hotkey: string?,
	Compact: boolean?,
	Order: number?,
}

function CyberChip.build(parent: Instance, o: Options): Chip
	local cat = UITheme.category(o.Category)
	local compact = o.Compact == true
	local button = UIUtil.create("TextButton", {
		Name = "Chip_" .. o.Name,
		LayoutOrder = o.Order or 0,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Charcoal,
		BorderSizePixel = 0,
		Selectable = true,
		ClipsDescendants = true,
	}, parent) :: TextButton
	UIUtil.corner(button, 3)
	local stroke = UIUtil.stroke(button, C.Steel, 1)
	local corners = {}
	for _, pos in { UDim2.fromOffset(5, 5), UDim2.new(1, -5, 1, -5) } do
		table.insert(corners, UIUtil.create("Frame", { Name = "Chamfer", BackgroundColor3 = cat.Color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 2), Rotation = -45, Position = pos }, button))
	end
	if not compact then
		UIUtil.text("Serial", button, `{o.Serial} · {cat.Code}`, 10, C.Muted, F.Label, { Position = UDim2.fromOffset(12, 4) })
	end
	local top = if compact then 6 else 20
	local icon = UIUtil.create("TextLabel", {
		Name = "Icon",
		BackgroundColor3 = C.Navy,
		Position = UDim2.fromOffset(8, top),
		Size = UDim2.fromOffset(if compact then 22 else 28, if compact then 22 else 28),
		Text = o.Icon,
		TextSize = if compact then 15 else 17,
		Font = F.Title,
		TextColor3 = cat.Text,
	}, button) :: TextLabel
	UIUtil.corner(icon, 4)
	UIUtil.stroke(icon, cat.Color, 1, 0.3)
	local nameX = if compact then 34 else 42
	local name = UIUtil.text("Name", button, o.Name, if compact then 11 else 13, C.Text, F.Title, { Position = UDim2.fromOffset(nameX, top + (if compact then 1 else 0)) })
	local state = UIUtil.text("State", button, "", 10, C.Muted, F.Label, { Position = UDim2.fromOffset(nameX, top + (if compact then 14 else 16)) })
	if o.Hotkey then
		UIUtil.text("Hotkey", button, o.Hotkey, 10, C.Muted, F.Mono, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4) })
	end
	if o.Effect and not compact then
		UIUtil.text("Effect", button, o.Effect, 10, C.Muted, F.Body, {
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(8, top + 32),
			Size = UDim2.new(1, -14, 0, 24),
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	end
	local pins = {}
	for i = 1, 7 do
		table.insert(pins, UIUtil.create("Frame", { Name = "Pin" .. i, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, (i - 4) * 9, 1, 0), Size = UDim2.fromOffset(4, 3), BackgroundColor3 = C.Steel }, button))
	end
	local shade = UIUtil.create("Frame", { Name = "Cooldown", BackgroundColor3 = C.Navy, BackgroundTransparency = 0.25, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), ZIndex = 2 }, button)
	local cdText = UIUtil.text("CooldownText", button, "", 14, C.Text, F.Mono, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -6), ZIndex = 3 })

	local chip: Chip
	chip = {
		Button = button,
		State = "default",
		SetState = function(st: string, label: string?)
			chip.State = st
			local strokeColor, thickness, text, textColor, pinColor, alpha = C.Steel, 1, "", C.Muted, C.Steel, 0
			if st == "focus" then
				strokeColor, thickness, pinColor = C.Cyan, 2, C.Cyan
			elseif st == "selected" then
				strokeColor, thickness, text, textColor, pinColor = C.VioletText, 2, "✓ SELECTED", C.VioletText, C.Cyan
			elseif st == "pending" then
				strokeColor, thickness, text, textColor, pinColor = C.Amber, 2, "HACKING…", C.Amber, C.Amber
			elseif st == "accepted" then
				strokeColor, thickness, text, textColor, pinColor = C.Green, 2, "✓ EXECUTED", C.Green, C.Green
			elseif st == "rejected" then
				strokeColor, thickness, text, textColor, pinColor = C.Coral, 2, "× REJECTED", C.Coral, C.Coral
			elseif st == "disabled" then
				text, alpha = "LOCKED", 0.55
			elseif st == "cooldown" then
				text, alpha = "RECHARGING", 0.35
			end
			if label then
				text = label
			end
			stroke.Color = strokeColor
			stroke.Thickness = thickness
			state.Text = text
			state.TextColor3 = textColor
			button.BackgroundColor3 = if st == "selected" or st == "accepted" then C.Surface2 else C.Charcoal
			for _, p in pins do
				p.BackgroundColor3 = pinColor
			end
			for _, cmark in corners do
				cmark.BackgroundColor3 = if st == "default" or st == "disabled" or st == "cooldown" then cat.Color else strokeColor
			end
			name.TextTransparency = alpha
			icon.TextTransparency = alpha
		end,
		SetCooldown = function(fraction: number, text: string?)
			shade.Size = UDim2.new(1, 0, math.clamp(fraction, 0, 1), 0)
			cdText.Text = text or ""
		end,
	}
	chip.SetState("default")
	return chip
end

return CyberChip

--!strict
-- Small helpers for building placeholder UI from built-in Roblox instances (no uploaded assets).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local Palette = Config.Palette

local UIUtil = {}

function UIUtil.create(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Navy panel with rounded corners and a coloured outline.
function UIUtil.panel(name: string, stroke: Color3, parent: Instance): Frame
	local frame = UIUtil.create("Frame", {
		Name = name,
		BackgroundColor3 = Palette.DeepNavy,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
	}, parent)
	UIUtil.create("UICorner", { CornerRadius = UDim.new(0, 8) }, frame)
	UIUtil.create("UIStroke", { Color = stroke, Thickness = 2 }, frame)
	UIUtil.create("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}, frame)
	return frame
end

function UIUtil.label(name: string, text: string, size: number, color: Color3, parent: Instance): TextLabel
	return UIUtil.create("TextLabel", {
		Name = name,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = Enum.Font.GothamBold,
		BackgroundTransparency = 1,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, size + 6),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
end

function UIUtil.formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return UIUtil

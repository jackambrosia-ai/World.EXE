--!strict
-- UIUtil: small helpers for building the WORLD.EXE UI from native Roblox instances (no uploaded
-- assets). Phase 8B-1B: themed surfaces, text, bars and the per-controller screen root (which
-- also hosts the Studio-only layout preview, see UITheme).

local Players = game:GetService("Players")

local UITheme = require(script.Parent:WaitForChild("UITheme"))
local C = UITheme.Color
local F = UITheme.Font

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

function UIUtil.corner(parent: Instance, radius: number?): UICorner
	return UIUtil.create("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

function UIUtil.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UIUtil.create("UIStroke", {
		Color = color or C.Steel,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function UIUtil.pad(parent: Instance, v: number, h: number?): UIPadding
	local hp = h or v
	return UIUtil.create("UIPadding", {
		PaddingTop = UDim.new(0, v),
		PaddingBottom = UDim.new(0, v),
		PaddingLeft = UDim.new(0, hp),
		PaddingRight = UDim.new(0, hp),
	}, parent)
end

function UIUtil.list(parent: Instance, direction: Enum.FillDirection, gap: number, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	return UIUtil.create("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
	}, parent)
end

-- Glass-like navy surface with a thin steel outline.
function UIUtil.surface(name: string, parent: Instance, props: { [string]: any }?): (Frame, UIStroke)
	local frame = UIUtil.create("Frame", {
		Name = name,
		BackgroundColor3 = C.Navy,
		BackgroundTransparency = UITheme.SurfaceTransparency,
		BorderSizePixel = 0,
	}, parent)
	if props then
		for k, v in props do
			(frame :: any)[k] = v
		end
	end
	UIUtil.corner(frame, 6)
	local stroke = UIUtil.stroke(frame, C.Steel, 1, 0.2)
	return frame, stroke
end

function UIUtil.text(name: string, parent: Instance, text: string, size: number, color: Color3?, font: Enum.Font?, props: { [string]: any }?): TextLabel
	local label = UIUtil.create("TextLabel", {
		Name = name,
		Text = text,
		TextSize = size,
		TextColor3 = color or C.Text,
		Font = font or F.Body,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(0, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	if props then
		for k, v in props do
			(label :: any)[k] = v
		end
	end
	return label
end

-- Thin progress bar: returns the track and the fill (fill size is a fraction on X).
function UIUtil.bar(name: string, parent: Instance, height: number, color: Color3): (Frame, Frame)
	local track = UIUtil.create("Frame", {
		Name = name,
		BackgroundColor3 = C.Steel,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
	}, parent)
	UIUtil.corner(track, math.floor(height / 2))
	local fill = UIUtil.create("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 1, 0),
	}, track)
	UIUtil.corner(fill, math.floor(height / 2))
	return track, fill
end

-- A ScreenGui plus a "Root" frame that fills the safe area (or, in Studio layout preview, a frame
-- of the preview size). Controllers lay everything out inside Root. Returns gui, root.
function UIUtil.screen(name: string, displayOrder: number): (ScreenGui, Frame)
	local player = Players.LocalPlayer
	local gui = UIUtil.create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder,
	}, player:WaitForChild("PlayerGui"))
	local root = UIUtil.create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, gui)
	local function applyPreview()
		local size = UITheme.previewSize()
		if size then
			root.Size = UDim2.fromOffset(size.X, size.Y)
			root.ClipsDescendants = true
		else
			root.Size = UDim2.fromScale(1, 1)
			root.ClipsDescendants = false
		end
	end
	applyPreview()
	UITheme.PreviewChanged:Connect(applyPreview)
	return gui, root
end

function UIUtil.formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return UIUtil

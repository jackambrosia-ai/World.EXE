--!strict
-- AbilityController (Phase 6; Phase 8B-1B controls): ability input, the ability controls, rejection
-- toasts and SCANNER highlights. Presentation only: it sends { abilityId } and shows what the server
-- decides (cooldowns and validation stay server-authoritative).
-- * Input (one coherent architecture): keyboard Q / F / R and gamepad ButtonX / ButtonY / DPadUp
--   through ContextActionService WITHOUT its automatic touch buttons, plus this controller's own
--   on-screen buttons (click / tap). Gamepad presses are ignored while a GUI element has gamepad
--   focus (for example the Architect chips), so they cannot conflict. E stays free for
--   ProximityPrompts.
-- * Layout: a bottom-centre bar on desktop; on touch devices three 56 px buttons arranged around
--   Roblox's native jump button (computed from its documented geometry, never overlapping it or
--   the thumbstick zone). The native joystick and jump button are not replaced.
-- * Slots show READY, ACTIVE (time left) or the cooldown (fill + seconds) from server-set player
--   attributes. Shown only to Participants while the match is ACTIVE or FINAL_PHASE.
-- * SCANNER: highlights are client-only and temporary. Feedback carries a per-player sequence
--   number: older, duplicate or already-expired results are ignored, a "cancelled" message clears
--   the matching scan, and highlights are also removed on expiry, character removal and match end.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local AbilityCatalog = require(shared:WaitForChild("AbilityCatalog"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))
local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local MatchStateClient = require(script.Parent:WaitForChild("MatchStateClient"))

local C = UITheme.Color
local F = UITheme.Font
local Palette = Config.Palette
local S = Config.MatchStates
local REFRESH_SECONDS = 0.1
local TOAST_SECONDS = 2
local MAX_HIGHLIGHTS = 20
local GAMEPAD_KEYS = { [Enum.KeyCode.ButtonX] = true, [Enum.KeyCode.ButtonY] = true, [Enum.KeyCode.DPadUp] = true }
local GLYPH: { [string]: string } = { PHASE_DASH = "»", ANCHOR = "▼", SCANNER = "◉" }
local KIND_COLORS: { [string]: Color3 } = {
	fragment = Palette.NeonCyan,
	bounce = Palette.ElectricPurple,
	slip = Color3.fromRGB(175, 230, 255),
	crate = Palette.ObjectiveGreen,
	drone = Color3.fromRGB(255, 70, 70),
	decay = Palette.AmberWarning,
	corrupt = Color3.fromRGB(255, 40, 200),
	prop = Color3.fromRGB(90, 170, 255),
}
local REASON_TEXT: { [string]: string } = {
	cooldown = "On cooldown",
	rate_limited = "Too fast",
	blocked = "Path blocked",
	start_blocked = "Path blocked",
	no_ground = "No ground there",
}

type Slot = { Button: TextButton, Stroke: UIStroke, Glyph: TextLabel, Key: TextLabel, Name: TextLabel, Status: TextLabel, Shade: Frame }

local AbilityController = {}

function AbilityController.Start(remotes: Instance)
	UITheme.init()
	local player = Players.LocalPlayer
	local request = remotes:WaitForChild(Config.Remotes.RequestAbility) :: RemoteEvent
	local feedback = remotes:WaitForChild(Config.Remotes.AbilityFeedback) :: RemoteEvent

	local gui, root = UIUtil.screen("WORLD_EXE_Abilities", 6)
	gui.Enabled = false
	local holder = UIUtil.create("Frame", { Name = "Controls", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
	local toast, _ = UIUtil.surface("Toast", root, { AnchorPoint = Vector2.new(0.5, 1), AutomaticSize = Enum.AutomaticSize.XY, Visible = false })
	UIUtil.corner(toast, 12)
	UIUtil.pad(toast, 4, 12)
	local toastText = UIUtil.text("Text", toast, "", 12, C.Amber, F.Label)
	local toastSerial = 0

	local function usable(): boolean
		local state = MatchStateClient.Get().State
		return (state == S.Active or state == S.FinalPhase)
			and player:GetAttribute(Config.PlayerAttributes.Role) == Config.Roles.Participant
	end
	local function fire(id: string)
		if usable() then
			request:FireServer({ abilityId = id })
		end
	end

	local slots: { [string]: Slot } = {}
	for _, id in AbilityCatalog.Ids() do
		local def = AbilityCatalog.Get(id) :: AbilityCatalog.AbilityDefinition
		local button = UIUtil.create("TextButton", {
			Name = `Slot_{id}`,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = C.Navy,
			BackgroundTransparency = UITheme.SurfaceTransparency,
			Size = UDim2.fromOffset(64, 64),
			ClipsDescendants = true,
			Selectable = false,
		}, holder) :: TextButton
		UIUtil.corner(button, 8)
		local stroke = UIUtil.stroke(button, C.Cyan, 1)
		local shade = UIUtil.create("Frame", { Name = "Cooldown", BackgroundColor3 = C.Navy, BackgroundTransparency = 0.3, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), ZIndex = 2 }, button)
		local glyph = UIUtil.text("Glyph", button, GLYPH[id] or "•", 22, C.Cyan, F.Title, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0), ZIndex = 3 })
		local key = UIUtil.text("Key", button, def.Key.Name, 10, C.Muted, F.Label, { Position = UDim2.fromOffset(5, 3), ZIndex = 3 })
		local name = UIUtil.text("Name", button, string.upper(def.DisplayName), 9, C.Muted, F.Label, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), ZIndex = 3 })
		local status = UIUtil.text("Status", button, "", 16, C.Text, F.Mono, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0), ZIndex = 4 })
		button.Activated:Connect(function()
			fire(id)
		end)
		slots[id] = { Button = button, Stroke = stroke, Glyph = glyph, Key = key, Name = name, Status = status, Shade = shade }
	end

	-- The native jump button: its live on-screen rectangle when Roblox's TouchGui exists, otherwise
	-- its documented geometry (also used by the Studio layout preview).
	local function jumpRect(size: Vector2): Rect
		if UITheme.previewSize() == nil then
			local touchGui = player:WaitForChild("PlayerGui"):FindFirstChild("TouchGui")
			local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
			if jump and jump:IsA("GuiObject") and jump.Visible and jump.AbsoluteSize.X > 0 then
				local p = jump.AbsolutePosition - root.AbsolutePosition
				return Rect.new(p.X, p.Y, p.X + jump.AbsoluteSize.X, p.Y + jump.AbsoluteSize.Y)
			end
		end
		return UITheme.nativeTouchZones(size).Jump
	end

	-- Placement: desktop bar or touch arc around the native jump button.
	local function applyLayout()
		-- A disabled ScreenGui reports a zero size; fall back to the preview / viewport size.
		local size = root.AbsoluteSize
		if size.X <= 0 then
			size = UITheme.previewSize() or workspace.CurrentCamera.ViewportSize
		end
		local layout = UITheme.layout(size)
		local ids = AbilityCatalog.Ids()
		if layout.Mode == "touch" then
			local jump = jumpRect(size)
			local b = 56
			local gap = 12
			local jcx, jcy = (jump.Min.X + jump.Max.X) / 2, (jump.Min.Y + jump.Max.Y) / 2
			local centres = {
				Vector2.new(jump.Min.X - gap - b / 2, jcy + 4), -- left of jump
				Vector2.new(jump.Min.X - gap - b / 2 + 6, jump.Min.Y - gap - b / 2 + 4), -- up-left
				Vector2.new(jcx + 4, jump.Min.Y - gap - b / 2), -- above jump
			}
			for i, id in ids do
				local slot = slots[id]
				local c = centres[i] or centres[#centres]
				slot.Button.AnchorPoint = Vector2.new(0.5, 0.5)
				slot.Button.Position = UDim2.fromOffset(math.floor(c.X), math.floor(c.Y))
				slot.Button.Size = UDim2.fromOffset(b, b)
				local corner = slot.Button:FindFirstChildOfClass("UICorner")
				if corner then
					corner.CornerRadius = UDim.new(0.5, 0)
				end
				slot.Key.Visible = false
				slot.Name.Visible = false
			end
			toast.Position = UDim2.new(1, -110, 1, -(size.Y - jump.Min.Y) - b - 40)
			toast.AnchorPoint = Vector2.new(1, 1)
		else
			local s = if layout.Mode == "desktop" then 64 else 58
			local gap = 8
			local total = #ids * s + (#ids - 1) * gap
			for i, id in ids do
				local slot = slots[id]
				slot.Button.AnchorPoint = Vector2.new(0, 1)
				slot.Button.Position = UDim2.new(0.5, -total / 2 + (i - 1) * (s + gap), 1, -12)
				slot.Button.Size = UDim2.fromOffset(s, s)
				local corner = slot.Button:FindFirstChildOfClass("UICorner")
				if corner then
					corner.CornerRadius = UDim.new(0, 8)
				end
				slot.Key.Visible = true
				slot.Name.Visible = true
			end
			toast.AnchorPoint = Vector2.new(0.5, 1)
			toast.Position = UDim2.new(0.5, 0, 1, -(s + 22))
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
	player:WaitForChild("PlayerGui").ChildAdded:Connect(function(child: Instance)
		if child.Name == "TouchGui" then
			task.delay(0.5, applyLayout) -- re-place once Roblox's touch controls exist
		end
	end)
	applyLayout()

	local function showToast(text: string)
		toastText.Text = text
		toast.Visible = true
		toastSerial += 1
		local serial = toastSerial
		task.delay(TOAST_SECONDS, function()
			if serial == toastSerial then
				toast.Visible = false
			end
		end)
	end

	for _, id in AbilityCatalog.Ids() do
		local def = AbilityCatalog.Get(id) :: AbilityCatalog.AbilityDefinition
		local action = `WORLD_EXE_{id}`
		ContextActionService:BindAction(action, function(_, inputState: Enum.UserInputState, input: InputObject)
			if inputState ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			if GAMEPAD_KEYS[input.KeyCode] and GuiService.SelectedObject ~= nil then
				return Enum.ContextActionResult.Pass -- the gamepad is navigating a GUI
			end
			fire(id)
			return Enum.ContextActionResult.Pass
		end, false, def.Key, def.GamepadKey)
	end

	-- SCANNER highlights
	local scanSeq = 0
	local highlights: { Highlight } = {}
	local function clearHighlights()
		for _, highlight in highlights do
			highlight:Destroy()
		end
		table.clear(highlights)
	end

	feedback.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		if data.ok == false then
			showToast(REASON_TEXT[tostring(data.reason)] or "Not available")
			return
		end
		if data.abilityId ~= "SCANNER" or typeof(data.seq) ~= "number" then
			return
		end
		if data.cancelled then
			if data.seq >= scanSeq then
				clearHighlights()
			end
			return
		end
		local untilTime = data.activeUntil
		if data.seq <= scanSeq or typeof(untilTime) ~= "number" or untilTime <= workspace:GetServerTimeNow() then
			return -- out of order, duplicate or already expired
		end
		scanSeq = data.seq
		clearHighlights()
		if typeof(data.targets) == "table" then
			for _, entry in data.targets do
				if #highlights >= MAX_HIGHLIGHTS then
					break
				end
				local target = if typeof(entry) == "table" then entry.Target else nil
				if typeof(target) == "Instance" and target:IsA("BasePart") and target:IsDescendantOf(workspace) then
					local color = KIND_COLORS[tostring(entry.Kind)] or Palette.CleanWhite
					local highlight = Instance.new("Highlight")
					highlight.Name = "WORLD_EXE_ScanHighlight"
					highlight.Adornee = target
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					highlight.FillColor = color
					highlight.FillTransparency = 0.7
					highlight.OutlineColor = color
					highlight.Parent = target
					table.insert(highlights, highlight)
				end
			end
		end
		local mySeq = scanSeq
		task.delay(untilTime - workspace:GetServerTimeNow(), function()
			if scanSeq == mySeq then
				clearHighlights()
			end
		end)
	end)
	player.CharacterRemoving:Connect(clearHighlights)

	task.spawn(function()
		while gui.Parent do
			local show = usable()
			gui.Enabled = show
			if not show and #highlights > 0 then
				clearHighlights()
			end
			if show then
				local t = workspace:GetServerTimeNow()
				for _, id in AbilityCatalog.Ids() do
					local def = AbilityCatalog.Get(id) :: AbilityCatalog.AbilityDefinition
					local readyAt = player:GetAttribute(Config.PlayerAttributes.AbilityReadyPrefix .. id)
					local activeUntil = player:GetAttribute(Config.PlayerAttributes.AbilityActivePrefix .. id)
					local slot = slots[id]
					if typeof(activeUntil) == "number" and activeUntil > t then
						slot.Stroke.Color = C.Amber
						slot.Stroke.Thickness = 2
						slot.Shade.Size = UDim2.new(1, 0, 0, 0)
						slot.Glyph.Visible = false
						slot.Status.Text = tostring(math.ceil(activeUntil - t))
						slot.Status.TextColor3 = C.Amber
						slot.Name.Text = "ACTIVE"
						slot.Name.TextColor3 = C.Amber
					elseif typeof(readyAt) == "number" and readyAt > t then
						local frac = math.clamp((readyAt - t) / math.max(def.CooldownSeconds, 0.1), 0, 1)
						slot.Stroke.Color = C.Steel
						slot.Stroke.Thickness = 1
						slot.Shade.Size = UDim2.new(1, 0, frac, 0)
						slot.Glyph.Visible = false
						slot.Status.Text = tostring(math.ceil(readyAt - t))
						slot.Status.TextColor3 = C.Muted
						slot.Name.Text = string.upper(def.DisplayName)
						slot.Name.TextColor3 = C.Muted
					else
						slot.Stroke.Color = C.Cyan
						slot.Stroke.Thickness = 1
						slot.Shade.Size = UDim2.new(1, 0, 0, 0)
						slot.Glyph.Visible = true
						slot.Status.Text = ""
						slot.Name.Text = string.upper(def.DisplayName)
						slot.Name.TextColor3 = C.Muted
					end
				end
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return AbilityController

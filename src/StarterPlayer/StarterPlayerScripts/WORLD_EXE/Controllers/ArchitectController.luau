--!strict
-- ArchitectController (Phase 2; Phase 8B-1B cyber-chip redesign). Shown only to the current
-- Architect during their turn. Shows the server-offered patches as "data chips", a draining turn
-- countdown, an optional keyword search (keyboard only, resolved locally, never broadcast) and a
-- two-step SELECT → CONFIRM flow. Sends only { patchId = <selected> }; the server decides
-- everything.
--
-- Turn identity is MatchId + TurnNumber (turn numbers restart every match). When the identity
-- changes, selection, pending/submitted/rejected state, keyword text and feedback are cleared, and
-- server responses tagged with any other turn are ignored.
--
-- Chip states: default, focus (mouse hover / gamepad selection), selected, disabled (while a
-- submission is pending or after one was accepted), pending, submitted, rejected.
-- Layout: right-side panel (desktop/compact); a top strip below the HUD on touch landscape
-- (clear of the native thumbstick, jump button and ability arc); a 2x2 grid on portrait.
-- Gamepad: chips and CONFIRM are Selectable; focus moves to the first chip when the turn opens
-- (only if a gamepad is the last input). Ability bindings ignore gamepad input while a GUI element
-- has gamepad focus (see AbilityController), so ButtonX / ButtonY / DPadUp cannot fire abilities
-- while the Architect is choosing. ButtonA activates the focused chip or CONFIRM; ButtonB clears.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local PatchCatalog = require(shared:WaitForChild("PatchCatalog"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))
local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local MatchStateClient = require(script.Parent:WaitForChild("MatchStateClient"))

local C = UITheme.Color
local F = UITheme.Font
local REFRESH_SECONDS = 0.1
local CLEAR_ACTION = "WORLD_EXE_ArchitectClear"

local FEEDBACK: { [string]: string } = {
	accepted = "Patch uploaded.",
	rate_limited = "Too many requests — wait a moment.",
	bad_payload = "Request rejected.",
	bad_patch_id = "Request rejected.",
	no_open_turn = "No Architect turn is open.",
	not_architect = "You are not the Architect.",
	stale_turn = "That turn has ended.",
	window_closed = "Time is up.",
	unknown_patch = "Unknown patch.",
	not_offered = "That patch is not on your chips.",
	architect_ineligible = "You can no longer act as Architect this turn.",
	capacity_full = "The simulation is at its patch limit — turn skipped.",
	match_not_live = "The match is not running.",
	duplicate = "That turn already submitted a patch.",
}

type Chip = {
	Button: TextButton,
	Stroke: UIStroke,
	State: TextLabel,
	Pins: { Frame },
	Corners: { Frame },
	Name: TextLabel,
	Effect: TextLabel,
	Icon: TextLabel,
}

local ArchitectController = {}

function ArchitectController.Start(remotes: Instance)
	UITheme.init()
	local player = Players.LocalPlayer
	local request = remotes:WaitForChild(Config.Remotes.RequestPatchSubmission) :: RemoteEvent
	local result = remotes:WaitForChild(Config.Remotes.SubmissionResult) :: RemoteEvent

	local gui, root = UIUtil.screen("WORLD_EXE_Architect", 8)
	gui.Enabled = false

	local panel, panelStroke = UIUtil.surface("Panel", root, { BackgroundTransparency = 0.1, Size = UDim2.fromOffset(344, 0), AutomaticSize = Enum.AutomaticSize.Y })
	panelStroke.Color = C.Violet
	panelStroke.Thickness = 2
	panelStroke.Transparency = 0.1
	UIUtil.pad(panel, 12, 12)
	local panelList = UIUtil.list(panel, Enum.FillDirection.Vertical, 8)

	-- Header: title + countdown
	local header = UIUtil.create("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1 }, panel)
	UIUtil.text("Title", header, "ARCHITECT ACCESS", 15, C.VioletText, F.Display)
	local subtitle = UIUtil.text("Subtitle", header, "Upload one patch to the simulation", 11, C.Muted, F.Body, { Position = UDim2.fromOffset(0, 18) })
	local timer = UIUtil.text("Timer", header, "0:12", 18, C.Amber, F.Mono, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0) })
	local timeTrack, timeFill = UIUtil.bar("TimeBar", panel, 4, C.Amber)
	timeTrack.LayoutOrder = 2

	-- Body: chip grid, plus (touch landscape only) a side column with the timer and CONFIRM
	local body = UIUtil.create("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 }, panel)
	UIUtil.list(body, Enum.FillDirection.Horizontal, 6)
	local grid = UIUtil.create("Frame", { Name = "Chips", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, body)
	local side = UIUtil.create("Frame", { Name = "Side", BackgroundTransparency = 1, Size = UDim2.fromOffset(84, 80), LayoutOrder = 2, Visible = false }, body)
	UIUtil.list(side, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center)
	local gridLayout = UIUtil.create("UIGridLayout", {
		CellSize = UDim2.fromOffset(156, 104),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = 2,
	}, grid) :: UIGridLayout

	-- Keyword search (keyboard only; resolved locally to an offered chip)
	local keywordBox = UIUtil.create("TextBox", {
		Name = "Keyword",
		LayoutOrder = 4,
		PlaceholderText = "Search by keyword, then Enter",
		Text = "",
		ClearTextOnFocus = false,
		TextSize = 12,
		Font = F.Body,
		TextColor3 = C.Text,
		PlaceholderColor3 = C.Muted,
		BackgroundColor3 = C.Charcoal,
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel) :: TextBox
	UIUtil.corner(keywordBox, 6)
	UIUtil.pad(keywordBox, 0, 8)

	local footer = UIUtil.create("Frame", { Name = "Footer", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 5 }, panel)
	local confirm = UIUtil.create("TextButton", {
		Name = "Confirm",
		Size = UDim2.new(1, -56, 1, 0),
		BackgroundColor3 = C.Surface2,
		Text = "SELECT A CHIP",
		TextSize = 14,
		Font = F.Title,
		TextColor3 = C.Muted,
		AutoButtonColor = false,
		Selectable = true,
	}, footer) :: TextButton
	UIUtil.corner(confirm, 6)
	local confirmStroke = UIUtil.stroke(confirm, C.Steel, 1)
	local clear = UIUtil.create("TextButton", {
		Name = "Clear",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 48, 1, 0),
		BackgroundColor3 = C.Charcoal,
		Text = "×",
		TextSize = 16,
		Font = F.Title,
		TextColor3 = C.Muted,
		Selectable = true,
	}, footer) :: TextButton
	UIUtil.corner(clear, 6)
	UIUtil.stroke(clear, C.Steel, 1)

	local feedback = UIUtil.text("Feedback", panel, "", 12, C.Text, F.Body, { LayoutOrder = 6, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true })

	-- State
	local shownKey = "" -- MatchId:TurnNumber currently rendered
	local shownMatch: any = nil
	local selected: string? = nil
	local pending = false
	local submitted: string? = nil
	local rejected: string? = nil
	local focus: { [string]: boolean } = {}
	local chips: { [string]: Chip } = {}
	local chipOrder: { string } = {}
	local compactChips = false

	local function stateOf(id: string): string
		if submitted == id then
			return "submitted"
		elseif pending and selected == id then
			return "pending"
		elseif rejected == id then
			return "rejected"
		elseif selected == id then
			return "selected"
		elseif pending or submitted ~= nil then
			return "disabled"
		elseif focus[id] then
			return "focus"
		end
		return "default"
	end

	local function renderChips()
		for id, chip in chips do
			local def = PatchCatalog.Get(id)
			local cat = UITheme.category(def and def.Category)
			local st = stateOf(id)
			local strokeColor, thickness, label, labelColor, pinColor, alpha = C.Steel, 1, "", C.Muted, C.Steel, 0
			if st == "focus" then
				strokeColor, thickness, pinColor = C.Cyan, 2, C.Cyan
			elseif st == "selected" then
				strokeColor, thickness, label, labelColor, pinColor = C.VioletText, 2, "✓ SELECTED", C.VioletText, C.Cyan
			elseif st == "pending" then
				strokeColor, thickness, label, labelColor, pinColor = C.Amber, 2, "UPLOADING…", C.Amber, C.Amber
			elseif st == "submitted" then
				strokeColor, thickness, label, labelColor, pinColor = C.Green, 2, "✓ UPLOADED", C.Green, C.Green
			elseif st == "rejected" then
				strokeColor, thickness, label, labelColor, pinColor = C.Coral, 2, "× REJECTED", C.Coral, C.Coral
			elseif st == "disabled" then
				label, alpha = "LOCKED", 0.55
			end
			chip.Stroke.Color = strokeColor
			chip.Stroke.Thickness = thickness
			chip.State.Text = label
			chip.State.TextColor3 = labelColor
			chip.Button.BackgroundColor3 = if st == "selected" or st == "submitted" then C.Surface2 else C.Charcoal
			for _, pin in chip.Pins do
				pin.BackgroundColor3 = pinColor
			end
			for _, corner in chip.Corners do
				corner.BackgroundColor3 = if st == "default" or st == "disabled" then cat.Color else strokeColor
			end
			chip.Name.TextTransparency = alpha
			chip.Effect.TextTransparency = alpha
			chip.Icon.TextTransparency = alpha
			chip.Button.AutoButtonColor = false
			chip.Button.Active = st ~= "disabled" and st ~= "pending" and st ~= "submitted"
		end
		local def = selected and PatchCatalog.Get(selected)
		if submitted then
			confirm.Text = "UPLOADED"
			confirm.BackgroundColor3 = C.Surface2
			confirm.TextColor3 = C.Green
			confirmStroke.Color = C.Green
		elseif pending then
			confirm.Text = "UPLOADING…"
			confirm.BackgroundColor3 = C.Surface2
			confirm.TextColor3 = C.Amber
			confirmStroke.Color = C.Amber
		elseif def then
			confirm.Text = "CONFIRM " .. string.upper(def.DisplayName)
			confirm.BackgroundColor3 = C.Violet
			confirm.TextColor3 = C.Text
			confirmStroke.Color = C.VioletText
		else
			confirm.Text = "SELECT A CHIP"
			confirm.BackgroundColor3 = C.Surface2
			confirm.TextColor3 = C.Muted
			confirmStroke.Color = C.Steel
		end
	end

	local function select(id: string?)
		if pending or submitted then
			return
		end
		selected = id
		rejected = nil
		local def = id and PatchCatalog.Get(id)
		if def then
			local _, hint = UITheme.splitWarning(def.Warning)
			feedback.Text = `{string.upper(def.DisplayName)}: {def.Effect}{if hint ~= "" then "  ·  Counter: " .. hint else ""}`
			feedback.TextColor3 = C.Text
		else
			feedback.Text = ""
		end
		renderChips()
	end

	local function resetTurnState()
		selected = nil
		pending = false
		submitted = nil
		rejected = nil
		table.clear(focus)
		keywordBox.Text = ""
		feedback.Text = ""
	end

	-- One data chip (original hardware-module look built from native frames)
	local function buildChip(id: string, order: number): Chip?
		local def = PatchCatalog.Get(id)
		if not def then
			return nil
		end
		local cat = UITheme.category(def.Category)
		local button = UIUtil.create("TextButton", {
			Name = "Chip_" .. id,
			LayoutOrder = order,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = C.Charcoal,
			BorderSizePixel = 0,
			Selectable = true,
		}, grid) :: TextButton
		UIUtil.corner(button, 3)
		local stroke = UIUtil.stroke(button, C.Steel, 1)
		-- Chamfer marks: a hairline diagonal + bracket in two opposite corners
		local corners = {}
		local function cornerMark(pos: UDim2, rot: number)
			local diag = UIUtil.create("Frame", { Name = "Chamfer", BackgroundColor3 = cat.Color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 2), Rotation = rot, Position = pos }, button)
			table.insert(corners, diag)
		end
		cornerMark(UDim2.fromOffset(5, 5), -45)
		cornerMark(UDim2.new(1, -5, 1, -5), -45)
		-- Serial marking + severity pips
		local top = if compactChips then 18 else 22 -- icon / name row
		local effectY = if compactChips then 46 else 56
		UIUtil.text("Serial", button, `{UITheme.ChipSerial[id] or "WX-00"} · {cat.Code}`, 9, C.Muted, F.Label, { Position = UDim2.fromOffset(12, 4) })
		local pips = UIUtil.create("Frame", { Name = "Severity", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 7), Size = UDim2.fromOffset(26, 6) }, button)
		local level = UITheme.Severity[def.Severity] or 1
		for i = 1, 3 do
			UIUtil.create("Frame", {
				Name = "Pip" .. i,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(6, 6),
				Position = UDim2.fromOffset((i - 1) * 9, 0),
				BackgroundColor3 = if i <= level then (if level == 3 then C.Coral elseif level == 2 then C.Amber else C.Green) else C.Steel,
			}, pips)
		end
		-- Icon tile
		local icon = UIUtil.create("TextLabel", {
			Name = "Icon",
			BackgroundColor3 = C.Navy,
			Position = UDim2.fromOffset(9, top),
			Size = UDim2.fromOffset(if compactChips then 26 else 30, if compactChips then 26 else 30),
			Text = UITheme.PatchIcon[id] or "•",
			TextSize = 18,
			Font = F.Title,
			TextColor3 = cat.Text,
		}, button) :: TextLabel
		UIUtil.corner(icon, 4)
		UIUtil.stroke(icon, cat.Color, 1, 0.3)
		local textX = if compactChips then 42 else 46
		local name = UIUtil.text("Name", button, string.upper(def.DisplayName), if compactChips then 12 else 13, C.Text, F.Title, { Position = UDim2.fromOffset(textX, top) })
		local stateLabel = UIUtil.text("State", button, "", 9, C.Muted, F.Label, { Position = UDim2.fromOffset(textX, top + 16) })
		local effect = UIUtil.text("Effect", button, def.Effect, if compactChips then 10 else 11, C.Muted, F.Body, {
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(9, effectY),
			Size = UDim2.new(1, -18, 0, if compactChips then 24 else 28),
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		-- Circuit trace from the icon to the contact pins
		UIUtil.create("Frame", { Name = "Trace", BackgroundColor3 = cat.Color, BackgroundTransparency = 0.7, BorderSizePixel = 0, Position = UDim2.fromOffset(23, top + 30), Size = UDim2.new(0, 1, 1, -(top + 36)) }, button)
		UIUtil.create("Frame", { Name = "Trace2", BackgroundColor3 = cat.Color, BackgroundTransparency = 0.7, BorderSizePixel = 0, Position = UDim2.new(0, 23, 1, -7), Size = UDim2.new(0.5, -23, 0, 1) }, button)
		-- Contact pins along the bottom edge
		local pins = {}
		for i = 1, 7 do
			local pin = UIUtil.create("Frame", {
				Name = "Pin" .. i,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, (i - 4) * 9, 1, 0),
				Size = UDim2.fromOffset(4, 4),
				BackgroundColor3 = C.Steel,
			}, button)
			table.insert(pins, pin)
		end
		button.MouseEnter:Connect(function()
			focus[id] = true
			renderChips()
		end)
		button.MouseLeave:Connect(function()
			focus[id] = nil
			renderChips()
		end)
		button.SelectionGained:Connect(function()
			focus[id] = true
			renderChips()
		end)
		button.SelectionLost:Connect(function()
			focus[id] = nil
			renderChips()
		end)
		button.Activated:Connect(function()
			select(id)
		end)
		return { Button = button, Stroke = stroke, State = stateLabel, Pins = pins, Corners = corners, Name = name, Effect = effect, Icon = icon }
	end

	local function buildChips(offered: { string })
		for _, child in grid:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		table.clear(chips)
		table.clear(chipOrder)
		for i, id in offered do
			local chip = buildChip(id, i)
			if chip then
				chips[id] = chip
				table.insert(chipOrder, id)
			end
		end
		renderChips()
	end

	-- Responsive placement
	local function applyLayout()
		-- A disabled ScreenGui reports a zero size; fall back to the preview / viewport size.
		local size = root.AbsoluteSize
		if size.X <= 0 then
			size = UITheme.previewSize() or workspace.CurrentCamera.ViewportSize
		end
		local layout = UITheme.layout(size)
		local touch = layout.Mode == "touch"
		local strip = touch and not layout.Portrait
		keywordBox.Visible = not touch
		-- Touch landscape: one compact row (chips + a side column with the timer and CONFIRM) that
		-- ends above the native thumbstick zone (top 45 % of the screen only). Elsewhere: header,
		-- grid and a footer with CONFIRM / CLEAR.
		header.Visible = not strip
		footer.Visible = not strip
		side.Visible = strip
		timeTrack.Visible = not strip
		clear.Visible = not strip
		confirm.Parent = if strip then side else footer
		confirm.Size = if strip then UDim2.new(1, 0, 0, 56) else UDim2.new(1, -56, 1, 0)
		confirm.TextSize = if strip then 12 else 14
		confirm.TextWrapped = strip
		timer.Parent = if strip then side else header
		timer.AnchorPoint = if strip then Vector2.new(0, 0) else Vector2.new(1, 0)
		timer.Position = if strip then UDim2.new() else UDim2.new(1, 0, 0, 0)
		feedback.TextSize = if strip then 11 else 12
		panelList.Padding = UDim.new(0, if strip then 6 else 8)
		if compactChips ~= strip then
			compactChips = strip
			if #chipOrder > 0 then
				buildChips(table.clone(chipOrder))
			end
		end
		if strip then
			local cellW = math.clamp(math.floor((size.X - 210) / 4) - 6, 104, 132)
			gridLayout.CellSize = UDim2.fromOffset(cellW, 80)
			gridLayout.CellPadding = UDim2.fromOffset(6, 6)
			gridLayout.FillDirectionMaxCells = 4
			local gridW = 4 * cellW + 3 * 6
			grid.Size = UDim2.fromOffset(gridW, 0)
			panel.Size = UDim2.fromOffset(gridW + 6 + 84 + 16, 0)
			panel.AnchorPoint = Vector2.new(0.5, 0)
			panel.Position = UDim2.new(0.5, 0, 0, 56)
			subtitle.Visible = false
		elseif touch then
			local cellW = math.clamp(math.floor((size.X - 64) / 2), 130, 170)
			gridLayout.CellSize = UDim2.fromOffset(cellW, 96)
			gridLayout.CellPadding = UDim2.fromOffset(8, 8)
			gridLayout.FillDirectionMaxCells = 2
			grid.Size = UDim2.fromOffset(2 * cellW + 8, 0)
			panel.Size = UDim2.fromOffset(2 * cellW + 8 + 24, 0)
			panel.AnchorPoint = Vector2.new(0.5, 0)
			panel.Position = UDim2.new(0.5, 0, 0, 130)
			subtitle.Visible = true
			footer.Size = UDim2.new(1, 0, 0, 48)
		else
			local compact = layout.Mode == "compact"
			local cellW = if compact then 146 else 156
			gridLayout.CellSize = UDim2.fromOffset(cellW, if compact then 98 else 104)
			gridLayout.CellPadding = UDim2.fromOffset(8, 8)
			gridLayout.FillDirectionMaxCells = 2
			grid.Size = UDim2.fromOffset(2 * cellW + 8, 0)
			panel.Size = UDim2.fromOffset(2 * cellW + 8 + 24, 0)
			panel.AnchorPoint = Vector2.new(1, 0.5)
			panel.Position = UDim2.new(1, -12, 0.5, if compact then 10 else 0)
			subtitle.Visible = true
			footer.Size = UDim2.new(1, 0, 0, 44)
		end
		header.Size = UDim2.new(1, 0, 0, if subtitle.Visible then 34 else 20)
		local padding = panel:FindFirstChildOfClass("UIPadding")
		if padding then
			local p = if strip then 8 else 12
			padding.PaddingTop = UDim.new(0, p)
			padding.PaddingBottom = UDim.new(0, p)
			padding.PaddingLeft = UDim.new(0, p)
			padding.PaddingRight = UDim.new(0, p)
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
	applyLayout()

	-- Input
	keywordBox.FocusLost:Connect(function(enterPressed: boolean)
		if not enterPressed or keywordBox.Text == "" then
			return
		end
		local id = PatchCatalog.Resolve(keywordBox.Text)
		if id and chips[id] then
			select(id)
		else
			feedback.Text = "No offered chip matches that keyword."
			feedback.TextColor3 = C.Amber
		end
	end)
	clear.Activated:Connect(function()
		select(nil)
	end)
	confirm.Activated:Connect(function()
		if selected == nil or pending or submitted ~= nil then
			return
		end
		if not chips[selected] then
			return -- never submit a chip that is not on the current offer
		end
		pending = true
		feedback.Text = "Uploading…"
		feedback.TextColor3 = C.Amber
		renderChips()
		request:FireServer({ patchId = selected })
	end)

	result.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		-- Ignore responses for any turn other than the one currently shown.
		if MatchStateClient.TurnKey(data.MatchId, data.TurnNumber) ~= shownKey then
			gui:SetAttribute("IgnoredResponses", (gui:GetAttribute("IgnoredResponses") or 0) + 1)
			return
		end
		pending = false
		local reason = tostring(data.reason)
		if reason == "accepted" then
			submitted = selected
			feedback.TextColor3 = C.Green
		else
			rejected = selected
			feedback.TextColor3 = C.Coral
		end
		feedback.Text = FEEDBACK[reason] or "Request rejected."
		renderChips()
	end)

	local function bindClear(on: boolean)
		if on then
			ContextActionService:BindActionAtPriority(CLEAR_ACTION, function(_, inputState: Enum.UserInputState)
				if inputState == Enum.UserInputState.Begin and GuiService.SelectedObject ~= nil and GuiService.SelectedObject:IsDescendantOf(gui) then
					select(nil)
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
		else
			ContextActionService:UnbindAction(CLEAR_ACTION)
		end
	end

	local wasOpen = false
	task.spawn(function()
		while gui.Parent do
			local snap = MatchStateClient.Get()
			local turn = snap.Turn
			local t = workspace:GetServerTimeNow()
			if snap.MatchId ~= shownMatch then
				-- New match: nothing from the previous match may carry over.
				shownMatch = snap.MatchId
				shownKey = ""
				resetTurnState()
				buildChips({})
			end
			local turnEndsAt = turn.TurnEndsAt
			local mine = turn.ArchitectUserId == player.UserId and typeof(turnEndsAt) == "number" and turnEndsAt > t
			local key = MatchStateClient.TurnKey(turn.TurnMatchId, turn.TurnNumber)
			if mine and key ~= shownKey then
				shownKey = key
				applyLayout()
				resetTurnState()
				buildChips(if typeof(turn.OfferedPatches) == "table" then turn.OfferedPatches else {})
			end
			gui:SetAttribute("TurnKey", shownKey)
			gui.Enabled = mine
			if mine then
				local left = (turnEndsAt :: number) - t
				timer.Text = UIUtil.formatTime(left)
				local window = Config.Architect.SubmissionWindowSeconds
				timeFill.Size = UDim2.new(math.clamp(left / window, 0, 1), 0, 1, 0)
				timeFill.BackgroundColor3 = if left <= 4 then C.Coral else C.Amber
				timer.TextColor3 = if left <= 4 then C.Coral else C.Amber
				panelStroke.Color = if submitted then C.Green else C.Violet
			end
			if mine and not wasOpen then
				applyLayout() -- lay out for the current screen before the first frame is shown
				bindClear(true)
				local last = UserInputService:GetLastInputType()
				if last.Name:find("Gamepad") and chipOrder[1] and chips[chipOrder[1]] then
					GuiService.SelectedObject = chips[chipOrder[1]].Button
				end
			elseif not mine and wasOpen then
				bindClear(false)
				if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
					GuiService.SelectedObject = nil
				end
			end
			wasOpen = mine
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return ArchitectController

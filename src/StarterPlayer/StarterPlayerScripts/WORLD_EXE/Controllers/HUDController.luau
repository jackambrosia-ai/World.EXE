--!strict
-- HUDController (Phase 8B-1B): compact match HUD. Presentation only; it reads the accepted
-- Snapshot (MatchStateClient), server-set player attributes and the PatchAnnouncement remote.
--   * Top centre: phase + timer pill and a slim stability bar (with a target tick and its number).
--   * Alerts: the patch WARNING strip (for the full server-defined warning period), the
--     combination strip and short toasts. Desktop: under the pill. Touch landscape: a top-left
--     column above the native thumbstick zone, so the Architect tray (right of the thumbstick) can
--     never cover a warning. Touch portrait: under the patch chips. Nothing is placed over the
--     screen centre during play.
--   * The HUD publishes its top row as UITheme reserved "hudTop"; touch panels lay out below it.
--   * Top right: one compact chip per running patch / combination (category colour + glyph +
--     code + time-left bar), a personal SHIELD chip, and the Details button.
--   * Details (hidden by default): score, fragments, stabilizer progress, expanded patch list and
--     the session-only Reduced Effects switch. Its height is capped to the free area and its
--     content scrolls; on touch it sits right of the thumbstick zone and left of (or above) the
--     ability buttons, and below an open Architect tray. Opened by the Details button, G (Tab is Roblox's
--     player list) or gamepad DPadDown (ignored while a GUI element has gamepad focus).
--   * RESULTS / RESET: a structured results card built only from Snapshot.LastResult.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("WORLD_EXE")
local Config = require(shared:WaitForChild("Shared"):WaitForChild("Config"))
local PatchCatalog = require(shared:WaitForChild("Shared"):WaitForChild("PatchCatalog"))
local InteractionCatalog = require(shared:WaitForChild("Shared"):WaitForChild("InteractionCatalog"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))
local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local MatchStateClient = require(script.Parent:WaitForChild("MatchStateClient"))

local C = UITheme.Color
local F = UITheme.Font
local S = Config.MatchStates
local Roles = Config.Roles
local REFRESH_SECONDS = 0.2
local TOAST_SECONDS = 2.5
local COMBO_SECONDS = 4.5
local DETAILS_ACTION = "WORLD_EXE_Details"

local PHASE_TEXT: { [string]: string } = {
	[S.Lobby] = "LOBBY",
	[S.Countdown] = "STARTING",
	[S.Initializing] = "LOADING",
	[S.Active] = "ACTIVE",
	[S.FinalPhase] = "FINAL PHASE",
	[S.Results] = "RESULTS",
	[S.Reset] = "RESETTING",
}
local ZONE_SHORT: { [string]: string } = { CentralCore = "CORE", Skybridge = "SKY", ResearchYard = "YARD" }

local HUDController = {}

function HUDController.Start(remotes: Instance)
	UITheme.init()
	local player = Players.LocalPlayer
	local gui, root = UIUtil.screen("WORLD_EXE_HUD", 5)

	---------------------------------------------------------------------------------------------
	-- Top centre: phase pill, stability, warning strip, combination strip, toast
	local top = UIUtil.create("Frame", {
		Name = "TopCenter",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, root)
	UIUtil.list(top, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)

	local pill, pillStroke = UIUtil.surface("PhasePill", top, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 })
	UIUtil.corner(pill, 14)
	UIUtil.pad(pill, 5, 14)
	UIUtil.list(pill, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local phaseLabel = UIUtil.text("Phase", pill, "LOBBY", 13, C.Cyan, F.Label, { LayoutOrder = 1 })
	local divider = UIUtil.create("Frame", { Name = "Divider", BackgroundColor3 = C.Steel, BorderSizePixel = 0, Size = UDim2.fromOffset(1, 16), LayoutOrder = 2 }, pill)
	local timerLabel = UIUtil.text("Timer", pill, "0:00", 18, C.Text, F.Mono, { LayoutOrder = 3 })
	local subLabel = UIUtil.text("Sub", pill, "", 12, C.Muted, F.Body, { LayoutOrder = 4 })

	local stab = UIUtil.create("Frame", { Name = "Stability", BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 14), LayoutOrder = 2 }, top)
	local stabTrack, stabFill = UIUtil.bar("Track", stab, 6, C.Cyan)
	stabTrack.AnchorPoint = Vector2.new(0, 0.5)
	stabTrack.Position = UDim2.new(0, 0, 0.5, 0)
	stabTrack.Size = UDim2.new(1, -34, 0, 6)
	local stabTick = UIUtil.create("Frame", { Name = "TargetTick", BackgroundColor3 = C.Text, BorderSizePixel = 0, Size = UDim2.new(0, 2, 0, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0) }, stabTrack)
	local stabValue = UIUtil.text("Value", stab, "", 12, C.Cyan, F.Mono, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) })

	-- Alerts column: warning strip, combination strip, toast (placed per layout in applyLayout)
	local alerts = UIUtil.create("Frame", { Name = "Alerts", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 }, top)
	local alertsList = UIUtil.list(alerts, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)

	-- Warning strip (one at a time: the soonest WARNING patch)
	local warn, warnStroke = UIUtil.surface("WarningStrip", alerts, { Size = UDim2.fromOffset(440, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Visible = false })
	UIUtil.pad(warn, 8, 10)
	local warnAccent = UIUtil.create("Frame", { Name = "Accent", BackgroundColor3 = C.Amber, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 0), Position = UDim2.new(0, -10, 0, -8) }, warn)
	warnAccent.Size = UDim2.new(0, 4, 1, 16)
	local warnIcon = UIUtil.create("TextLabel", { Name = "Icon", BackgroundColor3 = C.Charcoal, Size = UDim2.fromOffset(38, 38), Text = "◎", TextSize = 22, Font = F.Title, TextColor3 = C.Amber }, warn)
	UIUtil.corner(warnIcon, 6)
	local warnBody = UIUtil.create("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -100, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, warn)
	UIUtil.list(warnBody, Enum.FillDirection.Vertical, 2)
	local warnTitle = UIUtil.text("Title", warnBody, "", 15, C.Amber, F.Title, { LayoutOrder = 1 })
	local warnTag = UIUtil.text("Tag", warnBody, "", 11, C.Muted, F.Label, { LayoutOrder = 2 })
	local warnHint = UIUtil.text("Hint", warnBody, "", 13, C.Text, F.Body, { LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true })
	local warnCount = UIUtil.create("TextLabel", { Name = "Countdown", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = C.Charcoal, Text = "5", TextSize = 20, Font = F.Mono, TextColor3 = C.Amber }, warn)
	UIUtil.corner(warnCount, 20)
	local warnCountStroke = UIUtil.stroke(warnCount, C.Amber, 2)

	-- Combination strip
	local combo, comboStroke = UIUtil.surface("CombinationStrip", alerts, { Size = UDim2.fromOffset(440, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Visible = false })
	comboStroke.Color = C.Violet
	comboStroke.Thickness = 2
	UIUtil.pad(combo, 8, 12)
	UIUtil.list(combo, Enum.FillDirection.Vertical, 2)
	local comboTitle = UIUtil.text("Title", combo, "", 14, C.VioletText, F.Title, { LayoutOrder = 1 })
	local comboHint = UIUtil.text("Hint", combo, "", 13, C.Text, F.Body, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true })
	local comboSerial = 0

	-- Toast (short, low priority)
	local toast, _ = UIUtil.surface("Toast", alerts, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 5, Visible = false })
	UIUtil.corner(toast, 12)
	UIUtil.pad(toast, 4, 12)
	local toastText = UIUtil.text("Text", toast, "", 12, C.Text, F.Label)
	local toastSerial = 0
	local function showToast(text: string, color: Color3?)
		toastText.Text = text
		toastText.TextColor3 = color or C.Text
		toast.Visible = true
		toastSerial += 1
		local serial = toastSerial
		task.delay(TOAST_SECONDS, function()
			if serial == toastSerial then
				toast.Visible = false
			end
		end)
	end

	---------------------------------------------------------------------------------------------
	-- Top right: patch chips, shield chip, details button
	local topRight = UIUtil.create("Frame", {
		Name = "TopRight",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, root)
	UIUtil.list(topRight, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
	local chipRow = UIUtil.create("Frame", { Name = "PatchChips", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 }, topRight)
	UIUtil.list(chipRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
	local detailsButton = UIUtil.create("TextButton", {
		Name = "DetailsButton",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = C.Navy,
		BackgroundTransparency = UITheme.SurfaceTransparency,
		Text = "≡",
		TextSize = 22,
		Font = F.Title,
		TextColor3 = C.Cyan,
		AutoButtonColor = true,
	}, topRight) :: TextButton
	UIUtil.corner(detailsButton, 6)
	UIUtil.stroke(detailsButton, C.Steel, 1, 0.2)

	local chips: { [string]: { Frame: Frame, Fill: Frame, Glyph: TextLabel, Code: TextLabel, Stroke: UIStroke } } = {}
	local function chip(key: string): { Frame: Frame, Fill: Frame, Glyph: TextLabel, Code: TextLabel, Stroke: UIStroke }
		local existing = chips[key]
		if existing then
			return existing
		end
		local frame, stroke = UIUtil.surface("Chip_" .. key, chipRow, { Size = UDim2.fromOffset(44, 44) })
		local glyph = UIUtil.text("Glyph", frame, "", 18, C.Text, F.Title, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center })
		local code = UIUtil.text("Code", frame, "", 11, C.Muted, F.Label, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 12), TextXAlignment = Enum.TextXAlignment.Center })
		local track, fill = UIUtil.bar("Time", frame, 3, C.Text)
		track.AnchorPoint = Vector2.new(0.5, 1)
		track.Position = UDim2.new(0.5, 0, 1, -4)
		track.Size = UDim2.new(1, -10, 0, 3)
		local entry = { Frame = frame, Fill = fill, Glyph = glyph, Code = code, Stroke = stroke }
		chips[key] = entry
		return entry
	end

	---------------------------------------------------------------------------------------------
	-- Details panel (on demand)
	local details, _ = UIUtil.surface("Details", root, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 58),
		Size = UDim2.fromOffset(300, 200),
		Visible = false,
		BackgroundTransparency = 0.08,
	})
	UIUtil.pad(details, 10, 12)
	-- Content scrolls when the free area is shorter than the content (nothing is clipped away).
	local dScroll = UIUtil.create("ScrollingFrame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Steel,
		VerticalScrollBarInset = Enum.ScrollBarInset.Always,
	}, details)
	local dList = UIUtil.list(dScroll, Enum.FillDirection.Vertical, 8)
	UIUtil.text("Header", dScroll, "SIMULATION DETAILS", 12, C.Cyan, F.Label, { LayoutOrder = 1 })
	local dPersonal = UIUtil.text("Personal", dScroll, "", 14, C.Text, F.Title, { LayoutOrder = 2 })
	local dStabHead = UIUtil.text("StabilizersHeader", dScroll, "STABILIZERS", 11, C.Muted, F.Label, { LayoutOrder = 3 })
	local dStab = UIUtil.create("Frame", { Name = "Stabilizers", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4 }, dScroll)
	UIUtil.list(dStab, Enum.FillDirection.Vertical, 6)
	local dPatchHead = UIUtil.text("PatchesHeader", dScroll, "ACTIVE PATCHES", 11, C.Muted, F.Label, { LayoutOrder = 5 })
	local dPatches = UIUtil.text("Patches", dScroll, "", 12, C.Text, F.Body, { LayoutOrder = 6, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true })
	local reducedButton = UIUtil.create("TextButton", {
		Name = "ReducedEffects",
		LayoutOrder = 7,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = C.Charcoal,
		Text = "",
		TextSize = 12,
		Font = F.Label,
		TextColor3 = C.Text,
	}, dScroll) :: TextButton
	UIUtil.corner(reducedButton, 6)
	UIUtil.stroke(reducedButton, C.Steel, 1)
	UIUtil.text("Close", dScroll, "Close: ≡ / G", 11, C.Muted, F.Body, { LayoutOrder = 8 })
	local stabRows: { [string]: { Label: TextLabel, Fill: Frame } } = {}
	local function stabRow(id: string, order: number)
		local existing = stabRows[id]
		if existing then
			return existing
		end
		local row = UIUtil.create("Frame", { Name = "Row_" .. id, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = order }, dStab)
		local label = UIUtil.text("Label", row, "", 12, C.Text, F.Label, { Position = UDim2.fromOffset(0, 0) })
		local track, fill = UIUtil.bar("Bar", row, 5, C.Green)
		track.Position = UDim2.new(0, 0, 1, -6)
		local entry = { Label = label, Fill = fill }
		stabRows[id] = entry
		return entry
	end

	local detailsOpen = false
	local function renderReduced()
		reducedButton.Text = if UITheme.reducedEffects() then "REDUCED EFFECTS: ON" else "REDUCED EFFECTS: OFF"
		reducedButton.TextColor3 = if UITheme.reducedEffects() then C.Green else C.Muted
	end
	renderReduced()
	reducedButton.Activated:Connect(function()
		UITheme.setReducedEffects(not UITheme.reducedEffects())
		renderReduced()
	end)
	local placeDetails: () -> () = function() end
	local function setDetails(open: boolean)
		detailsOpen = open
		details.Visible = open
		if open then
			placeDetails()
		end
		detailsButton.TextColor3 = if open then C.Text else C.Cyan
		detailsButton.BackgroundColor3 = if open then C.Surface2 else C.Navy
	end
	detailsButton.Activated:Connect(function()
		setDetails(not detailsOpen)
	end)
	ContextActionService:BindAction(DETAILS_ACTION, function(_, inputState: Enum.UserInputState, input: InputObject)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if input.KeyCode == Enum.KeyCode.DPadDown and GuiService.SelectedObject ~= nil then
			return Enum.ContextActionResult.Pass -- gamepad is navigating a GUI (e.g. the Architect panel)
		end
		setDetails(not detailsOpen)
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.G, Enum.KeyCode.DPadDown)

	---------------------------------------------------------------------------------------------
	-- Results card (RESULTS / RESET only)
	local results, resultsStroke = UIUtil.surface("Results", root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		BackgroundTransparency = 0.06,
	})
	resultsStroke.Thickness = 2
	UIUtil.pad(results, 16, 20)
	UIUtil.list(results, Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center)
	local rHeader = UIUtil.text("Header", results, "", 26, C.Green, F.Display, { LayoutOrder = 1 })
	local rReason = UIUtil.text("Reason", results, "", 13, C.Muted, F.Body, { LayoutOrder = 2 })
	local rYou = UIUtil.surface("You", results, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, BackgroundColor3 = C.Charcoal })
	UIUtil.pad(rYou, 10, 12)
	UIUtil.list(rYou, Enum.FillDirection.Vertical, 4)
	local rYouTitle = UIUtil.text("Title", rYou, "", 18, C.Text, F.Title, { LayoutOrder = 1 })
	local rYouStats = UIUtil.text("Stats", rYou, "", 13, C.Muted, F.Body, { LayoutOrder = 2 })
	local rYouRewards = UIUtil.text("Rewards", rYou, "", 13, C.Cyan, F.Label, { LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true })
	local rTable = UIUtil.text("Table", results, "", 13, C.Text, F.Mono, { LayoutOrder = 4, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true })
	local rMeta = UIUtil.text("Meta", results, "", 12, C.Muted, F.Body, { LayoutOrder = 5 })

	---------------------------------------------------------------------------------------------
	-- Responsive layout
	local layout = UITheme.layout(root.AbsoluteSize)
	local function applyLayout()
		local size = root.AbsoluteSize
		if size.X <= 0 then
			return
		end
		layout = UITheme.layout(size)
		local touch = layout.Mode == "touch"
		local warnWidth = math.min(if touch then 360 else 440, size.X - 140)
		warn.Size = UDim2.fromOffset(warnWidth, 0)
		combo.Size = UDim2.fromOffset(warnWidth, 0)
		stab.Size = UDim2.fromOffset(if touch then 160 else 220, 14)
		timerLabel.TextSize = if touch then 15 else 18
		phaseLabel.TextSize = if touch then 11 else 13
		warnTitle.TextSize = if touch then 13 else 15
		warnHint.TextSize = if touch then 12 else 13
		detailsButton.Size = UDim2.fromOffset(if touch then 44 else 40, if touch then 44 else 40)
		results.Size = UDim2.fromOffset(math.min(560, size.X - 32), 0)
		results.Position = UDim2.fromScale(0.5, if layout.Portrait then 0.45 else 0.52)
		-- Portrait fallback: patch chips go below the pill so the top row does not crowd.
		if layout.Portrait then
			topRight.AnchorPoint = Vector2.new(0.5, 0)
			topRight.Position = UDim2.new(0.5, 0, 0, 82)
		else
			topRight.AnchorPoint = Vector2.new(1, 0)
			topRight.Position = UDim2.new(1, -10, 0, 6)
		end
		-- Alerts placement (see the header comment)
		if touch and not layout.Portrait then
			local zones = UITheme.nativeTouchZones(size)
			local w = math.floor(math.min(360, zones.Move.Max.X - 18))
			warn.Size = UDim2.fromOffset(w, 0)
			combo.Size = UDim2.fromOffset(w, 0)
			alerts.Parent = root
			alerts.AnchorPoint = Vector2.new(0, 0)
			alerts.Position = UDim2.fromOffset(10, 6)
			alertsList.HorizontalAlignment = Enum.HorizontalAlignment.Left
		elseif touch then
			alerts.Parent = root
			alerts.AnchorPoint = Vector2.new(0.5, 0)
			alerts.Position = UDim2.new(0.5, 0, 0, 82 + 44 + 6)
			alertsList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		else
			alerts.Parent = top
			alerts.AnchorPoint = Vector2.new(0, 0)
			alerts.Position = UDim2.new()
			alertsList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		end
	end

	-- Publishes the HUD's top row (on portrait also the alerts under it) for touch panel layout.
	local function publishTop()
		if root.AbsoluteSize.X <= 0 then
			return
		end
		local r1 = UITheme.rectOf(top, root)
		local r2 = UITheme.rectOf(topRight, root)
		local maxY = math.max(r1.Max.Y, r2.Max.Y)
		if layout.Mode == "touch" and layout.Portrait and (warn.Visible or combo.Visible or toast.Visible) then
			maxY = math.max(maxY, UITheme.rectOf(alerts, root).Max.Y)
		end
		UITheme.setReserved("hudTop", Rect.new(math.min(r1.Min.X, r2.Min.X), 0, math.max(r1.Max.X, r2.Max.X), maxY))
	end

	-- Details placement: the largest free rectangle; height capped, the content scrolls.
	placeDetails = function()
		local size = root.AbsoluteSize
		if size.X <= 0 then
			return
		end
		local x1, y1, x2, y2
		if layout.Mode == "touch" then
			local zones = UITheme.nativeTouchZones(size)
			local controls = UITheme.touchControlsRect(size)
			local hud = UITheme.reserved("hudTop")
			y1 = (if hud then hud.Max.Y else 54) + 8
			x1 = zones.Move.Max.X + 8
			-- Option A: above the touch controls. Option B: left of them, full height.
			local aW, aH = size.X - 10 - x1, controls.Min.Y - 8 - y1
			local bW, bH = controls.Min.X - 8 - x1, size.Y - 8 - y1
			if bW >= 240 and bW * bH >= aW * aH then
				x2, y2 = controls.Min.X - 8, size.Y - 8
			else
				x2, y2 = size.X - 10, controls.Min.Y - 8
			end
		else
			x1, y1, x2, y2 = 10, 54, size.X - 10, size.Y - 12
		end
		-- Never under an open Architect tray: below it or left of it, whichever leaves more room.
		local arch = UITheme.reserved("architect")
		if arch and arch.Max.X > x1 and arch.Min.X < x2 and arch.Max.Y > y1 and arch.Min.Y < y2 then
			local below = (x2 - x1) * (y2 - (arch.Max.Y + 8))
			local left = ((arch.Min.X - 8) - x1) * (y2 - y1)
			if below >= left then
				y1 = arch.Max.Y + 8
			else
				x2 = arch.Min.X - 8
			end
		end
		local w = math.max(math.min(if layout.Mode == "desktop" then 300 else 270, x2 - x1), 0)
		local h = math.max(math.min(dList.AbsoluteContentSize.Y + 20, y2 - y1), 0)
		details.AnchorPoint = Vector2.new(1, 0)
		details.Position = UDim2.fromOffset(x2, y1)
		details.Size = UDim2.fromOffset(w, h)
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
	applyLayout()

	---------------------------------------------------------------------------------------------
	-- Rendering
	local lastObjectiveState: { [string]: string } = {}
	local lastMatch: any = nil

	local function refresh()
		local snap = MatchStateClient.Get()
		local state = tostring(snap.State or S.Lobby)
		local t = workspace:GetServerTimeNow()
		local inMatch = state == S.Active or state == S.FinalPhase
		local touch = layout.Mode == "touch"

		-- Phase pill
		local endsAt = snap.StateEndsAt
		local remaining = if typeof(endsAt) == "number" and endsAt > 0 then endsAt - t else nil
		phaseLabel.Text = PHASE_TEXT[state] or state
		timerLabel.Text = if remaining then UIUtil.formatTime(remaining) else "--:--"
		local final = state == S.FinalPhase
		phaseLabel.TextColor3 = if final then C.Coral elseif inMatch then C.Cyan else C.Muted
		pillStroke.Color = if final then C.Coral else C.Steel
		pillStroke.Thickness = if final then 2 else 1
		local role = tostring(player:GetAttribute(Config.PlayerAttributes.Role) or Roles.Lobby)
		if state == S.Lobby or state == S.Countdown then
			local waiting = 0
			for _, other in Players:GetPlayers() do
				if other:GetAttribute(Config.PlayerAttributes.Role) == Roles.Lobby then
					waiting += 1
				end
			end
			subLabel.Text = `{waiting}/{tostring(snap.MinPlayers or "?")} ready`
		elseif role == Roles.Spectator then
			subLabel.Text = "SPECTATING · next match"
		else
			subLabel.Text = ""
		end
		subLabel.Visible = subLabel.Text ~= ""
		divider.Visible = true

		-- Stability
		local stability = snap.Stability
		if inMatch and typeof(stability) == "number" then
			local max = if typeof(snap.StabilityMax) == "number" and snap.StabilityMax > 0 then snap.StabilityMax else 100
			local target = Config.Stability.SuccessTarget
			local low = stability < target
			stab.Visible = true
			stabFill.Size = UDim2.new(math.clamp(stability / max, 0, 1), 0, 1, 0)
			stabFill.BackgroundColor3 = if low then C.Amber else C.Cyan
			stabTick.Position = UDim2.new(math.clamp(target / max, 0, 1), 0, 0.5, 0)
			stabValue.Text = tostring(stability) .. (if low then "!" else "")
			stabValue.TextColor3 = if low then C.Amber else C.Cyan
		else
			stab.Visible = false
		end

		-- Patch chips + warning strip
		local seen: { [string]: boolean } = {}
		local soonest: any = nil
		local detailLines = {}
		if typeof(snap.Patches) == "table" then
			for i, patch in snap.Patches do
				if typeof(patch) == "table" and typeof(patch.PatchId) == "string" then
					local def = PatchCatalog.Get(patch.PatchId)
					local cat = UITheme.category(def and def.Category)
					local key = tostring(patch.RuntimeId or patch.PatchId)
					seen[key] = true
					local entry = chip(key)
					entry.Frame.LayoutOrder = i
					entry.Glyph.Text = UITheme.PatchIcon[patch.PatchId] or "•"
					entry.Code.Text = UITheme.PatchCode[patch.PatchId] or string.sub(patch.PatchId, 1, 2)
					local name = if def then string.upper(def.DisplayName) else patch.PatchId
					if patch.State == "WARNING" and typeof(patch.WarningEndsAt) == "number" then
						entry.Glyph.TextColor3 = C.Amber
						entry.Stroke.Color = C.Amber
						entry.Stroke.Thickness = 2
						entry.Fill.BackgroundColor3 = C.Amber
						local total = if def and def.WarningSeconds then def.WarningSeconds else 4.5
						entry.Fill.Size = UDim2.new(math.clamp((patch.WarningEndsAt - t) / math.max(total, 0.1), 0, 1), 0, 1, 0)
						if soonest == nil or patch.WarningEndsAt < soonest.WarningEndsAt then
							soonest = patch
						end
						table.insert(detailLines, `{name} — incoming {UIUtil.formatTime(patch.WarningEndsAt - t)}`)
					elseif typeof(patch.ExpiresAt) == "number" then
						entry.Glyph.TextColor3 = cat.Text
						entry.Stroke.Color = cat.Color
						entry.Stroke.Thickness = 1
						entry.Fill.BackgroundColor3 = cat.Color
						local total = if def and def.DurationSeconds then def.DurationSeconds else 35
						entry.Fill.Size = UDim2.new(math.clamp((patch.ExpiresAt - t) / math.max(total, 0.1), 0, 1), 0, 1, 0)
						table.insert(detailLines, `{name} — {UIUtil.formatTime(patch.ExpiresAt - t)} · {if def then def.Effect else ""}`)
					end
				end
			end
		end
		if typeof(snap.Interactions) == "table" then
			for i, combination in snap.Interactions do
				if typeof(combination) == "table" and typeof(combination.Id) == "string" then
					local key = "combo:" .. combination.Id
					seen[key] = true
					local entry = chip(key)
					entry.Frame.LayoutOrder = 10 + i
					entry.Glyph.Text = "★"
					entry.Glyph.TextColor3 = C.VioletText
					entry.Code.Text = "COMBO"
					entry.Stroke.Color = C.Violet
					entry.Stroke.Thickness = 2
					entry.Fill.BackgroundColor3 = C.Violet
					entry.Fill.Size = UDim2.new(1, 0, 1, 0)
					table.insert(detailLines, `COMBINATION: {string.upper(tostring(combination.DisplayName or combination.Id))}`)
				end
			end
		end
		-- Personal shield (SUPPLY_DROP; server-set expiry)
		local shieldUntil = player:GetAttribute(Config.PlayerAttributes.Shield)
		if typeof(shieldUntil) == "number" and shieldUntil > t then
			seen["shield"] = true
			local entry = chip("shield")
			entry.Frame.LayoutOrder = 30
			entry.Glyph.Text = "⊕"
			entry.Glyph.TextColor3 = C.Green
			entry.Code.Text = UIUtil.formatTime(shieldUntil - t)
			entry.Stroke.Color = C.Green
			entry.Fill.BackgroundColor3 = C.Green
			entry.Fill.Size = UDim2.new(1, 0, 1, 0)
		end
		for key, entry in chips do
			if not seen[key] then
				entry.Frame:Destroy()
				chips[key] = nil
			end
		end

		if soonest and inMatch then
			local def = PatchCatalog.Get(soonest.PatchId)
			local cat = UITheme.category(def and def.Category)
			local headline, hint = UITheme.splitWarning(if def then def.Warning else soonest.PatchId)
			local severe = def ~= nil and def.Severity == "severe"
			local edge = if severe then C.Coral else C.Amber
			warn.Visible = true
			warnAccent.BackgroundColor3 = edge
			warnStroke.Color = edge
			warnIcon.Text = UITheme.PatchIcon[soonest.PatchId] or "!"
			warnIcon.TextColor3 = edge
			warnTitle.Text = headline
			warnTitle.TextColor3 = edge
			warnTag.Text = `{if severe then "▲ SEVERE · " else ""}{cat.Glyph} {cat.Code} · {if def then string.upper(def.DisplayName) else ""}`
			warnHint.Text = hint
			warnCount.Text = tostring(math.max(0, math.ceil(soonest.WarningEndsAt - t)))
			warnCount.TextColor3 = edge
			warnCountStroke.Color = edge
		else
			warn.Visible = false
		end

		-- Details content
		local myScore = player:GetAttribute(Config.PlayerAttributes.Score)
		local myFragments = player:GetAttribute(Config.PlayerAttributes.Fragments)
		dPersonal.Text = string.format("SCORE %s   ·   FRAGMENTS %s", if typeof(myScore) == "number" then tostring(myScore) else "-", if typeof(myFragments) == "number" then tostring(myFragments) else "0")
		local objectives = if typeof(snap.Objectives) == "table" then snap.Objectives else {}
		local stabSeen: { [string]: boolean } = {}
		for i, o in objectives do
			if typeof(o) == "table" then
				local id = tostring(o.Id)
				stabSeen[id] = true
				local row = stabRow(id, i)
				local zone = ZONE_SHORT[tostring(o.Zone)] or id
				local progress = if typeof(o.Progress) == "number" then o.Progress else 0
				local status = if o.State == "REPAIRING" then `REPAIRING {progress}%`
					elseif o.State == "PAUSED" then `PAUSED {progress}%`
					elseif o.State == "COOLDOWN" then "✓ REPAIRED"
					else "NEEDS REPAIR"
				row.Label.Text = `{zone}  ·  {status}`
				row.Label.TextColor3 = if o.State == "COOLDOWN" then C.Green elseif o.State == "REPAIRING" or o.State == "PAUSED" then C.Text else C.Amber
				row.Fill.Size = UDim2.new(if o.State == "COOLDOWN" then 1 else math.clamp(progress / 100, 0, 1), 0, 1, 0)
				-- Contextual toast when a stabilizer is repaired (state change only)
				if inMatch and o.State == "COOLDOWN" and lastObjectiveState[id] ~= nil and lastObjectiveState[id] ~= "COOLDOWN" then
					showToast(`✓ {zone} STABILIZER REPAIRED`, C.Green)
				end
				lastObjectiveState[id] = tostring(o.State)
			end
		end
		for id, row in stabRows do
			if not stabSeen[id] then
				(row.Label.Parent :: Instance):Destroy()
				stabRows[id] = nil
			end
		end
		dStabHead.Visible = next(stabRows) ~= nil
		dPatches.Text = if #detailLines > 0 then table.concat(detailLines, "\n") else "None running."
		dPatchHead.Visible = true

		-- Results
		if state == S.Results or state == S.Reset then
			local data = snap.LastResult
			if typeof(data) == "table" then
				results.Visible = true
				if detailsOpen then
					setDetails(false) -- the results card replaces the Details panel
				end
				local team = if typeof(data.Team) == "table" then data.Team else {}
				local header, color
				if team.Aborted then
					header, color = "MATCH ABORTED", C.Muted
				elseif team.Success then
					header, color = "SIMULATION STABILIZED", C.Green
				else
					header, color = "SIMULATION COLLAPSED", C.Coral
				end
				rHeader.Text = header
				rHeader.TextColor3 = color
				resultsStroke.Color = color
				rReason.Text = `TEAM {if team.Success then "SUCCESS" elseif team.Aborted then "ABORTED" else "FAILED"} · {tostring(team.Reason or data.Reason or "")}`
				local rows = {}
				local mine: any = nil
				if typeof(data.Players) == "table" then
					for _, row in data.Players do
						if typeof(row) == "table" then
							if row.UserId == player.UserId then
								mine = row
							end
							if #rows < 6 then
								local place = if row.Left then "LEFT" elseif row.Placement == 0 then " -" else string.format("%2d", row.Placement)
								table.insert(rows, string.format("%s  %-16s %5s pts  %5s total", place, string.sub(tostring(row.Name), 1, 16), tostring(row.Score), tostring(row.Total or row.Score)))
							end
						end
					end
				end
				if mine then
					rYou.Visible = true
					rYouTitle.Text = if mine.Placement and mine.Placement > 0 then `#{mine.Placement}  ·  {tostring(mine.Score)} POINTS` else `{tostring(mine.Score)} POINTS`
					rYouStats.Text = `Fragments {tostring(mine.Fragments)}  ·  Repairs {tostring(mine.Repairs)}  ·  Assists {tostring(mine.Assists)}`
					local b = if typeof(mine.RewardBreakdown) == "table" then mine.RewardBreakdown else {}
					rYouRewards.Text = `MATCH REWARDS +{tostring(mine.Rewards)}  (participation {tostring(b.Participation)} · team {tostring(b.Team)} · placement {tostring(b.Placement)})  =  {tostring(mine.Total)}`
				else
					rYou.Visible = false
				end
				rTable.Text = table.concat(rows, "\n")
				local nextText = if state == S.Results and remaining then ` · Next: lobby in {UIUtil.formatTime(remaining)}` else ""
				rMeta.Text = `Match #{tostring(data.MatchId)} · {tostring(data.DurationSeconds)}s · patches {tostring(data.TurnsAccepted)} · skipped turns {tostring(data.TurnsSkipped)}{nextText}`
			else
				results.Visible = false
			end
		else
			results.Visible = false
		end

		-- Match change: clear transient state
		if snap.MatchId ~= lastMatch then
			lastMatch = snap.MatchId
			table.clear(lastObjectiveState)
			comboSerial += 1
			combo.Visible = false
		end
	end

	local announce = remotes:WaitForChild(Config.Remotes.PatchAnnouncement) :: RemoteEvent
	announce.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		if data.Outcome == "interaction" and typeof(data.DisplayName) == "string" then
			local def = if typeof(data.Id) == "string" then InteractionCatalog.Get(data.Id) else nil
			local _, hint = UITheme.splitWarning(tostring(data.Warning or (def and def.Warning) or ""))
			comboTitle.Text = `★ COMBINATION: {string.upper(data.DisplayName)}  +{tostring(data.DiscoveryPoints or 0)}`
			comboHint.Text = hint
			combo.Visible = true
			comboSerial += 1
			local serial = comboSerial
			task.delay(COMBO_SECONDS, function()
				if serial == comboSerial then
					combo.Visible = false
				end
			end)
		elseif data.Outcome == "accepted" and typeof(data.DisplayName) == "string" then
			showToast(`{tostring(data.ArchitectName)} uploaded {string.upper(data.DisplayName)}`, C.VioletText)
		else
			showToast(`Architect turn skipped ({tostring(data.Outcome)})`, C.Muted)
		end
	end)

	-- Studio-only layout preview: outline the preview frame and Roblox's native touch zones.
	if RunService:IsStudio() then
		local overlay = UIUtil.create("Frame", { Name = "PreviewOverlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Visible = false }, root)
		local function zone(name: string, color: Color3): Frame
			local f = UIUtil.create("Frame", { Name = name, BackgroundColor3 = color, BackgroundTransparency = 0.85, BorderSizePixel = 0, ZIndex = 50 }, overlay)
			UIUtil.stroke(f, color, 1)
			UIUtil.text("Label", f, name, 11, color, F.Label, { ZIndex = 51, Position = UDim2.fromOffset(4, 2) })
			return f
		end
		local jumpZone = zone("native jump", C.Coral)
		local moveZone = zone("native thumbstick", C.Coral)
		UIUtil.stroke(overlay, C.Cyan, 2)
		local function placeZones()
			local p = UITheme.previewSize()
			overlay.Visible = p ~= nil and UITheme.isTouchDevice()
			if p then
				local z = UITheme.nativeTouchZones(p)
				jumpZone.Position = UDim2.fromOffset(z.Jump.Min.X, z.Jump.Min.Y)
				jumpZone.Size = UDim2.fromOffset(z.Jump.Width, z.Jump.Height)
				moveZone.Position = UDim2.fromOffset(z.Move.Min.X, z.Move.Min.Y)
				moveZone.Size = UDim2.fromOffset(z.Move.Width, z.Move.Height)
			end
		end
		placeZones()
		UITheme.PreviewChanged:Connect(placeZones)
	end

	task.spawn(function()
		while gui.Parent do
			refresh()
			publishTop()
			if detailsOpen then
				placeDetails()
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return HUDController

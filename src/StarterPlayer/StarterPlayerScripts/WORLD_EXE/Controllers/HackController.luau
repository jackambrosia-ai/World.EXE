--!strict
-- HackController (wrist-hacking prototype, client). The player "wrist terminal": presentation and
-- intent only; the server (HackService) validates and decides everything.
--
-- Two ways to start a hack, ONE request shape ({ op = "begin", hackId, targetId?, source, ... }):
--   * Quick hack: cyber-chips (CyberChip, the Architect chip look). SELECT -> CONFIRM: click/tap a
--     chip, then EXECUTE (or activate the same chip / press its number again). Target-needing hacks
--     use the selected target (auto-picked nearest the camera centre; X / tap / gamepad to change).
--   * Typed hack: the command line ("fling self", "freeze dummy", "freeze boss", "shield", ...),
--     parsed by the shared HackCatalog.Parse; the server re-parses the same text.
-- Activation challenges are drawn here from server snapshots; presses are sent one at a time.
--
-- Controls (owner requirement: camera centre, movement, jump and dodge stay free):
--   Keyboard  H toggle terminal (G is the HUD details panel) · 1-4 chips (press twice = execute) · Enter execute · X next target
--             · T focus the command line · number keys 1-5 = challenge inputs (WASD + mouse stay free) ·
--             Backspace cancel challenge.
--   Gamepad   L1 toggle · GUI selection on chips/targets/EXECUTE (A) · D-pad = challenge directions ·
--             B cancel / close.
--   Touch     wrist button beside the controls; terminal and direction pad live in the free region
--             right of the thumbstick, above the jump/ability buttons (UITheme.touchPanelRegion).
-- Arbitration with the Architect UI: while the Architect tray is open (WORLD_EXE_Architect enabled)
-- the terminal is closed, any challenge is cancelled and the toggle does nothing. The Architect UI
-- is untouched and always wins.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local sharedRoot = ReplicatedStorage:WaitForChild("WORLD_EXE")
local HackCatalog = require(sharedRoot:WaitForChild("Shared"):WaitForChild("HackCatalog"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))
local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local MoveState = require(script.Parent:WaitForChild("MoveState"))
local CyberChip = require(script.Parent:WaitForChild("CyberChip"))
local HackVfx = require(script.Parent:WaitForChild("HackVfx"))
local ArrowGlyph = require(script.Parent:WaitForChild("ArrowGlyph"))
local HackFeel = require(script.Parent:WaitForChild("HackFeel"))

local C = UITheme.Color
local F = UITheme.Font
local A = HackCatalog.Attr
local T = HackCatalog.Tuning


-- Rev 15 (owner 2026-11-16): challenge input is the NUMBER ROW so the right hand stays on the mouse.
-- Keyboard 1-5 (and keypad 1-5). Gamepad (deliberate, documented): D-pad Left/Up/Right/Down = 1/2/3/4,
-- Y = 5. While a challenge is active this binding outranks the quick-chip number keys.
local KEY_DIR: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.One] = "1", [Enum.KeyCode.Two] = "2", [Enum.KeyCode.Three] = "3", [Enum.KeyCode.Four] = "4", [Enum.KeyCode.Five] = "5",
	[Enum.KeyCode.KeypadOne] = "1", [Enum.KeyCode.KeypadTwo] = "2", [Enum.KeyCode.KeypadThree] = "3", [Enum.KeyCode.KeypadFour] = "4", [Enum.KeyCode.KeypadFive] = "5",
	[Enum.KeyCode.DPadLeft] = "1", [Enum.KeyCode.DPadUp] = "2", [Enum.KeyCode.DPadRight] = "3", [Enum.KeyCode.DPadDown] = "4", [Enum.KeyCode.ButtonY] = "5",
}
local MAX_TARGETS = 4
local TOGGLE_ACTION = "WORLD_EXE_WristToggle"
local KEYS_ACTION = "WORLD_EXE_WristKeys"
local DIR_ACTION = "WORLD_EXE_WristDirections"

local REASON: { [string]: string } = {
	applied = "Executed.",
	rate_limited = "Too fast — wait a moment.",
	bad_payload = "Request rejected.",
	unknown_hack = "Unknown hack.",
	parse_mismatch = "Command did not match a hack.",
	busy = "Finish or cancel the current hack first.",
	not_alive = "You are down.",
	you_are_frozen = "You are frozen — wait it out.",
	you_are_ragdolled = "You are knocked down.",
	cooldown = "Recharging.",
	retry_wait = "Recalibrating — try again in a moment.",
	no_target = "No valid target.",
	cannot_target_self = "Pick another target.",
	out_of_range = "Target out of range.",
	no_line_of_sight = "No line of sight.",
	boss_offline = "The Conductor is offline.",
	target_immune = "Target is briefly immune.",
	already_frozen = "Already frozen.",
	already_ragdolled = "Target is already down.",
	target_busy = "Target is mid-effect.",
	target_frozen = "Target is frozen solid — it cannot be flung.",
	already_active = "Shield is already up.",
	timeout = "Hack timed out.",
	too_many_misses = "Too many wrong inputs.",
	resisted = "The Conductor resisted the hack.",
	overrun = "The Conductor outran you — queue overflow.",
	interrupted = "Hit by an attack — hack interrupted.",
	cancelled = "Hack cancelled.",
	died = "Hack lost (you went down).",
	respawned = "Hack lost (respawn).",
	boss_immune = "The Conductor is briefly immune.",
	no_character = "No character.",
}

type Candidate = { id: string, name: string, model: Model, root: BasePart, dist: number, score: number, boss: boolean }

local HackController = {}

function HackController.Start()
	UITheme.init()
	HackVfx.Start()
	local player = Players.LocalPlayer
	local remotes = sharedRoot:WaitForChild(HackCatalog.RemoteFolder, 30)
	if not remotes then
		warn("[HackPrototype] client: HackRemotes not found")
		return
	end
	local request = remotes:WaitForChild(HackCatalog.RequestRemote) :: RemoteEvent
	local event = remotes:WaitForChild(HackCatalog.EventRemote) :: RemoteEvent
	local playerGui = player:WaitForChild("PlayerGui")

	local gui, root = UIUtil.screen("WORLD_EXE_WristHack", 7)

	-----------------------------------------------------------------------------------------------
	-- Wrist pill (always visible): toggle + shield / frozen status
	local pill, pillStroke = UIUtil.surface("WristPill", root, { Size = UDim2.fromOffset(168, 34) })
	pillStroke.Color = C.Cyan
	local pillButton = UIUtil.create("TextButton", { Name = "Toggle", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", Selectable = false }, pill) :: TextButton
	local pillText = UIUtil.text("Text", pill, "◈ WRIST  [H]", 13, C.Cyan, F.Title, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0) })
	local status, _ = UIUtil.surface("Status", root, { Size = UDim2.fromOffset(168, 26), Visible = false })
	local statusText = UIUtil.text("Text", status, "", 12, C.Green, F.Mono, { Position = UDim2.fromOffset(8, 5) })
	local statusTrack, statusFill = UIUtil.bar("Bar", status, 3, C.Green)
	statusTrack.Position = UDim2.new(0, 0, 1, -3)

	-----------------------------------------------------------------------------------------------
	-- Terminal panel
	local panel, panelStroke = UIUtil.surface("Terminal", root, { BackgroundTransparency = 0.08, Size = UDim2.fromOffset(340, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false })
	panelStroke.Color = C.Cyan
	panelStroke.Thickness = 2
	UIUtil.pad(panel, 10, 10)
	local panelList = UIUtil.list(panel, Enum.FillDirection.Vertical, 6)

	local header = UIUtil.create("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1 }, panel)
	UIUtil.text("Title", header, "WRIST // HACK", 14, C.Cyan, F.Display)
	local modeText = UIUtil.text("Mode", header, "", 10, C.Muted, F.Label, { Position = UDim2.fromOffset(0, 17) })
	local close = UIUtil.create("TextButton", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(28, 24), BackgroundColor3 = C.Charcoal, Text = "×", TextSize = 16, Font = F.Title, TextColor3 = C.Muted, Selectable = true }, header) :: TextButton
	UIUtil.corner(close, 5)

	-- Chips
	local grid = UIUtil.create("Frame", { Name = "Chips", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, panel)
	local gridLayout = UIUtil.create("UIGridLayout", { CellSize = UDim2.fromOffset(156, 82), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, FillDirectionMaxCells = 2 }, grid) :: UIGridLayout

	-- Targets
	local targetRow = UIUtil.create("Frame", { Name = "Targets", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 3 }, panel)
	UIUtil.list(targetRow, Enum.FillDirection.Horizontal, 4)

	-- Command line
	local command = UIUtil.create("TextBox", {
		Name = "Command",
		LayoutOrder = 4,
		PlaceholderText = "> type a hack: fling self · freeze · shield  [T]",
		Text = "",
		ClearTextOnFocus = false,
		TextSize = 13,
		Font = F.Mono,
		TextColor3 = C.Green,
		PlaceholderColor3 = C.Muted,
		BackgroundColor3 = C.Charcoal,
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Selectable = true,
	}, panel) :: TextBox
	UIUtil.corner(command, 5)
	UIUtil.pad(command, 0, 8)

	-- Footer: EXECUTE
	local footer = UIUtil.create("Frame", { Name = "Footer", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 5 }, panel)
	local execute = UIUtil.create("TextButton", { Name = "Execute", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Surface2, Text = "SELECT A CHIP", TextSize = 14, Font = F.Title, TextColor3 = C.Muted, AutoButtonColor = false, Selectable = true }, footer) :: TextButton
	UIUtil.corner(execute, 6)
	local executeStroke = UIUtil.stroke(execute, C.Steel, 1)

	-- Challenge view (replaces chips/targets/command while a hack challenge runs)
	local chal = UIUtil.create("Frame", { Name = "Challenge", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Visible = false }, panel)
	UIUtil.list(chal, Enum.FillDirection.Vertical, 6)
	local chalTitle = UIUtil.text("Title", chal, "", 12, C.Amber, F.Label, { LayoutOrder = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true })
	local arrowRow = UIUtil.create("Frame", { Name = "Arrows", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 2 }, chal) -- tall enough for the current arrow's direction word
	UIUtil.list(arrowRow, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center)
	local arrowRowList = arrowRow:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	arrowRowList.VerticalAlignment = Enum.VerticalAlignment.Top
	local track = UIUtil.create("Frame", { Name = "SignalTrack", BackgroundColor3 = C.Charcoal, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 3, Visible = false, ClipsDescendants = true }, chal)
	UIUtil.corner(track, 4)
	local zone = UIUtil.create("Frame", { Name = "LockZone", BackgroundColor3 = C.Cyan, BackgroundTransparency = 0.7, BorderSizePixel = 0, Size = UDim2.new(0, 20, 1, 0), Position = UDim2.fromScale(0.15, 0), AnchorPoint = Vector2.new(0.5, 0) }, track)
	UIUtil.stroke(zone, C.Cyan, 1)
	local barLabel = UIUtil.text("BarLabel", chal, "", 11, C.Muted, F.Label, { LayoutOrder = 4 })
	local progTrack, progFill = UIUtil.bar("Progress", chal, 10, C.Cyan)
	progTrack.LayoutOrder = 5
	local thresholdMark = UIUtil.create("Frame", { Name = "Threshold", BackgroundColor3 = C.Text, BorderSizePixel = 0, Size = UDim2.new(0, 2, 1, 4), Position = UDim2.new(1, -2, 0, -2) }, progTrack)
	local timeTrack, timeFill = UIUtil.bar("Time", chal, 4, C.Amber)
	timeTrack.LayoutOrder = 6
	local chalInfo = UIUtil.text("Info", chal, "", 11, C.Muted, F.Body, { LayoutOrder = 7 })
	local pad = UIUtil.create("Frame", { Name = "DirPad", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 8, Visible = false }, chal)
	UIUtil.list(pad, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	local cancelBtn = UIUtil.create("TextButton", { Name = "Cancel", LayoutOrder = 9, Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.Charcoal, Text = "CANCEL  [Backspace / B]", TextSize = 12, Font = F.Label, TextColor3 = C.Muted, Selectable = true }, chal) :: TextButton
	UIUtil.corner(cancelBtn, 5)

	local info = UIUtil.text("Info", panel, "", 12, C.Text, F.Body, { LayoutOrder = 7, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true })

	-- Frozen banner (top centre, small: the camera centre stays clear)
	local frozenBanner, _ = UIUtil.surface("Frozen", root, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(200, 30), Visible = false })
	local frozenText = UIUtil.text("Text", frozenBanner, "", 14, C.Ice, F.Title, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })

	-----------------------------------------------------------------------------------------------
	-- State
	local open = false
	local compact = false
	local touch = false
	local selected: string? = nil
	local pending: string? = nil
	local lastResult: { [string]: string } = {}
	local focus: { [string]: boolean } = {}
	local chips: { [string]: CyberChip.Chip } = {}
	local candidates: { Candidate } = {}
	local pickedTarget: string? = nil -- user's explicit pick (sticky while valid)
	local currentTarget: Candidate? = nil
	local challenge: { token: number, hackId: string, snap: { [string]: any }, recv: number, n: number, targetId: string? }? = nil
	local currentAim: Vector3? = nil -- FLING flick aim after casting (horizontal unit), nil until flicked
	local frozenUntil = 0
	local architectOpen = false
	local targetMarker: Highlight? = nil
	local targetPills: { TextButton } = {}

	local function setInfo(text: string, color: Color3?)
		info.Text = text
		info.TextColor3 = color or C.Text
	end

	local function nowT(): number
		return workspace:GetServerTimeNow()
	end

	-----------------------------------------------------------------------------------------------
	-- Targets
	local function addCandidate(list: { Candidate }, id: string, name: string, model: Model, boss: boolean, myPos: Vector3, cam: Camera)
		local r = model:FindFirstChild("HumanoidRootPart")
		local h = model:FindFirstChildOfClass("Humanoid")
		if not r or not r:IsA("BasePart") or not h or h.Health <= 0 then
			return
		end
		local d = (r.Position - myPos).Magnitude
		if d > math.max(HackCatalog.Tune("Freeze", "Range"), HackCatalog.Tune("FlingTarget", "Range")) then
			return
		end
		local dirTo = (r.Position - cam.CFrame.Position)
		local angle = math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(dirTo.Unit), -1, 1)))
		table.insert(list, { id = id, name = name, model = model, root = r, dist = d, score = angle + d * 0.3, boss = boss })
	end

	local function refreshCandidates()
		local list: { Candidate } = {}
		local c = player.Character
		local myRoot = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local cam = workspace.CurrentCamera
		if myRoot and cam then
			for _, m in CollectionService:GetTagged(HackCatalog.TargetTag) do
				if m:IsA("Model") then
					local id = m:GetAttribute(A.TargetId)
					if typeof(id) == "string" then
						addCandidate(list, id, if CollectionService:HasTag(m, HackCatalog.BossTag) then "CONDUCTOR" else string.upper(m.Name), m, CollectionService:HasTag(m, HackCatalog.BossTag), myRoot.Position, cam)
					end
				end
			end
			for _, other in Players:GetPlayers() do
				if other ~= player and other.Character then
					addCandidate(list, "player:" .. other.UserId, string.upper(other.DisplayName), other.Character, false, myRoot.Position, cam)
				end
			end
		end
		table.sort(list, function(a, b)
			return a.score < b.score
		end)
		candidates = list
		currentTarget = nil
		if pickedTarget then
			for _, cand in list do
				if cand.id == pickedTarget then
					currentTarget = cand
				end
			end
			if not currentTarget then
				pickedTarget = nil
			end
		end
		if not currentTarget then
			currentTarget = list[1]
		end
	end

	local function renderTargets()
		for _, b in targetPills do
			b:Destroy()
		end
		table.clear(targetPills)
		for i = 1, math.min(MAX_TARGETS, #candidates) do
			local cand = candidates[i]
			local isSel = currentTarget ~= nil and currentTarget.id == cand.id
			local b = UIUtil.create("TextButton", {
				Name = "Target" .. i,
				LayoutOrder = i,
				Size = UDim2.fromOffset(if compact then 70 else 76, 28),
				BackgroundColor3 = if isSel then C.Surface2 else C.Charcoal,
				Text = string.format("%s%s\n%dm", if cand.boss then "☠ " else "◎ ", string.sub(cand.name, 1, 9), math.floor(cand.dist)),
				TextSize = 10,
				Font = F.Label,
				TextColor3 = if isSel then C.Cyan else C.Muted,
				AutoButtonColor = false,
				Selectable = true,
			}, targetRow) :: TextButton
			UIUtil.corner(b, 4)
			UIUtil.stroke(b, if isSel then C.Cyan else C.Steel, if isSel then 2 else 1)
			b.Activated:Connect(function()
				pickedTarget = cand.id
				refreshCandidates()
				renderTargets()
			end)
			table.insert(targetPills, b)
		end
		if #candidates == 0 then
			local b = UIUtil.create("TextButton", { Name = "NoTarget", Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = string.format("no target in range (%d studs)", math.max(HackCatalog.Tune("Freeze", "Range"), HackCatalog.Tune("FlingTarget", "Range"))), TextSize = 11, Font = F.Body, TextColor3 = C.Muted, Selectable = false }, targetRow) :: TextButton
			table.insert(targetPills, b)
		end
		-- World marker on the selected target (client-only)
		if currentTarget and open then
			if not targetMarker then
				local hl = Instance.new("Highlight")
				hl.Name = "WristTargetMarker"
				hl.FillTransparency = 1
				hl.OutlineColor = C.Cyan
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				targetMarker = hl
			end
			(targetMarker :: Highlight).Adornee = currentTarget.model;
			(targetMarker :: Highlight).Parent = gui
		elseif targetMarker then
			targetMarker.Parent = nil
		end
	end

	local function cycleTarget()
		if #candidates == 0 then
			return
		end
		local idx = 0
		for i, cand in candidates do
			if currentTarget and cand.id == currentTarget.id then
				idx = i
			end
		end
		pickedTarget = candidates[(idx % math.min(MAX_TARGETS, #candidates)) + 1].id
		refreshCandidates()
		renderTargets()
	end

	-----------------------------------------------------------------------------------------------
	-- Chips
	local function readyAt(id: string): number
		local v = player:GetAttribute(A.ReadyPrefix .. id)
		return if typeof(v) == "number" then v else 0
	end

	local function cooldownOf(id: string): number
		if id == "FLING_SELF" then
			return T.FlingSelf.Cooldown
		elseif id == "FLING_TARGET" then
			return T.FlingTarget.Cooldown
		elseif id == "FREEZE" then
			return T.Freeze.Cooldown
		end
		return T.Shield.Cooldown
	end

	local function renderChips()
		local t = nowT()
		for id, chip in chips do
			local left = readyAt(id) - t
			if pending == id then
				chip.SetState("pending")
			elseif left > 0 then
				chip.SetState("cooldown")
			elseif lastResult[id] == "rejected" then
				chip.SetState("rejected")
			elseif lastResult[id] == "accepted" then
				chip.SetState("accepted")
			elseif selected == id then
				chip.SetState("selected")
			elseif pending then
				chip.SetState("disabled")
			elseif focus[id] then
				chip.SetState("focus")
			else
				chip.SetState("default")
			end
			chip.SetCooldown(if left > 0 then left / cooldownOf(id) else 0, if left > 0 then string.format("%.1f", left) else nil)
		end
		local def = selected and HackCatalog.Get(selected)
		if pending then
			execute.Text = "HACKING…"
			execute.BackgroundColor3 = C.Surface2
			execute.TextColor3 = C.Amber
			executeStroke.Color = C.Amber
		elseif def then
			local needsTarget = def.Target == "other"
			local tname = if needsTarget then (if currentTarget then " › " .. currentTarget.name else " › NO TARGET") else ""
			execute.Text = "EXECUTE " .. string.upper(def.DisplayName) .. tname
			execute.BackgroundColor3 = if needsTarget and not currentTarget then C.Surface2 else C.Violet
			execute.TextColor3 = C.Text
			executeStroke.Color = C.VioletText
		else
			execute.Text = "SELECT A CHIP"
			execute.BackgroundColor3 = C.Surface2
			execute.TextColor3 = C.Muted
			executeStroke.Color = C.Steel
		end
	end

	local function aimHint(): Vector3
		local c = player.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hum and hum.MoveDirection.Magnitude > 0.1 then
			return hum.MoveDirection
		end
		local cam = workspace.CurrentCamera
		return if cam then cam.CFrame.LookVector else Vector3.zAxis
	end

	local function begin(hackId: string, source: string, text: string?, targetId: string?)
		local def = HackCatalog.Get(hackId)
		if not def or pending then
			return
		end
		if def.Target == "other" and not targetId then
			setInfo("No target selected.", C.Amber)
			return
		end
		pending = hackId
		lastResult[hackId] = nil
		setInfo(if source == "typed" then `> {text} → {def.DisplayName}{if targetId and currentTarget then " › " .. currentTarget.name else ""}` else "Hacking…", C.Amber)
		renderChips()
		request:FireServer({ op = "begin", hackId = hackId, targetId = if def.Target == "other" then targetId else nil, source = source, text = text, dir = aimHint() })
	end

	local function executeSelected()
		if not selected or pending or challenge then
			return
		end
		local def = HackCatalog.Get(selected)
		if not def then
			return
		end
		refreshCandidates()
		begin(selected, "chip", nil, if def.Target == "other" and currentTarget then currentTarget.id else nil)
	end

	local function selectChip(id: string)
		if pending or challenge then
			return
		end
		if selected == id then
			executeSelected() -- second press = confirm
			return
		end
		selected = id
		lastResult[id] = nil
		local def = HackCatalog.Get(id)
		if def then
			setInfo(`{string.upper(def.DisplayName)}: {def.Effect}`, C.Text)
		end
		renderChips()
	end

	-- Chips are rebuilt when the layout switches between full (desktop) and compact (touch) chips.
	local chipsCompact: boolean? = nil
	local function buildChips(compactChips: boolean)
	if chipsCompact == compactChips then
		return
	end
	chipsCompact = compactChips
	for _, c in chips do
		c.Button:Destroy()
	end
	table.clear(chips)
	for i, id in HackCatalog.Ids() do
		local def = HackCatalog.Get(id) :: HackCatalog.HackDef
		local chip = CyberChip.build(grid, { Name = def.Short, Serial = def.Serial, Icon = def.Icon, Category = def.Category, Effect = def.Effect, Hotkey = if compactChips then nil else tostring(i), Order = i, Compact = compactChips })
		chips[id] = chip
		chip.Button.MouseEnter:Connect(function()
			focus[id] = true
			renderChips()
		end)
		chip.Button.MouseLeave:Connect(function()
			focus[id] = nil
			renderChips()
		end)
		chip.Button.SelectionGained:Connect(function()
			focus[id] = true
			renderChips()
		end)
		chip.Button.SelectionLost:Connect(function()
			focus[id] = nil
			renderChips()
		end)
		chip.Button.Activated:Connect(function()
			selectChip(id)
		end)
	end
	renderChips()
	end
	buildChips(false)

	-----------------------------------------------------------------------------------------------
	-- Typed command
	local function findByName(fragment: string): Candidate?
		for _, cand in candidates do
			if string.find(string.lower(cand.name), fragment, 1, true) then
				return cand
			end
		end
		return nil
	end

	local function runCommand(text: string)
		if pending or challenge then
			setInfo("Finish or cancel the current hack first.", C.Amber)
			return
		end
		refreshCandidates()
		local hackId, hint = HackCatalog.Parse(text, currentTarget ~= nil)
		if not hackId then
			if hint == "self" then
				setInfo("FREEZE cannot target yourself.", C.Coral)
			else
				setInfo("Unknown hack. Try: " .. table.concat(HackCatalog.Examples, " · "), C.Coral)
			end
			return
		end
		local targetId: string? = nil
		if hint == "boss" then
			for _, cand in candidates do
				if cand.boss then
					targetId = cand.id
					pickedTarget = cand.id
				end
			end
			if not targetId then
				setInfo("The Conductor is not in range.", C.Coral)
				return
			end
		elseif hint == "target" then
			targetId = currentTarget and currentTarget.id
		elseif hint and hint ~= "self" then
			local cand = findByName(hint)
			if not cand then
				setInfo(`No target named "{hint}" in range.`, C.Coral)
				return
			end
			targetId = cand.id
			pickedTarget = cand.id
		end
		refreshCandidates()
		renderTargets()
		selected = hackId
		begin(hackId, "typed", text, targetId)
	end

	command.FocusLost:Connect(function(enter: boolean)
		if enter and command.Text ~= "" then
			local text = command.Text
			command.Text = ""
			runCommand(text)
		end
	end)

	-----------------------------------------------------------------------------------------------
	-- Challenge view
	local arrowGlyphs: { ArrowGlyph.Glyph } = {}
	local signalLabels: { Frame } = {}
	local padButtons: { TextButton } = {}
	local currentGlyph: ArrowGlyph.Glyph? = nil

	local function sendDir(dir: string)
		if not challenge then
			return
		end
		challenge.n += 1 -- replay protection: strictly increasing per challenge
		request:FireServer({ op = "input", token = challenge.token, dir = dir, t = nowT(), n = challenge.n })
		-- immediate local press feedback on the pad
		for _, b in padButtons do
			if b:GetAttribute("Dir") == dir then
				b.BackgroundColor3 = C.Cyan
				task.delay(0.08, function()
					b.BackgroundColor3 = C.Surface2
				end)
			end
		end
	end

	for i, d in { "1", "2", "3", "4", "5" } do
		local b = UIUtil.create("TextButton", { Name = "Pad" .. d, LayoutOrder = i, Size = UDim2.fromOffset(46, 52), BackgroundColor3 = C.Surface2, Text = "", AutoButtonColor = false, Selectable = false }, pad) :: TextButton
		b:SetAttribute("Dir", d)
		UIUtil.corner(b, 8)
		UIUtil.stroke(b, C.Cyan, 1, 0.3)
		local g = ArrowGlyph.new(b, d, 40)
		g.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Frame.Position = UDim2.fromScale(0.5, 0.5)
		g.SetState("pad")
		b.Activated:Connect(function()
			sendDir(d)
		end)
		table.insert(padButtons, b)
	end

	local KIND_TITLE: { [string]: string } = {
		Sequence = "ENTER THE NUMBERS",
		ResistanceBattle = "RESISTANCE BATTLE — fill the bar faster than the Conductor drains it",
		InputChase = "INPUT CHASE — keep up as the Conductor writes numbers; clear them all",
		SignalLock = "SIGNAL LOCK — press each number (1-5) as it crosses the lock zone",
	}

	local function renderArrows(seq: { string }, index: number, chase: boolean)
		for _, g in arrowGlyphs do
			g.Frame:Destroy()
		end
		table.clear(arrowGlyphs)
		currentGlyph = nil
		for i, d in seq do
			if i > 9 then
				break
			end
			local done = (not chase) and i < index
			local current = if chase then i == 1 else i == index
			local g = ArrowGlyph.new(arrowRow, d, if current then 44 else 34, i, current)
			g.SetState(if current then "current" elseif done then "done" else "upcoming")
			if current then
				currentGlyph = g
			end
			table.insert(arrowGlyphs, g)
		end
	end

	local function renderChallengeStatic()
		if not challenge then
			return
		end
		local snap = challenge.snap
		local kind = snap.kind
		local def = HackCatalog.Get(challenge.hackId)
		chalTitle.Text = (if def then string.upper(def.DisplayName) .. " · " else "") .. (KIND_TITLE[kind] or kind)
		local isLock = kind == "SignalLock"
		arrowRow.Visible = not isLock
		track.Visible = isLock
		progTrack.Visible = kind == "ResistanceBattle" or kind == "InputChase"
		barLabel.Visible = progTrack.Visible
		thresholdMark.Visible = kind == "ResistanceBattle"
		if kind == "Sequence" or kind == "ResistanceBattle" then
			renderArrows(snap.seq, snap.index, false)
		elseif kind == "InputChase" then
			renderArrows(snap.seq, 1, true)
		else
			for _, l in signalLabels do
				l:Destroy()
			end
			table.clear(signalLabels)
			for i, sig in snap.signals do
				local g = ArrowGlyph.new(track, sig.d, 34, i)
				g.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
				g.SetState(if sig.state == "locked" then "locked" elseif sig.state == "missed" then "missed" else "upcoming")
				g.Frame:SetAttribute("T", sig.t)
				g.Frame:SetAttribute("State", sig.state)
				table.insert(signalLabels, g.Frame)
			end
		end
		local misses = snap.misses or 0
		local extra = ""
		if kind == "SignalLock" then
			extra = string.format("LOCKS %d/%d", snap.locks or 0, snap.need or 0)
		elseif kind == "InputChase" then
			extra = string.format("QUEUE %d/%d · CLEARED %d/%d", #snap.seq, snap.cap or 0, snap.cleared or 0, snap.need or 0)
		end
		local bossMod = if snap.boss == "CHARGING" then "  · BOSS CHARGING (harder)" elseif snap.boss == "VULNERABLE" or snap.boss == "FROZEN" or snap.boss == "STAGGERED" then "  · BOSS VULNERABLE (easier)" else ""
		local missText = if (snap.maxMisses or 0) > 50 then string.format("MISSES %d", misses) else string.format("MISSES %d/%d", misses, snap.maxMisses)
		chalInfo.Text = extra .. (if extra ~= "" then " · " else "") .. missText .. bossMod .. (if (snap.assist or 1) > 1 then string.format("  · ASSIST x%g", snap.assist) else "")
		pad.Visible = touch
		for _, b in padButtons do -- 5 only appears for challenges configured with five numbers
			b.Visible = (tonumber(b:GetAttribute("Dir")) or 1) <= (snap.symbols or 4)
		end
	end

	-- Per-frame: time bar, resistance drain prediction, chase countdown, signal motion.
	RunService.RenderStepped:Connect(function()
		if not challenge then
			return
		end
		local snap = challenge.snap
		local t = nowT()
		local total = math.max(0.1, (snap.deadline or t) - (snap.started or t))
		timeFill.Size = UDim2.new(math.clamp(((snap.deadline or t) - t) / total, 0, 1), 0, 1, 0)
		if snap.kind == "ResistanceBattle" then
			local p = math.max(0, (snap.progress or 0) - (snap.drain or 0) * (t - (snap.now or t)))
			progFill.Size = UDim2.new(math.clamp(p / 1.2, 0, 1), 0, 1, 0)
			thresholdMark.Position = UDim2.new((snap.threshold or 1) / 1.2, -1, 0, -2)
			progFill.BackgroundColor3 = if p >= (snap.threshold or 1) then C.Green elseif p < 0.2 then C.Coral else C.Cyan
			barLabel.Text = string.format("HACK PROGRESS %d%%   ▼ resistance %.0f%%/s   %d/%d inputs", math.floor(p * 100), (snap.drain or 0) * 100, math.min((snap.index or 1) - 1, snap.length or 0), snap.length or 0)
		elseif snap.kind == "InputChase" then
			local left = math.max(0, (snap.nextAppend or t) - t)
			progFill.Size = UDim2.new(math.clamp(left / math.max(0.1, snap.interval or 1), 0, 1), 0, 1, 0)
			progFill.BackgroundColor3 = if left < 0.4 then C.Coral else C.Amber
			barLabel.Text = string.format("NEXT INJECTED ARROW IN %.1fs", left)
		elseif snap.kind == "SignalLock" then
			local w = track.AbsoluteSize.X
			local zoneX = w * 0.15
			local travel = snap.travel or 1.6
			zone.Size = UDim2.new(0, math.max(8, (snap.window or 0.22) * 2 / travel * (w - zoneX)), 1, 0)
			for _, l in signalLabels do
				local st = l:GetAttribute("T") :: number
				local x = zoneX + (st - t) / travel * (w - zoneX)
				l.Position = UDim2.new(0, x, 0.5, 0)
				l.Visible = x > -20 and x < w + 20
			end
		end
	end)

	-----------------------------------------------------------------------------------------------
	-- Input bindings
	local function dirAction(_: string, inputState: Enum.UserInputState, inputObj: InputObject)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		local d = KEY_DIR[inputObj.KeyCode]
		if d then
			sendDir(d)
		end
		return Enum.ContextActionResult.Sink
	end

	local function bindDirections(on: boolean)
		if on then
			local keys = {}
			for k in KEY_DIR do
				table.insert(keys, k)
			end
			ContextActionService:BindActionAtPriority(DIR_ACTION, dirAction, false, Enum.ContextActionPriority.High.Value + 20, table.unpack(keys))
		else
			ContextActionService:UnbindAction(DIR_ACTION)
		end
	end

	local applyLayout: () -> ()

	local function setOpen(on: boolean)
		if on and architectOpen then
			setInfo("Wrist locked during your Architect turn.", C.Amber)
			return
		end
		open = on
		panel.Visible = on
		if on then
			refreshCandidates()
			renderTargets()
			renderChips()
			applyLayout()
			if UserInputService:GetLastInputType().Name:find("Gamepad") then
				GuiService.SelectedObject = chips[HackCatalog.Ids()[1]].Button
			end
		else
			if challenge then
				request:FireServer({ op = "cancel" })
			end
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
			if targetMarker then
				targetMarker.Parent = nil
			end
			command:ReleaseFocus()
		end
		UITheme.setReserved("wrist", if on then UITheme.rectOf(panel, root) else nil)
	end

	ContextActionService:BindActionAtPriority(TOGGLE_ACTION, function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			setOpen(not open)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Medium.Value, Enum.KeyCode.H, Enum.KeyCode.ButtonL1)

	-- Keys that only matter while the terminal is open (1-4, Return, X, T, Backspace, ButtonB).
	ContextActionService:BindActionAtPriority(KEYS_ACTION, function(_, inputState: Enum.UserInputState, inputObj: InputObject)
		if inputState ~= Enum.UserInputState.Begin or not open then
			return Enum.ContextActionResult.Pass
		end
		local k = inputObj.KeyCode
		if challenge then
			if k == Enum.KeyCode.Backspace or k == Enum.KeyCode.ButtonB then
				request:FireServer({ op = "cancel" })
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end
		local ids = HackCatalog.Ids()
		local num = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
		if num[k] and ids[num[k]] then
			selectChip(ids[num[k]])
			return Enum.ContextActionResult.Sink
		elseif k == Enum.KeyCode.Return then
			executeSelected()
			return Enum.ContextActionResult.Sink
		elseif k == Enum.KeyCode.X then
			cycleTarget()
			return Enum.ContextActionResult.Sink
		elseif k == Enum.KeyCode.T then
			task.defer(function()
				command:CaptureFocus()
			end)
			return Enum.ContextActionResult.Sink
		elseif k == Enum.KeyCode.ButtonB then
			setOpen(false)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
		Enum.KeyCode.Return, Enum.KeyCode.X, Enum.KeyCode.T, Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB)

	pillButton.Activated:Connect(function()
		setOpen(not open)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	execute.Activated:Connect(executeSelected)
	cancelBtn.Activated:Connect(function()
		request:FireServer({ op = "cancel" })
	end)

	-----------------------------------------------------------------------------------------------
	-- Layout: desktop/compact bottom-left; touch in the free right-hand region.
	applyLayout = function()
		local size = root.AbsoluteSize
		if size.X <= 0 then
			size = UITheme.previewSize() or workspace.CurrentCamera.ViewportSize
		end
		local layout = UITheme.layout(size)
		touch = layout.Mode == "touch"
		compact = layout.Mode ~= "desktop"
		buildChips(touch)
		if touch then
			local region = UITheme.touchPanelRegion(size)
			local w = math.max(260, region.Width)
			panel.AnchorPoint = Vector2.new(0, 1)
			panel.Size = UDim2.fromOffset(w, 0)
			panel.Position = UDim2.fromOffset(region.Min.X, region.Max.Y)
			gridLayout.FillDirectionMaxCells = 4
			gridLayout.CellSize = UDim2.fromOffset(math.floor((w - 20 - 3 * 4) / 4), 46)
			gridLayout.CellPadding = UDim2.fromOffset(4, 4)
			command.Visible = true
			pill.AnchorPoint = Vector2.new(0, 1)
			pill.Position = UDim2.fromOffset(region.Min.X, region.Max.Y)
			pill.Size = UDim2.fromOffset(120, 34)
			pillText.Text = if architectOpen then "◈ ARCHITECT TURN" else "◈ WRIST"
		else
			panel.AnchorPoint = Vector2.new(0, 1)
			panel.Size = UDim2.fromOffset(340, 0)
			panel.Position = UDim2.new(0, 12, 1, -54)
			gridLayout.FillDirectionMaxCells = 2
			gridLayout.CellSize = UDim2.fromOffset(156, if compact then 74 else 82)
			gridLayout.CellPadding = UDim2.fromOffset(8, 8)
			command.Visible = true
			pill.AnchorPoint = Vector2.new(0, 1)
			pill.Position = UDim2.new(0, 12, 1, -12)
			pill.Size = UDim2.fromOffset(168, 34)
			pillText.Text = if architectOpen then "◈ WRIST · ARCHITECT TURN" else "◈ WRIST  [H]"
		end
		status.AnchorPoint = Vector2.new(0, 1)
		status.Position = pill.Position + UDim2.fromOffset(pill.Size.X.Offset + 6, 0)
		panelList.Padding = UDim.new(0, if touch then 4 else 6)
		pad.Visible = touch and challenge ~= nil
		if open then
			UITheme.setReserved("wrist", UITheme.rectOf(panel, root))
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
	UITheme.PreviewChanged:Connect(applyLayout)
	UITheme.ReservedChanged:Connect(function(name: string)
		if name ~= "wrist" then
			applyLayout()
		end
	end)
	applyLayout()

	-----------------------------------------------------------------------------------------------
	-- Incoming targeted hack (directive section 7): banner + directional attacker indicator +
	-- quick SHIELD (C / R1 / touch button). Self hacks never produce this warning.
	local OUTCOME_TEXT: { [string]: { string } } = { -- { attacker view, defender view }
		hit = { "HACK LANDED", "HIT" },
		deflected = { "DEFLECTED", "DEFLECTED" },
		perfect = { "PERFECT DEFLECT", "PERFECT DEFLECT · shield cooldown refunded" },
		evaded_cover = { "TARGET BROKE LINE OF SIGHT", "EVADED · line of sight broken" },
		evaded_dodge = { "TARGET DODGED", "EVADED · left the ring" },
		lost = { "HACK FIZZLED", "HACK FIZZLED" },
	}
	local QUICK_ACTION = "WORLD_EXE_HackQuickShield"
	local incomingUi = UIUtil.create("Frame", { Name = "Incoming", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, root) :: Frame
	local incBanner = UIUtil.create("Frame", {
		Name = "IncomingBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.Navy, BackgroundTransparency = 0.1, BorderSizePixel = 0,
	}, incomingUi) :: Frame
	UIUtil.corner(incBanner, 10)
	UIUtil.stroke(incBanner, C.Coral, 2)
	local incList = Instance.new("UIListLayout")
	incList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	incList.Padding = UDim.new(0, 4)
	incList.SortOrder = Enum.SortOrder.LayoutOrder
	incList.Parent = incBanner
	local incPad = Instance.new("UIPadding")
	incPad.PaddingTop, incPad.PaddingBottom, incPad.PaddingLeft, incPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 10), UDim.new(0, 10)
	incPad.Parent = incBanner
	local incTitle = UIUtil.text("Title", incBanner, "⚠ INCOMING HACK", 22, C.Coral, F.Display, { LayoutOrder = 1, AutomaticSize = Enum.AutomaticSize.XY })
	local incHint = UIUtil.text("Hint", incBanner, "", 14, C.Text, F.Label, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.XY })
	local incTrack = UIUtil.create("Frame", { Name = "Window", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.Charcoal, BorderSizePixel = 0 }, incBanner) :: Frame
	local incFill = UIUtil.create("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Coral, BorderSizePixel = 0 }, incTrack) :: Frame
	local quickShield = UIUtil.create("TextButton", {
		Name = "QuickShield", LayoutOrder = 4, Size = UDim2.fromOffset(170, 40), BackgroundColor3 = C.Surface2,
		Text = "◈ SHIELD", TextColor3 = C.Green, Font = F.Title, TextSize = 18, AutoButtonColor = true, Visible = false,
	}, incBanner) :: TextButton
	UIUtil.corner(quickShield, 8)
	UIUtil.stroke(quickShield, C.Green, 2)
	local pointer = ArrowGlyph.new(incomingUi, "R", 54)
	pointer.Frame.Name = "AttackerPointer"
	pointer.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.SetState("wrong")
	local pointerLabel = UIUtil.text("AttackerLabel", incomingUi, "", 13, C.Coral, F.Label, { AnchorPoint = Vector2.new(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY, TextStrokeTransparency = 0.3 })
	local incoming: { id: number, attacker: Model?, resolveAt: number, startAt: number, hackId: string, armed: boolean? }? = nil
	local incomingVfx: { [number]: () -> () } = {}

	local function quickShieldNow()
		request:FireServer({ op = "begin", hackId = "SHIELD", source = "quick" })
	end
	quickShield.Activated:Connect(quickShieldNow)

	local function setIncoming(info: { id: number, attacker: Model?, resolveAt: number, startAt: number, hackId: string, armed: boolean? }?)
		incoming = info
		incomingUi.Visible = info ~= nil
		gui:SetAttribute("IncomingId", if info then info.id else nil)
		if info then
			local def = HackCatalog.Get(info.hackId)
			incTitle.Text = "⚠ INCOMING " .. (if def then string.upper(def.DisplayName) else info.hackId) .. (if info.armed then " · being cast" else "")
			incHint.Text = if touch then "SHIELD · or break line of sight" else "[C] SHIELD · or break line of sight behind cover"
			quickShield.Visible = touch
			incBanner.Size = UDim2.fromOffset(if touch then 330 else 440, 0)
			incBanner.Position = UDim2.new(0.5, 0, 0, if touch then 40 else 64)
			incTitle.TextSize = if touch then 18 else 22
			incHint.TextSize = if touch then 12 else 14
			ContextActionService:BindActionAtPriority(QUICK_ACTION, function(_, st: Enum.UserInputState)
				if st == Enum.UserInputState.Begin then
					quickShieldNow()
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.C, Enum.KeyCode.ButtonR1)
		else
			ContextActionService:UnbindAction(QUICK_ACTION)
		end
	end

	RunService.RenderStepped:Connect(function()
		local inc = incoming
		if not inc then
			return
		end
		local t = nowT()
		incFill.Size = UDim2.fromScale(math.clamp((inc.resolveAt - t) / math.max(0.1, inc.resolveAt - inc.startAt), 0, 1), 1)
		local cam = workspace.CurrentCamera
		local aRoot = inc.attacker and inc.attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not cam or not aRoot then
			pointer.Frame.Visible = false
			pointerLabel.Visible = false
			return
		end
		-- screen-space direction to the attacker: right = camera right, up = camera forward (flattened)
		local rel = aRoot.Position - cam.CFrame.Position
		local fwd = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		fwd = if fwd.Magnitude > 1e-3 then fwd.Unit else Vector3.zAxis
		local x, y = rel:Dot(cam.CFrame.RightVector), rel:Dot(fwd)
		local ang = math.atan2(-y, x) -- UI y grows downward
		local vp = root.AbsoluteSize
		local r = math.min(vp.X, vp.Y) * 0.36
		local px, py = vp.X / 2 + math.cos(ang) * r, vp.Y / 2 + math.sin(ang) * r
		-- never draw the pointer over the banner (short touch screens put the ring top under it)
		local bPos, bSize = incBanner.AbsolutePosition - root.AbsolutePosition, incBanner.AbsoluteSize
		if py < bPos.Y + bSize.Y + 34 and px > bPos.X - 34 and px < bPos.X + bSize.X + 34 then
			py = bPos.Y + bSize.Y + 34
		end
		pointer.Frame.Visible = true
		pointer.Frame.Position = UDim2.fromOffset(px, py)
		pointer.Frame.Rotation = math.deg(ang)
		pointerLabel.Visible = true
		pointerLabel.Text = string.format("%s · %d studs", (inc.attacker :: Model).Name, math.floor(rel.Magnitude + 0.5))
		pointerLabel.Position = UDim2.fromOffset(px, py + 44) -- under the arrow, never on it
	end)

	local lastSnap: { token: number, index: number, misses: number, cleared: number, locks: number }? = nil
	local function diffSnapshot(token: number, snap: { [string]: any })
		local cur = { token = token, index = snap.index or 0, misses = snap.misses or 0, cleared = snap.cleared or 0, locks = snap.locks or 0 }
		local prev = lastSnap
		lastSnap = cur
		if not prev or prev.token ~= token then
			return
		end
		if cur.misses > prev.misses then
			HackFeel.Cue("wrong")
			local g = currentGlyph
			if g then
				g.SetState("wrong")
				g.Shake()
				task.delay(0.22, function()
					if currentGlyph == g then
						g.SetState("current")
					end
				end)
			end
			gui:SetAttribute("LastInputFeedback", "wrong")
		elseif cur.index > prev.index or cur.cleared > prev.cleared or cur.locks > prev.locks then
			HackFeel.Cue("tick")
			if currentGlyph then
				currentGlyph.Pulse()
			end
			gui:SetAttribute("LastInputFeedback", "correct")
		end
	end

	-----------------------------------------------------------------------------------------------
	-- FLING flick aim (owner 2026-11-16: "in the direction the cursor moves after casting").
	-- After a FLING on someone else is cast, the server opens a flick window (op "flick": the
	-- warning window for players/NPCs, a short window for the boss). During it, the direction the
	-- mouse MOVES on screen becomes the throw direction on the ground, relative to the camera:
	-- screen right = camera right, screen up = camera forward. Only recent movement counts (last
	-- 0.25 s, at least 14 px), so the latest flick wins. A flat arrow at the target's feet shows the
	-- current throw: bright = your flick, dim = the default (no flick: away from you).
	local FLICK_SPAN = 0.2
	local FLICK_MIN_PX = 16
	local flick: { target: Model, boss: boolean, untilT: number }? = nil
	local flickSamples: { { t: number, d: Vector2 } } = {}
	local lastMouse: Vector2? = nil
	local aimFolder = Instance.new("Folder")
	aimFolder.Name = "WORLD_EXE_FlingAim"
	local function aimBar(name: string): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 70, 40) -- orange-red: distinct from the yellow lane markers
		p.Transparency = 0.2
		p.Parent = aimFolder
		return p
	end
	local aimShaft, aimHeadA, aimHeadB = aimBar("Shaft"), aimBar("HeadA"), aimBar("HeadB")
	local aimLand = aimBar("Landing")
	aimLand.Shape = Enum.PartType.Cylinder
	aimLand.Material = Enum.Material.SmoothPlastic
	local lastAimSent: Vector3? = nil
	local lastAimSentT = 0

	local function flat(v: Vector3): Vector3?
		local h = Vector3.new(v.X, 0, v.Z)
		return if h.Magnitude > 0.05 then h.Unit else nil
	end

	local function startFlick(target: Model, boss: boolean, untilT: number)
		flick = { target = target, boss = boss, untilT = untilT }
		table.clear(flickSamples)
		currentAim = nil
		lastAimSent = nil
		lastMouse = UserInputService:GetMouseLocation() -- movement before the cast does not count
		gui:SetAttribute("FlingAim", nil)
		gui:SetAttribute("FlickActive", true)
	end
	local function endFlick()
		flick = nil
		currentAim = nil
		table.clear(flickSamples)
		aimFolder.Parent = nil
		gui:SetAttribute("FlickActive", false)
	end

	-- mouse movement: with a free cursor, the change in cursor position per frame (sampled in the
	-- render step below); with a locked cursor (shift-lock / camera drag), the raw movement delta.
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not flick or input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then
			return -- free cursor: handled by position sampling
		end
		local d = Vector2.new(input.Delta.X, input.Delta.Y)
		if d.Magnitude > 0 then
			table.insert(flickSamples, { t = os.clock(), d = d })
		end
	end)

	local function predictedThrow(boss: boolean): number
		local up = HackCatalog.Tune("FlingTarget", if boss then "BossUp" else "Up")
		local fwd = HackCatalog.Tune("FlingTarget", if boss then "BossForward" else "Forward")
		return math.clamp(fwd * 2 * up / workspace.Gravity, 6, 80)
	end

	RunService.RenderStepped:Connect(function()
		local f = flick
		if f and (nowT() > f.untilT + 0.3 or not f.target.Parent) then
			endFlick()
			f = nil
		end
		if not f then
			return
		end
		local root = f.target:FindFirstChild("HumanoidRootPart") :: BasePart?
		local cam = workspace.CurrentCamera
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not cam then
			aimFolder.Parent = nil
			return
		end
		-- recent movement → world direction
		local tnow = os.clock()
		if UserInputService.MouseEnabled and UserInputService.MouseBehavior == Enum.MouseBehavior.Default then
			local m = UserInputService:GetMouseLocation()
			if lastMouse and (m - lastMouse).Magnitude > 0 then
				table.insert(flickSamples, { t = tnow, d = m - (lastMouse :: Vector2) })
			end
			lastMouse = m
		end
		local sum = Vector2.zero
		for i = #flickSamples, 1, -1 do
			if tnow - flickSamples[i].t > FLICK_SPAN then
				table.remove(flickSamples, i)
			else
				sum += flickSamples[i].d
			end
		end
		if sum.Magnitude >= FLICK_MIN_PX then
			local fwd = flat(cam.CFrame.LookVector) or Vector3.zAxis
			local right = flat(cam.CFrame.RightVector) or Vector3.xAxis
			currentAim = flat(right * sum.X - fwd * sum.Y) -- screen y grows downward
		end
		gui:SetAttribute("FlingAim", if currentAim then string.format("%.2f,%.2f", currentAim.X, currentAim.Z) else nil)
		-- the first slide throws immediately: send it once and close the window
		if currentAim then
			local aim = currentAim :: Vector3
			lastAimSent, lastAimSentT = aim, tnow
			request:FireServer({ op = "aim", dir = aim })
			gui:SetAttribute("LastFlick", string.format("%.2f,%.2f", aim.X, aim.Z))
			endFlick()
			return
		end
		-- draw: your flick (bright) or the default throw away from you (dim)
		local dir = currentAim or (myRoot and flat(root.Position - myRoot.Position)) or flat(root.CFrame.LookVector)
		if not dir then
			aimFolder.Parent = nil
			return
		end
		local bright = currentAim ~= nil
		for _, p in { aimShaft, aimHeadA, aimHeadB } do
			p.Transparency = if bright then 0.15 else 0.7
		end
		aimLand.Transparency = if bright then 0.5 else 0.85
		local len = predictedThrow(f.boss)
		local feet = root.Position - Vector3.new(0, 2.8, 0)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { f.target, aimFolder }
		local down = workspace:Raycast(root.Position, Vector3.new(0, -14, 0), params)
		if down then
			feet = down.Position
		end
		local y = Vector3.new(0, 0.15, 0)
		local start = feet + dir * 2.5 + y
		local tip = feet + dir * len + y
		aimShaft.Size = Vector3.new(0.8, 0.1, (tip - start).Magnitude)
		aimShaft.CFrame = CFrame.lookAt((start + tip) / 2, tip)
		local headLen = math.min(4, len * 0.3)
		for i, h in { aimHeadA, aimHeadB } do
			local side = if i == 1 then 1 else -1
			local back = CFrame.lookAt(tip, tip + dir) * CFrame.Angles(0, math.rad(150 * side), 0)
			h.Size = Vector3.new(0.8, 0.1, headLen)
			h.CFrame = back * CFrame.new(0, 0, -headLen / 2)
		end
		aimLand.Size = Vector3.new(0.1, 6, 6)
		aimLand.CFrame = CFrame.new(tip) * CFrame.Angles(0, 0, math.rad(90))
		aimFolder.Parent = cam
	end)

	-----------------------------------------------------------------------------------------------
	-- FLING GRAB control (owner 2026-11-16: "almost like the gravity gun"). When the server sends
	-- grab_control, the target is held: every frame the cursor is projected onto the ground and sent
	-- as the hold point (~20/s), together with the current drag direction. LEFT-CLICK throws it the
	-- way the mouse is being dragged (power from drag speed); clicking without dragging throws it
	-- straight away from you. The server auto-throws after HoldSeconds. The arrow at the target's
	-- feet shows the throw: bright = your drag, dim = the default (away from you).
	local THROW_ACTION = "WORLD_EXE_HackGrabThrow"
	local hold: { target: Model, boss: boolean, untilT: number }? = nil
	local holdSamples: { { t: number, d: Vector2 } } = {}
	local holdLastMouse: Vector2? = nil
	local holdVirtual = Vector2.zero -- locked-cursor aiming: accumulated mouse deltas of this hold
	local holdLastSend = 0
	local holdDir: string? = nil -- "up" | "left" | "right" | "back" while dragging
	local holdPower = 0

	local function holdCursorGround(model: Model): Vector3?
		local cam = workspace.CurrentCamera
		if not cam or not UserInputService.MouseEnabled then
			return nil
		end
		local m = UserInputService:GetMouseLocation()
		local ray = cam:ViewportPointToRay(m.X, m.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { model, player.Character :: any, aimFolder }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		if hit then
			return hit.Position
		end
		if ray.Direction.Y < -1e-3 then
			local t = -ray.Origin.Y / ray.Direction.Y
			return ray.Origin + ray.Direction * t
		end
		-- cursor in the sky: aim along the cursor direction at the leash distance (server clamps it)
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local fl = flat(ray.Direction)
		if myRoot and fl then
			return myRoot.Position + fl * HackCatalog.Tune("FlingTarget", "HoldLeash")
		end
		return nil
	end

	-- Throw zones (owner 2026-11-16): a point at the screen centre and four lines from it to the
	-- screen CORNERS split the screen into four triangles — top = UP, left = LEFT, right = RIGHT,
	-- bottom = BEHIND. The regions are NOT shown to players; the drawing below is a debug aid only.
	-- Its own ScreenGui ignores the top-bar inset so the drawn centre is exactly the camera centre
	-- (the same point the classification uses).
	local zonesGui = Instance.new("ScreenGui")
	zonesGui.Name = "WORLD_EXE_ThrowZones"
	zonesGui.IgnoreGuiInset = true
	zonesGui.ResetOnSpawn = false
	zonesGui.DisplayOrder = 8
	zonesGui.Enabled = false
	zonesGui.Parent = playerGui
	local reticle = UIUtil.create("Frame", { Name = "ThrowReticle", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, zonesGui) :: Frame
	local dot = UIUtil.create("Frame", { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.Text, BackgroundTransparency = 0.2, BorderSizePixel = 0 }, reticle) :: Frame
	UIUtil.corner(dot, 4)
	local zoneLines: { Frame } = {}
	for i = 1, 4 do
		local ln = UIUtil.create("Frame", { Name = "Diagonal" .. i, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Text, BackgroundTransparency = 0.75, BorderSizePixel = 0 }, reticle) :: Frame
		table.insert(zoneLines, ln)
	end
	local zoneLabels: { [string]: TextLabel } = {}
	for name, pos in { up = UDim2.fromScale(0.5, 0.22), left = UDim2.fromScale(0.28, 0.5), right = UDim2.fromScale(0.72, 0.5), back = UDim2.fromScale(0.5, 0.8) } do -- side labels kept clear of the wrist panel
		zoneLabels[name] = UIUtil.text("Zone_" .. name, reticle, if name == "back" then "BEHIND YOU" else string.upper(name), 16, C.Muted, F.Title, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, TextStrokeTransparency = 0.4,
		})
	end
	local function layoutZoneLines()
		local s = reticle.AbsoluteSize
		local c = s / 2
		for i, corner in { Vector2.new(0, 0), Vector2.new(s.X, 0), Vector2.new(s.X, s.Y), Vector2.new(0, s.Y) } do
			local d = corner - c
			local ln = zoneLines[i]
			ln.Size = UDim2.fromOffset(d.Magnitude, 2)
			ln.Position = UDim2.fromOffset(c.X + d.X / 2, c.Y + d.Y / 2)
			ln.Rotation = math.deg(math.atan2(d.Y, d.X))
		end
	end
	reticle:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutZoneLines)
	local function updateReticle(mode: string?)
		local m = mode or "up"
		for name, l in zoneLabels do
			local on = name == m
			l.TextColor3 = if on then C.Coral else C.Muted
			l.TextSize = if on then 22 else 15
			l.TextTransparency = if on then 0 else 0.4
		end
	end

	local function endHold(why: string?)
		zonesGui.Enabled = false
		gui:SetAttribute("HoldEnd", why or "?")
		hold = nil
		table.clear(holdSamples)
		holdDir = nil
		holdPower = 0
		ContextActionService:UnbindAction(THROW_ACTION)
		aimFolder.Parent = nil
		gui:SetAttribute("Holding", false)
	end

	local function throwNow()
		if not hold then
			return
		end
		request:FireServer({ op = "throw", dir = holdDir, power = holdPower })
		gui:SetAttribute("LastThrow", string.format("%s p%.2f", holdDir or "up (no drag)", holdPower))
		endHold("throw")
	end

	local function startHold(target: Model, boss: boolean, untilT: number)
		hold = { target = target, boss = boss, untilT = untilT }
		table.clear(holdSamples)
		holdLastMouse = UserInputService:GetMouseLocation()
		holdVirtual = Vector2.zero
		holdDir = nil
		holdPower = 0
		gui:SetAttribute("Holding", true)
		-- the zone lines/labels are a debug aid only (owner 2026-11-16: "they shouldn't be visible");
		-- set the player attribute WORLD_EXE_ShowThrowZones = true in Studio to draw them
		zonesGui.Enabled = player:GetAttribute("WORLD_EXE_ShowThrowZones") == true
		layoutZoneLines()
		updateReticle(nil)
		ContextActionService:BindActionAtPriority(THROW_ACTION, function(_, st: Enum.UserInputState)
			if st == Enum.UserInputState.Begin then
				throwNow()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 30, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
		HackFeel.Popup("AIM FROM THE CENTRE · CLICK TO THROW", C.Coral)
	end

	UserInputService.InputBegan:Connect(function(input: InputObject)
		if hold and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2) then
			throwNow()
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not hold or input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then
			return -- free cursor: sampled per frame below
		end
		local d = Vector2.new(input.Delta.X, input.Delta.Y)
		if d.Magnitude > 0 then
			table.insert(holdSamples, { t = os.clock(), d = d })
		end
	end)

	RunService.RenderStepped:Connect(function()
		local h = hold
		if not h then
			return
		end
		if nowT() > h.untilT + 0.5 or not h.target.Parent then
			endHold(if h.target.Parent then "timeout" else "target gone")
			return
		end
		local root = h.target:FindFirstChild("HumanoidRootPart") :: BasePart?
		local cam = workspace.CurrentCamera
		if not root or not cam then
			return
		end
		local tnow = os.clock()
		-- throw mode from the CURSOR POSITION relative to the screen centre (owner 2026-11-16):
		-- above = UP, left/right = that SIDE, below = BACK (over and behind you); near the centre = UP.
		-- Farther from the centre = a stronger throw.
		-- regions are the four triangles made by the lines from the centre to the screen CORNERS:
		-- normalise the offset by the half-screen size, then compare |x| and |y|
		local vp = cam.ViewportSize
		local mloc = UserInputService:GetMouseLocation()
		local offC = mloc - vp / 2
		-- Rev 15 shift-lock / first-person fix: a LOCKED cursor always sits at the centre, so the zones
		-- read "up" forever. While locked, the zone comes from (1) a held movement key / left stick
		-- (W/↑ = up, A = left, D = right, S = behind), else (2) a virtual cursor that accumulates this
		-- hold's mouse deltas (slide right = right, as when unlocked). Unlocked keeps the screen zones.
		local locked = UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default
		local aimScheme = "screen"
		if locked or not UserInputService.MouseEnabled then
			for _, sm in holdSamples do
				holdVirtual += sm.d
			end
			table.clear(holdSamples)
			holdVirtual = Vector2.new(math.clamp(holdVirtual.X, -vp.X / 2, vp.X / 2), math.clamp(holdVirtual.Y, -vp.Y / 2, vp.Y / 2))
			-- movement intent in CAMERA space (one path for WASD, arrows, gamepad stick and the touch
			-- thumbstick): Humanoid.MoveDirection is world-space and camera-relative by construction
			local kx, ky = 0, 0
			local myHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local md = if myHum then myHum.MoveDirection else Vector3.zero
			if md.Magnitude > 0.3 then
				local camLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
				local camRight = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)
				if camLook.Magnitude > 0.01 and camRight.Magnitude > 0.01 then
					local fx, fy = md:Dot(camRight.Unit), -md:Dot(camLook.Unit)
					kx = if math.abs(fx) > 0.38 then math.sign(fx) else 0
					ky = if math.abs(fy) > 0.38 then math.sign(fy) else 0
				end
			end
			if kx ~= 0 or ky ~= 0 then
				aimScheme = "keys"
				offC = Vector2.new(math.clamp(kx, -1, 1) * vp.X / 2, math.clamp(ky, -1, 1) * vp.Y / 2) * 0.8 -- keys throw at 80 % power; W+A/D ties go UP
			else
				aimScheme = "virtual"
				offC = holdVirtual
			end
		end
		gui:SetAttribute("AimScheme", aimScheme)
		local nx, ny = offC.X / math.max(1, vp.X / 2), offC.Y / math.max(1, vp.Y / 2)
		if offC.Magnitude >= 6 then
			if math.abs(ny) >= math.abs(nx) then
				holdDir = if ny < 0 then "up" else "back"
			else
				holdDir = if nx > 0 then "right" else "left"
			end
			holdPower = math.clamp(math.max(math.abs(nx), math.abs(ny)), 0, 1) -- centre 0 → screen edge 1
		else
			holdDir = nil -- at the centre: a click launches it straight up
			holdPower = 0
		end
		updateReticle(holdDir)
		-- hold point (~20/s)
		if tnow - holdLastSend >= 0.05 then
			holdLastSend = tnow
			local p = holdCursorGround(h.target)
			if p then
				request:FireServer({ op = "hold", pos = p, dir = holdDir })
			end
		end
		gui:SetAttribute("HoldDir", holdDir)
		-- throw arrow at the held target, using the same geometry as the server:
		-- toMe = target → me, right = my right while facing the target, up = up
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local toMe = (myRoot and flat(myRoot.Position - root.Position)) or Vector3.zAxis
		local rightV = (-toMe):Cross(Vector3.yAxis).Unit
		local mode = holdDir or "up"
		local dir: Vector3 = if mode == "up" then (Vector3.yAxis * 2.6 - toMe).Unit elseif mode == "back" then toMe elseif mode == "right" then rightV else -rightV
		local bright = holdDir ~= nil
		for _, p in { aimShaft, aimHeadA, aimHeadB } do
			p.Transparency = if bright then 0.25 else 0.7
			p.Color = Color3.fromRGB(120, 230, 255) -- small electric-cyan hint (was a large orange-red arrow)
		end
		aimLand.Transparency = 1
		local len = 3.5 + 3 * holdPower
		local start = root.Position + dir * 2.5
		local tip = root.Position + dir * len
		local upRef = if mode == "up" then toMe else Vector3.yAxis -- lookAt needs a non-parallel up
		aimShaft.Size = Vector3.new(0.25, 0.08, (tip - start).Magnitude)
		aimShaft.CFrame = CFrame.lookAt((start + tip) / 2, tip, upRef)
		local headLen = 1.2
		for i, hp in { aimHeadA, aimHeadB } do
			local side = if i == 1 then 1 else -1
			local back = CFrame.lookAt(tip, tip + dir, upRef) * CFrame.Angles(0, math.rad(150 * side), 0)
			hp.Size = Vector3.new(0.25, 0.08, headLen)
			hp.CFrame = back * CFrame.new(0, 0, -headLen / 2)
		end
		aimFolder.Parent = cam
	end)

	local grabBeams: { [Model]: () -> () } = {}

	-----------------------------------------------------------------------------------------------
	-- Server events
	local function showChallenge(on: boolean)
		grid.Visible = not on
		targetRow.Visible = not on
		command.Visible = not on
		footer.Visible = not on
		chal.Visible = on
		bindDirections(on)
		if on then
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil -- the D-pad now types directions, not GUI navigation
			end
			if not open then
				open = true
				panel.Visible = true
			end
		end
		pad.Visible = on and touch
	end

	-- FLING SELF executor (this client owns its character's physics).
	local flingConn: RBXScriptConnection? = nil
	local flingParts: { Instance } = {}
	local function endFling()
		if flingConn then
			flingConn:Disconnect()
			flingConn = nil
		end
		for _, inst in flingParts do
			inst:Destroy()
		end
		table.clear(flingParts)
		MoveState.Release("flingSelf")
	end
	local function flingSelf(v: Vector3, steer: number, minAir: number, maxT: number, blockedFrac: number, ctl: { turn: number, brake: number, fallCap: number, glideCap: number })
		endFling()
		local c = player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then
			return
		end
		MoveState.Claim("flingSelf", true) -- FLING SELF overrides dash / super-speed (MovementController stops its drive)
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		hrp.AssemblyLinearVelocity = v
		local att = Instance.new("Attachment")
		att.Name = "WristFlingAttachment"
		att.Parent = hrp
		local lv = Instance.new("LinearVelocity")
		lv.Name = "WristFlingCarry"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.xAxis
		lv.SecondaryTangentAxis = Vector3.zAxis
		lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
		lv.MaxForce = hrp.AssemblyMass * 2500
		local base = Vector2.new(v.X, v.Z)
		lv.PlaneVelocity = base
		lv.Parent = hrp
		table.insert(flingParts, att)
		table.insert(flingParts, lv)
		local t0 = os.clock()
		local slowFor = 0
		local stats = { apexY = hrp.Position.Y, startY = hrp.Position.Y, start = hrp.Position }
		gui:SetAttribute("LastFling", nil)
		flingConn = RunService.Heartbeat:Connect(function(dt)
			if not hrp.Parent or hum.Health <= 0 then
				endFling()
				return
			end
			local md = hum.MoveDirection
			local want = Vector2.new(md.X, md.Z)
			-- Air control (owner 2026-11-16 "control your fall a bit more"):
			-- holding a direction turns the launch carry toward it; holding the opposite direction brakes it.
			if want.Magnitude > 0.1 and base.Magnitude > 0.5 then
				local w = want.Unit
				local b = base.Unit
				local dot = math.clamp(b:Dot(w), -1, 1)
				if dot < -0.3 then
					base = b * math.max(0, base.Magnitude - ctl.brake * dt)
				else
					local ang = math.acos(dot)
					local step = math.min(ang, ctl.turn * dt)
					local cross = b.X * w.Y - b.Y * w.X
					local a = if cross >= 0 then step else -step
					local c, s = math.cos(a), math.sin(a)
					base = Vector2.new(b.X * c - b.Y * s, b.X * s + b.Y * c) * base.Magnitude
				end
			end
			local plane = base + want * steer
			lv.PlaneVelocity = plane
			-- Fall control: cap the descent; holding Jump while falling glides (lower cap).
			local vel = hrp.AssemblyLinearVelocity
			if vel.Y < 0 then
				local holding = hum.Jump or UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
				local cap = if holding then ctl.glideCap else ctl.fallCap
				if vel.Y < -cap then
					hrp.AssemblyLinearVelocity = Vector3.new(vel.X, -cap, vel.Z)
				end
				gui:SetAttribute("FlingGlide", holding)
			end
			stats.apexY = math.max(stats.apexY, hrp.Position.Y)
			local elapsed = os.clock() - t0
			local hv = Vector2.new(hrp.AssemblyLinearVelocity.X, hrp.AssemblyLinearVelocity.Z).Magnitude
			if elapsed > minAir and hv < plane.Magnitude * blockedFrac then
				slowFor += dt
			else
				slowFor = 0
			end
			local landed = elapsed > minAir and hum.FloorMaterial ~= Enum.Material.Air
			if landed or elapsed > maxT or slowFor > 0.15 then
				local p = hrp.Position
				gui:SetAttribute("LastFling", string.format("rise %.1f  horiz %.1f  air %.2fs  end=%s", stats.apexY - stats.startY, Vector3.new(p.X - stats.start.X, 0, p.Z - stats.start.Z).Magnitude, elapsed, if landed then "landed" elseif slowFor > 0.15 then "blocked" else "timeout"))
				endFling()
			end
		end)
	end

	event.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		local op = data.op
		if op == "result" then
			local id = data.hackId
			if id and pending == id then
				pending = nil
			end
			if id then
				lastResult[id] = if data.ok then "accepted" else "rejected"
				task.delay(1.2, function()
					if lastResult[id] then
						lastResult[id] = nil
						renderChips()
					end
				end)
			end
			if data.ok and data.reason == "applied" then
				HackFeel.Cue(if id == "FLING_SELF" then "launch" else "hit")
			elseif not data.ok and data.reason ~= "success" then
				HackFeel.Cue("failed")
			end
			if data.ok then
				setInfo("✓ " .. (data.text or "Executed."), C.Green)
			else
				setInfo("× " .. (REASON[data.reason] or tostring(data.reason)), C.Coral)
			end
			if id == nil then
				pending = nil
			end
			renderChips()
		elseif op == "challenge" then
			local sameToken = challenge ~= nil and challenge.token == data.token
			if not sameToken then
				setInfo("") -- a new challenge clears the previous attempt's result line
			end
			challenge = { token = data.token, hackId = data.hackId, snap = data.snap, recv = os.clock(), n = if sameToken and challenge then challenge.n else 0, targetId = if typeof(data.targetId) == "string" then data.targetId else nil }
			showChallenge(true)
			renderChallengeStatic()
			diffSnapshot(data.token, data.snap)
		elseif op == "challenge_end" then
			if challenge and challenge.token == data.token then
				challenge = nil
			end
			lastSnap = nil
			if data.result == "success" then
				HackFeel.Cue("sequence")
				HackFeel.Popup("SEQUENCE COMPLETE", C.Cyan)
			else
				HackFeel.Cue("failed")
				HackFeel.Popup(string.upper(REASON[data.result] or tostring(data.result)), C.Coral)
			end
			gui:SetAttribute("LastChallengeEnd", data.result)
			showChallenge(false)
			pending = nil
			renderChips()
		elseif op == "fling_self" then
			if typeof(data.v) == "Vector3" then
				flingSelf(data.v, tonumber(data.steer) or 0, tonumber(data.minAir) or 0.2, tonumber(data.maxT) or 4, tonumber(data.blocked) or 0.3, {
					turn = tonumber(data.turn) or 3, brake = tonumber(data.brake) or 45, fallCap = tonumber(data.fallCap) or 75, glideCap = tonumber(data.glideCap) or 28 })
			end
		elseif op == "ragdoll" then
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				endFling()
				hum:ChangeState(if data.on then Enum.HumanoidStateType.Physics else Enum.HumanoidStateType.GettingUp)
			end
		elseif op == "vfx" then
			if data.kind == "launch" and typeof(data.pos) == "Vector3" then
				HackVfx.Launch(if typeof(data.model) == "Instance" and data.model:IsA("Model") then data.model else nil, data.pos, tonumber(data.scale) or 1)
			elseif data.kind == "glide" and typeof(data.model) == "Instance" and data.model:IsA("Model") then
				HackVfx.Glide(data.model, tonumber(data.seconds) or 1.5)
			elseif data.kind == "throw" and typeof(data.model) == "Instance" and data.model:IsA("Model") then
				HackVfx.ThrowTrail(data.model)
			elseif data.kind == "land" and typeof(data.pos) == "Vector3" then
				HackVfx.LandImpact(if typeof(data.model) == "Instance" and data.model:IsA("Model") then data.model else nil, data.pos, tonumber(data.strength) or 0.5)
			end
		elseif op == "incoming" then
			local tgt = data.target
			local atk = if typeof(data.attacker) == "Instance" and data.attacker:IsA("Model") then data.attacker else nil
			if typeof(tgt) == "Instance" and tgt:IsA("Model") and typeof(data.center) == "Vector3" then
				local id = tonumber(data.id) or 0
				local armed = data.armed == true -- FLING: raised at cast start, no countdown
				local startAt = tonumber(data.startAt) or nowT()
				local resolveAt = if armed then startAt + 1e6 else (tonumber(data.resolveAt) or nowT() + 1)
				incomingVfx[id] = HackVfx.Incoming(atk, tgt, data.center, tonumber(data.radius) or 9, startAt, resolveAt, tostring(data.hackId))
				task.delay(if armed then 30 else 6, function() -- safety cleanup if the result never arrives
					local f = incomingVfx[id]
					if f then
						incomingVfx[id] = nil
						f()
					end
					if incoming and incoming.id == id then
						setIncoming(nil)
					end
				end)
				if tgt == player.Character then
					HackFeel.Cue("incoming")
					setIncoming({ id = id, attacker = atk, resolveAt = resolveAt, startAt = startAt, hackId = tostring(data.hackId), armed = armed })
				end
			end
		elseif op == "incoming_result" then
			local id = tonumber(data.id) or 0
			local f = incomingVfx[id]
			if f then
				incomingVfx[id] = nil
				f()
			end
			if incoming and incoming.id == id then
				setIncoming(nil)
			end
			if flick and flick.target == data.target and data.hackId == "FLING_TARGET" then
				endFlick()
			end
			if (data.outcome == "deflected" or data.outcome == "perfect") and typeof(data.target) == "Instance" and data.target:IsA("Model") then
				HackVfx.Deflect(data.target, data.outcome == "perfect")
			end
		elseif op == "hack_outcome" then
			local o = tostring(data.outcome)
			local defender = data.role == "defender"
			local txt = OUTCOME_TEXT[o]
			local label = if txt then txt[if defender then 2 else 1] else string.upper(o)
			local good = if defender then o ~= "hit" else o == "hit"
			local cue = if o == "perfect" then "perfect" elseif o == "deflected" then "deflect" elseif o == "evaded_cover" or o == "evaded_dodge" then "evaded" elseif o == "hit" then (if defender then "failed" else "hit") else "failed"
			HackFeel.Cue(cue)
			HackFeel.Popup(label, if good then (if o == "perfect" then C.Text else C.Green) else C.Coral, o == "perfect")
			setInfo(label, if good then C.Green else C.Coral)
			gui:SetAttribute("LastOutcome", (if defender then "defender:" else "attacker:") .. o)
		elseif op == "boss" then
			local ev = tostring(data.event)
			if ev == "engaged" then
				HackFeel.Popup("CONDUCTOR ENGAGED", C.Amber)
			elseif ev == "defeated" then
				HackFeel.Cue("perfect")
				HackFeel.Popup(string.format("CONDUCTOR OFFLINE · %.0fs", tonumber(data.seconds) or 0), C.Green, true)
			elseif ev == "failed" and data.userId == player.UserId then
				HackFeel.Cue("failed")
				HackFeel.Popup("DOWNED · leave and return to retry", C.Coral)
			elseif ev == "reset" then
				HackFeel.Popup("CONDUCTOR RESET", C.Muted)
			end
			gui:SetAttribute("LastBossEvent", ev)
		elseif op == "grab" then
			if typeof(data.target) == "Instance" and data.target:IsA("Model") then
				local old = grabBeams[data.target]
				if old then
					old()
				end
				local atk = if typeof(data.attacker) == "Instance" and data.attacker:IsA("Model") then data.attacker else nil
				grabBeams[data.target] = HackVfx.GrabBeam(atk, data.target)
				local tgt = data.target
				task.delay(8, function() -- safety cleanup
					local f = grabBeams[tgt]
					if f then
						grabBeams[tgt] = nil
						f()
					end
				end)
			end
		elseif op == "grab_control" then
			if typeof(data.target) == "Instance" and data.target:IsA("Model") then
				startHold(data.target, data.boss == true, tonumber(data.untilT) or nowT() + 3)
			end
		elseif op == "grab_end" then
			if typeof(data.target) == "Instance" then
				local f = grabBeams[data.target :: any]
				if f then
					grabBeams[data.target :: any] = nil
					f()
				end
				if hold and hold.target == data.target then
					endHold("grab_end")
				end
			end
		elseif op == "flick" then
			if typeof(data.target) == "Instance" and data.target:IsA("Model") then
				startFlick(data.target, data.boss == true, tonumber(data.untilT) or nowT() + 1)
				HackFeel.Popup("SLIDE THE MOUSE TO THROW", C.Coral)
			end
		elseif op == "station" then
			HackFeel.Popup(tostring(data.text), C.Cyan)
			setInfo(tostring(data.text), C.Cyan)
		elseif op == "frozen" then
			frozenUntil = if data.on then nowT() + (tonumber(data.seconds) or 3) else 0
			if data.on then
				endFling()
			end
		end
	end)

	-----------------------------------------------------------------------------------------------
	-- Refresh loop: arbitration with the Architect tray, targets, cooldowns, shield/frozen status.
	task.spawn(function()
		local lastTargets = 0
		while gui.Parent do
			local arch = playerGui:FindFirstChild("WORLD_EXE_Architect")
			local nowArch = arch ~= nil and arch:IsA("ScreenGui") and arch.Enabled
			if nowArch ~= architectOpen then
				architectOpen = nowArch
				if nowArch and open then
					setOpen(false)
				end
				pillText.Text = if nowArch then (if touch then "◈ ARCHITECT TURN" else "◈ WRIST · ARCHITECT TURN") else (if touch then "◈ WRIST" else "◈ WRIST  [H]")
				pillText.TextColor3 = if nowArch then C.Muted else C.Cyan
			end
			gui:SetAttribute("ArchitectLock", architectOpen)
			gui:SetAttribute("Open", open)
			if open and os.clock() - lastTargets > 0.25 and not challenge then
				lastTargets = os.clock()
				refreshCandidates()
				renderTargets()
				local mode = nil
				for _, cand in candidates do
					if cand.boss then
						mode = cand.model:GetAttribute(A.BossChallenge)
					end
				end
				modeText.Text = if mode then "BOSS HACK MODE: " .. string.upper(tostring(mode)) else "personal hacks · not Architect patches"
			end
			if open then
				renderChips()
			end
			local t = nowT()
			local shieldUntil = player:GetAttribute(A.ShieldUntil)
			if typeof(shieldUntil) == "number" and shieldUntil > t then
				status.Visible = true
				statusText.Text = string.format("◈ SHIELD %.1fs", shieldUntil - t)
				statusText.TextColor3 = C.Green
				statusFill.BackgroundColor3 = C.Green
				statusFill.Size = UDim2.new(math.clamp((shieldUntil - t) / T.Shield.Seconds, 0, 1), 0, 1, 0)
			else
				status.Visible = false
			end
			if frozenUntil > t then
				frozenBanner.Visible = true
				frozenText.Text = string.format("❄ FROZEN %.1fs", frozenUntil - t)
			else
				frozenBanner.Visible = false
			end
			task.wait(0.1)
		end
	end)

	local dialAngle = 0
	RunService.RenderStepped:Connect(function(dt)
		if not (open or challenge) then
			return
		end
		local c = player.Character
		local dev = c and c:FindFirstChild("WristDevice")
		local dial = dev and dev:FindFirstChild("Dial")
		local weld = dial and dial:FindFirstChild("DialWeld")
		if weld and weld:IsA("Weld") then
			local base = weld:GetAttribute("BaseC0")
			if typeof(base) ~= "CFrame" then
				base = weld.C0
				weld:SetAttribute("BaseC0", base)
			end
			dialAngle += dt * (if challenge then 9 else 3)
			weld.C0 = (base :: CFrame) * CFrame.Angles(dialAngle, 0, 0)
		end
	end)

	player.CharacterAdded:Connect(function()
		endFling()
		frozenUntil = 0
	end)
end

return HackController

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
--             · T focus the command line · arrow keys = challenge directions (WASD keeps moving) ·
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
local CyberChip = require(script.Parent:WaitForChild("CyberChip"))
local HackVfx = require(script.Parent:WaitForChild("HackVfx"))

local C = UITheme.Color
local F = UITheme.Font
local A = HackCatalog.Attr
local T = HackCatalog.Tuning

local ARROW: { [string]: string } = { U = "▲", D = "▼", L = "◀", R = "▶" }
local KEY_DIR: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Up] = "U", [Enum.KeyCode.Down] = "D", [Enum.KeyCode.Left] = "L", [Enum.KeyCode.Right] = "R",
	[Enum.KeyCode.DPadUp] = "U", [Enum.KeyCode.DPadDown] = "D", [Enum.KeyCode.DPadLeft] = "L", [Enum.KeyCode.DPadRight] = "R",
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
	local arrowRow = UIUtil.create("Frame", { Name = "Arrows", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 2 }, chal)
	UIUtil.list(arrowRow, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center)
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
	local challenge: { token: number, hackId: string, snap: { [string]: any }, recv: number }? = nil
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
	local arrowLabels: { TextLabel } = {}
	local signalLabels: { TextLabel } = {}
	local padButtons: { TextButton } = {}

	local function sendDir(dir: string)
		if not challenge then
			return
		end
		request:FireServer({ op = "input", token = challenge.token, dir = dir, t = nowT() })
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

	for _, d in { "L", "U", "D", "R" } do
		local b = UIUtil.create("TextButton", { Name = "Pad" .. d, Size = UDim2.fromOffset(56, 52), BackgroundColor3 = C.Surface2, Text = ARROW[d], TextSize = 24, Font = F.Title, TextColor3 = C.Cyan, AutoButtonColor = false, Selectable = false }, pad) :: TextButton
		b:SetAttribute("Dir", d)
		UIUtil.corner(b, 8)
		UIUtil.stroke(b, C.Cyan, 1, 0.3)
		b.Activated:Connect(function()
			sendDir(d)
		end)
		table.insert(padButtons, b)
	end

	local KIND_TITLE: { [string]: string } = {
		Sequence = "ENTER THE SEQUENCE",
		ResistanceBattle = "RESISTANCE BATTLE — fill the bar faster than the Conductor drains it",
		InputChase = "INPUT CHASE — keep up as the Conductor writes arrows; clear them all",
		SignalLock = "SIGNAL LOCK — press each arrow as it crosses the lock zone",
	}

	local function renderArrows(seq: { string }, index: number, chase: boolean)
		for _, l in arrowLabels do
			l:Destroy()
		end
		table.clear(arrowLabels)
		for i, d in seq do
			if i > 9 then
				break
			end
			local done = (not chase) and i < index
			local current = if chase then i == 1 else i == index
			local l = UIUtil.create("TextLabel", {
				Name = "A" .. i,
				LayoutOrder = i,
				Size = UDim2.fromOffset(if current then 40 else 32, if current then 40 else 32),
				BackgroundColor3 = if current then C.Surface2 else C.Charcoal,
				Text = ARROW[d] or "?",
				TextSize = if current then 30 else 22,
				Font = F.Title,
				TextColor3 = if done then C.Green elseif current then C.Cyan else C.Muted,
				TextTransparency = if done then 0.4 else 0,
			}, arrowRow) :: TextLabel
			UIUtil.corner(l, 5)
			UIUtil.stroke(l, if current then C.Cyan elseif done then C.Green else C.Steel, if current then 2 else 1)
			table.insert(arrowLabels, l)
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
				local l = UIUtil.create("TextLabel", {
					Name = "S" .. i,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(30, 30),
					BackgroundColor3 = C.Surface2,
					Text = ARROW[sig.d] or "?",
					TextSize = 18,
					Font = F.Title,
					TextColor3 = if sig.state == "locked" then C.Green elseif sig.state == "missed" then C.Coral else C.Cyan,
				}, track) :: TextLabel
				UIUtil.corner(l, 5)
				l:SetAttribute("T", sig.t)
				l:SetAttribute("State", sig.state)
				table.insert(signalLabels, l)
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
			ContextActionService:BindActionAtPriority(DIR_ACTION, dirAction, false, Enum.ContextActionPriority.High.Value + 20,
				Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
				Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight)
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
	end
	local function flingSelf(v: Vector3, steer: number, minAir: number, maxT: number, blockedFrac: number)
		endFling()
		local c = player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then
			return
		end
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
			local plane = base + Vector2.new(md.X, md.Z) * steer
			lv.PlaneVelocity = plane
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
			challenge = { token = data.token, hackId = data.hackId, snap = data.snap, recv = os.clock() }
			showChallenge(true)
			renderChallengeStatic()
		elseif op == "challenge_end" then
			if challenge and challenge.token == data.token then
				challenge = nil
			end
			showChallenge(false)
			pending = nil
			renderChips()
		elseif op == "fling_self" then
			if typeof(data.v) == "Vector3" then
				flingSelf(data.v, tonumber(data.steer) or 0, tonumber(data.minAir) or 0.2, tonumber(data.maxT) or 2.5, tonumber(data.blocked) or 0.3)
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
			end
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

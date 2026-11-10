--!strict
-- ArchitectController (Phase 2): placeholder Architect panel, shown only to the current Architect.
-- Shows the offered patch cards, a keyword box (resolved locally to a card; never broadcast),
-- a turn timer, and a confirm step. Sends only { patchId = <id> }; the server decides everything.
--
-- Turn identity is MatchId + TurnNumber (turn numbers restart every match). When the identity
-- changes, selection, pending state, keyword text and feedback are cleared, and server responses
-- tagged with any other turn are ignored.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local PatchCatalog = require(shared:WaitForChild("PatchCatalog"))
local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local MatchStateClient = require(script.Parent:WaitForChild("MatchStateClient"))

local Palette = Config.Palette
local REFRESH_SECONDS = 0.1

local FEEDBACK: { [string]: string } = {
	accepted = "Patch submitted.",
	rate_limited = "Too many requests — wait a moment.",
	bad_payload = "Request rejected.",
	bad_patch_id = "Request rejected.",
	no_open_turn = "No Architect turn is open.",
	not_architect = "You are not the Architect.",
	stale_turn = "That turn has ended.",
	window_closed = "Time is up.",
	unknown_patch = "Unknown patch.",
	not_offered = "That patch is not on your cards.",
	architect_ineligible = "You can no longer act as Architect this turn.",
	capacity_full = "The simulation is at its patch limit — turn skipped.",
	match_not_live = "The match is not running.",
	duplicate = "That turn already submitted a patch.",
}

local ArchitectController = {}

function ArchitectController.Start(remotes: Instance)
	local player = Players.LocalPlayer
	local request = remotes:WaitForChild(Config.Remotes.RequestPatchSubmission) :: RemoteEvent
	local result = remotes:WaitForChild(Config.Remotes.SubmissionResult) :: RemoteEvent

	local gui = UIUtil.create("ScreenGui", {
		Name = "WORLD_EXE_Architect",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))

	local panel = UIUtil.panel("Panel", Palette.ElectricPurple, gui)
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -12, 0.5, 0)
	panel.Size = UDim2.new(0.3, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UIUtil.create("UISizeConstraint", { MinSize = Vector2.new(240, 0), MaxSize = Vector2.new(340, math.huge) }, panel)
	UIUtil.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, panel)

	local title = UIUtil.label("Title", "YOU ARE THE ARCHITECT", 18, Palette.ElectricPurple, panel)
	title.LayoutOrder = 1
	local subtitle = UIUtil.label("Subtitle", "Submit a patch to change the simulation", 13, Palette.CleanWhite, panel)
	subtitle.LayoutOrder = 2
	subtitle.Font = Enum.Font.Gotham
	local timer = UIUtil.label("Timer", "", 16, Palette.AmberWarning, panel)
	timer.LayoutOrder = 3

	local cards = UIUtil.create("Frame", {
		Name = "Cards",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
	}, panel)
	UIUtil.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, cards)

	local keywordRow = UIUtil.create("Frame", {
		Name = "KeywordRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 5,
	}, panel)
	local keywordBox = UIUtil.create("TextBox", {
		Name = "Keyword",
		PlaceholderText = "or type a keyword",
		Text = "",
		ClearTextOnFocus = false,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = Palette.CleanWhite,
		PlaceholderColor3 = Color3.fromRGB(150, 160, 190),
		BackgroundColor3 = Color3.fromRGB(24, 30, 52),
		Size = UDim2.new(0.68, 0, 1, 0),
	}, keywordRow) :: TextBox
	UIUtil.create("UICorner", { CornerRadius = UDim.new(0, 6) }, keywordBox)
	local findButton = UIUtil.create("TextButton", {
		Name = "Find",
		Text = "FIND",
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextColor3 = Palette.DeepNavy,
		BackgroundColor3 = Palette.NeonCyan,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.3, 0, 1, 0),
	}, keywordRow) :: TextButton
	UIUtil.create("UICorner", { CornerRadius = UDim.new(0, 6) }, findButton)

	local submit = UIUtil.create("TextButton", {
		Name = "Submit",
		Text = "SELECT A PATCH",
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = Palette.DeepNavy,
		BackgroundColor3 = Color3.fromRGB(90, 96, 120),
		AutoButtonColor = true,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 6,
	}, panel) :: TextButton
	UIUtil.create("UICorner", { CornerRadius = UDim.new(0, 6) }, submit)

	local feedback = UIUtil.label("Feedback", "", 13, Palette.CleanWhite, panel)
	feedback.LayoutOrder = 7
	feedback.Font = Enum.Font.Gotham

	local shownKey = "" -- MatchId:TurnNumber currently rendered
	local shownMatch: any = nil
	local selected: string? = nil
	local pending = false
	local cardButtons: { [string]: TextButton } = {}

	local function resetTurnState()
		selected = nil
		pending = false
		keywordBox.Text = ""
		feedback.Text = ""
	end

	local function renderSelection()
		for id, button in cardButtons do
			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = if id == selected then 3 else 1
				stroke.Color = if id == selected then Palette.AmberWarning else Palette.ElectricPurple
			end
		end
		local def = selected and PatchCatalog.Get(selected)
		submit.Text = if def then "SUBMIT " .. string.upper(def.DisplayName) else "SELECT A PATCH"
		submit.BackgroundColor3 = if def then Palette.AmberWarning else Color3.fromRGB(90, 96, 120)
	end

	local function buildCards(offered: { string })
		for _, child in cards:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		table.clear(cardButtons)
		for i, id in offered do
			local def = PatchCatalog.Get(id)
			if def then
				local button = UIUtil.create("TextButton", {
					Name = "Card_" .. id,
					Text = string.upper(def.DisplayName) .. "\n" .. def.Effect,
					TextSize = 13,
					Font = Enum.Font.GothamBold,
					TextWrapped = true,
					TextColor3 = Palette.CleanWhite,
					BackgroundColor3 = Color3.fromRGB(28, 22, 60),
					Size = UDim2.new(1, 0, 0, 48),
					LayoutOrder = i,
				}, cards) :: TextButton
				UIUtil.create("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
				UIUtil.create("UIStroke", { Color = Palette.ElectricPurple, Thickness = 1 }, button)
				button.Activated:Connect(function()
					selected = id
					feedback.Text = def.Warning
					renderSelection()
				end)
				cardButtons[id] = button
			end
		end
		renderSelection()
	end

	findButton.Activated:Connect(function()
		local id = PatchCatalog.Resolve(keywordBox.Text)
		if id and cardButtons[id] then
			selected = id
			feedback.Text = "Keyword matched a card — confirm to submit."
		else
			feedback.Text = "No offered patch matches that keyword."
		end
		renderSelection()
	end)

	submit.Activated:Connect(function()
		if selected == nil or pending then
			return
		end
		pending = true
		feedback.Text = "Submitting…"
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
		feedback.Text = FEEDBACK[tostring(data.reason)] or "Request rejected."
	end)

	task.spawn(function()
		while true do
			local snap = MatchStateClient.Get()
			local turn = snap.Turn
			local t = workspace:GetServerTimeNow()
			if snap.MatchId ~= shownMatch then
				-- New match: nothing from the previous match may carry over.
				shownMatch = snap.MatchId
				shownKey = ""
				resetTurnState()
				buildCards({})
			end
			local turnEndsAt = turn.TurnEndsAt
			local mine = turn.ArchitectUserId == player.UserId and typeof(turnEndsAt) == "number" and turnEndsAt > t
			local key = MatchStateClient.TurnKey(turn.TurnMatchId, turn.TurnNumber)
			if mine and key ~= shownKey then
				shownKey = key
				resetTurnState()
				buildCards(if typeof(turn.OfferedPatches) == "table" then turn.OfferedPatches else {})
			end
			gui:SetAttribute("TurnKey", shownKey)
			gui.Enabled = mine
			if mine then
				timer.Text = "Time left: " .. UIUtil.formatTime((turnEndsAt :: number) - t)
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return ArchitectController

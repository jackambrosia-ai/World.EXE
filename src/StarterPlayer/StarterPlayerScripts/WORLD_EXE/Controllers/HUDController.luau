--!strict
-- HUDController (Phase 2): placeholder match HUD — phase + timer, role, Architect turn status,
-- patch announcements, and match results. Reads the versioned server snapshot only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WORLD_EXE")
local Config = require(shared:WaitForChild("Shared"):WaitForChild("Config"))
local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local MatchStateClient = require(script.Parent:WaitForChild("MatchStateClient"))

local Palette = Config.Palette
local S = Config.MatchStates
local Roles = Config.Roles
local REFRESH_SECONDS = 0.2
local BANNER_SECONDS = 6

local STATE_TITLES: { [string]: string } = {
	[S.Lobby] = "LOBBY",
	[S.Countdown] = "MATCH STARTING",
	[S.Initializing] = "INITIALIZING SIMULATION",
	[S.Active] = "SIMULATION ACTIVE",
	[S.FinalPhase] = "FINAL PHASE",
	[S.Results] = "RESULTS",
	[S.Reset] = "RESETTING",
}

local HUDController = {}

local function roleText(role: string): string
	if role == Roles.Participant then
		return "You are in this match"
	elseif role == Roles.Spectator then
		return "Spectating — you will join the next match"
	end
	return "In lobby"
end

local function resultsText(data: any): string
	if typeof(data) ~= "table" then
		return ""
	end
	return string.format(
		"Match #%s %s (%s) · %ss · patches submitted: %s, skipped turns: %s",
		tostring(data.MatchId),
		tostring(data.Outcome),
		tostring(data.Reason),
		tostring(data.DurationSeconds),
		tostring(data.TurnsAccepted),
		tostring(data.TurnsSkipped)
	)
end

function HUDController.Start(remotes: Instance)
	local player = Players.LocalPlayer
	local gui = UIUtil.create("ScreenGui", {
		Name = "WORLD_EXE_HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	local status = UIUtil.panel("Status", Palette.NeonCyan, gui)
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 8)
	status.Size = UDim2.new(0.42, 0, 0, 0)
	status.AutomaticSize = Enum.AutomaticSize.Y
	UIUtil.create("UISizeConstraint", { MinSize = Vector2.new(260, 0), MaxSize = Vector2.new(520, math.huge) }, status)
	UIUtil.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, status)
	local title = UIUtil.label("StateLabel", "", 20, Palette.NeonCyan, status)
	title.LayoutOrder = 1
	local detail = UIUtil.label("DetailLabel", "", 14, Palette.CleanWhite, status)
	detail.LayoutOrder = 2
	detail.Font = Enum.Font.Gotham
	local architectLine = UIUtil.label("ArchitectLabel", "", 14, Palette.ElectricPurple, status)
	architectLine.LayoutOrder = 3
	local results = UIUtil.label("ResultsLabel", "", 14, Palette.ObjectiveGreen, status)
	results.LayoutOrder = 4
	results.Font = Enum.Font.Gotham

	local banner = UIUtil.panel("Announcement", Palette.AmberWarning, gui)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 120)
	banner.Size = UDim2.new(0.42, 0, 0, 0)
	banner.AutomaticSize = Enum.AutomaticSize.Y
	banner.Visible = false
	UIUtil.create("UISizeConstraint", { MinSize = Vector2.new(260, 0), MaxSize = Vector2.new(520, math.huge) }, banner)
	local bannerText = UIUtil.label("BannerText", "", 16, Palette.AmberWarning, banner)
	local bannerSerial = 0

	local function refresh()
		local snap = MatchStateClient.Get()
		local turn = snap.Turn
		local state = tostring(snap.State or S.Lobby)
		local t = workspace:GetServerTimeNow()
		local endsAt = snap.StateEndsAt
		local remaining = if typeof(endsAt) == "number" and endsAt > 0 then UIUtil.formatTime(endsAt - t) else nil
		title.Text = (STATE_TITLES[state] or state) .. (if remaining then "  ·  " .. remaining else "")

		local role = tostring(player:GetAttribute(Config.PlayerAttributes.Role) or Roles.Lobby)
		if state == S.Lobby or state == S.Countdown then
			local waiting = 0
			for _, other in Players:GetPlayers() do
				if other:GetAttribute(Config.PlayerAttributes.Role) == Roles.Lobby then
					waiting += 1
				end
			end
			detail.Text = string.format("%s · players ready %d / %s needed", roleText(role), waiting, tostring(snap.MinPlayers or "?"))
		else
			detail.Text = string.format("%s · participants %s", roleText(role), tostring(snap.ParticipantCount or 0))
		end

		local architectId = turn.ArchitectUserId
		local turnEndsAt = turn.TurnEndsAt
		local nextTurnAt = turn.NextTurnAt
		if typeof(architectId) == "number" and architectId ~= 0 and typeof(turnEndsAt) == "number" then
			architectLine.Text = string.format("Architect: %s · %s", tostring(turn.ArchitectName), UIUtil.formatTime(turnEndsAt - t))
		elseif state == S.Active and typeof(nextTurnAt) == "number" and nextTurnAt > 0 then
			architectLine.Text = "Next Architect turn in " .. UIUtil.formatTime(nextTurnAt - t)
		else
			architectLine.Text = ""
		end
		architectLine.Visible = architectLine.Text ~= ""

		results.Text = if state == S.Results or state == S.Reset then resultsText(snap.LastResult) else ""
		results.Visible = results.Text ~= ""
	end

	local announce = remotes:WaitForChild(Config.Remotes.PatchAnnouncement) :: RemoteEvent
	announce.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		if data.Outcome == "accepted" and typeof(data.DisplayName) == "string" then
			bannerText.Text = string.format("PATCH SUBMITTED: %s by %s\n%s\n(Patch effects arrive in a later phase.)", string.upper(data.DisplayName), tostring(data.ArchitectName), tostring(data.Warning))
		else
			bannerText.Text = string.format("Architect turn skipped (%s)", tostring(data.Outcome))
		end
		banner.Visible = true
		bannerSerial += 1
		local serial = bannerSerial
		task.delay(BANNER_SECONDS, function()
			if serial == bannerSerial then
				banner.Visible = false
			end
		end)
	end)

	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return HUDController

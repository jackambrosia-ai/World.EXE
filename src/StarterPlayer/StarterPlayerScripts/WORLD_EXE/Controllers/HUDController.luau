--!strict
-- HUDController (Phase 2): placeholder match HUD — phase + timer, role, Architect turn status,
-- patch announcements, running patches, shield status, stability, stabilizer objectives, own score
-- and fragments (Phase 5), and match results with team outcome and placements. Reads the
-- versioned server snapshot and server-set player attributes only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WORLD_EXE")
local Config = require(shared:WaitForChild("Shared"):WaitForChild("Config"))
local PatchCatalog = require(shared:WaitForChild("Shared"):WaitForChild("PatchCatalog"))
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

local ZONE_SHORT: { [string]: string } = { CentralCore = "CORE", Skybridge = "SKY", ResearchYard = "YARD" }

local function resultsText(data: any): string
	if typeof(data) ~= "table" then
		return ""
	end
	local lines = {
		string.format(
			"Match #%s %s (%s) · %ss · patches submitted: %s, skipped turns: %s",
			tostring(data.MatchId),
			tostring(data.Outcome),
			tostring(data.Reason),
			tostring(data.DurationSeconds),
			tostring(data.TurnsAccepted),
			tostring(data.TurnsSkipped)
		),
	}
	local team = data.Team
	if typeof(team) == "table" then
		local label = if team.Aborted then "MATCH ABORTED" elseif team.Success then "TEAM SUCCESS" else "TEAM FAILED"
		table.insert(lines, string.format("%s — %s", label, tostring(team.Reason)))
	end
	if typeof(data.Players) == "table" then
		for _, row in data.Players do
			if typeof(row) == "table" then
				local stats = string.format("fragments %s, repairs %s, assists %s", tostring(row.Fragments), tostring(row.Repairs), tostring(row.Assists))
				if row.Left then
					table.insert(lines, string.format("Left: %s — %s pts (%s)", tostring(row.Name), tostring(row.Score), stats))
				else
					local b = if typeof(row.RewardBreakdown) == "table" then row.RewardBreakdown else {}
					table.insert(lines, string.format(
						"%s. %s — %s pts + %s rewards (participation %s, team %s, placement %s) = %s · %s",
						if row.Placement == 0 then "-" else tostring(row.Placement), tostring(row.Name), tostring(row.Score), tostring(row.Rewards),
						tostring(b.Participation), tostring(b.Team), tostring(b.Placement), tostring(row.Total), stats
					))
				end
			end
		end
	end
	return table.concat(lines, "\n")
end

local function objectivesText(list: any): string
	if typeof(list) ~= "table" then
		return ""
	end
	local parts = {}
	for _, o in list do
		if typeof(o) == "table" then
			local name = ZONE_SHORT[tostring(o.Zone)] or tostring(o.Id)
			local status = if o.State == "REPAIRING" then `repairing {o.Progress}%`
				elseif o.State == "PAUSED" then `paused {o.Progress}%`
				elseif o.State == "COOLDOWN" then "repaired"
				else "needs repair"
			table.insert(parts, `{name} {status}`)
		end
	end
	return if #parts > 0 then "Stabilizers: " .. table.concat(parts, " · ") else ""
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
	local patchesLine = UIUtil.label("PatchesLabel", "", 14, Palette.AmberWarning, status)
	patchesLine.LayoutOrder = 4
	patchesLine.Font = Enum.Font.Gotham
	local stabilityLine = UIUtil.label("StabilityLabel", "", 14, Palette.NeonCyan, status)
	stabilityLine.LayoutOrder = 5
	local objectivesLine = UIUtil.label("ObjectivesLabel", "", 13, Palette.ObjectiveGreen, status)
	objectivesLine.LayoutOrder = 6
	objectivesLine.Font = Enum.Font.Gotham
	local personalLine = UIUtil.label("PersonalLabel", "", 14, Palette.CleanWhite, status)
	personalLine.LayoutOrder = 7
	local results = UIUtil.label("ResultsLabel", "", 14, Palette.ObjectiveGreen, status)
	results.LayoutOrder = 8
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
		-- SUPPLY_DROP shield (Phase 4): server-set expiry; display only.
		local shieldUntil = player:GetAttribute(Config.PlayerAttributes.Shield)
		if typeof(shieldUntil) == "number" and shieldUntil > t then
			detail.Text ..= " · SHIELD " .. UIUtil.formatTime(shieldUntil - t)
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

		-- Running patches (Phase 3): name, phase and time left, plus slots used.
		local parts = {}
		if typeof(snap.Patches) == "table" then
			for _, patch in snap.Patches do
				if typeof(patch) == "table" then
					local def = PatchCatalog.Get(tostring(patch.PatchId))
					local name = if def then string.upper(def.DisplayName) else tostring(patch.PatchId)
					if patch.State == "WARNING" and typeof(patch.WarningEndsAt) == "number" then
						table.insert(parts, `{name} incoming {UIUtil.formatTime(patch.WarningEndsAt - t)}`)
					elseif patch.State == "ACTIVE" and typeof(patch.ExpiresAt) == "number" then
						table.insert(parts, `{name} {UIUtil.formatTime(patch.ExpiresAt - t)}`)
					end
				end
			end
		end
		patchesLine.Text = if #parts > 0 then `Patches ({#parts}/{tostring(snap.PatchCapacity or "?")}): {table.concat(parts, " · ")}` else ""
		patchesLine.Visible = patchesLine.Text ~= ""

		-- Phase 5: stability, stabilizers, own score and carried fragments (display only).
		local inMatch = state == S.Active or state == S.FinalPhase
		local stability = snap.Stability
		if inMatch and typeof(stability) == "number" then
			local max = if typeof(snap.StabilityMax) == "number" and snap.StabilityMax > 0 then snap.StabilityMax else 100
			local filled = math.clamp(math.floor(stability / max * 10 + 0.5), 0, 10)
			stabilityLine.Text = string.format("STABILITY %d/%d  %s%s", stability, max, string.rep("■", filled), string.rep("□", 10 - filled))
			stabilityLine.TextColor3 = if stability >= Config.Stability.SuccessTarget then Palette.NeonCyan else Palette.AmberWarning
		else
			stabilityLine.Text = ""
		end
		stabilityLine.Visible = stabilityLine.Text ~= ""
		objectivesLine.Text = if inMatch then objectivesText(snap.Objectives) else ""
		objectivesLine.Visible = objectivesLine.Text ~= ""
		local myScore = player:GetAttribute(Config.PlayerAttributes.Score)
		local myFragments = player:GetAttribute(Config.PlayerAttributes.Fragments)
		personalLine.Text = if inMatch and typeof(myScore) == "number" then string.format("Score %d · Fragments %d", myScore, if typeof(myFragments) == "number" then myFragments else 0) else ""
		personalLine.Visible = personalLine.Text ~= ""

		results.Text = if state == S.Results or state == S.Reset then resultsText(snap.LastResult) else ""
		results.Visible = results.Text ~= ""
	end

	local announce = remotes:WaitForChild(Config.Remotes.PatchAnnouncement) :: RemoteEvent
	announce.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		if data.Outcome == "accepted" and typeof(data.DisplayName) == "string" then
			bannerText.Text = string.format("PATCH SUBMITTED: %s by %s\n%s", string.upper(data.DisplayName), tostring(data.ArchitectName), tostring(data.Warning))
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

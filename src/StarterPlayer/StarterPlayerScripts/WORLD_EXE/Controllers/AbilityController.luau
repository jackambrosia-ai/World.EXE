--!strict
-- AbilityController (Phase 6): ability input, the ability bar, rejection toasts and SCANNER
-- highlights. Presentation only: it sends { abilityId } and shows what the server decides.
-- * Input: keyboard Q / F / R, gamepad ButtonX / ButtonY / DPadUp, touch buttons
--   (ContextActionService). E stays free for ProximityPrompts.
-- * Bar: one slot per ability — READY, ACTIVE (time left) or cooldown countdown — from server-set
--   player attributes. Shown only to Participants while the match is ACTIVE or FINAL_PHASE.
-- * SCANNER: highlights are client-only and temporary. Feedback carries a per-player sequence
--   number: older, duplicate or already-expired results are ignored, a "cancelled" message clears
--   the matching scan, and highlights are also removed on expiry, character removal and match end.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local AbilityCatalog = require(shared:WaitForChild("AbilityCatalog"))
local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local MatchStateClient = require(script.Parent:WaitForChild("MatchStateClient"))

local Palette = Config.Palette
local S = Config.MatchStates
local REFRESH_SECONDS = 0.1
local TOAST_SECONDS = 2
local MAX_HIGHLIGHTS = 20
local KIND_COLORS: { [string]: Color3 } = {
	fragment = Palette.NeonCyan,
	bounce = Palette.ElectricPurple,
	slip = Color3.fromRGB(175, 230, 255),
	crate = Palette.ObjectiveGreen,
	drone = Color3.fromRGB(255, 70, 70),
	decay = Palette.AmberWarning,
}
local REASON_TEXT: { [string]: string } = {
	cooldown = "On cooldown",
	rate_limited = "Too fast",
	blocked = "Path blocked",
	start_blocked = "Path blocked",
	no_ground = "No ground there",
}

local AbilityController = {}

function AbilityController.Start(remotes: Instance)
	local player = Players.LocalPlayer
	local request = remotes:WaitForChild(Config.Remotes.RequestAbility) :: RemoteEvent
	local feedback = remotes:WaitForChild(Config.Remotes.AbilityFeedback) :: RemoteEvent

	local gui = UIUtil.create("ScreenGui", {
		Name = "WORLD_EXE_Abilities",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	local bar = UIUtil.create("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, gui)
	UIUtil.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, bar)
	local toast = UIUtil.label("Toast", "", 14, Palette.AmberWarning, gui)
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -78)
	toast.Size = UDim2.new(0, 300, 0, 20)
	toast.Visible = false
	local toastSerial = 0

	local slots: { [string]: TextLabel } = {}
	for _, id in AbilityCatalog.Ids() do
		local def = AbilityCatalog.Get(id) :: AbilityCatalog.AbilityDefinition
		local slot = UIUtil.panel(`Slot_{id}`, Palette.NeonCyan, bar)
		slot.Size = UDim2.new(0, 132, 0, 0)
		slot.AutomaticSize = Enum.AutomaticSize.Y
		slot.LayoutOrder = def.Order
		local label = UIUtil.label("Text", "", 13, Palette.CleanWhite, slot)
		slots[id] = label
	end

	local function showToast(text: string)
		toast.Text = text
		toast.Visible = true
		toastSerial += 1
		local serial = toastSerial
		task.delay(TOAST_SECONDS, function()
			if serial == toastSerial then
				toast.Visible = false
			end
		end)
	end

	local function usable(): boolean
		local state = MatchStateClient.Get().State
		return (state == S.Active or state == S.FinalPhase)
			and player:GetAttribute(Config.PlayerAttributes.Role) == Config.Roles.Participant
	end

	for _, id in AbilityCatalog.Ids() do
		local def = AbilityCatalog.Get(id) :: AbilityCatalog.AbilityDefinition
		local action = `WORLD_EXE_{id}`
		ContextActionService:BindAction(action, function(_, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.Begin and usable() then
				request:FireServer({ abilityId = id })
			end
			return Enum.ContextActionResult.Pass
		end, true, def.Key, def.GamepadKey)
		ContextActionService:SetTitle(action, def.DisplayName)
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
		while true do
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
					local label = slots[id]
					local status, color
					if typeof(activeUntil) == "number" and activeUntil > t then
						status, color = `ACTIVE {math.ceil(activeUntil - t)}`, Palette.AmberWarning
					elseif typeof(readyAt) == "number" and readyAt > t then
						status, color = `{math.ceil(readyAt - t)}s`, Color3.fromRGB(150, 160, 190)
					else
						status, color = "READY", Palette.NeonCyan
					end
					label.Text = `[{def.Key.Name}] {def.DisplayName}\n{status}`
					label.TextColor3 = color
				end
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return AbilityController

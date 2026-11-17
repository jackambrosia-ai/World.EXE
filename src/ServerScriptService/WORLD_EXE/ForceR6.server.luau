--!strict
-- ForceR6 — owner 2026-11-16: "make the game force R6 for everyone".
-- Puts an R6 rig in StarterPlayer as "StarterCharacter", so every spawn (the engine's auto-load and
-- PlayerStateService's LoadCharacter) produces an R6 character. With StarterPlayer.LoadCharacterAppearance
-- on, the engine still applies each player's own clothing, body colours, face and accessories to it.
-- If the place already has a StarterCharacter (a deliberate custom rig), it is left alone.
-- Publishing note: also set Game Settings > Avatar > Avatar Type = R6 on the published experience.
-- KNOWN ISSUE (deferred by the owner, 2026-11-17; NOT resolved): Config.ForceR6 and this script are not gated
-- to the wrist-hacking prototype (Workspace.WORLD_EXE_HackPrototype). If this src/ tree is synced into a
-- production place, R6 would be forced there too. Gate or remove it BEFORE any production integration.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))

if Config.ForceR6 ~= true then
	return
end

local function ensureRig(): boolean
	local existing = StarterPlayer:FindFirstChild("StarterCharacter")
	if existing then
		local hum = existing:FindFirstChildOfClass("Humanoid")
		return hum ~= nil and hum.RigType == Enum.HumanoidRigType.R6
	end
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if not ok or not rig then
		warn("[WORLD_EXE] ForceR6: could not build the R6 rig: " .. tostring(rig))
		return false
	end
	local model = rig :: Model
	model.Name = "StarterCharacter"
	model.Parent = StarterPlayer
	return true
end

local ready = ensureRig()
workspace:SetAttribute("WORLD_EXE_ForceR6", ready)

-- The engine does not dress a StarterCharacter (tested 2026-11-16: R6 body, no accessories or clothes),
-- so apply each player's own avatar description to the R6 body. Cached per player; failures are
-- harmless (the plain R6 body stays).
local descs: { [Player]: HumanoidDescription } = {}
local function dress(player: Player, character: Model)
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum or hum.RigType ~= Enum.HumanoidRigType.R6 then
		return
	end
	local desc = descs[player]
	if not desc then
		local ok, d = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(math.max(1, player.UserId))
		end)
		if not ok or not d then
			return
		end
		desc = d :: HumanoidDescription
		descs[player] = desc
	end
	if character.Parent == nil then
		character.AncestryChanged:Wait()
	end
	pcall(function()
		hum:ApplyDescription(desc :: HumanoidDescription)
	end)
	character:SetAttribute("WORLD_EXE_Dressed", true)
end
local function hook(player: Player)
	player.CharacterAdded:Connect(function(c)
		task.spawn(dress, player, c)
	end)
	if player.Character then
		task.spawn(dress, player, player.Character)
	end
end
Players.PlayerAdded:Connect(hook)
Players.PlayerRemoving:Connect(function(p)
	descs[p] = nil
end)
for _, p in Players:GetPlayers() do
	hook(p)
end

-- Anyone who spawned before the rig existed (very early joins) is reloaded once as R6.
local function check(player: Player)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if ready and hum and hum.RigType ~= Enum.HumanoidRigType.R6 then
		task.defer(function()
			if player.Parent == Players then
				player:LoadCharacter()
			end
		end)
	end
end
for _, p in Players:GetPlayers() do
	check(p)
end

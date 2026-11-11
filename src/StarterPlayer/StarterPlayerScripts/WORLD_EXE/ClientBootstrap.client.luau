--!strict
-- WORLD.EXE client entry point. Presentation only; the server is authoritative.
-- With StreamingEnabled, map parts may arrive later; client code must not assume they exist.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("WORLD_EXE", 30)
local shared = sharedRoot and sharedRoot:WaitForChild("Shared", 30)
local configModule = shared and shared:WaitForChild("Config", 30)
if not sharedRoot or not configModule or not configModule:IsA("ModuleScript") then
	warn("[WORLD_EXE] Client: shared Config not found")
	return
end
local Config = require(configModule)

-- Workspace.WORLD_EXE is a Folder, so it replicates even with streaming enabled.
local root = workspace:WaitForChild(Config.RootName, 30)
local stateFolder = sharedRoot:WaitForChild(Config.MatchStateFolder, 30)
local remotes = sharedRoot:WaitForChild("Remotes", 30)
if not root or not stateFolder or not remotes then
	warn("[WORLD_EXE] Client: server state not found")
	return
end

local controllers = script.Parent:WaitForChild("Controllers")
local MatchStateClient = require(controllers:WaitForChild("MatchStateClient"))
local HUDController = require(controllers:WaitForChild("HUDController"))
local ArchitectController = require(controllers:WaitForChild("ArchitectController"))
local AbilityController = require(controllers:WaitForChild("AbilityController"))
local EnvironmentResponseClient = require(controllers:WaitForChild("EnvironmentResponseClient"))
MatchStateClient.Start(stateFolder)
EnvironmentResponseClient.Start(MatchStateClient)
HUDController.Start(remotes)
ArchitectController.Start(remotes)
AbilityController.Start(remotes)

print(`[WORLD_EXE] Client ready v{Config.Version} ({Players.LocalPlayer.Name}); server status={tostring(root:GetAttribute("BootstrapStatus"))}`)

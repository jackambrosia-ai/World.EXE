--!strict
-- WORLD.EXE client entry point (Phase 1). Presentation only; the server is authoritative.
-- With StreamingEnabled, map parts may arrive later; client code must not assume they exist.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("WORLD_EXE", 30)
local shared = sharedRoot and sharedRoot:WaitForChild("Shared", 30)
local configModule = shared and shared:WaitForChild("Config", 30)
if not configModule or not configModule:IsA("ModuleScript") then
	warn("[WORLD_EXE] Client: shared Config not found")
	return
end
local Config = require(configModule)

-- Workspace.WORLD_EXE is a Folder, so it replicates even with streaming enabled.
local root = workspace:WaitForChild(Config.RootName, 30)
if not root then
	warn("[WORLD_EXE] Client: Workspace.WORLD_EXE not found")
	return
end

local function report()
	print(`[WORLD_EXE] Client ready v{Config.Version} ({Players.LocalPlayer.Name}); server status={tostring(root:GetAttribute("BootstrapStatus"))}`)
end

report()
root:GetAttributeChangedSignal("BootstrapStatus"):Connect(report)

--!strict
-- Wrist-hacking prototype client entry. INERT unless Workspace attribute WORLD_EXE_HackPrototype
-- is true. Runs beside ClientBootstrap; the existing HUD / Architect / ability controllers are
-- unchanged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared")
local HackCatalog = require(shared:WaitForChild("HackCatalog"))

if workspace:GetAttribute(HackCatalog.PrototypeAttribute) ~= true then
	return
end
local controllers = script.Parent:WaitForChild("Controllers")
require(controllers:WaitForChild("HackController")).Start()
print("[WORLD_EXE] Wrist-hacking prototype client started")

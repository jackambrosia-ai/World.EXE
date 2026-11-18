--!strict
-- Wrist-hacking prototype server entry. INERT unless the place opts in with
-- Workspace attribute WORLD_EXE_HackPrototype = true (only the isolated prototype place does).
-- Independent of the WORLD.EXE match bootstrap: personal hacks never depend on Architect turns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HackCatalog = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("HackCatalog"))

if workspace:GetAttribute(HackCatalog.PrototypeAttribute) ~= true then
	return
end
require(script.Parent:WaitForChild("HackService")).Start()
print("[WORLD_EXE] Wrist-hacking prototype server started")

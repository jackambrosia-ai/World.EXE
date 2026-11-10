--!strict
-- WORLD.EXE server entry point (Phase 1).
-- Initializes services in explicit order. Phase 1 only validates the arena and prepares runtime folders.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local ArenaService = require(ServerScriptService:WaitForChild("WORLD_EXE"):WaitForChild("Services"):WaitForChild("ArenaService"))

local root = workspace:WaitForChild(Config.RootName)
root:SetAttribute("BootstrapStatus", "Starting")

local ok, result = pcall(ArenaService.Init)
if not ok then
	root:SetAttribute("BootstrapStatus", "Failed")
	error(`[WORLD_EXE] Bootstrap failed: {result}`)
end

local report: ArenaService.ValidationReport = result
local summary = {}
for key, n in report.counts do
	table.insert(summary, `{key}={n}`)
end
table.sort(summary)

root:SetAttribute("ArenaValidationErrors", #report.errors)
if report.ok then
	root:SetAttribute("BootstrapStatus", "Ready")
	print(`[WORLD_EXE] Bootstrap ready v{Config.Version}: {table.concat(summary, ", ")}`)
else
	root:SetAttribute("BootstrapStatus", "Degraded")
	for _, message in report.errors do
		warn(`[WORLD_EXE] Arena validation: {message}`)
	end
end

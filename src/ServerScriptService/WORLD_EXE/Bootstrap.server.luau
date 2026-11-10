--!strict
-- WORLD.EXE server entry point.
-- Initializes services in explicit order:
-- Arena -> Net -> PlayerState -> WorldModifier -> Match (which initializes Patch and Architect).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local serverRoot = ServerScriptService:WaitForChild("WORLD_EXE")
local services = serverRoot:WaitForChild("Services")
local ArenaService = require(services:WaitForChild("ArenaService"))
local NetService = require(services:WaitForChild("NetService"))
local PlayerStateService = require(services:WaitForChild("PlayerStateService"))
local WorldModifierService = require(services:WaitForChild("WorldModifierService"))
local MatchService = require(services:WaitForChild("MatchService"))

local root = workspace:WaitForChild(Config.RootName)
root:SetAttribute("BootstrapStatus", "Starting")

local function fail(message: string)
	root:SetAttribute("BootstrapStatus", "Failed")
	error(`[WORLD_EXE] Bootstrap failed: {message}`)
end

local ok, result = pcall(ArenaService.Init)
if not ok then
	fail(tostring(result))
end
local report: ArenaService.ValidationReport = result
local errors = table.clone(report.errors)

local netOk, netErr = pcall(NetService.Init)
if not netOk then
	fail(`NetService: {netErr}`)
end

for _, problem in PlayerStateService.Init() do
	table.insert(errors, problem)
end

-- Capture shared-world baselines before any patch can run.
WorldModifierService.Init()

local matchOk, matchErr = pcall(MatchService.Init, serverRoot)
if not matchOk then
	fail(`MatchService: {matchErr}`)
end

PlayerStateService.Start()
MatchService.Start()
game:BindToClose(MatchService.Shutdown)

local summary = {}
for key, n in report.counts do
	table.insert(summary, `{key}={n}`)
end
table.sort(summary)

root:SetAttribute("ArenaValidationErrors", #errors)
if #errors == 0 then
	root:SetAttribute("BootstrapStatus", "Ready")
	print(`[WORLD_EXE] Bootstrap ready v{Config.Version}: {table.concat(summary, ", ")}`)
else
	root:SetAttribute("BootstrapStatus", "Degraded")
	for _, message in errors do
		warn(`[WORLD_EXE] Validation: {message}`)
	end
end

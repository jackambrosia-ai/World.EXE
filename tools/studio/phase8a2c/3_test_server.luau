-- WORLD.EXE Phase 8A-2c test harness (SERVER side, solo Play only; never saved).
-- The Studio MCP runner creates a Script "ZZ_EnvFXTest8A2C" in ServerScriptService with this Source
-- right after starting Play (MCP code gets its own module instances, so an injected Script is needed
-- to drive the live PatchService). It executes one command at a time, written by the runner to its
-- "Cmd" attribute, and publishes the result in "Out" plus a live "Info" line:
--   req <PATCH_ID> <scale>    PatchService.Request on the live match (scale multiplies warning/active)
--   cancel <runtimeId>        PatchService.Cancel
--   cancelall                 PatchService.CancelAll("envfx-test")
--   validate                  ArenaService.Validate() and CompareToBaseline()
-- Nothing here changes server code or gameplay rules; patches run exactly as in a real match.
local ServerScriptService = game:GetService("ServerScriptService")
local root = ServerScriptService:WaitForChild("WORLD_EXE")
local svc = root:WaitForChild("Services")
local MatchService = require(svc:WaitForChild("MatchService"))
local PatchService = require(svc:WaitForChild("PatchService"))
local PIS = require(svc:WaitForChild("PatchInteractionService"))
local ArenaService = require(svc:WaitForChild("ArenaService"))

local me = script
me:SetAttribute("Cmd", "")
me:SetAttribute("Out", "ready")
local n = 0
while me.Parent do
	local cmd = me:GetAttribute("Cmd")
	if typeof(cmd) == "string" and cmd ~= "" then
		me:SetAttribute("Cmd", "")
		n += 1
		local words = string.split(cmd, " ")
		local out
		local ok, err = pcall(function()
			if words[1] == "req" then
				local okReq, rid = PatchService.Request(words[2], 0, MatchService.GetMatchId(), tonumber(words[3]) or 1)
				out = string.format("req %s -> %s %s", words[2], tostring(okReq), tostring(rid))
			elseif words[1] == "cancel" then
				out = "cancel " .. tostring(PatchService.Cancel(words[2], "envfx-test"))
			elseif words[1] == "cancelall" then
				out = "cancelall " .. tostring(PatchService.CancelAll("envfx-test"))
			elseif words[1] == "validate" then
				local v = ArenaService.Validate()
				local c = ArenaService.CompareToBaseline()
				out = string.format("validate ok=%s errors=%d baseline=%s differences=%d", tostring(v.ok), #v.errors, tostring(c.matches), c.total)
			else
				out = "unknown " .. cmd
			end
		end)
		me:SetAttribute("Out", string.format("#%d %s", n, if ok then out else ("ERROR " .. tostring(err))))
	end
	local list = {}
	for _, p in PatchService.GetSnapshot() do
		table.insert(list, p.PatchId .. ":" .. p.State .. ":" .. p.RuntimeId)
	end
	local combos = {}
	for _, c in PIS.GetSnapshot() do
		table.insert(combos, c.Id)
	end
	me:SetAttribute("Info", string.format("%s match %d | %s | %s", MatchService.GetState(), MatchService.GetMatchId(), table.concat(list, ","), table.concat(combos, ",")))
	task.wait(0.1)
end

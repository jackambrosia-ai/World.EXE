--!nonstrict
-- Core Round Step 1: copy src/**/CoreRound/**/*.luau from the local repo (cr_serve.js on 127.0.0.1:8791)
-- into the open CORE ROUND test place (Edit mode, command bar or Studio MCP). Refuses any other place.
-- Mapping: src/<Service>/<path>/<Name>[.server|.client].luau -> game.<Service>.<path>.<Name>
--   .server.luau = Script, .client.luau = LocalScript, otherwise ModuleScript; folders are Folders.
-- Existing scripts are updated in place; scripts inside a CoreRound folder that are no longer in the repo are
-- removed. Returns a JSON summary with byte counts.
local HS = game:GetService("HttpService")
assert(string.find(game.Name, "CoreRound", 1, true), "core round test place only")
local BASE = "http://127.0.0.1:8791/"
local manifest = HS:JSONDecode(HS:GetAsync(BASE .. "manifest.json", true))
local summary = { files = 0, bytes = 0, created = 0, updated = 0, removed = 0, mismatched = {} }
local keep = {}
for _, entry in ipairs(manifest) do
	local parts = string.split(entry.path, "/")
	local service = game:GetService(parts[1])
	local parent = service
	for i = 2, #parts - 1 do
		local child = parent:FindFirstChild(parts[i])
		if not child then
			child = Instance.new("Folder")
			child.Name = parts[i]
			child.Parent = parent
		end
		parent = child
	end
	local file = parts[#parts]
	local name = file:gsub("%.server%.luau$", ""):gsub("%.client%.luau$", ""):gsub("%.luau$", "")
	local src = HS:GetAsync(BASE .. "src/" .. HS:UrlEncode(entry.path):gsub("%%2F", "/"), true)
	local inst = parent:FindFirstChild(name)
	if inst and inst.ClassName ~= entry.kind then
		inst:Destroy()
		inst = nil
	end
	if not inst then
		inst = Instance.new(entry.kind)
		inst.Name = name
		summary.created += 1
	else
		summary.updated += 1
	end
	inst.Source = src
	inst.Parent = parent
	keep[inst] = true
	if #inst.Source ~= entry.bytes then
		table.insert(summary.mismatched, entry.path .. " " .. #inst.Source .. "/" .. entry.bytes)
	end
	summary.files += 1
	summary.bytes += #src
end
-- remove stale scripts inside CoreRound folders
for _, svc in { "ReplicatedStorage", "ServerScriptService", "StarterPlayer" } do
	for _, d in game:GetService(svc):GetDescendants() do
		if d:IsA("LuaSourceContainer") and not keep[d] then
			local p = d.Parent
			local inCore = false
			while p do
				if p.Name == "CoreRound" then
					inCore = true
				end
				p = p.Parent
			end
			if inCore then
				d:Destroy()
				summary.removed += 1
			end
		end
	end
end
return HS:JSONEncode(summary)

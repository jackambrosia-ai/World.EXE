--!nonstrict
-- Wrist-hacking prototype: copy src/**/*.luau from the local repo (hp_serve.js on 127.0.0.1:8790)
-- into the open PROTOTYPE place (Edit mode, Studio command bar or MCP). Refuses any other place.
-- Mapping: src/<Service>/<path>/<Name>[.server|.client].luau -> game.<Service>.<path>.<Name>
--   .server.luau = Script, .client.luau = LocalScript, otherwise ModuleScript; folders are Folders.
-- Existing scripts at the same path are updated in place; returns a JSON summary with byte counts.
local HS = game:GetService("HttpService")
assert(string.find(game.Name, "HackPrototype", 1, true), "prototype place only")
local BASE = "http://127.0.0.1:8790/"
local manifest = HS:JSONDecode(HS:GetAsync(BASE .. "manifest.json", true))
local summary = { files = 0, bytes = 0, created = 0, updated = 0, mismatched = {} }
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
	if #inst.Source ~= entry.bytes then
		table.insert(summary.mismatched, entry.path .. " " .. #inst.Source .. "/" .. entry.bytes)
	end
	summary.files += 1
	summary.bytes += #src
end
return HS:JSONEncode(summary)

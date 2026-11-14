-- WORLD.EXE Map 1: READ-ONLY script inventory. Hashes every LuaSourceContainer source (FNV-1a 32 +
-- length) in the DataModel and posts scripts_<label>.json to the sink. Compare two runs with
-- 5_check_map1.luau (or by diffing the JSON). Usage: _G.MAP1_LABEL = "before"; run; read _G.MAP1_SCRIPTS.
local HS = game:GetService("HttpService")
local sink = _G.MAP1_SINK or "http://127.0.0.1:8775/sink/"
local label = _G.MAP1_LABEL or "run"

local function fnv(s: string): string
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		-- multiply by 16777619 = 2^24 + 403 (mod 2^32), exact in doubles
		h = (h * 403 + bit32.lshift(h, 24)) % 4294967296
	end
	return string.format("%08x", h)
end

local out = {}
local n = 0
for _, svc in { workspace, game.ReplicatedStorage, game.ServerScriptService, game.ServerStorage, game.StarterPlayer, game.StarterGui, game.ReplicatedFirst, game.StarterPack, game.Lighting } do
	for _, d in svc:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			local ok, src = pcall(function()
				return (d :: any).Source
			end)
			src = ok and src or ""
			out[d:GetFullName() .. "|" .. d.ClassName] = fnv(src) .. ":" .. #src
			n += 1
			if n % 10 == 0 then
				task.wait()
			end
		end
	end
end
local json = HS:JSONEncode({ label = label, count = n, scripts = out })
pcall(function()
	HS:PostAsync(sink .. "scripts_" .. label .. ".json", json)
end)
_G.MAP1_SCRIPTS = { label = label, count = n, scripts = out }
return n

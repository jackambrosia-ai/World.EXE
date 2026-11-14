-- WORLD.EXE Map 1 step 2: WORKING-COPY-ONLY edit of Config.ArenaBoundsMin/Max in the Studio session so
-- the expansion is playable (PlayerStateService out-of-arena containment and AbilityService Dash use
-- these bounds). src/ReplicatedStorage/WORLD_EXE/Shared/Config.luau in git is NOT changed; the proposed
-- source change is documented in notes/CHANGED_OBJECTS.md. OutOfBoundsY (-60) is not touched.
--   _G.MAP1_BOUNDS_MODE = "apply" (default) | "restore" | "status"
-- Replaces exactly the two lines below (refuses if the current text is neither the old nor the new form).
local OLD_MIN = "Config.ArenaBoundsMin = Vector3.new(-275, -40, -275)"
local OLD_MAX = "Config.ArenaBoundsMax = Vector3.new(275, 160, 275)"
local NEW_MIN = "Config.ArenaBoundsMin = Vector3.new(-845, -40, -715) -- MAP1 WORKING COPY (was -275, -40, -275)"
local NEW_MAX = "Config.ArenaBoundsMax = Vector3.new(705, 160, 275) -- MAP1 WORKING COPY (was 275, 160, 275)"
local mode = _G.MAP1_BOUNDS_MODE or "apply"
local cfg = game.ReplicatedStorage.WORLD_EXE.Shared.Config
local src = cfg.Source
local function count(s, pat)
	local _, n = string.gsub(s, pat, "")
	return n
end
local function esc(s)
	return (s:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"))
end
local hasOld = count(src, esc(OLD_MIN)) == 1 and count(src, esc(OLD_MAX)) == 1 and count(src, esc(NEW_MIN)) == 0
local hasNew = count(src, esc(NEW_MIN)) == 1 and count(src, esc(NEW_MAX)) == 1
if mode == "status" then
	return hasNew and "applied" or (hasOld and "original" or "UNKNOWN")
end
local target
if mode == "apply" then
	if hasNew then
		return "already applied"
	end
	assert(hasOld, "refusing: Config bounds text is not the expected original")
	target = src:gsub(esc(OLD_MIN), NEW_MIN, 1):gsub(esc(OLD_MAX), NEW_MAX, 1)
elseif mode == "restore" then
	if hasOld and not hasNew then
		return "already original"
	end
	assert(hasNew, "refusing: Config bounds text is not the expected working-copy form")
	target = src:gsub(esc(NEW_MIN), OLD_MIN, 1):gsub(esc(NEW_MAX), OLD_MAX, 1)
else
	error("unknown mode " .. tostring(mode))
end
local SES = game:GetService("ScriptEditorService")
local ok = pcall(function()
	SES:UpdateSourceAsync(cfg, function()
		return target
	end)
end)
if not ok then
	cfg.Source = target
end
assert(cfg.Source == target, "source update did not apply")
return mode .. " ok (" .. #src .. " -> " .. #target .. " chars)"

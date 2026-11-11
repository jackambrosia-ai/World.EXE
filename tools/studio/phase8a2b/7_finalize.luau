-- WORLD.EXE Phase 8A-2b step 7: finalize after a passing read-only audit (Studio EDIT mode).
-- Requires 6_audit to have run in this session with every gameplay check passing and no new strict
-- AC2 failure (_G.AUDIT8A2B_PASS == true). Sets Map.Phase8A2B. ArenaVersion stays 3 (no gameplay
-- geometry changed). On a failing audit, fix the builder or run _G.W8A2B.Restore / 9_restore.
local map = workspace:WaitForChild("WORLD_EXE"):WaitForChild("Map")
assert(_G.AUDIT8A2B_PASS == true, "6_audit has not passed in this session")
assert(map:GetAttribute("Phase8A2B") == nil, "already finalized")
map:SetAttribute("Phase8A2B", "2026-11-11")
return "Phase 8A-2b finalized (Map.Phase8A2B set)"

-- WORLD.EXE ENV_SPRINT2 traversal specification (Agent A, gameplay level design, 2026-11-13).
-- Data only: returns the SprintTraversal models for the coordinator's builder. Generated from
-- C:\WORLD.EXE-Art\EnvSprint2\agentA\design.js by gen_spec.js; checked by check.js (see DESIGN.md there).
-- Tuple: { name, size, position (absolute), {r,g,b}, material, role or nil, orientation or nil, extra or nil }
-- Roles: WalkSurface / EdgeRail (existing ENV_SLICE1 rules) and JumpStep (PROPOSED, needs Agent C's
--   matching audit rule: level unrotated collidable slab >= 4x4 in bounds, 6-stud headroom, part of a
--   chain whose links are gap <= 8 / rise <= 6.5 and whose ends reach existing floors). If no step role is
--   approved, Traversal_IslandClimb must be dropped; the other two models do not depend on it.
-- Collidable parts carry exactly one role; parts with role nil are decorative (CanCollide/CanQuery/
--   CanTouch/CastShadow false). No lights, no rotations, native Block parts only.
return {
	{ model = "Traversal_YardArchiveLink", category = "SprintTraversal", parts = { -- 12 parts, 7 collidable
		{ "YA_Walk_1", Vector3.new(29, 2, 10), Vector3.new(-130.5, 23, -123), {30,36,60}, "SmoothPlastic", "WalkSurface" },
		{ "YA_Walk_2", Vector3.new(8, 2, 18), Vector3.new(-120, 23, -137), {30,36,60}, "SmoothPlastic", "WalkSurface" },
		{ "YA_Rail_N1", Vector3.new(16, 4, 0.4), Vector3.new(-132, 26, -127.8), {84,96,130}, "Metal", "EdgeRail" },
		{ "YA_Rail_S1", Vector3.new(24, 4, 0.4), Vector3.new(-128, 26, -118.2), {84,96,130}, "Metal", "EdgeRail" },
		{ "YA_Rail_E1", Vector3.new(0.4, 4, 9.6), Vector3.new(-116.2, 26, -123.2), {84,96,130}, "Metal", "EdgeRail" },
		{ "YA_Rail_W2", Vector3.new(0.4, 4, 12), Vector3.new(-123.8, 26, -134), {84,96,130}, "Metal", "EdgeRail" },
		{ "YA_Rail_E2", Vector3.new(0.4, 4, 12), Vector3.new(-116.2, 26, -134), {84,96,130}, "Metal", "EdgeRail" },
		{ "YA_Guide_1", Vector3.new(24.85, 0.2, 0.3), Vector3.new(-132.575, 24.1, -123), {0,200,255}, "Neon" },
		{ "YA_Guide_2", Vector3.new(0.3, 0.2, 22.85), Vector3.new(-120, 24.1, -134.575), {0,200,255}, "Neon" },
		{ "YA_EdgeTrim_W2", Vector3.new(0.3, 0.2, 6), Vector3.new(-123.85, 24.1, -143), {0,200,255}, "Neon" },
		{ "YA_EdgeTrim_E2", Vector3.new(0.3, 0.2, 6), Vector3.new(-116.15, 24.1, -143), {0,200,255}, "Neon" },
		{ "YA_EdgeTrim_N1", Vector3.new(5, 0.2, 0.3), Vector3.new(-142.5, 24.1, -127.85), {0,200,255}, "Neon" },
	} },
	{ model = "Traversal_ArchiveSkyLink", category = "SprintTraversal", parts = { -- 12 parts, 6 collidable
		{ "AS_Walk_1", Vector3.new(8, 2, 16), Vector3.new(120, 23, -138), {30,36,60}, "SmoothPlastic", "WalkSurface" },
		{ "AS_Walk_2", Vector3.new(26, 2, 10), Vector3.new(137, 23, -135), {30,36,60}, "SmoothPlastic", "WalkSurface" },
		{ "AS_Rail_W1", Vector3.new(0.4, 4, 9.6), Vector3.new(116.2, 26, -135.2), {84,96,130}, "Metal", "EdgeRail" },
		{ "AS_Rail_S1", Vector3.new(8, 4, 0.4), Vector3.new(120, 26, -130.2), {84,96,130}, "Metal", "EdgeRail" },
		{ "AS_Rail_S2", Vector3.new(16, 4, 0.4), Vector3.new(132, 26, -130.2), {84,96,130}, "Metal", "EdgeRail" },
		{ "AS_Rail_N2", Vector3.new(18, 4, 0.4), Vector3.new(141, 26, -139.8), {84,96,130}, "Metal", "EdgeRail" },
		{ "AS_Guide_1", Vector3.new(0.3, 0.2, 10.85), Vector3.new(120, 24.1, -140.575), {0,200,255}, "Neon" },
		{ "AS_Guide_2", Vector3.new(29.85, 0.2, 0.3), Vector3.new(135.075, 24.1, -135), {0,200,255}, "Neon" },
		{ "AS_EdgeTrim_W1", Vector3.new(0.3, 0.2, 6), Vector3.new(116.15, 24.1, -143), {0,200,255}, "Neon" },
		{ "AS_EdgeTrim_E1", Vector3.new(0.3, 0.2, 6), Vector3.new(123.85, 24.1, -143), {0,200,255}, "Neon" },
		{ "AS_EdgeTrim_N2", Vector3.new(6, 0.2, 0.3), Vector3.new(127, 24.1, -139.85), {0,200,255}, "Neon" },
		{ "AS_EdgeTrim_S2", Vector3.new(10, 0.2, 0.3), Vector3.new(145, 24.1, -130.15), {0,200,255}, "Neon" },
	} },
	{ model = "Traversal_IslandClimb", category = "SprintTraversal", parts = { -- 21 parts, 9 collidable
		{ "IC_Step_1", Vector3.new(7, 2, 7), Vector3.new(156.5, 28, -114.5), {30,36,60}, "SmoothPlastic", "JumpStep" },
		{ "IC_Step_2", Vector3.new(7, 2, 7), Vector3.new(156.5, 33, -124.5), {30,36,60}, "SmoothPlastic", "JumpStep" },
		{ "IC_Step_3", Vector3.new(7, 2, 7), Vector3.new(156.5, 38, -135.5), {30,36,60}, "SmoothPlastic", "JumpStep" },
		{ "IC_Step_4", Vector3.new(7, 2, 7), Vector3.new(167.5, 43, -135.5), {30,36,60}, "SmoothPlastic", "JumpStep" },
		{ "IC_Step_5", Vector3.new(7, 2, 7), Vector3.new(167.5, 48, -124.5), {30,36,60}, "SmoothPlastic", "JumpStep" },
		{ "IC_Step_6", Vector3.new(7, 2, 7), Vector3.new(156.5, 53, -124.5), {30,36,60}, "SmoothPlastic", "JumpStep" },
		{ "IC_Step_7", Vector3.new(7, 2, 7), Vector3.new(156.5, 58, -135.5), {30,36,60}, "SmoothPlastic", "JumpStep" },
		{ "IC_Step_8", Vector3.new(7, 2, 7), Vector3.new(167.5, 63, -135.5), {30,36,60}, "SmoothPlastic", "JumpStep" },
		{ "IC_Step_9", Vector3.new(7, 2, 7), Vector3.new(167.5, 68, -124.5), {30,36,60}, "SmoothPlastic", "JumpStep" },
		{ "IC_Strip_1", Vector3.new(7, 0.2, 0.3), Vector3.new(156.5, 29.1, -117.85), {0,200,255}, "Neon" },
		{ "IC_Strip_2", Vector3.new(7, 0.2, 0.3), Vector3.new(156.5, 34.1, -127.85), {0,200,255}, "Neon" },
		{ "IC_Strip_3", Vector3.new(0.3, 0.2, 7), Vector3.new(159.85, 39.1, -135.5), {0,200,255}, "Neon" },
		{ "IC_Strip_4", Vector3.new(7, 0.2, 0.3), Vector3.new(167.5, 44.1, -132.15), {0,200,255}, "Neon" },
		{ "IC_Strip_5", Vector3.new(0.3, 0.2, 7), Vector3.new(164.15, 49.1, -124.5), {0,200,255}, "Neon" },
		{ "IC_Strip_6", Vector3.new(7, 0.2, 0.3), Vector3.new(156.5, 54.1, -127.85), {0,200,255}, "Neon" },
		{ "IC_Strip_7", Vector3.new(0.3, 0.2, 7), Vector3.new(159.85, 59.1, -135.5), {0,200,255}, "Neon" },
		{ "IC_Strip_8", Vector3.new(7, 0.2, 0.3), Vector3.new(167.5, 64.1, -132.15), {0,200,255}, "Neon" },
		{ "IC_Strip_9", Vector3.new(0.3, 0.2, 7), Vector3.new(170.85, 69.1, -124.5), {0,200,255}, "Neon" },
		{ "IC_Mast_Pylon", Vector3.new(2, 51.5, 2), Vector3.new(162, 55.25, -128), {58,68,100}, "Metal" },
		{ "IC_Mast_Strip", Vector3.new(0.4, 46, 0.4), Vector3.new(162, 56, -126.8), {0,200,255}, "Neon" },
		{ "IC_Mast_Cap", Vector3.new(4, 1, 4), Vector3.new(162, 81.5, -128), {198,204,216}, "Metal" },
	} },
}

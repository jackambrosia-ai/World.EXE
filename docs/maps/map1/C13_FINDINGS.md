# C13 (legacy audit) findings on Ring_E, Map 1 working copy

Agent A, iteration 2, 2026-11-14. Legacy audit: `tools/studio/phase8a2b/6_audit.luau` from the tools/env-sprint2 checkout (read-only, not edited).

## The two v7 failures
- `C13 rail blocks 10 drop-down sample(s): ...TransitRing.Structure.Rails.EdgeRail` = the **inner** Ring_E rail, X 223.0..223.4, Z -39..39, Y 24.0..25.2.
- `C13 rail blocks 11 drop-down sample(s): ...Map1Expansion.HallOpenings.EdgeRail_Cut39` = the **outer** Ring_E rail piece, X 236.6..237.0, Z -222.5..83, Y 24.0..25.2 (a v7 cut piece of the original outer EdgeRail).
- C13 rule: every 8A-2b EdgeRail must face the void; a collidable whose top is within 40 studs below the rail's floor, 1 stud outside the rail, counts as a blocked drop-down.

## Measured on the real geometry (Studio, Edit mode, raycasts straight down 1 stud outside each rail, every 4 studs from Z -40 to 40)
| Item | Value |
|---|---|
| Ring_E deck | X 223..237, top Y 24, 14 wide (`OuterRing.Ring_E`, 14 x 2 x 446) |
| Rail height | 1.2 studs (Y 24.0..25.2): a lip, not a 4-stud guard rail. Stock jump height 7.2 clears it anywhere on the ring |
| Below the rails, Z -28..-12 | `Map1Expansion.Route_E.RE_Ground_Floor` (X 200..510, Z -30..-10, top Y 0) on both sides; its own 4-high rails at Z -30..-29 and -11..-10 |
| Below the rails elsewhere (Z -40..-32 and -8..40) | nothing (void; out-of-bounds Y -60) |
| Fall height | 24.0 studs onto a 20-wide walkable corridor; the corridor passes under the deck with 22 studs clearance |
| Fall damage | none in `src/` (no fall-damage code); `Workspace.FallenPartsDestroyHeight` -500 |
| Reachability | the corridor is a normal route (SkyBase X 200 -> Foundry X 510); the walk graph already modelled the drop (its drop rule ignores 1.2-high rails) |

## Verdict
Not unsafe: the landing is a railed, reachable floor and the lip never stopped a jump. It **was** a real mismatch with the design rule behind C13 (edges over a walkable floor should be open drop-downs, not railed), and the rail protects nothing there, so the geometry was corrected rather than waived.

## Correction (v8, reversible)
- Two cut boxes in `gen_expansion.js` (`RE_RingDrop_Inner` X 222.9..223.5 and `RE_RingDrop_Outer` X 236.5..237.2, both Y 24.02..25.5, Z -30.5..-9.5) open both rails exactly over the corridor (the 0.5-stud margin keeps every C13 sample outside the corridor footprint). The originals move to `ServerStorage.Map1_Isolated.CutOriginals`; `9_remove_expansion.luau` restores them.
- Two violet floor strips (`RE_RingDrop_GlowW/E`, decor) mark the opening on the ring deck.
- Result: legacy audit C13 now passes (38 rails checked, 0 C13 errors). The drop is a 1-second Ring_E -> E ground shortcut (Play walk `E_RingDrop`).
- Evidence: `screenshots/BEFORE_v7_10_C13_RingE_over_corridor.jpg`, `BEFORE_v7_11_C13_RingE_top.jpg`, `AFTER_v9_10_C13_RingE_drop.jpg`; raw audit `raw/old_audit_v7_recheck.json` and `raw/old_audit_after_v9_final.json`.

## Proposed map-specific rule note (proposal only; the audit was not edited)
The legacy C13 only inspects 8A-2b / slice / sprint rails. It never inspects Map 1 expansion rails, and several of those are **intentionally** stacked over a lower route (the W elevated bridge sits 24 studs directly above the W ground corridor, Z 26..38 over Z 23..41). If C13 is extended to Map 1, propose: "a 4-high rail over a lower walkable floor is allowed when both floors belong to the same documented stacked route pair and a drop-down or ramp between the two levels exists within 120 studs (v8: W-Line Junction ramp)". Until then, Map 1's own `5_check_map1` K5 covers expansion edges (every walk-surface edge with a drop over 8 studs must be guarded).

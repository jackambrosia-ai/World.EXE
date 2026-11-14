# Map 1 per-map budget proposal (for owner approval; NOT applied, NOT approved)

Agent A, iteration 2, 2026-11-14. Nothing in `src/`, in the legacy audit or in any approved cap was changed.
The independent engineer's 750-collidable figure is a proposal only and is **not** treated as approved here.

## Measured (Studio working copy, map1-expansion v9)
| Scope | Parts | Collidable | Lights |
|---|---|---|---|
| Whole `Workspace.WORLD_EXE.Map` (v7) | 2,843 | 814 | 73 |
| Whole `Workspace.WORLD_EXE.Map` (v9) | 2,931 | 765 | 76 |
| Expansion v9 (959 spec + 41 cut pieces) | 1,000 | 367 | 25 |
| Hub (everything else) v9 | 1,931 | 398 | 51 |

Expansion by sector, v7 -> v8 (parts / collidable / lights):
ContainmentVault 125/58/7 -> 153/65/7; Route_N 58/17/1 -> 93/32/2; TestingPit 309/184/4 -> 180/85/4;
Route_W 53/29/2 -> 107/38/3; Foundry 133/96/6 -> 152/100/6; Route_E 73/23/2 -> 104/39/3; Backdrop 120/0/0 (same);
HallOpenings 40/8/0 -> 41/8/0. (v9 adds 14 decor jamb strips and 36 invisible non-collidable proposed-marker placeholders; collidable unchanged.)

## Legacy caps that the expanded map exceeds (old `phase8a2b/6_audit`, unchanged)
| Rule | Cap | v9 | Note |
|---|---|---|---|
| C10 map after the sprint | 2,102 / 421 / 53 | 2,931 / 765 / 76 | single-arena cap; the expansion roughly doubles the walkable area (2.07x) |
| C10 design total | 2,252 parts | 2,931 | same reason |
| C10 DataArchive district | 170 / 24 / 8 | 171 / 21 / 8 | the two full-height VaultWall_N openings split ArchiveFloor_Trim2 into 3 pieces (cut pieces keep the district attribute). v7 was 174 / 24 / 8 |
| C10 global ceiling | 4,000 / 900 / 80 / 12 shadows | within | |

## Proposal (owner decision)
1. **Per-map caps instead of one global arena cap.** For Map 1 (hub + three wings):
   - map total <= 3,000 parts / 800 collidable / 80 lights / 12 shadow lights (v9 uses 2,931 / 765 / 76 / 1);
   - expansion share <= 1,050 parts / 380 collidable / 26 lights;
   - per wing including its two routes: Vault+Route_N <= 290 / 105 / 10; Pit+Route_W <= 320 / 130 / 8; Foundry+Route_E <= 300 / 145 / 10; Backdrop <= 130 / 0 / 0; HallOpenings <= 45 / 10 / 0.
2. **Count opening pieces under HallOpenings, not under the district** (or raise DataArchive to 172 / 24 / 8). This is the only district cap the expansion touches.
3. **Keep 750 collidable as a stretch target, not a gate**, until a device test exists. A further ~30 collidables could be cut (aisle ramps, junction cover blocks, station deck rails merged into walls), but each costs either mobility or cover.
4. **Before adoption: a mobile performance pass** (low-end phone, 8-12 players, all four zones occupied). None was run in this iteration; all numbers here are static counts.
5. Map 2 needs its own budget once it is imported; it is not covered by this proposal.

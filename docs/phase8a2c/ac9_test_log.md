# Phase 8A-2c — AC9 / streaming / reset test log (2026-11-11)

Solo Studio Play (1 server + 1 client), driven through Studio MCP. Patches were requested on the live
match through the injected harness `tools/studio/phase8a2c/3_test_server.luau` (`ZZ_EnvFXTest8A2C`,
Play session only, never saved). The client was checked with a read-only comparison that, for every
EnvFX hook streamed in on the client, recomputes the expected value of every managed property from the
hook's `Base_*` attributes plus the expected active effects (the module's frozen `Styles`/`Order`) and
compares it with the live property. "mismatches 0" means every managed property of every hook equals
its expected value; with no active effect that is exactly the builder-written baseline.

Multiplayer, mobile and gamepad are **not** tested here (deferred milestone).

## Run 1 — AC9 matrix (StudioTimeScale 3, first build)
Build at the time: 126 hooks (28 new parts, the 8 small glitch bands of the first build). Final-build
re-check is in run 3.

| # | State on the server (Snapshot) | Client check | Result |
|---|---|---|---|
| 1 | ACTIVE, no patches | hooks 126, props 185, mismatches 0, 30 connections | PASS (baseline) |
| 2 | ZERO_G **WARNING** | mismatches 0 vs baseline, Writes 0 | PASS (no WARNING response) |
| 3 | ZERO_G ACTIVE | mismatches 0; ZERO_G changed 30 properties | PASS |
| 4 | ZERO_G + BOUNCY → **SUPER_BOUNCE** | mismatches 0; ZERO_G 30, BOUNCY 16, SUPER_BOUNCE 46 (coils at the combination violet) | PASS (combination precedence) |
| 5 | BOUNCY cancelled (combination ends, ZERO_G remains) | mismatches 0 vs {ZERO_G}: rims hidden again, coils back to the ZERO_G violet | PASS (source resumes) |
| 6 | DECAY + CORRUPTION → **RAPID_DECAY** | mismatches 0; DECAY 14, CORRUPTION 8, RAPID_DECAY 9 | PASS |
| 7 | rapid: cancelall → FLOOD, MAGNETIC, SLIPPERY requested back-to-back → **FLOATING_DEBRIS** + **SLIDE_FIELD** | mismatches 0; SLIPPERY 48, MAGNETIC 9, FLOOD 11, FLOATING_DEBRIS 9, SLIDE_FIELD 12 | PASS (two combinations at once, rapid changes) |
| 8 | cancelall | mismatches 0 vs baseline | PASS (exact restore on cancellation) |
| 9 | BLACKOUT ACTIVE (server and client Lighting 0.50/−0.90, owned by WorldModifierService) | mismatches 0; BLACKOUT 10 (5 seams) | PASS |
| 10 | + DRONE_SWARM → **HUNTER_SCAN**, + SUPPLY_DROP | mismatches 0; DRONE_SWARM 6, SUPPLY_DROP 20, BLACKOUT 10, HUNTER_SCAN 1 | PASS |
| 11 | all of them **expired naturally** | Lighting back to 1.80/0.30; only an Architect-accepted BOUNCY (live Architect path) remained and matched exactly | PASS (expiry restore) |

All 10 patches and all 5 combinations produced their response with 0 mismatches.

### Streaming (run 1, client-local re-parenting while the patch state changes)
| Test | Evidence | Result |
|---|---|---|
| Assembly **leaves** during activation | ReactorSilhouette re-parented to nil while ZERO_G active: HooksRemoved 0→27, tracked hooks 126→99 | PASS (removed events received) |
| **Reappears before the patch ends** (a coil trim tampered to red while out) | HooksAdded 126→153, tracked 126; trim back to the ZERO_G colour; mismatches 0 | PASS |
| **Reappears after the patch ended** (left while ZERO_G active, ZERO_G cancelled while out) | while out the trim still showed the ZERO_G colour (0.675,0.376,1); after re-add it is the base colour (0.541,0.169,0.886); mismatches 0 | PASS (restore from `Base_*`, not cached values) |
| Assembly **arrives after activation** | TestHangar.Structure removed at baseline, DECAY activated (in-workspace hooks correct, skylights still base while out), re-added → skylight (0.173,0.055,0.259) T 0.30 = DECAY style; mismatches 0 | PASS |

## Run 2 — RESET and consecutive matches (StudioTimeScale 0.25)
| Test | Evidence | Result |
|---|---|---|
| FLOOD + MAGNETIC → FLOATING_DEBRIS, through FINAL_PHASE | mismatches 0 in ACTIVE and FINAL_PHASE | PASS |
| Natural expiry in FINAL_PHASE, then RESULTS → RESET → LOBBY | mismatches 0 vs baseline at RESULTS and at COUNTDOWN | PASS |
| **Client initialisation while a patch is active** (match 2, ZERO_G + BOUNCY + SUPER_BOUNCE): every hook first forced back to its server/base values (345 writes), then a NEW module instance + new MatchStateClient instance started mid-patch | fresh instance applied the full active state: mismatches 0, key `ZERO_G,BOUNCY,SUPER_BOUNCE`, 126 hooks, 30 connections | PASS |
| **Match end with patches still ACTIVE** (210 s patches; "ended: match_end") | RESULTS: mismatches 0 vs baseline; COUNTDOWN: mismatches 0 | PASS (exact restore at match end / RESET) |
| Fresh instance `Stop()` | connections 30→0, hooks 126→0, no extra writes (already baseline) | PASS (clean disconnect) |
| **Match 3** (no client restart): SLIPPERY active then expired | active: mismatches 0 (SLIPPERY 40); after expiry: mismatches 0; still 30 connections, 126 hooks | PASS (consecutive matches) |
| Server validators in match 3 | `Validate ok=true errors=0 baseline=true differences=0` | PASS |

Connection count of the running controller: 30 (15 effects × added/removed) at every check across three
matches; no RenderStepped/Heartbeat/loops in the module (event-driven only). Skipped (unchanged-key)
Snapshots: 48 by the end of run 2 (timers, stability, turns, objectives).

## Run 3 — final build re-check (after the glitch bands were enlarged to 12 and the beam widened)
| Test | Evidence | Result |
|---|---|---|
| Validators at match start | `Validate ok=true errors=0 baseline=true differences=0` | PASS |
| CORRUPTION + BLACKOUT + DRONE_SWARM → HUNTER_SCAN | hooks 130, props 189, mismatches 0; CORRUPTION 12, BLACKOUT 10, DRONE_SWARM 6, HUNTER_SCAN 1 | PASS |
| cancelall | mismatches 0 vs baseline; Lighting 1.80/0.30 | PASS |

## Console
Runs 1–3: only `[WORLD_EXE]` info lines (patch/combination lifecycle, Architect turns, match transitions)
and one Studio-assistant note about the camera type. **0 warnings, 0 errors**, 0 EnvFX diagnostics.

# Core Round Step 1: movement + Rebound Disc + holographic shield (isolated prototype)

- **Authorization:** owner, 2026-11-20 ("Step 1 authorized"). Step 1 only; Steps 2–4 need a new authorization.
- **Specification:** Core Round v1.1 (https://claude.ai/artifact/Dh6v31x3TNMv6eAAeTQSPq) and its closeout addendum (https://claude.ai/artifact/B3GbA1siSCDRZ7DQfxrEJG).
- **Status:** draft, isolated, **do not merge**. All values are provisional.

## 1. Isolation
- **Code** lives only in `src/**/CoreRound/**` (19 files, about 4,500 lines). Every script returns immediately unless `Workspace.WORLD_EXE_CoreRound == true`. Only the Step 1 test place sets that attribute.
- **The test place** is a separate local file, script-built (`tools/studio/coreround/`), never published. It contains only the CoreRound scripts.
- **Not modified:** `Place1.rbxl`, Cyber City, Concept C r3, any map, lighting, the main-game scripts, and PR #22 (`proto/wrist-hacking` stays at `8737958`; its place hash is unchanged).
- **Avatar rig:** no ForceR6 and no avatar or rig settings change. Hit volumes are rig-agnostic (Head part + root).
- **Not imported from PR #22:** skill check, diamonds, hacking UI, FLING / FREEZE, Matter Manipulation, ForceR6.
- **Reused from PR #22:**
  - `WallRun.luau` and `MoveState.luau`, copied and adapted to CoreConfig tuning, with Super Dash allowed to hand over to a wall run;
  - the pooled-effects / afterimage approach (L-0049, L-0063);
  - the server-decides / owning-client-applies movement pattern (L-0019).

## 2. Implemented systems
| System | Where | Summary (provisional values) |
|---|---|---|
| Fast baseline run | `Movement.luau`, server `CoreRound.server.luau` | Run 30 studs/s. Momentum is kept through jumps (air decay 6/s). Every dash ends at 38 studs/s, easing back over 1 s. Wall-jump +4. Soft cap 45 (decay 30/s). |
| Two-charge Super Dash | `Movement.luau` (client), `CoreMove.luau` (server judge) | Q / gamepad B / touch DASH. A press is a dash: 26 studs in 0.25 s. A second press within 0.40 s of the first is a Super Dash: 1.0 s steerable at 70 studs/s. 2 charges, 2.5 s each, regenerating one at a time on the ground or in the air. No skill check and no diamonds. The server rejects any burst it did not allow. |
| Rebound Disc | `CoreDisc.luau` (server), `DiscClient.luau` (client) | Out 70 studs at 130 studs/s. Homes back at 150 and is auto-caught. One wall reflection. Snaps back after 2.5 s with a 1.5 s penalty. Team-coloured disc, a 0.6 s trail, a ring at the bounce point. The client predicts its own disc; the server decides every hit. |
| Disruption meter | `CoreCombat.luau` | Body +30, head +50, stun at 100 (0.8 s). Decay starts 2.5 s after the last hit, at 40/s. 3.0 s protection after a stun. Hits during a stun are ignored. Stun sets WalkSpeed to 0 and blocks dash, throw and shield. |
| Duplicate-hit protection | `CoreDisc.luau` | The disc passes through targets. By default **a throw hits a given target once** (`SameTargetPerThrow = 1`; see §6.2). |
| Lag compensation | `CoreDisc.luau`, `CoreCombat.luau` | Targets are tested at server time − (thrower one-way latency + interpolation term). The term is 0 for server-moved targets and 0.05 s for player characters, both measured (§5). Cap 0.25 s. The server disc catches up by the thrower's one-way latency, up to 0.12 s. |
| Holographic shield | `CoreCombat.luau` (server maths), `ShieldClient.luau` (visual) | Hold right mouse / L2. Touch taps to toggle (a setting). Panel 8 × 7 studs, 3 studs ahead, facing the camera aim. Energy 100: drains 20/s, 15 per block, regenerates 25/s after 1 s, breaks at 0 for 2.5 s. 70% speed while raised; no throwing; a dash lowers it. Protects anyone standing behind it. **The server tests a rectangle mathematically; the visual is a client-only part with no collision, query or touch**, so it never obstructs characters or pickups. |
| HUD / feedback | `Hud.luau`, `Fx.luau` | Crosshair, white body / gold head hit markers, stun ring, dash charge pills, shield energy, disc state, speed readout, own meter. Over other entities: meter bars, STUN / PROTECTED flags, team-colour outlines. F2 diagnostics panel with toggles (Reduced FX, Aim lock, Touch shield toggle, Speed readout). Pooled bursts, rings and shards. Sounds are pitch-shifted built-in placeholders (no uploads). |
| Aim / camera | `Aim.luau` | Desktop aim lock (default): cursor locked to the centre, over-the-shoulder offset, the character faces the camera yaw. Left Alt frees the cursor. Gamepad and touch aim through the centre crosshair. No camera shake; FOV eases +6 on a dash and +10 on a Super Dash. |
| Input | `Input.luau` | Roblox movement and jump are untouched. CAS bindings: Q/B dash, LMB/R2 disc, RMB/L2 shield, plus three compact touch buttons left of and above the jump button. |
| Anti-abuse | `CoreRound.server.luau` | 30 requests/s token bucket. Throw rate limit. Origin check (clamped beyond 8 studs + speed × latency). 0.06 s minimum between dash presses. Super window checked with latency slack. Stunned or shielded players cannot throw. Cleanup on death, respawn, leave and test reset. |
| Test yard | `tools/studio/coreround/cr_20_build_yard.luau` | Arena, disc range, moving lane, shield fixture, movement lane, rooftop gaps, wall-run walls, 7 dummies (one moving, one shielded, one Cyan). Team assignment: Cyan first, then the smaller team. |

## 3. Build and verification
- Build steps: `tools/studio/coreround/README.md`.
- **Local test place:** `C:\WORLD.EXE-Art\CoreRound\place\WorldEXE_CoreRound_2026-11-20.rbxlx`, 1,306,765 bytes, SHA-256 `f8cf4b0a1d5dead43cc9822b74f5e3b51d36df5eeeb1927fde847c0dd128dc9e`. Backup: `place\backup_step1_2026-11-20\` (identical hash).
- **Source-to-saved-place verification** (`cr_40_verify_saved.js`, reading the saved file): 19/19 scripts identical to `src/`, no extra scripts, no test leftovers (`ZZ_*`).
- **Protected files:** 9/9 OK before and after.

## 4. Test matrix (one focused session, Studio solo + one two-client session)
Unless noted, results are from the server event log and client test hooks. Bot-driven tests do not show that the game is fun.

### Movement
| Test | Result | Evidence |
|---|---|---|
| Baseline run 30 (server + client) | PASS | WalkSpeed 30; 21.0 with the shield up (×0.7) |
| Dash distance / time | PASS | 26.0 studs in 0.25 s (ground and air) |
| Super Dash | PASS | 71.2 studs in 1.02 s (a second press 0.12 s after the first) |
| Charge use and regeneration | PASS | 2 → 0. A third press is refused for no charge. +1 after 2.5 s, full by 5 s. |
| Real Q key spam (10 presses in 0.2 s) | PASS | Only dash + super, then refusals |
| Forged remote flood | PASS | 16 in one frame → 1 accepted. 6 spaced 0.1 s → 2 accepted, 4 refused for no charge. |
| Throw while dashing | PASS | Solo and two-client |
| Wall-run (optional), real W + Space | PASS | wallrun → walljump → run; climbed to y 19.1 |
| Direction changes and speed feel | UNVERIFIED | Needs human play |

### Rebound Disc
| Test | Result | Evidence |
|---|---|---|
| Throw / return / catch | PASS | Caught in 0.78–0.98 s |
| Wall rebound | PASS | Bounce at the north rebound wall, caught in 0.82 s. A rebound hit off cover was also logged. |
| Snap-back penalty | PASS | Snap at 0.42 s (test tuning). Re-throw at +0.7 s refused (cooldown); allowed at +2.0 s. |
| Ownership / other clients' view | PASS | Only the owner catches. Dummy discs return to the dummy. The other client draws the disc. |
| Static targets | PASS | All dummies |
| Moving target (14 and 30 studs/s) | PASS | Hits with lead; stun on the moving dummy |
| Head / body classification, static | **FAIL → fixed → PASS** | The first version disagreed with itself (client said HEAD, server said BODY on 4 of 6 body throws): the inflated head volume overlapped the upper torso, so the result depended on step size. Fixed with a shared `CoreGeom.DiscHit`. Afterwards 6/6 agree, 3/3 head. |
| 2 heads → stun · 2 body + 1 head → stun · 3 body → no stun | PASS | 50 → STUN · 30, 60 → STUN · 30, 60, 90 (re-run after every change) |
| Meter decay | PASS | 60 at +2.3 s, 52 at +2.7, 32 at +3.2, 4 at +3.9 |
| Duplicate-hit prevention | PASS | One "once_per_throw" dedupe logged per throw |
| Stun and recovery | PASS | 0.80 s stun. Protection to +3.80 s. During the stun: walk 0, dash/throw/shield refused. Afterwards walk 30. |
| Player stunned by a dummy attacker | PASS (1 note) | Hit then STUN. One earlier attempt registered two head misses that did not reproduce in 3 later tries. Cause unknown; logged as a defect to watch. |

### Holographic shield
| Test | Result | Evidence |
|---|---|---|
| Front block (fixture and player) | PASS | Blocks; energy 100 → 82 → 56 (blocks + drain) |
| Teammate behind is protected | PASS | Throws at D-BEHIND blocked by D-SHIELD's panel |
| Flank | PASS | Side throw hits (fixture and two-client) |
| Energy drain / break / broken / regeneration | PASS | Held → breaks at 5.03 s. Raising while broken refused. 49 energy 3.5 s later. |
| Dash lowers it | PASS | Server state down after a dash |
| No throwing while shielded | PASS | Refused ("shield") |
| Movement while shielded | PASS | 21.0 studs/s |
| Never obstructs characters | PASS | Walked straight through the panel line (x 62 → 74). 0 effect parts with collide/query/touch. |
| Visual feedback (deploy, impact flash, energy, cracks, break) | PASS (captures) | Defect fixed: after a break the panel lingered 0.5 s (it now drops at once) |

### Controls and accessibility
| Test | Result |
|---|---|
| Keyboard + mouse (Q, LMB, RMB hold / release) through the real bindings | PASS (MCP-emulated input) |
| Gamepad (B, R2, L2 hold) | PASS with emulated KeyCodes; **real controller UNVERIFIED** |
| Touch buttons / layout / toggle | **UNVERIFIED** (no device or emulator run) |
| Reduced Effects | PASS: peak effect instances during a Super Dash 78 → 18 |

### Multiplayer
| Test | Result |
|---|---|
| Two-client PvP hits and stuns | PASS: 46 server-confirmed hits and 8 stuns on player B during the batches |
| Two-client shield front block / flank | PASS at 150 ms |
| Death / respawn cleanup (disc in flight, shield up, meter > 0) | PASS: disc "cleared"; respawned entity meter 0, shield down, energy 100 |
| Disconnect cleanup | UNVERIFIED (code path only) |

## 5. Latency and hit reliability (measured)
Shaping used Studio's `settings().Network` (inbound / outbound delay). Measured `NetworkPing` was 152 ms and 252 ms. Each batch is 14 throws, half aimed at the head, from a scripted thrower that leads the target's visible motion. "Agree" means the thrower's screen and the server gave the same result (head / body / miss). Shaping was reset to 0 afterwards.

**Visual delay (how far behind the server the thrower sees a target):**
- server-moved dummy at 150 ms: 67 ms;
- player character at 150 ms: 128 ms (p10 119, p90 133);
- player character at 250 ms: 175 ms (147–182).

So rewind = one-way latency + 0 for dummies, + ~0.05 s for characters. The server's own round-trip estimate ran 25–30 ms above NetworkPing; a 25 ms bias correction was added.

**Solo, server-moved target at 30 studs/s:**
| Ping | Rewind | Agree | Seen hit, server missed | Head throws scored HEAD by the server |
|---|---|---|---|---|
| 150 | off | 4/14 | 7 | 0/7 |
| 150 | on, +0.05 s interp (first default) | 7/14 | 0 | 0/7 (7 seen HEAD, all scored BODY) |
| 150 | on, interp 0 (current dummy setting) | 11/14 | 0 | 3/7 |
| 250 | off | 6/14 | 8 | 0/7 |
| 250 | on, interp 0 | 9/14 | 0 | 0/7 |
| 250, static target | on | 7/8 | 0 | 3/4 |
| 0, moving target | on | 9/10 | 0 | 1/5 |

**Two clients, player target running at 30 studs/s (rewind on, player interp 0.05):**
| Ping | Rewind | Agree | Seen hit, server missed | Server hit, not seen | Head throws scored HEAD by the server |
|---|---|---|---|---|---|
| 0 | on | 11/14 | 2 | 1 | 3/7 |
| 150 | on | 9/14 (4 differ head/body) | 1 | 0 | 5/7 (the thrower saw only 2) |
| 250 | on | 13/14 | 0 | 0 | 3/7 |
| 250 | **off** | 4/14 | 6 | 0 | 0/7 |

**Findings**
1. **Lag compensation is essential.** Without it, at 150–250 ms about half the throws a player sees landing miss on the server.
2. **Body hits are reliable** with rewind. **Head classification on targets moving at running speed is not reliable**, even at 0 ms with scripted aim. The head volume is 0.85 studs and the disc crosses it in about 1 frame, so ~0.5 stud of aim or latency error flips HEAD and BODY. Static headshots are reliable.
3. The owner's two-headshot stun was **not** weakened to compensate (values unchanged).
4. Small samples (14 throws per cell, scripted aim). These are indicators, not statistics.

## 6. Known defects, concerns and recommendations before Step 2
1. **Headshots on moving players** (§5). Options for owner review (none applied):
   - (a) "favour the shooter": the client reports what it saw, and the server accepts it if it lies within a small tolerance of the rewound pose;
   - (b) a larger head volume, which changes how often the head combo lands;
   - (c) accept rare moving headshots as a skill reward.

   Recommend (a), then a human play test.
2. **Duplicate-hit rule differs from the v1.1 text.** The returning disc homes back along nearly the same line, so the spec rule (out + return both count, 0.4 s apart) lets one throw at a still target hit twice about 0.7 s apart. A single head throw would then stun. Default is now "a throw hits a target once" (`CoreTune_Disc_SameTargetPerThrow = 2` restores the spec). **Owner decision.**
3. **The returning disc ignores walls**, so it is always caught; visually it passes through geometry on the way back. Owner decision on the feel.
4. **The shield faces the camera aim**, not the character. Correct per spec, but it surprised the scripted tests; worth a human feel check.
5. **Desktop aim lock** makes the character face the camera (shooter-style strafing). This is a feel decision.
6. **Placeholder sounds only** (built-in files). Proper audio is an art task.
7. **Untested:** touch layout and real controller hardware; disconnect cleanup; server load with more than 2 players (no profiling).
8. **Exploit surface:** charges, throws, shield and hits are server-checked; character position and speed are client-simulated (Roblox default). Speed-hack checks are a later milestone.
9. One unexplained double miss (dummy → player head) did not reproduce; watch for it in human tests.
10. Studio multi-client launch failed once (flag-fetch HTTP timeouts in the test windows); the second launch worked.
11. **Before Step 2, recommended:** an owner play session (2 people) for feel; decisions on items 1–3; then authorize Step 2.

## 7. Gameplay-feel assessment (measured, not validated with players)
- **Movement:** the dash reaches 26 studs in 0.25 s and ends at 38 studs/s, so momentum carries into running. The Super Dash covers ~71 studs per second with a bright afterimage trail (the trail may be too heavy; Reduced FX tones it down). No timing test stands between the player and the burst.
- **Disc:** about 0.5 s out to 70 studs and back in about 0.5 s gives a short, readable cycle (about 1 s per throw). The trail, bounce rings, bursts and hit markers read clearly in captures.
- **Shield:** the cyan frame and energy strip read clearly from behind. Blocks flash. Breaks shatter.
- **Combat loop:** the meter forces 2–3 hits within 2.5 s while the target can shield, dash out or break line of sight. In principle this encourages pressure and chasing rather than trading, but **whether it is fun is unvalidated**: only scripted bots played.

## 8. Captures (local only, not committed)
`C:\WORLD.EXE-Art\CoreRound\evidence\captures\`:
- `disc_range/` (disc trail, meter bars, HUD in flight);
- `super_dash/` (afterimages, trail);
- `shield_block3/` (blocks, energy drop, break shards, "SHIELD BROKEN");
- `shield_block2/` (a mistimed test: stun without a shield; kept as evidence of stun / "PROTECTED" UI).

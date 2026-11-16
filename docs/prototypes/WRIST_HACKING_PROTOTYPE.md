# Wrist-hacking prototype (FLING / FREEZE / SHIELD + boss challenges)

Status: **isolated prototype, draft PR, not for merge.** The owner approved the milestone on 2026-11-16. This is **not** an adopted gameplay design. Every number is provisional.

## 1. Scope and isolation
- **New code only**, active only when `Workspace.WORLD_EXE_HackPrototype == true`. Only the local prototype place sets it. In Place1 every new script returns immediately.
- **No existing file is modified.** ArchitectController, HUDController, AbilityController, UITheme, UIUtil, the services and the patches are untouched.
- **Separate from Architect patches:** own catalog (`HackCatalog`), own remotes (`HackRemotes/HackRequest`, `HackEvent`), own service and cooldowns. Hacks never read Architect turn state.

## 2. Files
| File | Role |
|---|---|
| `ReplicatedStorage/WORLD_EXE/Shared/HackCatalog.luau` | The one effect library for chips **and** typed commands. It holds the definitions, provisional tuning, live overrides (`Tune`), challenge configuration and the bounded parser (`Parse`). |
| `ServerScriptService/WORLD_EXE/HackPrototype/Main.server.luau` | Gated server entry. |
| `…/HackPrototype/HackService.luau` | Remotes, rate limit, validation, cooldown and retry, challenge sessions, effect dispatch, cleanup, NPC patrol and respawn, Studio test hooks. |
| `…/HackPrototype/HackChallenges.luau` | Server-authoritative challenges: Sequence, ResistanceBattle, InputChase, SignalLock, plus the assist scale. |
| `…/HackPrototype/HackEffects.luau` | FLING_SELF hand-off, reversible ragdoll (FLING_TARGET), FREEZE, SHIELD, and their cleanup. |
| `…/HackPrototype/HackTargets.luau` | Server-side target resolution and line-of-sight checks. |
| `…/HackPrototype/ConductorPrototype.luau` | Placeholder boss: telegraphs, strikes, vulnerability windows, reactions, integrity. |
| `StarterPlayerScripts/WORLD_EXE/HackPrototype.client.luau` | Gated client entry. |
| `…/Controllers/HackController.luau` | Wrist terminal (chips, targets, command line, challenge views, touch pad), input arbitration, FLING_SELF client executor. |
| `…/Controllers/CyberChip.luau` | The 8B-1B data-chip look as a reusable builder. |
| `tools/studio/hackproto/*` | Server, code sync, place builder, saved-file verifier, client test kit, capture script, README. |

## 3. Mechanics as built (owner requirements → implementation)

**FLING SELF**
- **Launch:** the server computes `dir × Forward + up × Up`. Direction comes from camera-relative move intent, falling back to camera facing.
- **Execution:** the owning client applies it (Roblox simulates a character on its own client).
- **Control in flight:** the Humanoid stays in normal states (Jumping → Freefall → Landed). There is no ragdoll and no PlatformStand.
- **Carry and steer:** a plane `LinearVelocity` keeps the horizontal carry, and move input adds or subtracts up to `SteerSpeed`.
- **Release:** on landing, after a wall stop (speed under 30 % for 0.15 s), or at a 2.5 s cap.

**FLING TARGET**
- **Limits:** server-chosen target, range 55, line of sight, cooldown 8, and 4 s fling immunity after recovery.
- **Ragdoll:** every non-root Motor6D is disabled and mirrored by a limited `BallSocketConstraint` plus a `NoCollisionConstraint`. Limbs collide, `RequiresNeck` is off during the ragdoll, and the server owns network physics.
- **Recovery:** after 2.0 s (hard cap 4.0 s) motors are re-enabled, constraints destroyed and collisions restored. The root stands upright with its yaw kept. Ownership returns to the player (or the server for NPCs), followed by GettingUp.
- **Death mid-ragdoll:** constraints are cleaned up with no stand-up.

**FREEZE**
- **Effect:** about 3 s (anchors the root), with an ice highlight and a countdown label. The victim's client shows a banner.
- **Limits:** no stacking ("already_frozen"), then 4 s freeze immunity, which prevents stun-lock. A frozen target cannot be flung.
- **Cleanup:** on death or removal.
- **Boss:** 1.5 s, then 6 s immunity. It cancels an attack being charged.

**SHIELD**
- **Effect:** self only, 6 s, server attribute plus a bubble. The client shows the remaining-duration bar.
- **No refresh:** the 12 s cooldown starts at activation.
- **Scope:** only Conductor strikes check it (blocked strikes flash the bubble). It is not general invulnerability.
- **Cleanup:** cleared on death or respawn.

**Challenges** (all decided on the server; the client sends one direction per press)
- **Self:** FLING SELF has none. SHIELD has 1 arrow (2.5 s).
- **Player or NPC targets:** 3 ordered arrows chosen by the **hacker**, within 4.5 s, with up to 2 misses (no reset).
- **Boss**, one variant at a time (boss attribute, switched at the arena consoles):
  - **Resistance Battle:** +0.2 per correct arrow; drain 0.16/s (0.22 while the boss charges, 0.06 while it is vulnerable); needs 6 arrows **and** a full bar; misses cost 0.08.
  - **Input Chase:** starts with 3 arrows; the boss appends one every 0.9 s (0.7 charging, 1.3 vulnerable); success needs an empty queue **and** at least 7 cleared; fails if the queue exceeds 6.
  - **Signal Lock:** 4 locks within ±0.22 s of arrival (0.32 vulnerable); 2 misses allowed; client press time accepted only within 0.25 s before receipt.
- **Interruption:** an unblocked boss hit cancels the boss challenge.
- **Retry:** a failed or cancelled challenge costs only a 1.5 s retry wait. Cooldowns start only when an effect applies.
- **Assist:** `HackTune_Challenge_TimeScale` (1-8) gives longer limits and windows and a slower boss, under the same rules.

**Typed commands**
- **One parser:** `HackCatalog.Parse` maps verbs, aliases and target words to an id and a hint. It never evaluates text.
- **Same validation:** the client resolves the hint to a target and sends the **same** `begin` request as a chip. The server re-parses the text and rejects a mismatch (`parse_mismatch`).
- **Contextual rules:**
  - Bare `fling` means fling the selected target if there is one, else fling yourself.
  - `jump`, `leap` and `boost` always mean yourself.
  - `freeze me` is refused.

## 4. Architect UI adaptation
- **Shared look:** the 8B-1B chip look (chamfers, serial, icon tile, state label, pins) is extracted into `CyberChip`, which the wrist terminal uses. It has the states default, focus, selected, pending, accepted, rejected, disabled and recharging, plus a cooldown shade.
- **Reused patterns:**
  - SELECT → CONFIRM (a second press of the same chip also confirms).
  - The keyword field, here as the typed command line.
  - The feedback line.
  - Touch placement via `UITheme.touchPanelRegion`.
  - Reserved rectangles (`"wrist"`).
- **Not copied:** turn identity, countdown and server patch logic.
- **Arbitration:**
  - While `WORLD_EXE_Architect` is enabled, the terminal closes, any challenge is cancelled and H/L1 do nothing.
  - Challenge directions are bound at a priority above the HUD (D-pad Down) and abilities (D-pad Up).
  - The toggle moved from G to H after testing showed G is the HUD details key.

## 5. Tests run (solo Studio, 2026-11-16; Server + Client in one Play session)

| Test | Result |
|---|---|
| FLING SELF sweep A 78/48, B 90/42, C 98/48 over 3 lanes, 4 gaps and flat ground | **B chosen.** Rise 20.5, about 39 on flat ground. Reaches the 8-high/24-away lane, the 14/32 lane, and the 24- and 32-stud gaps. C reaches the 20/36 lane and the 40 gap but overshoots short targets. No ragdoll; state Running on landing; tilt 0. |
| FLING SELF via chip keys `1`,`1` onto the 14/32 platform | Landed on top; rise 20.5, 32.4 across, 0.76 s in the air. |
| FLING TARGET, Dummy-A, wall 22 behind it | Flung into the wall; full recovery (motors on, 0 sockets, upright, server-owned). |
| FLING TARGET, Dummy-C off a 12-high ledge (time series) | Arc to the ground, limp 2.0 s (tilt −75°), then upright and Running. |
| NPC killed mid-ragdoll / mid-freeze | 0 leftover effects, constraints or highlights; dummy respawns healthy after 3 s. |
| FREEZE, patrolling Dummy-B | Frozen 3.06 s, then the patrol resumes. Fling-on-frozen → `target_frozen`; re-freeze → `cooldown`. |
| SHIELD | 1-arrow activation; second activation rejected. Two Conductor strikes logged **"BLOCKED by shield"** during the 6 s; hits before and after it. |
| Death mid-challenge / with shield | Result `died`; session cleared; shield attribute cleared; UI reset. |
| Resistance Battle | Solve (6 arrows, about 1.1 s) ✓; wrong arrows → `resisted`; no input → `resisted` (3 s). |
| Input Chase (after fix) | Fast (0.2 s per press) ✓ 1.4 s; medium (0.6 s) ✓ 3.8 s; slow (1.2 s) → `timeout`; wrong → `overrun`. |
| Signal Lock | On time ✓ (4 locks, about 5.7 s); 0.4 s late → `too_many_misses`; forged early client time is clamped. |
| Boss hit during a boss challenge | `interrupted`. |
| Validation | `bad_payload` ×3, `unknown_hack`, `parse_mismatch`, `cannot_target_self`, `no_target` ×2, `out_of_range`, `no_line_of_sight`, `retry_wait`; a 40-request burst → 27 `rate_limited`. |
| Parser table (26 inputs) | As specified, including contextual fling, `freeze me` refused, and code-like text refused. |
| Real keyboard via Studio input | H opens; `3` selects; Enter executes; arrow keys solve; typed `fling dummy-a` + arrows → "Target flung". |
| Emulated gamepad keycodes | L1 toggles; the D-pad solves a challenge; D-pad Down did **not** toggle the HUD details panel during the challenge. |
| Touch layout preview (844×390) | Terminal and direction pad sit in the free region (no overlap with the thumbstick or jump zone); clicking the pad solved a challenge. |
| Architect arbitration (solo match, StudioMinPlayers 1) | Turn opened → terminal closed, `ArchitectLock` true, H ignored. |
| Saved place vs `src/` | 54/54 scripts identical (`hp_40_verify_saved.js`). |

**Defects found and fixed during testing:**
1. Input Chase was trivially beaten before the boss ever appended. It now needs at least 7 clears, with faster appends.
2. The rate limit (4/s) blocked fast legitimate input. It is now a burst of 14 at 9/s.
3. The G key clashed with the HUD details panel; the toggle moved to H.
4. Three glyphs did not render in the UI font.
5. Touch chips were clipped.
6. The challenge title overflowed.
7. The client's target range ignored live tuning.
8. The pill's Architect label was overwritten.
9. Dead dummies never respawned.

## 6. Not tested / limitations (not claimed)
- **Multiplayer:** no two-client run (needs the owner's Test → Clients and Servers). Player-vs-player FLING/FREEZE network ownership hand-off, victim view and counterplay are untested.
- **Real devices:** no real touch hardware or gamepad hardware. Gamepad GUI focus is untested: emulated keys report Keyboard as the last input.
- **Real Studio keyboard timing** is limited by tool latency (L-0001). The timed keyboard runs used assist ×8; the timing-critical runs were validated through the same remote by the test kit.
- **Typed input vs chat:** in one run the typed command went to Roblox chat instead of the terminal. Focus behaviour on real keyboards needs an owner check.
- **Trust in Signal Lock timing:** client press time can gain up to 0.25 s.
- **FLING SELF** is executed by the client and has no server-side trajectory check.
- **Not built:** victim counterplay, diminishing returns beyond fixed immunity, and team rules.
- **Boss:** a placeholder humanoid, anchored and stationary. Two attacks; balance not tuned.

## 7. Revision 2 — owner reference clip (2026-11-16)
**Owner direction:**
- The fling should work like a reference clip from another Roblox experience. The key takeaway is **how it flings upward and how the character gets ragdolled**.
- "When I first saw the patches, they looked underwhelming."
- Make the wrist device look omnitrix-like as a placeholder.

**Reading of the clip** (frames 28–74 at 30 fps):
- **Launch:** an orange starburst and sparks at the feet; a ring of broken, tilted floor tiles stays behind.
- **Flight:** about 30 studs high, about 1.25 s airtime, about 35–40 studs of travel. The camera chases it up. The body is limp and tumbles; it lands and then gets up.

**Changes:**

*Ragdoll launch (shared by FLING TARGET and, optionally, FLING SELF)*
- **New path:** `ragdollLaunch` (HackEffects).
  - Up 112, Forward 32, plus a tumble of 7 rad/s around the axis across the flight direction.
  - Limp for the whole flight.
  - Landing is detected on the server (torso ray, low fall speed); the target stands up `LandRecoverDelay` 0.9 s after touching down (minimum limp 1.2 s, cap 5 s).
  - The fixed 2 s timer is gone.
- **Measured** (Dummy-A): rise +26.2 (peak at 0.53 s), landed 1.18 s, standing 2.10 s, travel 36.2, tumble tilt up to −76°/−138°, final state Running.

*FLING SELF reference mode*
- **Switch:** `HackTune_FlingSelf_Ragdoll = 1` gives FLING SELF the same ragdoll launch (Up 112 / Forward 32).
- **Measured** on the player's own R15 character: rise +28.7, landed 1.17 s, standing 2.12 s. Physics was **server-owned during the flight and returned to the player** afterwards.
- **Clean recovery:** 0 ragdoll sockets left, full health, and real WASD + jump worked right after recovery.
- **Default left at 0:** the 2026-11-16 directive said FLING SELF does not ragdoll. **Owner decision pending.**

*Launch and landing VFX (`HackVfx`, client, broadcast to all clients, cosmetic)*
- **Launch:** starburst spikes, core flash and light, spark burst (built-in particle texture), orange shockwave, crater ring of tilted tiles plus scorch (fades after about 4 s), and a flight trail.
- **Camera:** an FOV kick and shake for the flung player, and a light shake for nearby viewers.
- **Landing:** a dust ring, a small crater and sparks.
- **Reduced Effects** turns all of it off.
- **Fix:** a mid-air "landing" crater, caused by a missed floor ray being treated as a landing.

*Placeholder wrist device (`HackDevice`, server)*
- **Look:** an original chunky gauntlet on the left forearm (band, trims, raised round face, bezel, glowing green core, dial ring with ticks, side buttons). Native, massless, non-colliding parts. No franchise emblem copied.
- **Core colour:** idle green, hacking amber, success cyan, failure red.
- **Dial:** spins locally while the terminal is open (faster during a challenge).

**Recorded, not built:** the owner found the existing **Architect patches visually underwhelming**. The same launch/impact language (burst, crater, trail, camera kick) is a candidate for patch presentation. That needs a separate owner decision.

## 8. Revision 3 — owner rule on ragdoll (2026-11-16)
**Owner:** "It should only ragdoll when done on another player or boss type of enemy, but when you're doing it on yourself, it should not ragdoll you."

**FLING SELF**
- **Never ragdolls.** The `HackTune_FlingSelf_Ragdoll` switch is removed.
- **Kept:** the controlled arc (Up 90 / Forward 42) plus the launch VFX.
- **Verified:** 0 ragdoll samples during a self fling (even with the old attribute set). Landed on the 14-high platform, Running, tilt 0.

**FLING TARGET on players and NPCs:** unchanged from revision 2 (tumbling ragdoll launch, gets up after landing).

**FLING TARGET on the boss**
- **Now a real ragdoll** (it was a scripted stagger before):
  - The anchored placeholder is released.
  - Decorative parts are welded at start-up.
  - It is launched with the shared ragdoll launch (BossUp 80 / BossForward 24).
  - Once it has stood up it is re-anchored at its post. Its attack loop waits meanwhile and then resumes with the vulnerability window.
- **Measured:** rise +16.1, landed 0.92 s, back at its post 2.20 s after launch, all motors restored. Attacks resumed.

**Saved place:** 56/56 scripts match `src/`, hash D4D84B24….

## 9. Revision 4 — more fall control on FLING SELF (2026-11-16)
**Owner:** "make it so you can control your fall a bit more on the fling."

**Air control** (client executor, server-sent tuning; still no ragdoll):
- **Turn:** holding a direction rotates the launch carry toward it (`TurnRate` 3 rad/s).
- **Brake:** holding the opposite direction slows the carry (`BrakeRate` 45/s).
- **Steer:** extra steer speed is now 24 (was 16).
- **Fall cap:** the descent is capped at 75 studs/s.
- **Glide:** holding Jump while falling caps it at 28 studs/s.
- **Flight window:** the carry/fall control lasts up to 4 s (was 2.5).

**Solo Studio results, real key presses** (H → `1`,`1`; camera facing +Z):

| Input | Rise | Distance | Airtime | Notes |
|---|---|---|---|---|
| None | 20.5 | 39.2 | 0.92 s | baseline |
| Hold S (brake) | 20.5 | 29.7 | 1.00 s | about 25 % shorter |
| Hold A (turn) | 20.5 | 40.6 | 0.92 s | velocity swung from +Z to +X mid-air; landed 36 studs to the side |
| Hold Space after the apex (glide) | 20.5 | 48.8 | 1.15 s | descent held at about −31 studs/s (free fall reached −77) |

**Notes:**
- Emulated key input took about 0.2 s to show in `MoveDirection`.
- Holding Jump after landing performs normal Roblox repeat jumps.

**Saved place:** 56/56 scripts match `src/`, hash C078ABD3….

## 10. Milestone 2 — hacking, cyberware & boss prototype (2026-11-16)
Directive: "WORLD.EXE — Hacking, cyberware & boss gameplay prototype". Same isolated place and branch. The full record (results tables, captures, findings, owner checklist) is in the vault: `03-Gameplay/Hacking-Cyberware-Boss-Prototype-2026-11-16.md` (vault PR #23).

**New code:**
- **Server:**
  - `HackIncoming.luau`: warning stage for targeted hacks.
    - Reaction window 1.0 s + 0.12 s grace.
    - Resolution order: lost → shield (perfect / deflected) → no line of sight (evaded_cover) → outside ring (evaded_dodge) → hit.
    - Perfect deflect refunds 50 % of the remaining SHIELD cooldown.
  - `HackService.luau`:
    - incoming integration, quick SHIELD (`source = "quick"`);
    - replay protection (input `n` must increase, max +50);
    - TestStation prompts, `Perf` / `IncomingStats` / `SimulateIncoming` hooks.
  - `ConductorPrototype.luau`:
    - relocation, engaged / failed / defeated / reset broadcasts;
    - reset after the arena is empty for 5 s or 16 s after defeat;
    - refuses hacks at integrity 0.
- **Client:**
  - `ArrowGlyph.luau`: shaft + head arrows; states current / done / upcoming / wrong / locked / missed / pad.
  - `HackFeel.luau`: cues, haptics, edge glow, popups.
  - `HackController.luau`: arrows, per-input correct/wrong feedback, incoming banner + attacker pointer + C / R1 / touch SHIELD, outcome popups, boss and station messages.
  - `HackVfx.Incoming` / `Deflect`: dashed ring, tether, overhead warning.
- **Shared:** `HackCatalog.Boots` — Starter 90/42/24/3.0, Vault 106/30/20/3.0, Vector 74/64/22/2.2 (Up / Forward / Steer / Turn). Selected per player at the station; not saved.

**Results (solo Studio; the "player attacked" rows use a dummy stand-in attacker through the real server path):**
- All five incoming outcomes reproduced, for dummies as targets and for the player as defender (real C key, touch button click).
- Forged token, replayed or missing `n`, bad direction, unknown hack, bad source and injected typed text: all rejected. Old timestamps are clamped, not trusted.
- Boss: defeated in Resistance Battle (34 s) and Input Chase (36 s) modes. In Signal Lock, 5 of 9 attempts were interrupted by strikes (finding). Failure leads to a reset in about 4 s.
- Each mode has a measured failure: too_many_misses, resisted, overrun, interrupted.
- Boots, same pad, distance with forward held: Starter 60.6, Vault 54.9, Vector 65.1. Rise: Starter 20.5, Vault 28.4, Vector 13.8. Vector was retuned (56→64 forward) because Starter nearly dominated it.
- Perf: begin avg 0.08 / max 0.43 ms; input avg 0.15 / max 1.32 ms.
- Saved place: 59/59 scripts match `src/`; hash 973D6F2C…. Protected files: 9/9 unchanged since the milestone start.

**Not tested:**
- two real clients (owner decision 2026-11-16: leave untested for this milestone);
- real touch or gamepad hardware;
- per-boot lane reachability in play (model-derived only);
- a re-run of the integrity-0 fix;
- a desktop re-capture after the arrow-row height fix.

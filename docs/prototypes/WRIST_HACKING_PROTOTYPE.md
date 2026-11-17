# Wrist-hacking prototype (FLING / FREEZE / SHIELD + boss challenges)

Status: **isolated prototype, draft PR, not for merge.** The owner approved the milestone on 2026-11-16. This is **not** an adopted gameplay design. Every number is provisional.

## 0. Current state (Rev 15m, 2026-11-17) — read this first
Sections 1–21 are the revision history and keep superseded designs for the record. **This section is the current behaviour.** Where an older section disagrees, this one wins.

**Superseded (do not implement from the history):**
- arrow-key challenge input → **number keys 1–4** (Signal Lock also 5), Rev 15;
- Q-Q super-speed window (0.2–0.8 s), its 11 s cooldown and the 15g follow-up chain → **skill check + diamonds**, Rev 15j;
- full-detail avatar clone afterimages → **R6 silhouettes**, Rev 15m;
- the 1.0 s FLING SELF trail → **blue aura until landing**, Rev 15m.

**Controls (keyboard; gamepad / touch bindings exist but are untested on hardware):**
| Input | Action |
|---|---|
| **H** (gamepad L1, WRIST pill) | Open the wrist terminal |
| **1–4** (keypad, D-pad) | Pick a quick hack; during a challenge, the challenge inputs (Signal Lock adds **5** / Y) |
| Same key again, **Enter** or EXECUTE | Run the selected quick hack; **X** cycles the target; **T** typed commands |
| **C** / R1 / SHIELD button | Shield against an incoming hack |
| **Q** / gamepad X | Grounded **dash** (115 studs/s × 0.3 s ≈ 28 studs, 6 s cooldown) and a **skill check** |
| **Q** inside the skill-check zone | +1 diamond (two containers, bottom middle). One attempt per dash |
| **Q** while the dash cools | Spend a diamond on **super-speed** (1 s, 74 studs/s, steerable); no diamond = soft tick |
| **Q** during super-speed | **Chain** the next super-speed (diamond left, ≥ 0.25 s after the last start) |
| **Space** with a wall at your side (or held when you arrive) | **Wall-run**: up the wall, along it, then down; ends at wall ends / corners |
| While wall-running | W / toward the wall = cruise; **S** (back along the wall) = brake; **away** from the wall = peel off; **Space** = wall jump (also ≤ 0.3 s after the run ends at a wall end) |
| FLING SELF (hack) | Launch with loose limbs, steer with WASD, hold **Space** while falling to glide; blue aura until landing |

**Key tuning (all `HackTune_<Group>_<Key>` overridable):**
| Group | Values |
|---|---|
| Move | RunSpeed 28; DashSpeed 115; DashSeconds 0.3; DashCooldown 6; CheckDelay 0.1; CheckSweepSeconds 0.6; **CheckZoneSeconds 0.11** (Rev 15m, was 0.07); CheckZoneEarliest 0.2; CheckLatency 0.04; SuperChargesMax 2; SuperChainMinGap 0.25; SuperSeconds 1.0; SuperSpeed 74 |
| WallRun | Speed 36; Seconds 4; ClimbSpeed 30 over ClimbSeconds 1; MaxSink 6; Reach 3.2; SideFacingMaxDot 0.5; JumpOut 40; JumpUp 50; EdgeJumpGrace 0.3; **Flow 1** (Rev 15m; 0 = Rev 15l feel) with EntryBlendSeconds 0.14, MaxEntrySpeed 52, SpeedSettle 18, BackBrake 40, MinCruise 16, PeelDot 0.6, PeelSeconds 0.12, PeelOut 16, ExitCarrySeconds 0.25, ForwardLeanDegrees 7, AnimRate 1.5 |
| FlingSelf | Up 90; Forward 42; SteerSpeed 24; GlideFallSpeed 28; MaxFlightSeconds 4; **AuraMaxSeconds 10** (Rev 15m) |
| Config | `ForceR6 = true` (prototype feature; see the deferred issue below) |

**Tested (solo Studio, one client, Rev 15m session 2026-11-17):** see §21.21 for numbers — skill-check A/B/baseline, display-vs-judge timing, chaining regression, wall-run entry / climb / brake / peel / exit / wall jump / dash hand-over, R6 silhouettes + cost, FLING SELF aura in 9 flight cases, Reduced Effects, dash distance and cooldown, Q spam, FLING TARGET, R6 dressing, saved-file parity 65/65.

**Not tested:** multiplayer / a second client (other players' view of silhouettes and the aura is server-relayed but unverified), real network latency, real touch / gamepad hardware, genuine shift-lock (Studio is Classic), keyboard number-key challenge input in this revision (code unchanged since Rev 15), owner feel of the Rev 15m wall-run and skill check.

**Deferred engineering concerns (owner, 2026-11-17 — documented, NOT resolved):**
1. **R6 isolation.** `Config.ForceR6` and `ForceR6.server.luau` are **not** gated to the prototype (`Workspace.WORLD_EXE_HackPrototype`). `Config.luau` is the one existing file this PR modifies. Syncing this tree into a production place would force R6 there. Must be gated or removed before any production integration.
2. **Skill-check network fairness.** The server judges Q on its own clock. Rev 15m draws the sweep on the server clock, but the press still travels to the server: in solo Studio the judged time was a constant ~50 ms after the drawn marker (15 fps unfocused Studio; partly frame quantization). Only a 0.04 s late tolerance absorbs this. Fairness at real internet latency is **unverified**; no lag compensation was added.

## 1. Scope and isolation
- **New code only**, active only when `Workspace.WORLD_EXE_HackPrototype == true`. Only the local prototype place sets it. In Place1 every new script returns immediately. **Exception (Rev 15c, deferred issue — see §0):** `ForceR6.server.luau` / `Config.ForceR6` are not gated.
- **No existing file is modified**, except `Shared/Config.luau` (one `ForceR6` flag, Rev 15c). ArchitectController, HUDController, AbilityController, UITheme, UIUtil, the services and the patches are untouched.
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
- **Player or NPC targets:** 3 ordered arrows chosen by the **hacker**, within 4.5 s, with up to 2 misses (no reset). *(Superseded input: since Rev 15 the inputs are number keys 1–4, not arrows — see §0.)*
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

## 11. Revision 5 — aim FLING with the mouse (2026-11-16)
**Owner:** "make it so when you fling on someone else or boss, you can fling them in the direction you move the mouse."

**How it works:**
- **When aiming is active:**
  - FLING is selected with a target;
  - the FLING challenge is running;
  - your FLING is in its warning window.
- **Direction:** the client projects the cursor onto the ground; the throw goes from the target toward the cursor.
- **Ground arrow:** a flat orange-red arrow (local only) runs from the target's feet along the aim, ending in a landing ring at the predicted throw distance (≈ 2·Up·Forward / g). It is a different colour from the yellow lane markers.
- **Sending:** the client sends `{op = "aim", dir}` when the aim changes by more than 4° (at most 10/s), plus a 1 s keep-alive.
  - The server accepts at most one aim per 0.08 s. Aim messages get no reply and do not use the input rate limit.
  - Invalid vectors (NaN, vertical, huge, wrong type) are dropped. Aims expire after 3 s.
- **Resolution:** the server reads the latest aim when the fling resolves, so the attacker keeps steering through the 1.0 s warning window. The boss fling uses it at challenge success.
- **No mouse (touch / gamepad):** no aim is sent, and the target is thrown straight away from the attacker (previous behaviour).
- **Logs:** the server logs `fling aim (x, z)` or `fling aim none -> away from attacker` for every fling.

**Results (solo Studio, real mouse and arrow keys; dummy moved to open ground):**

| Case | Server aim used | Actual throw direction | Distance / rise |
|---|---|---|---|
| Cursor left of target | (−1.00, 0.02) | (−1.00, 0.05) | 37.7 / 31.6 |
| Cursor moved during the warning window (window stretched to 4 s for tool latency) | (−0.93, 0.37), updated from (−1.00, 0.02) | (−0.90, 0.44) | 47.9 / 31.5 |
| Boss, Resistance Battle | (0.26, −0.97) | (0.23, −0.97) | 22.0 / 16.1 |
| 60 junk or spam aim messages, then a real request | — | the request was answered normally, not rate limited; no replies to the aim messages | — |

**Saved place:** 59/59 scripts match `src/`; hash 67A8E4B7…. Protected files: 9/9 unchanged.

**Not tested:**
- two real clients (a real player as the target);
- real touch or gamepad fallback (the Studio touch preview still has a mouse);
- whether free aim is fair in PvP (e.g. throwing someone off a ledge). This is an owner design question.

## 12. Revision 6 — flick after casting (2026-11-16, replaces rev 5's cursor-position aim)
**Owner (correction):** "no it should be in the direction the cursor moves after casting."

**How it works now:**
- **No aiming before or during the challenge.** Aims from before the cast are discarded.
- **Flick window:** after a FLING on someone else succeeds, the server sends `{op = "flick", target, boss, untilT}`.
  - Players and NPCs: the 1.0 s warning window (+0.12 s grace).
  - Boss: `HackTune_FlingTarget_BossFlickWindow`, default 0.6 s. The boss throw now happens at the end of that window instead of instantly.
- **Direction:** the direction the mouse **moves** during the window.
  - Only the last 0.25 s of movement counts, and it needs at least 14 px, so the latest flick wins.
  - Screen right = camera right; screen up = camera forward (flattened).
  - With a free cursor, the client samples cursor position each frame. With a locked cursor (shift-lock or camera drag), it uses raw mouse deltas.
- **Arrow:** at the target's feet, bright for your flick, dim for the default.
- **No flick:** thrown straight away from the attacker (also the touch/gamepad behaviour).
- **Unchanged from rev 5:** aim streaming, throttling, validation and the per-throw log line.

**Results (solo Studio; real arrow keys for the cast, then emulated mouse moves; windows stretched to 4 s / 3 s for tool latency):**

| Case | Server aim | Thrown | Distance / rise |
|---|---|---|---|
| Dummy, flick up (camera faces −Z) | (0.00, −1.00) | (−0.03, −1.00) | 49.5 / 31.6 |
| Dummy, flick up then left (latest wins) | (−1.00, 0.00) | (−1.00, 0.00) | 13.0 / 28.8 (aimed straight back at me; the dummy hit my character and dropped) |
| Dummy, no mouse movement | none | (1.00, −0.02), away from attacker | 52.3 / 31.5 |
| Boss, flick right (camera right = +X) | (1.00, 0.00) | (1.00, −0.09) | 27.0 / 16.1 |

**Notes and findings:**
- Emulated `moveTo` produced no `MouseMovement` deltas, so the first attempt fell back. Sampling cursor position per frame fixed it. A real mouse produces both.
- One flick threw DUMMY-A off the edge of the ground (it respawned). Throwing targets off ledges is now possible: an owner design question for PvP.
- **Saved place:** 59/59 scripts; hash 533A871E…. Protected files: 9/9 unchanged.

**Not tested:**
- a human flicking within the real 1.0 s and 0.6 s windows (only stretched windows were used);
- a real second player;
- locked-cursor (shift-lock) flicks;
- touch and gamepad.

## 13. Revision 7 — instant slide-throw (2026-11-16)
**Owner:** "I don't like the current feel of it on other's, i should be able to slide my mouse and they should immediately go in that direction."

**What changed:**
- **Warning moved to the cast start (FLING on players/NPCs only).** It goes up when the attacker *begins* casting, with no countdown and the banner reading "· being cast", so the defender reacts while the attacker types.
- **Instant throw:** after the cast, a flick window opens (`FlingTarget.FlickWindow`, 0.6 s). The client sends the *first* slide (≥ 16 px within 0.2 s) once, and the server fires the throw on receipt, in the same step.
- **No slide within 0.6 s:** thrown away from the attacker.
- **Defences** (shield / cover / dodge ring) are checked at the moment of the throw.
- **`Incoming.MinWarning` (0.5 s):** the throw never lands sooner than this after the warning appears, so a very fast cast plus slide still leaves time to react.
- **Cancelled or failed cast:** the warning is withdrawn (`incoming_result` "cancelled").
- **Safety:** `Incoming.MaxArmedSeconds` 25.
- **Boss:** fires on the first slide the same way (no warning, as before).
- **FREEZE:** unchanged (timed warning after the cast).

**Results (solo Studio):**

| Case | Result |
|---|---|
| Dummy, real arrow keys, then slide up | Slide arrived 0.27 s after the cast (tool gap); thrown in the same server step (1.5 ms); direction (−0.03, −1.00); 50.8 studs |
| Warning while casting | Shown from begin; capture 28 |
| Cancel mid-cast (Backspace) | `incoming_result` cancelled; 0 leftover warning parts |
| Dummy shields during the cast | deflected (the cast took 0.38 s, so the 0.5 s minimum warning applied) |
| Boss, slide right | thrown (1.00, 0.01), 21.3 studs, at once on the slide |
| No slide, real 0.6 s window | thrown away (1.00, 0.00) exactly 0.60 s after the cast |

**Saved place:** 59/59 scripts; hash A7A1C5FD…. Protected files: 9/9 unchanged.

**Findings:**
- **Perfect deflect is now harder to time:** the throw moment depends on the attacker's slide, not on a visible countdown.
- **Warning length grows with cast time:** slow casters give targets more time.
- **Arrow row fix confirmed on desktop:** the capture shows "RIGHT" under the arrow, clear of the timer bar (pending since milestone 2).

**Not tested:**
- a human sliding at real speed;
- a real player as the target (two clients);
- shift-lock;
- touch or gamepad.

## 14. Revision 8 — owner clip review: low sideways slide-throw; ring dodge removed (2026-11-16)
**Source:** an owner screen recording with voice, 89 s. I reviewed 382 extracted frames (headless Blender) and a rough offline transcript (Windows System.Speech; low confidence). The interpretation was confirmed by the owner through three multiple-choice questions.

**Findings from the clip:**
1. **Throws read as "up", not "where I slid".** The no-slide throw is Up 112 / Forward 32 (about 74° from horizontal), so even correct slides looked like vertical launches.
2. **The ring made a hack fail.** At 8–12 s the patrolling dummy walked out of its warning ring while the owner typed the arrows, and the fling was dodged. The owner said, roughly, that he doesn't like it "to be countered by getting out of the circle".

**Owner decisions (2026-11-16):**
- **Slide-throw:** mostly sideways with a low arc. Players/NPCs use `AimedUp` 50 / `AimedForward` 80; the boss uses `BossAimedUp` 40 / `BossAimedForward` 55. A throw with no slide keeps the tall reference launch.
- **Ring:** removed for **all** hacks. `evaded_dodge` no longer exists, and the ring visuals are gone. Defences are SHIELD and breaking line of sight behind cover.
- **Gesture:** unchanged — just slide the mouse after the cast.

**Results (solo Studio):**

| Case | Thrown | Rise |
|---|---|---|
| Dummy, slide left | (−1.00, 0.02), 75.8 studs (flight plus ground tumble) | 6.6 |
| Dummy, slide right | (1.00, −0.06), 56.7 studs | 6.5 |
| Boss, slide right | (1.00, −0.10), 46.4 studs | 4.2 |
| Dummy walks away during the cast ("dodge" reaction) | **hit**; no slide, so the tall default throw | 32 |

- No ring parts were drawn during a cast (0 found).
- **Saved place:** 59/59 scripts; hash 497A1EBC…. Protected files: 9/9 unchanged.
- **Capture:** burst sheet `evidence/ui/m6_slide_right_sheet.jpg` (low arc across the screen).

**Notes:**
- The test-station "dodge" dummy reaction still walks away, but no longer evades. It is kept so the "walking does not dodge" case can be checked.
- Slide distance is tunable live (`HackTune_FlingTarget_AimedForward` / `AimedUp`). The ground tumble roughly doubles the flight distance on flat ground.

**Owner decision (2026-11-16):** slide-throw distance (57–76 studs incl. tumble) "Feels right"; AimedUp 50 / AimedForward 80 kept.

## 15. Revision 9 — banana-peel style GLIDE for slide-throws (2026-11-16)
**Owner:** "the fling still feels like an explosion and less like the player getting sent in the direction of the cursor"; reference: the banana peel item in another Roblox game.

**Research:** public pages only describe that item as a trap that trips the victim; none describe the motion, and the game's Fandom wiki and NamuWiki blocked automated reading. The owner chose to have my own interpretation built ("build the glide"); it was not matched to a clip.

**Built:**
- **Style switch:** slide-throws now default to `FlingTarget.AimedStyle = 1` (GLIDE). TestStation pads "Slide-fling: GLIDE / LAUNCH" switch it live, and the board shows the current style.
- **Glide (`ragdollGlide`):** the target goes limp, drops flat on its back with its feet leading in the slid direction, and slides along the ground.
  - **Speed:** a plane `LinearVelocity` drives it at `GlideSpeed × (1 − t/GlideSeconds)^1.6` (85 / 1.8 s; boss 55 / 1.3 s).
  - **No spin:** an `AlignOrientation` keeps the body flat.
  - **Ledges:** only horizontal motion is driven, so the target can fall off ledges.
  - **Recovery:** it gets up `GlideRestSeconds` (0.6) after stopping.
- **No explosion:** no launch burst, crater or camera kick. Clients draw a light dust scuff (≤ 30 puffs) under the sliding body instead.
- **Shared setup:** the ragdoll setup was split out into `ragdollBegin`, used by both the launch and the glide.
- **Unchanged:** a no-slide throw keeps the tall reference launch.

**Results (solo Studio, real arrow keys plus emulated mouse slide):**

| Case | Result |
|---|---|
| DUMMY-A, slide left | slid 60.9 studs at (−1.00, 0.00); max rise **0.3** studs; lay flat within ~0.2 s; stood up afterwards with no leftover constraints |
| Boss, slide right | slid 28.3 studs at (0.97, −0.24); max rise 0.4; re-homed after recovery |

- **Capture:** `evidence/ui/m7_glide_sheet.jpg` (flat body skidding left with a dust trail). The dust was lightened after this capture.
- **Saved place:** 59/59 scripts; hash BAD09D7B…. Protected files: 9/9 unchanged.

**Not tested:**
- the LAUNCH pad in play (it uses the unchanged rev 8 code path);
- a real player as the glide target (client physics ownership is handed to the server as for the launch);
- a human feel test.

## 16. Revision 10 — FLING as a gravity-gun grab (2026-11-16)
**Owner:**
- "i kind of want the fling to feel almost like the gravity gun from g-mod";
- "there's too small of a window to choose a direction, it just looks like you execute the hack and the player gets exploded into the air".

**Owner choices (multiple choice):**
- **Hold spot:** the held target follows the cursor.
- **Throw:** left-click throws it the way you're dragging; a faster drag throws harder.
- **Hold time:** up to 3 s, then an auto-throw.

**Built (`FlingTarget.AimedStyle = 2`, the new default; station pads GRAB / slide GLIDE / slide LAUNCH):**
- **When it lands:** players/NPCs are grabbed as soon as the incoming warning resolves as a hit (it still went up at cast start, with MinWarning 0.5 s); the boss is grabbed on challenge success. The target goes limp (`ragdollBegin`).
- **The hold:** an `AlignPosition` (MaxVelocity 70, Responsiveness 18) pulls the target to a server-validated hold point:
  - the attacker's cursor ground point,
  - clamped to `HoldLeash` 32 studs from the attacker,
  - `HoldHeight` 7 studs above the ground under it (×1.3 for the boss).
- **Client during the hold:**
  - sends `{op = "hold", pos, dir}` about 20 times a second (own 0.04 s throttle, no reply, outside the input rate limit);
  - when the cursor is in the sky, uses a point along the cursor direction at leash distance;
  - shows an orange beam from the wrist device to the glowing (Highlight) limp target, plus a throw arrow;
  - shows the hint "DRAG TO AIM · CLICK TO THROW".
- **The throw:**
  - **Left-click** (or R2) sends `{op = "throw", dir, power}`. The direction is the last 0.2 s of mouse drag (screen → camera-relative ground direction); the power comes from drag speed (300 → 1800 px/s maps to 0 → 1).
  - **Server velocity:** `dir × (ThrowSpeed 65 + power × ThrowBonus 35) + up ThrowUp 22` (boss ×0.6), then the normal land-and-recover ragdoll and a short throw trail. No blast.
  - **No drag at click:** thrown straight away from the attacker.
  - **Auto-throw** after `HoldSeconds` (3) uses the last dragged direction.
- **Attacker dies or leaves:** the target is dropped.
- **Boss:** its post-fling re-home now waits for the whole hold (it used to give up after 8 s and re-anchor the boss mid-hold).

**Results (solo Studio):**

| Case | Result |
|---|---|
| Dummy, real mouse | Held 5–7 studs up beside the cursor (capture `m8_grab_held_left.jpg`: limp glowing dummy, curved beam from the wrist). Real left-click while dragging right → thrown (1.00, −0.03), 42 studs, peak +1 |
| Hold point | Followed the cursor (hold messages logged on the server, about 20 per second) |
| Boss, scripted hold points | Swept x 462 → 426 at y ≈ 9.5, thrown on command, re-homed afterwards |
| Default 3 s hold, no input | Auto-thrown after 2.93 s |
| Power (old 70/50 tuning, with tumble) | Still click ≈ 42 studs; auto (0.4) ≈ 81; full drag ≈ 119. Trimmed afterwards to 65/35; the new values were not re-measured |

- **Fixes found while testing:**
  - a cursor in the sky sent no hold point;
  - drag power read 0 with burst input (now measured over the time the samples span);
  - the throw click is caught by both the action binding and `InputBegan`.
- **Saved place:** 59/59 scripts; hash FDA6D9BD…. Protected files: 9/9 unchanged.

**Not tested:**
- you playing at real speed;
- a real player being held (server takes physics ownership, same as the ragdoll);
- touch and gamepad (no hold steering; the target is auto-thrown away after 3 s; R2 throws);
- the trimmed throw values.

## 17. Revision 11 — throw directions limited; 2 s hold (2026-11-16)
**Owner:**
- "fling directions should only be sideways, backwards and upwards";
- "cut it's duration to 2 seconds";
- backwards means "behind me" (confirmed after a clarifying question).

**Built:**
- **Four throw modes only**, classified on the client from the drag direction:
  - drag **up** → `up` (straight up, `UpThrowSpeed` 90 + power × 30);
  - drag **left/right** → that **side** (`ThrowSpeed` 65 + power × 35, up 22);
  - drag **down** → `back`: over and past the attacker, landing behind them (`BackThrowUp` 45 so it clears the attacker's head).
- **No drag at click:** up. Auto-throw: the last dragged mode, else up.
- **Server-enforced:** directions are computed on the server from attacker → target geometry, and the client only sends a mode name. Anything else (e.g. "forward") becomes `up`, so a target can never be thrown forward or away from the attacker.
- **Arrow:** the throw arrow at the held target shows the current mode (vertical for up). The hint reads "DRAG UP · SIDEWAYS · DOWN (BEHIND YOU) — CLICK TO THROW"; words are used because arrow symbols can render as boxes. The chip text was updated.
- **Hold:** `HoldSeconds` 3 → **2**.

**Results (solo Studio; positions measured relative to the attacker):**

| Throw | Result |
|---|---|
| up | peak rise 27.8; lands about 4 studs from where it was held |
| right | 76.6 studs to the right |
| left | 24.4 studs left (stopped early; it probably hit the height-lane platforms on that side) |
| back | 83 studs past and behind the attacker; peak +5 above the 7-stud hold height |
| invalid "forward" | server used `up` |
| no input | auto-thrown `up` after exactly 2.00 s |
| **real mouse**, drag down then click | classified `back`; landed 63 studs behind the attacker (capture `m9_grab_drag_down_back.jpg`) |

**Saved place:** 59/59 scripts; hash 470C3A66…. Protected files: 9/9 unchanged.

## 18. Revision 12 — aim from the screen centre; limited hold movement (2026-11-16)
**Owner:**
- "I like that the fling activates on clicking";
- "I don't think that you should be able to move them around as much … before clicking";
- "instead of just going off the last direction the mouse moved, it should go relative to the center of the screen".

**Built:**
- **Throw mode from the cursor's position relative to the screen centre at the click:**
  - above → up; left/right → that side; below → behind you (over your head);
  - within 40 px of the centre → up;
  - power = distance from the centre (40 px → 0, 45 % of the short screen side → 1).

  Mouse-movement (drag) sampling was removed.
- **Reticle:** shown at the screen centre while holding — a dot plus UP / LEFT / RIGHT / BEHIND, with the active zone lit coral. Hint: "AIM FROM THE CENTRE · CLICK TO THROW". The chip text was updated.
- **Limited hold movement:** the held target now only sways up to `HoldWiggle` (4) studs from its lifted grab point, leaning toward the cursor. It is no longer carried around within a 32-stud leash.
- **Server-side protections from rev 11 are unchanged:** only up/left/right/back, computed from attacker → target geometry; 2 s hold.

**Results (solo Studio):**

| Check | Result |
|---|---|
| Reticle with cursor right of centre | RIGHT lit, throw arrow pointing right (capture `m10_reticle_right.jpg`) |
| Zone maths on fixed screen points | centre → up p0; top → up; bottom → behind; far left/right → left/right p1.00; slightly right → right p0.37 |
| Sway limit | hold points sent 30 studs sideways for the whole hold → the target moved at most 3.5 studs from its grab point |
| Auto-throw | at 1.97 s, in the cursor's zone (right) → 67.5 studs right |

**Real-mouse clicks:** these could not be verified this time. The physical Windows cursor sat over the Studio window and overrode the emulated cursor (`GetMouseLocation` read positions that were never sent), so one click registered as "back". The zone code path is the same as the verified maths.

**Saved place:** 59/59 scripts; hash 8A3BE422…. Protected files: 9/9 unchanged.

**Known limitation:** with shift-lock or a held right-click camera drag, the cursor is locked at the centre, so every click throws up. A keyboard/gamepad zone selection is not built.

## 19. Revision 13 — throw zones split by the screen diagonals (2026-11-16)
**Owner:** "imagine a point in the center of the screen, from there draw 4 lines from the center to the corners of the screen, this should separate it into 4 separate regions. Each one corresponding to a direction."

**Built:**
- **Classification:** the cursor offset from the centre is normalised by the half-screen size (`nx = dx / (W/2)`, `ny = dy / (H/2)`). If `|ny| ≥ |nx|`, the cursor is in the top triangle (up) or the bottom triangle (behind); otherwise it is in the left or right triangle. These are exactly the four triangles cut by the corner-to-corner lines; rev 12's 45° split was only correct on a square screen.
- **Centre:** within 6 px of the centre = up.
- **Power:** `max(|nx|, |ny|)` — 0 at the centre, 1 at the screen edge.
- **Drawn zones:** while holding, a separate full-screen GUI (ignoring the top-bar inset, so its centre is the camera centre used by the maths) draws the centre dot, four faint lines to the corners, and UP / LEFT / RIGHT / BEHIND YOU labels, with the active one lit.

**Results (solo Studio, 1914 × 761 viewport):**
- **Fixed points:**
  - centre → up;
  - just above the top-right diagonal → up; just right of it → right;
  - (75 %, 20 %) → up (rev 12's 45° rule said right);
  - (25 %, 85 %) → behind; (10 %, 50 %) → left; (50 %, 95 %) → behind.
- **Capture:** `m11_corner_zones.jpg` shows the four corner lines, UP lit, and the held dummy with its up arrow. The LEFT label sat under the wrist panel, so the side labels were moved to 28 % / 72 % (after this capture).
- **Saved place:** 59/59 scripts; hash 33BFE866…. Protected files: 9/9 unchanged.

**Rev 13a (owner, 2026-11-16):** "they shouldn't be visible, that was just for you to understand". The zone lines, labels and centre dot are now hidden. They remain only as a Studio debug aid: set the player attribute `WORLD_EXE_ShowThrowZones = true` to draw them. The classification is unchanged and was checked during a hold (overlay disabled; zone still classified as `up`). Saved place: 59/59 scripts; hash 31F6E2C5…. Protected files: 9/9 unchanged.

## 20. Revision 14 — remote-hack shock instead of explosion and levitation (2026-11-16)
**Owner:** "the explosion sfx is throwing me off as well as the player levitating upon executing, this should replicate the feel of hacking someone remotely. the enemy should be stunned as if they're actively being electrocuted or shocked. so ragdolled but still stood upwards."

**Built:**
- **Shocked in place:**
  - `HoldHeight` 7 → 0 (no lift); `HoldWiggle` 4 → 0 (stays put);
  - the root is set upright (yaw kept) and held there by an `AlignOrientation`;
  - limbs stay ragdolled and convulse: every 0.07 s each limb gets a random spin (`ShockJitter` 9 rad/s).
- **Sound:** the hit cue is now an electric zap (six rapid high-pitched clicks) instead of `impact_explosion`. While held, a 3D crackle (random high-pitch clicks every 50–110 ms) plays at the target. Built-in sounds only.
- **Visuals:**
  - a jittery cyan/white electric arc from the wrist (curves re-randomised every 2 frames), replacing the orange gravity beam;
  - a flickering cyan glow;
  - short neon sparks crawling over the body;
  - a cyan throw trail.
- **Throw hint:** the arrow on the held target is now a small thin cyan arrow; the old large orange-red arrow filled the screen when pointing at the camera.
- **Unchanged:** click to throw (corner-diagonal zones), 2 s hold, server-enforced modes.

**Results (solo Studio; hold stretched for tool latency):**

| Check | Result |
|---|---|
| Height during the hold | root y 3.00–3.02 (standing height 3.00): no levitation |
| Upright | minimum UpVector.Y 0.95 |
| Horizontal drift | 0.00 studs |
| Convulsions | arm spin up to 12.1 rad/s |
| Auto-throw | 64.7 studs; the dummy then stood up (Running) with 0 leftover constraints |

- **Captures:** burst `m12_shock_sheet.jpg` (taken before the arrow was shrunk).
- **Saved place:** 59/59 scripts; hash 9CCF3C2A…. Protected files: 9/9 unchanged.

**Not tested:** how the crackle and zap sound to a person.

**Owner feedback (2026-11-16):** "i'm impressed it looks good for now". Rev 14 (remote-shock grab) is accepted for now.

## 21. Revision 15 — movement, number-key hacking, longer FLING ragdoll (2026-11-16, owner-authorized)

Scope is the owner-authorized "AUTHORIZED MOVEMENT & HACKING REVISION, Rev 15" directive. Rev 14's remote-shock grab, click-to-throw and corner-diagonal zones are kept unchanged. Development stops after Rev 15.

### 21.1 Reference → implementation (owner videos, SHA-256 verified before review; original interpretations)

| Ref | SHA-256 | Segments used | Mechanics taken | Implemented as | Gameplay evidence | Deviations |
|---|---|---|---|---|---|---|
| MOV-01 | `21f33d2e…f93f57b` (MATCH) | 2.14–3.47 s, 9.74–10.41 s | abrupt start, streak look, fading afterimages, quick return | instant super-speed start cue; translucent **violet** afterimage chain (not the source's red/pink); 0.15 s ease back to run speed | `super_burst_sheet.jpg`, `super_burst/b_01.jpg` | no character, branding or combat taken |
| MOV-02 | `933a047b…6d4650` (MATCH) | 1.07–2.40 s, 22.67–24.00 s (menus ≥25.6 s ignored) | ~1 s steerable bursts, sharp jukes, drain gauge, dust, speed lines | second Q = 1.0 s super-speed at 74 studs/s, turn rate 14 rad/s, pooled dust, violet foot streaks, +9° FOV, bottom-centre drain gauge | trace: −Z, then a W+D diagonal turn in < 0.1 s at a constant 74 studs/s | exact pace not copied (values are tuning) |
| MOV-03 | `cebfa6c1…89f5a007` (MATCH) | 2.00–6.27 s (menus ≥7.7 s) | fast baseline run; wall-running later | WalkSpeed 16 → 28; subtle cyan foot streaks above 22 studs/s; sparse dust; +3° FOV at full run | WalkSpeed = 28 measured | **wall-running is architecture only** (MoveState) |
| MOV-04 | `c7f07092…b2e8` (MATCH) | 0.53–2.80 s (≥4.0 s ignored per owner) | short, low, grounded dash with dust | first Q = 0.17 s horizontal-only dash (≈10–12 studs), three dust puffs, short whoosh | dy range 0.01 studs | ending (flash/debris) ignored |

### 21.2 Movement (server `MovementService`; client `MovementController` + `MoveState`)

- **Server-authoritative Q:**
  - The client only reports a press (`{op="q", n}`), with a sequence number for replay protection.
  - The server decides between dash and super-speed and keeps both cooldowns, keyed by Player so a respawn cannot reset them.
  - Q is rejected while frozen, ragdolled or dead.
  - The client executes the motion with a plane `LinearVelocity` (horizontal only; Y stays physical).
- **Timing:**
  - Second Q earlier than **0.2 s** after the dash: **void**. The window is gone, so spam can never activate super-speed.
  - **0.2–0.8 s:** super-speed, if its cooldown is ready.
  - **Later:** a fresh dash.
  - Dash cooldown 0.6 s; super-speed cooldown **11 s** (starts at activation).
- **Ownership:**
  - `MoveState` gives a single owner of the local velocity: nil (run), `dash`, `super`, `flingSelf`, and a future `wallrun`.
  - FLING SELF force-claims ownership, and MovementController stops its drive.
- **Feedback and performance:**
  - Afterimages (96 parts) and dust (24 balls) come from fixed pools; foot trails are created once per character and toggled.
  - Other players' super-speed and dash are drawn from the character attributes `WORLD_EXE_SuperUntil` and `WORLD_EXE_DashUntil`.
  - Reduced Effects removes afterimages, dust, trails and FOV changes; sounds and the gauge stay.
- **Q binding:** Q / ButtonX at `High` priority in the prototype only. It sinks the main game's PHASE_DASH binding there.
- **Wall-run integration points (not built):**
  1. Claim `MoveState("wallrun")`.
  2. Read the wall normal.
  3. Drive along the wall plane.
  4. Release on exit.
  - Dash and super-speed never assume the character is grounded.

**Results (solo Studio):**

| Test | Result |
|---|---|
| Q, then Q at +0.40 s (client) | server +0.533 s → SUPER |
| Q Q at +0.13 s; 8 presses ≈0.13–0.2 s apart (spam) | "too early → window voided"; **no super-speed** |
| Q, then Q at +1.13 s | two dashes |
| In window while cooling | "super cooling (8.7 s)" → dash only |
| Dash | 10.2–11.4 studs, top speed 70–75, dy 0.01 |
| Super-speed | ≈0.92 s, 74 studs/s; steering verified after a sign fix (21.7) |
| FLING SELF during a stretched dash | owner dash → flingSelf → nil; 0 leftover drives; no ragdoll |
| Reduced Effects ON | super ran; ghost/dust counters unchanged; FOV stayed 70 |
| Pools | 120 effect parts constant; +8 transient instances (sounds) |
| Frame time | 66.6 ms avg in both baseline and super (Studio throttled the unfocused window to ~15 fps, so this shows no relative change, not absolute fps) |

### 21.3 Number-key hacking

- **Symbols:** "1"–"4" for Sequence, Resistance Battle and Input Chase; "1"–"5" for Signal Lock (advanced).
  - Server-randomized; `Challenge.Symbols` per kind.
  - `VALID` = 1–5; the snapshot carries `symbols`.
- **Inputs:**
  - Keys 1–5 and Keypad 1–5.
  - D-pad Left / Up / Right / Down = 1 / 2 / 3 / 4; ButtonY = 5.
  - Touch pad buttons 1–5, with 5 hidden when `symbols` = 4.
  - The challenge binding is `High + 20`, above the quick-chip number keys (`High`), so an active challenge wins. With no challenge active, 1–4 still select chips.
  - Mouse and camera stay free (corner panel).
- **UI:** big digits replace arrows; the current/done/wrong/missed states keep their non-colour cues.
- **Unchanged:** typed commands, token and replay protection, and rate limits.

**Results:**
- **Sequence (real number keys on Dummy-A):** 3 ✓, a deliberate 1 → MISSES 1/2, then 4, 3 → success → incoming → hit. The panel stayed on FREEZE, so quick chips did not fire.
- **Resistance Battle (real keys 1-2-2-3 on the boss):** progress 0.25 → 0.42, no misses. The live boss then interrupted it with SWEEP, which is intended.
- **With the Studio-only `HackTest_BossPassive` switch (scripted presses through the same remote):**

| Challenge | Result |
|---|---|
| Signal Lock | success, symbols 5 |
| Resistance Battle | success, 6 presses |
| Input Chase | success, 1 deliberate wrong press |

- **Captures:** `num_seq_wrong.jpg`, `num_resistance.jpg`, `num_signallock.jpg`.

### 21.4 FLING TARGET post-throw ragdoll

- **Timing:** recovery is measured **from the throw**. The target stands up only when `PostThrowSeconds` has passed **and** the torso is grounded and settled (speed < 6 for 0.15 s). The hard cap is 5.5 s, and `recover()` lifts the body 1.5 studs so it cannot be trapped.
- **Phases:** `HackFlingPhase` goes held (shock) → launched → down → nil.
- **Landing impact:** broadcast once, on first ground contact:
  - a low dust ring;
  - 5–12 cyan residual sparks;
  - a 3D body thud (`action_jump_land` at 0.62 pitch).
  - There is no explosion audio and no camera shake. Reduced Effects keeps only the thud.
- **Boss re-home wait:** now uses `max(MaxRagdollSeconds, PostThrowCap)`.
- **Default:** 3.0 s.

**Measured (Dummy-A, flat ground, power 0.6; the "Rev 14" column applies Rev 14's rule `max(1.2, air + 0.9)` to the same flight):**

| Mode | Rev 14 (derived) | 2.5 s | 3.0 s | 3.5 s |
|---|---|---|---|---|
| side (right) | ≈1.45 s | 2.55 s (air 0.55, down 2.00) | 3.03 s (air 0.53, down 2.50) | 3.53 s (air 0.63, down 2.90) |
| up | ≈2.04 s | 2.55 s (air 1.14, apex 29.5) | 3.00 s (air 1.12) | 3.55 s (air 1.15) |
| back | ≈1.47 s | 2.57 s (air 0.57, 54.5 studs) | 3.02 s (air 0.55) | 3.57 s (air 0.57) |

**Edge cases (3.0 s), all ended "settled", upright, Running, with no overlaps:**

| Case | Result |
|---|---|
| Off the 12-stud ledge (Dummy-C) | 3.02 s; finished on the ground at y = 3 |
| Thrown into the cover wall from 8 studs | 3.07 s; bounced back 2.5 studs, not embedded |
| Up-throw from the slope | 3.03 s; slid 13.5 studs off the slope and stood up |

- **Captures:** `fling_burst_sheet.jpg`, `fling_throw_land_sheet.jpg` (distant camera; the numbers above are the primary evidence).

### 21.5 Counterplay (Dummy-A as a stand-in attacker via `SimulateIncoming`; window stretched for tool latency)

| Case | Result |
|---|---|
| Q dash west behind `WallBehindA`, +0.13 s into a 15 s window | **evaded_cover** |
| Same, dashing east into open space | **hit**: no immunity from dashing |
| SHIELD (C) raised at +0.11 s of a 4 s window | **deflected** |

- An 8 s window let the 6 s shield expire before resolution. That is a test artifact, so I retested with the 4 s window above.
- The circle dodge was not reintroduced, and reaction timing was not changed: there is no solo evidence yet that fast running makes hacks too hard to land; this needs two-client play.

### 21.6 Shift-lock throw aiming

- **Unlocked cursor:** screen corner-diagonal zones (Rev 13/14).
- **Locked cursor (shift-lock or first person, `MouseBehavior ≠ Default`):**
  1. The movement intent in camera space (`Humanoid.MoveDirection`) picks the zone: W = up, A = left, D = right, S = behind, at 0.8 power. The same path covers keyboard, gamepad stick and the touch thumbstick.
  2. With no movement, a virtual cursor accumulates this hold's mouse deltas.
  3. With neither, the throw goes up.
- **Why this scheme wins:** while locked, mouse movement also turns the camera, so a mouse-only aim would spin the view during the 2 s hold. Movement keys are always available and readable.
- **Bug found and fixed:** `IsKeyDown` polling missed emulated keys, so it now reads `MoveDirection`.

**Matrix (shift-lock state forced by `MouseBehavior = LockCenter`, because the Studio user's ControlMode is Classic and account settings were not changed):**

| Mode | Input | Scheme | Zone | Thrown |
|---|---|---|---|---|
| locked | none | virtual | up | — |
| locked | D | keys | right | — |
| locked | S | keys | back | — |
| locked | W | keys | up | — |
| locked | A + left click | keys | left | **left p0.80** |
| unlocked | cursor right of centre + click | screen | right | **right p0.72** |
| locked | mouse slide | virtual | — | **untested** (emulated mouse sends no delta) |
| gamepad / touch | stick | keys | — | **untested** (no hardware) |

### 21.7 Bugs found during testing

- **Super-speed steering sign:** steering turned the long way round. Fixed in `MovementController`.
- **Test harness:** my scripted solver started `n` at ≈5000, which replay protection correctly rejected. The server is unchanged.
- **Test tooling:** `hp_30_client_testkit` "wrong" map now covers digits.

### 21.8 Files and save

- **New:**
  - `MovementService.luau`
  - `Controllers/MovementController.luau`
  - `Controllers/MoveState.luau`
- **Changed:**
  - `HackCatalog` (Move group; Signal Lock Symbols; PostThrow keys)
  - `HackChallenges` (digits)
  - `HackService` (op `q`, MoveLog hook)
  - `HackEffects` (post-throw recovery, phases)
  - `ConductorPrototype` (cap; `HackTest_BossPassive`)
  - `HackController` (digits, MoveState, locked-cursor aim, land VFX)
  - `ArrowGlyph` (digit glyph)
  - `HackVfx` (LandImpact)
  - client entry
- **Saved place:** `WorldEXE_HackPrototype_2026-11-16.rbxlx`, SHA-256 `3c55bdc226310fb2a31166cdb7dcacdc56129aad5d4dfeacb00c95deee82964a`; 62/62 scripts match `src/` (re-saved after two comment-only edits; the test session ran on `423a8753…`, same code).
- **Backup:** `backup_pre_rev15/…_rev14.rbxlx` (`9ccf3c2a…`).
- **Protected files:** 9/9 OK.

**Not tested:**
- real two-client networking (latency, other players' afterimage replication, PvP counterplay);
- the shift-lock toggle itself (forced state used);
- gamepad and touch hardware;
- how the audio sounds to a person;
- absolute fps on a focused window.

### 21.9 Rev 15a — the up-throw also launches forward (owner, 2026-11-16)
Owner: "the upward fling should still launch the player forward".
- **Change:** the "up" mode now pushes the target **away from the attacker** (`-toMe`, i.e. forward from the attacker's view) at `UpThrowForward` 32 + power × `UpThrowForwardBonus` 10 studs/s, on top of the vertical `UpThrowSpeed` 90 + power × 30. It tumbles forward.
- **Throw hint:** the arrow tilts forward to match.
- **Other modes:** side and back are unchanged.
- **Measured (Dummy-A, power 0.5):**
  - apex 27.8 studs, air 1.15 s;
  - 50.8 studs horizontal (dx −42.5, dz −27.9, directly away from the attacker);
  - recovery 3.05 s, settled.
- **Saved place:** SHA-256 `6d571e9bc630a59832a3646bcf26b55d2f91a90ce080bc9ae0c51035650f029e`, 62/62. Protected files 9/9 OK.

### 21.10 Rev 15b — bigger dash, dash cooldown = half of super-speed, FLING SELF like the regular fling (owner, 2026-11-16)
The owner said: "the regular dash is not substantial enough to affect gameplay at all", "the self fling should resemble the regular fling more, but with less ragdoll and more control" and "make the dash half the cooldown of the super speed dash". Asked how much ragdoll, they chose **loose limbs in the air**.

- **Dash:**
  - `DashSpeed` 88 → 115 and `DashSeconds` 0.17 → 0.30.
  - Measured at 0.24 s: 19.3–20.7 studs (was 10–11), top speed 114–115, dy ≤ 0.02. At 0.30 s it is expected to be ≈25–28 studs; not re-measured.
- **Dash cooldown:** `SuperCooldown × DashCooldownRatio` (0.5) = **5.5 s** (was 0.6 s).
  - A Q during the cooldown gives a soft tick (`move_fx dash_cooldown`).
  - A thin cyan bar under the gauge fills while the dash recharges.
  - Measured: Q at +1.67 s was rejected (3.83 s left); Q at +6.27 s dashed.
- **FLING SELF** — same launch, look and landing as the regular fling:
  - the electric zap cue (not the old "boom");
  - a 0.35 s shock on the body (cyan glow flicker, crackle, sparks);
  - the cyan throw trail;
  - the regular landing impact (thud, dust ring, cyan sparks).
  - The old orange starburst, crater and camera kick are gone for FLING SELF.
- **Loose limbs, client-side (`Controllers/LooseLimbs.luau`):**
  - Only arm and leg joints go loose (12). Root, waist and neck stay powered, and the Humanoid state is unchanged, so steering and the upright body are untouched.
  - A launch spin kick plus light kicks every 0.12 s make the limbs flail (in free fall, free limbs otherwise barely move).
  - The limbs are restored on landing. If a real ragdoll takes over, the joints are handed to the server rather than restored.
- **Rig finding:** the owner's avatar has **no Motor6Ds**. Each joint is an `AnimationConstraint` plus a `…BallSocket` constraint.
  - Loose limbs and the server ragdoll (`ragdollBegin`/`recover`, also used by FLING TARGET on players) now handle both rigs.
  - FLING TARGET against such a player rig had never been tested: the dummies use Motor6Ds.
- **Two bugs found and fixed:**
  - Loosening limbs on the server at launch collapsed the flight to 2.2 studs. It moved to the owning client.
  - Freed limbs started at rest and dragged the body down (arms only gave 9.7 studs). Every part now gets the launch velocity.
- **Landing impact:** the server raycasts from the client-reported landing point (accepted within 25 studs of the server position), because the server's copy of a fast fall lags.
- **Measured (solo, owner's avatar):**
  - flight 20.0–20.3 studs high, 38.1–38.9 forward, 0.90–0.92 s air (unchanged from before loosening);
  - 12 joints loose, upright 1.00;
  - arm swing ≤ 20°, leg swing ≤ 47°;
  - all joints restored after landing (Running);
  - landing impact received.
- **Captures:** `selffling_burst/b_24.jpg`, `selffling_sheet.jpg`.
- **Saved place:** SHA-256 `89d2d572aaca578df49ff7c634735eba91e1b4d374069d0af519e2c04a2a2324`, 63/63. Protected files 9/9 OK.

**Not tested:**
- how other players see the loose limbs (two-client);
- FLING TARGET on a player using the AnimationConstraint rig;
- the 0.30 s dash distance (only 0.24 s was measured).

### 21.11 Rev 15c — everyone is forced to R6 (owner, 2026-11-16)
Owner: "make the game force R6 for everyone".
- **How:**
  - `Config.ForceR6 = true`.
  - `ForceR6.server.luau` puts an R6 rig in `StarterPlayer` as `StarterCharacter`, so every spawn (the engine auto-load and `PlayerStateService` LoadCharacter) is R6. The prototype place also has it saved.
  - Each player's own avatar description is applied to the R6 body with `ApplyDescription`, because the engine does not dress a StarterCharacter: the first test gave a bare R6 body.
  - A character that spawned R15 before the rig existed is reloaded once.
- **Publishing note (owner action, not done here):** also set Game Settings > Avatar > Avatar Type = **R6** on the published experience. `StarterPlayer.GameSettingsAvatar` cannot be set from scripts, and nothing was published.
- **Results (solo Studio, owner's avatar):**
  - rig R6 (Head, Torso, arms, legs);
  - the player's own accessories (4), shirt, pants and face applied;
  - wrist device on the left arm; run speed 28.
- **FLING SELF on R6:**
  - 4 Motor6Ds (shoulders and hips) go loose;
  - arm swing up to 82°, a clearer flop than R15's 20°;
  - upright 1.00; flight 20.5 high, 39.2 forward, 0.92 s;
  - joints restored; landing impact fired.
- **Dash (final 0.30 s):** 27.0 studs, top speed 115, dy 0.00. **Super-speed:** 71.1 studs in 1.00 s.
- **FLING TARGET on Dummy-A:** unchanged (side throw, 3.00 s, settled).
- **Saved place:** SHA-256 `1ef4e97be998e5834be099ba06eaa929d2c9686cc897cff849560bf497acdf9f`, 64/64. Protected files 9/9 OK. Production places untouched.

**Not tested:**
- other players' appearance on R6 (two-client);
- avatars whose `GetHumanoidDescriptionFromUserId` fails: they keep a plain R6 body;
- layered clothing on R6 (Roblox does not render it on R6).

### 21.12 Rev 15d — thrown targets look dragged by the torso (owner, 2026-11-16)
Owner: "the fling should look as if they're getting dragged by their torso in the direction they're flung too".
- **Built (`torsoDrag`, FLING TARGET throws only):**
  - At release the chest (UpperTorso / Torso) gets the full launch velocity. Every other part starts at 30% of the horizontal speed (`DragTrailStart`), and the tumble spin is gone.
  - For `DragSeconds` (1.1 s), through the air **and** the ground slide, the chest is pulled along the horizontal throw direction (LinearVelocity, line mode; gravity untouched). The pull eases to half speed.
  - The chest is snapped and held facing the pull, pitched 50° **into** it (`DragLeanDegrees`).
  - Non-torso parts are damped horizontally (7/s), so the legs trail.
- **First attempt:** the torso leaned **back**. The measurements showed the legs *ahead* of the torso (+0.6 studs), so the lean was flipped.
- **Measured (Dummy-A, R6, side throw, power 0.5):**
  - legs trail **1.8–1.9 studs** behind the torso from 0.12 s through the slide;
  - head leads by 0.7–1.0;
  - torso pitched into travel (up·travel ≈ 0.8);
  - recovery 3.02–3.07 s, settled.
- **Distances:**

| Throw | Before | Now |
|---|---|---|
| side | 72–78 studs | 84 studs |
| up (apex 27.5) | 51 studs forward | 34 studs forward |
| back | 57 studs | 85 studs |

- **Capture:** `drag_burst/b_29.jpg` (body horizontal, chest first, legs dragging, landing dust ring).
- **Tuning:** `HackTune_FlingTarget_DragLeanDegrees`, `_DragTrailStart`, `_DragTrailDamping`, `_DragSeconds`.
- **Saved place:** SHA-256 `13ee1c034c6e9fd49eca95f1cdfb698aa00fc7563aebaae90b0ac04c58607bdd`, 64/64. Protected files 9/9 OK.

**Not tested:**
- how the drag looks on a real player target over the network (the ragdoll is server-owned, so it should replicate like the existing ragdoll);
- R15 targets.

### 21.13 Rev 15e — super-speed looks like the owner's new reference (MOV-05, 2026-11-16)
Owner: a YouTube short (`youtube.com/shorts/dnXIFzKC2DY`) and "make the super dash look more like this".

**Reference intake:**
- Watched in the in-app browser by seeking through the 28 s clip; not downloaded, so no SHA-256 is possible. Recorded as MOV-05 in the vault register.
- What it shows, around 10–14 s and 17–19 s:
  - a dense chain of **full-detail copies of the character** (hair, face, clothes), packed almost shoulder to shoulder along the path, even curving around a target;
  - the copies linger briefly, then fade;
  - a strong **whole-screen colour tint** while active (green in the clip).
- **Taken:** the structure and timing. **Not copied:** the green palette (signature of the source franchise), the character, or the source's moves.

**Built (MovementController):**
- **Afterimages are now clones of the actual character**, replacing the old one-colour limb boxes:
  - each character's model is cloned 16 times on its first super-speed, with scripts, sounds, trails, constraints and joints stripped and every part anchored;
  - every 0.042 s the next clone is posed to the character's live part CFrames (≈2.5–3 studs apart at 74 studs/s);
  - each clone stays nearly solid, then fades over 0.65 s;
  - a Highlight tints it, shifting **cyan → violet** over the 1 s burst.
  - Workspace attribute `WORLD_EXE_SuperTint` (a Color3) overrides the tint, for example green.
- **Screen tint (local, while I am in super-speed):** a `ColorCorrectionEffect` blends the tint in fast and out over about 0.2 s (saturation −0.3, contrast +0.18).
- **Reduced Effects:** no clones and no screen tint.

**Results:**
- 16 clones per character, reused (≈20 spawned per burst);
- the chain renders with the face, hat and shirt textures visible;
- the screen grade turns on during the burst;
- capture: `clone_burst/b_09.jpg`.

**Limits:**
- Roblox renders at most 31 Highlights at once. One person in super-speed uses about 16, so two at the same moment may lose some tint.
- Other players see each other's clones; not tested with two clients.

**Bug fixed:** replacing the old afterimage block also removed the dust-pool variables, which broke MovementController on start.

**Testing note:** the Studio MCP resets camera changes made from an execute call, so captures pin the camera from a RenderStep binding instead.

**Saved place:** SHA-256 `c7bf4e297222e35d879d25f2b91392dc480f6cb2d53431dbd598364f82e634e6`, 64/64. Protected files 9/9 OK.

### 21.14 Rev 15f — super-speed colours: a mix of all (owner, 2026-11-16)
Asked whether to keep cyan → violet or switch to the reference's green, the owner answered "mix of all".
- **Change:** the afterimage chain cycles **cyan → neon green → violet → cyan**, 1.5 cycles per 1 s burst, so neighbouring copies differ and every colour shows. The local screen tint follows the current colour.
- The Workspace attribute `WORLD_EXE_SuperTint` still forces a single colour.
- **Capture:** `mix_burst/b_10.jpg` shows green, violet and cyan copies in one chain, with the tinted screen.
- **Saved place:** SHA-256 `78a95098d57d3d73ef22e96205280551c3610fbb78e9293510f2449d8fe7ca51`, 64/64. Protected files 9/9 OK.

### 21.15 Rev 15g — dash cooldown halved, super-speed chain + smoother, wall-running (owner, 2026-11-16)
Owner: "the dash cooldown should be half of what it currently is, the wall run still needs to be implemented and the super dash should feel smoother (also should be able to be used 2 times after initial activation". The only wall-run reference is MOV-03; the owner confirmed it.

**Dash cooldown:** `DashCooldownRatio` 0.5 → 0.25 of SuperCooldown, so 5.5 s → **2.75 s**. Verified: a dash at +5.07 s, the next at +8.38 s.

**Super-speed chain (server-authoritative, `MovementService`):**
- After the Q-Q activation the player holds `SuperFollowUps` = 2 extra bursts.
- Each fires with **one** Q:
  - during a burst, it is queued to that burst's end (only one can be queued, so mashing is guarded);
  - otherwise it must come within `SuperFollowWindow` 2.5 s after the burst ends.
- The 11 s cooldown starts when the chain ends: after the last burst, or when the window runs out unused.
- The gauge shows ◆ charges and a green follow-up window. A follow-up has a lighter cue and keeps the wind sound going.
- **Verified:** activation at +0.67; follow-up at +2.10 (after the burst); follow-up at +2.93 queued to the burst end; a mashed Q ignored; chain end at +4.12, then super ready 11 s later.

**Smoother super-speed:**
- eased ramp-in from the current speed (`SuperAccelSeconds` 0.14);
- exponential steering capped at 10 rad/s (`SuperSteerSmoothing` 7);
- eased return to run speed (`SuperEaseOutSeconds` 0.32);
- follow-ups continue in the current direction of travel.
- **Root cause of the "not smooth" feel:** the Rev 15e clone afterimages keep a Humanoid (for clothing), and Humanoids force their parts collidable every frame. The clones posed at the runner bumped them, so measured speed flickered 74 ↔ 28. Fixed with the `WORLD_EXE_Afterimage` collision group (registered by the server, collides with nothing).
- **Client trace after the fix:** 28→74 over ≈0.14 s, 74 held, eased 74→28 over ≈0.3 s, with 16 clones present.

**Wall-running (`Controllers/WallRun.luau`, MoveState "wallrun"; MOV-03: ~4 s along building faces at window height, wrapping around corners):**
- **Start:** airborne, moving, at least 18 studs/s, with a tall, collidable, non-character wall within 3.2 studs at the side or forward-diagonal. Head-on walls are excluded.
- **While running:**
  - carried along the wall at max(speed, 36) studs/s;
  - a short lift, then **level running**, then a sink in the last 0.6 s;
  - kept about 1.5 studs off the wall, body tilted 8°, run animation at 1.5×, dust at the feet;
  - **outside corners** turn onto the side face (a ≈2-stud step), **inside corners** onto the wall ahead.
- **Ends:**
  - Space = wall jump: out 40, up 50, along 75% of speed, then a 0.5 s horizontal carry. Roblox air control otherwise cancelled the push in about 0.25 s;
  - landing, the wall ending, letting go of the keys, or 4.0 s.
  - Dash, super-speed and FLING SELF can take over.
- **Verified:**
  - straight wall: 1.62 s / 58 studs at the old 1.6 s limit;
  - 24-stud block: **4.02 s, 6 corners**, height level at y = 9.2, wall gap 1.5–1.6 studs;
  - wall jump: run → jump → **latched onto the opposite wall** → a second run.
- **Test lane:** `tools/studio/hackproto/hp_21_wallrun_lane.luau` builds `HackProto.WallRunLane`, also saved in the place:
  - two 70×16 walls at x = 320 and x = 340 (z 15–85);
  - a 24×16×24 block at (330, 140);
  - checked to overlap nothing.

**Saved place:** SHA-256 `f00043470836310475dc38d6d6a9c32b2d10117b3aee28ccceea9fbdb8407cc2`, 65/65. Protected files 9/9 OK.

**Not tested:**
- how others see wall-running (two-client);
- gamepad and touch;
- wall-running on map geometry other than the lane.

### 21.16 Rev 15h — wall-run starts only on Space with the wall at your side (owner, 2026-11-16)
Owner: "the wall run should only be activated when the spacebar is pressed … and when the side of the player is facing the wall".

**Start rule:**
- Wall-running no longer starts automatically. It starts **only** on a fresh Space press (gamepad A or the touch jump button also count).
- Only when the wall is at the character's **left or right**: the character's facing is checked, |look · wall normal| ≤ `SideFacingMaxDot` 0.5.
- It works from the ground (lift `GroundStartUp` 22 to about window height) or in the air.
- `MinSpeed` is now 8 (just "moving"), because hugging a wall slows the runner.
- A held jump button repeats JumpRequest, so only a request after a 0.2 s gap counts as a new press.

**During a run:** Space wall-jumps. To latch onto the next wall you press Space again with that wall at your side.

**Verified (solo):**

| Case | Result |
|---|---|
| Running alongside the wall, no Space (1.1 s) | no wall run |
| Space with the wall at the side | starts from the ground, lifted to y ≈ 8 in 0.3 s |
| Space mid-run | wall jump |
| Fresh Space near the opposite wall | latched, second run |
| Facing the wall head-on + Space | normal jump, no wall run |

**Saved place:** SHA-256 `7adda4b8dd176d4f85dae688de7fa276300ffd94ac7b0cb9141be0354e895316`, 65/65. Protected files 9/9 OK.

### 21.17 Rev 15i — the wall-run climbs the wall, as in MOV-03 (owner, 2026-11-16)
Owner: "make the wall running more true to the reference i sent, you shouldn't just glide across the wall without moving upward".

**MOV-03 re-read frame by frame** (private frames f_0057–f_0193; detail sheets `refs/MOV-03_wall_detail_a/b.jpg`, not committed):
- On latching (≈1.9–2.1 s) the runner **runs up the wall**, from the sidewalk to near the purple building's roofline.
- They then travel along the face, gradually coming down past the window rows (≈2.4–3.2 s).
- On the blue building they climb again from street level to the second window band (≈4.6–5.2 s), then drop to the grass.

**Built (WallRun):**
- The vertical speed is now a **climb** of `ClimbSpeed` 30 (×0.75 when latching mid-air), smoothly easing to 0 over `ClimbSeconds` 1.0 (≈15 studs up).
- Then a **gentle descent** building at `Gravity` 9, capped at `MaxSink` 6 studs/s.
- At a wall's top edge (no wall `TopClearance` 2.6 above the root) the climb stops instead of running off the top.
- Replaces the Rev 15g "short lift then level" profile.
- **Test lane:** walls and block raised from 16 to 24 studs (2–3 storeys), so there is room to climb.

**Measured (Space start from the ground, 36 studs/s along the wall):**
- y 3.6 → 18.7 in 0.9 s, along with 32 studs of travel;
- then a steady descent of ≈6 studs/s, to y 8.0 by 3.1 s;
- it wrapped the wall's end (2 corners), ending when W was released.

**Saved place:** SHA-256 `9cdcda2b383313ba9f6b9de9bc57a6e53746837e7a32aedb04d564d751618c57`, 65/65. Protected files 9/9 OK.

**Not tested:** how it feels to the owner; behaviour on real map buildings.

### 21.18 Rev 15j — no corner wrapping; super-speed through a skill check and diamond charges (owner, 2026-11-16)
Owner: "the wall run shouldn't be able to take you around corners. Also, regarding the super dash, after hitting a regular dash, it should activate a skill check like the one that is already there, except it should be harder than that. And if you hit it, it fills up a bar … in the middle bottom of the screen, like an empty diamond, like two of them to be containers … and hitting Q while dash is on cooldown would activate the super dash."

**Wall-run:** no corner wrapping. The run ends at a wall ahead (inside corner), when the face ends (outside corner), or on a normal change over 25°; gently curved walls are still followed. Verified on the block: "wall_end" at the corner, 0 corners, after climbing 11 studs.

**Super-speed redesign (server-authoritative, `MovementService`):**
- **Q (dash ready):**
  - a grounded dash and a **skill check**;
  - the marker sweeps the bar in `CheckSweepSeconds` 0.75, starting `CheckDelay` 0.1 after the dash;
  - the target zone is `CheckZoneSeconds` **0.11** wide at a **random** spot (start between 0.2 and the end).
  - The old window was 0.6 s wide at a fixed spot, so this is much harder.
- **One Q during the sweep is the only attempt:**
  - inside the zone (−0.02 / +`CheckLatency` 0.08) = **hit**, +1 charge, capped at `SuperChargesMax` 2;
  - anything else = miss.
- **Q while the dash is cooling** (`DashCooldown` 2.75 s) after the check: **super-speed** (1 s, steerable, smooth) if a charge is stored, which uses it; otherwise a soft "no charge" tick and a small shake of the diamonds.
- **Removed:**
  - super-speed's own 11 s cooldown and the 15g follow-up chain (the diamonds are the gate now);
  - the old early/void logic (the check allows one attempt).
- **UI:** two diamond containers (outlined, empty) at the bottom middle, above the gauge; violet when filled, with a pop on fill. The gauge shows the target zone and the sweeping marker, then a "◆ +1" / "MISS" flash. Player attribute `WORLD_EXE_SuperCharges`.

**Verified** (zone fixed with live tuning for repeatable key timing, then reset to random):

| Case | Result |
|---|---|
| Dash, then Q at 0.50 s | HIT → 1 charge |
| Dash, then Q at 0.23 s | MISS |
| Q during cooldown | SUPER, 0 charges left |
| Dash, no hit, then Q | "no charge" |
| Three hits | charges capped at 2 |

- **Capture:** `check_burst/b_05.jpg` (empty diamonds, bar with zone and marker) and `diamonds_full_zoom.jpg` (two filled).
- **Saved place:** SHA-256 `31b4ac4af8643f32ea0e86c62750f1ee1a0f9b7cb805fb6ae81844617a6bfc27`, 65/65. Protected files 9/9 OK.

**Not tested:**
- whether 0.11 s is the right difficulty with a person's reflexes (tunable);
- gamepad and touch;
- two-client play.

### 21.19 Rev 15k — harder skill check, 6 s dash cooldown, held-Space wall-run, end-of-wall jump (owner, 2026-11-16)
Owner: "the skillcheck is too forgiving; if you miss the second skill and use the super dash, by the time the dash has ended, the regular dash is back on cooldown (this should not be the case …), also the wall run should be activated if the spacebar is already being held down by the time the player reaches the wall, also even at the end of the wall the player should be able to jump off from that point". Also: "6 second dash cooldown is fine".

**Skill check, harder:**

| Setting | Before | Now |
|---|---|---|
| Sweep | 0.75 s | 0.6 s |
| Zone width | 0.11 s | **0.07 s** |
| Late tolerance | 0.08 s | 0.04 s |
| Early tolerance | 0.02 s | none |

The zone is still at a random spot.

**Dash cooldown: 6 s** (was 2.75 s), so the dash is still cooling after a super-speed. Verified: dash at +7.33, missed check, super-speed at +8.77 (ends +9.77); Q at +10.37 → "no charge (dash cooling 2.97 s)".

**Wall-run:**
- **Held Space** also starts a run: airborne, with the wall at your side, while Space is held.
- After a run that did not end in a wall jump, Space must be released once before a held Space counts again. A held Space stays armed through wall-jump chains.
- **End-of-wall jump:** when a run ends at the wall's end, a corner, the wall ahead or the time limit, a jump press within `EdgeJumpGrace` 0.3 s still does the full wall jump from that wall.

**Verified:**
- holding Space + W → the run started at +0.43 s; it ended at the wall end and did **not** re-latch while Space stayed held;
- wall_end at +36.43, Space at +36.70 (0.27 s later) → wall jump from the end of the wall.

**Saved place:** SHA-256 `b923d2541d6ff270788eacea34069b0525df16943640d174cc1f1ccad1c7c34b`, 65/65. Protected files 9/9 OK.

### 21.20 Rev 15l — super-speed chaining (owner, 2026-11-16)
Owner: "super dashes should be able to be used in quick succession".

**Chaining:** pressing **Q during a super-speed** starts the next one at once if a diamond is left. The server allows it no sooner than `SuperChainMinGap` (0.25 s) after the last start, so one accidental double-tap does not spend both diamonds. With no diamond left, the press is ignored with the soft "no charge" tick. A chained burst plays a lighter start cue.

**Smooth hand-over:** a chained burst carries on from the previous burst's commanded speed and heading, with no ramp-up. Before this fix the velocity read after the old constraint was removed made a visible dip (74 → ~43 for about 4 frames).

**Verified:**
- server log: two hits → charges 2; SUPER at +0.00 (charges left 1); SUPER (chained) at +0.63 (charges left 0);
- client trace: speed ramps 28 → 74, stays at **74 through the hand-over**, then eases back to 28. That is about 1.6 s of continuous super-speed.

**Tuning:** `HackTune_Move_SuperChainMinGap`.

**Saved place:** SHA-256 `b93b40064f4a8c67c429d41c0eee552ce17f2db487061eac3f7ed7ae2e7acd1e`, 65/65. Protected files 9/9 OK.

### 21.21 Rev 15m — feel refinement, R6 silhouette afterimages, FLING SELF aura until landing (owner-authorized, 2026-11-17)
**Owner play-test of Rev 15l (authoritative):** skill check **too hard**; super-speed chaining **good**; wall-running **needs work**. Plus two new owner decisions: afterimages become simple coloured R6 silhouettes, and FLING SELF's blue effect must last the whole airborne journey.

**Baseline:** game `c1d74f6`; pre-Rev-15m place backup `place/backup_pre_rev15m/` SHA-256 `b93b4006…acd1e` (identical to the Rev 15l save). MOV-01..04 re-hashed: all MATCH the register (no re-download or re-extraction; existing private MOV-03 frames re-read).

#### Skill check
**Defect found and fixed (display alignment).** The client started drawing the sweep when the dash message *arrived*; the server judges from its own clock. Measured in solo Studio: every press was judged **82–83 ms later** than the marker showed. One press drawn *inside* the zone was judged MISS, and one drawn *before* it was judged HIT. Now the server sends `check.startAt` and the client draws on `GetServerTimeNow`. Re-measured: a constant **~50 ms** remains (the press's trip to the server; Studio unfocused at 15 fps, so largely frame quantization). The 0.04 s late tolerance covers most of it. **Not** lag compensation: the server still judges, and real-network fairness stays deferred (§0).

**A/B (zone pinned for repeatable key timing; emulated keys; display position read at each press):**
| Config | Zone / sweep | Share of bar | Server-judged hits | Misses |
|---|---|---|---|---|
| Rev 15l baseline (after the alignment fix) | 0.07 s / 0.6 s | 12 % | rel 0.482, 0.533, 0.567 | 0.450 (early), 0.633 (late) |
| **A (chosen)** | **0.11 s / 0.6 s** | **18 %** | 0.466, 0.484, 0.533, 0.584 | 0.401, 0.617 |
| B | 0.15 s / 0.7 s | 21 % (slower marker) | 0.516, 0.568, 0.650 | 0.449, 0.700 |

**Provisional choice: A.** Combined with the alignment fix it is clearly easier than what the owner played, but still a timing skill; B pushes toward trivial. B stays one attribute away (`HackTune_Move_CheckZoneSeconds=0.15`, `_CheckSweepSeconds=0.7`). Preserved and re-checked: random zone (starts 0.205 / 0.268 / 0.356 / 0.379 / 0.428 seen), one attempt per dash, 2-diamond cap, 6 s dash cooldown (next dash 6.23 s / 6.4 s later), "no charge" tick ("Q no charge (dash cooling 4.38 s)"), Q spam (3 extra presses during a super → "Q ignored (super running; charges 0)"). Observation, unchanged design: a spam press right after a hit spends that diamond on super-speed at once (Q while the dash cools = super).

#### Super-speed chaining (regression — unchanged code)
Server log, Rev 15m: `SUPER (charges left 1)` → `SUPER (chained)` 0.75 s later `(charges left 0)` → `Q ignored (super running; charges 0)`: same as Rev 15l. Client trace (commanded / measured): 28 → 74 ramp, **74 through the hand-over**, eased return to 28 (~1.7 s total). When the chain press lands inside the first burst's final 0.32 s ease-out, the hand-over carries 71 and returns to 74 within 3 frames (≤ 3 studs/s; the Rev 15l code path, which the Rev 15l test simply did not hit). Not changed (owner: preserve chaining exactly).

#### Wall-running "Flow" (`HackTune_WallRun_Flow`: 1 = Rev 15m, 0 = exact Rev 15l)
Rules unchanged (side-on Space / held Space, climb then descent, ends at wall ends and corners, wall jump, edge grace, no corner wrapping, no auto-adhesion). Changes are feel only:

| Aspect | Rev 15l (Flow 0, measured) | Rev 15m (Flow 1, measured) |
|---|---|---|
| Entry | along-wall 28 → 36 **in one frame** (+ climb 36) | 28 → 29 → 30 → 31 → 33 → 34 → 35 over ~0.14 s; vertical continues from the jump (36 → 30), no dip |
| Mid-air entry (held Space) | — | max per-frame change **3.7 studs/s** (vy 41 → 23 eased into the climb) |
| Entry momentum | always 36 | along-wall momentum kept up to 52, settles to 36 (dash hand-over: 94 → 52 over ~0.14 s) |
| Control while attached | only "let go" ends it | S = brake 36 → 16 in ~0.45 s; toward the wall = cruise (16 → 25 back up); away = **peel** off (out 16 + along 33) |
| Body | lean away 8° only | lean away 8° **and into the run 7°**; run animation rate follows speed |
| Exit at wall end | 31 → 28 at once (air control) | carries 32–33 for 0.25 s, then normal air control |
| Climb / distance | 15.2 studs, wall_end after 1.65 s | 15.1 studs, wall_end after 1.66 s (same rules) |
| Wall jump | — | velocity out 40 / up 51 on the same frame; caught the second wall with held Space, ran to its end |
| Dash → wall run | blocked until the dash ended | Space during a dash next to a wall hands over |
| FLING SELF → wall run | blocked until FLING control ended | Space mid-flight beside a wall hands over (aura continues, see below) |

Camera: default Roblox camera, untouched (no roll; the lean is the character only). Whether Flow *feels* right is the owner's call: compare with `HackTune_WallRun_Flow = 0`. One entry defect was found and fixed during the session: the first Flow build dipped the climb (vy 36 → 9 → 30) because it blended from a velocity sampled before the jump impulse.

#### Super-speed afterimages: lightweight R6 silhouettes
Each ghost = 6 anchored Neon parts (head ball, torso, 2 arms, 2 legs) sized from the runner's R6 limbs and posed from their CFrames when dropped (moved with `BulkMoveTo`). No Humanoid, clothing, hair, accessories, face decal, wrist device, animation, collision or queries (`WORLD_EXE_Afterimage` group). Start transparency 0.42 with a smoothstep fade over 0.55 s, one every 0.045 s, pool of 14 per character. Cyan → green → violet cycle and the screen grade are unchanged.

| Measure (solo Studio, same instrumentation) | Rev 15l clones | Rev 15m silhouettes |
|---|---|---|
| Instances per character pool | **1,671** (16 clone models × 25 parts + decals, accessories, 16 Humanoids, 16 Highlights) | **84 parts** (14 × 6), folder total 108 |
| Humanoids in afterimages | 16 | **0** |
| Pool build (first super-speed) | **25.9 ms** one-frame hitch | ≤ 6.0 ms (session max, includes the build) |
| Steady afterimage CPU (spawn + fade) | ~6 ms per second of super-speed | ~4 ms per second of super-speed |
| Max visible ghosts | 16 | 12 |
| Lifetime / interval | 0.65 s / 0.042 s | 0.55 s / 0.045 s |

Caveat: Studio frame rate differed between the two runs (15 fps unfocused vs ~60 fps), so per-frame numbers are not comparable; per-second and instance counts are. Solo client only: **multiplayer cost is not measured**. Reduced Effects: 0 visible ghost parts and no screen grade during super-speed (verified).

#### FLING SELF: blue aura for the whole flight
Cause: Rev 15b used the 1.0 s throw trail, and the landing / end message was tied to the movement controller, which can end in the air (wall hit, time limit). **Baseline measured:** high launch + glide (2.2 s airtime) → blue gone **1.25 s before landing**; even a short glide lost it 0.15 s early.

Now: launch shock (unchanged) + an aura (cyan torso trail, crackling sparks, soft light, faint flickering body glow) whose lifetime is the **visual flight**. The owner client ends the flight only on real ground contact (not while wall-running), death / ragdoll ("cancel") or `AuraMaxSeconds` (10 s), and sends exactly **one** `fling_self_end`. The server relays `self_fling_end` to everyone (aura off) and plays the landing impact only for `landed`. Each client also removes the aura on death / removal / 10 s. Reduced Effects keeps the trail only (verified). FLING SELF still never ragdolls; loose limbs unchanged.

| # | Case | Airtime | Aura gaps while airborne | Aura off vs landing | Landing impacts |
|---|---|---|---|---|---|
| 1 | Normal arc | 0.88 s | 0 frames | +0.05 s | 1 |
| 2 | High launch (Up 140) | 1.50 s | 0 | +0.05 s | 1 |
| 3 | Extended glide (Up 140, Space held) | 2.25 s | 0 | +0.05 s | 1 |
| 4 | Mid-air steering (A, then S) | 1.08 s | 0 | +0.05 s | 1 |
| 5 | FLING SELF → wall-run (Up 60, Space beside the wall) | 1.92 s | 0 | +0.05 s | 1 |
| 6 | Q + Space mid-air (no wall) | 1.15 s | 0 | +0.05 s | 1 |
| 7 | Landing on the 24-stud block top (y 27) | 0.75 s | 0 | +0.05 s | 1 |
| 8 | Launched into a wall (control ended "blocked" at 0.38 s) | 0.63 s | 0 | +0.03 s | 1 |
| 9 | Death mid-flight | — | aura removed at death | "cancel", no impact | 0; nothing left after respawn |

(+0.05 s = the server relay. Case 5 at Up 140 correctly did not latch: the runner was above the wall's usable height.)

**Captures (private, not committed):** `C:\WORLD.EXE-Art\HackProto\evidence\rev15m\` — `selffling_before*` (Rev 15l: blue gone during the descent), `selffling_after*` and `selffling_wallrun*` (aura in every airborne frame, gone at the landing-impact frame), `ghosts_after*` (R6 silhouettes). Selected sheets are in the vault note (evidence 49–51).

#### Other regression checks
FLING TARGET on Dummy-A: challenge success, thrown ~46 studs, one landing impact, back to Running. R6 avatar: rig R6, 6 clothing / accessory items, WalkSpeed 28. Dash 28.2 studs. Clean Play start, no errors. Number-key challenge input was **not** re-run by keyboard this revision (code unchanged since Rev 15).

#### Documentation and comments
§0 added (current controls, tuning, tested / untested, deferred concerns); superseded mechanics marked. Source comments updated in MovementController (controls, silhouettes), MoveState (current owners and hand-overs), MovementService (15l / 15m), WallRun (Flow), HackVfx / HackController / HackEffects (aura lifetime), ForceR6 (deferred isolation issue). Studio-only afterimage cost counters (`FxCost` GUI attribute) stay in MovementController.

**Saved place:** SHA-256 `3b6afbf117d6a6cc6d6f4fc36f647298737d34f1b8d4e91b895cff03ad639781`, 65/65 scripts identical to `src/`. Protected files 9/9 OK.

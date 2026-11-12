# WORLD.EXE — Gameplay Experience Review (2026-11-12)

**Baseline:** `main` `f716fe4`, unchanged. The saved place is unchanged (SHA-256 `0CEB5484…`). No code, map, UI, balance or place changes were made. After the session, Studio was checked: 44/44 sources equal `main`, there are no `ZZ_` objects, and Lighting is at baseline.

**Method:**
- **Primary run:** one full solo match in Studio Play at normal timing. No `StudioTimeScale`, no teleports, no forced patches, no score changes.
  - Movement used the MCP walk-to (pathfinding) tool. Abilities and E used keyboard input; Architect chips used mouse clicks.
  - A passive client logger recorded the timeline without changing anything.
- **Diagnostic:** labelled D1–D2, and run in match 2 after RESULTS.
- **Evidence:** 19 sequential player-camera screenshots. **No video**: the tool cannot record video.

**Important caveats (they limit the evidence):**
1. **Tool latency.** Each MCP action takes about 5–12 s against the 12 s Architect window. **8 of 12 turns were skipped because of my tooling, not the game.** A human Architect would have uploaded roughly 2–3× as many patches, so pacing numbers involving patches understate patch frequency.
2. **Solo.** In solo the local player is the Architect every turn. **Multiplayer and social enjoyment are UNVERIFIED.** A local Clients-and-Servers session needs the owner to start it in Studio and was not run.
3. **Navigation.** The pathfinding walker is not a human player. It does not jump creatively, choose routes or look around, so the movement-feel scores are provisional.

---

## A. Overall first impression

WORLD.EXE **looks like a real game** and its **systems work**. The neon-grid arena has a clear identity, and the 8B-1B HUD and Architect panel are polished. Everything ran without a single error, and rounds reset cleanly.

**As a game, though, the core loop is currently flat.**
- The player spawns with **no stated goal**.
- They walk long distances to collect **tiny, silent** fragments, then repair **unmarked** stabilizers in 6 safe seconds.
- The team objective **cannot realistically fail**: stability never dropped below 85 against a target of 50.

The signature mechanic, reality patches, produced **one genuinely great moment (BLACKOUT)**. Most other patches happened **somewhere else**, and from where I stood the only evidence was a HUD chip. DRONE SWARM ran for 35 s and I never saw a drone.

The **final phase is the quietest part of the match**: no Architect turns, no patches, and 73 s with nothing to decide.

The problem is mostly **fundamental loop design (stakes, patch reach, escalation)**, not missing polish.

## B. Scorecard (1–10)

**O** = observed in this run; **P** = provisional (needs multiplayer or a human player).

| Category | Score | Evidence |
|---|---|---|
| First-time clarity | **3** (O) | Spawn shows only `ACTIVE 6:54` and a stability bar (`01`). There is no objective text and no explanation of fragments, stabilizers or stability. Fragment pickups are silent (+10 score, shown nowhere on the HUD); the fragment count is only in Details. Stabilizers have no marker; the prompt "Repair (3 fragments)" appears only within 10 studs. |
| Movement and exploration | **5** (P) | Vertical districts, bridges and catwalks are visually rich, and the reactor reads as a landmark from the Reservoir (`D2`). But the 976-stud arena with fragment legs of 64–250 studs means long straight runs. Areas are blue-on-blue and hard to tell apart (`07`, `15`). The pathfinder could not route to an elevated fragment at y=74. |
| Fragment collection | **4** (O) | Fragments are plentiful (12 live) and respawn. But each is a 1.6-stud cube, there is no pickup feedback, and there are no choices: walk to the nearest one. SCANNER highlights help (`02`). |
| Stabilizer objectives | **4** (O) | Repairs work (`08`→`09`). But a 6 s repair has no risk or pressure. State is shown only by ring colour (green, yellow, cyan); there is no progress bar and no completion moment beyond a 2.5 s toast. Stability went 94→100 after one repair, and the team target of 50 was never close. |
| Architect system | **5** (P) | The panel is clean and readable, with counterplay text (`05`). In solo the player is Architect every ~37 s, which turns into a chore and pulls attention from movement. 12 s to read 4 chips and confirm is tight even for a human. **Social enjoyment: UNVERIFIED.** |
| Patch excitement | **4** (O) | BLACKOUT is excellent (`13`→`14`): the arena goes dark and the warning reads well. DRONE SWARM, MAGNETIC and CORRUPTION were invisible from my position (`10`, `12`). FLOOD fills 3 local basins, and the water is almost the same blue as the floor (`D1`, `D2`). Patches last ~35 s, so overlaps were brief: CORRUPTION and BLACKOUT shared 1.6 s, and no combination fired. |
| Player abilities | **5** (P) | SCAN gives useful highlights. DASH refusal feedback is clear ("Path blocked", `11`). ANCHOR never had a reason to be used. Cooldowns are readable on the bar. Ability use was limited by the tooling. |
| Match pacing | **3** (O) | The first accepted patch came at 2:54 (tool-inflated). The final phase has **no turns and no patches**. The longest gap without a meaningful decision was **73 s** (final phase after the second repair, `16`). |
| Visual presentation | **6** (O) | Strong neon/cyber identity, a polished HUD, a good reactor silhouette and a great BLACKOUT. But the palette is monotone blue with low contrast, there is no audio at all, props and fragments are placeholders, and patch VFX are weak or local. |
| Replayability potential | **3** (P) | Solo outcomes are always success, objectives don't change, and patches rarely touch the player. Multiplayer (Architect rotation, competing for fragments, co-op repairs) could change this a lot, but it is **unverified**. |

## C. Five biggest strengths

1. **Presentation quality.** The HUD, warning strips (icon, severity, counterplay, countdown) and Architect panel look professional and read well (`05`, `06`, `13`).
2. **BLACKOUT** proves the concept: one upload visibly transformed the whole world for everyone, which is exactly the "reality patch" fantasy.
3. **Distinct arena identity:** a neon-grid megastructure with a readable central reactor and real verticality.
4. **Solid systems:** zero errors across two matches, clean RESET, clear refusal feedback, and correct scoring and results.
5. **A coherent concept loop is in place** (fragments → repair → stability; patches → threat → counterplay). The pieces exist; they need stakes and reach.

## D. Five biggest weaknesses (ranked by impact on enjoyment)

1. **Patches don't reach the player.** Most patch effects are local to districts or entity-based and happen out of view: drones never seen, FLOOD/MAGNETIC/CORRUPTION invisible from where the player was. The signature mechanic rarely affects the person playing.
2. **No stakes.** Stability never threatened failure (min 85 vs target 50). Repairs are optional, safe and short, so there is nothing to defend and no tension.
3. **The final phase is an anticlimax.** Architect turns and patches stop; the last 90 s are the calmest of the match.
4. **The objective is unclear at spawn and during play:** no goal statement, unmarked stabilizers, silent pickups, fragment count hidden.
5. **Too much empty traversal:** a large, samey arena with tiny pickups means long runs between decisions.

(No audio is a significant polish gap, but it ranks below these loop problems.)

## E. Gameplay timeline (primary run; ACTIVE = 0:00)

| Time | Event |
|---|---|
| 0:00 | Spawn on Skybridge; the countdown had already elapsed while loading. No goal shown (`01`). |
| 0:10 | Pressed SCAN: highlights appear. Architect turn 1 opens (`02`), then is skipped (tool latency, `03`). |
| 0:48 | Fragment 1 (64 studs). Silent: no HUD change (`04`). |
| 0:53 / 1:30 / 2:07 | Turns 2–4 skipped (tool). |
| 1:20, 2:26 | Fragments 2 and 3 (115 and 225 studs of walking). |
| 2:45–2:59 | **DRONE SWARM uploaded** (`06`); active 35 s. **No drone ever seen.** |
| 3:19–3:25 | **Repair 1** at Central Core: ring turns yellow, no progress bar (`07`, `08`), done in 6 s; stability 94→100 (`09`). |
| 3:37–4:09 | **MAGNETIC**: nothing visible where I stood (`10`). |
| 4:30 | DASH refused: "Path blocked" (`11`). |
| 5:07–5:20 | **CORRUPTION**: nothing visible (`12`). |
| 5:41–5:54 | **BLACKOUT**: the match's best moment (`13`, `14`). Overlapped CORRUPTION for 1.6 s. |
| 6:14 / 6:52 | Turn 11 skipped; turn 12 cut off by the final phase. |
| 7:00 | **FINAL PHASE**: only the timer pill turns red. Turns and patches stop. |
| 7:11–7:17 | **Repair 2** at Research Yard; stability back to 100 (`15`). |
| **7:17–8:30** | **73 s with nothing to do** (`16`). Only survival-score ticks. |
| 8:30 | RESULTS: "SIMULATION STABILIZED", 220 pts, 6 fragments, 2 repairs, 4 patches, 8 skipped turns (`17`). |

- **Most exciting moment:** BLACKOUT activation (5:54).
- **Most boring moment:** the final phase after the second repair (7:17–8:30).
- **Repetitive or chore-like:** walking 100–250 studs to 1.6-stud fragments; being Architect every turn in solo.
- **Results:** clear and well laid out, but feels unearned because success was never in doubt.
- **Would I immediately play again (solo)?** No. With friends: possibly, but unverified.

## F. Visual evidence

All screenshots are player camera, desktop Studio viewport, in `docs/gameplay_review/screens/` on branch `evidence/gameplay-review-2026-11-12`:

- spawn `01`
- fragment `04`
- stabilizer and repair `07`–`09`
- Architect `02`, `05`
- patch activation `06`, `13`
- overlapping effects `13`/`14` (CORRUPTION + BLACKOUT, brief)
- final phase `15`, `16`
- results `17`
- diagnostics `D1`, `D2`

Not captured: a visible drone (none appeared in view) or a patch combination (none triggered).

**Diagnostic (labelled, separate from the primary run):** in match 2, FLOOD was uploaded from the spawn.
- Water appears only in 3 basins; the nearest was 122 studs from spawn and not visible (`D1`).
- Up close, the water is a flat blue plane hard to tell apart from the floor (`D2`).

## G. Recommendations (ranked within each group)

**1. Fundamental gameplay**
1. **Bring patches to the players.** Each upload should affect where players are, or say where it hits:
   - target the most populated district, or make effects arena-wide;
   - show the location in the warning ("FLOOD → RESERVOIR");
   - make threats such as drones spawn within sight of players.
2. **Create real stakes:**
   - stability drains over time and per active patch, so repairs are necessary and failure is possible;
   - repairs take long enough, or are exposed enough, to need defending;
   - stabilizers degrade again.
3. **Make the final phase escalate:** faster or doubled patches, guaranteed combinations, all stabilizers under pressure. The final phase should be the climax.

**2. Pacing and balance**
1. Shorten the first-patch delay and the gaps between turns; tune durations so patches overlap and combinations happen naturally.
2. Scale fragment cost and arena use to player count (solo/small lobbies feel empty), or concentrate fragments along routes between stabilizers.
3. Re-check the 12 s submission window with humans: reading four chips plus confirming is tight.

**3. Clarity and onboarding** (largely the proposed 8B-2)
1. A spawn objective line ("Collect 3 fragments → repair a stabilizer to keep the simulation stable").
2. Stabilizer world markers with state and distance; a repair progress bar.
3. Visible fragment pickup feedback and an always-on fragment count (◆ 2/3).
4. Patch location in warnings.

**4. Visual and audio polish**
1. Make patch VFX readable from a distance: drone silhouettes and lights, water colour and surface, corruption trail.
2. Increase palette contrast between floor, walls and hazards.
3. An audio pass (proposed 8B-3; needs owner asset approval).
4. Fragment presentation (size, glow, bob).

**5. Future experimental (unapproved concepts; not current priorities)**
Overclock movement, Freeze/Stasis, Possession. These are better evaluated after the loop has stakes, since they add to player-versus-patch interplay. Physical-chip presentation and materialization animations remain design inspiration.

## H. Phase 8B-2 decision

**Recommendation: do not build 8B-2 (Objective Clarity) as a standalone polish phase next.**

Clarity is genuinely missing (weakness #4), but the play session showed bigger fundamental problems:
- patches rarely reach the player;
- there are no stakes;
- the final phase de-escalates.

Clarity alone would make a flat loop easier to understand, not more fun.

**Proposed next step (for ChatGPT and owner decision):**
1. **Owner-run local multiplayer observation (Studio Test → Clients and Servers, 2–3 clients).** It is cheap and read-only, and it answers the biggest unknown: whether Architect rotation and player-vs-player patching are fun. Without it, the social layer is unverified.
2. **Then a focused "Core Loop Pass" phase:**
   - (a) stability pressure and failure possibility;
   - (b) patch reach/location (targeting or callouts);
   - (c) final-phase escalation;
   - (d) the minimum clarity needed to support them: the spawn objective line, stabilizer markers and fragment feedback, taken from the 8B-2 scope.

   It involves server and balance changes, so it requires explicit owner approval and its own spec.
3. Keep the rest of 8B-2's polish (edge indicator, full tracker) and audio (8B-3) for after the loop pass.

**Unverified (not claimed):** multiplayer and social enjoyment; Architect rotation; co-op repairs; competition; mobile, gamepad and device feel; human route choice and movement feel.

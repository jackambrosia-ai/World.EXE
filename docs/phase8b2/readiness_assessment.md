# Phase 8B-2 readiness assessment (2026-11-12)

This is a read-only assessment and a proposal only. Nothing here is authorized construction. Phase 8B-2 is **NOT STARTED**, and optional Phase 8A-2d is **NOT AUTHORIZED**. The proposed scope in §4 is for ChatGPT review and explicit owner approval.

## 1. Verified baseline

| Check | Result |
|---|---|
| `main` | `f716fe4` (PR #17, squash). Tree identical to the final PR head `f37d288`; `src/` identical to the reviewed `ee17515`. No unreviewed source changes. |
| Live Studio (Edit) | 44 scripts, 44/44 sources identical to `main` (length + hash). No `ZZ_` objects. Only the documented `Orig8A2A_*` Lighting attributes remain. |
| Saved place | `Place1.rbxl` 2026-11-11 21:32:12, 231,250 bytes, SHA-256 `0CEB5484…8DD03FC6`, unchanged. Decoded sources 44/44 = `main`. |
| Backup | `WorldEXE_post-phase8b1b-r1_2026-11-11.rbxl`, same SHA-256. |
| Other PRs | #13, #11, #4 still draft and untouched. |

This used existing evidence plus read-only hashing; no regression suite was rerun.

## 2. Phase 8 requirements: what is satisfied, what remains

The sources are the roadmap Phase 8 entry and acceptance criteria, UI/Art Direction §2–§7, Game Design §6 and §11, and Testing §5 and §9.

| Requirement | Status | Evidence |
|---|---|---|
| Original HUD, Architect UI, patch announcements, results | **Done** (8B-1B) | `HUDController`, `ArchitectController`, `UITheme` |
| Readable desktop/mobile layout; warning text fits; UI does not block play | **Done (emulated)** | 8B-1B round 1, measured rects |
| Critical warnings work with audio disabled | **Met**: there is no audio; all warnings are text, glyphs and strips | — |
| Reduced-effects setting functions | **Partly met.** A session-only switch exists and applies to UI tweens. No camera shake or flashing exists to reduce. Persisting it belongs to Phase 9. | `UITheme.reducedEffects` |
| **Objective markers** (roadmap Phase 8, Art §5 "world-space marker") | **Missing** | 0 BillboardGuis in Workspace; no objective direction or distance anywhere |
| Interaction prompt with hold progress (Art §5) | **Partial.** A native prompt with a 0.3 s hold starts the repair. The 6 s repair progress is shown only in the hidden Details panel and by the ring colour. | `ObjectiveService` L246–250; `HUDController` L569–590 |
| Interruption feedback (Art §5, Test §5) | **Missing.** REPAIRING → PAUSED is silent. Rejected presses (`need_fragments`, `too_far`, `full`, `cooldown`) are dropped with no player feedback. | `ObjectiveService.TryJoin` result is discarded at L252–254 |
| Completion animation and stability update | **Partial.** A toast "✓ ZONE STABILIZER REPAIRED", the ring turns cyan, and the stability bar moves. | — |
| HUD hierarchy item 4: "objective progress and nearby stabilizer direction" | **Missing** from the always-visible HUD (Details only) | — |
| HUD item 5: fragment count | **Details only.** A player cannot see at a glance whether they carry the 3 fragments a repair costs. | — |
| Colour-independent indicators | HUD: yes (glyphs and text). **World: no.** The stabilizer state is ring colour only (green, amber, cyan). | `ObjectiveService.setRing` |
| Audio feedback (patches, repairs, abilities, Architect, results) | **Missing entirely.** There are 0 `Sound` instances or SoundIds in source. Every sound needs an asset choice. | grep `Sound` / `SoundId` |
| Patch Archive UI, settings persistence | Phase 9 (persistence) | Roadmap Phase 9 |
| Real-device, gamepad, multiplayer and performance validation | Deferred (§6) | — |

### Objective clarity (measured in Studio, read-only)
- **Arena size:** part centres span about 976 × 976 studs.
- **Stabilizers:** there are three, each 13 × 8 × 8 studs. The only beacon is an 8 × 1.2 × 1.2 neon bar. Tops are at y = 10 for Core and Yard, and y = 58 for Skybridge.
- **Distances between stabilizers:** Core–Yard 188, Core–Sky 256, Yard–Sky 432 studs.
- **From the 16 player spawns:**
  - each stabilizer is within 120 studs of only 2 spawns;
  - a raw line of sight to the stabilizer top exists from 7–10 of the 16 spawns. At 200–500 studs, though, a 13-stud object with a 1.2-stud beacon is a few pixels wide, so a clear line is not the same as being identifiable.
- **Conclusion:** players can't quickly find the three stabilizers from common routes, can't see repair progress without opening Details, and get no feedback when a repair is paused or rejected. This is the largest gap between the shipped game and the Phase 8 acceptance criteria.

### Streaming
Stabilizer models use `ModelStreamingMode = Atomic` with `StreamingTargetRadius = 1024`. On desktop they will normally be present. On memory-constrained devices they may stream out, so a marker must not depend on the model being present (see owner decision O1).

### Visual and environmental feedback
8A-2c environment responses are static, event-driven and decorative, and need nothing more for 8B-2. Fragments and crates are still placeholder neon parts, which is asset-dependent and out of scope.

## 3. Why Objective Clarity is the right 8B-2, and not audio first

1. It is the only Phase 8 roadmap item that is plainly **missing**, and it is the core loop: collect fragments → find a stabilizer → repair → stability.
2. It can be done with **native primitives only** (BillboardGui, TextLabel, UIStroke, existing ProximityPrompts), with no asset decisions.
3. **Audio is not achievable without asset decisions.** Every sound requires choosing SoundIds, checking licensing and provenance, and owner approval. It also needs a mixer/settings pass. It is better as its own small stage (8B-3, §7), and it is not required for any acceptance item: warnings already work without audio.

## 4. Recommended scope: Phase 8B-2 — Objective Clarity and Repair Feedback

### 4.1 Deliverables
- **D1 — Stabilizer world markers**, one per stabilizer, client-side only.
  - A `BillboardGui` (AlwaysOnTop) above each stabilizer showing:
    - a zone code (CORE, YARD, SKY);
    - a **state glyph and word**: `! NEEDS REPAIR` / `▶ REPAIRING 45%` / `‖ PAUSED 45%` / `✓ REPAIRED` with the cooldown seconds left. The glyph shapes differ, so state does not rely on colour;
    - a thin progress bar;
    - the distance in studs.
  - It fades and shrinks with distance to a minimum readable size (text ≥ 11 px), and is hidden outside ACTIVE / FINAL_PHASE and for spectators.
- **D2 — One off-screen edge indicator** for the **nearest actionable** stabilizer (NEEDS REPAIR, or REPAIRING/PAUSED with room for another contributor). It is a small chevron on the screen edge with the zone code and distance, and is clamped outside the reserved rects (`hudTop`, `abilities`, `architect`), so it never covers controls.
- **D3 — HUD objective tracker**, always visible and compact: three zone pips (glyph + code + progress) plus the carried fragments as `◆ 2/3`. It extends HUD item 4/5 within the existing top layout and reserved-rect contract. No new panel is added and nothing is placed at screen centre.
- **D4 — Repair feedback toasts**, client-side and using the existing toast path:
  - **Insufficient fragments:** `Need 3 fragments — you have 1`. The client sees its own prompt trigger (`ProximityPromptService.PromptTriggered`) and compares it with its replicated fragment attribute.
  - **Paused:** `CORE REPAIR PAUSED — stay in range` when the stabilizer you are near goes REPAIRING → PAUSED.
  - **Completed:** the existing ✓ toast is kept, and the marker shows a brief completion pulse that is skipped under Reduced Effects.
  - Not attempted: `too_far` and `full` cannot be inferred reliably on the client without a server result (see O2).
- **D5 — Accessibility:**
  - every new state has a glyph and a word, not just colour;
  - text is ≥ 11 px;
  - all tweens use `UITheme.tween`, so Reduced Effects removes them;
  - nothing new takes gamepad focus, and the native ProximityPrompt keeps keyboard, gamepad and touch support.

### 4.2 Files and Studio objects likely affected
- **New:** `src/StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/ObjectiveMarkerController.luau` (D1, D2, D4).
- **Edited:**
  - `ClientBootstrap` (start the controller);
  - `HUDController` (D3 tracker; it reads `Snapshot.Objectives`, which it already does);
  - `UITheme` (a reserved rect for the tracker, if needed).
- **Studio:** only the matching script instances. Possible exception: O1-B (streaming mode on 3 models).
- **Unchanged:** server services, remotes, Config gameplay values, map geometry, environment hooks.

### 4.3 Architecture and performance limits
- `MatchStateClient` stays the only Snapshot reader; markers subscribe to `OnChanged`.
- Stabilizers are discovered on the client by the existing `Stabilizer` tag and `StabilizerId` attribute, mapped to `Snapshot.Objectives[].Id`.
- Budgets:
  - **instances:** 3 BillboardGuis + 1 edge indicator, all with ≤ 6 descendants each. No new parts, lights, particles or Beams.
  - **updates:** state on Snapshot change only. Distance, fade and the edge indicator are updated at ≤ 10 Hz in one Heartbeat-throttled loop; there are no per-marker loops.
  - **network:** no new remotes or replicated attributes, and no server work. The 0.1 ms/frame client budget is checked with MicroProfiler or `os.clock` sampling in Studio.
- Cleanup: everything is rebuilt on RESET and destroyed for spectators and in the lobby. The controller is idempotent across consecutive matches.

### 4.4 Desktop and mobile usability
- **Desktop 1366×768 and up:** markers are readable at 300 studs, and the tracker sits under the stability bar.
- **Touch landscape 740×360 and 844×390 (emulated):**
  - the tracker fits within `hudTop` or the alerts column and causes no new overlaps in the 8B-1B overlap check;
  - the edge indicator never enters the thumbstick, ability, jump or tray rects;
  - Architect tray behaviour is unchanged.
- **Portrait 390×700:** the tracker wraps to one line of three pips.

### 4.5 Visual quality standard
- Uses the existing 8B-1B tokens (navy panel, cyan info, amber needs-repair, green repaired, violet unused here) and the existing cyber-chip language. No new fonts or images.
- Markers are restrained: a small plate with a 1 px stroke, no glow spam, and nothing larger than about 120 × 44 px on screen.
- No flashing. The completion pulse is ≤ 0.4 s, a single pulse, and is skipped under Reduced Effects.

### 4.6 Focused tests and acceptance criteria
All tests are solo Studio. Touch layouts are emulated and labelled as such.

| # | Acceptance criterion |
|---|---|
| A1 | From each of the 16 spawns, the nearest actionable stabilizer is identifiable within 2 s: a marker is on screen, or the edge indicator points to it. Distance is shown and correct within 1 stud. |
| A2 | The marker state matches the server in every state (IDLE / REPAIRING % / PAUSED % / COOLDOWN with seconds), including **two consecutive matches** and RESET. |
| A3 | Pressing the prompt with fewer than 3 fragments shows the "Need 3 fragments — you have N" toast; leaving range shows the PAUSED toast. Neither changes the server result. |
| A4 | The tracker shows the correct fragments and all three states without opening Details. |
| A5 | Overlap check at 844×390, 740×360 and 390×700 (emulated) plus desktop: no new overlaps with the controls, tray, warning or Details. Text ≥ 11 px, and `TextFits` is true. |
| A6 | Colour independence: a greyscale screenshot still shows every state through its glyph and word. |
| A7 | Reduced Effects ON: no pulses or tweens, and the final states are still correct. |
| A8 | Spectator, lobby and RESULTS: markers and the edge indicator are hidden; nothing is left behind after RESET (descendant count is stable across 2 matches). |
| A9 | Performance: client cost ≤ 0.1 ms/frame on average in Studio; no new server cost; Output is clean. |
| A10 | Regression spot checks only: Architect submit (desktop), ability cooldown, RESULTS card, parity, clean Edit place. |

### 4.7 Must remain unchanged
- server gameplay and every `ObjectiveService` rule (cost, radius, hold, rates, cooldown);
- remotes and the Snapshot schema (unless O1-A or O2 is approved);
- the 8B-1B layouts, Architect tray and cyber-chip design, and the Details panel;
- the patch catalog, map geometry, environment effects (8A-2c) and lighting;
- abilities, scoring and progression;
- no persistence.

### 4.8 Owner decisions required before construction
- **O1 — markers when a stabilizer streams out** (affects low-memory devices only). Pick one:
  - **A:** add a read-only `Pos` to each `Snapshot.Objectives` entry. This is one additive server line, with no gameplay effect.
  - **B (recommended):** set `ModelStreamingMode = Persistent` on the three stabilizer models. This is a place property change only, not geometry: 12 small parts, always present on the client, and no code.
  - **C:** client-only. Markers appear only while the model is streamed in, and that limitation is documented.
- **O2 — include `too_far` / `full` / `cooldown` rejection feedback?** It needs a server→client result, either a new remote or a reuse of an existing feedback remote. Recommendation: **not in 8B-2.** Revisit with multiplayer testing.
- **O3 — include the D2 edge indicator?** Recommended yes; it can be dropped to shrink the scope.
- **No asset, upload, purchase, ForgeGUI or licensing decisions** are needed for this scope.

## 5. Out of scope; preserved for later
- **Phase 8B-3 — Audio feedback (proposal only).** A small `AudioController` and a client `SoundGroup` with a volume and mute setting, plus an event map:
  - patch warning, activation and expiry;
  - repair start and complete;
  - ability use;
  - Architect select and confirm;
  - results.

  It needs owner approval of a specific sound list, either Roblox-provided library audio or original audio, with licensing and provenance checked. Captions are already covered because every event has text.
- Fragment and crate art, and drone silhouettes, are asset-dependent and stay placeholders.
- **Future creative backlog**, as design inspiration only and not to be implemented now:
  - Overclock movement mode;
  - Freeze/Stasis ability;
  - Possession;
  - Cyberpunk physical-chip presentation;
  - digitized materialization animations for UI sequences.
- The existing cyber-chip Architect design stays approved and unchanged.

## 6. Pre-release validation: recommended milestone
These five requirements remain **open and are not claimed as passed**:
1. real mobile touch controls and device safe areas;
2. expanded Roblox chat versus critical warnings and Architect chips;
3. physical gamepad input and navigation;
4. multiplayer and non-Architect client visibility;
5. device performance and representative desktop resolutions.

**Recommendation:** an **Integration Test Milestone (IT-1)** after Phase 8 construction (8B-2, plus 8B-3 if approved) and before Phase 9 construction. It would run in a **private published test place**, which Phase 9 DataStore testing needs anyway, with:
- 1 real phone;
- 1 physical gamepad;
- 2–4 clients, including a non-Architect view;
- a 1920×1080 desktop.

Planning work can continue in parallel; IT-1 blocks only release and Phase 9 persistence testing. 8B-2's markers and edge indicator should be added to IT-1's checklist, covering streaming on a phone and chat overlap with the tracker.

## 7. Risks
- **Chat overlap:** the Roblox chat window overlaps the top-left on touch (round-1 finding). The tracker and alerts column could be covered when chat is open; this is verified only in IT-1.
- **Marker clutter:** BillboardGui AlwaysOnTop markers can clutter during BLACKOUT or FLOOD. This is mitigated by distance fade, a 3-marker cap and no glow.
- **Local inference:** "you are near a paused repair" is inferred on the client from distance plus the state change. In co-op it may sometimes show to a nearby non-contributor. It is acceptable as a hint, and it is worded neutrally.
- **Streaming:** depends on O1.

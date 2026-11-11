# WORLD.EXE — Project Status

This file is maintained by Claude after each phase. ChatGPT uses it to understand the current implementation state.

## Current state
- Overall status: PHASE 7B IN REVIEW — review round 1 correction (safe MAGNETIC crate restore) pushed to PR #10 for focused final review. Completes the initial catalog (10 patches, 5 combinations). Phase 8 not started. D3 stays unimplemented. Multiplayer validation is deferred to the pre-release integration milestone.
- Current phase: Phase 7B — MAGNETIC, CORRUPTION, FLOOD and the remaining combinations (in review)
- Current branch: `phase-07b-catalog-expansion`
- Current PR: Phase 7B in review: [jackambrosia-ai/World.EXE#10](https://github.com/jackambrosia-ai/World.EXE/pull/10). Phase 7A merged via [jackambrosia-ai/World.EXE#9](https://github.com/jackambrosia-ai/World.EXE/pull/9). Phase 6 merged via [jackambrosia-ai/World.EXE#8](https://github.com/jackambrosia-ai/World.EXE/pull/8). Phase 5 merged via [jackambrosia-ai/World.EXE#6](https://github.com/jackambrosia-ai/World.EXE/pull/6). Phase 4 merged via [jackambrosia-ai/World.EXE#5](https://github.com/jackambrosia-ai/World.EXE/pull/5). Phase 3 merged via [jackambrosia-ai/World.EXE#3](https://github.com/jackambrosia-ai/World.EXE/pull/3). The separate, unmerged AI-automation PR #4 is not part of the phase work and must not be merged or activated as part of Phase 4
- Studio place: saved by the owner 2026-11-10 17:35:27 (`Place1.rbxl`, 135,464 bytes, SHA-256 `F4DF639AB773961792E97BF2FB305751D64ABAFCF6B11BD0F598C86368FE90FF`). The save is verified from the file itself: all 21 `Source` strings decoded from the saved `.rbxl` are byte-identical (length + hash) to `src/` at `c7f5186` (unchanged in `main` `8d244b9`), and the file has no other scripts. Before the save, the Edit place was checked clean: no test scripts or attributes, 64 DecayTiles, gravity 196.2.
- Phase 1 merge: squash-merged 2026-11-10 by owner approval as `9b9cbd0` (from PR head `ddc784c`; merged tree identical to that head). The `phase-01-arena` branch still exists on GitHub and can be deleted.
- Phase 2 merge: squash-merged 2026-11-10 by owner approval as `09d9c2a` (from PR head `2e99b13`; merged tree identical to that head; final gameplay code `9c6de7a`). The `phase-02-match` branch still exists on GitHub and can be deleted.
- Phase 3 merge: squash-merged 2026-11-10 by owner approval as `c2ab456` (from PR head `27c3599`; merged tree identical to that head; final code reviewed at `d22939f`). The `phase-03-patch-engine` branch still exists on GitHub and can be deleted.
- Phase 4 merge: squash-merged 2026-11-10 by owner approval as `8d244b9` (from PR head `cba4987`; merged tree identical to that head; final code reviewed at `c7f5186`). The `phase-04-prototype-patches` branch still exists on GitHub and can be deleted.
- Phase 5 merge: squash-merged 2026-11-10 by the owner as `66374fe` (from PR head `81aabf2`; merged tree identical to that head; final code reviewed at `6e7ed2e`). The `phase-05-objectives-scoring` branch still exists on GitHub and can be deleted.
- Phase 6 merge: squash-merged 2026-11-10 by the owner as `16cef23` (from PR head `bfdbd66`; merged tree identical to that head; final code reviewed at `03f9cab`). The `phase-06-abilities` branch still exists on GitHub and can be deleted.
- Phase 7A merge: squash-merged 2026-11-10 by owner approval as `059f191` (from PR head `36e2926`; merged tree identical to that head; final code reviewed at `0ecbfa4`). The `phase-07a-interactions` branch still exists on GitHub and can be deleted.
- Communication protocol (owner, 2026-11-10, [issue #7](https://github.com/jackambrosia-ai/World.EXE/issues/7)): Claude posts phase reports and test evidence as comments on the phase PR; ChatGPT posts its verdicts and correction requests there; Claude reads new PR comments and implements corrections within the approved phase before asking the owner anything. Owner gates (merge, next phase, saves, publishing, spending) remain explicit. PR #4 (paid API automation) stays disabled and untouched.
- Last verified Studio place: `Place1.rbxl` (on disk: `OneDrive\Documents\Place1.rbxl`), unpublished (PlaceId 0). Saved by the owner 2026-11-10 16:35:24 (129,164 bytes, SHA-256 `2663A50DABDDFAA936A7B84866ECA716047C8D77C2B734A96D95A2A6F11FBB98`). The save is verified from the file itself: all 18 `Source` strings decoded from the saved `.rbxl` are byte-identical (length + hash) to `src/` at `d22939f` (unchanged in `main` `c2ab456`), and the file has no other scripts. Before the save, the Edit place was checked clean: no test attributes, injected scripts, clones or runtime folders, and gravity 196.2.
- Source synchronization method: **owner decision — no Rojo / no mirroring toolchain.** Claude edits Studio directly via Studio MCP and keeps an identical copy of every WORLD_EXE script in `src/`, verified by byte-length + hash comparison after each change (see `src/README.md`).
- Place backups (outside the repo, `OneDrive\Documents\RobloxBackups\`):
  - `WorldEXE_baseline_2026-11-09.rbxl` — pre-Phase-1 place (byte-identical copy)
  - `WorldEXE_post-phase1_2026-11-10.rbxl` — post-Phase-1 place incl. both review rounds (byte-identical copy of the saved `Place1.rbxl`)
  - `WorldEXE_pre-phase2_2026-11-10.rbxl` — verified pre-Phase-2 copy (identical content to post-Phase-1)
  - `WorldEXE_post-phase2_2026-11-10.rbxl` — post-Phase-2 place (SHA-256 `0F402A70…42B7B204`, identical to the saved `Place1.rbxl`)
  - `WorldEXE_pre-phase3_2026-11-10.rbxl` — verified pre-Phase-3 copy (SHA-256 `0F402A70…42B7B204`, identical to the saved place)
  - `WorldEXE_post-phase3_2026-11-10.rbxl` — post-Phase-3 place (SHA-256 `2663A50D…F11FBB98`, identical to the saved `Place1.rbxl`)
  - `WorldEXE_pre-phase4_2026-11-10.rbxl` — verified pre-Phase-4 copy (SHA-256 `2663A50D…F11FBB98`, identical to the saved place)
  - `WorldEXE_post-phase4_2026-11-10.rbxl` — post-Phase-4 place (SHA-256 `F4DF639A…68FE90FF`, identical to the saved `Place1.rbxl`)
  - `WorldEXE_pre-phase5_2026-11-10.rbxl` — verified pre-Phase-5 copy (SHA-256 `F4DF639A…68FE90FF`, identical to the saved place)
  - `WorldEXE_post-phase5_2026-11-10.rbxl` — post-Phase-5 place (SHA-256 `13CDA584…FEC74635`, identical to the saved `Place1.rbxl`)
  - `WorldEXE_pre-phase6_2026-11-10.rbxl` — verified pre-Phase-6 copy (SHA-256 `13CDA584…FEC74635`, identical to the saved place)
  - `WorldEXE_post-phase6_2026-11-10.rbxl` — post-Phase-6 place (SHA-256 `B2252755…B397F3B2`, identical to the saved `Place1.rbxl`)
  - `WorldEXE_pre-phase7a_2026-11-10.rbxl` — verified pre-Phase-7A copy (SHA-256 `B2252755…B397F3B2`, identical to the saved place)
  - `WorldEXE_post-phase7a_2026-11-10.rbxl` — post-Phase-7A place (SHA-256 `3198C186…93625552`, identical to the saved `Place1.rbxl`)
  - `WorldEXE_pre-phase7b_2026-11-10.rbxl` — verified pre-Phase-7B copy (SHA-256 `3198C186…93625552`, identical to the saved place); current rollback point
- Studio place (Phase 7A): `Place1.rbxl` last written 2026-11-10 20:41:38 (158,802 bytes, SHA-256 `3198C186DEEFA561873DB5C00672EB5AD0C4EB7AEE0A085D40A07EF393625552`). Verified from the file itself: all 36 decoded script sources are byte-identical (length + hash) to `src/` at `0ecbfa4`, the 8 Phase 7A pads (`Map.PatchSurfaces`, BounceSurface/SlipSurface tags) are present, and there are no `ZZ_` test leftovers. The Edit place was checked clean: no test scripts or attributes, pads at build state, 64/64 DecayTiles solid, 12 FragmentSpawn, Lighting 3.00/0.00, gravity 196.2.
- Studio place (Phase 6): saved by the owner 2026-11-10 19:11:29 (`Place1.rbxl`, 150,191 bytes, SHA-256 `B2252755CFA1DA6FCE1BCC34D64BCEAEF49BAAB88B117A9E4E07A37BB397F3B2`). Verified from the file itself: all 28 decoded script sources are byte-identical (length + hash) to `src/` at `03f9cab` (unchanged in `main` `16cef23`), with no other scripts. Before the save, the Edit place was checked clean: no test scripts or attributes, 64/64 DecayTiles collidable, 12 FragmentSpawn markers, stabilizer rings at their original colour, gravity 196.2.
- Studio place (Phase 5): saved by the owner 2026-11-10 18:16:45 (`Place1.rbxl`, 144,480 bytes, SHA-256 `13CDA584FCF8C65F22044D67DF9CFCD45043F2669F21F8456304ADCCFEC74635`). Verified from the file itself: all 25 decoded script sources are byte-identical (length + hash) to `src/` at `6e7ed2e` (unchanged in `main` `66374fe`), the file has no other scripts, and the 12 FragmentSpawn marker ids are present. Before the save, the Edit place was checked clean: no test scripts or attributes, stabilizer rings at their original colour, 64 DecayTiles, gravity 196.2.
- Studio save: Studio MCP cannot save the place — the owner must press Ctrl+S after each change set. Latest save 2026-11-10 16:35:24 (post-Phase-3 incl. review round 1, backed up).
- StreamingEnabled: unchanged (enabled), per Phase 0 review
- Multi-client testing: Phase 2 run with Studio Clients and Servers (1 server + 2 clients) on 2026-11-10 — see the matrix in "Phase 2 review round 2 correction". Phase 1 tests remain solo.
- Latest technical review: Phase 2 final review (ChatGPT, `9c6de7a`) — no remaining code blockers; two-client acceptance run recorded; merged with owner approval. Phase 3 review round 1 (ChatGPT, `04b734a`): hook yield-safety and non-finite modifiers — corrected. **Phase 3 final review (ChatGPT, `d22939f`): APPROVED, no blocking code issues**; merged with owner approval. **Phase 4 final review (ChatGPT, `c7f5186`): APPROVED, no remaining blocking code issues**; merged with owner approval.
- Known Phase 3 gaps carried forward (not counted as passed): multi-client (Clients and Servers) run; 3 concurrent patches reached through live Architect play. (The live gravity change was verified in Phase 4, Z1.)
- Known Phase 6 gaps (not counted as passed): departure, recovery and shutdown cancellation not triggered live (code paths only); anchor mass-change update; gamepad/touch input; all multiplayer ability behaviour — deferred to the multiplayer integration milestone.
- Known Phase 5 gaps (not counted as passed): co-op repair, fragment races, departures mid-repair/mid-match, joiner scoring, multi-row results on real clients — deferred to the multiplayer integration milestone.
- Known Phase 4 gaps (not counted as passed): all multiplayer scenarios, **deferred by owner decision (2026-11-10) to a batched multiplayer integration milestone; comprehensive multiplayer testing is required before public release.** See "Testing policy and deferred multiplayer validation".
- Testing policy (owner, 2026-11-10): automated and targeted solo tests routinely, chosen by the risk a change introduces; multiplayer batched across phases; owner interaction only when genuinely necessary; full regression suite at milestones and release candidates.
- Known Phase 2 gaps carried forward (not counted as passed): real mid-match join → Spectator; multiplayer spawn-protection window; > 12 players; streaming at distance; pending-respawn invalidation on departure. Hardening note for Phase 10: server→client remotes have no `OnServerEvent` handler (client spam is queued with warnings).
- Known Phase 7A gaps (not counted as passed): a real failing combination activation (shared RunHook path covered by E1/E2); combination cap 5 unreachable with 2 combinations; departure/recovery during a combination (code paths only); BLACKOUT on a real client; all multiplayer behaviour — deferred to the multiplayer integration milestone.
- Known Phase 7B gaps (not counted as passed): recovery, shutdown or departure while a 7B patch runs (code paths only); all multiplayer behaviour (crate replication, several players pausing crates, flood slow and corruption damage on several players) — deferred to the multiplayer integration milestone.
- Last updated: 2026-11-10

## Phase tracker
| Phase | Scope | Status | PR/Commit | Studio test evidence |
|---|---|---|---|---|
| 0 | Audit and setup | Complete (owner decisions recorded) | — | Read-only audit; ForgeGUI read-only audit |
| 1 | Foundation and arena | **Complete — merged** (solo-tested; multi-client tests outstanding) | [PR #1](https://github.com/jackambrosia-ai/World.EXE/pull/1) → `9b9cbd0` | Solo playtests: see reports below |
| 2 | Match and Architect | **Complete — merged** (solo + two-client Studio tests; gaps listed above) | [PR #2](https://github.com/jackambrosia-ai/World.EXE/pull/2) → `09d9c2a` | Two-client matrix: 19 PASS, 1 split, 1 NOT TESTED |
| 3 | Patch engine | **Complete — merged** (solo Studio tests; multi-client outstanding) | [PR #3](https://github.com/jackambrosia-ai/World.EXE/pull/3) → `c2ab456` | Original: 25 PASS, 0 FAIL, 3 NOT TESTED. Round 1: 18 PASS, 0 FAIL, 1 NOT TESTED |
| 4 | Four prototype patches | **Complete — merged** (solo Studio tests; multiplayer deferred) | [PR #5](https://github.com/jackambrosia-ai/World.EXE/pull/5) → `8d244b9` | Solo: 36 PASS, 0 FAIL, 3 NOT TESTED; round 1: 6 PASS (targeted); multiplayer deferred |
| 5 | Stability/objectives/scoring | **Complete — merged** (solo Studio tests; multiplayer deferred) | [PR #6](https://github.com/jackambrosia-ai/World.EXE/pull/6) → `66374fe` | Targeted solo: 36 PASS, 0 FAIL; round 1: 10 PASS (targeted); multiplayer deferred |
| 6 | Initial abilities | **Complete — merged** (solo Studio tests; multiplayer deferred) | [PR #8](https://github.com/jackambrosia-ai/World.EXE/pull/8) → `16cef23` | Targeted solo: 27 PASS, 0 FAIL; multiplayer deferred (see Phase 6 report) |
| 7A | Interactions + BOUNCY/SLIPPERY/BLACKOUT | **Complete — merged** (solo Studio tests; multiplayer deferred) | [PR #9](https://github.com/jackambrosia-ai/World.EXE/pull/9) → `059f191` | Targeted solo: 35 PASS, 0 FAIL; round 1: 9 PASS (targeted live Architect runs) |
| 7B | MAGNETIC/CORRUPTION/FLOOD + 3 combinations | **In review** (solo Studio tests; multiplayer deferred) | [PR #10](https://github.com/jackambrosia-ai/World.EXE/pull/10) (`2b8b3f0`) | Targeted solo: 30 PASS, 0 FAIL; round 1: 7 PASS (safe crate restore) |
| 8 | UI and visual polish | Not started | — | — |
| 9 | Progression and persistence | Not started | — | — |
| 10 | Hardening and release candidate | Not started | — | — |

## Phase 7B review round 1 correction (2026-11-10)

ChatGPT reviewed PR #10 at `425b503` and returned CHANGES REQUESTED, with one safety blocker. Everything else was accepted.

### Finding
**MAGNETIC crate restoration.** At cleanup, each anchored, collidable crate was put back at its resting spot at once, even if a player stood there. The crate could intersect or push the character.

### Fix: "ghost" restore
- **Exact position at once.** At cleanup, every crate goes back to its exact original CFrame, and its Colour is restored.
- **Collision off first if the spot is occupied.** If any character part overlaps the crate's resting volume (crate size + 0.2 studs), the crate is first made non-colliding and 60% transparent, and only then moved. Both changes happen in the same server step, so it can never push, trap or fling anyone.
- **Settle loop.** One module-level task in `Magnetic` runs only while ghost crates exist:
  - every 0.1 s it makes a ghost solid again, with its original CanCollide and Transparency, once no character overlaps it;
  - it ends itself when none are left;
  - there are no connections and no timers in the patch's cleanup bag.
- **Applies to every end reason.** The restore is in the patch's cleanup, so it covers expiry, cancel, match end, RESET, recovery and shutdown. A ghost crate taken over by a new MAGNETIC patch keeps its exact origin and becomes solid when clear.
- **RESET diagnostic.** RESET compares the arena with its baseline before players respawn in the lobby, which happens asynchronously. A difference found at RESET is now compared again at LOBBY and only reported (`warn` and `LastResetBaselineMatches`) if it is still there. A ghost crate is solid again by then because the players have left the spot.
- **Unchanged:** crate lanes, movement, the never-strike rule, and the other patches.

### Targeted tests (solo Studio, 2026-11-10)

| # | Test | Result | Evidence |
|---|---|---|---|
| G1 | Player on a crate's resting spot at expiry | PASS | Crate 1 had moved 6.6 studs away; the player then stood on its spot. At expiry: crate at its exact resting CFrame, CanCollide false, Transparency 0.6, 1 ghost. The other 7 crates were exact. Player displaced 0.00 studs over 1 s, speed 0.00 (no push) |
| G2 | Exact restore after the player leaves | PASS | Player stepped away: the crate was solid again after 0.10 s. 8/8 crates exactly restored (CFrame, Colour, CanCollide, Transparency); 0 ghosts; 0 patch objects; arena baseline matches |
| G3 | Player on a resting spot at match end | PASS | Crate had moved 6.1 studs away; the player stood on its spot through RESULTS. At RESULTS: 0 patches, crate at its exact CFrame as a ghost; player displaced 0.00 studs. At LOBBY: 0 ghosts, 8/8 exact, `LastResetBaselineMatches=true`, arena baseline matches |
| G4 | RESET re-check path | PASS | Same case with sampling: during RESET 1 ghost and `LastResetBaselineMatches=false`; at LOBBY 0 ghosts, `true`, crate exact and solid. No warning printed |
| G5 | No stranded crates or resources | PASS | After every case: 0 ghosts, 0 patch objects, crates at their build state (anchored, solid, opaque, original colour); the settle loop ended |
| G6 | Output | PASS | Three matches: only `[WORLD_EXE]` info lines; no errors or warnings |
| G7 | Parity and Edit place | PASS | 42/42 hash-identical; Edit place clean |

Totals: **7 PASS, 0 FAIL.** The 30-test suite was not repeated, per the review.

Notes:
- A first attempt at G1/G3 put the player on the spot before the crate had moved, so the player stood on the crate itself. Turning it into a ghost then let the player drop 3 studs onto the floor. The tests were rerun the intended way (the player steps onto the empty spot after the crate has left); the results above are from those reruns.
- Recovery and shutdown with an occupied spot were not triggered live. They use the same cleanup function.

### Changed files
- `Patches/Magnetic.luau` (ghost restore and settle loop)
- `Services/MatchService.luau` (the RESET baseline re-check at LOBBY)
- This document

## Phase 7B report — Remaining patches and combinations (2026-11-10)

Approved scope (Phase 7B execution approval):
- Three patches: MAGNETIC, CORRUPTION, FLOOD.
- Three combinations: FLOATING_DEBRIS, RAPID_DECAY, SLIDE_FIELD.

This completes the initial catalog of **10 patches and 5 combinations**.

Unchanged (approved provisional values):
- Architect interval 25 s; BLACKOUT 35 s.
- Severity costs −4 / −5 / −6; combination cost −4; +10 Discovery.
- 3 major patches at most.

The match timeline is unchanged. D3, persistence, ForgeGUI and publishing are not included.

### Pre-checks (all passed)
- `main` synced to `9a720b7`.
- Studio matched `main` on all 36 scripts, and the Edit place was clean.
- `WorldEXE_pre-phase7b_2026-11-10.rbxl` was created. Its SHA-256 matches the saved place: `3198C186…93625552`.
- Branch `phase-07b-catalog-expansion` created.

### Completed features
- **Arena content** (dedicated tagged parts only; no existing geometry changed), under `Map.PatchMarkers`, built by `tools/studio/phase7b_markers.luau`:
  - 8 `MagneticProp` crates (3×3×3, anchored, collidable).
  - 4 `MagneticPoint` markers.
  - 12 `CorruptionNode` markers: 2 paths of 6, CentralCore and ResearchYard, ordered by `Order`.
  - 2 `FloodZone` footprints: the Core deck 80×80 and the Research Yard 104×104, each with `MaxRise` 2.5.
  - Markers are invisible, with no collision, queries or touch.
  - The build tool checked, before creating anything:
    - floor under every crate and node;
    - crate headroom;
    - a box sweep of each crate's lane to its point;
    - clearance from spawns, stabilizers, supply points, fragment markers and pads.
  - Yard items sit on DecayTile centres.
  - Config adds the tags, counts (8/4/12/2), classes and attribute schema, so Bootstrap validation and the arena baseline cover them.
- **New patches:**

  | Patch | Severity / weight | Duration | Effect | Counterplay | Safeguards and restore |
  |---|---|---|---|---|---|
  | MAGNETIC | standard / 3 | 35 s | Up to 8 crates move along fixed lanes toward their zone's nearest MagneticPoint, stopping 3.5 studs short. The field flips every 8 s: pull, then push back to rest. Blue while pulling, orange while pushing. | Keep off the lanes; crates telegraph by colour | Anchored and kinematic: the server sets CFrame at 10 Hz and 6 studs/s, so physics ownership never leaves the server and nothing is flung. A crate never moves while a character is within 4 + 1.5 studs of its next position. CFrame and Colour restored exactly. |
  | CORRUPTION | severe / 2 | 35 s | One path is chosen at random. A new node every 3 s: amber warning disc for 2 s, then a magenta corrupted disc. 4 damage/s (applied every 0.5 s) to living Participants on a corrupted disc. | Step off amber discs; the trail covers at most 6 discs of 6 studs; SCANNER shows the discs | At most 6 active nodes across all CORRUPTION patches. ForceField (spawn protection) blocks the damage. Discs are runtime parts with no collision or queries and are removed at the end. |
  | FLOOD | severe / 2 | 35 s | Water rises linearly to 2.5 studs over 10 s in both zones, then holds. Wading Participants (feet below the surface) walk at 60% speed. **Non-lethal.** | Take the ramps: the Skybridge ramp and steps, the Lookout ramp, the Bridge and the North Annex stay dry | WalkSpeed is restored on leaving the water, on no longer being a living Participant, and at the end. The water is a runtime part with no collision or queries. |

- **New combinations** (InteractionCatalog). As in 7A, each one: starts once per match; ends with either source; holds no slot; costs −4 stability; gives +10 Discovery.
  - **FLOATING_DEBRIS** (FLOOD + MAGNETIC):
    - Crates float on the water: bottom 1 stud below the surface, so the top is 2 studs above it.
    - A crate someone stands on keeps them out of the water and does not move while occupied.
    - When it ends, crates settle back to their resting height.
  - **RAPID_DECAY** (DECAY + CORRUPTION):
    - DECAY starts tile groups 1.5× as often (cycle 5 → 3.33 s).
    - Unchanged: the 2.5 s amber warning, the collapse time and the cap of 8 unsafe tiles.
    - DECAY's loop now checks every 0.25 s against the current cycle.
  - **SLIDE_FIELD** (SLIPPERY + MAGNETIC):
    - Crates slide at 2× speed to their points and are held there (no push-back).
    - Each point is marked by a glowing ring.
    - The rule that crates never strike a player still applies.
- **SCANNER** also highlights corruption discs and magnetic crates.
- **Unchanged:** PatchInteractionService, BehaviorRuntime, ArchitectService, MatchService and Stability/Score, plus all Phase 7A patches except DECAY (speed hook only). PatchService gained three entries in its behaviour list.

### Changed / added files
- Added:
  - `Patches/Magnetic.luau`, `Corruption.luau`, `Flood.luau`, `FloatingDebris.luau`, `RapidDecay.luau`, `SlideField.luau`
  - `tools/studio/phase7b_markers.luau`
- Changed:
  - Shared: `Config` (0.7.0-phase7b, tags, counts, classes, schema), `PatchCatalog`, `InteractionCatalog`
  - `Services/PatchService` (behaviour list), `Patches/Decay` (speed hook), `Services/AbilityService` (scanner), `Controllers/AbilityController` (colours)
  - `src/README.md`, this document
- Studio parity: **42/42 scripts hash-identical.**

### Tests (solo Studio, targeted, 2026-11-10)
Most tests used scripts injected into the play server, calling the real services with a real player. Lifecycle runs used real Architect submissions through the `RequestPatchSubmission` remote. Movement speed was measured on the real client.

| # | Test | Result | Evidence |
|---|---|---|---|
| V0 | Arena validation | PASS | `Validate` ok, 0 errors; MagneticProp 8, MagneticPoint 4, CorruptionNode 12, FloodZone 2; baseline matches. Bootstrap: `v0.7.0-phase7b … CorruptionNode=12 … FloodZone=2 … MagneticPoint=4, MagneticProp=8` |
| M1 | MAGNETIC activation | PASS | 8/8 crates moved (cap 8); pull colour shown |
| M2 | Crates never strike players | PASS | Player standing in crate 2's lane: closest crate-to-player distance 6.08 studs (clearance 5.5); 29 held steps |
| M3 | Lanes and polarity | PASS | Maximum distance from a lane 0.000 studs; 8/8 moved more than 5 studs while pulling; 8/8 moving back after the flip; push colour shown |
| M4 | MAGNETIC restore | PASS | 8/8 crates exactly restored (CFrame and Colour), 8/8 anchored; baseline matches |
| C1 | Warning before damage | PASS | First node amber at +0.2 s (not yet corrupted); corrupted at +2.3 s |
| C2 | Corruption damage | PASS | On a corrupted disc: 98 → 92 in 2 s, i.e. 4/s damage minus Roblox's default health regeneration of +1/s. 9 studs away: 92 → 94 (regeneration only, no damage) |
| C3 | Spread and cap | PASS | After 22 s: 6 active, 6 corrupted; never more than 6 |
| C4 | CORRUPTION cleanup | PASS | 0 nodes, 0 disc parts; baseline matches |
| F1 | Predictable rise; dry routes | PASS | Water 1.24 at +5 s, 2.50 at +10.5 s. Bridge, North Annex and SkyDeck dry |
| F2 | Slow, non-lethal | PASS | WalkSpeed 16 → 9.6 while wading; SkyDeck 16; Annex 16; back in water 9.6; health 100 → 100 |
| F3 | Real client movement | PASS | Real client steady walking speed: dry 16.0 studs/s, wading 9.6 studs/s (−40%) |
| F4 | FLOOD restore | PASS | WalkSpeed 16.0; 0 slowed; 0 water parts; baseline matches |
| FD1 | FLOATING_DEBRIS start | PASS | Running; 2 patch slots used (the combination uses none); stability 83 → 68 (FLOOD −6, MAGNETIC −5, combination −4); Discovery +10 |
| FD2 | Floating stepping stones | PASS | 8/8 crates floating, centre Y 3.00 (rest 1.50; expected 3.00). On a floating crate: WalkSpeed 16.0, crate moved 0.00 studs while occupied. Wading beside it: 9.6 |
| FD3 | Ends with its source | PASS | FLOOD cancelled → `source_ended`; MAGNETIC still running; 8/8 crates back at resting height within 1.2 s |
| RD1 | RAPID_DECAY speed | PASS | DECAY cycle 5.00 → 3.33 s. Measured group gaps: before 5.22 / 5.17 s; during 3.37 / 3.40 / 3.40 s |
| RD2 | Safety unchanged | PASS | Shortest amber warning before a collapse 2.47 s (2.5 s, with 0.05 s sampling); at most 8 unsafe tiles (cap 8) |
| RD3 | Ends with its source | PASS | CORRUPTION cancelled → `source_ended`; cycle back to 5.00 s |
| SF1 | SLIDE_FIELD | PASS | Running; 4 rings; crate speed 11.2 studs/s (2 × 6, measured over 0.5 s); held 3.5 studs from the point, with no push-back over 12 s |
| SF2 | Ends with its source | PASS | SLIPPERY cancelled → `source_ended`; 0 rings left |
| SF3 | Once per match; no strikes | PASS | MAGNETIC + SLIPPERY again in the same match: no second SLIDE_FIELD. With a player in a lane, the closest crate came to 6.05 studs |
| S1 | SCANNER | PASS | Real client highlights: 3 corruption discs, 4 magnetic crates (plus fragments) |
| L1 | Natural combinations | PASS | Live match 1 with a deliberate Architect (prefers partner cards, submits after 4 s): **RAPID_DECAY** at 102 s, **FLOATING_DEBRIS** at 160 s and **SLIDE_FIELD** at 277 s, all through normal Architect turns. 14 turns, 14 activations, at most 2 of 3 slots |
| L2 | Ordinary Architect | PASS | Live match 2 with random cards after 3–10 s: 13 activations, 0 combinations, at most 2 of 3 slots |
| L3 | Cleanup across consecutive matches | PASS | At LOBBY after each match: 8/8 crates restored, WalkSpeed 16.0, 0 slowed, 0 corruption nodes, DECAY cycle 5.00, Lighting exact, gravity 196.2000, world and arena baselines match, 0 patches, 0 interactions, 0 patch objects |
| L4 | Match end with patches running | PASS | FLOOD, MAGNETIC and CORRUPTION running with FLOATING_DEBRIS (3 slots; player wading at 9.6). At RESULTS: all ended; FLOATING_DEBRIS `source_ended:match_end`; 0 nodes, 0 water parts, WalkSpeed 16.0. At LOBBY: 8/8 crates restored; baseline matches |
| P1 | Server Output | PASS | Two full matches: only `[WORLD_EXE]` info lines; no errors or warnings |
| P2 | Source parity | PASS | 42/42 hash-identical |
| P3 | Edit place clean | PASS | No test scripts or attributes; 8/8 crates at build state; 26 markers; 64/64 DecayTiles solid; Lighting 3.00/0.00; gravity 196.2 |

Totals: **30 PASS, 0 FAIL.**

Not rerun:
- The Phase 3 engine suite (E1–E9) and the Phase 7A suite were not rerun. The shared systems are unchanged: BehaviorRuntime, PatchInteractionService and PatchService code paths. PatchService only gained behaviour-list entries.
- DECAY and the SCANNER, which did change, were retested (RD1–RD3, S1).

Not tested:
- Recovery, shutdown or departure while a 7B patch runs. These use the same `CancelAll` / `Reset` paths, covered for earlier patches.
- MAGNETIC restore while a player stands on a crate's resting spot.
- Multiplayer, deferred to the integration milestone:
  - kinematic crate replication;
  - several players pausing crates;
  - FLOOD slowing several players;
  - corruption damage on several players.

### Design notes for review
- **"Loose physics props" are kinematic.** The crates are anchored and moved by the server instead of being unanchored physics parts. This meets "server-controlled, no ownership exploits, no uncontrolled collisions": nothing can be flung, and no client owns them.
- **MAGNETIC polarity flip.** Pull for 8 s, then push for 8 s. Without it, crates finish within about 4 s and FLOATING_DEBRIS and SLIDE_FIELD would show nothing when their second source arrives later. The crates stay on validated lanes.
- **SUPPLY_DROP shield and CORRUPTION.** The shield blocks one drone hit and is used up by it. It does **not** block corruption damage over time, which would use it up within half a second. Spawn protection (ForceField) does block corruption damage.
- **Crate restore** (superseded by review round 1): crates now return as non-colliding ghosts when their spot is occupied and become solid once it is clear.

### Balancing considerations (carried forward)
- **Combination length:** about 6–10 s, as in 7A. FLOATING_DEBRIS crates rise in under a second, so the effect is visible within that window.
- **Patch frequency:** 13–14 activations per match, as with the 25 s cadence.
- **Higher stability pressure with 7B:** CORRUPTION and FLOOD are severe (−6), and the deliberate Architect also triggered three combinations (−12). Match 1 ended at stability 12 and match 2 at 33, with no repairs (solo). Revisit in playtests together with the repair loop.

## Phase 7A final review (2026-11-10)
ChatGPT approved PR #9 at `0ecbfa4`: no remaining blocking issues. The Architect cadence correction is accepted. Both combinations were demonstrated through normal Architect turns. The 25 s interval, the 35 s BLACKOUT duration and the reduced severity costs are approved as provisional tuning. No additional test round was required.

Closeout (completed):
1. Studio ↔ GitHub parity: 36/36 hash-identical to `0ecbfa4`.
2. Edit place clean (see "Current state").
3. Saved place verified from the file: `Place1.rbxl` (2026-11-10 20:41:38) contains all 36 current script sources and the 8 pads, with no test leftovers.
4. Backup `WorldEXE_post-phase7a_2026-11-10.rbxl` created. Its SHA-256 matches the saved place: `3198C186DEEFA561873DB5C00672EB5AD0C4EB7AEE0A085D40A07EF393625552`.
5. This document and PR #9 were updated.

Carried forward as balancing considerations (not blockers):
- **Short combinations:** at the 25 s cadence a combination lasts about 6–10 s.
- **Higher patch frequency:** 12–13 activations per match, above the design doc's first hypothesis of 5–7. Stability pressure was kept about equal through lower costs.

Still open, by design:
- D3 remains unimplemented.
- Phase 7A multiplayer scenarios stay NOT TESTED and are assigned to the pre-release multiplayer integration milestone.
- Phase 7B requires separate owner approval.

## Phase 7A review round 1 correction (2026-11-10)

ChatGPT reviewed PR #9 at `daab8ac` and returned CHANGES REQUESTED with one gameplay blocker. The rest of the architecture was accepted.

### Finding
**Natural combinations were not reachable.**
- The Architect interval (45 s after each turn ends) was longer than the source patches' lifetimes (30–35 s).
- So two consecutive Architect patches never overlapped.
- In the original 7A tests, combinations were only reached by calling PatchService directly.

### Timing decision
Three provisional tuning values changed. The match timeline, the 3-patch cap, the warnings and submission validation are all unchanged.

| Setting | Before | After | Why |
|---|---|---|---|
| `Config.Architect.TurnIntervalSeconds` | 45 | **25** | The main fix: a modest cadence change instead of changing every patch duration. The next patch now arrives 25 s + decision time after the previous one, which is less than the 35 s source lifetime, so consecutive patches overlap. |
| BLACKOUT `DurationSeconds` | 30 | **35** | The same lifetime as the other combination sources, so HUNTER_SCAN works in both orders. (At 30 s, BLACKOUT → DRONE_SWARM needed a decision in under 5 s.) |
| Stability cost per activation (mild / standard / severe) | −6 / −8 / −10 | **−4 / −5 / −6** | About 1.5× more activations now fit in ACTIVE, so per-activation costs were scaled down to keep total stability pressure per match about the same. The combination cost (−4, approved P4) is unchanged. |

How the overlap works:
- When the next patch becomes ACTIVE, the previous one has 35 − (25 + decision time) seconds left.
- With a 4 s decision, that is about 6 s of combination. A 1 s decision gives about 9 s.
- A combination still needs its two sources accepted in consecutive turns.

Unchanged:
- ACTIVE 420 s + FINAL_PHASE 90 s.
- Architect turns only in ACTIVE.
- The 12 s submission window.
- The 4.5 s warnings.
- `MaxActiveMajor = 3`.
- Every server-side submission check.

### Targeted regressions (solo Studio, 2026-11-10)
Live matches at normal speed (time scale 1). The real client submitted through the real `RequestPatchSubmission` remote with full server validation. No test code called PatchService in T1–T5.

| # | Test | Result | Evidence |
|---|---|---|---|
| T1 | Combinations through normal Architect turns | PASS | Match 1, a deliberate Architect (prefers partner cards, submits after 4 s): **SUPER_BOUNCE** started at 76 s (ZERO_G at 47 s, BOUNCY at 76 s) and **HUNTER_SCAN** at 134 s (BLACKOUT at 105 s, DRONE_SWARM at 134 s). Each ended `source_ended:expired` when its first source expired. Both happened once in the match and paid Discovery once. |
| T2 | Ordinary (random) Architect | PASS (no excess) | Match 2, random cards after 3–10 s: 13 activations, 0 combinations. No consecutive partner pair was drawn, which is valid. Combinations need a deliberate choice. |
| T3 | Activations and stability | PASS | Match 1: 14 turns, 12 activations, stability 100 → 37. Match 2: 14 turns, 13 activations, 100 → 42. No repairs in either (worst case). For comparison, the old cadence with a 4 s decision allows 9 turns in ACTIVE; at the old costs that is about −60 to −70 (an estimate, not measured). |
| T4 | Slots and warnings | PASS | Max patch slots used: 2 of 3 in both matches. At least 2 patches were active for 56 s (match 1) and 43 s (match 2) of 420 s. A new patch is announced at most every ~29 s, with the 4.5 s warning intact. |
| T5 | Match timeline | PASS | Match 2 state watcher: ACTIVE 420 s, FINAL_PHASE 90.2 s, then RESULTS. A turn still open at ACTIVE → FINAL_PHASE was `cancelled`. (The match 1 monitor's 496 s total is a measuring artefact of that script, which polled the snapshot; the transitions were unchanged.) |
| T6 | Cap enforcement | PASS | Match 3: 3 patches requested → accepted; 4th → `capacity_full`. While all 3 slots were full, no Architect turn was offered (deferred). The next turn started only after the slots were freed. |
| T7 | Match cleanup | PASS | After 2 matches, at LOBBY: pads restored, Lighting exact, gravity 196.2000, world at baseline, 0 scan cones, 0 patches, 0 interactions, arena baseline, 0 runtime objects |
| T8 | Server Output | PASS | Only `[WORLD_EXE]` info lines; no errors or warnings |
| T9 | Parity and Edit place | PASS | 36/36 hash-identical. Edit place clean: no test scripts or attributes, pads at build state, Lighting 3.00/0.00, gravity 196.2 |

Totals: **9 PASS, 0 FAIL.** The full 35-test 7A suite was not repeated, per the review.

Observed, not a code defect:
- Match 1 turn 1 timed out although the test client sent a submission. The result listener was attached only later, so the server's reply reason was not captured.
- Every later submission (27) was accepted or correctly refused: `no_open_turn` once after the Architect had died, and once after ACTIVE had ended.

### Notes for review
- **Short combinations.** At this cadence a combination lasts about 6–10 s. Discovery is paid at the start. If longer combinations are wanted, a 20 s interval gives about 11–14 s, at the cost of more activations. This is tuning for 7B or later.
- **Activations exceed the design's first hypothesis.** 12–13 activations per match is above the "roughly 5–7" in `01_GAME_DESIGN.md`, which the old cadence also exceeded (about 9). Stability pressure was kept about equal through the lower costs. Revisit in playtests.
- More accepted patches also mean more Architect score (+5 each). This is provisional.

### Changed files
- `Shared/Config.luau` (TurnIntervalSeconds)
- `Shared/PatchCatalog.luau` (BLACKOUT duration)
- `Services/StabilityService.luau` (severity costs)
- this document

## Phase 7A report — Patch interactions and the first catalog expansion (2026-11-10)

Approved scope (Phase 7A execution approval, P1–P8):
- PatchInteractionService and InteractionCatalog.
- A shared BehaviorRuntime refactor.
- Rotation and balancing.
- Three new patches: BOUNCY, SLIPPERY, BLACKOUT.
- Two combinations: SUPER_BOUNCE, HUNTER_SCAN.
- Dedicated tagged arena content, ANCHOR integration, and match-scoped discovery scoring.

Not included:
- Phase 7B (FLOOD, CORRUPTION and the other combinations).
- D3, persistence, ForgeGUI, publishing.

The match timeline is unchanged.

### Pre-checks (all passed)
- Studio matched `main` `4708e48` on all 28 scripts.
- `WorldEXE_pre-phase7a_2026-11-10.rbxl` was created. Its SHA-256 matches the saved place: `B2252755…B397F3B2`.
- Branch `phase-07a-interactions` created.

### Completed features
- **BehaviorRuntime** (new, server): `RunHook` and `NewContext` were moved out of PatchService unchanged, so patches and combinations share one contract:
  - hooks may not yield (a yielding hook is cancelled);
  - resources are tracked in a CleanupService bag;
  - the context stops working after cleanup.
  - PatchService now delegates to it. Its behaviour is unchanged, and Phase 3 regressions E1–E9 pass.
- **PatchService hooks:**
  - `onActivated(patchId, matchId, runtimeId)`.
  - New `onEnded(patchId, runtimeId, matchId, reason)`, called once per end for every reason: expiry, cancel, match end, reset, recovery, shutdown, failed or yielded activation, match not live. Both callbacks are pcalled.
- **InteractionCatalog** (new, Shared): an allowlist of exactly two combinations:
  - SUPER_BOUNCE = ZERO_G + BOUNCY;
  - HUNTER_SCAN = BLACKOUT + DRONE_SWARM.
  - Any other pair does nothing.
- **PatchInteractionService** (new, server):
  - A combination starts when both sources are ACTIVE in the same live match.
  - It starts at most **once per match** (P4), even if a source runs again. The cap is 5 per match.
  - It holds **no patch slot**, so the major-patch cap is unchanged.
  - It ends as soon as either source ends, with reason `source_ended:<reason>`. It also ends at RESULTS (`match_end`) and on RESET, recovery and shutdown (`Reset`).
  - A failed or yielding activation is rolled back and does not retry in that match.
  - On a successful start (P4/P7):
    - stability −4;
    - +10 Discovery points to every living Participant, with score key `discovery:<match>:<combo>:<userId>`, so it is awarded once per player per match;
    - an announcement to all clients.
  - A bounded history of 50 entries is kept, and `Interactions` is added to the match snapshot.
- **New patches** (P3: dedicated tagged pads only; no existing geometry was modified):

  | Patch | Severity / weight | Duration | Effect | Counterplay | Restore |
  |---|---|---|---|---|---|
  | BOUNCY | mild / 3 | 35 s | The 4 `BounceSurface` pads glow and launch living Participants up at 55 studs/s (rise ≈15 studs) with a LinearVelocity held for 0.12 s; cooldown 1 s per character | Avoid the glowing pads; ANCHOR blocks launches (P5) | Pad colour and material restored; constraints destroyed |
  | SLIPPERY | mild / 3 | 35 s | The 4 `SlipSurface` pads become ice: friction 0.02 with friction weight 100 | Walk slowly or go around; ANCHOR damps sliding on an active pad (P5) | CustomPhysicalProperties, colour and material restored |
  | BLACKOUT | mild / 3 | 30 s (round 1: 35 s) | Lighting Brightness set to 0.5 and ExposureCompensation −1.2, through WorldModifierService tokens | Hazards glow (Neon); SCANNER | Exact baseline restored when the last token is removed |

- **Combinations:**
  - **SUPER_BOUNCE:** launch boost ×1.5. Every launch is clamped so the total rise (hold distance plus ballistic rise) stays at most 35 studs under the current gravity.
  - **HUNTER_SCAN:**
    - Drones get a visible scan cone, cyan while searching and amber before a lock, and aggro range ×1.2.
    - Every new lock is preceded by at least 1.5 s of amber warning.
    - Cones are removed when it ends.
- **Movement precedence** (deterministic, highest first):
  1. ANCHOR: no launch.
  2. Combination boost: the strongest wins.
  3. Base launch.
  4. Apex clamp.
- **ANCHOR integration (P5):**
  - BOUNCY skips anchored players and counts them as `Suppressed`.
  - On an active slip pad, ANCHOR adds a damping VectorForce, `−v_horizontal × mass × 8`. A downward raycast of up to 6 studs checks which pad is underfoot.
  - Grip is not given through the character's own friction, because the Roblox character controller takes traction from the floor.
  - There is no invulnerability.
- **Rotation and balancing (P6, provisional tuning):**
  - Every patch has a Severity and a Weight:

    | Patch | Severity | Weight |
    |---|---|---|
    | ZERO_G | standard | 3 |
    | DECAY | severe | 2 |
    | DRONE_SWARM | severe | 2 |
    | SUPPLY_DROP | mild | 3 |
    | BOUNCY, SLIPPERY, BLACKOUT | mild | 3 |

  - `ArchitectService.ChooseCards` is a weighted draw without replacement. It allows at most 2 severe cards per offer.
  - It excludes running patches and patches accepted in the last 2 turns of the same match.
  - On a shortage it offers fewer cards. With 0 eligible cards the turn is deferred.
  - The stability cost depends on severity: mild −6, standard −8, severe −10. A combination costs −4. (Round 1: now −4 / −5 / −6; the combination cost is unchanged.)
- **Arena content:** `Workspace.WORLD_EXE.Map.PatchSurfaces` holds the new pads, tagged with `SurfaceId` and `Zone` attributes. Floor and clearance were verified at every corner.
  - 4 BounceSurface pads, 6×0.4×6: `BOUNCE_CORE_NW`, `BOUNCE_CORE_SE`, `BOUNCE_YARD_S`, `BOUNCE_YARD_N`.
  - 4 SlipSurface pads: `SLIP_CORE_W`, `SLIP_ANNEX`, `SLIP_YARD_E`, `SLIP_YARD_W`.
  - They are built by `tools/studio/phase7a_surfaces.luau`. Bootstrap validates the new tags (4/4).
- **Client:**
  - HUD banner: `COMBINATION DISCOVERED: <name>`, the warning, and "+10 for everyone still in the match".
  - SCANNER highlights bounce and slip pads.

### Changed / added files
- Added:
  - `Services/BehaviorRuntime.luau`
  - `Services/PatchInteractionService.luau`
  - `Shared/InteractionCatalog.luau`
  - `Patches/Bouncy.luau`, `Slippery.luau`, `Blackout.luau`, `SuperBounce.luau`, `HunterScan.luau`
  - `tools/studio/phase7a_surfaces.luau`
- Changed:
  - Shared: `Config`, `PatchCatalog`
  - Services: `PatchService`, `WorldModifierService`, `StabilityService`, `ScoreService`, `ArchitectService`, `AbilityService`, `MatchService`
  - Patches: `DroneSwarm`
  - Controllers: `AbilityController`, `HUDController`
  - `src/README.md`, this document
- Studio parity: **36/36 scripts hash-identical**. Edit place: the 8 new pads exist at their build state.

### Tests (solo Studio, targeted per the risk-based policy, 2026-11-10)
Most tests used scripts injected into the play server, calling the real services with a real player. Engine and rotation tests ran on a cloned WORLD_EXE in the play server. Client checks ran in the real client.

| # | Test | Result | Evidence |
|---|---|---|---|
| E1 | Phase 3: yielding Activate | PASS | Rolled back (released 2); worst Update 0.0004 s |
| E2 | Phase 3: failed activation | PASS | Full rollback |
| E3 | Phase 3: yielding Deactivate | PASS | Does not delay the end |
| E4 | Phase 3: concurrency cap | PASS | 3 running; 4th rejected |
| E5 | Phase 3: inert context | PASS | Context inert after cleanup |
| E6 | Phase 3: match generation | PASS | Match ended during the warning → never activates |
| E7 | Phase 3: tracked tasks | PASS | Stopped; ticks 9 → 9 |
| E8 | `onEnded` once per end | PASS | activation_yielded, activation_failed, match_end, reset, recovery, shutdown, expired, match_not_live (8/8) |
| E9 | Engine clean | PASS | No resources left |
| R1 | Rotation (3000 simulated offers) | PASS | Excluded offered 0, duplicates 0, at most 2 severe, underfilled 0; all 7 patches offered (1422–1871 each) |
| R2 | Card shortage | PASS | 2 eligible → 2 cards; 0 eligible → 0 cards |
| R3 | Live offers | PASS | Live Architect turns offer the new patches. Match 4 turn 3 offered 3 cards (`BLACKOUT, SLIPPERY, DECAY`) because the other patches were running or recently accepted |
| B1 | BOUNCY launch | PASS | 4 pads glowing; launches +3 at 55.0 studs/s; peak rise 15.3 studs (cap 35) |
| B2 | ANCHOR blocks the launch | PASS | Anchored: launches +0, suppressed +1, rise 0.5 |
| B3 | SUPER_BOUNCE apex clamp | PASS | Gravity 58.86: boosted 82.5 clamped to 57.5; measured rise 36.0 (cap 35, within simulation granularity). The first run measured 43.8 because the clamp ignored the hold distance; fixed and rerun |
| B4 | BOUNCY restore | PASS | Colour and material restored; 0 constraints; 0 active pads |
| C1 | SUPER_BOUNCE start | PASS | Stability 94 → 82 (ZERO_G −8, combination −4); Discovery 0 → 10 |
| C2 | Ends with its source | PASS | ZERO_G cancelled → `source_ended:test`, released 1, errors 0; launch speed back to 55.0 |
| C3 | Once per match | PASS | ZERO_G again with BOUNCY active: no restart; history and score unchanged |
| C4 | Unsupported pair | PASS | DECAY + SUPPLY_DROP: 0 combinations |
| C5 | Same tick; no slot | PASS | ZERO_G + BOUNCY activated together → SUPER_BOUNCE started; patch slots used 2 (the combination uses none). Both ended in one frame → one end record |
| H0 | Control | PASS | Drone at 78 studs (aggro 70), no HUNTER_SCAN → no lock |
| H1 | BLACKOUT lighting | PASS | Brightness 0.50 (baseline 3.00), ExposureCompensation −1.20 (baseline 0.00); HUNTER_SCAN running |
| H2 | HUNTER_SCAN lock | PASS | Cones on 3/3 drones. At 78 studs (hunter range 84): pre-lock warning shown, then locked after 2.17 s (minimum 1.5) |
| H3 | HUNTER_SCAN end and restore | PASS | BLACKOUT cancelled → combination ended; 0 cones; Lighting restored exactly |
| S1 | SLIPPERY slide | PASS | After a 24 stud/s shove: normal floor 0.4 studs, slippery pad 4.8 studs |
| S2 | ANCHOR on ice | PASS | Anchored on an active pad: 0.1 studs. The first approach, character friction, still gave 4.8 and was replaced by the damping force |
| S3 | SLIPPERY restore | PASS | Physical properties, colour and material restored; 0 anchor forces after expiry |
| L1 | Match end | PASS | SUPER_BOUNCE running with BLACKOUT, BOUNCY and ZERO_G (3 slots) → at RESULTS: ended `source_ended:match_end` |
| L2 | Reset | PASS | Pads restored; Lighting exact; gravity 196.2000; world at baseline; 0 interactions in the snapshot; arena baseline; 0 runtime objects |
| L3 | Next match | PASS | Match 4: SUPER_BOUNCE started again; Discovery 0 → 10 (new match key) |
| U1 | Client | PASS | Two `COMBINATION DISCOVERED: SUPER BOUNCE` banners (matches 3 and 4) with warning and +10 line; SCANNER highlighted 2 fragments and 2 bounce pads |
| P1 | Source parity | PASS | 36/36 hash-identical |
| P2 | Server Output | PASS | Lifecycle session: only `[WORLD_EXE]` info lines, no errors |
| P3 | Edit place clean | PASS | No test scripts or attributes; 4+4 pads at their build state; Lighting 3.00/0.00; gravity 196.2 |

Totals: **35 PASS, 0 FAIL.**

Not tested:
- A **combination** activation that fails for real. The shared `RunHook` rollback path is covered by E1/E2; no catalog combination fails on demand.
- MAX_PER_MATCH (5) reached. Only 2 combinations exist, so it cannot be reached in 7A.
- Departure or recovery while a combination runs. The code path is `Reset` in recovery and shutdown, and PatchService's `onEnded` for every reason (E8).
- BLACKOUT appearance on a real client. Server Lighting values were measured; Lighting replicates.
- Multiplayer, deferred to the integration milestone: launches and ice on other clients; Discovery to several players; banners on several clients.

Test-script notes (not code defects):
- The first ANCHOR-on-BOUNCY run was blocked by the bounce cooldown and was rerun.
- One client signal relied on client attributes, which do not replicate. It was switched to timed stages.
- One lifecycle recorder waited on patches with a 4.5 s warning that never became active, and was rerun at a shorter time scale.

### Outstanding risks / notes for review
- **Standing on a bounce pad** relaunches about once per second (the cooldown). This is intended, but tunable.
- **Natural combinations are rare** at the current Architect cadence: the source pair must be accepted within each other's 30–35 s lifetime. In tests they were forced. Revisit with Phase 7B tuning.
- **Apex clamp:** the measured rise is 36.0 against the 35 cap. The physics step adds about 1 stud.
- **ANCHOR lowers jumps:** the Phase 6 note still applies.
- All rotation weights, severity costs, launch speed, ice friction and the hunter multiplier are **provisional tuning** (P6).

## Phase 6 final review (2026-11-10)
ChatGPT approved PR #8 at `03f9cab`: no merge-blocking defects. No additional test round was required.

Notes recorded at the reviewer's request:
- **ANCHOR lowers jumps (tuning consideration).** While ANCHOR is active under ZERO_G, jumps are lower than normal: apex 4.9 studs vs 7.3, airtime 0.45 s vs 0.55 s. Roblox's jump-height mode sets launch speed from the reduced world gravity, while ANCHOR restores full downward acceleration. This is accepted for now as part of being "planted". Revisit during tuning, for example by temporarily adjusting the anchored Humanoid's jump. That would be a separate, approved change.
- **Cooldown attribute timing (clarification).** At RESULTS, `AbilityService.Stop()` ends running effects and clears the `WORLD_EXE_AbilityActive_*` attributes. The `WORLD_EXE_AbilityReady_*` cooldown attributes and server cooldowns are cleared at RESET (and in recovery and shutdown) by `AbilityService.Reset()`, and again when the next match's ACTIVE begins. Requests are refused (`not_live`) throughout RESULTS, so the remaining ready attributes have no gameplay effect.

Closeout (completed):
1. Studio ↔ GitHub parity: 28/28 hash-identical to `03f9cab`.
2. Edit place clean (see "Current state").
3. The owner saved `Place1.rbxl` (2026-11-10 19:11:29). Verified from the file: 28 decoded script sources match `src/`.
4. Backup `WorldEXE_post-phase6_2026-11-10.rbxl` created. Its SHA-256 matches the saved place: `B2252755CFA1DA6FCE1BCC34D64BCEAEF49BAAB88B117A9E4E07A37BB397F3B2`.
5. This document and PR #8 were updated.

Still open, by design:
- D3 remains unimplemented.
- Phase 6 multiplayer scenarios stay NOT TESTED and are assigned to the pre-release multiplayer integration milestone.

## Phase 6 report — Initial player abilities (2026-11-10)

Approved scope: PHASE_DASH, ANCHOR and SCANNER, with the approved decisions:
- **A1:** ANCHOR counters ZERO_G only.
- **A2:** DASH follows the character's horizontal facing.
- **A3:** abilities only in ACTIVE and FINAL_PHASE.

The five review safeguards are applied. Not included: persistence, new patches, ForgeGUI.

### Pre-checks (all passed)
- Studio matched `main` `d648807` on all 25 scripts.
- `WorldEXE_pre-phase6_2026-11-10.rbxl` is SHA-256 identical to the saved place (`13CDA584…FEC74635`).
- Branch `phase-06-abilities` created.

### Completed features
- **AbilityCatalog** (new, Shared, replicated):
  - PHASE_DASH: cooldown 18 s, instant; Q / gamepad X.
  - ANCHOR: cooldown 25 s, lasts 4 s; F / gamepad Y.
  - SCANNER: cooldown 22 s, lasts 6 s; R / D-pad up.
- **AbilityService** (new, server):
  - **Remote:** `RequestAbility` accepts only a table with exactly one key, `abilityId` (a string of 32 characters or fewer, from the catalog).
  - **Rate limit:** per-player token bucket, burst 4, refilling 2 per second.
  - **Checks, in order:** match live (A3), Participant, alive with a root part, cooldown (server clock).
  - **Cooldowns:** match-scoped; they start only on success. Ready and active-until times are mirrored to server-set player attributes.
  - **Replies:** every request is answered on `AbilityFeedback` with ok, reason, seq, readyAt, activeUntil and the scanner targets.
  - **PHASE_DASH (safeguard 1):**
    - The start must not be inside geometry (`GetPartBoundsInBox`, because a blockcast cannot detect an initial overlap).
    - A character-sized 2×4×2 blockcast sweep stops 1.5 studs before obstacles.
    - Each candidate landing must be inside `Config.ArenaBounds`, have collidable floor within 12 studs below (collapsed DECAY tiles do not count), and not overlap geometry. Otherwise the dash steps back 2 studs at a time.
    - Under 3 studs: rejected (`blocked`, `no_ground`, `start_blocked`) and the cooldown is not used.
    - The server moves the character with `PivotTo`, keeping orientation, and zeroes velocity.
  - **ANCHOR (A1, safeguard 2):**
    - A `VectorForce` with `RelativeTo = World` and `ApplyAtCenterOfMass = true`.
    - Force = (0, −(baseline gravity − current gravity) × `AssemblyMass`, 0). It is recomputed when `Workspace.Gravity` changes or the character gains or loses parts.
    - It never writes `Workspace.Gravity` and gives no damage reduction or ForceField.
  - **SCANNER (safeguard 3):** the server selects, closest first, up to 20 of these within 60 studs:
    - data fragments, drones, supply crates, DECAY tiles that are warned or collapsed (`Decay.GetClaimedTiles()`, a new read-only accessor).
    - The list goes to that player only.
  - **Cancellation (safeguard 4):** each timed effect owns a CleanupService bag.
    - It ends on expiry, death (`Humanoid.Died`), role change, character removal, departure (`OnPlayerLeft`), RESULTS (`Stop`), and RESET, recovery and shutdown (`Reset`).
    - Expiry timers are identity-guarded, so a stale timer cannot end a newer effect.
    - An early end sends `cancelled` with the effect's seq.
- **AbilityController** (new, client):
  - Bindings through ContextActionService (keyboard, gamepad and touch buttons). E stays free for ProximityPrompts.
  - Ability bar (bottom centre): `[Q] Phase Dash READY / 15s / ACTIVE n`. Shown only to Participants in ACTIVE or FINAL_PHASE.
  - Rejection toasts: "On cooldown", "Path blocked", "No ground there", "Too fast", "Not available".
  - SCANNER highlights are client-only `Highlight`s parented to their targets.
  - A per-player seq means older, duplicate or already-expired results are ignored, and `cancelled` clears the matching scan.
  - Highlights are removed on expiry, character removal and when the match is no longer live. At most 20.
- **Wiring:**
  - `Config`: version 0.6.0-phase6, the `RequestAbility` / `AbilityFeedback` remotes (created by NetService), and the `AbilityReadyPrefix` / `AbilityActivePrefix` attributes.
  - `MatchService`: Init, Begin at ACTIVE, Stop at RESULTS, Reset at RESET, recovery and shutdown, `OnPlayerLeft`. No new loop.
  - `ClientBootstrap` starts the controller.

### Changed / added files
- Added:
  - `Shared/AbilityCatalog.luau`
  - `Services/AbilityService.luau`
  - `Controllers/AbilityController.luau`
- Changed:
  - `Shared/Config.luau`, `Services/MatchService.luau`
  - `Patches/Decay.luau` (read-only `GetClaimedTiles`)
  - `ClientBootstrap.client.luau`
  - `src/README.md`, `docs/PROJECT_STATUS.md`
- Unchanged:
  - The other patches, PatchService, Architect, Stability/Score/Objective/Collectible, PlayerStateService and the HUD.
  - All geometry.
- Studio parity: 28/28 scripts hash-identical.

### Finding for review: ANCHOR and jumping
Roblox characters use `UseJumpPower=false` (jump-height mode): the engine sets jump launch speed from **world** gravity.

Under ZERO_G (58.86), an anchored character launches at the low-gravity speed but falls at full 196.2. Measured on a real client:

| Situation | Airtime | Apex |
|---|---|---|
| Unanchored, ZERO_G | 0.98 s | 7.4 studs |
| Anchored, ZERO_G | 0.45 s | 4.9 studs |
| Normal gravity, no anchor (Phase 4 measurement) | 0.55 s | 7.3 studs |

So ANCHOR "plants" the player as intended (fast, heavy falls; no floating) but also lowers jumps while it lasts. That fits "planted" and A1. Changing the Humanoid's jump settings would be a separate mechanic, so it was not done.

### Tests (solo Studio, targeted per the risk-based policy, 2026-11-10)
Tests used a script injected into the play server that calls `AbilityService.Request(player, payload)`, the same function the remote handler calls, with a real player. Client checks ran in the real client. The final check used real key presses.

| # | Test | Result | Evidence |
|---|---|---|---|
| V1 | Malformed payloads | PASS | `"x"`, `5`, `{}`, unknown id, an extra key, a 40-character id, NaN, an array, a boolean id → all 9 `bad_payload` |
| V2 | Rate limit | PASS | 12 rapid requests: 4 processed, 8 `rate_limited` |
| V3 | State gates (A3) | PASS | INITIALIZING → `not_live`; Spectator → `not_participant`; dead → `not_alive`; RESULTS and LOBBY → `not_live` (L1) |
| D1 | Open-floor dash | PASS | Moved exactly 16.0 studs |
| D2 | Cooldown | PASS | Immediate second dash → `cooldown`; ready attribute 18.0 s ahead |
| D3 | Walls never crossed | PASS | Facing CoverWall_W, CoverWall_E, CoverWall_N and CoverWall_S from 8 studs: each `dashed 5.5`, distance from wall centre 9.0 → 3.5 (stops 1.5 short; never crossed) |
| D4 | Start inside geometry | PASS | Inside CoverWall_W → `start_blocked`; cooldown not used |
| D5 | Ledge | PASS | Edge 4 studs ahead → `no_ground` (no cooldown used); edge 10 studs ahead → shortened to 8.0, landing on SkyDeck 2 studs from the edge |
| D6 | Collapsed DECAY tiles | PASS | 2 tiles ahead set non-collidable → dashed only 4.0 and landed on a solid tile (`Tile_R4C1`), never on a collapsed one |
| D7 | Arena bounds | PASS | Lobby (outside the arena bounds, with floor in all 4 directions) → every dash refused |
| D8 | Dash out of a repair | PASS | Repair started, dashed 10 studs to 14 from the stabilizer (radius 10) → repair PAUSED at 26% |
| A1 | Anchor force parameters | PASS | Present, `RelativeTo=World`, `ApplyAtCenterOfMass=true`; at normal gravity Force = (0,0,0) |
| A2 | Anchor force under ZERO_G | PASS | Gravity 58.86, mass 13.26 → Force Y −1821.4 (expected −1821.4); the client sees the same force |
| A3 | Real client effect | PASS | ZERO_G airtime 0.98 s → anchored 0.45 s (see the finding above) |
| A4 | Not invulnerable | PASS | While anchored, `TakeDamage(10)` 100 → 90; no ForceField |
| A5 | Expiry | PASS | Force gone after 4.3–4.5 s; active attribute cleared |
| A6 | Death cancels | PASS | 0.15 s after death: 0 effects, attribute cleared |
| A7 | Role change cancels | PASS | Set to Spectator → force removed immediately, 0 effects |
| S1 | Scanner targets | PASS | 3 fragment highlights (farthest 36 studs). With DRONE_SWARM and DECAY active: 8 highlights (2 fragments, 3 drones, 3 DECAY tiles), farthest 46 studs (range 60, cap 20) |
| S2 | Out-of-order and expired feedback | PASS | An older-seq result and an already-expired result were both ignored (highlights stayed 3); `cancelled` cleared them (0) |
| S3 | Expiry | PASS | Rescan → 3 highlights → 0 after 6 s |
| L1 | RESULTS cancels everything | PASS | ANCHOR and SCANNER active right before the end (2 effects, 2 force instances, 4 attributes) → at RESULTS: 0 effects, 0 forces, active-until attributes cleared, request → `not_live`; client: 0 highlights, bar hidden. (Cooldown/ready attributes are cleared at RESET, not RESULTS; see L2.) |
| L2 | Reset and next match | PASS | After RESET: 0 effects, forces and attributes; lobby request → `not_live`. Match 2: everything ready, SCANNER works again; bar shown again |
| K1 | Real keyboard input | PASS | Real key presses Q, F, R, Q in the client: dash, anchor and scanner activated (ready 14.9 / 22.7 / 20.6 s), the second Q showed "On cooldown", bar `[Q] Phase Dash 15s | [F] Anchor ACTIVE 2 | [R] Scanner ACTIVE 5` |
| P1 | Source parity | PASS | 28/28 hash-identical |
| P2 | Server Output | PASS | Lifecycle session: only `[WORLD_EXE]` info lines, no errors. (Output from the earlier dash/anchor/scanner session was not captured before it was stopped.) |
| E1 | Edit place clean | PASS | No test scripts or attributes; 64/64 DecayTiles collidable (the D6 test restored them); 12 FragmentSpawn; gravity 196.2 |

Totals: **27 PASS, 0 FAIL.** Not tested:
- Departure while an effect is active. Solo departure ends the session; the code path is `OnPlayerLeft` → end all effects.
- Recovery and shutdown cancellation. The code path is `AbilityService.Reset()` in `recover()` and `Shutdown()`; it was not triggered live.
- Anchor update when character mass changes. Wired to `DescendantAdded` / `DescendantRemoving`; no mass change happened.
- Gamepad and touch input. Bindings are registered; touch buttons appear only on touch devices.
- Multiplayer (deferred to the integration milestone): other clients seeing dashes and anchored players; scanner results private to one client; two players using abilities at once.

Test-script notes (not code defects): the first Barrier_1 wall attempt and the first lobby check started from points without floor in my own search, so they were rerun with better placement (D3, D7). One lifecycle attempt started after the match had already begun at full time scale and was restarted.

### Outstanding risks
- **ANCHOR lowers jumps** while active (see the finding).
- **Dash replication:** the dash is a server teleport; its smoothness on other clients is unverified (multiplayer).
- **Low walls are tested:** the cover walls are 3–4 studs high and the body box spans ±2 studs around the root part. Very thin or low obstacles below the box are not obstacles by design.
- **SCANNER and streaming:** highlights rely on targets being streamed to the client. Targets more than 60 studs away are never sent; with streaming, a far target arrives as nil and is skipped.
- **Icons:** none (text-only placeholder UI).

## Phase 5 final review (2026-11-10)
ChatGPT approved Phase 5 at `6e7ed2e`: no remaining blocking code issues. It accepted the aborted-match outcome correction, the reward policy, the departed-player award protection, results compatibility, and the targeted regressions.

Closeout (completed; no full re-test and no multiplayer session, per review):
1. Studio ↔ GitHub parity: 25/25 scripts hash-identical to `6e7ed2e`.
2. Edit place clean: no test scripts, attributes or runtime objects; rings at their original colour; 12 FragmentSpawn markers and 64 DecayTiles; gravity 196.2.
3. The owner saved `Place1.rbxl` (2026-11-10 18:16:45). Verified from the file: 25 decoded script sources match `src/`, and 12/12 FragmentSpawn ids are present.
4. Backup `WorldEXE_post-phase5_2026-11-10.rbxl` created. Its SHA-256 matches the saved place: `13CDA584FCF8C65F22044D67DF9CFCD45043F2669F21F8456304ADCCFEC74635`.
5. This document and the PR #6 description were updated.

Still open, by design:
- D3 (stability changing match flow) stays unimplemented, pending a separate design decision.
- The Phase 5 multiplayer scenarios stay NOT TESTED and are assigned to the multiplayer integration milestone before public release.

## Phase 5 review round 1 correction (2026-11-10)

ChatGPT reviewed PR #6 at `347cb59`: CHANGES REQUESTED, one results-consistency blocker. The rest of the architecture was accepted.

### Finding and resolution
1. **Aborted matches could report team success.**
   - The problem: `MatchService.buildResults()` called `ScoreService.Finalize(stability, repairs)` for every outcome. Stability starts at 100, so an aborted match could show `Team.Success = true`.
   - Fix: the signature is now `Finalize(stability, repairs, outcome, outcomeReason)`, and MatchService passes the match outcome.
   - **Completed matches** (`outcome == "completed"`): unchanged rule, success if stability ≥ 50 OR repairs ≥ 3.
   - **Aborted matches** (any other outcome, today `"aborted"` / "no participants"):
     - `Team.Success = false` and the new field `Team.Aborted = true`.
     - `Team.Reason = "match aborted (<reason>): no team result"`.
   - **Aborted reward policy (explicit):**
     - Players still placed get the participation reward only (+20). No team bonus, no placement bonus.
     - Every row has `Placement = 0` (unplaced), still ordered by score.
     - Left rows get nothing, as before.
     - In practice an abort happens only when no participants remain, so every row is Left and rewards are 0.
   - `Finalize` stays idempotent: a second call returns the same table, whatever arguments it is given.
   - Compatibility: all existing `LastResult` fields are kept; `Team.Aborted` is additive. The HUD shows "MATCH ABORTED — …" and "-" for an unplaced row.
2. **Defensive change (accepted suggestion):** `ScoreService.Award()` now ignores players marked `Left`.
   - A Left row keeps exactly the score the player had when they left.
   - This also covers a repair or Architect award that lands after its player has gone.
   - No Phase 5 rule needs to award departed players.

### Changed files
- `Services/ScoreService.luau`: Finalize signature and aborted policy; Left guard.
- `Services/MatchService.luau`: passes `outcome`, `outcomeReason`.
- `Controllers/HUDController.luau`: aborted label; "-" placement.
- `docs/PROJECT_STATUS.md`.
- Parity: 25/25 scripts hash-identical (ScoreService 8723 bytes, hash 292975779; MatchService 16801/733335019; HUDController 11114/850775587).

### Targeted regressions (as requested; the full Phase 5 matrix was not repeated)
| # | Test | Result | Evidence |
|---|---|---|---|
| 1 | Abort during INITIALIZING with stability 100 | PASS | Live: the only player was kicked during INITIALIZING (stability 100) → `INITIALIZING -> RESULTS (no participants)`; `Success=false Aborted=true` "match aborted (no participants): no team result"; row Left, place 0, rewards 0 |
| 2 | Abort during ACTIVE with high stability | PASS | Live, match 2: kicked during ACTIVE at stability 100 → outcome aborted; `Success=false Aborted=true`; row Left, place 0, rewards 0 (P0 T0 Pl0); the reset afterwards was clean (ledger inactive, stability 100, 0 fragments, 0 runtime effects) |
| 3 | Completed, stability ≥ 50 → success | PASS | Clone: stability 50 → success; rewards 170 (20+100+50) / 150 (20+100+30). Live match 1 completed: `Success=true Aborted=false` "stability 100 >= 50", place 1, rewards 170 |
| 4 | Completed, repairs ≥ 3 → success | PASS | Clone: stability 10, 3 repairs → success "3 repairs >= 3" |
| 5 | Completed below both thresholds → failure | PASS | Clone: stability 49, 2 repairs → failure; participation + placement kept (70) |
| 6 | Finalize twice → no duplicate rewards or score changes | PASS | Clone: the second call (with different, aborted arguments) returned the same table; score, rewards and total unchanged; a later Award was ignored |
| 7 | Reset and next match start clean | PASS | Live: after match 1 RESULTS/RESET, match 2 ACTIVE had a new ledger (score 0, repairs 0, score attribute 0, no fragments attribute), stability 100, 8 fragments, stabilizers IDLE, 0 repairs |
| U1 | Aborted with stability 100 and 5 repairs → no success, no team/placement rewards | PASS | Clone: `Success=false Aborted=true`; both rows place 0, rewards 20 (participation only) |
| D1 | Award to a Left player ignored | PASS | Clone: after MarkLeft, a +50 award returned false; the Left row kept 10 points and got 0 rewards |
| P1 | Source parity, Output, Edit place | PASS | 25/25 identical; Output only `[WORLD_EXE]` lines plus the test's own kick message; Edit place clean |

Totals for round 1: **10 PASS, 0 FAIL.**

Not tested:
- The "MATCH ABORTED" HUD label on a real client. The abort path removes the only client in solo tests; the change is a display-only label.

Method notes:
- Score rules were tested on a cloned ScoreService inside a play server. Edit-mode tool context caches the old Config, which is a known Studio MCP limitation.
- Live aborts were produced by kicking the only player, which makes the participant list empty: the real abort trigger.

## Phase 5 report — Stability, objectives, collectibles, scoring (2026-11-10)

Approved scope: the stability meter, the three stabilizer objectives, data fragments, individual and team scoring, results with placements and match-scoped rewards, and the HUD. The proposed design defaults were used as provisional tuning.

Not included: persistence, DataStores, new patches, abilities, ForgeGUI.

### Pre-checks (all passed)
- `main` at `9f760c6`, matching Studio on all 21 scripts.
- Backup `WorldEXE_pre-phase5_2026-11-10.rbxl` is SHA-256 identical to the saved place (`F4DF639A…68FE90FF`).
- Branch `phase-05-objectives-scoring` created.
- Reviewed docs 01, 02, 03, 05 and 06, plus MatchService, PlayerStateService, PatchService and Bootstrap.

### Flagged for owner review — deliberately NOT implemented
- **D3, stability affecting match flow:** the plan proposed that stability ≤ 25 starts FINAL_PHASE early and that stability 0 ends the match as a failure. That changes match length and the victory conditions, so per the approval conditions it is **not implemented**.
- In Phase 5, stability only affects the team outcome at RESULTS. The match timeline is unchanged.
- Owner decision needed: enable D3 (and at what values), or keep stability results-only.

### Completed features
- **StabilityService** (new):
  - Server-only `Adjust(delta, reason)`, clamped to 0–100; starts at 100 every match.
  - −8 when any patch goes ACTIVE (via a new optional `PatchService.Init` `onActivated` callback, wrapped in a pcall so it can never affect the patch). +15 per completed repair.
  - Snapshot fields: `Stability`, `StabilityMax`. No remote can change it.
- **ObjectiveService** (new): the three existing stabilizers (`STAB_CORE`, `STAB_SKY`, `STAB_YARD`) are discovered from their tags and attributes.
  - Each match, a ProximityPrompt sits on an invisible anchor part in `RuntimeEffects` at the stabilizer's InteractionPoint. The Map itself is never given new instances; only the StatusRing color changes (visual only, restored at reset).
  - States: IDLE → REPAIRING ⇄ PAUSED → COOLDOWN → IDLE.
  - **Start:** a living Participant within InteractionRadius (10) presses the prompt with 3 carried fragments, which are spent. Joining a running or paused repair is free.
  - **Rate:** 6 s solo; up to 3 contributors, each extra one adding +50% speed.
  - **Interruption:** every tick, contributors who leave the radius, die, stop being Participants or disconnect are dropped. With none left the repair PAUSES and keeps its progress.
  - **Completion:** happens exactly once per repair (session counter plus unique score keys). Effects: stability +15, +50 to the player who started it, +25 assist to each other contributor with at least 1 s, then a 60 s cooldown.
  - **Rings:** green = original/idle, amber = repairing, cyan = repaired.
  - Snapshot field: `Objectives` (3 entries: Id, Zone, State, Progress %, Contributors) and `RepairsCompleted`.
- **CollectibleService** (new):
  - Fragments spawn only at the 12 approved `FragmentSpawn` markers. At most 8 exist at once; the field is topped up every 20 s while the match is live.
  - Pickup is by touch, validated on the server: match live, fragment present, living Participant, within 8 studs of the server-side position.
  - The fragment is removed before anything else happens, so it can be collected exactly once.
  - Each pickup gives +1 carried fragment (`WORLD_EXE_Fragments` attribute) and +10 score.
  - Carried fragments are kept on death and cleared at match end and on departure.
  - All fragments are removed at RESULTS and reset.
- **ScoreService** (new):
  - Match-scoped ledger per participant UserId; spectators and joiners have no entry.
  - `Award` with a unique key per event: a duplicate key is a no-op, and awards after finalize are ignored.
  - Points: fragment +10; repair +50; assist +25; survival +5 per 60 s alive; accepted Architect patch +5.
  - Running score in the `WORLD_EXE_Score` attribute.
  - `Finalize` runs once at RESULTS:
    - Team success if stability ≥ 50 OR at least 3 repairs. (Round 1: completed matches only; aborted matches are never a success.)
    - Rewards: participation +20 to every placed player; team success +100 each; placement +50/+30/+15.
    - Ties: score, then repairs, then fragments, then lower UserId.
    - Players who left: a "Left" row with their partial score, no placement, no rewards.
    - At most 16 rows.
  - Nothing is persisted.
- **MatchService integration** (no second loop):
  - INITIALIZING: stability reset, score ledger begins.
  - ACTIVE: objectives and fragments begin.
  - Every tick in ACTIVE/FINAL_PHASE: score survival, fragment waves, objective progress (the snapshot is republished on visible changes, at 5% progress steps).
  - RESULTS: freeze objectives and pickups, award accepted Architect turns, finalize. `LastResult` gains `Team` and `Players`; existing fields are kept.
  - RESET, recovery and shutdown: idempotent resets of all four services before the runtime-folder clear.
  - On player departure: `MarkLeft` and carried fragments dropped.
- **HUD** (backwards compatible):
  - Lines: `STABILITY n/100 ■■■■□□` (amber below 50); `Stabilizers: CORE repaired · SKY repairing 22% · YARD needs repair`; `Score n · Fragments n`.
  - The results panel shows the match line, TEAM SUCCESS/FAILED with its reason, and one row per player (placement, points, reward breakdown, total, fragments/repairs/assists).
- **Arena (documented additive change):**
  - 12 invisible, anchored, non-colliding, non-queryable, non-touchable `FragmentSpawn` markers under `Map.FragmentSpawns` (4 Yard, 3 Core, 3 Sky, 2 Routes; 2 of them on DECAY tiles for risk/reward).
  - Each sits 2.5 studs above a raycast-verified floor.
  - Recorded in `tools/studio/phase5_fragment_spawns.luau`.
  - Validation counts and schema were added to `Config` and are checked generically by ArenaService.
  - No existing geometry was moved or edited.

### Provisional tuning (exact values; rationale)
| Value | Setting | Rationale |
|---|---|---|
| Stability initial / min / max | 100 / 0 / 100 | Design doc §6 ("initialized to 100") |
| Patch activation cost | −8 | About 5–7 patches per match (design hypothesis) → 44–60 without repairs, so the team needs at least some repairs |
| Repair gain | +15 | One repair offsets about two patches |
| Team success | stability ≥ 50 OR ≥ 3 repairs | Approved plan D4 "either" |
| Repair time / co-op | 6 s solo, +50% per extra player, max 3 | Exposes the repairer to hazards briefly; rewards cooperation |
| Repair cost / cooldown | 3 fragments / 60 s | Links collection to objectives; prevents spam |
| Interruption | pause, keep progress | Approved plan D6 default; forgiving with drones/DECAY around |
| Fragments | max 8 at once, top-up every 20 s, pickup range 8 | Bounded and steady supply |
| Score | fragment 10, repair 50, assist 25, survival 5/60 s, Architect 5 | Approved plan D7; no points for harming players |
| Rewards | participation 20, team 100, placement 50/30/15 | Match-scoped only; failure keeps participation and placement |

### Changed / added files
- Added:
  - `Services/StabilityService.luau`, `Services/ScoreService.luau`, `Services/CollectibleService.luau`, `Services/ObjectiveService.luau`
  - `tools/studio/phase5_fragment_spawns.luau`
- Changed:
  - `Shared/Config.luau` (version 0.5.0-phase5, FragmentSpawn tag/count/class/schema, Score/Fragments attributes, Stability and ObjectiveStates)
  - `Services/MatchService.luau`, `Services/PatchService.luau` (`onActivated`), `Bootstrap.server.luau` (comment)
  - `Controllers/HUDController.luau`
  - `src/README.md`, `docs/PROJECT_STATUS.md`
- Unchanged: the patch behaviors, ArchitectService, PlayerStateService, ArenaService, WorldModifierService, CleanupService, NetService (no new remotes), the client modules other than the HUD, and all existing geometry.
- Studio parity: 25/25 scripts hash-identical.

### Tests (solo Studio, targeted per the risk-based policy, 2026-11-10)
Live tests used a Script injected into the play server with the game's own modules, a real player and the real match loop. S1–S10 used a cloned ScoreService with simulated players (needed for multi-player ledgers).

| # | Test | Result | Evidence |
|---|---|---|---|
| B1 | Boot and validation with the new tag | PASS | `Bootstrap ready v0.5.0-phase5 … FragmentSpawn=12 …`, 0 validation errors |
| B2 | Match start state | PASS | ACTIVE: stability 100/100, 3 stabilizers IDLE, 3 prompt anchors in RuntimeEffects, 8 fragments at markers, score attribute 0 |
| ST1 | Patch activation lowers stability | PASS | ZERO_G + DECAY active: 100 → 84 (−8 each); snapshot 84 |
| ST2 | Repair raises stability | PASS | 84 → 99 (+15) |
| ST3 | Live Architect submissions | PASS | 9 accepted ZERO_G: log shows `patch:ZERO_G:-8` ×9, final 28 = 100 − 8×9; Architect credited 9 patches (+45) |
| F1 | Real touch pickups | PASS | 3 pickups by moving the character onto fragments: carried 0→1→2→3, score 0→10→20→30 |
| F2 | Pickup rejections | PASS | Same fragment again → `unavailable`; 150 studs away → `too_far`; Spectator → `not_participant` |
| F3 | Bounded waves | PASS | Never more than 8; after 3 pickups (5 left) the next top-up restored 8 |
| F4 | Cleanup | PASS | RESULTS: 0 fragments. After each reset: Collectibles empty, carried attribute cleared |
| O1 | Fragment cost enforced | PASS | 0 carried → `need_fragments` |
| O2 | Start, duplicate join | PASS | `started` (carried 3 → 0); pressing again → `already_repairing` |
| O3 | Leaving the radius pauses and keeps progress | PASS | 49% → PAUSED, still 49% 1 s later; HUD snapshot `PAUSED 49` |
| O4 | Resume and exactly-once completion | PASS | `resumed` (no cost); completed 3.1 s later → COOLDOWN, repairs 1, score +50, stability +15; join during cooldown → `cooldown`; prompt disabled |
| O5 | Real ProximityPrompt start | PASS | Client pressed "Repair (3 fragments)" at STAB_SKY → REPAIRING, 3 fragments spent |
| O6 | Death interrupts | PASS | Killed at 35% → PAUSED, still 35%, 0 contributors |
| O7 | Match end mid-repair | PASS | Match 2: repair paused at 62% when RESULTS froze it → not counted (repairs 0); clean reset |
| O8 | Ring states | PASS | Original green → repairing amber → repaired cyan (fixed: cooldown was first also green, the rings' own color); restored to original after every reset |
| SC1–SC10 | Score rules (cloned module, 4 simulated players) | PASS | Duplicate key ignored; non-participant can't score; tie order B > C > A (score, then repairs, then fragments, then UserId); left player unplaced with no rewards; team failure keeps participation and placement (20+50, 20+15); finalize once; awards after finalize ignored; success by 3 repairs; success by stability 50; reset clears the ledger |
| R1 | Live results match server state | PASS | Match 1: TEAM SUCCESS (stability 99 ≥ 50); row: place 1, score 130 (= ledger 130), rewards 170 (20+100+50), total 300, fragments 6, repairs 1 |
| R2 | Live team failure | PASS | Match 3: stability 28, 0 repairs → TEAM FAILED "stability 28 < 50 and 0 repairs < 3" |
| R3 | Results HUD | PASS | Client: `TEAM SUCCESS — stability 99 >= 50` / `1. amfam1 — 130 pts + 170 rewards (participation 20, team 100, placement 50) = 300 · fragments 6, repairs 1, assists 0` |
| H1 | Live HUD lines | PASS | `STABILITY 99/100 ■■■■■■■■■■` / `Stabilizers: CORE repaired · SKY repairing 22% · YARD needs repair` / `Score 115 · Fragments 0` |
| P4 | Phase 4 patches together with objectives | PASS | Repair and pickups ran while ZERO_G (gravity 58.86) and DECAY were active; 9 live ZERO_G patches with clean expiry; 3-patch cap untouched |
| L1 | Repeated matches, no leftovers | PASS | After resets 1 and 2: Collectibles 0, RuntimeEffects 0, stabilizers IDLE with original rings and no prompts, stability 100, score/fragment attributes cleared, arena baseline true (including the 12 markers) |
| P1 | Source parity | PASS | 25/25 hash-identical |
| P2 | Server Output | PASS | Only `[WORLD_EXE]` info lines (including `Stabilizer STAB_CORE repaired`); no errors or warnings |
| E1 | Edit place clean after play | PASS | No test scripts or attributes; 12 FragmentSpawn and 64 DecayTile intact; gravity 196.2 |

Totals: **36 PASS, 0 FAIL** (SC1–SC10 counted as ten). Not tested (deferred to the multiplayer integration milestone):
- Co-op repair with two or three real players: speed bonus and assist credit live. Logic is covered by SC rules and code review only.
- Two players racing for the same fragment.
- A real player leaving mid-repair or mid-match. MarkLeft is covered by SC4; the departure path itself is unobserved.
- Mid-match joiner, as a Spectator, has no score.
- Results with several rows on real clients.

### Outstanding risks / open decisions
- **D3 (owner):** should stability affect match flow (early FINAL_PHASE or an early end)? Not implemented.
- **Balance:** with the default cadence (~5–7 patches) and no repairs, stability ends around 44–60, so team success hinges on repairs. Needs playtests.
- **Touch pickups:** the client can influence touch events, so the server-side 8-stud distance check is the safeguard.
- **Fragments on DECAY tiles:** they can be briefly unreachable while a tile is collapsed (by design).
- **Repair credit:** the player who started a repair gets the repair credit even if others finish it (they get assists).
- **Placeholder visuals:** fragments are cyan neon spheres and prompts are invisible anchors.
- **Multiplayer:** all multiplayer behavior is untested (see the list above).

## Phase 4 final review (2026-11-10)
ChatGPT approved Phase 4 at `c7f5186`: no remaining blocking code issues. All three drone corrections were inspected and accepted, and the risk-based testing documentation was accepted.

Closeout (completed; no full re-test and no two-client session, per review):
1. Studio ↔ GitHub parity: 21/21 scripts hash-identical to `c7f5186`.
2. Edit place clean: no test scripts, attributes or runtime objects; 64 DecayTiles; gravity 196.2.
3. The owner saved `Place1.rbxl` (2026-11-10 17:35:27). Verified from the file: its 21 decoded script sources match `src/` exactly.
4. Backup `WorldEXE_post-phase4_2026-11-10.rbxl` created. Its SHA-256 matches the saved place: `F4DF639AB773961792E97BF2FB305751D64ABAFCF6B11BD0F598C86368FE90FF`.
5. This document and the PR #5 description were updated.

The multiplayer scenarios stay NOT TESTED and are assigned to the multiplayer integration milestone, which is required before public release (see "Testing policy and deferred multiplayer validation").

## Phase 4 review round 1 correction (2026-11-10)

ChatGPT reviewed PR #5 at `a1e4b46`. Overall architecture: ACCEPTABLE. Three drone changes were requested, plus multiplayer acceptance. Under the revised testing policy (below), multiplayer acceptance is deferred.

### Findings and resolutions (commit `52365e1`, `Patches/DroneSwarm.luau` only)
1. **Drone targeting: clear disengagement.**
   - A new constant `DISENGAGE_RANGE = 90` studs (new locks still need ≤ `AGGRO_RANGE = 70`, giving hysteresis).
   - It is checked every step (10 Hz) for an existing lock. Line of sight is still checked at every 1 s retarget and before every hit.
   - Drones (14 studs/s) are slower than players (16), so running away always escapes.
   - A `Disengaged` counter was added to `GetStats()`.
2. **Capacity policy: all or nothing.** A swarm spawns exactly `DRONES_PER_PATCH` (3) drones, or none.
   - If fewer than 3 drone slots are free (`MAX_DRONES = 6` across all swarms) or fewer than 3 waypoints exist, activation fails. That means full rollback and the patch slot is released.
   - Partial swarms are never spawned. With a cap of 6 that allows exactly two concurrent swarms.
3. **Spawn protection takes precedence over the shield.** Protection order in `hit()`:
   1. ForceField: hit blocked, nothing used (`Protected` counter).
   2. Supply shield: blocked and used up.
   3. Otherwise: 15 damage.

### Targeted solo regressions (real game modules, real player; previously passed Phase 4 tests were not repeated)
| # | Test | Result | Evidence |
|---|---|---|---|
| R1 | Drone stops pursuing a player beyond the disengage range | PASS | A locked drone's target was moved to 132 studs (> 90). The lock dropped after 0.12 s, before the 1 s retarget, so it was the range rule. `Disengaged` +2 (two drones were locked). No re-lock afterwards. Drone–player distance went 132 → 108 over 3 s while the drone returned to its patrol waypoint; full-speed pursuit would close 42 |
| R2 | Capacity policy | PASS | Three concurrent swarms: 3 + 3 drones; the third → `activation_failed` "drone cap reached (6/6, a swarm needs 3)", 0 drones spawned, slot released. Active count 6 |
| R3 | ForceField precedence | PASS | Shield granted plus ForceField: 2 hits counted as `Protected`, shield kept, 0 shield blocks, 0 damage (health 100 → 100). With the ForceField removed: the next hit used the shield (blocked +1) |
| R4 | Cleanup after the regressions | PASS | `CancelAll`: 0 drones, active count 0 |
| R5 | Source parity | PASS | 21/21 scripts hash-identical (DroneSwarm 11195 bytes, hash 946438829) |
| R6 | Edit place clean after play | PASS | No test scripts, attributes or runtime objects; gravity 196.2 |

Two test-script bugs were fixed and rerun; neither was an engine defect:
- A capacity read was taken before the 3.6 s warning ended.
- A `string.find` pattern treated `-` in `P1-4` as a pattern character.

The Output showed only the test script's own error from those runs and the intended cap rejections.

### Testing policy and deferred multiplayer validation (owner decision 2026-11-10)
Owner direction:
- Run automated and targeted solo tests routinely, chosen by the risk a change introduces.
- Batch multiplayer testing across phases into an integration milestone.
- Don't ask the owner to launch Clients and Servers per phase or per fix.
- Run comprehensive multiplayer testing **before public release**.
- Keep a complete regression suite for milestones and release candidates.

**Deferred multiplayer scenarios (NOT TESTED, carried to the multiplayer integration milestone):**

| Scenario | Risk while untested |
|---|---|
| Two players each claim one item from the same crate (second item, empty crate) | Logic is per-UserId and server-only (one claim per player is verified solo); risk is low, but the "crate empties after two claims" path has never run |
| Drone targeting, damage and shields across two clients | Damage is server-side `TakeDamage` and replicates through the Humanoid; risk is mainly visual (drones move as 10 Hz anchored CFrames and may look choppy) |
| Player disconnecting during an active patch (drone target, claimer) | Targets are re-checked every step (`player.Parent`) and per-player tables are weak-keyed, but a real departure has not been observed |
| ZERO_G gravity and DECAY tile replication on both clients | `Workspace.Gravity` and part properties replicate natively; risk is low, but readability at a distance is unverified |
| Concurrent patch cleanup at match end with two players | Verified solo (M1); the risk with two players is only replication of the cleanup |
| Server and both client Outputs during the above | Unknown until run |
| Carried from earlier phases: real mid-match join → Spectator; multiplayer spawn-protection window; > 12 players; streaming at distance; pending-respawn invalidation on departure; Phase 3 multi-client run | See the Phase 2 and Phase 3 sections |

## Phase 4 report — Four prototype patches (2026-11-10)

Approved scope: the four prototype patch behaviors, plugged into the Phase 3 `PatchService`. Nothing beyond that: no new patches, combinations, scoring or abilities. No ForgeGUI. Visuals are placeholder parts built in code.

### Pre-checks (all passed, no blockers)
- PR #3 merged (`c2ab456`); `main` at `abac96f`. Local `main` was synced.
- Studio matched `main` on all 18 scripts before any change.
- Backup `WorldEXE_pre-phase4_2026-11-10.rbxl` created, SHA-256 identical to the saved place (`2663A50D…F11FBB98`).
- Branch `phase-04-prototype-patches` created from `main`.
- Reviewed docs 02, 03, 05 and 06, and the arena's tagged content:
  - 64 DecayTiles in an 8×8 Research Yard grid with nothing beneath them;
  - 15 linked DroneWaypoints;
  - 5 SupplyLandingPoints.

### Completed features
- **ZERO_G** (`Patches/ZeroG`): one gravity `multiply 0.3` token through `WorldModifierService` (196.2 → 58.86).
  - It composes with other gravity tokens and is removed when the patch ends.
  - It never writes `Workspace.Gravity`.
- **DECAY** (`Patches/Decay`): only BaseParts tagged `DecayTile` inside the arena Map.
  - Cycle: every 5 s, a group of up to 4 random free tiles turns amber neon (warning). After 2.5 s they become non-solid and see-through (red ForceField material) for 4 s, then are restored.
  - At most 8 tiles are unsafe at once, across all DECAY patches. A shared claim table stops two DECAY patches from fighting over a tile.
  - Only Color, Material, Transparency and CanCollide change. A restore-all runs at patch end for any reason.
  - Destroyed or missing tiles are skipped without error.
- **DRONE_SWARM** (`Patches/DroneSwarm`):
  - 3 drones per patch, spawned at distinct waypoints, at most 6 alive across all swarms. With no room, activation fails: full rollback, slot freed. (Round 1 made this explicitly all or nothing.)
  - One tracked loop per patch at 10 Hz, retargeting every 1 s. No pathfinding: drones patrol the waypoint graph and chase only a target with clear line of sight within 70 studs.
  - Targets are living Participants only.
  - Speed 14 studs/s, below the default walk speed of 16.
  - A locked drone turns amber.
  - A hit needs range 5, line of sight, a 1.5 s per-drone cooldown and a 0.75 s per-player cooldown shared by all drones. It does 15 damage, never an instant kill. The shield and spawn-protection ForceField block hits.
- **SUPPLY_DROP** (`Patches/SupplyDrop`):
  - A random free tagged landing point (never client input), not shared with another active drop.
  - A cyan beacon column appears at once; 3 s later a crate lands with a ProximityPrompt. The crate holds 2 items, at most 1 per player.
  - Every claim goes through `SupplyDrop.TryClaim` on the server, which checks: patch live, crate present, living Participant, 1 s attempt cooldown, within 12 studs, not already claimed from this crate, not already shielded, items left.
  - Reward: a **shield** that blocks the next drone hit, for up to 45 s.
  - An empty crate despawns, and unclaimed supplies despawn at patch end.
- **Shield state** (`PlayerStateService.GrantShield` / `HasShield` / `ConsumeShield`):
  - Stored as a server-set expiry attribute, `WORLD_EXE_ShieldUntil`.
  - Cleared on death and on every role change, so RESET and recovery clear it too.
  - The HUD shows `SHIELD m:ss`.
- **Engine wiring**:
  - `PatchService` maps each approved id to its module (`BEHAVIOR_MODULES`) and fails loudly at Init if one is missing.
  - The Phase 3 `Placeholder` module was removed.
  - `Config` version `0.4.0-phase4`, plus `PlayerAttributes.Shield`.
  - The HUD banner no longer says "Patch effects arrive in Phase 4".
- Every behavior follows the Phase 3 rules:
  - `Activate` is short and non-yielding. Deactivate is not used.
  - All instances, connections, timers and loops go through `ctx.Add`, `ctx.AddModifier`, `ctx.Spawn` and `ctx.Delay`.
  - Loops check `ctx.IsLive()`.
  - Everything is reversed when the patch expires, is cancelled, or the match ends.

### Changed / added files
- Added: `src/ServerScriptService/WORLD_EXE/Patches/` `ZeroG.luau`, `Decay.luau`, `DroneSwarm.luau`, `SupplyDrop.luau`.
- Removed: `src/ServerScriptService/WORLD_EXE/Patches/Placeholder.luau` (also deleted in Studio).
- Changed:
  - `Shared/Config.luau`, `Shared/PatchCatalog.luau` (comment)
  - `Services/PatchService.luau`, `Services/PlayerStateService.luau`
  - `Controllers/HUDController.luau`
  - `src/README.md`, `docs/PROJECT_STATUS.md`
- Unchanged: MatchService, ArchitectService, ArenaService, NetService, WorldModifierService, CleanupService, TestBehaviors, the remaining client modules, and all arena and lobby geometry (the arena baseline matched after every reset).
- Studio parity: 21/21 scripts hash-identical to `src/`.

### Design decisions for review
1. **Placeholder parts built in code.** The ServerStorage templates in the architecture doc wait for approved artwork (ForgeGUI needs owner approval). Drones are neon spheres and the crate is an amber box; both are easy to swap for templates later.
2. **Tuning stays in each server module.** `Config` is replicated and must not hold server-only tuning. Each module exports a read-only `Tuning` table for tests.
3. **SUPPLY_DROP reward is a one-hit drone shield.** It is the only reward possible without Phase 5 systems (data fragments and score). It has 2 items per crate, one per player.
4. **DECAY collapse means falling.** Collapsed tiles are non-solid with nothing below, so a player who stays on a warned tile falls out of bounds and respawns under the existing Phase 2 rule. This is offset by the 2.5 s warning on every tile, at most 8 of 64 tiles unsafe, and ~10-stud tiles (one step to safety).
5. **ZERO_G uses multiply 0.3.** Characters use `UseJumpPower=false` (JumpHeight mode), so Roblox keeps the jump apex constant under any gravity. Jumps become floatier (airtime 0.55 s → 0.98 s), not higher. Changing JumpHeight would be a separate, unrequested mechanic, so it is left out.
6. **No pathfinding for drones** (catalog: "simple waypoint steering"). They patrol the waypoint links and chase in a straight line only with line of sight.
7. **Exhausted resources fail activation cleanly.** No drone budget or no free landing point → `activation_failed`, full rollback and the slot is released.

### Tests (all **solo** Studio, 2026-11-10)
Live tests ran a Script injected into the play server that uses the game's own modules, with a real player, the real match loop and real remotes. Engine test D5 used cloned modules.

| # | Test | Result | Evidence |
|---|---|---|---|
| Z1 | Gravity lowered only while active | PASS | Warning 196.20 → active 58.86 (expected 58.86) |
| Z2 | Baseline restored after expiry | PASS | After `expired`: 196.2000 = baseline |
| Z3 | Players keep control in low gravity | PASS | Real client: walk to a point 10 studs away reached (9.5 moved); jump airtime 0.55 s → 0.98 s; apex 7.3 → 7.4 studs (see decision 5) |
| D1 | Only tagged tiles affected | PASS | 20 arena-baseline comparisons during DECAY: 0 differences outside `.DecayTiles.Tile_*` |
| D2 | Every tile warned before it collapses | PASS | 16 collapses, 0 without a warning; shortest warning-to-collapse 2.52 s |
| D3 | Bounded unsafe area | PASS | Max 8 unsafe tiles at once (limit 8 of 64) |
| D4 | Tiles return to baseline | PASS | 64/64 tiles restored (Color, Material, Transparency, CanCollide); claims 0; arena baseline true; released 11, 0 errors |
| D5 | Destroyed tile does not break cleanup | PASS | Engine run: a warned tile destroyed mid-patch → `expired`, 0 cleanup errors, other 63/63 restored, claims 0 |
| DS1 | Drone count capped | PASS | 3 per patch. Three swarms at once: max 6 alive; third → `activation_failed` ("drone cap reached (6/6)"), slot freed |
| DS2 | AI updates bounded | PASS | 8.5 position updates/s per drone (10 Hz step) |
| DS3 | Server-controlled damage cadence | PASS | Real player: health 100 → 85 → 71 → 57 (15 per hit, regen between); gaps 1.58 s and 1.25 s |
| DS4 | Non-Participants not targeted | PASS | Role set to Spectator: 0 locked drones after 1.6 s, 0 hits in the next 2 s |
| DS5 | Dead players not targeted | PASS | After death: 0 locked drones, 0 hits |
| DS6 | Shield blocks one hit | PASS | Blocked +1, health not reduced, shield consumed |
| DS7 | Drones removed on expiry | PASS | `expired`, released 7, 0 errors, 0 drones, active count 0 |
| S1 | Landing point from the server allowlist; overlapping drops use different points | PASS | SUP_SKY; two concurrent drops at SUP_ANNEX / SUP_YARD |
| S2 | Beacon first, then crate | PASS | Crate landed 3.02 s after the beacon, with a prompt |
| S3 | Real ProximityPrompt claim | PASS | Client `InputHoldBegin/End` → server granted a 45.0 s shield; crate "(1 left)"; HUD `SHIELD 0:45` |
| S4 | Too far rejected | PASS | 87 studs → `too_far` |
| S5 | Non-participant rejected | PASS | Spectator → `not_participant` |
| S6 | Dead player rejected | PASS | `not_alive` (the character had fallen out of bounds during an earlier step) |
| S7 | Claim cooldown | PASS | Immediate retry after the prompt claim → `cooldown` |
| S8 | One claim per player per crate | PASS | Retry after 1.1 s → `already_claimed` |
| S9 | Shielded player cannot take another item | PASS | Other crate → `already_shielded` |
| S10 | Expired crate cannot be claimed | PASS | Kept reference after `expired` → `unavailable` |
| S11 | Supply assets removed | PASS | 0 crates, 0 beacons, 0 claimed points, empty runtime folder; 0 cleanup errors |
| S12 | Shield cleared on death and reset | PASS | Death → cleared. A shield granted before match end was cleared after RESET |
| O1 | Unrelated patches together, 4th rejected | PASS | ZERO_G + DECAY + DRONE_SWARM all ACTIVE (gravity 58.86, 3 drones, 4 tiles claimed); SUPPLY_DROP → `capacity_full`; afterwards everything at baseline |
| O2 | Same patch overlapping | PASS | 2 SUPPLY_DROPs on distinct points; 3 DRONE_SWARMs capped (DS1); shared DECAY claims (D3) |
| M1 | Match end cancels running patches | PASS | ZERO_G, DECAY and DRONE_SWARM active at FINAL_PHASE end → all `match_end`, 0 errors. After RESET: gravity at baseline, 0 drones/claims/points, empty folder, arena baseline, shield cleared, `LastResetWorldAtBaseline` true |
| M2 | Repeated matches via real Architect submissions | PASS | Matches 3–5 (scale 0.1): a client auto-submitter sent real `RequestPatchSubmission` remotes. 27 patches went ACTIVE (ZERO_G 7, DECAY 7, DRONE_SWARM 7, SUPPLY_DROP 6); 3 resets checked, 0 problems |
| P1 | Source parity | PASS | 21/21 hash-identical |
| P2 | Server Output | PASS | Only `[WORLD_EXE]` info lines and the intended "drone cap reached" rejection; no errors |
| S13 | Second item claimed by a second player; empty crate | NOT TESTED | Needs two players (Clients and Servers) |
| N1 | Multi-client run (replication, readability, two players) | NOT TESTED | Needs the owner to start Clients and Servers |
| N2 | Player leaving mid-patch (drone target, claimer) | NOT TESTED | Leaving ends a solo session. In code: targets are re-checked every step (`player.Parent`), and per-player tables are weak-keyed |

Totals: **36 PASS, 0 FAIL, 3 NOT TESTED.** After stopping play, the Edit place was verified clean: no test scripts or attributes, 64 DecayTiles intact, gravity 196.2.

### Outstanding risks
- **Multi-client is untested:**
  - Drone movement is a server-side anchored CFrame at 10 Hz, which may look choppy on clients (no client interpolation yet).
  - Warning readability at distance needs a real client check.
- **Drones can briefly clip through geometry.** A chase stops only at the next 1 s retarget after line of sight breaks, and returning to the nearest waypoint is a straight line. Damage always needs line of sight.
- **DECAY falls end in out-of-bounds elimination.** That may feel harsh; tune the group size and timings in playtests.
- **ZERO_G changes airtime, not jump height** (decision 5). Confirm this is the intended feel.
- **SUPPLY_DROP's reward only matters during DRONE_SWARM** until Phase 5 adds data fragments and score.

## Phase 3 final review (2026-11-10)
ChatGPT approved Phase 3 at `d22939f` with no blocking code issues. It confirmed:
- Yielding hooks are cancelled without blocking the match loop.
- Long-running work uses tracked tasks.
- A failed activation rolls back fully.
- Modifier math is safe against non-finite values.
- The patch capacity limit, Architect authorization, lifecycle and match cleanup are intact.

Pre-merge steps, completed:
1. Studio ↔ GitHub parity: 18/18 scripts hash-identical to `d22939f`.
2. Edit place checked clean.
3. The owner saved `Place1.rbxl`. The save was verified from the file contents, as described under "Current state".
4. Backup `WorldEXE_post-phase3_2026-11-10.rbxl` was created. Its SHA-256 matches the saved place: `2663A50DABDDFAA936A7B84866ECA716047C8D77C2B734A96D95A2A6F11FBB98`.
5. This document and the PR description were updated.

Still outstanding: a multi-client (Clients and Servers) run of Phase 3 was not tested.

## Phase 3 review round 1 correction (2026-11-10)

ChatGPT reviewed PR #3 at `04b734a` and asked for one lifecycle-safety correction, plus hardening of the modifier math.

### Findings and resolutions
1. **Behavior hooks ran inside the shared match tick.** A yielding `Activate` could stall the whole match.
   - Fixed with an **enforced non-yielding contract**. `PatchService` runs `Activate` and `Deactivate` through `runHook`: each hook gets its own coroutine, resumed once.
   - If the hook has not finished when that resume returns (it yielded on `task.wait`, `WaitForChild`, a web call and so on), the coroutine is cancelled with `task.cancel`, so its remaining code can never run.
   - A yielded `Activate` is treated as a failed activation: full rollback, reason `activation_yielded`. A yielded `Deactivate` is logged, and ending continues normally.
   - Errors are handled as before (`activation_failed`).
   - This is simpler than async isolation: the tick never waits on behavior code, so no generation or cancellation bookkeeping is needed for hooks.
2. **Tracked tasks for long-running work.** The patch context gains two functions:
   - `ctx.Spawn(fn, ...)`, built on `task.defer`, so it never runs inside the tick.
   - `ctx.Delay(seconds, fn, ...)`, built on `task.delay`.

   Both threads go into the patch's cleanup bag, so they are cancelled when the patch ends for any reason: expiry, cancel, match end, reset, recovery or shutdown.

   Once a patch is cleaned up, its context does nothing:
   - `ctx.Spawn`, `ctx.Delay` and `ctx.AddModifier` return nil without acting.
   - `ctx.Add` releases the item immediately.
   - `ctx.IsLive()` is false.
3. **Non-finite modifier results.** Finite tokens can still combine into a non-finite value, for example two ×1e200 multipliers. `WorldModifierService.resolve` now:
   - clamps +infinity to Max and −infinity to Min;
   - falls back to the baseline on NaN (for example an overflowed product × 0, or +inf and −inf offsets), with a warning.

   Non-finite token inputs were already rejected. The world never receives a non-finite value.
4. **Wording correction.** The Phase 3 report said the modifier result "does not depend on the order tokens were added". More precisely: multipliers and offsets are applied in token-creation order, so the result is deterministic for a given set of tokens and independent of removal order. Floating-point rounding, or overflow at extreme values, could in principle differ if the same tokens were created in another order.

### Changed files
- `src/ServerScriptService/WORLD_EXE/Services/PatchService.luau`: hook contract in the header, `runHook`, `ctx.Spawn` / `ctx.Delay`, post-cleanup guards, `activation_yielded`.
- `src/ServerScriptService/WORLD_EXE/Services/WorldModifierService.luau`: non-finite guard.
- `src/ServerScriptService/WORLD_EXE/Patches/TestBehaviors.luau`: three Studio-only test behaviors.
  - `TEST_YIELD_ACTIVATE`: creates a marker and ×0.5 gravity, yields 2 s, then would write `workspace.Gravity = 1` and a probe.
  - `TEST_YIELD_DEACTIVATE`: yields 2 s in Deactivate, then would do the same writes.
  - `TEST_TRACKED_TASKS`: a `ctx.Spawn` loop that never checks `IsLive`, a 4 s slow `ctx.Spawn`, and a 3 s `ctx.Delay`, all writing to the world.
  - Late writes are recorded as `TestProbe*` attributes on `Workspace.WORLD_EXE`.
- `docs/PROJECT_STATUS.md`.
- Unchanged: the 3-patch limit, the lifecycle, Architect security checks, MatchService, the HUD, and all geometry. The 4 catalog patches are still placeholders.
- Studio parity: all 18 scripts hash-identical. The 3 changed scripts:

  | Script | Bytes | Hash |
  |---|---|---|
  | PatchService | 14017 | 206455472 |
  | WorldModifierService | 5600 | 2125428737 |
  | TestBehaviors | 4429 | 2005119348 |

### Tests (all **solo** Studio, 2026-11-10)
**Live (Y).** A Script injected at runtime into the play server requires the **game's own** PatchService (verified: its requests appear in the live snapshot and Output), so these run through the real `MatchService.tick` loop. Time scale 0.05, tick 0.25 s.

**Engine (R).** Cloned modules in the play server. `PatchService.Update` is driven every frame.

| # | Test | Result | Evidence |
|---|---|---|---|
| Y1 | Match deadlines keep progressing with a yielding Activate in the live tick | PASS | `TEST_YIELD_ACTIVATE`, `TEST_YIELD_DEACTIVATE` and `TEST_TRACKED_TASKS` were requested 1.2 s before the ACTIVE deadline, and the yielding Activate ran ~0.7 s before it. Transition lateness vs. `StateEndsAt`: ACTIVE→FINAL_PHASE 0.14 s, FINAL_PHASE→RESULTS 0.22 s, RESULTS→RESET 0.20 s, RESET→LOBBY 0.13 s; all within one 0.25 s tick. A stalled tick would have been ≈1.3 s late |
| Y2 | Yielded Activate rolled back live | PASS | `P1-1 … activation failed: hook yielded …` → `ended: activation_yielded (released 2)` |
| Y3 | Yielded Deactivate live | PASS | `P1-2 Deactivate failed: hook yielded` → `ended: expired (released 1)` with no delay |
| Y4 | Cancelled work cannot mutate the next match | PASS | `P1-4 TEST_TRACKED_TASKS` was activated 0.7 s before RESULTS and cancelled `match_end` (released 4). Its 3 s Delay and 4 s Spawn were due in match 2. Checked 6 s later, with match 2 ACTIVE: probe ticks 21 → 21 (stopped), `TestProbeLate` nil, gravity 196.2 (never 1) |
| Y5 | No leftovers after the live run | PASS | Tracked resources 0, tokens 0, markers 0, running patches 0 |
| R1 | Yielding Activate does not stall `Update` | PASS | Slowest `Update()` call 0.0004 s; reason `activation_yielded`, released 2 |
| R1b | Rollback | PASS | Marker gone, gravity at baseline, 0 tokens, slot free |
| R2 | Yielding Deactivate does not delay ending | PASS | `Cancel` took 0.0003 s; released 1; marker gone |
| R3 | Tracked tasks run while active | PASS | 9 probe ticks |
| R3b | Tracked tasks stopped by reset / recovery / shutdown | PASS | 3 patches, one per reason, each released 4; 0 tracked; 0 markers |
| R4 | Context inert after cleanup | PASS | `Add(part)` destroyed the part; `Spawn`, `Delay` and `AddModifier` returned nil; gravity unchanged; `IsLive` false |
| R5 | Non-finite modifier combinations (6 cases) | PASS | ×1e200 ×1e200 → 1000 (Max); + ×0 → baseline; set 0 × overflow → baseline; +1e308 +1e308 → 1000; −1e308 −1e308 → 0 (Min); overflowed product + −inf offset → baseline. Every case removed cleanly back to baseline |
| R5b | Non-finite inputs rejected | PASS | `add math.huge` and `multiply NaN` errored; 0 tokens |
| R6 | Phase 3 regressions | PASS | Lifecycle expired (released 4); 3 slots fill and the 4th is `capacity_full`; composition = 25; failed activation rolled back (released 2); `NUKE` → `unknown_patch` |
| R7 | No late work after every deadline | PASS | 4.6 s after the last cancel: `TestProbeLate` nil, ticks unchanged (9), gravity at baseline; tracked 0, tokens 0, markers 0, `IsAtBaseline` true |
| L9 | Live Phase 2/3 regression with real remote submissions | PASS | Match 4 at scale 0.1: all states in order. 9 accepted submissions (ZERO_G, DECAY, SUPPLY_DROP, DRONE_SWARM) → P4-5…P4-13, each WARNING → ACTIVE → expired. Reset: world at baseline, gravity 196.2 |
| P1 | Source parity | PASS | 18/18 hash-identical |
| P2 | Server Output | PASS | Only `[WORLD_EXE]` info lines and intended warnings (yielded hooks, the injected activation failure, 3 non-finite fallbacks from R5). No unexpected errors |
| N1 | Multi-client (Clients and Servers) | NOT TESTED | Needs the owner to start it; unchanged from the Phase 3 report |

The Edit place was verified clean after the run: no test attributes, no injected scripts or clones, gravity 196.2.

### Remaining risks
- The contract catches **yielding**, not **non-yielding long work**. A hook that loops without yielding still blocks the server until Roblox's script timeout. Phase 4 reviews must keep hooks short.
- Behaviors must still use `ctx.Add`, `ctx.AddModifier`, `ctx.Spawn` and `ctx.Delay`. A raw `task.spawn` or a direct property write bypasses cleanup. The engine cannot prevent this; code review must.
- Finished `ctx.Spawn` threads stay in the bag (as dead threads) until the patch ends. That is fine for a few tasks per patch; a behavior should not spawn unbounded numbers of tasks.
- If a tracked task itself ends its own patch, the cleanup cancels the running thread. That produces a logged cleanup error instead of a crash.

## Phase 3 report — Patch engine foundation (2026-11-10)

Approved scope: lifecycle engine, shared-world modifiers, idempotent cleanup, and Architect integration. **No real patch effects**: ZERO_G, DECAY, DRONE_SWARM and SUPPLY_DROP run a no-op placeholder behavior until Phase 4.

### Pre-checks (all passed, no blockers)
- PR #2 merged (`09d9c2a`); `main` at `40a1d39`.
- The 13 Studio scripts were hash-identical to `main` before any change.
- Backup `WorldEXE_pre-phase3_2026-11-10.rbxl` created; SHA-256 identical to the saved place.
- Branch `phase-03-patch-engine` created from `origin/main`.

### Completed features
- **CleanupService** (new): a cleanup bag that holds instances, connections, threads, functions and objects with `:Destroy`.
  - `Cleanup()` releases items in reverse order with a pcall per item and returns `(released, errors)`.
  - It is idempotent. An item added after cleanup is released immediately, so a late callback cannot leak.
- **WorldModifierService** (new): the only writer of shared world properties. Phase 3 covers `Gravity` only.
  - Patches add **tokens** (`set` / `multiply` / `add`, with priority and owner) instead of writing the property.
  - Deterministic resolution: the highest-priority `set` wins (ties go to the earliest token); with no `set`, the captured baseline is used. Then the product of all `multiply` tokens and the sum of all `add` tokens are applied, and the result is clamped to `Config.WorldModifiers`.
  - The result does not depend on the order tokens were added or removed. When the last token goes, the exact original value is restored.
  - `RemoveModifier` and `ClearAll` are idempotent.
- **PatchService** (new): server-authoritative patch lifecycle **WARNING → ACTIVE → ENDING → ENDED**.
  - Each patch gets a unique runtime ID (`P{matchId}-{n}`). The service tracks PatchId, creator, MatchId, warning/active durations (from `PatchCatalog`, scaled by the Studio time scale), expiry, and a per-patch cleanup bag.
  - `Request` validation: catalog ID only (`unknown_patch`), match must be live (`match_not_live`), the same source key cannot be reused (`duplicate`), and at most `Config.Patches.MaxActiveMajor = 3` concurrent patches (`capacity_full`).
  - At warning end the patch is revalidated: the match must still be live and the creator still present (`creator_left`). Then `Activate` runs inside a pcall. On error the patch rolls back fully (`activation_failed`): instances, connections, threads and modifier tokens are released and the slot is freed.
  - `finish` is idempotent and frees the slot in every path: expired, cancelled, match_end, reset, recovery, shutdown or activation_failed. `CancelAll` returns the count of patches cancelled.
  - A bounded history of the last 50 ended patches is kept for diagnostics.
  - Patch behaviors receive a context (`Add`, `AddModifier`, `IsLive`, `Folder`). Modifier tokens are owned by the patch's bag, so they are always removed with the patch.
- **Placeholder behavior** (`Patches/Placeholder`): an empty `Activate` for the 4 approved patches.
- **Test behaviors** (`Patches/TestBehaviors`) are registered **only when `RunService:IsStudio()`** and are requested with `{Test=true}`. They are never in `PatchCatalog`, so players cannot request them; the player path returns `unknown_patch`.
  - `TEST_LIFECYCLE`: marker part, value, connection and thread.
  - `TEST_GRAVITY_MULTIPLY`, `TEST_GRAVITY_SET_HIGH`, `TEST_GRAVITY_SET_LOW`: gravity modifier tokens.
  - `TEST_FAIL_ACTIVATE`: creates a part and a modifier, then errors.
- **ArchitectService integration**:
  - An accepted submission now calls `PatchService.Request` with source key `turn:{match}:{turn}`. On success the announcement carries `RuntimeId` and the scaled warning and active durations.
  - On rejection the turn resolves with the PatchService reason, which is sent to the client.
  - A new Architect turn is **deferred** while all 3 slots are full, retrying on the existing no-eligible retry interval.
- **MatchService integration**:
  - `PatchService.Update()` runs at the start of every tick in the existing single deadline loop.
  - RESULTS cancels all patches (`match_end`) and clears all modifiers. RESET does both again as a backstop, checks `IsAtBaseline` (warns if not), clears source keys, and then resets the arena.
  - Recovery and shutdown cancel all patches and clear all modifiers.
  - The snapshot adds `Patches` (runtime views), `PatchCapacity`, and the reset diagnostics `LastResetPatchesCancelled`, `LastResetModifiersCleared`, `LastResetWorldAtBaseline`.
- **Bootstrap**: `WorldModifierService.Init()` captures baselines before `MatchService.Init`, which initializes PatchService before ArchitectService.
- **HUD** (backwards compatible):
  - New patches line, e.g. `Patches (1/3): DRONE SWARM incoming 0:01` during WARNING and `DRONE SWARM 0:07` during ACTIVE.
  - The Phase 2 banner is kept, with the added line "(Patch effects arrive in Phase 4.)".
  - The Architect panel has feedback for `capacity_full`, `match_not_live` and `duplicate`.
- **Config / PatchCatalog**:
  - Version `0.3.0-phase3`; new `PatchStates`, `Patches` and `WorldModifiers` sections.
  - Each catalog entry gains `WarningSeconds` (4.5) and `DurationSeconds` (ZERO_G 35, DECAY 40, DRONE_SWARM 35, SUPPLY_DROP 30).

### Changed / added files
- Added:
  - `src/ServerScriptService/WORLD_EXE/Services/CleanupService.luau`
  - `src/ServerScriptService/WORLD_EXE/Services/WorldModifierService.luau`
  - `src/ServerScriptService/WORLD_EXE/Services/PatchService.luau`
  - `src/ServerScriptService/WORLD_EXE/Patches/Placeholder.luau`
  - `src/ServerScriptService/WORLD_EXE/Patches/TestBehaviors.luau`
- Changed:
  - `Shared/Config.luau`, `Shared/PatchCatalog.luau`
  - `Bootstrap.server.luau`, `Services/ArchitectService.luau`, `Services/MatchService.luau`
  - `Controllers/HUDController.luau`, `Controllers/ArchitectController.luau`
  - `src/README.md`, `docs/PROJECT_STATUS.md`
- Unchanged: ArenaService, NetService, PlayerStateService, all client modules other than the two controllers, and all arena and lobby geometry.
- Studio parity: all 18 scripts are hash-identical to `src/` (byte length + polynomial hash).

### Design decisions for review
1. **Capacity full → reject, and defer turns.** A 4th request is rejected with `capacity_full`. Nothing is queued and nothing running is displaced. ArchitectService also does not open a turn while 3/3 slots are used, so in normal play the rejection is only a race-condition backstop.
2. **Revalidate at warning end.** A patch whose match has ended (`match_not_live`) or whose creator has left (`creator_left`) never activates. Creator UserId 0 (test/system) skips the presence check.
3. **FINAL_PHASE keeps running patches.** RESULTS cancels everything (`match_end`); RESET repeats the cancel as an idempotent backstop.
4. **Duplicate guard by source key.** One Architect turn can create at most one patch. Keys clear at RESET.
5. **Test patches are Studio-only** and live outside the catalog.
6. **Gravity is the only modifier property** in Phase 3. More properties are added only when a Phase 4 patch needs one.

### Tests (all **solo** Studio, 2026-11-10)
Method:
- Engine tests (E) use MCP-context module instances inside a running play server, with real `workspace.Gravity` and real workspace folders, at time scale 0.2 unless noted.
- Integration tests (A) use a clone of ArchitectService driving the MCP-context PatchService.
- Live tests (L) use the real running game with real RemoteEvent submissions from a client-side auto-submitter, observed through the snapshot, the HUD and the Output.

| # | Test | Result | Evidence |
|---|---|---|---|
| E1 | Activation / expiration | PASS | `TEST_LIFECYCLE`: WARNING → ACTIVE (4 tracked resources, marker present) → ENDED `expired`, released 4, 0 errors, marker removed |
| E1b | Warning and active durations | PASS | Warning ended at the scaled 0.2 s; active lasted 0.43 s against an expected 0.40 s (tick granularity) |
| E2 | 3 simultaneous patches | PASS | 3 patches in WARNING/ACTIVE at once; `HasCapacity()` false |
| E2b | 4th request | PASS | Rejected `capacity_full`; the 3 running patches were unaffected; a request succeeded after one ended |
| E3 | Multiple modifiers on one property | PASS | Run at scale 1. set 50 (p10) + set 100 (p5) + ×0.5 → **25.00**; remove HIGH → 50; remove MULTIPLY → 100; remove all → baseline 196.2, `IsAtBaseline`, 0 tokens; reverse removal order gave identical values |
| E3b | Modifier removed on natural expiry | PASS | ×0.5 patch: 98.10 while active, exact baseline after `expired` |
| E4 | Failed activation, full rollback | PASS | `TEST_FAIL_ACTIVATE` → `activation_failed`, released 2 (marker + modifier), slot freed, gravity at baseline, marker absent |
| E5 | Double cleanup / double cancel | PASS | `CancelAll` → 3, then 0; `Cancel` on an ended patch → false; bag cleanup 2, then 0; late add released at once; `RemoveModifier`/`ClearAll` twice → no error |
| E6 | Cancellation at match end | PASS | A WARNING patch whose match ended → `match_not_live`, never activated; `CancelAll("match_end")` ended the ACTIVE patch (released 4, markers 0) |
| E7 | Invalid requests | PASS | `NUKE` → `unknown_patch`; test ID through the player path → `unknown_patch`; old MatchId → `match_not_live`; reused source key → `duplicate` |
| E8 | Creator leaves during warning | PASS | Absent creator → `creator_left`, never activated |
| E9 | Repeated cycles without leaks | PASS | 20 request/expire cycles: 0 running, 0 tracked resources, 0 markers, 0 tokens, gravity at baseline |
| A1 | Architect turn deferred while full | PASS | With 3/3 slots full no turn opened; it opened after a slot freed |
| A2 | Submission while full | PASS | Turn resolved `capacity_full`; no patch created |
| A3 | Accepted submission creates a patch | PASS | One WARNING patch; RuntimeId and CreatorUserId match the turn result |
| L1 | Live lifecycle via real submission | PASS | Match 1: P1-1 ZERO_G WARNING (4.5 s) → ACTIVE → `expired` |
| L2 | Live cancellation at match end | PASS | Match 2: `P2-2 ZERO_G ended: match_end` at RESULTS; snapshot `Patches` empty from RESULTS on |
| L3 | No leftovers after RESET | PASS | After every observed reset: patches 0, modifiers cleared, `LastResetWorldAtBaseline` true, arena baseline matched, runtime objects 0 |
| L4 | Recovery cancels patches | PASS | `StudioFailOnEnter=FINAL_PHASE` with P3-3 ACTIVE → `P3-3 ZERO_G ended: recovery` → LOBBY, 0 patches, gravity 196.2 |
| L5 | Consecutive matches without leaks | PASS | Matches 3 → 7: 3 resets checked, 0 problems; gravity 196.2 at every reset |
| L6 | Open turn at FINAL_PHASE | PASS | The open turn resolved `cancelled`; no patch created |
| L7 | HUD patches line and banner | PASS | WARNING `Patches (1/3): DRONE SWARM incoming 0:01`; ACTIVE `DRONE SWARM 0:07`; Phase 2 banner intact |
| L8 | Phase 2 regression (lifecycle, Architect turns, announcements) | PASS | Every state reached in order across 7 live matches; turns offered, accepted and announced as before |
| P1 | Source parity | PASS | 18/18 scripts hash-identical |
| P2 | Server Output | PASS | Only `[WORLD_EXE]` info lines and the intended injected messages ("injected activation failure", "injected recovery failure"); no unexpected errors or warnings |
| N1 | Multi-client (Clients and Servers) run | NOT TESTED | Needs the owner to start Clients and Servers. The engine is server-side and player-independent apart from creator presence (E8) |
| N2 | 3 concurrent patches reached through live Architect play | NOT TESTED | Not reachable at the designed cadence: the turn interval is at least the patch duration, so at most 1 patch ran at once live. Covered by E2, A1 and A2 |
| N3 | Live gravity change | NOT TESTED | The live catalog patches are placeholders (by scope). Gravity composition was tested in E3/E3b on real `workspace.Gravity` |

Notes:
- Two engine runs were repeated because of test-timing errors, not engine errors. The first E3 at scale 0.01 let the patches expire before measuring, and the first E6 let the ACTIVE patch expire before its check. Both reruns passed.
- During one live run the time scale was lowered after FINAL_PHASE had started. That run's post-reset reading was discarded and the test was redone (L2).

### Outstanding risks / for Phase 4
- Real patch behaviors must create everything through `ctx.Add` / `ctx.AddModifier` to get automatic cleanup. A behavior that writes `workspace.Gravity` directly or parents objects outside the bag would bypass the guarantees. Code review must enforce this.
- `Deactivate` hooks run before bag cleanup. A slow or yielding `Deactivate` would delay the tick loop, so Phase 4 behaviors should keep it non-yielding.
- Capacity is counted across all patches as "major"; there is no minor/major split yet (only the 4 major patches exist).
- Multi-client verification of Phase 3 is still outstanding (N1).

## Phase 2 review round 2 correction (2026-11-10)

Re-review at `852f234` confirmed the round 1 findings fixed; one remaining issue.

### Change
`ArchitectService` now requires the current Architect to be a **living Participant**:
- On submission (after the ownership check): if the Architect is dead or no longer a Participant, the turn is skipped (`architect_ineligible`, nothing activates) and the request is rejected with reason `architect_ineligible`.
- Every tick while a turn is open: if the Architect has left → `architect_left` (unchanged); if dead or no longer a Participant → `architect_ineligible`.
- `ArchitectService.HandleSubmission` exports the RemoteEvent handler so tests can drive the exact accept path on a module clone. Client feedback text added for `architect_ineligible`.
- Turn identity, serialized spawns, recovery and snapshot protections are unchanged.

Changed files: `src/ServerScriptService/WORLD_EXE/Services/ArchitectService.luau`, `src/StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/ArchitectController.luau`, this file. Studio copies hash-verified identical.

### Regression tests (solo)
| Test | Result |
|---|---|
| Live: Architect killed with 11.7 s left in turn `1:1` → turn cleared after 0.23 s, next turn scheduled; log `turn 1: amfam1 -> architect_ineligible` | PASS |
| Clone, exact accept path: eligible Architect submits (control) | PASS — `accepted`, patch recorded |
| Clone: Architect stops being a Participant, then submits | PASS — `architect_ineligible`, no patch, turn closed |
| Clone: Architect dies, then submits before the next tick | PASS — `architect_ineligible`, no patch, turn closed |
| Live regression via real remote: bad id → `bad_patch_id`; `zero-g` → accepted; second → `no_open_turn`; all tagged `1:3`; panel key `1:3` | PASS |
| Output | Only `[WORLD_EXE]` info lines (match ids 998/999 are the test clones); no warnings or errors |
| Edit DataModel after play | Clean |

### Multi-client Studio test (Test → Clients and Servers, 1 server + 2 clients)
ChatGPT accepted `9c6de7a` (no remaining code blockers) and confirmed this plan. Procedure:
- `StudioMinPlayers = 2` (set temporarily on `ServerScriptService.WORLD_EXE` in the Edit place; Studio-only).
- Server / Client 1 / Client 2 Output captured separately.
- Disconnect tests: record `MatchId`, state, participant count, Architect and relevant Output **before and after** each disconnect.
- Client UI-click and client-visual tests stay NOT TESTED unless Studio MCP can reach the client windows or the owner performs them and provides evidence.
- After testing: remove `StudioMinPlayers`, re-verify every script hash against GitHub, then the owner saves and a fresh post-Phase-2 `.rbxl` backup is made before merging.

**Run on 2026-11-10 in two sessions** (each: Studio Local Server, 1 server + 2 clients, `Player1` / `Player2`). Studio MCP reached the server and both clients as separate instances, including mouse input on client UI. Code under test: PR head `8711fa8` (no gameplay changes since `9c6de7a`).
- **Session 1:** `StudioMinPlayers = 2`; the test server's `StudioTimeScale` set to 0.2 after start (turn interval 9 s; the 12 s submission window is never scaled). Scenarios 3–5, 7–18, 20.
- **Session 2** (procedure approved by ChatGPT): Edit-place `StudioMinPlayers = 3`, `StudioTimeScale = 1`. Scenarios 1, 2, 6, 20.

| # | Scenario | Expected | Result | Actual / evidence |
|---|---|---|---|---|
| 1 | One connected player cannot start a match | Stays in LOBBY; no COUNTDOWN | **PASS** | S2: 2 players connected, minimum 3 → 10 s observed in LOBBY, snapshot v1 unchanged, both HUDs "players ready 2 / 3 needed". After Player2 disconnected (#6), Player1 alone with minimum 2 → LOBBY for 10 s (no other states), HUD "players ready 1 / 2 needed". |
| 2 | Requirement met → match begins automatically | COUNTDOWN starts without intervention | **PASS — threshold-change test** | S2: minimum lowered 3 → 2 on the running server; COUNTDOWN ("enough players", 10 s) 0.03 s later (snapshot v2). Not a literal later join: Studio launches both clients together. In S1 the match also started automatically with 2 players ("LOBBY -> COUNTDOWN (enough players)"). |
| 3 | Both clients join: roles and lobby spawn | Both `Lobby`, both on lobby pads | **PASS (indirect)** | S2 start: both `Lobby` (HUD "In lobby"). S1 after each RESET: both `Lobby` on lobby pads (`LobbySpawn_4`/`LobbySpawn_1`, then `LobbySpawn_4`/`LobbySpawn_3`). The initial join moment of S1 was not observed (the match had already started when inspected). |
| 4 | Concurrent spawns at INITIALIZING | 2 participants on distinct arena pads, spawn protection on | **PASS (pads) / NOT TESTED (ForceField)** | Match 2: `Spawn_CORE_1` + `Spawn_YARD_1`; match 3: `Spawn_CORE_4` + `Spawn_CORE_2`; both `arena#…:loaded`. ForceField: the sample landed after the 1 s INITIALIZING window (time scale 0.2), so multiplayer spawn protection was **not observed** (it passed in solo tests). |
| 5 | Snapshot replication | Both clients see the same snapshots as the server | **PASS** | Server recorded per-version JSON hashes; Player1 observed v25–v27, Player2 v27–v28, every hash identical to the server's. S2: Player1's client v3 matched the server's v3. |
| 6 | Countdown cancellation when the count drops below 2 | COUNTDOWN → LOBBY ("not enough players") | **PASS** | S2 (server timestamps from t0): t+0.03 s COUNTDOWN v2 (2 players). t+2.05 s BEFORE: COUNTDOWN, 8.0 s left, 2 players → Player2 kicked. t+3.10 s v3 LOBBY "countdown cancelled: not enough players", 1 player. Server log: `Match 0: COUNTDOWN -> LOBBY (countdown cancelled: not enough players)`. Player1 stayed in LOBBY (see #1). |
| 7 | Non-Architect submission | `not_architect`, turn unaffected | **PASS** | Player1 during Player2's turn `1:8` → `not_architect` (tag `1:8`); turn still open under Player2; Player1's panel hidden. |
| 8 | Spectator unauthorized submission | Rejected, no effect | **PASS (role set by server)** | Player2's role set to Spectator by the server (a real mid-match joiner isn't possible with two fixed clients), and the watchdog moved them to the lobby within 0.5 s (z 46 → 160 on server and client). Submission during Player1's turn `3:4` → `not_architect`, turn unaffected, no panel. |
| 9 | Duplicate rapid submission by the Architect | Exactly one `accepted` | **PASS** | Player2 (Architect, turn `1:6`) fired 3 identical requests in one frame → `accepted`, `no_open_turn`, `no_open_turn` (all tagged `1:6`); log `turn 6: Player2 -> accepted DECAY`. Observation: the scripted duplicates' `no_open_turn` replies overwrite the "Patch submitted." text; the real UI blocks duplicates with its pending flag. |
| 10 | Architect panel visibility | Shown only on the Architect's client | **PASS** | Enabled on the Architect's client (`TurnKey` = current turn) and disabled on the other client in turns `1:6`, `1:8`, `3:4`, `2:2`, `2:3`. |
| 11 | Architect panel real clicks | Accepted via UI | **PASS** | Studio MCP mouse input on Player1's client: click `Card_ZERO_G`, then `Submit` → server log `Match 1 turn 17: Player1 -> accepted ZERO_G`; client button "SUBMIT ZERO-G", feedback "Patch submitted.". |
| 12 | Rotation between two players | Alternates; no consecutive repeat | **PASS** | Match 1 turns 1–20 alternated Player1/Player2 (server log). While Player2 was a Spectator, Player1 took turns 3:2–3:4 in a row as the sole eligible player (expected). |
| 13 | Architect becomes ineligible during an open turn | Turn skipped `architect_ineligible` | **PASS** | Death: Player1 killed in turn `1:9` → turn cleared after 0.20 s, log `turn 9: Player1 -> architect_ineligible`. Role change: Player2 set to Spectator during its own turn `3:1` → log `turn 1: Player2 -> architect_ineligible`. |
| 14 | Non-Architect death | Respawns on an arena pad, still Participant | **PASS** | Player2 killed → respawned on `Spawn_YARD_4`, role Participant, alive. |
| 15 | Stale snapshot / delayed submission response | Older versions ignored; replies for other turns ignored | **PASS** | The server sent Player2 a reply tagged `1:13` during turn `1:14` → feedback stayed empty, `IgnoredResponses` incremented. Snapshot versions only increased on both clients (#5). |
| 16 | Two complete matches | No stale turn UI, feedback, role or spawn state | **PASS** | Matches 1 and 2 each ran ACTIVE → FINAL_PHASE → RESULTS → RESET → LOBBY. Match 1 result: completed/time, 3 accepted / 17 skipped, both participants; reset baseline matched. In the next match, both panels opened fresh (keys `2:2` / `2:3`, empty feedback and keyword, no selection, 4 cards, role Participant), although Player1 had ended match 1 with "Patch submitted." and a selected card. New arena pads each match. |
| 17 | Disconnect during the Architect's open turn | `architect_left`, roster updated | **PASS** | BEFORE: v84 match 4 ACTIVE, participants 2, Architect Player2, turn `4:2`, players 2. Player2 kicked. AFTER (1.57 s): v86 ACTIVE, participants 1, no Architect, next turn scheduled, players 1. Log `turn 2: Player2 -> architect_left`; turn 3 went to Player1. |
| 18 | All participants leave | Abort to RESULTS (`no participants`) | **PASS** | BEFORE: v88 match 4 ACTIVE, participants 1, players 1. Player1 kicked. RESULTS at 7.6 s: reason "no participants", outcome `aborted`, participants []. Then RESET → LOBBY; 3 s later still LOBBY with 0 players. Log `Match 4: ACTIVE -> RESULTS (no participants)`. |
| 19 | Player joins mid-match | Spectator, kept in lobby, joins next match | **NOT TESTED** | Studio cannot add a player to a running Clients and Servers session. The spectator role path was exercised by setting the role (#8). |
| 20 | Output — Server / Client 1 / Client 2 | No unexpected warnings or errors | **PASS** | Server (both sessions): only `[WORLD_EXE]` info lines (bootstrap, transitions, turns, outcomes). Clients: only `[WORLD_EXE] Client ready v0.2.1-phase2 (PlayerN)`, captured before each disconnect. No warnings or errors anywhere. |
| 21 | Cleanup | Test attributes removed; scripts match GitHub; post-Phase-2 backup | **PASS** | `StudioMinPlayers` removed from the Edit place (no attributes remain on `ServerScriptService.WORLD_EXE`). All 13 Studio scripts byte-identical to GitHub `phase-02-match` (the `src/` tree is unchanged from `8711fa8` through `cfd6cfd`). Test session stopped; the owner saved `Place1.rbxl` at 2026-11-10 03:21:24, after the cleanup (03:17) and the last code change (`9c6de7a`, 02:07). Backup `OneDrive\Documents\RobloxBackups\WorldEXE_post-phase2_2026-11-10.rbxl`: 121,000 bytes, SHA-256 `0F402A70A592516BC281390A491E301F9B70D1EF3FD4775E1194A76442B7B204`, identical to the saved place. |

Investigated during the run (not defects): a client read once showed the Spectator inside the arena; a 250 ms server trace showed the watchdog moving them within 0.5 s (the read had landed before the tick). Early cross-instance tests missed their turn windows because Studio MCP calls between instances take several seconds; they were repeated with the waits inside the client scripts.

**Summary:** 19 PASS (#2 as a threshold-change test, #3 indirect, #8 role set by server), 1 PASS/NOT TESTED split (#4: ForceField unobserved), 1 NOT TESTED (#19). No defects found; no gameplay code changed.

## Phase 2 review round 1 corrections (2026-11-10)

### Findings and resolutions
| # | Finding | Resolution |
|---|---|---|
| 1 | Architect UI turn identity | `ArchitectController` keys the rendered turn by `MatchId:TurnNumber` (from the snapshot's `Turn.TurnMatchId`/`TurnNumber`). A new match clears selection, pending state, keyword text, feedback and cards; a new turn key rebuilds the panel. The current key is exposed as the panel's `TurnKey` attribute for tests. |
| 2 | Deferred `LoadCharacter` races | `PlayerStateService` keeps a per-player **spawn generation**, bumped by every spawn request, role change (`SetRole`), phase change (`SetArenaPhase`) and departure. Requests are **serialized per player**: one `LoadCharacter` runs at a time and only the newest request waits. Immediately before loading, the request is re-checked (still connected, generation current, intent arena/lobby still matches role + phase) and dropped otherwise. Diagnostic player attribute `WORLD_EXE_LastSpawn` = `<intent>#<generation>:<superseded|intent_mismatch|loading|loaded>`. |
| 3 | Transition hook failures | `MatchService.transition` runs the entry hook in `pcall`. On failure, `recover()` runs isolated cleanup steps (stop Architect, protection off, arena phase off, all roles → Lobby, return everyone to the lobby, clear runtime folders), sets LOBBY with no participants, increments `Recoveries`, logs and warns. Studio-only fault injection: `StudioFailOnEnter`. |
| 4 | Tagged submission responses | Every `SubmissionResult` carries `MatchId` and `TurnNumber` (the turn the request was evaluated against). The client ignores responses whose `MatchId:TurnNumber` differs from the turn it is showing (counted in the panel's `IgnoredResponses` attribute). |
| 5 | Partially updated replicated state | Replaced the per-field attributes with **one `Snapshot` attribute** (JSON) on `ReplicatedStorage.WORLD_EXE.MatchState` containing match state, Architect turn, last result and reset info, with a monotonically increasing `Version`. Publishing is suppressed mid-transition and done once at the end; Architect turn changes trigger a full republish. The new client module `MatchStateClient` is the only reader and ignores older/duplicate/malformed versions. `MatchStateChanged` fires the same snapshot. |

### Bug found during testing (fixed)
The first generation-only version still left a participant in the lobby after a recovery: the engine **silently ignores a `LoadCharacter` issued while that player's previous load is still finishing**. Observed: recovery lobby load at 5.75 s, next match's arena load at 6.55 s → `arena#22:loading` with no `CharacterAdded`; the participant stayed on a lobby pad during ACTIVE. Fixed by serializing loads per player (above); re-test shows the arena request waiting for the lobby load and then landing on an arena pad.

### Commits
- Corrections commit: `0f4bf4e`. The PR head after this round is the docs-only commit directly after it that records this line (exact hash in the PR conversation).

### Approved design decisions (recorded)
Respawn in ACTIVE and FINAL_PHASE; lobby auto-ready; no new Architect turns in FINAL_PHASE; keep `SubmissionResult`; Studio minimum 1 / live 2; ACTIVE 420 s + FINAL_PHASE 90 s. Match duration standardized in `README.md`, `CLAUDE_START_HERE.md` and `docs/01_GAME_DESIGN.md` to **8–12 minutes, initial gameplay duration 8:30**.

### Changed files
- `src/ServerScriptService/WORLD_EXE/Services/MatchService.luau` — versioned snapshot, publish suppression, recovery path, fault injection.
- `src/ServerScriptService/WORLD_EXE/Services/PlayerStateService.luau` — spawn generations, serialized loads, revalidation, diagnostics.
- `src/ServerScriptService/WORLD_EXE/Services/ArchitectService.luau` — `GetTurnSnapshot()`, change callback, tagged replies.
- `src/StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/MatchStateClient.luau` — new.
- `src/StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/{ArchitectController,HUDController}.luau`, `ClientBootstrap.client.luau` — read the snapshot; turn keys; stale-reply filtering.
- `src/ReplicatedStorage/WORLD_EXE/Shared/Config.luau` — v0.2.1-phase2, `MatchSnapshotAttribute`, `StudioControls.FailOnEnter`, duration comment.
- `README.md`, `CLAUDE_START_HERE.md`, `docs/01_GAME_DESIGN.md` (duration), `src/README.md`, this file.
- Studio: all 13 scripts hash-verified identical to `src/`. No geometry changes.

### Tests (all **solo** — one Studio client)
| Test | Result |
|---|---|
| Unit (fresh play VM, cloned modules): rotation fairness 400 turns, round-robin, 11 bad payloads, valid payload, catalog, turn snapshot fields | 6/6 PASS |
| Unit: `MatchStateClient` — reads v5; ignores older v4, duplicate v5, malformed JSON; accepts v6 and fills a missing turn; turn key includes match id | 6/6 PASS |
| **Architect UI over consecutive matches** (one turn per match): match 3 turn 1 submission accepted, reply tagged `3:1`, feedback "Patch submitted."; match 4 turn 1 → panel key `4:1`, feedback empty, no selection, keyword empty, 4 cards | PASS |
| **Stale/delayed feedback**: reply tagged `3:1` sent during `4:1` → ignored; reply tagged `4:1` arriving after the panel moved to `5:1` → ignored; reply tagged with the current turn (`6:1`) → shown | PASS (IgnoredResponses 0→1→2, current reply displayed) |
| **Transition failure at INITIALIZING** (after spawns were scheduled): state → LOBBY, reason "recovered: entering INITIALIZING failed", participants 0, Architect 0, role Lobby, no force field, player on a lobby pad, 0 runtime objects; next match starts normally | PASS |
| **Overlapping respawn requests** (recovery lobby load, then next match's arena load ~0.9 s later): arena request waits, then loads; player on an arena pad in ACTIVE | PASS (after the serialization fix) |
| **Transition failure at ACTIVE** (after Architect start): LOBBY, participants 0, Architect 0, no scheduled turn; next match proceeds with the player on an arena pad | PASS |
| **Snapshot consistency** (client observed every snapshot over 3 matches): versions strictly increasing; Architect only in ACTIVE and tagged with the current match; no participants/Architect in LOBBY/COUNTDOWN; participants ≥ 1 in match states; RESULTS tagged with the current match; no scheduled turn outside ACTIVE | 17 snapshots, **0 violations** |
| Regression: real-remote submissions — number payload, extra key, 40-char id, code-like text, unknown patch rejected; alias `drones` accepted; second submission `no_open_turn`; every reply tagged `13:1` | PASS |
| Regression: burst of 8 → 4 `rate_limited` | PASS |
| Regression: death → arena respawn (5.2 s); out of bounds → eliminated 0.25 s → arena; non-participant in arena → lobby (0.13 s) | PASS |
| Regression: countdown with minimum 2 → LOBBY ("countdown cancelled: not enough players"), stays in LOBBY, restarts when the minimum is restored | PASS |
| Regression: stress — 4 more full cycles (matches 14→18): 40 snapshot versions, 0 out-of-order, 0 illegal transitions, baseline matched at every reset, 0 runtime objects left | PASS |
| Edit DataModel after play: no test clones, runtime objects or test attributes | PASS |
| Output | Only the two **intended** injected-failure warnings; no other errors or warnings |

### Unverified — multi-client Studio testing is not available through Studio MCP
*(Superseded: most of these were run in the two-client acceptance test above; see its matrix for current results.)* Not run at that time: Architect authorization with two players (`not_architect`, `stale_turn`); a player leaving during a turn or mid-match; abort when all participants leave; mid-match join → Spectator; > 12 players; concurrent spawning; multi-client replication of the snapshot/HUD; streaming at distance; spawn-generation invalidation on **departure** (code path present, not exercised); real UI clicks. These need Studio **Test → Clients and Servers** with 2+ clients, run by the owner.

## Phase 2 report — Match lifecycle and Architect selection (2026-11-10)

Approved by the owner 2026-11-10. Pre-phase checks: `Place1.rbxl` saved and unchanged since the post-Phase-1 backup (hash-identical); fresh backup `WorldEXE_pre-phase2_2026-11-10.rbxl` verified hash-identical; live Studio scripts hash-identical to `main` before any edit.

### Completed features
- **Match state machine** (`MatchService`, the only writer of match state): LOBBY → COUNTDOWN → INITIALIZING → ACTIVE → FINAL_PHASE → RESULTS → RESET → LOBBY, plus COUNTDOWN → LOBBY (below minimum) and INITIALIZING/ACTIVE/FINAL_PHASE → RESULTS when no participants remain. Illegal transitions assert. One server loop (0.25 s) evaluates all deadlines — there are no per-state timer callbacks that could fire into a later match. `MatchId` increments at INITIALIZING; Architect turns and results carry it.
- **Timing** (`Config.Match`): countdown 10 s, initializing 5 s, ACTIVE 420 s, FINAL_PHASE 90 s (8:30 of gameplay; target range now standardized to 8–12 min), results 12 s, reset 3 s. Low-stability trigger for the final phase is left for Phase 5.
- **Participation** (`PlayerStateService`): server-set player attribute `WORLD_EXE_Role` (Lobby / Participant / Spectator) and `WORLD_EXE_Alive`. Everyone in the lobby at the end of the countdown becomes a participant (cap 12; overflow spectates). Players joining during LOBBY/COUNTDOWN join the lobby; joining later → Spectator until the next match. Leaving removes the player from the roster and the Architect queue; an Architect who leaves ends their turn as skipped.
- **Spawning & respawning**: new enclosed **Lobby** platform (`Workspace.WORLD_EXE.Lobby`, 4 `LobbySpawn` SpawnLocations, built by `tools/studio/phase2_build_lobby.luau`, outside the arena map so Phase 1 validation/baseline are unaffected). The server sets each player's `RespawnLocation`: participants respawn on an arena pad during INITIALIZING/ACTIVE/FINAL_PHASE (different pad from last time); everyone else in the lobby. INITIALIZING reloads each participant on a distinct arena pad; RESET reloads everyone in the lobby.
- **Spawn protection**: a visible ForceField on participants for the INITIALIZING window only, removed at ACTIVE.
- **Out-of-bounds / containment**: watchdog every 0.5 s — characters below Y = −60 are eliminated (then respawn per role); non-participants found inside the arena bounds are returned to the lobby.
- **Safe reset**: RESET empties runtime folders (marker-checked, Phase 1 safety rules), compares the map to its baseline snapshot (warns on drift), resets every role to Lobby, and returns everyone to the lobby.
- **Architect** (`ArchitectService`): roster shuffled at match start, then round-robin; the chosen player moves to the back, so nobody goes twice in a row when another eligible (alive participant) player exists. First turn 15 s into ACTIVE, 12 s submission window (never time-scaled), 45 s between turns, 4 cards offered. Timeout / Architect leaving / phase change → turn skipped, nothing activates. No new turns in FINAL_PHASE (an open turn is cancelled).
- **Submission validation** (server): rate limit (burst 4, 1/s refill) → payload must be a table with exactly one key `patchId` → string, 1–32 chars of `[A-Za-z0-9 _-]` → an open turn exists → sender is the current Architect → turn belongs to the current match → window not expired → id/alias resolves through `PatchCatalog` → id is one of the offered cards. Each rejection returns a reason code via `SubmissionResult`. Accepted submissions are recorded and announced; **no patch behaviour runs** (Phase 3).
- **Patch catalog** (`Shared/PatchCatalog`): finite list of the four prototype patches with display names, warnings, effect text and aliases (case/punctuation-insensitive).
- **Replication** *(superseded by the versioned `Snapshot` attribute in review round 1)*: `ReplicatedStorage.WORLD_EXE.MatchState` attributes (State, MatchId, StateStartedAt, StateEndsAt, ParticipantCount, MinPlayers, Reason, ArchitectUserId/Name, TurnNumber, TurnEndsAt, OfferedPatches, NextTurnAt, LastResult JSON, LastReset*) plus `MatchStateChanged` / `PatchAnnouncement` / `SubmissionResult` RemoteEvents created by `NetService`.
- **Placeholder UI** (built-in Roblox UI only, palette from the reference board): HUD status panel (phase + timer, role, players needed / participants, Architect line or next-turn timer, results summary) and amber announcement banner; Architect panel on the right side, shown only to the current Architect, with 4 cards, keyword box (resolved locally to a card, never broadcast), confirm button, timer and feedback text.
- **Studio-only test controls**: `StudioTimeScale`, `StudioMinPlayers` attributes on `ServerScriptService.WORLD_EXE` (ignored on live servers; see `src/README.md`).

### Changed / added files
- Added: `src/ReplicatedStorage/WORLD_EXE/Shared/PatchCatalog.luau`, `src/ServerScriptService/WORLD_EXE/Services/{NetService,PlayerStateService,ArchitectService,MatchService}.luau`, `src/StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/{UIUtil,HUDController,ArchitectController}.luau`, `tools/studio/phase2_build_lobby.luau`.
- Changed: `Config.luau` (v0.2.0-phase2; Phase 2 sections appended, Phase 1 content unchanged), `Bootstrap.server.luau`, `ClientBootstrap.client.luau`, `src/README.md`, this file.
- Studio: all 12 scripts hash-verified identical to `src/`; new `Workspace.WORLD_EXE.Lobby`. Arena map unchanged (DecayTile 64, ArenaSpawn 12, baseline matched at every reset).

### Tests (all **solo** — one Studio client; no multi-client run)
| Group | Result |
|---|---|
| Unit (Edit mode): fair rotation — 400 simulated turns, 8 players, 25 % random ineligibility | PASS — 0 consecutive repeats when an alternative existed; 49–51 turns each |
| Unit: strict round-robin A B C A B C; sole eligible player may repeat; nobody eligible → nil | PASS |
| Unit: payload validation — 15 cases (non-table, string, nil, empty, extra key, array, wrong key, number/NaN id, empty, 33 chars, code-like text, newline, valid id, valid alias text) | 15/15 PASS |
| Unit: catalog resolution — 12 inputs incl. aliases, unknown, empty; exactly 4 approved ids | 13/13 PASS |
| Live: Bootstrap `Ready`, 4 remotes created, client ready | PASS |
| Live: INITIALIZING → participant on an arena pad with ForceField; ACTIVE → ForceField removed | PASS |
| Live: Architect selected (solo → self), 4 cards offered, panel shown only during the open turn | PASS |
| Live (client → real RemoteEvent): number payload, extra `duration` key, 40-char id, code-like text, unknown id | rejected: `bad_payload`, `bad_payload`, `bad_patch_id`, `bad_patch_id`, `unknown_patch` |
| Live: alias `gravity` → accepted as ZERO_G; announcement + HUD banner shown; second submission → `no_open_turn` | PASS |
| Live: burst of 8 rapid requests | 4 served, 4 `rate_limited` |
| Live: turn timeout → skipped, next turn after the interval; open turn cancelled at FINAL_PHASE | PASS (log) |
| Live: death in ACTIVE → respawn on an arena pad, still Participant; `Alive` false→true | PASS (3.8 s) |
| Live: below Y = −60 → eliminated by watchdog (0.37 s) → respawn in arena | PASS |
| Live: non-participant teleported into the arena → returned to the lobby (0.2 s); participant left in place | PASS |
| Live: RESULTS summary JSON (outcome, duration, participants, 1 accepted / 4 skipped turns) | PASS |
| Live: RESET removed 2 planted runtime objects, baseline matched, role → Lobby, player on a lobby pad, Architect cleared | PASS |
| Live: COUNTDOWN with `StudioMinPlayers=2` → LOBBY ("countdown cancelled: not enough players"), stays in LOBBY, restarts when the minimum is met | PASS |
| Live: repeated resets — 10 matches total in one session; recorder over 4 cycles: 0 illegal transitions, baseline matched at every reset, 0 runtime objects left | PASS |
| Edit DataModel after stopping play: no Remotes/MatchState/runtime folders/test attributes saved | PASS |
| Output | Only `[WORLD_EXE]` info lines (bootstrap, client ready, transitions, turns); **no errors or warnings** |

### Not tested at the time (requires multi-client) — superseded by the two-client acceptance test above
- `not_architect` and `stale_turn` rejections (need a second player); fair rotation with real players (covered only by the unit simulation).
- Player leaving during an Architect turn / during a match; abort to RESULTS when all participants leave.
- Mid-match join → Spectator; lobby overflow beyond 12 participants.
- Concurrent spawning on distinct pads; multi-client replication of state, HUD and announcements; streaming at distance (carried over from Phase 1).
- Clicking the placeholder UI with real input (the client viewport was not visible to the test harness); the submission path was exercised through the same RemoteEvent the UI uses.

### Design decisions for review
- Respawn policy: participants respawn in the arena during ACTIVE **and** FINAL_PHASE (no elimination). Phase 5 can change this.
- Readiness: every lobby player is treated as ready (no ready toggle).
- Final phase: stops new Architect turns rather than restricting the patch subset.
- An extra remote, `SubmissionResult`, carries per-request feedback to the submitting client.
- Studio defaults to a minimum of 1 player (live: 2) so solo playtests run the loop.

## Review round 2 correction — Phase 1 (2026-11-09)

### Change
`ArenaService` baseline snapshots now also record, for every BasePart: `Part.Shape` (Part and subclasses such as SpawnLocation), `Material` (it sets default friction/density), `CustomPhysicalProperties` (all five components, or `material-default`), `CollisionGroup`, `Massless`, and `AssemblyLinearVelocity` / `AssemblyAngularVelocity` (an anchored part with velocity acts as a conveyor); plus `CollisionFidelity` for mesh/union parts and `MeshId` for MeshParts (none exist in the map yet).

**Intentionally excluded** (documented in `ArenaService.luau` above `describe()`): Color, Transparency, Reflectance, CastShadow, Locked, Archivable and surface types (visual-only or no physics effect); RootPriority (only matters for unanchored assemblies — Anchored is compared); network ownership (runtime state); internal union geometry (not readable from Luau; no unions in the map).

### Changed files
- `src/ServerScriptService/WORLD_EXE/Services/ArenaService.luau` — `describe()` extended, new helpers `vectorKey()` / `physicalPropertiesKey()`, inclusion/exclusion list documented. Studio copy hash-verified identical (15481 bytes).
- `docs/PROJECT_STATUS.md` — this section.
- No other scripts, no geometry, and no arena layout changes.

### Tests (all **solo** Studio playtests via Studio MCP)
| Test | Result |
|---|---|
| **New:** `CentralCore.ReactorBase` Shape Cylinder → Block is reported as drift (`shape=Cylinder … => … shape=Block`); restored to Cylinder, baseline matches again | **PASS** |
| **New:** CollisionGroup changed (registered test group); CustomPhysicalProperties set; Material → Ice; Massless toggled; conveyor velocity on an anchored part | 5/5 detected, each matches again after restore |
| **New:** visual-only change (Color + Transparency) is not reported, by design | PASS |
| Regression: the 21 round-1 snapshot cases (move, rotate, resize, Anchored, CanCollide, CanQuery, CanTouch, attribute value/added/type, tag removed/added, rename, reparent, SpawnLocation Enabled, Attachment moved, Model PrimaryPart, removed, added, identity swap, class swap) + float-noise ignored | 22/22 PASS |
| Init valid, baseline matches before and after all restores, arena still valid | PASS |
| Bootstrap on server start | PASS — `Ready`, 0 errors, DecayTile=64 |
| Regression: 12/12 forced spawns | PASS |
| Edit DataModel after stopping play (ReactorBase still Cylinder; CoverWall_W Default group, SmoothPlastic, no custom physics, zero velocity; no test objects) | PASS |
| Output | Only the two `[WORLD_EXE] … ready v0.1.1-phase1` lines |

Totals this round: 32/32 snapshot cases, 12/12 spawns. Validation and runtime-folder code are unchanged since round 1 (35/35 and 6/6 there).

### Commits
- Round 2 correction commit: `9e96936` (ArenaService + this report).
- Final PR head for this round: `ddc784c` (docs-only commit recording `9e96936`). Squash-merged to `main` as `9b9cbd0` on 2026-11-10.

### Outstanding (not claimed)
- Concurrent-spawn test and multi-client streaming test (Studio Test → Clients and Servers, 2+ clients) — not run.

## Review round 1 corrections — Phase 1 (2026-11-09)

### Findings and resolutions
| # | Finding | Resolution |
|---|---|---|
| 1 | Type/value-check every tagged attribute | `Config.AttributeSchema` declares each attribute's kind (`id`, `zone`, `positive`, `links`) and `Config.TagClasses` the required class per tag. `Validate()` enforces: non-empty unique string ids per tag; `Zone` ∈ `Config.Zones`; `InteractionRadius` finite and > 0 (rejects 0, negatives, NaN, ±inf, strings); `Links` is a string of comma-separated ids with no empty entries, whitespace, duplicates or self-links, every id known, every link symmetric; tagged instances have the right class; tag counts match. |
| 2 | Stronger spawn validation | Each `ArenaSpawn` must be a `SpawnLocation` that is Enabled, Neutral, Anchored and CanCollide. Floor support: raycasts from the pad centre and four inset corners must hit anchored, collidable, non-`DecayTile` floor within 0.05 studs of the pad bottom (reports "no floor" or "floats N studs"). The 4×6×4 overhead-clearance check is retained. |
| 3 | Replace additive fingerprint | Removed (extended in round 2 with Shape and physics properties). `ArenaService` now captures a per-instance snapshot of `Workspace.WORLD_EXE.Map` at Init (keyed by instance identity) recording class, full path, all attributes (name + type + value), tags, and for BaseParts CFrame (position + rotation, 0.001 precision), size, Anchored, CanCollide, CanQuery, CanTouch; SpawnLocation Enabled/Neutral/Duration; Attachment CFrame; Model PrimaryPart. `CompareToBaseline()` reports added, removed, and changed instances (first 25 listed, total counted). Visual-only properties (color, material, transparency) are intentionally not compared. |
| 4 | Should SkySteps be DecayTiles? | **Decision: no.** See "SkySteps decision" below. The 5 steps were untagged, `TileId` removed, recoloured as solid floor; `DecayTile` count is now 64. |
| 5 | Runtime-folder safety | The server marks folders it creates with attribute `WORLD_EXE_RuntimeFolder=true`. `ResetRuntime()` empties only a single marked `Folder` per name; a non-Folder, an unmarked Folder, or duplicate same-named children are left untouched and reported as problems (Bootstrap → `Degraded`). |
| 6 | Status update | This section. |

### SkySteps decision
The five SkySteps are **not** `DecayTile`s. They form the only jump route between the Core and the Skybridge and sit over a lethal void, so a collapse there would mean a fall death rather than a reroute. `docs/03_PATCH_CATALOG.md` lists "Leave highlighted tiles, use alternate routes" as DECAY counterplay, which fits the Research Yard field (64 tiles, solid frame, several exits) but not a single-file shortcut. DECAY therefore targets the Research Yard only. Reversible: if Phase 4 tuning wants the shortcut to decay, re-tag the steps and raise `Config.ExpectedTagCounts.DecayTile` — that should be an explicit design decision.

### Changed files
- `src/ReplicatedStorage/WORLD_EXE/Shared/Config.luau` — version `0.1.1-phase1`; `AttributeSchema`, `TagClasses`, `SpawnFloorTolerance`, `RuntimeFolderMarker`; `DecayTile` count 64; removed `RequiredAttributes`.
- `src/ServerScriptService/WORLD_EXE/Services/ArenaService.luau` — rewritten validation, spawn checks, snapshot baseline (`CompareToBaseline`, `MatchesBaseline`), marker-based runtime folders (`ResetRuntime` now returns `(removed, problems)`).
- `tools/studio/phase1_build_arena.luau` — SkySteps built as plain floor (no `DecayTile`).
- `docs/PROJECT_STATUS.md` — this report.
- Unchanged: `Bootstrap.server.luau`, `ClientBootstrap.client.luau`.
- Studio: same script sources (hash-verified identical to `src/`); 5 SkySteps untagged/recoloured. No other geometry changed.

### Tests (all **solo** Studio playtests via Studio MCP; each negative case mutates the play-mode copy, validates, restores, and re-validates)
| Group | Result |
|---|---|
| Bootstrap on server start | PASS — `Ready`, 0 errors, counts DecayTile=64 / ArenaSpawn=12 / Stabilizer=3 / SupplyLandingPoint=5 / DroneWaypoint=15 |
| Attribute validation (20 cases): id empty / wrong type / missing / duplicate; zone unknown / wrong type / missing; radius 0 / negative / NaN / inf / string; links unknown / duplicate / self / empty entry / empty string / whitespace / asymmetric / wrong type | **20/20 PASS** — each rejected with the expected message, valid again after restore |
| Tag checks: tag on wrong class; tag count drift | 2/2 PASS |
| Spawn validation: disabled; unanchored; non-collidable; floating 2 studs; over void; half off an edge; on a DecayTile; supporting floor unanchored; supporting floor non-collidable; overhead obstruction | **10/10 PASS** |
| Arena valid and baseline matching after all restores | PASS |
| Snapshot drift (21 cases): move 0.5 studs; rotate 5°; resize; Anchored; CanCollide; CanQuery; CanTouch; attribute value / added / type (`10` vs `"10"`); tag removed / added; rename; reparent; SpawnLocation Enabled; Attachment moved; Model PrimaryPart; instance removed; instance added; identity swap with an identical clone; class swap Part→WedgePart | **21/21 detected**, each matches again after restore |
| Snapshot ignores float noise (1e-5 stud move) | PASS |
| Runtime folders: reset empties 9 objects from marked folders, second reset removes 0 | PASS |
| Runtime folders: a `Model` named `Collectibles` (with an authored part) is not destroyed and is reported | PASS |
| Runtime folders: an unmarked authored `Folder` named `RuntimeEffects` is not emptied and is reported | PASS |
| Runtime folders: duplicate `ActivePatchInstances` (marked + authored twin) → nothing destroyed, reported | PASS |
| Runtime folders: recreated and marked once conflicts are removed; map baseline unchanged | PASS |
| Regression: 12/12 forced spawns on pad, no overlap, on floor; respawn after death | PASS (respawned on `Spawn_YARD_3` after 4.0s) |
| Edit DataModel after stopping play: no runtime folders/attributes, no test objects, all restored values intact | PASS |
| Output | Only `[WORLD_EXE] Bootstrap ready v0.1.1-phase1 …` and `[WORLD_EXE] Client ready v0.1.1-phase1 …`; no errors or warnings |

Totals: 35/35 validation cases, 28/28 snapshot + runtime-folder cases, 12/12 spawns.

Issue found while testing: the floor-support ray was initially 1 stud long, so a pad floating 2 studs was reported as "no floor" rather than "floats 2.00 studs". The ray is now 5 studs; both messages were then verified.

### Commits
- Corrections commit: `1efe67b` (code + Studio-mirrored sources + this report).
- PR head after this round: the docs-only commit directly after `1efe67b` that records this line (its hash is posted in the PR conversation; a commit cannot contain its own hash).

### Outstanding (not claimed)
- **Concurrent-spawn test** (several players spawning/respawning at once, pad contention) — requires Studio Test → Clients and Servers with 2+ clients; not run.
- **Multi-client streaming test** (clients far from each zone; tagged parts streaming in/out; client tolerance) — not run.
- No lobby, spawn protection, or out-of-bounds handling beyond FallenPartsDestroyHeight (−500) — Phase 2 scope.

### Manual steps (resolved 2026-11-10)
1. ~~Press Ctrl+S in Studio~~ — done; `Place1.rbxl` saved 2026-11-09 23:56 and backed up as `WorldEXE_post-phase1_2026-11-10.rbxl`.
2. ~~ChatGPT re-review of PR #1~~ — done; squash-merged as `9b9cbd0`.

## Original Phase 1 report (2026-11-09, commit `ea9e05c`)

### Studio changes
- **Moved (not deleted):** template `Workspace.Baseplate` and `Workspace.SpawnLocation` → `ServerStorage.WORLD_EXE_TemplateBackup` (folder did not exist beforehand; properties verified identical after the move).
- **Created `Workspace.WORLD_EXE.Map`** (182 parts; generated by `tools/studio/phase1_build_arena.luau`, Studio owns the geometry):
  - `CentralCore` — 80×80 deck, reactor (base, neon column, glass shell, cap), two cover walls.
  - `ResearchYard` — solid frame around an 8×8 field of `DecayTile`s (9.8-stud tiles), four barriers.
  - `Skybridge` — elevated deck (top Y=24), north span to the Lookout, five `SkySteps` jump platforms (not DecayTiles since review round 1).
  - `Routes` — Core↔Yard bridge, Core→Skybridge ramp, Lookout, Lookout→Yard ramp, Yard north annex. Every zone is reachable by at least two routes.
  - `Stabilizers` — 3 placeholder Models (`STAB_CORE`, `STAB_YARD`, `STAB_SKY`), Atomic streaming, `InteractionPoint` attachment, `InteractionRadius=10`.
  - `SpawnLocations` — 12 real `SpawnLocation`s (4 per zone; Enabled, Neutral, Duration 0), on solid non-decay floor.
  - `SupplyLandingPoints` — 5 invisible, non-collidable markers.
  - `DroneWaypoints` — 15 invisible markers forming a symmetric link graph (`Links` attribute).
- **Scripts** (identical copies in `src/`):
  - `ReplicatedStorage.WORLD_EXE.Shared.Config` (ModuleScript) — tags, counts, attribute schema, runtime folder names/marker, palette.
  - `ServerScriptService.WORLD_EXE.Services.ArenaService` (ModuleScript) — arena validation, runtime-folder reset, baseline snapshot.
  - `ServerScriptService.WORLD_EXE.Bootstrap` (Script) — initializes ArenaService, sets `BootstrapStatus` / `ArenaValidationErrors` attributes on `Workspace.WORLD_EXE`.
  - `StarterPlayer.StarterPlayerScripts.WORLD_EXE.ClientBootstrap` (LocalScript) — minimal client controller; streaming-tolerant.
- Runtime folders (`ActivePatchInstances`, `Collectibles`, `RuntimeEffects`) are created by the server at runtime only; they are not saved in the place.
- Not changed: Lighting, StreamingEnabled, any third-party plugin.

### Tag/attribute baseline (current)
| Tag | Count | Class | Attributes |
|---|---|---|---|
| DecayTile | 64 (Research Yard only) | BasePart | TileId (id), Zone (zone) |
| ArenaSpawn | 12 | SpawnLocation | SpawnId (id), Zone (zone) |
| Stabilizer | 3 | Model | StabilizerId (id), Zone (zone), InteractionRadius (positive) |
| SupplyLandingPoint | 5 | BasePart | PointId (id), Zone (zone) |
| DroneWaypoint | 15 | BasePart | WaypointId (id), Zone (zone), Links (links) |

### Original tests (all **solo**)
| Test | Result |
|---|---|
| Static: tag counts, anchoring, collidable floors, non-collidable decor/markers, spawns on solid non-decay floor, supply points over floor | PASS (0 issues) |
| Each of the 12 spawns, forced via `RespawnLocation` + `LoadCharacter` | PASS 12/12 |
| Natural respawn after death (Health=0) ×2; respawn after falling into the void | PASS |
| 30 automatic (random) spawns | PASS — 30/30 on a pad; 11/12 pads drawn at random (YARD_2 passed its forced test) |
| Walk Core → Skybridge, Skybridge → Yard annex, Yard annex → Core | PASS |
| Jump route Core ↔ Skybridge via 5 SkySteps (real jumps) | PASS 6/6 up, 6/6 down (after reducing gaps from 8 to 4 studs) |
| Client: Config/root found with streaming on, status replicated | PASS |
| Edit DataModel unchanged after stopping play | PASS |

Test-harness note: setting `Humanoid.Jump` from an injected client script is overwritten by the default control script; jump tests use `Humanoid:ChangeState(Jumping)`.

### Known limitations / risks
- Solo tests only (see Outstanding above).
- Arena geometry lives only in the place file; `tools/studio/phase1_build_arena.luau` reproduces it on an empty place.
- The ForgeGUIConnect Studio plugin error seen in Phase 0 has not reappeared; still treated as an external plugin issue.

## ForgeGUI
- Workflow: [docs/09_FORGEGUI_WORKFLOW.md](./09_FORGEGUI_WORKFLOW.md).
- Read-only audit done 2026-11-09: 41 tools; publishing connection `@amfam1` (Personal, Image/Model/Audio); no credit-balance or cost-estimate tool; Studio insertion only via Studio MCP.
- Owner decisions: publish destination `@amfam1`; no generation/publishing until a specific test batch and budget are approved; check credit balance on the website before the first generation; keep assets private (no Creator Store); do not upload the reference board without separate approval; create `docs/ASSET_MANIFEST.md` before the first published asset; placeholder shapes and built-in UI until artwork is approved.

# WORLD.EXE — Development Roadmap and Acceptance Gates

## Global rules
- Work in order, one phase at a time.
- Save a project backup before substantial edits.
- Each phase ends with tests and a short report.
- Do not call a phase complete if a critical criterion fails.
- If multi-client testing is unavailable, state that; do not overclaim.

## Phase 0 — Audit and setup (read-only first)
Identify correct Studio session, inspect Explorer/DataModel and existing scripts, determine blank vs existing place, verify MCP read/write/playtest capability, map contents to planned architecture, identify risks, and propose backup method.

**Acceptance:** correct Studio instance identified; project summarized; no unrelated content modified; backup plan agreed; connection capability verified.

## Phase 1 — Foundation and arena blockout
Create WORLD_EXE folder structure; build compact three-zone graybox arena; add spawn locations and three stabilizers; tag decay tiles, spawn points, pickup points, and drone paths; set basic lighting/collision; create Bootstrap and minimal client controller.

**Acceptance:** arena loads; spawns work; tagged assets discoverable; no script errors; no player spawns inside geometry; reset restores known baseline.

## Phase 2 — Match lifecycle and Architect selection
Implement state machine; lobby participant policy; countdown; initialization; active timer; results; reset; safe join/leave handling; server-owned Architect queue; turn timer; submission UI placeholder; approved patch ID validation and fallback.

**Acceptance:** match starts/ends without manual intervention; join policy works; leaving during turn does not stall; only current Architect can submit; invalid patch IDs rejected; state replicates correctly.

## Phase 3 — Patch engine foundation
Implement catalog lookup; runtime records; warning/active/ending/ended lifecycle; active cap three; duration handling; unique runtime IDs; idempotent cleanup; match-generation cancellation; announcement event; central WorldModifierService abstraction.

**Acceptance:** test patch activates/tracks/expires/cleans; over-cap requests safely rejected/deferred; reset removes resources; repeated cleanup safe; failed activation does not corrupt match.

## Phase 4 — Four prototype patches
Build ZERO_G, DECAY, DRONE_SWARM, SUPPLY_DROP.

**Acceptance:** each passes relevant tests in `06_TESTING_AND_RELEASE.md`; each runs alongside at least one unrelated patch; no orphaned objects/tasks; counters/warnings/cleanup correct.

## Phase 5 — Stability, objectives, collectibles, scoring
Build stability meter; three stabilizer interactions; data fragments; objective interruption/completion; team objective result; individual scoring; results table; participation and placement rewards.

**Acceptance:** server owns score; duplicate collection/completion impossible; team and personal outcomes shown; rewards match server state; join/leave edge cases handled.

## Phase 6 — Initial player abilities
Build PHASE_DASH, ANCHOR, SCANNER; server cooldown validation; UI feedback; clear ability state; exploit/rate-limit tests.

**Acceptance:** abilities cannot be spammed; client cannot choose arbitrary cooldown/effect/target; abilities don't bypass map bounds or counterplay.

## Phase 7 — Interactions and catalog expansion
Build PatchInteractionService; first five curated combinations; expand toward 10–12 release-quality patches; archive discovery; balancing and patch rotation.

**Acceptance:** each interaction triggers once; cleanup follows source lifetimes; unsupported combinations fail safely; cap/stacking correct; every patch has warning and counterplay.

## Phase 8 — UI and visual polish
Replace placeholders with original style; improve HUD/Architect UI/announcements/objective markers/results/accessibility/audio.

**Acceptance:** readable desktop/mobile; warning text fits; UI does not block play; critical warnings work with audio disabled; reduced-effects settings function.

## Phase 9 — Progression and persistence
Add schema version, XP/levels, Data Bits/Core Shards, Patch Archive, mastery, cosmetic ownership/equip, safe persistence.

**Acceptance:** data loads/saves in published test environment; errors handled; values validated/clamped; no duplicate rewards; no per-frame datastore writes; migration documented.

## Phase 10 — Hardening and release candidate
Run multi-client tests, network latency/abuse tests, performance profiling, mobile controls, regression suite, UI polish, sound balance, tutorial, and owner-approved analytics plan.

**Acceptance:** no critical errors in test matrix; patch caps and cleanup verified; exploit tests rejected; performance acceptable at target player count; owner explicitly approves publishing.
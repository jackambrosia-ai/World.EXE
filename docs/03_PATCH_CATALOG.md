# WORLD.EXE — Patch Catalog and Behavior Specifications

## Shared patch rules
Every patch must define:
- Stable `PatchId` and display name.
- Category and rarity/weight where applicable.
- Warning title, short instruction, icon, and tell.
- Warning duration, active duration, and cleanup policy.
- Active patch cap cost (normally 1).
- Required tags/assets and dependency checks.
- Gameplay effect and explicit counterplay.
- Score/stability effects.
- Allowed combinations and exclusions.
- Server-authoritative behavior and client presentation.

All numerical values below are initial tuning proposals, not final balance.

## Prototype patches (build these first)

### 1. ZERO_G — Physics / global modifier
- **Warning:** `GRAVITY UNSTABLE — Movement will feel weightless!`
- **Effect:** Reduce effective world gravity during its active period.
- **Initial duration:** 35 seconds.
- **Counterplay:** Controlled movement, stable surfaces, Anchor ability, predictable landing routes.
- **Implementation:** WorldModifierService token; never set/restore Workspace.Gravity directly from the patch module without composition.
- **Cleanup:** Remove token and recompute effective gravity.
- **Tests:** Baseline restored after expiry; overlapping tokens resolve deterministically; match-end cleanup restores baseline; character/loose-part behavior acceptable in multi-client test.

### 2. DECAY — Environment / tagged tile hazard
- **Warning:** `STRUCTURAL DECAY — Marked platforms are about to collapse!`
- **Effect:** Select a limited number of tagged floor tiles in a readable sequence. A tile flashes/changes appearance, warns, then becomes temporarily non-solid or safely disabled. Do not permanently delete arena geometry.
- **Initial duration:** 40 seconds; collapse cycle bounded.
- **Counterplay:** Leave highlighted tiles, use alternate routes, Phase Dash.
- **Implementation:** Affect only parts tagged `DecayTile`; server chooses affected tiles. Client receives tile IDs/state for animation. Server owns collision/state and score.
- **Cleanup:** Restore original tile properties/collision; tolerate missing/destroyed tiles.
- **Tests:** No untagged part changes; warning precedes collapse; tile returns to baseline; no impossible unavoidable state.

### 3. DRONE_SWARM — Entity / AI hazard
- **Warning:** `SECURITY DRONES DEPLOYED — Keep moving and break line of sight!`
- **Effect:** Spawn a small capped group (initially 2–3) from approved spawn points. Drones pursue nearby living players using bounded server logic. Threatening but telegraphed, not instant-kill.
- **Initial duration:** 35 seconds.
- **Counterplay:** Cover, safe routes, dodge, Anchor/Phase Dash.
- **Implementation:** Clone approved templates from ServerStorage. Target eligible living participants only. Use throttled path recomputation or simple waypoint steering; do not compute paths every frame. Server owns hit/damage cooldowns and target selection.
- **Cleanup:** Remove drones, connections, path tasks, and target state. Check cancellation token in loops.
- **Tests:** Drone count capped; no targeting lobby/spectators/dead players; no through-wall damage if LOS is part of design; cleanup on expiry/reset; no orphaned loops.

### 4. SUPPLY_DROP — Beneficial / contested pickup
- **Warning:** `SUPPLY DROP INBOUND — Reach the marked landing zone!`
- **Effect:** Select a server-approved landing point, show a beacon/marker, then spawn a crate with small utility rewards (e.g., temporary shield pickup or data fragment bundle). First valid player to claim each item receives it.
- **Initial duration:** 30 seconds; unclaimed supply despawns on expiry.
- **Choice:** Opportunity, not harmful hazard; routing exposes players to other active patches.
- **Implementation:** Spawn from ServerStorage template at approved point. Server validates distance, alive state, match state, unclaimed state, and cooldown. Do not trust client-sent reward amounts.
- **Cleanup:** Remove crate, marker, prompt, and connections; prevent double claims.
- **Tests:** Exactly one claim per item; invalid distance rejected; expired crate cannot be claimed; rewards server-defined; reset clears all supply assets.

## Additional launch-catalog candidates (after prototype)
5. **BOUNCY:** selected tagged surfaces apply controlled bounce impulses; per-character/surface cooldown prevents infinite launch loops.
6. **SLIPPERY:** selected tagged surfaces reduce friction or use controlled movement response; restore original behavior.
7. **FLOOD:** safe water volume rises predictably; provide elevated escape routes and warnings.
8. **BLACKOUT:** reduce ambient lighting while preserving readable hazard indicators and accessibility.
9. **CORRUPTION:** bounded zones expand along a defined path; warn before expansion; do not spread to arbitrary parts.
10. **MAGNETIC:** move a capped set of tagged metal props toward safe magnetic points; never pull characters uncontrollably.
11. **ERROR_404:** distinct original malfunctioning entity with readable pursuit pattern and counterplay.
12. **DATA_RUSH:** spawn capped data fragments at approved locations with a timed collection window.
13. **INVERT:** short, well-signaled gravity-direction experiment, only after ZERO_G and character physics are stable.
14. **CLONE_ERROR:** spawn stylized non-player decoys; do not impersonate real players deceptively.

Public release target: 10–12 well-tested patches, not necessarily all 14. Do not add patches solely to reach a count.

## Approved combinations (build only after interaction framework)
1. **ZERO_G + BOUNCY = SUPER_BOUNCE:** amplified bounce in low gravity; clamp launch velocity.
2. **BLACKOUT + DRONE_SWARM = HUNTER_SCAN:** scan cones are visible; players get warning before scans.
3. **FLOOD + MAGNETIC = FLOATING_DEBRIS:** selected debris creates temporary stepping routes; never block every escape route.
4. **DECAY + CORRUPTION = RAPID_DECAY:** only tagged DECAY tiles affected; warning remains fair.
5. **SLIPPERY + MAGNETIC = SLIDE_FIELD:** tagged loose props slide toward a marked safe magnetic area, not into players.

Each combination triggers once per relevant active set/session. Give it an interaction ID and cleanup tied to source patch lifetimes. If a source ends, combination ends or recomputes according to a documented rule.

## Conflict and fairness rules
- Never combine modifiers into unbounded velocity, impossible jumps, or forced instant elimination.
- Never exceed global active-patch cap.
- Warnings must explain the danger and response.
- Do not allow targeted harm against a named player.
- Prevent repeated severe-patch spam with cooldowns, rotation, or availability weights.
- All patch behavior must be reversible at match end.
# WORLD.EXE — Game Design Document

## 1. High concept
**Working title:** WORLD.EXE  
**Tagline:** Reality is yours to break.  
**Genre:** Multiplayer reality-manipulation sandbox with survival, party-game, and objective elements.

Players are test subjects in a shared virtual simulation. A malfunctioning Reality Engine allows selected players (Architects) to submit approved updates called **patches**. Patches change the world's physics, environment, entities, or opportunities. Players adapt to the changing arena, complete shared repair objectives, collect data fragments, and compete for individual score.

## 2. Design pillars
1. **Player-driven variation:** players influence what the world does next.
2. **Readable chaos:** warnings, visual language, safe counterplay, and consistent rules make danger understandable.
3. **Emergent combinations:** selected patches can overlap and create surprising, tested interactions.
4. **Hybrid motivation:** individual score and survival rewards coexist with shared objectives.
5. **Expandable foundation:** new patches, maps, objectives, and modes can be added without rewriting the match core.

## 3. Target scope
- Platform: Roblox.
- Initial target: 8–12 players per server, subject to Studio performance and actual Roblox server constraints.
- Target match length: 8–12 minutes. Initial gameplay duration: 8:30 (ACTIVE 7:00 + FINAL_PHASE 1:30); revisit after the first public tuning pass.
- Initial release: one polished modular arena, one main mode (Stability Run), 10–12 patches after expansion, three initial abilities, a patch archive, basic XP/currency, and persistent data.
- Prototype milestone: one blockout arena, complete match loop, and four functioning patches.

These numbers are design targets, not guaranteed performance or final balance values.

## 4. Fiction and setting
The Reality Engine is an experimental simulation platform. Its control layer has become unstable. Players can submit patches, while the system tracks instability and launches recovery objectives. The world resets between simulations, allowing players to experiment and progress.

Use an original digital-lab visual identity: modular platforms, holographic infrastructure, clean color-coded warnings, stylized corruption, and a central reactor/core. Do not borrow another game's recognizable presentation.

## 5. Main mode: Stability Run

### Match flow
1. **LOBBY** — wait for minimum players and readiness.
2. **COUNTDOWN** — announce match start and lock entry.
3. **INITIALIZING** — spawn players, reset arena, initialize match data.
4. **ACTIVE** — Architect turns, patch activations, objectives, pickups, scoring.
5. **FINAL_PHASE** — trigger on elapsed-time threshold or low stability; constrain new patch choices and increase pressure fairly.
6. **RESULTS** — calculate standings, rewards, participation, and team objective result.
7. **RESET** — clean temporary objects and return participants to lobby.

Handle early server shutdown, players leaving, and insufficient participants without hanging the match.

### Architect selection and patch submission
- Select an eligible living participant at each Architect turn.
- Avoid selecting the same player on consecutive turns when alternatives exist.
- Use a shuffled/weighted turn queue so opportunities are reasonably distributed.
- Give the selected player a short submission window (initial target 10–12 seconds).
- The player selects one approved patch from a keyword/alias or a small set of presented cards.
- If the player does not submit, use a safe default/skip policy; do not randomly activate a severe patch without warning.
- Announce the patch and a clear warning (initial target 4–5 seconds) before activation.
- Architect is a gameplay role, not permission to execute arbitrary code or spawn arbitrary objects.

### Match length and cadence
Target 8–12 minutes, starting at 8:30 of gameplay (ACTIVE 7:00 + FINAL_PHASE 1:30). Start with a conservative patch cadence that allows warnings, player reaction, and cleanup. Do not attempt to activate every patch in every match. A target of roughly 5–7 major patch activations per match is a reasonable first balancing hypothesis; verify with playtests.

### Concurrent patch limit
Start with a maximum of three concurrent major patches. Some short-lived effects may be treated as sub-effects owned by a major patch. The engine must reject or defer activations that exceed the cap. Never silently delete a still-active patch to make room unless an explicit replacement rule says so.

## 6. Hybrid objectives and scoring
Each match has a shared **Simulation Stability** value, initialized to 100. Patch activation and certain hazards lower it; completing stabilizer tasks raises it. Exact rates must be tuned in playtests.

Three stabilizer structures are placed in distinct arena regions. Players gather data fragments and interact with a stabilizer to complete a repair task. Repair tasks should require time and expose players to some risk, but provide clear progress feedback and interruption rules.

### Individual score sources
- Survive meaningful time intervals while alive.
- Collect data fragments.
- Complete or assist stabilizer repairs.
- Complete optional match objectives.
- Discover a new patch or approved combination.
- Successfully adapt to a patch-specific challenge.

Avoid rewarding players for repeatedly damaging/eliminating others. If a patch creator receives a reward, keep it modest and based on participation/variety rather than causing deaths.

### Team outcome
At match end, award a team success bonus if the group reaches a stability target or completes a required number of repairs. A failed team objective should not erase individual participation rewards.

### Final phase
Trigger after a configured time or when stability reaches a critical threshold. It should provide a clear announcement/countdown, restrict new patches to a tested subset or stop new activations, intensify existing threats without untelegraphed instant deaths, award survival/placement bonuses, and end at a fixed deadline or clear match end condition.

## 7. Player abilities (initial three)
Abilities are sidegrades for counterplay and utility, not pay-to-win power.
1. **PHASE_DASH** — short displacement/dodge; initial cooldown target 18s. Server validates cooldown and state. Prevent teleporting through walls or into invalid regions.
2. **ANCHOR** — briefly reduces knockback or selected movement disturbances; initial cooldown target 25s. Does not grant invulnerability.
3. **SCANNER** — reveals nearby data fragments and/or patch hazard indicators for a short duration; initial cooldown target 22s.

Future candidates: REBOOT (limited recovery), GRAPPLE (movement), STABILIZER (small temporary protection zone). Not part of first playable prototype.

## 8. Progression
### Sync XP and levels
Earned through match participation, objectives, survival, discovery, and helpful actions. Levels unlock cosmetics, titles, and customization. Do not increase base damage/health/speed through progression.

### Currencies
- **Data Bits:** common earnable currency for basic cosmetics and noncompetitive unlocks.
- **Core Shards:** rarer earnable currency for special cosmetics/achievement rewards. Keep earnable through play initially.

### Patch Archive
Tracks patch discoveries, activation counts, survival challenges, and discovered combinations. Use a finite patch catalog. Do not store unbounded player text.

### Patch Mastery
Each patch can have optional challenges (survive while active, complete an objective, collect fragments during it, help another player). Rewards should be XP, titles, and cosmetics rather than direct combat advantages.

## 9. First arena: THE SANDBOX
Build a compact modular arena with three regions:
- **Central Core:** central gathering landmark and primary stabilizer.
- **Research Yard:** open space, cover, pickups, and hazard test area.
- **Skybridge:** elevated platforms, shortcuts, and movement challenges.

Include multiple connected routes and vertical variation, clearly marked spawn points, three stabilizer locations with interaction zones, tagged floor tiles for DECAY, drone navigation paths/waypoints or accessible walkable surfaces, supply drop landing points, and safe spawn protection during match initialization only.

Use blockout parts first. Do not spend time on final art until the full loop is testable.

## 10. Modes and future content (not launch blockers)
- Sandbox Lab: no elimination pressure; test patches and combinations.
- Patch Wars: team-based control mode.
- Daily Simulation: fixed patch sequence and leaderboard.
- Additional maps: Aqua Lab, Sky Grid, Neon City, Core Breach.

These are future expansions, not launch blockers.

## 11. Fairness and accessibility
- Every harmful patch must have a readable tell and plausible counterplay.
- Avoid full-screen effects that obscure critical telegraphs.
- Provide captions/subtitles for important audio warnings.
- Use shape, icon, and text as well as color to communicate danger.
- Provide reduced screen shake/flashing settings where feasible.
- Avoid relying only on sound to communicate an imminent threat.
- Architect submissions must not allow targeted harassment, arbitrary scripts, or irreversible griefing.
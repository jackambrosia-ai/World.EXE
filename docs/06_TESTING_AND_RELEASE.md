# WORLD.EXE — Testing, Security, Performance, and Release

## 1. Testing principles
- Test server behavior, not only visual effects.
- Distinguish solo tests from Start Server + multiple clients.
- Test normal, invalid, expired, interrupted, and cleanup paths.
- Record steps, expected/actual result, console errors, and severity.
- Re-run regression tests after shared-service changes.

## 2. Foundation tests
- Match cannot start below minimum participant count.
- Countdown cancels safely if participants drop below minimum.
- Players spawn at valid locations, not inside geometry.
- Only allowed state transitions occur.
- Mid-match join follows spectator/next-round policy.
- Player leaving during Architect turn/objective/ability does not hang state.
- Reset removes match state and invalidates old callbacks.

## 3. Architect and remote security tests
- Non-Architect cannot submit.
- Architect cannot submit after window closes.
- Unknown patch IDs rejected.
- Wrong payload types, excessive strings, NaN/infinite numbers, unexpected table keys rejected.
- Repeated requests rate-limited.
- Client cannot set patch duration, damage, target, score, reward, or ownership.
- Player cannot use another player's Architect slot.
- Invalid/malicious Instance references rejected.

## 4. Patch tests

### ZERO_G
- Baseline captured/restored.
- Modifier token removal recomputes effective gravity.
- Expiry, reset, and failed activation restore safe state.
- Players retain control and can reach safe platforms.

### DECAY
- Only tagged tiles affected.
- Every tile gets warning before unsafe state.
- Warning visible at useful distance.
- Tile returns to baseline after patch.
- Missing/destroyed tile does not crash cleanup.

### DRONE_SWARM
- Drone count stays within cap.
- Target selection excludes lobby/spectator/dead players.
- AI updates bounded/throttled.
- Hit/damage cadence server-controlled.
- Drone loops/instances removed on expiry/reset.

### SUPPLY_DROP
- Landing point from server allowlist.
- One pickup claimed once.
- Too-far or invalid-state player cannot claim.
- Expired/unavailable crate cannot be claimed.
- Reward values server-defined.
- All assets/prompts removed on cleanup.

## 5. Objective and score tests
- Only valid living participants start repairs.
- Interaction range and hold duration server-verified.
- Leaving range, dying, or interruption follows clear rule.
- Duplicate one-time reward impossible.
- Team stability and personal score separate.
- Client cannot request arbitrary score.
- Results calculated once per match.

## 6. Ability tests
- Cooldown enforced on server.
- Invalid ability IDs rejected.
- Ability unavailable while dead, in lobby, or forbidden phase.
- PHASE_DASH cannot pass through walls/out of bounds.
- ANCHOR reduces only intended effects; not invulnerability.
- SCANNER reveals only intended objects.

## 7. Persistence tests
- DataStore errors produce safe fallback.
- Loaded schema version/types validated.
- Currency, XP, and collections clamped.
- Save at checkpoints, not every frame.
- Duplicate completion callbacks do not double-award.
- Test in published private test place before release.
- Do not use production player data for destructive tests.

## 8. Performance checks
- Cap active major patches (initially three).
- Cap drones and collectibles.
- Avoid repeated full Workspace scans.
- Avoid per-frame server loops where lower frequency suffices.
- Clean connections, tasks, instances, and modifier tokens.
- Check server memory/script activity over multiple matches.
- Test target client count where possible.
- Keep bounded VFX client-side when gameplay authority is unaffected.

## 9. Accessibility and UX
- Important warnings include text and visual cues, not audio alone.
- Reduced screen shake/flashing settings honored.
- HUD works at common aspect ratios/mobile resolutions.
- Touch controls and prompts usable.
- No unavoidable instant elimination without explicit approval.

## 10. Release checklist
- All release features pass tests.
- Backup/version saved.
- No unknown free-model scripts or unreviewed assets.
- No hard-coded secrets.
- No unauthorized purchases/products/monetization.
- Description, icon, thumbnails, permissions reviewed by owner.
- DataStore tested in private published environment.
- Multi-client report reviewed.
- Owner explicitly approves publishing.
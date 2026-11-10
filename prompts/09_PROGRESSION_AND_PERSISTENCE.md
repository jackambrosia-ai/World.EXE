# Phase 9 — Progression and persistence

Implement after the playable match loop is stable:
- Versioned player data schema.
- Sync XP and levels.
- Data Bits and Core Shards.
- Patch Archive discovery and usage counts.
- Patch-specific mastery challenges.
- Basic cosmetic ownership/equip.
- Settings persistence.

Use DataStoreService safely with pcall, bounded retries/backoff, schema validation, clamping, dirty-state saves, and shutdown handling. Do not save every action/frame. Do not introduce pay-to-win progression. Test persistence in a private published test place, not against production player data. Report DataStore limitations clearly.
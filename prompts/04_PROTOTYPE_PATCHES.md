# Phase 4 — Four prototype patches

Implement the four patches from `docs/03_PATCH_CATALOG.md` in order:

1. ZERO_G — low-gravity modifier through WorldModifierService.
2. DECAY — sequential, telegraphed collapse of tagged tiles only.
3. DRONE_SWARM — capped 2–3 server-controlled drones with throttled targeting and readable counterplay.
4. SUPPLY_DROP — server-selected landing point, beacon, one-time validated pickup, server-defined reward.

For each patch:
- Implement server behavior and client presentation separately.
- Use the catalog warning and counterplay.
- Define duration, resource ownership, cleanup, and scoring/stability hooks.
- Test expiry, match reset, player departure, failure paths, and concurrency with at least one unrelated patch.

Do not begin progression or content expansion until all four pass their tests.
# Phase 6 — Initial player abilities

Implement PHASE_DASH, ANCHOR, and SCANNER as server-validated sidegrade abilities.

- PHASE_DASH: short, collision-aware dodge; initial cooldown target 18s.
- ANCHOR: briefly reduces selected knockback/movement disturbances; initial cooldown target 25s; not invulnerability.
- SCANNER: briefly reveals nearby data fragments and/or intended hazard indicators; initial cooldown target 22s.

Server validates player state, ability ownership, match phase, cooldown, request rate, and all effect parameters. Client handles input and feedback only. Test spam, invalid IDs, dead/spectator use, cooldown reset edge cases, geometry exploits, and interactions with prototype patches.
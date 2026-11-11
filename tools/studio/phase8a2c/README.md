# Phase 8A-2c — patch-responsive environments (Studio tools)

Run through Studio MCP (`execute_luau`) in **Edit** unless stated. No Rojo. The client logic lives in
`src/StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/EnvironmentResponseClient.luau`.

| File | Mode | Purpose |
|---|---|---|
| `0_build.luau` | Edit | Tags existing decorative hooks `EnvFX_<EFFECT_ID>`, writes `Base_*` + `EnvFX_Role` + `Env8A2C=hook`; builds the Option B extras in `Map.EnvFX8A2C` (`Env8A2C=new`); writes `ServerStorage.WORLD_EXE_Rollback8A2C`. Refuses to run twice; a failed build undoes itself. |
| `1_audit.luau` | Edit, read-only | JSON report: hooks per effect, roles, Base_* types and baseline equality, no gameplay-tagged hooks, collidable hooks Color-only, extras hidden/non-collidable/non-query/non-touch/no-shadow, lights/beam disabled, Option B limits, map totals, marker counts. |
| `2_rollback.luau` | Edit (working session only) | Removes exactly the 8A-2c work (marked instances, EnvFX tags, Base_/EnvFX_Role/Env8A2C attributes, rollback folder, `Map.Phase8A2C`). Never touches 8A-2a/8A-2b content. |
| `3_test_server.luau` | Play (Server) | Injected as `ZZ_EnvFXTest8A2C`: command-driven harness (`req`, `cancel`, `cancelall`, `validate`) for AC9 tests. Never saved. |
| `4_finalize.luau` | Edit | After a PASS audit on the final state: checks no `ZZ_` leftovers, StudioTimeScale cleared, Lighting 1.80/0.30, then sets `Map.Phase8A2C`. |

Order: `0_build` → `1_audit` (PASS) → `4_finalize` → owner save.

Reproducibility (2026-11-11, unsaved working session before the owner's save): rollback → state
fingerprint equal to the pre-8A-2c fingerprint (2003 instances, `2003:1713694229`); build →
`2049:548979784`; rollback → `2003:1713694229` again; build → `2049:548979784` again.

## Hook inventory (130 instances)
Existing decorative architecture (92): CoilTrim 24 + CoilLight 3 (ZERO_G, SUPER_BOUNCE), Skylight 3
(DECAY, RAPID_DECAY), Inlay 4 (DECAY), SpireBeacon 2 + SpireLight 2 (DRONE_SWARM), HubRing 12 +
Oculus 8 (SUPPLY_DROP), Pipe 12 (SLIPPERY), Seam 5 (BLACKOUT), CableTray 5 (MAGNETIC), IntakeGrate 4 +
IntakeLight 1 + PumpRing 2 + TurbineCasing 3 (collidable: Color only) (FLOOD), CraneWarning 1 +
CraneLight 1 (RAPID_DECAY).

Option B extras (38 instances; all hidden or disabled at baseline): BounceRim 8 (BOUNCY, SUPER_BOUNCE),
SlipRim 4 (SLIPPERY, SLIDE_FIELD), GlitchA 4 + GlitchB 8 (CORRUPTION), Debris 6 + DebrisChip 2 +
DebrisLight 1 (FLOATING_DEBRIS), MagCoil 2 + MagLight 2 (MAGNETIC), ScanBeam 1 (HUNTER_SCAN), plus the
beam's 2 Attachments. 34 BaseParts, 0 collidable, 3 PointLights, 1 Beam, 0 emitters.

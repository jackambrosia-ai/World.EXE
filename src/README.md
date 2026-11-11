# src/ — WORLD.EXE script sources

These files are exact copies of the WORLD_EXE scripts in the Studio place. Paths mirror the Studio hierarchy:

| File | Studio instance | Class |
|---|---|---|
| `ReplicatedStorage/WORLD_EXE/Shared/Config.luau` | `ReplicatedStorage.WORLD_EXE.Shared.Config` | ModuleScript |
| `ReplicatedStorage/WORLD_EXE/Shared/PatchCatalog.luau` | `ReplicatedStorage.WORLD_EXE.Shared.PatchCatalog` | ModuleScript |
| `ReplicatedStorage/WORLD_EXE/Shared/AbilityCatalog.luau` | `ReplicatedStorage.WORLD_EXE.Shared.AbilityCatalog` | ModuleScript |
| `ReplicatedStorage/WORLD_EXE/Shared/InteractionCatalog.luau` | `ReplicatedStorage.WORLD_EXE.Shared.InteractionCatalog` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Bootstrap.server.luau` | `ServerScriptService.WORLD_EXE.Bootstrap` | Script |
| `ServerScriptService/WORLD_EXE/Services/ArenaService.luau` | `ServerScriptService.WORLD_EXE.Services.ArenaService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/NetService.luau` | `ServerScriptService.WORLD_EXE.Services.NetService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/PlayerStateService.luau` | `ServerScriptService.WORLD_EXE.Services.PlayerStateService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/ArchitectService.luau` | `ServerScriptService.WORLD_EXE.Services.ArchitectService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/MatchService.luau` | `ServerScriptService.WORLD_EXE.Services.MatchService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/CleanupService.luau` | `ServerScriptService.WORLD_EXE.Services.CleanupService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/WorldModifierService.luau` | `ServerScriptService.WORLD_EXE.Services.WorldModifierService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/PatchService.luau` | `ServerScriptService.WORLD_EXE.Services.PatchService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/StabilityService.luau` | `ServerScriptService.WORLD_EXE.Services.StabilityService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/ScoreService.luau` | `ServerScriptService.WORLD_EXE.Services.ScoreService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/CollectibleService.luau` | `ServerScriptService.WORLD_EXE.Services.CollectibleService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/ObjectiveService.luau` | `ServerScriptService.WORLD_EXE.Services.ObjectiveService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/AbilityService.luau` | `ServerScriptService.WORLD_EXE.Services.AbilityService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/BehaviorRuntime.luau` | `ServerScriptService.WORLD_EXE.Services.BehaviorRuntime` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/PatchInteractionService.luau` | `ServerScriptService.WORLD_EXE.Services.PatchInteractionService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/ZeroG.luau` | `ServerScriptService.WORLD_EXE.Patches.ZeroG` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/Decay.luau` | `ServerScriptService.WORLD_EXE.Patches.Decay` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/DroneSwarm.luau` | `ServerScriptService.WORLD_EXE.Patches.DroneSwarm` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/SupplyDrop.luau` | `ServerScriptService.WORLD_EXE.Patches.SupplyDrop` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/Bouncy.luau` | `ServerScriptService.WORLD_EXE.Patches.Bouncy` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/Slippery.luau` | `ServerScriptService.WORLD_EXE.Patches.Slippery` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/Blackout.luau` | `ServerScriptService.WORLD_EXE.Patches.Blackout` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/SuperBounce.luau` | `ServerScriptService.WORLD_EXE.Patches.SuperBounce` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/HunterScan.luau` | `ServerScriptService.WORLD_EXE.Patches.HunterScan` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/Magnetic.luau` | `ServerScriptService.WORLD_EXE.Patches.Magnetic` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/Corruption.luau` | `ServerScriptService.WORLD_EXE.Patches.Corruption` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/Flood.luau` | `ServerScriptService.WORLD_EXE.Patches.Flood` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/FloatingDebris.luau` | `ServerScriptService.WORLD_EXE.Patches.FloatingDebris` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/RapidDecay.luau` | `ServerScriptService.WORLD_EXE.Patches.RapidDecay` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/SlideField.luau` | `ServerScriptService.WORLD_EXE.Patches.SlideField` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Patches/TestBehaviors.luau` | `ServerScriptService.WORLD_EXE.Patches.TestBehaviors` | ModuleScript |
| `StarterPlayer/StarterPlayerScripts/WORLD_EXE/ClientBootstrap.client.luau` | `StarterPlayer.StarterPlayerScripts.WORLD_EXE.ClientBootstrap` | LocalScript |
| `StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/UIUtil.luau` | `StarterPlayer.StarterPlayerScripts.WORLD_EXE.Controllers.UIUtil` | ModuleScript |
| `StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/MatchStateClient.luau` | `StarterPlayer.StarterPlayerScripts.WORLD_EXE.Controllers.MatchStateClient` | ModuleScript |
| `StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/HUDController.luau` | `StarterPlayer.StarterPlayerScripts.WORLD_EXE.Controllers.HUDController` | ModuleScript |
| `StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/ArchitectController.luau` | `StarterPlayer.StarterPlayerScripts.WORLD_EXE.Controllers.ArchitectController` | ModuleScript |
| `StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/AbilityController.luau` | `StarterPlayer.StarterPlayerScripts.WORLD_EXE.Controllers.AbilityController` | ModuleScript |

Created at runtime by the server (not saved in the place, not in `src/`): `ReplicatedStorage.WORLD_EXE.Remotes` (RemoteEvents), `ReplicatedStorage.WORLD_EXE.MatchState` (one `Snapshot` attribute: versioned JSON of the whole match state), and the runtime folders under `Workspace.WORLD_EXE`. Client UI is built in code by the controllers (no StarterGui instances).

## Sync procedure (no Rojo — owner decision)
Claude edits Studio directly through Studio MCP. After every script change, Claude writes the same source here and verifies that the Studio `Source` and the file have the same byte length and polynomial hash (`h = (h*31 + byte) mod 2147483647`). A mismatch blocks the commit.

Geometry is **not** in `src/`; it is Studio-owned. **Current arena (ArenaVersion 2, Phase 8A-1):** `tools/studio/phase8a1_build_arena.luau` builds the whole map, every tagged marker and the lobby, validates them, and keeps the previous arena as `ServerStorage.WORLD_EXE_RollbackArena_v1`. The older builders describe the prototype arena (ArenaVersion 1): `tools/studio/phase1_build_arena.luau` and `tools/studio/phase2_build_lobby.luau` record how the arena and lobby were generated; `tools/studio/phase5_fragment_spawns.luau` records the 12 FragmentSpawn markers added in Phase 5; `tools/studio/phase7a_surfaces.luau` records the 8 BounceSurface/SlipSurface pads added in Phase 7A; `tools/studio/phase7b_markers.luau` records the Phase 7B content under `Map.PatchMarkers` (8 MagneticProp crates, 4 MagneticPoint, 12 CorruptionNode and 2 FloodZone markers).

## Studio-only test controls
Attributes on `ServerScriptService.WORLD_EXE`, honoured only when `RunService:IsStudio()`:
- `StudioTimeScale` (number > 0): multiplies match-phase durations and Architect turn intervals (the 12 s submission window is never scaled).
- `StudioMinPlayers` (number ≥ 1): overrides the minimum player count. Without it, Studio uses `Config.Match.StudioMinPlayers` (1) so a solo playtest runs the loop; live servers always use `Config.Match.MinPlayers` (2).
- `StudioFailOnEnter` (state name, e.g. `"INITIALIZING"`): makes that state's entry fail after its hook runs, to test transition-failure recovery.

Studio-only test patches: `Patches/TestBehaviors` (`TEST_*` IDs) are registered by PatchService only when `RunService:IsStudio()`, are requested only with `{ Test = true }` from server-side test code, and are not in `PatchCatalog`, so players can never request them.

Test note: code run through Studio MCP gets its own module instances (it cannot reach the running game's services), so live tests observe the game through the `Snapshot` attribute, player attributes (`WORLD_EXE_Role`, `WORLD_EXE_Alive`, `WORLD_EXE_LastSpawn`) and the real RemoteEvents; pure-function tests require clones of the modules.

# src/ — WORLD.EXE script sources

These files are exact copies of the WORLD_EXE scripts in the Studio place. Paths mirror the Studio hierarchy:

| File | Studio instance | Class |
|---|---|---|
| `ReplicatedStorage/WORLD_EXE/Shared/Config.luau` | `ReplicatedStorage.WORLD_EXE.Shared.Config` | ModuleScript |
| `ReplicatedStorage/WORLD_EXE/Shared/PatchCatalog.luau` | `ReplicatedStorage.WORLD_EXE.Shared.PatchCatalog` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Bootstrap.server.luau` | `ServerScriptService.WORLD_EXE.Bootstrap` | Script |
| `ServerScriptService/WORLD_EXE/Services/ArenaService.luau` | `ServerScriptService.WORLD_EXE.Services.ArenaService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/NetService.luau` | `ServerScriptService.WORLD_EXE.Services.NetService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/PlayerStateService.luau` | `ServerScriptService.WORLD_EXE.Services.PlayerStateService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/ArchitectService.luau` | `ServerScriptService.WORLD_EXE.Services.ArchitectService` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Services/MatchService.luau` | `ServerScriptService.WORLD_EXE.Services.MatchService` | ModuleScript |
| `StarterPlayer/StarterPlayerScripts/WORLD_EXE/ClientBootstrap.client.luau` | `StarterPlayer.StarterPlayerScripts.WORLD_EXE.ClientBootstrap` | LocalScript |
| `StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/UIUtil.luau` | `StarterPlayer.StarterPlayerScripts.WORLD_EXE.Controllers.UIUtil` | ModuleScript |
| `StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/MatchStateClient.luau` | `StarterPlayer.StarterPlayerScripts.WORLD_EXE.Controllers.MatchStateClient` | ModuleScript |
| `StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/HUDController.luau` | `StarterPlayer.StarterPlayerScripts.WORLD_EXE.Controllers.HUDController` | ModuleScript |
| `StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/ArchitectController.luau` | `StarterPlayer.StarterPlayerScripts.WORLD_EXE.Controllers.ArchitectController` | ModuleScript |

Created at runtime by the server (not saved in the place, not in `src/`): `ReplicatedStorage.WORLD_EXE.Remotes` (RemoteEvents), `ReplicatedStorage.WORLD_EXE.MatchState` (one `Snapshot` attribute: versioned JSON of the whole match state), and the runtime folders under `Workspace.WORLD_EXE`. Client UI is built in code by the controllers (no StarterGui instances).

## Sync procedure (no Rojo — owner decision)
Claude edits Studio directly through Studio MCP. After every script change, Claude writes the same source here and verifies that the Studio `Source` and the file have the same byte length and polynomial hash (`h = (h*31 + byte) mod 2147483647`). A mismatch blocks the commit.

Geometry is **not** in `src/`; it is Studio-owned. `tools/studio/phase1_build_arena.luau` and `tools/studio/phase2_build_lobby.luau` record how the arena and lobby were generated.

## Studio-only test controls
Attributes on `ServerScriptService.WORLD_EXE`, honoured only when `RunService:IsStudio()`:
- `StudioTimeScale` (number > 0): multiplies match-phase durations and Architect turn intervals (the 12 s submission window is never scaled).
- `StudioMinPlayers` (number ≥ 1): overrides the minimum player count. Without it, Studio uses `Config.Match.StudioMinPlayers` (1) so a solo playtest runs the loop; live servers always use `Config.Match.MinPlayers` (2).
- `StudioFailOnEnter` (state name, e.g. `"INITIALIZING"`): makes that state's entry fail after its hook runs, to test transition-failure recovery.

Test note: code run through Studio MCP gets its own module instances (it cannot reach the running game's services), so live tests observe the game through the `Snapshot` attribute, player attributes (`WORLD_EXE_Role`, `WORLD_EXE_Alive`, `WORLD_EXE_LastSpawn`) and the real RemoteEvents; pure-function tests require clones of the modules.

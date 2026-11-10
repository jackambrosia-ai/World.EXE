# src/ — WORLD.EXE script sources

These files are exact copies of the WORLD_EXE scripts in the Studio place. Paths mirror the Studio hierarchy:

| File | Studio instance | Class |
|---|---|---|
| `ReplicatedStorage/WORLD_EXE/Shared/Config.luau` | `ReplicatedStorage.WORLD_EXE.Shared.Config` | ModuleScript |
| `ServerScriptService/WORLD_EXE/Bootstrap.server.luau` | `ServerScriptService.WORLD_EXE.Bootstrap` | Script |
| `ServerScriptService/WORLD_EXE/Services/ArenaService.luau` | `ServerScriptService.WORLD_EXE.Services.ArenaService` | ModuleScript |
| `StarterPlayer/StarterPlayerScripts/WORLD_EXE/ClientBootstrap.client.luau` | `StarterPlayer.StarterPlayerScripts.WORLD_EXE.ClientBootstrap` | LocalScript |

## Sync procedure (no Rojo — owner decision)
Claude edits Studio directly through Studio MCP. After every script change, Claude writes the same source here and verifies that the Studio `Source` and the file have the same byte length and polynomial hash (`h = (h*31 + byte) mod 2147483647`). A mismatch blocks the commit.

Arena geometry is **not** in `src/`; it is Studio-owned. `tools/studio/phase1_build_arena.luau` records how the Phase 1 arena was generated.

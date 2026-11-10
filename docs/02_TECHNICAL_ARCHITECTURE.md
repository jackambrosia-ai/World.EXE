# WORLD.EXE — Technical Architecture

## 1. Architecture goals
- Server-authoritative gameplay.
- Modular services with explicit responsibilities.
- Data-driven patch definitions with separate behavior modules.
- Bounded concurrent effects and predictable cleanup.
- Shared-world modifiers resolved by one owner service.
- UI and VFX separated from gameplay authority.
- Designed for future content without speculative overengineering.

## 2. Recommended Explorer hierarchy
```text
Workspace
└── WORLD_EXE
    ├── Map
    │   ├── CentralCore
    │   ├── ResearchYard
    │   ├── Skybridge
    │   ├── Stabilizers
    │   ├── SpawnLocations
    │   └── PatchGeometry
    ├── ActivePatchInstances
    ├── Collectibles
    └── RuntimeEffects

ReplicatedStorage
└── WORLD_EXE
    ├── Remotes
    │   ├── RequestPatchSubmission
    │   ├── PatchAnnouncement
    │   ├── MatchStateChanged
    │   ├── ObjectiveChanged
    │   ├── RequestAbility
    │   ├── AbilityFeedback
    │   ├── RequestInteract
    │   └── HUDSnapshot
    └── Shared
        ├── Config
        ├── Types
        ├── PatchCatalog
        ├── AbilityCatalog
        └── Utility

ServerStorage
└── WORLD_EXE
    ├── PatchTemplates
    │   ├── Drone
    │   ├── SupplyCrate
    │   └── OtherRuntimeTemplates
    └── MapTemplates

ServerScriptService
└── WORLD_EXE
    ├── Bootstrap.server.lua
    ├── Services
    │   ├── MatchService
    │   ├── PlayerStateService
    │   ├── ArchitectService
    │   ├── PatchService
    │   ├── WorldModifierService
    │   ├── PatchInteractionService
    │   ├── ObjectiveService
    │   ├── StabilityService
    │   ├── AbilityService
    │   ├── ScoreService
    │   ├── CollectibleService
    │   ├── PersistenceService
    │   └── CleanupService
    └── Patches
        ├── ZeroG
        ├── Decay
        ├── DroneSwarm
        └── SupplyDrop

StarterPlayer
└── StarterPlayerScripts
    └── WORLD_EXE
        ├── ClientBootstrap.client.lua
        └── Controllers
            ├── HUDController
            ├── ArchitectController
            ├── PatchEffectsController
            ├── AbilityController
            ├── InputController
            └── AudioController

StarterGui
└── WORLD_EXE
    ├── MainHUD
    ├── ArchitectUI
    ├── PatchAnnouncementUI
    ├── ObjectiveUI
    ├── ResultsUI
    ├── PatchArchiveUI
    └── SettingsUI
```

This is a target hierarchy. Adapt names to project conventions, but preserve service boundaries. Do not create empty placeholder modules just to match the tree; create modules when their phase is implemented.

## 3. Service boundaries
- **Bootstrap:** initializes dependencies in explicit order and wires services. Avoid circular requires.
- **MatchService:** owns match state transitions, participant roster, timers, and end conditions.
- **PlayerStateService:** tracks alive/participating state, Architect eligibility, and match-scoped state.
- **ArchitectService:** selects eligible Architects, runs submission windows, and validates turn ownership.
- **PatchService:** validates and owns patch lifecycles, enforces concurrent cap, tracks runtime IDs, and cleans up.
- **WorldModifierService:** calculates effective shared properties (gravity, lighting, surface modifiers) from active modifier tokens. Never let two patches directly fight over the same Workspace/Lighting property.
- **PatchInteractionService:** detects allowlisted sets of active patch IDs and activates a combination once per set/session.
- **ObjectiveService:** owns stabilizer interactions, progress, interruption, completion, and reward events.
- **StabilityService:** owns match stability value and threshold notifications.
- **AbilityService:** validates ability ownership, cooldown, player state, activation limits, and ability effect.
- **ScoreService:** calculates match score and results from trusted server events.
- **CollectibleService:** spawns and validates collectible pickup interactions.
- **PersistenceService:** loads/saves durable player data with protected calls, session safety, and throttling.
- **CleanupService:** central helper for connections, instances, scheduled tasks, and tracked resources.

## 4. Match state machine
States: `LOBBY`, `COUNTDOWN`, `INITIALIZING`, `ACTIVE`, `FINAL_PHASE`, `RESULTS`, `RESET`.

Only MatchService may change match state. State transitions must be explicit and validated. A match generation/session ID should invalidate callbacks from previous matches. Each transition fires a compact state snapshot to clients.

Suggested flow:
```text
LOBBY -> COUNTDOWN -> INITIALIZING -> ACTIVE -> FINAL_PHASE -> RESULTS -> RESET -> LOBBY
```
Allow ACTIVE -> RESULTS when no valid participants remain or server needs to abort safely. Handle players joining mid-match with a clear spectator/next-match policy.

## 5. Patch lifecycle
Each active patch instance should contain:
- `RuntimeId` (unique string or numeric token).
- `PatchId` (allowlisted catalog key).
- `CreatorUserId` (optional and server assigned).
- `StartedAt` (server clock value).
- `Duration` and `ExpiresAt`.
- `State`: `WARNING`, `ACTIVE`, `ENDING`, `ENDED`.
- `Resources`: connections, instances, modifier tokens, and cleanup callbacks.
- `MatchId` or generation token.

Lifecycle:
1. Validate request on server.
2. Reserve a slot under the active patch cap.
3. Send announcement to clients.
4. Wait warning period without blocking unrelated work.
5. Re-check match ID, player eligibility, and cap.
6. Activate behavior.
7. Track duration and interaction hooks.
8. On expiry or match end, transition and cleanup idempotently.
9. Report activation/end to scoring and archive systems.

If activation fails, release the reserved slot and restore partial state.

## 6. Shared modifier composition
Use tokens/leases rather than direct patch writes. A Gravity modifier provider collects active gravity tokens, resolves one effective value from the baseline and allowed modifiers, and applies it. On token removal, recompute the value. Apply the same approach to Lighting and other global properties.

## 7. Remote communication
Clients send intent only:
- RequestPatchSubmission: `{ patchId = "ZERO_G" }` only; never arbitrary config, duration, target, or code.
- RequestAbility: `{ abilityId = "PHASE_DASH" }` only.
- RequestInteract: target Instance or server-known target identifier; server checks range, line of sight where required, alive state, objective state, and interaction cooldown.

Server-to-client events carry presentation/state updates. Do not let clients report score, damage, collectible amounts, Architect selection, or patch completion as facts.

Rate-limit client-to-server requests per player and remote. Validate payload shape, strings, finite numbers, and instance ancestry. Never trust client-provided positions for hit/damage decisions.

## 8. Player data schema (initial proposal)
```lua
{
    SchemaVersion = 1,
    Level = 1,
    XP = 0,
    DataBits = 0,
    CoreShards = 0,
    TotalMatches = 0,
    TotalWins = 0,
    OwnedCosmetics = {},
    EquippedCosmetics = {},
    PatchArchive = {},
    PatchMastery = {},
    Settings = {
        ReducedScreenShake = false,
        ReduceFlashing = false,
    },
}
```
Keep match data separate from persistent data. Validate and clamp values on load and before save. Use DataStoreService safely with protected calls, bounded retries/backoff, and shutdown handling. Do not save every small score tick; mark data dirty and save at appropriate checkpoints. Do not invent a custom datastore/session-locking framework unless requirements justify it.

## 9. Physics and effects guidance
- ZERO_G must route through WorldModifierService. Confirm character and physics-object behavior in a live server test.
- DECAY only affects tagged arena tiles, not arbitrary Workspace descendants.
- DRONE_SWARM uses a small capped NPC count, server-owned target selection, bounded update frequency, and cleanup of AI loops/connections.
- SUPPLY_DROP uses server-authored spawn locations, server-owned pickup state, distance validation, and one-time claiming.
- Avoid high-frequency full Workspace scans. Cache/tag relevant instances.

## 10. Concurrency and cleanup
- Initial major patch cap: three.
- Each patch behavior owns its resources.
- Match end invalidates all runtime patches and clears modifier tokens.
- Cleanup is idempotent and safe if partially initialized.
- Every loop/task checks cancellation/session tokens.
- A patch must not leave permanent state behind after its match unless explicitly designed as a persistent map feature.
# WORLD.EXE — UI and Art Direction

## 1. Visual identity (owner-approved 2026-11-27: modern PSX-inspired low-poly)
> This section replaces the earlier navy/cyan/violet/amber "stylized sci-fi" environment style. The HUD, accessibility and asset-policy rules in the later sections still apply.

**Direction:** believable, cohesive places built from **low-polygon geometry with carefully authored, detailed textures**, rendered **cleanly and modernly**. The environment is attractive and stable at the start of a match, and is **progressively transformed by destruction and simulation instability**, ending in simulation effects with an **original WORLD.EXE identity**.

**Requirements**
- Believable, cohesive environments with recognizable real-world architecture and proportions at character scale.
- Low-poly models; detail lives in the textures (wear, grime, seams, tiles, signage). Consistent texel density; small reusable texture sets.
- Modern, clean rendering: good lighting, shadows, ambient occlusion, a stable image. **Not** deliberately degraded PS1 graphics: no vertex wobble, affine texture warping, dithering or colour crushing.
- Strong silhouettes, believable proportions and material variety (concrete, tile, plaster, metal, glass, wood, fabric, asphalt).
- Professional third-person combat readability: characters separate from the world by value and outline; the environment avoids team colours and high-contrast noise at character height.
- No fixed brand palette. Each area takes a restrained palette from its real materials. **Saturated colour is reserved for gameplay meaning** (team colours on characters, objective markers, one reserved signal for usable traversal links).
- Destructible buildings must still look right when split into pieces (exposed interiors, broken edges).

**Match arc:** stable and attractive at match start → destruction exposes interiors and the first simulation faults appear → the simulation visibly fails across the map during the collapse warning → a final, unmistakable WORLD.EXE effect at collapse. Final effects are original; do not reproduce another game's end-of-match presentation. Effects never hide characters or objective markers.

**Style references (technique only):** [Japan Subway Train Station — low-poly PS1/PS2/N64 style](https://bitsoft.itch.io/japan-subway-station) (a recognisable real place in very few triangles, with small photo-sourced tiling textures) and [PSX Starter Kit](https://dysfunctional-games.itch.io/psx-starter-kit) (efficient props: one clear silhouette, a small texture each). Their assets are not used, bought, imported or traced. Their licence terms differ: BitSoft's pack prohibits AI training use; Dysfunctional Games' kit prohibits use in AI generation tools.

**Unchanged:** the Neto character base, the gameplay direction and the map's functional requirements (street/interior/roof layers, reserved link signalling, objective readability, measured travel-time budgets). Preserving gameplay functionality does **not** lock any existing environment layout: the current alpha map's street plan and building templates may be replaced entirely.

**Textures (recommended, pending owner decision):** original reusable textures and atlases delivered as privately uploaded Roblox image assets, in separately owner-approved batches. Runtime-generated images (EditableImage) are not the default environment pipeline without a reproducible performance and replication test. No uploads are authorized yet.

**Simulation identity (provisional experiment):** the stable map is an attractive, complete, textured world; later instability causes controlled, local material and geometry failures leading to an original collapse presentation. It must read as a deliberate simulation event, never as an accidental texture-loading failure, and must not imitate another game's wireframe dissolve. No production effects are authorized yet.

**Before an environment art pass:** the pass itself needs owner authorization. The first step is an untextured, playable grey-box of the next map; no final texturing, mesh imports or uploads are part of it.

Use text, icons, shapes, and sound—not color alone—to signal important states.

## 2. HUD hierarchy
During a match, prioritize:
1. Current match phase and remaining time.
2. Current patch warning/effect and short counterplay instruction.
3. Stability meter.
4. Objective progress and nearby stabilizer direction.
5. Individual score and data fragment count.
6. Ability cooldowns.
7. Architect submission panel when local player is selected.

Do not cover the screen center with persistent panels. Use short animated announcements, then collapse to a compact active-patch strip.

## 3. Architect interface
- Clearly state that the player is the Architect.
- Show a visible turn timer.
- Show 3–5 eligible patch cards, each with name, icon, rarity/weight if used, warning text, and a one-sentence effect.
- Support keyboard/controller/mouse/touch navigation.
- Confirm submission before server activation.
- Show a safe fallback if timer expires.
- Never display arbitrary unfiltered player text as a world announcement.

## 4. Patch announcement
Every announcement includes patch name, short warning, distinctive icon/shape, countdown, and counterplay hint. Keep critical warning text readable and not audio-only.

## 5. Objective interaction
Stabilizers need a world-space marker, interaction prompt with hold progress, interruption feedback, completion animation/stability update, and keyboard/controller/mobile support.

## 6. Menus and progression UI
Initial interface: main menu/lobby, Architect UI, match HUD, Patch Archive (basic list/details), results, and settings with reduced screen shake/flashing options where practical. Do not build a full shop before the core match is playable.

## 7. Effects, sound, and accessibility
- Brief camera shake only for important events; allow reduction/disable.
- Avoid prolonged flashing and high-frequency strobing.
- Keep particles bounded and short-lived.
- Use clear silhouettes for drones and pickups.
- Provide visual warning equivalents for audio cues.
- Use original or properly licensed audio/visual assets.
- Keep VFX client-side where they do not affect gameplay; derive event/timing from server.

## 8. Asset policy
Use Roblox primitives and original meshes for prototypes. Do not insert unreviewed free models with unknown scripts. Inspect Creator Store asset provenance and contents. Ask before uploading, purchasing, or using assets with licensing uncertainty. No copyrighted characters, distinctive map replicas, or reference-game assets.

## Reference image (historical)
The earlier visual development reference board (navy/cyan/violet palette, simulation arena zones, Architect cards, low-gravity presentation) is **superseded for environment style and palette** by the owner-approved direction in section 1 (2026-11-27). Treat it as history, not as current guidance.
## ForgeGUI production handoff

ForgeGUI is available to Claude as an additional visual asset tool (the exact exposed capabilities must be checked in the active Claude session). Use it to accelerate original visual assets such as:
- Patch card artwork and category icons.
- HUD/panel decorative plates and subtle background textures.
- Ability icons, collectible icons, and patch archive illustrations.
- Original promotional thumbnails or lobby artwork, when separately approved.

Production sequence:
1. ChatGPT/owner locks a small asset brief: purpose, style, dimensions/aspect ratio, palette, variants, and use location.
2. Claude checks ForgeGUI connection/tools and any credit cost without generating.
3. Owner approves the particular generation batch and credit budget.
4. Claude generates a small set of candidates and reviews them against the current visual direction (section 1).
5. Owner approves chosen candidates.
6. Claude imports/inserts the chosen assets through an available supported path and verifies them in the intended Studio place.
7. Claude builds the editable Roblox UI hierarchy and Luau behavior around the assets.
8. Claude checks desktop/mobile layout, readability, transparency, cropping, compression, and runtime loading.

Do not use a single flattened screenshot as the whole game HUD. The HUD, Architect cards, buttons, labels, timers, and status indicators must be editable Roblox UI elements with working input and state updates. Use generated images as art within a functional interface, not as a substitute for it.

# WORLD.EXE — UI and Art Direction

## 1. Visual identity
**Style:** polished, stylized science-fiction simulation. Clean modular geometry, luminous but restrained holographic elements, digital-grid motifs, and controlled glitch effects. Colorful and readable rather than dark, noisy, or aggressively screen-distorting.

**Palette guidance:**
- Deep navy/charcoal: panels and background contrast.
- Electric cyan: neutral system information.
- Violet: simulation and patch identity.
- Amber: warnings and impending hazards.
- Green: objectives and successful repairs.
- Red/coral: critical danger, used sparingly.

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

## Reference image
The user supplied a visual development reference board for WORLD.EXE in the project conversation. Treat it as art-direction guidance, not a literal screenshot to reproduce. Match its navy/cyan/violet palette, restrained amber warnings, simulation arena zones, stability HUD, Architect cards, controlled corruption, and low-gravity presentation.
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
4. Claude generates a small set of candidates and reviews them against the visual reference board.
5. Owner approves chosen candidates.
6. Claude imports/inserts the chosen assets through an available supported path and verifies them in the intended Studio place.
7. Claude builds the editable Roblox UI hierarchy and Luau behavior around the assets.
8. Claude checks desktop/mobile layout, readability, transparency, cropping, compression, and runtime loading.

Do not use a single flattened screenshot as the whole game HUD. The HUD, Architect cards, buttons, labels, timers, and status indicators must be editable Roblox UI elements with working input and state updates. Use generated images as art within a functional interface, not as a substitute for it.

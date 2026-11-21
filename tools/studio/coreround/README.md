# Core Round Step 1: reproducible build

This is the isolated **movement + Rebound Disc + holographic shield** prototype. It is Step 1 of the owner-approved Core Round v1.1 plan (authorized 2026-11-20). It is not production: it never touches Place1, Cyber City, Concept C r3 or any map place.

## What gets built
- **A local place** (`WorldEXE_CoreRound_<date>.rbxlx`, never published) containing **only** the `src/**/CoreRound/**` scripts (19 files in Step 1; 22 in Step 1B, which adds `Slide`, `WallRun2` and `Poses`; 23 in Step 1C, which adds `SpeedFx`; still 23 in Step 1D). The main game's Bootstrap and the PR #22 hack prototype are not in it.
- **The test yard** (`cr_20_build_yard.luau`, native parts only):
  - a two-player combat arena with team spawns;
  - a disc range with static dummies at 20/40/60 studs, a moving-dummy lane and rebound walls;
  - a shield test (a dummy with a permanent shield and a teammate dummy behind it);
  - a measured movement lane;
  - rooftop gaps of 16/26/40/55/70 at height 20;
  - optional wall-run walls;
  - Step 1D (`Step1D` folder): Power Slide Jump ledges 8 / 12 / 16 / 20 studs high at x 160..208, z -20, each with a 70-stud run-up; the builder also turns off StarterPlayer.EnableMouseLockOption (Left Shift slides).
  - Step 1B (`Step1B` folder): slide slopes at 10°/20°/30° (x = 130/158/186, top at z -200, 60 long, with stairs and run-out marks), and the wall-run v2 course at x -175 (launch block, wall A, wall B 12 studs across for chaining, a waist-high rail and a landing block).
- **Gate:** every CoreRound script is inert unless `Workspace.WORLD_EXE_CoreRound == true`. Only the yard builder sets it.
- **Rig:** the avatar rig is not changed. There is no ForceR6; hit volumes are rig-agnostic.

## Steps (Windows, Studio + Node)
1. Create an empty place file whose name contains `CoreRound` (a single `Workspace` item is enough) and open it in Studio.
2. From the repo root:
   ```bash
   node tools/studio/coreround/cr_serve.js
   ```
3. In Studio, Edit mode (command bar or MCP):
   ```lua
   local HS = game:GetService("HttpService")
   print(loadstring(HS:GetAsync("http://127.0.0.1:8791/tools/cr_10_sync_code.luau", true))())
   print(loadstring(HS:GetAsync("http://127.0.0.1:8791/tools/cr_20_build_yard.luau", true))())
   ```
   Both scripts refuse to run unless the place name contains `CoreRound`.
4. Save, then verify the saved file against `src/` (reading the file, not the live session):
   ```bash
   node tools/studio/coreround/cr_40_verify_saved.js <place.rbxlx>
   ```
   Step 1 save (2026-11-20): 19/19, no extra scripts, SHA-256 `f8cf4b0a1d5dead43cc9822b74f5e3b51d36df5eeeb1927fde847c0dd128dc9e`.
   Step 1B save (2026-11-21, `WorldEXE_CoreRound_Step1B_2026-11-21.rbxlx`): 22/22, no extra scripts, SHA-256 `48e7a0f99df666af7cb10cf1d322d676fe895758faa33fea33aa9f38dc174d30` (after the full-charge sound fix; first 1B save was `1f2718ec…17e9d`).
   Step 1C save (2026-11-21, `WorldEXE_CoreRound_Step1C_2026-11-21.rbxlx`, a copy of the 1B place plus synced code): 23/23, no extra scripts, SHA-256 `43af6b6f9845d847ec0fd6d1f35e60a033de282ffae5625ba3c0ec2a16521592` (after the charge-ring change; first 1C save `73905fdc…32156b`).
   Step 1D save (2026-11-21, `WorldEXE_CoreRound_Step1D_2026-11-21.rbxlx`, a copy of the 1C place + synced code + rebuilt yard): 23/23, SHA-256 `e260bd5705bec07cce20c5817bf4d213be14f34b52ed806466aac3c187e26a7a` (after the wall-jump control follow-up; earlier 1D saves `9fb3caff…`, `a5a9e5fa…`).
   To open a copied place file in Studio from a shell: `Start-Process <RobloxStudioBeta.exe> '"<place.rbxlx>"'`.

## Captures
`cr_grab.ps1` grabs only the CoreRound Studio window (never the desktop). `cr_burst.ps1` takes timed bursts. Both take `-Match "<window title pattern>"` (for example `-Match "*Step1B*Roblox Studio*"`) when more than one CoreRound window is open. Hide the player list before capturing (`StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)`) so the account name never appears. Captures stay local and are never committed.

## Studio-only test hooks
- Server: `ServerStorage.CoreRoundTest` (BindableFunction). Ops: `Log`, `State`, `Reset`, `DummyThrow`, `ThrowFrom`, `SetShield`, `Pose`, `Hit`.
- Client: `PlayerScripts.CoreRoundClientTest`. Ops: `Press`, `MoveLog`, `Charges`, `Speed`, `State`, `Throw`, `ThrowAt`, `Records`, `Agreement`, `Shield`, `ResetLocal`, `Reduced`. Step 1B adds `Slide`, `SlideLog`, `WallLog`, `ChargeBegin`, `ChargeRelease`, `ChargeReleaseAt`, `Charging`, `Threats`. Step 1C adds `FxStats` / `FxStatsReset` (script time of `Poses` and `SpeedFx`), `Roll` (current camera roll, degrees), `SpeedFx` (streak and glow intensity), `SlideWeight` (a player's slide weight as drawn on this client) and `WallTilt` (turns the wall-run tilt on or off).
- In a Server & Clients test, client windows are all titled "Place1 - Roblox Studio", so `cr_burst.ps1 -Match` cannot tell them apart; use numeric logs for two-client evidence.
- `DummyThrow` and `ThrowFrom` take an optional charge (0..1) as the fifth argument.
- Live tuning: set `CoreTune_<Group>_<Key>` attributes on Workspace **on the server** (they replicate). Remove them before saving.
- Real input for tests: `user_keyboard_input` with W + LeftShift (slide; Step 1D - Left Ctrl was dropped because Ctrl+A / Ctrl+D are Studio shortcuts in test windows), Space (jump / wall-jump), Q (dash). Gamepad codes (`ButtonB`, `ButtonX`, `ButtonR2`) are accepted and reach the same bindings. Scripted `Humanoid:Move` from the test VM does not move the character.
- Dummy throws are stand-in attackers, not two-client evidence.
- Network shaping for latency tests uses Studio's `settings().Network` (`InboundNetworkMinDelayMs` / `OutboundNetworkMinDelayMs`). It persists in Studio settings, so set it back to 0 afterwards.

## Step 1E (animation)

- `tools/animation/` - Blender 5.3 authoring / bake / QA / preview scripts (see `docs/prototypes/CORE_ROUND_STEP1E.md`). They write `src/.../CoreRound/AnimData.luau` (generated: edit the clips, not the module).
- `cr_60_keyframes.luau` (Edit mode) - saves every clip as a LOCAL KeyframeSequence in `ServerStorage.RBX_ANIMSAVES.CoreRound_AnimRig` (no upload). Its builder is also used in a Play client for the temp-id test.
- `cr_70_anim_capture.luau` - Play-client helpers for the animation review (aim lock off, teleport, controller log, follow camera). Paste into the client datamodel; the client cannot fetch it over HTTP.
- `cr_sheet.ps1` - tiles capture frames into one contact sheet. Client test ops added: `AnimDebug`, `AimLock`.

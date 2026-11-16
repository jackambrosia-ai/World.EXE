# Wrist-hacking prototype: reproducible build

This is an **isolated prototype** for the owner-approved milestone of 2026-11-16. It is not production. It never touches Place1, Cyber City or any map place.

## What gets built
- **A local place** (`WorldEXE_HackPrototype_<date>.rbxlx`) with:
  - **Arena:** a compact test arena, launch area, 4 height lanes, a gap course (16/24/32/40), 3 R6 dummies (stationary, patrolling, on a ledge), landing pieces, a **TestStation** (13 option pads + settings board), a 60×60 **PvP area** with 5 cover blocks, and a boss arena with a native-part **Conductor placeholder** and 3 hack-mode consoles.
  - **Containers:** the WORLD_EXE containers so the unchanged match bootstrap runs. It reports `Degraded`, because none of the match markers exist by design.
- **The full `src/` tree:** synced as scripts. The wrist-hacking code is inert unless `Workspace.WORLD_EXE_HackPrototype == true`, which only this place sets.

## Steps (Windows, Studio + Node)
1. Create an empty place file, for example by copying the minimal XML used on 2026-11-16 (a single `Workspace` item). Open it in its own Studio process.
2. From the repo root, start the loopback file server:
   ```bash
   node tools/studio/hackproto/hp_serve.js
   ```
3. In Studio (Edit mode, command bar or MCP), run:
   ```lua
   local HS = game:GetService("HttpService")
   print(loadstring(HS:GetAsync("http://127.0.0.1:8790/tools/hp_10_sync_code.luau", true))())
   print(loadstring(HS:GetAsync("http://127.0.0.1:8790/tools/hp_20_build_place.luau", true))())
   ```
   Both scripts refuse to run unless the place name contains `HackPrototype`.
4. Save, then verify the saved file against `src/` (from the file, not the session):
   ```bash
   node tools/studio/hackproto/hp_40_verify_saved.js <place.rbxlx>
   ```
   The latest build (milestone 2, 2026-11-16) reported 59/59; place SHA-256 973D6F2C….

## Playing it
- Press Play (solo). You spawn at the launch area.
- **Open the wrist terminal:** **H** (gamepad **L1**, or tap the WRIST pill).
- **Quick hacks:**
  1. Press **1-4**, or click a chip.
  2. Press the same key again, press **Enter**, or click **EXECUTE**.
  3. **X** cycles the target.
- **Typed hacks:** **T** focuses the command line. Examples: `fling self`, `fling`, `fling dummy-a`, `freeze`, `freeze boss`, `shield`.
- **Challenges:** use the **arrow keys** or **D-pad**, or tap the on-screen pad on touch. WASD keeps moving. **Backspace** or **B** cancels.
- **Boss challenge type:** walk to a console at the boss arena entrance and use its prompt.
- **Incoming hack (you are targeted):** a banner, a pointer toward the attacker, and a draining window. Defend with **C** / **R1** / the on-screen SHIELD button, by breaking line of sight behind cover, or by leaving the ring.
- **TestStation:** step on a pad and use its prompt to pick boots (Starter / Vault / Vector), the reaction window (0.7 / 1.0 / 1.4 s), perfect deflect on/off, the dummy reaction (none / shield / perfect / dodge), or reset the boss.

## Live tuning (Workspace attributes, numbers)
Format: `HackTune_<Group>_<Key>`, overriding `HackCatalog.Tuning`. Examples:
- **Fling Self:** `HackTune_FlingSelf_Up`, `HackTune_FlingSelf_Forward`, `HackTune_FlingSelf_SteerSpeed`
- **Fling Target:** `HackTune_FlingTarget_Up`, `HackTune_FlingTarget_Forward`, `HackTune_FlingTarget_RagdollSeconds`, `HackTune_FlingTarget_Range`
- **Freeze:** `HackTune_Freeze_Seconds`, `HackTune_Freeze_BossSeconds`, `HackTune_Freeze_Range`
- **Shield:** `HackTune_Shield_Seconds`
- **Incoming:** `HackTune_Incoming_ReactionWindow`, `HackTune_Incoming_PerfectWindow` (0 = off), `HackTune_Incoming_DodgeRadius`, `HackTune_Incoming_LatencyGrace`
- **Dummy reaction:** Workspace string attribute `HackProto_DummyReaction` = none / shield / perfect / dodge
- **Assist:** `HackTune_Challenge_TimeScale` (1-8) is an accessibility/assist time scale. It gives longer limits and windows and a slower boss.

## Studio-only test controls
- **Test hooks:** `ServerStorage.HackProtoTest` (BindableFunction, Studio only) offers `Session`, `Events`, `BossLog`, `Effects`, `Perf`, `IncomingStats`, `ClearCooldowns` and `SimulateIncoming(player, hackId, npcModel)`. The last one sends a dummy through the real incoming stage as a stand-in attacker; label its results as stand-in, not two-client.
- **Client test kit:** `hp_30_client_testkit.luau` (paste into the Client data model). Every input carries an increasing `n` (replay protection).
- **Captures:** `hp_grab.ps1` (one window-only grab) and `hp_burst.ps1` (timed burst for sub-second states). Disable the PlayerList core GUI before capturing.
- **Allow a solo match:** set `ServerScriptService.WORLD_EXE.StudioMinPlayers` to 1. This tests the Architect-UI arbitration. The builder sets 99, so no match starts on its own.

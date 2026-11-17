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
- **Challenges (Rev 15):** use the **number keys 1–4** (Signal Lock also uses **5**), the keypad, the **D-pad** (Left/Up/Right/Down = 1/2/3/4, **Y** = 5), or tap the on-screen pad on touch. While a challenge is active, the number keys go to it rather than to the quick chips. WASD keeps moving. **Backspace** or **B** cancels.
- **Movement (Rev 15):**
  - Run speed is 28.
  - **Q** / **X** (gamepad) does a grounded dash (~25 studs). Its cooldown is a quarter of the super-speed cooldown (2.75 s), shown as a thin cyan bar under the gauge.
  - After the Q-Q activation, super-speed can be used **2 more times**, one Q each (during a burst or within 2.5 s after it). The 11 s cooldown starts when the chain ends.
- **Wall-running:** while moving, press **Space** with a wall at your **side** (left or right, not in front) to run on it (up to 4 s, around corners). **Space** again wall-jumps off; press Space at the next wall (side-on) to catch it. Test lane: `hp_21_wallrun_lane.luau` (two walls plus a block, west of the launch area).
  - A *separate* second **Q** between 0.2 and 0.8 s after the dash starts 1 s of steerable super-speed (11 s cooldown). Pressing earlier voids the window, so spamming Q never triggers it.
  - A small gauge under the screen centre shows the window, the drain and the cooldown.
- **FLING aiming with shift-lock / first person:** hold **W / A / D / S** (up / left / right / behind) and click. Otherwise, slide the mouse; with no input the throw goes up.
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
- **Movement (Rev 15):** `HackTune_Move_RunSpeed`, `_DashSpeed`, `_DashSeconds`, `_DashCooldownRatio` (× SuperCooldown), `_SuperMin`, `_SuperMax`, `_SuperSeconds`, `_SuperSpeed`, `_SuperTurnRate`, `_SuperCooldown`, `_FovRun`, `_FovSuper`
- **Wall-run (Rev 15g):** `HackTune_WallRun_MinSpeed`, `_Speed`, `_Seconds`, `_StartUp`, `_SinkSeconds`, `_Gravity`, `_Reach`, `_Stick`, `_JumpOut`, `_JumpUp`, `_JumpCarrySeconds`, `_LeanDegrees`, `_ReattachDelay`
- **Super chain (Rev 15g):** `HackTune_Move_SuperFollowUps`, `_SuperFollowWindow`, `_SuperAccelSeconds`, `_SuperEaseOutSeconds`, `_SuperSteerSmoothing`
- **FLING post-throw (Rev 15):** `HackTune_FlingTarget_PostThrowSeconds` (default 3.0; tested 2.5 / 3.0 / 3.5), `_PostThrowCap`, `_SettleSpeed`

## Studio-only test controls
- **Test hooks:** `ServerStorage.HackProtoTest` (BindableFunction, Studio only) offers `Session`, `Events`, `BossLog`, `Effects`, `Perf`, `IncomingStats`, `ClearCooldowns`, `MoveLog(player)` (Q decisions with server times) and `SimulateIncoming(player, hackId, npcModel)`. The Workspace attribute `HackTest_BossPassive = true` (Studio only) keeps the boss idle so its long challenge types can be tested without attack interruptions. The last one sends a dummy through the real incoming stage as a stand-in attacker; label its results as stand-in, not two-client.
- **Client test kit:** `hp_30_client_testkit.luau` (paste into the Client data model). Every input carries an increasing `n` (replay protection).
- **Captures:** `hp_grab.ps1` (one window-only grab) and `hp_burst.ps1` (timed burst for sub-second states). Disable the PlayerList core GUI before capturing.
- **Allow a solo match:** set `ServerScriptService.WORLD_EXE.StudioMinPlayers` to 1. This tests the Architect-UI arbitration. The builder sets 99, so no match starts on its own.

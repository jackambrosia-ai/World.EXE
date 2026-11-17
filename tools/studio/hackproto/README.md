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
   The latest save (Rev 15q, 2026-11-17) reported 66/66; place SHA-256 1DD1C836….

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
  - **Q** / **X** (gamepad) does a grounded dash (~28 studs). The dash has a 6 s cooldown, shown as a thin cyan bar under the gauge.
  - **Skill check (Rev 15j; eased in Rev 15m; Rev 15n look = owner reference UI-01):** each dash shows a thin outer square closing onto a fixed inner square around your character (0.6 s, drawn on the server's clock), warming gold → orange → red. Press **Q** while the outer square is on the inner square's border (the 0.11 s zone, at a random time) to fill one of the **two diamond containers**: the inner square flips pink. A miss greys out. One attempt per dash. `HackTune_Move_CheckStyle = 0` shows the older bar.
  - **Super-speed:** press **Q** while the dash is cooling, after the skill check, to spend a filled diamond on 1 s of steerable super-speed (coloured R6 silhouette afterimages). With no diamond you hear a soft tick.
  - **Chaining (Rev 15l):** press **Q** again during a super-speed to start the next one at once, if a diamond is left (at least 0.25 s after the last start).
- **Wall-running:** while moving, press **Space** with a wall at your **side** (left or right, not in front), or arrive at the wall already holding Space (also straight out of a dash or a FLING SELF flight). You run up and along it (up to 4 s). It stops at corners and wall ends. While attached: keep moving forward to cruise, hold **back** to brake, push **away** from the wall to peel off. **Space** again wall-jumps off, also within 0.3 s after the run ends at a wall end; press Space at the next wall (side-on) to catch it. `HackTune_WallRun_Flow = 0` restores the Rev 15l feel for comparison. Test lane: `hp_21_wallrun_lane.luau` (two walls plus a block, west of the launch area).
- **FLING SELF:** launches you with loose limbs; steer with WASD; hold **Space** while falling to glide. The blue aura stays until you land.
- **FLING aiming (Rev 15o/15p):** the target is held 3 s with all four throw arrows shown (yellow; the selected one red). While holding it, hold **W / A / D / S** (up / left / right / behind) and click, in any camera mode. With no key held, the cursor decides (its screen zone; a slide when the cursor is locked); with no input the throw goes up.
- **Boss challenge type:** walk to a console at the boss arena entrance and use its prompt.
- **Incoming hack (you are targeted):** a banner, a pointer toward the attacker, and a draining window. Defend with **C** / **R1** / the on-screen SHIELD button, or by breaking line of sight behind cover (the ring dodge was removed in Rev 8).
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
- **Movement (Rev 15):** `HackTune_Move_RunSpeed`, `_DashSpeed`, `_DashSeconds`, `_SuperSeconds`, `_SuperSpeed`, `_SuperTurnRate`, `_FovRun`, `_FovSuper`
- **Wall-run (Rev 15g–15m):** `HackTune_WallRun_MinSpeed`, `_Speed`, `_Seconds`, `_ClimbSpeed`, `_AirClimbScale`, `_ClimbSeconds`, `_MaxSink`, `_Gravity`, `_Reach`, `_Stick`, `_JumpOut`, `_JumpUp`, `_JumpCarrySeconds`, `_EdgeJumpGrace`, `_LeanDegrees`, `_ReattachDelay`; Rev 15m Flow: `_Flow` (1/0), `_EntryBlendSeconds`, `_MaxEntrySpeed`, `_SpeedSettle`, `_BackBrake`, `_MinCruise`, `_PeelDot`, `_PeelSeconds`, `_PeelOut`, `_ExitCarrySeconds`, `_ForwardLeanDegrees`, `_AnimRate`
- **FLING SELF aura (Rev 15m):** `HackTune_FlingSelf_AuraMaxSeconds` (safety cap, default 10)
- **Skill check and super-speed (Rev 15j):** `HackTune_Move_DashCooldown`, `_CheckDelay`, `_CheckSweepSeconds`, `_CheckZoneSeconds`, `_CheckZoneEarliest`, `_CheckLatency`, `_CheckStyle` (1 squares / 0 bar), `_SuperChargesMax`, `_SuperAccelSeconds`, `_SuperEaseOutSeconds`, `_SuperSteerSmoothing`, `_SuperChainMinGap`
- **FLING post-throw (Rev 15):** `HackTune_FlingTarget_PostThrowSeconds` (default 3.0; tested 2.5 / 3.0 / 3.5), `_PostThrowCap`, `_SettleSpeed`; wall slam (Rev 15q): `_SlamDownSeconds` (4.5), `_SlamMinSpeed` (20); hold: `_HoldSeconds` (3)

## Studio-only test controls
- **Test hooks:** `ServerStorage.HackProtoTest` (BindableFunction, Studio only) offers `Session`, `Events`, `BossLog`, `Effects`, `Perf`, `IncomingStats`, `ClearCooldowns`, `MoveLog(player)` (Q decisions with server times) and `SimulateIncoming(player, hackId, npcModel)`. The Workspace attribute `HackTest_BossPassive = true` (Studio only) keeps the boss idle so its long challenge types can be tested without attack interruptions. The last one sends a dummy through the real incoming stage as a stand-in attacker; label its results as stand-in, not two-client.
- **Client test kit:** `hp_30_client_testkit.luau` (paste into the Client data model). Every input carries an increasing `n` (replay protection).
- **Captures:** `hp_grab.ps1` (one window-only grab) and `hp_burst.ps1` (timed burst for sub-second states). Disable the PlayerList core GUI before capturing.
- **Allow a solo match:** set `ServerScriptService.WORLD_EXE.StudioMinPlayers` to 1. This tests the Architect-UI arbitration. The builder sets 99, so no match starts on its own.

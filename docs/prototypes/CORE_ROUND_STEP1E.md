# Core Round Step 1E: character animation production

Owner authorization: 2026-11-21. Step 1D gameplay is the baseline and is **unchanged**. No tuning values moved: run, slide, Power Slide Jump, wall-run, wall-jump, dash, disc and shield are all the same.

This step added no uploads, publishing, paid packs, Place1 or map changes, new abilities or vault edits. Status: **stopped for owner and ChatGPT review.**

## What changed

**New clips.** Seventeen original clips were authored in Blender 5.3. Three wall clips are mirrored at export, giving 20 clips in total. The procedural Step 1B–1D pose layers in `Poses.luau` are replaced by a clip-sampling controller.

**Playback.** The controller samples the clip data itself and writes each joint's `Transform` once per frame, in `PreSimulation`, after the Animator. Roblox's default animations stay underneath for idle, walk, climb and swim.
- No asset IDs or uploads.
- No root motion: only joints move, so gameplay never waits on an animation.

**Other players.** Other characters are driven by the existing replicated attributes (`CR_MoveState`, `CR_ChargeStart`, `CR_ShieldUp`, `CR_StunUntil`). No new remotes.

## Clip inventory and coverage

| # | Required area | Clip(s) | Frames @30 | Notes |
|---|---|---|---|---|
| 1 | Fast run loop | `run` | 14 (loop) | Authored for 36 studs/s; playback rate = speed / 36 (0.45–1.8). Lower body turns toward the move direction (aim lock); backpedal plays in reverse. |
| 2 | Run-to-slide entry | `slide_in` | 7 | Timed to `Slide.PoseBlendSeconds` 0.22. Torso blend = `CoreGeom.SlideWeight`. |
| 3 | Slide loop | `slide_loop` | 30 (loop) | Torso = `CoreGeom.SlidePoseR15` exactly. Life motion on the limbs only (off in Reduced FX). |
| 4 | Slide exit | `slide_out` | 8 | Rear foot plants, lead leg pulls under. |
| 5 | Power Slide Jump push-off | `psj_push` | 5 | Starts the same frame as the launch. |
| 6 | Rising pose | `psj_rise` | 10 | Tuck; held while vy > 12. |
| 7 | Apex pose | `psj_apex` | 12 | Opens up, glances down, blends to fall. |
| 8 | Fall + landing recovery | `fall`, `land` | 24 (loop), 10 | Landing: feet planted every frame. Full weight standing, 0.4 while running. |
| 9 | Wall-run loop, both sides | `wallrun_r`, `wallrun_l` (mirror) | 14 (loop) | Wall side from the wall normal (local) or a side raycast (others). |
| 10 | Wall-jump push-off | `walljump_r` / `_l` | 6 | Plus a roll toward the measured launch direction (camera-aimed). |
| 11 | Airborne recovery after a wall jump | `walljump_recover_r` / `_l` | 12 | Ends in the fall pose. |
| 12 | Disc charge + release (upper body) | `disc_charge`, `disc_release` | 8, 10 | Right arm plus an additive chest twist. Tremble grows with charge (off in Reduced FX). |
| 13 | Shield raise / hold / lower (upper body) | `shield_raise`, `shield_hold`, `shield_lower` | 4, 30 (loop), 5 | Left forearm across the chest; the panel sits 3 studs ahead. |

## Pipeline (all local, reproducible)

Run from `tools/animation/` in the repo, using Blender 5.3 and its bundled Python. No installs.

| Script | Role |
|---|---|
| `cr_anim_rig.py` | Canonical R15 authoring rig, measured from the live avatar. Maths, forward kinematics, box overlap test. |
| `cr_anim_clips.py` | Clip authoring: key poses, leg IK from foot-target trajectories, head anchoring, mirroring. |
| `cr_anim_build.py` | Builds the editable `.blend`: armature, proxy body boxes, floor and wall, one action per clip. Bezier keys; cyclic F-curves for loops. |
| `cr_anim_export.py` | Bakes each action at 30 fps, checks the bake against the rig maths, mirrors wall clips, runs QA on the **baked** data, and writes the outputs listed below. |
| `cr_anim_qa.py` | QA: floor penetration, foot slip, wall penetration, limb overlap, joint limits (swing–twist), head vs server head, loop seam, held-disc clearance. |
| `cr_anim_render.py` | Workbench contact sheets (local previews). |

The export step writes:
- `AnimData.luau`, the runtime data module;
- `export/CoreRoundAnim_Step1E.json`, a full-precision reference copy;
- `export/qa_report.json`.

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" -b --factory-startup --python-exit-code 1 -P tools/animation/cr_anim_build.py -- C:\WORLD.EXE-Art\CoreRound\animation
```
```powershell
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" -b C:\WORLD.EXE-Art\CoreRound\animation\WorldEXE_CoreRound_Anim_Step1E.blend --python-exit-code 1 -P tools/animation/cr_anim_export.py
```

### Rig and coordinate convention (export format)

- **Authoring rig.** The live avatar was measured in Studio: R15 with AnimationConstraint joints, axis-aligned attachments and HipHeight 2.57. The test avatars give the same posed slide head (0.19).
- **Units and axes.** 1 Blender unit = 1 stud. Roblox (x, y, z) maps to Blender (x, −z, y).
- **Bones.** Every bone points straight up with roll 0, so bone-local axes are the Roblox joint axes. A pose bone's `rotation_quaternion` *is* the joint `Transform` rotation, and the Root bone's location is the Root translation. The build script asserts this.
- **Bake check.** The bake was checked against the rig maths to 1e-6 studs.
- **Data module.** `AnimData.luau` holds per clip and per joint quaternions (w, x, y, z) at 30 fps, plus the Root translation, rounded to 4 decimals (94.8 KB). Loops store frames 0..N−1; one-shots store 0..N. The runtime builds `CFrame.new(tx, ty, tz, qx, qy, qz, qw)`.
- **Sign conventions** (re-measured in Studio). They follow standard right-handed maths:
  - right-limb +Z goes out to the side;
  - Root +X leans back;
  - knee −X bends.
  - The older Step 1C comment saying "−Z swings the right arm out" was wrong.

### Local Roblox animation data (no upload)

- **Animation Editor saves.** `tools/studio/coreround/cr_60_keyframes.luau` (Edit mode) saves all 20 clips as local `KeyframeSequence`s in `ServerStorage.RBX_ANIMSAVES.CoreRound_AnimRig`. These are next to a stock R15 rig, `ServerStorage.CoreRound_AnimRig`, made with `CreateHumanoidModelFromDescription` and no assets.
- **Temp-ID test.** In a Play client, all 20 clips were registered with `KeyframeSequenceProvider:RegisterKeyframeSequence`. Each loaded on the Animator and played at the correct length: **20/20**.
- **Temp-ID limits.** Temp IDs are Studio-only, are local to that client and do not replicate. They are not used at runtime.
- **Not tested.** Opening these saves in the Animation Editor UI was not tested.

## Hit-volume consistency (server unchanged)

- **Slide-weight coupling.** The slide layer's weight is `CoreGeom.SlideWeight`, the server's hit-volume curve, so drawn and judged bodies lower and rise together. During slide exit and push-off, the torso is `slerp(clip torso, slide torso, SlideWeight)`.
- **`CoreGeom.SlidePoseR15.Root` z: 0.2 → −1.11.** With 0.2, the drawn slide head sat **1.31 studs behind** the root. The server's slide head sphere is centred above the root (`root + (0, slideHead, 0)`).
  - Only z changed, so `PosedHeadOffset` (a height; 0.194) and every server hit volume are unchanged.
  - The visible effect: the pelvis is drawn forward of the root during a slide.
- **Measured in game** (client head relative to the root):

  | Situation | Drawn head vs server sample |
  |---|---|
  | Slide | (0.02, 0.19, 0.00) vs (0, 0.19, 0) |
  | Run | horizontal 0.00; drops ≤ 0.25 with the stride bob |
  | Wall-run | 0.38–0.43 sideways, away from the wall (8° lean; server head radius 0.85 + 0.15) |
  | Landing while running | ≤ 0.5 forward for 0.3 s |

## Bugs found and fixed (pre-existing in Step 1C/1D)

- **Stale joint references.** The avatar's head, with its `Neck` joint, is replaced after spawn while the appearance loads. The Step 1C/1D `Poses` cached the destroyed `Neck`, so the head never took the slide pose: the drawn slide head was 0.29 studs off the server's.
  - The joint map is now rebuilt when joints are added or removed.
  - Each joint is matched to the part it drives; a live AnimationConstraint wins over a Motor6D.
- **Wall-arm comment sign** was wrong (see sign conventions above).

## QA results (baked data, `qa_report.json`)

All 20 clips **PASS**. Bake vs rig error: 1e-6 studs.

| Check | Result |
|---|---|
| Floor | run 0.01; slide_loop 0.004; slide_in 0; land 0.08 (penetration, studs; < 0.10 passes) |
| Run foot slip (planted window) | 0.0 studs/s against 36 studs/s |
| Wall-run wall-foot slip | 0.06 studs/s |
| Joint limits | 0 violations in every clip |
| Loop seams | 0.0° in every loop |
| Limb–torso overlap (> 0.12 fails) | 0 failures. Wall-run has 11 sub-threshold contacts (upper arm near the head) |
| Held disc while charging | clears the body by 1.93 studs |
| Wall penetration, body/legs | 0.05 |
| Wall penetration, wall-side arm | **0.30** |

**Wall-arm limitation.** The root rides 0.85–0.88 from the wall (measured in game), and this avatar's shoulder is 0.85 wide. The arm pose was found by search and is the closest it gets.

## In-game tests (Step 1E place, solo Studio Play)

- **Run → Slide → PSJ → Landing.** Clips in order: `run` → slide (weight 0→1 in 0.2 s) → `psj_push` on the launch frame → `psj_rise` → `psj_apex` → `land` → `run`.
- **Run → Slide → PSJ → Wall-run → Wall-jump**, in one take: … → `psj_push` → `wallrun_r` → `walljump_r` → `walljump_recover_r` → `wallrun_l` (chained to wall B) → `land`.
  - First found that the PSJ sequence pre-empted the wall-jump clip. Fixed: a wall-run now ends the PSJ sequence.
- **Disc while running.** `disc_charge` fades in within 0.06 s; `disc_release` follows on release and fades out.
- **Shield while running.** Raise → hold → lower; the run cycle slows with the 0.7× speed.
- **Interruption.** Shield raised mid-slide: the slide blend drops and a charge pose is cancelled. The shield raises at once.
- **Stun** (real hits through the server test hook). Every layer, including the shield, cleared within one 0.15 s sample. The run resumed after the stun with no stuck tracks.
- **Death / respawn.** Writing stops on death. The new character animates, and its slide head is exact (joint rescan).
- **Reduced FX.** No errors; slide life-motion and charge tremble are off.
- **Performance.** The controller costs **0.054 ms per frame** on one character (Step 1C hook `FxStats`).
- **Rig compatibility.**
  - The measured avatar is the canonical rig.
  - Stock R15 rig (`CreateHumanoidModelFromDescription`; also AnimationConstraint, 15 joints, `PosedHeadOffset` 0.065): every joint resolves. The run stays within 0.09 of the floor, but **slide sinks 0.29 and land 0.23** because of the different proportions (no per-rig foot IK yet).
  - R6 keeps the old single-joint slide tilt only.

**Not tested — labelled:**
- **two-client** (needs the owner to start Server & Clients);
- mobile and touch;
- physical controllers;
- high latency;
- published playback (not possible without uploads).

## Evidence (local only, not committed)

**Evidence folder** `C:\WORLD.EXE-Art\CoreRound\evidence\captures_1e\`:
- `stage_poses/`, `stage_keyposes_a.jpg`, `stage_keyposes_b.jpg`: the real avatar posed from the exported data; side, three-quarter and back views; 24 labelled shots.
- `after_side_psj*`: gameplay bursts from the player camera.
- `before_after_side.jpg`: Step 1D gameplay frames from `captures_1d` against Step 1E stage shots. The Step 1D frames are small and far away — a weak "before".

**Animation folder** `C:\WORLD.EXE-Art\CoreRound\animation\`:
- `previews/`: Blender contact sheets.
- `WorldEXE_CoreRound_Anim_Step1E.blend`: SHA-256 `7ac29ee47107bca6…`.
- `export/CoreRoundAnim_Step1E.json`: SHA-256 `2a8104c7ba1093f3…`.

**Places:**

| Place | SHA-256 | Notes |
|---|---|---|
| `place/WorldEXE_CoreRound_Step1E_2026-11-21.rbxlx` | `f7a9bd86c923ab2f65c1c4cccf03986610693e3ef66cc3bc81cd7de0f543e2fa` | Parity 24/24 against the repo. Backup `backup_step1e_2026-11-21` (identical hash). |
| Step 1D place | `e260bd57…` | Unchanged. |

Protected-file check: 9/9 OK.

## Provenance and licence

- **References** (principles only — timing, silhouette, weight shift, blending; no keyframes or assets copied):
  - Sojourn: slide and slide-jump;
  - Titanfall 2: wall-run;
  - Warframe: blending.
- **Authorship.** Every pose and curve is authored from scratch in `cr_anim_clips.py` for this rig. No third-party animation data, packs or mocap.
- **Tooling.** Blender 5.3 (GPL tool; outputs are ours) and Python only.

## Remaining requirements (uploads not authorized; not done)

1. **Shipping on Roblox's Animator needs uploaded assets.** Animator-based playback (replicated tracks, published games) needs each `KeyframeSequence` uploaded as an Animation asset owned by the experience owner.
   - The current controller does not need this: it plays the data itself on every client.
2. **Choose the playback path.** Uploading would let the Animator replace the custom sampler. That needs a decision on priorities and blending with the custom layers.
3. **Other rig proportions (no upload needed).** Per-rig foot IK, or separate clip sets, for avatars whose proportions differ from the measured one.

## Proposed vault lessons (not written to the vault)

- **L-0113 (Draft):** AnimationConstraint rigs can replace joint objects after spawn (dynamic heads). Never cache joint references for a character's life; rebuild on `DescendantAdded`/`Removing` and match by driven part.
- **L-0114 (Draft):** Author Roblox animation in Blender with up-pointing, roll-0 bones under a (x, −z, y) mapping. Bone-local axes then equal joint axes, so export needs no conversion (verified to 1e-6).
- **L-0115 (Draft):** For "no foot sliding" at 36 studs/s, stance must be about 0.075 s (sprint-like). Author foot-contact trajectories, solve IK and key every frame; check planted windows against the move speed.
- **L-0116 (Draft):** Keep the drawn head on the server's hit geometry. Anchor the torso lean by translating the Root, and drive the slide torso blend with the same curve the server uses.
- **L-0117 (Draft):** With aim lock the body faces the camera. A forward run clip needs lower-body steering (Root yaw toward the move direction, chest counter-turn) and a reversed cycle for backpedal.
- **L-0118 (Draft):** `KeyframeSequenceProvider:RegisterKeyframeSequence` gives Studio-only, client-local temp IDs. They are useful to verify clip data on the Animator, but are not a shipping path.

## Follow-up: hand spin while charging (owner request, 2026-11-21)

- While the left click is held to charge the disc, the right hand spins rapidly about the forearm (wrist twist), from 3 to 8 turns per second as the charge builds. Reduced FX halves the speed.
- The spin stops at once on release or cancel, when the throw clip takes over. Other players see it too, from the replicated charge start.
- **Measured in Studio Play:** 4.6 turns/s early in the charge and 7.9 turns/s near full charge; the wrist is back to 0 after release.
- **Side effect:** the held disc is attached to the hand, so it now also circles the forearm.
- **Place:** SHA-256 `2c5e1f855cf2962f3d07b5b9aaa562daf3d6195fd3b20f9694834959af2d45d7`, parity 24/24, backup refreshed. Step 1D place unchanged; protected files 9/9.

## Follow-up: directional dash animation (owner request, 2026-11-21)

**Clips.** The regular dash (0.25 s at 104 studs/s) now has its own animation, chosen by the dash direction relative to the body:

| Direction | Clip | Pose |
|---|---|---|
| Front | `dash_f` | Low forward lunge: torso leaned 24°, rear leg driven back, arms swept back. |
| Back | `dash_b` | Back hop: hips drop, front foot pushes, rear leg reaches back, arms forward for balance. |
| Side | `dash_r`, `dash_l` (mirror) | Body rolls about 21° into the dash, lead leg steps out, trail leg pushes, trail arm swings across. |

- All three are 10 frames, keyed every frame; foot IK keeps the feet out of the floor. QA passes for all four clips. The data set is now **24 clips**.
- **Blending.** Diagonals blend between the two nearest clips by heading. The layer fades in over 0.04 s and out over the last 0.1 s (0.35 s total).
- **Gameplay unchanged.** No root motion; the movement code still owns the dash. The Super Dash keeps the run / fall animation, and starting it ends the dash clip.
- **Triggers.**
  - Local: `Movement` passes the burst kind and heading to the existing `onDash` callback (signature change only, no gameplay change).
  - Other players: a jump in horizontal speed past 85 studs/s starts the clip in their move direction. Only the dash reaches ~104 (Super Dash 70, slide ≤ 58, wall-run ≤ 60). No new remotes.
- **Measured in Studio Play** (aim lock on, so the body faces the camera):

  | Input | Clip chosen | Root while dashing |
  |---|---|---|
  | W+Q | front | pitch −24° |
  | S+Q | back | pitch +12° |
  | D+Q | right | roll ≈ −30° |
  | A+Q | left | roll ≈ +30° |

  All at 104 studs/s.
- **Evidence.** Real-avatar stills in `evidence/captures_1e/stage_dash*`.
- **Tooling fix.** `cr_60_keyframes.luau` now requires a fresh copy of `AnimData`, because Edit-mode `require` caches the module. It saves all 24 clips locally.
- **Place.** SHA-256 `fed520d8a4f83ce5ffcd7ebe25487c9d369dae8e9d283aeb157bb829c10130a0`, parity 24/24, backup refreshed. Step 1D place unchanged; protected files 9/9.

## Bug fix: dash into obstacles (owner report, 2026-11-21)

**Bug (pre-existing since Step 1).** The dash drove the root with an unlimited-force `LinearVelocity` for the full 0.25 s. Into a wall or the 4.5-stud rail, the physics turned that force into a launch. Measured:
- a 24-stud wall: bounced back, flipped, thrown up at 200 studs/s and about 50 studs away, tumbling in `FallingDown` for over a second (another try slid along the wall at 60 studs/s while fallen down);
- the rail: launched about 50 studs up at up to 134 studs/s and ended upside down.

**Fix (`Movement.luau`).**
- **Obstacle guard.** Before physics each frame, a root-width box (0.7 above the feet up to the root top) is cast ahead along the burst.
  - On a wall-like hit (|normal.Y| < 0.7), the burst keeps only its speed along the surface, so it slides along walls.
  - If under 40% would remain (head-on), the burst ends without slip and the speed into the surface is removed.
  - Steps under 0.7 studs are still left to the Humanoid.
- **Finite push.** The push is `AssemblyMass × 20000`, which reaches dash speed in about 5 ms, instead of `math.huge`.
- **No tripping.** `FallingDown` is disabled while a burst drives the root and re-enabled on every exit path.
- **Super Dash** uses the same guard.

**Retest (Studio Play).** Rise, vertical speed and tilt were also checked: 0 rise and no flip in every case.

| Case | Result |
|---|---|
| Open ground | 27.7 studs (configured 26; the timer ends on a frame) |
| Head-on, 24-stud wall | Stops at the wall after 5.1 studs |
| Head-on, rail | Stops after 5.1 studs |
| 35° glancing hit on a wall | Slides along it, 23 studs |

The character stays `Running` throughout. No tuning values changed.

## Bug fix: disc stuck on a shield after a hit from behind (owner report, 2026-11-21)

**Bug (pre-existing since Step 1B).** The owner's Studio capture (`…Step1E…2026-11-21 07-58-13.mp4`, SHA-256 `9133a003…`; frames reviewed and deleted) showed a block flash pulsing at the panel while the HUD said IN FLIGHT.
- **Cause.** A disc thrown from behind or a behind-diagonal hits the defender's back and passes the panel's back face (panels block one side). On the way home it meets the FRONT face. A return-pass block only suppressed body hits for 0.3 s and did not change the homing path, so the disc re-blocked every 1/90 s step until the 2.5 s flight cap snapped it home.
- **Before the fix** (real player throws):

  | Throw from | Result |
  |---|---|
  | Behind | ~235 blocks |
  | Behind-diagonal (135°) | 236 blocks |
  | Front, 45°, side | Normal |

  Each block costs the defender 15 shield energy.

**Fix (`CoreDisc.luau`).** A shield blocks a given disc at most once per throw (`blockedBy` per disc); afterwards that panel is ignored for the rest of the flight. Nothing else changes: front blocks, block cost, return behaviour and one-sided panels are the same.

**Retest (player throws at `D-SHIELD`, after the fix):**

| Throw from | Result |
|---|---|
| Front | 1 block, home 0.15 s |
| 45° | 1 block, home 0.13 s |
| Side | Body hit, home 0.65 s |
| Behind-diagonal | Body hit + 1 block, home 0.65 s |
| Behind | Body hits + 1 block, home 0.67 s |

**Still a design question (unchanged).** A disc from behind passes through the panel's back face, and a thrower inside the 3-stud gap between the panel and the defender hits the body.

## Owner decision: the back of the shield blocks too (2026-11-21)

**Change.** Shield panels now block discs from both faces (`CoreGeom.SegPanel(..., twoSided)`, used by `CoreDisc`). The block-once rule still applies, so a disc is blocked by a given shield at most once per throw.

The panel stands 3 studs in front of the defender, so a disc thrown at the defender from behind still reaches their back first. The back face stops it after that hit, and it returns.

**Retest (player throws at `D-SHIELD`):**

| Throw from | Result |
|---|---|
| Front | 1 block, home 0.15 s |
| Side | Body hit, home 0.65 s |
| Behind-diagonal | Body hit, then back-face block, home 0.27 s (was 0.65 s, passing through) |
| Behind | Body hits, then back-face block, home 0.23 s (was 0.67 s) |
| Behind, aimed at the panel beside the body | Back-face block only, home 0.25 s |

**Still open (owner decision):** a thrower standing in the 3-stud gap between the panel and the defender hits the body.
- Owner decision (2026-11-21): **keep as is.** The shield does not protect the defender's back: a disc from behind still hits the body before the panel's back face stops it.

## Acceptance closeout (ChatGPT review of fbea8d2; 2026-11-21)

**Backups.** The pre-change place was preserved in `backup_step1e_accept_2026-11-21` (SHA `a80b97a7…`). The final place backup is `backup_step1e_2026-11-21` (identical to the live place).

**Repo cleanup.** Three tracked `tools/animation/__pycache__/*.pyc` files were removed and `.gitignore` now ignores `__pycache__/` and `*.pyc` (723bfe6). Source scripts and animation data are unchanged.

**Dash KeyframeSequences, local Animator test (no upload).** `dash_f`, `dash_b`, `dash_r` and `dash_l` register as temporary IDs and play at 0.333 s on an Animator test rig. They match AnimData within 0.02° at a sampled frame.

### Two-client Studio sessions (owner started Server & Clients, 2 players)

The test players have the canonical proportions (posed slide head 0.195). For the different-avatar check, B was given a stock R15 body with `ApplyDescription` (session-only; posed head 0.065).

**As seen by the OTHER client — OK:**
- run, slide (drawn head exactly on the server's slide head: 0.02, 0.19, 0.00), wall-run L/R, landing;
- all four dashes, each for 0.33 s. A side dash rolls −29° on both screens. A dash with the body turned toward the move direction is correctly drawn as a front dash;
- charge pose with hand spin (~5.2 turns/s seen) and release follow-through;
- shield raise / hold / lower on the left arm.

**Defect found and fixed** (other-player path only: `Poses.luau`; local play and gameplay unchanged).
- **Cause.** The replicated state change (slide → run, wall-run → run) arrives about 0.2 s before the launch velocity. The other client checked only at that instant, so it never showed the Power Slide Jump or wall-jump clips.
- **Fix.** The check stays open for 0.35 s after the state change, and the current clip is held meanwhile, so no fall flash.
- **Retest (third session):**
  - The other client shows the PSJ push → rise → apex → fall → land.
  - Wall-run → wall-jump → wall-run (second wall) → land is shown.
- **Discarded attempt.** A longer (7-stud) side ray made side flicker worse and was reverted to 4 studs.

**Residual discrepancies (not fixed):**
1. **Wrong-side wall-run flash.** When A chains to the second wall, the other client shows the wall-run on the old side for about 0.12 s (was 0.18 s) until its 4-stud ray finds the new wall.
2. **Push-off missing into a wall-run.** When a PSJ leads straight into a wall-run (~0.15 s), the other client skips the push-off: the state goes slide → wall-run with no run in between.
3. **Hits during a slide.** B threw 4 discs at a moving A. The 2 thrown while A ran matched the server (BODY). The 2 thrown while A slid were seen as BODY hits on B but registered no hit on the server ("seen-not-confirmed").
   - The hit maths and volumes are unchanged by Step 1E; animation does not feed the hit test.
   - Likely cause: other players are drawn slightly behind their server position while decelerating in a slide (the Step 1 finding that moving-target hits are unreliable even at 0 ms).
   - There is no Step 1D baseline under the same conditions, so this is not proven pre-existing.
4. **Feet below the floor during the slide blend.**
   - While the slide blends in or out (0.22 s), the run-to-slide joint blend draws a foot up to 0.64 studs below the floor on canonical proportions and about 0.33 on the stock body. Measured as drawn on the other client.
   - With the slide fully in, feet are on the floor (stock body 0.04 below its standing baseline).
5. **Wall-side arm.**
   - From the player camera on the canonical avatar, the wall-side arm sits at the wall face with no obvious poke-through (measured up to 0.30 studs inside).
   - On the stock body (wider torso) the torso edge and wall arm sit at or inside the wall plane (staged capture).

**Evidence:** `evidence/captures_1e/accept_canon_wallrun*`, `accept_stock_r15/`.

**Verification.**
- Gameplay tuning (`CoreConfig.luau`) is unchanged since Step 1D (1b0e857).
- Saved place parity 24/24, SHA-256 `f9e8960f7f98043c5e15d3bc371396277323923825eff1dd1dfda831bf811209`; backup identical.
- Step 1D place `e260bd57…` unchanged. Protected files 9/9.

**Shield.** The two-sided panel kept here is the owner's explicit decision (0d0d6bd, made after fbea8d2). The close-range gap behaviour is unchanged pending the owner's decision.

## Final correction pass (owner authorization 2026-11-21)

Scope: the three outstanding categories (A, B, C) only.
- **Unchanged:** gameplay tuning (`CoreConfig.luau` is identical to Step 1D) and shield rules (two-sided, block once per disc, 3-stud gap behaviour as before).
- **Not done:** no uploads, publishing, merges or new abilities.

**Places:**

| Place | SHA-256 |
|---|---|
| Pre-correction backup `place/backup_step1e_precorrection_2026-11-21` | `f9e8960f…` |
| New isolated final place `place/WorldEXE_CoreRound_Step1E_Final_2026-11-21.rbxlx` | `5f6665718a9d90dd77775ba75f394f7fac770b502d8cd7466fc2b3131bec763e` |

- The final place has parity 24/24 and is identical to the working Step 1E place.
- Backup: `place/backup_step1e_final_2026-11-21`.
- Step 1D place `e260bd57…` unchanged (opened for the comparison, never saved). Protected files 9/9.

### A. Sliding Disc hit disagreement

**Instrumentation (Studio only, off unless Workspace attribute `CR_HitTrace`):**
- `DiscClient.Trace`, the client op `Trace`: thrower-visible disc segments, the target root and head as drawn, slide weight, verdict.
- `CoreDisc.TraceLog`, the server op `Trace`: server segments, rewound and live target, rewind, slide weight, verdict.
- A 10 s position-history ring (server op `HistAt`).

**Root causes, with evidence:**
1. **Test artifact (not a game defect).** The earlier acceptance thrower was teleported just before each throw. The server had not yet received the move and clamped the throw origin (`origin_clamp` in Step 1E; `off=15.6` in Step 1D). This explains the first "seen-not-confirmed" cases; it reproduces in Step 1D.
2. **Real defect, pre-existing since Step 1B/1C.** The thrower draws other players a *variable* 0.03–0.10 s behind (measured by matching the drawn root to the server history at the same server time). The server rewound player targets by a *fixed* thrower latency plus `InterpPlayerSeconds` 0.05.
   - At slide speed (~50 studs/s) the mismatch reaches ~2.5 studs, so grazing throws flip both ways.
   - The server disc also started slightly behind the thrower's visual disc, because the catch-up used a ping estimate.

**Step 1D vs Step 1E comparison** (same protocol: stationary thrower confirmed on the server, target sliding or running past at ~49 / 36 studs/s, lead-aimed throws):

| Case | Step 1D | Step 1E before fix | Step 1E with fix |
|---|---|---|---|
| Slide, body aim | 2/3 agree, 1 seen-not-confirmed | 3/3 agree | **4/4 agree** |
| Slide, head aim (hit/miss) | 3/3 agree; part differs 2× | 3/3 agree; part differs 1× | **4/4 agree; part differs 2×** |
| Run controls | 2/2 | 2/2 | **2/2** |
| Near-miss (aim ahead of slider) | 2/2 agree (miss) | 1 agree, 1 confirmed-not-seen | **3/3 agree (miss)** |
| Teleported thrower | origin clamped | origin clamped | (test artifact, unchanged) |

**Correction (narrowest, server stays authoritative):**
- **Client throw message.** `DiscClient` now also sends `t0`, the release time on the server clock, and `view`: where this screen drew each nearby enemy at release (≤ 8 entries, within 90 studs).
- **Disc start.** The server aligns its disc start to `t0`, bounded by the existing `Disc.CatchUpMax`.
- **Per-target rewind.** The server rewinds each target to the moment its *own* history matches the drawn position (`CoreCombat.ViewDelay`; accepted only within the existing `Disc.RewindMax` and within 1 stud of a history segment; otherwise the old rule).
- **Unchanged:** hit volumes, radii, tolerance, damage, stun and the shield rules. Clients never claim hits.
- **Measured.** Matched rewind 0.034–0.037 s on every throw (`throw_view matched=1`).

**Residual (not changed: damage rule):** head-vs-body classification can still differ on sliding head shots (2 of 4).
- The server classifies at its first touching sub-step (the disc is just grazing, so BODY); the thrower's screen classifies at the closest pass (HEAD).
- Proposed fix for owner review: classify at the deepest (closest-approach) sub-step. It changes the head-shot rate on sliders, so it was not done here.

### B. Slide-transition foot penetration

**Cause.** The joint-space blend of the run and slide poses (`CoreGeom.SlideWeight`, 0.22 s) can put a foot or shin under the floor even though each pose alone is on it. On a rig with a lower hip height than the authoring rig (stock R15), the slide's folded rear leg also sinks.

**Correction (`Poses.luau` `fixFeet`, runs on every client for every character).** Applied after the final pose, using this rig's own joint attachments and part sizes and the floor under the root:
- the thigh is swung about the hip (bisection) until the thigh and shin rest on the floor;
- then a 2-bone leg IK lifts the ankle if the foot or shin's lower end is under the floor (bend plane kept, foot keeps its world orientation);
- two passes per leg.

The root (HumanoidRootPart is never moved), pelvis translation and head are untouched (the slide head stays exactly on the server's slide head). Nothing changes when no leg is under the floor. A falling character is checked where physics will put the root this frame.

**Measured** (lowest leg corner vs the floor, every frame, run → slide → exit → jump → land → slide → PSJ → land):

| Body | Before | After |
|---|---|---|
| Canonical | slide blend −0.64 | worst −0.014; 0 of 300 frames below −0.06 |
| Stock R15 | slide blend −0.44 | worst −0.020; 0 of 300 frames below −0.06 |

From the opponent's camera (two-client): deepest −0.06 / −0.08 on a single landing frame.

### C. Wall-run animation

**C1 — wrong-side flash (other players).**
- **Cause.** The replicated "wallrun" state arrives before the drawn body is within the 4-stud side ray of the new wall, so the old side was kept.
- **Fix.** Side ray first (still 4 studs; the 7-stud ray was not repeated); only when no wall is found on either side does the sideways motion (> 12 studs/s) decide, else the last side. A first version that used motion first picked the wrong side at entry and was corrected.
- **Two-client:** wall-run R → wall-jump → wall-run L with no wrong-side frames, entry and chain.

**C2 — PSJ push-off into a wall-run.**
- **Cause.** The other client receives slide → wallrun, or slide → run (a few frames) → wallrun, so the PSJ clip never played.
- **Fix.** A `psj_push` overlay (full for 0.08 s, gone by 0.25 s) on top of the wall-run in both cases; also for this client's own PSJ that reaches a wall within 0.25 s.
- **Two-client:** the other screen shows the push-off silhouette (left arm up to 105°) blending into the wall-run.

**C3 — wall arm / torso.**
- **Re-authored brace.** Drawn pelvis 0.06 off the wall, straight forward-twisted wall arm; clip QA arm/wall 0.30 → 0.055. Head-to-server offset 0.43 → 0.49 (inside the head sphere).
- **Rig-aware runtime correction (`wallArmFix`).** Whenever a wall is within 2.5 studs, the wall-side arm boxes are tested against the real wall plane (predicted for this frame's approach). If inside, the arm is rotated about the shoulder (bisection) until it only touches. Both sides.
- **Disc arm.** On a right-hand wall the disc arm keeps the brace (chest twist, held disc and hand spin still show).
- **Measured:**

  | Avatar / view | Wall-run frames | Worst arm | Worst torso / legs |
  |---|---|---|---|
  | Canonical, solo (37 charging) | 125 | 0.020 | 0.083 (wall-side foot edge) |
  | Stock R15, solo (was 1.51) | 48 | 0.018 | 0.011 |
  | Opponent's camera, two-client | 97–116 | 0.009–0.026 | foot edge 0.10–0.17 |

- **Residual.** One frame on the opponent's screen at the instant another player's wall-run begins (hand 1.45 into the wall), while the replicated state switches.

### Regression checks (two-client unless noted)

| Check | Result |
|---|---|
| Disc while moving | OK |
| Shield raise / hold / lower; two-sided panel; block once per disc | OK (rules unchanged) |
| Stun clears all layers | OK |
| Death / respawn | OK; slide head exact on the new character |
| Dash obstacle protection | OK: stopped at the wall at 5.1 studs, no rise or flip |
| Directional dashes | unchanged |
| 24-clip set | re-exported; QA 24/24 (shoulder-twist limit ±125° for the straight-arm brace) |
| Controller cost | solo 0.143 ms/frame; two-client 0.195 ms/frame for 2 characters, all corrections included |

### Files changed in this pass

- `Poses.luau` (feet, wall arm, wall side, PSJ overlay, disc-arm wall rule)
- `DiscClient.luau` (`t0` / `view` in the throw; trace), `CoreRoundClient.client.luau` (`Trace` op)
- `CoreRound.server.luau` (view-matched rewind), `CoreDisc.luau` (per-target rewind; trace), `CoreCombat.luau` (`ViewDelay`; diagnostics ring), `CoreTest.luau` (`Trace`, `HistAt`)
- `AnimData.luau` (re-export), `tools/animation/cr_anim_clips.py` (wall brace, wall-jump key), `cr_anim_qa.py` (shoulder twist limit)
- `tools/studio/coreround/cr_71_floor_probe.luau`, `cr_72_wall_probe.luau`

### Proposed lessons (for later vault review; vault not modified)

- **L-0119:** Player-target rewind must match what the thrower actually drew. The drawn delay for other players varies (0.03–0.10 s measured); a fixed interpolation constant mis-judges fast movers. Let the client report release time and drawn positions, and match them against server history within the existing rewind cap.
- **L-0120:** Never teleport a test thrower right before a throw; the server may not have the move yet, and origin validation clamps it.
- **L-0121:** Post-pose, rig-aware contact correction (floor and wall) belongs after the final blend, using the rig's own attachments and sizes. Predict this frame's root motion, because poses are written before physics.
- **L-0122:** For other players, replicated state changes arrive before position and velocity. Decide visual details (wall side, push-off) from geometry first and keep a short watch window, instead of deciding at the instant of the state change.

## Final security gate + wall-run animation correction (2026-11-21)

Directive: fix the demonstrated rewind forgery (keep the first-contact HEAD/BODY rule), correct the wall-run animation (raised wall-side arm; only hand and feet touch the wall; both sides), touch gameplay networking only as needed, and do not change the HumanoidRootPart, wall-run forces / speeds / collision or wall-jump mechanics. Owner play-test feedback during the pass added three fixes: the arm "looks exactly the same", the head tilted the wrong way, and a slide-into-obstacle bug.

### A. Rewind forgery (security)

- **Before:** the server trusted the client's release timestamp `t0` and let any drawn position inside RewindMax (0.25 s) pick the rewind, so a modified client could claim an older view and hit where the target had been.
- **Now (`CoreRound.server.luau`, `CoreCombat.ResolveView`):** `payload.t0` is ignored. Latency and the reference time are server-measured. Each thrower has a server-tracked view offset estimate that starts at `ViewOffsetStart` (0.10 s), moves at most `ViewEstStep` (0.01) per accepted throw, and stays inside [`ViewOffsetMin` 0, `ViewOffsetMax` 0.15]. One throw's claim may only pick within ±`ViewSlack` (0.02) of the estimate, and a drawn position must lie within `ViewMatchTolerance` (1.0 stud) of the target's recorded path.
- **Calibration (two clients):** honest drawn positions were 0.08–0.16 s old at receipt (typically 0.10). The start moved 0.05 → 0.10 and the cap 0.10 → 0.15.
- **Adversarial (two clients, `cr_73_view_attack.luau`):** 0.3 s forged claims were unmatched with no hits. Missing views and invalid or duplicate entries counted as misses. A 12-throw drift pushed the estimate to the 0.15 cap, after which forged past=6 throws hit 3/3. Studio dummy lag is ~0.03 s, so this overstates real-network risk.
- **Disclosed compromise:** a cheating client can gain at most ~0.05 s of extra rewind over an honest player's lag (~2.5 studs at slide speed). The old rule allowed a free 0.25 s.
- **Honest throws with start 0.10 (two clients, final session):**
  - A threw at B sliding past at ~49 studs/s, aiming ahead of B: 7 of 8 hit (all BODY) and A's screen agreed on all 7.
  - The miss was the first throw after a pause: A's screen showed a hit, but A's true view delay was above est + slack (0.093 s allowed).
  - The estimate settled at 0.07. Every throw matched, with none forged or invalid.
  - Aiming where B was, with no lead: 0 of 8 hit, and A's screen also showed none, so these were honest misses.

### B. Wall-run animation

| Change | Detail |
|---|---|
| Pose (`cr_anim_clips.py`) | The wall-side upper arm reaches sideways to the wall, elbow bent, hand on the wall (`WALL_ARM = (35, 100, -15, 60, 0)`). The waist cancels the hip swing so the arm stays put. Body lean `WALL_TILT` 10° → 15° to give the arm room. |
| Why the earlier pose "looked the same" | The pose search measured the arm angle ignoring the forward component (the arm really pointed forward). In-game, the runtime wall fix also swung the arm near-vertical every frame (about 6° out). |
| Runtime (`Poses.luau`, `reachContact`) | The forearm's wrist half may meet the wall where the hand touches it. The clear-only fallback now runs only on the first entry frames. |
| Head | Neck counter-roll 2.4 → 0.2 (it tipped the head ~20° into the wall). The head now tilts ~6° away, with the body. |
| Remote entry side (two-client finding) | At entry, the replicated state can arrive while the drawn body is more than 4 studs from the wall. The last wall side was kept, so after a left-wall run a right-wall entry started in the left-wall pose (body ~1 stud into the wall for ~0.1 s on the watching client). At entry the side ray now reaches 8 studs, and if no wall is found yet, the wall pose waits instead of guessing. |

In-game (solo, own character): upper arm 45–49° out, head −6°, upper arm −0.005 / lower arm 0.038 / hand −0.05..0.09 studs from the wall (right); similar on the left.

Two clients, B watching A (after the entry fix):

| Check | Result |
|---|---|
| Right wall | Same arm, head and torso as A's own screen; body ≥0.32 clear; arm ≤0.03 |
| Left → right / right → left pairs | Correct side from the first wall frame; body clear |
| PSJ → wall-run → wall-jump → second wall | Full chain drawn; one first-contact frame with the arm 0.10 into the wall |
| Right-wall disc charging | Disc rim 0.45 clear of the wall |

Residuals (disclosed):
- **Snap frame:** one frame (~17 ms) when the other player's replicated position snaps onto the wall, before the wall pose starts (arm up to ~1 stud into the wall for that frame). The snap comes from the movement code, which this pass may not change.
- **Left-wall entry:** while the body closes its last ~0.3 studs, the forearm sits up to 0.14 studs into the wall for ~0.13 s.
- **Head hitbox:** the drawn head is ~1.1 studs from the server head hitbox centre (hit zone reach 1.6) because of the 15° lean. Hitboxes are unchanged.

### C. Slide into obstacles (owner report)

- **Cause:** sliding head-on into a block launched the character up (~48 studs/s) and knocked it over. The slide's LinearVelocity had unlimited force, so physics resolved the collision upward.
- **Fix (`Slide.luau`):** a sphere-cast look-ahead along the slide at two heights.
  - Head-on (no useful tangent): the slide ends ("blocked") with the into-wall velocity removed.
  - Glancing: the slide continues along the face at the tangent speed.
  - Ramps and walkable steps (normal Y ≥ 0.6) are unaffected.
- **Result:** head-on into Cover1 → blocked, max rise 3.7 studs/s, upright. Glancing along the perimeter wall → 38.7 studs of continued slide, no launch.

### Place and data

- Place `WorldEXE_CoreRound_Step1E_2026-11-21.rbxlx`: SHA-256 `88fd393a178fd5eca9698e2170cc0ccead9b99947acdec2092ebfb4326e7e4a4`. Script parity 24/24, 24 KeyframeSequences.
- Backup `backup_step1e_finalgate_2026-11-21.rbxlx` (same SHA). Earlier backups kept, including `backup_step1e_armslidefix_2026-11-21.rbxlx` (`aa492b58…`).
- Blender source `WorldEXE_CoreRound_Anim_Step1E.blend`: `18eb36fc85b7b9014f2db4d7dc2c96c6cf87a3f8b077bf9abfe228db13252b84`. AnimData QA 24/24.
- Protected-file check: 9 OK.
- Evidence (local, not committed) is in `evidence/captures_1e_gate/`:
  - `twoclient_B_sees_A_right_front.jpg`, `twoclient_B_sees_A_right_charging.jpg`, `twoclient_B_sees_A_left_behind.jpg` and `twoclient_B_sees_A_right_far.jpg`: the other player's screen.
  - `review_wallrun_r_elbowout.png` (Blender) and `canonical_R_elbowout_behind.jpg` (in-game).

### Proposed lessons (for later vault review; vault not modified)

- **L-0123:** A client-assisted rewind needs a server-owned window. Never trust client timestamps; keep a per-player estimate that moves slowly, and accept only claims near it. Calibrate the start value with two real clients.
- **L-0124:** Measure arm direction as the full 3-D shoulder→elbow vector in character space. A 2-D angle that drops the forward component can report "out to the side" for an arm that points forward.
- **L-0125:** A velocity constraint with unlimited force makes physics resolve collisions upward (launches). Look ahead and stop or redirect the drive instead.
- **L-0126:** For another player, a state change can arrive before their position. Never fall back to the last remembered side at the start of a new action; wait for geometry.

## Closeout: rewind manipulation + wall-run head alignment (2026-11-22)

### A. Rewind: server policy only

**Root cause (615ac22).** `CoreCombat.ResolveView` updated the per-thrower view-offset estimate from the client's own claims, including clamped ones, so sustained forged claims dragged it to its 0.15 s cap (3/3 forged hits).

**Fix.**
- Authoritative rewind against characters = server-measured one-way latency + `Disc.RewindPlayerOffset` (0.05), capped at `RewindMax`. Dummies keep `InterpSeconds` (0).
- The latency used for rewind is capped at `Player:GetNetworkPing()/2 + Net.EnginePingMargin` (0.02), so delaying pongs cannot inflate it.
- `payload.view` is diagnostics only: `ResolveView` returns the measured drawn age per target for the log and changes no server state. The estimator and its config keys are removed. `payload.t0` stays ignored.
- No change to hit volumes, HEAD/BODY first contact, damage, stun, disc or shield behaviour.

**Adversarial tests (solo, `cr_73_view_attack.luau`, moving dummy at 50 st/s).**

| Test | Throws | Rewind used | Outbound hits |
|---|---|---|---|
| Paired sweep: honest / forged 0.3 s / no view / invalid view, 4 distances past the line, 2 reps | 32 | latency only (0.006–0.010 s) in every condition | 0 in every condition |
| Sustained forgery: 20 forged 0.3 s claims in a row | 20 | unchanged throughout | 0 / 20 |
| Paired approach sweep: honest / forged (claims the dummy on the throw line) / no view, 5 distances, 2 reps | 30 | identical per pair (latency jitter only) | identical by distance (all hit at 1.5–3.5; all miss at 7.5; one "no view" hit at 5.5 = dummy timing) |

The rewind is computed without the claim, so a manipulated claim cannot change an authoritative outcome.

**Legitimate two-client test (Studio Server & Clients, latency ~0, B sliding at ~49 st/s, A leading the target).**

| RewindPlayerOffset | Throws | Server hits | Notes |
|---|---|---|---|
| 0.08 (first pick) | 9 | 0 | A's screen showed 4 of the 7 recorded as hits: the rewind overshot by ~3 studs |
| 0.05 (shipped) | 4 | 4 BODY | |
| 0.03 | 6 | 6 BODY | |

Honest drawn age in this session: 0.015–0.094 s (2026-11-21 session: 0.08–0.16 s). A fixed offset cannot match both. 0.05 is the middle. The cost is up to ~0.05 s of mismatch either way, ~2.5 studs at slide speed. A's own "visible hit" check agreed with the server on about half the throws at every setting (aim close to the edge).

### B. Wall-run head / hitbox alignment

| Item | Before | After |
|---|---|---|
| Drawn head offset from the upright server head (canonical, in game, entry + run, both sides) | 1.14 | 0.69–0.72 |
| Stock R15 | — | 0.67 |
| Wall arm | raised, elbow out | raised, elbow out (hand ≥1.06 above the shoulder) |

**Pose change (`cr_anim_clips.py`).**
- `WALL_SHIFT` −0.45 → −0.20; pelvis lean `WALL_TILT` 15 → 10, plus a chest roll `WALL_WAIST_ROLL` 8.
- Chest / hip turn toward the wall 30/12 → 35/15; `WALL_NECK` 1.0 (head level).
- `WALL_ARM` (120, 54, 0, 75, 20); outer foot +0.1, wall-leg lift 0.45.
- AnimData QA 24/24.

**Why not ≤0.35.** With the hips at the wall (`WALL_X` 0.9), the raised elbow-out arm needs the wall shoulder ~1.3 studs from the wall, and the head sits ~0.65 inside the shoulder at the waist-twist limit (40°).
- 0.44 is reachable only with an overhead, elbow-in arm.
- ~0.40 needs a 55° waist twist (fails QA).

**In-game finding (not fixed).** The server's own `Head` part (the hitbox centre) is not upright during wall-runs.
- It cycles about 0.6 studs forward of the root (y 1.36–2.39, z −1.1…+0.1).
- It does not mirror between walls.
- It did not change with `Animate` disabled, or with the wall-run's stock run track removed (test only; reverted).
- Against that live centre, the drawn head is ~0.9 away (old pose ~1.25 estimated).
- Fixing it needs a decision on the head-hitbox source for wall-runs, e.g. the root plus the rig's rest head offset, like `PosedHeadOffset` for slides.

**Wall contact (in game, own client).**

| Check | Right | Left | Stock R15 R / L |
|---|---|---|---|
| Upper arm | ≤ −0.072 | ≤ −0.057 | ≤ −0.008 / −0.009 |
| Forearm | ≤ −0.054 | ≤ −0.039 (was +0.14 at entry) | ≤ 0.013 / 0.015 |
| Hand | −0.17…−0.05 | −0.32…−0.04 | −0.16…0.03 / −0.25…0.04 |
| Body (torso, head) | ≤ −0.073 | ≤ −0.072 | ≤ −0.10 |
| Feet | 0.08 contact | 0.06 contact | 0.01 contact |

- Disc charging on the wall (stock R15): rim ≥0.45 clear over 15 charged frames.
- Stock R15 slide: lowest foot/shin −0.036, 0 of 71 frames below −0.06 (no regression).
- Stock R15 exit: the upper arm touches the wall by up to 0.15 for a few frames after leaving the wall.
- Canonical hand: sits up to ~0.17 studs off the wall in some frames (near, not always touching).

**Observer-side snap:** the one-frame position snap the other player sees at wall-run entry is unchanged (movement code untouched).

**Captures** (`evidence/captures_1e_closeout/`): `canonical_R_front.jpg`, `canonical_R_behind.jpg`, `canonical_L_front.jpg`, `stockR15_R_front.jpg`. The stock R15 body was applied with `ApplyDescription` for the session only.

### Place and data
- Place SHA-256 `127ade8815bcc102766d628fddfb3182dd49307e64a960ecb96442702213164d`; backup `backup_step1e_closeout_2026-11-22.rbxlx` (same SHA). The pre-edit backup `backup_step1e_closeout_pre_2026-11-21/` holds the previous version `88fd393a…`.
- Script parity 24/24, 24 KeyframeSequences, AnimData QA 24/24, protected files 9 OK.
- Blender `WorldEXE_CoreRound_Anim_Step1E.blend` SHA `e69012df…`; backup `backup_precloseout_WorldEXE_CoreRound_Anim_Step1E.blend`.

### Proposed lessons (vault not modified)
- **L-0127:** a server-side estimate trained on client observations is still client-controlled. Keep the authoritative value derived only from server measurements; use client reports for diagnostics.
- **L-0128:** Studio two-client interpolation delay varies a lot between sessions (0.02 to 0.10+ s). Calibrate rewind offsets in more than one session before fixing them.
- **L-0129:** on a client-posed character, the server-side `Head` part is not the drawn head. Measure the server's own part in game before assuming a hitbox centre.

## Final wall-run head-hitbox correction (owner-approved, 2026-11-22)

### Root cause

During a wall-run the server's physical `Head` part (the head-hit centre stored in combat history) follows **replicated AnimationTracks that no client shows**. Tracks seen on the server during a wall-run:

| Track | Priority | Source | Presence |
|---|---|---|---|
| Stock R15 run (913376220) | Action | `WallRun2` | every wall-run frame |
| Default jump (507765000) | Core | `Animate` | |
| Default fall (507767968) | Core | `Animate` | |
| Default run (913402848) | Core | `Animate` | |
| Idle | Idle | | |

- Every client overrides the joints with the Poses wall-run pose, so on screen only the custom pose is visible.
- The server head therefore sat ~0.56 studs forward of the root, cycling (y 1.36–2.39), the same for both walls, ~0.9 from the drawn head.
- Earlier single-cause tests (`Animate` off; `WallRun2` track off) each left the other source playing, which is why neither removed the offset.

### Chosen authoritative calculation (`CoreCombat.HeadCentre`, `CoreGeom.WallHeadOffset`)

- **Offset.** Head-hit centre = server root CFrame × the rig's own Root/Waist/Neck chain posed with the exported `wallrun_r` torso/neck transforms (`CoreGeom.WallPoseR15`, averaged over the 14 clip frames), mirrored to the wall side.
  - Canonical rig: (−0.70, 1.61, 0.00) in root space. Stock R15: (−0.633, 1.467, 0.021).
  - Recomputed at every wall-run entry, because an avatar change keeps the same entity.
- **Wall side.** Found by the server with the same rule the clients' Poses draws with, using only server data (root, raycasts, root velocity):
  - a wall within 4 studs;
  - until this run's wall is found, within 8 studs;
  - else a sideways speed above 12 st/s;
  - else keep the last side.
  - A "wallrun" state with no wall found gets no offset.
- **Timing.**
  - Blended from the physical head over `Disc.WallHeadBlendSeconds` 0.12.
  - Starts `WallHeadInDelaySeconds` 0.13 after the server's state change and ends `WallHeadOutDelaySeconds` 0.22 after it.
  - These follow when observers actually draw the pose (two-client measurement). Hit fairness follows the thrower's view, which is an observer's.
- **Chains.** A wall-to-wall chain eases the side across instead of flipping. A fresh run carries no side over.
- **History.** The corrected centre is stored in combat history, so lag compensation uses it.
- **Unchanged.**
  - Run, slide and all other states (weight 0; measured identical to the physical head, 0.0000 over 168 run + 72 slide frames).
  - Head radius, body capsule, tolerance, damage, stun, HEAD/BODY first contact.
  - Animation source, movement code, `HumanoidRootPart`.
- **Switch.** `Disc.WallHeadEnabled` (0 = previous behaviour) was used for the A/B throw comparison.
- **Security.** Nothing comes from the thrower or the target's client except the movement state the server already accepted. The rewind is unchanged.
  - Forged-view check at a wall-runner: an honest view and a view claiming a position 0.34 s old got the same server rewind (0.050 s).

### Measurements

Head-centre error vs the drawn head, in root space, time-aligned:
- **Own screen:** matched by server time.
- **Other player's screen:** matched to the server time of the same drawn root position (separates interpolation from rig error).

Final build, studs:

| Case | View | Phase | Corrected med / p95 / max | Physical med / p95 / max |
|---|---|---|---|---|
| Canonical, right | own | run | 0.05 / 0.08 / 0.08 | 0.86 / 1.05 / 1.08 |
| | other | run | 0.06 / 0.08 / 0.29 | 0.85 / 1.08 / 1.08 |
| | other | exit | 0.06 / 0.26 / 0.35 | 0.90 / 1.04 / 1.05 |
| | other | entry | 0.58 / 0.70 / 0.70 | 0.58 / 0.70 / 0.70 |
| Canonical, left | own | run | 0.05 / 0.08 / 0.08 | 1.00 / 1.06 / 1.08 |
| | other | run | 0.05 / 0.08 / 0.20 | 1.00 / 1.08 / 1.09 |
| | other | exit | 0.06 / 0.52 / 0.64 | 1.11 / 1.17 / 1.17 |
| | other | entry | 0.72 / 0.97 / 0.97 | 0.93 / 1.03 / 1.03 |
| Chain right → left | own | run | 0.05 / 0.08 / 0.08 | 0.89 / 1.06 / 1.08 |
| | other | run | 0.06 / 0.09 / 0.16 | 0.87 / 1.07 / 1.09 |
| | other | exit | 0.06 / 0.49 / 1.01 | 1.09 / 1.51 / 1.52 |
| | other | entry | 0.49 / 1.07 / 1.14 | 0.76 / 1.05 / 1.06 |
| Stock R15, left | own | run | 0.05 / 0.08 / 0.08 | 0.92 / 0.98 / 1.00 |
| | other | run | 0.06 / 0.08 / 0.08 | 0.92 / 1.00 / 1.01 |
| | other | exit | 0.06 / 0.22 / 0.34 | 1.03 / 1.09 / 1.11 |
| Stock R15, right (short runs) | other | run | 0.03 / 0.09 / 0.09 | 0.78 / 0.82 / 0.82 |
| | other | exit | 0.06 / 0.19 / 0.27 | 0.92 / 1.00 / 1.01 |

- **Entry** (first 0.25 s of the observer's wall-run state) is the weakest phase. The server is still on the physical head while the observer's pose blends, so the residual there is mostly the pre-existing normal-running mismatch, equal to or lower than before.
- **Chain** entry/exit can still reach ~1.0–1.1 on the frames around the wall-jump.
- **Stock R15 right-lane** runs ended after ~0.1 s (movement, pre-existing), so that sample is small.

### Throws at a wall-runner (canonical runner, A on the open side, lead aim; run before the chain/side fixes)

| Head centre | Aimed at drawn head | Aimed at drawn upper torso | 1.5 studs above the head |
|---|---|---|---|
| Corrected | HEAD; miss (A's own screen also showed a miss) | BODY, BODY | miss |
| Original physical | HEAD, HEAD | **HEAD**, BODY | miss |

The original head counted one torso shot as a headshot. A's own "visible hit" check disagreed with the server on two head throws (client BODY, server HEAD), under both versions.

### Remaining discrepancies (not changed; out of scope)

- **Normal running:** the physical `Head` (stock run/jump/fall tracks) sits ~0.3–0.9 studs from the drawn head. This sets the entry residual above.
- **Stock R15 wall-runs on the right lane:** sometimes end after ~0.1 s (movement).
- **One unexplained reading:** the first wall-run of one session read on the wrong side. It was not reproduced in later sessions; the side-reset fix covers the known cause.

### Files

- `src/ReplicatedStorage/WORLD_EXE/CoreRound/CoreGeom.luau`: `WallPoseR15`, `WallHeadOffset`.
- `src/ReplicatedStorage/WORLD_EXE/CoreRound/CoreConfig.luau`: `Disc.WallHeadBlendSeconds`, `WallHeadEnabled`, `WallHeadInDelaySeconds`, `WallHeadOutDelaySeconds`.
- `src/ServerScriptService/WORLD_EXE/CoreRound/CoreCombat.luau`: `HeadCentre`, history, `SetMoveState`.
- `src/ServerScriptService/WORLD_EXE/CoreRound/CoreTest.luau`: Studio `Diag` hook.

Animation source unchanged (`WorldEXE_CoreRound_Anim_Step1E.blend` `e69012df…`).

### Place

- SHA-256 `b7206d06b8496a926b2eeac8c8ed4e9ce665254c6f0f938e7f4b965635bd1c08`; backup `backup_step1e_headfix_2026-11-22.rbxlx` (same SHA). Pre-edit backup `backup_step1e_headfix_pre_2026-11-22/` (`127ade88…`).
- Script parity 24/24, 24 KeyframeSequences, protected files 9 OK.

### Proposed lesson (vault not modified)

- **L-0130:** a hidden replicated AnimationTrack still moves the server's parts. When clients override joints locally, derive server hit volumes from the root and the rig's own joints instead.

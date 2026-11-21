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

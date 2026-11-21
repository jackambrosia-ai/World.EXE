# Core Round Step 1C Phase A: movement fluidity and speed presentation

Owner-authorized on 2026-11-21: Phase A only (A1–A5). Not included: Phase B (landing roll, vault, mantle), new
mobility abilities, and Step 2. Isolated place only.

## Places and hashes
| | Path | SHA-256 |
|---|---|---|
| Step 1 (unchanged) | `C:\WORLD.EXE-Art\CoreRound\place\WorldEXE_CoreRound_2026-11-20.rbxlx` | `f8cf4b0a…128dc9e` |
| Step 1B (unchanged) | `...\WorldEXE_CoreRound_Step1B_2026-11-21.rbxlx` (+ `backup_step1b_2026-11-21`) | `48e7a0f9…174d30` |
| Step 1C (new) | `...\WorldEXE_CoreRound_Step1C_2026-11-21.rbxlx` (+ `backup_step1c_2026-11-21`) | `43af6b6f9845d847ec0fd6d1f35e60a033de282ffae5625ba3c0ec2a16521592` (after the charge-ring change; first 1C save `73905fdc…32156b`) |

Saved-place parity: `cr_40_verify_saved.js` reads 23/23 scripts identical to `src/`, with no extra scripts. The new
script is `SpeedFx`.

## What changed

### A1: blended transitions with fair hit volumes
- **One shared curve.** Slide pose and slide hit volumes both use the same eased curve, `CoreGeom.SlideWeight`, over
  `Slide.PoseBlendSeconds` (0.12 → 0.22).
  - The server records a blend weight for every history frame and samples it at the rewound time.
    `DiscHit` blends the head and body volumes between standing and sliding by that weight.
  - In Step 1B the server switched volumes in one frame while clients blended the pose.
  - A slide cancelled early, or restarted quickly, continues from the weight it had reached, on both sides.
- **Other players' pose timing.** Their pose clock starts `Disc.InterpPlayerSeconds` (0.05 s) after their move state
  arrives. That is the same delay their positions are drawn with, so the pose stays in step with what the server
  rewinds to.
- **Per-avatar slide head.** The server and clients compute the slide-head height from each character's own joints:
  `CoreGeom.PosedHeadOffset`, using the same pose targets as `CoreGeom.SlidePoseR15`.
  - Two-client measurement: the default test avatar's drawn head sits 0.18–0.22 above the root, and the computed
    value is 0.19.
  - The fixed 0.5 from Step 1B came from a different avatar. `Slide.HeadHeight` remains only as a fallback for
    non-R15 rigs.
- **Wall-run lean.** The lean is now a blended joint pose. The physical root stays upright: Step 1B tilted the root
  with an AlignOrientation and it snapped upright on exit. The wall-run animation fades in over 0.2 s (was 0.12) and
  out over 0.25 s (was 0.15).
- **Camera.** Offset changes use one tunable blend time, `Cam.BlendSeconds` = 0.25, which matches the old rate.
- **Client hit record.** The client's "what I saw" record now uses the drawn slide weight and head height, so the
  agreement diagnostic covers sliding targets.

### A2: speed presentation (`SpeedFx`, client only)
- Up to 24 thin 2D streaks at the screen edges, pointing at the centre.
  - Intensity eases between 40 and 75 studs/s, in and out over 0.25 s.
  - Streaks never enter the central 55% of the screen, where the crosshair, charge ring, hit marker and threat arrows
    sit. They also skip the bottom-centre status bar.
- A faint team-colour edge glow: full during a dash or Super Dash, 60% of full at high speed.
- One ScreenGui with pooled frames, drawn under the HUD, with no world particles.
- Off in Reduced FX. Hidden with no live character, so it cleans up after death, respawn and reset.

### A3: wall-run camera tilt (optional)
- Rolls the camera up to `WallRun2.CamTiltDegrees` (8°) away from the wall.
  - Eases in over 0.25 s and out over 0.3 s at a constant rate.
  - Applied after Roblox's camera each frame and never stored, so it cannot build up.
  - Level outside wall-runs.
- Forced to 0 in Reduced FX. Players can turn it off with the **Wall-run tilt** toggle in the settings panel; testers
  can override it with `CoreTune_WallRun2_CamTiltDegrees`.
- Rolling the camera leaves the crosshair ray, the aim yaw (shield facing) and the camera position unchanged.

### A4: procedural poses (`Poses`)
| Pose | What it does |
|---|---|
| Slide | Same pose as Step 1B, now on the shared, server-matched curve |
| Wall-run | The body leans 10° away from the wall; the wall-side arm reaches out to the wall (shoulder 78° out, slightly forward). The arm is skipped while that arm holds a charging disc. |
| Reach | After a wall jump or slide jump, the left arm reaches forward and up for 0.5 s |

- Other players see these poses from the existing `CR_MoveState` attribute; there is no new remote traffic.
- Only joints move. Collision, the root part and root motion are untouched.
- Supports R15 and AnimationConstraint rigs. R6 gets only the slide and lean, and is untested.
- Sign conventions were checked on captures: −Z on the right shoulder swings it out.

### A5: slide entry boost comparison
- Compared via `CoreTune_Slide_EntryBoost`. The default stays 8.

## Measured results (Studio, local; solo unless noted)

### Transitions (per-frame log, slide down the 20° slope)
- **Slide weight:** blends in over 198 ms and out over about 180 ms, changing by at most 0.12 per frame.
- **Camera drop:** moves at most 0.22 studs per frame.
- **Wall-run tilt:**
  - reaches 0 → 8° in about 0.25 s;
  - swings smoothly to −8° across a wall-jump to the opposite wall;
  - the out-ease tail was fixed to a constant rate.

### Pose and hit-volume alignment (two clients: A = Player1, B = Player2, round trip about 0.025 s)
| Check | Result |
|---|---|
| Slide weight drawn on A vs server weight at A's rewind time (0.065 s), 136 frames over two slides | Max difference 0.22, mean 0.013. No frame where B looked upright (< 0.2) while the server used mostly lowered volumes (> 0.5). |
| Same comparison under the Step 1B rule (instant server switch) | Max difference 1.0 |
| B's drawn slide head on both screens | 0.18–0.22 above the root; the server computes 0.19 for that rig |
| Throws straight down the lane at sliding B, aimed as drawn on A | Head ×2: HEAD, HEAD. Above the head (+2.2): passed over on the way out. Body (−1.0): BODY. A's own record agreed on all outbound passes. |
| Sideways leading throws at a slider moving 37 studs/s | Head ×3: 1 BODY hit, 2 misses. Body ×1: hit on the return pass. This is aim error on a fast-moving target, the same as the Step 1/1B finding. |
| Wall-run seen by the other client | 10° lean, wall-side arm 78° out, reach after the wall-jump |

- **Delay fit:** the best match was at about 0.10 s. A sees the pose about 35 ms after the server applies it. The
  difference stays inside the head volume's tolerance.

### A5: slide entry boost (flat lane and 20° slope; real keys)
| Boost | Flat: distance in 2 s (run alone ≈ 57) | Flat: one slide | Hop chain: boosted entries | Hop chain: distance in 2 s | 20° slope: peak / distance |
|---|---|---|---|---|---|
| 8 (default) | 55.9 | entry 38, 47 studs, 1.78 s | 38–38 | 66.9 | 51.0 / 136 studs |
| 10 | 58.7 | entry 40, 53 studs, 1.93 s | 40–42 | 72.0 | 52.4 / 140 studs |
| 12 | 62.6 | entry 42, 60 studs, 2.08 s | 42–46 (cap) | 75.4 | 54.0 / 145 studs |

- No `speed_violation` at any setting. Chains at 12 reach the 46 entry cap. The boost cooldown (0.9 s) boosts every
  other hop at this pace.

### Regression checks
- Stun rules unchanged: 2 head stuns; 2 body + 1 head stuns; 3 body is not a stun (meter 90).
- Full-charge throw: server charge 1.0, speed 200, range 115. Blocked by a front shield. A flank throw hits, as
  designed.
- Hit geometry: fully standing and fully sliding match the Step 1B tables exactly; halfway sits between them.

### Reduced FX
- During a dash and a wall-run, roll stayed at 0°, streak and glow intensity stayed at 0, and the speed layer never
  turned on.

### Performance (same 4 s dash + slide run, 240 frames)
| | Mean frame | p95 | Max | Poses script time | SpeedFx script time | Most streaks on screen |
|---|---|---|---|---|---|---|
| Effects on | 16.66 ms | 17.77 ms | 18.34 ms | 0.024 ms/frame | 0.027 ms/frame | 12 |
| Reduced FX | 16.67 ms | 17.72 ms | 18.36 ms | 0.024 ms/frame | 0.006 ms/frame | 0 |

- Frame time is capped at 60 fps in Studio, so the added cost shows up as script time: about 0.05 ms per frame.
  Not measured on mobile hardware.

## Captures (local, never committed; player list hidden)
`C:\WORLD.EXE-Art\CoreRound\evidence\captures_1c\`:
- `slide_slope`: slide from behind.
- `wallrun_pose_front2`: right wall, arm to the wall and lean.
- `wallrun_pose_left`: left wall.
- `wallrun_tilt8` and `wallrun_tilt0`: camera tilt comparison.
- `speedfx_dash`: streaks and glow.

"Before" frames from Step 1B are in `captures_1b\` (`slide_slope2`, `wallrun`).

## Remaining issues
- **Return pass.** For one of the throws, the server judged the disc's return pass HEAD while A's own record said
  BODY. Outbound passes all agreed.
- **Fast sideways targets.** Hitting a sliding head from the side is still mostly a matter of aim at 37 studs/s.
- **Untested hardware.** R6 poses, mobile and real controller hardware are untested in 1C. No new buttons were added.
- **Pose quality.** The poses are procedural and look stiff next to real animation; hand-made animations are a later
  art task.
- **Slide head per avatar.** The slide head height now depends on the avatar. For the test avatar it is lower than
  Step 1B's fixed value (0.19 vs 0.5), so heads on sliders are slightly smaller targets. That matches what is drawn.

## Follow-up: shrinking charge ring (owner feedback, 2026-11-21)
The Disc charge ring was 12 dots on a fixed 24-pixel ring that lit up as you charged. Now:
- It opens wide (48 px radius, `Hud.ChargeRingStart`) the moment you start charging.
- It closes in evenly as the charge builds, and the dots meet in a single point on the crosshair (`Hud.ChargeRingEnd` = 0) exactly at full charge.
- At full charge the point pulses white.

Measured radius during one charge: 48 px at the start, 33 px at 18% charge, 0 px at 100%. An ease-out curve was tried first: it reached 4 px at 74% charge, which made "full" hard to read, so the ring now closes linearly.

Capture: `captures_1c\charge_ring3\sheet.jpg`, taken with a real mouse hold. Window-only grabs without input focus showed stale frames.

# Core Round Step 1D: Power Slide and Power Slide Jump

**Owner direction (2026-11-21):** a fast, powerful slide that can turn straight into a high jump. The reference is Sojourn's Power Slide in Overwatch 2.

This is an original WORLD.EXE adaptation in the isolated Core Round prototype. No values, animations, assets or implementation were copied. All new numbers are **provisional** and wait for the owner's review.

Not done here: landing rolls, vaulting, mantling, Step 2, monetization and map work.

## References
| Source | How it was used | What it gave us |
|---|---|---|
| Official Sojourn hero page | Text fetched | Power Slide is "Ground slide that can cancel into a high jump"; no numbers given |
| Developer Update video | Streamed, no download, no SHA; auto-captions read; frames not kept | Slide any time, in any direction, "really far and really fast"; you can fire while sliding; jumping during the slide gives a very big jump onto rooftops or over walls; airborne pose is knees tucked with the weapon kept forward |

## Places and hashes
| | Path | SHA-256 |
|---|---|---|
| Step 1C (comparison baseline, unchanged) | `C:\WORLD.EXE-Art\CoreRound\place\WorldEXE_CoreRound_Step1C_2026-11-21.rbxlx` (+ backup) | `43af6b6f…521592` |
| Step 1D (new) | `...\WorldEXE_CoreRound_Step1D_2026-11-21.rbxlx` (+ `backup_step1d_2026-11-21`) | `e260bd5705bec07cce20c5817bf4d213be14f34b52ed806466aac3c187e26a7a` (after the wall-jump control follow-up; earlier 1D saves `9fb3caff…`, `a5a9e5fa…`) |

- **Parity:** the saved file matches `src/`, 23/23 scripts, with no extra scripts.
- **Protected files:** the check passes 9/9.

## What changed

### Power Slide Jump (highest priority)
Press Jump while sliding and the slide ends at once. The character launches upward and keeps some forward travel:
- **Up** = `PowerJumpUp` (76) + `PowerJumpConvert` (0.6) × (slide speed − 36), capped at `PowerJumpMaxUp` (90).
- **Forward** = slide speed × `PowerJumpKeep` (0.68), with a minimum of 22.

How it behaves:
- Part of the slide's speed becomes height, so faster slides jump higher, up to the cap.
- There is no extra button and no hold timing.
- The velocity is never reset and the camera is untouched.
- The launch is re-applied only for the first 0.1 s, and only if Roblox's own jump overwrote it.
  - Fixed during testing: the first version also cancelled gravity in that window and added about 7 studs of height.
- Wall-runs still catch from the air.
- `Slide.PowerJump = 0` restores the Step 1C slide-jump for comparison.

### Run, slide and wall-run (provisional)
- **Run speed:** 30 → 36.
  - Carried speed now drains at a fixed 8 per second on the ground. The old formula would have nearly stopped draining at the new run speed.
- **Slide entry boost:** 8 → 16. The entry-speed cap went from 46 to 58, so boosts up to +20 are not silently discarded. A boost still only applies once per 0.9 s.
- **Wall-run:**
  - Entry boost: 3 → 5.
  - Top speed: 50 → 60, so fast arrivals are no longer cut to a low cruise.
  - This is still a hard cap, so chaining walls cannot keep accelerating.

### Server checks
- **Carried speed:** speed carried out of a slide or wall-run keeps that state's speed cap for 1 s.
- **Upward speed:** anything above 58 studs/s up is logged, except within 0.5 s after a slide the server accepted (cap 96 there). Only a real Power Slide Jump can launch high.
- **Slide-start re-check:** if the server's copy shows too little speed when a slide starts (seen right after spawns and teleports), it re-checks 0.2 s later before rejecting. The lowered hit volumes only apply once the speed is plausible.

### Animation (procedural, no assets)
- **Push-off:** legs drive down and back, and the free arm swings up.
- **Airborne:** blends into a tuck, with knees up, the disc arm forward and the free arm out.
- **Return:** fades back to the normal animations as the character starts to fall.
- Other players see it from the existing move-state data plus the rising speed; there is no new network traffic.
- The slide pose and blended hit volumes are unchanged from Step 1C.

### Input fix (found in owner testing)
- In Studio test windows, Left Ctrl+A and Ctrl+D are Studio's Select All and Duplicate. Sliding sideways with Ctrl therefore duplicated every character and the yard in that window.
- **Slide is now Left Shift**, which is also Sojourn's key, **or C, or gamepad B**. The touch SLIDE button is unchanged.
- Roblox's shift-lock option is turned off in the Core Round place. Core Round has its own aim lock.

### Test yard
- New `Step1D` folder: ledges 8, 12, 16 and 20 studs high at x 160–208, z −20, each with a marked 70-stud run-up.

## Measured results (Studio, real keys)

### Run speed (2 s from standing)
| Run speed | 34 | 36 | 38 |
|---|---|---|---|
| Distance | 68.5 studs | 72.0 studs | 75.8 studs |

Step 1C ran at 30 and covered 57 studs.

### Slide entry boost (run 36, slide held to the end)
| Boost | Entry speed | Slide distance | Distance in 2 s |
|---|---|---|---|
| 12 | 48 | 80 studs, 2.55 s | 74.4 studs |
| 16 | 52 | 96 studs, 2.85 s | 81.0 studs |
| 20 | 56 | 113 studs, 3.17 s | 87.9 studs |

### Jumps (flat ground; jump pressed 0.45 s into the slide)
| Jump | Launch up / forward | Rise | Distance | Airtime |
|---|---|---|---|---|
| Normal running jump (run 36) | 50.5 / 36 | 6.4 studs | 19.2 studs | 0.53 s |
| Step 1C slide jump | 50.5 / ~32 | 6.4 studs | 17.3 studs | 0.53 s |
| Power Slide Jump, boost 12 | 79.6 / 28.6 | 16.0 studs | 29.8 studs | 0.83 s |
| Power Slide Jump, boost 16 (default) | 81.9 / 31.2 | 17.0 studs | 30.5 studs | 0.85 s |
| Power Slide Jump, boost 20 | 84.4 / 34.1 | 18.0 studs | 31.8 studs | 0.88 s |

- **Height vs forward speed:** at the default, a 46 studs/s slide becomes 31 forward plus 82 up.
- **Rejected launch value:** a first launch of 68 (rise 13.8) could not reach the 16-stud ledge.

### Ledges, with a normal flat slide at the default
| Ledge | Result |
|---|---|
| 12 studs | Landed on top |
| 16 studs | Landed on top |
| 20 studs | Not reached |

A 20-stud ledge needs a faster slide, such as downhill, near the 90 cap. Jumping on the 20° slope at 50 studs/s rose 14.7 studs before the launch was retuned to 76.

### Slide → Power Slide Jump → wall-run
- Launched at 82 up and caught wall A at 36 studs/s.
- Ran 37 studs to the wall's end and left at 41.

### Wall entry boost (running jump onto wall A, same approach of 35.5)
| Boost | Wall-run speed | Wall-jump exit | Second-wall run |
|---|---|---|---|
| 3 | 38.6 | 51.0 | 45.6 |
| 5 | 40.5 | 52.6 | 49.5 |
| 8 | 43.5 | 55.1 | 55.5 |

### Chaining
- Holding slide and pressing Jump about every 1.1 s gave four Power Slide Jumps in a row.
- Each landing slide entered at 52, launches were 82–83 up, and the top horizontal speed was 52. It stays bounded.

### Server checks
- No speed or vertical violations during normal slides, jumps, wall-runs or chains.
- A fake 85-up launch while standing was flagged (`vertical_violation`, 72 against the cap of 58).

### Regression checks
- Stun rules unchanged:
  - 2 head = stun;
  - 2 body + 1 head = stun;
  - 3 body = no stun (meter 90).
- Full-charge throw (speed 200) into a front shield: blocked.

### Two clients (round trip ~0.026 s, Left Shift slide)
- **Hit volumes:** the slide weight B saw drawn for A, compared with the server's weight at A's rewind time, differed by at most 0.15. There were no frames where A looked upright while judged as sliding.
- **Pose:** on B's screen A rose 16.8 studs, with the tuck (hip 68°) and push-off arm (112°) visible.
- **Copies:** each client had exactly 2 characters.

## Captures (local)
`C:\WORLD.EXE-Art\CoreRound\evidence\captures_1d\`:
- `before_after_side.jpg`: the same side camera, Step 1C slide jump vs Power Slide Jump.
- `ledge16`: landing on the 16-stud ledge.
- `pose_follow`: launch sparks and arc.
- `psj_to_wallrun`: slide into wall-run.

## Future authored animation needed for professional quality
The procedural poses communicate the moves, but they are stiff. Custom animations would need an owner decision on uploads. Needed:
1. **Slide entry:** a drop into a low lean-back slide with the lead leg out, plus a sliding loop with small adjustments.
2. **Power Slide Jump push-off:** a fast anticipation followed by an explosive two-leg extension.
3. **Airborne:** a rising tuck, an apex hang and a falling stretch.
4. **Landing:** a soft absorb, chained back into the run cycle.
5. **Wall-run:** a dedicated loop with a hand brushing the wall, plus a wall-jump kick-off.

Other improvements that would help: feet-planted ground alignment while sliding (IK), and motion-matched blends from run to slide.

## Remaining issues and limits
- All new values are provisional, pending the owner's playtest: run 36, slide boost 16, launch 76/0.6/90, wall boost 5, wall top speed 60.
- Wall top speed 60 combined with boost 8 gives wall-jump exits near 55. The server cap is 74.
- Untested on real mobile devices and controllers. Jump is Roblox's standard jump button on every input, and touch SLIDE is a toggle.
- The server's upward-speed check only logs; nothing is enforced.

## Follow-up: wall jumps push further (owner feedback, 2026-11-21)
The owner asked to be able to jump further away from a wall while wall-running.

**New values (provisional):**
- Push away from the wall (`WallRun2.JumpOut`): 28 → 48.
- Upward kick (`JumpUp`): 40 → 48.
- How long the push is kept against air control (`JumpCarrySeconds`): 0.35 → 0.6.

**Measured on open ground**, from the wall jump to landing (run speed 36, holding forward):

| Setting | Away from the wall | Total distance | Airtime |
|---|---|---|---|
| Old (28 / 40 / 0.35) | 12.3 studs | 26.3 studs | 0.55 s |
| Push 40, kept 0.5 s | 21.1 studs | 31.9 studs | 0.53 s |
| Push 40, kept 0.5 s, kick 48 | 23.5 studs | 35.4 studs | 0.62 s |
| **New (48 / 48 / 0.6)** | **29.4 studs** | **40.3 studs** | **0.62 s** |

**Chaining fixes**
- Detection: a steeper push meant the next wall was mostly in front of the character, and wall-run detection only looked sideways. For the 0.6 s after a wall jump, it now also looks straight along the push direction.
- Test course: the wall-run course walls were raised from 16 to 24 studs, because the stronger jump reached the top of the 16-stud walls.
- Result: the chain wall A → wall B now catches wall B at 65.6 and runs 64 studs (1.3 s) to its end.

**Server**
- Wall cap raised from 74 to 86 (the largest exit is (60 + 4) along + 48 out = 80).
- No speed or vertical violations.

Capture: `captures_1d\walljump_far`.

## Follow-up 2: controllable wall jumps (owner feedback, 2026-11-21)
The owner reported that the outward wall force wasn't controllable enough. The previous version pushed a fixed 48 away and locked the flight for 0.6 s.

**Now the camera aims the wall jump (third person, aim lock):**
- **How hard you push off:**
  - looking along the wall gives the standard push (`JumpOutNeutral` 40);
  - looking away from the wall raises it to the full 48 (`JumpOut`);
  - looking toward the wall lowers it to 20 (`JumpOutMin`), but you always leave the wall.
- **Launch direction:** turns 35% of the way toward where you look (`JumpAim`), never back into the wall.
- **Steering in the air:** during the push, sideways keys (A/D or a diagonal) curve the flight at 1.2 rad/s, keeping the speed (`JumpSteerRate`). Plain W does not steer; it means "keep going".

**Rejected first version.** I first let the movement keys decide the push. With W held (the normal way to wall-run), the jump barely left the wall: 0.5 studs out, and it re-caught the same wall. Steering at 2.5 rad/s was also too strong.

**Measured on open ground**, from the wall jump to landing, holding W:

| Case | Lands this far from the wall | Total distance |
|---|---|---|
| Look along the wall (standard push 34, tried first) | 13.1 studs | 34.2 studs |
| **Look along the wall (standard push 40, chosen)** | **15.7 studs** | **36.4 studs** |
| Look 35° away (standard 34 / 40) | 23.4 / 24.7 studs | 37.4 / 38.5 studs |
| Look 30° toward the wall (standard 34) | 7.7 studs | 31.9 studs |
| Look along, steer toward the wall (A) mid-air (standard 34) | 6.3 studs | 33.7 studs |
| Look along, steer away (D) mid-air (standard 34) | 18.9 studs | 33.8 studs |

- Looking further away reaches the full 48 push; at 90° it is about 29 studs, as measured for the fixed-48 version.
- **Chaining** wall A → wall B still works: caught at 58.8 and ran 55 studs.
- **Server:** no violations.

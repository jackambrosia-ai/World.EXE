# Core Round Step 1B: movement and combat tuning

Owner feedback pass on the Step 1 prototype (movement, Rebound Disc, holographic shield). Isolated place only. No Step 2 work (no guardians, fragments, theft, patches, extraction or collapse).

## Places and hashes
| | Path | SHA-256 |
|---|---|---|
| Step 1 (kept, unchanged) | `C:\WORLD.EXE-Art\CoreRound\place\WorldEXE_CoreRound_2026-11-20.rbxlx` (+ `backup_step1_2026-11-20`) | `f8cf4b0a1d5dead43cc9822b74f5e3b51d36df5eeeb1927fde847c0dd128dc9e` |
| Step 1B (new) | `C:\WORLD.EXE-Art\CoreRound\place\WorldEXE_CoreRound_Step1B_2026-11-21.rbxlx` (+ `backup_step1b_2026-11-21`) | `1f2718ec71a707df41390cd7b4a0699759e1e19066451f16dcb2293495f17e9d` |

Saved-place parity: `cr_40_verify_saved.js` reads 22/22 scripts identical to `src/`, with no extra scripts. The Step 1 commit `b3651ff` is unchanged on the branch history.

## References studied
- **Fortnite movement docs:** crouch while sprinting starts a slide; downhill slides are faster; jump ends the slide.
- **Warframe quickstart:** a bullet jump out of a slide.
- **Titanfall 2 "Mobility and Momentum" video** (streamed, no SHA):
  - a slide gives a strong initial boost that dials back, so paced chaining is rewarded;
  - you can buffer a slide by tapping mid-air;
  - anything waist-high is a short wall-run surface;
  - bouncing between walls keeps momentum;
  - slowing players while they fire kills the pace.
- **Titanfall controls interview:**
  - gravity comes on gradually during a wall-run;
  - wall-runs and wall jumps add speed;
  - the view tilts away from the wall;
  - the camera should not move unless the player asks;
  - landings have a spring.
- **Knockout City** (streamed, no SHA):
  - tap to throw, hold to charge a faster throw;
  - the held ball glows while charging;
  - a screen-edge warning shows where a throw is coming from.
- **TRON:** the disc and arena look only.

Frames were not saved.

## What changed

### Slide (new, primary movement upgrade)
**Controls:** hold Left Ctrl, C or ButtonB. On touch, tap SLIDE to toggle.

**How it moves**
- Starts at 16 studs/s or faster.
- Entry boost of +8, with a 0.9 s cooldown and a 46 cap.
- Friction 13; slopes accelerate it up to 58.
- Light steering; a 3.5 s cap; 0.12 s of coyote time.
- Jumping out carries your speed plus 2 (a slide-hop).
- A landing buffer: hold slide in the air and it starts when you land.

**Presentation**
- Procedural lean-back slide pose. It is drawn on every client from `CR_MoveState` and works on R15/R6 and AnimationConstraint rigs. No assets.
- Scrape sound and sparks; the sparks are off with Reduced FX.

**Server**
- The server validates the slide start (it needs half the start speed).
- While sliding, hit volumes are lowered:
  - head at root +0.5;
  - body from -1.9 to 0.0.

### Wall-run v2 (Titanfall-informed; `WallRun2.Mode` 2 = v2, 1 = old wall-run for comparison)
**Entry and run**
- Entry is automatic: jump along a wall while moving.
- The run is horizontal and keeps your momentum:
  - entry +3, a 26 minimum, accelerates toward 38 (cap 50);
  - no auto climb (upward speed is kept up to 12);
  - gentle wall gravity of 18;
  - no snapping.
- Waist-high surfaces count.

**Ending and jumping**
- The run ends at the wall's edge, if you peel away, on landing, after 1.8 s, or when you jump.
- A wall jump pushes you out and up, adds +4 to speed, and keeps that push for 0.35 s so you can chain to the opposite wall.
- Fix found in testing: a wall jump now needs a fresh jump press. Holding Space from takeoff no longer ends the run after 0.017 s.

**Presentation:** a 10° body lean and a small camera push away from the wall. No camera roll.

### Super Dash comparison
The `CoreTune_Move_SuperEnabled` and `CoreTune_Move_DashEnabled` switches control it. The server refuses disabled moves.

### Charged Rebound Disc
- **Controls:** MB1 or R2. A tap of 0.15 s or less is a normal throw; holding charges it fully in 0.9 s. Releasing throws.
- **The server times the charge** from the press and release it receives. A client claim can only lower it, or raise it by up to 0.08 s of slack.
- **Charging does not slow you.** You can charge while running, jumping or sliding.
- **Unchanged:**
  - no extra damage or stun;
  - shields still block;
  - stun combos are the same;
  - one counted hit per target per throw.

**Presentation**
- The held disc glows, and a 12-dot ring fills around the crosshair.
- Other players see your charge.
- There are tick and max sounds.
- Charged throws get a hotter trail.
- New threat arrows point toward incoming enemy discs (inspired by Knockout City).

### Camera
The third-person camera is unchanged at its core. Additions:
- an eased offset and a clip guard;
- the view drops 1.1 while sliding;
- a wall-run bias;
- a landing dip (off with Reduced FX);
- a gentle speed FOV of up to +9, halved with Reduced FX.

There is no first-person view and no camera roll.

### Correctness and security
- The shield yaw now rejects NaN and inf and wraps large values.
- Shield panels are checked at the rewound time.
- Stuns and raising the shield clear any charge.
- **Speed monitor** (detection only, logs `speed_violation`). Caps per validated state:

| State | Cap (studs/s) |
|---|---|
| Run | 52 |
| Slide | 64 |
| Wall-run | 58 |
| Dash / Super Dash window | 125 |

- **Teleport monitor:** it now checks a 0.25 s window. The old single-frame check missed a 60-stud client teleport because the server receives it smoothed over several frames.

## Measured results (solo, Studio)

### Slide
| Case | Result |
|---|---|
| Flat | entry 38, 47 studs, 1.8 s |
| 10° slope | holds 38, 97 studs |
| 20° slope | peak 51, 135 studs (time cap) |
| 30° slope | peak 58 (cap), 155 studs |
| Slide-jump | carries 34.6 |
| 7-hop chain | entry 38 rising to 42.1 (converges below the 46 cap) |

### Wall-run v2 (real keys)
- Wall A: entry 29–30, 1.0–1.1 s, 36–41 studs along, rise +2.8 to +3.7.
- Wall jump: exits at 50.
- Wall B caught at 50; chain speeds 42–45.
- Old v1 with the same input climbed about 15 studs.

### Charged disc (server-confirmed)
| Hold | Charge | Speed | Range |
|---|---|---|---|
| 0.05 s | 0 | 130 | 70 |
| 0.62 s | 0.52 | 166 | 94 |
| 1.13–1.22 s | 1.0 | 200 | 115–117 |

- A forged full charge after 0.05 s: the server used 0.08.
- A throw with no charge start: the server used 0.
- A full-charge throw at the shielded dummy was blocked.

### Traversal in 2 s from standstill (flat lane)
| Case | Distance | Peak speed |
|---|---|---|
| Run | 57 studs | 30 |
| Flat slide | 55 studs | 38 |
| Dash | 83 studs | 105 |
| Q Q with Super off (two dashes) | 98 studs | 105 |
| Dash + Super Dash | 119 studs | 105 |

### Slide hit volumes (shared server geometry, 130 st/s steps)
| | Head | Body | Miss |
|---|---|---|---|
| Standing | +1.5 to +3.0 | below | – |
| Sliding | +0.5 to +1.8 | 0.0 to -2.0 | above +2.2 |

A live dummy throw at a sliding player hit BODY at -1.0. Two predicted head-height throws missed: the aim was predicted from the target's motion, and player rewind applies even to server test throws.

### Monitors
- 150 st/s held for 0.8 s → `speed_violation` (state run, cap 52).
- Three test teleports (51–99 studs) → all flagged.
- Real dash, Super Dash and slide → nothing flagged.

### Other checks
- Reduced FX: slide sparks off; peak FOV during the slide was 70.8.
- Controller codes:
  - ButtonB started a slide;
  - ButtonX dashed;
  - holding R2 for 1.13 s threw at full charge.

## Captures (local, never committed)
- **Step 1B** (`C:\WORLD.EXE-Art\CoreRound\evidence\captures_1b\`): `slide_slope2` (slide pose and sparks), `wallrun` (v2 run and chain), `charge` (held disc and ring). The player list is redacted.
- **Step 1 "before"** frames: `C:\WORLD.EXE-Art\CoreRound\evidence\captures\`.

## Recommended defaults
- **Slide:** keep as tuned.
  - A flat slide is not faster than running over 2 s. The gain comes from slopes, hops and the lower profile, which matches the references.
  - If flat slides should feel faster, raise `Slide.EntryBoost` (8 → 10–12).
- **Wall-run:** v2 on by default (`Mode` 2). If it still feels unnatural in the owner playtest, defer wall-running rather than tune further.
- **Super Dash:**
  - Lean: weaken or defer. Slide and wall-run now carry momentum, and Super Dash adds about 21 studs over two plain dashes.
  - It also forces the loose 125 speed cap.
  - Keep it on for the playtest so it can be compared. Turn it off with `CoreTune_Move_SuperEnabled = 0`.
- **Charged disc:** keep 0.9 s, 200 speed and 115 range.

## Remaining issues and limits
- **Two-client PvP for Step 1B:** pending. The owner starts "Server & Clients". Step 1's two-client results still stand for the unchanged systems.
- **Controller:** tested by injecting button codes, not a physical pad. Stick aim and the gamepad camera are untested.
- **Mobile:** the touch buttons exist (SLIDE, DASH, DISC, SHIELD) but have not been tested on a device or emulator. Hold-to-charge on touch uses the DISC button's hold.
- **The speed and teleport monitors only log.** Enforcement comes later. Server-set teleports (respawn pads, tests) would also be logged.
- **Slide pose:** procedural, so it looks stiff. Real animations are future art work, with no uploads in this step.
- **Not implemented:** the Knockout City overcharge-on-catch idea was noted only.

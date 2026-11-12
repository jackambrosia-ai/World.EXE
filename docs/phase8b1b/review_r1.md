# Phase 8B-1B — Review round 1 corrections (2026-11-11)

These are corrections to ChatGPT's review of `cf97737`, all client presentation only. Server gameplay, remotes, the catalog, the map, environment effects and timing are unchanged. Changed modules: `UITheme`, `HUDController`, `ArchitectController` and `AbilityController` (`UIUtil` is unchanged).

All tests are **solo Studio** playtests. The touch layouts use the Studio-only layout preview (`WORLD_EXE_UITest`), so **every "touch" result below is emulated, not a device test**. No real-device, gamepad or multiplayer result is claimed.

## What changed

### Shared layout contract (UITheme)
The controllers now publish their screen rectangles (root-relative pixels):

- `"hudTop"`: the HUD's top row;
- `"abilities"`: the touch ability buttons together with the native jump button;
- `"architect"`: the open Architect tray.

`UITheme.touchPanelRegion(size)` returns the free area for touch panels: right of the native thumbstick zone, below `hudTop`, and above the ability/jump controls. It updates whenever a published rectangle changes.

### Priority 1: Details panel vs ability buttons (HUDController)
- The Details content is now a `ScrollingFrame`. The panel's height is capped to the free area, so it never grows into the controls, and it scrolls instead of clipping.
- Placement picks the largest free rectangle:
  - **Touch landscape:** right of the thumbstick zone and left of the ability buttons, full height. It moves below the Architect tray while the tray is open.
  - **Touch portrait:** above the ability buttons.
  - **Desktop:** top right, moving left of the Architect panel while it is open.
- The ability buttons were not moved into the native jump or thumbstick zones.
- The Details panel now closes when the results card appears (it used to sit underneath the card).

### Priority 2: Architect tray on touch, and warning priority
- **Tray placement:** the tray fills `touchPanelRegion` with **fixed heights** derived from that region, so no state (default, selected, pending, rejected) can grow into the movement zone.
  - **Landscape:** one row of 4 chips plus a side column (timer and CONFIRM), with a 36 px info line (3 lines of 12 px).
  - **Portrait:** a 2×2 grid plus a footer, with a 60 px info line (5 lines).
- **Warning priority:** on touch landscape the warning strip, combination strip and toasts now live in a **top-left alerts column** above the thumbstick zone. That is a separate horizontal band from the tray (which is always right of the thumbstick zone), so a warning can never be hidden by the tray. The warning period is unchanged (server-defined).
  - **Portrait:** the alerts sit under the patch chips and are included in `hudTop`, so the tray lays out below them.
  - **Desktop:** unchanged (under the pill).
- **Chip reveal:** chips are built with the grid hidden and revealed after one layout pass, so they never flash stacked on one cell.

### Priority 3: Readability
- **Touch chips:**
  - the name is 12 px, dropping to 11 px for long names via `UITextSizeConstraint` (min 11, max 12);
  - the state label is 11 px (was 9);
  - the decorative serial text and circuit traces are removed when compact;
  - the effect and counterplay move to the info line, which shows "Tap a chip to see what it does, then CONFIRM." until a chip is chosen;
  - the CONFIRM labels are short (PICK A CHIP / CONFIRM / SENDING… / UPLOADED).
- **Desktop chips:** the state label is 11 px (was 9) and the serial 10 px (decorative).
- **HUD:** patch-chip codes are 11 px (was 10).
- **Ability buttons:**
  - every button has a short label: **DASH / ANCHOR / SCAN** at 11 px;
  - touch buttons are 60 px (was 56), with the label inside the circle's widest band;
  - the desktop key hint is 11 px (was 10).

## Measured rectangles (root-relative px, from `AbsolutePosition` / `AbsoluteSize`)

Native zones come from the documented geometry (thumbstick = left 40 % × bottom 55 %; jump = 70 px for screens with min(w,h) ≤ 500).

### 844×390 (emulated)
| Element | Rect |
|---|---|
| Native thumbstick zone | (0,175)–(337,389) |
| Native jump | (749,300)–(819,370) |
| ANCHOR / DASH / SCAN | (683,232)–(743,292) / (677,309)–(737,369) / (758,228)–(818,288) |
| TopCenter / TopRight | (342,6)–(502,52) / (784,6)–(834,50) |
| Architect tray | (345,58)–(833,196) |
| Details (tray closed) | (399,60)–(669,333): 8 px left of the ability buttons |
| Details (tray open) | (399,204)–(669,382): below the tray |
| Alerts (toast) | (10,6)–(216,26) |

Overlap check run in every recorded state (default, selected, rejected, closed): **no overlaps** among the tray, Details, warning, toast, top row, ability buttons, jump and thumbstick.

### 740×360 (emulated)
| Element | Rect |
|---|---|
| Native thumbstick / jump | (0,162)–(296,360) / (645,270)–(715,340) |
| ANCHOR / DASH / SCAN | (579,202)–(639,262) / (573,279)–(633,339) / (654,198)–(714,258) |
| Architect tray | (304,58)–(730,190) |
| Details (tray closed / open) | (304,60)–(565,333) / (304,198)–(565,352) |
| Warning strip (after accept) | (10,6)–(288,74): left of the tray region (x ≥ 304) |

No overlaps in any recorded state.

### 390×700 portrait (emulated)
Tray (164,132)–(380,452), a 2×2 grid; Details below it at (164,460)–(380,530), scrolling; ability buttons start at y = 538; thumbstick zone (0,315)–(156,700). No overlaps.

### Text fit (TextService, same font and size as the labels)
| Layout | Info width / box | Worst catalog text | Fits |
|---|---|---|---|
| 844 strip | 472 / 36 px | 24 px (DECAY) | yes |
| 740 strip | 410 / 36 px | 36 px (CORRUPTION) | yes (exactly 3 lines) |
| 932×430 strip | 525 / 36 px | 24 px | yes |
| 390×700 portrait | 200 / 60 px | 60 px (MAGNETIC) | yes (exactly 5 lines) |

`TextFits` was also true at run time for the info line and the CONFIRM label in every recorded state, and for every chip name in the measured 844 and portrait trays. CORRUPTION, the widest name, is 76 px at 12 px and 70 px at 11 px; the 740 chip leaves 71 px for it.

## Focused test results

| # | Case | Result |
|---|---|---|
| 1 | 844×390 (emulated): Details open does not overlap the ability buttons, jump or thumbstick; content scrolls | PASS (`r1_03`) |
| 2 | 740×360 (emulated): Details open, ability clearance | PASS (`r1_04`) |
| 3 | Architect tray default / selected / rejected at 844 (emulated): stays inside the region, no overlaps, text fits | PASS (recorded rects; `r1_01`, `r1_02`) |
| 4 | Rejected state: off-offer `ZERO_G` request, server `not_offered`, chip "× REJECTED", coral info "That patch is not on your chips." | PASS (recorder log) |
| 5 | Warning vs tray: warning strip in the left alerts column, geometrically separate from the tray region; full server warning period | PASS (emulated; measured) |
| 6 | **Touch-layout submission in one genuine turn (emulated 740×360):** tray opened 196.15, chip SUPPLY_DROP selected 202.93, CONFIRM 204.35, server `accepted` 204.42, console `amfam1 -> accepted SUPPLY_DROP`, tray closed, "Patch uploaded.", warning strip shown, then the patch went ACTIVE | **PASS** (8.3 s after open) |
| 6b | Same flow at 844×390 (emulated): FLOOD selected 631.12, CONFIRM 632.52, `accepted` 632.59 (about 2.6 s after the tray opened), FLOOD ACTIVE | PASS (build before the final cosmetic tweaks) |
| 7 | Desktop Architect acceptance (real mouse, native viewport): CORRUPTION chip, CONFIRM, `accepted`, panel closed, CR chip live | PASS (`r1_09`) |
| 8 | Desktop: Details moves left of the open Architect panel (x 1300–1570), then returns to the top right (1634–1904) | PASS |
| 9 | Ability cooldown feedback: Q starts the Dash cooldown (shade + seconds) on touch; desktop bar shows DASH/ANCHOR/SCAN with Q/F/R | PASS (`r1_03`, `r1_09`) |
| 10 | RESULTS: card shown; Details closes automatically | PASS (`r1_10`; `r1_08` is the before-fix overlap) |
| 11 | RESET → match 2: no stale results, Details or patch chips; GUI descendants 180 | PASS |
| 12 | Source parity 44/44 (Studio vs `src/`) | PASS |
| 13 | Output: no game warnings or errors (one error came from an MCP test script typo, not game code) | PASS |
| 14 | Edit place clean after tests: no `ZZ_`, no `StudioTimeScale`, preview attribute never saved | PASS |

### How the touch submission was made repeatable (test method, not game timing)
Each MCP round trip takes about 5–12 s, against the unscaled 12 s submission window. The working sequence:

1. A client call returns about 4 s before the server's `NextTurnAt`.
2. One pre-scheduled mouse batch then waits through the opening and clicks the chip, then CONFIRM.

This needs no extra round trips, and gameplay timing was not changed.

**Diagnosis recorded during testing:** in the emulated layouts, clicks aimed at **chip 1** never reached the game, while chip 2/3 and CONFIRM worked. The cause is Roblox's own **chat window and chat input bar** (core UI, drawn above game UI). They occupy viewport (8,12)–(483,235) in Studio, which is where the 844×390 preview draws chip 1. That is a property of the preview position, not a UI defect; the desktop panel sits on the right and is unaffected. Tests therefore used chips outside that area.

## Remaining limitations (not claimed)
- Real touch devices, notches and safe areas; real-device performance.
- **Roblox chat window on mobile:** if a player opens chat on a phone, the core chat window may cover the top-left alerts column and the left edge of the tray. This is untested on a device and would be a candidate for a later, separately approved adjustment (for example, nudging the alerts column or tray when chat is visible).
- Gamepad hardware: the code paths (DPadDown Details, ButtonB clear, chip focus after reveal) were not exercised.
- The keyword-search path on desktop was not retested in this round (its code is unchanged).
- Multiplayer, including the non-Architect view.
- Full-frame 1920×1080 and 1366×768 (Studio viewport is 761 px tall).

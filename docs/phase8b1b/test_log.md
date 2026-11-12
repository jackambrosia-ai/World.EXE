# Phase 8B-1B — UI implementation test log (2026-11-11)

All tests are **solo Studio playtests** driven through Studio MCP (one server + one client in Play mode).
Touch layouts were checked with the **Studio-only layout preview** (`WORLD_EXE_UITest = "WxH:touch"`
on the LocalPlayer, honoured only when `RunService:IsStudio()`), which lays the UI out inside a frame
of that size and outlines the native thumbstick and jump zones. **These are emulated layout checks, not
device tests.** We make no claim about real touch, gamepad, multiplayer or device performance.

Studio viewport during testing: 1914×761. Full 1920×1080 and 1366×768 frames cannot be displayed in
that viewport, so the desktop checks ran at the native viewport (compact mode, h < 820) plus a
1366×700 preview.

## Architecture (as built)

| Module | Role |
|---|---|
| `UITheme` (new) | Colour/font tokens, category + patch glyphs, `layout()` (desktop / compact / touch), native touch zone geometry, session-only Reduced Effects, Studio layout preview |
| `UIUtil` | Instance helpers, themed surface/text/bar, `screen()` root (safe-area `CoreUISafeInsets`) |
| `HUDController` | Top-centre phase pill + timer + stability bar; warning strip; combination strip; toasts; top-right patch chips; Details panel (G / DPadDown / ≡ button); results card |
| `ArchitectController` | Cyber-chip cards (all states) and confirm/clear; sends only `{patchId}`; TurnKey stale-turn guard; rejection feedback |
| `AbilityController` | **Touch Option B**: CAS binds with `createTouchButton = false`; custom slots (desktop bar / touch arc around the jump button) |

There are no new remotes and no server changes. `MatchStateClient` is still the only Snapshot reader, and all timers use `GetServerTimeNow`.
Tab is not bound. Gamepad bindings (ButtonX/ButtonY/ButtonB/DPadDown) are ignored while `GuiService.SelectedObject` is set.

## Results

| # | Case | Result | Evidence |
|---|---|---|---|
| 1 | Lobby: pill shows the lobby state; no patch chips | PASS | `01_desktop_lobby.jpg` |
| 2 | Countdown pill + mono timer counts down (server time) | PASS | console + live read |
| 3 | ACTIVE: pill, timer, stability bar with target tick and number | PASS | `02`, `05` |
| 4 | Architect panel opens **only** on the local player's turn; closes on timeout | PASS | console `-> timeout`; panel `Enabled=false` after |
| 5 | Chip states: default, hover/focus, selected (effect + "Counter:" hint) | PASS | `02`, `03` |
| 6 | Confirm sends `{patchId}` only → accepted (MAGNETIC) → panel closes, upload toast, warning strip | PASS (desktop, real mouse) | `05`, console `accepted MAGNETIC` |
| 7 | Rejection path (off-offer request) → `not_offered` → chip REJECTED + coral feedback | PASS | `14` (superseded touch layout; same handler) |
| 8 | Disabled/pending/submitted states | PASS (state function exercised in 6 and 7) | — |
| 9 | Warning strip lasts the full server warning period, with a countdown and counterplay text; SEVERE shown in coral | PASS | `05`, `16` |
| 10 | Patch goes ACTIVE → amber warning chip becomes an active chip with a time bar | PASS | `06`, live reads (the chip list comes from the Snapshot, so expired patches drop out; not timed separately) |
| 11 | Combination announcement (violet strip, 4.5 s) + ★ COMBO chip | PASS | `06` |
| 12 | FINAL_PHASE: coral pill | PASS | `08` |
| 13 | RESULTS card from existing `LastResult` data (header, own row, top-6, rewards, next lobby) | PASS | `09` |
| 14 | RESET → match 2: no stale results/chips; GUI descendant count 277 → 177 (no leak) | PASS | live read |
| 15 | Details panel: G toggles; ≡ button toggles; hidden by default; Reduced Effects toggle | PASS | `04` |
| 16 | Q → Phase Dash fires; cooldown shade + seconds | PASS | `04` |
| 17 | Touch 844×390: HUD + ability arc clear of the jump and thumbstick zones | PASS (emulated) | `10`, `11` |
| 18 | Touch 740×360 | PASS (emulated) | `12` |
| 19 | Portrait 390×700: top-right chips move under the pill | PASS (emulated) | `13` |
| 20 | Touch Architect "strip" layout above the thumbstick zone; chip tap → ✓ SELECTED | PASS (emulated; mouse-driven) | `15`, hook log `Chip_BLACKOUT … ACTIVATED … ✓ SELECTED` |
| 21 | Touch strip Confirm → accepted | **LIMITED** — the Confirm `Activated` handler fired in strip mode, but every end-to-end attempt missed the unscaled 12 s window because of MCP call latency (turns 1–11 timed out). The same confirm path passed on desktop (#6). | console |
| 22 | Turn-skipped toast | PASS | `17` |
| 23 | Coverage: desktop 1366×700 ≈ 2.6 % ; touch 844×390 ≈ 5 % (estimate from frame rects) | PASS (< 8 %) | `07`, `10` |
| 24 | Output: 0 new warnings/errors from game scripts (only MCP test-script errors) | PASS | console |
| 25 | Edit place clean after tests: no `ZZ_`, no `StudioTimeScale`, no preview attribute | PASS | live read |
| 26 | Parity: 44/44 Studio sources identical to `src/` (length + hash) | PASS | — |

## Not tested (not claimed)
- Real touch devices, notches and safe areas on hardware.
- Gamepad navigation on hardware. Only the code paths exist: DPadDown Details, ButtonB clear, initial chip focus.
- Multiplayer, including another player's Architect turn as seen by non-Architects.
- 1920×1080 and 1366×768 shown full-frame (Studio viewport limit).
- Device performance.

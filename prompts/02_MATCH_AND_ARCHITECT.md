# Phase 2 — Match lifecycle and Architect selection

Implement the explicit state machine: LOBBY, COUNTDOWN, INITIALIZING, ACTIVE, FINAL_PHASE, RESULTS, RESET.

Implement:
- Minimum-player policy and countdown cancellation.
- Match generation/session ID to invalidate stale callbacks.
- Safe player join/leave/death behavior.
- Server-owned participant states.
- Fair Architect selection/queue; avoid consecutive repeats when alternatives exist.
- 10–12 second submission window.
- Approved PatchId/alias validation and safe timeout fallback.
- Replicated match state and placeholder Architect UI.

Only MatchService may change match state. Only the current eligible Architect may request a submission. Test invalid requests, player leaving during a turn, insufficient players, repeated state resets, and basic multi-client flow where available. Do not implement patch behaviors yet.
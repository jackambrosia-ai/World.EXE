# Phase 10 — Final hardening and release candidate

Run a full regression and multiplayer verification pass:
- Match lifecycle, Architect fairness, remotes/security, patch cap/lifecycle/cleanup.
- All prototype patches and approved combinations.
- Objective duplication/interruption and score authority.
- Ability cooldowns and exploit attempts.
- Join/leave/reset and repeated-match leak tests.
- Performance at realistic player counts, bounded entities/VFX, memory and task cleanup.
- Desktop and mobile layout/input checks.
- Accessibility and audio-disabled warning checks.
- Published private-place DataStore test and backup check.

Produce a release-candidate report with test matrix, pass/fail, known issues, performance evidence, and unresolved risks. Fix critical issues before recommending release. Never publish or change monetization without explicit owner approval.
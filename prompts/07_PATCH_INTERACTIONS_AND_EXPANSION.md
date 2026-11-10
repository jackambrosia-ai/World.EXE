# Phase 7 — Curated patch interactions and catalog expansion

Build PatchInteractionService using the approved combinations in `docs/03_PATCH_CATALOG.md`. Each combination must have a stable interaction ID, activate once per relevant active source set, and clean up when source patches end.

Start with the five documented interactions. Add launch-catalog candidates only after the four prototype patches and interaction framework pass regression tests. Keep total patch count focused on 10–12 well-tested launch patches. Do not introduce unbounded random combinations or unreviewed stacking. Test every interaction, cap behavior, source expiry, simultaneous activation, and match reset.
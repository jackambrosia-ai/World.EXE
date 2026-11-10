# Phase 3 — Patch engine foundation

Implement a data-driven PatchService and central WorldModifierService.

Each runtime patch must track a unique runtime ID, PatchId, server-assigned creator UserId, match generation, start/expiry times, lifecycle state, owned instances/connections/modifier tokens, and idempotent cleanup.

Lifecycle: validate -> reserve capacity -> announce -> warning -> revalidate -> activate -> track duration -> ending -> cleanup.

Requirements:
- Maximum three concurrent major patches initially.
- Independent lifetimes; do not silently overwrite another active patch.
- Server-owned definitions/configuration; client sends PatchId only.
- Failure-safe partial activation rollback.
- Cancellation and cleanup on expiry, match end, reset, error, and shutdown as appropriate.
- Shared global properties use modifier tokens/leases so effective settings are recomputed from active sources.

Build a safe test patch to verify lifecycle before implementing the four real patches. Test over-cap submissions, invalid IDs, duplicate cleanup, failed activation, and reset.
# WORLD.EXE — Project Status

This file is maintained by Claude after each phase. ChatGPT uses it to understand the current implementation state.

## Current state
- Overall status: SETUP BLOCKED — prerequisites pending
- Current phase: Phase 0 — audit received; local toolchain and backup pending
- Current branch: main
- Current PR: none
- Last verified Studio place: Claude reports title Place1.rbxl; on-disk location not yet confirmed
- Source synchronization method: Rojo selected; installation/configuration not yet verified
- Baseline place backup: pending owner action
- StreamingEnabled: reported enabled; recommendation is to keep enabled and design/test around streaming
- Multi-client testing: Claude currently reports solo playtest capability only
- Latest technical review: [ChatGPT Phase 0 review](./PHASE_0_AUDIT_REVIEW.md)
- Last updated: 2026-11-09

## Phase tracker
| Phase | Scope | Status | PR/Commit | Studio test evidence |
|---|---|---|---|---|
| 0 | Audit and setup | Audit reviewed; local prerequisites and backup pending | — | Read-only audit report supplied by Claude; environment not independently verified by ChatGPT |
| 1 | Foundation and arena | Blocked pending Phase 0 gate and owner approval | — | — |
| 2 | Match and Architect | Not started | — | — |
| 3 | Patch engine | Not started | — | — |
| 4 | Four prototype patches | Not started | — | — |
| 5 | Stability/objectives/scoring | Not started | — | — |
| 6 | Initial abilities | Not started | — | — |
| 7 | Interactions and expansion | Not started | — | — |
| 8 | UI and visual polish | Not started | — | — |
| 9 | Progression and persistence | Not started | — | — |
| 10 | Hardening and release candidate | Not started | — | — |

## Latest phase report
Claude's Phase 0 audit report was supplied by the owner on 2026-11-09. Key reported blockers: Git/GitHub CLI and Rojo/Rokit not installed; intended place file location unknown; baseline backup not yet created; current MCP test workflow reportedly solo-only. ChatGPT reviewed the proposed Rojo strategy, recommends preserving StreamingEnabled and scoping the Rojo mapping to WORLD_EXE-owned source containers only.

## Next owner actions
1. Install Git, GitHub CLI, Rokit, Rojo CLI, and Rojo Studio plugin using docs/PHASE_0_AUDIT_REVIEW.md.
2. Authenticate with gh auth login and verify gh auth status.
3. Save a baseline .rbxl copy outside the repository and confirm its exact path.
4. Confirm Claude can clone/pull the private repository and Rojo can connect to the intended Studio session.
5. Approve Phase 1 only after these prerequisites are confirmed.

Claude: after each subsequent phase, update this file with branch, PR, commit, Studio objects/scripts changed, test type/results, Output errors, known risks, and next recommended phase. Do not mark a phase complete when a critical acceptance criterion fails.
## ForgeGUI
- Owner reports Claude has ForgeGUI connected.
- Exact tools/capabilities: pending Claude read-only verification.
- Credit-consuming generation: not authorized by default.
- Asset upload/publication: not authorized by default.
- Studio insertion and functional UI verification: required per asset before marking UI work complete.

# WORLD.EXE — Collaboration Workflow

This document defines how the project owner, Claude, ChatGPT, Roblox Studio, and GitHub work together.

## The one-sentence rule

**ChatGPT plans and reviews; Claude implements and tests in Roblox Studio; GitHub carries the agreed specifications, code, and evidence; the owner makes scope and release decisions.**

## 1. Assign work to the right assistant

### Ask ChatGPT when you need:
- New gameplay ideas or design decisions.
- Architecture or system breakdowns.
- A technical specification before implementation.
- A review of Claude's commits, code, or test report.
- Debugging analysis based on Studio Output, scripts, or reproduction steps.
- A focused correction prompt for Claude.
- Prioritization and decisions about what to build next.

### Ask Claude when you need:
- Changes made directly inside Roblox Studio.
- Luau scripts, Instances, UI, map objects, and assets assembled in the project.
- Playtests, Output inspection, and in-Studio debugging.
- A completed implementation phase.
- Git commits and pushes of tested work.

### Ask both in sequence when:
- A feature is not designed yet: ask ChatGPT to specify it, save the agreed spec to GitHub, then ask Claude to implement it.
- A feature is implemented: ask Claude to commit/push it with a test report, then ask ChatGPT to review it.
- A bug is found: give Claude the exact reproduction and logs; if its fix is uncertain or architectural, ask ChatGPT to review the proposed fix before Claude applies it.

You do not need to paste the full project history into every message. Refer to the repository and exact phase/file/commit.

## 2. Standard task cycle

1. **Choose one bounded task.** Use one phase or a small feature, not "build the whole game".
2. **Confirm the design.** If requirements or behavior are unclear, ask ChatGPT first. Record the decision in the relevant `docs/` file.
3. **Assign Claude.** Tell Claude the exact prompt file, acceptance criteria, and branch name. Claude should read the latest `main` and work in a local clone with the Roblox Studio MCP connection enabled.
4. **Claude audits before editing.** It identifies affected files/Instances and preserves existing work. For substantial changes, it confirms a backup.
5. **Claude implements and tests.** It must test in Studio, inspect Output, distinguish solo tests from multi-client tests, and record known limitations.
6. **Claude commits and pushes.** Prefer a feature branch and pull request; do not silently commit unfinished work to `main`.
7. **Ask ChatGPT for review.** Provide the PR link or commit SHA and say what review you need. ChatGPT reads the actual changed files/diff, checks design and architecture, and returns prioritized findings.
8. **Claude fixes review findings.** Give Claude the findings or the generated correction prompt. Claude pushes the fixes to the same branch/PR.
9. **Owner accepts.** Merge only after the tests and review are satisfactory. The owner approves publishing, monetization, destructive edits, and scope changes.
10. **Update status.** Claude updates `docs/PROJECT_STATUS.md` after each completed phase.

## 3. Git conventions

- Repository: `jackambrosia-ai/World.EXE`
- `main`: reviewed, accepted project baseline.
- Branch naming: `phase-01-arena`, `phase-02-match-loop`, `feature-zero-g`, `fix-decay-cleanup`.
- Use small, descriptive commits.
- Prefer one pull request per phase or coherent feature.
- Keep docs and implementation synchronized.
- Never commit secrets, access tokens, private player information, or large unreviewed binaries.
- If Claude is using GitHub context sync rather than a local clone, it must still ensure implementation changes are committed from a local workflow that can access the relevant files and Studio session. GitHub context sync by itself is not local Studio access.

## 4. Source synchronization with Roblox Studio

GitHub does **not** automatically keep the live Studio DataModel synchronized with scripts stored in the repository.

During Phase 0, Claude must recommend and confirm one source-sync workflow:
- Prefer Rojo with a checked-in project mapping if the project and user setup support it; or
- Use a documented, tested Studio-MCP-to-source mirroring procedure.

Do not maintain two independently edited copies of the same scripts. Establish which copy is authoritative and how edits are synchronized before significant code work. After edits, verify the code in Studio and the repository contain the same implementation.

## 5. What to send

### When assigning Claude
Send:
- Repository URL.
- Exact prompt file from `prompts/`.
- Desired branch.
- Any additional decisions/constraints.
- Reminder to test, report, commit, and push.

Example:
"Work on Phase 1 only. Read docs/ and prompts/01_FOUNDATION_AND_ARENA.md. Pull latest main, create branch phase-01-arena, inspect and preserve existing work, implement the approved arena blockout in the connected Studio place, run the acceptance tests, update docs/PROJECT_STATUS.md, commit and push, and open a PR. Do not publish."

### When asking ChatGPT to review Claude
Send:
- PR URL or commit SHA.
- The phase/feature.
- What you want reviewed (security, architecture, gameplay, Luau correctness, performance, UI).
- Any actual Studio logs or test results that are not in the PR.

Example:
"Review PR #3 for Phase 1. Inspect the diff and changed files in jackambrosia-ai/World.EXE. Check the arena structure, naming, spawn safety, tags, and whether the code matches docs/02_TECHNICAL_ARCHITECTURE.md. Give me blockers first and a concise correction prompt for Claude. Do not merge."

## 6. Avoid these common mistakes

- Do not have ChatGPT and Claude edit the same files simultaneously.
- Do not ask Claude to implement a feature before its behavior and acceptance criteria are clear.
- Do not assume a GitHub commit proves that the live Studio place was tested.
- Do not assume a screenshot proves server-side behavior.
- Do not allow Claude to publish or make irreversible changes without owner approval.
- Do not merge every commit automatically. Review meaningful phase boundaries.
- Do not ask ChatGPT to diagnose a Studio-only issue without providing the relevant logs, reproduction steps, or a pushed code change.

## 7. What happens when something breaks

1. Reproduce the bug in Studio.
2. Copy the exact Output error and reproduction steps.
3. Ask Claude to diagnose and fix in the current branch.
4. If the fix changes shared architecture or is uncertain, ask ChatGPT to review the proposed fix.
5. Claude applies the fix, reruns regression tests, and pushes.
6. ChatGPT reviews the changed diff and checks that the original issue is addressed.
7. Owner accepts the fix.

## 8. Completion report required from Claude

At the end of every phase, Claude must report:
- Phase and status: complete / partial / blocked.
- Branch, PR URL, and commit SHA.
- Files and Studio objects created/changed.
- Tests performed and exact results.
- Whether tests were solo or multi-client.
- Output errors/warnings remaining.
- Known limitations and risks.
- Manual Studio steps still needed.
- Recommended next task.

Update `docs/PROJECT_STATUS.md` with the same information. Never mark a phase complete if a critical acceptance test failed.

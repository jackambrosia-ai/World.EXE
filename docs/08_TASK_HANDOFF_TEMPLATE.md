# WORLD.EXE — Task Handoff Template

Copy the relevant section into Claude or ChatGPT. Replace bracketed values.

## A. Assign implementation to Claude

Repository: https://github.com/jackambrosia-ai/World.EXE

Task: [one feature or phase]
Prompt file: [prompts/NN_...md]
Branch: [phase-NN-short-name]

Instructions:
1. Pull latest `main` and read `docs/00_MASTER_INSTRUCTIONS.md` plus the relevant design/test docs.
2. Read the specified prompt file.
3. Inspect existing Studio content and identify exactly what will change.
4. Preserve unrelated content and follow backup/approval rules.
5. Implement this task only in the connected Roblox Studio project.
6. Test the acceptance criteria in Studio and inspect Output.
7. Distinguish solo tests from multi-client tests.
8. Update `docs/PROJECT_STATUS.md`.
9. Commit and push the branch and open a PR.
10. Report the PR URL, commit SHA, changes, tests, failures, and remaining risks.
11. Do not merge or publish.

## B. Request ChatGPT review

Repository: https://github.com/jackambrosia-ai/World.EXE
PR/commit: [URL or SHA]
Phase/feature: [name]
Review focus: [architecture / security / Luau / performance / gameplay / UI]

Please inspect the actual changed files and diff. Compare them with the relevant docs and acceptance criteria. Return:
1. Blocking issues.
2. Important non-blocking issues.
3. Tests or evidence missing.
4. Specific recommendations.
5. A copy-ready correction prompt for Claude.

Do not assume Studio tests ran unless the report provides evidence. Do not merge or publish.

## C. Give Claude a correction from ChatGPT review

Apply the following review findings to the existing branch/PR only: [paste findings].

Before editing, inspect the current branch and diff. Fix the underlying causes, avoid unrelated refactors, rerun the failed tests and relevant regression tests, update the phase report, commit, and push. Do not merge or publish.

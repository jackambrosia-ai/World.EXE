# WORLD.EXE — Automated OpenAI + Claude PR review loop

This is an **opt-in** cloud-source review system. It does **not** run the interactive
ChatGPT conversation or connect to the owner's Roblox Studio window. It invokes
the **OpenAI Responses API** for independent review and **Claude Code GitHub Action**
for code corrections on an existing PR branch.

## Install (owner-controlled)

1. Review and merge the automation-only setup PR after checking the workflow.
   It is disabled by default. Do not merge this setup PR as part of a game phase.
2. Configure repository **Actions secrets** (Settings → Secrets and variables → Actions):
   - `OPENAI_API_KEY`: an OpenAI **API** key (separate billing from ChatGPT).
   - `ANTHROPIC_API_KEY`: an Anthropic API key. Install the official
     [Claude GitHub app](https://github.com/apps/claude) if required by the action.
   Never paste keys into GitHub issues, PR comments, code, or ChatGPT.
3. Set repository **Actions variable** `OPENAI_REVIEW_MODEL` to a structured-output
   capable model available to your OpenAI API project (default: `gpt-5.1`).
4. Before enabling automated edits, configure a **branch protection rule/ruleset**
   for `main`: require PR review by a human, disable auto-merge, and do not permit
   the automation identity to bypass required approvals. Keep manual owner merge.
   A prompt alone is **not** a hard permission boundary: the workflow must have
   GitHub write access to propose fixes.
5. Set the repository **Actions variable** `AI_REVIEW_ENABLED` = `true` to opt in.
   Leave unset or `false` to disable. No Actions job runs until this is set.
6. Create a new, same-repository PR targeting `main`. A PR open/update runs:
   OpenAI review → Claude correction (if needed) → re-review, max **three**
   Claude correction rounds, final review and PR comment. No automatic merge.
   PRs from forks, drafts, and PRs not targeting main are skipped.
7. Watch **Actions → WORLD.EXE AI Review Loop**. Review the review findings and
   Claude's commits. If a review still requests changes after three rounds, the
   workflow fails for **manual intervention**.

## Boundaries

- The OpenAI reviewer reads a Git diff as untrusted text, using a reviewer script
  loaded from the trusted `main` branch; it does not execute PR code.
- Claude's cloud action **can edit repository code**, but **cannot verify local
  Studio MCP scripts, save .rbxl, publish the place, or create the local backup**.
- Before merging any gameplay PR, Claude in your Studio-connected session or
  the owner must copy/sync any changed scripts into Studio, verify exact script
  hashes, run Studio playtests, remove test controls, and save/back up the place.
  Never claim cloud checks substitute for Studio multiplayer tests.
- **No phase transitions, merging, publication or ForgeGUI spending** are authorized
  by this automation. Do not supply ForgeGUI, Roblox publishing, deployment, or
  local machine credentials to GitHub Actions.
- The automated API reviewer is a *separate OpenAI API invocation*, not a
  continuation of this ChatGPT conversation. Independent final human review
  can still be requested here.
- Review service/API failures stop the workflow rather than approving a PR.
  Diffs over 100k characters require manual review.
- Review results are AI findings, not proof that tests passed.

## Security/operations

Only enable this for PRs from trusted collaborators in the **same repository**.
GitHub Actions secrets and a write-capable Claude action should never be run on
untrusted fork contributions. Audit collaborator write access, action permissions,
branch protection and commit history regularly.

This workflow runs within a single GitHub Actions job, so it does not rely on
`GITHUB_TOKEN`-authored commits triggering another workflow. The default GitHub
token is scoped to this repository but remains powerful enough to modify PR
branches; use branch rules to enforce your manual merge gate.

If you need to pause spending immediately, set `AI_REVIEW_ENABLED=false` and
cancel running jobs in Actions.

## References

- [Claude Code GitHub Action setup](https://github.com/anthropics/claude-code-action/blob/main/docs/setup.md)
- [Claude Code Action automation](https://github.com/anthropics/claude-code-action/blob/main/docs/custom-automations.md)
- [OpenAI Responses structured output](https://developers.openai.com/api/docs/guides/structured-outputs)
- [GitHub pull_request_target security](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target)

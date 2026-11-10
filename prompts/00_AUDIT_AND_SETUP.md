# Phase 0 — Read-only audit and setup

Read `docs/00_MASTER_INSTRUCTIONS.md` and all relevant documents in `docs/`.

**Do not modify the Roblox place or repository yet.**

1. Verify the current Git repository, branch, working-tree state, and available project files.
2. Verify the Roblox Studio MCP connection and list open Studio sessions.
3. Verify the ForgeGUI connection in this Claude session. List available tool capabilities and classify them as read-only, credit-consuming, upload/publish, or Studio-mutating. Do not invoke paid or mutating actions.
4. Identify the intended Studio place and inspect its DataModel/Explorer tree, scripts, remotes, assets, and Output.
5. Classify the place as blank, partially built, or an existing experience.
6. Identify reusable systems, conflicts, risks, missing prerequisites, and whether the project needs Git/Rojo or can use a simpler safe workflow.
7. Confirm whether a local backup exists and propose a backup approach if not.
8. Recommend a source synchronization method. Keep Studio-owned map geometry separate from repository-owned source unless the owner explicitly chooses otherwise.
9. Report any limitations to solo/multi-client testing and any plugin errors separately from WORLD.EXE errors.

Report concrete findings and evidence:
- GitHub repository and branch detected.
- Studio place and connection status.
- ForgeGUI tools actually available and their permissions/cost implications.
- Existing project structure and reusable systems.
- Source-sync recommendation and setup required.
- Risks, conflicts, missing prerequisites, and backup plan.
- Proposed Phase 1 plan.

Do not generate ForgeGUI assets, consume credits, upload/publish assets, or perform Studio mutations during this audit. Do not assume access to tools that are not actually available. Wait for explicit user approval before Phase 1.

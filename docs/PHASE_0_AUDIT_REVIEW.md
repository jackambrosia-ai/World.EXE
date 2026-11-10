# Phase 0 Audit Review — ChatGPT Technical Review

**Status:** Audit reviewed; Phase 1 is not yet authorized to begin.
**Review basis:** Claude's audit report supplied by the project owner on 2026-11-09. These machine/local environment findings are reported by Claude and have not been independently inspected by ChatGPT.

## 1. Overall assessment

The proposed split is sound:
- GitHub owns version-controlled scripts, configuration, documentation, and tests.
- Roblox Studio owns editable arena geometry and the live DataModel.
- Rojo synchronizes only explicitly mapped code-owned containers between disk and Studio.
- A saved RBXL copy outside the repository is the baseline backup.

Proceed with Rojo, but scope the Rojo project mapping narrowly. Do not map all of Workspace or the entire DataModel to disk while the arena remains Studio-owned. Map only WORLD_EXE-owned script/config/remote containers. Preserve the existing place and unrelated content.

## 2. Prerequisites and Windows install sequence

Use official sources. Open a fresh PowerShell or Windows Terminal window after installers modify PATH.

### Git and GitHub CLI

```powershell
winget install --id Git.Git -e --source winget
winget install --id GitHub.cli --source winget

git --version
gh --version
gh auth login
gh auth status
```

During gh auth login, choose GitHub.com and HTTPS, use browser sign-in, and accept Git credential integration when prompted. Do not paste tokens into chats or commit credentials.

Official references:
- https://git-scm.com/install/windows
- https://github.com/cli/cli/blob/trunk/docs/install_windows.md
- https://cli.github.com/manual/gh_auth_login

### Rokit and Rojo

Use Rokit as the project toolchain manager. In PowerShell, use the official Rokit installer:

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```

Close and reopen the terminal, then:

```powershell
rokit --version
```

From the WORLD.EXE repository root:

```powershell
rokit add rojo-rbx/rojo
rokit install
rojo --version
rojo plugin install
```

Commit the generated/pinned toolchain manifest and lock data (for example, rokit.toml and rokit.lock, depending on the installed Rokit version) so the Rojo version is reproducible. The Studio plugin must match the installed Rojo major version. Verify the Rojo plugin appears in Studio and can connect to the local server.

Official references:
- https://rojo.space/docs/v7/getting-started/installation/
- https://create.roblox.com/docs/projects/external-tools
- https://github.com/rojo-rbx/rokit

## 3. Baseline place backup

Before Phase 1:
1. In the intended Studio window, use File → Save to File As.
2. Save outside the Git repository, for example Documents\\RobloxBackups\\WorldEXE_baseline_2026-11-09.rbxl.
3. Confirm the file exists and note its exact path.
4. Do not publish the place to create a backup; publishing requires explicit owner approval.
5. Before each substantial phase, make another versioned backup.

The Studio title Place1.rbxl is not proof of its on-disk path. Do not assume a location; ask the owner to save and confirm it.

## 4. StreamingEnabled decision

**Recommendation: leave StreamingEnabled enabled for Phase 1. Do not disable it preemptively.**

Roblox documents that Workspace streaming affects which Workspace descendants are replicated to each client. The server retains the full server-side Workspace; a client may not currently have distant Workspace instances loaded, and streamed-out instances can become unavailable in that client's local DataModel.

Implementation implications:
- Server-side patch, objective, scoring, and validation services must use authoritative server state and must not depend on whether a client has streamed an instance.
- Client controllers must tolerate relevant Workspace instances not being present locally yet.
- Do not make client UI or local effects assume all distant DECAY tiles, drones, waypoints, or stabilizers exist on every client at all times.
- Keep server-only configuration/waypoint data outside streamed Workspace where appropriate (e.g. ServerStorage or module configuration).
- For nearby interactables, use robust server-side distance/state validation; client visuals/prompts should bind when the local instance streams in.
- Consider targeted streaming techniques or per-model streaming modes only when a concrete test demonstrates they are needed. Do not mark the entire arena persistent or raise streaming radii without profiling.
- Validate the arena across the three connected zones and test player movement between zones.

Official references:
- https://create.roblox.com/docs/workspace/streaming
- https://create.roblox.com/docs/reference/engine/classes/Workspace

## 5. Testing limitation

Claude reports that the current MCP workflow can run solo playtests only. Treat that as the currently verified test capability.
- Solo tests can verify basic scripts, state transitions, object creation, and local behavior.
- They do not prove server/client replication, Architect exclusivity under multiple players, simultaneous objective claiming, network ownership, race conditions, or multiplayer balance.
- Before declaring multiplayer-sensitive systems complete, the owner should run Test → Start with a server and at least two clients, or Claude must verify a supported multi-client workflow.
- Record each test as solo, multi-client, or published private server; do not use the phrase multiplayer tested for a solo test.

## 6. ForgeGUI plugin Output noise

Treat the ForgeGUI error as an external plugin issue until its stack trace proves otherwise. Do not silently suppress it or assume it is harmless.
- Capture a clean baseline Output after Studio starts, before WORLD_EXE scripts run.
- Compare subsequent errors and attribute each to its source when possible.
- Do not uninstall or alter third-party plugins without the owner's approval.
- WORLD.EXE errors must be fixed even if ForgeGUI also emits unrelated messages.

## 7. Phase 1 scope — approved design, pending setup gate

Once Git, GitHub CLI, Rokit, Rojo CLI/plugin are installed and the baseline RBXL backup is confirmed, Claude may implement Phase 1 on branch phase-01-arena.

Phase 1 should:
1. Pull latest main; confirm clean working tree.
2. Create a feature branch.
3. Add a Rojo project configuration and source layout that maps only WORLD_EXE-owned script/config containers, not the Studio-owned arena.
4. Start Rojo and verify a harmless test ModuleScript syncs to the intended location in Studio.
5. Remove the test module after confirming sync, then implement the intended minimal Bootstrap and client controller.
6. Build the Studio-owned graybox arena: Central Core, Research Yard, Skybridge, spawn points, three stabilizers, tagged DecayTiles, supply landing points, and drone waypoints.
7. Ensure tags/attributes are correctly assigned and that the server can inspect all required tagged Workspace objects even with streaming enabled.
8. Solo playtest spawn safety, arena layout, tags, collisions, reset/baseline behavior, and script startup.
9. Inspect Output, update docs/PROJECT_STATUS.md, commit, push, and open a PR.
10. Do not merge or publish.

Additional Phase 1 safeguards:
- Do not run a full-place Rojo sync that could replace or remove Studio-owned map content.
- Before the first sync, explain the exact Rojo project mapping and which Studio instances it manages.
- Verify the first sync against an isolated test folder/container before mapping actual project scripts.
- Keep map geometry out of src/ for now, as agreed.
- Do not change Workspace.StreamingEnabled as part of Phase 1 without presenting evidence and obtaining owner approval.

## 8. Current gate

Phase 1 is not yet green-lit. The owner must first:
- Install Git, GitHub CLI, Rokit, Rojo CLI, and the Rojo Studio plugin.
- Run gh auth status and confirm authentication to the intended account.
- Save a baseline RBXL copy outside the repository and confirm its exact path.
- Confirm Claude can clone/pull the private repository and that Rojo can connect to the intended Studio place.

After these are confirmed, ask the owner to approve Phase 1.
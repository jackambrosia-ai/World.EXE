# WORLD.EXE — ForgeGUI Workflow

## Purpose
ForgeGUI is an additional tool available to Claude for suitable original visual asset and GUI-art workflows. The owner reports it is connected to Claude. Claude must verify the actual tool names, permissions, account, and capabilities in its active session before relying on it.

## Keep the tool boundaries clear

| Tool | Main responsibility |
|---|---|
| ChatGPT | Creative direction, requirements, asset briefs, architecture, reviews |
| Claude | Orchestrates creation, chooses approved assets, integrates and tests |
| ForgeGUI | Depending on connected version/tools: visual asset generation, reference search, project/artwork preparation, export, and possibly publication |
| Roblox Studio MCP | Inspects and edits the live Studio DataModel, imports/inserts supported assets, constructs functional UI, wires Luau, runs Studio tests |
| GitHub | Stores specifications, source, asset briefs/manifests, progress, and review evidence |

ForgeGUI and Roblox Studio MCP are separate integrations. Having ForgeGUI does not mean the live Studio place is accessible through ForgeGUI alone. The Studio MCP connection must remain verified.

A generated UI image is artwork, not a functional Roblox interface. Claude must construct editable ScreenGui/Frame/ImageLabel/TextLabel/Button/etc. instances, connect state and input using Luau, support relevant input modes, and playtest the result.

## Asset use cases for WORLD.EXE

Recommended candidates:
- Patch card art: ZERO_G, DECAY, DRONE_SWARM, SUPPLY_DROP.
- Patch/category and ability icons.
- Subtle panel plates, backgrounds, and decorative textures.
- Patch Archive illustrations and collectible icons.
- Original lobby artwork, promotional thumbnails, and other marketing art (separately scoped).
- UI visual concepts to guide the functional Roblox interface.

Use the existing WORLD.EXE reference board as art direction: navy, cyan, violet, restrained amber warnings, readable composition, clean sci-fi simulation geometry, and consistent iconography.

## Approval gate for credits, uploads, and publication

Do not perform any credit-consuming generation, Roblox asset upload, or publication by default.

Before doing any of these, Claude must provide:
1. Exact asset brief and intended use.
2. Number of assets/variants and output sizes/formats.
3. Estimated ForgeGUI credit spend or other cost (or state that it is unknown).
4. Whether the operation sends prompts/reference images to ForgeGUI and its generation providers.
5. Intended ForgeGUI project/account and Roblox publishing destination, if applicable.
6. Whether the action is reversible and how to review/undo it.

Wait for explicit approval of the specific operation and budget. Prefer a small preview batch, not a large blind generation run. If cost is unknown, do not proceed with the paid operation until the owner can verify it.

Never request or paste API keys, Roblox Open Cloud keys, access tokens, or publishing credentials in normal chat, source files, README files, or tool arguments. Use only the provider's official masked/secure authorization flow.

## Asset review and import workflow

1. ChatGPT/owner establishes the visual brief and acceptance criteria.
2. Claude verifies the ForgeGUI tools available in the current session using read-only discovery.
3. Claude presents a credit/cost estimate, asset count, target, and approval request.
4. After approval, generate only the agreed preview batch.
5. Review originality, visual consistency, transparency/cropping, dimensions, file format, Roblox suitability, and fit with the reference board.
6. Owner approves selected candidates.
7. Claude uses a supported import/export/publishing route. Do not assume generation automatically inserts an asset into Studio.
8. Claude verifies the resulting asset/instance in the intended place and records its asset ID and Studio path.
9. Build functional editable UI around the art.
10. Test runtime loading, layout, responsiveness, input, legibility, and failure behavior.

Use Roblox Studio Undo or a source-control/backup route where possible for reversible integration. Do not assume every ForgeGUI publish/import operation is reversible.

## Asset manifest

For each approved integrated asset, record:
- Asset name and purpose.
- ForgeGUI job/output identifier (if available).
- Roblox asset ID (if uploaded).
- Output format and dimensions.
- Approval record/context.
- ForgeGUI cost/credits, if any.
- Studio instance path.
- Verification result (generated / approved / imported / tested are separate states).

Keep the manifest in `docs/ASSET_MANIFEST.md`. Never commit credentials or proprietary source assets that are not intended to be public.

## First ForgeGUI audit task (read-only)

During Phase 0, Claude should:
- List the ForgeGUI tools and skills available in its active client.
- Identify which tools are read-only versus credit-consuming or mutating.
- Confirm whether it can generate artwork, search references, export assets, import into Studio, or publish.
- Confirm whether Studio insertion happens through ForgeGUI or the separate Studio MCP.
- Check whether an account/project is selected and whether a credit estimate can be obtained without generating.
- Report all limitations and any permissions required.

Do not generate, upload, or publish during this audit.

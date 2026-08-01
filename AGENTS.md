# DOX framework

- DOX is highly performant AGENTS.md hierarchy installed here
- Agent must follow DOX instructions across any edits

## Core Contract

- AGENTS.md files are binding work contracts for their subtrees
- Work products, source materials, instructions, records, assets, and durable docs must stay understandable from the nearest applicable AGENTS.md plus every parent AGENTS.md above it

## Read Before Editing

1. Read the root AGENTS.md
2. Identify every file or folder you expect to touch
3. Walk from the repository root to each target path
4. Read every AGENTS.md found along each route
5. If a parent AGENTS.md lists a child AGENTS.md whose scope contains the path, read that child and continue from there
6. Use the nearest AGENTS.md as the local contract and parent docs for repo-wide rules
7. If docs conflict, the closer doc controls local work details, but no child doc may weaken DOX

Do not rely on memory. Re-read the applicable DOX chain in the current session before editing.

## Update After Editing

Every meaningful change requires a DOX pass before the task is done.

Update the closest owning AGENTS.md when a change affects:

- purpose, scope, ownership, or responsibilities
- durable structure, contracts, workflows, or operating rules
- required inputs, outputs, permissions, constraints, side effects, or artifacts
- user preferences about behavior, communication, process, organization, or quality
- AGENTS.md creation, deletion, move, rename, or index contents

Update parent docs when parent-level structure, ownership, workflow, or child index changes. Update child docs when parent changes alter local rules. Remove stale or contradictory text immediately. Small edits that do not change behavior or contracts may leave docs unchanged, but the DOX pass still must happen.

## Hierarchy

- Root AGENTS.md is the DOX rail: project-wide instructions, global preferences, durable workflow rules, and the top-level Child DOX Index
- Child AGENTS.md files own domain-specific instructions and their own Child DOX Index
- Each parent explains what its direct children cover and what stays owned by the parent
- The closer a doc is to the work, the more specific and practical it must be

## Child Doc Shape

- Create a child AGENTS.md when a folder becomes a durable boundary with its own purpose, rules, responsibilities, workflow, materials, or quality standards
- Work Guidance must reflect the current standards of the project or user instructions; if there are no specific standards or instructions yet, leave it empty
- Verification must reflect an existing check; if no verification framework exists yet, leave it empty and update it when one exists

Default section order:
- Purpose
- Ownership
- Local Contracts
- Work Guidance
- Verification
- Child DOX Index

## Style

- Keep docs concise, current, and operational
- Document stable contracts, not diary entries
- Put broad rules in parent docs and concrete details in child docs
- Prefer direct bullets with explicit names
- Do not duplicate rules across many files unless each scope needs a local version
- Delete stale notes instead of explaining history
- Trim obvious statements, repeated rules, misplaced detail, and warnings for risks that no longer exist

## Closeout

1. Re-check changed paths against the DOX chain
2. Update nearest owning docs and any affected parents or children
3. Refresh every affected Child DOX Index
4. Remove stale or contradictory text
5. Run existing verification when relevant
6. Report any docs intentionally left unchanged and why

## User Preferences

When the user requests a durable behavior change, record it here or in the relevant child AGENTS.md

# Project: PIority

## Purpose

A World of Warcraft Retail addon that keeps a single macro's targeting line pointed at the right group member. As a **priest**, it inspects the party/raid, ranks every member by how much their spec gains from Power Infusion (using SimulationCraft sim data, normalized by item level), and lets you click a roster row to retarget the `PI_H` macro. As a **hunter**, it points the `MD_H` Misdirection macro at the group's first tank (or your own pet when solo) and watches for a missing/wrong Bloodlust pet in 5-mans. The addon only ever edits the `@target` inside the one managed `/cast` line — every other line in the macro is preserved. This root doc owns the addon runtime and its PI data pipeline; `tools/` owns release packaging and data conversion.

## Layout

- `PIority.lua` — the entire addon runtime (single file): constants, `CLASS_CONFIG` (PRIEST/HUNTER macro profiles), macro building/retargeting, inspect + spec/ilvl caching, roster sorting, PI-data lookup, UI (main roster window, settings window, notification popup), layout persistence, PI-request notifications, minimap button, and slash commands.
- `PIority_Locale.lua` — builds `ns.L`: English (default) plus a `deDE` override block selected by `GetLocale()`. The addon title stays `"PIority"` in every locale (never overridden).
- `pi_patchwerk1.lua`, `pi_patchwerk5.lua` — **auto-generated** PI sim-data modules. Each registers itself under `ns.piData["<profile>"]` (spec priority ranks + simmed PI DPS gains). Do not hand-edit; regenerate from the matching `.json` with `tools/convert-pi-data.js`.
- `pi_patchwerk1.json`, `pi_patchwerk5.json` — source SimC/bloodytools PI export data (converter input only; not loaded by WoW, not shipped).
- `PIority.toc` — load manifest: `## Interface`, `## Version`, `## SavedVariables: PIorityDB`, and the fixed file load order.
- `README.md`, `CHANGELOG.md`, `LICENSE.md` — docs. `logo.png`/`logo.svg`, `screenshot-*.png` — assets.
- `CLAUDE.md` — Claude Code entry point; imports this file (`@AGENTS.md`) so the DOX contract loads every session.
- `.luacheckrc` — lint config. `tools/` — release packaging + data conversion (see `tools/AGENTS.md`). `builds/` — generated zips, gitignored.

## Local Contracts

- Runtime is the WoW Retail Lua 5.1 sandbox. `local addonName, ns = ...` is the addon vararg; shared state hangs off `ns` (`ns.L` from the locale, `ns.piData` from the generated data modules).
- Load order is fixed by the `.toc` and dependency-ordered: `PIority_Locale.lua` (sets `ns.L`), then `pi_patchwerk1.lua` + `pi_patchwerk5.lua` (populate `ns.piData`), then `PIority.lua` reads both. Any new file must be inserted into `PIority.toc` in dependency order.
- Localization: English keys live inline as the default `ns.L`; `deDE` overrides go in the `GetLocale() == "deDE"` block. Both must stay key-parallel — every new user-facing string gets a key, and display text is never hardcoded in `PIority.lua`.
- Macro safety is the core promise: only the `@target` clause of the single managed `/cast` line is ever changed (`BuildMacroBody`/`UpdateMacroTarget`). If that line can't be found, warn the user instead of rewriting the macro. Which macro/spell/reset-target a class manages is defined in `CLASS_CONFIG`.
- PI ranking data is generated, not authored: it flows `pi_*.json` → `tools/convert-pi-data.js` → `pi_*.lua` → `ns.piData`. `GetActivePIData` selects the profile by group size. To change rankings, edit the JSON source and re-run the converter; never edit the generated `.lua` tables by hand.
- Members are ranked and shown by **absolute** simmed DPS gain (`value - value2`, via `PIGain`), gear-scaled by the player's ilvl vs the group average — not by percentage gain. Absolute gain reflects the real damage PI adds, so a high-throughput spec outranks a lower one with a bigger percentage. The roster label shows the raw gain (`FormatGain`, e.g. `+18.3k`).
- Persistence goes through `PIorityDB` (declared in the `.toc`). Layout/state (window position, size, open state, per-character macro target, notification frame position) route through the existing save/restore helpers and the login load path.
- UI is a flat dark theme. Build new controls with the existing helpers — `MakeFlatBtn`, `ApplyFlatBg`, `AutoSizeBtn` — rather than styling from scratch.
- Releases: bump `## Version` in `PIority.toc` and add a matching `CHANGELOG.md` entry together; the build script reads the version from the `.toc`.
- `## Interface` lists **every** client the build supports — current live plus the next patch's PTR build (e.g. `120007, 120100`) — so a single release loads un-flagged on both and needs no cutover on patch day. Prepare for an upcoming patch by appending its interface number, not by branching or by replacing the live one. Drop an old number only when that client is no longer supported. Branch per-patch only if the two clients ever need materially different code.

## Verification

- Lint from the addon folder: `luacheck .`. `.luacheckrc` whitelists the addon's own globals (`PIorityDB`, the `SLASH_*` globals, `ProcessInspectQueue`) and the WoW API surface it calls; add to `read_globals` when you use a new API so typos still get flagged. Use the Scoop standalone luacheck (system Lua breaks luarocks/luacheck).
- No automated tests. Verify game logic in-game.

## Child DOX Index

- `tools/` — [tools/AGENTS.md](tools/AGENTS.md): zero-dependency Node scripts — `build-release.js` (zips the shippable addon files) and `convert-pi-data.js` (SimC PI JSON → generated `pi_*.lua` data modules).

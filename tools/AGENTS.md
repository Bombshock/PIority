# tools/

## Purpose

Zero-dependency Node build utilities for PIority. Two scripts, run from the addon root:

- `build-release.js` — bundles the shippable addon into `builds/PIority-<version>-<interface>.zip`.
- `convert-pi-data.js` — converts SimC/bloodytools Power Infusion export JSON into the generated `pi_*.lua` data modules the addon loads.

## Ownership

- Owns the packaging and PI-data-conversion pipeline only. The addon runtime, `.toc` load order, and the `ns.piData` consumer live in the parent scope (root `AGENTS.md`).

## Local Contracts

- Node standard library only — no npm dependencies, no `package.json`, no lockfile. Keep it that way (`build-release.js` even hand-rolls its own ZIP writer).
- `build-release.js`: ships exactly every root `*.lua`, the `*.toc`, and `README.md`, nested under a top-level `PIority/` folder so the zip extracts straight into `Interface/AddOns`. It names the zip `PIority-<version>-<interface>.zip`, reading `<version>` from the `.toc` `## Version` line and `<interface>` from `## Interface` — taking the **highest** value when several clients are listed, so the zip is named after the newest client it supports. Output goes to `builds/` unless `-o <dir>` is given. Source `pi_*.json` files are intentionally excluded (only their generated `.lua` ships).
- `convert-pi-data.js`: each `pi_FOO.json` becomes `pi_FOO.lua` next to it, registering under `ns.piData["FOO"]` (leading `pi_` stripped). `NAME_TO_SPECID` maps SimC spec names to WoW specIDs — extend it when a profile introduces a new spec, or the spec is silently skipped (the script warns about unmapped names). Regenerated `.lua` files carry an "AUTO-GENERATED / do not edit by hand" header; any data change must be made in the JSON and re-converted, never in the `.lua`.

## Work Guidance

- After editing PI sim data, re-run `node tools/convert-pi-data.js` and confirm no "unmapped spec names" warnings before shipping.
- When adding a new `pi_*.lua` data module, add it to `PIority.toc` (before `PIority.lua`) so `ns.piData` is populated in time.

## Verification

- No automated tests. Sanity-check by running each script from the addon root and inspecting its stdout (file list / conversion summary) and the generated output.

# Changelog

All notable changes to PIority are documented here.

## [1.7] - 2026-08-01

**Preparation for patch 12.1 — no new features.** This release exists so PIority is ready when 12.1 lands; none of the ranking, macro, or roster behaviour has changed.

### Changed
- **Runs on both the live client and the 12.1 PTR** — the TOC now declares both (`120007, 120100`), so this single build loads without an "out of date" flag on either, and will keep working the day 12.1 goes live with no update needed. The addon previously still declared `120000`, so it had been showing as out of date on the live client; that is fixed as a side effect.

### Fixed
- **Minimap button sits properly on the minimap again** — its ring was anchored by the centre, which pushed the visible border down and to the right of the icon and off the minimap edge; it is now anchored the standard way. The button's distance from the minimap centre is also measured from the minimap's real size instead of a fixed 80 pixels, so it stays flush if the minimap is ever resized.

## [1.6] - 2026-07-29

### Changed
- **Ranked by real DPS gain, not percentage** — the roster now ranks and shows each player's *absolute* Power Infusion gain in DPS (e.g. `+18.3k`) instead of a percentage. Percentage understated high-throughput specs: in 5-target content an Elemental Shaman gaining +18.3k DPS was ranked below a Retribution Paladin gaining only +10.7k just because the Paladin's percentage was marginally higher. Ranking by the damage PI actually adds puts the biggest beneficiary on top, where it belongs. Gear (item level vs the group) still scales the number, so a better-geared player of the same spec still ranks higher.

## [1.5] - 2026-07-28

### Added
- **PI gain shown per player** — every roster row now displays the spec's actual Power Infusion gain (e.g. +6.3%), so you can see what a cast is worth instead of just the ranking order.
- **Non-priests are ranked too** — your own character now appears in the roster and is ranked alongside the group (handy for hunters), rather than being left out of the list.
- **Auto-open when the group is known** — in a full 5-man party the roster pops open automatically once every member's spec has resolved, so you're ready to pick a target the moment scanning finishes.

## [1.4] - 2026-07-28

### Changed
- **Data-driven ranking** — the roster is now ranked by real SimulationCraft Power Infusion sim data (the measured %-DPS gain per spec) instead of a hand-maintained priority list. Gains are normalized by item level, so a better-geared player of the same spec ranks higher, and party (≤5) and raid (>5) groups each use their own sim profile.
- **Tanks and healers sink to the bottom** — support specs are now detected by their assigned role and always sorted below DPS, rather than being placed by the old static spec list.

## [1.3.1] - 2026-07-24

### Fixed
- The PI request popup now shows up during combat. Before, it only appeared out of combat, so priests missed requests in the middle of a fight — exactly when they matter most.

## [1.3] - 2026-07-04

### Added
- **Bloodlust watch for hunters** — in a 5-man group with no Shaman, Mage, or Evoker, a warning frame appears when your summoned pet isn't Ferocity (or no pet is out), with a secure button that dismisses your current pet on the first click and calls a Ferocity pet from your call slots on the second. Draggable, dismissable, plays the configured alert sound, localized.
- **Account-wide window positions** — the main and settings windows now share one saved position across all characters by default. A new settings checkbox (default on) switches back to per-character positions. The first character logging in with sharing enabled defines the shared position for everyone.
- **`/md` slash command** — hunter-flavored alias for `/pi`; both commands work for every class, and chat messages show the one matching your class.
- Screenshot mode now also triggers the hunter Bloodlust watch as if you were in a lust-less group, so it can be captured solo.

### Fixed
- Window positions no longer drift apart between characters: WoW's per-character layout cache (`layout-local.txt`) was silently overriding the addon's saved positions after login. The addon's SavedVariables are now the single source of truth.
- The settings window position is now saved between sessions; previously it reset next to the main window on every login.

## [1.2] - 2026-07-03

### Added
- **Hunter Misdirection support** — maintains an MD_H macro targeting the first tank in your group, or your own pet when solo; auto-pick targets the tank automatically.
- **Per-character macro targets** — every character remembers its own PI_H/MD_H target between sessions.
- **Settings window** — re-inspect, alert position, and reset controls in one place.
- **Minimap button** — left-click toggles the roster, right-click the settings, drag to reposition.
- **Sound picker** — choose from ten alert sounds (or none) for PI request notifications, with preview.
- **Screenshot mode** — `/pi screenshot` fills the roster with demo data and forces English for clean promo shots.
- **Full localization** — English and German.
- Smarter macro defaults: the macro resets to yourself (priest) or your pet (hunter) when leaving a group.
- Alert-related settings are disabled with a hint on non-priest characters.
- New logos and screenshots.

## [1.0] - 2026-06-29

### Added
- Initial release as **PIority** (renamed from PI Helper).
- Priority-sorted group/raid roster ranking all 32 DPS/tank specs by Power Infusion value, with class icons, class-colored names, spec labels, level, and average item level.
- One-click PI_H macro targeting: click a roster row to retarget the macro.
- Auto-pick mode: automatically targets the highest-priority player once every spec is known.
- PI request notifications: `/pirequest` alerts the priest with a pulsing spell icon popup and sound (spam-protected).
- Addon-presence indicator for group members who also run PIority.
- Flat purple/violet UI theme with resizable, movable window.

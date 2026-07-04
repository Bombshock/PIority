# Changelog

All notable changes to PIority are documented here.

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

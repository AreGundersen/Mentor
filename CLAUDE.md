# Mentor (WoW Forever addon)

Instructions for working in this repository.

## Versions and releases

- **Never give a new version number unless Are says the release is finished.**
  Follow `RELEASING.md` exactly.
- While working: add every change under `## Unreleased` in `CHANGELOG.md`, and
  make sure `## Version` in `Mentor.toc` is `<last release>+dev`.
- Test builds come from `tools/package.sh` and are named `...+dev.zip`. They
  must never be described as a release or uploaded to CurseForge.

## Code style

- Write proper explanatory comments and descriptive variable names (no terse
  abbreviations).
- The game client is the retail client for WoW Forever (interface 16001):
  use C_Item, C_Spell, C_SpellBook, C_Traits, C_TooltipInfo, and guard
  values that can be secret with `issecretvalue`.

## Bug reports

Bug reports arrive as GitHub issues from the in-game "Report bug" window
(`BugReport.lua`). The pasted report contains the Mentor version, class,
spec, talents, settings, other addons, caught errors with stack lines, and
for attached items the exact tooltip text Mentor read.

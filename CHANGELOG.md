# Changelog

Changes are collected under **Unreleased** while we work. A new version
number is only given when Are decides the release is finished (see
`RELEASING.md`).

## Unreleased

## 1.10.0 - 2026-11-10

Sell advice, clearer tooltips and a better talent window.

- **New: Sell advice** (off by default, needs the Auctionator addon). Items you don't need say whether to sell them on the auction house, disenchant them or just vendor them, based on Auctionator's prices (the 5% AH cut included). Items worth selling get a gold coin or disenchant icon in your bags. Things you use (potions, food, campfire ...) and reagents for your professions say "Keep". Turn it on under Settings or with `/mentor sell on`.
- **Tooltips start with what to do:** "Equip", "Equip at level 24", "Keep - upgrade for <spec>" or the sell advice. The spec lines are shorter (just the arrow and the percentages).
- **New setting "Tooltip details":** turn it off to hide the stat explanations and the extra lines, so the tooltip only shows the verdicts (`/mentor details off`).
- **Talent window:** shows where your next 5 talent *points* go (not the next 5 talents), with talent icons, ranks and levels in a new strip above the window. The NEXT frame and the point numbers no longer cover the neighbouring talents.
- **New Mentor logo** on the minimap button and in the addon list.
- Bug reports include the sell advice and the prices it used for attached items, and the Report bug button says "No errors caught." when there are none.

## 1.9.0 - 2026-11-10

Better bug reporting.

- Errors inside Mentor are caught automatically (where they happened and how often). One chat hint per session points to `/mentor bug`.
- New "Report bug" window: pick the type of problem, describe it, and shift-click items into the text to attach them (tooltip text, stats and the verdict per spec are included).
- The finished report comes with a link to the bug report form on GitHub.
- The Report bug button shows how many errors have been caught.

## 1.8.0 - 2026-11-09

First release on CurseForge.

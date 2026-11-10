# Changelog

Changes are collected under **Unreleased** while we work. A new version
number is only given when Are decides the release is finished (see
`RELEASING.md`).

## Unreleased

- Sell advice: quest items ("Quest Item", "This Item Begins a Quest", quest pages) say "Keep - quest item". "Use:" lines in colour were not recognised, so some usable items were sent to the vendor.
- Sell advice: items worth at least twice the vendor price on the AH are recommended for the AH from 1 silver gain (before: 10 silver), so a 7 silver item is no longer vendored for 62 copper.

## 1.11.0 - 2026-11-10

Five tools in one addon, and a tidier settings menu.

- **New: Life log** (on by default; the window stays closed until you click the new "Life log" button or type `/mentor log`): your character's story - kills, deaths, gold, loot, crafting, professions, consumables, reputation, travel, groups and more - for the session, this character and all your characters. Coming from the LifeLog addon? Keep it installed for one login: Mentor copies all your data (LifeLog itself is never changed), then you can disable LifeLog.
- **New: Level pace** (off by default): XP per hour, time to level and kills to level in a small window (`/mentor pace on`).
- **New: Auto vendor** (off by default): sells grey items and repairs your gear at vendors, with check boxes for each and a small window with junk value and durability (`/mentor vendor on`; hold Shift to skip once).
- **New: One-key fishing** (off by default): one key casts Fishing and reels in the catch (`/mentor fishing on`, `/mentor fish`).
- **New: Mana warning** (off by default): a big LOW MANA / OUT OF MANA warning with a sound and an optional party message (`/mentor mana on`). Your ManaWarning settings are copied the first time.
- These come from the standalone LifeLog, LevelPace, AutoVendor, OneKeyFishing and ManaWarning addons. While one of those is still loaded, Mentor leaves the job to it.
- **Settings** open to the right of the Mentor window, in two columns with sections: Talents & play, Gear & loot, Interface, Gold, Extra tools and Mana warning.
- Bug reports include actions the game blocked.

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

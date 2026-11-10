# Changelog

Changes are collected under **Unreleased** while we work. A new version
number is only given when Are decides the release is finished (see
`RELEASING.md`).

## Unreleased

- **Settings are organized:** two columns with sections - Talents & play, Gear & loot, Gold, Extra tools and Interface. "Details" sits under "Item tooltips" and is greyed out while tooltips are off.
- **New: Level pace** (off by default): a small Mentor window with XP, XP to level, rested XP, XP per hour, time to level and kills to level. Turn it on under Settings or with `/mentor pace on`; `/mentor pace reset` starts the session statistics again.
- **New: Auto vendor** (off by default): sells all grey items and repairs your gear when you open a vendor (hold Shift to skip once), with a small window showing the junk value and your lowest durability. Turn it on under Settings or with `/mentor vendor on`. `/mentor keep <item>` keeps a grey item from being sold.
- **Auto vendor window:** check boxes for "Auto sell junk" and "Auto repair" (both on by default).
- **New: Life log** (off by default): your character's story - kills, deaths, gold, loot, crafting, professions, consumables, reputation, travel, groups and more - for the session, this character and all your characters, in a Mentor window (`/mentor log`). Turn it on under Settings or with `/mentor lifelog on`.
- **Moving from the LifeLog addon keeps all your data:** while LifeLog is still installed, Mentor copies its data at every login and logout (LifeLog itself is never changed) and turns its own life log on. Disable LifeLog afterwards and Mentor carries on where it left off. Characters you have not logged in with since then start from the copy LifeLog kept for the "All chars" column.
- **New: One-key fishing** (off by default): a small window with a Start / Stop fishing button. While fishing, one key (F by default, `/mentor fish key <KEY>`) casts Fishing and reels in the catch; auto loot is on and the sound is turned up so you hear the splash, and your settings come back when you stop. Turn it on under Settings or with `/mentor fishing on`; `/mentor fish` starts and stops fishing.
- These come from the standalone LevelPace, AutoVendor, OneKeyFishing and LifeLog addons. If one of those is still loaded, Mentor leaves the job to it and says so.

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

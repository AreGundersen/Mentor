# Changelog

Changes are collected under **Unreleased** while we work. A new version
number is only given when Are decides the release is finished (see
`RELEASING.md`).

## Unreleased

- **Settings are remembered for your whole account:** a new character starts with the settings you used last, and changes carry over to your other characters at their next login. Window positions stay per character.
- **New: Journey tab** (Spells & racials panel, or `/mentor journey`): zones and dungeons for your level and faction, profession advice for your class, and professions that need a trainer.
- **New: Reminders** (on by default, Settings > Reminders): new spells at your class trainer when you level up; low ammo, reagents or an unhappy pet when you leave town; gear that is almost broken; professions stuck at their cap; empty bag slots and small bags.
- **New: Dungeon tips:** a short tip about the dungeon and your role when you enter one.
- **Auto vendor:** can also sell the items Sell advice marks "Just vendor it" - it lists them with the total and asks first, and never sells an upgrade for any of your specs.
- **New: a short tour** the first time you use Mentor (`/mentor tour` shows it again).
- Sell advice: quest items ("Quest Item", "This Item Begins a Quest") and other items with a "Use:" line say "Keep" - unless the AH pays clearly more, then they say "Sell on the AH". Potions, food and reagents for your professions are always kept. "Use:" lines in colour were not recognised before.
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

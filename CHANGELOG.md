# Changelog

Changes are collected under **Unreleased** while we work. A new version
number is only given when Are decides the release is finished (see
`RELEASING.md`).

## Unreleased

## 1.13.0 - 2026-11-12

- **New: Loot roll advice** (on by default, "Loot rolls" under Gear & loot): when a group loot roll appears, a "Mentor: Need" or "Mentor: Greed" tag sits above it with the reason ("upgrade +12%", "big upgrade" over +100%, "new slot", "only for Feral", "not an upgrade", "you can't use it"), and the recommended button gets a small gold frame just inside its edge with a soft pulsing light, like the quest pick (the pulse now works on every client). Need is only for the spec you play.
- Fixed (#4): Mana warning made the game block Mentor ("blocked from an action") when you were in a group, because it sent "Low mana!" / "Out of mana!" to party chat by itself - WoW Forever only lets addons send chat from a click. Now a "Tell group" button appears under the mana box for 10 seconds; one click tells your group.
- Fixed: after learning a weapon skill (for example Staves at a weapon master), items of that type still said "You cannot use this item" and had a red cross until you logged out. Mentor now checks again as soon as you learn a skill or spell.
- Auto vendor: the "only worth vendoring" list is now a Mentor window next to the vendor, with each item's icon, name in its quality colour and price. Untick the ones you want to keep (hover for the item tooltip), then "Sell" or "Keep all".
- **New: Gold graph** in the Life log ("Gold graph" button): your gold over time as a line, for the last 7 days, 30 days or everything, with the change over the period. Gold is recorded at most every 10 minutes from now on.
- **New: Words tab** (`/mentor words`): what aggro, pull, add, CC, wipe, OOM, LFG, rested, BoP/BoE and other words mean.
- **New: Kill count** in the mob tooltip ("Mentor: Killed: 23"), from the Life log, once you have killed one. "Kill count" under Help (on by default). Only kills that give experience are counted.
- **New: Mob warnings** in the mob tooltip: "Elite - bring a group" and "5 levels above you - very dangerous".
- **New: Help tips:** when you die, how to get back without the spirit healer's penalty; when you log out outside an inn or a city, that you get no rested XP there (in a small Mentor box right under the logout countdown, and in chat).
- Settings: new "Help" section (Help tips, Mob warnings, Kill count); Interface moved under Reminders.
- "Support Mentor" button in Settings (and `/mentor support`): shows the CurseForge page with the Donate button, ready to copy. The GitHub page and README link to it too.

## 1.12.0 - 2026-11-11

Where to go next, reminders, and a new look.

- **New: Journey tab** (`/mentor journey`): zones and dungeons for your level and faction - including WoW Forever's 9 new dungeons and new zones - and professions that suit your class.
- **New: Weapons tab** (`/mentor weapons`): the weapon types your class can learn, which you know, and which weapon master teaches the rest (10 silver).
- **New: Reminders** (on by default): new spells at your trainer when you level up, low ammo or reagents, almost broken gear, professions that need a trainer and empty bag slots - in a small box under the Mentor window, or on its own while the window is closed.
- **New: Dungeon tips:** a short tip about the dungeon and your role when you enter one.
- **New: a short tour** the first time you use Mentor (`/mentor tour` shows it again).
- **Settings are remembered for your whole account:** a new character starts with the settings you used last.
- **New look:** rounded Warcraft-style boxes and icon frames everywhere, a new Full build panel, and a new "Mentor pick" marker on quest rewards that says why it is the pick.
- Panels open on the left of the Mentor window when there is no room on the right.
- **Auto vendor** can also sell gear that Sell advice marks "Just vendor it" - it lists them and asks first, and never sells an upgrade for any of your specs.
- **Sell advice:** quest items and items with a "Use:" line say "Keep" unless the AH pays clearly more; profession tools are always kept; items worth twice the vendor price on the AH are recommended for the AH.
- The Report bug button only counts errors from the current Mentor version.

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

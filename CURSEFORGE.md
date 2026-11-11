# Mentor

**An all-in-one leveling helper for new WoW Forever players.** Mentor detects your class and spec and tells you what to do next: which talent to take, which gear to wear, how to play your spec, and what to do with the loot you don't need.

## Talents
- Your next talent point is marked with a gold **NEXT** frame in the talent window.
- A strip above the talent window shows where your **next 5 points** go, with talent icons, ranks and the level for each point.
- 23 of 27 specs follow the exact level-by-level order of the Mobalytics WoW Forever leveling guides.
- Switch spec in the Mentor window whenever you like.

## Gear
- **Arrows on bag items** (Blizzard bags and Bagnon): green = upgrade, yellow = upgrade at a higher level, red = worse. A red cross marks items you can't use.
- **Tooltips start with what to do:** "Equip", "Equip at level 24" or "Keep - upgrade for <your other spec>", followed by how much better or worse the item is for each of your specs.
- See exactly which stats change, and what each stat does for you.
- Chat alert when you loot an upgrade, and the best quest reward marked when you hand in a quest.

## Where next? and reminders
- **Journey tab:** zones and dungeons for your level and faction, and professions that suit your class.
- **Reminders** (on by default): new spells at your class trainer when you level up, low ammo or reagents when you leave town, almost broken gear, professions that need a trainer, and empty bag slots.
- **Dungeon tips:** a short tip about the dungeon and your role when you enter one.

## Sell advice (optional)
Needs the **Auctionator** addon. Off by default: turn it on under Settings or with `/mentor sell on`.
- Tells you whether an item is worth **selling on the auction house**, **disenchanting** or **just vendoring**, based on Auctionator's prices (the 5% AH cut is included).
- Items worth money get a gold coin or disenchant icon in your bags.
- Potions, food and other things you use, and reagents for your professions, say "Keep".

## Life log, Level pace, Auto vendor, One-key fishing and Mana warning
Life log is on (its window stays closed until you click "Life log" in the Mentor window). The others are off by default: turn them on under Settings.
- **Level pace** (`/mentor pace on`) - a small window with your XP, XP per hour, time to level and kills to level.
- **Auto vendor** (`/mentor vendor on`) - sells your grey items and repairs your gear when you open a vendor (hold Shift to skip once). A small window shows the value of your junk and your lowest durability. `/mentor keep <item>` keeps a grey item from being sold. Auto sell and auto repair each have their own check box in the window.
- **Life log** (the "Life log" button, or `/mentor log`) - your character's story: kills, deaths, gold, loot, crafting, professions, consumables, reputation, travel, groups and more, for the session, this character and all your characters. Coming from the LifeLog addon? Keep it installed for one login: Mentor copies all your LifeLog data (LifeLog itself is not changed), then you can disable LifeLog.
- **Mana warning** (`/mentor mana on`) - a small box with your mana and a big LOW MANA / OUT OF MANA warning with a sound, and optionally a message to your group. Set the levels with `/mentor mana low 30` and `/mentor mana critical 10`.
- **One-key fishing** (`/mentor fishing on`) - press one key to cast Fishing and the same key to reel in. Auto loot is on and the sound is turned up while you fish, and your settings come back when you stop.

## How to play
- Rotation, 1 mob, 2 mobs, 3+ mobs, pet and "in trouble" advice for all 27 specs.
- The advice changes as you learn new abilities.
- New abilities by level, your racials and ready-made macros (place them with one click).

## Settings
Everything can be turned on or off in the Settings window (`/mentor settings`), including "Tooltip details" for shorter tooltips. Your settings are remembered for all your characters.

## Commands
- `/mentor` - show or hide the window
- `/mentor settings` - settings
- `/mentor sell on|off` - sell advice
- `/mentor details on|off` - explanations in tooltips
- `/mentor pace on|off|reset` - Level pace window
- `/mentor vendor on|off` - Auto vendor
- `/mentor log` - Life log window (`/mentor lifelog off` turns it off)
- `/mentor mana on|off|low|critical` - Mana warning
- `/mentor fishing on|off` - One-key fishing window; `/mentor fish` starts / stops fishing, `/mentor fish key <KEY>` picks the key
- `/mentor journey` - zones, dungeons and professions for your level
- `/mentor tour` - the short tour again
- `/mentor bug` - report a bug

## Found a bug?
Click **Report bug** in the Mentor window (or type `/mentor bug`). Mentor collects all the details, and you paste them into the bug report form on GitHub: https://github.com/AreGundersen/Mentor/issues

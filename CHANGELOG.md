# Changelog

Changes are collected under **Unreleased** while we work. A new version
number is only given when Are decides the release is finished (see
`RELEASING.md`).

## Unreleased
- **Mentor looks like part of WoW:** "Where to get upgrades" and the Handbook use WoW's own window frame (title bar, round Mentor portrait, dark inset), and the Handbook has icon tabs down its right edge, like WoW Forever's own windows. On a client without these templates, Mentor keeps its own look.
- **Handbook:** the "Spells & racials" and "Macros" buttons are one "Handbook" button that opens the panel on the tab you used last. Its tabs are Mentor's own red buttons, in two rows so every label has room.
- Journey has headings (your professions, zones, dungeons, professions for you) instead of a tag on every row. Dungeons show where they are and how many upgrades they have; **click a dungeon** to see all its upgrades in "Where to get upgrades" ("Show all" goes back). Long texts are in the tooltip, and the level column has room from the border.
- **Auction house panel:** click an upgrade to search for it on the auction house; the panel keeps the upgrades from all your searches while the auction house is open.
- Factions: each row says what the next standing gives; hover for what every standing gives (perks and quartermaster gear); progress bars are all the same thickness.
- Test builds (+dev) have a test checklist for the developer (`/mentor check`); players never see it.
- **Dungeon upgrades on the way:** when you enter a dungeon, the tip names the best gear for you in it and who drops it ("Look out for: [Cruel Barb] from Edwin VanCleef (+40%)").
- **Upgrades on the auction house:** search the auction house (also through Auctionator) and a small Mentor panel next to it lists the results that are upgrades for you, best first, with the buyout price. Setting "Auction upgrades" under Gold.
- **New: Factions tab** (`/mentor rep`): your factions with their standing and a progress bar, one short line on what each faction gives you (hover for the details) (cities, the goblin towns, Timbermaw, Argent Dawn and more), and quartermaster gear that is an upgrade for you with the standing it needs - also from quartermasters you haven't met yet.
- **Profession window:** two new parts in Mentor's panel - "Your materials" (what you carry for your recipes, and the recipes that still give skill that you can craft right now) and "Tools" (Mining Pick, Skinning Knife, Blacksmith Hammer, Arclight Spanner, enchanting rods, fishing pole: which you have, which are missing and where to get them). A missing tool for a gathering profession also shows in the Journey tab.
- **Weapon skill reminder:** when the skill for the weapon you hold is far below its maximum (after switching weapon type), Mentor tells you and to fight easy mobs for a while. Setting "Weapon skill" under Reminders.
- **Trainer prices for all your characters:** the class trainer list is shared by your characters of the same class, so a new character sees ranks and prices before its first visit (marked as seen by your other character).

## 1.17.0 - 2026-11-18
- **Profession tools** (fishing poles, Skinning Knife, Mining Pick, Blacksmith Hammer) no longer get a red arrow or a sell coin in your bags: the tooltip says "Keep - Fishing tool" instead of calling them a downgrade.
- **Bug reports explain themselves** - writing is now optional. The report adds the items you hovered lately (with the exact tooltip text and Mentor's verdict), where you are, what every feature shows right now (bag arrows, procs, trainer prices, upgrades, Level pace, professions, reminders), problems Mentor handled quietly, and a log of what Mentor did lately - also from before your last /reload.
- **Support Mentor** now shows the Buy Me a Coffee page (buymeacoffee.com/AGundersen).
- The CurseForge description and README describe the new Upgrades, Spells and Level pace features.

## 1.16.0 - 2026-11-17
- **New: XP from finished quests in Level pace** - a "Quests done" line shows how much XP the finished quests in your quest log give when you hand them in, and turns green with "= level!" when that is enough to reach the next level.
- **New: ranks and prices in the Spells tab** - open your class trainer once and Mentor remembers its whole list (also the ranks you can't learn yet) with the price that trainer asks you, so your reputation discount is included. The Spells tab then shows new ranks of spells you already know, with the rank after the name and the price on the right, and puts the price on new spells too. Spells your spec uses (from its guide, the class' everyday spells, or already on your action bars) say "Train now!"; the rest say "Optional" and come after them. The line at the top says what the recommended training costs, and what everything costs. The list updates every time you visit a trainer. `/mentor trainer` shows what Mentor read.
- **New: Upgrades** - the "Find more" button next to "Upgrades in your bags" in the Mentor window (or `/mentor upgrades`) opens "Where to get upgrades": the dungeons for your level that drop gear better than yours for the spec you play, best dungeon first, with up to three items each (one per slot), how much better they are, and the boss that drops them on hover (shift-click links the item). Rewards from the dungeon's own quests are included with a gold "Quest" tag (only quests for your faction that you haven't done, and only the best choice when a quest lets you pick one). Yellow with the level when you can't wear it yet. Under the dungeons, "From vendors" lists up to four uncommon or better items you can simply buy with gold, with who sells them and where (zone and map coordinates) on hover - only vendors friendly to your faction, a vendor in your zone first (vendor data from Questie's classic database). Gear from the new Forever quartermasters (Darkspear Raiders and its Alliance counterpart, Ratchet, Booty Bay, Gadgetzan, Everlook, Riverglades, Zephras Isle) is there too with a blue "Rep" tag, the price, and the reputation it needs compared with yours - shown when you are at most one standing away. It sits beside the Mentor window like the Settings and Extras panels. Loot and quests from Wowhead's WoW Forever zone pages: every dungeon from Ragefire Chasm to Stratholme and Scholomance (Scarlet Monastery split into its four wings, Blackrock Spire into Lower and Upper) except Shaper's Terrace and City of Dalaran, which Wowhead has no list for yet; quest rewards for every dungeon except Ragefire Chasm.
- The tabs in the Spells / Racials / Macros / Journey / Weapons / Words panel get widths that fit their names, so "Weapons" is no longer squeezed.
- **Rings and trinkets** are compared with both of the ones you wear: the tooltip shows a line per worn ring / trinket ("vs Ring A: +12% (swap this one)", "vs Ring B: -3%"). Mentor's verdict is against the weaker one, the one to swap. Trinkets whose only effect is on-use say "no stats Mentor can rate".

## 1.15.0 - 2026-11-17

- **New: where the profession trainers are.** When a profession is stuck at its skill cap, the Journey tab's "visit a trainer" row names a trainer for the next rank in your faction, with the place and map coordinates, and the panel next to the profession window lists up to three trainers for your next rank (capital cities first). Includes the special Artisan trainers, for example Drakk Stonehand (Aerie Peak) and Hahrana Ironhide (Camp Mojache) for Leatherworking and Brikk Keencraft (Booty Bay) for Blacksmithing. From Wowhead's WoW Forever profession guides and NPC pages.
- **Profession leveling: when you don't have the recipe**, the panel says where to get it - your trainer, the vendor that sells it for your faction with the place, or the special trainer / questline - and suggests a recipe you already know that still gives skill (orange first, then yellow) to craft meanwhile. The same suggestion shows when the guide's recipe has gone grey.
- **Profession leveling is now on by default.**
- Settings: a description that wraps onto a third line makes its row taller, so rows no longer overlap; some descriptions are shorter.
- The version in the Mentor window moved to the bottom right corner: in the top right it was hidden behind the Life log / Settings buttons.

## 1.14.0 - 2026-11-17

- **New: Profession help**, a Mentor panel next to the profession window, with two settings under Extra tools:
  - **Profession leveling**: **what to craft to level up** (from Wowhead's WoW Forever leveling guides) - the recipe coloured by its skill-up chance, about how many to craft and to which skill, and the next step. Tells you when you don't know the recipe yet or when it has gone grey.
  - **Craftable upgrades** (on by default): your known recipes that make an upgrade for the spec you play, best first (yellow with the level when you can't wear it yet). Hover for the item; click any recipe in the panel to show it in the profession window. The panel sits beside the window's side tabs, level with its top.
  - With Profession leveling on, the Journey tab shows each of your professions with what to craft - or for Mining, Herbalism and Skinning, what to gather and where.
- **Mentor's version** is shown in the Mentor window (top right), in Settings, and with `/mentor version`.

- **Fixed (#6): a proc icon could get stuck** on screen after its time ran out, with a flickering timer. The timer no longer restarts every update, procs whose time is up always go away, and a spell with no listed cost (for example in a form) no longer counts as Clearcasting.
- **Fixed (#5): the gold frame on loot rolls** now sits around the dice / coin picture itself, not the button's (sometimes larger) click area.

- **New: Proc alerts.** When something procs - Shadow Trance (Nightfall), Clearcasting, Maelstrom Weapon at 5 stacks, Fingers of Frost, Missile Barrage, Hot Streak, Surge of Light, Infusion of Light and more, or Overpower / Revenge / Riposte / Counterattack / Mongoose Bite becoming usable in combat - Mentor shows it two ways, each with its own switch under Talents & play (both on by default):
  - **Proc icon**: a big pulsing icon under your character with what the proc does, what to press, stacks and time left.
  - **Proc glow**: a gold, pulsing frame on the action bar button to press (Blizzard's bars).
  - Works in combat too, where the game hides buff names: WoW Forever hides your buffs from addons in combat, so Mentor also watches what the proc does: Shadow Bolt, Lightning Bolt, Pyroblast and similar spells becoming instant, and your spells becoming free (Clearcasting).
  - The icon sits under your character (above the action bars) with the game's own gold button glow around it; `/mentor procs move` lets you drag it anywhere (`/mentor procs reset` puts it back).
  - `/mentor procs test` shows an example; `/mentor procs debug` shows what Mentor can read (use it in combat).

- **Fixed: Mob warnings and Kill count were missing in 1.13.0.** A change to the rested XP tip removed the mob tooltip code by mistake. Both are back, and the kill count now also shows on mobs whose tooltip gives no readable unit (for example quest objectives).

- **Life log is easier to read:**
  - A new **Overview** at the top: gold now, time played, kills, deaths, quests and level-ups.
  - **Gold on all your characters** together ("Gold now" in the All chars column), and each character's gold in the Characters list. Other characters are counted from their last login with Mentor 1.13.0 or newer.
  - Sections fold: click a header to open or close it. Overview and Characters start open; Mentor remembers what you open.
  - Rows that are 0 everywhere are hidden.

- **New: Feral (Tank) for druids.** Druids now pick between "Feral DPS" and "Feral Tank" (a fourth spec button). Feral (Tank) follows the Mobalytics Bear Tank leveling order, rates gear for a bear (more Stamina, Armor and Dodge), and has its own How to play page and a Mouseover Growl macro.
- Talent orders checked against the latest guides (Nov 2026):
  - **Now from a guide** (before Mentor's own order): Protection Paladin and Discipline Priest (Mobalytics), Survival Hunter (LudiDeo's 1-60 guide on Mobalytics), Destruction Warlock (Warcraft Tavern - Mobalytics has none).
  - **Updated** because the guide changed: Affliction Warlock and Elemental Shaman.
  - The other 21 were still the same.

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

--------------------------------------------------------------------------------
-- Mentor - Data.lua
-- Everything that is class/spec specific lives here:
--   * stat weights      how much each stat is worth for the spec (gear scoring)
--   * stat priority     a short human-readable priority line
--   * tips              one or two beginner tips per spec
--   * build             talent priority list, in the order points should go
--
-- Talent builds use the talent NAMES of the WoW Forever trees. All specs
-- follow a published level-by-level order, most of them the Mobalytics WoW Forever
-- guides (Nov 2026), including Protection Paladin, Discipline and Feral (Tank);
-- Survival follows LudiDeo's 1-60 guide on Mobalytics and Destruction the
-- Warcraft Tavern leveling guide (Mobalytics has no Destruction order).
-- The addon matches every name against the real tree it reads from the game. Names that do not exist are
-- skipped, and when a build step cannot be taken the addon suggests the best
-- learnable talent in your main tree instead. Nothing here can make it
-- recommend something that is not actually in your talent window.
--
-- Build entry format: { treeNumber, "Talent Name", totalRankWanted }
--   treeNumber = 1, 2 or 3 in the order of that class' talent tabs.
--   totalRankWanted = the rank the talent should have after this step, so the
--   same talent can appear twice (e.g. 3 points early, the last 2 later).
--------------------------------------------------------------------------------

local _, Mentor = ...

--------------------------------------------------------------------------------
-- Stat weights per spec, set from the stat priorities in the Mobalytics WoW
-- Forever guides (Nov 2026) for LEVELING. Keys are the stat names in Gear.lua:
--   STR AGI STA INT SPI ARMOR AP RAP          (per point)
--   CRIT HIT SPELLCRIT SPELLHIT DODGE PARRY BLOCK  (per 1%, valued at level
--        60 - Gear.lua scales them down at lower levels, see
--        Mentor.GetPercentStatFactor)
--   SPELLPOWER HEALING MP5 DEFENSE BLOCKVALUE (per point)
--   DPS        weapon damage per second for melee weapons
--   RANGED_DPS damage per second for the ranged slot (bows, guns, wands)
-- The numbers are relative: what matters is how they compare to each other.
-- A stat that is missing counts as 0 ("does nothing for your spec").
--------------------------------------------------------------------------------
local WEIGHTS = {
    -- Warriors: in Forever Spirit gives warriors by far the most health
    -- regeneration, so the guide ranks Spirit > Strength > Agility > Stamina.
    WARRIOR_DPS = {
        SPI = 1.05, STR = 1.0, AGI = 0.75, STA = 0.50, INT = 0.05, AP = 0.50, ARMOR = 0.01,
        HIT = 10, CRIT = 9, DPS = 6.0, RANGED_DPS = 0.3,
    },
    WARRIOR_TANK = {
        STA = 1.0, SPI = 0.90, STR = 0.85, AGI = 0.70, ARMOR = 0.05, DEFENSE = 1.0,
        DODGE = 8, PARRY = 7, BLOCK = 4, BLOCKVALUE = 0.30, HIT = 8, CRIT = 5, DPS = 2.5, AP = 0.40,
    },
    -- Retribution: weapon damage first (slow weapons for Seal of Command),
    -- then Stamina and Spirit for less downtime, Intellect from level 40.
    PALADIN_RET = {
        DPS = 7.0, STR = 0.80, STA = 0.80, SPI = 0.80, AGI = 0.40, AP = 0.40, INT = 0.35,
        SPELLPOWER = 0.40, MP5 = 1.0, CRIT = 9, HIT = 8, ARMOR = 0.01,
    },
    PALADIN_HOLY = {     -- Intellect > Spirit > Stamina > Strength > Agility
        INT = 1.0, HEALING = 0.90, SPELLPOWER = 0.90, SPI = 0.80, STA = 0.50, STR = 0.25, AGI = 0.15,
        MP5 = 2.0, SPELLCRIT = 6, DPS = 1.0, ARMOR = 0.01,
    },
    PALADIN_TANK = {     -- Defense, Stamina, Armor, Block; hit then spell power for threat
        STA = 1.0, DEFENSE = 1.2, ARMOR = 0.06, BLOCK = 5, BLOCKVALUE = 0.35, PARRY = 6, DODGE = 6,
        STR = 0.40, AGI = 0.40, INT = 0.30, SPI = 0.30, SPELLPOWER = 0.55, HIT = 8, CRIT = 4, DPS = 1.5,
    },
    -- Beast Mastery: Agility > Attack Power > Stamina > Spirit > Intellect.
    HUNTER_BM = {
        AGI = 1.0, RAP = 0.50, AP = 0.45, STA = 0.45, SPI = 0.35, INT = 0.30, STR = 0.05,
        CRIT = 10, HIT = 9, MP5 = 0.6, DPS = 1.0, RANGED_DPS = 6.0, ARMOR = 0.01,
    },
    -- Marksmanship / Survival: Careful Aim turns Intellect into attack power
    -- 1:1, and Rapid Recuperation / Resourcefulness make Spirit your mana.
    HUNTER_MM_SV = {
        AGI = 1.0, INT = 0.55, SPI = 0.45, STA = 0.35, RAP = 0.50, AP = 0.40, STR = 0.05,
        HIT = 11, CRIT = 11, MP5 = 0.8, DPS = 1.5, RANGED_DPS = 6.0, ARMOR = 0.01,
    },
    -- Rogues: Agility by far; Strength = Attack Power (1 Str = 1 AP); hit is
    -- the best secondary while leveling because auto attacks are so much damage.
    ROGUE = {
        AGI = 1.0, STR = 0.55, AP = 0.50, STA = 0.35, ARMOR = 0.01,
        HIT = 13, CRIT = 10, DPS = 6.0, RANGED_DPS = 0.5,
    },
    -- Shadow: Spell Power > Spirit > Intellect > Stamina > Crit > Hit > MP5.
    SHADOW_PRIEST = {
        SPELLPOWER = 1.0, SPI = 0.60, INT = 0.45, STA = 0.35,
        SPELLCRIT = 5, SPELLHIT = 4, MP5 = 0.6, RANGED_DPS = 3.0, ARMOR = 0.01,
    },
    -- Discipline leveling: Intellect and Spirit (Spirit Tap), then Stamina;
    -- avoid Strength and Agility. Holy Fire / Smite / wand do the damage.
    DISC_PRIEST = {
        INT = 0.80, SPI = 0.80, SPELLPOWER = 0.90, HEALING = 0.40, STA = 0.40,
        MP5 = 1.2, SPELLCRIT = 4, RANGED_DPS = 3.0, ARMOR = 0.01,
    },
    -- Holy: Spirit > Spell Power > Intellect > MP5 > Crit > Stamina.
    HOLY_PRIEST = {
        SPI = 1.0, SPELLPOWER = 0.90, HEALING = 0.80, INT = 0.75, MP5 = 1.5,
        SPELLCRIT = 5, STA = 0.30, RANGED_DPS = 2.5, ARMOR = 0.01,
    },
    -- Enhancement: Intellect (Mental Dexterity turns it into attack power) >
    -- Strength > Attack Power / Spell Power / Agility > Spirit; crit feeds Flurry.
    SHAMAN_ENH = {
        INT = 1.05, STR = 1.0, AP = 0.50, SPELLPOWER = 0.45, AGI = 0.55, SPI = 0.40, STA = 0.35,
        CRIT = 11, HIT = 6, DPS = 6.0, MP5 = 1.0, ARMOR = 0.01,
    },
    -- Elemental: Spell Power > Intellect > Spirit > Crit > Hit; a strong
    -- two-hander helps early because you finish mobs in melee.
    SHAMAN_ELE = {
        SPELLPOWER = 1.0, INT = 0.55, SPI = 0.45, STA = 0.30, SPELLCRIT = 7, SPELLHIT = 5,
        MP5 = 1.2, DPS = 1.5, ARMOR = 0.01,
    },
    -- Restoration shaman: healing, Intellect and regeneration (Spirit with
    -- Mindfulness, MP5), enough Stamina.
    SHAMAN_RESTO = {
        HEALING = 0.90, SPELLPOWER = 0.80, INT = 1.0, SPI = 0.55, MP5 = 2.0, STA = 0.40,
        SPELLCRIT = 6, DPS = 0.5, ARMOR = 0.01,
    },
    -- Mages: Spell Power and Intellect while leveling, Stamina for safety;
    -- hit, crit and haste are rare until late.
    MAGE = {
        SPELLPOWER = 1.0, INT = 0.50, SPI = 0.30, STA = 0.35,
        SPELLCRIT = 9, SPELLHIT = 10, MP5 = 1.0, RANGED_DPS = 2.5, ARMOR = 0.01,
    },
    -- Affliction / Demonology: Spell Power > Hit > Intellect > Stamina > Crit >
    -- Spirit (Life Tap scales with Spirit). Wands are big damage early.
    WARLOCK = {
        SPELLPOWER = 1.0, INT = 0.45, STA = 0.40, SPI = 0.25,
        SPELLHIT = 10, SPELLCRIT = 6, MP5 = 0.8, RANGED_DPS = 3.5, ARMOR = 0.01,
    },
    -- Destruction: Spell Power (fire) > Crit (Ruin) > Hit.
    WARLOCK_DESTRO = {
        SPELLPOWER = 1.0, INT = 0.45, STA = 0.35, SPI = 0.20,
        SPELLCRIT = 9, SPELLHIT = 9, MP5 = 0.8, RANGED_DPS = 3.0, ARMOR = 0.01,
    },
    -- Balance: Crit > Spell Power > Intellect > Stamina > Spirit.
    DRUID_BALANCE = {
        SPELLPOWER = 1.0, INT = 0.50, STA = 0.40, SPI = 0.30,
        SPELLCRIT = 12, SPELLHIT = 8, MP5 = 1.0, ARMOR = 0.01,
    },
    -- Feral: NEW in Forever - your weapon's DPS counts in cat and bear form
    -- (speed is normalized). Then Strength = Agility, Stamina and Spirit.
    -- About 10-11 Strength = 1% hit or crit at level 60.
    DRUID_FERAL = {
        DPS = 6.5, STR = 1.0, AGI = 1.0, AP = 0.50, STA = 0.55, SPI = 0.50, ARMOR = 0.02,
        CRIT = 10.5, HIT = 10.5, DODGE = 4, INT = 0.05,
    },
    -- Feral (Tank): while leveling the same as Feral (weapon DPS, Strength,
    -- Agility), with more weight on what keeps a bear alive in dungeons:
    -- Stamina, Armor (bears multiply it) and Dodge (bears can't block or parry).
    DRUID_BEAR = {
        DPS = 5.0, STR = 1.0, AGI = 1.0, AP = 0.45, STA = 0.90, SPI = 0.35, ARMOR = 0.06,
        DODGE = 9, DEFENSE = 0.8, HIT = 9, CRIT = 7, INT = 0.05,
    },
    -- Restoration druid: Healing > Intellect = Spirit >> Stamina.
    DRUID_RESTO = {
        HEALING = 1.0, SPELLPOWER = 0.85, INT = 0.60, SPI = 0.60, STA = 0.30, AGI = 0.10, STR = 0.05,
        MP5 = 1.5, SPELLCRIT = 5, ARMOR = 0.01,
    },
}

--------------------------------------------------------------------------------
-- Class data. Specs are numbered in the order of the class' talent tabs.
-- defaultSpec is used before the first talent point is spent.
--------------------------------------------------------------------------------
Mentor.CLASS_DATA = {
    ----------------------------------------------------------------------------
    WARRIOR = {
        defaultSpec = 1,
        specs = {
            {
                name = "Arms", role = "Melee damage", weights = WEIGHTS.WARRIOR_DPS,
                statPriority = "Spirit > Strength > Agility > Stamina > weapon DPS",
                tips = { "Use a two-handed weapon. Big slow weapons hit harder.",
                         "Keep Rend and Battle Shout up; use Overpower when it lights up." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Warrior leveling guide
                    {1, "Improved Rend", 3}, {1, "Deflection", 2}, {1, "Improved Overpower", 2},
                    {1, "Improved Charge", 2}, {1, "Deflection", 3}, {1, "Deep Wounds", 3},
                    {1, "Deflection", 5}, {1, "Spearing Strike", 1},
                    {1, "Two-Handed Weapon Specialization", 3}, {1, "Impale", 1}, {1, "Sweeping Strikes", 1},
                    {1, "Bloodthrill", 2}, {1, "Impale", 2}, {1, "Weaponmaster", 1}, {1, "Improved Slam", 1},
                    {1, "Weaponmaster", 5}, {1, "Mortal Strike", 1}, {1, "Improved Slam", 2},
                    {2, "Cruelty", 5}, {2, "Unbridled Wrath", 5}, {2, "Enrage", 5}, {2, "Piercing Howl", 1},
                    {2, "Reckless Swings", 1}, {2, "Lingering Rage", 2},
                },
            },
            {
                name = "Fury", role = "Melee damage", weights = WEIGHTS.WARRIOR_DPS,
                statPriority = "Spirit > Strength > Agility > Stamina > weapon DPS",
                tips = { "Use two one-handed weapons once you have Dual Wield.",
                         "Use Bloodthirst on cooldown and Whirlwind when there are several enemies." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Warrior leveling guide
                    {2, "Cruelty", 5}, {2, "Unbridled Wrath", 5}, {2, "Enrage", 2}, {2, "Blood Craze", 3},
                    {2, "Reckless Swings", 1}, {2, "Dual Wield Specialization", 4}, {2, "Death Wish", 1},
                    {2, "Gore Drinker", 2}, {2, "Dual Wield Specialization", 5}, {2, "Enrage", 3},
                    {2, "Flurry", 3}, {2, "Improved Whirlwind", 2}, {2, "Bloodthirst", 1}, {2, "Enrage", 5},
                    {2, "Furious Precision", 3}, {1, "Deflection", 5}, {2, "Improved Execute", 2},
                    {2, "Improved Berserker Rage", 2}, {1, "Improved Overpower", 2},
                    {1, "Improved Tactical Mastery", 3}, {1, "Anger Management", 1},
                },
            },
            {
                name = "Protection", role = "Tank", weights = WEIGHTS.WARRIOR_TANK,
                statPriority = "Stamina > Spirit > Strength > Agility > Armor",
                tips = { "Use a one-handed weapon and a shield.",
                         "Sunder Armor and Revenge build threat; keep Thunder Clap on groups." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Warrior leveling guide
                    {3, "Shield Specialization", 5}, {3, "Improved Revenge", 3},
                    {3, "Improved Thunder Clap", 2}, {3, "Master of Defense", 2}, {3, "Last Stand", 1},
                    {3, "Improved Thunder Clap", 3}, {3, "Defiance", 1}, {3, "Vanguard", 1},
                    {3, "Defiance", 3}, {3, "Improved Bloodrage", 2}, {3, "Concussion Blow", 1},
                    {3, "Focused Rage", 3}, {3, "Improved Shield Wall", 1}, {3, "Bastion", 5},
                    {3, "Shield Slam", 1}, {2, "Cruelty", 5}, {2, "Lingering Rage", 5}, {2, "Enrage", 5},
                    {1, "Improved Rend", 3}, {1, "Deflection", 2},
                },
            },
        },
    },
    ----------------------------------------------------------------------------
    PALADIN = {
        defaultSpec = 3,
        specs = {
            {
                name = "Holy", role = "Healer", weights = WEIGHTS.PALADIN_HOLY,
                statPriority = "Intellect > Spirit > Stamina > Strength > Agility",
                tips = { "Use Flash of Light for most healing; Holy Light for big hits.",
                         "Stand still between fights to regain mana, or drink." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Holy Paladin guide
                    {1, "Spiritual Focus", 5}, {1, "Reverence", 2}, {1, "Healing Light", 3},
                    {1, "Illumination", 5}, {1, "Oath of Light", 1}, {1, "Divine Favor", 1},
                    {1, "Infusion of Light", 2}, {1, "Divine Precision", 1}, {1, "Holy Shock", 1},
                    {1, "Boundless Light", 2}, {1, "Divine Precision", 2}, {1, "Holy Conduit", 1},
                    {1, "Holy Power", 5}, {1, "Light's Vigil", 1}, {3, "Benediction", 5},
                    {3, "Conviction", 3}, {2, "Divine Intellect", 5}, {3, "Sanctified Judgement", 2},
                    {3, "Pursuit of Justice", 2}, {1, "Holy Conduit", 2}, {3, "Sanctified Judgement", 3},
                    {1, "Purifying Power", 1},
                },
            },
            {
                name = "Protection", role = "Tank", weights = WEIGHTS.PALADIN_TANK,
                statPriority = "Defense > Stamina > Armor > Block > Hit",
                tips = { "Righteous Fury must be on while tanking.",
                         "Consecration and Holy Shield keep threat on groups." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Protection Paladin guide (Nov 2026)
                    {2, "Redoubt", 5}, {2, "Precision", 3}, {2, "Sacred Duty", 2}, {2, "Shield Specialization", 2},
                    {2, "Templar's Bulwark", 1}, {2, "Toughness", 2}, {2, "Swift Judgement", 1}, {2, "Improved Righteous Fury", 3},
                    {2, "Anticipation", 1}, {2, "Holy Shield", 1}, {2, "Reckoning", 5}, {2, "Iron Creed", 3},
                    {2, "Anticipation", 2}, {2, "Shieldsworn", 1}, {3, "Deflection", 5}, {3, "Improved Judgement", 2},
                    {3, "Conviction", 3}, {3, "Pursuit of Justice", 2}, {2, "Anticipation", 5}, {2, "Toughness", 5},
                    {2, "Guardian's Favor", 2},
                },
            },
            {
                name = "Retribution", role = "Melee damage", weights = WEIGHTS.PALADIN_RET,
                statPriority = "Weapon DPS > Stamina > Spirit > Strength > Intellect",
                tips = { "Use a slow two-handed weapon; Seal of Command loves slow weapons.",
                         "Judge your seal, then put it back on." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Paladin leveling guide
                    {3, "Deflection", 5}, {3, "Conviction", 3}, {3, "Improved Judgement", 2},
                    {3, "Pursuit of Justice", 2}, {3, "Seal of Command", 1}, {3, "Sanctified Judgement", 2},
                    {3, "Two-Handed Weapon Specialization", 3}, {3, "Sacred Arbiter", 1},
                    {3, "Sanctified Judgement", 3}, {3, "Vengeance", 3}, {3, "Repentance", 1},
                    {3, "Benediction", 1}, {3, "Champion of the Light", 5}, {3, "Unsealed Wrath", 1},
                    {1, "Divine Strength", 5}, {1, "Reverence", 2}, {1, "Improved Seals", 5},
                    {2, "Divine Intellect", 5}, {2, "Precision", 3},
                },
            },
        },
    },
    ----------------------------------------------------------------------------
    HUNTER = {
        defaultSpec = 1,
        specs = {
            {
                name = "Beast Mastery", role = "Ranged damage", weights = WEIGHTS.HUNTER_BM,
                statPriority = "Agility > Attack Power > Stamina > Spirit > Intellect",
                tips = { "Let your pet tank, then shoot. Feed your pet to keep it happy.",
                         "Keep Aspect of the Hawk on while fighting." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Hunter leveling guide
                    {1, "Deadly Aspects", 5}, {1, "Focused Fire", 2}, {1, "Improved Revive Pet", 2},
                    {1, "Endurance Training", 1}, {1, "Pathfinding", 2}, {1, "Bestial Swiftness", 1},
                    {1, "Unleashed Fury", 2}, {1, "Summon Hawk", 1}, {1, "Unleashed Fury", 4},
                    {1, "Ferocity", 2}, {1, "Intimidation", 1}, {1, "Bestial Discipline", 2},
                    {1, "Ferocity", 5}, {1, "Frenzy", 4}, {1, "Bestial Wrath", 1}, {2, "Lethal Attacks", 5},
                    {2, "Careful Aim", 5}, {2, "Rapid Killing", 2}, {2, "Hawk Eye", 3},
                    {2, "Trueshot Aura", 1}, {2, "Mortal Shots", 4},
                },
            },
            {
                name = "Marksmanship", role = "Ranged damage", weights = WEIGHTS.HUNTER_MM_SV,
                statPriority = "Agility > Intellect > Spirit > Stamina > Hit",
                tips = { "Open with Aimed Shot, then Multi-Shot and Arcane Shot.",
                         "Keep your distance: you deal no ranged damage up close." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Marksmanship Hunter guide
                    {2, "Lethal Attacks", 5}, {2, "Careful Aim", 5}, {2, "Improved Stings", 3},
                    {2, "Rapid Killing", 2}, {2, "Mortal Shots", 4}, {2, "Trueshot Aura", 1},
                    {2, "Rapid Recuperation", 2}, {2, "Barrage", 3}, {2, "Ranged Weapon Specialization", 5},
                    {2, "Mortal Shots", 5}, {2, "Sniper Shot", 1}, {1, "Deadly Aspects", 5},
                    {3, "Improved Tracking", 5}, {3, "Savage Strikes", 2}, {3, "Survivalist", 3},
                    {3, "Clever Traps", 2}, {1, "Focused Fire", 2},
                },
            },
            {
                name = "Survival", role = "Ranged damage", weights = WEIGHTS.HUNTER_MM_SV,
                statPriority = "Agility > Intellect > Spirit > Stamina > Hit",
                tips = { "Survival turns Agility into extra damage - stack it.",
                         "Freezing Trap is your emergency button against a second enemy." },
                build = {
                    -- Exact leveling order from LudiDeo's Survival Hunter 1-60 guide on Mobalytics ("Leveling 2H Weave", Nov 2026)
                    {3, "Improved Tracking", 5}, {3, "Savage Strikes", 2}, {3, "Survivalist", 3}, {3, "Surefooted", 3},
                    {3, "Clever Traps", 2}, {3, "Predator's Edge", 5}, {3, "Strider Kick", 1}, {3, "Expose Prey", 2},
                    {3, "Survivalist's Discipline", 2}, {3, "Lightning Reflexes", 5}, {3, "Lacerating Strikes", 1}, {2, "Lethal Attacks", 5},
                    {1, "Deadly Aspects", 5}, {2, "Careful Aim", 5}, {1, "Focused Fire", 2}, {2, "Improved Stings", 3},
                },
            },
        },
    },
    ----------------------------------------------------------------------------
    ROGUE = {
        defaultSpec = 2,
        specs = {
            {
                name = "Assassination", role = "Melee damage", weights = WEIGHTS.ROGUE,
                statPriority = "Agility > Strength > Attack Power > Stamina > Hit",
                tips = { "Put poisons on your weapons - they are free damage.",
                         "Keep Slice and Dice up, then spend combo points on Eviscerate." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Rogue leveling guide
                    {1, "Remorseless Attacks", 2}, {2, "Efficient Strikes", 2}, {1, "Malice", 3},
                    {1, "Improved Slice and Dice", 3}, {1, "Malice", 5}, {1, "Vigor", 2},
                    {1, "Ruthlessness", 3}, {1, "Cold Blood", 1}, {1, "Improved Poisons", 4},
                    {1, "Venom", 1}, {1, "Relentless Strikes", 4}, {1, "Seal Fate", 3},
                    {1, "Relentless Strikes", 5}, {1, "Improved Poisons", 5}, {1, "Mutilate", 1},
                    {2, "Lightning Reflexes", 3}, {2, "Deflection", 3}, {2, "Precision", 2},
                    {2, "Riposte", 1}, {2, "Precision", 3}, {3, "Opportunity", 5}, {1, "Vile Poisons", 3},
                },
            },
            {
                name = "Combat", role = "Melee damage", weights = WEIGHTS.ROGUE,
                statPriority = "Agility > Strength > Attack Power > Stamina > Hit",
                tips = { "Use a slow sword or mace in your main hand, a fast one in the off hand.",
                         "Sinister Strike to build combo points, Slice and Dice, then Eviscerate." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Rogue leveling guide
                    {1, "Remorseless Attacks", 2}, {2, "Efficient Strikes", 2}, {2, "Coup de Grace", 3},
                    {2, "Deflection", 3}, {2, "Precision", 2}, {2, "Riposte", 1}, {2, "Precision", 3},
                    {2, "Endurance", 2}, {2, "Lightning Reflexes", 1}, {2, "Weapon Expertise", 2},
                    {2, "Aggression", 3}, {2, "Blade Flurry", 1}, {2, "Dual Wield Specialization", 2},
                    {2, "Hack and Slash", 2}, {2, "Flash of Steel", 5}, {2, "Adrenaline Rush", 1},
                    {2, "Hack and Slash", 5}, {1, "Malice", 3}, {1, "Improved Slice and Dice", 3},
                    {1, "Malice", 5}, {1, "Vigor", 2}, {1, "Blood Splatter", 1}, {1, "Lethality", 2},
                    {1, "Cold Blood", 1}, {2, "Flawless Execution", 1},
                },
            },
            {
                name = "Subtlety", role = "Melee damage", weights = WEIGHTS.ROGUE,
                statPriority = "Agility > Strength > Attack Power > Stamina > Hit",
                tips = { "Open from stealth with Ambush using a dagger in your main hand.",
                         "Hemorrhage replaces Sinister Strike once you have it." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Rogue leveling guide
                    {1, "Remorseless Attacks", 2}, {3, "Setup", 3}, {3, "Opportunity", 2},
                    {3, "Dirty Deeds", 2}, {3, "Opportunity", 5}, {3, "Serrated Blades", 3},
                    {3, "Premeditation", 1}, {3, "Initiative", 1}, {3, "Ghostly Strike", 1},
                    {3, "Initiative", 3}, {3, "Elusiveness", 2}, {3, "Hemorrhage", 1}, {3, "Preparation", 1},
                    {3, "Heightened Senses", 2}, {3, "Camouflage", 1}, {3, "Boot Knife", 5},
                    {3, "Death Mark", 1}, {2, "Efficient Strikes", 2}, {2, "Coup de Grace", 3},
                    {2, "Deflection", 3}, {2, "Precision", 2}, {2, "Riposte", 1}, {2, "Precision", 3},
                    {2, "Composure", 2}, {1, "Malice", 3}, {1, "Improved Slice and Dice", 1},
                },
            },
        },
    },
    ----------------------------------------------------------------------------
    PRIEST = {
        defaultSpec = 3,
        specs = {
            {
                name = "Discipline", role = "Healer", weights = WEIGHTS.DISC_PRIEST,
                statPriority = "Intellect > Spirit > Spell Power > Stamina > Wand DPS",
                tips = { "Power Word: Shield before the damage comes.",
                         "Use a wand when you are low on mana while soloing." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Discipline Priest guide (Nov 2026)
                    {1, "Wand Specialization", 2}, {3, "Spirit Tap", 5}, {1, "Twin Disciplines", 5}, {1, "Mental Strength", 3},
                    {1, "Meditation", 3}, {1, "Inner Focus", 1}, {1, "Improved Power Word: Shield", 3}, {1, "Soul Warding", 1},
                    {1, "Mental Agility", 2}, {1, "Penance", 1}, {1, "Renewed Hope", 4}, {1, "Divine Aegis", 3},
                    {1, "Renewed Hope", 5}, {1, "Mental Agility", 3}, {1, "Power Infusion", 1}, {2, "Holy Specialization", 5},
                    {2, "Twilight Focus", 3}, {2, "Improved Renew", 2}, {2, "Holy Nova", 1}, {2, "Inspiration", 3},
                    {2, "Improved Renew", 3},
                },
            },
            {
                name = "Holy", role = "Healer", weights = WEIGHTS.HOLY_PRIEST,
                statPriority = "Spirit > Spell Power > Intellect > MP5 > Crit",
                tips = { "Renew on the tank, Flash Heal for emergencies, Greater Heal for big damage.",
                         "Spirit is great for you: it fuels Spiritual Guidance." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Holy Priest guide
                    {1, "Wand Specialization", 2}, {3, "Spirit Tap", 5}, {2, "Twilight Focus", 3},
                    {2, "Improved Renew", 2}, {2, "Divine Fury", 5}, {2, "Holy Nova", 1},
                    {2, "Improved Renew", 3}, {2, "Inspiration", 3}, {2, "Holy Binding", 1},
                    {2, "Holy Reach", 2}, {2, "Improved Healing", 2}, {2, "Spiritual Guidance", 5},
                    {2, "Spiritual Healing", 3}, {2, "Spirit of Redemption", 1}, {2, "Litany of Light", 1},
                    {2, "Prayer of Mending", 1}, {2, "Litany of Light", 2}, {1, "Twin Disciplines", 5},
                    {1, "Mental Strength", 3}, {1, "Meditation", 3}, {1, "Inner Focus", 1},
                },
            },
            {
                name = "Shadow", role = "Caster damage", weights = WEIGHTS.SHADOW_PRIEST,
                statPriority = "Spell Power > Spirit > Intellect > Stamina > Crit",
                tips = { "Shadow Word: Pain, Mind Blast, then Mind Flay. Use a wand to finish.",
                         "Spirit Tap gives huge mana regen after a kill - stay out of combat to use it." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Priest leveling guide
                    {1, "Wand Specialization", 2}, {3, "Spirit Tap", 5},
                    {3, "Improved Shadow Word: Pain", 2}, {3, "Shadow Reach", 2}, {3, "Shadow Focus", 1},
                    {3, "Mind Flay", 1}, {3, "Improved Mind Flay", 2}, {3, "Shadow Focus", 3},
                    {3, "Vampiric Embrace", 1}, {3, "Shadow Weaving", 3}, {3, "Shadow Focus", 4},
                    {3, "Silence", 1}, {3, "Devouring Contagion", 2}, {3, "Shadow Focus", 5},
                    {3, "Improved Mind Blast", 1}, {3, "Early Demise", 2}, {3, "Darkness", 3},
                    {3, "Shadowform", 1}, {3, "Darkness", 5}, {2, "Twilight Focus", 3},
                    {1, "Twin Disciplines", 5}, {1, "Mental Strength", 3}, {1, "Meditation", 3},
                    {1, "Inner Focus", 1}, {1, "Mental Strength", 4},
                },
            },
        },
    },
    ----------------------------------------------------------------------------
    SHAMAN = {
        defaultSpec = 2,
        specs = {
            {
                name = "Elemental", role = "Caster damage", weights = WEIGHTS.SHAMAN_ELE,
                statPriority = "Spell Power > Intellect > Spirit > Crit > Hit",
                tips = { "Lightning Bolt is your main spell; Flame Shock and Earth Shock are instant.",
                         "Drop a Searing Totem when you fight." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Elemental Shaman guide (updated Nov 2026)
                    {1, "Convection", 5}, {1, "Elemental Alacrity", 3}, {1, "Call of Flame", 2}, {1, "Elemental Focus", 1},
                    {1, "Call of Flame", 3}, {1, "Concussion", 3}, {1, "Eye of the Storm", 3}, {1, "Trial by Fire", 2},
                    {1, "Call of Thunder", 1}, {1, "Lightning Overload", 3}, {1, "Earthbound", 1}, {1, "Concussion", 5},
                    {1, "Elemental Reach", 2}, {1, "Elemental Fury", 1}, {1, "Lightning Mastery", 1}, {3, "Tidal Focus", 5},
                    {3, "Mindfulness", 3}, {2, "Thundering Strikes", 5}, {3, "Totemic Focus", 2}, {3, "Water Shield", 1},
                    {2, "Earth's Grasp", 2}, {2, "Ancestral Knowledge", 2},
                },
            },
            {
                name = "Enhancement", role = "Melee damage", weights = WEIGHTS.SHAMAN_ENH,
                statPriority = "Intellect > Strength > Agility > Spell Power > Spirit",
                tips = { "Use the slowest two-handed weapon you can find - Windfury loves slow weapons.",
                         "Rockbiter/Windfury Weapon on your weapon, Strength of Earth Totem down, Stormstrike on cooldown." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Shaman leveling guide
                    {2, "Thundering Strikes", 5}, {2, "Mental Dexterity", 3}, {2, "Ancestral Knowledge", 2},
                    {2, "Shamanistic Focus", 1}, {2, "Elemental Weapons", 3}, {2, "Ancestral Knowledge", 3},
                    {2, "Stormstrike", 1}, {2, "Improved Ghost Wolf", 2}, {2, "Flurry", 2},
                    {2, "Improved Stormstrike", 2}, {3, "Tidal Focus", 5}, {3, "Mindfulness", 3},
                    {3, "Totemic Focus", 2}, {3, "Water Shield", 1}, {2, "Mental Quickness", 2},
                    {2, "Flurry", 3}, {2, "Maelstrom Weapon", 5}, {2, "Rage of the Farseer", 1},
                    {2, "Spirit Weapons", 1}, {2, "Flurry", 5}, {2, "Ancestral Knowledge", 5},
                    {1, "Concussion", 4},
                },
            },
            {
                name = "Restoration", role = "Healer", weights = WEIGHTS.SHAMAN_RESTO,
                statPriority = "Healing > Intellect > MP5 > Spirit > Stamina",
                tips = { "Lesser Healing Wave is fast, Healing Wave is efficient, Chain Heal for groups.",
                         "Mana Spring Totem keeps your mana up in dungeons." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Restoration Shaman guide
                    {3, "Improved Healing Wave", 5}, {3, "Mindfulness", 3}, {3, "Tidal Focus", 2},
                    {3, "Water Shield", 1}, {3, "Tidal Focus", 5}, {3, "Ancestral Healing", 1},
                    {3, "Mana Tide Totem", 1}, {3, "Healing Focus", 3}, {3, "Ancestral Healing", 2},
                    {3, "Nature's Swiftness", 1}, {3, "Healing Way", 3}, {3, "Ancestral Healing", 3},
                    {3, "Purification", 5}, {3, "Riptide", 1}, {3, "Tidal Mastery", 5},
                    {3, "Totemic Focus", 5}, {3, "Restorative Totems", 5}, {2, "Ancestral Knowledge", 5},
                },
            },
        },
    },
    ----------------------------------------------------------------------------
    MAGE = {
        defaultSpec = 3,
        specs = {
            {
                name = "Arcane", role = "Caster damage", weights = WEIGHTS.MAGE,
                statPriority = "Spell Power > Intellect > Stamina > Spirit > Crit",
                tips = { "Arcane Missiles and Arcane Explosion hit hard but cost a lot of mana.",
                         "Conjure food and water - you never need to buy any." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Mage leveling guide
                    {1, "Improved Channeling", 5}, {1, "Missile Barrage", 2}, {1, "Arcane Subtlety", 2},
                    {1, "Arcane Concentration", 1}, {1, "Arcane Blast", 1}, {3, "Precision", 3},
                    {1, "Arcane Concentration", 5}, {1, "Arcane Wrath", 1}, {1, "Arcane Meditation", 3},
                    {1, "Arcane Impact", 1}, {1, "Presence of Mind", 1}, {1, "Arcane Mind", 4},
                    {1, "Arcane Instability", 3}, {1, "Arcane Mind", 5}, {1, "Arcane Impact", 2},
                    {1, "Arcane Power", 1}, {1, "Arcane Impact", 3}, {2, "Incineration", 5},
                    {2, "Accelerant", 5}, {2, "Improved Fire Blast", 2}, {1, "Arcane Geometry", 2},
                    {1, "Magic Absorption", 2},
                },
            },
            {
                name = "Fire", role = "Caster damage", weights = WEIGHTS.MAGE,
                statPriority = "Spell Power > Intellect > Stamina > Spirit > Crit",
                tips = { "Fireball is your main spell; Fire Blast is instant for finishing.",
                         "Pyroblast is a great opener when the enemy has not seen you." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Mage leveling guide
                    {2, "Accelerant", 5}, {3, "Precision", 3}, {2, "Ignite", 5}, {2, "Pyroblast", 1},
                    {2, "Burning Soul", 3}, {2, "Improved Fire Blast", 1}, {2, "Heating Up", 1},
                    {2, "Improved Fire Blast", 2}, {2, "Master of Elements", 3}, {2, "Blast Wave", 1},
                    {2, "Critical Mass", 3}, {2, "Flame Throwing", 1}, {2, "Fire Power", 3},
                    {2, "Flame Throwing", 2}, {2, "Incineration", 1}, {2, "Combustion", 1},
                    {1, "Improved Channeling", 5}, {1, "Missile Barrage", 1}, {1, "Arcane Concentration", 5},
                    {1, "Missile Barrage", 2}, {1, "Arcane Subtlety", 2}, {1, "Arcane Blast", 1},
                    {1, "Arcane Meditation", 2},
                },
            },
            {
                name = "Frost", role = "Caster damage", weights = WEIGHTS.MAGE,
                statPriority = "Spell Power > Intellect > Stamina > Spirit > Crit",
                tips = { "Frostbolt slows enemies so they never reach you. Frost Nova if they do.",
                         "Frost is the easiest and safest way to level a mage." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Mage leveling guide
                    {3, "Improved Frostbolt", 5}, {3, "Precision", 3}, {3, "Frostbite", 2},
                    {3, "Ice Lance", 1}, {3, "Ice Shards", 4}, {3, "Ice Block", 1}, {3, "Shatter", 3},
                    {3, "Ice Shards", 5}, {3, "Fingers of Frost", 2}, {3, "Cold Snap", 1},
                    {3, "Improved Cone of Cold", 2}, {3, "Winter's Chill", 5}, {3, "Ice Barrier", 1},
                    {3, "Improved Cone of Cold", 3}, {3, "Frostbite", 3}, {3, "Frost Channeling", 3},
                    {3, "Improved Blizzard", 3}, {1, "Improved Channeling", 5}, {1, "Missile Barrage", 1},
                    {1, "Arcane Subtlety", 2}, {1, "Arcane Concentration", 4},
                },
            },
        },
    },
    ----------------------------------------------------------------------------
    WARLOCK = {
        defaultSpec = 1,
        specs = {
            {
                name = "Affliction", role = "Caster damage", weights = WEIGHTS.WARLOCK,
                statPriority = "Spell Power > Hit > Intellect > Stamina > Crit",
                tips = { "Corruption and Bane of Agony on everything - your dots can crit in Forever.",
                         "Nightfall gives free instant Shadow Bolts - use them right away." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Warlock leveling guide (updated Nov 2026)
                    {1, "Improved Corruption", 5}, {1, "Suppression", 4}, {1, "Improved Drains", 3}, {1, "Fel Concentration", 3},
                    {1, "Soul Harvest", 2}, {1, "Nightfall", 2}, {1, "Grim Reach", 1}, {1, "Siphon Life", 1},
                    {1, "Soul Siphon", 3}, {1, "Grim Reach", 2}, {1, "Shadow Mastery", 5}, {1, "Wrack", 1},
                    {1, "Improved Bane of Agony", 2}, {1, "Pandemic", 3}, {1, "Amplify Curse", 1}, {1, "Curse of Exhaustion", 1},
                    {1, "Malevolence", 2}, {3, "Improved Shadow Bolt", 5}, {3, "Bane", 5}, {3, "Shadowburn", 1},
                },
            },
            {
                name = "Demonology", role = "Caster damage", weights = WEIGHTS.WARLOCK,
                statPriority = "Spell Power > Hit > Intellect > Stamina > Crit",
                tips = { "Your demon does a lot of the work - the Voidwalker tanks for you.",
                         "Health Funnel keeps your pet alive in long fights." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Warlock leveling guide
                    {1, "Improved Corruption", 1}, {2, "Unholy Power", 5}, {2, "Demonic Energies", 2},
                    {2, "Fel Vitality", 3}, {2, "Master Summoner", 2}, {2, "Improved Sayaad", 3},
                    {2, "Demonic Brand", 3}, {2, "Fel Domination", 1}, {2, "Demonic Sacrifice", 1},
                    {2, "Soul Link", 1}, {2, "Demonic Knowledge", 3}, {2, "Demonic Embrace", 1},
                    {2, "Master Demonologist", 5}, {2, "Demonic Pact", 1}, {1, "Improved Corruption", 5},
                    {1, "Suppression", 5}, {1, "Pandemic", 3}, {1, "Improved Bane of Agony", 2},
                    {1, "Malevolence", 5},
                },
            },
            {
                name = "Destruction", role = "Caster damage", weights = WEIGHTS.WARLOCK_DESTRO,
                statPriority = "Spell Power > Crit > Hit > Intellect > Stamina",
                tips = { "Shadow Bolt is your main nuke; Shadowburn finishes enemies.",
                         "Destruction hits hard but costs mana - keep Life Tap ready." },
                build = {
                    -- Leveling order from the Warcraft Tavern WoW Forever Warlock leveling guide (Destruction build; Mobalytics has none)
                    {3, "Bane", 5}, {3, "Cataclysm", 3}, {3, "Aftermath", 2}, {3, "Shadowburn", 1},
                    {3, "Aftermath", 5}, {3, "Ruin", 1}, {3, "Conflagrate", 1}, {3, "Ruin", 3},
                    {3, "Agonizing Flames", 3}, {3, "Bane of Havoc", 1}, {3, "Fire and Brimstone", 3}, {3, "Shadow and Flame", 5},
                    {3, "Incinerate", 1}, {1, "Suppression", 5}, {1, "Improved Life Tap", 2}, {1, "Improved Corruption", 5},
                    {2, "Improved Imp", 3}, {1, "Amplify Curse", 1}, {1, "Pandemic", 3}, {1, "Malevolence", 1},
                },
            },
        },
    },
    ----------------------------------------------------------------------------
    DRUID = {
        defaultSpec = 2,
        -- Order of the spec buttons: Balance, Feral (Damage), Feral (Tank), Restoration.
        specButtonOrder = { 1, 2, 4, 3 },
        specs = {
            {
                name = "Balance", role = "Caster damage", weights = WEIGHTS.DRUID_BALANCE,
                statPriority = "Crit > Spell Power > Intellect > Stamina > Spirit",
                tips = { "Moonfire and Insect Swarm, then Wrath or Starfire.",
                         "Entangling Roots keeps melee enemies away from you." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Balance Druid guide
                    {1, "Improved Wrath", 5}, {1, "Moonglow", 3}, {1, "Improved Moonfire", 2},
                    {1, "Nature's Majesty", 2}, {1, "Nature's Splendor", 1}, {1, "Nature's Reach", 2},
                    {1, "Insect Swarm", 1}, {3, "Nature's Focus", 5}, {3, "Reflection", 3},
                    {1, "Improved Starfire", 4}, {1, "Nature's Grace", 1}, {1, "Eclipse", 3},
                    {1, "Improved Starfire", 5}, {1, "Moonfury", 5}, {1, "Moonkin Form", 1},
                    {3, "Naturalist", 5}, {1, "Genesis", 5}, {1, "Vengeance", 2},
                },
            },
            {
                -- treeName: the talent tree this spec uses (the name differs from the tree's).
                name = "Feral (Damage)", buttonName = "Feral DPS", treeName = "Feral Combat", role = "Melee damage", weights = WEIGHTS.DRUID_FERAL,
                statPriority = "Weapon DPS > Strength > Agility > Stamina > Spirit",
                tips = { "Cat Form for damage, Bear Form when you need to survive (or pick Feral (Tank) to tank).",
                         "Your weapon's damage does not matter in forms - only its stats do." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Druid leveling guide
                    {2, "Ferocity", 3}, {2, "Furor", 5}, {2, "Feral Swiftness", 2},
                    {2, "Sharpened Claws", 2}, {2, "Savage Fury", 2}, {2, "Feral Charge", 1},
                    {2, "Predatory Discipline", 1}, {2, "Blood Frenzy", 2}, {2, "Predatory Strikes", 2},
                    {2, "Leader of the Pack", 1}, {2, "Natural Instinct", 2}, {2, "Predatory Strikes", 3},
                    {2, "Ferocity", 4}, {2, "Rend and Tear", 5}, {2, "Shifting Power", 1}, {1, "Genesis", 5},
                    {1, "Nature's Majesty", 2}, {1, "Nature's Reach", 2}, {3, "Heart of the Wild", 5},
                    {3, "Naturalist", 5}, {3, "Natural Shapeshifter", 1},
                },
            },
            {
                name = "Restoration", role = "Healer", weights = WEIGHTS.DRUID_RESTO,
                statPriority = "Healing > Intellect > Spirit > Stamina",
                tips = { "Rejuvenation and Regrowth keep healing over time; Healing Touch for big heals.",
                         "Innervate restores a lot of mana - use it on yourself or a healer." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Restoration Druid guide
                    {3, "Nature's Focus", 5}, {3, "Naturalist", 5}, {3, "Bloom", 1}, {3, "Reflection", 3},
                    {3, "Gift of Nature", 1}, {3, "Swiftmend", 1}, {3, "Gift of Nature", 5},
                    {3, "Nature's Swiftness", 1}, {3, "Living Spirit", 3}, {3, "Improved Rejuvenation", 3},
                    {3, "Improved Tranquility", 2}, {3, "Improved Regrowth", 1}, {3, "Wild Growth", 1},
                    {1, "Genesis", 5}, {1, "Nature's Majesty", 2}, {1, "Improved Moonfire", 2},
                    {1, "Moonglow", 1}, {1, "Nature's Splendor", 1}, {3, "Improved Regrowth", 5},
                    {3, "Heart of the Wild", 5},
                },
            },
            {
                -- Feral (Tank): the same Feral Combat tree as Feral (Damage), with a
                -- bear build. A fourth spec button for druids (tree = 2 below).
                name = "Feral (Tank)", buttonName = "Feral Tank", tree = 2, role = "Tank", weights = WEIGHTS.DRUID_BEAR,
                statPriority = "Weapon DPS > Strength > Agility > Stamina > Armor (dungeons: Stamina, Armor, Dodge)",
                tips = { "Bear Form for groups and elites; Swipe and Maul keep the mobs on you.",
                         "Cat Form is still faster for single easy mobs while you quest." },
                build = {
                    -- Exact leveling order from the Mobalytics WoW Forever Feral Druid (Bear Tank) guide (Nov 2026)
                    {2, "Ferocity", 5}, {2, "Furor", 1}, {2, "Feral Instinct", 2}, {2, "Feral Swiftness", 2},
                    {2, "Feral Charge", 1}, {2, "Savage Fury", 2}, {2, "Sharpened Claws", 2}, {2, "Lacerate", 1},
                    {2, "Furor", 2}, {2, "Predatory Discipline", 1}, {2, "Furor", 4}, {2, "Leader of the Pack", 1},
                    {2, "Natural Instinct", 2}, {2, "Blood Frenzy", 2}, {2, "Predatory Strikes", 3}, {2, "Feral Instinct", 3},
                    {2, "Rend and Tear", 1}, {2, "Primal Bite", 1}, {2, "Shifting Power", 1}, {3, "Heart of the Wild", 5},
                    {3, "Naturalist", 5}, {1, "Genesis", 5}, {1, "Nature's Reach", 2}, {2, "Rend and Tear", 3},
                },
            },
        },
    },
}

--------------------------------------------------------------------------------
-- Spec icons (the classic talent tab icons), shown on the spec buttons.
--------------------------------------------------------------------------------
local SPEC_ICONS = {
    WARRIOR = { "Ability_Warrior_SavageBlow", "Ability_Warrior_InnerRage", "Ability_Warrior_DefensiveStance" },
    PALADIN = { "Spell_Holy_HolyBolt", "Spell_Holy_DevotionAura", "Spell_Holy_AuraOfLight" },
    HUNTER  = { "Ability_Hunter_BeastTaming", "Ability_Marksmanship", "Ability_Hunter_SwiftStrike" },
    ROGUE   = { "Ability_Rogue_Eviscerate", "Ability_BackStab", "Ability_Stealth" },
    PRIEST  = { "Spell_Holy_WordFortitude", "Spell_Holy_HolyBolt", "Spell_Shadow_ShadowWordPain" },
    SHAMAN  = { "Spell_Nature_Lightning", "Spell_Nature_LightningShield", "Spell_Nature_MagicImmunity" },
    MAGE    = { "Spell_Holy_MagicalSentry", "Spell_Fire_FireBolt02", "Spell_Frost_FrostBolt02" },
    WARLOCK = { "Spell_Shadow_DeathCoil", "Spell_Shadow_Metamorphosis", "Spell_Shadow_RainOfFire" },
    DRUID   = { "Spell_Nature_StarFall", "Ability_Druid_CatForm", "Spell_Nature_HealingTouch", "Ability_Racial_BearForm" },
}
for className, iconNames in pairs(SPEC_ICONS) do
    for specNumber, iconName in ipairs(iconNames) do
        Mentor.CLASS_DATA[className].specs[specNumber].icon = "Interface\\Icons\\" .. iconName
    end
end

--------------------------------------------------------------------------------
-- Mentor - Guides.lua
-- "How to play" content for every class and spec, kept short on purpose:
-- each situation has a few spell icons and at most three short lines.
--
-- Situations (tabs in the guide panel):
--   rotation  what to press, in order, against a normal enemy
--   single    fighting 1 enemy
--   two       fighting 2 enemies
--   many      fighting 3 or more enemies
--   pet       using your pet (hunters and warlocks only)
--   trouble   when things go wrong (low health / mana)
--
-- Spells are written by NAME, so the icons come from the game itself and
-- spells you have not learned yet are shown greyed out.
--
-- Each class has "shared" situations used by all its specs; a spec can
-- replace any of them with its own version.
--------------------------------------------------------------------------------

local _, Mentor = ...

Mentor.GUIDE_SITUATIONS = {
    { key = "rotation", label = "Rotation" },
    { key = "single",   label = "1 mob" },
    { key = "two",      label = "2 mobs" },
    { key = "many",     label = "3+ mobs" },
    { key = "pet",      label = "Pet" },
    { key = "trouble",  label = "In trouble" },
}

Mentor.CLASS_GUIDES = {
    ----------------------------------------------------------------------------
    WARRIOR = {
        shared = {
            two = { spells = { "Demoralizing Shout", "Thunder Clap", "Cleave" }, lines = {
                "Demoralizing Shout and Thunder Clap weaken both enemies.",
                "Use Cleave instead of Heroic Strike while two are next to you." } },
            many = { spells = { "Retaliation", "Thunder Clap", "Sweeping Strikes", "Intimidating Shout" }, lines = {
                "Three or more is dangerous early on - pull one at a time.",
                "If it happens: Retaliation, Thunder Clap, then Intimidating Shout to escape." } },
            trouble = { spells = { "Intimidating Shout", "Last Stand", "Shield Wall" }, lines = {
                "Intimidating Shout makes enemies run - use the time to bandage or leave.",
                "Warriors cannot heal themselves: eat between fights." } },
        },
        specs = {
            {   rotation = { spells = { "Charge", "Rend", "Mortal Strike", "Overpower", "Heroic Strike", "Battle Shout", "Thunder Clap" }, lines = {
                    "Charge in, Rend, then Mortal Strike every time it is ready.",
                    "Overpower when it lights up; spend extra rage on Heroic Strike." } },
                single = { spells = { "Charge", "Rend", "Mortal Strike" }, lines = {
                    "Open with Charge for free rage.",
                    "Keep Battle Shout up; Hamstring runners." } } },
            {   rotation = { spells = { "Charge", "Bloodthirst", "Whirlwind", "Rend", "Overpower", "Heroic Strike", "Execute", "Battle Shout" }, lines = {
                    "Bloodthirst on cooldown, Whirlwind next, Heroic Strike with spare rage.",
                    "Execute when the enemy is below 20% health." } },
                single = { spells = { "Charge", "Bloodthirst", "Execute" }, lines = {
                    "Charge, Bloodthirst, and keep rage from overflowing.",
                    "Berserker Rage and Bloodrage give extra rage." } } },
            {   rotation = { spells = { "Shield Slam", "Revenge", "Sunder Armor", "Shield Block", "Heroic Strike", "Rend", "Taunt" }, lines = {
                    "Shield Slam and Revenge first, Sunder Armor to fill.",
                    "Taunt anything that attacks your healer." } },
                single = { spells = { "Shield Slam", "Revenge", "Sunder Armor" }, lines = {
                    "You deal less damage but almost never die.",
                    "Keep a shield on - Shield Block makes Revenge ready more often." } },
                many = { spells = { "Thunder Clap", "Demoralizing Shout", "Cleave", "Taunt" }, lines = {
                    "Thunder Clap and Demoralizing Shout on the whole group.",
                    "Tab between targets and Sunder each one to hold them." } } },
        },
    },
    ----------------------------------------------------------------------------
    PALADIN = {
        shared = {
            two = { spells = { "Hammer of Justice", "Consecration", "Judgement" }, lines = {
                "Stun one with Hammer of Justice while you hit the other.",
                "Consecration hits both, but costs a lot of mana." } },
            many = { spells = { "Consecration", "Divine Protection", "Retribution Aura" }, lines = {
                "Retribution Aura and Consecration punish groups.",
                "Divine Protection buys time if it goes wrong." } },
            trouble = { spells = { "Divine Protection", "Holy Light", "Lay on Hands" }, lines = {
                "Divine Protection, then heal yourself with Holy Light.",
                "Lay on Hands is a full heal with a long cooldown." } },
        },
        specs = {
            {   rotation = { spells = { "Seal of Righteousness", "Judgement", "Flash of Light", "Holy Light", "Purify", "Cleanse" }, lines = {
                    "Solo: Seal of Righteousness, Judgement, melee.",
                    "In groups: Flash of Light for small damage, Holy Light for big." } },
                single = { spells = { "Seal of Righteousness", "Judgement" }, lines = {
                    "Seal, Judgement, put the Seal back, melee.",
                    "Heal yourself between fights instead of eating." } } },
            {   rotation = { spells = { "Righteous Fury", "Holy Shield", "Consecration", "Seal of Righteousness", "Judgement", "Devotion Aura" }, lines = {
                    "Righteous Fury must be on while you tank.",
                    "Holy Shield and Consecration keep threat on everything." } },
                single = { spells = { "Seal of Righteousness", "Judgement", "Holy Shield" }, lines = {
                    "Slow but very safe: you rarely need to rest.",
                    "Blessing of Sanctuary reflects damage back." } } },
            {   rotation = { spells = { "Seal of the Crusader", "Judgement", "Seal of Command", "Seal of Righteousness", "Consecration", "Hammer of Wrath" }, lines = {
                    "Seal of the Crusader, Judge it, then Seal of Command and fight.",
                    "Judge again whenever Judgement is ready." } },
                single = { spells = { "Seal of Command", "Judgement", "Hammer of Wrath" }, lines = {
                    "Use the slowest two-handed weapon you have.",
                    "Hammer of Wrath finishes enemies below 20% health." } } },
        },
    },
    ----------------------------------------------------------------------------
    HUNTER = {
        shared = {
            single = { spells = { "Hunter's Mark", "Serpent Sting", "Arcane Shot" }, lines = {
                "Send your pet first, wait two seconds, then start shooting.",
                "Stay at range: you cannot shoot up close." } },
            two = { spells = { "Freezing Trap", "Concussive Shot", "Multi-Shot" }, lines = {
                "Let your pet hold one while you shoot the other.",
                "Freezing Trap freezes one enemy for a long time." } },
            many = { spells = { "Multi-Shot", "Freezing Trap", "Feign Death", "Disengage" }, lines = {
                "Avoid groups - pull one at a time.",
                "Feign Death drops all threat; your pet keeps fighting." } },
            pet = { spells = { "Call Pet", "Mend Pet", "Feed Pet", "Revive Pet" }, lines = {
                "Your pet tanks for you. Keep it happy with Feed Pet.",
                "Mend Pet when it is low; tame a better pet as you level." } },
            trouble = { spells = { "Feign Death", "Mend Pet", "Aspect of the Cheetah" }, lines = {
                "Feign Death to drop everything, then bandage.",
                "Aspect of the Monkey helps when something reaches you." } },
        },
        specs = {
            {   rotation = { spells = { "Hunter's Mark", "Serpent Sting", "Arcane Shot", "Bestial Wrath", "Multi-Shot", "Auto Shot", "Raptor Strike" }, lines = {
                    "Pet in first, Hunter's Mark, Serpent Sting, Arcane Shot.",
                    "Bestial Wrath makes your pet hit much harder." } } },
            {   rotation = { spells = { "Hunter's Mark", "Aimed Shot", "Serpent Sting", "Multi-Shot", "Arcane Shot", "Auto Shot", "Raptor Strike" }, lines = {
                    "Open with Aimed Shot, then Multi-Shot and Arcane Shot.",
                    "Keep Trueshot Aura on once you have it." } } },
            {   rotation = { spells = { "Hunter's Mark", "Serpent Sting", "Arcane Shot", "Auto Shot", "Raptor Strike", "Mongoose Bite", "Wing Clip" }, lines = {
                    "Shoot as usual; if something reaches you, Wing Clip and step back.",
                    "Raptor Strike and Mongoose Bite when you must melee." } } },
        },
    },
    ----------------------------------------------------------------------------
    ROGUE = {
        shared = {
            two = { spells = { "Sap", "Gouge", "Blade Flurry" }, lines = {
                "Sap the second enemy from stealth before you start.",
                "Gouge one while you finish the other." } },
            many = { spells = { "Blade Flurry", "Evasion", "Vanish", "Sprint" }, lines = {
                "Avoid groups - rogues are fragile.",
                "If it happens: Evasion, then Vanish or Sprint away." } },
            trouble = { spells = { "Evasion", "Vanish", "Sprint", "Kidney Shot" }, lines = {
                "Evasion makes you dodge most attacks for a while.",
                "Vanish to escape, then bandage." } },
        },
        specs = {
            {   rotation = { spells = { "Cheap Shot", "Sinister Strike", "Slice and Dice", "Eviscerate", "Cold Blood", "Backstab" }, lines = {
                    "Open with Cheap Shot, build combo points with Sinister Strike.",
                    "Slice and Dice, then Eviscerate; Cold Blood for a big hit." } },
                single = { spells = { "Cheap Shot", "Sinister Strike", "Eviscerate" }, lines = {
                    "Poisons on both weapons - free damage.",
                    "Eviscerate at 4-5 combo points." } } },
            {   rotation = { spells = { "Sinister Strike", "Slice and Dice", "Eviscerate", "Blade Flurry", "Adrenaline Rush", "Riposte" }, lines = {
                    "Sinister Strike to build combo points, Slice and Dice, then Eviscerate.",
                    "Blade Flurry and Adrenaline Rush for tough fights." } },
                single = { spells = { "Sinister Strike", "Slice and Dice", "Eviscerate" }, lines = {
                    "A slow sword or mace in your main hand.",
                    "Keep Slice and Dice up the whole fight." } } },
            {   rotation = { spells = { "Premeditation", "Ambush", "Hemorrhage", "Sinister Strike", "Slice and Dice", "Eviscerate" }, lines = {
                    "Premeditation and Ambush from stealth (dagger in main hand).",
                    "Hemorrhage builds combo points after that." } },
                single = { spells = { "Ambush", "Hemorrhage", "Eviscerate" }, lines = {
                    "Always open from stealth - your first hit is your biggest.",
                    "Preparation resets Vanish and Sprint." } } },
        },
    },
    ----------------------------------------------------------------------------
    PRIEST = {
        shared = {
            two = { spells = { "Shadow Word: Pain", "Power Word: Shield", "Psychic Scream" }, lines = {
                "Shadow Word: Pain on both and shield yourself.",
                "Psychic Scream if both reach you." } },
            many = { spells = { "Power Word: Shield", "Psychic Scream", "Holy Nova", "Fade" }, lines = {
                "Shield first, Psychic Scream, then pick them off one by one." } },
            trouble = { spells = { "Power Word: Shield", "Renew", "Flash Heal", "Psychic Scream" }, lines = {
                "Shield and Renew yourself, then keep fighting.",
                "Use your wand when mana is low; drink between fights." } },
        },
        specs = {
            {   rotation = { spells = { "Power Word: Shield", "Shadow Word: Pain", "Mind Blast", "Smite", "Shoot" }, lines = {
                    "Shield, Shadow Word: Pain, then wand (Shoot).",
                    "Smite only when you have mana to spare." } } },
            {   rotation = { spells = { "Holy Fire", "Shadow Word: Pain", "Power Word: Shield", "Smite", "Shoot" }, lines = {
                    "Solo: Holy Fire, Shadow Word: Pain, wand.",
                    "In groups: Renew on the tank, Flash Heal for emergencies." } } },
            {   rotation = { spells = { "Power Word: Shield", "Vampiric Embrace", "Shadow Word: Pain", "Mind Blast", "Mind Flay", "Smite", "Shoot" }, lines = {
                    "Shadow Word: Pain, Mind Blast, Mind Flay; finish with wand.",
                    "Spirit Tap after a kill restores mana fast - wait a moment." } },
                single = { spells = { "Shadow Word: Pain", "Mind Blast", "Mind Flay" }, lines = {
                    "Shield yourself before you pull.",
                    "Shadowform once you have it - stay in it." } } },
        },
    },
    ----------------------------------------------------------------------------
    SHAMAN = {
        shared = {
            two = { spells = { "Earthbind Totem", "Earth Shock", "Flame Shock" }, lines = {
                "Earthbind Totem slows them; shock the one hitting you.",
                "Kill the weakest first." } },
            many = { spells = { "Stoneclaw Totem", "Fire Nova Totem", "Magma Totem", "Chain Lightning" }, lines = {
                "Stoneclaw Totem distracts enemies while you fight.",
                "Fire Nova / Magma Totem and Chain Lightning hit groups." } },
            trouble = { spells = { "Stoneclaw Totem", "Healing Wave", "Lesser Healing Wave", "Reincarnation" }, lines = {
                "Drop Stoneclaw Totem, then heal yourself.",
                "Reincarnation brings you back after death (needs an Ankh)." } },
        },
        specs = {
            {   rotation = { spells = { "Searing Totem", "Flame Shock", "Lightning Bolt", "Earth Shock", "Elemental Mastery", "Lightning Shield" }, lines = {
                    "Searing Totem down, Flame Shock, then Lightning Bolt.",
                    "Earth Shock to finish or interrupt." } },
                single = { spells = { "Lightning Bolt", "Flame Shock", "Earth Shock" }, lines = {
                    "Pull with Lightning Bolt, cast another as it runs at you.",
                    "Shocks are instant - use them when it reaches you." } } },
            {   rotation = { spells = { "Windfury Weapon", "Rockbiter Weapon", "Lightning Shield", "Strength of Earth Totem", "Stormstrike", "Earth Shock", "Flame Shock" }, lines = {
                    "Windfury Weapon on your weapon, Strength of Earth Totem down.",
                    "Stormstrike on cooldown, then Earth Shock." } },
                single = { spells = { "Rockbiter Weapon", "Stormstrike", "Earth Shock" }, lines = {
                    "Use the slowest two-handed weapon you can find.",
                    "Lightning Shield before you pull." } } },
            {   rotation = { spells = { "Flame Shock", "Lightning Bolt", "Earth Shock", "Healing Wave", "Chain Heal", "Mana Spring Totem" }, lines = {
                    "Solo: Flame Shock and Lightning Bolt, melee to save mana.",
                    "In groups: Healing Wave, Chain Heal for several people." } },
                single = { spells = { "Flame Shock", "Lightning Bolt", "Earth Shock" }, lines = {
                    "You level slower - pull carefully and heal yourself.",
                    "Mana Spring Totem keeps your mana up." } } },
        },
    },
    ----------------------------------------------------------------------------
    MAGE = {
        shared = {
            two = { spells = { "Polymorph", "Frost Nova", "Frostbolt" }, lines = {
                "Polymorph one enemy, kill the other, then the sheep.",
                "Frost Nova and step back if they reach you." } },
            many = { spells = { "Frost Nova", "Blizzard", "Arcane Explosion", "Cone of Cold" }, lines = {
                "Frost Nova, back up, then Blizzard or Arcane Explosion.",
                "Blink away if it goes wrong." } },
            trouble = { spells = { "Frost Nova", "Blink", "Ice Block", "Mana Shield" }, lines = {
                "Frost Nova and Blink to get distance.",
                "Conjure food and water - you never need to buy any." } },
        },
        specs = {
            {   rotation = { spells = { "Arcane Power", "Presence of Mind", "Arcane Missiles", "Frostbolt", "Fireball", "Fire Blast", "Arcane Explosion" }, lines = {
                    "Arcane Missiles is your main attack, Fire Blast to finish.",
                    "Arcane Power and Presence of Mind for big hits." } },
                single = { spells = { "Frostbolt", "Arcane Missiles", "Fire Blast" }, lines = {
                    "Open with Frostbolt to slow it, then Arcane Missiles.",
                    "Watch your mana - Arcane drains it fast." } } },
            {   rotation = { spells = { "Pyroblast", "Fireball", "Fire Blast", "Scorch", "Blast Wave", "Frost Nova" }, lines = {
                    "Open with Pyroblast, then Fireball.",
                    "Fire Blast is instant - use it to finish." } },
                single = { spells = { "Pyroblast", "Fireball", "Fire Blast" }, lines = {
                    "Enemies die before they reach you if you start from range." } } },
            {   rotation = { spells = { "Frostbolt", "Fireball", "Frost Nova", "Ice Lance", "Fire Blast", "Cone of Cold" }, lines = {
                    "Frostbolt until it reaches you, Frost Nova, step back, Frostbolt again.",
                    "Fire Blast to finish." } },
                single = { spells = { "Frostbolt", "Frost Nova", "Fire Blast" }, lines = {
                    "The safest way to level a mage: enemies rarely reach you." } } },
        },
    },
    ----------------------------------------------------------------------------
    WARLOCK = {
        shared = {
            two = { spells = { "Corruption", "Bane of Agony", "Curse of Agony", "Fear" }, lines = {
                "Put your dots on both, let your Voidwalker hold one.",
                "Fear one if both reach you." } },
            many = { spells = { "Summon Voidwalker", "Corruption", "Bane of Agony", "Curse of Agony", "Fear", "Howl of Terror", "Death Coil" }, lines = {
                "Avoid 3+ if you can - pull one or two at a time.",
                "If it happens: Voidwalker taunts, you put Corruption and Agony on every mob.",
                "Fear only the one hitting YOU, not the whole group - a feared mob can run off and pull more.",
                "Howl of Terror (later) fears everything near you - your panic button. Death Coil buys a few more seconds." } },
            pet = { spells = { "Summon Imp", "Summon Voidwalker", "Health Funnel", "Sacrifice" }, lines = {
                "Voidwalker while leveling: it tanks while you dot.",
                "Health Funnel heals your pet; Sacrifice gives you a shield." } },
            trouble = { spells = { "Death Coil", "Fear", "Drain Life", "Health Funnel" }, lines = {
                "Death Coil heals you and makes the enemy run.",
                "Life Tap turns health into mana - Drain Life brings health back." } },
        },
        specs = {
            {   rotation = { spells = { "Corruption", "Bane of Agony", "Curse of Agony", "Siphon Life", "Immolate", "Drain Life", "Shadow Bolt", "Shoot" }, lines = {
                    "Corruption, Bane of Agony, Siphon Life - then wand or Drain Life.",
                    "Your pet tanks; you barely need to rest." } },
                single = { spells = { "Corruption", "Bane of Agony", "Curse of Agony", "Drain Life" }, lines = {
                    "Send the pet first, then dot.",
                    "Drain Soul on the last bit of health gives a Soul Shard." } } },
            {   rotation = { spells = { "Corruption", "Bane of Agony", "Curse of Agony", "Immolate", "Shadow Bolt", "Health Funnel", "Shoot" }, lines = {
                    "Your demon does much of the work - keep it alive.",
                    "Dots first, Shadow Bolt to finish." } },
                single = { spells = { "Corruption", "Bane of Agony", "Curse of Agony", "Shadow Bolt" }, lines = {
                    "Voidwalker tanks; Health Funnel it in long fights." } } },
            {   rotation = { spells = { "Immolate", "Corruption", "Conflagrate", "Shadow Bolt", "Shadowburn", "Searing Pain" }, lines = {
                    "Immolate, then Shadow Bolt; Conflagrate when Immolate is on.",
                    "Shadowburn finishes enemies and gives a Soul Shard." } },
                single = { spells = { "Immolate", "Shadow Bolt", "Shadowburn" }, lines = {
                    "Big hits cost mana - keep Life Tap ready." } } },
        },
    },
    ----------------------------------------------------------------------------
    DRUID = {
        shared = {
            two = { spells = { "Entangling Roots", "Moonfire", "Demoralizing Roar" }, lines = {
                "Root one enemy, kill the other.",
                "In Bear Form: Demoralizing Roar and Swipe." } },
            many = { spells = { "Bear Form", "Swipe", "Demoralizing Roar", "Hurricane" }, lines = {
                "Go Bear Form and Swipe to survive groups." } },
            trouble = { spells = { "Rejuvenation", "Regrowth", "Barkskin", "Frenzied Regeneration" }, lines = {
                "Leave your form and heal yourself.",
                "In Bear Form: Frenzied Regeneration turns rage into health." } },
        },
        specs = {
            {   rotation = { spells = { "Moonfire", "Insect Swarm", "Starfire", "Wrath", "Entangling Roots", "Faerie Fire" }, lines = {
                    "Moonfire and Insect Swarm, then Wrath or Starfire.",
                    "Entangling Roots keeps melee enemies away." } },
                single = { spells = { "Starfire", "Moonfire", "Wrath" }, lines = {
                    "Open with Starfire from range, Moonfire as it runs in." } } },
            {   rotation = { spells = { "Cat Form", "Prowl", "Rake", "Claw", "Rip", "Ferocious Bite", "Bear Form", "Maul", "Moonfire", "Wrath" }, lines = {
                    "Prowl, open with Rake, Claw to 5 combo points, Ferocious Bite.",
                    "Switch to Bear Form if it goes wrong." } },
                single = { spells = { "Prowl", "Rake", "Ferocious Bite" }, lines = {
                    "Your weapon's damage does not matter in forms - only its stats.",
                    "Faerie Fire (Feral) pulls from range." } } },
            {   rotation = { spells = { "Moonfire", "Wrath", "Rejuvenation", "Regrowth", "Healing Touch" }, lines = {
                    "Solo: Moonfire and Wrath, heal yourself between fights.",
                    "In groups: Rejuvenation on the tank, Regrowth and Healing Touch." } },
                single = { spells = { "Moonfire", "Wrath", "Rejuvenation" }, lines = {
                    "Leveling as Restoration is slow - Cat Form helps save mana." } } },
        },
    },
}

-- Returns the guide content for a situation (spec version first, then the
-- class' shared one), or nil when there is none (e.g. "pet" for a mage).
function Mentor.GetGuideSection(classFileName, specNumber, situationKey)
    local classGuide = Mentor.CLASS_GUIDES[classFileName]
    if not classGuide then
        return nil
    end
    local specGuide = classGuide.specs[specNumber] or {}
    return specGuide[situationKey] or classGuide.shared[situationKey]
end

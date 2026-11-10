--------------------------------------------------------------------------------
-- Mentor - GuidesForever.lua
-- "How to play" content for all 27 specs, rewritten from the Mobalytics WoW
-- Forever guides (Nov 2026): the class leveling guides plus the spec guides
-- for specs without one. Loaded after Guides.lua and replaces its content.
--
-- Situations: rotation, single (one tough mob), two, many (3+), pet, trouble.
--
-- Lines follow what you have learned (see Mentor.GetApplicableGuideLines):
--   { "text", needs = "Spell" }    shown once you know the spell or talent
--   { "text", without = "Spell" }  shown until you learn it
--   { "text", from = 24, to = 41 } shown between those levels
-- Spell icons are in priority order; only learned ones are shown, plus the
-- next one you will get, greyed out.
--------------------------------------------------------------------------------

local _, Mentor = ...

-- Classes that got a class-wide "1 mob" section below (SetClassGuide).
local classesWithSharedSingle = {}

-- Replaces the given situations for one spec (spec number = order in Data.lua).
local function SetSpecGuide(classFileName, specNumber, sections)
    local classGuide = Mentor.CLASS_GUIDES[classFileName]
    classGuide.specs = classGuide.specs or {}
    classGuide.specs[specNumber] = classGuide.specs[specNumber] or {}
    for situationKey, section in pairs(sections) do
        classGuide.specs[specNumber][situationKey] = section
    end
    -- "1 mob" is the class-wide one-mob advice if there is one, otherwise the
    -- plain rotation (unless the spec gives its own).
    if sections.rotation and not sections.single then
        local hasNewSharedSingle = classesWithSharedSingle[classFileName]
        classGuide.specs[specNumber].single = (not hasNewSharedSingle) and sections.rotation or nil
    end
end

-- Replaces situations shared by every spec of a class (e.g. "trouble").
local function SetClassGuide(classFileName, sections)
    local classGuide = Mentor.CLASS_GUIDES[classFileName]
    classGuide.shared = classGuide.shared or {}
    if sections.single then
        classesWithSharedSingle[classFileName] = true
    end
    for situationKey, section in pairs(sections) do
        classGuide.shared[situationKey] = section
        -- Old spec-specific versions (Guides.lua) would hide the new shared
        -- one; specs that need their own get it again from SetSpecGuide.
        for _, specGuide in pairs(classGuide.specs or {}) do
            specGuide[situationKey] = nil
        end
    end
end

--------------------------------------------------------------------------------
-- WARRIOR: 1 Arms, 2 Fury, 3 Protection
--------------------------------------------------------------------------------
local WARRIOR_RAGE_DUMP = {
    { "Heroic Strike only above 60 rage - it is a rage dump, not a filler.", to = 23 },
    { "Heroic Strike only above 85 rage.", from = 24 },
    { "Execute to finish, ideally at about 15 rage - more rage is wasted.", needs = "Execute" },
}

SetClassGuide("WARRIOR", {
    single = {
        spells = { "Charge", "Demoralizing Shout", "Rend", "Overpower", "Hamstring", "Victory Rush" },
        lines = {
            "Before a strong mob: fight weaker mobs nearby first to bring rage with you.",
            "Demoralizing Shout and Thunder Clap - but not against casters.",
            "Casters: pull them around a corner so they must come to you.",
            { "Hamstring mobs that run away.", needs = "Hamstring" },
            "Stand behind mobs in dungeons so you don't get parried.",
        },
    },
    many = {
        spells = { "Thunder Clap", "Demoralizing Shout", "Retaliation", "Whirlwind", "Intimidating Shout" },
        lines = {
            "3+ is dangerous solo - pull one or two at a time.",
            "Demoralizing Shout and Thunder Clap first - they cut the damage you take.",
            { "Thunder Clap is better than Cleave on 3+.", needs = "Cleave" },
            { "Spread Rend on all of them rather than Heroic Strike.", needs = "Rend" },
            { "Whirlwind on cooldown (jumping gives it extra range).", needs = "Whirlwind" },
            { "Retaliation when they all hit you.", needs = "Retaliation" },
        },
    },
    trouble = {
        spells = { "Intimidating Shout", "Victory Rush", "Shield Wall", "Last Stand", "Retaliation", "Hamstring" },
        lines = {
            { "Intimidating Shout, then bandage yourself - it can save the fight.", needs = "Intimidating Shout" },
            { "Victory Rush heals 10% after every kill.", needs = "Victory Rush" },
            { "Shield Wall with a shield on.", needs = "Shield Wall" },
            { "Last Stand for a big chunk of health.", needs = "Last Stand" },
            "Always plan an escape route; avoid mobs above your level.",
            "Shield Block does nothing against elementals (except earth).",
        },
    },
})

SetSpecGuide("WARRIOR", 1, {
    rotation = {
        spells = { "Charge", "Victory Rush", "Overpower", "Mortal Strike", "Rend", "Slam", "Demoralizing Shout", "Thunder Clap", "Heroic Strike", "Execute" },
        lines = {
            "Keep Battle Shout up and open with Charge.",
            { "Victory Rush after a kill when you are below 90% health.", needs = "Victory Rush" },
            { "Overpower whenever it lights up - your best damage per rage.", needs = "Overpower" },
            { "Mortal Strike on cooldown.", needs = "Mortal Strike" },
            "Rend if the mob lives 9+ seconds; Demoralizing Shout on hard hitters.",
            { "Spearing Strike - strongest against dragonkin and giants.", needs = "Spearing Strike" },
            { "Slam only with Improved Slam talented.", needs = "Improved Slam" },
            WARRIOR_RAGE_DUMP[1], WARRIOR_RAGE_DUMP[2], WARRIOR_RAGE_DUMP[3],
        },
    },
    two = {
        spells = { "Sweeping Strikes", "Cleave", "Thunder Clap", "Demoralizing Shout", "Rend" },
        lines = {
            { "Sweeping Strikes with 2+ mobs (skip Victory Rush while it is up).", needs = "Sweeping Strikes" },
            "Demoralizing Shout and Thunder Clap weaken both.",
            { "Cleave instead of Heroic Strike at 60+ rage.", needs = "Cleave", to = 23 },
            { "Cleave instead of Heroic Strike at 85+ rage.", needs = "Cleave", from = 24 },
            "Rend on both if they will live long enough.",
        },
    },
})

SetSpecGuide("WARRIOR", 2, {
    rotation = {
        spells = { "Charge", "Victory Rush", "Death Wish", "Bloodthirst", "Whirlwind", "Overpower", "Rend", "Demoralizing Shout", "Heroic Strike", "Execute" },
        lines = {
            "Keep Battle Shout up and open with Charge.",
            { "Victory Rush after a kill when you are below 90% health.", needs = "Victory Rush" },
            { "Until 30 you play like Arms: Overpower, Rend, Thunder Clap, Demoralizing Shout.", to = 29 },
            { "Death Wish early and often.", needs = "Death Wish" },
            { "Keep Gore Drinker going with Bloodrage, Berserker Rage or Bloodthirst.", needs = "Gore Drinker" },
            { "Stay in Battle Stance for now - Overpower and Rend are worth it.", from = 30, to = 37 },
            { "From 38: live in Berserker Stance, Whirlwind and Bloodthirst on cooldown.", needs = "Improved Whirlwind" },
            { "Short on rage? Save it for Bloodthirst to keep Gore Drinker up.", needs = "Bloodthirst" },
            { "Reckless Swings when you stay at high health.", needs = "Reckless Swings" },
            WARRIOR_RAGE_DUMP[1], WARRIOR_RAGE_DUMP[2], WARRIOR_RAGE_DUMP[3],
        },
    },
    two = {
        spells = { "Whirlwind", "Cleave", "Thunder Clap", "Demoralizing Shout" },
        lines = {
            { "Whirlwind hits them all - use it on cooldown.", needs = "Whirlwind" },
            "Demoralizing Shout so both hit softer.",
            { "Cleave with spare rage, but never instead of Bloodthirst.", needs = "Cleave" },
        },
    },
})

SetSpecGuide("WARRIOR", 3, {
    rotation = {
        spells = { "Shield Block", "Revenge", "Shield Slam", "Victory Rush", "Demoralizing Shout", "Rend", "Thunder Clap", "Heroic Strike" },
        lines = {
            "Stay in Defensive Stance. Keep Battle Shout up.",
            { "Battle Stance only to Charge - Vanguard lets you Charge in Defensive.", without = "Vanguard" },
            "Dump rage before switching to Defensive Stance - it drops to 10.",
            { "Shield Block on cooldown: almost free and makes Revenge ready.", needs = "Shield Block" },
            { "Revenge whenever it lights up.", needs = "Revenge" },
            { "Shield Slam on cooldown.", needs = "Shield Slam" },
            { "Victory Rush after a kill below 90% health.", needs = "Victory Rush" },
            "Demoralizing Shout, Rend and Thunder Clap; Heroic Strike above 60 rage.",
        },
    },
    two = {
        spells = { "Thunder Clap", "Rend", "Revenge", "Shield Slam" },
        lines = {
            "Hit each mob at least once early so they all stay on you.",
            "Thunder Clap on cooldown with several mobs.",
            "Rend on every mob while Shield Slam and Revenge are on cooldown.",
        },
    },
})

--------------------------------------------------------------------------------
-- PALADIN: 1 Holy, 2 Protection, 3 Retribution
--------------------------------------------------------------------------------
SetClassGuide("PALADIN", {
    trouble = {
        spells = { "Divine Protection", "Divine Shield", "Lay on Hands", "Holy Light", "Flash of Light", "Hammer of Justice" },
        lines = {
            { "Hammer of Justice, then heal yourself while it is stunned.", needs = "Hammer of Justice" },
            { "Divine Shield / Divine Protection, then heal to full.", needs = { "Divine Shield", "Divine Protection" } },
            { "Lay on Hands as the last resort - a full heal.", needs = "Lay on Hands" },
            { "Divine Shield also stops fall damage - jump down cliffs to save time.", needs = "Divine Shield" },
        },
    },
    many = {
        spells = { "Consecration", "Holy Wrath", "Hammer of Justice", "Divine Protection" },
        lines = {
            "Paladins gain little from pulling many - one or two at a time.",
            { "Consecration with 3 or more.", needs = "Consecration" },
            { "Holy Wrath against groups of undead or demons.", needs = "Holy Wrath" },
        },
    },
})

SetSpecGuide("PALADIN", 1, {
    rotation = {
        spells = { "Seal of Righteousness", "Judgement", "Holy Strike", "Exorcism", "Consecration", "Holy Shock", "Flash of Light" },
        lines = {
            "Solo: Seal of Righteousness + Blessing of Might (Wisdom in a group).",
            "Keep a high-damage two-hander in your bags for solo play.",
            { "Judgement on cooldown - great damage for its mana.", needs = "Judgement" },
            { "Holy Strike on cooldown - cheap.", needs = "Holy Strike" },
            { "Exorcism on undead and demons.", needs = "Exorcism" },
            { "Holy Shock only with spare mana (Divine Favor first for more).", needs = "Holy Shock" },
            "Cast spells back to back, then let mana come back (5 sec rule).",
        },
    },
    two = {
        spells = { "Consecration", "Judgement", "Holy Strike" },
        lines = {
            { "Consecration against several - expensive until Holy Conduit.", needs = "Consecration" },
            "Don't spend the mana you need for healing.",
        },
    },
    many = {
        spells = { "Flash of Light", "Holy Light", "Light's Vigil", "Holy Shock" },
        lines = {
            "Healing a group: Flash of Light first - your cheapest heal.",
            "Holy Light when someone needs a big heal.",
            { "Light's Vigil + Holy Shock when 4+ party members are low.", needs = "Light's Vigil" },
        },
    },
})

SetSpecGuide("PALADIN", 2, {
    rotation = {
        spells = { "Seal of Fury", "Holy Shield", "Holy Strike", "Judgement", "Exorcism", "Consecration", "Hammer of Wrath" },
        lines = {
            { "Keep Seal of Fury up - it also shields you.", needs = "Seal of Fury" },
            { "Seal of Righteousness until you learn Seal of Fury.", without = "Seal of Fury" },
            { "Holy Shield on cooldown.", needs = "Holy Shield" },
            "Holy Strike and Judgement on cooldown (Judgement is off the global cooldown).",
            { "Exorcism on undead and demons.", needs = "Exorcism" },
            { "Consecration for steady threat.", needs = "Consecration" },
            { "Hammer of Wrath below 20%.", needs = "Hammer of Wrath" },
        },
    },
    two = {
        spells = { "Judgement", "Swift Judgement", "Consecration", "Holy Strike" },
        lines = {
            "Spread threat: Judgement one mob, Holy Strike another.",
            { "Swift Judgement on a third mob.", needs = "Swift Judgement" },
            { "Consecration - full damage on the first 4 mobs.", needs = "Consecration" },
        },
    },
})

SetSpecGuide("PALADIN", 3, {
    rotation = {
        spells = { "Seal of Command", "Seal of Righteousness", "Seal of the Crusader", "Judgement", "Holy Strike", "Exorcism", "Hammer of Justice", "Consecration" },
        lines = {
            "Keep Blessing of Might and your aura up.",
            { "Retribution Aura in combat.", needs = "Retribution Aura" },
            { "Seal of Righteousness, then Judgement and Holy Strike on cooldown. Auto attack between.", without = "Seal of Command" },
            { "Long fights: Seal of the Crusader > Judgement, then Seal of Command.", needs = "Seal of Command" },
            { "Judgement and Holy Strike on cooldown, close together.", needs = "Seal of Command" },
            { "Optional: Hammer of Justice before judging Seal of Command - extra damage.", needs = "Seal of Command" },
            { "Exorcism on undead and demons.", needs = "Exorcism" },
            { "Unsealed Wrath at 3 stacks: Seal of Righteousness, swing, then back to Command.", needs = "Unsealed Wrath" },
            { "Running low on mana? Switch to Blessing of Wisdom.", needs = "Blessing of Wisdom" },
            "Finish low mobs with auto attacks - mana comes back 5 sec after your last spell.",
        },
    },
    two = {
        spells = { "Consecration", "Judgement", "Holy Strike" },
        lines = {
            "Pulling several mobs gains little - take them one at a time.",
            { "Consecration only with 3 or more.", needs = "Consecration" },
        },
    },
})

--------------------------------------------------------------------------------
-- HUNTER: 1 Beast Mastery, 2 Marksmanship, 3 Survival
--------------------------------------------------------------------------------
SetClassGuide("HUNTER", {
    two = {
        spells = { "Auto Shot", "Raptor Strike", "Serpent Sting", "Wing Clip", "Multi-Shot", "Arcane Shot" },
        lines = {
            "Fastest leveling: keep both Auto Shot and melee busy all the time.",
            "Melee the closest mob, shoot the one further away.",
            "Serpent Sting both if your mana allows.",
            { "Wing Clip to space them; Multi-Shot when they stand together.", needs = "Multi-Shot" },
            { "Your pet kills one while you kill the other.", needs = "Call Pet" },
        },
    },
    many = {
        spells = { "Multi-Shot", "Explosive Trap", "Volley", "Serpent Sting" },
        lines = {
            "3-5 mobs: Multi-Shot and Auto Shot first.",
            { "Then step in and drop Explosive Trap.", needs = "Explosive Trap" },
            { "Big packs: Explosive Trap early, then Volley - watch your mana.", needs = "Volley" },
            "Send the pet in first so it holds one of them.",
        },
    },
    pet = {
        spells = { "Call Pet", "Mend Pet", "Revive Pet", "Intimidation", "Bestial Wrath" },
        lines = {
            "Your pet is a second damage dealer - give it its own mob.",
            "Keep its Claw and Bite up to date (tame a pet with the new rank, then teach it).",
            "Toggle its Growl so the mob bounces between you and the pet.",
            { "With Cheetah: turn Growl off, kite the mob and let the pet kill it.", needs = "Aspect of the Cheetah" },
            "Taming sets your armor to 0 - pull with Concussive Shot or drop a Freezing Trap first.",
        },
    },
    trouble = {
        spells = { "Feign Death", "Disengage", "Freezing Trap", "Concussive Shot", "Aspect of the Cheetah", "Mend Pet" },
        lines = {
            { "Feign Death drops everything off you (macro it with /stopcasting).", needs = "Feign Death" },
            { "Freezing Trap on one, kill the other.", needs = "Freezing Trap" },
            { "Disengage and Concussive Shot to get distance.", needs = "Disengage" },
            "Let the pet take the mobs while you shoot.",
        },
    },
})

SetSpecGuide("HUNTER", 1, {
    rotation = {
        spells = { "Hunter's Mark", "Aimed Shot", "Arcane Shot", "Auto Shot", "Serpent Sting", "Concussive Shot", "Wing Clip", "Raptor Strike" },
        lines = {
            { "Hunter's Mark first, then get some distance.", needs = "Hunter's Mark" },
            { "Open with Aimed Shot.", needs = "Aimed Shot" },
            "Auto Shot and Arcane Shot are your damage; Serpent Sting after them.",
            { "Arcane Shot is still better than Summon Hawk (Nov 2026).", needs = "Summon Hawk" },
            "Move away between Auto Shots - try never to let it touch you.",
            { "Concussive Shot to keep distance.", needs = "Concussive Shot" },
            "If it reaches you: Wing Clip and Raptor Strike together.",
            { "Bestial Wrath on tough mobs.", needs = "Bestial Wrath" },
        },
    },
})

SetSpecGuide("HUNTER", 2, {
    rotation = {
        spells = { "Hunter's Mark", "Sniper Shot", "Aimed Shot", "Serpent Sting", "Arcane Shot", "Auto Shot", "Multi-Shot" },
        lines = {
            { "Hunter's Mark before the pull (100 yards).", needs = "Hunter's Mark" },
            "Send the pet in first.",
            { "Open with Sniper Shot - your hardest hit, use it often.", needs = "Sniper Shot" },
            { "Open with Aimed Shot.", needs = "Aimed Shot", without = "Sniper Shot" },
            { "Check your threat after the opener - Feign Death if it comes for you.", needs = "Feign Death" },
            { "Keep Serpent Sting up for Rapid Recuperation mana.", needs = "Rapid Recuperation" },
            "Arcane Shot and Auto Shot between; melee weave if it reaches you.",
        },
    },
})

SetSpecGuide("HUNTER", 3, {
    rotation = {
        spells = { "Hunter's Mark", "Aimed Shot", "Serpent Sting", "Arcane Shot", "Raptor Strike", "Mongoose Bite", "Strider Kick" },
        lines = {
            { "Hunter's Mark before the pull.", needs = "Hunter's Mark" },
            { "Open with Aimed Shot, then Serpent Sting.", needs = "Aimed Shot" },
            "Don't go into melee until your Auto Shot has fired.",
            "Arcane Shot on the way in, then Raptor Strike (no global cooldown).",
            { "Mongoose Bite after a dodge.", needs = "Mongoose Bite" },
            { "Strider Kick to get back to range.", needs = "Strider Kick" },
        },
    },
})

--------------------------------------------------------------------------------
-- ROGUE: 1 Assassination, 2 Combat, 3 Subtlety
--------------------------------------------------------------------------------
local ROGUE_SLICE_AND_DICE = {
    { "Eviscerate when another builder won't fit before the mob dies.", to = 41 },
    { "Level 42+: keep Slice and Dice up with 2+ combo points (rank 2 is +30%).", from = 42 },
}

SetClassGuide("ROGUE", {
    single = {
        spells = { "Cheap Shot", "Garrote", "Ambush", "Riposte", "Kick", "Evasion" },
        lines = {
            "Elites: open from stealth, Kick heals and big casts.",
            { "Evasion when it hits hard.", needs = "Evasion" },
            { "Blade Flurry + Evasion together on a dangerous one.", needs = "Blade Flurry" },
            "Fight mobs while you travel - rogues level by never standing still.",
        },
    },
    two = {
        spells = { "Blade Flurry", "Evasion", "Gouge", "Adrenaline Rush" },
        lines = {
            { "Blade Flurry ready? Pull 2+ mobs together.", needs = "Blade Flurry" },
            { "High-level mobs: add Evasion so you don't die first.", needs = "Evasion" },
            { "Gouge one while you hit the other.", needs = "Gouge" },
            "Burst one down with your cooldowns, then the next.",
        },
    },
    many = {
        spells = { "Blade Flurry", "Evasion", "Sap", "Blind", "Vanish" },
        lines = {
            "Rogues have almost no area damage - avoid 3+ solo.",
            { "Sap one before the pull.", needs = "Sap" },
            { "Blind one more.", needs = "Blind" },
            { "Vanish to get out if it goes wrong.", needs = "Vanish" },
        },
    },
    trouble = {
        spells = { "Evasion", "Gouge", "Sprint", "Vanish", "Blind", "Kidney Shot" },
        lines = {
            { "Evasion first.", needs = "Evasion" },
            { "Gouge, then bandage or run with Sprint.", needs = "Gouge" },
            { "Vanish resets the fight.", needs = "Vanish" },
            { "Blind and walk away.", needs = "Blind" },
        },
    },
})

SetSpecGuide("ROGUE", 1, {
    rotation = {
        spells = { "Riposte", "Shank", "Mutilate", "Sinister Strike", "Slice and Dice", "Eviscerate", "Kick" },
        lines = {
            { "Riposte whenever it lights up - cheap, big hit, disarms.", needs = "Riposte" },
            { "Shank below 70 energy.", needs = "Shank" },
            { "Mutilate to build combo points.", needs = "Mutilate" },
            { "Sinister Strike to build combo points.", without = "Mutilate" },
            ROGUE_SLICE_AND_DICE[1], ROGUE_SLICE_AND_DICE[2],
            { "Kick heals and big casts.", needs = "Kick" },
        },
    },
})

SetSpecGuide("ROGUE", 2, {
    rotation = {
        spells = { "Riposte", "Shank", "Sinister Strike", "Slice and Dice", "Eviscerate", "Kick" },
        lines = {
            { "Riposte whenever it lights up - cheap, big hit, disarms.", needs = "Riposte" },
            { "Shank below 60 energy - it gives energy back.", needs = "Shank" },
            "Sinister Strike to build combo points.",
            ROGUE_SLICE_AND_DICE[1], ROGUE_SLICE_AND_DICE[2],
            { "Kick heals and big casts.", needs = "Kick" },
        },
    },
})

SetSpecGuide("ROGUE", 3, {
    rotation = {
        spells = { "Riposte", "Ghostly Strike", "Shank", "Garrote", "Hemorrhage", "Sinister Strike", "Slice and Dice", "Death Mark", "Eviscerate" },
        lines = {
            { "Riposte whenever it lights up.", needs = "Riposte" },
            { "Ghostly Strike on cooldown - more dodge and a free combo point.", needs = "Ghostly Strike" },
            { "Shank below 60 energy.", needs = "Shank" },
            { "Open with Garrote from stealth.", needs = "Garrote" },
            { "Hemorrhage to build combo points.", needs = "Hemorrhage" },
            { "Sinister Strike to build combo points.", without = "Hemorrhage" },
            ROGUE_SLICE_AND_DICE[1], ROGUE_SLICE_AND_DICE[2],
            { "Death Mark with 4+ combo points.", needs = "Death Mark" },
        },
    },
})

--------------------------------------------------------------------------------
-- PRIEST: 1 Discipline, 2 Holy, 3 Shadow
--------------------------------------------------------------------------------
SetClassGuide("PRIEST", {
    two = {
        spells = { "Shadow Word: Pain", "Power Word: Shield", "Renew", "Shoot", "Psychic Scream" },
        lines = {
            "Once you have a wand, pull 2-3 at a time.",
            "Shadow Word: Pain on all of them, then wand them down one by one.",
            "Power Word: Shield and Renew keep you topped up.",
            { "Too scared? Psychic Scream and a full Heal. Fearing often = pull fewer.", needs = "Psychic Scream" },
        },
    },
    many = {
        spells = { "Shadow Word: Pain", "Psychic Scream", "Holy Nova", "Power Word: Shield" },
        lines = {
            "More than 3 is too many solo - stick to 2-3.",
            { "Psychic Scream to break up a pack.", needs = "Psychic Scream" },
            { "Holy Nova if they all stand on you.", needs = "Holy Nova" },
        },
    },
    trouble = {
        spells = { "Power Word: Shield", "Psychic Scream", "Renew", "Flash Heal", "Heal", "Fade" },
        lines = {
            "Power Word: Shield first.",
            { "Psychic Scream, then heal yourself.", needs = "Psychic Scream" },
            "Free spells (Inner Focus, Desperate Prayer...) don't stop mana regen - use them.",
        },
    },
})

SetSpecGuide("PRIEST", 1, {
    rotation = {
        spells = { "Holy Fire", "Smite", "Shoot", "Power Word: Shield", "Renew", "Shadow Word: Pain" },
        lines = {
            "Keep Inner Fire, Fortitude and Divine Spirit up.",
            { "Open with Holy Fire.", needs = "Holy Fire" },
            { "Open with Smite, then Shadow Word: Pain.", without = "Holy Fire" },
            "Then Smite or wand - whichever does more damage at your level and mana.",
            "Wanding is not interrupted when you get hit.",
            "Power Word: Shield when it hits you; Renew between fights.",
        },
    },
})

SetSpecGuide("PRIEST", 2, {
    rotation = {
        spells = { "Smite", "Shadow Word: Pain", "Shoot", "Power Word: Shield", "Renew", "Holy Fire" },
        lines = {
            "Keep Fortitude, Inner Fire and later Divine Spirit up.",
            "One mob at a time: Smite to pull, Shadow Word: Pain, more Smite.",
            "Mana tight? Wand or melee to finish.",
            "Holy is the slowest solo spec - it shines in groups and dungeons.",
        },
    },
})

SetSpecGuide("PRIEST", 3, {
    rotation = {
        spells = { "Power Word: Shield", "Mind Blast", "Shadow Word: Pain", "Devouring Plague", "Vampiric Embrace", "Mind Flay", "Shadow Word: Death", "Smite", "Shoot" },
        lines = {
            "Keep Power Word: Fortitude and Inner Fire up.",
            { "Stay in Shadowform.", needs = "Shadowform" },
            "Power Word: Shield right before you pull.",
            { "Pull with Smite.", without = "Mind Blast" },
            { "Pull with Mind Blast.", needs = "Mind Blast" },
            "Shadow Word: Pain - step back during the global cooldown.",
            { "Devouring Plague and Vampiric Embrace, stepping back between.", needs = "Vampiric Embrace" },
            { "Mind Flay 2-3 times until your shield is about to break.", needs = "Mind Flay" },
            { "Shadow Word: Death on anything below 20%.", needs = "Shadow Word: Death" },
            { "Night Elf: Starshards while you have distance.", needs = "Starshards" },
            "Then wand it down - not casting lets your mana regenerate.",
        },
    },
    two = {
        spells = { "Shadow Word: Pain", "Devouring Plague", "Mind Flay", "Psychic Scream", "Power Word: Shield" },
        lines = {
            "Pull 2-3 and put Shadow Word: Pain on all of them.",
            { "Devouring Plague the one that lives longest - kill another fast to spread it.", needs = "Devouring Contagion" },
            "Shield and Renew yourself, wand them down one by one.",
            { "Psychic Scream if it gets scary.", needs = "Psychic Scream" },
        },
    },
})

--------------------------------------------------------------------------------
-- SHAMAN: 1 Elemental, 2 Enhancement, 3 Restoration
--------------------------------------------------------------------------------
SetClassGuide("SHAMAN", {
    many = {
        spells = { "Magma Totem", "Fire Nova", "Chain Lightning", "Earthbind Totem", "Stormstrike", "Flame Shock" },
        lines = {
            { "Magma Totem; move it with Totemic Call when needed.", needs = "Magma Totem" },
            { "Fire Nova on cooldown with 3+ mobs.", needs = "Fire Nova" },
            { "Chain Lightning on cooldown.", needs = "Chain Lightning" },
            "Flame Shock the ones with most health.",
            { "Earthbind Totem to keep them away from you.", needs = "Earthbind Totem" },
        },
    },
    trouble = {
        spells = { "Healing Wave", "Lesser Healing Wave", "Earthbind Totem", "Stoneclaw Totem", "Frost Shock", "Ghost Wolf" },
        lines = {
            { "Stoneclaw Totem takes the hits while you heal.", needs = "Stoneclaw Totem" },
            "Heal between mobs, not while being hit.",
            { "Earthbind Totem or Frost Shock, then run with Ghost Wolf.", needs = "Ghost Wolf" },
            "Leaving totems behind? Totemic Recall gives 25% of their mana back.",
            "Rank 1 Earth Shock is a cheap interrupt.",
        },
    },
})

SetSpecGuide("SHAMAN", 1, {
    rotation = {
        spells = { "Searing Totem", "Flame Shock", "Lightning Mastery", "Chain Lightning", "Lightning Bolt", "Earth Shock" },
        lines = {
            "Before the fight: Flametongue Weapon; Lightning Shield is nice.",
            { "Drop Searing Totem before you pull.", needs = "Searing Totem" },
            { "Flame Shock the target.", needs = "Flame Shock" },
            { "Lightning Mastery and your racial.", needs = "Lightning Mastery" },
            { "Chain Lightning if mana allows.", needs = "Chain Lightning" },
            "Lightning Bolt as filler.",
            { "Elemental Focus proc: Chain Lightning or Earth Shock.", needs = "Elemental Focus" },
            "Mob below 20% or in melee? Hit it with your weapon and save mana.",
        },
    },
    two = {
        spells = { "Searing Totem", "Flame Shock", "Chain Lightning", "Lightning Bolt" },
        lines = {
            "Flame Shock both, Searing Totem helps.",
            { "Chain Lightning hits both.", needs = "Chain Lightning" },
            "Let the totem and dots finish them while you regenerate.",
        },
    },
})

SetSpecGuide("SHAMAN", 2, {
    rotation = {
        spells = { "Flame Shock", "Rage of the Farseer", "Stormstrike", "Lightning Bolt", "Earth Shock", "Frost Shock" },
        lines = {
            { "Before the fight: Rockbiter or Flametongue on your weapon.", without = "Windfury Weapon" },
            { "Before the fight: Windfury Weapon on your weapon.", needs = "Windfury Weapon" },
            { "Lightning Shield up.", without = "Water Shield" },
            { "Water Shield up - mana back when you get hit.", needs = "Water Shield" },
            { "Drop your 4 totems with Call of the Elements.", needs = "Call of the Elements" },
            "Use a /startattack macro - the attack button toggles off in Forever.",
            { "From range: Flame Shock if the mob lives 12+ seconds.", needs = "Flame Shock" },
            { "Rage of the Farseer, then Stormstrike.", needs = "Rage of the Farseer" },
            { "Stormstrike on cooldown.", needs = "Stormstrike", without = "Rage of the Farseer" },
            { "Lightning Bolt at 5 Maelstrom Weapon stacks.", needs = "Maelstrom Weapon" },
            "Earth Shock (Frost Shock if you have too much threat).",
            "Low mana or mob below 20%: stop casting so mana regenerates.",
        },
    },
    two = {
        spells = { "Flame Shock", "Stormstrike", "Searing Totem", "Earth Shock" },
        lines = {
            "Flame Shock both, then melee one down.",
            { "Searing Totem helps on the second.", needs = "Searing Totem" },
            "Windfury does most of the work - relax and let it.",
        },
    },
})

SetSpecGuide("SHAMAN", 3, {
    rotation = {
        spells = { "Lightning Bolt", "Flame Shock", "Earth Shock", "Searing Totem", "Healing Wave", "Lesser Healing Wave" },
        lines = {
            "Resto is slow solo - best with a partner or in dungeons.",
            { "Lightning Bolt at range, then fight with your weapon.", to = 9 },
            { "Rockbiter Weapon and melee; Earth Shock only for dangerous casts.", needs = "Rockbiter Weapon", without = "Windfury Weapon" },
            { "Windfury Weapon from 30 if your weapon is good.", needs = "Windfury Weapon" },
            { "Flame Shock if the mob lives long enough.", needs = "Flame Shock" },
            { "Searing Totem when it is worth the mana.", needs = "Searing Totem" },
            "Heal between mobs, not under melee pressure.",
        },
    },
    many = {
        spells = { "Chain Heal", "Healing Wave", "Lesser Healing Wave", "Mana Tide Totem", "Riptide" },
        lines = {
            "Healing a group: choose the target first, then the spell.",
            { "Riptide first so Chain Heal heals more.", needs = "Riptide" },
            { "Chain Heal when several are hurt.", needs = "Chain Heal" },
            { "Mana Tide Totem before you run dry.", needs = "Mana Tide Totem" },
        },
    },
})

--------------------------------------------------------------------------------
-- MAGE: 1 Arcane, 2 Fire, 3 Frost
--------------------------------------------------------------------------------
local MAGE_OUT_OF_MANA = "Out of mana: mana gem, potion or Evocation - then wand."

SetClassGuide("MAGE", {
    two = {
        spells = { "Polymorph", "Frost Nova", "Frostbolt", "Cone of Cold" },
        lines = {
            { "Polymorph one, kill the other.", needs = "Polymorph" },
            { "Frost Nova and step away if both reach you.", needs = "Frost Nova" },
        },
    },
    trouble = {
        spells = { "Frost Nova", "Blink", "Polymorph", "Ice Block", "Ice Barrier", "Mana Shield" },
        lines = {
            "Overpulled? Control them: Frost Nova, Polymorph, then run or fight.",
            { "Blink away after Frost Nova.", needs = "Blink" },
            { "Ice Block to survive - press again to leave it early.", needs = "Ice Block" },
            "Ice Armor / Frost Armor solo, Mage Armor only in dungeons.",
            "Buy better water than you can conjure (e.g. Melon Juice at 15, Sweet Nectar at 25).",
        },
    },
})

SetSpecGuide("MAGE", 1, {
    rotation = {
        spells = { "Arcane Wrath", "Arcane Missiles", "Arcane Blast", "Presence of Mind", "Arcane Power", "Fireball" },
        lines = {
            "Always be casting.",
            { "Precast Arcane Wrath.", needs = "Arcane Wrath" },
            { "Precast Fireball, then Fireball / Frostbolt.", without = "Arcane Blast" },
            { "Missile Barrage proc: Arcane Missiles.", needs = "Missile Barrage" },
            { "Arcane Wrath when it is safe to cast.", needs = "Arcane Wrath" },
            { "Arcane Blast as long as your mana allows.", needs = "Arcane Blast" },
            { "Presence of Mind on Arcane Wrath, or to move.", needs = "Presence of Mind" },
            { "Arcane Power with your racial right after the precast.", needs = "Arcane Power" },
            MAGE_OUT_OF_MANA,
        },
    },
    many = {
        spells = { "Flamestrike", "Arcane Power", "Arcane Explosion", "Frost Nova" },
        lines = {
            { "Precast Flamestrike - careful, lots of threat.", needs = "Flamestrike" },
            { "Arcane Power and racials.", needs = "Arcane Power" },
            { "Then spam Arcane Explosion.", needs = "Arcane Explosion" },
        },
    },
})

SetSpecGuide("MAGE", 2, {
    rotation = {
        spells = { "Pyroblast", "Scorch", "Fire Blast", "Arcane Missiles", "Fireball", "Combustion" },
        lines = {
            "Always be casting.",
            { "Precast Pyroblast out of combat.", needs = "Pyroblast" },
            { "Scorch first only if the mob lives long.", needs = "Scorch" },
            { "Fire Blast on cooldown to build Heating Up; at 3 stacks: Pyroblast.", needs = "Heating Up" },
            { "Fire Blast on cooldown.", without = "Heating Up" },
            { "Missile Barrage proc: Arcane Missiles.", needs = "Missile Barrage" },
            "Fireball as filler.",
            { "Combustion with racials and potions.", needs = "Combustion" },
            MAGE_OUT_OF_MANA,
        },
    },
    many = {
        spells = { "Flamestrike", "Blast Wave", "Arcane Explosion", "Frost Nova" },
        lines = {
            { "Precast Flamestrike - watch your threat.", needs = "Flamestrike" },
            { "Blast Wave.", needs = "Blast Wave" },
            { "Then spam Arcane Explosion.", needs = "Arcane Explosion" },
        },
    },
})

SetSpecGuide("MAGE", 3, {
    rotation = {
        spells = { "Ice Barrier", "Frostbolt", "Ice Lance", "Arcane Missiles", "Fire Blast", "Fireball" },
        lines = {
            "Always be casting.",
            { "Keep Ice Barrier up (+3% damage).", needs = "Ice Barrier" },
            { "Spam Frostbolt.", needs = "Frostbolt" },
            { "Spam Fireball.", without = "Frostbolt" },
            { "Fingers of Frost proc: stop casting and Ice Lance.", needs = "Fingers of Frost" },
            { "Frostbite proc: Frostbolt, then Ice Lance so both hit while frozen.", needs = "Frostbite" },
            { "Missile Barrage proc: Arcane Missiles.", needs = "Missile Barrage" },
            "Moving? Fire Blast.",
            MAGE_OUT_OF_MANA,
        },
    },
    many = {
        spells = { "Frost Nova", "Blink", "Blizzard", "Cone of Cold", "Arcane Explosion", "Flamestrike" },
        lines = {
            { "Gather them, Frost Nova, then Blink or run away.", needs = "Frost Nova" },
            { "Blizzard from max range.", needs = "Blizzard" },
            { "When they reach you: Cone of Cold, then Arcane Explosion.", needs = "Cone of Cold" },
            "Nova again and repeat.",
            { "Finish frozen mobs: Flamestrike + Cone of Cold (Shatter crits).", needs = "Shatter" },
        },
    },
})

--------------------------------------------------------------------------------
-- WARLOCK: 1 Affliction, 2 Demonology, 3 Destruction
--------------------------------------------------------------------------------
SetClassGuide("WARLOCK", {
    two = {
        spells = { "Bane of Agony", "Curse of the Elements", "Corruption", "Fear" },
        lines = {
            "Dot up mob 1. At about 50% health, pull the next one.",
            "Pull with Bane of Agony or Curse of the Elements - low threat.",
            "Send your demon to the new mob and dot it up.",
            { "Fear one if it gets dangerous.", needs = "Fear" },
        },
    },
    many = {
        spells = { "Corruption", "Bane of Agony", "Fear", "Hellfire", "Howl of Terror", "Death Coil" },
        lines = {
            "2-3 mobs is fine once your dots tick - keep pulling while dots finish the last one.",
            { "Fear only the one hitting YOU - a feared mob can run off and pull more.", needs = "Fear" },
            { "Feared mob running into others? Curse of Recklessness brings it back.", needs = "Curse of Recklessness" },
            { "Big pack: Corruption on a few, Hellfire a few yards away (it hurts you too).", needs = "Hellfire" },
            { "Howl of Terror in melee range when it goes wrong.", needs = "Howl of Terror" },
        },
    },
    pet = {
        spells = { "Summon Succubus", "Summon Incubus", "Summon Voidwalker", "Summon Imp", "Health Funnel", "Fel Domination" },
        lines = {
            { "Imp until level 10 - keep it attacking.", without = "Summon Voidwalker" },
            { "Voidwalker: the safe choice, it holds several mobs.", needs = "Summon Voidwalker" },
            { "Succubus / Incubus deals the most damage - use it while leveling.", needs = { "Summon Succubus", "Summon Incubus" } },
            "Send the demon in first so it gets threat before you cast.",
            { "Voidwalker: set Torment to manual and macro /petattack into it.", needs = "Summon Voidwalker" },
            { "Fel Domination + Master Summoner: resummon instead of Health Funnel.", needs = "Fel Domination" },
            { "Imp + Demonic Sacrifice (+15% shadow), then summon your Succubus.", needs = "Demonic Sacrifice" },
            "Bandages (First Aid) top your demon up fast between pulls.",
        },
    },
    trouble = {
        spells = { "Death Coil", "Fear", "Howl of Terror", "Drain Life", "Create Healthstone", "Health Funnel" },
        lines = {
            { "Death Coil heals you and makes the enemy run.", needs = "Death Coil" },
            "Fear the one hitting you, Drain Life to heal.",
            { "Keep a Healthstone in your bags.", needs = "Create Healthstone" },
            { "Howl of Terror when several reach you.", needs = "Howl of Terror" },
        },
    },
})

SetSpecGuide("WARLOCK", 1, {
    rotation = {
        spells = { "Bane of Agony", "Immolate", "Corruption", "Siphon Life", "Curse of the Elements", "Drain Life", "Wrack", "Shoot", "Shadow Bolt", "Drain Soul" },
        lines = {
            "Send your demon in first and let it get threat.",
            { "Bane of Agony, Immolate, Corruption.", needs = "Bane of Agony" },
            { "Corruption and Immolate, then Shadow Bolt.", without = "Bane of Agony" },
            { "Siphon Life too.", needs = "Siphon Life" },
            { "Curse of the Elements if it lives a while.", needs = "Curse of the Elements" },
            { "Then wand - Drain Life is weak until rank 4 at level 38.", to = 37 },
            { "Then Drain Life to stay healthy; Life Tap for mana.", from = 38 },
            { "Wrack, alternating with Drain Life.", needs = "Wrack" },
            { "Nightfall proc: instant Shadow Bolt.", needs = "Nightfall" },
            { "Finish with Drain Soul when you need Soul Shards.", needs = "Drain Soul" },
        },
    },
})

SetSpecGuide("WARLOCK", 2, {
    rotation = {
        spells = { "Searing Pain", "Bane of Agony", "Curse of the Elements", "Immolate", "Corruption", "Shadow Bolt", "Shoot", "Drain Life" },
        lines = {
            "Send your demon in first (Succubus from level 20).",
            { "Searing Pain for Demonic Brand - macro /petattack into it.", needs = "Demonic Brand" },
            { "Bane of Agony, Curse of the Elements, Immolate, Corruption.", needs = "Bane of Agony" },
            { "Immolate, Corruption, then Shadow Bolt.", without = "Bane of Agony" },
            { "Then wand.", to = 29 },
            { "Then Shadow Bolt (wand to save mana).", from = 30 },
            { "Recast Searing Pain when Demonic Brand runs low.", needs = "Demonic Brand" },
            "Drain Life when you need health; Drain Soul for shards.",
        },
    },
    two = {
        spells = { "Searing Pain", "Bane of Agony", "Curse of the Elements", "Corruption", "Immolate" },
        lines = {
            "Demonology is best at two at a time.",
            "Brand and dot mob 1; at 50% pull mob 2 with a low-threat curse.",
            "Brand mob 2 and send the demon over while you dot it.",
            "It's fine to tank one mob yourself - keep dots up and wand.",
            { "Succubus below 20%? Fel Domination and summon a fresh one.", needs = "Fel Domination" },
        },
    },
})

SetSpecGuide("WARLOCK", 3, {
    rotation = {
        spells = { "Immolate", "Corruption", "Conflagrate", "Shadowburn", "Incinerate", "Shadow Bolt", "Bane of Agony" },
        lines = {
            "Destruction levels slowest and eats mana - Life Tap often.",
            "Send your demon in first.",
            { "Bane of Agony if the mob lives long.", needs = "Bane of Agony" },
            "Immolate, Corruption.",
            { "Conflagrate on cooldown.", needs = "Conflagrate" },
            { "Shadowburn on cooldown (needs a Soul Shard).", needs = "Shadowburn" },
            { "Incinerate as filler.", needs = "Incinerate" },
            { "Shadow Bolt as filler.", without = "Incinerate" },
        },
    },
})

--------------------------------------------------------------------------------
-- DRUID: 1 Balance, 2 Feral Combat, 3 Restoration
--------------------------------------------------------------------------------
SetClassGuide("DRUID", {
    trouble = {
        spells = { "Entangling Roots", "Regrowth", "Rejuvenation", "Healing Touch", "Barkskin", "Bear Form" },
        lines = {
            "Root it with Entangling Roots and heal yourself - it works indoors too.",
            "You can drink potions in your forms in Forever.",
            { "Barkskin while you heal.", needs = "Barkskin" },
            { "Bear Form to survive a bad pull.", needs = "Bear Form" },
            { "Teleport: Moonglade works as a second hearthstone.", needs = "Teleport: Moonglade" },
        },
    },
})

SetSpecGuide("DRUID", 1, {
    rotation = {
        spells = { "Moonfire", "Insect Swarm", "Wrath", "Rejuvenation", "Regrowth", "Starfire", "Entangling Roots" },
        lines = {
            "Keep Mark of the Wild and Thorns up - Thorns hurts everything that hits you.",
            "Moonfire and Insect Swarm, then Wrath as filler.",
            { "Insect Swarm too.", needs = "Insect Swarm" },
            "Rejuvenation and Regrowth on yourself while they tick.",
            { "Starfire once you have Eclipse and Improved Starfire.", needs = "Eclipse" },
        },
    },
    single = {
        spells = { "Entangling Roots", "Moonfire", "Insect Swarm", "Rejuvenation", "Regrowth" },
        lines = {
            "Tough elite: Entangling Roots it, heal up while your dots tick.",
            "It can't flee or pull friends while rooted - rot it down slowly.",
        },
    },
    two = {
        spells = { "Moonfire", "Insect Swarm", "Rejuvenation", "Wrath" },
        lines = {
            "Balance can tank several mobs: dot them all, Thorns and heals do the rest.",
            "Wrath is cheap with Improved Wrath and Moonglow.",
        },
    },
    many = {
        spells = { "Hurricane", "Moonfire", "Insect Swarm", "Entangling Roots" },
        lines = {
            { "Hurricane for groups.", needs = "Hurricane" },
            "Dot the rest and heal yourself.",
        },
    },
})

SetSpecGuide("DRUID", 2, {
    rotation = {
        spells = { "Prowl", "Ravage", "Shred", "Faerie Fire", "Rake", "Shifting Power", "Claw", "Ferocious Bite", "Wrath", "Moonfire" },
        lines = {
            "Keep Mark of the Wild and Thorns up.",
            { "Wrath from max range, Moonfire, Wrath until it reaches you; finish in melee.", without = { "Cat Form", "Bear Form" } },
            { "Optional bear: Wrath + Moonfire, Bear Form, Enrage, Maul (Swipe on 3+).", needs = "Bear Form", without = "Cat Form" },
            { "Prowl in Cat Form and sneak behind the mob.", needs = "Cat Form" },
            { "Open with Ravage.", needs = "Ravage" },
            { "Open with Shred.", needs = "Shred", without = "Ravage" },
            { "Faerie Fire, Rake, then Claw to 5 combo points.", needs = "Cat Form" },
            { "Shifting Power once per mob.", needs = "Shifting Power" },
            { "At 5 points wait for full energy, then Ferocious Bite.", needs = "Ferocious Bite" },
            "Your weapon's DPS counts in forms in Forever - upgrade it.",
        },
    },
    two = {
        spells = { "Bear Form", "Demoralizing Roar", "Swipe", "Maul" },
        lines = {
            "Cat: one mob at a time - pulling more gains little.",
            { "Two came anyway? Bear Form, Demoralizing Roar, Maul.", needs = "Bear Form" },
        },
    },
    many = {
        spells = { "Bear Form", "Demoralizing Roar", "Swipe", "Challenging Roar" },
        lines = {
            { "Bear Form and Swipe for 3+.", needs = "Swipe" },
            { "Demoralizing Roar so they hit softer.", needs = "Demoralizing Roar" },
        },
    },
})

SetSpecGuide("DRUID", 3, {
    rotation = {
        spells = { "Moonfire", "Starfire", "Wrath", "Rejuvenation", "Regrowth", "Bear Form", "Maul" },
        lines = {
            "Keep Mark of the Wild and Thorns up.",
            { "Moonfire, Rejuvenation on yourself, Wrath with spare mana; finish with melee.", to = 9 },
            { "10-15: Bear Form is stronger until you have a caster weapon - Enrage, Demoralizing Roar, Maul.", from = 10, to = 15 },
            { "Moonfire if it lives 9+ seconds.", from = 16 },
            { "Starfire - Nature's Focus stops pushback.", needs = "Starfire", from = 16 },
            { "Wrath when low on mana or to finish.", from = 16 },
        },
    },
    two = {
        spells = { "Moonfire", "Rejuvenation", "Wrath", "Bear Form" },
        lines = {
            "Early on Resto is great at 2 mobs: Moonfire on both, Rejuvenation yourself.",
            { "Bear Form: Moonfire both, then Demoralizing Roar and Maul.", needs = "Bear Form" },
        },
    },
    many = {
        spells = { "Wild Growth", "Tranquility", "Regrowth", "Swiftmend", "Rejuvenation" },
        lines = {
            "Healing a group: Wild Growth when 3+ are hurt.",
            { "Tranquility for big group damage (Regrowth + Rejuvenation the tank first).", needs = "Tranquility" },
            "Keep Regrowth on the tank; Swiftmend to catch up.",
        },
    },
})

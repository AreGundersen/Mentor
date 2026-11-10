--------------------------------------------------------------------------------
-- Mentor - Extras.lua
-- Data for the "Spells & macros" panel:
--   * RACIALS: what each race's abilities do and when to press them.
--   * MACROS:  ready-made, beginner-friendly macros per class.
--
-- Spell names that do not exist in this game version are simply not shown
-- (Mentor.ResolveSpell finds no spell id), so a table can list old and new
-- names side by side.
--------------------------------------------------------------------------------

local _, Mentor = ...

--------------------------------------------------------------------------------
-- Racials, keyed by the race file name from UnitRace("player").
-- Each entry: { spell = "Name", tip = "When to use it" }.
--------------------------------------------------------------------------------
Mentor.RACIALS = {
    -- WoW Forever reworked the racials (Oct 2026). Several names differ
    -- between sources and patches, so both spellings are listed where
    -- unsure; only abilities your character actually has are shown.
    Human = {
        { spell = "Will to Survive", tip = "Breaks stuns. Save it for the moment something locks you down." },
        { spell = "Every Man for Himself", tip = "Breaks stuns. Save it for the moment something locks you down." },
        { spell = "Perception", tip = "Shows stealthed rogues and druids nearby for a short time." },
        { spell = "Sword Specialization", tip = "Passive: extra crit chance with swords." },
        { spell = "Ruthlessness", tip = "Passive: a little extra crit chance." },
        { spell = "Ruthless", tip = "Passive: a little extra crit chance." },
        { spell = "The Human Spirit", tip = "Passive: more Spirit, so you regenerate faster." },
    },
    Dwarf = {
        { spell = "Stoneform", tip = "Immune to poison, disease and bleeds and less physical damage for 8 sec. Press it when a mob poisons you or you are about to die." },
        { spell = "Find Treasure", tip = "Shows treasure chests on the minimap while leveling." },
        { spell = "Mace Specialization", tip = "Passive: extra crit chance with maces." },
        { spell = "Big Game Hunter", tip = "Passive: more damage to beasts - many leveling mobs are beasts." },
        { spell = "Artisan's Precision", tip = "Passive: 1% more hit chance with spells and attacks." },
    },
    NightElf = {
        { spell = "Elune's Light", tip = "+10% crit chance for 15 sec. Press it at the start of a hard fight." },
        { spell = "Shadowmeld", tip = "Stand still to hide. Out of combat it lets you sneak past mobs; in a pull gone wrong it can drop you out of the fight." },
        { spell = "Quickness", tip = "Passive: more dodge and a bit faster run speed." },
        { spell = "Wisp Spirit", tip = "Passive: you run much faster as a ghost after dying." },
    },
    Gnome = {
        { spell = "Eureka!", tip = "Your next 3 spells or abilities cost less and hit 10% harder. Use it on a big fight or a tough pull." },
        { spell = "Eureka", tip = "Your next 3 spells or abilities cost less and hit 10% harder. Use it on a big fight or a tough pull." },
        { spell = "Escape Artist", tip = "Breaks roots and slows (Frost Nova, nets, Entangling Roots). Use it to get away or back into range." },
        { spell = "Expansive Mind", tip = "Passive: 5% more max mana, rage or energy." },
        { spell = "Engineering Specialization", tip = "Passive: your engineering gadgets fail less often." },
    },
    Skyborne = {
        { spell = "Walk on Air", tip = "Glide gently down for 10 sec. Jump off cliffs safely and take shortcuts." },
        { spell = "Read Ley Line", tip = "+50% health and mana regeneration for 15 sec - use it while eating/drinking. At a ley line it lasts 1 hour and gets stronger." },
        { spell = "Read Leyline", tip = "+50% health and mana regeneration for 15 sec - use it while eating/drinking. At a ley line it lasts 1 hour and gets stronger." },
        { spell = "Leyline Reading", tip = "+50% health and mana regeneration for 15 sec - use it while eating/drinking. At a ley line it lasts 1 hour and gets stronger." },
        { spell = "Skysight", tip = "+15% run speed for 15 sec. At an elemental convergence it lasts 1 hour and gives +30%." },
        { spell = "Skyward Gaze", tip = "+15% run speed for 15 sec. At an elemental convergence it lasts 1 hour and gives +30%." },
        { spell = "Wind Blessed", tip = "Passive: a bit more haste on everything." },
        { spell = "Wind-Blessed", tip = "Passive: a bit more haste on everything." },
        { spell = "Elemental Insight", tip = "Passive: more damage to elementals." },
    },
    Orc = {
        { spell = "Blood Fury", tip = "+10% attack power and spell power for 15 sec. Press it at the start of a hard fight." },
        { spell = "Shatter Curse", tip = "Immune to curses and banes and less magic damage for 8 sec. Use it against casters that curse you." },
        { spell = "Axe Specialization", tip = "Passive: extra crit chance with axes." },
        { spell = "Hardiness", tip = "Passive: stuns on you are 20% shorter." },
        { spell = "Command", tip = "Passive: Hunter and Warlock pets deal 5% more damage." },
    },
    Scourge = {
        { spell = "Will of the Forsaken", tip = "Breaks fear, charm and sleep. Press it as soon as you get feared." },
        { spell = "Cannibalize", tip = "Eat a nearby humanoid or undead corpse to get health and mana back - free food after every kill." },
        { spell = "Touch of the Grave", tip = "Passive: your attacks sometimes drain health from the enemy." },
        { spell = "Underwater Breathing", tip = "Passive: you can stay under water much longer." },
    },
    Tauren = {
        { spell = "War Stomp", tip = "Stuns enemies around you for 2 seconds. Use it to stop a cast, to get a free heal off, or to run away." },
        { spell = "Cultivation", tip = "Pick extra herbs even without Herbalism." },
        { spell = "Plainsrunning", tip = "Passive: you run faster the longer you keep moving (not on a mount)." },
        { spell = "Endurance", tip = "Passive: 5% more health." },
    },
    Troll = {
        { spell = "Berserking", tip = "+10% attack and casting speed for 10 sec. Press it at the start of every hard fight." },
        { spell = "Rapid Regeneration", tip = "Heals 50% of your health over a short time. Your 'oh no' button when a fight goes badly." },
        { spell = "Beast Slaying", tip = "Passive: more damage to beasts - many leveling mobs are beasts." },
        { spell = "Regeneration", tip = "Passive: some health regeneration keeps going in combat." },
    },
    -- Races from the retail client, in case they appear.
    Draenei = { { spell = "Gift of the Naaru", tip = "Heals you or a friend over a few seconds." } },
    BloodElf = { { spell = "Arcane Torrent", tip = "Silences enemies around you and gives you some mana, energy or rage." } },
}

-- Returns the racial list for a race, also when the game's race file name is
-- not one of the keys above (Skyborne may come in an Alliance and a Horde
-- version, e.g. "SkyborneHighOrder").
function Mentor.GetRacialList(raceFileName, raceName)
    if Mentor.RACIALS[raceFileName] then
        return Mentor.RACIALS[raceFileName]
    end
    local searchText = ((raceFileName or "") .. " " .. (raceName or "")):lower():gsub("[%s%-']", "")
    for raceKey, racialList in pairs(Mentor.RACIALS) do
        if searchText:find(raceKey:lower(), 1, true) then
            return racialList
        end
    end
    return {}
end

--------------------------------------------------------------------------------
-- New abilities from the class trainer in WoW Forever, by level.
-- Only the FIRST rank of each ability; talents are not listed here (they come
-- from your talent build). Sources: wowforever.wclbox.com trainer lists,
-- checked against senseos.gg's list of Forever-only abilities. Spell names
-- are the English ones (the trainer lists are machine translated in places).
-- Each entry: { level, "Spell Name", "what it does in a few words" }
--------------------------------------------------------------------------------
Mentor.TRAINER_SPELLS = {
    WARRIOR = {
        { 4, "Charge", "Rush to an enemy and stun it. Gives rage." },
        { 4, "Rend", "Bleeds the target over time." },
        { 6, "Thunder Clap", "Damages and slows the attacks of enemies around you." },
        { 8, "Hamstring", "Slows the target so it can't run away." },
        { 10, "Defensive Stance", "Stance for tanking: you take less damage." },
        { 10, "Sunder Armor", "Lowers the target's armor. Lots of threat." },
        { 10, "Taunt", "Forces the target to attack you." },
        { 10, "Bloodrage", "Turns some health into rage." },
        { 12, "Overpower", "Strong hit after the target dodges." },
        { 12, "Shield Bash", "Interrupts a spell. Needs a shield." },
        { 14, "Revenge", "Strong hit after you block, dodge or parry." },
        { 14, "Demoralizing Shout", "Enemies around you hit softer." },
        { 14, "Tactical Mastery", "Keep up to 10 rage when you change stance." },
        { 16, "Shield Block", "Block much more often for a few seconds." },
        { 16, "Mocking Blow", "Hit that forces the target to attack you." },
        { 18, "Disarm", "Takes the enemy's weapon away for 10 sec." },
        { 20, "Victory Rush", "Strong hit that heals you - only right after a kill." },
        { 20, "Cleave", "Hits your target and one more enemy." },
        { 20, "Slam", "Heavy weapon hit." },
        { 20, "Retaliation", "Strike back at everyone who hits you." },
        { 22, "Intimidating Shout", "Fears up to 5 enemies around you." },
        { 24, "Execute", "Huge hit on enemies below 20% health." },
        { 26, "Challenging Shout", "Taunts every enemy around you." },
        { 28, "Shield Wall", "Take much less damage for 12 sec." },
        { 30, "Berserker Stance", "Stance with extra crit, but you take more damage." },
        { 30, "Berserker Rage", "Immune to fear and gain extra rage." },
        { 30, "Intercept", "Charge in Berserker Stance, also in combat." },
        { 36, "Whirlwind", "Hit up to 4 enemies around you." },
        { 38, "Pummel", "Interrupts a spell in Berserker Stance." },
        { 50, "Recklessness", "Much more crit for 15 sec, but you take more damage." },
    },
    PALADIN = {
        { 4, "Blessing of Might", "More attack power." },
        { 4, "Judgement", "Releases your seal as damage on the target." },
        { 6, "Holy Strike", "Instant weapon hit with holy damage." },
        { 6, "Divine Protection", "Short immunity to physical attacks." },
        { 6, "Seal of the Crusader", "Faster attacks and more attack power." },
        { 8, "Hammer of Justice", "Stuns the target for 3 sec." },
        { 8, "Purify", "Removes a poison and a disease." },
        { 10, "Lay on Hands", "Heals a target to full. Uses all your mana." },
        { 10, "Blessing of Protection", "Immune to physical attacks for 6 sec." },
        { 10, "Seal of Fury", "Seal with extra holy damage and threat - for tanking." },
        { 12, "Redemption", "Brings a dead player back to life." },
        { 14, "Blessing of Wisdom", "Restores mana over time." },
        { 16, "Retribution Aura", "Damages enemies that hit your group." },
        { 18, "Blessing of Freedom", "Immune to slows for 10 sec." },
        { 20, "Flash of Light", "Fast, cheap heal." },
        { 20, "Consecration", "Holy damage on the ground around you." },
        { 20, "Exorcism", "Big holy damage to undead and demons." },
        { 20, "Blessing of Kings", "+10% to all stats." },
        { 22, "Seal of Justice", "Your hits can stun the target." },
        { 22, "Concentration Aura", "Spells get interrupted less." },
        { 24, "Turn Undead", "Makes undead flee." },
        { 30, "Seal of Light", "Your hits heal you." },
        { 34, "Divine Shield", "Immune to all damage for 10 sec." },
        { 38, "Seal of Wisdom", "Your hits give mana back." },
        { 40, "Hammer of the Righteous", "Hits up to 4 enemies." },
        { 40, "Summon Warhorse", "Your own mount." },
        { 42, "Cleanse", "Removes poison, disease and magic." },
        { 44, "Hammer of Wrath", "Ranged finisher on enemies below 20% health." },
        { 46, "Blessing of Sacrifice", "Take damage for a party member." },
        { 50, "Holy Wrath", "Damages and stuns undead and demons around you." },
        { 60, "Summon Charger", "Your epic mount." },
    },
    HUNTER = {
        { 4, "Aspect of the Monkey", "More dodge while enemies are in melee." },
        { 4, "Serpent Sting", "Poison damage over time." },
        { 6, "Arcane Shot", "Instant arcane damage shot." },
        { 6, "Hunter's Mark", "More ranged attack power against the target." },
        { 8, "Concussive Shot", "Slows the target by 50%." },
        { 10, "Tame Beast", "Tame your first pet (also a class quest)." },
        { 10, "Call Pet", "Calls your pet." },
        { 10, "Revive Pet", "Brings your dead pet back." },
        { 10, "Aspect of the Hawk", "More ranged attack power." },
        { 12, "Mend Pet", "Heals your pet over time." },
        { 12, "Wing Clip", "Melee hit that slows the target." },
        { 12, "Distracting Shot", "Pulls threat off your pet or a friend." },
        { 14, "Scare Beast", "Makes a beast flee." },
        { 14, "Eyes of the Beast", "See and move as your pet." },
        { 16, "Immolation Trap", "Trap that burns the enemy." },
        { 16, "Mongoose Bite", "Strong melee hit after you dodge." },
        { 18, "Multi-Shot", "Hits up to 3 enemies." },
        { 20, "Aspect of the Cheetah", "Run faster (dazed if hit)." },
        { 20, "Aimed Shot", "Slow but very strong shot." },
        { 20, "Disengage", "Jump back and lose threat." },
        { 20, "Freezing Trap", "Freezes the first enemy that steps on it." },
        { 22, "Scorpid Sting", "The target misses more." },
        { 26, "Rapid Fire", "Shoot much faster for a short time." },
        { 28, "Frost Trap", "Ice on the ground that slows enemies." },
        { 30, "Feign Death", "Pretend to be dead - mobs leave you alone." },
        { 30, "Aspect of the Beast", "Mobs can't track you; more melee power." },
        { 32, "Flare", "Shows stealthed enemies in an area." },
        { 34, "Explosive Trap", "Trap that blows up enemies around it." },
        { 36, "Viper Sting", "Drains the target's mana." },
        { 40, "Volley", "Rain arrows on an area." },
        { 40, "Aspect of the Pack", "Faster run speed for the group." },
        { 46, "Aspect of the Wild", "Nature resistance for the group." },
        { 60, "Tranquilizing Shot", "Calms an enraged enemy." },
    },
    ROGUE = {
        { 4, "Backstab", "Big hit from behind with a dagger." },
        { 4, "Pick Pocket", "Steal from a humanoid while stealthed." },
        { 6, "Gouge", "Stuns the target until it takes damage." },
        { 8, "Evasion", "Dodge much more for 15 sec." },
        { 10, "Slice and Dice", "Faster attacks; longer with more combo points." },
        { 10, "Sprint", "Run much faster for a few seconds." },
        { 10, "Sap", "Knocks out a humanoid that is not in combat." },
        { 12, "Kick", "Interrupts a spell." },
        { 14, "Garrote", "Bleed from stealth, from behind." },
        { 14, "Expose Armor", "Lowers the target's armor." },
        { 16, "Feint", "Lowers your threat." },
        { 18, "Ambush", "Huge hit from stealth, from behind." },
        { 18, "Poised", "Your next ability costs less energy." },
        { 20, "Rupture", "Bleed finisher." },
        { 20, "Poisons", "Learn to make Instant and Crippling Poison." },
        { 22, "Vanish", "Disappear into stealth, even in combat." },
        { 22, "Distract", "Makes mobs look away." },
        { 24, "Shank", "Quick off-hand hit that gives energy back." },
        { 26, "Cheap Shot", "Stun from stealth." },
        { 30, "Kidney Shot", "Stun finisher." },
        { 34, "Blind", "Blinds a target for a long time." },
        { 40, "Safe Fall", "Take less fall damage." },
    },
    PRIEST = {
        -- Race-only priest spells (Divine Grace, Contingency Plan, Confounding
        -- Flash, Starshards ...) are left out: not every priest can train them.
        { 4, "Shadow Word: Pain", "Shadow damage over time." },
        { 6, "Power Word: Shield", "Absorbs damage." },
        { 8, "Renew", "Heal over time." },
        { 8, "Fade", "Lowers your threat for 10 sec." },
        { 10, "Mind Blast", "Big shadow damage." },
        { 10, "Resurrection", "Brings a dead player back to life." },
        { 12, "Inner Fire", "More armor." },
        { 14, "Psychic Scream", "Fears enemies around you." },
        { 14, "Cure Disease", "Removes a disease." },
        { 16, "Heal", "Bigger heal." },
        { 18, "Dispel Magic", "Removes magic from a friend or a buff from an enemy." },
        { 20, "Flash Heal", "Fast heal." },
        { 20, "Holy Fire", "Holy damage plus burn." },
        { 20, "Fear Ward", "Blocks the next fear." },
        { 20, "Shackle Undead", "Locks down one undead." },
        { 24, "Mana Burn", "Burns the target's mana." },
        { 30, "Mind Control", "Control a humanoid." },
        { 30, "Prayer of Healing", "Heals your whole group." },
        { 32, "Shadow Word: Death", "Shadow finisher - hurts you too if it doesn't kill." },
        { 32, "Abolish Disease", "Removes diseases over time." },
        { 34, "Levitate", "Float - also over water." },
        { 40, "Greater Heal", "Big, slow heal." },
    },
    SHAMAN = {
        { 4, "Earth Shock", "Instant damage that interrupts a spell." },
        { 4, "Stoneskin Totem", "Group takes less physical damage." },
        { 6, "Earthbind Totem", "Slows enemies around the totem." },
        { 8, "Lightning Shield", "Shocks enemies that hit you." },
        { 8, "Stoneclaw Totem", "Totem that draws attacks away from you." },
        { 10, "Flame Shock", "Fire damage plus burn." },
        { 10, "Searing Totem", "Totem that shoots fire at enemies." },
        { 10, "Flametongue Weapon", "Fire damage on your weapon hits." },
        { 10, "Strength of Earth Totem", "More Strength for the group." },
        { 12, "Purge", "Removes a magic buff from an enemy." },
        { 12, "Fire Nova", "Fire burst around your fire totem." },
        { 12, "Ancestral Spirit", "Brings a dead player back to life." },
        { 16, "Cure Poison", "Removes a poison." },
        { 18, "Tremor Totem", "Breaks fear, charm and sleep on the group." },
        { 20, "Ghost Wolf", "Run faster outdoors." },
        { 20, "Frost Shock", "Frost damage that slows." },
        { 20, "Lesser Healing Wave", "Fast heal." },
        { 20, "Healing Stream Totem", "Heals the group over time." },
        { 20, "Call of the Elements", "Drop up to 4 totems with one button." },
        { 20, "Totemic Recall", "Picks up your totems and gives some mana back." },
        { 20, "Frostbrand Weapon", "Frost damage and slow on your hits." },
        { 22, "Cure Disease", "Removes a disease." },
        { 26, "Magma Totem", "Fire damage to enemies around the totem." },
        { 26, "Mana Spring Totem", "Mana back for the group." },
        { 28, "Flametongue Totem", "Fire damage on the group's weapons." },
        { 30, "Windfury Weapon", "Chance for extra attacks." },
        { 30, "Reincarnation", "Come back to life where you died." },
        { 30, "Grounding Totem", "Eats an enemy spell." },
        { 30, "Astral Recall", "Teleport to your hearthstone location." },
        { 32, "Chain Lightning", "Lightning that jumps between enemies." },
        { 32, "Windfury Totem", "Extra attacks for the group's melee." },
        { 40, "Chain Heal", "Heal that jumps between friends." },
        { 42, "Grace of Air Totem", "More Agility for the group." },
    },
    MAGE = {
        { 4, "Frostbolt", "Frost damage that slows." },
        { 4, "Conjure Water", "Make your own water." },
        { 6, "Fire Blast", "Instant fire damage." },
        { 6, "Conjure Food", "Make your own food." },
        { 8, "Polymorph", "Turns an enemy into a sheep." },
        { 8, "Arcane Missiles", "Channelled arcane damage." },
        { 10, "Frost Nova", "Freezes enemies around you in place." },
        { 12, "Slow Fall", "Fall slowly." },
        { 14, "Arcane Explosion", "Damage to all enemies around you." },
        { 16, "Flamestrike", "Fire damage on an area." },
        { 18, "Remove Lesser Curse", "Removes a curse." },
        { 20, "Blink", "Teleport a short way forward; breaks stuns." },
        { 20, "Blizzard", "Frost damage on an area." },
        { 20, "Evocation", "Get lots of mana back." },
        { 20, "Mana Shield", "Damage drains mana instead of health." },
        { 22, "Scorch", "Quick fire damage." },
        { 24, "Counterspell", "Interrupts and locks a spell school." },
        { 26, "Cone of Cold", "Frost damage and slow in front of you." },
        { 28, "Conjure Mana Agate", "Gem that gives mana back." },
        { 30, "Ice Armor", "Better armor; slows attackers." },
        { 34, "Mage Armor", "More mana regeneration." },
        { 40, "Frostfire Bolt", "Frost and fire damage that slows." },
        { 56, "Arcane Brilliance", "Intellect for the whole group." },
    },
    WARLOCK = {
        { 4, "Corruption", "Shadow damage over time." },
        { 4, "Curse of Weakness", "The target hits softer." },
        { 6, "Life Tap", "Turns health into mana." },
        { 8, "Bane of Agony", "Shadow damage over time." },
        { 8, "Fear", "Makes one enemy run away in fear." },
        { 10, "Summon Voidwalker", "Your tank pet." },
        { 10, "Drain Soul", "Drain that gives a Soul Shard if the target dies." },
        { 10, "Create Healthstone", "Stone you can eat for a big heal." },
        { 12, "Health Funnel", "Heals your pet with your health." },
        { 14, "Drain Life", "Drains health from the target to you." },
        { 14, "Curse of Recklessness", "Lowers the target's armor." },
        { 16, "Unending Breath", "Breathe under water." },
        { 18, "Searing Pain", "Fast fire damage." },
        { 18, "Create Soulstone", "Lets you or a friend come back after dying." },
        { 20, "Summon Succubus", "Damage pet that can seduce humanoids." },
        { 20, "Rain of Fire", "Fire damage on an area." },
        { 20, "Demon Armor", "Better armor and health regeneration." },
        { 20, "Ritual of Summoning", "Summon a party member to you." },
        { 24, "Drain Mana", "Drains the target's mana." },
        { 26, "Curse of Tongues", "The target casts slower." },
        { 28, "Banish", "Locks down a demon or elemental." },
        { 30, "Summon Felhunter", "Pet that eats magic and interrupts casters." },
        { 30, "Hellfire", "Fire damage around you - hurts you too." },
        { 32, "Shadow Ward", "Absorbs shadow damage." },
        { 40, "Howl of Terror", "Fears enemies around you." },
        { 40, "Summon Felsteed", "Your own mount." },
        { 42, "Death Coil", "Fears the target and heals you." },
        { 48, "Soul Fire", "Huge fire damage, slow cast." },
        { 50, "Inferno", "Calls down an Infernal demon." },
        { 60, "Bane of Doom", "Big shadow damage after a long delay." },
        { 60, "Summon Dreadsteed", "Your epic mount." },
    },
    DRUID = {
        { 4, "Moonfire", "Instant damage plus damage over time." },
        { 4, "Rejuvenation", "Heal over time." },
        { 6, "Thorns", "Damages enemies that hit the target." },
        { 8, "Entangling Roots", "Roots the target in place." },
        { 10, "Bear Form", "Tank form: more armor and health." },
        { 10, "Growl", "Forces the target to attack you." },
        { 10, "Maul", "Bear: next hit deals extra damage." },
        { 10, "Demoralizing Roar", "Bear: enemies around you hit softer." },
        { 10, "Nature's Grasp", "Roots the next enemy that hits you." },
        { 10, "Teleport: Moonglade", "Teleport to Moonglade." },
        { 12, "Regrowth", "Heal plus heal over time." },
        { 12, "Enrage", "Bear: gain rage fast." },
        { 14, "Bash", "Bear: stuns the target." },
        { 14, "Cure Poison", "Removes a poison." },
        { 16, "Aquatic Form", "Swim fast and breathe under water." },
        { 16, "Swipe", "Bear: hits enemies around you." },
        { 18, "Faerie Fire", "Lowers the target's armor." },
        { 18, "Hibernate", "Puts a beast or dragon to sleep." },
        { 20, "Cat Form", "Fast melee form with combo points." },
        { 20, "Claw", "Cat: basic hit, gives a combo point." },
        { 20, "Prowl", "Cat: stealth." },
        { 20, "Rip", "Cat: bleed finisher." },
        { 20, "Shred", "Cat: big hit from behind." },
        { 20, "Starfire", "Big arcane damage, slow cast." },
        { 20, "Rebirth", "Brings a dead player back in combat." },
        { 24, "Rake", "Cat: bleed, gives a combo point." },
        { 24, "Ferocious Bite", "Cat: damage finisher." },
        { 24, "Remove Curse", "Removes a curse." },
        { 26, "Dash", "Cat: run much faster." },
        { 26, "Abolish Poison", "Removes poisons over time." },
        { 28, "Challenging Roar", "Bear: taunts all enemies around you." },
        { 28, "Cower", "Cat: lowers your threat." },
        { 30, "Travel Form", "Run faster outdoors." },
        { 30, "Tranquility", "Heals your whole group." },
        { 32, "Ravage", "Cat: huge hit from stealth." },
        { 32, "Poised", "Your next ability costs less." },
        { 36, "Pounce", "Cat: stun and bleed from stealth." },
        { 36, "Frenzied Regeneration", "Bear: turns rage into health." },
        { 40, "Dire Bear Form", "Stronger bear form." },
        { 40, "Hurricane", "Nature damage on an area." },
        { 40, "Innervate", "Lots of mana back for you or a healer." },
        { 44, "Barkskin", "Take less damage." },
        { 50, "Gift of the Wild", "Mark of the Wild for the whole group." },
    },
}

--------------------------------------------------------------------------------
-- Macros, keyed by class file name. Most come from the "Macros" sections of
-- the Mobalytics WoW Forever guides; a few are simple beginner helpers.
-- Each entry:
--   name   macro name in the game (max 16 characters)
--   spells the spells it needs (the first one gives the icon)
--   body   the macro text (max 255 characters)
--   about  one or two plain sentences about what it does
--   specs  (optional) only shown for these spec numbers (order in Data.lua)
--------------------------------------------------------------------------------
local SMART_HEAL_TARGET = "[@mouseover,help,nodead][help,nodead][@player]"

local function SmartHeal(macroName, spellName, specNumbers)
    return {
        name = macroName, spells = { spellName }, specs = specNumbers,
        body = "#showtooltip " .. spellName .. "\n/cast " .. SMART_HEAL_TARGET .. " " .. spellName,
        about = "Heals the friend under your mouse, else your friendly target, else yourself. No more clicking yourself first.",
    }
end

-- Casts a damage spell on the enemy under your mouse without changing target.
local function MouseoverDamage(macroName, spellName, specNumbers)
    return {
        name = macroName, spells = { spellName }, specs = specNumbers,
        body = "#showtooltip " .. spellName .. "\n/cast [@mouseover,harm,nodead][] " .. spellName,
        about = "Puts " .. spellName .. " on the enemy under your mouse without changing target - great for dotting several mobs.",
    }
end

local WAND_MACRO = {
    name = "Wand", spells = { "Shoot" },
    body = "#showtooltip Shoot\n/cast !Shoot",
    about = "Starts your wand. Pressing it again never turns it off by accident.",
}

local START_ATTACK_MACRO = {
    name = "Start Attack", spells = {}, icon = "Interface\\Icons\\Ability_MeleeDamage",
    body = "#showtooltip\n/startattack",
    about = "In Forever the attack button turns auto attack OFF if you press it twice. This one only turns it on.",
}

-- Pops racials and trinkets together with a class cooldown.
local function Cooldowns(macroName, spellName, specNumbers)
    return {
        name = macroName, spells = { spellName }, specs = specNumbers,
        body = "#showtooltip " .. spellName .. "\n/cast " .. spellName
            .. "\n/cast Blood Fury\n/cast Berserking\n/cast Elune's Light\n/use 13\n/use 14",
        about = spellName .. " together with your damage racial and both trinkets in one press.",
    }
end

Mentor.MACROS = {
    WARRIOR = {
        {
            name = "Charge", spells = { "Charge", "Intercept" },
            body = "#showtooltip\n/startattack\n/cast [stance:3] Intercept; Charge",
            about = "One button to rush in: Intercept in Berserker Stance, Charge otherwise. Also turns on auto attack.",
        },
        {
            name = "Interrupt", spells = { "Pummel", "Shield Bash" },
            body = "#showtooltip\n/cast [stance:3] Pummel; Shield Bash",
            about = "Stops a caster: Pummel in Berserker Stance, Shield Bash otherwise.",
        },
        {
            name = "Heroic Strike", spells = { "Heroic Strike" },
            body = "#showtooltip Heroic Strike\n/startattack\n/cast Heroic Strike",
            about = "Heroic Strike that also turns on auto attack, so you never stand there doing nothing.",
        },
        {
            name = "Scare & Bandage", spells = { "Intimidating Shout" },
            body = "#showtooltip Intimidating Shout\n/cast Intimidating Shout\n/stopattack",
            about = "Fears the pack and stops your attacks so you don't break it - then bandage. The guide's lifesaver.",
        },
        Cooldowns("Burst", "Death Wish", { 2 }),
        Cooldowns("Burst", "Recklessness", { 1 }),
    },
    PALADIN = {
        SmartHeal("Smart Holy Light", "Holy Light"),
        SmartHeal("Smart Flash", "Flash of Light"),
        {
            name = "Judge", spells = { "Judgement" },
            body = "#showtooltip Judgement\n/startattack\n/cast Judgement",
            about = "Judgement that also turns on auto attack.",
        },
        {
            name = "Threat Opener", spells = { "Swift Judgement", "Judgement", "Holy Strike" }, specs = { 2 },
            body = "#showtooltip Swift Judgement\n/startattack\n/cast Judgement\n/cast Swift Judgement\n/cast Holy Strike",
            about = "Judgement, Swift Judgement and Holy Strike in one press - big threat right at the start.",
        },
        {
            name = "Bubble", spells = { "Divine Shield" },
            body = "#showtooltip Divine Shield\n/cancelaura Divine Shield\n/cast Divine Shield",
            about = "Press once to bubble, press again to cancel it early.",
        },
        {
            name = "BoP Target's Tgt", spells = { "Blessing of Protection" },
            body = "#showtooltip\n/cast [@targettarget,help] Blessing of Protection",
            about = "Blessing of Protection on whoever your target is attacking - save a friend without retargeting.",
        },
    },
    HUNTER = {
        {
            name = "Pet Control", spells = { "Call Pet", "Revive Pet", "Mend Pet" },
            body = "#showtooltip\n/cast [@pet,dead] Revive Pet; [nopet] Call Pet; Mend Pet",
            about = "One button for your pet: calls it if it is gone, revives it if it is dead, heals it otherwise.",
        },
        {
            name = "Mark and Send", spells = { "Hunter's Mark" },
            body = "#showtooltip Hunter's Mark\n/cast Hunter's Mark\n/petattack",
            about = "Marks your target and sends your pet in. Your opener for every fight.",
        },
        {
            name = "Auto Shot", spells = { "Auto Shot" },
            body = "#showtooltip Auto Shot\n/cast !Auto Shot",
            about = "Starts shooting. Pressing it again never stops Auto Shot by accident.",
        },
        {
            name = "Feign Death", spells = { "Feign Death" },
            body = "#showtooltip Feign Death\n/stopcasting\n/cast Feign Death",
            about = "Stops whatever you are casting so Feign Death always goes off - even mid Aimed Shot.",
        },
        {
            name = "Cheetah Off", spells = { "Aspect of the Cheetah" },
            body = "#showtooltip Aspect of the Cheetah\n/cancelaura Aspect of the Cheetah",
            about = "Takes Cheetah off without a global cooldown - for kiting: Cheetah on, gain distance, off, shoot.",
        },
        Cooldowns("Burst", "Rapid Fire"),
        {
            name = "Flare", spells = { "Flare" },
            body = "#showtooltip Flare\n/cast !Flare",
            about = "Spam it without the targeting circle disappearing.",
        },
    },
    ROGUE = {
        {
            name = "Attack", spells = { "Sinister Strike", "Riposte" },
            body = "#showtooltip Sinister Strike\n/startattack\n/cast Riposte\n/cast Sinister Strike",
            about = "From the guide: always starts auto attack, uses Riposte when it lights up, otherwise Sinister Strike.",
        },
        {
            name = "Opener", spells = { "Cheap Shot", "Sinister Strike" },
            body = "#showtooltip\n/startattack\n/cast [stealth] Cheap Shot; Sinister Strike",
            about = "Cheap Shot from stealth, Sinister Strike otherwise - one button for the start of a fight.",
        },
        {
            name = "Dagger Opener", spells = { "Ambush", "Backstab" }, specs = { 1, 3 },
            body = "#showtooltip\n/startattack\n/cast [stealth] Ambush; Backstab",
            about = "For daggers: Ambush from stealth, Backstab after.",
        },
        {
            name = "Safe Stealth", spells = { "Stealth" },
            body = "#showtooltip Stealth\n/cast !Stealth",
            about = "Goes into stealth, but never takes you out of it by pressing twice.",
        },
        {
            name = "MH Poison", spells = { "Poisons" },
            body = "#show 16\n/use Instant Poison\n/use 16\n/click StaticPopup1Button1",
            about = "Puts your best Instant Poison on your main-hand weapon in one press.",
        },
        {
            name = "OH Poison", spells = { "Poisons" },
            body = "#show 17\n/use Instant Poison\n/use 17\n/click StaticPopup1Button1",
            about = "Same for your off-hand weapon.",
        },
        Cooldowns("Burst", "Adrenaline Rush", { 2 }),
    },
    PRIEST = {
        {
            name = "Smart Shield", spells = { "Power Word: Shield" },
            body = "#showtooltip Power Word: Shield\n/cast " .. SMART_HEAL_TARGET .. " Power Word: Shield",
            about = "Shields the friend under your mouse, else your friendly target, else yourself.",
        },
        SmartHeal("Smart Renew", "Renew"),
        SmartHeal("Smart Flash Heal", "Flash Heal"),
        WAND_MACRO,
        {
            name = "Safe Mind Blast", spells = { "Mind Blast" }, specs = { 3 },
            body = "#showtooltip Mind Blast\n/cast [nochanneling:Mind Flay] Mind Blast",
            about = "Never cuts Mind Flay short - its last tick hits hardest with Improved Mind Flay.",
        },
        {
            name = "Safe Mind Flay", spells = { "Mind Flay" }, specs = { 3 },
            body = "#showtooltip Mind Flay\n/cast [nochanneling:Mind Flay] Mind Flay",
            about = "Spam it without restarting the channel.",
        },
        MouseoverDamage("Mouseover Pain", "Shadow Word: Pain", { 3 }),
    },
    SHAMAN = {
        START_ATTACK_MACRO,
        SmartHeal("Smart Heal", "Healing Wave"),
        SmartHeal("Smart Lesser", "Lesser Healing Wave"),
        SmartHeal("Smart Chain Heal", "Chain Heal", { 3 }),
        {
            name = "Interrupt", spells = { "Earth Shock" },
            body = "#showtooltip Earth Shock\n/stopcasting\n/cast Earth Shock(Rank 1)",
            about = "Stops your cast and interrupts with rank 1 Earth Shock - cheap on mana.",
        },
    },
    MAGE = {
        WAND_MACRO,
        {
            name = "Ice Block", spells = { "Ice Block" },
            body = "#showtooltip Ice Block\n/cancelaura Ice Block\n/cast Ice Block",
            about = "Press once to block, press again to leave Ice Block early.",
        },
        {
            name = "Sheep Focus", spells = { "Polymorph" },
            body = "#showtooltip Polymorph\n/cast [@focus,harm,nodead][] Polymorph",
            about = "Type /focus on a second mob first. Then this sheeps it while you keep fighting your target.",
        },
        {
            name = "Counterspell", spells = { "Counterspell" },
            body = "#showtooltip Counterspell\n/stopcasting\n/cast Counterspell",
            about = "Stops your own cast and counters the enemy's spell right away.",
        },
        Cooldowns("Burst", "Arcane Power", { 1 }),
        Cooldowns("Burst", "Combustion", { 2 }),
    },
    WARLOCK = {
        WAND_MACRO,
        {
            name = "Brand + Pet", spells = { "Searing Pain" }, specs = { 2 },
            body = "#showtooltip Searing Pain\n/petattack\n/cast Searing Pain",
            about = "The guide calls this mandatory: your demon always attacks the target with Demonic Brand.",
        },
        {
            name = "Dot and Pet", spells = { "Corruption" },
            body = "#showtooltip Corruption\n/petattack\n/cast Corruption",
            about = "Sends your pet in and puts Corruption on the target. Your opener for every fight.",
        },
        MouseoverDamage("Mouseover Dot", "Corruption"),
        MouseoverDamage("Mouseover Agony", "Bane of Agony"),
        {
            name = "Summon Demon", spells = { "Summon Succubus", "Summon Imp", "Summon Voidwalker", "Summon Felhunter" },
            body = "#showtooltip\n/cast [mod:alt] Summon Imp; [mod:shift] Summon Voidwalker; [mod:ctrl] Summon Felhunter; Summon Succubus",
            about = "All demons on one button: plain = Succubus, Alt = Imp, Shift = Voidwalker, Ctrl = Felhunter.",
        },
        {
            name = "Fear Focus", spells = { "Fear" },
            body = "#showtooltip Fear\n/cast [@focus,harm,nodead][] Fear",
            about = "Type /focus on a second mob first. Then this fears it while you keep fighting your target.",
        },
    },
    DRUID = {
        SmartHeal("Smart Rejuv", "Rejuvenation"),
        SmartHeal("Smart Regrowth", "Regrowth"),
        SmartHeal("Smart Heal", "Healing Touch"),
        {
            name = "Form Heal", spells = { "Regrowth" },
            body = "#showtooltip Regrowth\n/cancelform\n/cast [@player] Regrowth",
            about = "In Bear or Cat Form: leaves the form and heals yourself in one press.",
        },
        {
            name = "Cat Opener", spells = { "Ravage", "Shred" }, specs = { 2 },
            body = "#showtooltip\n/cast [stealth] Ravage; Shred",
            about = "From Prowl: Ravage. Otherwise Shred. Your opener from behind.",
        },
        MouseoverDamage("Mouseover Moonfire", "Moonfire", { 1, 3 }),
    },
}

--------------------------------------------------------------------------------
-- Mentor - Journey.lua
-- "Where next?" data and logic for the Journey tab (ExtrasUI.lua) and the
-- dungeon tip when you enter a dungeon:
--   * zones that fit your level and faction
--   * dungeons that fit your level, with a short tip
--   * professions that suit your class, and when your profession needs a trainer
-- The level ranges are the classic ones; WoW Forever follows the classic world.
--------------------------------------------------------------------------------

local _, Mentor = ...

local ZONE_ICON = "Interface\\Icons\\INV_Misc_Map_01"
local DUNGEON_ICON = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"
local LEVELS_BELOW_RANGE_SHOWN = 2       -- a zone appears 2 levels before its range starts
local MAX_ZONES_SHOWN = 4
local MAX_DUNGEONS_SHOWN = 4

local journey = {}
Mentor.Journey = journey

--------------------------------------------------------------------------------
-- Zones: { name, lowest level, highest level, faction ("Alliance", "Horde" or nil = both), tip }
--------------------------------------------------------------------------------
local ZONES = {
    { "Elwynn Forest", 1, 10, "Alliance", "Human start. Quests around Goldshire, then Westfall or Loch Modan." },
    { "Dun Morogh", 1, 10, "Alliance", "Dwarf and gnome start. Kharanos is the main town." },
    { "Teldrassil", 1, 10, "Alliance", "Night elf start. Take the boat from Rut'theran to Darkshore after." },
    { "Durotar", 1, 10, "Horde", "Orc and troll start. Razor Hill, then The Barrens." },
    { "Mulgore", 1, 10, "Horde", "Tauren start. Bloodhoof Village, then Thunder Bluff and The Barrens." },
    { "Tirisfal Glades", 1, 10, "Horde", "Undead start. Brill, then Silverpine Forest." },
    { "Westfall", 10, 20, "Alliance", "Sentinel Hill. Ends with the Deadmines dungeon." },
    { "Loch Modan", 10, 20, "Alliance", "Thelsamar. Calm zone with lots of quests." },
    { "Darkshore", 10, 20, "Alliance", "Auberdine. Long zone along the coast." },
    { "The Barrens", 10, 25, "Horde", "Crossroads. Huge zone; Wailing Caverns is here." },
    { "Silverpine Forest", 10, 20, "Horde", "The Sepulcher. Leads to Shadowfang Keep." },
    { "Redridge Mountains", 15, 25, "Alliance", "Lakeshire. Good next to Westfall." },
    { "Stonetalon Mountains", 15, 27, nil, "Both factions have quests here." },
    { "Ashenvale", 18, 30, nil, "Big forest, quests for both factions. Blackfathom Deeps is here." },
    { "Duskwood", 18, 30, "Alliance", "Darkshire. Dangerous elites at night - group up." },
    { "Wetlands", 20, 30, "Alliance", "Menethil Harbor. Boats to Darkshore and Theramore." },
    { "Hillsbrad Foothills", 20, 30, nil, "Southshore (Alliance) and Tarren Mill (Horde)." },
    { "Thousand Needles", 25, 35, "Horde", "Freewind Post. Razorfen Downs is at the edge." },
    { "Arathi Highlands", 30, 40, nil, "Refuge Pointe (Alliance) and Hammerfall (Horde)." },
    { "Desolace", 30, 40, nil, "Centaur factions and Maraudon." },
    { "Stranglethorn Vale", 30, 45, nil, "Booty Bay. Lots of quests; watch out for players." },
    { "Alterac Mountains", 30, 40, nil, "Small zone north of Hillsbrad." },
    { "Dustwallow Marsh", 35, 45, nil, "Theramore (Alliance) and Brackenwall Village (Horde)." },
    { "Badlands", 35, 45, nil, "Kargath (Horde). Uldaman is here." },
    { "Swamp of Sorrows", 35, 45, nil, "Stonard (Horde). Leads to the Sunken Temple." },
    { "Tanaris", 40, 50, nil, "Gadgetzan. Zul'Farrak is here." },
    { "Feralas", 40, 50, nil, "Feathermoon (Alliance) and Camp Mojache (Horde). Dire Maul is here." },
    { "The Hinterlands", 40, 50, nil, "Aerie Peak (Alliance) and Revantusk Village (Horde)." },
    { "Searing Gorge", 43, 50, nil, "Thorium Point. Gate to Blackrock Mountain." },
    { "Azshara", 45, 55, nil, "Quiet zone with few quests." },
    { "Blasted Lands", 45, 55, nil, "Nethergarde Keep. Short zone." },
    { "Felwood", 48, 55, nil, "Bloodvenom Post and Talonbranch Glade." },
    { "Un'Goro Crater", 48, 55, nil, "Marshal's Refuge. Great quests for both factions." },
    { "Burning Steppes", 50, 58, nil, "Morgan's Vigil (Alliance) and Flame Crest (Horde)." },
    { "Western Plaguelands", 51, 58, nil, "Chillwind Camp (Alliance) and the Bulwark (Horde)." },
    { "Eastern Plaguelands", 53, 60, nil, "Light's Hope Chapel. Stratholme is here." },
    { "Winterspring", 55, 60, nil, "Everlook. Good place to finish leveling." },
    { "Silithus", 55, 60, nil, "Cenarion Hold." },
}

--------------------------------------------------------------------------------
-- Dungeons: { name, lowest level, highest level, faction or nil, where, tip }
-- The name must match the instance name (GetInstanceInfo) for the tip on entry.
--------------------------------------------------------------------------------
local DUNGEONS = {
    { "Ragefire Chasm", 13, 18, "Horde", "Orgrimmar (Cleft of Shadow)", "Short and easy - a good first dungeon." },
    { "Wailing Caverns", 17, 24, nil, "The Barrens", "Easy to get lost. Follow the druid at the end to finish." },
    { "The Deadmines", 17, 26, "Alliance", "Westfall (Moonbrook)", "Long. Mr. Smite stuns everyone - kill his adds first." },
    { "Shadowfang Keep", 22, 30, nil, "Silverpine Forest", "Arugal teleports around - stay together." },
    { "Blackfathom Deeps", 24, 32, nil, "Ashenvale (coast)", "Lots of swimming. Murlocs flee and pull more - kill them fast." },
    { "The Stockade", 24, 32, "Alliance", "Stormwind", "Short and packed. Good fast experience." },
    { "Gnomeregan", 29, 38, nil, "Dun Morogh", "Long, with radiation and bombs. Bring a good tank." },
    { "Razorfen Kraul", 29, 38, nil, "The Barrens (south)", "Quilboar and thorny vines. Watch out for their healers." },
    { "Scarlet Monastery", 26, 45, nil, "Tirisfal Glades", "Four wings: Graveyard (26+), Library (29+), Armory (32+) and Cathedral (35+)." },
    { "Razorfen Downs", 37, 46, nil, "The Barrens / Thousand Needles", "Undead quilboar. One big escort event in the middle." },
    { "Uldaman", 41, 51, nil, "Badlands", "Stone keepers wake in a big room - be ready." },
    { "Zul'Farrak", 42, 46, nil, "Tanaris", "The stair event is hard: stand at the top and let the tank hold." },
    { "Maraudon", 46, 55, nil, "Desolace", "Big and pretty. Princess Theradras is the final boss." },
    { "The Temple of Atal'Hakkar", 50, 56, nil, "Swamp of Sorrows", "Sunken Temple: many dragons; kill the trolls on the balconies first." },
    { "Blackrock Depths", 52, 60, nil, "Blackrock Mountain", "Huge. Pick a few bosses per run." },
    { "Lower Blackrock Spire", 55, 60, nil, "Blackrock Mountain", "Long with big packs. Crowd control helps." },
    { "Dire Maul", 55, 60, nil, "Feralas", "Three wings: East, West and North." },
    { "Scholomance", 58, 60, nil, "Western Plaguelands", "Needs a key quest. Lots of undead casters." },
    { "Stratholme", 58, 60, nil, "Eastern Plaguelands", "Two halves: Live (Scarlet side) and Undead." },
    { "Upper Blackrock Spire", 58, 60, nil, "Blackrock Mountain", "Ten players. Needs the Seal of Ascension key." },
}

-- What to do in a dungeon for each role (from your spec in Data.lua).
local ROLE_TIPS = {
    ["Tank"] = "You lead: mark targets, pull one pack at a time and keep threat on everything.",
    ["Healer"] = "Keep the tank alive first, watch your mana and ask for a break when you need to drink.",
    ["Melee damage"] = "Attack the tank's target from behind, and stop if a mob turns to you.",
    ["Melee damage / tank"] = "In bear form you can tank; in cat form attack the tank's target from behind.",
    ["Ranged damage"] = "Attack the tank's target after a few seconds so the tank keeps threat.",
    ["Caster damage"] = "Attack the tank's target after a few seconds so the tank keeps threat.",
}

--------------------------------------------------------------------------------
-- Professions
--------------------------------------------------------------------------------
local PROFESSION_ICONS = {
    Tailoring = "Interface\\Icons\\Trade_Tailoring", Enchanting = "Interface\\Icons\\Trade_Engraving",
    Alchemy = "Interface\\Icons\\Trade_Alchemy", Herbalism = "Interface\\Icons\\Trade_Herbalism",
    Blacksmithing = "Interface\\Icons\\Trade_BlackSmithing", Mining = "Interface\\Icons\\Trade_Mining",
    Engineering = "Interface\\Icons\\Trade_Engineering", Leatherworking = "Interface\\Icons\\Trade_LeatherWorking",
    Skinning = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", ["First Aid"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    Cooking = "Interface\\Icons\\INV_Misc_Food_15", Fishing = "Interface\\Icons\\Trade_Fishing",
}

-- Two good choices per class: { "First + Second", why }.
local PROFESSION_ADVICE = {
    WARRIOR = { { "Mining + Blacksmithing", "Make your own weapons and armor." },
                { "Mining + Engineering", "Bombs, a scope and fun gadgets - great for PvP." } },
    PALADIN = { { "Mining + Blacksmithing", "Make your own plate and weapons." },
                { "Herbalism + Alchemy", "Your own potions and elixirs." } },
    HUNTER  = { { "Mining + Engineering", "Make your own guns, scopes and ammo." },
                { "Skinning + Leatherworking", "Make your own mail and leather armor." } },
    ROGUE   = { { "Skinning + Leatherworking", "Make your own leather armor." },
                { "Mining + Engineering", "Bombs and gadgets - great for PvP." } },
    PRIEST  = { { "Tailoring + Enchanting", "Make your own cloth gear and enchant it." },
                { "Herbalism + Alchemy", "Mana potions keep you going." } },
    SHAMAN  = { { "Skinning + Leatherworking", "Make your own leather and mail." },
                { "Herbalism + Alchemy", "Potions and elixirs for every spec." } },
    MAGE    = { { "Tailoring + Enchanting", "Make your own cloth gear and enchant it." },
                { "Herbalism + Alchemy", "Mana potions and elixirs." } },
    WARLOCK = { { "Tailoring + Enchanting", "Make your own cloth gear and enchant it." },
                { "Herbalism + Alchemy", "Potions and elixirs." } },
    DRUID   = { { "Skinning + Leatherworking", "Make your own leather armor." },
                { "Herbalism + Alchemy", "You can pick herbs in Travel Form." } },
}
local ALWAYS_USEFUL_ADVICE = { "First Aid + Cooking + Fishing",
    "Free to learn next to your two main professions: bandages, food and fish. Everyone should take First Aid." }

-- Skill caps and the level needed to learn the next rank at a trainer.
local PROFESSION_RANKS = {
    { cap = 75, nextRank = "Journeyman", requiredLevel = 10 },
    { cap = 150, nextRank = "Expert", requiredLevel = 20 },
    { cap = 225, nextRank = "Artisan", requiredLevel = 35 },
}

-- { name, skill, maximum } for each profession you have.
function journey.GetPlayerProfessions()
    local professions = {}
    if not (GetProfessions and GetProfessionInfo) then
        return professions
    end
    for _, professionIndex in pairs({ GetProfessions() }) do
        local success, professionName, _, skillLevel, maximumSkill = pcall(GetProfessionInfo, professionIndex)
        if success and professionName and skillLevel and maximumSkill then
            table.insert(professions, { name = professionName, skill = skillLevel, maximum = maximumSkill })
        end
    end
    return professions
end

-- "Visit a trainer" text when a profession is at its cap and you can learn
-- the next rank, otherwise nil.
function journey.GetProfessionTrainerHint(profession, playerLevel)
    for _, rank in ipairs(PROFESSION_RANKS) do
        if profession.maximum == rank.cap and profession.skill >= rank.cap - 5 then
            if playerLevel >= rank.requiredLevel then
                return string.format("Visit a %s trainer to learn %s - your skill is stuck at %d.", profession.name, rank.nextRank, rank.cap)
            end
            return string.format("%s needs level %d for %s (skill stuck at %d).", rank.nextRank, rank.requiredLevel, profession.name, rank.cap)
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Entries for the Journey tab
--------------------------------------------------------------------------------
local function FitsFaction(entryFaction, playerFaction)
    return entryFaction == nil or entryFaction == playerFaction
end

-- Rows in the format ExtrasUI uses: { name, icon, levelText, tag, description, kind }.
function journey.GetEntries(advice)
    local playerLevel = advice.level or UnitLevel("player") or 1
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
    local entries = {}

    -- Professions that need a trainer come first.
    for _, profession in ipairs(journey.GetPlayerProfessions()) do
        local trainerHint = journey.GetProfessionTrainerHint(profession, playerLevel)
        if trainerHint then
            table.insert(entries, { kind = "journey", name = profession.name .. " " .. profession.skill .. "/" .. profession.maximum,
                icon = PROFESSION_ICONS[profession.name], levelText = "", tag = "|cffff9933Trainer|r", description = trainerHint })
        end
    end

    local shownZones = 0
    for _, zone in ipairs(ZONES) do
        local zoneName, lowestLevel, highestLevel, zoneFaction, zoneTip = zone[1], zone[2], zone[3], zone[4], zone[5]
        if shownZones < MAX_ZONES_SHOWN and FitsFaction(zoneFaction, playerFaction)
            and playerLevel >= lowestLevel - LEVELS_BELOW_RANGE_SHOWN and playerLevel <= highestLevel then
            shownZones = shownZones + 1
            table.insert(entries, { kind = "journey", name = zoneName, icon = ZONE_ICON,
                levelText = lowestLevel .. "-" .. highestLevel, tag = "|cff66ccffZone|r", description = zoneTip })
        end
    end

    local shownDungeons = 0
    for _, dungeon in ipairs(DUNGEONS) do
        local dungeonName, lowestLevel, highestLevel, dungeonFaction, location, dungeonTip =
            dungeon[1], dungeon[2], dungeon[3], dungeon[4], dungeon[5], dungeon[6]
        if shownDungeons < MAX_DUNGEONS_SHOWN and FitsFaction(dungeonFaction, playerFaction)
            and playerLevel >= lowestLevel - LEVELS_BELOW_RANGE_SHOWN and playerLevel <= highestLevel then
            shownDungeons = shownDungeons + 1
            table.insert(entries, { kind = "journey", name = dungeonName, icon = DUNGEON_ICON,
                levelText = lowestLevel .. "-" .. highestLevel, tag = "|cffff6666Dungeon|r",
                description = location .. ". " .. dungeonTip })
        end
    end

    -- Profession advice: what you have, otherwise two suggestions for your class.
    local playerProfessions = journey.GetPlayerProfessions()
    local mainProfessionCount = 0
    for _, profession in ipairs(playerProfessions) do
        if profession.name ~= "First Aid" and profession.name ~= "Cooking" and profession.name ~= "Fishing" then
            mainProfessionCount = mainProfessionCount + 1
        end
    end
    if mainProfessionCount < 2 then
        for _, professionAdvice in ipairs(PROFESSION_ADVICE[advice.classFileName] or {}) do
            local firstProfession = professionAdvice[1]:match("^(.-) %+")
            table.insert(entries, { kind = "journey", name = professionAdvice[1], icon = PROFESSION_ICONS[firstProfession],
                levelText = "", tag = "|cffffd100Profession|r", description = professionAdvice[2] })
        end
    end
    table.insert(entries, { kind = "journey", name = ALWAYS_USEFUL_ADVICE[1], icon = PROFESSION_ICONS["First Aid"],
        levelText = "", tag = "|cffffd100Profession|r", description = ALWAYS_USEFUL_ADVICE[2] })
    return entries
end

--------------------------------------------------------------------------------
-- Tip when you enter a dungeon (setting "Dungeon tips", on by default)
--------------------------------------------------------------------------------
local lastDungeonTipName
function journey.ShowDungeonTip()
    if not (MentorDB and MentorDB.areDungeonTipsEnabled ~= false) or not GetInstanceInfo then
        return
    end
    local instanceName, instanceType = GetInstanceInfo()
    if instanceType ~= "party" or not instanceName or instanceName == lastDungeonTipName then
        if instanceType ~= "party" then
            lastDungeonTipName = nil
        end
        return
    end
    for _, dungeon in ipairs(DUNGEONS) do
        if instanceName:find(dungeon[1], 1, true) or dungeon[1]:find(instanceName, 1, true) then
            lastDungeonTipName = instanceName
            Mentor.Print(string.format("|cffff6666%s|r (level %d-%d): %s", dungeon[1], dungeon[2], dungeon[3], dungeon[6]))
            local advice = Mentor.currentAdvice
            local roleTip = advice and advice.specData and ROLE_TIPS[advice.specData.role]
            if roleTip then
                Mentor.Print("As " .. advice.specData.name .. ": " .. roleTip)
            end
            return
        end
    end
end

local eventFrame = CreateFrame("Frame")
for _, eventName in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end
eventFrame:SetScript("OnEvent", function()
    if C_Timer then
        C_Timer.After(2, function() pcall(journey.ShowDungeonTip) end)
    end
end)

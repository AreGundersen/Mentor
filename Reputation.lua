--------------------------------------------------------------------------------
-- Mentor - Reputation.lua
-- The "Reputation" tab: the factions you know, how far you are, what each
-- faction gives you, and - from the new WoW Forever quartermasters
-- (ReputationGear.lua) - which of their gear is an upgrade for you and what
-- standing it needs. Factions with gear for you come first.
--
-- The benefits are the original WoW ones; Forever can have changed details.
--------------------------------------------------------------------------------

local _, Mentor = ...

local reputation = {}
Mentor.Reputation = reputation

local STANDING_NAMES = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
local EXALTED_STANDING = 8
local REPUTATION_ICON = 236681          -- a banner
local LEVELS_ABOVE_FOR_GEAR = 5         -- gear goals a few levels ahead
local LEVELS_BELOW_FOR_GEAR = 10

local CITY_BENEFIT = "Its vendors and trainers get cheaper as your reputation rises (10% from Honored). "
    .. "Exalted lets you buy its race's mount even if you are another race."
local GOBLIN_TOWN_BENEFIT = "A goblin town: its guards protect you. Booty Bay, Gadgetzan, Ratchet and Everlook "
    .. "share reputation - gaining with one gives some with the others."

-- What each faction gives you, by faction id.
local FACTION_BENEFITS = {
    [72] = CITY_BENEFIT, [47] = CITY_BENEFIT, [69] = CITY_BENEFIT, [54] = CITY_BENEFIT,       -- Alliance cities
    [76] = CITY_BENEFIT, [81] = CITY_BENEFIT, [68] = CITY_BENEFIT, [530] = CITY_BENEFIT,     -- Horde cities
    [21] = GOBLIN_TOWN_BENEFIT, [369] = GOBLIN_TOWN_BENEFIT, [470] = GOBLIN_TOWN_BENEFIT, [577] = GOBLIN_TOWN_BENEFIT,
    [576] = "Timbermaw Hold (Felwood, Winterspring): from Neutral its furbolgs stop attacking you and you can use "
        .. "their tunnel between the zones. Kill Deadwood and Winterfall furbolgs to raise it; recipes and gear later.",
    [609] = "Cenarion Circle (Silithus, Moonglade): quests and gear in Silithus, and leatherworking, tailoring and "
        .. "blacksmithing recipes.",
    [529] = "Argent Dawn (Plaguelands): wear the Argent Dawn Commission trinket to earn Scourgestones from undead, "
        .. "hand them in for reputation; gear, consumables and recipes.",
    [59] = "Thorium Brotherhood (Blackrock Depths' city): blacksmithing, leatherworking and tailoring recipes "
        .. "for fire-resistance gear.",
    [589] = "Wintersaber Trainers (Winterspring, Alliance): Exalted gives the Winterspring Frostsaber mount.",
    [749] = "Hydraxian Waterlords (Azshara): for the Molten Core raid - douse the runes there.",
    [349] = "Ravenholdt (Alterac Mountains): rogue-friendly faction; quests at Ravenholdt Manor.",
    [87] = "Bloodsail Buccaneers: raising it lowers Booty Bay and the other goblin towns - usually not worth it.",
    [909] = "Darkmoon Faire: turn in Darkmoon Faire decks and crafted goods for tickets and prizes.",
}

local function IsReadable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- Every faction you have met: { factionId, name, standing, current, maximum }
-- (current / maximum: progress inside the standing).
function reputation.GetKnownFactions()
    local factions = {}
    if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
        for factionIndex = 1, C_Reputation.GetNumFactions() or 0 do
            local isSuccess, factionData = pcall(C_Reputation.GetFactionDataByIndex, factionIndex)
            if isSuccess and type(factionData) == "table" and factionData.factionID and IsReadable(factionData.name)
                and (not factionData.isHeader or factionData.isHeaderWithRep) then
                local barMinimum = factionData.currentReactionThreshold or 0
                table.insert(factions, {
                    factionId = factionData.factionID, name = factionData.name, standing = factionData.reaction or 4,
                    current = (factionData.currentStanding or 0) - barMinimum,
                    maximum = (factionData.nextReactionThreshold or 0) - barMinimum,
                })
            end
        end
    elseif GetNumFactions and GetFactionInfo then
        for factionIndex = 1, GetNumFactions() or 0 do
            local factionName, _, standingId, barMinimum, barMaximum, barValue, _, _, isHeader, _, hasRep, _, _, factionId =
                GetFactionInfo(factionIndex)
            if factionName and factionId and (not isHeader or hasRep) then
                table.insert(factions, { factionId = factionId, name = factionName, standing = standingId or 4,
                    current = (barValue or 0) - (barMinimum or 0), maximum = (barMaximum or 0) - (barMinimum or 0) })
            end
        end
    end
    return factions
end

-- Quartermaster gear that is an upgrade for you, by faction id:
-- { [factionId] = { { itemLink, gain, standingNeeded, vendor }, ... } } best first.
function reputation.GetGearGoals()
    local goalsByFaction = {}
    local advice = Mentor.currentAdvice
    local weights = advice and advice.specData and advice.specData.weights
    if not (weights and Mentor.CompareItem and Mentor.REPUTATION_GEAR and Mentor.REPUTATION_VENDORS) then
        return goalsByFaction
    end
    local playerLevel = UnitLevel("player") or 1
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
    local factionLetter = playerFaction == "Alliance" and "A" or playerFaction == "Horde" and "H" or nil
    local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    for itemId, gearEntry in pairs(Mentor.REPUTATION_GEAR) do
        local vendor = Mentor.REPUTATION_VENDORS[gearEntry[1]]
        local requiredLevel = gearEntry[2]
        if vendor and factionLetter and vendor[4]:find(factionLetter, 1, true)
            and requiredLevel <= playerLevel + LEVELS_ABOVE_FOR_GEAR and requiredLevel >= playerLevel - LEVELS_BELOW_FOR_GEAR then
            local isSuccess, _, itemLink = pcall(getItemInfo, itemId)
            if isSuccess and itemLink then
                local compareSuccess, result = pcall(Mentor.CompareItem, itemLink, weights)
                if compareSuccess and result and (result.kind == "upgrade" or result.kind == "empty") then
                    local factionId = vendor[2]
                    goalsByFaction[factionId] = goalsByFaction[factionId] or {}
                    table.insert(goalsByFaction[factionId], { itemLink = itemLink, standingNeeded = gearEntry[3], vendor = vendor,
                        gain = result.kind == "empty" and 100 or (result.overallPercent or result.percent or 0) })
                end
            elseif C_Item and C_Item.RequestLoadItemDataByID then
                pcall(C_Item.RequestLoadItemDataByID, itemId)
            end
        end
    end
    for _, goals in pairs(goalsByFaction) do
        table.sort(goals, function(first, second) return first.gain > second.gain end)
    end
    return goalsByFaction
end

local function FormatGearGoal(goal, playerStanding)
    local standingName = STANDING_NAMES[goal.standingNeeded] or "?"
    local readyText = playerStanding >= goal.standingNeeded and "|cff40ff40you can buy it now|r"
        or ("at " .. standingName)
    return string.format("%s |cff40ff40+%.0f%%|r - %s", goal.itemLink, goal.gain, readyText)
end

-- Rows in the format ExtrasUI uses (kind "journey": level column = standing).
function reputation.GetEntries()
    local goalsByFaction = reputation.GetGearGoals()
    local entries = {}
    local shownFactionIds = {}
    for _, faction in ipairs(reputation.GetKnownFactions()) do
        local goals = goalsByFaction[faction.factionId]
        local benefitText = FACTION_BENEFITS[faction.factionId]
        if goals or benefitText then
            shownFactionIds[faction.factionId] = true
            local descriptionParts = {}
            if goals then
                table.insert(descriptionParts, "Gear for you: " .. FormatGearGoal(goals[1], faction.standing)
                    .. (#goals > 1 and string.format(" (+%d more)", #goals - 1) or "") .. ".")
            end
            if benefitText then
                table.insert(descriptionParts, benefitText)
            end
            local progressText = ""
            if faction.standing < EXALTED_STANDING and faction.maximum > 0 then
                progressText = string.format(" |cffa6a6a6%d/%d to %s|r", faction.current, faction.maximum,
                    STANDING_NAMES[faction.standing + 1] or "?")
            end
            table.insert(entries, {
                kind = "journey", name = faction.name .. progressText, icon = REPUTATION_ICON,
                levelText = STANDING_NAMES[faction.standing] or "?",
                tag = goals and "|cff40ff40Gear|r" or "", description = table.concat(descriptionParts, " "),
                sortGroup = goals and 1 or 2, sortGain = goals and goals[1].gain or 0,
            })
        end
    end
    -- Quartermasters you haven't met yet, but whose gear would help you.
    for factionId, goals in pairs(goalsByFaction) do
        if not shownFactionIds[factionId] then
            local vendor = goals[1].vendor
            local factionName = vendor[3] or ("the faction of " .. vendor[1])
            table.insert(entries, {
                kind = "journey", name = factionName, icon = REPUTATION_ICON, levelText = "new",
                tag = "|cff40ff40Gear|r",
                description = string.format("Not met yet. Gear for you: %s. Quests near %s (%s) start it.",
                    FormatGearGoal(goals[1], 4), vendor[1], vendor[5]),
                sortGroup = 1, sortGain = goals[1].gain,
            })
        end
    end
    table.sort(entries, function(first, second)
        if first.sortGroup ~= second.sortGroup then
            return first.sortGroup < second.sortGroup
        end
        return first.sortGain > second.sortGain
    end)
    return entries
end

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

-- What each faction gives you, by faction id: { short line for the row,
-- the full text for the tooltip }.
local CITY_BENEFIT = { "Cheaper vendors and trainers from Honored; its mount at Exalted.",
    "Its vendors and trainers get cheaper as your reputation rises (10% from Honored). "
    .. "Exalted lets you buy its race's mount even if you are another race." }
local GOBLIN_TOWN_BENEFIT = { "Neutral goblin town; shares reputation with the other three.",
    "A goblin town: its guards protect you. Booty Bay, Gadgetzan, Ratchet and Everlook share reputation - "
    .. "gaining with one gives some with the others." }

local FACTION_BENEFITS = {
    [72] = CITY_BENEFIT, [47] = CITY_BENEFIT, [69] = CITY_BENEFIT, [54] = CITY_BENEFIT,       -- Alliance cities
    [76] = CITY_BENEFIT, [81] = CITY_BENEFIT, [68] = CITY_BENEFIT, [530] = CITY_BENEFIT,     -- Horde cities
    [21] = GOBLIN_TOWN_BENEFIT, [369] = GOBLIN_TOWN_BENEFIT, [470] = GOBLIN_TOWN_BENEFIT, [577] = GOBLIN_TOWN_BENEFIT,
    [576] = { "From Neutral: its furbolgs leave you alone and the tunnel opens.",
        "Timbermaw Hold (Felwood, Winterspring): from Neutral its furbolgs stop attacking you and you can use their "
        .. "tunnel between the zones. Kill Deadwood and Winterfall furbolgs to raise it; recipes and gear later." },
    [609] = { "Silithus quests, gear and recipes.",
        "Cenarion Circle (Silithus, Moonglade): quests and gear in Silithus, and leatherworking, tailoring and blacksmithing recipes." },
    [529] = { "Scourgestones for reputation; gear and recipes.",
        "Argent Dawn (Plaguelands): wear the Argent Dawn Commission trinket to earn Scourgestones from undead, hand them in "
        .. "for reputation; gear, consumables and recipes." },
    [59] = { "Fire-resistance recipes.",
        "Thorium Brotherhood (Blackrock Depths' city): blacksmithing, leatherworking and tailoring recipes for fire-resistance gear." },
    [589] = { "Exalted: the Winterspring Frostsaber mount.", "Wintersaber Trainers (Winterspring, Alliance): Exalted gives the Winterspring Frostsaber mount." },
    [749] = { "For the Molten Core raid.", "Hydraxian Waterlords (Azshara): for the Molten Core raid - douse the runes there." },
    [349] = { "Rogue faction at Ravenholdt Manor.", "Ravenholdt (Alterac Mountains): rogue-friendly faction; quests at Ravenholdt Manor." },
    [87] = { "Lowers the goblin towns - skip it.", "Bloodsail Buccaneers: raising it lowers Booty Bay and the other goblin towns - usually not worth it." },
    [909] = { "Decks and crafted goods for prizes.", "Darkmoon Faire: turn in Darkmoon Faire decks and crafted goods for tickets and prizes." },
}

-- Standing colors, like the game's reputation bars.
local STANDING_COLORS = {
    [1] = { 0.80, 0.13, 0.13 }, [2] = { 0.80, 0.13, 0.13 }, [3] = { 0.75, 0.27, 0.00 }, [4] = { 0.90, 0.70, 0.00 },
    [5] = { 0.00, 0.60, 0.10 }, [6] = { 0.00, 0.70, 0.30 }, [7] = { 0.00, 0.75, 0.55 }, [8] = { 0.00, 0.80, 0.80 },
}

local function ColorText(standing, text)
    local color = STANDING_COLORS[standing] or { 1, 1, 1 }
    return string.format("|cff%02x%02x%02x%s|r", math.floor(color[1] * 255), math.floor(color[2] * 255),
        math.floor(color[3] * 255), text)
end

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
    local readyText = playerStanding >= goal.standingNeeded and "|cff40ff40buy it now|r"
        or ("at " .. (STANDING_NAMES[goal.standingNeeded] or "?"))
    return string.format("%s |cff40ff40+%.0f%%|r %s", goal.itemLink, goal.gain, readyText)
end

-- Rows for ExtrasUI (kind "reputation"): name, standing on the right, a
-- progress bar, one short line, and the details in the tooltip.
function reputation.GetEntries()
    local goalsByFaction = reputation.GetGearGoals()
    local entries = {}
    local shownFactionIds = {}
    for _, faction in ipairs(reputation.GetKnownFactions()) do
        local goals = goalsByFaction[faction.factionId]
        local benefit = FACTION_BENEFITS[faction.factionId]
        if goals or benefit then
            shownFactionIds[faction.factionId] = true
            local tooltipLines = {}
            local isExalted = faction.standing >= EXALTED_STANDING
            if not isExalted and faction.maximum > 0 then
                table.insert(tooltipLines, string.format("%d / %d to %s", faction.current, faction.maximum,
                    STANDING_NAMES[faction.standing + 1] or "?"))
            end
            for goalIndex = 1, math.min(4, goals and #goals or 0) do
                table.insert(tooltipLines, "Gear: " .. FormatGearGoal(goals[goalIndex], faction.standing))
            end
            if benefit then
                table.insert(tooltipLines, benefit[2])
            end
            table.insert(entries, {
                kind = "reputation", name = faction.name, icon = REPUTATION_ICON,
                tag = ColorText(faction.standing, STANDING_NAMES[faction.standing] or "?"),
                description = goals and ("Gear: " .. FormatGearGoal(goals[1], faction.standing)) or benefit[1],
                progress = (not isExalted and faction.maximum > 0) and (faction.current / faction.maximum) or (isExalted and 1 or 0),
                progressColor = STANDING_COLORS[faction.standing],
                tooltipLines = tooltipLines,
                sortGroup = goals and 1 or 2, sortGain = goals and goals[1].gain or 0,
            })
        end
    end
    -- Quartermasters you haven't met yet, but whose gear would help you.
    for factionId, goals in pairs(goalsByFaction) do
        if not shownFactionIds[factionId] then
            local vendor = goals[1].vendor
            local factionName = vendor[3] or ("the faction of " .. vendor[1])
            local tooltipLines = { "You haven't met this faction yet. Quests near " .. vendor[1] .. " (" .. vendor[5] .. ") start it." }
            for goalIndex = 1, math.min(4, #goals) do
                table.insert(tooltipLines, "Gear: " .. FormatGearGoal(goals[goalIndex], 4))
            end
            table.insert(entries, {
                kind = "reputation", name = factionName, icon = REPUTATION_ICON, tag = "|cffa6a6a6Not met|r",
                description = "Gear: " .. FormatGearGoal(goals[1], 4), tooltipLines = tooltipLines,
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

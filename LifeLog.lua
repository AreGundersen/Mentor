--------------------------------------------------------------------------------
-- Mentor - LifeLog.lua
-- "Life log" (ON by default; turn it off under Settings or with
-- /mentor lifelog off; the "Life log" button in the Mentor window opens it): records (almost) everything your character does and
-- keeps it forever. A Mentor-style window (/mentor log) shows every stat for
-- the session, this character and all your characters.
-- Built from Are's standalone LifeLog addon.
--
-- Data from the standalone LifeLog addon is never changed, only copied:
--   * While LifeLog is still loaded, it keeps tracking and Mentor's life log
--     stays passive. At every login and logout Mentor copies LifeLog's data
--     (this character, and the saved copies of all other characters) into its
--     own saved variables (MentorMentorLifeLogCharDB / MentorMentorLifeLogAccountDB).
--   * When LifeLog is disabled, Mentor carries on from the last copy. A
--     character that never logged in with both addons starts from the copy
--     LifeLog kept in its account-wide "All chars" data.
--
-- Tracked categories:
--   General       time played, logins, level-ups, time AFK / in combat,
--                 first seen, days played, longest session, rested XP used,
--                 fastest / slowest / average level
--   Combat        kills, deaths, spells cast (+ combat-log stats where allowed)
--   Death & life  spirit releases, corpse runs, spirit healer, resurrected by
--                 others, Reincarnation
--   Experience    XP gained (kills / quests), quests accepted / completed
--   Money         gained / spent, looted, quests, vendor, repairs, flights,
--                 training, mail, auction house, peak gold
--   Loot          items looted by quality, fish caught
--   Professions   skill-ups, herbs, ore, skinning, disenchants, items crafted
--   Consumables   potions, elixirs, food & drink, bandages, scrolls, oils/stones
--   Reputation    reputation gained / lost, duels won / lost, honor
--   Travel        distance walked / mounted / swum / flown, flights,
--                 hearthstone, jumps, zones visited, times mounted
--   Social        whispers, chat messages, emotes, groups, players grouped
--                 with, dungeons entered, mail sent
--   Top lists     most killed, most time per zone, favorite spells, most
--                 crafted, most used consumables, favorite emotes, most
--                 grouped with, dungeons, reputation per faction, skills,
--                 level history with time taken and gold earned per level
--
-- Every tracking module runs protected: a failing event is skipped without
-- stopping the rest, and values the client hides ("secret values") are ignored.
--
-- Slash commands:
--   /mentor log                  show / hide the window
--   /mentor log reset            reset the session column
--   /mentor log wipe confirm     erase ALL lifetime stats for this character
--   /mentor log forget <name>    remove a (deleted) character from the All chars column
--
-- Columns: Session | This char | All chars. "All chars" adds up every
-- character on the account that has logged in with LifeLog 1.2 or newer
-- ("highest ever" stats show the highest of any character).
-- The window follows the Mentor lock (/mentor lock).
--------------------------------------------------------------------------------

local _, Mentor = ...
local STANDALONE_ADDON_NAME = "LifeLog"

local lifeLog = {}
Mentor.LifeLog = lifeLog

--------------------------------------------------------------------------------
-- Configuration constants
--------------------------------------------------------------------------------
local WINDOW_WIDTH              = 480
local WINDOW_HEIGHT             = 440
local TITLE_BAR_HEIGHT          = 22
local COLUMN_HEADER_HEIGHT      = 16
local BOTTOM_BAR_HEIGHT         = 28
local SCROLL_BAR_SPACE          = 26     -- room on the right for the scroll bar
local WINDOW_PADDING            = 8
local STAT_ROW_HEIGHT           = 14
local HEADER_ROW_HEIGHT         = 20
local VALUE_COLUMN_WIDTH        = 84     -- width of each value column (Session, This char, All chars)
local BACKGROUND_ALPHA          = 0.80
local ROW_FONT                  = "GameFontHighlightSmall"
local HEADER_FONT               = "GameFontNormal"
local MUTED_TEXT_COLOR          = { 0.65, 0.65, 0.65 }

local DISPLAY_REFRESH_SECONDS   = 1.0    -- how often the open window redraws
local TRACKING_TICK_SECONDS     = 0.5    -- how often movement / time is sampled
local MAX_YARDS_PER_TICK_GROUND = 25     -- anything bigger is a teleport, not movement
local MAX_YARDS_PER_TICK_FLIGHT = 60     -- flight paths are faster than ground mounts
local YARDS_TO_KILOMETERS       = 0.0009144
local TOP_LIST_SIZE             = 5
local REQUEST_PLAYED_ON_LOGIN   = true   -- asks the server for /played once per login

local HEARTHSTONE_SPELL_ID      = 8690
local DUNGEON_REENTRY_SECONDS   = 1800   -- re-entering the same dungeon within 30 min is one visit
local RESURRECTION_SICKNESS_SPELL_ID = 15007
local REINCARNATION_SPELL_IDS   = { [20608] = true, [21169] = true }
local SELF_RESURRECT_WINDOW_SECONDS = 5  -- an alive event this soon after Reincarnation is not an outside res

-- Gathering / profession spells, matched by name so every rank counts.
-- The value is the stat key that gets +1 for each successful cast.
local GATHERING_SPELL_IDS = {
    [2366]  = "herbsGathered",      -- Herb Gathering
    [2575]  = "oreMined",           -- Mining
    [8613]  = "creaturesSkinned",   -- Skinning
    [13262] = "itemsDisenchanted",  -- Disenchant
}

-- Consumable sub-classes (item class 0) -> stat key. Used when a consumable
-- disappears from your bags without a vendor / mail / bank / trade being open.
local CONSUMABLE_ITEM_CLASS_ID = 0
local CONSUMABLE_STAT_BY_SUBCLASS = {
    [1] = "potionsUsed",
    [2] = "elixirsUsed",            -- elixirs
    [3] = "elixirsUsed",            -- flasks
    [4] = "scrollsUsed",
    [5] = "foodAndDrinkUsed",
    [6] = "weaponEnhancementsUsed", -- oils, sharpening / weight stones
    [7] = "bandagesUsed",
}
local OTHER_CONSUMABLE_STAT = "otherConsumablesUsed"
local FIRST_BAG_INDEX = 0
local LAST_BAG_INDEX  = NUM_BAG_SLOTS or 4

-- WoW Forever runs on the modern (Midnight-era) engine, where addons are not
-- allowed to register for the combat log. Registering anyway pops up the
-- "LifeLog has been blocked from an action only available to the Blizzard UI"
-- dialog. On those clients the combat-log stats (damage, healing, crits,
-- killing blows, falls, "killed most by") are simply hidden from the window.
local CLIENT_INTERFACE_VERSION  = (GetBuildInfo and select(4, GetBuildInfo())) or 0
local RESTRICTED_INTERFACE_FROM = 16000  -- Forever is 16001, Classic Era is 115xx
local IS_COMBAT_LOG_RESTRICTED  = (issecretvalue ~= nil)
    or (CLIENT_INTERFACE_VERSION >= RESTRICTED_INTERFACE_FROM)

-- Item quality colors used in item links -> quality index.
local QUALITY_BY_LINK_COLOR = {
    ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2,
    ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5,
}
local QUALITY_STAT_KEYS = {
    [0] = "itemsPoor", [1] = "itemsCommon", [2] = "itemsUncommon",
    [3] = "itemsRare", [4] = "itemsEpic",   [5] = "itemsLegendary",
}

--------------------------------------------------------------------------------
-- What the window shows, in order. "format" decides how values are printed:
--   number | gold | time | distance | text.  "peak" = keep the highest value.
--   "totalOnly" = the session column stays empty for that row.
--------------------------------------------------------------------------------
local STAT_SECTIONS = {
    { title = "General", stats = {
        { key = "timePlayed",       label = "Time played",        format = "time" },
        { key = "logins",           label = "Logins",             format = "number" },
        { key = "levelUps",         label = "Level-ups",          format = "number" },
        { key = "timeAfk",          label = "Time AFK",           format = "time" },
        { key = "timeInCombat",     label = "Time in combat",     format = "time" },
        { key = "firstSeen",        label = "Tracking since",     format = "text", totalOnly = true },
        { key = "daysPlayed",       label = "Days played",        format = "number", totalOnly = true },
        { key = "longestSession",   label = "Longest session",    format = "time", peak = true, totalOnly = true },
        { key = "restedXPUsed",     label = "Rested XP used",     format = "number" },
        { key = "fastestLevel",     label = "Fastest level",      format = "text", totalOnly = true },
        { key = "slowestLevel",     label = "Slowest level",      format = "text", totalOnly = true },
        { key = "averageLevelTime", label = "Average level time", format = "time", totalOnly = true },
    }},
    { title = "Combat", stats = {
        { key = "kills",            label = "Kills (XP)",         format = "number" },
        -- needsCombatLog = only trackable where addons may read the combat log.
        { key = "killingBlows",     label = "Killing blows",      format = "number", needsCombatLog = true },
        { key = "playerKills",      label = "Player kills",       format = "number", needsCombatLog = true },
        { key = "deaths",           label = "Deaths",             format = "number" },
        { key = "damageDone",       label = "Damage done",        format = "number", needsCombatLog = true },
        { key = "damageTaken",      label = "Damage taken",       format = "number", needsCombatLog = true },
        { key = "healingDone",      label = "Healing done",       format = "number", needsCombatLog = true },
        { key = "healingReceived",  label = "Healing received",   format = "number", needsCombatLog = true },
        { key = "highestHit",       label = "Highest hit",        format = "number", peak = true, needsCombatLog = true },
        { key = "highestCrit",      label = "Highest crit",       format = "number", peak = true, needsCombatLog = true },
        { key = "highestHeal",      label = "Highest heal",       format = "number", peak = true, needsCombatLog = true },
        { key = "criticalHits",     label = "Critical hits",      format = "number", needsCombatLog = true },
        { key = "spellsCast",       label = "Spells cast",        format = "number" },
        { key = "falls",            label = "Falls",              format = "number", needsCombatLog = true },
        { key = "fallDamage",       label = "Fall damage",        format = "number", needsCombatLog = true },
    }},
    { title = "Death & life", stats = {
        { key = "spiritReleases",      label = "Spirit releases",      format = "number" },
        { key = "corpseRuns",          label = "Corpse runs",          format = "number" },
        { key = "spiritHealerUses",    label = "Spirit healer",        format = "number" },
        { key = "resurrectedByOthers", label = "Resurrected by others",format = "number" },
        { key = "reincarnations",      label = "Reincarnations",       format = "number" },
    }},
    { title = "Experience", stats = {
        { key = "xpGained",         label = "XP gained",          format = "number" },
        { key = "xpFromKills",      label = "XP from kills",      format = "number" },
        { key = "xpFromQuests",     label = "XP from quests",     format = "number" },
        { key = "questsAccepted",   label = "Quests accepted",    format = "number" },
        { key = "questsCompleted",  label = "Quests completed",   format = "number" },
    }},
    { title = "Money", stats = {
        { key = "moneyGained",      label = "Gold gained",        format = "gold" },
        { key = "moneySpent",       label = "Gold spent",         format = "gold" },
        { key = "moneyLooted",      label = "Looted",             format = "gold" },
        { key = "moneyFromQuests",  label = "From quests",        format = "gold" },
        { key = "moneyVendorIn",    label = "Sold to vendors",    format = "gold" },
        { key = "moneyVendorOut",   label = "Bought from vendors",format = "gold" },
        { key = "moneyRepairs",     label = "Repairs",            format = "gold" },
        { key = "moneyFlights",     label = "Flight paths",       format = "gold" },
        { key = "moneyTraining",    label = "Training",           format = "gold" },
        { key = "moneyFromMail",    label = "Received by mail",   format = "gold" },
        { key = "moneyMailOut",     label = "Sent by mail",       format = "gold" },
        { key = "moneyAuctionHouse",label = "Auction house fees", format = "gold" },
        { key = "peakMoney",        label = "Most gold held",     format = "gold", peak = true },
    }},
    { title = "Loot", stats = {
        { key = "itemsLooted",      label = "Items looted",       format = "number" },
        { key = "itemsPoor",        label = "|cff9d9d9dPoor|r",        format = "number" },
        { key = "itemsCommon",      label = "|cffffffffCommon|r",      format = "number" },
        { key = "itemsUncommon",    label = "|cff1eff00Uncommon|r",    format = "number" },
        { key = "itemsRare",        label = "|cff0070ddRare|r",        format = "number" },
        { key = "itemsEpic",        label = "|cffa335eeEpic|r",        format = "number" },
        { key = "itemsLegendary",   label = "|cffff8000Legendary|r",   format = "number" },
        { key = "fishCaught",       label = "Fish caught",        format = "number" },
    }},
    { title = "Professions", stats = {
        { key = "skillUps",          label = "Skill-ups (all skills)", format = "number" },
        { key = "itemsCrafted",      label = "Items crafted",      format = "number" },
        { key = "herbsGathered",     label = "Herbs gathered",     format = "number" },
        { key = "oreMined",          label = "Ore mined",          format = "number" },
        { key = "creaturesSkinned",  label = "Creatures skinned",  format = "number" },
        { key = "itemsDisenchanted", label = "Items disenchanted", format = "number" },
    }},
    { title = "Consumables", stats = {
        { key = "consumablesUsed",        label = "Total used",          format = "number" },
        { key = "potionsUsed",            label = "Potions",             format = "number" },
        { key = "elixirsUsed",            label = "Elixirs & flasks",    format = "number" },
        { key = "foodAndDrinkUsed",       label = "Food & drink",        format = "number" },
        { key = "bandagesUsed",           label = "Bandages",            format = "number" },
        { key = "scrollsUsed",            label = "Scrolls",             format = "number" },
        { key = "weaponEnhancementsUsed", label = "Oils, stones & lures",format = "number" },
        { key = "otherConsumablesUsed",   label = "Other",               format = "number" },
    }},
    { title = "Reputation & PvP", stats = {
        { key = "reputationGained", label = "Reputation gained",  format = "number" },
        { key = "reputationLost",   label = "Reputation lost",    format = "number" },
        { key = "duelsWon",         label = "Duels won",          format = "number" },
        { key = "duelsLost",        label = "Duels lost",         format = "number" },
        { key = "honorableKills",   label = "Honorable kills",    format = "number" },
        { key = "honorGained",      label = "Honor gained",       format = "number" },
    }},
    { title = "Travel", stats = {
        { key = "distanceWalked",   label = "On foot",            format = "distance" },
        { key = "distanceMounted",  label = "Mounted",            format = "distance" },
        { key = "distanceSwum",     label = "Swimming",           format = "distance" },
        { key = "distanceFlown",    label = "Flight paths",       format = "distance" },
        { key = "flightsTaken",     label = "Flights taken",      format = "number" },
        { key = "hearthstoneUses",  label = "Hearthstone uses",   format = "number" },
        { key = "jumps",            label = "Jumps",              format = "number" },
        { key = "timesMounted",     label = "Times mounted",      format = "number" },
        { key = "zonesVisited",     label = "Zones visited",      format = "number", totalOnly = true },
    }},
    { title = "Social", stats = {
        { key = "whispersSent",     label = "Whispers sent",      format = "number" },
        { key = "whispersReceived", label = "Whispers received",  format = "number" },
        { key = "chatMessagesSent", label = "Chat messages sent", format = "number" },
        { key = "emotesUsed",       label = "Emotes used",        format = "number" },
        { key = "groupsJoined",     label = "Groups joined",      format = "number" },
        { key = "playersGrouped",   label = "Players grouped with", format = "number", totalOnly = true },
        { key = "dungeonsEntered",  label = "Dungeons entered",   format = "number" },
        { key = "mailSent",         label = "Mail sent",          format = "number" },
    }},
}

-- Quick lookup: stat key -> its definition (used to know which keys are peaks).
local STAT_DEFINITION_BY_KEY = {}
for _, section in ipairs(STAT_SECTIONS) do
    for _, statDefinition in ipairs(section.stats) do
        STAT_DEFINITION_BY_KEY[statDefinition.key] = statDefinition
    end
end

local DEFAULT_SETTINGS = {
    isShown = false,
    isLocked = false,
    point = "CENTER",
    relativePoint = "CENTER",
    offsetX = 0,
    offsetY = 0,
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local characterDB                 -- = MentorLifeLogCharDB once loaded
local isTracking = false          -- true while Mentor's life log is the one recording
local sessionStats = {}           -- same keys as characterDB.stats, this session only
local sessionStartTime = 0
local disabledModules = {}        -- module name -> true once an error has been reported
local playerGUID

-- Context flags used to categorize money changes and bag changes.
local isLootWindowOpen, isMerchantOpen, isTaxiMapOpen, isTrainerOpen = false, false, false, false
local isMailOpen, isAuctionOpen, isBankOpen, isTradeOpen = false, false, false, false

-- Rested XP, deaths, groups, dungeons, bags.
local lastKnownRestedXP = 0
local isPlayerDead = false
local lastReincarnationTime = 0
local currentGroupMembers = {}    -- name -> true for everyone in the current group
local currentInstanceName         -- dungeon/raid we are inside right now (nil outside)
local bagItemCounts = {}          -- itemId -> count in bags at the last scan
local bagItemNames = {}           -- itemId -> item name from the last scan
local lastRecordedDate            -- "YYYY-MM-DD" last written to daysPlayed
local lastKnownMoney = 0
local lastKnownRepairCost = 0
local pendingQuestMoney = 0       -- quest money already counted, so PLAYER_MONEY skips it

-- XP tracking.
local lastKnownXP, lastKnownMaxXP = 0, 0

-- Movement / state transitions.
local lastPositionX, lastPositionY, lastInstanceId
local wasOnTaxi, wasMounted = false, false
local lastDamageSourceName        -- whoever hit us last (for "killed most by")

-- /played estimate (total and "this level", both from TIME_PLAYED_MSG).
local playedSecondsAtSync, playedThisLevelAtSync, gameTimeAtSync

--------------------------------------------------------------------------------
-- Generic helpers
--------------------------------------------------------------------------------
local function PrintMessage(text)
    Mentor.Print("Life log: " .. text)
end

-- True when the client has hidden this value from addons ("secret value").
-- WoW Forever does this for some unit info and chat data, mostly in combat.
local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Returns true/false for a flag, or nil when the client keeps it secret.
local function ReadFlag(value)
    if IsSecret(value) then
        return nil
    end
    return value and true or false
end

-- Runs a tracking function protected. A failing event is just skipped and the
-- module keeps running, so one hidden value never stops tracking for the rest
-- of the session. Unexpected errors are reported once per module; errors about
-- secret values are expected on Forever and stay silent.
local function RunSafely(moduleName, trackingFunction, ...)
    local success, errorMessage = pcall(trackingFunction, ...)
    if not success and not disabledModules[moduleName] then
        disabledModules[moduleName] = true -- only used to report each module once
        if not tostring(errorMessage):find("secret") then
            PrintMessage(string.format("%s tracking hit an error (%s).",
                moduleName, tostring(errorMessage)))
        end
    end
end

-- Adds an amount to a stat, both for this session and for the lifetime total.
local function AddStat(statKey, amount)
    amount = amount or 1
    if amount == 0 then
        return
    end
    sessionStats[statKey] = (sessionStats[statKey] or 0) + amount
    characterDB.stats[statKey] = (characterDB.stats[statKey] or 0) + amount
end

-- Records a new "highest ever" value if it beats the current one.
local function SetPeakStat(statKey, value)
    if value > (sessionStats[statKey] or 0) then
        sessionStats[statKey] = value
    end
    if value > (characterDB.stats[statKey] or 0) then
        characterDB.stats[statKey] = value
    end
end

-- Adds one to a named counter inside a lifetime table (e.g. kills per creature).
local function IncrementNamedCounter(counterTable, name, amount)
    if name and name ~= "" then
        counterTable[name] = (counterTable[name] or 0) + (amount or 1)
    end
end

-- Turns a Blizzard format string ("%s dies, you gain %d experience.") into a
-- Lua pattern with captures for every %s and %d.
local function BuildPatternFromFormatString(formatString)
    if not formatString then
        return nil
    end
    local pattern = formatString:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    pattern = pattern:gsub("%%%%s", "(.+)")
    pattern = pattern:gsub("%%%%d", "(%%d+)")
    return "^" .. pattern .. "$"
end

-- The kill message often has a rested/group bonus suffix, so do not anchor its end.
local KILL_XP_PATTERN = BuildPatternFromFormatString(COMBATLOG_XPGAIN_FIRSTPERSON)
if KILL_XP_PATTERN then
    KILL_XP_PATTERN = KILL_XP_PATTERN:gsub("%$$", "")
end
local LOOT_MULTIPLE_PATTERN = BuildPatternFromFormatString(LOOT_ITEM_SELF_MULTIPLE)
local LOOT_SINGLE_PATTERN   = BuildPatternFromFormatString(LOOT_ITEM_SELF)
local CREATED_MULTIPLE_PATTERN = BuildPatternFromFormatString(LOOT_ITEM_CREATED_SELF_MULTIPLE)
local CREATED_SINGLE_PATTERN   = BuildPatternFromFormatString(LOOT_ITEM_CREATED_SELF)

-- Like BuildPatternFromFormatString, but also understands positional
-- placeholders ("%1$s", "%2$d") and returns which argument each capture is,
-- so messages such as "%2$s has fled from %1$s in a duel" are read correctly.
local function EscapeLiteralText(text)
    return (text:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function BuildPatternWithOrder(formatString)
    if not formatString then
        return nil, nil
    end
    local patternPieces, argumentOrder = {}, {}
    local searchPosition, nextArgumentIndex = 1, 1
    while true do
        local startIndex, endIndex, positionalIndex, placeholderKind =
            formatString:find("%%(%d*)%$?([sd])", searchPosition)
        if not startIndex then
            table.insert(patternPieces, EscapeLiteralText(formatString:sub(searchPosition)))
            break
        end
        table.insert(patternPieces, EscapeLiteralText(formatString:sub(searchPosition, startIndex - 1)))
        table.insert(patternPieces, placeholderKind == "d" and "(%d+)" or "(.+)")
        table.insert(argumentOrder, tonumber(positionalIndex) or nextArgumentIndex)
        nextArgumentIndex = nextArgumentIndex + 1
        searchPosition = endIndex + 1
    end
    return "^" .. table.concat(patternPieces) .. "$", argumentOrder
end

-- Matches a message; returns a table argumentIndex -> captured text, or nil.
local function MatchWithOrder(message, pattern, argumentOrder)
    if not pattern then
        return nil
    end
    local captures = { message:match(pattern) }
    if #captures == 0 then
        return nil
    end
    local argumentsByIndex = {}
    for captureIndex, argumentIndex in ipairs(argumentOrder) do
        argumentsByIndex[argumentIndex] = captures[captureIndex]
    end
    return argumentsByIndex
end

local REPUTATION_UP_PATTERN,   REPUTATION_UP_ORDER   = BuildPatternWithOrder(FACTION_STANDING_INCREASED)
local REPUTATION_DOWN_PATTERN, REPUTATION_DOWN_ORDER = BuildPatternWithOrder(FACTION_STANDING_DECREASED)
local DUEL_KNOCKOUT_PATTERN,   DUEL_KNOCKOUT_ORDER   = BuildPatternWithOrder(DUEL_WINNER_KNOCKOUT)
local DUEL_RETREAT_PATTERN,    DUEL_RETREAT_ORDER    = BuildPatternWithOrder(DUEL_WINNER_RETREAT)
local HONOR_KILL_PATTERN,      HONOR_KILL_ORDER      = BuildPatternWithOrder(COMBATLOG_HONORGAIN)
local HONOR_AWARD_PATTERN,     HONOR_AWARD_ORDER     = BuildPatternWithOrder(COMBATLOG_HONORAWARD)

local function GetSpellNameById(spellId)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellId)
    end
    return GetSpellInfo and (GetSpellInfo(spellId)) or nil
end

local function GetItemQualityFromLink(itemLink)
    local colorHex = itemLink:match("|c%x%x(%x%x%x%x%x%x)")
    if colorHex and QUALITY_BY_LINK_COLOR[colorHex:lower()] then
        return QUALITY_BY_LINK_COLOR[colorHex:lower()]
    end
    if C_Item and C_Item.GetItemInfo then
        return (select(3, C_Item.GetItemInfo(itemLink)))
    elseif GetItemInfo then
        return (select(3, GetItemInfo(itemLink)))
    end
    return nil
end

local function GetPlayedSecondsEstimate()
    if not playedSecondsAtSync then
        return nil
    end
    return playedSecondsAtSync + (GetTime() - gameTimeAtSync)
end

-- Seconds played on the current level (from /played), or nil before the first sync.
local function GetPlayedThisLevelEstimate()
    if not playedThisLevelAtSync then
        return nil
    end
    return playedThisLevelAtSync + (GetTime() - gameTimeAtSync)
end

local GetItemInfoInstantCompat = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

local function GetBagSlotCount(bagIndex)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagIndex) or 0
    end
    return GetContainerNumSlots(bagIndex) or 0
end

-- Returns itemId, itemLink, stackCount for a bag slot (or nil if empty).
local function GetBagSlotItem(bagIndex, slotIndex)
    if C_Container and C_Container.GetContainerItemInfo then
        local slotInfo = C_Container.GetContainerItemInfo(bagIndex, slotIndex)
        if not slotInfo then
            return nil
        end
        return slotInfo.itemID, slotInfo.hyperlink, slotInfo.stackCount
    end
    local _, stackCount, _, _, _, _, itemLink, _, _, itemId = GetContainerItemInfo(bagIndex, slotIndex)
    if not itemLink then
        return nil
    end
    return itemId, itemLink, stackCount
end

-- "[Copper Ore]" -> "Copper Ore"
local function GetItemNameFromLink(itemLink)
    return itemLink and itemLink:match("%[(.-)%]")
end

-- Returns true when the player has the given aura (debuff or buff), false if
-- not, or nil when the client does not let us know.
local function PlayerHasAura(spellId)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
        if IsSecret(auraData) then
            return nil
        end
        return auraData ~= nil
    end
    for auraIndex = 1, 40 do
        local auraName, _, _, _, _, _, _, _, _, auraSpellId = UnitDebuff("player", auraIndex)
        if not auraName then
            break
        end
        if auraSpellId == spellId then
            return true
        end
    end
    return false
end

local function CountTableKeys(anyTable)
    local keyCount = 0
    for _ in pairs(anyTable) do
        keyCount = keyCount + 1
    end
    return keyCount
end

--------------------------------------------------------------------------------
-- Formatting
--------------------------------------------------------------------------------
local function FormatNumber(number)
    local formatted = tostring(math.floor(number + 0.5))
    local replacementsMade
    repeat
        formatted, replacementsMade = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until replacementsMade == 0
    return formatted
end

local function FormatDuration(totalSeconds)
    totalSeconds = math.floor(totalSeconds)
    local days    = math.floor(totalSeconds / 86400)
    local hours   = math.floor((totalSeconds % 86400) / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = totalSeconds % 60
    if days > 0 then
        return string.format("%dd %dh %02dm", days, hours, minutes)
    elseif hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm %02ds", minutes, seconds)
    end
    return string.format("%ds", seconds)
end

-- Money with the game's gold / silver / copper coin icons, like Mentor's
-- tooltips. Gold keeps thousands separators; copper is left out above 1 gold.
local GOLD_COIN = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER_COIN = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER_COIN = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
local function FormatGold(copperAmount)
    copperAmount = math.floor(copperAmount)
    local isNegative = copperAmount < 0
    copperAmount = math.abs(copperAmount)
    local gold   = math.floor(copperAmount / 10000)
    local silver = math.floor((copperAmount % 10000) / 100)
    local copper = copperAmount % 100
    local parts = {}
    if gold > 0 then
        table.insert(parts, FormatNumber(gold) .. GOLD_COIN)
    end
    if silver > 0 then
        table.insert(parts, silver .. SILVER_COIN)
    end
    if gold == 0 and (copper > 0 or silver == 0) then
        table.insert(parts, copper .. COPPER_COIN)
    end
    return (isNegative and "-" or "") .. table.concat(parts, " ")
end

local function FormatDistance(yards)
    local kilometers = yards * YARDS_TO_KILOMETERS
    if kilometers >= 1 then
        return string.format("%.2f km", kilometers)
    end
    return string.format("%d m", math.floor(kilometers * 1000 + 0.5))
end

local function FormatStatValue(value, formatType)
    if value == nil then
        return "--"
    elseif formatType == "text" then
        return tostring(value)
    elseif formatType == "gold" then
        return FormatGold(value)
    elseif formatType == "time" then
        return FormatDuration(value)
    elseif formatType == "distance" then
        return FormatDistance(value)
    end
    return FormatNumber(value)
end

--------------------------------------------------------------------------------
-- Tracking: combat log (damage, healing, killing blows, falls, last attacker)
--------------------------------------------------------------------------------
local PLAYER_TYPE_FLAG = COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400

local function HandleCombatLogEvent()
    local _, subEvent, _, sourceGUID, sourceName, _, _, destGUID, _, destFlags, _,
        argument12, argument13, argument14, argument15, argument16, argument17,
        argument18, argument19, argument20, argument21 = CombatLogGetCurrentEventInfo()

    local isFromPlayer = (sourceGUID == playerGUID)
    local isToPlayer   = (destGUID == playerGUID)
    if not isFromPlayer and not isToPlayer and subEvent ~= "PARTY_KILL" then
        return
    end

    -- Read amount + crit flag for the different damage/heal event layouts.
    local amount, isCritical, isHeal, overhealing
    if subEvent == "SWING_DAMAGE" then
        amount, isCritical = argument12, argument18
    elseif subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE"
        or subEvent == "RANGE_DAMAGE" or subEvent == "DAMAGE_SHIELD" then
        amount, isCritical = argument15, argument21
    elseif subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" then
        amount, overhealing, isCritical, isHeal = argument15, argument16, argument18, true
    elseif subEvent == "ENVIRONMENTAL_DAMAGE" then
        if isToPlayer then
            local environmentType, environmentDamage = argument12, argument13 or 0
            AddStat("damageTaken", environmentDamage)
            if environmentType == "FALLING" or environmentType == "Falling" then
                AddStat("falls")
                AddStat("fallDamage", environmentDamage)
                lastDamageSourceName = "Falling"
            else
                lastDamageSourceName = tostring(environmentType)
            end
        end
        return
    elseif subEvent == "PARTY_KILL" then
        if isFromPlayer then
            AddStat("killingBlows")
            if destFlags and bit.band(destFlags, PLAYER_TYPE_FLAG) > 0 then
                AddStat("playerKills")
            end
        end
        return
    else
        return
    end

    amount = amount or 0
    if isHeal then
        local effectiveHealing = amount - (overhealing or 0)
        if isFromPlayer then
            AddStat("healingDone", effectiveHealing)
            SetPeakStat("highestHeal", amount)
        end
        if isToPlayer then
            AddStat("healingReceived", effectiveHealing)
        end
        return
    end

    if isFromPlayer and not isToPlayer then
        AddStat("damageDone", amount)
        SetPeakStat("highestHit", amount)
        if isCritical then
            AddStat("criticalHits")
            SetPeakStat("highestCrit", amount)
        end
    end
    if isToPlayer then
        AddStat("damageTaken", amount)
        if sourceName and not isFromPlayer then
            lastDamageSourceName = sourceName
        end
    end
end

--------------------------------------------------------------------------------
-- Gold over time: a point { time = unix seconds, copper = money } at most
-- every MONEY_POINT_SECONDS (and at login), for the gold graph. Old points are
-- thinned out so the list stays small: the newest half keeps every point.
--------------------------------------------------------------------------------
local MONEY_HISTORY = { pointSeconds = 600, maxPoints = 600 }   -- one point per 10 minutes at most

function lifeLog.RecordMoneyPoint(currentMoney, isForced)
    if IsSecret(currentMoney) or not characterDB then
        return
    end
    characterDB.moneyHistory = characterDB.moneyHistory or {}
    local moneyHistory = characterDB.moneyHistory
    local now = time()
    local lastPoint = moneyHistory[#moneyHistory]
    if lastPoint and not isForced and now - lastPoint.time < MONEY_HISTORY.pointSeconds then
        lastPoint.copper = currentMoney     -- keep the latest value in the current 10-minute point
        return
    end
    table.insert(moneyHistory, { time = now, copper = currentMoney })
    if #moneyHistory > MONEY_HISTORY.maxPoints then
        local thinnedHistory = {}
        local oldHalfEnd = math.floor(#moneyHistory / 2)
        for pointIndex, moneyPoint in ipairs(moneyHistory) do
            if pointIndex > oldHalfEnd or pointIndex % 2 == 1 then
                table.insert(thinnedHistory, moneyPoint)
            end
        end
        characterDB.moneyHistory = thinnedHistory
    end
end
lifeLog.FormatGold = function(copperAmount) return FormatGold(copperAmount) end

--------------------------------------------------------------------------------
-- Tracking: money (categorized by which window is open)
--------------------------------------------------------------------------------
local function HandleMoneyChange()
    local currentMoney = GetMoney()
    if IsSecret(currentMoney) then
        return -- next readable money update will include this change
    end
    local moneyDelta = currentMoney - lastKnownMoney
    lastKnownMoney = currentMoney
    SetPeakStat("peakMoney", currentMoney)
    lifeLog.RecordMoneyPoint(currentMoney, false)

    if moneyDelta > 0 then
        AddStat("moneyGained", moneyDelta)
        if pendingQuestMoney > 0 then
            -- Already counted as quest money in QUEST_TURNED_IN.
            local questPart = math.min(pendingQuestMoney, moneyDelta)
            pendingQuestMoney = pendingQuestMoney - questPart
        elseif isLootWindowOpen then
            AddStat("moneyLooted", moneyDelta)
        elseif isMerchantOpen then
            AddStat("moneyVendorIn", moneyDelta)
        elseif isMailOpen then
            AddStat("moneyFromMail", moneyDelta) -- includes auction house sales
        end
    elseif moneyDelta < 0 then
        local moneySpent = -moneyDelta
        AddStat("moneySpent", moneySpent)
        if isMerchantOpen then
            -- If the repair cost dropped, this payment was (at least partly) a repair.
            local currentRepairCost = (GetRepairAllCost and GetRepairAllCost()) or 0
            local repairPart = math.max(0, math.min(moneySpent, lastKnownRepairCost - currentRepairCost))
            lastKnownRepairCost = currentRepairCost
            AddStat("moneyRepairs", repairPart)
            AddStat("moneyVendorOut", moneySpent - repairPart)
        elseif isTaxiMapOpen then
            AddStat("moneyFlights", moneySpent)
        elseif isTrainerOpen then
            AddStat("moneyTraining", moneySpent)
        elseif isMailOpen then
            AddStat("moneyMailOut", moneySpent)      -- postage, COD and gold sent
        elseif isAuctionOpen then
            AddStat("moneyAuctionHouse", moneySpent) -- deposits and bids
        end
    end
end

--------------------------------------------------------------------------------
-- Tracking: XP
--------------------------------------------------------------------------------
local function HandleXPUpdate()
    local currentXP = UnitXP("player") or 0
    local currentMaxXP = UnitXPMax("player") or 0
    if IsSecret(currentXP) or IsSecret(currentMaxXP) then
        return -- next readable XP update will include this gain
    end
    local gainedXP
    if currentXP >= lastKnownXP then
        gainedXP = currentXP - lastKnownXP
    else
        -- Levelled up in between: finish the old bar and add the new progress.
        gainedXP = (lastKnownMaxXP - lastKnownXP) + currentXP
    end
    if gainedXP > 0 then
        AddStat("xpGained", gainedXP)
    end
    lastKnownXP, lastKnownMaxXP = currentXP, currentMaxXP
end

-- Rested XP only ever goes down when it is spent on bonus XP, so every drop
-- in the rested pool is "rested XP used". Called on XP and rested updates.
local function UpdateRestedTracking()
    local restedNow = GetXPExhaustion() or 0
    if IsSecret(restedNow) then
        return
    end
    if restedNow < lastKnownRestedXP then
        AddStat("restedXPUsed", lastKnownRestedXP - restedNow)
    end
    lastKnownRestedXP = restedNow
end

local function HandleKillXPMessage(chatMessage)
    if not KILL_XP_PATTERN or not chatMessage or IsSecret(chatMessage) then
        return
    end
    local creatureName, experienceText = chatMessage:match(KILL_XP_PATTERN)
    local experienceFromKill = tonumber(experienceText)
    if creatureName and experienceFromKill then
        AddStat("kills")
        AddStat("xpFromKills", experienceFromKill)
        IncrementNamedCounter(characterDB.killsByCreature, creatureName)
    end
end

--------------------------------------------------------------------------------
-- Tracking: loot
--------------------------------------------------------------------------------
-- "You create: [Item]x3." -> counts as crafted, with a per-item top list.
local function HandleCraftedMessage(chatMessage)
    local itemLink, quantityText
    if CREATED_MULTIPLE_PATTERN then
        itemLink, quantityText = chatMessage:match(CREATED_MULTIPLE_PATTERN)
    end
    if not itemLink and CREATED_SINGLE_PATTERN then
        itemLink = chatMessage:match(CREATED_SINGLE_PATTERN)
    end
    if not itemLink then
        return false
    end
    local quantity = tonumber(quantityText) or 1
    AddStat("itemsCrafted", quantity)
    IncrementNamedCounter(characterDB.craftedByItem, GetItemNameFromLink(itemLink) or itemLink, quantity)
    return true
end

local function HandleLootMessage(chatMessage)
    if not chatMessage or IsSecret(chatMessage) then
        return
    end
    if HandleCraftedMessage(chatMessage) then
        return -- crafted items are not counted as loot
    end
    local itemLink, quantityText
    if LOOT_MULTIPLE_PATTERN then
        itemLink, quantityText = chatMessage:match(LOOT_MULTIPLE_PATTERN)
    end
    if not itemLink and LOOT_SINGLE_PATTERN then
        itemLink = chatMessage:match(LOOT_SINGLE_PATTERN)
    end
    if not itemLink then
        return -- someone else's loot, or a non-loot message
    end
    local quantity = tonumber(quantityText) or 1
    AddStat("itemsLooted", quantity)
    local quality = GetItemQualityFromLink(itemLink)
    if quality and QUALITY_STAT_KEYS[quality] then
        AddStat(QUALITY_STAT_KEYS[quality], quantity)
    end
end

--------------------------------------------------------------------------------
-- Tracking: periodic sampling (movement, zone time, AFK, combat time)
--------------------------------------------------------------------------------
-- Every value below is checked with ReadFlag / IsSecret first: when the client
-- hides a value, only that one part of this tick is skipped.
local function SampleMovementAndTime(tickSeconds)
    local isOnTaxi = ReadFlag(UnitOnTaxi("player"))
    local isMountedNow = ReadFlag(IsMounted())
    local isSwimmingNow = ReadFlag(IsSwimming())

    -- State transitions (only when the flags are readable).
    if isOnTaxi ~= nil then
        if isOnTaxi and not wasOnTaxi then
            AddStat("flightsTaken")
        end
        wasOnTaxi = isOnTaxi
    end
    if isMountedNow ~= nil then
        if isMountedNow and not wasMounted then
            AddStat("timesMounted")
        end
        wasMounted = isMountedNow
    end

    -- Time-based stats.
    if ReadFlag(UnitIsAFK("player")) then
        AddStat("timeAfk", tickSeconds)
    end
    if ReadFlag(UnitAffectingCombat("player")) then
        AddStat("timeInCombat", tickSeconds)
    end
    local zoneName = GetRealZoneText()
    if zoneName and not IsSecret(zoneName) and zoneName ~= "" then
        IncrementNamedCounter(characterDB.secondsByZone, zoneName, tickSeconds)
    end

    -- Distance travelled since the last sample. If the position or the
    -- movement state is hidden, start measuring again from the next tick.
    local positionY, positionX, _, instanceId = UnitPosition("player")
    if IsSecret(positionX) or IsSecret(positionY) or IsSecret(instanceId)
        or isOnTaxi == nil or isMountedNow == nil or isSwimmingNow == nil then
        lastPositionX, lastPositionY, lastInstanceId = nil, nil, nil
        return
    end
    if positionX and lastPositionX and instanceId == lastInstanceId then
        local deltaX, deltaY = positionX - lastPositionX, positionY - lastPositionY
        local yardsMoved = math.sqrt(deltaX * deltaX + deltaY * deltaY)
        local maxYards = isOnTaxi and MAX_YARDS_PER_TICK_FLIGHT or MAX_YARDS_PER_TICK_GROUND
        if yardsMoved > 0.05 and yardsMoved <= maxYards then
            if isOnTaxi then
                AddStat("distanceFlown", yardsMoved)
            elseif isSwimmingNow then
                AddStat("distanceSwum", yardsMoved)
            elseif isMountedNow then
                AddStat("distanceMounted", yardsMoved)
            else
                AddStat("distanceWalked", yardsMoved)
            end
        end
    end
    lastPositionX, lastPositionY, lastInstanceId = positionX, positionY, instanceId
end

--------------------------------------------------------------------------------
-- Tracking: chat
--------------------------------------------------------------------------------
local function IsMessageFromPlayer(senderName)
    -- The sender can be hidden from addons; such a message is simply not counted.
    if not senderName or IsSecret(senderName) then
        return false
    end
    local senderWithoutRealm = senderName:gsub("%-.*$", "")
    return senderWithoutRealm == UnitName("player")
end

--------------------------------------------------------------------------------
-- Tracking: death & life
--------------------------------------------------------------------------------
local function HandlePlayerAlive()
    -- PLAYER_ALIVE also fires while logging in; that is not a resurrection.
    if GetTime() - sessionStartTime < SELF_RESURRECT_WINDOW_SECONDS then
        return
    end
    if ReadFlag(UnitIsGhost("player")) then
        -- Released the spirit: now a ghost at the graveyard.
        AddStat("spiritReleases")
    elseif isPlayerDead then
        isPlayerDead = false
        -- Came back to life without being a ghost: someone resurrected us,
        -- unless we used Reincarnation. The Reincarnation cast event can
        -- arrive just after this one, so decide a moment later.
        C_Timer.After(1, function()
            RunSafely("Death & life", function()
                if GetTime() - lastReincarnationTime > SELF_RESURRECT_WINDOW_SECONDS then
                    AddStat("resurrectedByOthers")
                end
            end)
        end)
    end
end

-- Back from being a ghost: either a corpse run or the spirit healer. The
-- spirit healer gives Resurrection Sickness, so check for it a moment later.
local function HandlePlayerUnghost()
    isPlayerDead = false
    C_Timer.After(1, function()
        RunSafely("Death & life", function()
            if PlayerHasAura(RESURRECTION_SICKNESS_SPELL_ID) then
                AddStat("spiritHealerUses")
            else
                AddStat("corpseRuns")
            end
        end)
    end)
end

--------------------------------------------------------------------------------
-- Tracking: spells, gathering and Reincarnation
--------------------------------------------------------------------------------
-- Spell name -> stat key, built once so every rank of a gathering spell counts.
local gatheringStatBySpellName = {}
for gatheringSpellId, statKey in pairs(GATHERING_SPELL_IDS) do
    local spellName = GetSpellNameById(gatheringSpellId)
    if spellName then
        gatheringStatBySpellName[spellName] = statKey
    end
end

local function HandleSpellCastSucceeded(unitId, _, spellId)
    if unitId ~= "player" or spellId == nil or IsSecret(spellId) then
        return
    end
    AddStat("spellsCast")
    if spellId == HEARTHSTONE_SPELL_ID then
        AddStat("hearthstoneUses")
    end
    if REINCARNATION_SPELL_IDS[spellId] then
        AddStat("reincarnations")
        lastReincarnationTime = GetTime()
    end
    local spellName = GetSpellNameById(spellId)
    if spellName and IsSecret(spellName) then
        spellName = nil
    end
    if spellName then
        IncrementNamedCounter(characterDB.spellsByName, spellName)
    end
    local gatheringStatKey = GATHERING_SPELL_IDS[spellId]
        or (spellName and gatheringStatBySpellName[spellName])
    if gatheringStatKey then
        AddStat(gatheringStatKey)
    end
end

--------------------------------------------------------------------------------
-- Tracking: skills (professions, weapon skills, ...)
-- Reads the skill window and counts every rank increase as a skill-up.
--------------------------------------------------------------------------------
local function ScanSkillLines()
    if not GetNumSkillLines or not GetSkillLineInfo then
        return
    end
    local currentHeader
    for skillLineIndex = 1, GetNumSkillLines() do
        local skillName, isHeader, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(skillLineIndex)
        if IsSecret(skillName) or IsSecret(skillRank) then
            return
        end
        if isHeader then
            currentHeader = skillName
        elseif skillName and skillMaxRank and skillMaxRank > 1
            and not (currentHeader and currentHeader:find(LANGUAGES_LABEL or "Languages", 1, true)) then
            local previousRank = characterDB.skillRanks[skillName]
            if previousRank and skillRank > previousRank then
                AddStat("skillUps", skillRank - previousRank)
            end
            characterDB.skillRanks[skillName] = skillRank
            characterDB.skillMaxRanks[skillName] = skillMaxRank
        end
    end
end

--------------------------------------------------------------------------------
-- Tracking: consumables (bag snapshot comparison)
-- When a consumable disappears from the bags while no vendor, mailbox, bank,
-- trade or auction house is open, it was used (eaten, drunk, applied, ...).
--------------------------------------------------------------------------------
local function IsMovingItemsSomewhere()
    return isMerchantOpen or isMailOpen or isBankOpen or isTradeOpen or isAuctionOpen
end

local function ScanBags()
    local newCounts, newNames = {}, {}
    for bagIndex = FIRST_BAG_INDEX, LAST_BAG_INDEX do
        for slotIndex = 1, GetBagSlotCount(bagIndex) do
            local itemId, itemLink, stackCount = GetBagSlotItem(bagIndex, slotIndex)
            if itemId and not IsSecret(itemId) then
                newCounts[itemId] = (newCounts[itemId] or 0) + (stackCount or 1)
                newNames[itemId] = newNames[itemId] or GetItemNameFromLink(itemLink)
            end
        end
    end
    return newCounts, newNames
end

local function HandleBagUpdate()
    local newCounts, newNames = ScanBags()
    if not IsMovingItemsSomewhere() and GetItemInfoInstantCompat then
        for itemId, oldCount in pairs(bagItemCounts) do
            local usedCount = oldCount - (newCounts[itemId] or 0)
            if usedCount > 0 then
                local _, _, _, _, _, itemClassId, itemSubClassId = GetItemInfoInstantCompat(itemId)
                if itemClassId == CONSUMABLE_ITEM_CLASS_ID then
                    AddStat("consumablesUsed", usedCount)
                    AddStat(CONSUMABLE_STAT_BY_SUBCLASS[itemSubClassId] or OTHER_CONSUMABLE_STAT, usedCount)
                    IncrementNamedCounter(characterDB.consumablesByItem,
                        bagItemNames[itemId] or ("item " .. itemId), usedCount)
                end
            end
        end
    end
    bagItemCounts, bagItemNames = newCounts, newNames
end

--------------------------------------------------------------------------------
-- Tracking: reputation, duels and honor (system / chat messages)
--------------------------------------------------------------------------------
local function HandleReputationMessage(chatMessage)
    if not chatMessage or IsSecret(chatMessage) then
        return
    end
    local gainedArguments = MatchWithOrder(chatMessage, REPUTATION_UP_PATTERN, REPUTATION_UP_ORDER)
    if gainedArguments then
        local factionName, amount = gainedArguments[1], tonumber(gainedArguments[2])
        if factionName and amount then
            AddStat("reputationGained", amount)
            IncrementNamedCounter(characterDB.reputationByFaction, factionName, amount)
        end
        return
    end
    local lostArguments = MatchWithOrder(chatMessage, REPUTATION_DOWN_PATTERN, REPUTATION_DOWN_ORDER)
    if lostArguments then
        local factionName, amount = lostArguments[1], tonumber(lostArguments[2])
        if factionName and amount then
            AddStat("reputationLost", amount)
            IncrementNamedCounter(characterDB.reputationByFaction, factionName, -amount)
        end
    end
end

local function HandleSystemMessage(chatMessage)
    if not chatMessage or IsSecret(chatMessage) then
        return
    end
    -- Duels: argument 1 is the winner, argument 2 the loser in both messages.
    local duelArguments = MatchWithOrder(chatMessage, DUEL_KNOCKOUT_PATTERN, DUEL_KNOCKOUT_ORDER)
        or MatchWithOrder(chatMessage, DUEL_RETREAT_PATTERN, DUEL_RETREAT_ORDER)
    if duelArguments then
        local playerName = UnitName("player")
        if duelArguments[1] == playerName then
            AddStat("duelsWon")
        elseif duelArguments[2] == playerName then
            AddStat("duelsLost")
        end
    end
end

local function HandleHonorMessage(chatMessage)
    if not chatMessage or IsSecret(chatMessage) then
        return
    end
    local awardArguments = MatchWithOrder(chatMessage, HONOR_AWARD_PATTERN, HONOR_AWARD_ORDER)
    if awardArguments then
        AddStat("honorGained", tonumber(awardArguments[1]) or 0)
        return
    end
    -- Honorable kill: the honor estimate is the last number in the message.
    AddStat("honorableKills")
    AddStat("honorGained", tonumber(chatMessage:match("(%d+)%D*$")) or 0)
end

--------------------------------------------------------------------------------
-- Tracking: groups and dungeons
--------------------------------------------------------------------------------
-- Adds everyone in the group who was not already counted for this group.
-- countAsNew = false only at login, so relogging does not count people twice.
local function ScanGroupMembers(countAsNew)
    local unitPrefix, memberCount
    if IsInRaid() then
        unitPrefix, memberCount = "raid", GetNumGroupMembers()
    else
        unitPrefix, memberCount = "party", GetNumSubgroupMembers()
    end
    for memberIndex = 1, memberCount do
        local memberName = UnitName(unitPrefix .. memberIndex)
        if memberName and not IsSecret(memberName) and memberName ~= UnitName("player")
            and memberName ~= UNKNOWNOBJECT and not currentGroupMembers[memberName] then
            currentGroupMembers[memberName] = true
            if countAsNew then
                IncrementNamedCounter(characterDB.playersGroupedWith, memberName)
            end
        end
    end
end

local function HandleZoneChange()
    local isInsideInstance, instanceType = IsInInstance()
    if IsSecret(isInsideInstance) or IsSecret(instanceType) then
        return
    end
    if isInsideInstance and (instanceType == "party" or instanceType == "raid") then
        local instanceName = GetInstanceInfo()
        if instanceName and not IsSecret(instanceName) and instanceName ~= currentInstanceName then
            local secondsSinceLeft = time() - (characterDB.lastDungeonLeftAt or 0)
            -- A quick re-entry (e.g. after a wipe) is the same visit.
            if instanceName ~= characterDB.lastDungeonName or secondsSinceLeft > DUNGEON_REENTRY_SECONDS then
                AddStat("dungeonsEntered")
                IncrementNamedCounter(characterDB.dungeonsByName, instanceName)
            end
            currentInstanceName = instanceName
            characterDB.lastDungeonName = instanceName
        end
    elseif currentInstanceName then
        characterDB.lastDungeonLeftAt = time()
        currentInstanceName = nil
    end
end

--------------------------------------------------------------------------------
-- Tracking: days played and level history
--------------------------------------------------------------------------------
local function RecordDayPlayed()
    local today = date("%Y-%m-%d")
    if today ~= lastRecordedDate then
        lastRecordedDate = today
        characterDB.daysPlayed[today] = true
    end
end

-- Stats remembered at each level-up, so the next level can show what was
-- earned during it.
local function TakeLevelSnapshot()
    local lifetimeStats = characterDB.stats
    characterDB.levelStartSnapshot = {
        moneyGained = lifetimeStats.moneyGained or 0,
        kills = lifetimeStats.kills or 0,
        deaths = lifetimeStats.deaths or 0,
        questsCompleted = lifetimeStats.questsCompleted or 0,
    }
end

local function HandleLevelUp(newLevel)
    AddStat("levelUps")
    local lifetimeStats = characterDB.stats
    local snapshot = characterDB.levelStartSnapshot
    local levelEntry = {
        level = newLevel,
        date = date("%Y-%m-%d"),
        playedSeconds = GetPlayedSecondsEstimate(),
        -- Time spent on the level that was just finished.
        levelSeconds = GetPlayedThisLevelEstimate(),
    }
    -- Only filled in when tracking covered the whole level.
    if snapshot then
        levelEntry.goldEarned = (lifetimeStats.moneyGained or 0) - snapshot.moneyGained
        levelEntry.kills = (lifetimeStats.kills or 0) - snapshot.kills
        levelEntry.deaths = (lifetimeStats.deaths or 0) - snapshot.deaths
        levelEntry.quests = (lifetimeStats.questsCompleted or 0) - snapshot.questsCompleted
    end
    table.insert(characterDB.levelHistory, levelEntry)
    TakeLevelSnapshot()
    -- Re-sync /played so "time on this level" restarts at 0.
    if REQUEST_PLAYED_ON_LOGIN then
        RequestTimePlayed()
    end
end

-- Fastest, slowest and average level from one or more level histories
-- (default: this character only).
local function GetLevelTimeSummary(levelHistories)
    levelHistories = levelHistories or { characterDB.levelHistory }
    local allLevelEntries = {}
    for _, levelHistory in ipairs(levelHistories) do
        for _, levelEntry in ipairs(levelHistory) do
            table.insert(allLevelEntries, levelEntry)
        end
    end
    local fastestEntry, slowestEntry, totalSeconds, timedLevels = nil, nil, 0, 0
    for _, levelEntry in ipairs(allLevelEntries) do
        local levelSeconds = levelEntry.levelSeconds
        if levelSeconds and levelSeconds > 0 then
            timedLevels = timedLevels + 1
            totalSeconds = totalSeconds + levelSeconds
            if not fastestEntry or levelSeconds < fastestEntry.levelSeconds then
                fastestEntry = levelEntry
            end
            if not slowestEntry or levelSeconds > slowestEntry.levelSeconds then
                slowestEntry = levelEntry
            end
        end
    end
    local function Describe(levelEntry)
        if not levelEntry then
            return nil
        end
        -- The entry is the level reached; the timed level is the one before it.
        return string.format("Lvl %d: %s", levelEntry.level - 1, FormatDuration(levelEntry.levelSeconds))
    end
    local averageSeconds = timedLevels > 0 and (totalSeconds / timedLevels) or nil
    return Describe(fastestEntry), Describe(slowestEntry), averageSeconds
end

--------------------------------------------------------------------------------
-- All characters (account-wide)
-- MentorLifeLogAccountDB.characters["Name-Realm"] holds each character's database.
-- The current character is a live reference; the others are the copies saved
-- the last time they logged out. A character appears once it has logged in
-- with this version of LifeLog.
--------------------------------------------------------------------------------
local function GetCharacterKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "?")
end

local function RegisterCharacterInAccount()
    MentorLifeLogAccountDB = MentorLifeLogAccountDB or {}
    MentorLifeLogAccountDB.characters = MentorLifeLogAccountDB.characters or {}
    MentorLifeLogAccountDB.characters[GetCharacterKey()] = characterDB
end

-- Remembers name, class and level so the character list can show them.
local function UpdateCharacterInfo()
    local _, classFileName = UnitClass("player")
    characterDB.info = {
        name = UnitName("player"),
        realm = GetRealmName and GetRealmName() or nil,
        className = (UnitClass("player")),
        classFileName = classFileName,
        level = UnitLevel("player"),
    }
end

-- Every stored character database, the current one included.
local function GetAllCharacterDatabases()
    local characterDatabases = {}
    if MentorLifeLogAccountDB and MentorLifeLogAccountDB.characters then
        for _, storedDatabase in pairs(MentorLifeLogAccountDB.characters) do
            table.insert(characterDatabases, storedDatabase)
        end
    end
    return characterDatabases
end

-- Number of distinct keys across one table field of every character.
local function CountUnionOfKeys(characterDatabases, fieldName)
    local seenKeys, keyCount = {}, 0
    for _, storedDatabase in ipairs(characterDatabases) do
        for key in pairs(storedDatabase[fieldName] or {}) do
            if not seenKeys[key] then
                seenKeys[key] = true
                keyCount = keyCount + 1
            end
        end
    end
    return keyCount
end

-- Played seconds for one character: live estimate for the current one,
-- the last known value for the others.
local function GetCharacterPlayedSeconds(storedDatabase)
    if storedDatabase == characterDB then
        return GetPlayedSecondsEstimate() or storedDatabase.lastPlayedSeconds
    end
    return storedDatabase.lastPlayedSeconds
end

-- Builds the "All chars" value for every stat: counters are added up,
-- "highest ever" stats take the maximum, and computed stats are combined.
local function BuildAllCharactersValues()
    local characterDatabases = GetAllCharacterDatabases()
    local allValues = {}

    for _, section in ipairs(STAT_SECTIONS) do
        for _, statDefinition in ipairs(section.stats) do
            local statKey = statDefinition.key
            local combinedValue = 0
            for _, storedDatabase in ipairs(characterDatabases) do
                local characterValue = (storedDatabase.stats or {})[statKey] or 0
                if statDefinition.peak then
                    combinedValue = math.max(combinedValue, characterValue)
                else
                    combinedValue = combinedValue + characterValue
                end
            end
            allValues[statKey] = combinedValue
        end
    end

    local totalPlayedSeconds, earliestDate, levelHistories = 0, nil, {}
    for _, storedDatabase in ipairs(characterDatabases) do
        totalPlayedSeconds = totalPlayedSeconds + (GetCharacterPlayedSeconds(storedDatabase) or 0)
        local firstSeenDate = storedDatabase.firstSeenDate
        if firstSeenDate and (not earliestDate or firstSeenDate < earliestDate) then
            earliestDate = firstSeenDate
        end
        table.insert(levelHistories, storedDatabase.levelHistory or {})
    end
    local fastestLevelText, slowestLevelText, averageLevelSeconds = GetLevelTimeSummary(levelHistories)

    allValues.timePlayed = totalPlayedSeconds
    allValues.firstSeen = earliestDate or "--"
    allValues.daysPlayed = CountUnionOfKeys(characterDatabases, "daysPlayed")
    allValues.zonesVisited = CountUnionOfKeys(characterDatabases, "secondsByZone")
    allValues.playersGrouped = CountUnionOfKeys(characterDatabases, "playersGroupedWith")
    allValues.fastestLevel = fastestLevelText or "--"
    allValues.slowestLevel = slowestLevelText or "--"
    allValues.averageLevelTime = averageLevelSeconds or "--"
    return allValues, characterDatabases
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
local mainFrame = CreateFrame("Frame", "MentorLifeLogFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
local isWindowBuilt = false
local MENTOR_GOLD = { 1.00, 0.78, 0.10 }
local LOGO_TEXTURE = "Interface\\AddOns\\Mentor\\Media\\Logo"
local scrollChildFrame
local rowPool = {}  -- reusable rows: { label, session, total, all } font strings
-- Three value columns from right to left: All chars, This char, Session.
local VALUE_COLUMN_ALL_OFFSET     = 0
local VALUE_COLUMN_TOTAL_OFFSET   = -(VALUE_COLUMN_WIDTH + 4)
local VALUE_COLUMN_SESSION_OFFSET = -(VALUE_COLUMN_WIDTH + 4) * 2

local function SaveWindowPosition()
    local point, _, relativePoint, offsetX, offsetY = mainFrame:GetPoint()
    characterDB.settings.point = point
    characterDB.settings.relativePoint = relativePoint
    characterDB.settings.offsetX = offsetX
    characterDB.settings.offsetY = offsetY
end

local function RestoreWindowPosition()
    local settings = characterDB.settings
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(settings.point, UIParent, settings.relativePoint, settings.offsetX, settings.offsetY)
end

local function GetOrCreateRow(rowIndex)
    local row = rowPool[rowIndex]
    if row then
        return row
    end
    row = {}
    row.labelText = scrollChildFrame:CreateFontString(nil, "OVERLAY", ROW_FONT)
    row.labelText:SetJustifyH("LEFT")
    row.labelText:SetWordWrap(false)

    row.sessionText = scrollChildFrame:CreateFontString(nil, "OVERLAY", ROW_FONT)
    row.sessionText:SetJustifyH("RIGHT")
    row.sessionText:SetWidth(VALUE_COLUMN_WIDTH)

    row.totalText = scrollChildFrame:CreateFontString(nil, "OVERLAY", ROW_FONT)
    row.totalText:SetJustifyH("RIGHT")
    row.totalText:SetWidth(VALUE_COLUMN_WIDTH)

    row.allText = scrollChildFrame:CreateFontString(nil, "OVERLAY", ROW_FONT)
    row.allText:SetJustifyH("RIGHT")
    row.allText:SetWidth(VALUE_COLUMN_WIDTH)

    rowPool[rowIndex] = row
    return row
end

-- Places one row at a vertical offset. kind = "header" or "stat".
local function LayoutRow(row, verticalOffset, kind, labelText, sessionValueText, totalValueText, allValueText)
    local childWidth = scrollChildFrame:GetWidth()
    row.labelText:ClearAllPoints()
    row.sessionText:ClearAllPoints()
    row.totalText:ClearAllPoints()
    row.allText:ClearAllPoints()

    if kind == "header" then
        local function MutedCaption(captionText)
            return captionText and ("|cffa6a6a6" .. captionText .. "|r") or ""
        end
        row.labelText:SetFontObject(HEADER_FONT)
        row.labelText:SetPoint("TOPLEFT", 0, verticalOffset - 4)
        row.labelText:SetWidth(childWidth - VALUE_COLUMN_WIDTH * 3)
        row.labelText:SetText(labelText)
        -- Optional muted column captions on a header (e.g. "Time" / "Gold").
        row.sessionText:SetPoint("TOPRIGHT", VALUE_COLUMN_SESSION_OFFSET, verticalOffset - 6)
        row.sessionText:SetText(MutedCaption(sessionValueText))
        row.totalText:SetPoint("TOPRIGHT", VALUE_COLUMN_TOTAL_OFFSET, verticalOffset - 6)
        row.totalText:SetText(MutedCaption(totalValueText))
        row.allText:SetPoint("TOPRIGHT", VALUE_COLUMN_ALL_OFFSET, verticalOffset - 6)
        row.allText:SetText(MutedCaption(allValueText))
    else
        row.labelText:SetFontObject(ROW_FONT)
        row.labelText:SetPoint("TOPLEFT", 6, verticalOffset)
        row.labelText:SetWidth(childWidth - (VALUE_COLUMN_WIDTH + 4) * 3 - 8)
        row.labelText:SetText(labelText)
        row.sessionText:SetPoint("TOPRIGHT", VALUE_COLUMN_SESSION_OFFSET, verticalOffset)
        row.sessionText:SetText(sessionValueText or "")
        row.totalText:SetPoint("TOPRIGHT", VALUE_COLUMN_TOTAL_OFFSET, verticalOffset)
        row.totalText:SetText(totalValueText or "")
        row.allText:SetPoint("TOPRIGHT", VALUE_COLUMN_ALL_OFFSET, verticalOffset)
        row.allText:SetText(allValueText or "")
    end
    row.labelText:Show()
    row.sessionText:Show()
    row.totalText:Show()
    row.allText:Show()
end

-- Returns the top N entries of a name -> number table, sorted descending.
local function GetTopEntries(counterTable, entryCount)
    local sortedEntries = {}
    for name, value in pairs(counterTable) do
        table.insert(sortedEntries, { name = name, value = value })
    end
    table.sort(sortedEntries, function(first, second) return first.value > second.value end)
    local topEntries = {}
    for entryIndex = 1, math.min(entryCount, #sortedEntries) do
        topEntries[entryIndex] = sortedEntries[entryIndex]
    end
    return topEntries
end

-- Builds the full list of rows to show, then lays them out.
local function RefreshWindow()
    if not scrollChildFrame or not mainFrame:IsShown() then
        return
    end

    -- Values that are computed rather than counted.
    local sessionSeconds = GetTime() - sessionStartTime
    local playedEstimate = GetPlayedSecondsEstimate()
    local fastestLevelText, slowestLevelText, averageLevelSeconds = GetLevelTimeSummary()
    local computedSession = { timePlayed = sessionSeconds }
    local computedTotal = {
        timePlayed = playedEstimate,
        zonesVisited = CountTableKeys(characterDB.secondsByZone),
        firstSeen = characterDB.firstSeenDate or "--",
        daysPlayed = CountTableKeys(characterDB.daysPlayed),
        fastestLevel = fastestLevelText or "--",
        slowestLevel = slowestLevelText or "--",
        averageLevelTime = averageLevelSeconds or "--",
        playersGrouped = CountTableKeys(characterDB.playersGroupedWith),
    }
    local allCharactersValues, characterDatabases = BuildAllCharactersValues()

    local rowsToShow = {}

    -- Gold you hold right now: this character live, the others from the last
    -- point of their gold history (saved since the gold graph came in, so a
    -- character that has not logged in since then is not counted yet).
    local function GetGoldNow(storedDatabase)
        if storedDatabase == characterDB then
            local currentMoney = GetMoney and GetMoney()
            if currentMoney and not IsSecret(currentMoney) then
                return currentMoney
            end
        end
        local moneyHistory = storedDatabase.moneyHistory
        local lastPoint = moneyHistory and moneyHistory[#moneyHistory]
        return lastPoint and lastPoint.copper or nil
    end
    local goldOnAllCharacters, charactersWithKnownGold = 0, 0
    for _, storedDatabase in ipairs(characterDatabases) do
        local goldNow = GetGoldNow(storedDatabase)
        if goldNow then
            goldOnAllCharacters = goldOnAllCharacters + goldNow
            charactersWithKnownGold = charactersWithKnownGold + 1
        end
    end

    -- Overview: the numbers most people look for, always at the top.
    local sessionGoldChange = (sessionStats.moneyGained or 0) - (sessionStats.moneySpent or 0)
    local goldLabel = "Gold now"
    if charactersWithKnownGold < #characterDatabases then
        goldLabel = goldLabel .. string.format(" |cffa6a6a6(%d of %d chars known)|r", charactersWithKnownGold, #characterDatabases)
    end
    table.insert(rowsToShow, { kind = "header", label = "Overview", sectionKey = "Overview" })
    table.insert(rowsToShow, { kind = "stat", label = goldLabel,
        sessionText = (sessionGoldChange >= 0 and "+" or "-") .. FormatGold(math.abs(sessionGoldChange)),
        totalText = FormatGold(GetGoldNow(characterDB) or 0),
        allText = FormatGold(goldOnAllCharacters) })
    for _, overviewKey in ipairs({ "timePlayed", "kills", "deaths", "questsCompleted", "levelUps" }) do
        for _, section in ipairs(STAT_SECTIONS) do
            for _, statDefinition in ipairs(section.stats) do
                if statDefinition.key == overviewKey then
                    local totalValue = computedTotal[overviewKey] or characterDB.stats[overviewKey] or 0
                    table.insert(rowsToShow, { kind = "stat", label = statDefinition.label, keepWhenZero = true,
                        sessionText = FormatStatValue(computedSession[overviewKey] or sessionStats[overviewKey] or 0, statDefinition.format),
                        totalText = FormatStatValue(totalValue, statDefinition.format),
                        allText = FormatStatValue(allCharactersValues[overviewKey] or 0, statDefinition.format) })
                end
            end
        end
    end

    for _, section in ipairs(STAT_SECTIONS) do
        table.insert(rowsToShow, { kind = "header", label = section.title })
        for _, statDefinition in ipairs(section.stats) do
          -- Rows that cannot be tracked on this client are left out entirely.
          if not (IS_COMBAT_LOG_RESTRICTED and statDefinition.needsCombatLog) then
            local statKey = statDefinition.key
            local sessionValue = computedSession[statKey] or sessionStats[statKey] or 0
            local totalValue = computedTotal[statKey]
            if totalValue == nil then
                totalValue = characterDB.stats[statKey] or 0
            end
            -- "--" placeholders are shown as-is instead of being formatted.
            local totalText = (totalValue == "--") and "--" or FormatStatValue(totalValue, statDefinition.format)
            local allValue = allCharactersValues[statKey]
            local allText = (allValue == "--") and "--" or FormatStatValue(allValue, statDefinition.format)
            table.insert(rowsToShow, {
                kind = "stat",
                label = statDefinition.label,
                sessionText = statDefinition.totalOnly and "" or FormatStatValue(sessionValue, statDefinition.format),
                totalText = totalText,
                allText = allText,
            })
          end
        end
    end

    -- Characters on this account, most played first.
    table.insert(rowsToShow, { kind = "header", label = "Characters", sessionText = "Gold", totalText = "Level", allText = "Played" })
    table.sort(characterDatabases, function(first, second)
        return (GetCharacterPlayedSeconds(first) or 0) > (GetCharacterPlayedSeconds(second) or 0)
    end)
    for _, storedDatabase in ipairs(characterDatabases) do
        local characterInfo = storedDatabase.info or {}
        local characterName = characterInfo.name or "?"
        -- Class colour when the client knows it.
        local classColor = characterInfo.classFileName and RAID_CLASS_COLORS
            and RAID_CLASS_COLORS[characterInfo.classFileName]
        if classColor and classColor.colorStr then
            characterName = "|c" .. classColor.colorStr .. characterName .. "|r"
        end
        if storedDatabase == characterDB then
            characterName = characterName .. " |cffa6a6a6(you)|r"
        end
        local playedSeconds = GetCharacterPlayedSeconds(storedDatabase)
        local characterGold = GetGoldNow(storedDatabase)
        table.insert(rowsToShow, {
            kind = "stat",
            label = characterName .. " |cffa6a6a6" .. (characterInfo.className or "") .. "|r",
            sessionText = characterGold and FormatGold(characterGold) or "--",
            totalText = characterInfo.level and tostring(characterInfo.level) or "--",
            allText = playedSeconds and FormatDuration(playedSeconds) or "--",
        })
    end

    -- Top lists (lifetime only, this character).
    local topLists = {
        { title = "Most killed",          source = characterDB.killsByCreature,    format = "number" },
        { title = "Killed most by",       source = characterDB.deathsByKiller,     format = "number", needsCombatLog = true },
        { title = "Most time in zone",    source = characterDB.secondsByZone,      format = "time" },
        { title = "Favorite spells",      source = characterDB.spellsByName,       format = "number" },
        { title = "Most crafted",         source = characterDB.craftedByItem,      format = "number" },
        { title = "Most used consumables",source = characterDB.consumablesByItem,  format = "number" },
        { title = "Favorite emotes",      source = characterDB.emotesByName,       format = "number" },
        { title = "Most grouped with",    source = characterDB.playersGroupedWith, format = "number" },
        { title = "Dungeons visited",     source = characterDB.dungeonsByName,     format = "number" },
        { title = "Reputation earned",    source = characterDB.reputationByFaction,format = "number" },
    }
    for _, topList in ipairs(topLists) do
      if not (IS_COMBAT_LOG_RESTRICTED and topList.needsCombatLog) then
        table.insert(rowsToShow, { kind = "header", label = topList.title })
        local topEntries = GetTopEntries(topList.source, TOP_LIST_SIZE)
        if #topEntries == 0 then
            table.insert(rowsToShow, { kind = "stat", label = "|cffa6a6a6Nothing yet|r" })
        end
        for entryIndex, entry in ipairs(topEntries) do
            table.insert(rowsToShow, {
                kind = "stat",
                label = entryIndex .. ". " .. entry.name,
                totalText = FormatStatValue(entry.value, topList.format),
            })
        end
      end
    end

    -- Skills (professions, weapon skills, ...), highest rank first.
    table.insert(rowsToShow, { kind = "header", label = "Skills", totalText = "Rank" })
    local skillEntries = GetTopEntries(characterDB.skillRanks, math.huge)
    if #skillEntries == 0 then
        table.insert(rowsToShow, { kind = "stat", label = "|cffa6a6a6Nothing yet|r" })
    end
    for _, skillEntry in ipairs(skillEntries) do
        local maxRank = characterDB.skillMaxRanks[skillEntry.name]
        table.insert(rowsToShow, {
            kind = "stat",
            label = skillEntry.name,
            totalText = maxRank and (skillEntry.value .. " / " .. maxRank) or tostring(skillEntry.value),
        })
    end

    -- Level history, newest first: date, time it took, gold earned on the level.
    table.insert(rowsToShow, { kind = "header", label = "Level history", sessionText = "Time taken", totalText = "Gold earned" })
    local levelHistory = characterDB.levelHistory
    if #levelHistory == 0 then
        table.insert(rowsToShow, { kind = "stat", label = "|cffa6a6a6No level-ups recorded yet|r" })
    end
    for historyIndex = #levelHistory, 1, -1 do
        local levelEntry = levelHistory[historyIndex]
        local detailText = ""
        if levelEntry.kills then
            detailText = string.format(" |cffa6a6a6%dk %dd %dq|r",
                levelEntry.kills, levelEntry.deaths or 0, levelEntry.quests or 0)
        end
        table.insert(rowsToShow, {
            kind = "stat",
            -- Date shown as "MM-DD" to keep the row short; k/d/q = kills, deaths, quests.
            label = "Lvl " .. levelEntry.level .. " |cffa6a6a6" .. (levelEntry.date or ""):sub(6) .. "|r" .. detailText,
            sessionText = levelEntry.levelSeconds and FormatDuration(levelEntry.levelSeconds) or "--",
            totalText = levelEntry.goldEarned and FormatGold(levelEntry.goldEarned) or "--",
        })
    end

    -- Sections fold: click a header to open or close it. Overview and
    -- Characters start open, the rest closed, so the window fits on one screen.
    -- The choice is remembered per character.
    characterDB.settings.openSections = characterDB.settings.openSections or { Overview = true, Characters = true }
    local openSections = characterDB.settings.openSections
    local visibleRows, isCurrentSectionOpen = {}, true
    for _, rowData in ipairs(rowsToShow) do
        if rowData.kind == "header" then
            rowData.sectionKey = rowData.sectionKey or rowData.label
            isCurrentSectionOpen = openSections[rowData.sectionKey] == true
            rowData.label = (isCurrentSectionOpen and "|cffffd100-|r " or "|cffffd100+|r ") .. rowData.label
            if not isCurrentSectionOpen then
                -- A closed header keeps no column captions.
                rowData.sessionText, rowData.totalText, rowData.allText = nil, nil, nil
            end
            table.insert(visibleRows, rowData)
        elseif isCurrentSectionOpen then
            local function IsZero(valueText)
                return valueText == nil or valueText == "" or valueText == "0" or valueText == "--"
            end
            -- Overview rows always show, even at 0 ("Deaths 0" is worth seeing).
            local isEmptyStatRow = rowData.kind == "stat" and not rowData.keepWhenZero and IsZero(rowData.sessionText)
                and IsZero(rowData.totalText) and IsZero(rowData.allText)
                and not rowData.label:find("Nothing yet") and not rowData.label:find("No level")
            if not isEmptyStatRow then
                table.insert(visibleRows, rowData)
            end
        end
    end
    rowsToShow = visibleRows

    -- Lay everything out from the top down.
    local verticalOffset = 0
    for rowIndex, rowData in ipairs(rowsToShow) do
        local row = GetOrCreateRow(rowIndex)
        LayoutRow(row, verticalOffset, rowData.kind, rowData.label, rowData.sessionText, rowData.totalText, rowData.allText)
        row.labelText:SetTextColor(1, 1, 1)
        if rowData.kind == "header" then
            row.labelText:SetTextColor(1, 0.82, 0)
        end
        if not row.headerButton then
            row.headerButton = CreateFrame("Button", nil, scrollChildFrame)
            row.headerButton:SetScript("OnClick", function(clickedButton)
                local sectionKey = clickedButton.sectionKey
                if sectionKey then
                    local sections = characterDB.settings.openSections
                    sections[sectionKey] = not sections[sectionKey] or nil
                    RefreshWindow()
                end
            end)
            local hoverHighlight = row.headerButton:CreateTexture(nil, "HIGHLIGHT")
            hoverHighlight:SetAllPoints()
            hoverHighlight:SetColorTexture(1, 0.82, 0, 0.08)
        end
        if rowData.kind == "header" then
            row.headerButton.sectionKey = rowData.sectionKey
            row.headerButton:ClearAllPoints()
            row.headerButton:SetPoint("TOPLEFT", 0, verticalOffset)
            row.headerButton:SetSize(scrollChildFrame:GetWidth(), HEADER_ROW_HEIGHT)
            row.headerButton:Show()
        else
            row.headerButton:Hide()
        end
        if rowData.kind == "header" then
            verticalOffset = verticalOffset - HEADER_ROW_HEIGHT
        else
            verticalOffset = verticalOffset - STAT_ROW_HEIGHT
        end
    end
    for unusedRowIndex = #rowsToShow + 1, #rowPool do
        local unusedRow = rowPool[unusedRowIndex]
        unusedRow.labelText:Hide()
        unusedRow.sessionText:Hide()
        unusedRow.totalText:Hide()
        unusedRow.allText:Hide()
        if unusedRow.headerButton then
            unusedRow.headerButton:Hide()
        end
    end
    scrollChildFrame:SetHeight(-verticalOffset + 4)
end

local function BuildWindow()
    if isWindowBuilt then
        return
    end
    isWindowBuilt = true
    mainFrame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)

    -- Mentor look: dark background with a gold border.
    if mainFrame.SetBackdrop then
        mainFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        mainFrame:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.9)
    end

    -- Title bar: drag here to move the window.
    local titleBar = CreateFrame("Frame", nil, mainFrame)
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    titleBar:SetHeight(TITLE_BAR_HEIGHT)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        if not (MentorDB and MentorDB.isLocked) then
            mainFrame:StartMoving()
        end
    end)
    titleBar:SetScript("OnDragStop", function()
        mainFrame:StopMovingOrSizing()
        SaveWindowPosition()
    end)

    -- Logo, title and a thin gold line under the title bar.
    local logo = titleBar:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(LOGO_TEXTURE)
    logo:SetSize(16, 16)
    logo:SetPoint("LEFT", WINDOW_PADDING, -2)
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    titleText:SetText("Life log |cffa6a6a6- " .. (UnitName("player") or "") .. "|r")
    local titleLine = titleBar:CreateTexture(nil, "ARTWORK")
    titleLine:SetColorTexture(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.3)
    titleLine:SetHeight(1)
    titleLine:SetPoint("BOTTOMLEFT", WINDOW_PADDING, -2)
    titleLine:SetPoint("BOTTOMRIGHT", -WINDOW_PADDING, -2)

    local closeButton = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeButton:SetPoint("RIGHT", -2, -2)
    closeButton:SetSize(24, 24)
    closeButton:SetScript("OnClick", function()
        characterDB.settings.isShown = false
        mainFrame:Hide()
    end)

    -- Column headers.
    local sessionHeader = mainFrame:CreateFontString(nil, "OVERLAY", ROW_FONT)
    sessionHeader:SetPoint("TOPRIGHT", -SCROLL_BAR_SPACE + VALUE_COLUMN_SESSION_OFFSET, -TITLE_BAR_HEIGHT - 3)
    sessionHeader:SetWidth(VALUE_COLUMN_WIDTH)
    sessionHeader:SetJustifyH("RIGHT")
    sessionHeader:SetTextColor(MUTED_TEXT_COLOR[1], MUTED_TEXT_COLOR[2], MUTED_TEXT_COLOR[3])
    sessionHeader:SetText("Session")

    local totalHeader = mainFrame:CreateFontString(nil, "OVERLAY", ROW_FONT)
    totalHeader:SetPoint("TOPRIGHT", -SCROLL_BAR_SPACE, -TITLE_BAR_HEIGHT - 3)
    totalHeader:SetWidth(VALUE_COLUMN_WIDTH)
    totalHeader:SetJustifyH("RIGHT")
    totalHeader:SetTextColor(MUTED_TEXT_COLOR[1], MUTED_TEXT_COLOR[2], MUTED_TEXT_COLOR[3])
    totalHeader:SetText("This char")

    -- Session and This char move one column left to make room for All chars.
    sessionHeader:ClearAllPoints()
    sessionHeader:SetPoint("TOPRIGHT", -SCROLL_BAR_SPACE + VALUE_COLUMN_SESSION_OFFSET, -TITLE_BAR_HEIGHT - 3)
    totalHeader:ClearAllPoints()
    totalHeader:SetPoint("TOPRIGHT", -SCROLL_BAR_SPACE + VALUE_COLUMN_TOTAL_OFFSET, -TITLE_BAR_HEIGHT - 3)

    local allHeader = mainFrame:CreateFontString(nil, "OVERLAY", ROW_FONT)
    allHeader:SetPoint("TOPRIGHT", -SCROLL_BAR_SPACE + VALUE_COLUMN_ALL_OFFSET, -TITLE_BAR_HEIGHT - 3)
    allHeader:SetWidth(VALUE_COLUMN_WIDTH)
    allHeader:SetJustifyH("RIGHT")
    allHeader:SetTextColor(MUTED_TEXT_COLOR[1], MUTED_TEXT_COLOR[2], MUTED_TEXT_COLOR[3])
    allHeader:SetText("All chars")

    -- Scrollable stat list.
    local scrollFrame = CreateFrame("ScrollFrame", "MentorLifeLogScrollFrame", mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", WINDOW_PADDING, -TITLE_BAR_HEIGHT - COLUMN_HEADER_HEIGHT - 4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_SPACE, BOTTOM_BAR_HEIGHT)

    scrollChildFrame = CreateFrame("Frame", nil, scrollFrame)
    scrollChildFrame:SetSize(WINDOW_WIDTH - WINDOW_PADDING - SCROLL_BAR_SPACE, 1)
    scrollFrame:SetScrollChild(scrollChildFrame)

    -- Bottom bar: reset session button.
    local resetButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    resetButton:SetSize(110, 20)
    resetButton:SetPoint("BOTTOMLEFT", WINDOW_PADDING, 6)
    resetButton:SetText("Reset session")
    resetButton:SetScript("OnClick", function()
        wipe(sessionStats)
        sessionStartTime = GetTime()
        RefreshWindow()
    end)

    local goldGraphButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    goldGraphButton:SetSize(100, 20)
    goldGraphButton:SetPoint("LEFT", resetButton, "RIGHT", 6, 0)
    goldGraphButton:SetText("Gold graph")
    goldGraphButton:SetScript("OnClick", function()
        lifeLog.ToggleGoldGraph()
    end)

    local hintText = mainFrame:CreateFontString(nil, "OVERLAY", ROW_FONT)
    hintText:SetPoint("BOTTOMRIGHT", -WINDOW_PADDING - 2, 11)
    hintText:SetTextColor(MUTED_TEXT_COLOR[1], MUTED_TEXT_COLOR[2], MUTED_TEXT_COLOR[3])
    hintText:SetText("/mentor log to toggle")

    mainFrame:SetScript("OnShow", RefreshWindow)
end

--------------------------------------------------------------------------------
-- Database setup
--------------------------------------------------------------------------------
local function InitializeDatabase()
    MentorLifeLogCharDB = MentorLifeLogCharDB or {}
    characterDB = MentorLifeLogCharDB
    characterDB.stats           = characterDB.stats or {}
    characterDB.killsByCreature = characterDB.killsByCreature or {}
    characterDB.deathsByKiller  = characterDB.deathsByKiller or {}
    -- Version 1.0.0 stored deaths with no known killer as "Unknown"; clean that up.
    characterDB.deathsByKiller["Unknown"] = nil
    characterDB.secondsByZone   = characterDB.secondsByZone or {}
    characterDB.levelHistory    = characterDB.levelHistory or {}
    characterDB.spellsByName        = characterDB.spellsByName or {}
    characterDB.craftedByItem       = characterDB.craftedByItem or {}
    characterDB.consumablesByItem   = characterDB.consumablesByItem or {}
    characterDB.emotesByName        = characterDB.emotesByName or {}
    characterDB.playersGroupedWith  = characterDB.playersGroupedWith or {}
    characterDB.dungeonsByName      = characterDB.dungeonsByName or {}
    characterDB.reputationByFaction = characterDB.reputationByFaction or {}
    characterDB.skillRanks          = characterDB.skillRanks or {}
    characterDB.skillMaxRanks       = characterDB.skillMaxRanks or {}
    characterDB.daysPlayed          = characterDB.daysPlayed or {}
    -- Older saves have no start date: use the first recorded level-up if any.
    local firstLevelEntry = characterDB.levelHistory[1]
    characterDB.firstSeenDate       = characterDB.firstSeenDate
        or (firstLevelEntry and firstLevelEntry.date) or date("%Y-%m-%d")
    characterDB.settings        = characterDB.settings or {}
    for settingName, defaultValue in pairs(DEFAULT_SETTINGS) do
        if characterDB.settings[settingName] == nil then
            characterDB.settings[settingName] = defaultValue
        end
    end
    RegisterCharacterInAccount()
end

--------------------------------------------------------------------------------
-- Event handling
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")

-- Each event maps to { module name, handler }. The module name is what gets
-- switched off if that handler ever errors on this client.
local EVENT_HANDLERS = {
    COMBAT_LOG_EVENT_UNFILTERED = { "Combat log", HandleCombatLogEvent },

    PLAYER_DEAD = { "Deaths", function()
        AddStat("deaths")
        isPlayerDead = true
        -- The killer is only known when the combat log is readable.
        if lastDamageSourceName then
            IncrementNamedCounter(characterDB.deathsByKiller, lastDamageSourceName)
        end
        lastDamageSourceName = nil
    end },

    PLAYER_MONEY = { "Money", HandleMoneyChange },
    LOOT_OPENED  = { "Loot window", function()
        isLootWindowOpen = true
        if IsFishingLoot and IsFishingLoot() then
            AddStat("fishCaught")
        end
    end },
    LOOT_CLOSED     = { "Loot window", function() isLootWindowOpen = false end },
    MERCHANT_SHOW   = { "Money", function()
        isMerchantOpen = true
        lastKnownRepairCost = (GetRepairAllCost and GetRepairAllCost()) or 0
    end },
    MERCHANT_CLOSED = { "Money", function() isMerchantOpen = false end },
    TAXIMAP_OPENED  = { "Money", function() isTaxiMapOpen = true end },
    TAXIMAP_CLOSED  = { "Money", function() isTaxiMapOpen = false end },
    TRAINER_SHOW    = { "Money", function() isTrainerOpen = true end },
    TRAINER_CLOSED  = { "Money", function() isTrainerOpen = false end },
    MAIL_SHOW       = { "Money", function() isMailOpen = true end },
    MAIL_CLOSED     = { "Money", function() isMailOpen = false end },
    AUCTION_HOUSE_SHOW   = { "Money", function() isAuctionOpen = true end },
    AUCTION_HOUSE_CLOSED = { "Money", function() isAuctionOpen = false end },
    BANKFRAME_OPENED = { "Bags", function() isBankOpen = true end },
    BANKFRAME_CLOSED = { "Bags", function() isBankOpen = false end },
    TRADE_SHOW       = { "Bags", function() isTradeOpen = true end },
    TRADE_CLOSED     = { "Bags", function()
        -- Items can still settle into the bags right after the trade window
        -- closes, so keep treating bag changes as "moved" for a moment.
        C_Timer.After(2, function() isTradeOpen = false end)
    end },
    MAIL_SEND_SUCCESS = { "Mail", function() AddStat("mailSent") end },

    PLAYER_ALIVE   = { "Death & life", HandlePlayerAlive },
    PLAYER_UNGHOST = { "Death & life", HandlePlayerUnghost },

    BAG_UPDATE_DELAYED = { "Consumables", HandleBagUpdate },
    SKILL_LINES_CHANGED = { "Skills", ScanSkillLines },
    UPDATE_EXHAUSTION  = { "Rested XP", UpdateRestedTracking },

    CHAT_MSG_COMBAT_FACTION_CHANGE = { "Reputation", HandleReputationMessage },
    CHAT_MSG_SYSTEM                = { "Duels", HandleSystemMessage },
    CHAT_MSG_COMBAT_HONOR_GAIN     = { "Honor", HandleHonorMessage },

    -- The member list is only cleared on GROUP_LEFT, so the roster update that
    -- can arrive just before GROUP_JOINED never makes anyone count twice.
    GROUP_JOINED = { "Groups", function()
        AddStat("groupsJoined")
        ScanGroupMembers(true)
    end },
    GROUP_ROSTER_UPDATE = { "Groups", function() ScanGroupMembers(true) end },
    GROUP_LEFT = { "Groups", function() wipe(currentGroupMembers) end },

    PLAYER_ENTERING_WORLD = { "Dungeons", HandleZoneChange },
    ZONE_CHANGED_NEW_AREA = { "Dungeons", HandleZoneChange },

    PLAYER_XP_UPDATE        = { "Experience", function()
        HandleXPUpdate()
        UpdateRestedTracking()
    end },
    CHAT_MSG_COMBAT_XP_GAIN = { "Kills", HandleKillXPMessage },
    CHAT_MSG_LOOT           = { "Loot", HandleLootMessage },

    QUEST_ACCEPTED  = { "Quests", function() AddStat("questsAccepted") end },
    QUEST_TURNED_IN = { "Quests", function(_, experienceReward, moneyReward)
        AddStat("questsCompleted")
        AddStat("xpFromQuests", experienceReward or 0)
        if moneyReward and moneyReward > 0 then
            AddStat("moneyFromQuests", moneyReward)
            pendingQuestMoney = pendingQuestMoney + moneyReward
        end
    end },

    PLAYER_LEVEL_UP = { "Level history", function(newLevel)
        HandleLevelUp(newLevel)
        UpdateCharacterInfo()
        characterDB.info.level = newLevel -- UnitLevel can lag behind this event
    end },

    TIME_PLAYED_MSG = { "Time played", function(totalPlayedSeconds, playedThisLevelSeconds)
        if IsSecret(totalPlayedSeconds) or IsSecret(playedThisLevelSeconds) then
            return
        end
        playedSecondsAtSync = totalPlayedSeconds
        playedThisLevelAtSync = playedThisLevelSeconds
        gameTimeAtSync = GetTime()
        -- Kept in the database so the "All chars" total includes this
        -- character while you play others.
        characterDB.lastPlayedSeconds = totalPlayedSeconds
    end },

    UNIT_SPELLCAST_SUCCEEDED = { "Spells", HandleSpellCastSucceeded },

    CHAT_MSG_WHISPER        = { "Chat", function() AddStat("whispersReceived") end },
    CHAT_MSG_WHISPER_INFORM = { "Chat", function() AddStat("whispersSent") end },
    CHAT_MSG_SAY   = { "Chat", function(_, senderName) if IsMessageFromPlayer(senderName) then AddStat("chatMessagesSent") end end },
    CHAT_MSG_YELL  = { "Chat", function(_, senderName) if IsMessageFromPlayer(senderName) then AddStat("chatMessagesSent") end end },
    CHAT_MSG_PARTY = { "Chat", function(_, senderName) if IsMessageFromPlayer(senderName) then AddStat("chatMessagesSent") end end },
    CHAT_MSG_GUILD = { "Chat", function(_, senderName) if IsMessageFromPlayer(senderName) then AddStat("chatMessagesSent") end end },
    CHAT_MSG_RAID  = { "Chat", function(_, senderName) if IsMessageFromPlayer(senderName) then AddStat("chatMessagesSent") end end },
}

local function OnPlayerLogin()
    playerGUID = UnitGUID("player")
    sessionStartTime = GetTime()
    lastKnownMoney = GetMoney()
    lastKnownXP = UnitXP("player") or 0
    lastKnownMaxXP = UnitXPMax("player") or 0
    wasOnTaxi = UnitOnTaxi("player") and true or false
    wasMounted = IsMounted() and true or false
    AddStat("logins")
    SetPeakStat("peakMoney", lastKnownMoney)
    lifeLog.RecordMoneyPoint(lastKnownMoney, true)
    if REQUEST_PLAYED_ON_LOGIN then
        RequestTimePlayed()
    end

    lastKnownRestedXP = GetXPExhaustion() or 0
    if IsSecret(lastKnownRestedXP) then
        lastKnownRestedXP = 0
    end
    isPlayerDead = ReadFlag(UnitIsDeadOrGhost("player")) or false
    RecordDayPlayed()
    RunSafely("Characters", UpdateCharacterInfo)

    -- Per-level stats start counting from the first login with this version.
    if not characterDB.levelStartSnapshot then
        TakeLevelSnapshot()
    end

    -- Starting points so that only changes from now on are counted.
    RunSafely("Consumables", function()
        bagItemCounts, bagItemNames = ScanBags()
    end)
    RunSafely("Skills", ScanSkillLines)
    RunSafely("Groups", ScanGroupMembers, false)

    -- Count jumps by hooking the jump function (runs after the real jump).
    RunSafely("Jumps", function()
        if lifeLog.areHooksInstalled then
            return
        end
        hooksecurefunc("JumpOrAscendStart", function()
            if not isTracking then return end
            AddStat("jumps")
        end)
    end)

    -- Count emotes (/dance, /wave, ...) by hooking the emote function.
    RunSafely("Emotes", function()
        if lifeLog.areHooksInstalled then
            return
        end
        lifeLog.areHooksInstalled = true
        hooksecurefunc("DoEmote", function(emoteToken)
            if not isTracking then return end
            RunSafely("Emotes", function()
                if emoteToken and not IsSecret(emoteToken) then
                    AddStat("emotesUsed")
                    IncrementNamedCounter(characterDB.emotesByName, "/" .. tostring(emoteToken):lower())
                end
            end)
        end)
    end)

    -- Register all tracked events, skipping any this client does not know.
    -- The combat log is never registered where it is restricted, because that
    -- is what triggers the "blocked from an action" popup.
    for eventName in pairs(EVENT_HANDLERS) do
        local shouldSkip = (eventName == "COMBAT_LOG_EVENT_UNFILTERED") and IS_COMBAT_LOG_RESTRICTED
        if not shouldSkip then
            pcall(eventFrame.RegisterEvent, eventFrame, eventName)
        end
    end
end


--------------------------------------------------------------------------------
-- Copying the standalone LifeLog addon's data (read only - never changed)
--------------------------------------------------------------------------------
local function DeepCopy(value, seenTables)
    if type(value) ~= "table" then
        return value
    end
    seenTables = seenTables or {}
    if seenTables[value] then
        return seenTables[value]
    end
    local copy = {}
    seenTables[value] = copy
    for key, innerValue in pairs(value) do
        copy[DeepCopy(key, seenTables)] = DeepCopy(innerValue, seenTables)
    end
    return copy
end

local function IsStandaloneLoaded()
    return Mentor.IsStandaloneAddonLoaded(STANDALONE_ADDON_NAME)
end

-- True when LifeLog's copy of a character is at least as far along as
-- Mentor's (more time played). Mentor's data is never replaced by an older
-- copy - for example if LifeLog is turned on again after Mentor has been
-- recording for a while.
local function IsStandaloneCopyNewer(standaloneDatabase, mentorDatabase)
    if type(mentorDatabase) ~= "table" or not next(mentorDatabase) then
        return true
    end
    local standalonePlayed = tonumber(standaloneDatabase.lastPlayedSeconds) or 0
    local mentorPlayed = tonumber(mentorDatabase.lastPlayedSeconds) or 0
    return standalonePlayed >= mentorPlayed
end

-- Copies LifeLog's data into Mentor's saved variables. Returns true when
-- there was something to copy.
function lifeLog.ImportFromStandalone()
    local standaloneCharacterDB = _G["LifeLogCharDB"]
    local standaloneAccountDB = _G["LifeLogAccountDB"]
    if type(standaloneCharacterDB) ~= "table" and type(standaloneAccountDB) ~= "table" then
        return false
    end
    MentorLifeLogAccountDB = MentorLifeLogAccountDB or {}
    MentorLifeLogAccountDB.characters = MentorLifeLogAccountDB.characters or {}
    if type(standaloneAccountDB) == "table" and type(standaloneAccountDB.characters) == "table" then
        for characterKey, storedDatabase in pairs(standaloneAccountDB.characters) do
            if type(storedDatabase) == "table"
                and IsStandaloneCopyNewer(storedDatabase, MentorLifeLogAccountDB.characters[characterKey]) then
                MentorLifeLogAccountDB.characters[characterKey] = DeepCopy(storedDatabase)
            end
        end
    end
    if type(standaloneCharacterDB) == "table" and next(standaloneCharacterDB)
        and IsStandaloneCopyNewer(standaloneCharacterDB, MentorLifeLogCharDB) then
        MentorLifeLogCharDB = DeepCopy(standaloneCharacterDB)
        MentorLifeLogAccountDB.characters[GetCharacterKey()] = MentorLifeLogCharDB
    end
    MentorLifeLogAccountDB.importedFromLifeLog = date("%Y-%m-%d %H:%M")
    return true
end

-- A character that never logged in with both addons: start from the copy
-- LifeLog kept of it in the account data (imported above), if there is one.
local function UseAccountCopyIfEmpty()
    if type(MentorLifeLogCharDB) == "table" and next(MentorLifeLogCharDB) then
        return
    end
    local accountCopy = MentorLifeLogAccountDB and MentorLifeLogAccountDB.characters
        and MentorLifeLogAccountDB.characters[GetCharacterKey()]
    if type(accountCopy) == "table" and next(accountCopy) then
        MentorLifeLogCharDB = accountCopy
    end
end

--------------------------------------------------------------------------------
-- Starting and stopping
--------------------------------------------------------------------------------
local isLoggedIn = false

local function IsWanted()
    return MentorDB and MentorDB.isLifeLogEnabled and not IsStandaloneLoaded()
end

local function StartTracking()
    if isTracking then
        return
    end
    UseAccountCopyIfEmpty()
    InitializeDatabase()
    BuildWindow()
    RestoreWindowPosition()
    isTracking = true
    RunSafely("Login", OnPlayerLogin)
    -- Recording starts at login, but the window stays closed until you open
    -- it (the "Life log" button in the Mentor window, or /mentor log).
    mainFrame:Hide()
end

-- Stopping only pauses: the events stay registered and are ignored while
-- isTracking is false. Unregistering them made the game block Mentor
-- ("blocked from an action only available to the Blizzard UI") - the combat
-- log event may not be touched by addons at all on Forever.
local hasStartedThisSession = false

local function StopTracking()
    if not isTracking then
        return
    end
    isTracking = false
    mainFrame:Hide()
end

-- Recording only starts while the game logs in (exactly like the standalone
-- LifeLog): starting it in the middle of a session made the game block Mentor
-- ("blocked from an action only available to the Blizzard UI"). Turning it on
-- mid-session therefore asks for a /reload; turning it off works at once.
local isStartAllowed = false     -- true only during the PLAYER_LOGIN handler
local hasAskedForReload = false

local function AskForReload()
    if hasAskedForReload then
        return
    end
    hasAskedForReload = true
    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs["MENTOR_LIFELOG_RELOAD"] = {
            text = "Mentor's Life log starts recording after a reload of the interface.\n\nReload now?",
            button1 = "Reload", button2 = "Later",
            OnAccept = function() ReloadUI() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("MENTOR_LIFELOG_RELOAD")
    else
        PrintMessage("it starts recording after /reload or your next login.")
    end
end

-- Called after login and whenever the setting changes.
function lifeLog.UpdateActivation()
    if not isLoggedIn then
        return
    end
    if IsWanted() then
        if isStartAllowed then
            StartTracking()
            hasStartedThisSession = true
        elseif not isTracking and hasStartedThisSession then
            isTracking = true            -- it was only paused: carry on without a reload
        elseif not isTracking then
            AskForReload()
        end
    else
        StopTracking()
    end
end

function lifeLog.GetCharacterDB()
    return characterDB
end

function lifeLog.IsTracking()
    return isTracking
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", function(self, eventName, ...)
    if eventName == "PLAYER_LOGIN" then
        isLoggedIn = true
        if IsStandaloneLoaded() and lifeLog.ImportFromStandalone() then
            -- You used LifeLog: keep its data, and switch Mentor's life log on
            -- so it carries on when LifeLog is disabled.
            if MentorDB and not MentorDB.isLifeLogImported then
                MentorDB.isLifeLogImported = true
                MentorDB.isLifeLogEnabled = true
                Mentor.Print("Life log: your LifeLog data has been copied into Mentor (LifeLog itself is not changed). "
                    .. "Disable the LifeLog addon and Mentor's life log carries on from where it was.")
            end
        end
        isStartAllowed = true
        lifeLog.UpdateActivation()
        isStartAllowed = false
        return
    elseif eventName == "PLAYER_LOGOUT" then
        -- Copy LifeLog's data once more, so this session is not lost.
        if IsStandaloneLoaded() then
            lifeLog.ImportFromStandalone()
        end
        return
    end
    if not isTracking then
        return
    end
    local handlerInfo = EVENT_HANDLERS[eventName]
    if handlerInfo then
        RunSafely(handlerInfo[1], handlerInfo[2], ...)
    end
end)

-- One OnUpdate drives both the sampling and the window refresh. It lives on
-- the always-visible event frame so tracking continues with the window closed.
local secondsSinceSample, secondsSinceRefresh, secondsSinceSettingCheck = 0, 0, 0
eventFrame:SetScript("OnUpdate", function(_, elapsedSinceLastFrame)
    secondsSinceSettingCheck = secondsSinceSettingCheck + elapsedSinceLastFrame
    if secondsSinceSettingCheck >= 1 then
        secondsSinceSettingCheck = 0
        lifeLog.UpdateActivation()
    end
    if not isTracking or not characterDB or not playerGUID then
        return
    end
    secondsSinceSample = secondsSinceSample + elapsedSinceLastFrame
    secondsSinceRefresh = secondsSinceRefresh + elapsedSinceLastFrame

    if secondsSinceSample >= TRACKING_TICK_SECONDS then
        RunSafely("Movement", SampleMovementAndTime, secondsSinceSample)
        RunSafely("Days played", RecordDayPlayed)
        -- Longest session = highest session length ever seen.
        local sessionLength = GetTime() - sessionStartTime
        if sessionLength > (characterDB.stats.longestSession or 0) then
            characterDB.stats.longestSession = sessionLength
        end
        -- Keep the saved /played up to date for the "All chars" column.
        local playedEstimate = GetPlayedSecondsEstimate()
        if playedEstimate then
            characterDB.lastPlayedSeconds = playedEstimate
        end
        secondsSinceSample = 0
    end
    if secondsSinceRefresh >= DISPLAY_REFRESH_SECONDS then
        secondsSinceRefresh = 0
        RefreshWindow()
        if lifeLog.RefreshGoldGraph then
            lifeLog.RefreshGoldGraph()
        end
    end
end)

--------------------------------------------------------------------------------
-- /mentor log [reset | wipe confirm | forget <name>]
--------------------------------------------------------------------------------
function lifeLog.HandleCommand(input)
    local command, argument = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()

    if not isTracking then
        if IsStandaloneLoaded() then
            PrintMessage("the LifeLog addon is loaded, so it is the one recording. Use /ll, or disable LifeLog to use Mentor's.")
        else
            PrintMessage("turn it on under Settings first (or /mentor lifelog on).")
        end
        return
    end
    if command == "" then
        characterDB.settings.isShown = not mainFrame:IsShown()
        mainFrame:SetShown(characterDB.settings.isShown)
    elseif command == "reset" then
        wipe(sessionStats)
        sessionStartTime = GetTime()
        RefreshWindow()
        PrintMessage("session stats reset.")
    elseif command == "wipe" then
        if argument:lower() == "confirm" then
            local savedSettings = characterDB.settings
            wipe(MentorLifeLogCharDB)
            InitializeDatabase()
            characterDB.settings = savedSettings
            TakeLevelSnapshot()
            UpdateCharacterInfo()
            wipe(sessionStats)
            RefreshWindow()
            PrintMessage("all lifetime stats for this character have been erased.")
        else
            PrintMessage("this erases ALL lifetime stats. Type /mentor log wipe confirm to do it.")
        end
    elseif command == "forget" then
        -- Removes a (deleted) character from the "All chars" totals.
        local characterName = argument
        if characterName == "" then
            PrintMessage("usage: /mentor log forget <character name>")
            return
        end
        local removedCount = 0
        for characterKey, storedDatabase in pairs(MentorLifeLogAccountDB.characters) do
            local storedName = (storedDatabase.info and storedDatabase.info.name) or characterKey:match("^[^-]+")
            if storedName and storedName:lower() == characterName:lower() and storedDatabase ~= characterDB then
                MentorLifeLogAccountDB.characters[characterKey] = nil
                removedCount = removedCount + 1
            end
        end
        if removedCount > 0 then
            PrintMessage(characterName .. " is removed from the All chars totals.")
            RefreshWindow()
        else
            PrintMessage("no other character called " .. characterName .. " found (you cannot forget the one you are playing).")
        end
    else
        PrintMessage("commands: /mentor log | log reset | log wipe confirm | log forget <name>")
    end
end

-- The "Life log" button in the Mentor window.
function lifeLog.ToggleWindow()
    if isTracking then
        lifeLog.HandleCommand("")
    elseif IsStandaloneLoaded() then
        PrintMessage("the LifeLog addon is loaded, so it is the one recording. Type /ll, or disable LifeLog to use Mentor's.")
    elseif MentorDB and not MentorDB.isLifeLogEnabled then
        MentorDB.isLifeLogEnabled = true       -- turned off earlier: switch it back on
        hasAskedForReload = false
        lifeLog.UpdateActivation()
    else
        hasAskedForReload = false
        AskForReload()
    end
end

function lifeLog.ResetWindowPosition()
    if isTracking then
        local settings = characterDB.settings
        settings.point, settings.relativePoint, settings.offsetX, settings.offsetY = "CENTER", "CENTER", 0, 0
        RestoreWindowPosition()
    end
end

--------------------------------------------------------------------------------
-- Mentor - Gear.lua
-- Scores items for your spec and compares them with what you are wearing.
--
--   score = sum of (stat amount x stat weight) using the weights in Data.lua
--   change = (new score - equipped score) / equipped score
--
-- Stats come from the game's item stat API, plus the "Equip:" lines in the
-- tooltip (crit, hit, spell damage, healing, mana per 5, ...). The tooltip is
-- also used to see if you can use the item (red text = cannot use).
--------------------------------------------------------------------------------

local _, Mentor = ...

local SIGNIFICANT_CHANGE_PERCENT = 1      -- smaller changes count as "about the same"
local RED_TEXT_THRESHOLD = 0.9            -- red channel above this ...
local NOT_RED_THRESHOLD = 0.2             -- ... and green/blue below this = red text

-- Item stat API keys -> internal stat names used by the weight tables.
local STAT_KEY_MAP = {
    ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI",
    ITEM_MOD_STAMINA_SHORT = "STA", ITEM_MOD_INTELLECT_SHORT = "INT",
    ITEM_MOD_SPIRIT_SHORT = "SPI", RESISTANCE0_NAME = "ARMOR",
    ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT",
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = "CRIT",
    ITEM_MOD_HIT_RATING_SHORT = "HIT", ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT",
    ITEM_MOD_HIT_RANGED_RATING_SHORT = "HIT",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = "SPELLCRIT", ITEM_MOD_HIT_SPELL_RATING_SHORT = "SPELLHIT",
    ITEM_MOD_SPELL_POWER_SHORT = "SPELLPOWER", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SPELLPOWER",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEALING",
    ITEM_MOD_POWER_REGEN0_SHORT = "MP5", ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEFENSE", ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY", ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE",
}

-- Stats given in percent on the item ("Improves your chance to get a
-- critical strike by 1.0%"). On WoW Forever the item stat API reports these
-- as RATINGS instead (14 for 1% crit), so they are always read from the
-- tooltip text and never from the API.
local PERCENT_STATS = {
    CRIT = true, HIT = true, SPELLCRIT = true, SPELLHIT = true,
    DODGE = true, PARRY = true, BLOCK = true,
}

-- Tooltip lines (English client, matched in lower case). Order matters: the
-- spell versions must be tried before the general ones. Numbers may have
-- decimals ("1.0%"). Lines that say "Decreases" or "Reduces" count negative.
local NUMBER = "(%d+%.?%d*)"
local TOOLTIP_STAT_PATTERNS = {
    { "critical strike with spells by " .. NUMBER .. "%%", "SPELLCRIT" },
    { "hit with spells by " .. NUMBER .. "%%", "SPELLHIT" },
    { "critical strike by " .. NUMBER .. "%%", "CRIT" },
    { "chance to hit by " .. NUMBER .. "%%", "HIT" },
    { "damage and healing done by magical spells and effects by up to (%d+)", "SPELLPOWER" },
    { "healing done by spells and effects by up to (%d+)", "HEALING" },
    { "(%d+) mana per 5 sec", "MP5" },
    { "%+(%d+) attack power", "AP" },
    { "increases attack power by (%d+)", "AP" },
    { "increased defense %+(%d+)", "DEFENSE" },
    { "dodge an attack by " .. NUMBER .. "%%", "DODGE" },
    { "parry an attack by " .. NUMBER .. "%%", "PARRY" },
    { "block attacks with a shield by " .. NUMBER .. "%%", "BLOCK" },
    { "%(" .. NUMBER .. " damage per second%)", "DPS" },
    { "^(%d+) armor$", "ARMOR" },
}
local NEGATIVE_WORDS = { "decreases", "reduces" }
-- Damage for one school only ("Shadow spells") is worth part of full spell damage.
local SINGLE_SCHOOL_PATTERN = "damage done by %a+ spells and effects by up to (%d+)"
local SINGLE_SCHOOL_FACTOR = 0.6

-- Equip slot -> inventory slot ids it can go into.
local SLOTS_BY_EQUIP_LOCATION = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
    INVTYPE_RELIC = { 18 },
}
local MAIN_HAND_SLOT, OFF_HAND_SLOT, RANGED_SLOT = 16, 17, 18
Mentor.SLOTS_BY_EQUIP_LOCATION = SLOTS_BY_EQUIP_LOCATION

--------------------------------------------------------------------------------
-- Item info helpers (work on old and new clients)
--------------------------------------------------------------------------------
local function GetItemInfoCompat(itemLink)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(itemLink)
    end
    return GetItemInfo(itemLink)
end

local function GetItemStatsCompat(itemLink)
    if C_Item and C_Item.GetItemStats then
        return C_Item.GetItemStats(itemLink)
    end
    if GetItemStats then
        return GetItemStats(itemLink)
    end
    return nil
end

function Mentor.GetEquipLocation(itemLink)
    local equipLocation = select(9, GetItemInfoCompat(itemLink))
    if equipLocation and equipLocation ~= "" then
        return equipLocation
    end
    local instantInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if instantInfo then
        local _, _, _, instantEquipLocation = instantInfo(itemLink)
        return instantEquipLocation
    end
    return nil
end

--------------------------------------------------------------------------------
-- Tooltip scanning
--------------------------------------------------------------------------------
local scanTooltip = CreateFrame("GameTooltip", "MentorScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
Mentor.scanTooltip = scanTooltip

local function IsRedColor(red, green, blue)
    return red and green and blue and red > RED_TEXT_THRESHOLD and green < NOT_RED_THRESHOLD and blue < NOT_RED_THRESHOLD
end

-- Modern clients (WoW Forever): tooltip data straight from C_TooltipInfo.
local function ReadTooltipLinesFromData(itemLink)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then
        return nil
    end
    local success, tooltipData = pcall(C_TooltipInfo.GetHyperlink, itemLink)
    if not success or type(tooltipData) ~= "table" or type(tooltipData.lines) ~= "table" then
        return nil
    end
    local tooltipLines = {}
    for _, lineData in ipairs(tooltipData.lines) do
        for _, side in ipairs({ "left", "right" }) do
            local lineText = lineData[side .. "Text"]
            local lineColor = lineData[side .. "Color"]
            if type(lineText) == "string" and lineText ~= "" and not (issecretvalue and issecretvalue(lineText)) then
                local isRed = false
                if type(lineColor) == "table" then
                    isRed = IsRedColor(lineColor.r, lineColor.g, lineColor.b)
                end
                -- Right-hand text only matters when it is red ("Plate" you cannot wear).
                if side == "left" or isRed then
                    table.insert(tooltipLines, { text = lineText, isRed = isRed })
                end
            end
        end
    end
    return tooltipLines
end

-- Returns a list of { text, isRed } for every tooltip line.
local function ReadTooltipLines(itemLink)
    local dataLines = ReadTooltipLinesFromData(itemLink)
    if dataLines then
        return dataLines
    end
    local tooltipLines = {}
    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    local success = pcall(scanTooltip.SetHyperlink, scanTooltip, itemLink)
    if not success then
        return tooltipLines
    end
    for lineIndex = 1, scanTooltip:NumLines() do
        local leftFontString = _G["MentorScanTooltipTextLeft" .. lineIndex]
        local lineText = leftFontString and leftFontString:GetText()
        if lineText and not (issecretvalue and issecretvalue(lineText)) then
            local red, green, blue = leftFontString:GetTextColor()
            local isRed = red and red > RED_TEXT_THRESHOLD and green < NOT_RED_THRESHOLD and blue < NOT_RED_THRESHOLD
            table.insert(tooltipLines, { text = lineText, isRed = isRed })
        end
        -- Right-hand red text (e.g. "Plate" when you cannot wear plate) also blocks use.
        local rightFontString = _G["MentorScanTooltipTextRight" .. lineIndex]
        local rightText = rightFontString and rightFontString:IsShown() and rightFontString:GetText()
        if rightText and not (issecretvalue and issecretvalue(rightText)) then
            local red, green, blue = rightFontString:GetTextColor()
            if red and red > RED_TEXT_THRESHOLD and green < NOT_RED_THRESHOLD and blue < NOT_RED_THRESHOLD then
                table.insert(tooltipLines, { text = rightText, isRed = true })
            end
        end
    end
    return tooltipLines
end

--------------------------------------------------------------------------------
-- Item analysis (cached per item link)
--------------------------------------------------------------------------------
local itemAnalysisCache = {}

-- The item's tooltip text exactly as Mentor reads it, for bug reports:
-- a list of { text = "...", isRed = true/false }.
function Mentor.GetItemTooltipLines(itemLink)
    local success, tooltipLines = pcall(ReadTooltipLines, itemLink)
    return success and tooltipLines or {}
end

function Mentor.ClearItemCache()
    wipe(itemAnalysisCache)
    if Mentor.ClearTotalScoreCache then
        Mentor.ClearTotalScoreCache()
    end
end

-- Returns { stats = {STR = 10, ...}, equipLocation, canUse, requiredLevel,
--           cannotUseReason } or nil while the item is not loaded yet.
function Mentor.AnalyzeItem(itemLink)
    if not itemLink then
        return nil
    end
    if itemAnalysisCache[itemLink] then
        return itemAnalysisCache[itemLink]
    end
    local itemName = GetItemInfoCompat(itemLink)
    if not itemName then
        return nil -- not cached by the client yet; GET_ITEM_INFO_RECEIVED will retry
    end

    local analysis = { stats = {}, equipLocation = Mentor.GetEquipLocation(itemLink), canUse = true }

    -- Not fully loaded yet: return nil WITHOUT caching, so it is analysed
    -- again once the data is there (otherwise an item could be stuck with
    -- no stats until you hover it).
    local tooltipLines = ReadTooltipLines(itemLink)
    local retrievingText = RETRIEVING_ITEM_INFO or "Retrieving item information"
    if #tooltipLines == 0 then
        return nil
    end
    for _, tooltipLine in ipairs(tooltipLines) do
        if tooltipLine.text:find(retrievingText, 1, true) then
            return nil
        end
    end
    -- The tooltip is complete, so an empty stat answer simply means "no stats".
    local apiStats = GetItemStatsCompat(itemLink) or {}

    for apiKey, amount in pairs(apiStats) do
        local statName = STAT_KEY_MAP[apiKey]
        if statName and not PERCENT_STATS[statName] and type(amount) == "number" then
            analysis.stats[statName] = (analysis.stats[statName] or 0) + amount
        end
    end

    for _, tooltipLine in ipairs(tooltipLines) do
        local lineText = tooltipLine.text
        if tooltipLine.isRed then
            local requiredLevel = tonumber(lineText:match("Requires Level (%d+)"))
            if requiredLevel then
                analysis.requiredLevel = requiredLevel
            else
                analysis.canUse = false
                analysis.cannotUseReason = lineText
            end
        end
        -- Percent stats always come from here; other stats only when the API
        -- did not report them, so nothing counts twice.
        local lowerLineText = lineText:lower()
        for _, patternInfo in ipairs(TOOLTIP_STAT_PATTERNS) do
            local pattern, statName = patternInfo[1], patternInfo[2]
            local amount = tonumber(lowerLineText:match(pattern))
            if amount then
                for _, negativeWord in ipairs(NEGATIVE_WORDS) do
                    if lowerLineText:find(negativeWord, 1, true) then
                        amount = -amount
                        break
                    end
                end
                if PERCENT_STATS[statName] then
                    analysis.stats[statName] = (analysis.stats[statName] or 0) + amount
                elseif analysis.stats[statName] == nil then
                    analysis.stats[statName] = amount
                end
                break
            end
        end
        local singleSchoolAmount = tonumber(lineText:match(SINGLE_SCHOOL_PATTERN))
        if singleSchoolAmount and not lineText:find("magical spells") then
            analysis.stats.SPELLPOWER = (analysis.stats.SPELLPOWER or 0) + singleSchoolAmount * SINGLE_SCHOOL_FACTOR
        end
    end

    -- Ranged weapons (bows, guns, wands) score their DPS with RANGED_DPS.
    local slotIds = SLOTS_BY_EQUIP_LOCATION[analysis.equipLocation or ""]
    if slotIds and slotIds[1] == RANGED_SLOT and analysis.stats.DPS then
        analysis.stats.RANGED_DPS = analysis.stats.DPS
        analysis.stats.DPS = nil
    end

    itemAnalysisCache[itemLink] = analysis
    return analysis
end

--------------------------------------------------------------------------------
-- Scoring and comparison
--------------------------------------------------------------------------------
-- The weights value percent stats (1% crit, 1% hit) at level 60. A percent
-- adds a share of your damage, and your damage grows with your level, while
-- +1 Agility or +1 Spell Power adds the same amount at any level. So at low
-- level percent stats are worth much less compared with flat stats (at level
-- 23, 6 Agility beats 1% crit for a hunter). Scale them by level / 60.
local MAX_LEVEL = 60
local MIN_PERCENT_STAT_FACTOR = 0.15

function Mentor.GetPercentStatFactor()
    local playerLevel = UnitLevel("player") or MAX_LEVEL
    if issecretvalue and issecretvalue(playerLevel) then
        playerLevel = MAX_LEVEL
    end
    return math.max(MIN_PERCENT_STAT_FACTOR, math.min(1, playerLevel / MAX_LEVEL))
end

function Mentor.ScoreItem(itemLink, weights)
    local analysis = Mentor.AnalyzeItem(itemLink)
    if not analysis then
        return nil
    end
    local score = 0
    local percentStatFactor = Mentor.GetPercentStatFactor()
    for statName, amount in pairs(analysis.stats) do
        local weight = weights[statName] or 0
        if PERCENT_STATS[statName] then
            weight = weight * percentStatFactor
        end
        score = score + amount * weight
    end
    return score
end

local function GetEquippedLink(slotId)
    return GetInventoryItemLink("player", slotId)
end

local function ScoreEquippedSlot(slotId, weights)
    local equippedLink = GetEquippedLink(slotId)
    if not equippedLink then
        return 0
    end
    return Mentor.ScoreItem(equippedLink, weights) or 0
end

-- Sum of the scores of everything you wear (shirt and tabard excluded).
-- Cached per weight table until the gear changes (ClearItemCache).
local EQUIPMENT_SLOT_IDS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local totalScoreCache = {}
function Mentor.GetTotalEquippedScore(weights)
    if totalScoreCache[weights] then
        return totalScoreCache[weights]
    end
    local totalScore = 0
    for _, slotId in ipairs(EQUIPMENT_SLOT_IDS) do
        totalScore = totalScore + ScoreEquippedSlot(slotId, weights)
    end
    totalScoreCache[weights] = totalScore
    return totalScore
end
function Mentor.ClearTotalScoreCache()
    wipe(totalScoreCache)
end

-- New item's stats minus the stats of the item(s) it replaces.
function Mentor.GetStatDifference(newStats, replacedSlots)
    local statDifference = {}
    for statName, amount in pairs(newStats) do
        statDifference[statName] = amount
    end
    for _, slotId in ipairs(replacedSlots or {}) do
        local equippedLink = GetEquippedLink(slotId)
        local equippedAnalysis = equippedLink and Mentor.AnalyzeItem(equippedLink)
        if equippedAnalysis then
            for statName, amount in pairs(equippedAnalysis.stats) do
                statDifference[statName] = (statDifference[statName] or 0) - amount
            end
        end
    end
    return statDifference
end

local function IsTwoHandWeapon(itemLink)
    return itemLink and Mentor.GetEquipLocation(itemLink) == "INVTYPE_2HWEAPON"
end

local function CanDualWieldNow()
    if CanDualWield then
        local success, canDualWield = pcall(CanDualWield)
        if success then
            return canDualWield and true or false
        end
    end
    return false
end

-- Compares an item with your gear for the given weights.
-- Returns a result table:
--   kind = "upgrade" | "downgrade" | "same" | "empty" | "cannotUse" | "notGear"
--        | "loading" | "equipped" | "needsOneHand"
--   percent, newScore, oldScore, replacedSlot, requiredLevel, reason
function Mentor.CompareItem(itemLink, weights)
    local analysis = Mentor.AnalyzeItem(itemLink)
    if not analysis then
        return { kind = "loading" }
    end
    local slotIds = SLOTS_BY_EQUIP_LOCATION[analysis.equipLocation or ""]
    if not slotIds then
        return { kind = "notGear" }
    end
    if not analysis.canUse then
        return { kind = "cannotUse", reason = analysis.cannotUseReason }
    end
    for _, slotId in ipairs(slotIds) do
        if GetEquippedLink(slotId) == itemLink then
            return { kind = "equipped" }
        end
    end

    local newScore = Mentor.ScoreItem(itemLink, weights) or 0
    local oldScore, replacedSlot, replacedSlots

    if analysis.equipLocation == "INVTYPE_2HWEAPON" then
        -- A two-hander replaces both hands.
        oldScore = ScoreEquippedSlot(MAIN_HAND_SLOT, weights) + ScoreEquippedSlot(OFF_HAND_SLOT, weights)
        replacedSlot, replacedSlots = MAIN_HAND_SLOT, { MAIN_HAND_SLOT, OFF_HAND_SLOT }
    elseif slotIds[1] == OFF_HAND_SLOT and IsTwoHandWeapon(GetEquippedLink(MAIN_HAND_SLOT)) then
        return { kind = "needsOneHand", newScore = newScore }
    else
        local candidateSlots = slotIds
        -- One-hand weapons only go in the off hand if you can dual wield.
        if analysis.equipLocation == "INVTYPE_WEAPON" and not CanDualWieldNow() then
            candidateSlots = { MAIN_HAND_SLOT }
        end
        -- Compare against the weaker of the possible slots (rings, trinkets, ...).
        for _, slotId in ipairs(candidateSlots) do
            local slotScore = ScoreEquippedSlot(slotId, weights)
            local slotsReplacedHere = { slotId }
            if slotId == MAIN_HAND_SLOT and IsTwoHandWeapon(GetEquippedLink(MAIN_HAND_SLOT)) then
                slotScore = slotScore + ScoreEquippedSlot(OFF_HAND_SLOT, weights)
                slotsReplacedHere = { MAIN_HAND_SLOT, OFF_HAND_SLOT }
            end
            if not oldScore or slotScore < oldScore then
                oldScore, replacedSlot, replacedSlots = slotScore, slotId, slotsReplacedHere
            end
        end
    end

    local result = {
        newScore = newScore, oldScore = oldScore, replacedSlot = replacedSlot,
        requiredLevel = (analysis.requiredLevel and analysis.requiredLevel > (UnitLevel("player") or 1))
            and analysis.requiredLevel or nil,
        statDifference = Mentor.GetStatDifference(analysis.stats, replacedSlots),
    }
    -- How much the swap changes your whole gear set (keeps small items honest).
    local totalEquippedScore = Mentor.GetTotalEquippedScore(weights)
    if totalEquippedScore > 0 then
        result.overallPercent = (newScore - oldScore) / totalEquippedScore * 100
    end
    if oldScore <= 0 then
        result.kind = newScore > 0 and "empty" or "same"
        return result
    end
    result.percent = (newScore - oldScore) / oldScore * 100
    if result.percent >= SIGNIFICANT_CHANGE_PERCENT then
        result.kind = "upgrade"
    elseif result.percent <= -SIGNIFICANT_CHANGE_PERCENT then
        result.kind = "downgrade"
    else
        result.kind = "same"
    end
    return result
end

--------------------------------------------------------------------------------
-- Upgrades in your bags
--------------------------------------------------------------------------------
local function GetBagSlotCount(bagIndex)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagIndex) or 0
    end
    return GetContainerNumSlots(bagIndex) or 0
end

local function GetBagItemLink(bagIndex, slotIndex)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bagIndex, slotIndex)
    end
    return GetContainerItemLink(bagIndex, slotIndex)
end

-- Returns a list of { itemLink, result } sorted by biggest upgrade first.
function Mentor.FindBagUpgrades(weights)
    local upgrades, seenLinks = {}, {}
    for bagIndex = 0, NUM_BAG_SLOTS or 4 do
        for slotIndex = 1, GetBagSlotCount(bagIndex) do
            local itemLink = GetBagItemLink(bagIndex, slotIndex)
            if itemLink and not seenLinks[itemLink] then
                seenLinks[itemLink] = true
                local result = Mentor.CompareItem(itemLink, weights)
                if (result.kind == "upgrade" or result.kind == "empty") and not result.requiredLevel then
                    table.insert(upgrades, { itemLink = itemLink, result = result })
                end
            end
        end
    end
    table.sort(upgrades, function(first, second)
        local firstPercent = first.result.kind == "empty" and math.huge or first.result.percent
        local secondPercent = second.result.kind == "empty" and math.huge or second.result.percent
        return firstPercent > secondPercent
    end)
    return upgrades
end

--------------------------------------------------------------------------------
-- Text for tooltips and chat
--------------------------------------------------------------------------------
-- The same stepped arrows as on bag items (Media\ArrowUp.tga / ArrowDown.tga:
-- white fill with a black outline, 32x64 with the arrow in pixels 4-28 x 14-50).
-- The game tints the white with the last three numbers (red, green, blue 0-255).
local ARROW_TEXTURE_FOLDER = "Interface\\AddOns\\Mentor\\Media\\"
local function MakeTooltipArrow(fileName, red, green, blue)
    return string.format("|T%s%s:15:10:0:0:32:64:4:28:14:50:%d:%d:%d|t", ARROW_TEXTURE_FOLDER, fileName, red, green, blue)
end
local ARROW_UP = MakeTooltipArrow("ArrowUp", 64, 255, 64)            -- green: better now
local ARROW_UP_LATER = MakeTooltipArrow("ArrowUp", 255, 217, 25)     -- yellow: better at a higher level
local ARROW_DOWN = MakeTooltipArrow("ArrowDown", 255, 64, 64)        -- red: worse
-- Red cross for items you cannot use (Media\Cross.tga, 32x32, white X).
local CROSS = string.format("|T%sCross:14:14:0:0:32:32:0:32:0:32:255:64:64|t", ARROW_TEXTURE_FOLDER)

-- "+250%" / "-40%". No upper limit: a big number on the item usually just
-- means the item you wear has almost nothing useful on it.
function Mentor.FormatPercentChange(percent)
    return string.format("%+.0f%%", percent)
end

-- The change to your whole gear set, with one decimal when it is small.
local function FormatTotalPercent(percent)
    if math.abs(percent) < 10 then
        return string.format("%+.1f%%", percent)
    end
    return string.format("%+.0f%%", percent)
end

-- Returns the line to show, plus r, g, b; or nil when nothing should be shown.
-- Size of an upgrade, judged by how much it changes your WHOLE gear set, so
-- one extra Spirit on a low-level cloak reads "Tiny", not "+40%".
-- Each entry: { percent of total gear score, label for better, label for worse }
local MAGNITUDE_STEPS = {
    { 2, "Tiny upgrade", "Slightly worse" },
    { 5, "Small upgrade", "Worse" },
    { 10, "Good upgrade", "Clearly worse" },
    { math.huge, "Big upgrade", "Much worse" },
}

local function GetMagnitudeLabel(result, isBetter)
    local sizePercent = math.abs(result.overallPercent or result.percent or 0)
    for _, magnitudeStep in ipairs(MAGNITUDE_STEPS) do
        if sizePercent < magnitudeStep[1] then
            return isBetter and magnitudeStep[2] or magnitudeStep[3]
        end
    end
    return isBetter and "Big upgrade" or "Much worse"
end

-- Two numbers, because they answer different questions:
--   total  how much your WHOLE gear set improves; this decides the label
--          (Tiny / Small / Good / Big), since that is what you feel in fights
--   item   this item compared with the one it replaces, which can be huge
--          (+300%) when the old item had almost nothing useful on it
-- specName (optional) is put in front:
--   "Affliction: ^ Tiny upgrade +1.2% total (item +300%)"
local function FormatBothPercents(result)
    if result.overallPercent then
        return string.format("%s total (item %s)", FormatTotalPercent(result.overallPercent), Mentor.FormatPercentChange(result.percent))
    end
    return Mentor.FormatPercentChange(result.percent)
end

function Mentor.DescribeComparison(result, specName)
    local prefix = specName and (specName .. ": ") or ""
    local levelText = result.requiredLevel and string.format(" - at level %d", result.requiredLevel) or ""
    if result.kind == "upgrade" then
        return string.format("%s%s %s %s%s", prefix, result.requiredLevel and ARROW_UP_LATER or ARROW_UP, GetMagnitudeLabel(result, true),
            FormatBothPercents(result), levelText), 0.25, 1.0, 0.25
    elseif result.kind == "downgrade" then
        return string.format("%s%s %s %s", prefix, ARROW_DOWN, GetMagnitudeLabel(result, false),
            FormatBothPercents(result)), 1.0, 0.35, 0.35
    elseif result.kind == "empty" then
        local totalText = result.overallPercent and (" " .. FormatTotalPercent(result.overallPercent) .. " total") or ""
        return prefix .. (result.requiredLevel and ARROW_UP_LATER or ARROW_UP) .. " Upgrade: fills an empty slot" .. totalText .. levelText, 0.25, 1.0, 0.25
    elseif result.kind == "same" then
        return prefix .. "About the same", 0.8, 0.8, 0.8
    elseif result.kind == "cannotUse" then
        local reasonText = result.reason and (" (" .. result.reason .. ")") or ""
        return CROSS .. " You cannot use this item" .. reasonText, 1.0, 0.35, 0.35
    elseif result.kind == "needsOneHand" then
        return "Off-hand: you are using a two-handed weapon", 0.8, 0.8, 0.8
    elseif result.kind == "equipped" then
        return "You are wearing this", 0.6, 0.8, 1.0
    end
    return nil
end

-- Readable names for the stat difference line.
local STAT_DISPLAY_NAMES = {
    STR = "Strength", AGI = "Agility", STA = "Stamina", INT = "Intellect", SPI = "Spirit",
    ARMOR = "Armor", AP = "Attack Power", RAP = "Ranged AP", CRIT = "% Crit", HIT = "% Hit",
    SPELLCRIT = "% Spell Crit", SPELLHIT = "% Spell Hit", SPELLPOWER = "Spell Damage",
    HEALING = "Healing", MP5 = "Mana/5s", DPS = "DPS", RANGED_DPS = "Ranged DPS",
    DEFENSE = "Defense", DODGE = "% Dodge", PARRY = "% Parry", BLOCK = "% Block", BLOCKVALUE = "Block Value",
}
-- Display order: damage stats first, armor last.
local STAT_DISPLAY_ORDER = {
    "DPS", "RANGED_DPS", "STR", "AGI", "AP", "RAP", "SPELLPOWER", "HEALING", "INT", "SPI", "STA",
    "CRIT", "HIT", "SPELLCRIT", "SPELLHIT", "MP5", "DEFENSE", "DODGE", "PARRY", "BLOCK", "BLOCKVALUE", "ARMOR",
}

-- "What is this stat?" - a few plain words per stat, for new players.
local STAT_EXPLANATIONS = {
    STR = "melee attack power; block for shields",
    AGI = "attack power, crit and dodge",
    STA = "more health",
    INT = "more mana and spell crit",
    SPI = "health and mana back between fights",
    ARMOR = "less physical damage taken",
    AP = "more melee damage",
    RAP = "more ranged damage",
    CRIT = "more hits do double damage",
    HIT = "fewer misses",
    SPELLCRIT = "more spells do extra damage",
    SPELLHIT = "fewer spell misses / resists",
    SPELLPOWER = "stronger damage spells",
    HEALING = "stronger heals",
    MP5 = "mana back every 5 seconds",
    DPS = "weapon damage - your biggest stat in melee",
    RANGED_DPS = "bow/gun/wand damage",
    DEFENSE = "harder to hit and crit (tanks)",
    DODGE = "avoid more melee hits",
    PARRY = "block more melee hits with your weapon",
    BLOCK = "block more hits with a shield",
    BLOCKVALUE = "how much a block stops",
}
Mentor.STAT_EXPLANATIONS = STAT_EXPLANATIONS

-- Explains a stat written as text ("Ranged weapon DPS", "Agility"), for the
-- stat priority pills. Returns nil when it is not recognised.
local STAT_KEYWORDS = {
    { "ranged weapon", "RANGED_DPS" }, { "wand", "RANGED_DPS" }, { "weapon", "DPS" }, { "spell crit", "SPELLCRIT" },
    { "spell hit", "SPELLHIT" }, { "ranged attack", "RAP" }, { "attack power", "AP" },
    { "strength", "STR" }, { "agility", "AGI" }, { "stamina", "STA" }, { "intellect", "INT" },
    { "spirit", "SPI" }, { "armor", "ARMOR" }, { "crit", "CRIT" }, { "hit", "HIT" },
    { "healing", "HEALING" }, { "damage", "SPELLPOWER" }, { "spell power", "SPELLPOWER" },
    { "mp5", "MP5" }, { "mana", "MP5" }, { "defense", "DEFENSE" }, { "dodge", "DODGE" },
    { "parry", "PARRY" }, { "block", "BLOCK" },
}
function Mentor.ExplainStatText(statText)
    local lowerText = (statText or ""):lower()
    for _, keywordInfo in ipairs(STAT_KEYWORDS) do
        if lowerText:find(keywordInfo[1], 1, true) then
            return STAT_EXPLANATIONS[keywordInfo[2]], keywordInfo[2]
        end
    end
    return nil
end

-- One entry per changed stat, for a vertical list in the tooltip:
-- { text = "+1% Crit  more hits do double damage", red, green, blue }
-- (green gains, red losses). With weights, stats that are worth nothing to
-- your spec say so ("does nothing for Beast Mastery") and are greyed out.
function Mentor.GetStatDifferenceLines(statDifference, weights, specName)
    local differenceLines = {}
    if not statDifference then
        return differenceLines
    end
    for _, statName in ipairs(STAT_DISPLAY_ORDER) do
        local amount = statDifference[statName]
        if amount and math.abs(amount) >= 0.05 then
            local amountText = (math.floor(amount) == amount) and string.format("%+d", amount) or string.format("%+.1f", amount)
            local isGain = amount > 0
            local displayName = STAT_DISPLAY_NAMES[statName]
            -- "+1% Crit" rather than "+1 % Crit".
            local statText = displayName:sub(1, 1) == "%" and (amountText .. displayName) or (amountText .. " " .. displayName)
            local isUseless = weights and (weights[statName] or 0) == 0
            local noteText
            if isUseless then
                noteText = "does nothing for " .. (specName or "your spec")
            else
                noteText = STAT_EXPLANATIONS[statName]
            end
            if isUseless then
                table.insert(differenceLines, {
                    text = statText .. (noteText and ("  |cff808080" .. noteText .. "|r") or ""),
                    red = 0.6, green = 0.6, blue = 0.6,
                })
            else
                table.insert(differenceLines, {
                    text = statText .. (noteText and ("  |cff808080" .. noteText .. "|r") or ""),
                    red = isGain and 0.25 or 1.0, green = isGain and 1.0 or 0.35, blue = isGain and 0.25 or 0.35,
                })
            end
        end
    end
    return differenceLines
end

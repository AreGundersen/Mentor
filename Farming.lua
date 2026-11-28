--------------------------------------------------------------------------------
-- Mentor - Farming.lua
-- "Worth farming" in the Journey tab: which herbs, ore, leather and cloth you
-- can gather at your level and skill sell best. Only shown when market data
-- is available (MarketPrices.lua).
--
-- Ranking: price per unit times how many the auction house sells a day,
-- with the daily sales capped at SALES_PER_DAY_CAP. Above that cap the
-- auction house takes everything you farm in a session, so only the price
-- matters; below it, a high price is worth little when nobody buys.
--------------------------------------------------------------------------------

local _, Mentor = ...

local farming = {}
Mentor.Farming = farming

local SALES_PER_DAY_CAP = 40
local MAX_SHORT_ITEMS = 2           -- named in the row itself
local MAX_TOOLTIP_ITEMS = 8         -- listed when you hover the row
local LEVELS_ABOVE_YOU = 3          -- zones up to this many levels above you count
local LEVELS_BELOW_LOOT_RANGE = 8   -- cloth / leather from mobs this far below their range still counts

-- Herbs and ore: { itemId, name, skill needed, lowest zone level where it grows }.
local GATHERED_NODES = {
    Herbalism = {
        { 2447, "Peacebloom", 1, 1 }, { 765, "Silverleaf", 1, 1 }, { 2449, "Earthroot", 15, 5 },
        { 785, "Mageroyal", 50, 10 }, { 2450, "Briarthorn", 70, 10 }, { 3820, "Stranglekelp", 85, 15 },
        { 2453, "Bruiseweed", 100, 15 }, { 3355, "Wild Steelbloom", 115, 20 }, { 3369, "Grave Moss", 120, 20 },
        { 3356, "Kingsblood", 125, 25 }, { 3357, "Liferoot", 150, 25 }, { 3818, "Fadeleaf", 160, 30 },
        { 3821, "Goldthorn", 170, 30 }, { 3358, "Khadgar's Whisker", 185, 30 }, { 3819, "Wintersbite", 195, 30 },
        { 8831, "Purple Lotus", 210, 35 }, { 4625, "Firebloom", 205, 40 }, { 8836, "Arthas' Tears", 220, 40 },
        { 8838, "Sungrass", 230, 40 }, { 8839, "Blindweed", 235, 40 }, { 8845, "Ghost Mushroom", 245, 40 },
        { 8846, "Gromsblood", 250, 45 }, { 13464, "Golden Sansam", 260, 45 }, { 13463, "Dreamfoil", 270, 50 },
        { 13465, "Mountain Silversage", 280, 50 }, { 13466, "Plaguebloom", 285, 52 }, { 13467, "Icecap", 290, 53 },
        { 13468, "Black Lotus", 300, 55 },
    },
    Mining = {
        { 2770, "Copper Ore", 1, 1 }, { 2771, "Tin Ore", 65, 10 }, { 2775, "Silver Ore", 75, 15 },
        { 2772, "Iron Ore", 125, 25 }, { 2776, "Gold Ore", 155, 30 }, { 3858, "Mithril Ore", 175, 35 },
        { 7911, "Truesilver Ore", 230, 40 }, { 10620, "Thorium Ore", 245, 45 }, { 11370, "Dark Iron Ore", 230, 50 },
    },
}

-- Cloth (everyone) and leather (Skinning): { itemId, name, lowest and highest
-- level of the mobs that drop it }.
local LOOTED_MATERIALS = {
    Cloth = {
        { 2589, "Linen Cloth", 1, 15 }, { 2592, "Wool Cloth", 15, 25 }, { 4306, "Silk Cloth", 25, 35 },
        { 4338, "Mageweave Cloth", 35, 50 }, { 14047, "Runecloth", 45, 60 },
    },
    Skinning = {
        { 2318, "Light Leather", 1, 20 }, { 783, "Light Hide", 5, 20 }, { 2319, "Medium Leather", 15, 30 },
        { 4232, "Medium Hide", 15, 30 }, { 4234, "Heavy Leather", 25, 40 }, { 4235, "Heavy Hide", 25, 40 },
        { 4304, "Thick Leather", 35, 50 }, { 8169, "Thick Hide", 35, 50 }, { 8170, "Rugged Leather", 45, 60 },
        { 8171, "Rugged Hide", 45, 60 }, { 15417, "Devilsaur Leather", 50, 60 },
    },
}

-- Skill in each profession you have: { Herbalism = 120, ... }.
local function GetProfessionSkills()
    local skills = {}
    local journey = Mentor.Journey
    for _, profession in ipairs(journey and journey.GetPlayerProfessions() or {}) do
        skills[profession.name] = profession.skill
    end
    return skills
end

-- What you can farm now: { { itemId, name, source } } (source = profession or "Cloth").
local function GetFarmableItems(playerLevel)
    local professionSkills = GetProfessionSkills()
    local farmableItems = {}
    for professionName, nodes in pairs(GATHERED_NODES) do
        local skill = professionSkills[professionName]
        for _, node in ipairs(skill and nodes or {}) do
            local itemId, itemName, skillNeeded, zoneLevel = node[1], node[2], node[3], node[4]
            if skillNeeded <= skill and zoneLevel <= playerLevel + LEVELS_ABOVE_YOU then
                table.insert(farmableItems, { itemId = itemId, name = itemName, source = professionName })
            end
        end
    end
    for sourceName, materials in pairs(LOOTED_MATERIALS) do
        if sourceName == "Cloth" or professionSkills[sourceName] then
            for _, material in ipairs(materials) do
                local itemId, itemName, lowestLevel, highestLevel = material[1], material[2], material[3], material[4]
                if lowestLevel <= playerLevel + LEVELS_ABOVE_YOU and highestLevel >= playerLevel - LEVELS_BELOW_LOOT_RANGE then
                    table.insert(farmableItems, { itemId = itemId, name = itemName, source = sourceName })
                end
            end
        end
    end
    return farmableItems
end

-- The farmable items with a market price, best first:
-- { { itemId, name, source, price, salesPerDay, score } }.
function farming.GetBestItems(playerLevel)
    local marketPrices = Mentor.MarketPrices
    if not (marketPrices and marketPrices.IsAvailable()) then
        return {}
    end
    local rankedItems = {}
    for _, item in ipairs(GetFarmableItems(playerLevel)) do
        local price = marketPrices.GetPrice(item.itemId)
        if price then
            item.price = price
            item.salesPerDay = marketPrices.GetSalesPerDay(item.itemId)
            -- Unknown sales: count it as selling a little, so it isn't lost
            -- but doesn't beat items we know sell well.
            local countedSales = math.min(item.salesPerDay or 1, SALES_PER_DAY_CAP)
            item.score = price * countedSales
            table.insert(rankedItems, item)
        end
    end
    table.sort(rankedItems, function(first, second) return first.score > second.score end)
    return rankedItems
end

-- For the Journey tab: short text and tooltip lines, or nil when there is no
-- market data (or nothing you can farm has a price yet).
function farming.GetSummary(playerLevel)
    local bestItems = farming.GetBestItems(playerLevel)
    if #bestItems == 0 then
        return nil
    end
    local marketPrices = Mentor.MarketPrices
    local FormatMoney = Mentor.FormatMoneyWithIcons or function(copper) return tostring(copper) end
    local shortParts, tooltipLines = {}, {}
    for itemIndex = 1, math.min(MAX_TOOLTIP_ITEMS, #bestItems) do
        local item = bestItems[itemIndex]
        local trendArrow, trendText = marketPrices.DescribeTrend(item.itemId)
        if itemIndex <= MAX_SHORT_ITEMS then
            table.insert(shortParts, string.format("%s %s%s", item.name, FormatMoney(item.price), trendArrow and (" " .. trendArrow) or ""))
        end
        local salesText = marketPrices.DescribeSales(item.salesPerDay)
        table.insert(tooltipLines, string.format("%s  %s each |cffa6a6a6(%s%s)|r%s", item.name, FormatMoney(item.price),
            item.source == "Cloth" and "cloth from humanoids" or item.source, salesText and (", " .. salesText) or "",
            trendArrow and (" " .. trendArrow) or ""))
        if trendText then
            table.insert(tooltipLines, "    " .. trendText)
        end
    end
    table.insert(tooltipLines, " ")
    table.insert(tooltipLines, "|cffa6a6a6What you can gather at your level and skill, best gold first (price and how many the auction house sells a day).|r")
    return "Best: " .. table.concat(shortParts, ", "), tooltipLines
end

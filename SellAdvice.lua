--------------------------------------------------------------------------------
-- Mentor - SellAdvice.lua
-- "Sell / disenchant" advice for gear you don't need (OFF by default; the
-- player turns it on under Settings). Needs the Auctionator addon for prices.
--
-- For an item that is not an upgrade, three values are compared:
--   vendor      what a vendor pays for it
--   auction     Auctionator's last seen price minus the auction house's 5% cut
--               (not possible for soulbound / bind-on-pickup items)
--   disenchant  the expected value of the dust, essences and shards it gives,
--               priced with Auctionator (estimated from the classic disenchant
--               tables - WoW Forever items follow the classic item levels)
-- The best one is only recommended when it is clearly better than the vendor
-- (MIN_GAIN_FACTOR and MIN_GAIN_COPPER), so small differences don't nag.
-- Works for every item with a price (gear, cloth, hides, herbs ...); for
-- stackable items the gain is counted for a full stack, since that is what
-- you put on the AH.
--------------------------------------------------------------------------------

local ADDON_NAME, Mentor = ...

local AUCTION_HOUSE_CUT       = 0.05      -- the auction house keeps 5% of the sale
local MIN_GAIN_FACTOR         = 1.25      -- best value must be 25% above the vendor price ...
local MIN_GAIN_COPPER         = 1000      -- ... and at least 10 silver more (per item, or per full stack)
local OLD_PRICE_DAYS          = 3         -- older Auctionator prices are flagged
local ITEM_CLASS_WEAPON       = 2
local ITEM_CLASS_ARMOR        = 4
local DISENCHANT_SPELL_ID     = 13262
local ENCHANTING_SKILL_LINE   = 333
local CACHE_SECONDS           = 30

local COIN_ICON = "Interface\\MoneyFrame\\UI-GoldIcon"
local DISENCHANT_ICON = "Interface\\Icons\\INV_Enchant_Disenchant"

local sellAdvice = {}
Mentor.SellAdvice = sellAdvice
sellAdvice.COIN_ICON = COIN_ICON
sellAdvice.DISENCHANT_ICON = DISENCHANT_ICON

--------------------------------------------------------------------------------
-- Disenchanting materials (item ids)
--------------------------------------------------------------------------------
local MATERIAL = {
    STRANGE_DUST = 10940, SOUL_DUST = 11083, VISION_DUST = 11137, DREAM_DUST = 11176, ILLUSION_DUST = 16204,
    LESSER_MAGIC = 10938, GREATER_MAGIC = 10939, LESSER_ASTRAL = 10998, GREATER_ASTRAL = 11082,
    LESSER_MYSTIC = 11134, GREATER_MYSTIC = 11135, LESSER_NETHER = 11174, GREATER_NETHER = 11175,
    LESSER_ETERNAL = 16202, GREATER_ETERNAL = 16203,
    SMALL_GLIMMERING = 10978, LARGE_GLIMMERING = 11084, SMALL_GLOWING = 11138, LARGE_GLOWING = 11139,
    SMALL_RADIANT = 11177, LARGE_RADIANT = 11178, SMALL_BRILLIANT = 14343, LARGE_BRILLIANT = 14344,
    NEXUS_CRYSTAL = 20725,
}

-- Uncommon (green) items by item level: { highest item level, dust, average
-- dust count, essence, average essence count, shard }. Armor gives dust 75%,
-- essence 20%, shard 5%; weapons swap dust and essence.
local UNCOMMON_TABLE = {
    { 15, "STRANGE_DUST", 1.5, "LESSER_MAGIC", 1.5, "SMALL_GLIMMERING" },
    { 20, "STRANGE_DUST", 2.5, "GREATER_MAGIC", 1.5, "SMALL_GLIMMERING" },
    { 25, "STRANGE_DUST", 5.0, "LESSER_ASTRAL", 1.5, "SMALL_GLIMMERING" },
    { 30, "SOUL_DUST", 1.5, "GREATER_ASTRAL", 1.5, "LARGE_GLIMMERING" },
    { 35, "SOUL_DUST", 3.5, "LESSER_MYSTIC", 1.5, "SMALL_GLOWING" },
    { 40, "VISION_DUST", 1.5, "GREATER_MYSTIC", 1.5, "LARGE_GLOWING" },
    { 45, "VISION_DUST", 3.5, "LESSER_NETHER", 1.5, "SMALL_RADIANT" },
    { 50, "DREAM_DUST", 1.5, "GREATER_NETHER", 1.5, "LARGE_RADIANT" },
    { 55, "DREAM_DUST", 3.5, "LESSER_ETERNAL", 1.5, "SMALL_BRILLIANT" },
    { 60, "ILLUSION_DUST", 1.5, "GREATER_ETERNAL", 1.5, "LARGE_BRILLIANT" },
    { 999, "ILLUSION_DUST", 3.5, "GREATER_ETERNAL", 2.5, "LARGE_BRILLIANT" },
}

-- Rare (blue) items give one shard (a few rare high items a Nexus Crystal).
local RARE_TABLE = {
    { 25, "SMALL_GLIMMERING" }, { 30, "LARGE_GLIMMERING" }, { 35, "SMALL_GLOWING" }, { 40, "LARGE_GLOWING" },
    { 45, "SMALL_RADIANT" }, { 50, "LARGE_RADIANT" }, { 55, "SMALL_BRILLIANT" }, { 999, "LARGE_BRILLIANT" },
}

-- Epic (purple) items give several shards, or Nexus Crystals from item level 56.
local EPIC_TABLE = {
    { 45, "SMALL_RADIANT", 3 }, { 50, "LARGE_RADIANT", 3 }, { 55, "LARGE_BRILLIANT", 3 }, { 999, "NEXUS_CRYSTAL", 1.5 },
}

local function FindRow(levelTable, itemLevel)
    for _, tableRow in ipairs(levelTable) do
        if itemLevel <= tableRow[1] then
            return tableRow
        end
    end
    return levelTable[#levelTable]
end

--------------------------------------------------------------------------------
-- Auctionator
--------------------------------------------------------------------------------
local function GetAuctionatorApi()
    return Auctionator and Auctionator.API and Auctionator.API.v1
end

function sellAdvice.IsAuctionatorLoaded()
    return GetAuctionatorApi() ~= nil
end

function sellAdvice.IsEnabled()
    return MentorDB and MentorDB.isSellAdviceEnabled == true and sellAdvice.IsAuctionatorLoaded()
end

-- Price per item in copper, or nil when Auctionator has never seen it.
local function GetAuctionPriceById(itemId)
    local api = GetAuctionatorApi()
    if not (api and api.GetAuctionPriceByItemID and itemId) then
        return nil
    end
    local success, price = pcall(api.GetAuctionPriceByItemID, ADDON_NAME, itemId)
    return success and type(price) == "number" and price > 0 and price or nil
end

local function GetAuctionPriceByLink(itemLink)
    local api = GetAuctionatorApi()
    if api and api.GetAuctionPriceByItemLink then
        local success, price = pcall(api.GetAuctionPriceByItemLink, ADDON_NAME, itemLink)
        if success and type(price) == "number" and price > 0 then
            return price
        end
    end
    return GetAuctionPriceById(tonumber(itemLink:match("item:(%d+)")))
end

-- Days since Auctionator last saw the item, or nil.
local function GetPriceAgeDays(itemLink)
    local api = GetAuctionatorApi()
    if not (api and api.GetAuctionAgeByItemLink) then
        return nil
    end
    local success, ageDays = pcall(api.GetAuctionAgeByItemLink, ADDON_NAME, itemLink)
    return success and type(ageDays) == "number" and ageDays or nil
end

-- Mentor caches advice for a while; a new Auctionator scan clears it.
local adviceCache = {}
local function ClearCache()
    adviceCache = {}
end
sellAdvice.ClearCache = ClearCache

function sellAdvice.RegisterForPriceUpdates()
    local api = GetAuctionatorApi()
    if api and api.RegisterForDBUpdate then
        pcall(api.RegisterForDBUpdate, ADDON_NAME, function()
            ClearCache()
            if Mentor.RequestRefresh then
                Mentor.RequestRefresh()
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- Disenchanting
--------------------------------------------------------------------------------
function sellAdvice.CanPlayerDisenchant()
    if IsPlayerSpell and IsPlayerSpell(DISENCHANT_SPELL_ID) then
        return true
    end
    if GetProfessions and GetProfessionInfo then
        for _, professionIndex in ipairs({ GetProfessions() }) do
            if professionIndex then
                local _, _, _, _, _, _, skillLine = GetProfessionInfo(professionIndex)
                if skillLine == ENCHANTING_SKILL_LINE then
                    return true
                end
            end
        end
    end
    return false
end

-- Expected value in copper of disenchanting one item, or nil.
-- quality: 2 uncommon, 3 rare, 4 epic. classId: weapon or armor.
local function EstimateDisenchantValue(quality, itemLevel, classId)
    if not (itemLevel and (classId == ITEM_CLASS_WEAPON or classId == ITEM_CLASS_ARMOR)) then
        return nil
    end
    local expectedMaterials = {}       -- { materialKey, expected count }
    if quality == 2 then
        local tableRow = FindRow(UNCOMMON_TABLE, itemLevel)
        local dustChance, essenceChance = 0.75, 0.20
        if classId == ITEM_CLASS_WEAPON then
            dustChance, essenceChance = 0.20, 0.75
        end
        table.insert(expectedMaterials, { tableRow[2], dustChance * tableRow[3] })
        table.insert(expectedMaterials, { tableRow[4], essenceChance * tableRow[5] })
        table.insert(expectedMaterials, { tableRow[6], 0.05 })
    elseif quality == 3 then
        table.insert(expectedMaterials, { FindRow(RARE_TABLE, itemLevel)[2], 1 })
    elseif quality == 4 then
        local tableRow = FindRow(EPIC_TABLE, itemLevel)
        table.insert(expectedMaterials, { tableRow[2], tableRow[3] })
    else
        return nil
    end
    local totalValue, isAnyPriceKnown = 0, false
    for _, expectedMaterial in ipairs(expectedMaterials) do
        local materialPrice = GetAuctionPriceById(MATERIAL[expectedMaterial[1]])
        if materialPrice then
            isAnyPriceKnown = true
            totalValue = totalValue + materialPrice * expectedMaterial[2]
        end
    end
    return isAnyPriceKnown and math.floor(totalValue) or nil
end

--------------------------------------------------------------------------------
-- The verdict
--------------------------------------------------------------------------------
local function GetItemDetails(itemLink)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local _, _, quality, itemLevel, _, _, _, stackSize, _, _, vendorPrice, classId = getInfo(itemLink)
    return quality, itemLevel, stackSize, vendorPrice, classId
end

-- isBound: true when this copy is soulbound (from the bag slot or the
-- tooltip). Bind-on-pickup items are always treated as bound.
-- Returns nil when there is nothing to say, otherwise:
--   { action = "auction" | "disenchant" | "vendor", vendorValue, auctionValue,
--     disenchantValue, canDisenchant, priceAgeDays }
function sellAdvice.Evaluate(itemLink, isBound)
    if not (sellAdvice.IsEnabled() and type(itemLink) == "string") then
        return nil
    end
    local cacheKey = itemLink .. (isBound and "#bound" or "")
    local cachedEntry = adviceCache[cacheKey]
    local now = GetTime and GetTime() or 0
    if cachedEntry and now - cachedEntry.time < CACHE_SECONDS then
        return cachedEntry.advice
    end

    local quality, itemLevel, stackSize, vendorPrice, classId = GetItemDetails(itemLink)
    if not quality then
        return nil      -- not loaded yet
    end
    stackSize = math.max(tonumber(stackSize) or 1, 1)
    if not isBound and Mentor.GetItemTooltipLines then
        for _, tooltipLine in ipairs(Mentor.GetItemTooltipLines(itemLink)) do
            local lineText = tooltipLine.text
            if lineText == (ITEM_BIND_ON_PICKUP or "Binds when picked up") or lineText == (ITEM_SOULBOUND or "Soulbound") then
                isBound = true
            end
        end
    end

    local vendorValue = vendorPrice or 0
    local auctionPrice = not isBound and GetAuctionPriceByLink(itemLink) or nil
    local auctionValue = auctionPrice and math.floor(auctionPrice * (1 - AUCTION_HOUSE_CUT)) or nil
    local disenchantValue = EstimateDisenchantValue(quality, itemLevel, classId)

    local advice
    if auctionValue or disenchantValue or vendorValue > 0 then
        advice = {
            isBound = isBound == true, hasNoAuctionPrice = not isBound and auctionValue == nil,
            vendorValue = vendorValue, auctionValue = auctionValue, disenchantValue = disenchantValue,
            canDisenchant = disenchantValue ~= nil and sellAdvice.CanPlayerDisenchant(),
            priceAgeDays = auctionValue and GetPriceAgeDays(itemLink) or nil,
            action = "vendor", isStackable = stackSize > 1,
        }
        local bestValue = vendorValue
        local function IsClearlyBetter(value)
            return value and value >= bestValue * MIN_GAIN_FACTOR and (value - vendorValue) * stackSize >= MIN_GAIN_COPPER
        end
        if IsClearlyBetter(auctionValue) then
            advice.action, bestValue = "auction", auctionValue
        end
        if IsClearlyBetter(disenchantValue) and disenchantValue > bestValue then
            advice.action = "disenchant"
        end
    end
    adviceCache[cacheKey] = { time = now, advice = advice }
    return advice
end

--------------------------------------------------------------------------------
-- Text for tooltips
--------------------------------------------------------------------------------
local function FormatMoney(copper)
    copper = math.floor(copper or 0)
    if GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    local gold, silver, copperLeft = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if gold > 0 then
        return string.format("%dg %ds", gold, silver)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, copperLeft)
    end
    return copperLeft .. "c"
end
sellAdvice.FormatMoney = FormatMoney

-- Icon for the bag corner: a coin for "sell on the AH", the disenchant icon
-- for "disenchant", nothing for "just vendor it".
function sellAdvice.GetActionIcon(advice)
    if advice and advice.action == "auction" then
        return COIN_ICON
    elseif advice and advice.action == "disenchant" then
        return DISENCHANT_ICON
    end
    return nil
end

-- Returns the tooltip line and its colour for an Evaluate() result.
-- isShort: only the advice, without the other values in grey.
function sellAdvice.Describe(advice, isShort)
    if not advice then
        return nil
    end
    local otherValues = {}
    if advice.action ~= "vendor" then
        table.insert(otherValues, "vendor " .. FormatMoney(advice.vendorValue))
    end
    if advice.action ~= "auction" and advice.auctionValue then
        table.insert(otherValues, "AH " .. FormatMoney(advice.auctionValue))
    end
    if advice.action ~= "disenchant" and advice.disenchantValue then
        table.insert(otherValues, "disenchant ~" .. FormatMoney(advice.disenchantValue))
    end
    if advice.action == "vendor" and advice.hasNoAuctionPrice then
        table.insert(otherValues, "no AH price yet")       -- Auctionator has not seen it
    elseif advice.action == "vendor" and advice.isBound and not advice.disenchantValue then
        table.insert(otherValues, "soulbound")             -- why the AH is not mentioned
    end
    if isShort then
        otherValues = {}
    end
    local otherText = #otherValues > 0 and (" |cffa6a6a6(" .. table.concat(otherValues, ", ") .. ")|r") or ""
    local ageText = (not isShort and advice.priceAgeDays and advice.priceAgeDays >= OLD_PRICE_DAYS)
        and (" |cffa6a6a6- AH prices " .. advice.priceAgeDays .. " days old|r") or ""

    local eachText = advice.isStackable and " each" or ""      -- stackable prices are per item
    if advice.action == "auction" then
        return "|T" .. COIN_ICON .. ":0|t Sell on the AH: " .. FormatMoney(advice.auctionValue) .. eachText .. otherText .. ageText, 1.0, 0.82, 0.0
    elseif advice.action == "disenchant" then
        local whoText = (advice.canDisenchant or isShort) and "" or " |cffa6a6a6- ask an enchanter|r"
        return "|T" .. DISENCHANT_ICON .. ":0|t Disenchant: ~" .. FormatMoney(advice.disenchantValue) .. otherText .. whoText, 0.75, 0.55, 1.0
    end
    return "Just vendor it: " .. FormatMoney(advice.vendorValue) .. eachText .. otherText, 0.75, 0.75, 0.75
end

-- Listen for new Auctionator scans once every addon has loaded.
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    sellAdvice.RegisterForPriceUpdates()
end)

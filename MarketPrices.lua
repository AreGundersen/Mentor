--------------------------------------------------------------------------------
-- Mentor - MarketPrices.lua
-- Optional market data from another addon. When an addon sets the global
-- table MentorPriceSource, Mentor uses it for:
--   - Worth selling (Professions.lua): market prices for every craft and
--     material, how many sell a day, and the expected price trend
--   - Worth farming (Farming.lua, Journey tab): what to gather for gold
-- Without it these extras stay hidden and Mentor works as before.
--
-- MentorPriceSource (every function is optional and may return nil):
--   GetMarketPrice(itemId)  -> copper per unit, days of data
--   GetSalesPerDay(itemId)  -> units the auction house sells a day
--   GetPriceTrend(itemId)   -> expected price change as a factor (1.06 = +6 %),
--                              over how many hours
-- Mentor calls them with pcall, so a broken source can't break Mentor.
--------------------------------------------------------------------------------

local _, Mentor = ...

local marketPrices = {}
Mentor.MarketPrices = marketPrices

local TREND_SHOWN_CHANGE = 0.05     -- a predicted change under 5 % is not worth mentioning
local DAYS_PER_WEEK = 7

local function GetSource()
    local source = _G.MentorPriceSource
    if type(source) == "table" then
        return source
    end
    return nil
end

-- Calls one of the source's functions; returns its first two values when the
-- first one is a usable number, otherwise nil.
local function CallSource(functionName, itemId)
    local source = GetSource()
    local sourceFunction = source and source[functionName]
    if type(sourceFunction) ~= "function" or not itemId then
        return nil
    end
    local isSuccess, firstValue, secondValue = pcall(sourceFunction, itemId)
    if not isSuccess or type(firstValue) ~= "number" then
        return nil
    end
    if issecretvalue and issecretvalue(firstValue) then
        return nil
    end
    -- NaN is the only value that is not equal to itself.
    if firstValue ~= firstValue then
        return nil
    end
    return firstValue, secondValue
end

function marketPrices.IsAvailable()
    return GetSource() ~= nil
end

-- Market price per unit in copper, or nil.
function marketPrices.GetPrice(itemId)
    local price = CallSource("GetMarketPrice", itemId)
    if price and price > 0 then
        return math.floor(price)
    end
    return nil
end

-- Units sold a day on the auction house, or nil when unknown.
function marketPrices.GetSalesPerDay(itemId)
    local salesPerDay = CallSource("GetSalesPerDay", itemId)
    if salesPerDay and salesPerDay >= 0 then
        return salesPerDay
    end
    return nil
end

-- Expected price change factor and hours, or nil.
function marketPrices.GetTrend(itemId)
    local changeFactor, hours = CallSource("GetPriceTrend", itemId)
    if changeFactor and changeFactor > 0 then
        return changeFactor, type(hours) == "number" and hours or nil
    end
    return nil
end

-- "sells about 12 a day", "sells about 3 a week", "rarely sells", or nil.
function marketPrices.DescribeSales(salesPerDay)
    if not salesPerDay then
        return nil
    end
    if salesPerDay >= 1 then
        return string.format("sells about %d a day", math.floor(salesPerDay + 0.5))
    end
    local salesPerWeek = salesPerDay * DAYS_PER_WEEK
    if salesPerWeek >= 1 then
        return string.format("sells about %d a week", math.floor(salesPerWeek + 0.5))
    end
    return "rarely sells"
end

-- A short colored arrow for lists ("|cff40ff40^|r" rising, red "v" falling),
-- and a sentence for tooltips, when the expected change is big enough.
function marketPrices.DescribeTrend(itemId)
    local changeFactor, hours = marketPrices.GetTrend(itemId)
    if not changeFactor or math.abs(changeFactor - 1) < TREND_SHOWN_CHANGE then
        return nil, nil
    end
    local percentChange = math.floor(math.abs(changeFactor - 1) * 100 + 0.5)
    local hoursText = hours and string.format(" in the next %d hours", hours) or " soon"
    if changeFactor < 1 then
        return "|cffff6666v|r", string.format("|cffff6666Price expected to drop about %d%%%s - sell soon.|r", percentChange, hoursText)
    end
    return "|cff40ff40^|r", string.format("|cff40ff40Price expected to rise about %d%%%s - it can pay to wait before selling.|r", percentChange, hoursText)
end

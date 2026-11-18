--------------------------------------------------------------------------------
-- Mentor - AuctionUpgrades.lua
-- Upgrades on the auction house. When you search the auction house (also
-- through Auctionator), Mentor checks the results and a small panel next to
-- the auction house window lists the ones that are better than what you
-- wear for the spec you play, best first, with their buyout price.
--
-- WoW Forever's auction house functions are not documented, so both kinds
-- are supported and guarded: the modern C_AuctionHouse browse results and
-- the classic GetAuctionItemInfo list.
--------------------------------------------------------------------------------

local _, Mentor = ...

local auctionUpgrades = {}
Mentor.AuctionUpgrades = auctionUpgrades

local MAX_ROWS = 6
local PANEL_WIDTH = 250
local PANEL_PADDING = 10
local ROW_HEIGHT = 20
local LEVELS_ABOVE_SHOWN = 3
local MENTOR_GOLD = { 1.00, 0.78, 0.10 }

local function IsEnabled()
    return not (MentorDB and MentorDB.areAuctionUpgradesEnabled == false)
end

local function GetWeights()
    local advice = Mentor.currentAdvice
    return advice and advice.specData and advice.specData.weights
end

--------------------------------------------------------------------------------
-- Reading the results: { { itemLink, buyoutPrice } }
--------------------------------------------------------------------------------
local function ReadModernResults()
    local results = {}
    if not (C_AuctionHouse and C_AuctionHouse.GetBrowseResults) then
        return results
    end
    local isSuccess, browseResults = pcall(C_AuctionHouse.GetBrowseResults)
    if not isSuccess or type(browseResults) ~= "table" then
        return results
    end
    for _, browseResult in ipairs(browseResults) do
        local itemKey = browseResult.itemKey
        if itemKey and itemKey.itemID then
            local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
            local _, itemLink = getItemInfo(itemKey.itemID)
            table.insert(results, { itemLink = itemLink or ("item:" .. itemKey.itemID), buyoutPrice = browseResult.minPrice })
        end
    end
    return results
end

local function ReadClassicResults()
    local results = {}
    if not (GetNumAuctionItems and GetAuctionItemLink and GetAuctionItemInfo) then
        return results
    end
    local auctionCount = GetNumAuctionItems("list") or 0
    for auctionIndex = 1, auctionCount do
        local itemLink = GetAuctionItemLink("list", auctionIndex)
        local buyoutPrice = select(10, GetAuctionItemInfo("list", auctionIndex))
        if itemLink and buyoutPrice and buyoutPrice > 0 then
            table.insert(results, { itemLink = itemLink, buyoutPrice = buyoutPrice })
        end
    end
    return results
end

-- The upgrades among the current results: best first, the cheapest auction
-- of each item, one per slot.
function auctionUpgrades.FindUpgrades(results)
    local weights = GetWeights()
    if not (weights and Mentor.CompareItem) then
        return {}
    end
    local playerLevel = UnitLevel("player") or 1
    local cheapestByLink, upgrades = {}, {}
    for _, auction in ipairs(results) do
        local known = cheapestByLink[auction.itemLink]
        if not known or (auction.buyoutPrice or 0) < (known.buyoutPrice or 0) then
            cheapestByLink[auction.itemLink] = auction
        end
    end
    for itemLink, auction in pairs(cheapestByLink) do
        local isSuccess, result = pcall(Mentor.CompareItem, itemLink, weights)
        if isSuccess and result and (result.kind == "upgrade" or result.kind == "empty")
            and (not result.requiredLevel or result.requiredLevel <= playerLevel + LEVELS_ABOVE_SHOWN) then
            table.insert(upgrades, { itemLink = itemLink, buyoutPrice = auction.buyoutPrice, result = result,
                gain = result.kind == "empty" and 100 or (result.overallPercent or result.percent or 0) })
        end
    end
    table.sort(upgrades, function(first, second) return first.gain > second.gain end)
    local bestPerSlot, usedSlots = {}, {}
    for _, upgrade in ipairs(upgrades) do
        local slotKey = upgrade.result.replacedSlot or upgrade.itemLink
        if not usedSlots[slotKey] then
            usedSlots[slotKey] = true
            table.insert(bestPerSlot, upgrade)
        end
    end
    return bestPerSlot
end

--------------------------------------------------------------------------------
-- The panel next to the auction house window
--------------------------------------------------------------------------------
local panel
local rows = {}
-- Every upgrade seen in searches since the auction house opened (cheapest
-- price kept), so searching for one of them doesn't empty the list.
local upgradesSeenThisVisit = {}

local function GetAuctionWindow()
    return _G.AuctionHouseFrame or _G.AuctionFrame
end

-- Searches the auction house for an item, so you can buy it: the modern
-- search bar (C_AuctionHouse) or the classic Browse tab, whichever exists.
function auctionUpgrades.SearchFor(itemLink)
    local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local itemName = getItemInfo and getItemInfo(itemLink)
    if not itemName then
        itemName = itemLink:match("%[(.-)%]")
    end
    if not itemName then
        return false
    end
    local searchBar = _G.AuctionHouseFrame and _G.AuctionHouseFrame.SearchBar
    if searchBar and searchBar.SearchBox then
        if _G.AuctionHouseFrame.SetDisplayMode and _G.AuctionHouseFrameDisplayMode then
            pcall(_G.AuctionHouseFrame.SetDisplayMode, _G.AuctionHouseFrame, _G.AuctionHouseFrameDisplayMode.Buy)
        end
        searchBar.SearchBox:SetText(itemName)
        if searchBar.StartSearch then
            searchBar:StartSearch()
            return true
        end
    end
    if _G.BrowseName and _G.AuctionFrameBrowse_Search then
        if _G.AuctionFrameTab1 and _G.AuctionFrameTab_OnClick then
            pcall(_G.AuctionFrameTab_OnClick, _G.AuctionFrameTab1)
        end
        _G.BrowseName:SetText(itemName)
        _G.AuctionFrameBrowse_Search()
        return true
    end
    if QueryAuctionItems then
        QueryAuctionItems(itemName)
        return true
    end
    return false
end

local function CreateRow(rowIndex)
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(PANEL_WIDTH - 2 * PANEL_PADDING, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", PANEL_PADDING, -PANEL_PADDING - 38 - (rowIndex - 1) * ROW_HEIGHT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT")
    row.priceText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.priceText:SetPoint("RIGHT")
    row.priceText:SetJustifyH("RIGHT")
    row.gainText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.gainText:SetPoint("RIGHT", row.priceText, "LEFT", -6, 0)
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.nameText:SetPoint("RIGHT", row.gainText, "LEFT", -4, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:AddLine("|cff66ccffMentor:|r click to find it on the auction house.", 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnClick", function(self)
        if self.itemLink and not auctionUpgrades.SearchFor(self.itemLink) then
            Mentor.Print("Could not search the auction house here - search for the name yourself.")
        end
    end)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[rowIndex] = row
    return row
end

local function CreatePanel(auctionWindow)
    panel = CreateFrame("Frame", "MentorAuctionUpgradesPanel", auctionWindow, BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetPoint("TOPLEFT", auctionWindow, "TOPRIGHT", 4, 0)
    if panel.SetBackdrop and Mentor.BOX_BACKDROP then
        panel:SetBackdrop(Mentor.BOX_BACKDROP)
        panel:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.9)
        -- Dark background: the backdrop texture is plain white until colored.
        panel:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    end
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", PANEL_PADDING, -PANEL_PADDING)
    panel.title:SetText("Mentor: upgrades here")
    panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.hint:SetPoint("TOPLEFT", PANEL_PADDING, -PANEL_PADDING - 18)
    panel.hint:SetWidth(PANEL_WIDTH - 2 * PANEL_PADDING)
    panel.hint:SetJustifyH("LEFT")
end

function auctionUpgrades.Refresh()
    local auctionWindow = GetAuctionWindow()
    if not (auctionWindow and auctionWindow:IsShown()) or not IsEnabled() then
        if panel then
            panel:Hide()
        end
        return
    end
    if not panel then
        CreatePanel(auctionWindow)
    end
    local results = ReadModernResults()
    if #results == 0 then
        results = ReadClassicResults()
    end
    for _, upgrade in ipairs(auctionUpgrades.FindUpgrades(results)) do
        local seenUpgrade = upgradesSeenThisVisit[upgrade.itemLink]
        if not seenUpgrade or (upgrade.buyoutPrice or 0) < (seenUpgrade.buyoutPrice or 0) then
            upgradesSeenThisVisit[upgrade.itemLink] = upgrade
        end
    end
    local seenList = {}
    for itemLink, seenUpgrade in pairs(upgradesSeenThisVisit) do
        table.insert(seenList, { itemLink = itemLink, buyoutPrice = seenUpgrade.buyoutPrice })
    end
    -- Rated again against what you wear now (you may have bought one).
    local upgrades = auctionUpgrades.FindUpgrades(seenList)
    if #results == 0 and #upgrades == 0 then
        panel.hint:SetText("Search for gear (your armor type, or a slot) and Mentor marks the upgrades.")
    elseif #upgrades == 0 then
        panel.hint:SetText(string.format("None of these %d results is an upgrade for you.", #results))
    else
        panel.hint:SetText("From your searches this visit, best first. Click one to find it.")
    end
    for rowIndex = 1, MAX_ROWS do
        local upgrade = upgrades[rowIndex]
        local row = rows[rowIndex]
        if upgrade then
            row = row or CreateRow(rowIndex)
            row.itemLink = upgrade.itemLink
            local getItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
            row.icon:SetTexture(getItemIcon and getItemIcon(upgrade.itemLink) or 134400)
            row.nameText:SetText(upgrade.itemLink)
            row.gainText:SetText(upgrade.result.kind == "empty" and "|cff40ff40new|r"
                or string.format("|cff40ff40+%.0f%%|r", upgrade.gain))
            row.priceText:SetText(Mentor.FormatMoneyWithIcons and Mentor.FormatMoneyWithIcons(upgrade.buyoutPrice or 0) or "")
            row:Show()
        elseif row then
            row:Hide()
        end
    end
    local shownRows = math.min(MAX_ROWS, #upgrades)
    panel:SetHeight(PANEL_PADDING * 2 + 38 + shownRows * ROW_HEIGHT + 4)
    panel:Show()
    if #upgrades > 0 and Mentor.Trace then
        Mentor.Trace("Auction", string.format("%d upgrades among %d results, best %s", #upgrades, #results, upgrades[1].itemLink))
    end
end

-- Results arrive in bursts (and item data one item at a time): refresh once, a moment later.
local isRefreshQueued = false
local function QueueRefresh()
    if isRefreshQueued or not C_Timer then
        return
    end
    isRefreshQueued = true
    C_Timer.After(0.3, function()
        isRefreshQueued = false
        pcall(auctionUpgrades.Refresh)
    end)
end

local eventFrame = CreateFrame("Frame")
for _, eventName in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
    "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_ITEM_LIST_UPDATE" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end
eventFrame:SetScript("OnEvent", function(_, eventName)
    if eventName == "AUCTION_HOUSE_CLOSED" then
        upgradesSeenThisVisit = {}
        if panel then
            panel:Hide()
        end
        return
    end
    QueueRefresh()
end)

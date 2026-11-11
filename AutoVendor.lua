--------------------------------------------------------------------------------
-- Mentor - AutoVendor.lua
-- "Auto vendor" (OFF by default; turn it on under Settings or with
-- /mentor vendor on). When you open a vendor:
--   * every grey (junk) item in your bags is sold
--   * all your gear is repaired (if the vendor can repair)
--   * one chat line says what was sold and what the repair cost
--   * with Sell advice on: Mentor lists the gear marked "Just vendor it"
--     (never upgrades for any of your specs, never tools or other bag items)
--     and asks before selling them
-- Hold SHIFT while opening the vendor to skip both for that visit.
-- A small Mentor window shows the value of the junk in your bags and the
-- lowest durability of your gear.
-- Built from Are's standalone AutoVendor addon, in the Mentor look.
--
--   /mentor vendor on|off   turn it on or off
-- Auto sell and auto repair each have an on/off switch in the window.
--   /mentor keep <item>     never sell this grey item (shift-click it in)
--   /mentor unkeep <item>   sell it again
--   /mentor keeplist        show the keep list
--------------------------------------------------------------------------------

local _, Mentor = ...

local POOR_ITEM_QUALITY = 0              -- grey items
local FIRST_BAG_INDEX = 0                -- backpack
local LAST_BAG_INDEX = NUM_BAG_SLOTS or 4
local ITEMS_SOLD_PER_BATCH = 10          -- selling too fast can make the server drop sales
local SECONDS_BETWEEN_BATCHES = 0.3
local REFRESH_INTERVAL_SECONDS = 1.0
local FIRST_EQUIPMENT_SLOT = 1           -- head
local LAST_EQUIPMENT_SLOT = 18           -- ranged
local DURABILITY_WARNING_PERCENT = 25    -- shown in red below this
local STANDALONE_ADDON_NAME = "AutoVendor"

-- Auto sell and auto repair can each be switched off in the window (both on by default).
local function IsAutoSellOn() return MentorDB and MentorDB.isAutoSellEnabled ~= false end
local function IsAutoRepairOn() return MentorDB and MentorDB.isAutoRepairEnabled ~= false end

local ROW_DEFINITIONS = {
    { key = "junkValue",  label = "Junk value" },
    { key = "junkCount",  label = "Junk items" },
    { key = "durability", label = "Lowest durability" },
    { key = "autoSell",   label = "Auto sell junk", toggle = {
        isOn = IsAutoSellOn,
        setOn = function(newValue) MentorDB.isAutoSellEnabled = newValue end,
        tooltip = "Sell grey items when you open a vendor" } },
    { key = "autoRepair", label = "Auto repair", toggle = {
        isOn = IsAutoRepairOn,
        setOn = function(newValue) MentorDB.isAutoRepairEnabled = newValue end,
        tooltip = "Repair all your gear when you open a vendor that can repair" } },
    { key = "sellAdviceItems", label = "Sell \"vendor it\" items", toggle = {
        isOn = function() return MentorDB and MentorDB.isSellVendorItemsEnabled ~= false end,
        setOn = function(newValue) MentorDB.isSellVendorItemsEnabled = newValue end,
        tooltip = "Also sell what Sell advice marks \"Just vendor it\". Mentor lists them and asks first. Needs Sell advice." } },
}

local autoVendor = {}
Mentor.AutoVendor = autoVendor

local isMerchantOpen = false
local sellQueue = {}          -- { bagIndex, slotIndex, itemLink, stackCount, totalPrice }
local soldItemCount, soldCopperTotal = 0, 0

local function IsActive()
    return MentorDB and MentorDB.isAutoVendorEnabled and not Mentor.IsStandaloneAddonLoaded(STANDALONE_ADDON_NAME)
end

local function GetKeptItemIds()
    MentorDB.keptJunkItemIds = MentorDB.keptJunkItemIds or {}
    return MentorDB.keptJunkItemIds
end

--------------------------------------------------------------------------------
-- Bags
--------------------------------------------------------------------------------
local function GetBagSlotCount(bagIndex)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagIndex) or 0
    end
    return GetContainerNumSlots(bagIndex) or 0
end

-- itemId, itemLink, stackCount, quality, isLocked, isBound for a bag slot (or nil).
local function GetBagSlotItem(bagIndex, slotIndex)
    if C_Container and C_Container.GetContainerItemInfo then
        local slotInfo = C_Container.GetContainerItemInfo(bagIndex, slotIndex)
        if not slotInfo then
            return nil
        end
        return slotInfo.itemID, slotInfo.hyperlink, slotInfo.stackCount, slotInfo.quality, slotInfo.isLocked, slotInfo.isBound
    end
    local _, stackCount, isLocked, quality, _, _, itemLink, _, _, itemId = GetContainerItemInfo(bagIndex, slotIndex)
    if not itemLink then
        return nil
    end
    return itemId, itemLink, stackCount, quality, isLocked
end

local function UseBagSlotItem(bagIndex, slotIndex)
    if C_Container and C_Container.UseContainerItem then
        C_Container.UseContainerItem(bagIndex, slotIndex)
    else
        UseContainerItem(bagIndex, slotIndex)
    end
end

-- Vendor price per item in copper (0 = unknown or cannot be sold).
local function GetVendorPrice(itemLink)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    return select(11, getInfo(itemLink)) or 0
end

-- Calls handleJunkItem(bagIndex, slotIndex, itemLink, stackCount, totalPrice)
-- for every grey item that can be sold and is not on the keep list.
local function ForEachJunkItem(handleJunkItem)
    local keptItemIds = GetKeptItemIds()
    for bagIndex = FIRST_BAG_INDEX, LAST_BAG_INDEX do
        for slotIndex = 1, GetBagSlotCount(bagIndex) do
            local itemId, itemLink, stackCount, quality, isLocked = GetBagSlotItem(bagIndex, slotIndex)
            if itemLink and quality == POOR_ITEM_QUALITY and not isLocked and not keptItemIds[itemId] then
                local pricePerItem = GetVendorPrice(itemLink)
                if pricePerItem > 0 then
                    handleJunkItem(bagIndex, slotIndex, itemLink, stackCount or 1, pricePerItem * (stackCount or 1))
                end
            end
        end
    end
end

function autoVendor.GetJunkValueAndCount()
    local junkValue, junkCount = 0, 0
    ForEachJunkItem(function(_, _, _, stackCount, totalPrice)
        junkValue = junkValue + totalPrice
        junkCount = junkCount + stackCount
    end)
    return junkValue, junkCount
end

-- Lowest durability (0-100) of your equipped gear, or nil.
local function GetLowestDurabilityPercent()
    local lowestPercent
    for inventorySlot = FIRST_EQUIPMENT_SLOT, LAST_EQUIPMENT_SLOT do
        local currentDurability, maxDurability = GetInventoryItemDurability(inventorySlot)
        if currentDurability and maxDurability and maxDurability > 0 then
            local slotPercent = currentDurability / maxDurability * 100
            if not lowestPercent or slotPercent < lowestPercent then
                lowestPercent = slotPercent
            end
        end
    end
    return lowestPercent and math.floor(lowestPercent + 0.5)
end

--------------------------------------------------------------------------------
-- Selling (in small batches so the server keeps up) and repairing
--------------------------------------------------------------------------------
local function FinishSelling()
    if soldItemCount > 0 then
        Mentor.Print(string.format("Sold %d item%s for %s.", soldItemCount, soldItemCount == 1 and "" or "s",
            Mentor.FormatMoneyWithIcons(soldCopperTotal)))
    end
    soldItemCount, soldCopperTotal = 0, 0
end

local function SellNextBatch()
    if not isMerchantOpen then
        wipe(sellQueue)
        FinishSelling()
        return
    end
    local itemsSoldThisBatch = 0
    while #sellQueue > 0 and itemsSoldThisBatch < ITEMS_SOLD_PER_BATCH do
        local queuedItem = table.remove(sellQueue, 1)
        -- The item may have moved since the queue was built: check the slot again.
        local _, currentLink = GetBagSlotItem(queuedItem.bagIndex, queuedItem.slotIndex)
        if currentLink == queuedItem.itemLink then
            UseBagSlotItem(queuedItem.bagIndex, queuedItem.slotIndex)
            soldItemCount = soldItemCount + queuedItem.stackCount
            soldCopperTotal = soldCopperTotal + queuedItem.totalPrice
            itemsSoldThisBatch = itemsSoldThisBatch + 1
        end
    end
    if #sellQueue > 0 then
        C_Timer.After(SECONDS_BETWEEN_BATCHES, SellNextBatch)
    else
        FinishSelling()
    end
end

local function SellAllJunk()
    wipe(sellQueue)
    ForEachJunkItem(function(bagIndex, slotIndex, itemLink, stackCount, totalPrice)
        table.insert(sellQueue, { bagIndex = bagIndex, slotIndex = slotIndex, itemLink = itemLink,
            stackCount = stackCount, totalPrice = totalPrice })
    end)
    if #sellQueue > 0 then
        SellNextBatch()
    end
end

--------------------------------------------------------------------------------
-- "Just vendor it" items from Sell advice (asks first)
--------------------------------------------------------------------------------
local pendingVendorItems = {}

-- True when the item is an upgrade for one of your specs - never sold.
local function IsUpgradeForAnySpec(itemLink)
    local advice = Mentor.currentAdvice
    if not (advice and advice.classData and Mentor.CompareItem) then
        return true        -- unknown: better safe than sold
    end
    for _, specData in ipairs(advice.classData.specs) do
        local success, comparison = pcall(Mentor.CompareItem, itemLink, specData.weights)
        if not success or comparison.kind == "upgrade" or comparison.kind == "empty" then
            return true
        end
    end
    return false
end

-- Only gear is offered (things you can wear that are no upgrade): tools,
-- reagents and other bag items are never sold this way.
local function IsWearableGear(itemLink)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local equipLocation = select(9, getInfo(itemLink))
    return equipLocation ~= nil and equipLocation ~= "" and equipLocation ~= "INVTYPE_NON_EQUIP_IGNORE"
        and equipLocation ~= "INVTYPE_BAG" and equipLocation ~= "INVTYPE_AMMO" and equipLocation ~= "INVTYPE_QUIVER"
end

-- Bag items (gear, not grey, not kept) that Sell advice says to vendor.
local function FindVendorAdviceItems()
    local foundItems = {}
    local sellAdvice = Mentor.SellAdvice
    if not (sellAdvice and sellAdvice.IsEnabled()) then
        return foundItems
    end
    local keptItemIds = GetKeptItemIds()
    for bagIndex = FIRST_BAG_INDEX, LAST_BAG_INDEX do
        for slotIndex = 1, GetBagSlotCount(bagIndex) do
            local itemId, itemLink, stackCount, quality, isLocked, isBound = GetBagSlotItem(bagIndex, slotIndex)
            if itemLink and quality and quality > POOR_ITEM_QUALITY and not isLocked and not keptItemIds[itemId]
                and IsWearableGear(itemLink) then
                local success, itemAdvice = pcall(sellAdvice.Evaluate, itemLink, isBound)
                if success and itemAdvice and itemAdvice.action == "vendor" and (itemAdvice.vendorValue or 0) > 0
                    and not IsUpgradeForAnySpec(itemLink) then
                    table.insert(foundItems, { bagIndex = bagIndex, slotIndex = slotIndex, itemLink = itemLink,
                        stackCount = stackCount or 1, totalPrice = itemAdvice.vendorValue * (stackCount or 1) })
                end
            end
        end
    end
    return foundItems
end

-- The "sell these?" window: one row per item with its icon, name in its
-- quality colour, the price with coin icons and a check box (ticked = sell).
-- Hovering a row shows the item tooltip. "Sell" sells the ticked items.
local SELL_WINDOW_WIDTH = 320
local SELL_ROW_HEIGHT = 28
local MAX_SELL_ROWS = 10
local MENTOR_GOLD = { 1.00, 0.78, 0.10 }
local sellWindow

local function UpdateSellWindowTotal()
    local totalPrice, tickedCount = 0, 0
    for _, pendingItem in ipairs(pendingVendorItems) do
        if pendingItem.isTicked then
            totalPrice = totalPrice + pendingItem.totalPrice
            tickedCount = tickedCount + 1
        end
    end
    sellWindow.totalText:SetText(string.format("%d item%s: %s", tickedCount, tickedCount == 1 and "" or "s",
        Mentor.FormatMoneyWithIcons(totalPrice)))
    sellWindow.sellButton:SetEnabled(tickedCount > 0)
end

local function BuildSellWindow()
    sellWindow = CreateFrame("Frame", "MentorSellVendorItemsWindow", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    sellWindow:SetWidth(SELL_WINDOW_WIDTH)
    sellWindow:SetFrameStrata("DIALOG")
    sellWindow:SetClampedToScreen(true)
    if sellWindow.SetBackdrop then
        sellWindow:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        sellWindow:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.9)
    end
    local logo = sellWindow:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\Mentor\\Media\\Logo")
    logo:SetSize(18, 18)
    logo:SetPoint("TOPLEFT", 10, -9)
    sellWindow.title = sellWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sellWindow.title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    sellWindow.title:SetText("Only worth vendoring")
    sellWindow.hint = sellWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sellWindow.hint:SetPoint("TOPLEFT", 12, -32)
    sellWindow.hint:SetWidth(SELL_WINDOW_WIDTH - 24)
    sellWindow.hint:SetJustifyH("LEFT")
    sellWindow.hint:SetText("|cffa6a6a6Not an upgrade for any of your specs, and not worth more on the AH. Untick what you want to keep.|r")

    sellWindow.rows = {}
    for rowIndex = 1, MAX_SELL_ROWS do
        local row = CreateFrame("Button", nil, sellWindow, BackdropTemplateMixin and "BackdropTemplate" or nil)
        row:SetSize(SELL_WINDOW_WIDTH - 20, SELL_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 10, -56 - (rowIndex - 1) * (SELL_ROW_HEIGHT + 2))
        if row.SetBackdrop and Mentor.BOX_BACKDROP then
            row:SetBackdrop(Mentor.BOX_BACKDROP)
            row:SetBackdropColor(0, 0, 0, 0.35)
            row:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.2)
        end
        row.checkBox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.checkBox:SetSize(22, 22)
        row.checkBox:SetPoint("LEFT", 2, 0)
        row.iconHolder = CreateFrame("Frame", nil, row)
        row.iconHolder:SetSize(SELL_ROW_HEIGHT - 6, SELL_ROW_HEIGHT - 6)
        row.iconHolder:SetPoint("LEFT", row.checkBox, "RIGHT", 2, 0)
        row.icon = row.iconHolder:CreateTexture(nil, "ARTWORK")
        row.icon:SetAllPoints()
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.iconEdge = Mentor.AddRoundedBorder and Mentor.AddRoundedBorder(row.iconHolder, 0.5, 0.5, 0.5, 0.9, 8)
        row.countText = row.iconHolder:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        row.countText:SetPoint("BOTTOMRIGHT", 1, 0)
        row.priceText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.priceText:SetPoint("RIGHT", -8, 0)
        row.priceText:SetJustifyH("RIGHT")
        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.nameText:SetPoint("LEFT", row.iconHolder, "RIGHT", 8, 0)
        row.nameText:SetPoint("RIGHT", row.priceText, "LEFT", -6, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetWordWrap(false)
        local function ToggleRow()
            if row.pendingItem then
                row.pendingItem.isTicked = not row.pendingItem.isTicked
                row.checkBox:SetChecked(row.pendingItem.isTicked)
                row:SetAlpha(row.pendingItem.isTicked and 1 or 0.55)
                UpdateSellWindowTotal()
            end
        end
        row.checkBox:SetScript("OnClick", ToggleRow)
        row:SetScript("OnClick", ToggleRow)
        row:SetScript("OnEnter", function(self)
            if self.pendingItem then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.pendingItem.itemLink)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        sellWindow.rows[rowIndex] = row
    end

    sellWindow.totalText = sellWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sellWindow.moreText = sellWindow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sellWindow.sellButton = CreateFrame("Button", nil, sellWindow, "UIPanelButtonTemplate")
    sellWindow.sellButton:SetSize(90, 22)
    sellWindow.sellButton:SetText("Sell")
    sellWindow.sellButton:SetScript("OnClick", function()
        local wasQueueEmpty = #sellQueue == 0
        for _, pendingItem in ipairs(pendingVendorItems) do
            if pendingItem.isTicked then
                table.insert(sellQueue, pendingItem)
            end
        end
        wipe(pendingVendorItems)
        sellWindow:Hide()
        if wasQueueEmpty and #sellQueue > 0 then
            SellNextBatch()
        end
    end)
    sellWindow.keepButton = CreateFrame("Button", nil, sellWindow, "UIPanelButtonTemplate")
    sellWindow.keepButton:SetSize(90, 22)
    sellWindow.keepButton:SetText("Keep all")
    sellWindow.keepButton:SetScript("OnClick", function()
        wipe(pendingVendorItems)
        sellWindow:Hide()
    end)
    sellWindow:Hide()
end

local function ShowSellWindow()
    if not sellWindow then
        BuildSellWindow()
    end
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local shownRows = math.min(#pendingVendorItems, MAX_SELL_ROWS)
    for rowIndex, row in ipairs(sellWindow.rows) do
        local pendingItem = pendingVendorItems[rowIndex]
        row.pendingItem = pendingItem
        if pendingItem then
            local itemName, _, itemQuality, _, _, _, _, _, _, itemIcon = getInfo(pendingItem.itemLink)
            local qualityColor = ITEM_QUALITY_COLORS and itemQuality and ITEM_QUALITY_COLORS[itemQuality]
            row.icon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.nameText:SetText((qualityColor and qualityColor.hex or "|cffffffff") .. (itemName or pendingItem.itemLink) .. "|r")
            row.countText:SetText((pendingItem.stackCount or 1) > 1 and pendingItem.stackCount or "")
            row.priceText:SetText(Mentor.FormatMoneyWithIcons(pendingItem.totalPrice))
            if row.iconEdge and row.iconEdge.SetBackdropBorderColor and qualityColor then
                row.iconEdge:SetBackdropBorderColor(qualityColor.r, qualityColor.g, qualityColor.b, 1)
            end
            row.checkBox:SetChecked(pendingItem.isTicked)
            row:SetAlpha(pendingItem.isTicked and 1 or 0.55)
            row:Show()
        else
            row:Hide()
        end
    end
    -- Items beyond the first rows are sold too when ticked (they are all ticked).
    local listBottom = 56 + shownRows * (SELL_ROW_HEIGHT + 2)
    sellWindow.moreText:ClearAllPoints()
    sellWindow.moreText:SetPoint("TOPLEFT", 14, -listBottom - 2)
    if #pendingVendorItems > MAX_SELL_ROWS then
        sellWindow.moreText:SetText(string.format("+ %d more items", #pendingVendorItems - MAX_SELL_ROWS))
        listBottom = listBottom + 16
    else
        sellWindow.moreText:SetText("")
    end
    sellWindow.totalText:ClearAllPoints()
    sellWindow.totalText:SetPoint("TOPLEFT", 14, -listBottom - 8)
    sellWindow.keepButton:ClearAllPoints()
    sellWindow.keepButton:SetPoint("TOPRIGHT", -10, -listBottom - 30)
    sellWindow.sellButton:ClearAllPoints()
    sellWindow.sellButton:SetPoint("RIGHT", sellWindow.keepButton, "LEFT", -6, 0)
    sellWindow:SetHeight(listBottom + 62)
    UpdateSellWindowTotal()

    -- Next to the vendor window, or in the middle when it is not there.
    sellWindow:ClearAllPoints()
    if MerchantFrame and MerchantFrame:IsShown() then
        sellWindow:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 8, 0)
    else
        sellWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    end
    sellWindow:Show()
end

local function OfferToSellVendorAdviceItems()
    if MentorDB.isSellVendorItemsEnabled == false then
        return
    end
    pendingVendorItems = FindVendorAdviceItems()
    if #pendingVendorItems == 0 then
        return
    end
    for _, pendingItem in ipairs(pendingVendorItems) do
        pendingItem.isTicked = true
    end
    ShowSellWindow()
end
function autoVendor.HideSellWindow()
    if sellWindow then
        sellWindow:Hide()
    end
    wipe(pendingVendorItems)
end
autoVendor.FindVendorAdviceItems = FindVendorAdviceItems     -- for tests

local function RepairEverything()
    if not (CanMerchantRepair and CanMerchantRepair()) then
        return
    end
    local repairCost = GetRepairAllCost and GetRepairAllCost() or 0
    if repairCost <= 0 then
        return
    end
    if GetMoney() < repairCost then
        Mentor.Print("Not enough gold to repair everything (" .. Mentor.FormatMoneyWithIcons(repairCost) .. " needed).")
        return
    end
    RepairAllItems()
    Mentor.Print("Repaired all gear for " .. Mentor.FormatMoneyWithIcons(repairCost) .. ".")
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
local panel = Mentor.CreateInfoPanel("MentorAutoVendorFrame", "Auto vendor", ROW_DEFINITIONS,
    "autoVendorPosition", { point = "CENTER", relativePoint = "CENTER", offsetX = 250, offsetY = 0 })
autoVendor.panel = panel

local function UpdateDisplay()
    if not panel:IsShown() then
        return
    end
    for _, switch in pairs(panel.switches) do
        switch:Refresh()                 -- also after /mentor commands or a settings reset
    end
    local junkValue, junkCount = autoVendor.GetJunkValueAndCount()
    panel.values.junkValue:SetText(Mentor.FormatMoneyWithIcons(junkValue))
    panel.values.junkCount:SetText(tostring(junkCount))
    local lowestPercent = GetLowestDurabilityPercent()
    if lowestPercent then
        local percentColor = lowestPercent < DURABILITY_WARNING_PERCENT and "|cffff4040" or "|cff40ff40"
        panel.values.durability:SetText(string.format("%s%d%%|r", percentColor, lowestPercent))
    else
        panel.values.durability:SetText("--")
    end
end

function autoVendor.UpdateVisibility()
    local isWanted = IsActive()
    if isWanted and not panel:IsShown() then
        panel:RestorePosition()
        panel:Show()
        UpdateDisplay()
    elseif not isWanted and panel:IsShown() then
        panel:Hide()
    end
end

--------------------------------------------------------------------------------
-- Keep list (grey items that are never sold)
--------------------------------------------------------------------------------
local function GetItemIdFromText(text)
    local itemId = text and (text:match("item:(%d+)") or text:match("^%s*(%d+)%s*$"))
    return tonumber(itemId)
end

-- command: "keep", "unkeep" or "keeplist"; argument: the shift-clicked item.
function autoVendor.HandleKeepCommand(command, argument)
    local keptItemIds = GetKeptItemIds()
    if command == "keeplist" then
        local hasAnyKeptItem = false
        for itemId in pairs(keptItemIds) do
            hasAnyKeptItem = true
            local itemName = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemId)) or ("item " .. itemId)
            Mentor.Print("Never sold: " .. itemName)
        end
        if not hasAnyKeptItem then
            Mentor.Print("The keep list is empty. Add a grey item with /mentor keep <shift-click the item>.")
        end
        return
    end
    local itemId = GetItemIdFromText(argument)
    if not itemId then
        Mentor.Print("Usage: /mentor " .. command .. " <shift-click an item>")
        return
    end
    keptItemIds[itemId] = (command == "keep") or nil
    Mentor.Print((command == "keep" and "Auto vendor will never sell " or "Auto vendor sells this again: ") .. argument)
    UpdateDisplay()
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
for _, eventName in ipairs({ "PLAYER_LOGIN", "MERCHANT_SHOW", "MERCHANT_CLOSED", "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end
eventFrame:SetScript("OnEvent", function(_, eventName)
    if eventName == "PLAYER_LOGIN" then
        autoVendor.UpdateVisibility()
    elseif eventName == "MERCHANT_SHOW" then
        isMerchantOpen = true
        if not IsActive() then
            return
        end
        if IsShiftKeyDown() then
            Mentor.Print("SHIFT held - no auto sell or repair this time.")
            return
        end
        if IsAutoRepairOn() then
            RepairEverything()   -- first, so the repair is never paid with money you meant to keep
        end
        if IsAutoSellOn() then
            SellAllJunk()
        end
        OfferToSellVendorAdviceItems()
    elseif eventName == "MERCHANT_CLOSED" then
        autoVendor.HideSellWindow()
        isMerchantOpen = false
    else
        UpdateDisplay()          -- bags or durability changed
    end
end)

-- Fallback refresh (item prices can arrive a moment after login) and the on/off setting.
local secondsSinceRefresh = 0
eventFrame:SetScript("OnUpdate", function(_, elapsedSeconds)
    secondsSinceRefresh = secondsSinceRefresh + elapsedSeconds
    if secondsSinceRefresh >= REFRESH_INTERVAL_SECONDS then
        secondsSinceRefresh = 0
        autoVendor.UpdateVisibility()
        UpdateDisplay()
    end
end)

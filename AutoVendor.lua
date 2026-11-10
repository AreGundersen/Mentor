--------------------------------------------------------------------------------
-- Mentor - AutoVendor.lua
-- "Auto vendor" (OFF by default; turn it on under Settings or with
-- /mentor vendor on). When you open a vendor:
--   * every grey (junk) item in your bags is sold
--   * all your gear is repaired (if the vendor can repair)
--   * one chat line says what was sold and what the repair cost
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

-- itemId, itemLink, stackCount, quality, isLocked for a bag slot (or nil).
local function GetBagSlotItem(bagIndex, slotIndex)
    if C_Container and C_Container.GetContainerItemInfo then
        local slotInfo = C_Container.GetContainerItemInfo(bagIndex, slotIndex)
        if not slotInfo then
            return nil
        end
        return slotInfo.itemID, slotInfo.hyperlink, slotInfo.stackCount, slotInfo.quality, slotInfo.isLocked
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
        Mentor.Print(string.format("Sold %d junk item%s for %s.", soldItemCount, soldItemCount == 1 and "" or "s",
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
    elseif eventName == "MERCHANT_CLOSED" then
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

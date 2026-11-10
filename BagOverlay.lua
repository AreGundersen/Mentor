--------------------------------------------------------------------------------
-- Mentor - BagOverlay.lua
-- Shows an arrow in the corner of every bag item you could wear, so you can
-- see it without hovering:
--   green up   = upgrade for your spec
--   yellow up  = upgrade, but you need a higher level first
--   red down   = worse than what you wear
-- With "Sell advice" on (SellAdvice.lua) items worth selling also get a small
-- icon in the bottom-left corner: a gold coin (sell on the AH) or the
-- disenchant icon.
--
-- Works with Blizzard's bags (separate bag windows and the combined bag) and
-- with Bagnon / BagBrother. Other bag addons use their own buttons.
--------------------------------------------------------------------------------

local _, Mentor = ...

-- The arrow is drawn entirely from solid rectangles (no Blizzard texture,
-- whose arrow is not centred in every client and came apart from the body):
--   head: ARROW_HEAD_ROWS stacked bars, 2 px wider each row (a stepped triangle)
--   body: a narrow bar below (or above, for a down arrow) the head
-- Every piece gets a black copy 1 px larger on each side behind it, which
-- gives the arrow a clean outline on any item icon.
local ARROW_HEAD_ROWS = 5
local ARROW_ROW_HEIGHT = 2
local ARROW_HEAD_HEIGHT = ARROW_HEAD_ROWS * ARROW_ROW_HEIGHT
local ARROW_WIDTH = ARROW_HEAD_ROWS * 2          -- widest head row
local ARROW_BODY_WIDTH = 4
local ARROW_BODY_LENGTH = 6
local MARKER_WIDTH = ARROW_WIDTH + 2              -- + outline
local MARKER_HEIGHT = ARROW_HEAD_HEIGHT + ARROW_BODY_LENGTH + 2
local OUTLINE_SIZE = 1
local ARROW_SCALE = 0.9                           -- the whole arrow, outline included
local UP_ARROW = "up"
local DOWN_ARROW = "down"
local UPGRADE_COLOR = { 0.25, 1.0, 0.25 }        -- green: better, use it now
local LATER_UPGRADE_COLOR = { 1.0, 0.85, 0.1 }   -- yellow: better, but needs a higher level
local DOWNGRADE_COLOR = { 1.0, 0.25, 0.25 }      -- red: worse than what you wear
local CROSS_TEXTURE = "Interface\\AddOns\\Mentor\\Media\\Cross"   -- white X, tinted red
local CROSS_SIZE = 16
local CROSS = "cross"
local MAX_CLASSIC_CONTAINER_FRAMES = 13
local MAX_CLASSIC_ITEMS_PER_FRAME = 36

local bagOverlay = {}
Mentor.BagOverlay = bagOverlay

-- One marker per item button, kept in our own table (Blizzard's buttons are
-- left untouched apart from the small frame we add on top).
local arrowsByButton = {}

-- Creates one rectangle of the arrow plus its black outline.
local function CreateArrowPiece(marker)
    local outline = marker:CreateTexture(nil, "ARTWORK", nil, 1)
    outline:SetColorTexture(0, 0, 0, 0.95)
    local fill = marker:CreateTexture(nil, "OVERLAY", nil, 1)
    return { fill = fill, outline = outline }
end

-- Places one piece: width x height, its top edge distanceFromTip pixels from
-- the arrow's tip (the tip is at the top for an up arrow, at the bottom for
-- a down arrow).
local function PlaceArrowPiece(marker, piece, width, height, distanceFromTip, pointsUp)
    local anchor = pointsUp and "TOP" or "BOTTOM"
    local verticalOffset = pointsUp and -(distanceFromTip + OUTLINE_SIZE) or (distanceFromTip + OUTLINE_SIZE)
    piece.fill:ClearAllPoints()
    piece.fill:SetSize(width, height)
    piece.fill:SetPoint(anchor, marker, anchor, 0, verticalOffset)
    piece.outline:ClearAllPoints()
    piece.outline:SetSize(width + OUTLINE_SIZE * 2, height + OUTLINE_SIZE * 2)
    piece.outline:SetPoint("CENTER", piece.fill, "CENTER", 0, 0)
end

local function GetArrow(itemButton)
    local marker = arrowsByButton[itemButton]
    if marker then
        return marker
    end
    marker = CreateFrame("Frame", nil, itemButton)
    marker:SetSize(MARKER_WIDTH, MARKER_HEIGHT)
    marker:SetScale(ARROW_SCALE)
    -- Offsets are in the marker's own (scaled) units, hence the division.
    marker:SetPoint("TOPLEFT", itemButton, "TOPLEFT", 1 / ARROW_SCALE, -1 / ARROW_SCALE)
    marker:SetFrameLevel((itemButton:GetFrameLevel() or 1) + 5)

    marker.headRows = {}
    for rowIndex = 1, ARROW_HEAD_ROWS do
        marker.headRows[rowIndex] = CreateArrowPiece(marker)
    end
    marker.body = CreateArrowPiece(marker)
    marker.cross = marker:CreateTexture(nil, "OVERLAY", nil, 2)
    marker.cross:SetTexture(CROSS_TEXTURE)
    marker.cross:SetSize(CROSS_SIZE, CROSS_SIZE)
    marker.cross:SetPoint("TOPLEFT", 0, 0)
    marker.cross:SetVertexColor(DOWNGRADE_COLOR[1], DOWNGRADE_COLOR[2], DOWNGRADE_COLOR[3])
    marker.cross:Hide()

    local function SetArrowPiecesShown(isShown)
        for _, piece in ipairs(marker.headRows) do
            piece.fill:SetShown(isShown)
            piece.outline:SetShown(isShown)
        end
        marker.body.fill:SetShown(isShown)
        marker.body.outline:SetShown(isShown)
    end

    -- direction: UP_ARROW, DOWN_ARROW or CROSS.
    function marker:SetArrow(direction, red, green, blue)
        self.direction, self.color = direction, { red, green, blue }   -- kept for /mentor debug and tests
        -- direction CROSS: a red X instead of an arrow (item you cannot use).
        SetArrowPiecesShown(direction ~= CROSS)
        self.cross:SetShown(direction == CROSS)
        if direction == CROSS then
            return
        end
        local pointsUp = direction == UP_ARROW
        for rowIndex, row in ipairs(self.headRows) do
            PlaceArrowPiece(self, row, rowIndex * 2, ARROW_ROW_HEIGHT, (rowIndex - 1) * ARROW_ROW_HEIGHT, pointsUp)
            row.fill:SetColorTexture(red, green, blue, 1)
        end
        PlaceArrowPiece(self, self.body, ARROW_BODY_WIDTH, ARROW_BODY_LENGTH, ARROW_HEAD_HEIGHT, pointsUp)
        self.body.fill:SetColorTexture(red, green, blue, 1)
    end
    arrowsByButton[itemButton] = marker
    return marker
end

-- Sell advice icon, one per item button, bottom-left corner (the item count
-- uses the bottom-right one).
local SELL_ICON_SIZE = 14
local sellIconsByButton = {}

local function GetSellIcon(itemButton)
    local sellIcon = sellIconsByButton[itemButton]
    if sellIcon then
        return sellIcon
    end
    local iconFrame = CreateFrame("Frame", nil, itemButton)
    iconFrame:SetSize(SELL_ICON_SIZE, SELL_ICON_SIZE)
    iconFrame:SetPoint("BOTTOMLEFT", itemButton, "BOTTOMLEFT", 2, 2)
    iconFrame:SetFrameLevel((itemButton:GetFrameLevel() or 1) + 5)
    iconFrame.texture = iconFrame:CreateTexture(nil, "OVERLAY")
    iconFrame.texture:SetAllPoints()
    sellIconsByButton[itemButton] = iconFrame
    return iconFrame
end

-- True when the item in this bag slot is soulbound (cannot go on the AH).
local function IsButtonItemBound(itemButton)
    if type(itemButton.info) == "table" and itemButton.info.isBound ~= nil then   -- Bagnon
        return itemButton.info.isBound == true
    end
    if itemButton.GetBagID and C_Container and C_Container.GetContainerItemInfo then
        local success, slotInfo = pcall(C_Container.GetContainerItemInfo, itemButton:GetBagID(), itemButton:GetID())
        return success and type(slotInfo) == "table" and slotInfo.isBound == true
    end
    return false
end

local function GetContainerItemLinkCompat(bagIndex, slotIndex)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bagIndex, slotIndex)
    end
    return GetContainerItemLink(bagIndex, slotIndex)
end

--------------------------------------------------------------------------------
-- Blizzard bags
--------------------------------------------------------------------------------
-- Calls handleButton(itemButton, itemLink) for every visible Blizzard bag slot.
local function ForEachVisibleBlizzardButton(handleButton)
    -- Modern client: container frames list their item buttons.
    local modernFrames = {}
    if ContainerFrameCombinedBags then
        table.insert(modernFrames, ContainerFrameCombinedBags)
    end
    if ContainerFrameContainer and ContainerFrameContainer.ContainerFrames then
        for _, containerFrame in ipairs(ContainerFrameContainer.ContainerFrames) do
            table.insert(modernFrames, containerFrame)
        end
    end
    local handledAny = false
    for _, containerFrame in ipairs(modernFrames) do
        if containerFrame:IsShown() and containerFrame.EnumerateValidItems then
            for _, itemButton in containerFrame:EnumerateValidItems() do
                if itemButton.GetBagID then
                    handleButton(itemButton, GetContainerItemLinkCompat(itemButton:GetBagID(), itemButton:GetID()))
                    handledAny = true
                end
            end
        end
    end
    if handledAny then
        return
    end
    -- Classic client: ContainerFrame1..13 with ContainerFrameNItemM buttons.
    for frameIndex = 1, MAX_CLASSIC_CONTAINER_FRAMES do
        local containerFrame = _G["ContainerFrame" .. frameIndex]
        if containerFrame and containerFrame:IsShown() then
            local bagIndex = containerFrame:GetID()
            for itemIndex = 1, MAX_CLASSIC_ITEMS_PER_FRAME do
                local itemButton = _G["ContainerFrame" .. frameIndex .. "Item" .. itemIndex]
                if itemButton and itemButton:IsShown() then
                    handleButton(itemButton, GetContainerItemLinkCompat(bagIndex, itemButton:GetID()))
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Bagnon (and other BagBrother frontends)
-- Their item buttons are BagBrother "Item" objects: they know their bag
-- (button.bag / button:GetBag()) and keep the item in button.info.hyperlink.
-- Way 1: hook BagBrother's own upgrade-icon update, which runs every time a
--        button is redrawn, and remember those buttons.
-- Way 2: if BagBrother's table is not reachable, find the buttons by looking
--        for visible frames with that shape (only while Bagnon is loaded).
--------------------------------------------------------------------------------
local knownBagnonButtons = {}     -- button -> true
local isBagnonHooked = false
local secondsSinceBagnonScan = math.huge
local BAGNON_SCAN_INTERVAL_SECONDS = 1.0

local function IsAddOnLoadedCompat(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addonName)
    end
    return IsAddOnLoaded and IsAddOnLoaded(addonName)
end

local function IsBagnonLoaded()
    return IsAddOnLoadedCompat("Bagnon") or IsAddOnLoadedCompat("BagBrother")
end

-- True for a BagBrother item button showing one of YOUR current items
-- (cached items from other characters are skipped).
local function IsBagnonItemButton(frame)
    if type(frame) ~= "table" or type(rawget(frame, "info")) ~= "table" or rawget(frame, "bag") == nil then
        return false
    end
    if type(frame.IsCached) == "function" then
        local success, isCached = pcall(frame.IsCached, frame)
        if success and isCached then
            return false
        end
    end
    return true
end

function bagOverlay.TryHookBagnon()
    if isBagnonHooked then
        return
    end
    for _, globalName in ipairs({ "BagBrother", "Bagnon" }) do
        local addonTable = _G[globalName]
        local itemClass = type(addonTable) == "table" and rawget(addonTable, "Item")
        if type(itemClass) == "table" and type(itemClass.UpdateUpgradeIcon) == "function" then
            local function RememberButton(button)
                if IsBagnonItemButton(button) then
                    knownBagnonButtons[button] = true
                    Mentor.RequestRefresh()
                end
            end
            hooksecurefunc(itemClass, "UpdateUpgradeIcon", RememberButton)
            -- Subclasses that define their own copy need the hook too.
            local containerItemClass = rawget(addonTable, "ContainerItem")
            if type(containerItemClass) == "table" and rawget(containerItemClass, "UpdateUpgradeIcon") then
                hooksecurefunc(containerItemClass, "UpdateUpgradeIcon", RememberButton)
            end
            isBagnonHooked = true
            return
        end
    end
end

-- Way 2: walk all frames and remember the Bagnon item buttons.
local function ScanForBagnonButtons()
    if not EnumerateFrames then
        return
    end
    local frame = EnumerateFrames()
    while frame do
        if not knownBagnonButtons[frame] and frame:IsVisible() and IsBagnonItemButton(frame) then
            knownBagnonButtons[frame] = true
        end
        frame = EnumerateFrames(frame)
    end
end

local function ForEachVisibleBagnonButton(handleButton)
    if not IsBagnonLoaded() then
        return
    end
    bagOverlay.TryHookBagnon()
    if not isBagnonHooked and secondsSinceBagnonScan >= BAGNON_SCAN_INTERVAL_SECONDS then
        secondsSinceBagnonScan = 0
        pcall(ScanForBagnonButtons)
    end
    for itemButton in pairs(knownBagnonButtons) do
        if itemButton:IsVisible() and IsBagnonItemButton(itemButton) then
            handleButton(itemButton, itemButton.info.hyperlink)
        end
    end
end

-- Called from the main update loop so the fallback scan knows the time.
function bagOverlay.Tick(elapsedSeconds)
    secondsSinceBagnonScan = secondsSinceBagnonScan + elapsedSeconds
end

local function ForEachVisibleBagButton(handleButton)
    ForEachVisibleBlizzardButton(handleButton)
    ForEachVisibleBagnonButton(handleButton)
end

function bagOverlay.IsAnyBagOpen()
    local isOpen = false
    ForEachVisibleBagButton(function() isOpen = true end)
    return isOpen
end

--------------------------------------------------------------------------------
-- Marking
--------------------------------------------------------------------------------
-- Asks the game to load an item's data; GET_ITEM_INFO_RECEIVED follows.
local function RequestItemData(itemLink)
    if C_Item and C_Item.RequestLoadItemDataByID then
        local itemId = tonumber(itemLink:match("item:(%d+)"))
        if itemId then
            pcall(C_Item.RequestLoadItemDataByID, itemId)
        end
    end
end

local RETRY_DELAY_SECONDS = 0.5
local MAX_RETRIES = 10
local retriesLeft = MAX_RETRIES

-- Marks every visible bag item (Blizzard bags and Bagnon).
-- weights = the current spec's stat weights.
function bagOverlay.Update(weights)
    local areArrowsEnabled = weights and not (MentorDB and MentorDB.areBagArrowsEnabled == false)
    local isSellAdviceEnabled = weights and Mentor.SellAdvice and Mentor.SellAdvice.IsEnabled()
    local markedButtons = {}
    local buttonsWithSellIcon = {}
    local isAnyItemLoading = false

    if areArrowsEnabled or isSellAdviceEnabled then
        ForEachVisibleBagButton(function(itemButton, itemLink)
            if not itemLink then
                return
            end
            local result = Mentor.CompareItem(itemLink, weights)
            if result.kind == "loading" then
                -- Not in the item cache yet (this is why arrows used to appear
                -- only after hovering): ask the game to load it and try again.
                isAnyItemLoading = true
                RequestItemData(itemLink)
                return
            end
            local arrowDirection, arrowColor
            if result.kind == "upgrade" or result.kind == "empty" then
                arrowDirection = UP_ARROW
                arrowColor = result.requiredLevel and LATER_UPGRADE_COLOR or UPGRADE_COLOR
            elseif result.kind == "downgrade" then
                arrowDirection, arrowColor = DOWN_ARROW, DOWNGRADE_COLOR
            elseif result.kind == "cannotUse" then
                arrowDirection, arrowColor = CROSS, DOWNGRADE_COLOR
            end
            -- Coin / disenchant icon on items that are not an upgrade but worth money.
            if isSellAdviceEnabled and arrowDirection ~= UP_ARROW then
                local sellAdvice = Mentor.SellAdvice.Evaluate(itemLink, IsButtonItemBound(itemButton))
                local iconTexture = Mentor.SellAdvice.GetActionIcon(sellAdvice)
                if iconTexture then
                    local sellIcon = GetSellIcon(itemButton)
                    sellIcon.texture:SetTexture(iconTexture)
                    sellIcon.action = sellAdvice.action   -- kept for tests
                    sellIcon:Show()
                    buttonsWithSellIcon[itemButton] = true
                end
            end
            if arrowDirection and areArrowsEnabled then
                local marker = GetArrow(itemButton)
                marker:SetArrow(arrowDirection, arrowColor[1], arrowColor[2], arrowColor[3])
                marker:Show()
                markedButtons[itemButton] = true
            end
        end)
    end
    -- Hide every arrow that was not (re)marked in this pass.
    for itemButton, marker in pairs(arrowsByButton) do
        if not markedButtons[itemButton] then
            marker:Hide()
        end
    end
    for itemButton, sellIcon in pairs(sellIconsByButton) do
        if not buttonsWithSellIcon[itemButton] then
            sellIcon:Hide()
        end
    end
    -- Retry shortly while items are still loading (limited, so it never loops forever).
    if isAnyItemLoading and retriesLeft > 0 then
        retriesLeft = retriesLeft - 1
        C_Timer.After(RETRY_DELAY_SECONDS, Mentor.RequestRefresh)
    elseif not isAnyItemLoading then
        retriesLeft = MAX_RETRIES
    end
end

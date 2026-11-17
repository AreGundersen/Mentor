--------------------------------------------------------------------------------
-- Mentor - Upgrades.lua
-- "Where can I get better gear?" The Upgrades button (under Life log in the
-- Mentor window, or /mentor upgrades) opens a small window that lists the
-- dungeons for your level that drop upgrades for the spec you play, best
-- first, with up to three items each and the boss that drops them.
--
-- Data: DungeonLoot.lua (item ids per dungeon, from Wowhead's WoW Forever
-- zone pages) and the dungeon level ranges from Journey.lua. The items are
-- compared with what you wear by Mentor.CompareItem, like the bag arrows.
--------------------------------------------------------------------------------

local _, Mentor = ...

local upgrades = {}
Mentor.Upgrades = upgrades

local MENTOR_GOLD = { 1.00, 0.78, 0.10 }
local WINDOW_WIDTH = 340
local PADDING = 12
local ROW_HEIGHT = 20
local DUNGEON_HEADER_HEIGHT = 20
local MAX_DUNGEONS_SHOWN = 4
local MAX_ITEMS_PER_DUNGEON = 3
local LEVELS_ABOVE_SHOWN = 3            -- items you can wear within this many levels count
local LEVELS_BELOW_RANGE = 2            -- dungeons start counting a little before their range
local LOGO_TEXTURE = "Interface\\AddOns\\Mentor\\Media\\Logo"
local WINDOW_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

--------------------------------------------------------------------------------
-- Finding the upgrades
--------------------------------------------------------------------------------
-- The item link for an item id (nil until the game has loaded the item;
-- asking also makes the game load it).
local function GetItemLinkById(itemId)
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemId)
    end
    local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getItemInfo then
        return nil
    end
    local success, _, itemLink = pcall(getItemInfo, itemId)
    return success and itemLink or nil
end

local function FitsFaction(dungeonFaction)
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
    return dungeonFaction == nil or dungeonFaction == playerFaction
end

-- Dungeons for your level with their upgrades, best dungeon first:
-- { { name, minLevel, maxLevel, place, upgrades = { { itemLink, boss, result } }, bestGain } }
-- isStillLoading is true while some items were not loaded yet.
function upgrades.FindDungeonUpgrades()
    local advice = Mentor.currentAdvice
    local dungeonList = Mentor.Journey and Mentor.Journey.DUNGEONS
    if not (advice and advice.specData and advice.specData.weights and Mentor.CompareItem
        and Mentor.DUNGEON_LOOT and dungeonList) then
        return {}, false
    end
    local playerLevel = UnitLevel("player") or 1
    local isStillLoading = false
    local dungeonResults = {}
    for _, dungeon in ipairs(dungeonList) do
        local dungeonName, minLevel, maxLevel, dungeonFaction, place = dungeon[1], dungeon[2], dungeon[3], dungeon[4], dungeon[5]
        local lootList = Mentor.DUNGEON_LOOT[dungeonName]
        if lootList and FitsFaction(dungeonFaction)
            and playerLevel >= minLevel - LEVELS_BELOW_RANGE and playerLevel <= maxLevel then
            local dungeonUpgrades = {}
            for _, lootEntry in ipairs(lootList) do
                local itemId, bossName = lootEntry[1], lootEntry[2]
                local itemLink = GetItemLinkById(itemId)
                if not itemLink then
                    isStillLoading = true
                else
                    local success, result = pcall(Mentor.CompareItem, itemLink, advice.specData.weights)
                    if success and result then
                        if result.kind == "loading" then
                            isStillLoading = true
                        elseif (result.kind == "upgrade" or result.kind == "empty")
                            and (not result.requiredLevel or result.requiredLevel <= playerLevel + LEVELS_ABOVE_SHOWN) then
                            local gain = result.kind == "empty" and 100 or (result.overallPercent or result.percent or 0)
                            table.insert(dungeonUpgrades, { itemLink = itemLink, boss = bossName, result = result, gain = gain })
                        end
                    end
                end
            end
            if #dungeonUpgrades > 0 then
                table.sort(dungeonUpgrades, function(first, second) return first.gain > second.gain end)
                -- One upgrade per slot is enough: you can only wear one of them.
                local bestPerSlot, usedSlots = {}, {}
                for _, upgrade in ipairs(dungeonUpgrades) do
                    local slotKey = upgrade.result.replacedSlot or upgrade.itemLink
                    if not usedSlots[slotKey] then
                        usedSlots[slotKey] = true
                        table.insert(bestPerSlot, upgrade)
                    end
                end
                local totalGain = 0
                for _, upgrade in ipairs(bestPerSlot) do
                    totalGain = totalGain + math.min(upgrade.gain, 100)
                end
                table.insert(dungeonResults, { name = dungeonName, minLevel = minLevel, maxLevel = maxLevel, place = place,
                    upgrades = bestPerSlot, totalGain = totalGain })
            end
        end
    end
    table.sort(dungeonResults, function(first, second) return first.totalGain > second.totalGain end)
    return dungeonResults, isStillLoading
end

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------
local window
local dungeonHeaders, itemRows = {}, {}

local function CreateItemRow()
    local row = CreateFrame("Button", nil, window)
    row:SetSize(WINDOW_WIDTH - 2 * PADDING, ROW_HEIGHT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_HEIGHT - 2, ROW_HEIGHT - 2)
    row.icon:SetPoint("LEFT", 8, 0)
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.nameText:SetPoint("RIGHT", -96, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)
    row.valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.valueText:SetPoint("RIGHT", 0, 0)
    row.valueText:SetJustifyH("RIGHT")
    local hoverHighlight = row:CreateTexture(nil, "HIGHLIGHT")
    hoverHighlight:SetAllPoints()
    hoverHighlight:SetColorTexture(1, 0.82, 0, 0.08)
    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetHyperlink, GameTooltip, self.itemLink)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cff66ccffMentor:|r " .. (self.bossName ~= "" and ("Drops from " .. self.bossName)
                or "Drops from monsters in the dungeon"), 0.85, 0.85, 0.85)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        -- Shift-click links the item in chat, like items anywhere else.
        if self.itemLink and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
            ChatEdit_InsertLink(self.itemLink)
        end
    end)
    return row
end

local function CreateWindow()
    window = CreateFrame("Frame", "MentorUpgradesWindow", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    window:SetWidth(WINDOW_WIDTH)
    window:SetFrameStrata("DIALOG")
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetClampedToScreen(true)
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    if window.SetBackdrop then
        window:SetBackdrop(WINDOW_BACKDROP)
        window:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.9)
    end
    if UISpecialFrames then
        table.insert(UISpecialFrames, "MentorUpgradesWindow")   -- Escape closes it
    end
    local logo = window:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(LOGO_TEXTURE)
    logo:SetSize(18, 18)
    logo:SetPoint("TOPLEFT", PADDING - 2, -PADDING + 2)
    window.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    window.title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    window.title:SetText("Where to get upgrades")
    local closeButton = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -2, -2)
    window.subtitle = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.subtitle:SetPoint("TOPLEFT", PADDING, -PADDING - 24)
    window.subtitle:SetWidth(WINDOW_WIDTH - 2 * PADDING)
    window.subtitle:SetJustifyH("LEFT")
    window.emptyText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.emptyText:SetWidth(WINDOW_WIDTH - 2 * PADDING)
    window.emptyText:SetJustifyH("LEFT")
    window:Hide()
end

local function GetDungeonHeader(headerIndex)
    local header = dungeonHeaders[headerIndex]
    if not header then
        header = CreateFrame("Frame", nil, window)
        header:SetSize(WINDOW_WIDTH - 2 * PADDING, DUNGEON_HEADER_HEIGHT)
        header.nameText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header.nameText:SetPoint("LEFT", 0, 0)
        header.levelText = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        header.levelText:SetPoint("LEFT", header.nameText, "RIGHT", 6, 0)
        header.line = header:CreateTexture(nil, "ARTWORK")
        header.line:SetColorTexture(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.35)
        header.line:SetHeight(1)
        header.line:SetPoint("BOTTOMLEFT", 0, 0)
        header.line:SetPoint("BOTTOMRIGHT", 0, 0)
        dungeonHeaders[headerIndex] = header
    end
    return header
end

-- "+12%" in green, or "+12% (lvl 24)" in yellow when you can't wear it yet.
local function FormatGain(result)
    local gainText = result.kind == "empty" and "new slot"
        or (Mentor.FormatPercentChange and Mentor.FormatPercentChange(result.percent) or "")
    if result.requiredLevel then
        return "|cffffd100" .. gainText .. " (lvl " .. result.requiredLevel .. ")|r"
    end
    return "|cff40ff40" .. gainText .. "|r"
end

local isRefreshQueued = false

function upgrades.Refresh()
    if not (window and window:IsShown()) then
        return
    end
    local advice = Mentor.currentAdvice
    local specName = advice and advice.specData and advice.specData.name or "your spec"
    window.subtitle:SetText(string.format("Dungeons for level %d with gear better than yours for |cffffffff%s|r, best first.",
        UnitLevel("player") or 1, specName))
    local dungeonResults, isStillLoading = upgrades.FindDungeonUpgrades()

    for _, header in ipairs(dungeonHeaders) do
        header:Hide()
    end
    for _, row in ipairs(itemRows) do
        row:Hide()
    end
    local verticalOffset = -PADDING - 24 - (window.subtitle:GetStringHeight() or 24) - 8
    local usedRows = 0
    for dungeonIndex = 1, math.min(MAX_DUNGEONS_SHOWN, #dungeonResults) do
        local dungeonResult = dungeonResults[dungeonIndex]
        local header = GetDungeonHeader(dungeonIndex)
        header.nameText:SetText(dungeonResult.name)
        header.levelText:SetText(string.format("level %d-%d  |  %s", dungeonResult.minLevel, dungeonResult.maxLevel, dungeonResult.place or ""))
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", PADDING, verticalOffset)
        header:Show()
        verticalOffset = verticalOffset - DUNGEON_HEADER_HEIGHT - 2
        for itemIndex = 1, math.min(MAX_ITEMS_PER_DUNGEON, #dungeonResult.upgrades) do
            local upgrade = dungeonResult.upgrades[itemIndex]
            usedRows = usedRows + 1
            local row = itemRows[usedRows] or CreateItemRow()
            itemRows[usedRows] = row
            row.itemLink, row.bossName = upgrade.itemLink, upgrade.boss
            local itemIcon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(upgrade.itemLink))
                or (GetItemIcon and GetItemIcon(upgrade.itemLink)) or 134400
            row.icon:SetTexture(itemIcon)
            row.nameText:SetText(upgrade.itemLink)
            row.valueText:SetText(FormatGain(upgrade.result))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PADDING, verticalOffset)
            row:Show()
            verticalOffset = verticalOffset - ROW_HEIGHT
        end
        verticalOffset = verticalOffset - 6
    end
    if #dungeonResults == 0 then
        window.emptyText:SetText(isStillLoading and "|cffa6a6a6Loading items...|r"
            or "|cffa6a6a6No dungeon for your level drops an upgrade for you right now - your gear is good for your level!|r")
        window.emptyText:ClearAllPoints()
        window.emptyText:SetPoint("TOPLEFT", PADDING, verticalOffset)
        window.emptyText:Show()
        verticalOffset = verticalOffset - (window.emptyText:GetStringHeight() or 24) - 6
    else
        window.emptyText:Hide()
    end
    window:SetHeight(-verticalOffset + PADDING)

    -- Items arrive from the server one by one: look again a moment later.
    if isStillLoading and not isRefreshQueued and C_Timer then
        isRefreshQueued = true
        C_Timer.After(0.5, function()
            isRefreshQueued = false
            pcall(upgrades.Refresh)
        end)
    end
end

function upgrades.Toggle()
    if not window then
        CreateWindow()
    end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
        upgrades.Refresh()
    end
end

-- Keep it current while it is open (new gear, level up, spec change).
local eventFrame = CreateFrame("Frame")
for _, eventName in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "GET_ITEM_INFO_RECEIVED" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end
eventFrame:SetScript("OnEvent", function()
    if window and window:IsShown() and not isRefreshQueued and C_Timer then
        isRefreshQueued = true
        C_Timer.After(0.3, function()
            isRefreshQueued = false
            pcall(upgrades.Refresh)
        end)
    end
end)

--------------------------------------------------------------------------------
-- Mentor - Upgrades.lua
-- "Where can I get better gear?" The "Find more" button (next to "Upgrades
-- in your bags" in the Mentor window, or /mentor upgrades) opens a panel
-- beside the Mentor window that lists the dungeons for your level with
-- upgrades for the spec you play, best first, with up to three items each:
-- boss drops, and rewards from that dungeon's quests.
--
-- Data: DungeonLoot.lua and DungeonQuests.lua (item ids per dungeon, from
-- Wowhead's WoW Forever zone pages) and the dungeon level ranges from Journey.lua. The items are
-- compared with what you wear by Mentor.CompareItem, like the bag arrows.
--------------------------------------------------------------------------------

local _, Mentor = ...

local upgrades = {}
Mentor.Upgrades = upgrades

local MENTOR_GOLD = { 1.00, 0.78, 0.10 }
local WINDOW_WIDTH = 340
local PADDING = 12
local ROW_HEIGHT = 20
local DUNGEON_HEADER_HEIGHT = 32  -- dungeon name, with level and place on a line under it
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

-- Quest sides in DungeonQuests.lua: 1 = Alliance, 2 = Horde, 3 = both.
local QUEST_SIDE_BY_FACTION = { Alliance = 1, Horde = 2 }

local function IsQuestDone(questId)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local success, isDone = pcall(C_QuestLog.IsQuestFlaggedCompleted, questId)
        return success and isDone == true
    end
    return false
end

-- Everything one dungeon can give you, as { itemId, bossName, questName,
-- choiceQuestId } (choiceQuestId: you pick only one of that quest's choices):
-- its boss drops, then the rewards of its quests that your faction can take
-- and you haven't done yet.
local function GetDungeonRewardSources(dungeonName)
    local rewardSources = {}
    for _, lootEntry in ipairs(Mentor.DUNGEON_LOOT[dungeonName] or {}) do
        table.insert(rewardSources, { lootEntry[1], lootEntry[2], nil, nil })
    end
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
    local playerQuestSide = QUEST_SIDE_BY_FACTION[playerFaction]
    for _, questEntry in ipairs((Mentor.DUNGEON_QUESTS or {})[dungeonName] or {}) do
        local questId, questName, questSide = questEntry[1], questEntry[2], questEntry[3]
        local rewardItemIds, choiceItemIds = questEntry[4], questEntry[5]
        local isForPlayerFaction = questSide == 3 or questSide == playerQuestSide
        if isForPlayerFaction and not IsQuestDone(questId) then
            for _, itemId in ipairs(rewardItemIds or {}) do
                table.insert(rewardSources, { itemId, "", questName, nil })
            end
            for _, itemId in ipairs(choiceItemIds or {}) do
                table.insert(rewardSources, { itemId, "", questName, questId })
            end
        end
    end
    return rewardSources
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
        local hasData = Mentor.DUNGEON_LOOT[dungeonName] or (Mentor.DUNGEON_QUESTS and Mentor.DUNGEON_QUESTS[dungeonName])
        if hasData and FitsFaction(dungeonFaction)
            and playerLevel >= minLevel - LEVELS_BELOW_RANGE and playerLevel <= maxLevel then
            local dungeonUpgrades = {}
            for _, rewardSource in ipairs(GetDungeonRewardSources(dungeonName)) do
                local itemId, bossName, questName, choiceQuestId = rewardSource[1], rewardSource[2], rewardSource[3], rewardSource[4]
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
                            table.insert(dungeonUpgrades, { itemLink = itemLink, boss = bossName, questName = questName,
                                choiceQuestId = choiceQuestId, result = result, gain = gain })
                        end
                    end
                end
            end
            if #dungeonUpgrades > 0 then
                table.sort(dungeonUpgrades, function(first, second) return first.gain > second.gain end)
                -- One upgrade per slot is enough: you can only wear one of them.
                -- And only the best choice of a quest: you get to pick just one.
                local bestPerSlot, usedSlots, usedChoiceQuests = {}, {}, {}
                for _, upgrade in ipairs(dungeonUpgrades) do
                    local slotKey = upgrade.result.replacedSlot or upgrade.itemLink
                    local isChoiceTaken = upgrade.choiceQuestId and usedChoiceQuests[upgrade.choiceQuestId]
                    if not usedSlots[slotKey] and not isChoiceTaken then
                        usedSlots[slotKey] = true
                        if upgrade.choiceQuestId then
                            usedChoiceQuests[upgrade.choiceQuestId] = true
                        end
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
-- Vendors: weapons and armor you can simply buy (VendorGear.lua)
--------------------------------------------------------------------------------
local MAX_VENDOR_ITEMS_SHOWN = 4
local UNCOMMON_QUALITY = 2

local function GetItemQuality(itemId)
    if C_Item and C_Item.GetItemQualityByID then
        local isSuccess, quality = pcall(C_Item.GetItemQualityByID, itemId)
        if isSuccess and quality then
            return quality
        end
    end
    local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local isSuccess, _, _, quality = pcall(getItemInfo, itemId)
    return isSuccess and quality or nil
end

-- The vendors of an item that are friendly to you, nearest-looking first
-- (a vendor in a zone you are in comes first).
local function GetFriendlyVendors(vendorIds)
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
    local factionLetter = playerFaction == "Alliance" and "A" or playerFaction == "Horde" and "H" or nil
    local friendlyVendors = {}
    for _, vendorId in ipairs(vendorIds) do
        local vendor = Mentor.GEAR_VENDORS and Mentor.GEAR_VENDORS[vendorId]
        if vendor and factionLetter and vendor[2]:find(factionLetter, 1, true) then
            table.insert(friendlyVendors, vendor)
        end
    end
    local currentZone = GetRealZoneText and GetRealZoneText()
    table.sort(friendlyVendors, function(first, second)
        local isFirstHere = Mentor.VENDOR_ZONE_NAMES[first[3]] == currentZone
        local isSecondHere = Mentor.VENDOR_ZONE_NAMES[second[3]] == currentZone
        if isFirstHere ~= isSecondHere then
            return isFirstHere
        end
        return first[1] < second[1]
    end)
    return friendlyVendors
end

-- "Aldren Cordon in Loch Modan (65, 66)"
function upgrades.FormatVendor(vendor)
    local zoneName = type(vendor[3]) == "string" and vendor[3] or (Mentor.VENDOR_ZONE_NAMES[vendor[3]] or "?")
    return string.format("%s in %s (%d, %d)", vendor[1], zoneName, math.floor(vendor[4] + 0.5), math.floor(vendor[5] + 0.5))
end

--------------------------------------------------------------------------------
-- Quartermasters: gear for gold once your reputation is high enough
-- (ReputationGear.lua). Standings: 4 Neutral, 5 Friendly, 6 Honored,
-- 7 Revered, 8 Exalted.
--------------------------------------------------------------------------------
local NEUTRAL_STANDING = 4
local STANDING_STEPS_AHEAD_SHOWN = 1   -- show gear one standing above yours
local STANDING_NAMES = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }

-- Your standing and the faction's name ("Neutral" when you haven't met them).
local function GetPlayerStanding(factionId)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local isSuccess, factionData = pcall(C_Reputation.GetFactionDataByID, factionId)
        if isSuccess and type(factionData) == "table" and factionData.reaction then
            return factionData.reaction, factionData.name
        end
    end
    if GetFactionInfoByID then
        local isSuccess, factionName, _, standingId = pcall(GetFactionInfoByID, factionId)
        if isSuccess and standingId then
            return standingId, factionName
        end
    end
    return NEUTRAL_STANDING, nil
end

function upgrades.GetStandingName(standing)
    return STANDING_NAMES[standing] or "?"
end

-- Uncommon or better weapons and armor that a friendly vendor sells and that
-- are better than what you wear: { { itemLink, result, gain, vendors } },
-- best first, one per slot.
function upgrades.FindVendorUpgrades()
    local advice = Mentor.currentAdvice
    if not (advice and advice.specData and advice.specData.weights and Mentor.CompareItem and Mentor.VENDOR_GEAR) then
        return {}, false
    end
    local playerLevel = UnitLevel("player") or 1
    local isStillLoading = false
    local vendorUpgrades = {}
    for itemId, vendorEntry in pairs(Mentor.VENDOR_GEAR) do
        local requiredLevel = vendorEntry[1]
        if requiredLevel <= playerLevel + LEVELS_ABOVE_SHOWN and requiredLevel >= playerLevel - 15 then
            local vendorIds = { select(2, unpack(vendorEntry)) }
            local friendlyVendors = GetFriendlyVendors(vendorIds)
            local quality = #friendlyVendors > 0 and GetItemQuality(itemId)
            if quality and quality >= UNCOMMON_QUALITY then
                local itemLink = GetItemLinkById(itemId)
                if not itemLink then
                    isStillLoading = true
                else
                    local isSuccess, result = pcall(Mentor.CompareItem, itemLink, advice.specData.weights)
                    if isSuccess and result then
                        if result.kind == "loading" then
                            isStillLoading = true
                        elseif result.kind == "upgrade" or result.kind == "empty" then
                            local gain = result.kind == "empty" and 100 or (result.overallPercent or result.percent or 0)
                            table.insert(vendorUpgrades, { itemLink = itemLink, result = result, gain = gain,
                                vendors = friendlyVendors, boss = "" })
                        end
                    end
                end
            elseif #friendlyVendors > 0 and quality == nil then
                isStillLoading = true
                GetItemLinkById(itemId)  -- asks the game to load it
            end
        end
    end
    -- Quartermaster gear: your faction can buy it, and your reputation is
    -- high enough or one step away.
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
    local factionLetter = playerFaction == "Alliance" and "A" or playerFaction == "Horde" and "H" or nil
    for itemId, gearEntry in pairs(Mentor.REPUTATION_GEAR or {}) do
        local vendorId, requiredLevel, standingNeeded, priceInCopper = gearEntry[1], gearEntry[2], gearEntry[3], gearEntry[4]
        local vendor = Mentor.REPUTATION_VENDORS and Mentor.REPUTATION_VENDORS[vendorId]
        local isForYourFaction = vendor and factionLetter and vendor[4]:find(factionLetter, 1, true)
        local isLevelClose = requiredLevel <= playerLevel + LEVELS_ABOVE_SHOWN and requiredLevel >= playerLevel - 15
        if isForYourFaction and isLevelClose then
            local playerStanding, gameFactionName = GetPlayerStanding(vendor[2])
            if standingNeeded <= playerStanding + STANDING_STEPS_AHEAD_SHOWN then
                local itemLink = GetItemLinkById(itemId)
                if not itemLink then
                    isStillLoading = true
                else
                    local isSuccess, result = pcall(Mentor.CompareItem, itemLink, advice.specData.weights)
                    if isSuccess and result then
                        if result.kind == "loading" then
                            isStillLoading = true
                        elseif result.kind == "upgrade" or result.kind == "empty" then
                            local gain = result.kind == "empty" and 100 or (result.overallPercent or result.percent or 0)
                            -- Same shape as the Questie vendors: { name, sides, zone, x, y }.
                            local vendorForDisplay = { vendor[1], vendor[4], vendor[5], vendor[6], vendor[7] }
                            table.insert(vendorUpgrades, { itemLink = itemLink, result = result, gain = gain, boss = "",
                                vendors = { vendorForDisplay }, priceInCopper = priceInCopper,
                                reputation = { factionName = gameFactionName or vendor[3] or "their faction",
                                    standingNeeded = standingNeeded, playerStanding = playerStanding } })
                        end
                    end
                end
            end
        end
    end

    table.sort(vendorUpgrades, function(first, second) return first.gain > second.gain end)
    local bestPerSlot, usedSlots = {}, {}
    for _, upgrade in ipairs(vendorUpgrades) do
        local slotKey = upgrade.result.replacedSlot or upgrade.itemLink
        if not usedSlots[slotKey] and #bestPerSlot < MAX_VENDOR_ITEMS_SHOWN then
            usedSlots[slotKey] = true
            table.insert(bestPerSlot, upgrade)
        end
    end
    return bestPerSlot, isStillLoading
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
    row.valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.valueText:SetPoint("RIGHT", 0, 0)
    row.valueText:SetJustifyH("RIGHT")
    -- The name stops where the gain (and "Quest" tag) starts.
    row.nameText:SetPoint("RIGHT", row.valueText, "LEFT", -6, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)
    local hoverHighlight = row:CreateTexture(nil, "HIGHLIGHT")
    hoverHighlight:SetAllPoints()
    hoverHighlight:SetColorTexture(1, 0.82, 0, 0.08)
    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetHyperlink, GameTooltip, self.itemLink)
            GameTooltip:AddLine(" ")
            local sourceText
            if self.vendors then
                sourceText = "Sold by " .. upgrades.FormatVendor(self.vendors[1])
                if self.priceInCopper and Mentor.FormatMoneyWithIcons then
                    sourceText = sourceText .. " for " .. Mentor.FormatMoneyWithIcons(self.priceInCopper)
                end
                if self.reputation then
                    local hasStanding = self.reputation.playerStanding >= self.reputation.standingNeeded
                    GameTooltip:AddLine(string.format("|cff66ccffMentor:|r Needs %s with %s - you are %s.",
                        upgrades.GetStandingName(self.reputation.standingNeeded), self.reputation.factionName,
                        upgrades.GetStandingName(self.reputation.playerStanding)),
                        hasStanding and 0.25 or 1, hasStanding and 1 or 0.82, hasStanding and 0.25 or 0, true)
                end
                for vendorIndex = 2, math.min(4, #self.vendors) do
                    GameTooltip:AddLine("|cff66ccffMentor:|r Also: " .. upgrades.FormatVendor(self.vendors[vendorIndex]), 0.85, 0.85, 0.85, true)
                end
            elseif self.questName then
                sourceText = "Reward from the quest \"" .. self.questName .. "\""
            elseif self.bossName and self.bossName ~= "" then
                sourceText = "Drops from " .. self.bossName
            else
                sourceText = "Drops from monsters in the dungeon"
            end
            GameTooltip:AddLine("|cff66ccffMentor:|r " .. sourceText, 0.85, 0.85, 0.85, true)
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
    -- Docked to the Mentor window like its other side panels (settings, build,
    -- extras): it moves with the window, opens on the side with room, and
    -- closes when the Mentor window closes.
    local mentorWindow = _G.MentorFrame
    window = CreateFrame("Frame", "MentorUpgradesWindow", mentorWindow or UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    window:SetWidth(WINDOW_WIDTH)
    window:EnableMouse(true)
    if mentorWindow and Mentor.RegisterSidePanel then
        window:SetHeight(100)  -- real height is set in Refresh
        Mentor.RegisterSidePanel(window, false)
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    end
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
        header.nameText:SetPoint("TOPLEFT", 0, -1)
        -- Level and place in grey on their own line under the dungeon name.
        header.levelText = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        header.levelText:SetPoint("TOPLEFT", header.nameText, "BOTTOMLEFT", 0, -2)
        -- A very long place would still run past the window edge: stop at the
        -- edge and end with "...". The tooltip shows it all.
        header.levelText:SetPoint("RIGHT", header, "RIGHT", 0, 0)
        header.levelText:SetJustifyH("LEFT")
        header.levelText:SetWordWrap(false)
        header:EnableMouse(true)
        header:SetScript("OnEnter", function(self)
            if not self.dungeonResult then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.dungeonResult.name)
            if self.dungeonResult.isVendorSection then
                GameTooltip:AddLine("Gear you can buy with gold. Hover an item to see who sells it and where.", 1, 1, 1, true)
                GameTooltip:Show()
                return
            end
            GameTooltip:AddLine(string.format("Level %d-%d", self.dungeonResult.minLevel, self.dungeonResult.maxLevel), 1, 1, 1)
            if self.dungeonResult.place then
                GameTooltip:AddLine(self.dungeonResult.place, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        header:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    window.subtitle:SetText(string.format("Dungeons and vendors for level %d with gear better than yours for |cffffffff%s|r, best first.",
        UnitLevel("player") or 1, specName))
    local dungeonResults, isStillLoading = upgrades.FindDungeonUpgrades()
    local shownResults = {}
    for dungeonIndex = 1, math.min(MAX_DUNGEONS_SHOWN, #dungeonResults) do
        table.insert(shownResults, dungeonResults[dungeonIndex])
    end
    -- Gear from vendors comes last, as its own section.
    local vendorUpgrades, isVendorStillLoading = upgrades.FindVendorUpgrades()
    isStillLoading = isStillLoading or isVendorStillLoading
    if #vendorUpgrades > 0 then
        table.insert(shownResults, { name = "From vendors", isVendorSection = true, upgrades = vendorUpgrades })
    end

    for _, header in ipairs(dungeonHeaders) do
        header:Hide()
    end
    for _, row in ipairs(itemRows) do
        row:Hide()
    end
    local verticalOffset = -PADDING - 24 - (window.subtitle:GetStringHeight() or 24) - 8
    local usedRows = 0
    for dungeonIndex, dungeonResult in ipairs(shownResults) do
        local header = GetDungeonHeader(dungeonIndex)
        header.dungeonResult = dungeonResult
        header.nameText:SetText(dungeonResult.name)
        if dungeonResult.isVendorSection then
            header.levelText:SetText("buy with gold  |  hover an item to see where")
        else
            header.levelText:SetText(string.format("level %d-%d  |  %s", dungeonResult.minLevel, dungeonResult.maxLevel, dungeonResult.place or ""))
        end
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", PADDING, verticalOffset)
        header:Show()
        verticalOffset = verticalOffset - DUNGEON_HEADER_HEIGHT - 2
        local itemLimit = dungeonResult.isVendorSection and MAX_VENDOR_ITEMS_SHOWN or MAX_ITEMS_PER_DUNGEON
        for itemIndex = 1, math.min(itemLimit, #dungeonResult.upgrades) do
            local upgrade = dungeonResult.upgrades[itemIndex]
            usedRows = usedRows + 1
            local row = itemRows[usedRows] or CreateItemRow()
            itemRows[usedRows] = row
            row.itemLink, row.bossName, row.questName, row.vendors = upgrade.itemLink, upgrade.boss, upgrade.questName, upgrade.vendors
            row.priceInCopper, row.reputation = upgrade.priceInCopper, upgrade.reputation
            local itemIcon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(upgrade.itemLink))
                or (GetItemIcon and GetItemIcon(upgrade.itemLink)) or 134400
            row.icon:SetTexture(itemIcon)
            row.nameText:SetText(upgrade.itemLink)
            -- Quest rewards get a small gold "Quest" tag before the gain.
            local questTag = upgrade.questName and "|cffffd100Quest|r  " or ""
            -- Quartermaster gear: a blue "Rep" tag (grey while you still need more reputation).
            if upgrade.reputation then
                local hasStanding = upgrade.reputation.playerStanding >= upgrade.reputation.standingNeeded
                questTag = (hasStanding and "|cff66ccffRep|r  " or "|cffa6a6a6Rep|r  ")
            end
            row.valueText:SetText(questTag .. FormatGain(upgrade.result))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PADDING, verticalOffset)
            row:Show()
            verticalOffset = verticalOffset - ROW_HEIGHT
        end
        verticalOffset = verticalOffset - 6
    end
    if #shownResults == 0 then
        window.emptyText:SetText(isStillLoading and "|cffa6a6a6Loading items...|r"
            or "|cffa6a6a6No dungeon or vendor has an upgrade for you right now - your gear is good for your level!|r")
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
        return
    end
    -- Opened by command while the Mentor window is closed: open it too, since
    -- this panel sits beside it.
    local mentorWindow = _G.MentorFrame
    if mentorWindow and not mentorWindow:IsShown() then
        mentorWindow:Show()
    end
    -- The Extras and Settings panels open in the same spot: close them so
    -- the panels don't stack on top of each other.
    for _, otherPanelName in ipairs({ "MentorExtrasPanel", "MentorSettingsPanel" }) do
        local otherPanel = _G[otherPanelName]
        if otherPanel and otherPanel:IsShown() then
            otherPanel:Hide()
        end
    end
    -- Above the build panel, which can also be open on this side.
    if mentorWindow and mentorWindow.GetFrameLevel then
        window:SetFrameLevel((mentorWindow:GetFrameLevel() or 1) + 20)
    end
    window:Show()
    upgrades.Refresh()
    if Mentor.PlaceSidePanels then
        Mentor.PlaceSidePanels()
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

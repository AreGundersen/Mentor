--------------------------------------------------------------------------------
-- Mentor - Alerts.lua
--   * extra line on every item tooltip: "Mentor: +14% upgrade for Enhancement"
--   * optional sell / disenchant advice line (SellAdvice.lua)
--   * chat alert when you loot an upgrade
--   * best quest reward suggestion (with a glow) when you hand in a quest
--------------------------------------------------------------------------------

local _, Mentor = ...

local LOOT_CHECK_DELAY_SECONDS = 1.0
local QUEST_CHECK_DELAY_SECONDS = 0.3
local GOOD_COLOR = "|cff40ff40"

local function GetCurrentWeights()
    local advice = Mentor.currentAdvice
    return advice and advice.specData and advice.specData.weights
end

local function GetCurrentSpecName()
    local advice = Mentor.currentAdvice
    return advice and advice.specData and advice.specData.name
end

-- "Tooltip details" setting: off = only the verdicts, no explanations.
local function AreDetailsShown()
    return MentorDB.areTooltipDetailsShown ~= false
end

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

local function GetItemInfoCompat(itemLink)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(itemLink)
    end
    return GetItemInfo(itemLink)
end

--------------------------------------------------------------------------------
-- Item tooltips
--------------------------------------------------------------------------------
-- Sell / disenchant advice (off by default, needs Auctionator). Shown for items
-- that are not an upgrade for your current spec.
local function IsTooltipSoulbound(tooltip)
    local tooltipName = tooltip.GetName and tooltip:GetName()
    if not tooltipName or not tooltip.NumLines then
        return false
    end
    for lineNumber = 2, math.min(tooltip:NumLines(), 6) do
        local lineFontString = _G[tooltipName .. "TextLeft" .. lineNumber]
        local lineText = lineFontString and lineFontString:GetText()
        if lineText and not IsSecret(lineText)
            and (lineText == (ITEM_SOULBOUND or "Soulbound") or lineText == (ITEM_BIND_ON_PICKUP or "Binds when picked up")) then
            return true
        end
    end
    return false
end

-- Adds the sell line; currentResult (optional) is the comparison for your spec.
local function AddSellAdviceLine(tooltip, itemLink, currentResult, indentText)
    local sellAdvice = Mentor.SellAdvice
    if not (sellAdvice and MentorDB.isSellAdviceEnabled) then
        return
    end
    if not sellAdvice.IsAuctionatorLoaded() then
        tooltip:AddLine(indentText .. "Sell advice needs the Auctionator addon", 0.6, 0.6, 0.6)
        return
    end
    if currentResult and (currentResult.kind == "upgrade" or currentResult.kind == "empty") then
        return -- you want to wear this one, not sell it
    end
    local lineText, red, green, blue = sellAdvice.Describe(sellAdvice.Evaluate(itemLink, IsTooltipSoulbound(tooltip)),
        not AreDetailsShown())
    if lineText then
        tooltip:AddLine(indentText .. lineText, red, green, blue)
    end
end

-- Used when the Mentor tooltip lines are off but sell advice is on.
local function AddOnlySellAdviceToTooltip(tooltip)
    if tooltip == Mentor.scanTooltip or not tooltip.GetItem or MentorDB.areTooltipLinesEnabled then
        return
    end
    local _, itemLink = tooltip:GetItem()
    if not itemLink or IsSecret(itemLink) then
        return
    end
    local weights = GetCurrentWeights()
    local before = tooltip:NumLines()
    AddSellAdviceLine(tooltip, itemLink, weights and Mentor.CompareItem(itemLink, weights), "|cff66ccffMentor:|r ")
    if tooltip:NumLines() > before then
        tooltip:Show()
    end
end

local function AddComparisonToTooltip(tooltip)
    if tooltip == Mentor.scanTooltip or not tooltip.GetItem or not MentorDB.areTooltipLinesEnabled then
        return
    end
    local weights = GetCurrentWeights()
    if not weights then
        return
    end
    local _, itemLink = tooltip:GetItem()
    if not itemLink or IsSecret(itemLink) then
        return
    end
    local advice = Mentor.currentAdvice
    local currentResult = Mentor.CompareItem(itemLink, weights)

    -- Items that are not gear for you get one plain line.
    local isComparable = currentResult.kind == "upgrade" or currentResult.kind == "downgrade"
        or currentResult.kind == "same" or currentResult.kind == "empty"
    if not isComparable then
        local lineText, red, green, blue = Mentor.DescribeComparison(currentResult)
        if lineText then
            tooltip:AddLine("|cff66ccffMentor:|r " .. lineText, red, green, blue)
        end
        AddSellAdviceLine(tooltip, itemLink, currentResult, "|cff66ccffMentor:|r ")
        tooltip:Show()
        return
    end

    -- One line per spec of your class; your current spec is bright, the others grey.
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff66ccffMentor|r")
    for specNumber, specData in ipairs(advice.classData.specs) do
        local specResult = (specNumber == advice.specNumber) and currentResult
            or Mentor.CompareItem(itemLink, specData.weights)
        local specLabel = (specNumber == advice.specNumber) and ("|cffffffff" .. specData.name .. "|r")
            or ("|cffa6a6a6" .. specData.name .. "|r")
        local lineText, red, green, blue = Mentor.DescribeComparison(specResult, specLabel, true)
        if lineText then
            tooltip:AddLine("  " .. lineText, red, green, blue)
        end
    end
    if AreDetailsShown() then
        tooltip:AddLine("  total = all your gear, item = vs. what you wear in that slot", 0.5, 0.5, 0.5)
    end
    AddSellAdviceLine(tooltip, itemLink, currentResult, "  ")
    -- What actually changes compared with what you wear, one stat per line.
    local differenceLines = Mentor.GetStatDifferenceLines(currentResult.statDifference, weights,
        advice.specData and advice.specData.name, not AreDetailsShown())
    if #differenceLines > 0 then
        tooltip:AddLine("  Compared with what you wear:", 0.8, 0.8, 0.8)
        for _, differenceLine in ipairs(differenceLines) do
            tooltip:AddLine("    " .. differenceLine.text, differenceLine.red, differenceLine.green, differenceLine.blue)
        end
    end
    tooltip:Show() -- resize the tooltip to fit the new lines
end

function Mentor.HookItemTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            pcall(AddComparisonToTooltip, tooltip)
            pcall(AddOnlySellAdviceToTooltip, tooltip)
        end)
        return
    end
    for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tooltip and tooltip.HookScript then
            tooltip:HookScript("OnTooltipSetItem", function(self)
                pcall(AddComparisonToTooltip, self)
                pcall(AddOnlySellAdviceToTooltip, self)
            end)
        end
    end
end

--------------------------------------------------------------------------------
-- Looted upgrades
--------------------------------------------------------------------------------
local function BuildPattern(formatString)
    if not formatString then
        return nil
    end
    local pattern = formatString:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    pattern = pattern:gsub("%%%%s", "(.+)")
    pattern = pattern:gsub("%%%%d", "%%d+")
    return "^" .. pattern
end
local OWN_ITEM_PATTERNS = {
    BuildPattern(LOOT_ITEM_SELF_MULTIPLE), BuildPattern(LOOT_ITEM_SELF),
    BuildPattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE), BuildPattern(LOOT_ITEM_PUSHED_SELF),
}

local function CheckLootedItem(itemLink)
    local weights = GetCurrentWeights()
    if not weights then
        return
    end
    local result = Mentor.CompareItem(itemLink, weights)
    if result.kind == "upgrade" or result.kind == "empty" then
        local changeText = result.kind == "empty" and "fills an empty slot"
            or (Mentor.FormatPercentChange(result.percent) .. " for " .. GetCurrentSpecName())
        local levelText = result.requiredLevel and string.format(" (usable at level %d)", result.requiredLevel) or ""
        Mentor.Print(itemLink .. " is an upgrade: " .. GOOD_COLOR .. changeText .. "|r" .. levelText
            .. ". Open /mentor to equip it.")
        Mentor.RequestRefresh()
    end
end

function Mentor.HandleLootMessage(chatMessage)
    if not MentorDB.areLootAlertsEnabled or not chatMessage or IsSecret(chatMessage) then
        return
    end
    for _, pattern in ipairs(OWN_ITEM_PATTERNS) do
        local itemLink = pattern and chatMessage:match(pattern)
        if itemLink then
            -- The item may still be loading; check it a moment later.
            C_Timer.After(LOOT_CHECK_DELAY_SECONDS, function()
                pcall(CheckLootedItem, itemLink)
            end)
            return
        end
    end
end

--------------------------------------------------------------------------------
-- Quest rewards
--------------------------------------------------------------------------------
local questRewardGlow = CreateFrame("Frame", nil, UIParent)
questRewardGlow:SetFrameStrata("DIALOG")
questRewardGlow:Hide()
Mentor.AddBorder(questRewardGlow, 2, 0.25, 1.0, 0.25, 1)
local questRewardLabel = questRewardGlow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
questRewardLabel:SetPoint("BOTTOMRIGHT", questRewardGlow, "TOPRIGHT", 0, 1)
questRewardLabel:SetText("|cff40ff40Mentor pick|r")

local function HighlightQuestReward(choiceIndex)
    local rewardButton = _G["QuestInfoRewardsFrameQuestInfoItem" .. choiceIndex] or _G["QuestRewardItem" .. choiceIndex]
    if rewardButton and rewardButton:IsVisible() then
        questRewardGlow:ClearAllPoints()
        questRewardGlow:SetPoint("TOPLEFT", rewardButton, "TOPLEFT", -2, 2)
        questRewardGlow:SetPoint("BOTTOMRIGHT", rewardButton, "BOTTOMRIGHT", 2, -2)
        questRewardGlow:Show()
    end
end

function Mentor.HideQuestRewardGlow()
    questRewardGlow:Hide()
end

local function SuggestQuestReward()
    local weights = GetCurrentWeights()
    local choiceCount = GetNumQuestChoices and GetNumQuestChoices() or 0
    if not weights or choiceCount < 2 then
        return
    end
    -- An item for an empty slot beats any percentage upgrade.
    local EMPTY_SLOT_RANK = math.huge
    local bestUpgradeIndex, bestUpgradeRank, bestUpgradeResult, bestValueIndex, bestValue
    for choiceIndex = 1, choiceCount do
        local itemLink = GetQuestItemLink("choice", choiceIndex)
        if itemLink then
            local result = Mentor.CompareItem(itemLink, weights)
            local upgradeRank = (result.kind == "empty") and EMPTY_SLOT_RANK
                or (result.kind == "upgrade" and result.percent) or nil
            if upgradeRank and (not bestUpgradeRank or upgradeRank > bestUpgradeRank) then
                bestUpgradeIndex, bestUpgradeRank, bestUpgradeResult = choiceIndex, upgradeRank, result
            end
            local sellPrice = select(11, GetItemInfoCompat(itemLink)) or 0
            if not bestValue or sellPrice > bestValue then
                bestValueIndex, bestValue = choiceIndex, sellPrice
            end
        end
    end
    if bestUpgradeIndex then
        local changeText = bestUpgradeResult.kind == "empty" and "fills an empty slot"
            or Mentor.FormatPercentChange(bestUpgradeResult.percent)
        Mentor.Print("Best quest reward for you: " .. GetQuestItemLink("choice", bestUpgradeIndex)
            .. " (" .. GOOD_COLOR .. changeText .. "|r)")
        HighlightQuestReward(bestUpgradeIndex)
    elseif bestValueIndex then
        Mentor.Print("No reward is an upgrade. Take " .. GetQuestItemLink("choice", bestValueIndex)
            .. " - it sells for the most.")
        HighlightQuestReward(bestValueIndex)
    end
end

function Mentor.HandleQuestComplete()
    if not MentorDB.areQuestPicksEnabled then
        return
    end
    C_Timer.After(QUEST_CHECK_DELAY_SECONDS, function()
        pcall(SuggestQuestReward)
    end)
end

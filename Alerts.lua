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

-- Returns the sell line (text, red, green, blue), or nil. currentResult
-- (optional) is the comparison for your spec; upgrades are never sold.
local function GetSellAdviceLine(tooltip, itemLink, currentResult)
    local sellAdvice = Mentor.SellAdvice
    if not (sellAdvice and MentorDB.isSellAdviceEnabled) then
        return nil
    end
    if not sellAdvice.IsAuctionatorLoaded() then
        return "Sell advice needs the Auctionator addon", 0.6, 0.6, 0.6
    end
    if currentResult and (currentResult.kind == "upgrade" or currentResult.kind == "empty") then
        return nil -- you want to wear this one, not sell it
    end
    return sellAdvice.Describe(sellAdvice.Evaluate(itemLink, IsTooltipSoulbound(tooltip)), not AreDetailsShown())
end

local function AddSellAdviceLine(tooltip, itemLink, currentResult, indentText)
    local lineText, red, green, blue = GetSellAdviceLine(tooltip, itemLink, currentResult)
    if lineText then
        tooltip:AddLine(indentText .. lineText, red, green, blue)
    end
end

-- What to do with the item, shown right after "Mentor:" at the top:
--   Equip                       upgrade for your current spec
--   Equip at level 24           upgrade, but you need a higher level
--   Keep - upgrade for <spec>   not for your spec, but for another spec of yours
--   the sell advice             otherwise (when Sell advice is on)
local function GetActionLine(tooltip, itemLink, currentResult, otherSpecUpgradeName)
    if currentResult.kind == "upgrade" or currentResult.kind == "empty" then
        if currentResult.requiredLevel then
            return "Equip at level " .. currentResult.requiredLevel, 1.0, 0.85, 0.1
        end
        return "Equip", 0.25, 1.0, 0.25
    end
    if otherSpecUpgradeName then
        return "Keep - upgrade for " .. otherSpecUpgradeName, 0.6, 0.9, 0.6
    end
    return GetSellAdviceLine(tooltip, itemLink, currentResult)
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
        -- What to do with it first, then why ("You cannot use this item").
        AddSellAdviceLine(tooltip, itemLink, currentResult, "|cff66ccffMentor:|r ")
        local lineText, red, green, blue = Mentor.DescribeComparison(currentResult)
        if lineText then
            tooltip:AddLine("|cff66ccffMentor:|r " .. lineText, red, green, blue)
        end
        tooltip:Show()
        return
    end

    -- Compare once per spec of your class.
    local specLines = {}
    local otherSpecUpgradeName, bestOtherSpecGain = nil, 0
    for specNumber, specData in ipairs(advice.classData.specs) do
        local isCurrentSpec = specNumber == advice.specNumber
        local specResult = isCurrentSpec and currentResult or Mentor.CompareItem(itemLink, specData.weights)
        -- The other spec this helps most (largest gain over all your gear).
        local gainPercent = specResult.overallPercent or specResult.percent or 0
        if not isCurrentSpec and specResult.kind == "upgrade" and gainPercent > bestOtherSpecGain then
            otherSpecUpgradeName, bestOtherSpecGain = specData.name, gainPercent
        end
        local specLabel = isCurrentSpec and ("|cffffffff" .. specData.name .. "|r") or ("|cffa6a6a6" .. specData.name .. "|r")
        local lineText, red, green, blue = Mentor.DescribeComparison(specResult, specLabel, true)
        if lineText then
            table.insert(specLines, { lineText, red, green, blue })
        end
    end

    -- Header with the verdict, then one line per spec (your current spec bright, the others grey).
    tooltip:AddLine(" ")
    local actionText, actionRed, actionGreen, actionBlue = GetActionLine(tooltip, itemLink, currentResult, otherSpecUpgradeName)
    if actionText then
        tooltip:AddLine("|cff66ccffMentor:|r " .. actionText, actionRed, actionGreen, actionBlue)
    else
        tooltip:AddLine("|cff66ccffMentor|r")
    end
    for _, specLine in ipairs(specLines) do
        tooltip:AddLine("  " .. specLine[1], specLine[2], specLine[3], specLine[4])
    end
    if AreDetailsShown() then
        tooltip:AddLine("  total = all your gear, item = vs. what you wear in that slot", 0.5, 0.5, 0.5)
    end
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
-- The "Mentor pick" marker: a rounded gold frame around the reward with a
-- soft pulsing glow, and a small tag with the Mentor logo above it that says
-- why ("+3.2%" or "sells best").
local MENTOR_GOLD = { 1.00, 0.78, 0.10 }
local questRewardGlow = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
questRewardGlow:SetFrameStrata("DIALOG")
questRewardGlow:Hide()
if questRewardGlow.SetBackdrop then
    questRewardGlow:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
    questRewardGlow:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 1)
else
    Mentor.AddBorder(questRewardGlow, 2, MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 1)
end
-- Soft gold light that fills the frame exactly (added on top of the reward
-- so it brightens it), pulsing slowly.
local questRewardShine = questRewardGlow:CreateTexture(nil, "ARTWORK")
questRewardShine:SetColorTexture(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.22)
questRewardShine:SetBlendMode("ADD")
questRewardShine:SetPoint("TOPLEFT", 3, -3)
questRewardShine:SetPoint("BOTTOMRIGHT", -3, 3)
if questRewardGlow.CreateAnimationGroup then
    local pulse = questRewardGlow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    if fade and fade.SetFromAlpha then
        fade:SetTarget(questRewardShine)
        fade:SetFromAlpha(0.3)
        fade:SetToAlpha(1)
        fade:SetDuration(0.9)
    end
    questRewardGlow:SetScript("OnShow", function() pulse:Play() end)
    questRewardGlow:SetScript("OnHide", function() pulse:Stop() end)
end
-- Tag above the reward: [logo] Mentor pick  +3.2%
local questRewardTag = CreateFrame("Frame", nil, questRewardGlow, BackdropTemplateMixin and "BackdropTemplate" or nil)
questRewardTag:SetHeight(18)
questRewardTag:SetPoint("BOTTOMLEFT", questRewardGlow, "TOPLEFT", 0, -3)
if questRewardTag.SetBackdrop then
    questRewardTag:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    questRewardTag:SetBackdropColor(0.06, 0.05, 0.03, 0.95)
    questRewardTag:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 1)
end
local questRewardLogo = questRewardTag:CreateTexture(nil, "ARTWORK")
questRewardLogo:SetTexture("Interface\\AddOns\\Mentor\\Media\\Logo")
questRewardLogo:SetSize(13, 13)
questRewardLogo:SetPoint("LEFT", 4, 0)
local questRewardLabel = questRewardTag:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
questRewardLabel:SetPoint("LEFT", questRewardLogo, "RIGHT", 4, 0)

-- reasonText: "+3.2%", "new slot" or "sells best".
local function HighlightQuestReward(choiceIndex, reasonText)
    local rewardButton = _G["QuestInfoRewardsFrameQuestInfoItem" .. choiceIndex] or _G["QuestRewardItem" .. choiceIndex]
    if rewardButton and rewardButton:IsVisible() then
        -- Tight around what you see: the icon on the left (top and bottom) and
        -- the name plate on the right (its texture has some empty space at the
        -- right end, so the frame stops a little before it).
        local buttonName = rewardButton:GetName() or ""
        local iconPart = rewardButton.Icon or rewardButton.icon or _G[buttonName .. "IconTexture"]
        local namePart = rewardButton.NameFrame or _G[buttonName .. "NameFrame"]
        questRewardGlow:ClearAllPoints()
        if iconPart and namePart then
            questRewardGlow:SetPoint("TOPLEFT", iconPart, "TOPLEFT", -3, 3)
            questRewardGlow:SetPoint("BOTTOMLEFT", iconPart, "BOTTOMLEFT", -3, -3)
            questRewardGlow:SetPoint("RIGHT", namePart, "RIGHT", -10, 0)
        else
            questRewardGlow:SetPoint("TOPLEFT", rewardButton, "TOPLEFT", -2, 2)
            questRewardGlow:SetPoint("BOTTOMRIGHT", rewardButton, "BOTTOMRIGHT", 0, -2)
        end
        questRewardLabel:SetText("Mentor pick" .. (reasonText and ("  |cff40ff40" .. reasonText .. "|r") or ""))
        questRewardTag:SetWidth((questRewardLabel:GetStringWidth() or 60) + 26)
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
        HighlightQuestReward(bestUpgradeIndex, bestUpgradeResult.kind == "empty" and "new slot"
            or Mentor.FormatPercentChange(bestUpgradeResult.percent))
    elseif bestValueIndex then
        Mentor.Print("No reward is an upgrade. Take " .. GetQuestItemLink("choice", bestValueIndex)
            .. " - it sells for the most.")
        HighlightQuestReward(bestValueIndex, "sells best")
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

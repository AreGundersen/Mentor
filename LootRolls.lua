--------------------------------------------------------------------------------
-- Mentor - LootRolls.lua
-- Advice on group loot rolls, like the quest reward pick: when a roll window
-- appears, Mentor puts a small tag above it and a gold frame around the
-- button it recommends:
--   Need    the item is an upgrade for the spec you play (or fills an empty slot)
--   Greed   anything else you can use or sell - including upgrades for one of
--           your other specs (good manners: Need is for your main spec)
--   Pass    nothing (Mentor never says Pass; it only says why Greed)
-- Setting: "Loot rolls" under Gear & loot (on by default).
--------------------------------------------------------------------------------

local _, Mentor = ...

local MENTOR_GOLD = { 1.00, 0.78, 0.10 }
local MAX_ROLL_FRAMES = 4
local SECONDS_BEFORE_MARKING = 0.1       -- the roll frame is filled in right after the event

local lootRolls = {}
Mentor.LootRolls = lootRolls

local markersByFrame = {}                -- roll frame -> { tag, buttonFrame }

local function IsOn()
    return MentorDB and MentorDB.areLootRollPicksEnabled ~= false
end

--------------------------------------------------------------------------------
-- The advice
--------------------------------------------------------------------------------
-- Returns "need" or "greed" and a short reason, or nil when there is nothing to say.
function lootRolls.GetAdvice(itemLink)
    local advice = Mentor.currentAdvice
    if not (itemLink and advice and advice.classData and Mentor.CompareItem) then
        return nil
    end
    if not (advice.specData and advice.specData.weights) then
        return nil
    end
    local currentResult = Mentor.CompareItem(itemLink, advice.specData.weights)
    if currentResult.kind == "upgrade" then
        local percentText = Mentor.FormatPercentChange and Mentor.FormatPercentChange(currentResult.percent) or ""
        return "need", "upgrade " .. percentText
    elseif currentResult.kind == "empty" then
        return "need", "new slot"
    elseif currentResult.kind == "cannotUse" then
        return "greed", "you can't use it"
    elseif currentResult.kind == "notGear" then
        return nil
    end
    -- Not for the spec you play: an upgrade for another spec is still Greed.
    for specNumber, specData in ipairs(advice.classData.specs) do
        if specNumber ~= advice.specNumber then
            local otherResult = Mentor.CompareItem(itemLink, specData.weights)
            if otherResult.kind == "upgrade" then
                return "greed", "only for " .. specData.name
            end
        end
    end
    return "greed", "not an upgrade"
end

--------------------------------------------------------------------------------
-- Roll frames (retail GroupLootContainer and the older GroupLootFrame1-4)
--------------------------------------------------------------------------------
local function GetRollFrames()
    local rollFrames = {}
    if GroupLootContainer and type(GroupLootContainer.rollFrames) == "table" then
        for _, rollFrame in pairs(GroupLootContainer.rollFrames) do
            table.insert(rollFrames, rollFrame)
        end
    end
    for frameIndex = 1, MAX_ROLL_FRAMES do
        local rollFrame = _G["GroupLootFrame" .. frameIndex]
        if rollFrame then
            table.insert(rollFrames, rollFrame)
        end
    end
    return rollFrames
end

local function GetRollButton(rollFrame, choice)
    local buttonName = choice == "need" and "NeedButton" or "GreedButton"
    return rollFrame[buttonName] or (rollFrame:GetName() and _G[rollFrame:GetName() .. buttonName])
end

local function GetMarker(rollFrame)
    local marker = markersByFrame[rollFrame]
    if marker then
        return marker
    end
    marker = {}
    -- Tag above the roll window: [logo] Mentor: Need  upgrade +12%
    marker.tag = CreateFrame("Frame", nil, rollFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    marker.tag:SetHeight(18)
    marker.tag:SetPoint("BOTTOMLEFT", rollFrame, "TOPLEFT", 6, -2)
    marker.tag:SetFrameLevel((rollFrame:GetFrameLevel() or 1) + 10)
    if marker.tag.SetBackdrop then
        marker.tag:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        marker.tag:SetBackdropColor(0.06, 0.05, 0.03, 0.95)
        marker.tag:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 1)
    end
    marker.logo = marker.tag:CreateTexture(nil, "ARTWORK")
    marker.logo:SetTexture("Interface\\AddOns\\Mentor\\Media\\Logo")
    marker.logo:SetSize(13, 13)
    marker.logo:SetPoint("LEFT", 4, 0)
    marker.label = marker.tag:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    marker.label:SetPoint("LEFT", marker.logo, "RIGHT", 4, 0)
    -- Gold frame around the recommended button.
    marker.buttonFrame = CreateFrame("Frame", nil, rollFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    marker.buttonFrame:SetFrameLevel((rollFrame:GetFrameLevel() or 1) + 10)
    if marker.buttonFrame.SetBackdrop then
        marker.buttonFrame:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })
        marker.buttonFrame:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 1)
    end
    markersByFrame[rollFrame] = marker
    return marker
end

local function HideMarker(rollFrame)
    local marker = markersByFrame[rollFrame]
    if marker then
        marker.tag:Hide()
        marker.buttonFrame:Hide()
    end
end

-- Marks every visible roll frame (called when a roll starts).
function lootRolls.MarkRollFrames()
    for _, rollFrame in ipairs(GetRollFrames()) do
        local rollId = rollFrame.rollID
        if rollFrame:IsShown() and rollId and IsOn() then
            local itemLink = GetLootRollItemLink and GetLootRollItemLink(rollId)
            local choice, reason = lootRolls.GetAdvice(itemLink)
            if choice then
                local marker = GetMarker(rollFrame)
                local choiceText = choice == "need" and "|cff40ff40Need|r" or "|cffffd100Greed|r"
                marker.label:SetText("Mentor: " .. choiceText .. "  |cffa6a6a6" .. reason .. "|r")
                marker.tag:SetWidth((marker.label:GetStringWidth() or 80) + 26)
                marker.tag:Show()
                local rollButton = GetRollButton(rollFrame, choice)
                if rollButton and rollButton:IsShown() then
                    marker.buttonFrame:ClearAllPoints()
                    marker.buttonFrame:SetPoint("TOPLEFT", rollButton, "TOPLEFT", -4, 4)
                    marker.buttonFrame:SetPoint("BOTTOMRIGHT", rollButton, "BOTTOMRIGHT", 4, -4)
                    marker.buttonFrame:Show()
                else
                    marker.buttonFrame:Hide()
                end
            else
                HideMarker(rollFrame)
            end
        else
            HideMarker(rollFrame)
        end
    end
end

local eventFrame = CreateFrame("Frame")
for _, eventName in ipairs({ "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "LOOT_ROLLS_COMPLETE" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end
eventFrame:SetScript("OnEvent", function()
    if C_Timer then
        C_Timer.After(SECONDS_BEFORE_MARKING, function() pcall(lootRolls.MarkRollFrames) end)
    end
end)

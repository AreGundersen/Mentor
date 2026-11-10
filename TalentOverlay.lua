--------------------------------------------------------------------------------
-- Mentor - TalentOverlay.lua
-- Graphics inside the game's talent window:
--   * the next talent gets a pulsing gold frame, a soft glow and a "NEXT" tag
--   * the following talents of the build get numbered badges (2, 3, 4, 5)
--   * a guide strip above the window names the next talent and your spec
--
-- WoW Forever uses the modern talent window (PlayerSpellsFrame.TalentsFrame,
-- loaded with Blizzard_PlayerSpells); buttons are found by trait node id.
-- Classic clients fall back to finding the button by its icon.
--------------------------------------------------------------------------------

local _, Mentor = ...

local GOLD = { 1.00, 0.78, 0.10 }
local FRAME_GAP = 5            -- pixels between the talent button and the gold frame
local FRAME_THICKNESS = 3
local HALO_SIZE = 16
local BADGE_SIZE = 18
local GUIDE_HEIGHT = 34
local CLASSIC_TALENT_FRAME_NAMES = { "PlayerTalentFrame", "TalentFrame" }

local overlay = {}            -- created widgets
Mentor.TalentOverlay = overlay

--------------------------------------------------------------------------------
-- Widget factories
--------------------------------------------------------------------------------

-- Four thin textures forming a rectangle border on a frame.
local function AddBorder(frame, thickness, red, green, blue, alpha, drawLayer)
    local edges = {}
    for edgeIndex = 1, 4 do
        local edge = frame:CreateTexture(nil, drawLayer or "OVERLAY")
        edge:SetColorTexture(red, green, blue, alpha or 1)
        edges[edgeIndex] = edge
    end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(thickness)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(thickness)
    edges[3]:SetPoint("TOPLEFT", 0, -thickness); edges[3]:SetPoint("BOTTOMLEFT", 0, thickness); edges[3]:SetWidth(thickness)
    edges[4]:SetPoint("TOPRIGHT", 0, -thickness); edges[4]:SetPoint("BOTTOMRIGHT", 0, thickness); edges[4]:SetWidth(thickness)
    return edges
end
Mentor.AddBorder = AddBorder

local function CreateNextMarker()
    local marker = CreateFrame("Frame", "MentorNextTalentMarker", UIParent)
    marker:Hide()

    local halo = marker:CreateTexture(nil, "BACKGROUND")
    halo:SetTexture("Interface\\Buttons\\CheckButtonGlow")
    halo:SetBlendMode("ADD")
    halo:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    halo:SetPoint("TOPLEFT", -HALO_SIZE, HALO_SIZE)
    halo:SetPoint("BOTTOMRIGHT", HALO_SIZE, -HALO_SIZE)

    AddBorder(marker, FRAME_THICKNESS, GOLD[1], GOLD[2], GOLD[3], 1)

    -- "NEXT" tag above the button.
    local tag = CreateFrame("Frame", nil, marker)
    tag:SetSize(40, 14)
    tag:SetPoint("BOTTOM", marker, "TOP", 0, 1)
    local tagBackground = tag:CreateTexture(nil, "BACKGROUND")
    tagBackground:SetAllPoints()
    tagBackground:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    local tagText = tag:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tagText:SetPoint("CENTER", 0, 0)
    tagText:SetTextColor(0, 0, 0)
    tagText:SetText("NEXT")

    -- Pulse.
    local pulse = marker:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.4)
    fade:SetDuration(0.6)
    fade:SetSmoothing("IN_OUT")
    marker.pulse = pulse
    return marker
end

local function CreateBadge(badgeNumber)
    local badge = CreateFrame("Frame", nil, UIParent)
    badge:SetSize(BADGE_SIZE, BADGE_SIZE)
    local background = badge:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    AddBorder(badge, 1, GOLD[1], GOLD[2], GOLD[3], 0.9)
    local numberText = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    numberText:SetPoint("CENTER", 1, 0)
    numberText:SetText(tostring(badgeNumber))
    badge:Hide()
    return badge
end

local function CreateGuideStrip()
    local strip = CreateFrame("Frame", "MentorTalentGuide", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    strip:SetHeight(GUIDE_HEIGHT)
    if strip.SetBackdrop then
        strip:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        strip:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    end
    strip.brand = strip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    strip.brand:SetPoint("LEFT", 10, 0)
    strip.brand:SetText("|cff66ccffMentor|r")
    strip.icon = strip:CreateTexture(nil, "ARTWORK")
    strip.icon:SetSize(22, 22)
    strip.icon:SetPoint("LEFT", strip.brand, "RIGHT", 10, 0)
    strip.text = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    strip.text:SetPoint("LEFT", strip.icon, "RIGHT", 8, 0)
    strip.detail = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    strip.detail:SetPoint("RIGHT", -10, 0)
    strip.detail:SetJustifyH("RIGHT")
    strip:Hide()
    return strip
end

overlay.nextMarker = CreateNextMarker()
overlay.badges = {}
for badgeIndex = 1, 4 do
    overlay.badges[badgeIndex] = CreateBadge(badgeIndex + 1)
end
overlay.guide = CreateGuideStrip()

--------------------------------------------------------------------------------
-- Finding the talent window and its buttons
--------------------------------------------------------------------------------
local function GetModernTalentsFrame()
    if PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame then
        return PlayerSpellsFrame.TalentsFrame, PlayerSpellsFrame
    end
    if ClassTalentFrame and ClassTalentFrame.TalentsTab then
        return ClassTalentFrame.TalentsTab, ClassTalentFrame
    end
    return nil, nil
end

local function GetClassicTalentFrame()
    for _, frameName in ipairs(CLASSIC_TALENT_FRAME_NAMES) do
        local candidateFrame = _G[frameName]
        if candidateFrame and candidateFrame:IsVisible() then
            return candidateFrame
        end
    end
    return nil
end

local function FindModernButton(talentsFrame, nodeId)
    if talentsFrame.GetTalentButtonByNodeID then
        local success, talentButton = pcall(talentsFrame.GetTalentButtonByNodeID, talentsFrame, nodeId)
        if success and talentButton then
            return talentButton
        end
    end
    if talentsFrame.EnumerateAllTalentButtons then
        local success, buttonIterator = pcall(talentsFrame.EnumerateAllTalentButtons, talentsFrame)
        if success and buttonIterator then
            for talentButton in buttonIterator do
                local buttonNodeId = (talentButton.GetNodeID and talentButton:GetNodeID()) or talentButton.nodeID
                if buttonNodeId == nodeId then
                    return talentButton
                end
            end
        end
    end
    return nil
end

-- Classic: search the visible buttons for the talent's icon.
local function FindClassicButton(parentFrame, talent, searchDepth)
    if searchDepth > 6 then
        return nil
    end
    for _, childFrame in ipairs({ parentFrame:GetChildren() }) do
        if childFrame:IsVisible() then
            if childFrame:GetObjectType() == "Button" then
                local buttonId = childFrame:GetID() or 0
                if buttonId == 0 or buttonId == talent.index then
                    local buttonName = childFrame:GetName()
                    local iconTexture = buttonName and _G[buttonName .. "IconTexture"]
                    if type(iconTexture) == "table" and iconTexture.GetTexture and iconTexture:GetTexture() == talent.icon then
                        return childFrame
                    end
                end
            end
            local foundButton = FindClassicButton(childFrame, talent, searchDepth + 1)
            if foundButton then
                return foundButton
            end
        end
    end
    return nil
end

-- Returns the talent window that is open right now, plus a function that
-- finds the button for a talent in it.
local function GetOpenTalentWindow()
    local talentsFrame, outerFrame = GetModernTalentsFrame()
    if talentsFrame and talentsFrame:IsVisible() then
        return outerFrame or talentsFrame, function(talent)
            return talent.nodeId and FindModernButton(talentsFrame, talent.nodeId)
        end
    end
    local classicFrame = GetClassicTalentFrame()
    if classicFrame then
        return classicFrame, function(talent)
            return FindClassicButton(classicFrame, talent, 1)
        end
    end
    return nil, nil
end
overlay.GetOpenTalentWindow = GetOpenTalentWindow

--------------------------------------------------------------------------------
-- Placing the graphics
--------------------------------------------------------------------------------
local function AttachToButton(widget, talentButton, frameLevelOffset)
    widget:SetParent(talentButton)
    widget:SetFrameStrata(talentButton:GetFrameStrata() or "HIGH")
    widget:SetFrameLevel((talentButton:GetFrameLevel() or 1) + frameLevelOffset)
end

function overlay.HideAll()
    overlay.nextMarker.pulse:Stop()
    overlay.nextMarker:Hide()
    for _, badge in ipairs(overlay.badges) do
        badge:Hide()
    end
    overlay.guide:Hide()
end

-- Called whenever the advice or the talent window changes.
function overlay.Update(advice)
    local talentWindow, findButton = GetOpenTalentWindow()
    if not (MentorDB and MentorDB.isTalentHighlightEnabled and talentWindow and advice) then
        overlay.HideAll()
        overlay.lastStatus = talentWindow and "window open, nothing to show" or "talent window closed"
        return
    end

    -- Guide strip above the talent window.
    local guide = overlay.guide
    guide:SetParent(talentWindow)
    guide:SetFrameStrata("HIGH")
    guide:ClearAllPoints()
    guide:SetPoint("BOTTOMLEFT", talentWindow, "TOPLEFT", 0, 4)
    guide:SetPoint("BOTTOMRIGHT", talentWindow, "TOPRIGHT", 0, 4)
    local nextTalent = advice.nextTalent
    local specName = advice.specData.name
    if nextTalent then
        guide.icon:SetTexture(nextTalent.icon)
        guide.icon:Show()
        local actionText = advice.unspentPoints > 0 and "Take" or "Next point"
        guide.text:SetText(string.format("%s: |cffffd100%s|r  %d/%d%s", actionText, nextTalent.name,
            nextTalent.rank + 1, nextTalent.maxRank, advice.isAutomatic and " |cffa6a6a6(best available)|r" or ""))
    else
        guide.icon:Hide()
        guide.text:SetText("Your build is complete.")
    end
    local pointsText = advice.unspentPoints > 0
        and string.format("|cff40ff40%d point%s to spend|r", advice.unspentPoints, advice.unspentPoints == 1 and "" or "s")
        or "|cffa6a6a6no free points|r"
    guide.detail:SetText(specName .. " build  ·  " .. pointsText)
    guide:Show()

    -- Gold frame on the next talent.
    local marker = overlay.nextMarker
    local nextButton = nextTalent and findButton(nextTalent)
    if nextButton and nextButton:IsVisible() then
        AttachToButton(marker, nextButton, 6)
        marker:ClearAllPoints()
        local outerOffset = FRAME_GAP + FRAME_THICKNESS
        marker:SetPoint("TOPLEFT", nextButton, "TOPLEFT", -outerOffset, outerOffset)
        marker:SetPoint("BOTTOMRIGHT", nextButton, "BOTTOMRIGHT", outerOffset, -outerOffset)
        marker:Show()
        if not marker.pulse:IsPlaying() then
            marker.pulse:Play()
        end
        overlay.lastStatus = "next talent marked"
    else
        marker.pulse:Stop()
        marker:Hide()
        overlay.lastStatus = nextTalent and "next talent's button not found" or "no next talent"
    end

    -- Numbered badges on the talents after that.
    for badgeIndex, badge in ipairs(overlay.badges) do
        local upcomingTalent = advice.upcomingTalents and advice.upcomingTalents[badgeIndex]
        local badgeButton = upcomingTalent and findButton(upcomingTalent)
        if badgeButton and badgeButton:IsVisible() then
            AttachToButton(badge, badgeButton, 7)
            badge:ClearAllPoints()
            badge:SetPoint("CENTER", badgeButton, "TOPRIGHT", -2, -2)
            badge:Show()
        else
            badge:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- Hooking the modern talent window when Blizzard loads it
--------------------------------------------------------------------------------
local isModernWindowHooked = false
function overlay.TryHookModernWindow(onChange)
    local talentsFrame, outerFrame = GetModernTalentsFrame()
    if isModernWindowHooked or not talentsFrame then
        return
    end
    isModernWindowHooked = true
    talentsFrame:HookScript("OnShow", onChange)
    talentsFrame:HookScript("OnHide", overlay.HideAll)
    if outerFrame and outerFrame ~= talentsFrame then
        outerFrame:HookScript("OnShow", onChange)
        outerFrame:HookScript("OnHide", overlay.HideAll)
    end
    -- The tree rebuilds its buttons on these.
    for _, methodName in ipairs({ "UpdateTreeInfo", "UpdateAllTalentButtons", "OnTraitConfigUpdated", "RefreshGates" }) do
        if type(talentsFrame[methodName]) == "function" then
            hooksecurefunc(talentsFrame, methodName, onChange)
        end
    end
end

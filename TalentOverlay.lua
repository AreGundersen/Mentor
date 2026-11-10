--------------------------------------------------------------------------------
-- Mentor - TalentOverlay.lua
-- Graphics inside the game's talent window:
--   * the next talent gets a pulsing gold frame, a soft glow and a "NEXT" tag
--   * the next 5 talent POINTS get numbers: badges show which points go into
--     a talent ("2-4" = points 2, 3 and 4 all go here)
--   * a guide strip above the window names the next talent, your spec, and
--     the plan for the next 5 points with the level each is spent at
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
local GUIDE_HEIGHT = 50
local MUTED_TEXT = "|cffa6a6a6"
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

-- A small gold-framed label on a talent button with the point numbers that
-- go into that talent ("2", "2-4" or "2,5"). It widens to fit the text.
local function CreateBadge()
    local badge = CreateFrame("Frame", nil, UIParent)
    badge:SetSize(BADGE_SIZE, BADGE_SIZE)
    local background = badge:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    AddBorder(badge, 1, GOLD[1], GOLD[2], GOLD[3], 0.9)
    badge.numberText = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge.numberText:SetPoint("CENTER", 1, 0)
    function badge:SetPointNumbers(numbersText)
        self.numberText:SetText(numbersText)
        local textWidth = self.numberText:GetStringWidth() or 0
        self:SetWidth(math.max(BADGE_SIZE, textWidth + 8))
    end
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
    strip.brand:SetPoint("TOPLEFT", 10, -10)
    strip.brand:SetText("|cff66ccffMentor|r")
    strip.icon = strip:CreateTexture(nil, "ARTWORK")
    strip.icon:SetSize(22, 22)
    strip.icon:SetPoint("LEFT", strip.brand, "RIGHT", 10, 0)
    strip.text = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    strip.text:SetPoint("LEFT", strip.icon, "RIGHT", 8, 0)
    strip.detail = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    strip.detail:SetPoint("TOPRIGHT", -10, -11)
    strip.detail:SetJustifyH("RIGHT")
    -- Second line: the plan for the next points.
    strip.plan = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    strip.plan:SetPoint("BOTTOMLEFT", 10, 8)
    strip.plan:SetPoint("BOTTOMRIGHT", -10, 8)
    strip.plan:SetJustifyH("LEFT")
    strip.plan:SetWordWrap(false)
    strip:Hide()
    return strip
end

overlay.nextMarker = CreateNextMarker()
-- At most 5 points are shown, so at most 5 different talents need a badge.
overlay.badges = {}
for badgeIndex = 1, 5 do
    overlay.badges[badgeIndex] = CreateBadge()
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

--------------------------------------------------------------------------------
-- Formatting the point plan
--------------------------------------------------------------------------------

-- {2,3,4} -> "2-4", {2,5} -> "2,5", {3} -> "3".
function overlay.FormatNumberList(numbers)
    local parts, rangeStart = {}, nil
    for numberIndex, number in ipairs(numbers) do
        rangeStart = rangeStart or number
        local nextNumber = numbers[numberIndex + 1]
        if nextNumber ~= number + 1 then
            table.insert(parts, rangeStart == number and tostring(number) or (rangeStart .. "-" .. number))
            rangeStart = nil
        end
    end
    return table.concat(parts, ",")
end

-- Groups the upcoming points by talent, in order of first appearance:
-- { { talent, pointNumbers = {1,2}, firstRank, lastRank, levels = {...}, isNow = {...} }, ... }
function overlay.GroupPointsByTalent(upcomingPoints)
    local talentGroups, groupByTalent = {}, {}
    for pointNumber, upcomingPoint in ipairs(upcomingPoints or {}) do
        local talentGroup = groupByTalent[upcomingPoint.talent]
        if not talentGroup then
            talentGroup = { talent = upcomingPoint.talent, pointNumbers = {}, levels = {}, nowFlags = {},
                firstRank = upcomingPoint.rank }
            groupByTalent[upcomingPoint.talent] = talentGroup
            table.insert(talentGroups, talentGroup)
        end
        table.insert(talentGroup.pointNumbers, pointNumber)
        table.insert(talentGroup.levels, upcomingPoint.level)
        table.insert(talentGroup.nowFlags, upcomingPoint.isNow == true)
        talentGroup.lastRank = upcomingPoint.rank
    end
    return talentGroups
end

-- "now", "27" or "27-29" (or "now-28" when it starts with free points).
local function FormatLevelSpan(talentGroup)
    local firstText = talentGroup.nowFlags[1] and "now" or ("lv " .. tostring(talentGroup.levels[1]))
    local lastIndex = #talentGroup.levels
    if lastIndex == 1 or (talentGroup.nowFlags[lastIndex] and talentGroup.nowFlags[1]) then
        return firstText
    end
    return firstText .. "-" .. tostring(talentGroup.levels[lastIndex])
end

-- One line for the guide strip:
-- "Next 5 points:  Gift of Nature 2-4/5 (now-lv 28)  >  Improved Rejuvenation 1/3 (lv 29)"
function overlay.FormatPointPlan(upcomingPoints)
    local talentGroups = overlay.GroupPointsByTalent(upcomingPoints)
    if #talentGroups == 0 then
        return ""
    end
    local groupTexts = {}
    for _, talentGroup in ipairs(talentGroups) do
        local rankText = talentGroup.firstRank == talentGroup.lastRank and tostring(talentGroup.firstRank)
            or (talentGroup.firstRank .. "-" .. talentGroup.lastRank)
        table.insert(groupTexts, string.format("|cffffd100%s|r %s/%d %s(%s)|r", talentGroup.talent.name,
            rankText, talentGroup.talent.maxRank or 1, MUTED_TEXT, FormatLevelSpan(talentGroup)))
    end
    return MUTED_TEXT .. "Next " .. #upcomingPoints .. " points:|r  " .. table.concat(groupTexts, MUTED_TEXT .. "  >  |r")
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
    guide.plan:SetText(overlay.FormatPointPlan(advice.upcomingPoints))
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

    -- Point numbers on the talents: one badge per talent, listing which of
    -- the next points go there. Point 1 is the NEXT talent itself, so its
    -- badge only appears when it gets more points ("2-3").
    local talentGroups = overlay.GroupPointsByTalent(advice.upcomingPoints)
    local badgeIndex = 0
    for _, talentGroup in ipairs(talentGroups) do
        local shownNumbers = {}
        for _, pointNumber in ipairs(talentGroup.pointNumbers) do
            if pointNumber > 1 then
                table.insert(shownNumbers, pointNumber)
            end
        end
        local talentButton = #shownNumbers > 0 and findButton(talentGroup.talent)
        if talentButton and talentButton:IsVisible() and overlay.badges[badgeIndex + 1] then
            badgeIndex = badgeIndex + 1
            local badge = overlay.badges[badgeIndex]
            AttachToButton(badge, talentButton, 7)
            badge:SetPointNumbers(overlay.FormatNumberList(shownNumbers))
            badge:ClearAllPoints()
            badge:SetPoint("CENTER", talentButton, "TOPRIGHT", -2, -2)
            badge:Show()
        end
    end
    for unusedIndex = badgeIndex + 1, #overlay.badges do
        overlay.badges[unusedIndex]:Hide()
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

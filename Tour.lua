--------------------------------------------------------------------------------
-- Mentor - Tour.lua
-- A short tour the first time Mentor is used: a few speech bubbles that
-- point at the Mentor window and its buttons and say what they do.
-- "Next" goes on, "Skip tour" ends it. It is shown once per character
-- (MentorDB.isTourDone); /mentor tour shows it again.
--------------------------------------------------------------------------------

local _, Mentor = ...

local BUBBLE_WIDTH = 260
local BUBBLE_PADDING = 12
local SECONDS_AFTER_LOGIN = 4
local GOLD = { 1.00, 0.78, 0.10 }

-- Each step: target (a key in Mentor.tourTargets, "window" for the Mentor
-- window, or nil for the middle of the screen), title and text.
local TOUR_STEPS = {
    { target = "window", title = "Welcome to Mentor!",
      text = "Mentor helps you level: it knows your class and spec and tells you what to do next. This window shows your build, your stats and how to play." },
    { target = nil, title = "Talents",
      text = "Open your talent window: the gold NEXT frame shows where your next point goes, and the strip above it shows the plan for the next 5 points." },
    { target = nil, title = "Gear",
      text = "Arrows on items in your bags: green = better, red = worse. Item tooltips start with what to do: Equip, Keep or how to sell it." },
    { target = "spellsButton", title = "Spells, macros and where to go",
      text = "New spells as you level, your racials, ready-made macros, and the Journey tab with zones and dungeons for your level." },
    { target = "lifeLogButton", title = "Life log",
      text = "Everything your character has done: kills, deaths, gold, loot and travel." },
    { target = "settingsButton", title = "Settings",
      text = "Turn things on or off here - including extras like Auto vendor, Level pace, One-key fishing and Mana warning." },
}

local tour = {}
Mentor.Tour = tour

local bubble
local currentStepIndex = 0

local function BuildBubble()
    bubble = CreateFrame("Frame", "MentorTourBubble", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bubble:SetWidth(BUBBLE_WIDTH)
    bubble:SetFrameStrata("FULLSCREEN_DIALOG")
    bubble:SetClampedToScreen(true)
    if bubble.SetBackdrop then
        bubble:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        bubble:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
    end
    bubble.logo = bubble:CreateTexture(nil, "ARTWORK")
    bubble.logo:SetTexture("Interface\\AddOns\\Mentor\\Media\\Logo")
    bubble.logo:SetSize(18, 18)
    bubble.logo:SetPoint("TOPLEFT", BUBBLE_PADDING - 2, -BUBBLE_PADDING + 2)
    bubble.title = bubble:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bubble.title:SetPoint("LEFT", bubble.logo, "RIGHT", 6, 0)
    bubble.stepText = bubble:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    bubble.stepText:SetPoint("TOPRIGHT", -BUBBLE_PADDING, -BUBBLE_PADDING)
    bubble.text = bubble:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bubble.text:SetPoint("TOPLEFT", BUBBLE_PADDING, -BUBBLE_PADDING - 24)
    bubble.text:SetWidth(BUBBLE_WIDTH - BUBBLE_PADDING * 2)
    bubble.text:SetJustifyH("LEFT")

    bubble.nextButton = CreateFrame("Button", nil, bubble, "UIPanelButtonTemplate")
    bubble.nextButton:SetSize(80, 20)
    bubble.nextButton:SetPoint("BOTTOMRIGHT", -BUBBLE_PADDING + 2, BUBBLE_PADDING - 2)
    bubble.nextButton:SetScript("OnClick", function() tour.ShowStep(currentStepIndex + 1) end)
    bubble.skipButton = CreateFrame("Button", nil, bubble, "UIPanelButtonTemplate")
    bubble.skipButton:SetSize(80, 20)
    bubble.skipButton:SetPoint("BOTTOMLEFT", BUBBLE_PADDING - 2, BUBBLE_PADDING - 2)
    bubble.skipButton:SetText("Skip tour")
    bubble.skipButton:SetScript("OnClick", function() tour.Finish() end)
    bubble:Hide()
end

-- The frame a step points at (nil when it explains something else).
local function GetStepTarget(step)
    local target = step.target and step.target ~= "window" and Mentor.tourTargets and Mentor.tourTargets[step.target]
    if target and target.IsVisible and target:IsVisible() then
        return target
    end
    return nil
end

-- A gold frame around the button the bubble talks about.
local targetHighlight
local function HighlightTarget(target)
    if not targetHighlight then
        targetHighlight = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        targetHighlight:SetFrameStrata("FULLSCREEN_DIALOG")
        if targetHighlight.SetBackdrop then
            targetHighlight:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
            targetHighlight:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
        end
    end
    if target then
        targetHighlight:ClearAllPoints()
        targetHighlight:SetPoint("TOPLEFT", target, "TOPLEFT", -4, 4)
        targetHighlight:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 4, -4)
        targetHighlight:Show()
    else
        targetHighlight:Hide()
    end
end

-- Every bubble sits right beside the Mentor window (on the side with room),
-- level with the button it explains, or at the top for general steps.
local BUBBLE_GAP = 10
local function PlaceBubble(target)
    local mentorWindow = _G["MentorFrame"]
    bubble:ClearAllPoints()
    if not (mentorWindow and mentorWindow:IsShown()) then
        bubble:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        return
    end
    local screenWidth = UIParent:GetWidth() or 0
    local windowRight = mentorWindow:GetRight()
    local isRoomOnRight = not windowRight or screenWidth <= 0 or windowRight + BUBBLE_GAP + BUBBLE_WIDTH <= screenWidth
    local verticalOffset = 0
    if target and target.GetTop and mentorWindow.GetTop and target:GetTop() and mentorWindow:GetTop() then
        verticalOffset = target:GetTop() - mentorWindow:GetTop()      -- level with the button
    end
    if isRoomOnRight then
        bubble:SetPoint("TOPLEFT", mentorWindow, "TOPRIGHT", BUBBLE_GAP, verticalOffset)
    else
        bubble:SetPoint("TOPRIGHT", mentorWindow, "TOPLEFT", -BUBBLE_GAP, verticalOffset)
    end
end

function tour.ShowStep(stepIndex)
    local step = TOUR_STEPS[stepIndex]
    if not step then
        tour.Finish()
        return
    end
    if not bubble then
        BuildBubble()
    end
    currentStepIndex = stepIndex
    bubble.title:SetText(step.title)
    bubble.stepText:SetText(stepIndex .. "/" .. #TOUR_STEPS)
    bubble.text:SetText(step.text)
    bubble.nextButton:SetText(stepIndex == #TOUR_STEPS and "Done" or "Next")
    local textHeight = bubble.text:GetStringHeight() or 40
    bubble:SetHeight(BUBBLE_PADDING * 2 + 24 + textHeight + 34)

    local target = GetStepTarget(step)
    PlaceBubble(target)
    HighlightTarget(target)
    bubble:Show()
end

function tour.Start()
    local success, errorMessage = pcall(tour.ShowStep, 1)
    if not success then
        Mentor.Print("The tour could not start: " .. tostring(errorMessage))
        error(errorMessage)          -- also caught by the bug report
    end
end

function tour.Finish()
    if bubble then
        bubble:Hide()
    end
    HighlightTarget(nil)
    currentStepIndex = 0
    if MentorDB then
        MentorDB.isTourDone = true
    end
end

function tour.IsShowing()
    return bubble ~= nil and bubble:IsShown()
end

-- First login with Mentor: start the tour once the window is up.
-- PLAYER_ENTERING_WORLD comes after the loading screen, when windows can show.
local hasTriedThisSession = false
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    if hasTriedThisSession or not C_Timer then
        return
    end
    hasTriedThisSession = true
    C_Timer.After(SECONDS_AFTER_LOGIN, function()
        if MentorDB and not MentorDB.isTourDone then
            local mentorWindow = _G["MentorFrame"]
            if mentorWindow and not mentorWindow:IsShown() then
                MentorDB.isShown = true          -- the tour points at the window
                mentorWindow:Show()
            end
            tour.Start()
        end
    end)
end)

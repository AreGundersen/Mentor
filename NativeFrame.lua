--------------------------------------------------------------------------------
-- Mentor - NativeFrame.lua
-- Makes Mentor's windows look like part of WoW: Blizzard's own window frame
-- (ButtonFrameTemplate - the frame of the character windows) with Mentor's
-- logo as the round portrait, the title in the title bar, and the content in
-- the dark inset. Also icon tabs along the right edge, like WoW Forever's.
--
-- Every function returns nil / false when this client lacks the template, so
-- the caller can fall back to Mentor's own dark box.
--------------------------------------------------------------------------------

local _, Mentor = ...

local nativeFrame = {}
Mentor.NativeFrame = nativeFrame

nativeFrame.LOGO_TEXTURE = "Interface\\AddOns\\Mentor\\Media\\Logo"
-- Where content can start under the portrait / title bar, and the inset edges.
nativeFrame.CONTENT_TOP = 70
nativeFrame.SUBTITLE_LEFT = 64      -- right of the portrait
nativeFrame.SUBTITLE_TOP = 30

-- A ButtonFrameTemplate window, or nil. The frame gets:
--   frame.isNative = true, frame.closeButton
local function FindField(frame, fieldName, containerName)
    local directValue = rawget(frame, fieldName) or frame[fieldName]
    if type(directValue) == "table" then
        return directValue
    end
    local container = containerName and frame[containerName]
    if type(container) == "table" and type(container[fieldName]) == "table" then
        return container[fieldName]
    end
    return nil
end

function nativeFrame.CreateWindow(frameName, parentFrame, titleText)
    local isCreated, window = pcall(CreateFrame, "Frame", frameName, parentFrame, "ButtonFrameTemplate")
    if not isCreated or not window then
        return nil
    end
    if ButtonFrameTemplate_HideButtonBar then
        pcall(ButtonFrameTemplate_HideButtonBar, window)
    end
    nativeFrame.SetTitle(window, titleText)
    local portraitTexture = FindField(window, "portrait", "PortraitContainer")
    if portraitTexture and portraitTexture.SetTexture then
        if SetPortraitToTexture then
            pcall(SetPortraitToTexture, portraitTexture, nativeFrame.LOGO_TEXTURE)
        else
            portraitTexture:SetTexture(nativeFrame.LOGO_TEXTURE)
        end
    end
    window.closeButton = FindField(window, "CloseButton")
    window.isNative = true
    return window
end

function nativeFrame.SetTitle(window, titleText)
    if type(window.SetTitle) == "function" and pcall(window.SetTitle, window, titleText) then
        return
    end
    local titleFontString = FindField(window, "TitleText", "TitleContainer")
    if titleFontString and titleFontString.SetText then
        titleFontString:SetText(titleText)
    end
end

-- Side tabs like WoW Forever's character and profession windows: square icon
-- buttons hanging off the window's right edge, the selected one with a gold
-- border, the tab's name in a tooltip. tabs = { { label = "Spells", icon =
-- "Interface\\Icons\\..." }, ... }; onSelect(tabIndex). Returns the tab
-- buttons, or nil when this client has no backdrop support (then the caller
-- uses its own tabs). window.sideTabsWidth tells how far they stick out.
nativeFrame.SIDE_TAB_SIZE = 40
nativeFrame.SIDE_TAB_GAP = 4
nativeFrame.SIDE_TAB_TOP = 34          -- below the title bar, like Blizzard's
local SIDE_TAB_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local SELECTED_BORDER_COLOR = { 1.00, 0.82, 0.00 }
local NORMAL_BORDER_COLOR = { 0.45, 0.45, 0.45 }
-- The side tab buttons of each window, for SelectTab.
local sideTabsByWindow = setmetatable({}, { __mode = "k" })

function nativeFrame.CreateSideTabs(window, tabs, onSelect)
    if not BackdropTemplateMixin then
        return nil
    end
    local tabButtons = {}
    for tabIndex, tab in ipairs(tabs) do
        local isCreated, tabButton = pcall(CreateFrame, "Button", nil, window, "BackdropTemplate")
        if not isCreated or not tabButton or not tabButton.SetBackdrop then
            for _, madeTab in ipairs(tabButtons) do
                madeTab:Hide()
            end
            return nil
        end
        tabButton:SetSize(nativeFrame.SIDE_TAB_SIZE, nativeFrame.SIDE_TAB_SIZE)
        -- Overlaps the window's stone border by 2 px so it looks attached.
        tabButton:SetPoint("TOPLEFT", window, "TOPRIGHT", -2,
            -nativeFrame.SIDE_TAB_TOP - (tabIndex - 1) * (nativeFrame.SIDE_TAB_SIZE + nativeFrame.SIDE_TAB_GAP))
        tabButton:SetBackdrop(SIDE_TAB_BACKDROP)
        tabButton:SetBackdropColor(0, 0, 0, 1)

        local iconTexture = tabButton:CreateTexture(nil, "ARTWORK")
        iconTexture:SetPoint("TOPLEFT", 5, -5)
        iconTexture:SetPoint("BOTTOMRIGHT", -5, 5)
        iconTexture:SetTexture(tab.icon)
        iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)     -- crop the icon's own border
        tabButton.iconTexture = iconTexture

        local highlightTexture = tabButton:CreateTexture(nil, "HIGHLIGHT")
        highlightTexture:SetAllPoints(iconTexture)
        highlightTexture:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlightTexture:SetBlendMode("ADD")

        tabButton:SetScript("OnClick", function()
            onSelect(tabIndex)
        end)
        tabButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tab.label)
            GameTooltip:Show()
        end)
        tabButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        tabButtons[tabIndex] = tabButton
    end
    sideTabsByWindow[window] = tabButtons
    window.sideTabsWidth = nativeFrame.SIDE_TAB_SIZE - 2
    return tabButtons
end

-- Marks one side tab as selected (gold border, full color) and dims the rest.
function nativeFrame.SelectTab(window, selectedIndex)
    for tabIndex, tabButton in ipairs(sideTabsByWindow[window] or {}) do
        local isSelected = tabIndex == selectedIndex
        local borderColor = isSelected and SELECTED_BORDER_COLOR or NORMAL_BORDER_COLOR
        tabButton:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
        local brightness = isSelected and 1 or 0.75
        tabButton.iconTexture:SetVertexColor(brightness, brightness, brightness)
    end
end

-- A scroll frame with the modern thin scroll bar (dark track, gold thumb) that
-- WoW's own windows use. Falls back to the classic one with the arrow buttons
-- when this client lacks the newer template.
function nativeFrame.CreateScrollFrame(frameName, parentFrame)
    local isCreated, scrollFrame = pcall(CreateFrame, "ScrollFrame", frameName, parentFrame, "ScrollFrameTemplate")
    if isCreated and scrollFrame and type(scrollFrame.ScrollBar) == "table" then
        return scrollFrame
    end
    if isCreated and scrollFrame then
        scrollFrame:Hide()     -- a half-made one; the fallback takes over its name
    end
    return CreateFrame("ScrollFrame", frameName, parentFrame, "UIPanelScrollFrameTemplate")
end

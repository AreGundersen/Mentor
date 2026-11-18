--------------------------------------------------------------------------------
-- Mentor - NativeFrame.lua
-- Makes Mentor's windows look like part of WoW: Blizzard's own window frame
-- (ButtonFrameTemplate - the frame of the character windows) with Mentor's
-- logo as the round portrait, the title in the title bar, and the content in
-- the dark inset. Also Blizzard's tabs along the bottom edge.
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

-- Blizzard tabs hanging under the window's bottom edge, like the character
-- window's. tabLabels = { "Spells", ... }; onSelect(tabIndex). Returns the
-- tab buttons, or nil when the tab template is missing.
function nativeFrame.CreateBottomTabs(window, tabLabels, onSelect)
    local windowName = window:GetName()
    if not windowName or not PanelTemplates_SetNumTabs then
        return nil
    end
    local tabButtons = {}
    for tabIndex, tabLabel in ipairs(tabLabels) do
        local isCreated, tabButton = pcall(CreateFrame, "Button", windowName .. "Tab" .. tabIndex, window,
            "PanelTabButtonTemplate")
        if not isCreated or not tabButton then
            -- Undo: a half-made tab row is worse than the fallback.
            for _, madeTab in ipairs(tabButtons) do
                madeTab:Hide()
            end
            return nil
        end
        tabButton:SetID(tabIndex)
        tabButton:SetText(tabLabel)
        if PanelTemplates_TabResize then
            pcall(PanelTemplates_TabResize, tabButton, 0)
        end
        if tabIndex == 1 then
            tabButton:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 11, 2)
        else
            tabButton:SetPoint("LEFT", tabButtons[tabIndex - 1], "RIGHT", -15, 0)
        end
        tabButton:SetScript("OnClick", function()
            onSelect(tabIndex)
        end)
        tabButtons[tabIndex] = tabButton
    end
    pcall(PanelTemplates_SetNumTabs, window, #tabButtons)
    return tabButtons
end

function nativeFrame.SelectTab(window, tabIndex)
    if PanelTemplates_SetTab then
        pcall(PanelTemplates_SetTab, window, tabIndex)
    end
end

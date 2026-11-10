--------------------------------------------------------------------------------
-- Mentor - InfoPanel.lua
-- Small movable "label | value" windows in the Mentor style, used by Level
-- pace (LevelPace.lua) and Auto vendor (AutoVendor.lua):
--
--   [logo] Level pace
--   ------------------------------
--   XP                 1,240 / 7,000
--   XP / hour                 18,400
--
-- The position is saved per window in MentorDB, and the windows follow the
-- Mentor lock (/mentor lock).
--------------------------------------------------------------------------------

local _, Mentor = ...

local PANEL_WIDTH = 210
local PANEL_PADDING = 10
local HEADER_HEIGHT = 22
local ROW_HEIGHT = 15
local LOGO_SIZE = 16
local LOGO_TEXTURE = "Interface\\AddOns\\Mentor\\Media\\Logo"
local GOLD = { 1.00, 0.78, 0.10 }
local LABEL_COLOR = { 0.85, 0.85, 0.85 }
local PANEL_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

--------------------------------------------------------------------------------
-- On/off switch in the Warcraft style: the game's own gold-framed check box
-- (the same one Blizzard's settings use).
--   isOn()            returns the current value
--   setOn(newValue)   called when clicked
--------------------------------------------------------------------------------
local SWITCH_SIZE = 22

function Mentor.CreateSwitch(parentFrame, isOn, setOn, tooltipText)
    local switch = CreateFrame("CheckButton", nil, parentFrame, "UICheckButtonTemplate")
    switch:SetSize(SWITCH_SIZE, SWITCH_SIZE)
    -- The template's built-in label is not used; the row has its own.
    for _, labelFieldName in ipairs({ "text", "Text" }) do
        local templateLabel = rawget(switch, labelFieldName)
        if type(templateLabel) == "table" and templateLabel.SetText then
            templateLabel:SetText("")
        end
    end

    function switch:Refresh()
        local isSwitchOn = isOn() and true or false
        self.isOn = isSwitchOn            -- kept for tests
        self:SetChecked(isSwitchOn)
    end
    switch:SetScript("OnClick", function(self)
        setOn(not isOn())
        if PlaySound and SOUNDKIT then
            PlaySound(isOn() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        end
        self:Refresh()
    end)
    if tooltipText then
        switch:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        switch:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    switch:Refresh()
    return switch
end

-- frameName: global frame name. title: shown next to the logo.
-- rowDefinitions: { { key = "xpPerHour", label = "XP / hour" }, ... }
--   A row with toggle = { isOn = function, setOn = function, tooltip = "..." }
--   gets an on/off switch instead of a value (panel.switches[key]).
-- footerButtonText (optional): a full-width button under the rows (panel.footerButton).
-- positionKey: MentorDB field that stores { point, relativePoint, offsetX, offsetY }.
-- defaultPosition: the same table, used the first time.
-- Returns the panel; panel.values[key] is the value FontString of each row.
local FOOTER_BUTTON_HEIGHT = 20

function Mentor.CreateInfoPanel(frameName, title, rowDefinitions, positionKey, defaultPosition, footerButtonText)
    local panel = CreateFrame("Frame", frameName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    local footerHeight = footerButtonText and (FOOTER_BUTTON_HEIGHT + 6) or 0
    panel:SetSize(PANEL_WIDTH, PANEL_PADDING * 2 + HEADER_HEIGHT + #rowDefinitions * ROW_HEIGHT + footerHeight)
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)
    if panel.SetBackdrop then
        panel:SetBackdrop(PANEL_BACKDROP)
        panel:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    end

    -- Header: logo, title, and a thin gold line under it.
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(LOGO_TEXTURE)
    logo:SetSize(LOGO_SIZE, LOGO_SIZE)
    logo:SetPoint("TOPLEFT", PANEL_PADDING - 2, -PANEL_PADDING + 2)
    local titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    titleText:SetText(title)
    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.3)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", PANEL_PADDING, -PANEL_PADDING - HEADER_HEIGHT + 4)
    divider:SetPoint("TOPRIGHT", -PANEL_PADDING, -PANEL_PADDING - HEADER_HEIGHT + 4)

    -- Rows: label on the left, value on the right.
    panel.values = {}
    panel.switches = {}
    for rowIndex, rowDefinition in ipairs(rowDefinitions) do
        local rowTopOffset = -PANEL_PADDING - HEADER_HEIGHT - (rowIndex - 1) * ROW_HEIGHT
        local labelText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        labelText:SetPoint("TOPLEFT", PANEL_PADDING, rowTopOffset)
        labelText:SetTextColor(LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3])
        labelText:SetText(rowDefinition.label)
        if rowDefinition.toggle then
            local switch = Mentor.CreateSwitch(panel, rowDefinition.toggle.isOn, rowDefinition.toggle.setOn,
                rowDefinition.toggle.tooltip)
            switch:SetPoint("TOPRIGHT", -PANEL_PADDING + 4, rowTopOffset + 5)
            panel.switches[rowDefinition.key] = switch
        else
            local valueText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            valueText:SetPoint("TOPRIGHT", -PANEL_PADDING, rowTopOffset)
            valueText:SetJustifyH("RIGHT")
            valueText:SetWidth(PANEL_WIDTH - PANEL_PADDING * 2 - 70)
            valueText:SetWordWrap(false)
            valueText:SetText("--")
            panel.values[rowDefinition.key] = valueText
        end
    end
    if footerButtonText then
        panel.footerButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        panel.footerButton:SetHeight(FOOTER_BUTTON_HEIGHT)
        panel.footerButton:SetPoint("BOTTOMLEFT", PANEL_PADDING, PANEL_PADDING)
        panel.footerButton:SetPoint("BOTTOMRIGHT", -PANEL_PADDING, PANEL_PADDING)
        panel.footerButton:SetText(footerButtonText)
    end
    -- Switches show their saved value whenever the window appears.
    panel:SetScript("OnShow", function(self)
        for _, switch in pairs(self.switches) do
            switch:Refresh()
        end
    end)

    -- Dragging (unless Mentor is locked); the position is saved in MentorDB.
    local function SavePosition()
        local point, _, relativePoint, offsetX, offsetY = panel:GetPoint()
        MentorDB[positionKey] = { point = point, relativePoint = relativePoint, offsetX = offsetX, offsetY = offsetY }
    end
    function panel:RestorePosition()
        local position = (MentorDB and type(MentorDB[positionKey]) == "table") and MentorDB[positionKey] or defaultPosition
        self:ClearAllPoints()
        self:SetPoint(position.point, UIParent, position.relativePoint, position.offsetX, position.offsetY)
    end
    function panel:ResetPosition()
        if MentorDB then
            MentorDB[positionKey] = nil
        end
        self:RestorePosition()
    end
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        if not MentorDB.isLocked then
            self:StartMoving()
        end
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    panel:Hide()
    return panel
end

-- "1g 2s 3c" with the game's coin icons (shared with Sell advice when loaded).
function Mentor.FormatMoneyWithIcons(copper)
    if Mentor.SellAdvice and Mentor.SellAdvice.FormatMoney then
        return Mentor.SellAdvice.FormatMoney(copper)
    end
    return tostring(math.floor(copper or 0)) .. "c"
end

-- True when the standalone version of one of Are's addons is also loaded,
-- so Mentor does not do the same job twice.
function Mentor.IsStandaloneAddonLoaded(addonName)
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName))
        or (IsAddOnLoaded and IsAddOnLoaded(addonName))
    return isLoaded and true or false
end

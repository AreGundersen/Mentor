--------------------------------------------------------------------------------
-- Mentor - UI.lua
-- The Mentor window, the build panel, events and slash commands.
--
-- Window layout (top to bottom):
--   header      class icon, class name, level and role
--   spec        three spec buttons; detected from talents, or pick one
--   next talent a card with the talent's icon, name, rank and tree
--   upgrades    up to five items in your bags that are better (click = equip)
--   stats/tips  what to look for on gear, and beginner tips
--
-- Slash commands:
--   /mentor                   show / hide the window
--   /mentor build             show / hide the full talent build
--   /mentor alerts on|off     chat alerts for looted upgrades
--   /mentor highlight on|off  graphics in the talent window
--   /mentor arrows on|off     upgrade / downgrade arrows on bag items
--   /mentor tooltip on|off    Mentor lines in item tooltips
--   /mentor quest on|off      best quest reward pick
--   /mentor minimap on|off    minimap button
--   /mentor settings          open the settings menu (also: right-click the minimap button)
--   /mentor rotation on|off   rotation bar
--   /mentor sell on|off       sell / disenchant advice (needs Auctionator)
--   /mentor details on|off    explanations and extra values in tooltips
--   /mentor pace on|off|reset Level pace window (LevelPace.lua)
--   /mentor vendor on|off     sell junk and repair at vendors (AutoVendor.lua)
--   /mentor keep|unkeep <item>, /mentor keeplist   grey items Auto vendor never sells
--   /mentor fishing on|off    One-key fishing window (Fishing.lua)
--   /mentor fish [key <KEY> | reset]   start / stop fishing mode
--   /mentor mana on|off|low|critical|...   Mana warning (ManaWarning.lua)
--   /mentor journey           zones, dungeons and professions for your level
--   /mentor tour              show the first-time tour again
--   /mentor lifelog on|off    Life log (LifeLog.lua); /mentor log [reset | wipe confirm | forget <name>]
--   /mentor guide             open the "How to play" guide
--   /mentor spells | racials | macros   open the "Spells & macros" panel on that tab
--   /mentor bug               report a bug (saved as text, see BugReport.lua)
--   /mentor debug             print what Mentor sees
--   /mentor lock | unlock     lock or unlock the window position
--   /mentor center            move the window back to the middle of the screen
--------------------------------------------------------------------------------

local ADDON_NAME, Mentor = ...

--------------------------------------------------------------------------------
-- Look and layout
--------------------------------------------------------------------------------
local WINDOW_WIDTH            = 320
local PADDING                 = 12
local CONTENT_WIDTH           = WINDOW_WIDTH - PADDING * 2
local HEADER_HEIGHT           = 54
local SPEC_BUTTON_HEIGHT      = 54
local SPEC_BUTTON_GAP         = 6
local CARD_HEIGHT             = 58
local UPGRADE_ROW_HEIGHT      = 22
local MAX_UPGRADE_ROWS        = 5
local SECTION_GAP             = 10
local BUILD_PANEL_WIDTH       = 280
local BUILD_ROW_HEIGHT        = 18
local REFRESH_THROTTLE_SECONDS = 0.4
local OVERLAY_REFRESH_SECONDS = 0.5

local GOLD                    = { 1.00, 0.78, 0.10 }
local GOLD_TEXT               = "|cffffd100"
local MUTED_TEXT              = "|cffa6a6a6"
local GOOD_TEXT               = "|cff40ff40"
local BRAND_TEXT              = "|cff66ccff"
local WINDOW_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local DEFAULT_SETTINGS = {
    isShown = true,
    isLocked = false,
    isBuildShown = false,
    areLootAlertsEnabled = true,
    isTalentHighlightEnabled = true,
    areBagArrowsEnabled = true,
    areTooltipLinesEnabled = true,
    areTooltipDetailsShown = true, -- explanations, legend and extra values in tooltips
    areQuestPicksEnabled = true,
    isMinimapButtonShown = true,
    isRotationBarShown = true,
    isSellAdviceEnabled = false,   -- sell / disenchant advice, needs Auctionator
    isLevelPaceEnabled = false,    -- Level pace window (LevelPace.lua)
    isAutoVendorEnabled = false,   -- sell junk and repair at vendors (AutoVendor.lua)
    isFishingEnabled = false,      -- One-key fishing window (Fishing.lua)
    isLifeLogEnabled = true,       -- Life log: records everything your character does (LifeLog.lua)
    isManaWarningEnabled = false,  -- Mana warning box and LOW MANA warnings (ManaWarning.lua)
    isManaSoundEnabled = true,
    isManaPartyMessageEnabled = true,
    isManaCombatOnly = false,
    isTrainerReminderEnabled = true,   -- chat reminders (Reminders.lua)
    areSupplyRemindersEnabled = true,
    areBagRemindersEnabled = true,
    areDungeonTipsEnabled = true,      -- tip when you enter a dungeon (Journey.lua)
    isTourDone = false,                -- first-time tour (Tour.lua)
    guideTab = "rotation",
    minimapAngle = 200,          -- degrees around the minimap
    point = "CENTER", relativePoint = "CENTER", offsetX = -320, offsetY = 80,
}

--------------------------------------------------------------------------------
-- Settings shared by all your characters (MentorAccountDB.settings)
-- Window positions and which panels are open stay per character; every
-- on/off setting and option is remembered for the whole account: a new
-- character starts with the settings you used last, and a change on one
-- character carries over to the others at their next login.
--------------------------------------------------------------------------------
local PER_CHARACTER_SETTINGS = {
    isShown = true, isBuildShown = true, guideTab = true, extrasTab = true,
    point = true, relativePoint = true, offsetX = true, offsetY = true,
    isLifeLogImported = true, isManaWarningImported = true, keptJunkItemIds = true,
}
-- Settings that are not in DEFAULT_SETTINGS but are still shared.
local EXTRA_ACCOUNT_SETTINGS = {
    "isAutoSellEnabled", "isAutoRepairEnabled", "isSellVendorItemsEnabled",
    "manaLowPercent", "manaCriticalPercent", "fishingKey", "minimapAngle",
}

local function ForEachAccountSettingName(handleSettingName)
    for settingName in pairs(DEFAULT_SETTINGS) do
        if not PER_CHARACTER_SETTINGS[settingName] then
            handleSettingName(settingName)
        end
    end
    for _, settingName in ipairs(EXTRA_ACCOUNT_SETTINGS) do
        handleSettingName(settingName)
    end
end

-- At load: take the account's settings over this character's.
function Mentor.ApplyAccountSettings()
    MentorAccountDB = MentorAccountDB or {}
    MentorAccountDB.settings = MentorAccountDB.settings or {}
    local accountSettings = MentorAccountDB.settings
    ForEachAccountSettingName(function(settingName)
        if accountSettings[settingName] ~= nil then
            MentorDB[settingName] = accountSettings[settingName]
        end
    end)
end

-- After every change and at logout: remember this character's settings for the account.
function Mentor.SaveAccountSettings()
    if not (MentorDB and MentorAccountDB and MentorAccountDB.settings) then
        return
    end
    ForEachAccountSettingName(function(settingName)
        if type(MentorDB[settingName]) ~= "table" then
            MentorAccountDB.settings[settingName] = MentorDB[settingName]
        end
    end)
end

--------------------------------------------------------------------------------
-- Shared helpers
--------------------------------------------------------------------------------
function Mentor.Print(text)
    DEFAULT_CHAT_FRAME:AddMessage(BRAND_TEXT .. "Mentor:|r " .. text)
end

local isRefreshNeeded = true
function Mentor.RequestRefresh()
    isRefreshNeeded = true
end

local function GetClassColor(classFileName)
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFileName]
    if classColor then
        return classColor.r, classColor.g, classColor.b, classColor.colorStr and ("|c" .. classColor.colorStr) or "|cffffffff"
    end
    return 1, 1, 1, "|cffffffff"
end

local function CreateText(parentFrame, fontObject, width, justify)
    local fontString = parentFrame:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
    fontString:SetJustifyH(justify or "LEFT")
    if width then
        fontString:SetWidth(width)
    end
    return fontString
end

local function ApplyBackdrop(frame, borderRed, borderGreen, borderBlue)
    if frame.SetBackdrop then
        frame:SetBackdrop(WINDOW_BACKDROP)
        frame:SetBackdropBorderColor(borderRed or GOLD[1], borderGreen or GOLD[2], borderBlue or GOLD[3], 0.9)
    end
end

--------------------------------------------------------------------------------
-- Main window
--------------------------------------------------------------------------------
local mainFrame = CreateFrame("Frame", "MentorFrame", UIParent, BACKDROP_TEMPLATE)
local widgets = {}
local specButtons = {}
local upgradeRows = {}

local function SaveWindowPosition()
    local point, _, relativePoint, offsetX, offsetY = mainFrame:GetPoint()
    MentorDB.point, MentorDB.relativePoint, MentorDB.offsetX, MentorDB.offsetY = point, relativePoint, offsetX, offsetY
end

local function RestoreWindowPosition()
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(MentorDB.point, UIParent, MentorDB.relativePoint, MentorDB.offsetX, MentorDB.offsetY)
end

-- Thin gold line between sections.
local function AddDivider(verticalOffset)
    local divider = mainFrame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", PADDING, verticalOffset)
    divider:SetPoint("TOPRIGHT", -PADDING, verticalOffset)
end

local function AddSectionLabel(labelText, verticalOffset)
    local label = CreateText(mainFrame, "GameFontNormalSmall", CONTENT_WIDTH)
    label:SetPoint("TOPLEFT", PADDING, verticalOffset)
    label:SetText(GOLD_TEXT .. labelText:upper() .. "|r")
    return label
end

local function EquipItemFromBags(itemLink, targetSlot)
    if InCombatLockdown() then
        Mentor.Print("You can't change gear in combat.")
        return
    end
    local equipFunction = (C_Item and C_Item.EquipItemByName) or EquipItemByName
    if equipFunction then
        pcall(equipFunction, itemLink, targetSlot)
    end
end

local function OnSpecButtonClicked(specButton)
    local advice = Mentor.currentAdvice
    if not advice then
        return
    end
    -- Clicking a spec always switches to it. Clicking the spec you already
    -- chose again hands the choice back to Mentor (detected from talents).
    if MentorDB.chosenSpec == specButton.specNumber then
        MentorDB.chosenSpec = nil
        Mentor.Print("Spec is automatic again (from your talents).")
    else
        MentorDB.chosenSpec = specButton.specNumber
    end
    Mentor.ClearItemCache()
    Mentor.RequestRefresh()
end

local function CreateSpecButton(specIndex, verticalOffset)
    local buttonWidth = (CONTENT_WIDTH - SPEC_BUTTON_GAP * 2) / 3
    local specButton = CreateFrame("Button", nil, mainFrame, BACKDROP_TEMPLATE)
    specButton:SetSize(buttonWidth, SPEC_BUTTON_HEIGHT)
    specButton:SetPoint("TOPLEFT", PADDING + (specIndex - 1) * (buttonWidth + SPEC_BUTTON_GAP), verticalOffset)
    if specButton.SetBackdrop then
        specButton:SetBackdrop(Mentor.BOX_BACKDROP)
    end
    specButton.specNumber = specIndex

    specButton.icon = specButton:CreateTexture(nil, "ARTWORK")
    specButton.icon:SetSize(28, 28)
    specButton.icon:SetPoint("TOP", 0, -6)
    specButton.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    specButton.nameText = CreateText(specButton, "GameFontHighlightSmall", buttonWidth - 4, "CENTER")
    specButton.nameText:SetPoint("TOP", specButton.icon, "BOTTOM", 0, -3)
    specButton.nameText:SetWordWrap(false)

    specButton.tagText = CreateText(specButton, "GameFontNormalSmall", buttonWidth, "CENTER")
    specButton.tagText:SetPoint("BOTTOM", specButton, "TOP", 0, 1)

    local highlight = specButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.06)

    specButton:SetScript("OnClick", OnSpecButtonClicked)
    specButton:SetScript("OnEnter", function(self)
        local advice = Mentor.currentAdvice
        local specData = advice and advice.classData.specs[self.specNumber]
        if not specData then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(specData.name)
        GameTooltip:AddLine(specData.role, 1, 1, 1)
        GameTooltip:AddLine("Best stats: " .. specData.statPriority, 0.8, 0.8, 0.8, true)
        if MentorDB.chosenSpec == self.specNumber then
            GameTooltip:AddLine("Click again to let Mentor pick from your talents.", 0.4, 0.8, 1.0, true)
        else
            GameTooltip:AddLine("Click to switch to this spec: build, gear and guide.", 0.4, 0.8, 1.0, true)
        end
        GameTooltip:Show()
    end)
    specButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    specButtons[specIndex] = specButton
end

local function CreateUpgradeRow(rowIndex, verticalOffset)
    local row = CreateFrame("Button", nil, mainFrame)
    row:SetSize(CONTENT_WIDTH, UPGRADE_ROW_HEIGHT - 2)
    row:SetPoint("TOPLEFT", PADDING, verticalOffset)
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.07)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(UPGRADE_ROW_HEIGHT - 4, UPGRADE_ROW_HEIGHT - 4)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.percentText = CreateText(row, "GameFontHighlightSmall", 80, "RIGHT")
    row.percentText:SetPoint("RIGHT", -4, 0)
    row.nameText = CreateText(row, "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.nameText:SetPoint("RIGHT", row.percentText, "LEFT", -4, 0)
    row.nameText:SetWordWrap(false)

    row:SetScript("OnClick", function(self)
        if self.itemLink then
            EquipItemFromBags(self.itemLink, self.targetSlot)
        end
    end)
    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:AddLine("Click to equip", 0.4, 0.8, 1.0)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:Hide()
    upgradeRows[rowIndex] = row
end

--------------------------------------------------------------------------------
-- Side panels (settings, build, spells) open on the side of the Mentor
-- window where there is room: right normally, left when the window is near
-- the right edge of the screen - so they never cover the Mentor window.
--------------------------------------------------------------------------------
local sidePanels = {}      -- { frame = panel, stretch = true when it spans the window's height }
local SIDE_PANEL_GAP = 2

function Mentor.RegisterSidePanel(panel, isStretched)
    table.insert(sidePanels, { frame = panel, stretch = isStretched })
    Mentor.PlaceSidePanels()
end

function Mentor.PlaceSidePanels()
    if Mentor.Tour then
        Mentor.Tour.Reposition()
    end
    local screenWidth = UIParent:GetWidth() or 0
    local windowRight = mainFrame:GetRight()
    for _, sidePanel in ipairs(sidePanels) do
        local panel = sidePanel.frame
        local panelWidth = panel:GetWidth() or 0
        local isRoomOnRight = not windowRight or screenWidth <= 0 or windowRight + SIDE_PANEL_GAP + panelWidth <= screenWidth
        panel:ClearAllPoints()
        if isRoomOnRight then
            panel:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", SIDE_PANEL_GAP, 0)
            if sidePanel.stretch then
                panel:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMRIGHT", SIDE_PANEL_GAP, 0)
            end
        else
            panel:SetPoint("TOPRIGHT", mainFrame, "TOPLEFT", -SIDE_PANEL_GAP, 0)
            if sidePanel.stretch then
                panel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMLEFT", -SIDE_PANEL_GAP, 0)
            end
        end
    end
end

local function BuildMainWindow()
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self)
        if not MentorDB.isLocked then
            self:StartMoving()
            -- While dragging, switch the side panels to the side with room.
            self:SetScript("OnUpdate", function() Mentor.PlaceSidePanels() end)
        end
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetScript("OnUpdate", nil)
        SaveWindowPosition()
        Mentor.PlaceSidePanels()
    end)
    ApplyBackdrop(mainFrame)

    -- Header: class icon, class name, level and role.
    widgets.classIcon = mainFrame:CreateTexture(nil, "ARTWORK")
    widgets.classIcon:SetSize(38, 38)
    widgets.classIcon:SetPoint("TOPLEFT", PADDING, -PADDING)
    widgets.classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    widgets.className = CreateText(mainFrame, "GameFontNormalLarge")
    widgets.className:SetPoint("TOPLEFT", widgets.classIcon, "TOPRIGHT", 10, -2)
    widgets.subtitle = CreateText(mainFrame, "GameFontHighlightSmall")
    widgets.subtitle:SetPoint("TOPLEFT", widgets.className, "BOTTOMLEFT", 0, -3)
    local closeButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function()
        MentorDB.isShown = false
        mainFrame:Hide()
    end)
    local settingsButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    settingsButton:SetSize(70, 20)
    settingsButton:SetPoint("TOPRIGHT", -32, -PADDING + 2)
    settingsButton:SetText("Settings")
    settingsButton:SetScript("OnClick", function()
        Mentor.ToggleSettings()
    end)
    -- Life log window, left of Settings.
    local lifeLogButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    lifeLogButton:SetSize(70, 20)
    lifeLogButton:SetPoint("RIGHT", settingsButton, "LEFT", -4, 0)
    lifeLogButton:SetText("Life log")
    lifeLogButton:SetScript("OnClick", function()
        Mentor.LifeLog.ToggleWindow()
    end)
    lifeLogButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Life log")
        GameTooltip:AddLine("Your character's story: kills, deaths, gold, loot, travel and more.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    lifeLogButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Things the first-time tour (Tour.lua) points at.
    Mentor.tourTargets = Mentor.tourTargets or {}
    Mentor.tourTargets.settingsButton = settingsButton
    Mentor.tourTargets.lifeLogButton = lifeLogButton
    -- Report a bug, right under Settings so it is always in view.
    local bugButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    bugButton:SetSize(70, 18)
    bugButton:SetPoint("TOP", settingsButton, "BOTTOM", 0, -3)
    bugButton:SetNormalFontObject("GameFontNormalSmall")
    bugButton:SetHighlightFontObject("GameFontHighlightSmall")
    bugButton:SetText("Report bug")
    bugButton:SetScript("OnClick", function()
        Mentor.BugReport.Open()
    end)
    bugButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Report a bug")
        GameTooltip:AddLine("Something looks wrong? Tell us what happened and Mentor saves it with all the details.", 1, 1, 1, true)
        local errorCount = Mentor.BugReport.GetErrorCount()
        if errorCount > 0 then
            GameTooltip:AddLine(errorCount .. " error(s) caught - they are added to the report.", 1, 0.5, 0.3, true)
        else
            GameTooltip:AddLine("No errors caught.", 0.25, 1.0, 0.25)
        end
        GameTooltip:Show()
    end)
    bugButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local verticalOffset = -PADDING - HEADER_HEIGHT
    AddDivider(verticalOffset)
    verticalOffset = verticalOffset - SECTION_GAP

    -- Spec buttons.
    AddSectionLabel("Your spec", verticalOffset)
    widgets.specStatus = CreateText(mainFrame, "GameFontHighlightSmall", CONTENT_WIDTH - 80, "RIGHT")
    widgets.specStatus:SetPoint("TOPRIGHT", -PADDING, verticalOffset)
    verticalOffset = verticalOffset - 28
    for specIndex = 1, 3 do
        CreateSpecButton(specIndex, verticalOffset)
    end
    verticalOffset = verticalOffset - SPEC_BUTTON_HEIGHT - SECTION_GAP
    AddDivider(verticalOffset)
    verticalOffset = verticalOffset - SECTION_GAP

    -- Next talent card.
    AddSectionLabel("Next talent", verticalOffset)
    verticalOffset = verticalOffset - 16
    local card = CreateFrame("Frame", nil, mainFrame, BACKDROP_TEMPLATE)
    card:SetSize(CONTENT_WIDTH, CARD_HEIGHT)
    card:SetPoint("TOPLEFT", PADDING, verticalOffset)
    if card.SetBackdrop then
        card:SetBackdrop(Mentor.BOX_BACKDROP)
        card:SetBackdropColor(0, 0, 0, 0.35)
        card:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.35)
    end
    widgets.talentIconFrame = CreateFrame("Frame", nil, card)
    widgets.talentIconFrame:SetSize(42, 42)
    widgets.talentIconFrame:SetPoint("LEFT", 8, 0)
    widgets.talentIcon = widgets.talentIconFrame:CreateTexture(nil, "ARTWORK")
    widgets.talentIcon:SetPoint("TOPLEFT", 2, -2)
    widgets.talentIcon:SetPoint("BOTTOMRIGHT", -2, 2)
    widgets.talentIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    Mentor.AddRoundedBorder(widgets.talentIconFrame, GOLD[1], GOLD[2], GOLD[3], 1, 12)
    widgets.talentName = CreateText(card, "GameFontNormalLarge", CONTENT_WIDTH - 70)
    widgets.talentName:SetPoint("TOPLEFT", widgets.talentIconFrame, "TOPRIGHT", 10, -3)
    widgets.talentName:SetWordWrap(false)
    widgets.talentDetail = CreateText(card, "GameFontHighlightSmall", CONTENT_WIDTH - 70)
    widgets.talentDetail:SetPoint("TOPLEFT", widgets.talentName, "BOTTOMLEFT", 0, -4)
    verticalOffset = verticalOffset - CARD_HEIGHT - 6

    widgets.pointsLine = CreateText(mainFrame, "GameFontHighlightSmall", CONTENT_WIDTH)
    widgets.pointsLine:SetPoint("TOPLEFT", PADDING, verticalOffset)
    verticalOffset = verticalOffset - 18

    -- Two buttons side by side: the build list and the "How to play" guide.
    -- Only one of the two side panels is open at a time.
    local halfWidth = (CONTENT_WIDTH - 6) / 2
    widgets.buildButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    widgets.buildButton:SetSize(halfWidth, 22)
    widgets.buildButton:SetPoint("TOPLEFT", PADDING, verticalOffset)
    widgets.buildButton:SetScript("OnClick", function()
        MentorDB.isBuildShown = not MentorDB.isBuildShown
        if MentorDB.isBuildShown then
            Mentor.GuideUI.SetShown(false)
            Mentor.ExtrasUI.SetShown(false)
        end
        Mentor.RequestRefresh()
    end)
    widgets.guideButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    widgets.guideButton:SetSize(halfWidth, 22)
    widgets.guideButton:SetPoint("TOPRIGHT", -PADDING, verticalOffset)
    widgets.guideButton:SetText("How to play")
    widgets.guideButton:SetScript("OnClick", function()
        local willShow = not Mentor.GuideUI.IsShown()
        Mentor.GuideUI.SetShown(willShow)
        if willShow then
            MentorDB.isBuildShown = false
            Mentor.ExtrasUI.SetShown(false)
        end
        Mentor.RequestRefresh()
    end)
    verticalOffset = verticalOffset - 26

    -- Second row: new spells / racials, and ready-made macros. Both open the
    -- "Spells & macros" panel, on their own tab.
    local function CreateExtrasButton(tabKey, anchorPoint, xOffset)
        local extrasButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
        extrasButton:SetSize(halfWidth, 22)
        extrasButton:SetPoint(anchorPoint, xOffset, verticalOffset)
        extrasButton:SetScript("OnClick", function()
            if Mentor.ExtrasUI.Toggle(tabKey) then
                MentorDB.isBuildShown = false
                Mentor.GuideUI.SetShown(false)
            end
            Mentor.RequestRefresh()
        end)
        return extrasButton
    end
    widgets.spellsButton = CreateExtrasButton("spells", "TOPLEFT", PADDING)
    Mentor.tourTargets = Mentor.tourTargets or {}
    Mentor.tourTargets.spellsButton = widgets.spellsButton
    widgets.macrosButton = CreateExtrasButton("macros", "TOPRIGHT", -PADDING)
    verticalOffset = verticalOffset - 24 - SECTION_GAP
    AddDivider(verticalOffset)
    verticalOffset = verticalOffset - SECTION_GAP

    -- Upgrades in bags.
    AddSectionLabel("Upgrades in your bags", verticalOffset)
    widgets.upgradeHint = CreateText(mainFrame, "GameFontHighlightSmall", 120, "RIGHT")
    widgets.upgradeHint:SetPoint("TOPRIGHT", -PADDING, verticalOffset)
    verticalOffset = verticalOffset - 16
    for rowIndex = 1, MAX_UPGRADE_ROWS do
        CreateUpgradeRow(rowIndex, verticalOffset - (rowIndex - 1) * UPGRADE_ROW_HEIGHT)
    end
    widgets.noUpgrades = CreateText(mainFrame, "GameFontHighlightSmall", CONTENT_WIDTH)
    widgets.noUpgrades:SetPoint("TOPLEFT", PADDING + 2, verticalOffset - 4)
    -- Everything below the upgrade list moves up or down with the number of
    -- upgrades, so the window never has an empty gap (see LayoutLowerSection).
    widgets.upgradeListTop = verticalOffset

    local lowerFrame = CreateFrame("Frame", nil, mainFrame)
    lowerFrame:SetWidth(WINDOW_WIDTH)
    widgets.lowerFrame = lowerFrame

    local lowerDivider = lowerFrame:CreateTexture(nil, "ARTWORK")
    lowerDivider:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
    lowerDivider:SetHeight(1)
    lowerDivider:SetPoint("TOPLEFT", PADDING, 0)
    lowerDivider:SetPoint("TOPRIGHT", -PADDING, 0)

    widgets.statLabel = CreateText(lowerFrame, "GameFontNormalSmall", CONTENT_WIDTH)
    widgets.statLabel:SetText(GOLD_TEXT .. "BEST STATS ON GEAR|r")
    widgets.statPills = {}
    widgets.tipLabel = CreateText(lowerFrame, "GameFontNormalSmall", CONTENT_WIDTH)
    widgets.tipLabel:SetText(GOLD_TEXT .. "TIPS|r")
    widgets.tipRows = {}
    -- Starting size; the first refresh sizes the window to its content.
    mainFrame:SetSize(WINDOW_WIDTH, -widgets.upgradeListTop + 200)
end

--------------------------------------------------------------------------------
-- Lower section: stat priority "pills" and tip rows, laid out to fit content
--------------------------------------------------------------------------------
local PILL_HEIGHT = 20
local PILL_GAP = 5
local PILL_PADDING = 7
local TIP_GAP = 6

-- A small box: gold rank number + stat name.
local function GetStatPill(pillIndex)
    local pill = widgets.statPills[pillIndex]
    if pill then
        return pill
    end
    pill = CreateFrame("Frame", nil, widgets.lowerFrame, BACKDROP_TEMPLATE)
    pill:SetHeight(PILL_HEIGHT)
    if pill.SetBackdrop then
        pill:SetBackdrop(Mentor.BOX_BACKDROP)
    end
    pill.rankText = CreateText(pill, "GameFontNormalSmall")
    pill.rankText:SetPoint("LEFT", PILL_PADDING, 0)
    pill.nameText = CreateText(pill, "GameFontHighlightSmall")
    pill.nameText:SetPoint("LEFT", pill.rankText, "RIGHT", 4, 0)
    -- "What is this stat?": hover a pill for a plain explanation.
    pill:EnableMouse(true)
    pill:SetScript("OnEnter", function(self)
        local explanation = Mentor.ExplainStatText(self.statText)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.statText or "")
        if explanation then
            GameTooltip:AddLine(explanation:sub(1, 1):upper() .. explanation:sub(2) .. ".", 1, 1, 1, true)
        end
        GameTooltip:AddLine("Number " .. (self.rankText:GetText() or "?") .. " on the list of what to look for on gear.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    pill:SetScript("OnLeave", function() GameTooltip:Hide() end)
    widgets.statPills[pillIndex] = pill
    return pill
end

-- A tip: gold bar on the left, wrapped text on the right.
local function GetTipRow(tipIndex)
    local tipRow = widgets.tipRows[tipIndex]
    if tipRow then
        return tipRow
    end
    tipRow = CreateFrame("Frame", nil, widgets.lowerFrame)
    tipRow:SetWidth(CONTENT_WIDTH)
    tipRow.bar = tipRow:CreateTexture(nil, "ARTWORK")
    tipRow.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
    tipRow.bar:SetWidth(2)
    tipRow.bar:SetPoint("TOPLEFT", 0, -1)
    tipRow.bar:SetPoint("BOTTOMLEFT", 0, 1)
    tipRow.text = CreateText(tipRow, "GameFontHighlightSmall", CONTENT_WIDTH - 10)
    tipRow.text:SetPoint("TOPLEFT", 8, 0)
    tipRow.text:SetJustifyV("TOP")
    widgets.tipRows[tipIndex] = tipRow
    return tipRow
end

local function MeasureTextWidth(fontString, fallbackWidth)
    local measuredWidth = fontString:GetStringWidth()
    return (type(measuredWidth) == "number" and measuredWidth > 0) and measuredWidth or fallbackWidth
end

local function MeasureTextHeight(fontString, fallbackHeight)
    local measuredHeight = fontString:GetStringHeight()
    return (type(measuredHeight) == "number" and measuredHeight > 0) and measuredHeight or fallbackHeight
end

-- Places the lower section right under the visible upgrade rows and sizes
-- the window to fit everything.
local function LayoutLowerSection(advice, visibleUpgradeRows)
    local lowerFrame = widgets.lowerFrame
    local lowerTop = widgets.upgradeListTop - visibleUpgradeRows * UPGRADE_ROW_HEIGHT - SECTION_GAP
    lowerFrame:ClearAllPoints()
    lowerFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, lowerTop)

    local cursorY = -SECTION_GAP
    widgets.statLabel:ClearAllPoints()
    widgets.statLabel:SetPoint("TOPLEFT", PADDING, cursorY)
    cursorY = cursorY - 16

    -- Stat pills, flowing left to right and wrapping at the window edge.
    local statNames = {}
    for statName in advice.specData.statPriority:gmatch("[^>]+") do
        table.insert(statNames, (statName:gsub("^%s+", ""):gsub("%s+$", "")))
    end
    local cursorX = PADDING
    for pillIndex, statName in ipairs(statNames) do
        local pill = GetStatPill(pillIndex)
        pill.rankText:SetText(tostring(pillIndex))
        pill.nameText:SetText(statName)
        pill.statText = statName
        local pillWidth = PILL_PADDING * 2 + MeasureTextWidth(pill.rankText, 8) + 4 + MeasureTextWidth(pill.nameText, #statName * 6)
        if cursorX + pillWidth > WINDOW_WIDTH - PADDING then
            cursorX = PADDING
            cursorY = cursorY - PILL_HEIGHT - PILL_GAP
        end
        pill:SetWidth(pillWidth)
        pill:ClearAllPoints()
        pill:SetPoint("TOPLEFT", cursorX, cursorY)
        -- The most important stat stands out.
        if pill.SetBackdropColor then
            pill:SetBackdropColor(GOLD[1], GOLD[2], GOLD[3], pillIndex == 1 and 0.18 or 0.06)
            pill:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], pillIndex == 1 and 0.8 or 0.3)
        end
        pill:Show()
        cursorX = cursorX + pillWidth + PILL_GAP
    end
    for unusedIndex = #statNames + 1, #widgets.statPills do
        widgets.statPills[unusedIndex]:Hide()
    end
    cursorY = cursorY - PILL_HEIGHT - SECTION_GAP - 4

    -- Tips, each with its own gold bar.
    widgets.tipLabel:ClearAllPoints()
    widgets.tipLabel:SetPoint("TOPLEFT", PADDING, cursorY)
    cursorY = cursorY - 16
    for tipIndex, tipText in ipairs(advice.specData.tips) do
        local tipRow = GetTipRow(tipIndex)
        tipRow.text:SetText(tipText)
        local tipHeight = math.max(14, MeasureTextHeight(tipRow.text, 26))
        tipRow:SetHeight(tipHeight)
        tipRow:ClearAllPoints()
        tipRow:SetPoint("TOPLEFT", PADDING, cursorY)
        tipRow:Show()
        cursorY = cursorY - tipHeight - TIP_GAP
    end
    for unusedIndex = #advice.specData.tips + 1, #widgets.tipRows do
        widgets.tipRows[unusedIndex]:Hide()
    end

    local lowerHeight = -cursorY
    lowerFrame:SetHeight(lowerHeight)
    mainFrame:SetSize(WINDOW_WIDTH, -lowerTop + lowerHeight + PADDING - TIP_GAP)
end

--------------------------------------------------------------------------------
-- Build panel (opens to the right of the window)
--------------------------------------------------------------------------------
-- Messages and updates right after a setting is switched.
function Mentor.OnSettingChanged(settingName)
    Mentor.SaveAccountSettings()
    -- Sell advice needs Auctionator's prices.
    if settingName == "isSellAdviceEnabled" and MentorDB.isSellAdviceEnabled
        and Mentor.SellAdvice and not Mentor.SellAdvice.IsAuctionatorLoaded() then
        Mentor.Print("Sell advice needs the Auctionator addon. Install it and scan the auction house once.")
    end
    -- If the standalone LevelPace / AutoVendor addon is loaded, that one does the job.
    local standaloneNames = { isLevelPaceEnabled = "LevelPace", isAutoVendorEnabled = "AutoVendor",
        isFishingEnabled = "OneKeyFishing", isLifeLogEnabled = "LifeLog", isManaWarningEnabled = "ManaWarning" }
    local standaloneName = standaloneNames[settingName]
    if standaloneName and MentorDB[settingName] and Mentor.IsStandaloneAddonLoaded(standaloneName) then
        Mentor.Print("You also have the " .. standaloneName .. " addon loaded, so Mentor leaves this to it. "
            .. "Disable " .. standaloneName .. " in the addon list to use Mentor's version.")
    end
    if Mentor.LevelPace then
        Mentor.LevelPace.UpdateVisibility()
    end
    if Mentor.AutoVendor then
        Mentor.AutoVendor.UpdateVisibility()
    end
    if Mentor.LifeLog then
        Mentor.LifeLog.UpdateActivation()
    end
    if Mentor.ManaWarning then
        Mentor.ManaWarning.UpdateVisibility()
    end
    if Mentor.Fishing and not InCombatLockdown() then
        Mentor.Fishing.UpdateVisibility()
    end
end

--------------------------------------------------------------------------------
-- Settings menu: on/off switches for every overlay
--------------------------------------------------------------------------------
-- The settings are grouped in sections, in two columns. A row with
-- dependsOn is indented under the setting it belongs to.
local SETTINGS_SECTIONS = {
    { column = 1, title = "Talents & play", rows = {
        { "isTalentHighlightEnabled", "Talent window", "Mark the next talent and plan the next points" },
        { "isRotationBarShown",       "Rotation bar",  "Your rotation as icons, grows as you learn spells" },
    } },
    { column = 1, title = "Gear & loot", rows = {
        { "areBagArrowsEnabled",      "Bag arrows",    "Green / red arrows on items that are better / worse" },
        { "areTooltipLinesEnabled",   "Item tooltips", "What to do with an item, and how it compares per spec" },
        { "areTooltipDetailsShown",   "Details",       "Stat explanations and extra lines", dependsOn = "areTooltipLinesEnabled" },
        { "areLootAlertsEnabled",     "Loot alerts",   "Chat message when you loot an upgrade" },
        { "areQuestPicksEnabled",     "Quest rewards", "Mark the best reward when you hand in a quest" },
    } },
    { column = 1, title = "Reminders", rows = {
        { "isTrainerReminderEnabled", "Trainer",       "New spells to train when you level up" },
        { "areSupplyRemindersEnabled", "Supplies & repair", "Ammo, reagents, pet food and broken gear" },
        { "areBagRemindersEnabled",   "Bags & professions", "Empty bag slots and professions that need a trainer" },
        { "areDungeonTipsEnabled",    "Dungeon tips",  "A short tip for your role when you enter a dungeon" },
    } },
    { column = 2, title = "Gold", rows = {
        { "isSellAdviceEnabled",      "Sell advice",   "AH, disenchant or vendor? Needs Auctionator" },
        { "isAutoVendorEnabled",      "Auto vendor",   "Sell junk and repair at vendors (Shift skips)" },
    } },
    { column = 2, title = "Extra tools", rows = {
        { "isLevelPaceEnabled",       "Level pace",    "XP / hour, time and kills to level" },
        { "isFishingEnabled",         "One-key fishing", "One key casts Fishing and reels in" },
        { "isLifeLogEnabled",         "Life log",      "Your character's story (/mentor log)" },
    } },
    { column = 2, title = "Mana warning", rows = {
        { "isManaWarningEnabled",     "Mana warning",  "Big LOW MANA warning (/mentor mana low 30)" },
        { "isManaSoundEnabled",       "Sound",         "Play a sound with the warning", dependsOn = "isManaWarningEnabled" },
        { "isManaPartyMessageEnabled", "Tell the group", "Say \"Low mana!\" in party / raid", dependsOn = "isManaWarningEnabled" },
        { "isManaCombatOnly",         "Only in combat", "No warnings outside combat", dependsOn = "isManaWarningEnabled" },
    } },
    { column = 2, title = "Interface", rows = {
        { "isMinimapButtonShown",     "Minimap button", "Mentor button on the edge of the minimap" },
    } },
}
local SETTINGS_ROW_HEIGHT = 34
local SETTINGS_SECTION_HEADER_HEIGHT = 24
local SETTINGS_COLUMN_WIDTH = 250
local SETTINGS_TOP_OFFSET = 38
local SETTINGS_BOTTOM_SPACE = 44
local SETTINGS_INDENT = 18
local settingsPanel
local settingsCheckboxes = {}
local settingsDependentRows = {}   -- { checkbox, labelText, dependsOn }

-- Greys out "Details" while "Item tooltips" is off, and so on.
local function UpdateDependentSettings()
    for _, dependentRow in ipairs(settingsDependentRows) do
        local isParentOn = MentorDB[dependentRow.dependsOn] ~= false
        dependentRow.checkbox:SetEnabled(isParentOn)
        dependentRow.labelText:SetTextColor(isParentOn and 1 or 0.5, isParentOn and 1 or 0.5, isParentOn and 1 or 0.5)
    end
end

local function BuildSettingsPanel()
    settingsPanel = CreateFrame("Frame", "MentorSettingsPanel", mainFrame, BACKDROP_TEMPLATE)
    settingsPanel:SetFrameStrata("DIALOG")
    settingsPanel:EnableMouse(true)
    ApplyBackdrop(settingsPanel)

    local logo = settingsPanel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\Mentor\\Media\\Logo")
    logo:SetSize(20, 20)
    logo:SetPoint("TOPLEFT", PADDING - 2, -PADDING + 3)
    local title = CreateText(settingsPanel, "GameFontNormalLarge")
    title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    title:SetText("Mentor settings")
    local closeButton = CreateFrame("Button", nil, settingsPanel, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function() settingsPanel:Hide() end)

    -- Each column is filled from the top, section by section.
    local columnOffsets = { SETTINGS_TOP_OFFSET, SETTINGS_TOP_OFFSET }
    for _, section in ipairs(SETTINGS_SECTIONS) do
        local columnLeft = PADDING + (section.column - 1) * SETTINGS_COLUMN_WIDTH
        local verticalOffset = columnOffsets[section.column]

        -- Section header: gold title with a thin gold line under it.
        local headerText = CreateText(settingsPanel, "GameFontNormal")
        headerText:SetPoint("TOPLEFT", columnLeft, -verticalOffset)
        headerText:SetText(section.title)
        local headerLine = settingsPanel:CreateTexture(nil, "ARTWORK")
        headerLine:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.3)
        headerLine:SetHeight(1)
        headerLine:SetPoint("TOPLEFT", columnLeft, -verticalOffset - 15)
        headerLine:SetWidth(SETTINGS_COLUMN_WIDTH - 16)
        verticalOffset = verticalOffset + SETTINGS_SECTION_HEADER_HEIGHT

        for _, rowInfo in ipairs(section.rows) do
            local settingName, label, description = rowInfo[1], rowInfo[2], rowInfo[3]
            local indent = rowInfo.dependsOn and SETTINGS_INDENT or 0
            local checkbox = CreateFrame("CheckButton", nil, settingsPanel, "UICheckButtonTemplate")
            checkbox:SetSize(24, 24)
            checkbox:SetPoint("TOPLEFT", columnLeft - 4 + indent, -verticalOffset)
            local labelText = CreateText(settingsPanel, "GameFontHighlight")
            labelText:SetPoint("TOPLEFT", checkbox, "TOPRIGHT", 4, -2)
            labelText:SetText(label)
            local descriptionText = CreateText(settingsPanel, "GameFontHighlightSmall", SETTINGS_COLUMN_WIDTH - 50 - indent)
            descriptionText:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 0, -1)
            descriptionText:SetText(MUTED_TEXT .. description .. "|r")
            checkbox:SetScript("OnClick", function(self)
                MentorDB[settingName] = self:GetChecked() and true or false
                if settingName == "isMinimapButtonShown" and Mentor.MinimapButton then
                    Mentor.MinimapButton.UpdateVisibility()
                end
                Mentor.OnSettingChanged(settingName)
                UpdateDependentSettings()
                Mentor.RequestRefresh()
            end)
            settingsCheckboxes[settingName] = checkbox
            if rowInfo.dependsOn then
                table.insert(settingsDependentRows, { checkbox = checkbox, labelText = labelText, dependsOn = rowInfo.dependsOn })
            end
            verticalOffset = verticalOffset + SETTINGS_ROW_HEIGHT
        end
        columnOffsets[section.column] = verticalOffset + 6
    end
    local tallestColumn = math.max(columnOffsets[1], columnOffsets[2])
    settingsPanel:SetSize(PADDING * 2 + SETTINGS_COLUMN_WIDTH * 2 - 10, tallestColumn + SETTINGS_BOTTOM_SPACE)
    Mentor.RegisterSidePanel(settingsPanel, false)

    local bugButton = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
    bugButton:SetSize(140, 22)
    bugButton:SetPoint("BOTTOM", 0, PADDING)
    bugButton:SetText("Report a bug")
    bugButton:SetScript("OnClick", function()
        settingsPanel:Hide()
        Mentor.BugReport.Open()
    end)
    settingsPanel:Hide()
end

function Mentor.ToggleSettings()
    if not settingsPanel then
        return
    end
    if not mainFrame:IsShown() then
        MentorDB.isShown = true
        mainFrame:Show()
        Mentor.RequestRefresh()
    end
    Mentor.PlaceSidePanels()
    -- Tick the boxes to match the saved settings each time it opens.
    for settingName, checkbox in pairs(settingsCheckboxes) do
        checkbox:SetChecked(MentorDB[settingName] ~= false)
    end
    UpdateDependentSettings()
    settingsPanel:SetShown(not settingsPanel:IsShown())
end

function Mentor.ToggleWindow()
    MentorDB.isShown = not mainFrame:IsShown()
    mainFrame:SetShown(MentorDB.isShown)
    Mentor.RequestRefresh()
end

local buildPanel
local buildRows = {}

local function BuildBuildPanel()
    buildPanel = CreateFrame("Frame", "MentorBuildPanel", mainFrame, BACKDROP_TEMPLATE)
    buildPanel:SetWidth(BUILD_PANEL_WIDTH)
    Mentor.RegisterSidePanel(buildPanel, true)
    ApplyBackdrop(buildPanel)

    buildPanel.specIcon = buildPanel:CreateTexture(nil, "ARTWORK")
    buildPanel.specIcon:SetSize(24, 24)
    buildPanel.specIcon:SetPoint("TOPLEFT", PADDING, -PADDING)
    buildPanel.specIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    buildPanel.title = CreateText(buildPanel, "GameFontNormal")
    buildPanel.title:SetPoint("LEFT", buildPanel.specIcon, "RIGHT", 8, 0)
    buildPanel.legend = CreateText(buildPanel, "GameFontHighlightSmall", BUILD_PANEL_WIDTH - PADDING * 2)
    buildPanel.legend:SetPoint("TOPLEFT", PADDING, -PADDING - 30)

    local scrollFrame = CreateFrame("ScrollFrame", "MentorBuildScroll", buildPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", PADDING, -PADDING - 50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, PADDING)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(BUILD_PANEL_WIDTH - PADDING - 42, 1)
    scrollFrame:SetScrollChild(scrollChild)
    buildPanel.scrollChild = scrollChild
    buildPanel:Hide()
end

local STATUS_STYLE = {
    done    = { icon = "Interface\\RaidFrame\\ReadyCheck-Ready", color = "|cff8fd18f" },
    next    = { icon = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", color = "|cffffd100" },
    waiting = { icon = nil, color = "|cffffffff" },
    missing = { icon = "Interface\\RaidFrame\\ReadyCheck-NotReady", color = "|cff707070" },
}

local function GetBuildRow(rowIndex)
    local row = buildRows[rowIndex]
    if row then
        return row
    end
    local scrollChild = buildPanel.scrollChild
    row = CreateFrame("Frame", nil, scrollChild)
    row:SetSize(scrollChild:GetWidth(), BUILD_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(rowIndex - 1) * BUILD_ROW_HEIGHT)
    row.statusIcon = row:CreateTexture(nil, "ARTWORK")
    row.statusIcon:SetSize(12, 12)
    row.statusIcon:SetPoint("LEFT", 0, 0)
    row.talentIcon = row:CreateTexture(nil, "ARTWORK")
    row.talentIcon:SetSize(BUILD_ROW_HEIGHT - 4, BUILD_ROW_HEIGHT - 4)
    row.talentIcon:SetPoint("LEFT", 16, 0)
    row.talentIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.rankText = CreateText(row, "GameFontHighlightSmall", 40, "RIGHT")
    row.rankText:SetPoint("RIGHT", 0, 0)
    row.nameText = CreateText(row, "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", row.talentIcon, "RIGHT", 6, 0)
    row.nameText:SetPoint("RIGHT", row.rankText, "LEFT", -4, 0)
    row.nameText:SetWordWrap(false)
    buildRows[rowIndex] = row
    return row
end

local function RefreshBuildPanel(advice)
    if not MentorDB.isBuildShown then
        buildPanel:Hide()
        return
    end
    buildPanel:Show()
    buildPanel.specIcon:SetTexture(advice.specData.icon)
    buildPanel.title:SetText(advice.specData.name .. " build")
    buildPanel.legend:SetText(MUTED_TEXT .. "Talents in the order to take them. Grey = not in this game version.|r")

    for stepIndex, step in ipairs(advice.steps) do
        local row = GetBuildRow(stepIndex)
        local style = STATUS_STYLE[step.status]
        row.statusIcon:SetTexture(style.icon)
        row.statusIcon:SetShown(style.icon ~= nil)
        row.talentIcon:SetTexture(step.talent and step.talent.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.talentIcon:SetDesaturated(step.status == "missing")
        local treeSuffix = step.tree and step.tree ~= advice.mainTree and (MUTED_TEXT .. " (" .. step.tree.name .. ")|r") or ""
        row.nameText:SetText(style.color .. step.talentName .. "|r" .. treeSuffix)
        local currentRank = step.talent and math.min(step.talent.rank, step.targetRank) or 0
        row.rankText:SetText(style.color .. currentRank .. "/" .. step.targetRank .. "|r")
        row:Show()
    end
    for unusedIndex = #advice.steps + 1, #buildRows do
        buildRows[unusedIndex]:Hide()
    end
    buildPanel.scrollChild:SetHeight(#advice.steps * BUILD_ROW_HEIGHT + 4)
end

--------------------------------------------------------------------------------
-- Refreshing the window
--------------------------------------------------------------------------------
local DETECTION_TEXT = {
    talents   = GOOD_TEXT .. "detected from your talents|r",
    chosen    = "|cff66ccffchosen by you|r",
    suggested = "|cffffd100suggested - pick yours|r",
}

local function RefreshHeader(advice)
    local red, green, blue, classColorCode = GetClassColor(advice.classFileName)
    local iconCoordinates = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[advice.classFileName]
    if iconCoordinates then
        widgets.classIcon:SetTexCoord(unpack(iconCoordinates))
    end
    widgets.className:SetText(classColorCode .. (UnitClass("player") or advice.classFileName) .. "|r")
    widgets.subtitle:SetText(MUTED_TEXT .. "Level " .. advice.level .. "  ·  " .. advice.specData.role .. "|r")
    if mainFrame.SetBackdropBorderColor then
        mainFrame:SetBackdropBorderColor(red, green, blue, 0.9)
    end
end

local function RefreshSpecButtons(advice)
    widgets.specStatus:SetText(DETECTION_TEXT[advice.detectedBy] or "")
    for specIndex, specButton in ipairs(specButtons) do
        local specData = advice.classData.specs[specIndex]
        local isSelected = specIndex == advice.specNumber
        specButton.icon:SetTexture(specData.icon)
        specButton.icon:SetDesaturated(not isSelected)
        specButton.nameText:SetText((isSelected and "|cffffffff" or MUTED_TEXT) .. specData.name .. "|r")
        specButton.tagText:SetText(specIndex == advice.classData.defaultSpec and (MUTED_TEXT .. "leveling pick|r") or "")
        if specButton.SetBackdropColor then
            specButton:SetBackdropColor(1, 1, 1, isSelected and 0.10 or 0.03)
            if isSelected then
                specButton:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
            else
                specButton:SetBackdropBorderColor(1, 1, 1, 0.12)
            end
        end
    end
end

local function RefreshTalentCard(advice)
    local nextTalent = advice.nextTalent
    if nextTalent then
        widgets.talentIcon:SetTexture(nextTalent.icon)
        widgets.talentIconFrame:Show()
        widgets.talentName:SetText(nextTalent.name)
        local treeName = advice.nextTree and advice.nextTree.name or ""
        local detail = string.format("Rank %d / %d  ·  %s tree", nextTalent.rank + 1, nextTalent.maxRank, treeName)
        if advice.isAutomatic then
            detail = detail .. MUTED_TEXT .. "  ·  best available|r"
        end
        widgets.talentDetail:SetText(detail)
    else
        widgets.talentIconFrame:Hide()
        widgets.talentName:SetText(#advice.trees == 0 and "Talents not readable yet" or "Build complete")
        widgets.talentDetail:SetText(#advice.trees == 0 and (MUTED_TEXT .. "Open your talents once (N).|r") or "")
    end

    if advice.level < 10 and Mentor.GetTotalPointsSpent(advice.trees) == 0 then
        widgets.pointsLine:SetText(MUTED_TEXT .. "Talents unlock at level 10.|r")
    elseif advice.unspentPoints > 0 then
        widgets.pointsLine:SetText(string.format("%s%d point%s to spend|r - press N",
            GOOD_TEXT, advice.unspentPoints, advice.unspentPoints == 1 and "" or "s"))
    else
        widgets.pointsLine:SetText(MUTED_TEXT .. "Next point at level " .. (advice.level + 1) .. "|r")
    end
    widgets.buildButton:SetText(MentorDB.isBuildShown and "Hide build" or "Full build")
end

local function RefreshUpgrades(advice)
    local upgrades = Mentor.FindBagUpgrades(advice.specData.weights)
    for rowIndex, row in ipairs(upgradeRows) do
        local upgrade = upgrades[rowIndex]
        if upgrade then
            row.itemLink = upgrade.itemLink
            row.targetSlot = upgrade.result.replacedSlot
            local itemIcon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(upgrade.itemLink))
                or (GetItemIcon and GetItemIcon(upgrade.itemLink))
            row.icon:SetTexture(itemIcon)
            row.nameText:SetText(upgrade.itemLink)
            row.percentText:SetText(GOOD_TEXT .. (upgrade.result.kind == "empty" and "new slot"
                or Mentor.FormatPercentChange(upgrade.result.percent)) .. "|r")
            row:Show()
        else
            row.itemLink = nil
            row:Hide()
        end
    end
    widgets.noUpgrades:SetText(#upgrades == 0 and (MUTED_TEXT .. "Nothing better in your bags right now.|r") or "")
    widgets.upgradeHint:SetText(#upgrades > 0 and (MUTED_TEXT .. "click to equip|r") or "")
    return #upgrades
end

local function RefreshAll()
    local advice = Mentor.GetTalentAdvice()
    Mentor.currentAdvice = advice
    if not advice then
        return
    end
    if mainFrame:IsShown() then
        RefreshHeader(advice)
        RefreshSpecButtons(advice)
        RefreshTalentCard(advice)
        local upgradeCount = RefreshUpgrades(advice)
        -- Always room for at least one row (the "nothing better" line).
        LayoutLowerSection(advice, math.max(1, math.min(upgradeCount, MAX_UPGRADE_ROWS)))
        RefreshBuildPanel(advice)
        Mentor.GuideUI.Refresh(advice)
        widgets.guideButton:SetText(Mentor.GuideUI.IsShown() and "Hide guide" or "How to play")
        Mentor.ExtrasUI.Refresh(advice)
        local extrasTab = Mentor.ExtrasUI.IsShown() and Mentor.ExtrasUI.GetSelectedTab()
        widgets.spellsButton:SetText((extrasTab == "spells" or extrasTab == "racials") and "Hide spells" or "Spells & racials")
        widgets.macrosButton:SetText(extrasTab == "macros" and "Hide macros" or "Macros")
    end
    Mentor.GuideUI.RefreshRotationBar(advice)
    -- Each overlay runs on its own, so a problem in one never stops the other.
    local overlayOk, overlayError = pcall(Mentor.TalentOverlay.Update, advice)
    local bagsOk, bagsError = pcall(Mentor.BagOverlay.Update, advice.specData.weights)
    if not overlayOk then
        error(overlayError, 0)
    elseif not bagsOk then
        error(bagsError, 0)
    end
end

--------------------------------------------------------------------------------
-- Debug output
--------------------------------------------------------------------------------
local function PrintDebug()
    local advice = Mentor.GetTalentAdvice()
    if not advice then
        Mentor.Print("No data for this class.")
        return
    end
    Mentor.Print(string.format("%s, spec %s (%s), level %d, free points %d, talents read via %s",
        advice.classFileName, advice.specData.name, advice.detectedBy, advice.level,
        advice.unspentPoints, tostring(advice.treeSource)))
    for _, tree in ipairs(advice.trees) do
        Mentor.Print(string.format("  %s tree: %d points, %d talents", tree.name, tree.pointsSpent, #tree.talents))
    end
    if advice.missingCount > 0 then
        local missingNames = {}
        for _, step in ipairs(advice.steps) do
            if step.status == "missing" then
                table.insert(missingNames, step.talentName)
            end
        end
        Mentor.Print("  Not in this game version (skipped): " .. table.concat(missingNames, ", "))
    end
    Mentor.Print("  Next talent: " .. (advice.nextTalent and (advice.nextTalent.name
        .. (advice.isAutomatic and " (best available)" or "")) or "none"))
    local openWindow = Mentor.TalentOverlay.GetOpenTalentWindow()
    Mentor.Print("  Talent window: " .. (openWindow and "open" or "closed (open it with N and run /mentor debug again)")
        .. " - " .. tostring(Mentor.TalentOverlay.lastStatus))
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local REFRESH_EVENTS = {
    "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
    "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
    "ACTIVE_COMBAT_CONFIG_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
    "GET_ITEM_INFO_RECEIVED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
    "UPDATE_MACROS", "PLAYER_REGEN_ENABLED",
}
-- Unknown events throw on some clients, so register each one protected.
for _, eventName in ipairs({ "ADDON_LOADED", "PLAYER_LOGOUT", "CHAT_MSG_LOOT", "QUEST_COMPLETE", "QUEST_FINISHED", "SPELL_UPDATE_COOLDOWN", "SPELL_DATA_LOAD_RESULT" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end
for _, eventName in ipairs(REFRESH_EVENTS) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end

local function OnTalentWindowChanged()
    Mentor.RequestRefresh()
end

eventFrame:SetScript("OnEvent", function(self, eventName, ...)
    if eventName == "PLAYER_LOGOUT" then
        Mentor.SaveAccountSettings()   -- slash commands and switches change settings too
        return
    end
    if eventName == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == ADDON_NAME then
            MentorDB = MentorDB or {}
            Mentor.ApplyAccountSettings()
            for settingName, defaultValue in pairs(DEFAULT_SETTINGS) do
                if MentorDB[settingName] == nil then
                    MentorDB[settingName] = defaultValue
                end
            end
            BuildMainWindow()
            BuildBuildPanel()
            BuildSettingsPanel()
            Mentor.GuideUI.Build(mainFrame)
            Mentor.ExtrasUI.Build(mainFrame)
            Mentor.GuideUI.BuildRotationBar()
            Mentor.MinimapButton.Create()
            RestoreWindowPosition()
            Mentor.PlaceSidePanels()
            mainFrame:SetShown(MentorDB.isShown)
            Mentor.HookItemTooltips()
            Mentor.TalentOverlay.TryHookModernWindow(OnTalentWindowChanged)
        elseif loadedAddonName == "Blizzard_PlayerSpells" or loadedAddonName == "Blizzard_ClassTalentUI" then
            Mentor.TalentOverlay.TryHookModernWindow(OnTalentWindowChanged)
        elseif loadedAddonName == "Bagnon" or loadedAddonName == "BagBrother" then
            Mentor.BagOverlay.TryHookBagnon()
        end
    elseif eventName == "CHAT_MSG_LOOT" then
        Mentor.HandleLootMessage(...)
    elseif eventName == "QUEST_COMPLETE" then
        Mentor.HandleQuestComplete()
    elseif eventName == "SPELL_DATA_LOAD_RESULT" then
        -- A spell description finished loading: redraw the spells list only.
        if Mentor.ExtrasUI.IsShown() then
            Mentor.RequestRefresh()
        end
    elseif eventName == "SPELL_UPDATE_COOLDOWN" then
        -- Only the rotation bar's cooldown swirls; no full refresh needed.
        Mentor.GuideUI.UpdateRotationCooldowns()
    elseif eventName == "QUEST_FINISHED" then
        Mentor.HideQuestRewardGlow()
    else
        if eventName == "PLAYER_EQUIPMENT_CHANGED" or eventName == "PLAYER_LEVEL_UP" then
            Mentor.ClearItemCache() -- level requirements and comparisons change
        end
        Mentor.RequestRefresh()
    end
end)

local secondsSinceRefresh, secondsSinceOverlayCheck = 0, 0
local wasBagOpen = false
local bagChecksSinceRefresh = 0
local BAG_REFRESH_EVERY_CHECKS = 2   -- with 0.5 s checks: about once a second
eventFrame:SetScript("OnUpdate", function(_, elapsedSinceLastFrame)
    if not MentorDB or not widgets.className then
        return
    end
    secondsSinceRefresh = secondsSinceRefresh + elapsedSinceLastFrame
    secondsSinceOverlayCheck = secondsSinceOverlayCheck + elapsedSinceLastFrame
    Mentor.BagOverlay.Tick(elapsedSinceLastFrame)
    -- While the talent window is open, keep the graphics in step with clicks.
    -- When bags are opened, mark the upgrades in them.
    if secondsSinceOverlayCheck >= OVERLAY_REFRESH_SECONDS then
        secondsSinceOverlayCheck = 0
        if Mentor.TalentOverlay.GetOpenTalentWindow() then
            isRefreshNeeded = true
        elseif Mentor.TalentOverlay.nextMarker:IsShown() or Mentor.TalentOverlay.guide:IsShown() then
            Mentor.TalentOverlay.HideAll()
        end
        -- Bags: refresh right when they open, then every couple of checks
        -- while open (items can finish loading or move around).
        local isBagOpen = Mentor.BagOverlay.IsAnyBagOpen()
        if isBagOpen then
            bagChecksSinceRefresh = bagChecksSinceRefresh + 1
            if not wasBagOpen or bagChecksSinceRefresh >= BAG_REFRESH_EVERY_CHECKS then
                bagChecksSinceRefresh = 0
                isRefreshNeeded = true
            end
        end
        wasBagOpen = isBagOpen
    end
    if isRefreshNeeded and secondsSinceRefresh >= REFRESH_THROTTLE_SECONDS then
        isRefreshNeeded = false
        secondsSinceRefresh = 0
        local success, errorMessage = pcall(RefreshAll)
        if not success and errorMessage ~= Mentor.lastError then
            Mentor.lastError = errorMessage
            Mentor.Print("Error: " .. tostring(errorMessage))
        end
    end
end)

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------
local function ParseOnOff(text)
    text = (text or ""):lower()
    if text == "on" then return true end
    if text == "off" then return false end
    return nil
end

-- Simple on/off settings: command -> { setting name, description }
local ON_OFF_SETTINGS = {
    alerts    = { "areLootAlertsEnabled", "Loot alerts" },
    highlight = { "isTalentHighlightEnabled", "Talent window graphics" },
    arrows    = { "areBagArrowsEnabled", "Upgrade arrows in bags" },
    tooltip   = { "areTooltipLinesEnabled", "Mentor lines in item tooltips" },
    details   = { "areTooltipDetailsShown", "Explanations and extra values in item tooltips" },
    quest     = { "areQuestPicksEnabled", "Best quest reward pick" },
    minimap   = { "isMinimapButtonShown", "Minimap button" },
    rotation  = { "isRotationBarShown", "Rotation bar" },
    sell      = { "isSellAdviceEnabled", "Sell / disenchant advice (needs Auctionator)" },
    pace      = { "isLevelPaceEnabled", "Level pace window" },
    vendor    = { "isAutoVendorEnabled", "Auto vendor (sell junk and repair)" },
    fishing   = { "isFishingEnabled", "One-key fishing window" },
    lifelog   = { "isLifeLogEnabled", "Life log" },
}

SLASH_MENTOR1 = "/mentor"
SlashCmdList["MENTOR"] = function(input)
    local command, argument = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()

    if command == "" then
        MentorDB.isShown = not mainFrame:IsShown()
        mainFrame:SetShown(MentorDB.isShown)
        Mentor.RequestRefresh()
    elseif command == "build" then
        MentorDB.isBuildShown = not MentorDB.isBuildShown
        Mentor.RequestRefresh()
    elseif command == "pace" and argument:lower() == "reset" then
        Mentor.LevelPace.ResetSession()
        Mentor.Print("Level pace: session statistics reset.")
    elseif command == "mana" then
        Mentor.ManaWarning.HandleCommand(argument)
    elseif command == "tour" then
        if not mainFrame:IsShown() then
            MentorDB.isShown = true
            mainFrame:Show()
        end
        Mentor.Tour.Start()
    elseif command == "log" then
        Mentor.LifeLog.HandleCommand(argument)
    elseif command == "fish" then
        Mentor.Fishing.HandleCommand(argument)
    elseif command == "keep" or command == "unkeep" or command == "keeplist" then
        Mentor.AutoVendor.HandleKeepCommand(command, argument)
    elseif ON_OFF_SETTINGS[command] then
        local newValue = ParseOnOff(argument)
        if newValue == nil then
            Mentor.Print("Usage: /mentor " .. command .. " on|off")
            return
        end
        local settingName, description = ON_OFF_SETTINGS[command][1], ON_OFF_SETTINGS[command][2]
        MentorDB[settingName] = newValue
        Mentor.Print(description .. ": " .. (newValue and "on" or "off"))
        Mentor.OnSettingChanged(settingName)
        Mentor.MinimapButton.UpdateVisibility()
        Mentor.RequestRefresh()
    elseif command == "settings" then
        Mentor.ToggleSettings()
    elseif command == "guide" then
        if not mainFrame:IsShown() then
            MentorDB.isShown = true
            mainFrame:Show()
        end
        local willShow = not Mentor.GuideUI.IsShown()
        Mentor.GuideUI.SetShown(willShow)
        if willShow then
            MentorDB.isBuildShown = false
            Mentor.ExtrasUI.SetShown(false)
        end
        Mentor.RequestRefresh()
    elseif command == "spells" or command == "racials" or command == "macros" or command == "journey" then
        if not mainFrame:IsShown() then
            MentorDB.isShown = true
            mainFrame:Show()
        end
        if Mentor.ExtrasUI.Toggle(command) then
            MentorDB.isBuildShown = false
            Mentor.GuideUI.SetShown(false)
        end
        Mentor.RequestRefresh()
    elseif command == "bug" or command == "report" then
        Mentor.BugReport.Open()
    elseif command == "debug" then
        PrintDebug()
    elseif command == "lock" then
        MentorDB.isLocked = true
        Mentor.Print("Window locked.")
    elseif command == "unlock" then
        MentorDB.isLocked = false
        Mentor.Print("Window unlocked.")
    elseif command == "center" then
        MentorDB.point, MentorDB.relativePoint, MentorDB.offsetX, MentorDB.offsetY = "CENTER", "CENTER", 0, 0
        RestoreWindowPosition()
        -- The Level pace and Auto vendor windows come back to their default spots too.
        Mentor.LevelPace.panel:ResetPosition()
        Mentor.AutoVendor.panel:ResetPosition()
        Mentor.Fishing.panel:ResetPosition()
        Mentor.LifeLog.ResetWindowPosition()
        Mentor.ManaWarning.ResetPosition()
    else
        Mentor.Print("Commands: /mentor | settings | build | guide | spells | racials | macros | bug | alerts / highlight / arrows / tooltip / quest / minimap / sell / details / pace / vendor / fishing / lifelog on|off | pace reset | fish | log | mana | journey | tour | keep <item> | debug | lock | unlock | center")
    end
end

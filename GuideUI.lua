--------------------------------------------------------------------------------
-- Mentor - GuideUI.lua
--   * "How to play" panel next to the Mentor window: tabs for the rotation,
--     1 / 2 / 3+ enemies, pet and "in trouble", each with spell icons and a
--     few short lines.
--   * Rotation bar: a small movable bar with your rotation's spells in order.
--     It only shows spells you have learned, so it grows as you level.
--------------------------------------------------------------------------------

local _, Mentor = ...

local PANEL_WIDTH            = 300
local PADDING                = 12
local TAB_HEIGHT             = 22
local TAB_GAP                = 4
local GUIDE_ICON_SIZE        = 34
local GUIDE_ICON_GAP         = 10
local MAX_GUIDE_ICONS        = 6
local LINE_GAP               = 6
local BAR_ICON_SIZE          = 34
local BAR_ICON_GAP           = 4
local MAX_BAR_ICONS          = 6
local BAR_HANDLE_WIDTH       = 14
local UNKNOWN_ICON           = "Interface\\Icons\\INV_Misc_QuestionMark"
local GOLD                   = { 1.00, 0.78, 0.10 }
local GOLD_TEXT              = "|cffffd100"
local MUTED_TEXT             = "|cffa6a6a6"
local BACKDROP_TEMPLATE      = BackdropTemplateMixin and "BackdropTemplate" or nil
local PANEL_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local guideUI = {}
Mentor.GuideUI = guideUI

--------------------------------------------------------------------------------
-- Spells: icon, id and "have I learned it?" from the game
--------------------------------------------------------------------------------
local function IsSpellLearned(spellId)
    if not spellId then
        return false
    end
    for _, checkFunction in ipairs({
        IsPlayerSpell,
        C_SpellBook and C_SpellBook.IsSpellKnown,
        IsSpellKnown,
    }) do
        if checkFunction then
            local success, isKnown = pcall(checkFunction, spellId)
            if success and isKnown then
                return true
            end
        end
    end
    return false
end

-- Spells you have not learned yet but that the spellbook already lists
-- ("future spells"). The game only finds a spell by name once it is in your
-- spellbook, so without this list every not-yet-learned spell vanished from
-- the guide. Rebuilt at most once per SPELLBOOK_INDEX_SECONDS.
local SPELLBOOK_INDEX_SECONDS = 2
local futureSpellsByName, futureSpellsBuiltAt = {}, nil

local function GetFutureSpell(spellName)
    local spellBook = C_SpellBook
    if not (spellBook and spellBook.GetNumSpellBookSkillLines and spellBook.GetSpellBookItemInfo) then
        return nil
    end
    local now = GetTime and GetTime() or 0
    if not futureSpellsBuiltAt or now - futureSpellsBuiltAt > SPELLBOOK_INDEX_SECONDS then
        futureSpellsBuiltAt = now
        futureSpellsByName = {}
        local futureType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
        local playerBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local lineCountOk, skillLineCount = pcall(spellBook.GetNumSpellBookSkillLines)
        for skillLineIndex = 1, (lineCountOk and skillLineCount or 0) do
            local lineOk, lineInfo = pcall(spellBook.GetSpellBookSkillLineInfo, skillLineIndex)
            if lineOk and type(lineInfo) == "table" then
                local firstIndex = (lineInfo.itemIndexOffset or 0) + 1
                for itemIndex = firstIndex, firstIndex + (lineInfo.numSpellBookItems or 0) - 1 do
                    local itemOk, itemInfo = pcall(spellBook.GetSpellBookItemInfo, itemIndex, playerBank)
                    if itemOk and type(itemInfo) == "table" and itemInfo.itemType == futureType and type(itemInfo.name) == "string" then
                        futureSpellsByName[itemInfo.name] = { spellId = itemInfo.spellID or itemInfo.actionID, icon = itemInfo.iconID }
                    end
                end
            end
        end
    end
    return futureSpellsByName[spellName]
end

-- Returns { name, spellId, icon, isKnown } for a spell name. spellId is nil
-- when the spell does not exist for this character in this game version.
function Mentor.ResolveSpell(spellName)
    local spellId, spellIcon
    if C_Spell and C_Spell.GetSpellInfo then
        local success, spellInfo = pcall(C_Spell.GetSpellInfo, spellName)
        if success and type(spellInfo) == "table" then
            spellId, spellIcon = spellInfo.spellID, spellInfo.iconID
        end
    elseif GetSpellInfo then
        local _, _, legacyIcon, _, _, _, legacyId = GetSpellInfo(spellName)
        spellId, spellIcon = legacyId, legacyIcon
    end
    if not spellId then
        local futureSpell = GetFutureSpell(spellName)
        if futureSpell then
            spellId, spellIcon = futureSpell.spellId, futureSpell.icon
        end
    end
    -- Talents you have not taken yet: the talent tree knows their spell and icon.
    if not spellId then
        local advice = Mentor.currentAdvice
        for _, tree in ipairs(advice and advice.trees or {}) do
            local talent = tree.talentsByName and tree.talentsByName[spellName:lower()]
            if talent and talent.spellId then
                spellId, spellIcon = talent.spellId, talent.icon
                break
            end
        end
    end
    -- Class spells not learned yet: icon from the trainer list (SpellIcons.lua).
    -- There is no spell id, but the spell is known to exist in this game.
    local isKnownToExist = spellId ~= nil
    if not spellId then
        local _, classFileName = UnitClass("player")
        local iconName = Mentor.SPELL_ICONS and Mentor.SPELL_ICONS[classFileName or ""]
            and Mentor.SPELL_ICONS[classFileName][spellName]
        if iconName then
            spellIcon = "Interface\\Icons\\" .. iconName
            isKnownToExist = true
        end
    end
    return {
        name = spellName, spellId = spellId, icon = spellIcon or UNKNOWN_ICON,
        isKnown = IsSpellLearned(spellId), exists = isKnownToExist,
    }
end

-- A guide line is either plain text or a table:
--   { "text", needs = "Spell" }     only once you know that spell (or talent)
--   { "text", without = "Spell" }   only until you know it (early-level advice)
--   { "text", from = 30, to = 41 }  only between those levels
-- needs / without may also be a list: needs = any of them, without = none of them.
local function KnowsAnySpell(spellNames)
    if type(spellNames) == "string" then
        spellNames = { spellNames }
    end
    local advice = Mentor.currentAdvice
    for _, spellName in ipairs(spellNames) do
        if Mentor.ResolveSpell(spellName).isKnown then
            return true
        end
        -- Passive talents are not always in the spellbook: check the talent tree.
        for _, tree in ipairs(advice and advice.trees or {}) do
            local talent = tree.talentsByName and tree.talentsByName[spellName:lower()]
            if talent and (talent.rank or 0) > 0 then
                return true
            end
        end
    end
    return false
end

function Mentor.GetApplicableGuideLines(guideLines)
    local playerLevel = UnitLevel("player") or 1
    if issecretvalue and issecretvalue(playerLevel) then
        playerLevel = 1
    end
    local applicableLines = {}
    for _, guideLine in ipairs(guideLines or {}) do
        if type(guideLine) == "string" then
            table.insert(applicableLines, guideLine)
        elseif type(guideLine) == "table" then
            local isShown = true
            if guideLine.needs and not KnowsAnySpell(guideLine.needs) then isShown = false end
            if guideLine.without and KnowsAnySpell(guideLine.without) then isShown = false end
            if guideLine.from and playerLevel < guideLine.from then isShown = false end
            if guideLine.to and playerLevel > guideLine.to then isShown = false end
            if isShown then
                table.insert(applicableLines, guideLine[1])
            end
        end
    end
    return applicableLines
end

local function ShowSpellTooltip(owner, resolvedSpell, extraLine)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    local shownSpellTooltip = false
    if resolvedSpell.spellId and GameTooltip.SetSpellByID then
        shownSpellTooltip = pcall(GameTooltip.SetSpellByID, GameTooltip, resolvedSpell.spellId)
    end
    if not shownSpellTooltip then
        GameTooltip:AddLine(resolvedSpell.name)
    end
    if extraLine then
        GameTooltip:AddLine(extraLine, 0.6, 0.8, 1.0)
    end
    GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- How to play panel
--------------------------------------------------------------------------------
local guidePanel
local tabButtons = {}
local guideIcons = {}
local guideLines = {}

local function CreateText(parentFrame, fontObject, width, justify)
    local fontString = parentFrame:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
    fontString:SetJustifyH(justify or "LEFT")
    if width then
        fontString:SetWidth(width)
    end
    return fontString
end

local function CreateGuideIcon(iconIndex)
    local iconButton = CreateFrame("Button", nil, guidePanel)
    iconButton:SetSize(GUIDE_ICON_SIZE, GUIDE_ICON_SIZE)
    iconButton.texture = iconButton:CreateTexture(nil, "ARTWORK")
    iconButton.texture:SetAllPoints()
    iconButton.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    Mentor.AddRoundedBorder(iconButton, GOLD[1], GOLD[2], GOLD[3], 0.6, 8)
    iconButton.nameText = CreateText(iconButton, "GameFontHighlightSmall", GUIDE_ICON_SIZE + GUIDE_ICON_GAP, "CENTER")
    iconButton.nameText:SetPoint("TOP", iconButton, "BOTTOM", 0, -2)
    iconButton.nameText:SetWordWrap(true)
    iconButton.nameText:SetMaxLines(2)
    iconButton.arrowText = CreateText(guidePanel, "GameFontNormal")
    iconButton.arrowText:SetPoint("LEFT", iconButton, "RIGHT", 1, 0)
    iconButton.arrowText:SetText(GOLD_TEXT .. ">|r")
    iconButton:SetScript("OnEnter", function(self)
        if self.resolvedSpell then
            ShowSpellTooltip(self, self.resolvedSpell, not self.resolvedSpell.isKnown and "You learn this later." or nil)
        end
    end)
    iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    guideIcons[iconIndex] = iconButton
    return iconButton
end

local function GetGuideLine(lineIndex)
    local lineRow = guideLines[lineIndex]
    if lineRow then
        return lineRow
    end
    lineRow = CreateFrame("Frame", nil, guidePanel)
    lineRow:SetWidth(PANEL_WIDTH - PADDING * 2)
    lineRow.bar = lineRow:CreateTexture(nil, "ARTWORK")
    lineRow.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
    lineRow.bar:SetWidth(2)
    lineRow.bar:SetPoint("TOPLEFT", 0, -1)
    lineRow.bar:SetPoint("BOTTOMLEFT", 0, 1)
    lineRow.text = CreateText(lineRow, "GameFontHighlight", PANEL_WIDTH - PADDING * 2 - 10)
    lineRow.text:SetPoint("TOPLEFT", 8, 0)
    guideLines[lineIndex] = lineRow
    return lineRow
end

local function MeasureHeight(fontString, fallbackHeight)
    local measuredHeight = fontString:GetStringHeight()
    return (type(measuredHeight) == "number" and measuredHeight > 0) and measuredHeight or fallbackHeight
end

function guideUI.Build(mainFrame)
    guidePanel = CreateFrame("Frame", "MentorGuidePanel", mainFrame, BACKDROP_TEMPLATE)
    guidePanel:SetWidth(PANEL_WIDTH)
    guidePanel:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 2, 0)
    guidePanel:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMRIGHT", 2, 0)
    if guidePanel.SetBackdrop then
        guidePanel:SetBackdrop(PANEL_BACKDROP)
        guidePanel:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    end

    guidePanel.specIcon = guidePanel:CreateTexture(nil, "ARTWORK")
    guidePanel.specIcon:SetSize(24, 24)
    guidePanel.specIcon:SetPoint("TOPLEFT", PADDING, -PADDING)
    guidePanel.specIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    guidePanel.title = CreateText(guidePanel, "GameFontNormal")
    guidePanel.title:SetPoint("LEFT", guidePanel.specIcon, "RIGHT", 8, 0)

    -- Tabs: two rows of three.
    local tabWidth = (PANEL_WIDTH - PADDING * 2 - TAB_GAP * 2) / 3
    for tabIndex, situation in ipairs(Mentor.GUIDE_SITUATIONS) do
        local tabButton = CreateFrame("Button", nil, guidePanel, BACKDROP_TEMPLATE)
        tabButton:SetSize(tabWidth, TAB_HEIGHT)
        local column, row = (tabIndex - 1) % 3, math.floor((tabIndex - 1) / 3)
        tabButton:SetPoint("TOPLEFT", PADDING + column * (tabWidth + TAB_GAP), -PADDING - 32 - row * (TAB_HEIGHT + TAB_GAP))
        if tabButton.SetBackdrop then
            tabButton:SetBackdrop(Mentor.BOX_BACKDROP)
        end
        tabButton.label = CreateText(tabButton, "GameFontHighlightSmall", tabWidth, "CENTER")
        tabButton.label:SetPoint("CENTER")
        tabButton.label:SetText(situation.label)
        tabButton.situationKey = situation.key
        tabButton:SetScript("OnClick", function(self)
            MentorDB.guideTab = self.situationKey
            guideUI.Refresh(Mentor.currentAdvice)
        end)
        tabButtons[tabIndex] = tabButton
    end
    guidePanel.contentTop = -PADDING - 32 - 2 * (TAB_HEIGHT + TAB_GAP) - 8

    -- Rotation bar switch at the bottom.
    local barButton = CreateFrame("Button", nil, guidePanel, "UIPanelButtonTemplate")
    barButton:SetSize(150, 22)
    barButton:SetPoint("BOTTOM", 0, PADDING)
    barButton:SetScript("OnClick", function()
        MentorDB.isRotationBarShown = not MentorDB.isRotationBarShown
        guideUI.Refresh(Mentor.currentAdvice)
        guideUI.RefreshRotationBar(Mentor.currentAdvice)
    end)
    guidePanel.barButton = barButton
    guidePanel:Hide()
end

function guideUI.IsShown()
    return guidePanel and guidePanel:IsShown()
end

function guideUI.SetShown(isShown)
    if guidePanel then
        guidePanel:SetShown(isShown)
    end
end

-- Fills the panel for the selected tab.
function guideUI.Refresh(advice)
    if not guidePanel or not guidePanel:IsShown() or not advice then
        return
    end
    local classFileName, specNumber = advice.classFileName, advice.specNumber
    guidePanel.specIcon:SetTexture(advice.specData.icon)
    guidePanel.title:SetText("How to play: " .. advice.specData.name)

    -- Tabs: hide the ones without content (e.g. "Pet" for a mage).
    local selectedKey = MentorDB.guideTab or "rotation"
    if not Mentor.GetGuideSection(classFileName, specNumber, selectedKey) then
        selectedKey = "rotation"
    end
    for _, tabButton in ipairs(tabButtons) do
        local hasContent = Mentor.GetGuideSection(classFileName, specNumber, tabButton.situationKey) ~= nil
        tabButton:SetShown(hasContent)
        local isSelected = tabButton.situationKey == selectedKey
        if tabButton.SetBackdropColor then
            tabButton:SetBackdropColor(GOLD[1], GOLD[2], GOLD[3], isSelected and 0.25 or 0.05)
            tabButton:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], isSelected and 0.9 or 0.25)
        end
        tabButton.label:SetText((isSelected and "|cffffffff" or MUTED_TEXT) .. tabButton.label:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r")
    end

    local section = Mentor.GetGuideSection(classFileName, specNumber, selectedKey) or { spells = {}, lines = {} }
    local cursorY = guidePanel.contentTop

    -- Spell icons in priority order, with ">" between them. Only spells you
    -- know count, so the row grows as you level; the first spell you will
    -- learn next is added greyed out ("later") as a preview. Spells that do
    -- not exist in this game version (old names such as "Curse of Agony" when
    -- Forever calls it "Bane of Agony") are left out.
    local existingSpells, nextUnknownSpell = {}, nil
    for _, spellName in ipairs(section.spells or {}) do
        local resolvedSpell = Mentor.ResolveSpell(spellName)
        if resolvedSpell.spellId and resolvedSpell.isKnown then
            table.insert(existingSpells, resolvedSpell)
        elseif resolvedSpell.exists and not nextUnknownSpell then
            nextUnknownSpell = resolvedSpell
        end
    end
    if nextUnknownSpell and #existingSpells < MAX_GUIDE_ICONS then
        table.insert(existingSpells, nextUnknownSpell)
    end
    local shownIcons = math.min(#existingSpells, MAX_GUIDE_ICONS)
    for iconIndex = 1, MAX_GUIDE_ICONS do
        local iconButton = guideIcons[iconIndex] or CreateGuideIcon(iconIndex)
        if iconIndex <= shownIcons then
            local resolvedSpell = existingSpells[iconIndex]
            iconButton.resolvedSpell = resolvedSpell
            iconButton.texture:SetTexture(resolvedSpell.icon)
            iconButton.texture:SetDesaturated(not resolvedSpell.isKnown)
            iconButton.texture:SetAlpha(resolvedSpell.isKnown and 1 or 0.45)
            iconButton.nameText:SetText((resolvedSpell.isKnown and "" or MUTED_TEXT) .. resolvedSpell.name .. (resolvedSpell.isKnown and "" or "|r"))
            iconButton:ClearAllPoints()
            iconButton:SetPoint("TOPLEFT", PADDING + (iconIndex - 1) * (GUIDE_ICON_SIZE + GUIDE_ICON_GAP), cursorY)
            iconButton:Show()
            iconButton.arrowText:SetShown(iconIndex < shownIcons)
        else
            iconButton:Hide()
            iconButton.arrowText:Hide()
        end
    end
    if shownIcons > 0 then
        cursorY = cursorY - GUIDE_ICON_SIZE - 36
    end

    -- Short lines, each with a gold bar. Lines that depend on a spell or a
    -- level only show when they apply to you right now.
    local lines = Mentor.GetApplicableGuideLines(section.lines)
    for lineIndex, lineText in ipairs(lines) do
        local lineRow = GetGuideLine(lineIndex)
        lineRow.text:SetText(lineText)
        local lineHeight = math.max(14, MeasureHeight(lineRow.text, 28))
        lineRow:SetHeight(lineHeight)
        lineRow:ClearAllPoints()
        lineRow:SetPoint("TOPLEFT", PADDING, cursorY)
        lineRow:Show()
        cursorY = cursorY - lineHeight - LINE_GAP
    end
    for unusedIndex = #lines + 1, #guideLines do
        guideLines[unusedIndex]:Hide()
    end

    guidePanel.barButton:SetText(MentorDB.isRotationBarShown and "Hide rotation bar" or "Show rotation bar")
end

--------------------------------------------------------------------------------
-- Rotation bar
--------------------------------------------------------------------------------
local rotationBar
local barIcons = {}

local function UpdateIconCooldown(barIcon)
    local cooldownFrame = barIcon.cooldown
    local spellId = barIcon.resolvedSpell and barIcon.resolvedSpell.spellId
    if not (cooldownFrame and spellId) then
        return
    end
    -- Modern clients (Forever): duration objects work even when values are secret.
    if C_Spell and C_Spell.GetSpellCooldownDuration and cooldownFrame.SetCooldownFromDurationObject then
        local success, durationObject = pcall(C_Spell.GetSpellCooldownDuration, spellId)
        if success and durationObject then
            pcall(cooldownFrame.SetCooldownFromDurationObject, cooldownFrame, durationObject)
            return
        end
    end
    local startTime, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local success, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellId)
        if success and type(cooldownInfo) == "table" then
            startTime, duration = cooldownInfo.startTime, cooldownInfo.duration
        end
    elseif GetSpellCooldown then
        startTime, duration = GetSpellCooldown(spellId)
    end
    local isSecret = issecretvalue and (issecretvalue(startTime) or issecretvalue(duration))
    if startTime and duration and not isSecret then
        pcall(cooldownFrame.SetCooldown, cooldownFrame, startTime, duration)
    end
end

local function CreateBarIcon(iconIndex)
    local barIcon = CreateFrame("Button", nil, rotationBar)
    barIcon:SetSize(BAR_ICON_SIZE, BAR_ICON_SIZE)
    barIcon:SetPoint("LEFT", BAR_HANDLE_WIDTH + 4 + (iconIndex - 1) * (BAR_ICON_SIZE + BAR_ICON_GAP), 0)
    barIcon.texture = barIcon:CreateTexture(nil, "ARTWORK")
    barIcon.texture:SetAllPoints()
    barIcon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    Mentor.AddBorder(barIcon, 1, 0, 0, 0, 1)
    barIcon.cooldown = CreateFrame("Cooldown", nil, barIcon, "CooldownFrameTemplate")
    barIcon.cooldown:SetAllPoints()
    -- Priority number in the corner.
    barIcon.numberText = CreateText(barIcon, "NumberFontNormalSmall")
    barIcon.numberText:SetPoint("BOTTOMRIGHT", -2, 2)
    barIcon.numberText:SetText(tostring(iconIndex))
    barIcon:EnableMouse(true)
    barIcon:SetScript("OnEnter", function(self)
        if self.resolvedSpell then
            ShowSpellTooltip(self, self.resolvedSpell, "Priority " .. iconIndex .. " in your rotation")
        end
    end)
    barIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    barIcons[iconIndex] = barIcon
    return barIcon
end

function guideUI.BuildRotationBar()
    rotationBar = CreateFrame("Frame", "MentorRotationBar", UIParent, BACKDROP_TEMPLATE)
    rotationBar:SetHeight(BAR_ICON_SIZE + 10)
    rotationBar:SetClampedToScreen(true)
    rotationBar:SetMovable(true)
    rotationBar:EnableMouse(true)
    rotationBar:RegisterForDrag("LeftButton")
    if rotationBar.SetBackdrop then
        rotationBar:SetBackdrop(PANEL_BACKDROP)
        rotationBar:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.7)
    end
    -- Gold handle on the left: drag here (or anywhere on the bar) to move it.
    local handle = rotationBar:CreateTexture(nil, "ARTWORK")
    handle:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.5)
    handle:SetSize(3, BAR_ICON_SIZE - 6)
    handle:SetPoint("LEFT", 8, 0)
    rotationBar:SetScript("OnDragStart", function(self)
        if not MentorDB.isLocked then
            self:StartMoving()
        end
    end)
    rotationBar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, offsetX, offsetY = self:GetPoint()
        MentorDB.rotationBarPosition = { point, relativePoint, offsetX, offsetY }
    end)
    local savedPosition = MentorDB.rotationBarPosition or { "BOTTOM", "BOTTOM", 0, 180 }
    rotationBar:SetPoint(savedPosition[1], UIParent, savedPosition[2], savedPosition[3], savedPosition[4])
    rotationBar:Hide()
end

-- Shows the first spells of the rotation that you have learned.
function guideUI.RefreshRotationBar(advice)
    if not rotationBar then
        return
    end
    local rotation = advice and Mentor.GetGuideSection(advice.classFileName, advice.specNumber, "rotation")
    if not (MentorDB.isRotationBarShown and rotation) then
        rotationBar:Hide()
        return
    end
    local learnedSpells = {}
    for _, spellName in ipairs(rotation.spells) do
        local resolvedSpell = Mentor.ResolveSpell(spellName)
        if resolvedSpell.isKnown then
            table.insert(learnedSpells, resolvedSpell)
            if #learnedSpells >= MAX_BAR_ICONS then
                break
            end
        end
    end
    if #learnedSpells == 0 then
        rotationBar:Hide()
        return
    end
    for iconIndex = 1, MAX_BAR_ICONS do
        local barIcon = barIcons[iconIndex] or CreateBarIcon(iconIndex)
        local resolvedSpell = learnedSpells[iconIndex]
        if resolvedSpell then
            barIcon.resolvedSpell = resolvedSpell
            barIcon.texture:SetTexture(resolvedSpell.icon)
            UpdateIconCooldown(barIcon)
            barIcon:Show()
        else
            barIcon.resolvedSpell = nil
            barIcon:Hide()
        end
    end
    rotationBar:SetWidth(BAR_HANDLE_WIDTH + 4 + #learnedSpells * (BAR_ICON_SIZE + BAR_ICON_GAP) + 6)
    rotationBar:Show()
end

function guideUI.UpdateRotationCooldowns()
    if not (rotationBar and rotationBar:IsShown()) then
        return
    end
    for _, barIcon in ipairs(barIcons) do
        if barIcon:IsShown() then
            pcall(UpdateIconCooldown, barIcon)
        end
    end
end

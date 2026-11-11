--------------------------------------------------------------------------------
-- Mentor - ExtrasUI.lua
-- "Spells & macros" panel next to the Mentor window, with three tabs:
--   * Coming up  new buttons as you level: spells from your spellbook with the
--                level you get them, plus the big talents from your build
--                (gold border). Spells you can already train are shown first.
--   * Racials    your race's abilities and when to press them.
--   * Macros     ready-made macros; "Create" makes the macro and puts it on
--                your cursor so you can drop it on an action bar.
--   * Journey    where to go next: zones and dungeons for your level, and
--                profession advice (data in Journey.lua).
--------------------------------------------------------------------------------

local _, Mentor = ...

local PANEL_WIDTH          = 300
local PADDING              = 12
local TAB_HEIGHT           = 22
local TAB_GAP              = 4
local ROW_HEIGHT           = 50
local ROW_GAP              = 4
local ICON_SIZE            = 30
local LEVEL_COLUMN_WIDTH   = 34
local MAX_COMING_UP_ROWS   = 18
local DESCRIPTION_MAX_CHARS = 120
local FIRST_TALENT_LEVEL   = 10
local UNKNOWN_ICON         = "Interface\\Icons\\INV_Misc_QuestionMark"
local GOLD                 = { 1.00, 0.78, 0.10 }
local GREY                 = { 0.45, 0.45, 0.45 }
local GOLD_TEXT            = "|cffffd100"
local MUTED_TEXT           = "|cffa6a6a6"
local GOOD_TEXT            = "|cff40ff40"
local ORANGE_TEXT          = "|cffff9933"
local BACKDROP_TEMPLATE    = BackdropTemplateMixin and "BackdropTemplate" or nil
local PANEL_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local TABS = {
    { key = "spells",  label = "Coming up" },
    { key = "racials", label = "Racials" },
    { key = "macros",  label = "Macros" },
    { key = "journey", label = "Journey" },
}

local extrasUI = {}
Mentor.ExtrasUI = extrasUI

local panel
local tabButtons = {}
local rows = {}

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------
local function IsReadable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function SafeCall(apiFunction, ...)
    if not apiFunction then
        return nil
    end
    local success, result = pcall(apiFunction, ...)
    if success and IsReadable(result) then
        return result
    end
    return nil
end

local function CreateText(parentFrame, fontObject, width, justify)
    local fontString = parentFrame:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
    fontString:SetJustifyH(justify or "LEFT")
    if width then
        fontString:SetWidth(width)
    end
    return fontString
end

-- First sentence(s) of a spell description, cut to a readable length.
local function ShortenDescription(descriptionText)
    if type(descriptionText) ~= "string" or descriptionText == "" then
        return nil
    end
    descriptionText = descriptionText:gsub("\r", ""):gsub("\n+", " ")
    if #descriptionText <= DESCRIPTION_MAX_CHARS then
        return descriptionText
    end
    local cutText = descriptionText:sub(1, DESCRIPTION_MAX_CHARS)
    local lastSentenceEnd = cutText:match("^.*()%.%s")
    if lastSentenceEnd and lastSentenceEnd > 40 then
        return cutText:sub(1, lastSentenceEnd)
    end
    return cutText:gsub("%s+%S*$", "") .. "..."
end

local function GetSpellDescription(spellId)
    if not spellId then
        return nil
    end
    if C_Spell and C_Spell.RequestLoadSpellData then
        pcall(C_Spell.RequestLoadSpellData, spellId)
    end
    local descriptionText = SafeCall(C_Spell and C_Spell.GetSpellDescription, spellId)
        or SafeCall(GetSpellDescription, spellId)
    return ShortenDescription(descriptionText)
end

--------------------------------------------------------------------------------
-- "Coming up": spells from the spellbook
--------------------------------------------------------------------------------
local SPELL_ITEM_TYPE = Enum and Enum.SpellBookItemType or {}
local SPELL_BANK_PLAYER = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0

local function GetLevelLearned(itemIndex, spellId)
    return SafeCall(C_SpellBook and C_SpellBook.GetSpellBookItemLevelLearned, itemIndex, SPELL_BANK_PLAYER)
        or SafeCall(C_Spell and C_Spell.GetSpellLevelLearned, spellId)
        or SafeCall(GetSpellLevelLearned, spellId)
end

-- Every class spell in the spellbook that you do not have yet (or have not
-- trained yet). Returns a list of { name, spellId, icon, level, kind }.
-- Empty when this client has no spellbook API with future spells.
local function ReadUpcomingSpellbookSpells(playerLevel)
    local upcoming = {}
    local spellBook = C_SpellBook
    if not (spellBook and spellBook.GetNumSpellBookSkillLines and spellBook.GetSpellBookItemInfo) then
        return upcoming
    end
    local skillLineCount = SafeCall(spellBook.GetNumSpellBookSkillLines) or 0
    -- Line 1 is "General" (racials, professions); the class lines come after.
    for skillLineIndex = 2, skillLineCount do
        local lineInfo = SafeCall(spellBook.GetSpellBookSkillLineInfo, skillLineIndex)
        if lineInfo and not lineInfo.isGuild and not lineInfo.shouldHide then
            local firstIndex = (lineInfo.itemIndexOffset or 0) + 1
            local lastIndex = (lineInfo.itemIndexOffset or 0) + (lineInfo.numSpellBookItems or 0)
            for itemIndex = firstIndex, lastIndex do
                local itemInfo = SafeCall(spellBook.GetSpellBookItemInfo, itemIndex, SPELL_BANK_PLAYER)
                local isFutureSpell = itemInfo and SPELL_ITEM_TYPE.FutureSpell and itemInfo.itemType == SPELL_ITEM_TYPE.FutureSpell
                if isFutureSpell and not itemInfo.isOffSpec and itemInfo.name then
                    local spellId = itemInfo.spellID or itemInfo.actionID
                    local levelLearned = GetLevelLearned(itemIndex, spellId)
                    table.insert(upcoming, {
                        name = itemInfo.name, spellId = spellId, icon = itemInfo.iconID,
                        level = levelLearned,
                        kind = (levelLearned and levelLearned <= playerLevel) and "train" or "spell",
                        isPassive = itemInfo.isPassive,
                    })
                end
            end
        end
    end
    return upcoming
end

-- Fallback when the spellbook does not list future spells: the spells the
-- "How to play" guide talks about that you do not know yet (no level known).
local function ReadUpcomingGuideSpells(advice)
    local upcoming, alreadyListed = {}, {}
    for _, situation in ipairs(Mentor.GUIDE_SITUATIONS or {}) do
        local section = Mentor.GetGuideSection(advice.classFileName, advice.specNumber, situation.key)
        for _, spellName in ipairs(section and section.spells or {}) do
            if not alreadyListed[spellName] then
                alreadyListed[spellName] = true
                local resolvedSpell = Mentor.ResolveSpell(spellName)
                if resolvedSpell.spellId and not resolvedSpell.isKnown then
                    table.insert(upcoming, {
                        name = resolvedSpell.name, spellId = resolvedSpell.spellId,
                        icon = resolvedSpell.icon, kind = "spell",
                    })
                end
            end
        end
    end
    return upcoming
end

-- Talents with a single rank (new abilities and keystones such as Wrack or
-- Mortal Strike) from the build that are not taken yet, with the level the
-- build reaches them (one talent point per level from level 10).
local function ReadUpcomingTalents(advice)
    local upcoming = {}
    local pointsSoFar, rankPlannedByTalent = 0, {}
    for _, step in ipairs(advice.steps or {}) do
        local talentKey = step.talentName:lower()
        local alreadyPlanned = rankPlannedByTalent[talentKey] or 0
        if step.talent and step.targetRank > alreadyPlanned then
            pointsSoFar = pointsSoFar + (step.targetRank - alreadyPlanned)
            rankPlannedByTalent[talentKey] = step.targetRank
            if step.talent.maxRank == 1 and step.status ~= "done" then
                table.insert(upcoming, {
                    name = step.talent.name, spellId = step.talent.spellId, icon = step.talent.icon,
                    level = math.max(advice.level, FIRST_TALENT_LEVEL - 1 + pointsSoFar),
                    kind = step.status == "next" and "talentNow" or "talent",
                    treeName = step.tree and step.tree.name,
                })
            end
        end
    end
    return upcoming
end

local KIND_ORDER = { train = 1, talentNow = 2, talent = 3, spell = 3 }

-- Trainer spells for your class from Mentor.TRAINER_SPELLS that you do not
-- know yet. Spells whose level you have reached are "Train now!".
local function ReadUpcomingTrainerSpells(advice)
    local upcoming = {}
    for _, trainerEntry in ipairs(Mentor.TRAINER_SPELLS[advice.classFileName] or {}) do
        local spellLevel, spellName, shortDescription = trainerEntry[1], trainerEntry[2], trainerEntry[3]
        local resolvedSpell = Mentor.ResolveSpell(spellName)
        if not resolvedSpell.isKnown then
            table.insert(upcoming, {
                name = spellName, spellId = resolvedSpell.spellId, icon = resolvedSpell.icon,
                level = spellLevel, description = shortDescription,
                kind = spellLevel <= advice.level and "train" or "spell",
            })
        end
    end
    return upcoming
end

local function GetComingUpEntries(advice)
    -- Levels and names come from the Forever trainer list; the spellbook adds
    -- anything that list misses (and real icons when it lists future spells).
    local entries = ReadUpcomingTrainerSpells(advice)
    local listedNames = {}
    for _, entry in ipairs(entries) do
        listedNames[entry.name] = entry
    end
    local spellbookEntries = ReadUpcomingSpellbookSpells(advice.level)
    local usedSpellbook = #spellbookEntries > 0
    for _, spellbookEntry in ipairs(spellbookEntries) do
        local trainerEntry = listedNames[spellbookEntry.name]
        if trainerEntry then
            trainerEntry.spellId = trainerEntry.spellId or spellbookEntry.spellId
            if spellbookEntry.icon then
                trainerEntry.icon = spellbookEntry.icon
            end
        else
            table.insert(entries, spellbookEntry)
        end
    end
    if #entries == 0 and not usedSpellbook then
        entries = ReadUpcomingGuideSpells(advice)
    end
    for _, talentEntry in ipairs(ReadUpcomingTalents(advice)) do
        table.insert(entries, talentEntry)
    end
    table.sort(entries, function(first, second)
        local firstOrder, secondOrder = KIND_ORDER[first.kind], KIND_ORDER[second.kind]
        if firstOrder ~= secondOrder then
            return firstOrder < secondOrder
        end
        local firstLevel, secondLevel = first.level or 999, second.level or 999
        if firstLevel ~= secondLevel then
            return firstLevel < secondLevel
        end
        return first.name < second.name
    end)
    while #entries > MAX_COMING_UP_ROWS do
        table.remove(entries)
    end
    return entries, usedSpellbook
end

--------------------------------------------------------------------------------
-- Racials
--------------------------------------------------------------------------------
local function GetRacialEntries()
    local _, raceFileName = UnitRace("player")
    if not IsReadable(raceFileName) then
        return {}, nil
    end
    local raceName = UnitRace("player")
    local entries = {}
    local shownTips = {}
    for racialIndex, racial in ipairs(Mentor.GetRacialList(raceFileName, IsReadable(raceName) and raceName or nil)) do
        local resolvedSpell = Mentor.ResolveSpell(racial.spell)
        -- Only abilities this character really has (the list holds old and
        -- new names), and each ability once even if it has two names.
        if resolvedSpell.spellId and resolvedSpell.isKnown and not shownTips[racial.tip] then
            shownTips[racial.tip] = true
            local isPassive = SafeCall(C_Spell and C_Spell.IsSpellPassive, resolvedSpell.spellId)
                or SafeCall(IsPassiveSpell, resolvedSpell.spellId)
                or racial.tip:find("^Passive") ~= nil
            table.insert(entries, {
                name = resolvedSpell.name, spellId = resolvedSpell.spellId, icon = resolvedSpell.icon,
                description = racial.tip, kind = isPassive and "passive" or "racial",
                listOrder = racialIndex,
            })
        end
    end
    -- Abilities you press first, passives after.
    table.sort(entries, function(first, second)
        if first.kind ~= second.kind then
            return first.kind == "racial"
        end
        return first.listOrder < second.listOrder
    end)
    return entries, IsReadable(raceName) and raceName or raceFileName
end

--------------------------------------------------------------------------------
-- Macros
--------------------------------------------------------------------------------
local MACRO_ICON = 134400   -- the question mark: with #showtooltip the game shows the spell's icon

local function GetMacroIndex(macroName)
    return SafeCall(GetMacroIndexByName, macroName) or 0
end

local function GetMacroEntries(advice)
    local entries = {}
    for _, macro in ipairs(Mentor.MACROS[advice.classFileName] or {}) do
        -- Some macros only make sense for one spec (e.g. Demonic Brand).
        local isForThisSpec = not macro.specs
        for _, specNumber in ipairs(macro.specs or {}) do
            if specNumber == advice.specNumber then
                isForThisSpec = true
            end
        end
        local missingSpells, existingSpellCount, iconTexture = {}, 0, macro.icon
        for _, spellName in ipairs(macro.spells) do
            local resolvedSpell = Mentor.ResolveSpell(spellName)
            if resolvedSpell.exists then
                existingSpellCount = existingSpellCount + 1
                iconTexture = iconTexture or resolvedSpell.icon
            end
            if not resolvedSpell.isKnown then
                table.insert(missingSpells, spellName)
            end
        end
        -- Leave out macros for spells this game version does not have at all.
        local spellsExistInGame = isForThisSpec
            and (#macro.spells == 0 or existingSpellCount > 0 or not (C_Spell and C_Spell.GetSpellInfo))
        if spellsExistInGame then
            table.insert(entries, {
                name = macro.name, icon = iconTexture or UNKNOWN_ICON, description = macro.about,
                macro = macro, kind = "macro",
                -- A macro is useful as soon as you know one of its spells.
                isReady = #macro.spells == 0 or #missingSpells < #macro.spells,
                missingSpells = missingSpells,
                exists = GetMacroIndex(macro.name) > 0,
            })
        end
    end
    return entries
end

-- Creates (or updates) the macro and puts it on the cursor.
local function CreateOrUpdateMacro(macro)
    if InCombatLockdown and InCombatLockdown() then
        Mentor.Print("Macros can't be made in combat - try again after the fight.")
        return
    end
    local macroIndex = GetMacroIndex(macro.name)
    if macroIndex > 0 then
        pcall(EditMacro, macroIndex, macro.name, nil, macro.body)
    else
        local _, characterMacroCount = GetNumMacros()
        local characterMacroLimit = MAX_CHARACTER_MACROS or 18
        if characterMacroCount and characterMacroCount >= characterMacroLimit then
            Mentor.Print("Your character macro list is full. Delete one with /macro first.")
            return
        end
        local success, newIndex = pcall(CreateMacro, macro.name, MACRO_ICON, macro.body, true)
        if not success or not newIndex then
            Mentor.Print("Could not create the macro '" .. macro.name .. "'.")
            return
        end
        macroIndex = newIndex
    end
    if PickupMacro then
        PickupMacro(macroIndex)
        Mentor.Print("Macro '" .. macro.name .. "' is on your cursor - click an action bar slot to place it.")
    end
    extrasUI.Refresh(Mentor.currentAdvice)
end

--------------------------------------------------------------------------------
-- Rows (one row type for all three tabs)
--------------------------------------------------------------------------------
local function ShowRowTooltip(row)
    local entry = row.entry
    if not entry then
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if entry.kind == "macro" then
        GameTooltip:AddLine(entry.name)
        GameTooltip:AddLine(entry.description, 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        for macroLine in entry.macro.body:gmatch("[^\n]+") do
            GameTooltip:AddLine(macroLine, 0.6, 0.8, 1.0)
        end
    elseif entry.spellId and GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, entry.spellId) then
        if entry.kind == "talent" or entry.kind == "talentNow" then
            GameTooltip:AddLine("From your talent build (" .. (entry.treeName or "talents") .. ").", 1.0, 0.82, 0.0)
        end
    else
        GameTooltip:AddLine(entry.name)
    end
    GameTooltip:Show()
end

local function CreateRow(rowIndex)
    local row = CreateFrame("Frame", nil, panel.scrollChild, BACKDROP_TEMPLATE)
    row:SetSize(PANEL_WIDTH - PADDING * 2 - 22, ROW_HEIGHT)
    row:EnableMouse(true)
    if row.SetBackdrop then
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:SetBackdropColor(1, 1, 1, 0.04)
    end

    row.levelText = CreateText(row, "GameFontNormal", LEVEL_COLUMN_WIDTH, "CENTER")
    row.levelText:SetPoint("LEFT", 0, 0)

    row.iconFrame = CreateFrame("Frame", nil, row)
    row.iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
    row.iconFrame:SetPoint("LEFT", LEVEL_COLUMN_WIDTH, 0)
    row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints()
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.border = Mentor.AddBorder(row.iconFrame, 2, GOLD[1], GOLD[2], GOLD[3], 1)

    local textLeft = LEVEL_COLUMN_WIDTH + ICON_SIZE + 8
    local textWidth = row:GetWidth() - textLeft - 4
    row.nameText = CreateText(row, "GameFontHighlight", textWidth)
    row.nameText:SetPoint("TOPLEFT", textLeft, -5)
    row.nameText:SetWordWrap(false)
    row.tagText = CreateText(row, "GameFontNormalSmall", 90, "RIGHT")
    row.tagText:SetPoint("TOPRIGHT", -6, -6)
    row.descriptionText = CreateText(row, "GameFontHighlightSmall", textWidth)
    row.descriptionText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -2)
    row.descriptionText:SetWordWrap(true)
    if row.descriptionText.SetMaxLines then
        row.descriptionText:SetMaxLines(2)
    end

    row.actionButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.actionButton:SetSize(64, 20)
    row.actionButton:SetPoint("TOPRIGHT", -4, -4)
    row.actionButton:SetScript("OnClick", function()
        if row.entry and row.entry.macro then
            CreateOrUpdateMacro(row.entry.macro)
        end
    end)

    row:SetScript("OnEnter", ShowRowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[rowIndex] = row
    return row
end

-- Colours a row's icon border: gold for talents, grey for everything else.
local function SetBorderColor(row, color, alpha)
    for _, edgeTexture in ipairs(row.border or {}) do
        edgeTexture:SetColorTexture(color[1], color[2], color[3], alpha)
    end
end

local function FillRow(row, entry)
    row.entry = entry
    row.icon:SetTexture(entry.icon or UNKNOWN_ICON)
    local isTalent = entry.kind == "talent" or entry.kind == "talentNow"
    SetBorderColor(row, isTalent and GOLD or GREY, isTalent and 1 or 0.6)
    row.icon:SetDesaturated(entry.kind == "macro" and not entry.isReady)

    -- Level ranges ("10-20") need the smaller font to fit the column.
    row.levelText:SetFontObject(entry.kind == "journey" and GameFontNormalSmall or GameFontNormal)
    if entry.kind == "journey" then
        row.levelText:SetText(GOLD_TEXT .. (entry.levelText or "") .. "|r")
    elseif entry.kind == "macro" then
        row.levelText:SetText("")
    elseif entry.kind == "racial" or entry.kind == "passive" then
        row.levelText:SetText("")
    elseif entry.level then
        row.levelText:SetText(GOLD_TEXT .. entry.level .. "|r")
    else
        row.levelText:SetText(MUTED_TEXT .. "later|r")
    end

    local nameColor = isTalent and GOLD_TEXT or "|cffffffff"
    row.nameText:SetText(nameColor .. entry.name .. "|r")

    local tagByKind = {
        train     = ORANGE_TEXT .. "Train now!|r",
        talentNow = GOOD_TEXT .. "Take it now|r",
        talent    = GOLD_TEXT .. "Talent|r",
        spell     = "",
        racial    = GOLD_TEXT .. "Press it|r",
        passive   = MUTED_TEXT .. "Passive|r",
        macro     = "",
    }
    row.tagText:SetText(entry.kind == "journey" and (entry.tag or "") or tagByKind[entry.kind] or "")

    local descriptionText = entry.description or GetSpellDescription(entry.spellId) or ""
    if entry.kind == "macro" and not entry.isReady then
        descriptionText = MUTED_TEXT .. "Needs " .. table.concat(entry.missingSpells, " / ") .. " (you learn it later).|r"
    end
    row.descriptionText:SetText(descriptionText)

    row.actionButton:SetShown(entry.kind == "macro")
    if entry.kind == "macro" then
        row.actionButton:SetText(entry.exists and "Pick up" or "Create")
        row.tagText:SetText("")
        row.nameText:SetWidth(row:GetWidth() - (LEVEL_COLUMN_WIDTH + ICON_SIZE + 8) - 74)
    else
        row.nameText:SetWidth(row:GetWidth() - (LEVEL_COLUMN_WIDTH + ICON_SIZE + 8) - 4)
    end
    -- No level column on the racial and macro tabs: move the icon left.
    local hasLevelColumn = entry.kind ~= "macro" and entry.kind ~= "racial" and entry.kind ~= "passive"
    row.iconFrame:ClearAllPoints()
    row.iconFrame:SetPoint("LEFT", hasLevelColumn and LEVEL_COLUMN_WIDTH or 6, 0)
    row.nameText:ClearAllPoints()
    row.nameText:SetPoint("TOPLEFT", (hasLevelColumn and LEVEL_COLUMN_WIDTH or 6) + ICON_SIZE + 8, -5)
end

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------
function extrasUI.Build(mainFrame)
    panel = CreateFrame("Frame", "MentorExtrasPanel", mainFrame, BACKDROP_TEMPLATE)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 2, 0)
    panel:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMRIGHT", 2, 0)
    if panel.SetBackdrop then
        panel:SetBackdrop(PANEL_BACKDROP)
        panel:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    end

    panel.title = CreateText(panel, "GameFontNormal", PANEL_WIDTH - PADDING * 2)
    panel.title:SetPoint("TOPLEFT", PADDING, -PADDING - 4)

    local tabWidth = (PANEL_WIDTH - PADDING * 2 - TAB_GAP * (#TABS - 1)) / #TABS
    for tabIndex, tab in ipairs(TABS) do
        local tabButton = CreateFrame("Button", nil, panel, BACKDROP_TEMPLATE)
        tabButton:SetSize(tabWidth, TAB_HEIGHT)
        tabButton:SetPoint("TOPLEFT", PADDING + (tabIndex - 1) * (tabWidth + TAB_GAP), -PADDING - 26)
        if tabButton.SetBackdrop then
            tabButton:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        end
        tabButton.label = CreateText(tabButton, "GameFontHighlightSmall", tabWidth, "CENTER")
        tabButton.label:SetPoint("CENTER")
        tabButton.tabKey = tab.key
        tabButton.tabLabel = tab.label
        tabButton:SetScript("OnClick", function(self)
            MentorDB.extrasTab = self.tabKey
            extrasUI.Refresh(Mentor.currentAdvice)
        end)
        tabButtons[tabIndex] = tabButton
    end

    panel.hint = CreateText(panel, "GameFontHighlightSmall", PANEL_WIDTH - PADDING * 2)
    panel.hint:SetPoint("TOPLEFT", PADDING, -PADDING - 26 - TAB_HEIGHT - 8)

    local scrollFrame = CreateFrame("ScrollFrame", "MentorExtrasScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", PADDING, -PADDING - 26 - TAB_HEIGHT - 40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -PADDING - 20, PADDING)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(PANEL_WIDTH - PADDING * 2 - 22, 10)
    scrollFrame:SetScrollChild(scrollChild)
    panel.scrollFrame = scrollFrame
    panel.scrollChild = scrollChild

    panel.emptyText = CreateText(scrollChild, "GameFontHighlightSmall", PANEL_WIDTH - PADDING * 2 - 22)
    panel.emptyText:SetPoint("TOPLEFT", 4, -4)
    panel:Hide()
end

function extrasUI.IsShown()
    return panel ~= nil and panel:IsShown()
end

function extrasUI.SetShown(isShown)
    if panel then
        panel:SetShown(isShown)
    end
end

-- Opens the panel on a tab, or closes it when that tab is already open.
function extrasUI.Toggle(tabKey)
    if not panel then
        return false
    end
    if panel:IsShown() and (not tabKey or MentorDB.extrasTab == tabKey) then
        panel:Hide()
        return false
    end
    if tabKey then
        MentorDB.extrasTab = tabKey
    end
    panel:Show()
    extrasUI.Refresh(Mentor.currentAdvice)
    return true
end

-- For tests and /mentor debug.
extrasUI.GetComingUpEntries = GetComingUpEntries

function extrasUI.GetSelectedTab()
    return MentorDB and MentorDB.extrasTab or "spells"
end

function extrasUI.Refresh(advice)
    if not panel or not panel:IsShown() or not advice then
        return
    end
    local selectedKey = extrasUI.GetSelectedTab()
    for _, tabButton in ipairs(tabButtons) do
        local isSelected = tabButton.tabKey == selectedKey
        if tabButton.SetBackdropColor then
            tabButton:SetBackdropColor(GOLD[1], GOLD[2], GOLD[3], isSelected and 0.25 or 0.05)
            tabButton:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], isSelected and 0.9 or 0.25)
        end
        tabButton.label:SetText((isSelected and "|cffffffff" or MUTED_TEXT) .. tabButton.tabLabel .. "|r")
    end

    local entries, emptyMessage
    if selectedKey == "racials" then
        local raceName
        entries, raceName = GetRacialEntries()
        panel.title:SetText((raceName or "Your race") .. " racials: use them!")
        panel.hint:SetText(MUTED_TEXT .. "Free extra buttons from your race. Put the ones marked \"Press it\" on your bars.|r")
        emptyMessage = "No racial abilities found for your race."
    elseif selectedKey == "journey" then
        entries = Mentor.Journey.GetEntries(advice)
        panel.title:SetText("Where next?")
        panel.hint:SetText(MUTED_TEXT .. "Zones and dungeons for your level (number = level range), and professions that suit you.|r")
        emptyMessage = "Nothing to suggest right now."
    elseif selectedKey == "macros" then
        entries = GetMacroEntries(advice)
        panel.title:SetText("Helpful macros")
        panel.hint:SetText(MUTED_TEXT .. "Click Create: the macro lands on your cursor. Click an action bar slot to place it. Hover to see the text.|r")
        emptyMessage = "No macros for your class yet."
    else
        local usedSpellbook
        entries, usedSpellbook = GetComingUpEntries(advice)
        panel.title:SetText("New buttons as you level")
        panel.hint:SetText(MUTED_TEXT .. "Number = level. " .. GOLD_TEXT .. "Gold|r" .. MUTED_TEXT
            .. " = from your talent build. Visit your class trainer for the rest.|r")
        emptyMessage = "Nothing new coming up - you have it all!"
    end

    for rowIndex, entry in ipairs(entries) do
        local row = rows[rowIndex] or CreateRow(rowIndex)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(rowIndex - 1) * (ROW_HEIGHT + ROW_GAP))
        FillRow(row, entry)
        row:Show()
    end
    for unusedIndex = #entries + 1, #rows do
        rows[unusedIndex]:Hide()
        rows[unusedIndex].entry = nil
    end
    panel.emptyText:SetText(#entries == 0 and (MUTED_TEXT .. emptyMessage .. "|r") or "")
    panel.scrollChild:SetHeight(math.max(10, #entries * (ROW_HEIGHT + ROW_GAP)))
end

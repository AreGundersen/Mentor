--------------------------------------------------------------------------------
-- Mentor - BugReport.lua
-- Bug reporting for players, built around GitHub Issues:
--
--   1. Errors are caught automatically. Lua errors from Mentor's own files are
--      stored (with where in the code they happened, how often, and in which
--      Mentor version) and the player gets ONE chat hint per session that
--      they can report it. The game's error handler is wrapped, not replaced,
--      so BugSack / the default error window keep working.
--   2. The "Report bug" window: pick what kind of problem it is, describe it,
--      and shift-click any item into the text to attach it. Mentor then adds
--      everything a developer needs: version, game build, class/spec/talents,
--      settings, other addons, stored errors, and for every attached item the
--      exact tooltip text Mentor read, the stats it found and its verdict per
--      spec (plus the item you wear in that slot).
--   3. Step two shows a link to the GitHub issue form and the finished report,
--      both ready to copy. Addons cannot open a browser or send anything over
--      the internet, so copy & paste is the only way out of the game.
--
-- Everything is also kept in the account-wide saved variable MentorBugReports
-- (written on /reload or logout) as a backup:
--   World of Warcraft\_forever_\WTF\Account\<User>\SavedVariables\Mentor.lua
--------------------------------------------------------------------------------

local ADDON_NAME, Mentor = ...

-- Where reports go. ISSUE_FORM_URL opens the bug form directly.
local ISSUES_PAGE_URL      = "https://github.com/AreGundersen/Mentor/issues"
local ISSUE_FORM_URL       = ISSUES_PAGE_URL .. "/new?template=bug_report.yml"

local DIALOG_WIDTH         = 480
local DIALOG_HEIGHT        = 470
local PADDING              = 14
local MAX_SAVED_REPORTS    = 20
local MAX_STORED_ERRORS    = 20
local MAX_STACK_LINES      = 8
local MAX_DESCRIPTION_CHARS = 2000
local GOLD                 = { 1.00, 0.78, 0.10 }
local MUTED_TEXT           = "|cffa6a6a6"
local GOOD_TEXT            = "|cff40ff40"
local GOLD_TEXT            = "|cffffd100"
local BRAND_TEXT           = "|cff33ccff"
local BACKDROP_TEMPLATE    = BackdropTemplateMixin and "BackdropTemplate" or nil

-- What kind of problem: the label on the button and the word in the report.
local CATEGORIES = {
    { key = "advice",  label = "Wrong advice" },
    { key = "gear",    label = "Gear / arrows" },
    { key = "talents", label = "Talents" },
    { key = "error",   label = "Error message" },
    { key = "other",   label = "Other" },
}

local bugReport = {}
Mentor.BugReport = bugReport

--------------------------------------------------------------------------------
-- Saved data
--   MentorBugReports = {
--       reports = { { time = "...", category = "...", text = "..." }, ... },
--       errors  = { { message, stack, count, firstSeen, lastSeen, version }, ... },
--   }
-- Older versions stored a plain list of report strings; those are kept.
--------------------------------------------------------------------------------
local errorsBeforeLoad = {}      -- errors that happen before saved variables load

local function GetAddonVersion(addonName)
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local success, version = pcall(getMetadata, addonName, "Version")
    return success and version or "?"
end

local function GetSavedData()
    if type(MentorBugReports) ~= "table" then
        MentorBugReports = {}
    end
    if not MentorBugReports.reports then
        -- Convert the old format (a list of strings) into the new one.
        local oldReports = {}
        for _, oldReport in ipairs(MentorBugReports) do
            if type(oldReport) == "string" then
                table.insert(oldReports, { time = "?", category = "?", text = oldReport })
            end
        end
        MentorBugReports = { reports = oldReports, errors = {} }
    end
    MentorBugReports.errors = MentorBugReports.errors or {}
    return MentorBugReports
end

--------------------------------------------------------------------------------
-- Automatic error capture
--------------------------------------------------------------------------------
local hasHintedThisSession = false

local function IsReadableText(value)
    return type(value) == "string" and not (issecretvalue and issecretvalue(value))
end

-- Only the stack lines inside Mentor's files, shortened.
local function GetMentorStack()
    if not debugstack then
        return ""
    end
    local stackText = debugstack(3) or ""
    local keptLines = {}
    for stackLine in stackText:gmatch("[^\n]+") do
        if stackLine:find("AddOns[\\/]" .. ADDON_NAME) and #keptLines < MAX_STACK_LINES then
            local shortLine = stackLine:gsub("^.-AddOns[\\/]" .. ADDON_NAME .. "[\\/]", "")
            table.insert(keptLines, shortLine)
        end
    end
    return table.concat(keptLines, "\n")
end

local function StoreError(errorRecord, storedErrors)
    for _, storedError in ipairs(storedErrors) do
        if storedError.message == errorRecord.message then
            storedError.count = (storedError.count or 1) + errorRecord.count
            storedError.lastSeen = errorRecord.lastSeen
            storedError.version = errorRecord.version
            storedError.stack = errorRecord.stack ~= "" and errorRecord.stack or storedError.stack
            return
        end
    end
    table.insert(storedErrors, errorRecord)
    while #storedErrors > MAX_STORED_ERRORS do
        table.remove(storedErrors, 1)
    end
end

local function ShowErrorHint()
    if hasHintedThisSession or not DEFAULT_CHAT_FRAME then
        return
    end
    hasHintedThisSession = true
    DEFAULT_CHAT_FRAME:AddMessage(BRAND_TEXT .. "Mentor:|r Something went wrong inside Mentor. "
        .. "Help fix it: type " .. GOLD_TEXT .. "/mentor bug|r (takes a minute).")
end

local function RememberError(errorMessage)
    if not IsReadableText(errorMessage) or not errorMessage:find("AddOns[\\/]" .. ADDON_NAME) then
        return
    end
    local now = date and date("%Y-%m-%d %H:%M:%S") or "?"
    local errorRecord = {
        message = errorMessage:gsub("^.-AddOns[\\/]" .. ADDON_NAME .. "[\\/]", ""),
        stack = GetMentorStack(), count = 1, firstSeen = now, lastSeen = now,
        version = GetAddonVersion(ADDON_NAME),
    }
    if type(MentorBugReports) == "table" and MentorBugReports.reports then
        StoreError(errorRecord, GetSavedData().errors)
    else
        StoreError(errorRecord, errorsBeforeLoad)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(1, ShowErrorHint)
    end
end

if geterrorhandler and seterrorhandler then
    local previousHandler = geterrorhandler()
    seterrorhandler(function(errorMessage, ...)
        pcall(RememberError, errorMessage)
        if previousHandler then
            return previousHandler(errorMessage, ...)
        end
    end)
end

-- Saved variables are only available once the addon has loaded.
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", function(self, _, loadedAddonName)
    if loadedAddonName ~= ADDON_NAME then
        return
    end
    local savedData = GetSavedData()
    for _, earlyError in ipairs(errorsBeforeLoad) do
        StoreError(earlyError, savedData.errors)
    end
    errorsBeforeLoad = {}
    self:UnregisterEvent("ADDON_LOADED")
end)

-- Number of stored errors, for the UI.
function bugReport.GetErrorCount()
    local savedData = type(MentorBugReports) == "table" and MentorBugReports.errors
    return (savedData and #savedData or 0) + #errorsBeforeLoad
end

--------------------------------------------------------------------------------
-- Collecting the facts
--------------------------------------------------------------------------------
local function SafeValue(value)
    if value == nil or (issecretvalue and issecretvalue(value)) then
        return "?"
    end
    return tostring(value)
end

local function GetLoadedAddonNames()
    local addOns = C_AddOns or {}
    local getCount = addOns.GetNumAddOns or GetNumAddOns
    local getInfo = addOns.GetAddOnInfo or GetAddOnInfo
    local isLoaded = addOns.IsAddOnLoaded or IsAddOnLoaded
    local loadedNames = {}
    if not (getCount and getInfo and isLoaded) then
        return loadedNames
    end
    for addonIndex = 1, getCount() do
        local addonName = getInfo(addonIndex)
        local loadedOk, loaded = pcall(isLoaded, addonName)
        if addonName and loadedOk and loaded and addonName ~= ADDON_NAME then
            table.insert(loadedNames, addonName)
        end
    end
    table.sort(loadedNames)
    return loadedNames
end

-- "[Fletcher's Gloves]" instead of the coloured link code.
local function PlainText(textWithLinks)
    return (textWithLinks:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
end

-- The item strings ("item:1234:...") of every item linked in the text.
local function FindLinkedItems(textWithLinks)
    local itemStrings, alreadyFound = {}, {}
    for itemString, itemName in textWithLinks:gmatch("|H(item:[%-%d:]+)|h%[(.-)%]|h") do
        if not alreadyFound[itemString] then
            alreadyFound[itemString] = true
            table.insert(itemStrings, { itemString = itemString, name = itemName })
        end
    end
    return itemStrings
end

local function FormatStats(stats)
    local statTexts = {}
    for statName, amount in pairs(stats or {}) do
        table.insert(statTexts, statName .. "=" .. tostring(amount))
    end
    table.sort(statTexts)
    return #statTexts > 0 and table.concat(statTexts, ", ") or "(none)"
end

-- Everything Mentor knows about one item, so gear bugs can be reproduced.
local function AddItemDetails(Add, itemString, label, advice)
    Add(label)
    Add("  Link: " .. itemString)
    local analysis = Mentor.AnalyzeItem and Mentor.AnalyzeItem(itemString)
    if not analysis then
        Add("  (item data not loaded yet - hover the item once and report again)")
        return
    end
    Add("  Slot: " .. SafeValue(analysis.equipLocation) .. ", can use: " .. SafeValue(analysis.canUse)
        .. (analysis.cannotUseReason and (" (" .. analysis.cannotUseReason .. ")") or "")
        .. (analysis.requiredLevel and (", requires level " .. analysis.requiredLevel) or ""))
    Add("  Stats Mentor read: " .. FormatStats(analysis.stats))
    Add("  Tooltip text:")
    for _, tooltipLine in ipairs(Mentor.GetItemTooltipLines and Mentor.GetItemTooltipLines(itemString) or {}) do
        Add("    " .. (tooltipLine.isRed and "[red] " or "") .. PlainText(tooltipLine.text))
    end
    if not (advice and advice.classData) then
        return
    end
    for specNumber, specData in ipairs(advice.classData.specs) do
        local success, result = pcall(Mentor.CompareItem, itemString, specData.weights)
        if success and result then
            Add(string.format("  %s%s: %s, item %s%%, total %s%%%s", specData.name,
                specNumber == advice.specNumber and " (current)" or "", SafeValue(result.kind),
                result.percent and string.format("%.1f", result.percent) or "-",
                result.overallPercent and string.format("%.1f", result.overallPercent) or "-",
                result.replacedSlot and (", replaces slot " .. result.replacedSlot) or ""))
        end
    end
end

-- Builds the full report text.
local function BuildReportText(categoryKey, description)
    local lines = {}
    local function Add(text) table.insert(lines, text) end

    local categoryLabel = categoryKey
    for _, category in ipairs(CATEGORIES) do
        if category.key == categoryKey then
            categoryLabel = category.label
        end
    end

    Add("=== Mentor bug report ===")
    Add("Type: " .. SafeValue(categoryLabel))
    Add("Time: " .. (date and date("%Y-%m-%d %H:%M:%S") or "?"))
    Add("Mentor version: " .. GetAddonVersion(ADDON_NAME))
    local gameVersion, buildNumber, _, interfaceVersion = GetBuildInfo()
    Add(string.format("Game: %s (build %s, interface %s), locale %s",
        SafeValue(gameVersion), SafeValue(buildNumber), SafeValue(interfaceVersion), SafeValue(GetLocale and GetLocale())))
    Add("")
    Add("What happened:")
    Add((description and description ~= "") and PlainText(description) or "(no description)")
    Add("")

    local _, classFileName = UnitClass("player")
    local _, raceFileName = UnitRace("player")
    Add(string.format("Character: %s %s, level %s", SafeValue(raceFileName), SafeValue(classFileName), SafeValue(UnitLevel("player"))))
    local adviceOk, advice = pcall(Mentor.GetTalentAdvice)
    if adviceOk and advice then
        Add(string.format("Spec: %s (found by %s), talents read via %s, free points %s",
            advice.specData.name, SafeValue(advice.detectedBy), SafeValue(advice.treeSource), SafeValue(advice.unspentPoints)))
        for _, tree in ipairs(advice.trees) do
            local takenTalents = {}
            for _, talent in ipairs(tree.talents) do
                if talent.rank and talent.rank > 0 then
                    table.insert(takenTalents, talent.name .. " " .. talent.rank .. "/" .. talent.maxRank)
                end
            end
            Add(string.format("  %s: %d points, %d talents%s", tree.name, tree.pointsSpent, #tree.talents,
                #takenTalents > 0 and (" - " .. table.concat(takenTalents, ", ")) or ""))
        end
        Add("Next talent: " .. (advice.nextTalent and (advice.nextTalent.name .. (advice.isAutomatic and " (best available)" or "")) or "none"))
        if advice.missingCount and advice.missingCount > 0 then
            local missingNames, alreadyListed = {}, {}
            for _, step in ipairs(advice.steps) do
                if step.status == "missing" and not alreadyListed[step.talentName] then
                    alreadyListed[step.talentName] = true
                    table.insert(missingNames, step.talentName)
                end
            end
            Add("Build talents not found in game: " .. table.concat(missingNames, ", "))
        end
    elseif not adviceOk then
        Add("Talent advice failed: " .. tostring(advice))
        advice = nil
    end

    -- Attached items (shift-clicked into the description), and what the
    -- player wears in the same slot.
    local linkedItems = FindLinkedItems(description or "")
    for itemIndex, linkedItem in ipairs(linkedItems) do
        Add("")
        AddItemDetails(Add, linkedItem.itemString, "Attached item " .. itemIndex .. ": [" .. linkedItem.name .. "]", advice)
        local currentWeights = advice and advice.specData and advice.specData.weights
        local compareOk, result = pcall(Mentor.CompareItem, linkedItem.itemString, currentWeights)
        local slotId = compareOk and result and result.replacedSlot
        local equippedLink = slotId and GetInventoryItemLink("player", slotId)
        if equippedLink then
            local equippedString = equippedLink:match("|H(item:[%-%d:]+)|h") or equippedLink
            AddItemDetails(Add, equippedString, "  Worn in that slot: " .. PlainText(equippedLink), nil)
        end
    end
    Add("")

    local settingNames = {}
    for settingName, value in pairs(MentorDB or {}) do
        if type(value) == "boolean" or type(value) == "number" then
            table.insert(settingNames, settingName .. "=" .. tostring(value))
        end
    end
    table.sort(settingNames)
    Add("Settings: " .. table.concat(settingNames, ", "))
    Add("Other addons: " .. table.concat(GetLoadedAddonNames(), ", "))
    Add("")
    Add("Stored Mentor errors:")
    local storedErrors = GetSavedData().errors
    if #storedErrors == 0 then
        Add("  none")
    else
        for _, storedError in ipairs(storedErrors) do
            Add(string.format("  [%dx, v%s, last %s] %s", storedError.count or 1, SafeValue(storedError.version),
                SafeValue(storedError.lastSeen), SafeValue(storedError.message)))
            for stackLine in (storedError.stack or ""):gmatch("[^\n]+") do
                Add("      " .. stackLine)
            end
        end
    end
    return table.concat(lines, "\n")
end

local function SaveReport(categoryKey, reportText)
    local savedData = GetSavedData()
    table.insert(savedData.reports, { time = date and date("%Y-%m-%d %H:%M:%S") or "?", category = categoryKey, text = reportText })
    while #savedData.reports > MAX_SAVED_REPORTS do
        table.remove(savedData.reports, 1)
    end
end

--------------------------------------------------------------------------------
-- Dialog
--------------------------------------------------------------------------------
local dialog

local function CreateText(parentFrame, fontObject, width)
    local fontString = parentFrame:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
    fontString:SetJustifyH("LEFT")
    if width then
        fontString:SetWidth(width)
    end
    return fontString
end

local function AddDarkBackground(targetFrame, parentFrame)
    local background = CreateFrame("Frame", nil, parentFrame, BACKDROP_TEMPLATE)
    background:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", -6, 6)
    background:SetPoint("BOTTOMRIGHT", targetFrame, "BOTTOMRIGHT", 6, -6)
    if background.SetBackdrop then
        background:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        background:SetBackdropColor(0, 0, 0, 0.5)
        background:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.4)
    end
    background:SetFrameLevel(math.max(0, (targetFrame:GetFrameLevel() or 1) - 1))
    return background
end

-- A scrolling multi-line text box.
local function CreateTextArea(parentFrame, name)
    local scrollFrame = CreateFrame("ScrollFrame", name, parentFrame, "UIPanelScrollFrameTemplate")
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(DIALOG_WIDTH - PADDING * 2 - 30)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)
    -- Keep the cursor in view while typing (Blizzard's helper, if present).
    if ScrollingEdit_OnCursorChanged then
        editBox:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
        editBox:SetScript("OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, scrollFrame) end)
    end
    -- Clicking anywhere in the box puts the cursor in it.
    scrollFrame:EnableMouse(true)
    scrollFrame:SetScript("OnMouseDown", function() editBox:SetFocus() end)
    local background = AddDarkBackground(scrollFrame, parentFrame)
    background:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 26, -6)
    return scrollFrame, editBox
end

local function SelectCategory(categoryKey)
    dialog.categoryKey = categoryKey
    for _, categoryButton in ipairs(dialog.categoryButtons) do
        if categoryButton.categoryKey == categoryKey then
            categoryButton:LockHighlight()
        else
            categoryButton:UnlockHighlight()
        end
    end
end

-- Step 1: what kind of problem, and what happened.
local function ShowWriteStep(keepText)
    dialog.isShowingReport = false
    dialog.title:SetText("Report a bug")
    local errorCount = bugReport.GetErrorCount()
    dialog.info:SetText("What went wrong? What did you do, and what did you expect?\n"
        .. GOLD_TEXT .. "Tip:|r shift-click an item into the box to attach it (for gear problems).\n"
        .. MUTED_TEXT .. "Your class, spec, talents, settings"
        .. (errorCount > 0 and (" and " .. errorCount .. " caught error(s)") or "")
        .. " are added automatically.|r")
    for _, categoryButton in ipairs(dialog.categoryButtons) do
        categoryButton:Show()
    end
    dialog.linkLabel:Hide()
    dialog.linkBox:Hide()
    dialog.linkBackground:Hide()
    dialog.scrollFrame:SetPoint("TOPLEFT", PADDING + 6, -PADDING - 118)
    if not keepText then
        dialog.descriptionText = ""
        SelectCategory(errorCount > 0 and "error" or "advice")
    end
    dialog.editBox:SetText(dialog.descriptionText or "")
    dialog.primaryButton:SetText("Create report")
    dialog.secondaryButton:SetText("Cancel")
    dialog.editBox:SetFocus()
end

-- Step 2: the link to the issue form and the finished report.
local function ShowReportStep(reportText)
    dialog.isShowingReport = true
    dialog.reportText = reportText
    dialog.title:SetText("Send it on GitHub")
    dialog.info:SetText("1. Click the link below, press " .. GOLD_TEXT .. "Ctrl+C|r and paste it into your browser.\n"
        .. "2. Click in the report, press " .. GOLD_TEXT .. "Ctrl+A|r then " .. GOLD_TEXT .. "Ctrl+C|r, and paste it into the form.\n"
        .. MUTED_TEXT .. "No GitHub account? Post it in the CurseForge comments instead. Thank you!|r")
    for _, categoryButton in ipairs(dialog.categoryButtons) do
        categoryButton:Hide()
    end
    dialog.linkLabel:Show()
    dialog.linkBox:Show()
    dialog.linkBackground:Show()
    dialog.linkBox:SetText(ISSUE_FORM_URL)
    dialog.linkBox:SetCursorPosition(0)
    dialog.scrollFrame:SetPoint("TOPLEFT", PADDING + 6, -PADDING - 150)
    dialog.editBox:SetText(reportText)
    dialog.primaryButton:SetText("Done")
    dialog.secondaryButton:SetText("Back")
    dialog.linkBox:SetFocus()
    dialog.linkBox:HighlightText()
end

local function BuildDialog()
    dialog = CreateFrame("Frame", "MentorBugReportDialog", UIParent, BACKDROP_TEMPLATE)
    dialog:SetSize(DIALOG_WIDTH, DIALOG_HEIGHT)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    if dialog.SetBackdrop then
        dialog:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        dialog:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    end
    -- Escape closes it like other windows.
    if UISpecialFrames then
        table.insert(UISpecialFrames, "MentorBugReportDialog")
    end

    dialog.title = CreateText(dialog, "GameFontNormalLarge")
    dialog.title:SetPoint("TOPLEFT", PADDING, -PADDING)
    local closeButton = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -2, -2)

    dialog.info = CreateText(dialog, "GameFontHighlightSmall", DIALOG_WIDTH - PADDING * 2)
    dialog.info:SetPoint("TOPLEFT", PADDING, -PADDING - 26)

    -- Category buttons (step 1).
    dialog.categoryButtons = {}
    local buttonGap = 4
    local buttonWidth = (DIALOG_WIDTH - PADDING * 2 - buttonGap * (#CATEGORIES - 1)) / #CATEGORIES
    for categoryIndex, category in ipairs(CATEGORIES) do
        local categoryButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        categoryButton:SetSize(buttonWidth, 22)
        categoryButton:SetPoint("TOPLEFT", PADDING + (categoryIndex - 1) * (buttonWidth + buttonGap), -PADDING - 80)
        categoryButton:SetNormalFontObject("GameFontNormalSmall")
        categoryButton:SetHighlightFontObject("GameFontHighlightSmall")
        categoryButton:SetText(category.label)
        categoryButton.categoryKey = category.key
        categoryButton:SetScript("OnClick", function(self) SelectCategory(self.categoryKey) end)
        dialog.categoryButtons[categoryIndex] = categoryButton
    end

    -- Link to the GitHub form (step 2): a one-line box so it can be copied.
    dialog.linkLabel = CreateText(dialog, "GameFontNormalSmall")
    dialog.linkLabel:SetPoint("TOPLEFT", PADDING, -PADDING - 84)
    dialog.linkLabel:SetText("Bug report form:")
    dialog.linkBox = CreateFrame("EditBox", nil, dialog)
    dialog.linkBox:SetSize(DIALOG_WIDTH - PADDING * 2 - 12, 20)
    dialog.linkBox:SetPoint("TOPLEFT", PADDING + 6, -PADDING - 104)
    dialog.linkBox:SetAutoFocus(false)
    dialog.linkBox:SetFontObject(ChatFontNormal)
    dialog.linkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- Clicking selects the whole link; typing can't change it.
    dialog.linkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    dialog.linkBox:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    dialog.linkBox:SetScript("OnTextChanged", function(self, isUserInput)
        if isUserInput then
            self:SetText(ISSUE_FORM_URL)
            self:HighlightText()
        end
    end)
    dialog.linkBackground = AddDarkBackground(dialog.linkBox, dialog)

    local scrollFrame, editBox = CreateTextArea(dialog, "MentorBugReportScroll")
    scrollFrame:SetPoint("TOPLEFT", PADDING + 6, -PADDING - 118)
    scrollFrame:SetPoint("BOTTOMRIGHT", -PADDING - 26, PADDING + 40)
    dialog.scrollFrame = scrollFrame
    dialog.editBox = editBox
    editBox:SetMaxLetters(0)
    editBox:SetScript("OnTextChanged", function(self, isUserInput)
        if not isUserInput then
            return
        end
        if dialog.isShowingReport then
            -- The finished report can be selected and copied, not edited.
            self:SetText(dialog.reportText)
            self:HighlightText()
        else
            local typedText = self:GetText()
            if #typedText > MAX_DESCRIPTION_CHARS then
                typedText = typedText:sub(1, MAX_DESCRIPTION_CHARS)
                self:SetText(typedText)
            end
            dialog.descriptionText = typedText
        end
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        if dialog.isShowingReport then
            self:HighlightText()
        end
    end)

    dialog.primaryButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.primaryButton:SetSize(130, 24)
    dialog.primaryButton:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
    dialog.primaryButton:SetScript("OnClick", function()
        if dialog.isShowingReport then
            dialog:Hide()
            return
        end
        dialog.descriptionText = dialog.editBox:GetText()
        local reportText = BuildReportText(dialog.categoryKey, dialog.descriptionText)
        SaveReport(dialog.categoryKey, reportText)
        ShowReportStep(reportText)
    end)
    dialog.secondaryButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.secondaryButton:SetSize(100, 24)
    dialog.secondaryButton:SetPoint("RIGHT", dialog.primaryButton, "LEFT", -8, 0)
    dialog.secondaryButton:SetScript("OnClick", function()
        if dialog.isShowingReport then
            ShowWriteStep(true)
        else
            dialog:Hide()
        end
    end)
    dialog:Hide()
end

-- Shift-clicking an item while the description box has focus puts the item
-- link into it (the game only does this for the chat box by itself).
if hooksecurefunc and ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(linkText)
        if dialog and dialog:IsShown() and not dialog.isShowingReport
            and dialog.editBox:HasFocus() and IsReadableText(linkText) then
            dialog.editBox:Insert(linkText)
            dialog.descriptionText = dialog.editBox:GetText()
        end
    end)
end

function bugReport.Open(categoryKey)
    if not dialog then
        BuildDialog()
    end
    ShowWriteStep()
    if categoryKey then
        SelectCategory(categoryKey)
    end
    dialog:Show()
end

-- For tests and the CurseForge page.
bugReport.BuildReportText = BuildReportText
bugReport.ISSUE_FORM_URL = ISSUE_FORM_URL

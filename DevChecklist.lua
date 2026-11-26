--------------------------------------------------------------------------------
-- Mentor - DevChecklist.lua
-- For Are's test builds only: a list of things to check in game before a
-- release. It exists only when the version ends in "+dev" (see RELEASING.md),
-- so players never see it.
--
--   /mentor check    shows or hides the list
--
-- Click an item to mark it: empty -> OK (green) -> Problem (red) -> empty.
-- Hover an item to see how to test it. The marks are kept in MentorAccountDB
-- per version, so they survive /reload and start empty for a new version.
--
-- CHECKLIST_ITEMS is rewritten for every release cycle: what is new under
-- "## Unreleased" in CHANGELOG.md, each with how to test it.
--------------------------------------------------------------------------------

local _, Mentor = ...

local devChecklist = {}
Mentor.DevChecklist = devChecklist

-- { key, "what to check", "how to test it" }
local CHECKLIST_ITEMS = {
    { "expertTrainerRecipes", "Recipes that need an Expert trainer",
        "Tailoring 160-170 without Robe of Power learned: the panel says \"An Expert trainer teaches it\" and names Josef Gregorian (Undercity) for Horde / Georgio Bolero (Stormwind) for Alliance. Check that he really has it. Trainers for the next rank in Tailoring, Leatherworking and Blacksmithing should now be right too." },
    { "buildLevels", "Full build shows levels",
        "Open the full build: no grey text at the top; one row per level from 10 to 60 with the talent for that point and the rank it reaches (Deflection 1/5, 2/5, ...). Your current level is white, earlier grey, later gold; points you've spent have a check mark, the next one a gold box." },
    -- Tested OK this cycle (removed): Expert/Artisan sources for the secondary
    -- professions, right-click in bags after the bank (issue #8).
}

local STATE_ORDER = { [""] = "ok", ok = "problem", problem = "" }
local STATE_MARKS = { [""] = "|cff808080[  ]|r", ok = "|cff40ff40[OK]|r", problem = "|cffff4040[X]|r" }
local ROW_HEIGHT = 20
local WINDOW_WIDTH = 330
local PADDING = 12
local MENTOR_GOLD = { 1.00, 0.78, 0.10 }

function devChecklist.IsDevBuild()
    return Mentor.GetVersion and (Mentor.GetVersion() or ""):find("%+dev$") ~= nil
end

-- The marks for this version: { [key] = "ok" | "problem" }.
local function GetStates()
    MentorAccountDB = MentorAccountDB or {}
    local savedChecklist = MentorAccountDB.devChecklist
    local version = Mentor.GetVersion()
    if not savedChecklist or savedChecklist.version ~= version then
        savedChecklist = { version = version, states = {} }
        MentorAccountDB.devChecklist = savedChecklist
    end
    return savedChecklist.states
end

function devChecklist.GetCounts()
    local states = GetStates()
    local okCount, problemCount = 0, 0
    for _, item in ipairs(CHECKLIST_ITEMS) do
        if states[item[1]] == "ok" then
            okCount = okCount + 1
        elseif states[item[1]] == "problem" then
            problemCount = problemCount + 1
        end
    end
    return okCount, problemCount, #CHECKLIST_ITEMS
end

local window
local rows = {}

local function RefreshWindow()
    if not window then
        return
    end
    local states = GetStates()
    for itemIndex, item in ipairs(CHECKLIST_ITEMS) do
        local row = rows[itemIndex]
        local state = states[item[1]] or ""
        row.text:SetText(STATE_MARKS[state] .. "  " .. (state == "ok" and "|cffa6a6a6" or "|cffffffff") .. item[2] .. "|r")
    end
    local okCount, problemCount, totalCount = devChecklist.GetCounts()
    window.summary:SetText(string.format("%d / %d OK%s", okCount, totalCount,
        problemCount > 0 and string.format("  |cffff4040%d problem%s|r", problemCount, problemCount == 1 and "" or "s") or ""))
end

local function CreateWindow()
    -- A WoW window ("Test checklist" in the title bar) or Mentor's own box;
    -- the WoW window's content sits lower, under its title bar.
    local nativeWindow = Mentor.NativeFrame and Mentor.NativeFrame.CreateWindow("MentorDevChecklist", UIParent, "Test checklist")
    local contentShift = nativeWindow and 26 or 0
    window = nativeWindow or CreateFrame("Frame", "MentorDevChecklist", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    window:SetSize(WINDOW_WIDTH, PADDING * 2 + 44 + #CHECKLIST_ITEMS * ROW_HEIGHT + 30 + contentShift)
    window:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetClampedToScreen(true)
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    if not nativeWindow and window.SetBackdrop and Mentor.BOX_BACKDROP then
        window:SetBackdrop(Mentor.BOX_BACKDROP)
        window:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.9)
        -- Dark background: the backdrop texture is plain white until colored.
        window:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    end
    if nativeWindow then
        window.title = Mentor.NativeFrame.CreateSubtitle(nativeWindow, "GameFontNormal")
        window.title:SetText("v" .. Mentor.GetVersion())
    else
        window.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        window.title:SetPoint("TOPLEFT", PADDING, -PADDING)
        window.title:SetText("Test checklist  |cffa6a6a6v" .. Mentor.GetVersion() .. "|r")
        local closeButton = CreateFrame("Button", nil, window, "UIPanelCloseButton")
        closeButton:SetPoint("TOPRIGHT", -2, -2)
    end
    if nativeWindow then
        -- Beside the portrait, under the version: short so it fits one line.
        window.subtitle = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        window.subtitle:SetPoint("TOPLEFT", window.title, "BOTTOMLEFT", 0, -4)
        window.subtitle:SetText("Click to mark, hover for how to test.")
    else
        window.subtitle = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        window.subtitle:SetPoint("TOPLEFT", PADDING, -PADDING - 18)
        window.subtitle:SetText("Click: OK, then Problem, then empty. Hover: how to test.")
    end

    for itemIndex, item in ipairs(CHECKLIST_ITEMS) do
        local row = CreateFrame("Button", nil, window)
        row:SetSize(WINDOW_WIDTH - 2 * PADDING, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", PADDING, -PADDING - 40 - contentShift - (itemIndex - 1) * ROW_HEIGHT)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT")
        row.text:SetJustifyH("LEFT")
        row:SetScript("OnClick", function()
            local states = GetStates()
            local nextState = STATE_ORDER[states[item[1]] or ""]
            states[item[1]] = nextState ~= "" and nextState or nil
            RefreshWindow()
        end)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(item[2])
            GameTooltip:AddLine(item[3], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[itemIndex] = row
    end
    window.summary = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    window.summary:SetPoint("BOTTOMLEFT", PADDING, PADDING + 2)
    local resetButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    resetButton:SetSize(70, 20)
    resetButton:SetPoint("BOTTOMRIGHT", -PADDING, PADDING - 2)
    resetButton:SetText("Reset")
    resetButton:SetScript("OnClick", function()
        MentorAccountDB.devChecklist = nil
        RefreshWindow()
    end)
    if UISpecialFrames then
        table.insert(UISpecialFrames, "MentorDevChecklist")
    end
end

function devChecklist.Toggle()
    if not devChecklist.IsDevBuild() then
        Mentor.Print("The test checklist only exists in test builds (+dev).")
        return
    end
    if not window then
        CreateWindow()
    end
    if window:IsShown() then
        window:Hide()
    else
        RefreshWindow()
        window:Show()
    end
end

devChecklist.CHECKLIST_ITEMS = CHECKLIST_ITEMS

-- In a test build, say once at login how much is left to check.
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    if not devChecklist.IsDevBuild() or not C_Timer then
        return
    end
    C_Timer.After(6, function()
        local okCount, problemCount, totalCount = devChecklist.GetCounts()
        if okCount < totalCount then
            Mentor.Print(string.format("Test build: %d of %d checks done%s - |cffffd100/mentor check|r for the list.",
                okCount, totalCount, problemCount > 0 and string.format(", %d with a problem", problemCount) or ""))
        end
    end)
end)

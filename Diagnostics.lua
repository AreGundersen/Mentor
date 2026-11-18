--------------------------------------------------------------------------------
-- Mentor - Diagnostics.lua
-- Lets a bug report explain itself, so players don't have to write anything:
--
--   * Mentor.Trace(area, text)       a short log of what Mentor did lately
--                                    ("Gear: arrow on [Item] = upgrade +12%").
--   * Mentor.NoteProblem(area, text) problems Mentor caught and handled
--                                    quietly (a game function missing, a
--                                    pcall that failed) - counted, not spammed.
--   * Mentor.RegisterDiagnostics(name, function(Add) ... end)
--                                    each feature describes what it shows
--                                    right now; the bug report calls them all.
--
-- The log and the problems are kept in MentorBugReports (account-wide saved
-- variable), so a report after a /reload still shows what happened before.
-- Loaded first, so every other file can use these functions.
--------------------------------------------------------------------------------

local _, Mentor = ...

local MAX_TRACE_LINES = 80
local MAX_PROBLEMS = 30

local traceLines = {}        -- this session, oldest first
local problemsByKey = {}     -- "area: text" -> { area, text, count, firstSeen, lastSeen }
local problemOrder = {}
local diagnosticProviders = {}  -- { { name, provider } } in registration order

local function Now()
    return date and date("%H:%M:%S") or "?"
end

local function IsReadableText(value)
    return type(value) == "string" and not (issecretvalue and issecretvalue(value))
end

-- Item links become "[Name]" so the log stays readable as plain text.
local function PlainText(text)
    if not IsReadableText(text) then
        return "?"
    end
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
end

function Mentor.Trace(area, text)
    local isSuccess = pcall(function()
        table.insert(traceLines, string.format("%s %s: %s", Now(), tostring(area), PlainText(text)))
        while #traceLines > MAX_TRACE_LINES do
            table.remove(traceLines, 1)
        end
    end)
    return isSuccess
end

function Mentor.NoteProblem(area, text)
    pcall(function()
        local problemText = PlainText(tostring(text))
        local problemKey = tostring(area) .. ": " .. problemText
        local problem = problemsByKey[problemKey]
        if problem then
            problem.count = problem.count + 1
            problem.lastSeen = Now()
            return
        end
        problem = { area = tostring(area), text = problemText, count = 1, firstSeen = Now(), lastSeen = Now() }
        problemsByKey[problemKey] = problem
        table.insert(problemOrder, problemKey)
        while #problemOrder > MAX_PROBLEMS do
            problemsByKey[table.remove(problemOrder, 1)] = nil
        end
    end)
end

function Mentor.RegisterDiagnostics(name, provider)
    table.insert(diagnosticProviders, { name = name, provider = provider })
end

--------------------------------------------------------------------------------
-- For the bug report
--------------------------------------------------------------------------------
local diagnostics = {}
Mentor.Diagnostics = diagnostics

function diagnostics.GetTraceLines()
    return traceLines
end

-- The log from the previous session (saved on logout / reload).
function diagnostics.GetPreviousTraceLines()
    local savedData = type(MentorBugReports) == "table" and MentorBugReports
    return savedData and savedData.previousTrace or {}
end

function diagnostics.GetProblems()
    local problems = {}
    for _, problemKey in ipairs(problemOrder) do
        table.insert(problems, problemsByKey[problemKey])
    end
    return problems
end

-- Every feature's description of itself. A provider that fails says so
-- instead of breaking the report.
function diagnostics.AddFeatureStates(Add)
    for _, entry in ipairs(diagnosticProviders) do
        Add(entry.name .. ":")
        local isSuccess, errorText = pcall(entry.provider, function(text) Add("  " .. PlainText(tostring(text))) end)
        if not isSuccess then
            Add("  (could not read: " .. PlainText(tostring(errorText)) .. ")")
        end
    end
end

-- Where the player is and what the game looks like right now.
function diagnostics.AddSituation(Add)
    local zoneText = GetRealZoneText and GetRealZoneText() or "?"
    local subZoneText = GetSubZoneText and GetSubZoneText() or ""
    local mapPositionText = ""
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local mapId = C_Map.GetBestMapForUnit("player")
        local position = mapId and C_Map.GetPlayerMapPosition(mapId, "player")
        if position and position.x and not (issecretvalue and issecretvalue(position.x)) then
            mapPositionText = string.format(" (%.1f, %.1f)", position.x * 100, position.y * 100)
        end
    end
    Add(string.format("Where: %s%s%s", PlainText(zoneText), subZoneText ~= "" and (" - " .. PlainText(subZoneText)) or "", mapPositionText))
    local isInInstance, instanceType = false, nil
    if IsInInstance then
        isInInstance, instanceType = IsInInstance()
    end
    Add(string.format("In instance: %s%s, group: %s, in combat: %s, resting: %s",
        tostring(isInInstance), instanceType and (" (" .. tostring(instanceType) .. ")") or "",
        IsInRaid and IsInRaid() and "raid" or (IsInGroup and IsInGroup() and "party" or "solo"),
        tostring(InCombatLockdown and InCombatLockdown() or false), tostring(IsResting and IsResting() or false)))
    local freeBagSlots = 0
    if C_Container and C_Container.GetContainerNumFreeSlots then
        for bagIndex = 0, 4 do
            freeBagSlots = freeBagSlots + (C_Container.GetContainerNumFreeSlots(bagIndex) or 0)
        end
    end
    Add(string.format("Gold: %s, free bag slots: %d, XP: %s / %s",
        tostring(math.floor((GetMoney and GetMoney() or 0) / 10000)) .. "g", freeBagSlots,
        tostring(UnitXP and UnitXP("player") or "?"), tostring(UnitXPMax and UnitXPMax("player") or "?")))
    local screenWidth, screenHeight = GetPhysicalScreenSize and GetPhysicalScreenSize()
    Add(string.format("Screen: %sx%s, UI scale %s", tostring(screenWidth or "?"), tostring(screenHeight or "?"),
        tostring(UIParent and UIParent.GetEffectiveScale and math.floor(UIParent:GetEffectiveScale() * 100) / 100 or "?")))
    -- Which of Mentor's windows are open.
    local openWindows = {}
    for _, frameName in ipairs({ "MentorFrame", "MentorSettingsPanel", "MentorBuildPanel", "MentorExtrasPanel",
        "MentorUpgradesWindow", "MentorLifeLogWindow", "MentorLevelPaceFrame", "MentorProfessionPanel" }) do
        local frame = _G[frameName]
        if frame and frame.IsShown and frame:IsShown() then
            table.insert(openWindows, (frameName:gsub("^Mentor", "")))
        end
    end
    Add("Mentor windows open: " .. (#openWindows > 0 and table.concat(openWindows, ", ") or "none"))
end

-- Keep this session's log for the next one (written on logout / reload).
local saveFrame = CreateFrame("Frame")
saveFrame:RegisterEvent("PLAYER_LOGOUT")
saveFrame:SetScript("OnEvent", function()
    if type(MentorBugReports) == "table" then
        MentorBugReports.previousTrace = traceLines
    end
end)

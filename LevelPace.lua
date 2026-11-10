--------------------------------------------------------------------------------
-- Mentor - LevelPace.lua
-- "Level pace" window (OFF by default; turn it on under Settings or with
-- /mentor pace on): how far you are from the next level, how fast you gain
-- XP and roughly how long / how many kills are left.
-- Built from Are's standalone LevelPace addon, in the Mentor look.
--
--   /mentor pace on|off   show or hide the window
--   /mentor pace reset    start the session statistics again
--
-- XP is tracked all the time (it is cheap), so the numbers are right as soon
-- as the window is turned on.
--------------------------------------------------------------------------------

local _, Mentor = ...

local REFRESH_INTERVAL_SECONDS = 1
local KILL_HISTORY_SIZE = 10          -- recent kills used for "kills to level"
local FALLBACK_MAX_LEVEL = 60
local STANDALONE_ADDON_NAME = "LevelPace"

local ROW_DEFINITIONS = {
    { key = "level",        label = "Level" },
    { key = "currentXP",    label = "XP" },
    { key = "remainingXP",  label = "To level" },
    { key = "restedXP",     label = "Rested" },
    { key = "xpPerHour",    label = "XP / hour" },
    { key = "timeToLevel",  label = "Time to level" },
    { key = "killsToLevel", label = "Kills to level" },
    { key = "sessionTime",  label = "Session" },
}

local levelPace = {}
Mentor.LevelPace = levelPace

--------------------------------------------------------------------------------
-- Session state (reset on login / reload or with /mentor pace reset)
--------------------------------------------------------------------------------
local sessionStartTime = 0
local sessionGainedXP = 0
local lastKnownXP = 0
local lastKnownMaxXP = 0
local recentKillXPValues = {}

--------------------------------------------------------------------------------
-- Formatting
--------------------------------------------------------------------------------
-- 12345 -> "12,345"
local function FormatNumber(number)
    local formatted = tostring(math.floor(number + 0.5))
    local replacementsMade
    repeat
        formatted, replacementsMade = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until replacementsMade == 0
    return formatted
end

-- Seconds as "1h 23m", "12m 05s" or "45s".
local function FormatDuration(totalSeconds)
    if not totalSeconds or totalSeconds ~= totalSeconds or totalSeconds == math.huge then
        return "--"
    end
    totalSeconds = math.floor(totalSeconds)
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = totalSeconds % 60
    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm %02ds", minutes, seconds)
    end
    return string.format("%ds", seconds)
end

local function GetMaxLevel()
    if GetMaxPlayerLevel then
        local maxLevel = GetMaxPlayerLevel()
        if maxLevel and maxLevel > 0 then
            return maxLevel
        end
    end
    return MAX_PLAYER_LEVEL or FALLBACK_MAX_LEVEL
end

-- "%s dies, you gain %d experience." -> a pattern that captures the XP.
-- Only the start is matched, so rested / group bonus text is ignored.
local function BuildKillXPPattern(formatString)
    if not formatString then
        return nil
    end
    local pattern = formatString:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    pattern = pattern:gsub("%%%%s", ".+")
    pattern = pattern:gsub("%%%%d", "(%%d+)")
    return "^" .. pattern
end
local KILL_XP_PATTERN = BuildKillXPPattern(COMBATLOG_XPGAIN_FIRSTPERSON)

--------------------------------------------------------------------------------
-- Statistics
--------------------------------------------------------------------------------
function levelPace.ResetSession()
    sessionStartTime = GetTime()
    sessionGainedXP = 0
    lastKnownXP = UnitXP("player") or 0
    lastKnownMaxXP = UnitXPMax("player") or 0
    wipe(recentKillXPValues)
end

-- Adds the XP gained since the last update, also across a level-up.
local function TrackXPGain()
    local currentXP = UnitXP("player") or 0
    local currentMaxXP = UnitXPMax("player") or 0
    local gainedXP
    if currentXP >= lastKnownXP then
        gainedXP = currentXP - lastKnownXP
    else
        gainedXP = (lastKnownMaxXP - lastKnownXP) + currentXP   -- levelled: rest of the old bar + the new
    end
    if gainedXP > 0 then
        sessionGainedXP = sessionGainedXP + gainedXP
    end
    lastKnownXP, lastKnownMaxXP = currentXP, currentMaxXP
end

local function RecordKillXP(experienceFromKill)
    table.insert(recentKillXPValues, experienceFromKill)
    if #recentKillXPValues > KILL_HISTORY_SIZE then
        table.remove(recentKillXPValues, 1)
    end
end

local function GetAverageKillXP()
    if #recentKillXPValues == 0 then
        return nil
    end
    local totalKillXP = 0
    for _, killXP in ipairs(recentKillXPValues) do
        totalKillXP = totalKillXP + killXP
    end
    return totalKillXP / #recentKillXPValues
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
local panel = Mentor.CreateInfoPanel("MentorLevelPaceFrame", "Level pace", ROW_DEFINITIONS,
    "levelPacePosition", { point = "CENTER", relativePoint = "CENTER", offsetX = 0, offsetY = 200 })
levelPace.panel = panel

local function UpdateDisplay()
    if not panel:IsShown() then
        return
    end
    local values = panel.values
    local playerLevel = UnitLevel("player")
    local elapsedSeconds = GetTime() - sessionStartTime
    values.level:SetText(tostring(playerLevel))
    values.sessionTime:SetText(FormatDuration(elapsedSeconds))

    if playerLevel >= GetMaxLevel() then
        values.currentXP:SetText("Max level")
        for _, key in ipairs({ "remainingXP", "restedXP", "xpPerHour", "timeToLevel", "killsToLevel" }) do
            values[key]:SetText("--")
        end
        return
    end

    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 1
    local remainingXP = maxXP - currentXP
    local restedXP = GetXPExhaustion() or 0
    local percentDone = maxXP > 0 and (currentXP / maxXP * 100) or 0
    values.currentXP:SetText(string.format("%s / %s |cffa6a6a6(%.1f%%)|r", FormatNumber(currentXP), FormatNumber(maxXP), percentDone))
    values.remainingXP:SetText(string.format("%s |cffa6a6a6(%.1f%%)|r", FormatNumber(remainingXP), 100 - percentDone))
    values.restedXP:SetText(restedXP > 0 and ("|cff66ccff" .. FormatNumber(restedXP) .. "|r") or "None")

    -- XP per hour over everything gained since the session started.
    local xpPerHour = elapsedSeconds > 0 and (sessionGainedXP / elapsedSeconds * 3600) or 0
    values.xpPerHour:SetText(xpPerHour > 0 and FormatNumber(xpPerHour) or "--")
    values.timeToLevel:SetText(xpPerHour > 0 and FormatDuration(remainingXP / xpPerHour * 3600) or "--")

    local averageKillXP = GetAverageKillXP()
    if averageKillXP and averageKillXP > 0 then
        values.killsToLevel:SetText(string.format("%d |cffa6a6a6(~%s each)|r",
            math.ceil(remainingXP / averageKillXP), FormatNumber(averageKillXP)))
    else
        values.killsToLevel:SetText("--")
    end
end

-- Shows the window when the setting is on (and the standalone LevelPace
-- addon is not loaded - then that one is used).
function levelPace.UpdateVisibility()
    local isWanted = MentorDB and MentorDB.isLevelPaceEnabled and not Mentor.IsStandaloneAddonLoaded(STANDALONE_ADDON_NAME)
    if isWanted and not panel:IsShown() then
        panel:RestorePosition()
        panel:Show()
        UpdateDisplay()
    elseif not isWanted and panel:IsShown() then
        panel:Hide()
    end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
for _, eventName in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
    "UPDATE_EXHAUSTION", "CHAT_MSG_COMBAT_XP_GAIN" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end
eventFrame:SetScript("OnEvent", function(_, eventName, ...)
    if eventName == "PLAYER_LOGIN" then
        levelPace.UpdateVisibility()
    elseif eventName == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        -- A new session on login / reload only, not on every loading screen.
        if isInitialLogin or isReloadingUi or sessionStartTime == 0 then
            levelPace.ResetSession()
        end
        UpdateDisplay()
    elseif eventName == "PLAYER_XP_UPDATE" or eventName == "PLAYER_LEVEL_UP" then
        TrackXPGain()
        UpdateDisplay()
    elseif eventName == "UPDATE_EXHAUSTION" then
        UpdateDisplay()
    elseif eventName == "CHAT_MSG_COMBAT_XP_GAIN" then
        local chatMessage = ...
        local experienceFromKill = KILL_XP_PATTERN and chatMessage and tonumber(chatMessage:match(KILL_XP_PATTERN))
        if experienceFromKill then
            RecordKillXP(experienceFromKill)
            UpdateDisplay()
        end
    end
end)

-- Time-based values (session time, XP / hour) and the on/off setting.
local secondsSinceRefresh = 0
eventFrame:SetScript("OnUpdate", function(_, elapsedSeconds)
    secondsSinceRefresh = secondsSinceRefresh + elapsedSeconds
    if secondsSinceRefresh >= REFRESH_INTERVAL_SECONDS then
        secondsSinceRefresh = 0
        levelPace.UpdateVisibility()
        UpdateDisplay()
    end
end)

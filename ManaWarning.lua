--------------------------------------------------------------------------------
-- Mentor - ManaWarning.lua
-- "Mana warning" (OFF by default; turn it on under Settings or with
-- /mentor mana on). Built from Are's standalone ManaWarning addon.
-- Shows a small Mentor-style box with your mana and warns you when it is low:
--   * LOW MANA      when mana drops below the low threshold (default 30%)
--   * OUT OF MANA   when mana drops below the critical threshold (default 10%)
-- Each warning fires once per dip; it re-arms when your mana is back above
-- the threshold (plus a small margin, so it does not spam while hovering).
--
-- The warning is a big text in the middle of the screen plus a sound, and is
-- also said in party/raid chat ("Low mana! (28%)") when you are in a group.
--
-- WoW Forever hides your current mana from addons ("secret value"), so the
-- addon cannot know when it is low. There a different mode is used: a step
-- curve is handed to UnitPowerPercent, the GAME compares the mana with the
-- thresholds and returns an alpha that makes the warning text visible or
-- invisible. The text then stays on screen for as long as mana is low.
-- Sound and automatic party messages need the addon itself to know the mana,
-- so they are not possible for "low" there; use /mentor mana say (in a macro).
-- What does work automatically: when a cast fails with "Not enough mana",
-- the sound plays and "Out of mana!" is said in party/raid chat.
--
-- The settings live in MentorDB. The first time Mentor sees the standalone
-- ManaWarning addon's settings, it copies them (thresholds, sound, party,
-- combat only) and turns its own mana warning on.
--
-- Slash commands:
--   /mentor mana on|off            turn the mana warning on or off
--   /mentor mana low <percent>     low mana threshold, e.g. /mentor mana low 25
--   /mentor mana critical <percent>  critical threshold, e.g. 10
--   /mentor mana sound on|off      play a sound with the warning
--   /mentor mana party on|off      say "Low mana!" in party/raid chat
--   /mentor mana combat on|off     only warn while in combat
--   /mentor mana say               say "Low mana!" in party/raid chat now (macro)
--   /mentor mana test              show a test warning
--   /mentor mana debug             print what the game reports
-- The box follows the Mentor lock (/mentor lock).
--------------------------------------------------------------------------------

local _, Mentor = ...
local STANDALONE_ADDON_NAME = "ManaWarning"

local manaWarning = {}
Mentor.ManaWarning = manaWarning

--------------------------------------------------------------------------------
-- Configuration constants
--------------------------------------------------------------------------------
local MANA_POWER_TYPE           = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local REARM_MARGIN_PERCENT      = 5      -- mana must climb this far above a threshold to warn again
local WARNING_HOLD_SECONDS      = 2.0    -- how long the big text stays fully visible
local WARNING_FADE_SECONDS      = 1.0    -- how long it takes to fade out
local WARNING_TEXT_OFFSET_Y     = 180    -- height of the big text above the screen center
local WARNING_TEXT_SCALE        = 1.6
local LOW_WARNING_COLOR         = { 0.30, 0.60, 1.00 } -- blue
local CRITICAL_WARNING_COLOR    = { 1.00, 0.25, 0.25 } -- red
local LOW_WARNING_TEXT          = "LOW MANA"
local CRITICAL_WARNING_TEXT     = "OUT OF MANA"
local LOW_CHAT_TEXT             = "Low mana! (%d%%)"    -- %d = current mana percent
local CRITICAL_CHAT_TEXT        = "Out of mana! (%d%%)"
local WARNING_SOUND_KIT_ID      = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959
local MANUAL_CHAT_TEXT          = "Low mana!"           -- used by /mentor mana say
local NOT_ENOUGH_MANA_CHAT_TEXT = "Out of mana!"        -- sent when a cast fails for lack of mana
local NOT_ENOUGH_MANA_COOLDOWN_SECONDS = 20             -- at most one such message per 20 seconds
local MINIMUM_PERCENT           = 1
local MAXIMUM_PERCENT           = 99
local CURVE_EPSILON             = 0.0001 -- tiny offset so a step lands just past the threshold

local BOX_WIDTH                 = 150
local BOX_HEIGHT                = 42
local BOX_PADDING               = 9
local BAR_HEIGHT                = 10
local BACKGROUND_ALPHA          = 0.55
local FONT_OBJECT               = "GameFontHighlightSmall"
local ENABLED_TEXT              = "|cff40ff40ON|r"
local DISABLED_TEXT             = "|cffff4040OFF|r"
local MANA_BAR_COLOR            = { 0.00, 0.45, 1.00 }

-- The settings in MentorDB (missing ones get these values).
local DEFAULT_SETTINGS = {
    manaLowPercent = 30,
    manaCriticalPercent = 10,
    isManaSoundEnabled = true,
    isManaPartyMessageEnabled = true,
    isManaCombatOnly = false,
}
local DEFAULT_BOX_POSITION = { point = "CENTER", relativePoint = "CENTER", offsetX = 0, offsetY = -200 }
local MENTOR_GOLD = { 1.00, 0.78, 0.10 }

-- Short names for the settings, so the code below reads like the original.
local function GetSettings()
    return {
        isEnabled = MentorDB and MentorDB.isManaWarningEnabled and not Mentor.IsStandaloneAddonLoaded(STANDALONE_ADDON_NAME),
        lowThresholdPercent = MentorDB.manaLowPercent or DEFAULT_SETTINGS.manaLowPercent,
        criticalThresholdPercent = MentorDB.manaCriticalPercent or DEFAULT_SETTINGS.manaCriticalPercent,
        isSoundEnabled = MentorDB.isManaSoundEnabled ~= false,
        isPartyMessageEnabled = MentorDB.isManaPartyMessageEnabled ~= false,
        isCombatOnly = MentorDB.isManaCombatOnly == true,
    }
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local isLowWarningArmed = true       -- false after a LOW warning until mana recovers
local isCriticalWarningArmed = true  -- false after an OUT OF MANA warning until mana recovers
local hasReportedError = false       -- only print the first error, to avoid chat spam
local lastNotEnoughManaMessageTime = -math.huge

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function PrintMessage(text)
    Mentor.Print("Mana warning: " .. text)
end

-- True when the client hides this value from addons (WoW Forever, in combat).
local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Returns current mana, maximum mana and the percentage, or nil when the
-- values are hidden or the character has no mana.
local function GetManaInfo()
    local currentMana = UnitPower("player", MANA_POWER_TYPE)
    local maximumMana = UnitPowerMax("player", MANA_POWER_TYPE)
    if IsSecret(currentMana) or IsSecret(maximumMana) then
        return nil
    end
    if not maximumMana or maximumMana <= 0 then
        return nil
    end
    return currentMana, maximumMana, currentMana / maximumMana * 100
end

local function CharacterUsesMana()
    local maximumMana = UnitPowerMax("player", MANA_POWER_TYPE)
    if IsSecret(maximumMana) then
        return true -- cannot tell right now; assume yes
    end
    return maximumMana and maximumMana > 0
end

-- WoW Forever hides unit state flags (dead, AFK, ...) from addons. A hidden
-- "dead" flag is treated as alive, so the warning still works.
local function IsPlayerDead()
    local isDeadOrGhost = UnitIsDeadOrGhost("player")
    if IsSecret(isDeadOrGhost) then
        return false
    end
    return isDeadOrGhost and true or false
end

local function IsPlayerInCombat()
    local inCombat = UnitAffectingCombat("player")
    if IsSecret(inCombat) then
        return true
    end
    return inCombat and true or false
end

--------------------------------------------------------------------------------
-- Big on-screen warning text
--------------------------------------------------------------------------------
local warningFrame = CreateFrame("Frame", "MentorManaWarningAlertFrame", UIParent)
warningFrame:SetSize(600, 60)
warningFrame:SetPoint("CENTER", UIParent, "CENTER", 0, WARNING_TEXT_OFFSET_Y)
warningFrame:SetFrameStrata("HIGH")
warningFrame:Hide()

local warningText = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
warningText:SetPoint("CENTER")
warningText:SetScale(WARNING_TEXT_SCALE)
warningText:SetShadowOffset(2, -2)

local warningElapsedSeconds = 0
warningFrame:SetScript("OnUpdate", function(self, elapsedSinceLastFrame)
    warningElapsedSeconds = warningElapsedSeconds + elapsedSinceLastFrame
    if warningElapsedSeconds <= WARNING_HOLD_SECONDS then
        self:SetAlpha(1)
    else
        local fadeProgress = (warningElapsedSeconds - WARNING_HOLD_SECONDS) / WARNING_FADE_SECONDS
        if fadeProgress >= 1 then
            self:Hide()
        else
            self:SetAlpha(1 - fadeProgress)
        end
    end
end)

-- chatText is a format string with the mana percent (or nil for no chat message).
local function ShowWarning(displayText, textColor, chatText, manaPercent)
    warningText:SetText(displayText)
    warningText:SetTextColor(textColor[1], textColor[2], textColor[3])
    warningElapsedSeconds = 0
    warningFrame:SetAlpha(1)
    warningFrame:Show()

    if GetSettings().isSoundEnabled then
        pcall(PlaySound, WARNING_SOUND_KIT_ID, "Master")
    end

    -- Tell the group (only when actually in a party or raid).
    if GetSettings().isPartyMessageEnabled and chatText and IsInGroup() then
        local chatChannel = IsInRaid() and "RAID" or "PARTY"
        local chatMessage = string.format(chatText, math.floor((manaPercent or 0) + 0.5))
        pcall(SendChatMessage, chatMessage, chatChannel)
    end
end

--------------------------------------------------------------------------------
-- Hidden-mana mode (WoW Forever)
-- The addon never sees the mana number. Each warning text gets a step curve:
-- the game evaluates it with your mana percentage and returns a color whose
-- alpha is 1 (show) inside the warning range and 0 (hide) outside it. That
-- secret alpha goes straight into SetAlpha - the addon never looks at it.
--------------------------------------------------------------------------------
local function CreateHiddenModeWarning(displayText, textColor)
    local hiddenWarningFrame = CreateFrame("Frame", nil, UIParent)
    hiddenWarningFrame:SetSize(600, 60)
    hiddenWarningFrame:SetPoint("CENTER", UIParent, "CENTER", 0, WARNING_TEXT_OFFSET_Y)
    hiddenWarningFrame:SetFrameStrata("HIGH")
    hiddenWarningFrame:SetAlpha(0)

    local hiddenWarningText = hiddenWarningFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    hiddenWarningText:SetPoint("CENTER")
    hiddenWarningText:SetScale(WARNING_TEXT_SCALE)
    hiddenWarningText:SetShadowOffset(2, -2)
    hiddenWarningText:SetText(displayText)
    hiddenWarningText:SetTextColor(textColor[1], textColor[2], textColor[3])
    return hiddenWarningFrame
end

local hiddenLowWarningFrame = CreateHiddenModeWarning(LOW_WARNING_TEXT, LOW_WARNING_COLOR)
local hiddenCriticalWarningFrame = CreateHiddenModeWarning(CRITICAL_WARNING_TEXT, CRITICAL_WARNING_COLOR)
local lowWarningCurve, criticalWarningCurve -- rebuilt when the thresholds change
local workingArgumentOrder                  -- which UnitPowerPercent call style works
local hasWarnedAboutMissingCurveSupport = false

local function IsManaHidden()
    return IsSecret(UnitPower("player", MANA_POWER_TYPE))
end

-- Step curve on a 0..1 mana scale: alpha 1 while lowerFraction < mana <= upperFraction.
-- lowerFraction = nil means "from 0".
local function CreateBandCurve(lowerFraction, upperFraction)
    local bandCurve = C_CurveUtil.CreateColorCurve()
    bandCurve:SetType(Enum.LuaCurveType.Step)
    if lowerFraction then
        bandCurve:AddPoint(0, CreateColor(1, 1, 1, 0))
        bandCurve:AddPoint(lowerFraction + CURVE_EPSILON, CreateColor(1, 1, 1, 1))
    else
        bandCurve:AddPoint(0, CreateColor(1, 1, 1, 1))
    end
    bandCurve:AddPoint(upperFraction + CURVE_EPSILON, CreateColor(1, 1, 1, 0))
    return bandCurve
end

local function RebuildWarningCurves()
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor and Enum and Enum.LuaCurveType) then
        lowWarningCurve, criticalWarningCurve = nil, nil
        return
    end
    local lowFraction = GetSettings().lowThresholdPercent / 100
    local criticalFraction = GetSettings().criticalThresholdPercent / 100
    -- "LOW MANA" between critical and low, "OUT OF MANA" below critical, so
    -- only one of the two texts is ever visible.
    lowWarningCurve = CreateBandCurve(criticalFraction, lowFraction)
    criticalWarningCurve = CreateBandCurve(nil, criticalFraction)
end

-- Asks the game to evaluate a curve with the player's mana percentage.
-- Two argument orders exist across client builds; the working one is remembered.
local function EvaluateManaCurve(curve)
    local function TryArgumentOrder(argumentOrder)
        local success, curveColor
        if argumentOrder == 1 then
            success, curveColor = pcall(UnitPowerPercent, "player", MANA_POWER_TYPE, false, curve)
        else
            success, curveColor = pcall(UnitPowerPercent, "player", MANA_POWER_TYPE, curve)
        end
        if success and type(curveColor) == "table" then
            return curveColor
        end
        return nil
    end
    if not UnitPowerPercent or not curve then
        return nil
    end
    if workingArgumentOrder then
        local curveColor = TryArgumentOrder(workingArgumentOrder)
        if curveColor then
            return curveColor
        end
    end
    for argumentOrder = 1, 2 do
        local curveColor = TryArgumentOrder(argumentOrder)
        if curveColor then
            workingArgumentOrder = argumentOrder
            return curveColor
        end
    end
    return nil
end

-- Puts the game's (secret) alpha straight onto the frame; hides it if that fails.
local function ApplyCurveAlpha(targetFrame, curve)
    local curveColor = EvaluateManaCurve(curve)
    if curveColor then
        local success, _, _, _, curveAlpha = pcall(curveColor.GetRGBA, curveColor)
        if success and pcall(targetFrame.SetAlpha, targetFrame, curveAlpha) then
            return true
        end
    end
    targetFrame:SetAlpha(0)
    return false
end

local function HideHiddenModeWarnings()
    hiddenLowWarningFrame:SetAlpha(0)
    hiddenCriticalWarningFrame:SetAlpha(0)
end

local function UpdateHiddenModeWarnings(isAllowedToWarn)
    if not isAllowedToWarn then
        HideHiddenModeWarnings()
        return
    end
    local lowApplied = ApplyCurveAlpha(hiddenLowWarningFrame, lowWarningCurve)
    local criticalApplied = ApplyCurveAlpha(hiddenCriticalWarningFrame, criticalWarningCurve)
    if not (lowApplied and criticalApplied) and not hasWarnedAboutMissingCurveSupport then
        hasWarnedAboutMissingCurveSupport = true
        PrintMessage("This client hides your mana and the curve check is not available, so no warning can be shown. Please send /mentor mana debug.")
    end
end

-- Mana percentage as display text. In hidden mode the game's own ScaleTo100
-- curve gives a secret 0..100 number, which may go into string.format and
-- SetText but is never compared or calculated with.
local function GetManaPercentText()
    local _, _, manaPercent = GetManaInfo()
    if manaPercent then
        return string.format("Mana %d%%", math.floor(manaPercent + 0.5))
    end
    local scaleTo100Curve = CurveConstants and CurveConstants.ScaleTo100
    if scaleTo100Curve and UnitPowerPercent then
        local argumentOrders = { workingArgumentOrder or 1, (workingArgumentOrder == 2) and 1 or 2 }
        for _, argumentOrder in ipairs(argumentOrders) do
            local success, hiddenPercent
            if argumentOrder == 1 then
                success, hiddenPercent = pcall(UnitPowerPercent, "player", MANA_POWER_TYPE, false, scaleTo100Curve)
            else
                success, hiddenPercent = pcall(UnitPowerPercent, "player", MANA_POWER_TYPE, scaleTo100Curve)
            end
            if success and hiddenPercent ~= nil then
                local formatted, percentText = pcall(string.format, "Mana %.0f%%", hiddenPercent)
                if formatted then
                    return percentText
                end
            end
        end
    end
    return "Mana ?"
end

--------------------------------------------------------------------------------
-- Mana check (runs on every mana change)
--------------------------------------------------------------------------------
local UpdateBox -- forward declaration, defined with the box below

local function IsAllowedToWarn()
    return GetSettings().isEnabled
        and CharacterUsesMana()
        and not IsPlayerDead()
        and (not GetSettings().isCombatOnly or IsPlayerInCombat())
end

local function CheckMana()
    -- WoW Forever: the game decides visibility through the curves.
    if IsManaHidden() then
        UpdateHiddenModeWarnings(IsAllowedToWarn())
        return
    end
    HideHiddenModeWarnings()

    local _, _, manaPercent = GetManaInfo()
    if manaPercent == nil then
        return -- this character has no mana
    end

    local lowThreshold = GetSettings().lowThresholdPercent
    local criticalThreshold = GetSettings().criticalThresholdPercent

    -- Re-arm the warnings once mana is safely back above each threshold.
    if manaPercent >= lowThreshold + REARM_MARGIN_PERCENT then
        isLowWarningArmed = true
    end
    if manaPercent >= criticalThreshold + REARM_MARGIN_PERCENT then
        isCriticalWarningArmed = true
    end

    if not IsAllowedToWarn() then
        return
    end

    if manaPercent < criticalThreshold and isCriticalWarningArmed then
        isCriticalWarningArmed = false
        isLowWarningArmed = false -- critical already covers "low"
        ShowWarning(CRITICAL_WARNING_TEXT, CRITICAL_WARNING_COLOR, CRITICAL_CHAT_TEXT, manaPercent)
    elseif manaPercent < lowThreshold and isLowWarningArmed then
        isLowWarningArmed = false
        ShowWarning(LOW_WARNING_TEXT, LOW_WARNING_COLOR, LOW_CHAT_TEXT, manaPercent)
    end
end

--------------------------------------------------------------------------------
-- Small movable mana box (left-click toggles, drag moves)
--------------------------------------------------------------------------------
local manaBox = CreateFrame("Button", "MentorManaWarningBox", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
manaWarning.box = manaBox
local manaBar, manaText, statusText
local wasDraggedSinceMouseDown = false

local function SaveBoxPosition()
    local point, _, relativePoint, offsetX, offsetY = manaBox:GetPoint()
    MentorDB.manaWarningPosition = { point = point, relativePoint = relativePoint, offsetX = offsetX, offsetY = offsetY }
end

local function RestoreBoxPosition()
    local position = type(MentorDB.manaWarningPosition) == "table" and MentorDB.manaWarningPosition or DEFAULT_BOX_POSITION
    manaBox:ClearAllPoints()
    manaBox:SetPoint(position.point, UIParent, position.relativePoint, position.offsetX, position.offsetY)
end

function manaWarning.ResetPosition()
    MentorDB.manaWarningPosition = nil
    RestoreBoxPosition()
end

local function SetWarningsEnabled(shouldBeEnabled)
    MentorDB.isManaWarningEnabled = shouldBeEnabled
    -- Fresh start, so an already-low mana bar warns right away when turned on.
    isLowWarningArmed, isCriticalWarningArmed = true, true
    PrintMessage("Mana warnings are now " .. (shouldBeEnabled and ENABLED_TEXT or DISABLED_TEXT) .. ".")
    UpdateBox()
    CheckMana()
end

local function BuildBox()
    manaBox:SetSize(BOX_WIDTH, BOX_HEIGHT)
    manaBox:SetFrameStrata("MEDIUM")
    manaBox:SetClampedToScreen(true)
    manaBox:SetMovable(true)
    manaBox:EnableMouse(true)
    manaBox:RegisterForClicks("LeftButtonUp")
    manaBox:RegisterForDrag("LeftButton")

    -- Mentor look: dark background with a gold border.
    if manaBox.SetBackdrop then
        manaBox:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        manaBox:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.9)
    end

    -- Top line: "Mana 72%" on the left, ON/OFF on the right.
    manaText = manaBox:CreateFontString(nil, "OVERLAY", FONT_OBJECT)
    manaText:SetPoint("TOPLEFT", BOX_PADDING, -BOX_PADDING)
    manaText:SetJustifyH("LEFT")

    statusText = manaBox:CreateFontString(nil, "OVERLAY", FONT_OBJECT)
    statusText:SetPoint("TOPRIGHT", -BOX_PADDING, -BOX_PADDING)
    statusText:SetJustifyH("RIGHT")

    -- Mana bar along the bottom.
    manaBar = CreateFrame("StatusBar", nil, manaBox)
    manaBar:SetPoint("BOTTOMLEFT", BOX_PADDING, BOX_PADDING)
    manaBar:SetPoint("BOTTOMRIGHT", -BOX_PADDING, BOX_PADDING)
    manaBar:SetHeight(BAR_HEIGHT)
    manaBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    manaBar:SetStatusBarColor(MANA_BAR_COLOR[1], MANA_BAR_COLOR[2], MANA_BAR_COLOR[3])
    manaBar:SetMinMaxValues(0, 1)
    manaBar:SetValue(1)

    local barBackground = manaBar:CreateTexture(nil, "BACKGROUND")
    barBackground:SetAllPoints()
    barBackground:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    -- Drag to move; a click without dragging toggles the warnings.
    manaBox:SetScript("OnMouseDown", function()
        wasDraggedSinceMouseDown = false
    end)
    manaBox:SetScript("OnDragStart", function(self)
        if not MentorDB.isLocked then
            wasDraggedSinceMouseDown = true
            self:StartMoving()
        end
    end)
    manaBox:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveBoxPosition()
    end)
    manaBox:SetScript("OnClick", function()
        if not wasDraggedSinceMouseDown and Mentor.ToggleSettings then
            Mentor.ToggleSettings()          -- the mana options are in Mentor's settings
        end
    end)

    -- Tooltip explaining the controls.
    manaBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Mentor: Mana warning")
        GameTooltip:AddLine(string.format("Warns below %d%% (low) and %d%% (critical).",
            GetSettings().lowThresholdPercent, GetSettings().criticalThresholdPercent), 1, 1, 1)
        GameTooltip:AddLine("Click: Mentor settings   Drag: move", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("/mentor mana low|critical <percent>", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    manaBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

UpdateBox = function()
    if not manaBar then
        return
    end
    statusText:SetText(GetSettings().isCombatOnly and "|cffa6a6a6combat only|r" or "")

    local currentMana = UnitPower("player", MANA_POWER_TYPE)
    local maximumMana = UnitPowerMax("player", MANA_POWER_TYPE)
    -- The status bar accepts hidden values directly, so the bar keeps working
    -- even when the number itself cannot be read.
    pcall(manaBar.SetMinMaxValues, manaBar, 0, maximumMana or 1)
    pcall(manaBar.SetValue, manaBar, currentMana or 0)

    -- "Mana ?" = the game hides the number and no display workaround exists.
    manaText:SetText(GetManaPercentText())

    -- Only show the box for characters that use mana.
    manaBox:SetShown(GetSettings().isEnabled and CharacterUsesMana() and true or false)
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local isBoxBuilt = false

-- The first time the standalone ManaWarning's settings are found, copy them
-- (ManaWarning itself is not changed) and turn Mentor's mana warning on.
function manaWarning.ImportFromStandalone()
    local standaloneSettings = _G["ManaWarningDB"]
    if type(standaloneSettings) ~= "table" or MentorDB.isManaWarningImported then
        return
    end
    MentorDB.isManaWarningImported = true
    MentorDB.manaLowPercent = tonumber(standaloneSettings.lowThresholdPercent) or MentorDB.manaLowPercent
    MentorDB.manaCriticalPercent = tonumber(standaloneSettings.criticalThresholdPercent) or MentorDB.manaCriticalPercent
    for standaloneName, mentorName in pairs({ isSoundEnabled = "isManaSoundEnabled",
        isPartyMessageEnabled = "isManaPartyMessageEnabled", isCombatOnly = "isManaCombatOnly" }) do
        if type(standaloneSettings[standaloneName]) == "boolean" then
            MentorDB[mentorName] = standaloneSettings[standaloneName]
        end
    end
    if standaloneSettings.isEnabled ~= false then
        MentorDB.isManaWarningEnabled = true
    end
    PrintMessage("your ManaWarning settings have been copied into Mentor. Disable the ManaWarning addon to use Mentor's.")
end


local function OnManaChanged()
    UpdateBox()
    CheckMana()
end

-- Called when the setting changes: show / hide the box, re-arm the warnings.
function manaWarning.UpdateVisibility()
    if not isBoxBuilt then
        return
    end
    isLowWarningArmed, isCriticalWarningArmed = true, true
    RebuildWarningCurves()
    pcall(OnManaChanged)
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- entering combat (for combat-only mode)
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- leaving combat (hides combat-only warnings)
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_UNGHOST")
eventFrame:RegisterEvent("UI_ERROR_MESSAGE")       -- "Not enough mana" when a cast fails

-- The red "Not enough mana" error is NOT hidden on Forever, so it is the one
-- reliable automatic signal there. It fires right after your own key press.
local function HandleNotEnoughMana()
    if not GetSettings().isEnabled then
        return
    end
    if GetTime() - lastNotEnoughManaMessageTime < NOT_ENOUGH_MANA_COOLDOWN_SECONDS then
        return
    end
    lastNotEnoughManaMessageTime = GetTime()
    if GetSettings().isSoundEnabled then
        pcall(PlaySound, WARNING_SOUND_KIT_ID, "Master")
    end
    if GetSettings().isPartyMessageEnabled and IsInGroup() then
        local chatChannel = IsInRaid() and "RAID" or "PARTY"
        pcall(SendChatMessage, NOT_ENOUGH_MANA_CHAT_TEXT, chatChannel)
    end
end
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
eventFrame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
-- UNIT_POWER_FREQUENT updates more smoothly; fall back to UNIT_POWER_UPDATE.
if not pcall(eventFrame.RegisterUnitEvent, eventFrame, "UNIT_POWER_FREQUENT", "player") then
    eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
end

eventFrame:SetScript("OnEvent", function(self, eventName, ...)
    if eventName == "PLAYER_LOGIN" then
        for settingName, defaultValue in pairs(DEFAULT_SETTINGS) do
            if MentorDB[settingName] == nil then
                MentorDB[settingName] = defaultValue
            end
        end
        manaWarning.ImportFromStandalone()
        BuildBox()
        RestoreBoxPosition()
        RebuildWarningCurves()
        isBoxBuilt = true
        pcall(OnManaChanged)
        return
    end
    if not isBoxBuilt then
        return
    end

    if eventName == "UI_ERROR_MESSAGE" then
        local _, errorText = ...
        if errorText and not IsSecret(errorText) and ERR_OUT_OF_MANA and errorText == ERR_OUT_OF_MANA then
            pcall(HandleNotEnoughMana)
        end
        return
    end

    if eventName == "UNIT_POWER_FREQUENT" or eventName == "UNIT_POWER_UPDATE" then
        local _, powerTypeName = ...
        if powerTypeName and not IsSecret(powerTypeName) and powerTypeName ~= "MANA" then
            return -- rage / energy changes are not interesting
        end
    end

    -- Every other event: refresh the box and check the mana level.
    -- Errors are shown once (not silently swallowed) so problems are visible.
    local success, errorMessage = pcall(OnManaChanged)
    if not success and not hasReportedError then
        hasReportedError = true
        PrintMessage("Error (shown once): " .. tostring(errorMessage))
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

local function ParsePercent(text)
    local percent = tonumber(text)
    if not percent or percent < MINIMUM_PERCENT or percent > MAXIMUM_PERCENT then
        return nil
    end
    return math.floor(percent)
end

-- Settings that are simple on/off switches: command -> { setting, description }
local ON_OFF_SETTINGS = {
    sound  = { "isManaSoundEnabled",        "Warning sound" },
    party  = { "isManaPartyMessageEnabled", "Party/raid chat message" },
    combat = { "isManaCombatOnly",          "Only warn in combat" },
}

function manaWarning.HandleCommand(input)
    if not isBoxBuilt then
        return
    end
    local command, argument = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()

    if command == "" or command == "toggle" then
        SetWarningsEnabled(not GetSettings().isEnabled)
    elseif command == "on" then
        SetWarningsEnabled(true)
    elseif command == "off" then
        SetWarningsEnabled(false)
    elseif command == "low" or command == "critical" then
        local percent = ParsePercent(argument)
        if not percent then
            PrintMessage(string.format("Usage: /mentor mana %s <%d-%d>", command, MINIMUM_PERCENT, MAXIMUM_PERCENT))
            return
        end
        if command == "low" then
            MentorDB.manaLowPercent = percent
        else
            MentorDB.manaCriticalPercent = percent
        end
        isLowWarningArmed, isCriticalWarningArmed = true, true
        RebuildWarningCurves()
        CheckMana()
        PrintMessage(string.format("%s mana warning set to %d%%.",
            command == "low" and "Low" or "Critical", percent))
    elseif ON_OFF_SETTINGS[command] then
        local settingName, description = ON_OFF_SETTINGS[command][1], ON_OFF_SETTINGS[command][2]
        local newValue = ParseOnOff(argument)
        if newValue == nil then
            PrintMessage("Usage: /mentor mana " .. command .. " on|off")
            return
        end
        MentorDB[settingName] = newValue
        UpdateBox()
        PrintMessage(description .. ": " .. (newValue and ENABLED_TEXT or DISABLED_TEXT))
    elseif command == "say" then
        -- Manual party/raid message, for a macro or key binding. Works on
        -- every client because it is your own key press, not an automatic check.
        if IsInGroup() then
            local chatChannel = IsInRaid() and "RAID" or "PARTY"
            local sentOk = pcall(SendChatMessage, MANUAL_CHAT_TEXT, chatChannel)
            if not sentOk then
                PrintMessage("The game blocked the chat message.")
            end
        else
            PrintMessage("You are not in a group.")
        end
    elseif command == "test" then
        ShowWarning(LOW_WARNING_TEXT .. " (test)", LOW_WARNING_COLOR, nil)
    elseif command == "debug" then
        -- Shows exactly what the game gives the addon, to find out why a
        -- warning does or does not fire.
        local function Describe(value)
            if IsSecret(value) then
                return "|cffff8000HIDDEN|r"
            end
            return tostring(value)
        end
        local _, _, manaPercent = GetManaInfo()
        PrintMessage("Debug:")
        PrintMessage("  mana = " .. Describe(UnitPower("player", MANA_POWER_TYPE))
            .. " / " .. Describe(UnitPowerMax("player", MANA_POWER_TYPE))
            .. "  -> percent " .. (manaPercent and string.format("%.1f", manaPercent) or "unreadable"))
        PrintMessage("  dead = " .. Describe(UnitIsDeadOrGhost("player"))
            .. ", in combat = " .. Describe(UnitAffectingCombat("player"))
            .. ", in group = " .. Describe(IsInGroup()))
        PrintMessage(string.format("  enabled = %s, low = %d%%, critical = %d%%, combat only = %s, party = %s",
            tostring(GetSettings().isEnabled), GetSettings().lowThresholdPercent,
            GetSettings().criticalThresholdPercent, tostring(GetSettings().isCombatOnly),
            tostring(GetSettings().isPartyMessageEnabled)))
        PrintMessage("  low warning armed = " .. tostring(isLowWarningArmed)
            .. ", critical armed = " .. tostring(isCriticalWarningArmed))
        -- Hidden-mana mode details.
        local lowCurveColor = EvaluateManaCurve(lowWarningCurve)
        PrintMessage("  hidden mode = " .. tostring(IsManaHidden())
            .. ", curve support = " .. tostring(lowWarningCurve ~= nil)
            .. ", UnitPowerPercent = " .. tostring(UnitPowerPercent ~= nil)
            .. ", curve answer = " .. tostring(lowCurveColor ~= nil)
            .. ", argument order = " .. tostring(workingArgumentOrder))
        PrintMessage("  box text = " .. GetManaPercentText())
    else
        PrintMessage(string.format("Warnings %s | low %d%% | critical %d%% | sound %s | party %s | combat only %s",
            GetSettings().isEnabled and ENABLED_TEXT or DISABLED_TEXT,
            GetSettings().lowThresholdPercent, GetSettings().criticalThresholdPercent,
            GetSettings().isSoundEnabled and "on" or "off",
            GetSettings().isPartyMessageEnabled and "on" or "off",
            GetSettings().isCombatOnly and "on" or "off"))
        PrintMessage("Commands: /mentor mana on|off | low <%> | critical <%> | sound on|off | party on|off | combat on|off | say | test | debug")
    end
end

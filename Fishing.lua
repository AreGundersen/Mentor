--------------------------------------------------------------------------------
-- Mentor - Fishing.lua
-- "One-key fishing" (OFF by default; turn it on under Settings or with
-- /mentor fishing on). That shows a small Mentor window with a Start / Stop
-- fishing button. While fishing mode is on, one key does everything:
--   * no bobber out -> the key casts Fishing
--   * bobber is out -> the key interacts with the bobber (reels in the catch)
-- Built from Are's standalone OneKeyFishing addon, in the Mentor look.
--
-- How it works: the key is temporarily bound (override binding) to a secure
-- "cast Fishing" button. When the Fishing channel starts, the same key is
-- bound to "Interact With Target", and soft targeting makes the bobber the
-- interact target. Every press is still your own key press.
-- While fishing mode is on, auto loot is turned on and the sound effects are
-- turned up so the splash is easy to hear; your settings come back when
-- fishing mode is turned off.
--
--   /mentor fish            start / stop fishing mode
--   /mentor fish key <KEY>  choose the key, e.g. /mentor fish key F or BUTTON3
--   /mentor fish reset      reset the catch counter
--------------------------------------------------------------------------------

local _, Mentor = ...

local DEFAULT_FISHING_KEY = "F"
local FISHING_SPELL_ID = 7620            -- "Fishing"; casting by name uses your highest rank
local FISHING_SFX_VOLUME = 1.0
local FISHING_MASTER_VOLUME = 1.0
local SOFT_INTERACT_ALWAYS = "3"         -- SoftTargetInteract 3 = always soft-target interactables
local REFRESH_INTERVAL_SECONDS = 1.0
local STANDALONE_ADDON_NAME = "OneKeyFishing"
local ON_TEXT = "|cff40ff40"
local OFF_TEXT = "|cffa6a6a6"

local fishing = {}
Mentor.Fishing = fishing

local isFishingModeOn = false
local isBobberOut = false               -- true while the Fishing channel is active
local sessionCatchCount = 0
local lastCatchText = "--"
local savedCVarValues = {}              -- original values, restored when fishing mode ends
local isBindingUpdatePending = false    -- a binding change asked for during combat

local function IsActive()
    return MentorDB and MentorDB.isFishingEnabled and not Mentor.IsStandaloneAddonLoaded(STANDALONE_ADDON_NAME)
end

local function GetFishingKey()
    return (MentorDB and MentorDB.fishingKey) or DEFAULT_FISHING_KEY
end

--------------------------------------------------------------------------------
-- Game settings (cvars) changed while fishing, and restored afterwards
--------------------------------------------------------------------------------
local function GetSpellNameById(spellId)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellId)
    end
    return GetSpellInfo and (GetSpellInfo(spellId))
end
local FISHING_SPELL_NAME = GetSpellNameById(FISHING_SPELL_ID) or "Fishing"

local function ReadCVar(cvarName)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(cvarName)
    end
    return GetCVar and GetCVar(cvarName)
end

local function WriteCVar(cvarName, value)
    pcall(function()                     -- a cvar this client does not have must never throw
        if C_CVar and C_CVar.SetCVar then
            C_CVar.SetCVar(cvarName, value)
        else
            SetCVar(cvarName, value)
        end
    end)
end

local function OverrideCVar(cvarName, newValue)
    local originalValue = ReadCVar(cvarName)
    if originalValue == nil then
        return
    end
    if savedCVarValues[cvarName] == nil then
        savedCVarValues[cvarName] = originalValue
    end
    WriteCVar(cvarName, tostring(newValue))
end

local function RestoreAllCVars()
    for cvarName, originalValue in pairs(savedCVarValues) do
        WriteCVar(cvarName, originalValue)
    end
    wipe(savedCVarValues)
end

--------------------------------------------------------------------------------
-- The key: a secure "cast Fishing" button (casting is a protected action)
--------------------------------------------------------------------------------
local castFishingButton = CreateFrame("Button", "MentorFishingCastButton", UIParent, "SecureActionButtonTemplate")
castFishingButton:SetAttribute("type", "spell")
castFishingButton:SetAttribute("spell", FISHING_SPELL_NAME)
castFishingButton:RegisterForClicks("AnyUp", "AnyDown")
castFishingButton:Hide()                 -- only "clicked" through the key binding

-- Owner of the override bindings, so only our own bindings are cleared.
local bindingOwnerFrame = CreateFrame("Frame", "MentorFishingBindingOwner", UIParent)

local function ApplyKeyBinding()
    if InCombatLockdown() then           -- bindings cannot change in combat; try again after
        isBindingUpdatePending = true
        return
    end
    isBindingUpdatePending = false
    ClearOverrideBindings(bindingOwnerFrame)
    if not isFishingModeOn then
        return
    end
    if isBobberOut then
        SetOverrideBinding(bindingOwnerFrame, true, GetFishingKey(), "INTERACTTARGET")
    else
        SetOverrideBindingClick(bindingOwnerFrame, true, GetFishingKey(), castFishingButton:GetName(), "LeftButton")
    end
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
local ROW_DEFINITIONS = {
    { key = "status",    label = "Status" },
    { key = "fishKey",   label = "Key" },
    { key = "catches",   label = "Catches" },
    { key = "lastCatch", label = "Last catch" },
}
local panel = Mentor.CreateInfoPanel("MentorFishingFrame", "One-key fishing", ROW_DEFINITIONS,
    "fishingPosition", { point = "CENTER", relativePoint = "CENTER", offsetX = 0, offsetY = -150 }, "Start fishing")
fishing.panel = panel

local function UpdateDisplay()
    if not panel:IsShown() then
        return
    end
    local values = panel.values
    if not isFishingModeOn then
        values.status:SetText(OFF_TEXT .. "Off|r")
    elseif isBobberOut then
        values.status:SetText(ON_TEXT .. "Bobber out - press to reel in|r")
    else
        values.status:SetText(ON_TEXT .. "On - press to cast|r")
    end
    values.fishKey:SetText(GetFishingKey())
    values.catches:SetText(tostring(sessionCatchCount))
    values.lastCatch:SetText(lastCatchText)
    panel.footerButton:SetText(isFishingModeOn and "Stop fishing" or "Start fishing")
end

function fishing.SetFishingMode(shouldBeOn)
    if InCombatLockdown() then
        Mentor.Print("Fishing mode can't be changed in combat.")
        return
    end
    if shouldBeOn and not IsActive() then
        Mentor.Print("Turn on One-key fishing under Settings first (or /mentor fishing on).")
        return
    end
    isFishingModeOn = shouldBeOn and true or false
    isBobberOut = false
    if isFishingModeOn then
        OverrideCVar("SoftTargetInteract", SOFT_INTERACT_ALWAYS)
        OverrideCVar("autoLootDefault", "1")
        OverrideCVar("Sound_EnableSFX", "1")
        OverrideCVar("Sound_SFXVolume", FISHING_SFX_VOLUME)
        OverrideCVar("Sound_MasterVolume", FISHING_MASTER_VOLUME)
        Mentor.Print("Fishing mode on. Press " .. GetFishingKey() .. " to cast, and again to reel in.")
    else
        RestoreAllCVars()
        Mentor.Print("Fishing mode off. Your sound and loot settings are back.")
    end
    ApplyKeyBinding()
    UpdateDisplay()
end

panel.footerButton:SetScript("OnClick", function()
    fishing.SetFishingMode(not isFishingModeOn)
end)

function fishing.IsFishingModeOn()
    return isFishingModeOn
end

function fishing.UpdateVisibility()
    local isWanted = IsActive()
    if isWanted and not panel:IsShown() then
        panel:RestorePosition()
        panel:Show()
        UpdateDisplay()
    elseif not isWanted and panel:IsShown() then
        if isFishingModeOn then
            fishing.SetFishingMode(false)    -- turning the feature off also ends fishing mode
        end
        panel:Hide()
    end
end

-- /mentor fish [key <KEY> | reset]
function fishing.HandleCommand(argument)
    local subCommand, value = (argument or ""):match("^%s*(%S*)%s*(.-)%s*$")
    subCommand = (subCommand or ""):lower()
    if subCommand == "" then
        fishing.SetFishingMode(not isFishingModeOn)
    elseif subCommand == "key" then
        if value == "" then
            Mentor.Print("Usage: /mentor fish key <KEY>, for example /mentor fish key F or /mentor fish key BUTTON3")
            return
        end
        if InCombatLockdown() then
            Mentor.Print("The fishing key can't be changed in combat.")
            return
        end
        MentorDB.fishingKey = value:upper()
        ApplyKeyBinding()
        UpdateDisplay()
        Mentor.Print("Fishing key: " .. MentorDB.fishingKey)
    elseif subCommand == "reset" then
        sessionCatchCount, lastCatchText = 0, "--"
        UpdateDisplay()
        Mentor.Print("Catch counter reset.")
    else
        Mentor.Print("Usage: /mentor fish | fish key <KEY> | fish reset")
    end
end

--------------------------------------------------------------------------------
-- Catches and events
--------------------------------------------------------------------------------
local function RecordCatchFromLootWindow()
    local caughtItemNames = {}
    for lootSlotIndex = 1, GetNumLootItems() do
        local _, itemName, itemQuantity = GetLootSlotInfo(lootSlotIndex)
        if itemName then
            table.insert(caughtItemNames, (itemQuantity and itemQuantity > 1) and (itemName .. " x" .. itemQuantity) or itemName)
        end
    end
    if #caughtItemNames > 0 then
        sessionCatchCount = sessionCatchCount + 1
        lastCatchText = table.concat(caughtItemNames, ", ")
    end
end

local function IsFishingSpell(spellId)
    return spellId and GetSpellNameById(spellId) == FISHING_SPELL_NAME
end

local eventFrame = CreateFrame("Frame")
for _, eventName in ipairs({ "PLAYER_LOGIN", "LOOT_OPENED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_LOGOUT" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end
if eventFrame.RegisterUnitEvent then
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
end
eventFrame:SetScript("OnEvent", function(_, eventName, ...)
    if eventName == "PLAYER_LOGIN" then
        fishing.UpdateVisibility()
    elseif eventName == "UNIT_SPELLCAST_CHANNEL_START" or eventName == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local _, _, spellId = ...
        if isFishingModeOn and IsFishingSpell(spellId) then
            isBobberOut = eventName == "UNIT_SPELLCAST_CHANNEL_START"
            ApplyKeyBinding()
            UpdateDisplay()
        end
    elseif eventName == "LOOT_OPENED" then
        if isFishingModeOn and IsFishingLoot and IsFishingLoot() then
            RecordCatchFromLootWindow()
            UpdateDisplay()
        end
    elseif eventName == "PLAYER_REGEN_DISABLED" then
        -- Combat: give the key back so it works normally while fighting
        -- (this fires just before the lockdown, so clearing is still allowed).
        if isFishingModeOn then
            ClearOverrideBindings(bindingOwnerFrame)
            isBindingUpdatePending = true
        end
    elseif eventName == "PLAYER_REGEN_ENABLED" then
        if isBindingUpdatePending then
            isBobberOut = false
            ApplyKeyBinding()
            UpdateDisplay()
        end
    elseif eventName == "PLAYER_LOGOUT" then
        if isFishingModeOn then
            RestoreAllCVars()             -- never leave the boosted sound / auto loot behind
        end
    end
end)

local secondsSinceRefresh = 0
eventFrame:SetScript("OnUpdate", function(_, elapsedSeconds)
    secondsSinceRefresh = secondsSinceRefresh + elapsedSeconds
    if secondsSinceRefresh >= REFRESH_INTERVAL_SECONDS then
        secondsSinceRefresh = 0
        if not InCombatLockdown() then
            fishing.UpdateVisibility()
        end
    end
end)

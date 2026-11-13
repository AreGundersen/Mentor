--------------------------------------------------------------------------------
-- Mentor - Procs.lua
-- Shows when something "procs": a buff that makes your next spell free,
-- instant or stronger (Shadow Trance, Clearcasting, Maelstrom Weapon ...), or
-- an attack that only lights up after something happened (Overpower after a
-- dodge, Revenge after a block ...). The game only gives a buff and a small
-- sound, which is easy to miss while leveling.
--
-- Two ways to show it, each with its own switch under Talents & play:
--   Proc icon   a big pulsing icon above your character with what to press
--   Proc glow   a gold, pulsing frame on the action bar button to press
-- The glow is Mentor's own frame laid over the button (Blizzard's action
-- buttons are not touched, so nothing gets blocked in combat).
-- /mentor procs test shows an example.
--------------------------------------------------------------------------------

local _, Mentor = ...

local procs = {}
Mentor.Procs = procs

local MENTOR_GOLD = { 1.00, 0.78, 0.10 }
local ICON_SIZE = 52
local ICON_GAP = 14
local MAX_ICONS = 3
local ICON_AREA_OFFSET_Y = 150              -- above the middle of the screen (your character)
local SECONDS_BETWEEN_REACTIVE_CHECKS = 0.2

-- Buffs that are procs. press = the spell to press now (glows on your bar),
-- text = what the proc does, minStacks = only show from this many stacks.
-- Names that do not exist in WoW Forever simply never show.
local BUFF_PROCS = {
    -- Warlock
    { buff = "Shadow Trance",     press = "Shadow Bolt",     text = "Instant, free Shadow Bolt" },
    { buff = "Backlash",          press = "Shadow Bolt",     text = "Instant Shadow Bolt" },
    { buff = "Molten Core",       press = "Incinerate",      text = "Stronger Incinerate" },
    { buff = "Decimation",        press = "Soul Fire",       text = "Fast Soul Fire" },
    -- Mage
    { buff = "Clearcasting",      press = nil,               text = "Your next spell is free" },
    { buff = "Fingers of Frost",  press = "Ice Lance",       text = "Ice Lance hits as if frozen" },
    { buff = "Missile Barrage",   press = "Arcane Missiles", text = "Fast, free Arcane Missiles" },
    { buff = "Hot Streak",        press = "Pyroblast",       text = "Instant Pyroblast" },
    { buff = "Brain Freeze",      press = "Fireball",        text = "Instant, free Fireball" },
    -- Shaman
    { buff = "Maelstrom Weapon",  press = "Lightning Bolt",  text = "Instant Lightning Bolt", minStacks = 5 },
    { buff = "Lava Surge",        press = "Lava Burst",      text = "Instant Lava Burst" },
    -- Priest
    { buff = "Surge of Light",    press = "Smite",           text = "Instant, free Smite" },
    -- Paladin
    { buff = "The Art of War",    press = "Exorcism",        text = "Instant Exorcism" },
    { buff = "Art of War",        press = "Exorcism",        text = "Instant Exorcism" },
    { buff = "Infusion of Light", press = "Flash of Light",  text = "Faster heal" },
    -- Warrior
    { buff = "Sudden Death",      press = "Execute",         text = "Execute at any health" },
    { buff = "Bloodsurge",        press = "Slam",            text = "Instant Slam" },
    -- Druid
    { buff = "Eclipse (Solar)",   press = "Wrath",           text = "Stronger Wrath" },
    { buff = "Eclipse (Lunar)",   press = "Starfire",        text = "Stronger Starfire" },
    { buff = "Predator's Swiftness", press = "Healing Touch", text = "Instant Healing Touch" },
    -- Hunter
    { buff = "Lock and Load",     press = "Arcane Shot",     text = "Free shots" },
}

-- Attacks that only become usable after something happens (no buff).
-- Shown while you are in combat and the attack is ready.
local REACTIVE_PROCS = {
    { spell = "Overpower",     text = "The target dodged - Overpower" },
    { spell = "Revenge",       text = "You blocked or dodged - Revenge" },
    { spell = "Riposte",       text = "You parried - Riposte" },
    { spell = "Counterattack", text = "You parried - Counterattack" },
    { spell = "Mongoose Bite", text = "Mongoose Bite is ready" },
}

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function IsIconOn()
    return MentorDB and MentorDB.areProcIconsEnabled ~= false
end

local function IsGlowOn()
    return MentorDB and MentorDB.areProcGlowsEnabled ~= false
end

--------------------------------------------------------------------------------
-- Spells: names, icons, usable
--------------------------------------------------------------------------------
local function GetSpellIconByName(spellName)
    if not spellName then
        return nil
    end
    if C_Spell and C_Spell.GetSpellTexture then
        local success, spellIcon = pcall(C_Spell.GetSpellTexture, spellName)
        if success and spellIcon then
            return spellIcon
        end
    end
    if GetSpellTexture then
        local success, spellIcon = pcall(GetSpellTexture, spellName)
        if success then
            return spellIcon
        end
    end
    return nil
end

local function GetSpellNameById(spellId)
    if not spellId or IsSecret(spellId) then
        return nil
    end
    if C_Spell and C_Spell.GetSpellName then
        local success, spellName = pcall(C_Spell.GetSpellName, spellId)
        if success and spellName and not IsSecret(spellName) then
            return spellName
        end
    end
    if GetSpellInfo then
        local success, spellName = pcall(GetSpellInfo, spellId)
        if success and spellName and not IsSecret(spellName) then
            return spellName
        end
    end
    return nil
end

-- True when you know the spell, can use it now, and it is not on cooldown
-- (the global cooldown does not count).
local function IsSpellReadyNow(spellName)
    local isUsable
    if C_Spell and C_Spell.IsSpellUsable then
        local success, usable = pcall(C_Spell.IsSpellUsable, spellName)
        isUsable = success and usable
    elseif IsUsableSpell then
        local success, usable = pcall(IsUsableSpell, spellName)
        isUsable = success and usable
    end
    if not isUsable or IsSecret(isUsable) then
        return false
    end
    if C_Spell and C_Spell.GetSpellCooldown then
        local success, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellName)
        if success and type(cooldownInfo) == "table" and not IsSecret(cooldownInfo.duration)
            and (cooldownInfo.duration or 0) > 1.5 then
            return false
        end
    end
    return true
end

--------------------------------------------------------------------------------
-- What is procced right now
--------------------------------------------------------------------------------
-- Calls handleAura(name, icon, stacks, duration, expirationTime) for every buff on you.
local function ForEachPlayerBuff(handleAura)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for auraIndex = 1, 40 do
            local success, auraData = pcall(C_UnitAuras.GetAuraDataByIndex, "player", auraIndex, "HELPFUL")
            if not success or not auraData then
                break
            end
            if not IsSecret(auraData.name) then
                handleAura(auraData.name, auraData.icon, auraData.applications, auraData.duration, auraData.expirationTime)
            end
        end
    elseif UnitBuff then
        for auraIndex = 1, 40 do
            local auraName, auraIcon, auraStacks, _, auraDuration, auraExpiration = UnitBuff("player", auraIndex)
            if not auraName then
                break
            end
            if not IsSecret(auraName) then
                handleAura(auraName, auraIcon, auraStacks, auraDuration, auraExpiration)
            end
        end
    end
end

-- Returns a list of active procs: { key, name, icon, text, press, stacks, duration, expirationTime }.
function procs.GetActiveProcs()
    local activeProcs = {}
    local procByBuffName = {}
    for _, procDefinition in ipairs(BUFF_PROCS) do
        procByBuffName[procDefinition.buff] = procDefinition
    end
    ForEachPlayerBuff(function(auraName, auraIcon, auraStacks, auraDuration, auraExpiration)
        local procDefinition = procByBuffName[auraName]
        if procDefinition then
            local stackCount = (not IsSecret(auraStacks) and auraStacks) or 0
            if stackCount >= (procDefinition.minStacks or 0) then
                table.insert(activeProcs, {
                    key = "buff:" .. auraName, name = auraName, icon = auraIcon, text = procDefinition.text,
                    press = procDefinition.press, stacks = stackCount,
                    duration = not IsSecret(auraDuration) and auraDuration or nil,
                    expirationTime = not IsSecret(auraExpiration) and auraExpiration or nil,
                })
            end
        end
    end)
    local isInCombat = UnitAffectingCombat and UnitAffectingCombat("player")
    if isInCombat then
        for _, reactiveDefinition in ipairs(REACTIVE_PROCS) do
            if IsSpellReadyNow(reactiveDefinition.spell) then
                table.insert(activeProcs, {
                    key = "spell:" .. reactiveDefinition.spell, name = reactiveDefinition.spell,
                    icon = GetSpellIconByName(reactiveDefinition.spell), text = reactiveDefinition.text,
                    press = reactiveDefinition.spell, stacks = 0,
                })
            end
        end
    end
    return activeProcs
end

--------------------------------------------------------------------------------
-- Big icons above your character
--------------------------------------------------------------------------------
local iconArea = CreateFrame("Frame", "MentorProcIconArea", UIParent)
iconArea:SetSize(MAX_ICONS * (ICON_SIZE + ICON_GAP), ICON_SIZE + 40)
iconArea:SetPoint("CENTER", UIParent, "CENTER", 0, ICON_AREA_OFFSET_Y)
iconArea:SetFrameStrata("HIGH")
iconArea:EnableMouse(false)                 -- never blocks clicks in the middle of the screen
local procIcons = {}

local function CreateProcIcon()
    local procIcon = CreateFrame("Frame", nil, iconArea)
    procIcon:SetSize(ICON_SIZE, ICON_SIZE)
    procIcon:EnableMouse(false)
    procIcon.texture = procIcon:CreateTexture(nil, "ARTWORK")
    procIcon.texture:SetAllPoints()
    procIcon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- Time left as the usual clock sweep.
    procIcon.cooldown = CreateFrame("Cooldown", nil, procIcon, "CooldownFrameTemplate")
    procIcon.cooldown:SetAllPoints()
    if procIcon.cooldown.SetReverse then
        procIcon.cooldown:SetReverse(true)
    end
    if procIcon.cooldown.SetHideCountdownNumbers then
        procIcon.cooldown:SetHideCountdownNumbers(true)
    end
    -- Gold edge with a slow pulse (the same pulse as the quest and loot picks).
    local edgeFrame = Mentor.AddRoundedBorder(procIcon, MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 1, 14)
    local shine = edgeFrame:CreateTexture(nil, "OVERLAY")
    shine:SetColorTexture(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.35)
    shine:SetBlendMode("ADD")
    shine:SetPoint("TOPLEFT", procIcon, "TOPLEFT", 0, 0)
    shine:SetPoint("BOTTOMRIGHT", procIcon, "BOTTOMRIGHT", 0, 0)
    Mentor.StartPulse(edgeFrame, shine)
    procIcon.stacksText = edgeFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    procIcon.stacksText:SetPoint("BOTTOMRIGHT", procIcon, "BOTTOMRIGHT", -2, 2)
    procIcon.nameText = procIcon:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    procIcon.nameText:SetPoint("TOP", procIcon, "BOTTOM", 0, -6)
    procIcon.detailText = procIcon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    procIcon.detailText:SetPoint("TOP", procIcon.nameText, "BOTTOM", 0, -2)
    return procIcon
end

local function ShowIcons(activeProcs)
    local shownCount = (IsIconOn() and math.min(#activeProcs, MAX_ICONS)) or 0
    local rowWidth = shownCount * ICON_SIZE + math.max(shownCount - 1, 0) * ICON_GAP
    for iconIndex = 1, math.max(shownCount, #procIcons) do
        local procIcon = procIcons[iconIndex]
        local procData = activeProcs[iconIndex]
        if iconIndex <= shownCount then
            procIcon = procIcon or CreateProcIcon()
            procIcons[iconIndex] = procIcon
            procIcon:ClearAllPoints()
            procIcon:SetPoint("TOPLEFT", iconArea, "TOP", -rowWidth / 2 + (iconIndex - 1) * (ICON_SIZE + ICON_GAP), 0)
            procIcon.texture:SetTexture(procData.icon or GetSpellIconByName(procData.press) or 134400)
            procIcon.stacksText:SetText((procData.stacks or 0) > 1 and procData.stacks or "")
            procIcon.nameText:SetText(procData.name)
            local pressText = procData.press and procData.press ~= procData.name and ("Press " .. procData.press) or nil
            procIcon.detailText:SetText(pressText and (procData.text .. "\n|cff40ff40" .. pressText .. "|r") or procData.text)
            if procData.duration and procData.expirationTime and procData.duration > 0 then
                procIcon.cooldown:SetCooldown(procData.expirationTime - procData.duration, procData.duration)
                procIcon.cooldown:Show()
            else
                procIcon.cooldown:Hide()
            end
            procIcon:Show()
        elseif procIcon then
            procIcon:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- Glow on the action bar button to press
--------------------------------------------------------------------------------
local ACTION_BAR_BUTTON_PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}
local glowsByButton = {}

-- The spell name an action bar button casts (spells and macros), or nil.
local function GetButtonSpellName(actionButton)
    local actionSlot = actionButton.action
    if (not actionSlot or actionSlot == 0) and actionButton.GetPagedID then
        local success, pagedSlot = pcall(actionButton.GetPagedID, actionButton)
        actionSlot = success and pagedSlot or nil
    end
    if not actionSlot or IsSecret(actionSlot) or not GetActionInfo then
        return nil
    end
    local success, actionType, actionId = pcall(GetActionInfo, actionSlot)
    if not success or IsSecret(actionType) then
        return nil
    end
    if actionType == "spell" then
        return GetSpellNameById(actionId)
    elseif actionType == "macro" and GetMacroSpell then
        local macroSuccess, macroSpellId = pcall(GetMacroSpell, actionId)
        return macroSuccess and GetSpellNameById(macroSpellId) or nil
    end
    return nil
end

local function GetOrCreateGlow(actionButton)
    local glowFrame = glowsByButton[actionButton]
    if glowFrame then
        return glowFrame
    end
    -- Parented to UIParent and only anchored to the button: Mentor never
    -- changes Blizzard's protected buttons.
    glowFrame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    glowFrame:SetPoint("TOPLEFT", actionButton, "TOPLEFT", -3, 3)
    glowFrame:SetPoint("BOTTOMRIGHT", actionButton, "BOTTOMRIGHT", 3, -3)
    glowFrame:SetFrameStrata(actionButton:GetFrameStrata() or "MEDIUM")
    glowFrame:SetFrameLevel((actionButton:GetFrameLevel() or 1) + 5)
    glowFrame:EnableMouse(false)
    if glowFrame.SetBackdrop then
        glowFrame:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
        glowFrame:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 1)
    end
    local shine = glowFrame:CreateTexture(nil, "OVERLAY")
    shine:SetColorTexture(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.45)
    shine:SetBlendMode("ADD")
    shine:SetPoint("TOPLEFT", 3, -3)
    shine:SetPoint("BOTTOMRIGHT", -3, 3)
    Mentor.StartPulse(glowFrame, shine)
    glowsByButton[actionButton] = glowFrame
    return glowFrame
end

local function ShowGlows(activeProcs)
    local spellsToPress = {}
    if IsGlowOn() then
        for _, procData in ipairs(activeProcs) do
            if procData.press then
                spellsToPress[procData.press] = true
            end
        end
    end
    for _, buttonPrefix in ipairs(ACTION_BAR_BUTTON_PREFIXES) do
        for buttonNumber = 1, 12 do
            local actionButton = _G[buttonPrefix .. buttonNumber]
            if actionButton then
                local buttonSpellName = next(spellsToPress) and actionButton:IsVisible() and GetButtonSpellName(actionButton)
                local shouldGlow = buttonSpellName and spellsToPress[buttonSpellName]
                if shouldGlow then
                    GetOrCreateGlow(actionButton):Show()
                elseif glowsByButton[actionButton] then
                    glowsByButton[actionButton]:Hide()
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Updating
--------------------------------------------------------------------------------
local testProcs = nil                       -- set by /mentor procs test

function procs.Update()
    local activeProcs = testProcs or procs.GetActiveProcs()
    ShowIcons(activeProcs)
    ShowGlows(activeProcs)
end

-- /mentor procs test: an example proc for 6 seconds.
function procs.ShowTest()
    testProcs = { {
        key = "test", name = "Shadow Trance", icon = GetSpellIconByName("Shadow Bolt") or 136197,
        text = "Instant, free Shadow Bolt", press = "Shadow Bolt", stacks = 0,
    } }
    procs.Update()
    C_Timer.After(6, function()
        testProcs = nil
        procs.Update()
    end)
end

local eventFrame = CreateFrame("Frame")
for _, eventName in ipairs({ "PLAYER_ENTERING_WORLD", "UNIT_AURA", "SPELL_UPDATE_USABLE",
    "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_TARGET_CHANGED", "SPELL_UPDATE_COOLDOWN" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end
-- Many events come in bursts: update at most every SECONDS_BETWEEN_REACTIVE_CHECKS.
local isUpdateQueued = false
eventFrame:SetScript("OnEvent", function(_, eventName, unitToken)
    if eventName == "UNIT_AURA" and unitToken ~= "player" then
        return
    end
    if isUpdateQueued or not C_Timer then
        return
    end
    isUpdateQueued = true
    C_Timer.After(SECONDS_BETWEEN_REACTIVE_CHECKS / 2, function()
        isUpdateQueued = false
        pcall(procs.Update)
    end)
end)

-- /mentor procs [test|icon on|off|glow on|off]
function procs.HandleCommand(argument)
    local words = {}
    for word in (argument or ""):lower():gmatch("%S+") do
        table.insert(words, word)
    end
    if words[1] == "test" or words[1] == nil then
        procs.ShowTest()
        Mentor.Print("Proc test: an example proc for 6 seconds. Turn the icon or the glow on and off under Settings > Talents & play.")
    elseif (words[1] == "icon" or words[1] == "glow") and (words[2] == "on" or words[2] == "off") then
        local settingKey = words[1] == "icon" and "areProcIconsEnabled" or "areProcGlowsEnabled"
        MentorDB[settingKey] = words[2] == "on"
        if Mentor.SaveAccountSettings then
            pcall(Mentor.SaveAccountSettings)
        end
        procs.Update()
        Mentor.Print("Proc " .. words[1] .. " " .. words[2] .. ".")
    else
        Mentor.Print("/mentor procs test | icon on|off | glow on|off")
    end
end

-- For the test harness: is Mentor's glow shown on this button?
function procs.IsButtonGlowingForTests(actionButton)
    return glowsByButton[actionButton] ~= nil and glowsByButton[actionButton]:IsShown()
end

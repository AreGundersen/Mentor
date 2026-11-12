--------------------------------------------------------------------------------
-- Mentor - Reminders.lua
-- Short reminders about things new players forget (Settings > Reminders,
-- all on by default): "Trainer", "Supplies & repair", "Bags & professions",
-- "Help tips" (what to do when you die, log out in an inn for rested XP) and
-- "Mob warnings" (elites and mobs far above your level, in the mob tooltip).
--   * Trainer     you levelled up and your class trainer has new spells
--   * Supplies    low on ammo, soul shards or reagents for spells you know,
--                 and an unhappy pet - checked when you leave a town/inn
--   * Repair      your gear is almost broken
--   * Profession  a profession is stuck at its cap: learn the next rank
--   * Bags        an empty bag slot, or small bags you could replace
-- Reminders show in a small box (with an X to dismiss each): under the
-- Mentor window while it is open, on its own (movable) while it is closed. Every reminder is
-- shown once, and again only when the situation changes.
--------------------------------------------------------------------------------

local _, Mentor = ...

local SECONDS_AFTER_LEVEL_UP = 1.5          -- the spellbook needs a moment after a level-up
local REPAIR_WARNING_PERCENT = 20           -- warn when any item is at or below this durability
local REPAIR_REARM_PERCENT = 50             -- warn again only after a repair above this
local FIRST_EQUIPMENT_SLOT, LAST_EQUIPMENT_SLOT = 1, 18
local LOW_AMMO_COUNT = 200
local FIRST_BAG_SLOT, LAST_BAG_SLOT = 1, NUM_BAG_SLOTS or 4
local SMALL_BAG_SLOTS = 8                   -- bags smaller than this are worth replacing ...
local SMALL_BAG_REMINDER_LEVEL = 15         -- ... from this level ...
local SMALL_BAG_REMINDER_MONEY = 20000      -- ... when you have 2 gold
local PET_UNHAPPY = 1                       -- GetPetHappiness: 1 unhappy, 2 content, 3 happy

local MESSAGE_COLOR = "|cffffd100"

-- Reagents for spells you know: { class, spell that needs it, item id, item name, warn below }.
local REAGENT_CHECKS = {
    { "WARLOCK", "Summon Voidwalker", 6265, "Soul Shards", 3 },
    { "SHAMAN", "Reincarnation", 17030, "Ankh", 1 },
    { "ROGUE", "Vanish", 5140, "Flash Powder", 2 },
    { "MAGE", "Teleport: Stormwind", 17031, "Rune of Teleportation", 1 },
    { "MAGE", "Teleport: Ironforge", 17031, "Rune of Teleportation", 1 },
    { "MAGE", "Teleport: Darnassus", 17031, "Rune of Teleportation", 1 },
    { "MAGE", "Teleport: Orgrimmar", 17031, "Rune of Teleportation", 1 },
    { "MAGE", "Teleport: Undercity", 17031, "Rune of Teleportation", 1 },
    { "MAGE", "Teleport: Thunder Bluff", 17031, "Rune of Teleportation", 1 },
}

local reminders = {}
Mentor.Reminders = reminders

local saidReminders = {}            -- reminder key -> true once said this session
local isRepairWarningArmed = true

local function IsOn(settingName)
    return MentorDB and MentorDB[settingName] ~= false
end

-- Says a reminder once per key (and again after ForgetReminder).
--------------------------------------------------------------------------------
-- The reminder box: a small Mentor-style box under the Mentor window with
-- the current reminders, newest first, each with an X to dismiss it.
-- While the Mentor window is closed the box stands on its own and can be moved.
--------------------------------------------------------------------------------
local MAX_REMINDERS_SHOWN = 4
local BOX_PADDING = 8
local ROW_GAP = 4
local GOLD = { 1.00, 0.78, 0.10 }
local activeReminders = {}        -- { key, text }, newest first
local reminderBox

local function BuildReminderBox()
    local mentorWindow = _G["MentorFrame"]
    if not mentorWindow then
        return nil
    end
    reminderBox = CreateFrame("Frame", "MentorReminderBox", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    reminderBox:SetFrameStrata("MEDIUM")
    reminderBox:SetClampedToScreen(true)
    -- Draggable while it stands on its own (the Mentor window is closed).
    reminderBox:SetMovable(true)
    reminderBox:EnableMouse(true)
    reminderBox:RegisterForDrag("LeftButton")
    reminderBox:SetScript("OnDragStart", function(self)
        if not self.isUnderWindow and not (MentorDB and MentorDB.isLocked) then
            self:StartMoving()
        end
    end)
    reminderBox:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not self.isUnderWindow then
            local point, _, relativePoint, offsetX, offsetY = self:GetPoint()
            MentorDB.reminderBoxPosition = { point = point, relativePoint = relativePoint, offsetX = offsetX, offsetY = offsetY }
        end
    end)
    -- Follow the Mentor window opening and closing.
    mentorWindow:HookScript("OnShow", function() reminders.Refresh() end)
    mentorWindow:HookScript("OnHide", function() reminders.Refresh() end)
    if reminderBox.SetBackdrop then
        reminderBox:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        reminderBox:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    end
    reminderBox.title = reminderBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reminderBox.title:SetPoint("TOPLEFT", BOX_PADDING + 2, -BOX_PADDING)
    reminderBox.title:SetText("Reminders")
    reminderBox.rows = {}
    for rowIndex = 1, MAX_REMINDERS_SHOWN do
        local row = CreateFrame("Frame", nil, reminderBox)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("TOPLEFT", 0, 0)
        row.text:SetJustifyH("LEFT")
        row.closeButton = CreateFrame("Button", nil, row, "UIPanelCloseButton")
        row.closeButton:SetSize(18, 18)
        row.closeButton:SetPoint("TOPRIGHT", 4, 4)
        row.closeButton:SetScript("OnClick", function()
            reminders.Dismiss(row.reminderKey)
        end)
        reminderBox.rows[rowIndex] = row
    end
    reminderBox:Hide()
    return reminderBox
end

-- Under the Mentor window while it is open; on its own (where you dragged
-- it, the top of the screen at first) while it is closed.
local STANDALONE_WIDTH = 320
local DEFAULT_STANDALONE_POSITION = { point = "TOP", relativePoint = "TOP", offsetX = 0, offsetY = -140 }
function reminders.PlaceBox()
    if not reminderBox then
        return
    end
    local mentorWindow = _G["MentorFrame"]
    reminderBox:ClearAllPoints()
    if mentorWindow and mentorWindow:IsShown() then
        reminderBox.isUnderWindow = true
        reminderBox:SetPoint("TOPLEFT", mentorWindow, "BOTTOMLEFT", 0, -2)
        reminderBox:SetPoint("TOPRIGHT", mentorWindow, "BOTTOMRIGHT", 0, -2)
    else
        reminderBox.isUnderWindow = false
        local position = (MentorDB and type(MentorDB.reminderBoxPosition) == "table") and MentorDB.reminderBoxPosition
            or DEFAULT_STANDALONE_POSITION
        reminderBox:SetWidth(STANDALONE_WIDTH)
        reminderBox:SetPoint(position.point, UIParent, position.relativePoint, position.offsetX, position.offsetY)
    end
end

local function UpdateReminderBox()
    if not reminderBox then
        if not BuildReminderBox() then
            return
        end
        reminders.PlaceBox()
    end
    local boxWidth = reminderBox:GetWidth() or 300
    local verticalOffset = BOX_PADDING + 18
    for rowIndex, row in ipairs(reminderBox.rows) do
        local reminder = activeReminders[rowIndex]
        if reminder then
            row.reminderKey = reminder.key
            row.text:SetWidth(boxWidth - BOX_PADDING * 2 - 22)
            row.text:SetText("|cffffd100-|r " .. reminder.text)
            local rowHeight = math.max(row.text:GetStringHeight() or 14, 14)
            row:SetSize(boxWidth - BOX_PADDING * 2, rowHeight)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", BOX_PADDING + 2, -verticalOffset)
            row:Show()
            verticalOffset = verticalOffset + rowHeight + ROW_GAP
        else
            row:Hide()
        end
    end
    reminderBox:SetHeight(verticalOffset + BOX_PADDING - ROW_GAP)
    reminderBox:SetShown(#activeReminders > 0)
end

-- Place the box again and lay out its rows (the width changes with the place).
function reminders.Refresh()
    reminders.PlaceBox()
    UpdateReminderBox()
end

function reminders.ResetPosition()
    if MentorDB then
        MentorDB.reminderBoxPosition = nil
    end
    reminders.PlaceBox()
end

function reminders.Dismiss(reminderKey)
    for reminderIndex = #activeReminders, 1, -1 do
        if activeReminders[reminderIndex].key == reminderKey then
            table.remove(activeReminders, reminderIndex)
        end
    end
    UpdateReminderBox()
end

function reminders.GetActive()
    return activeReminders
end

-- Shows a reminder once per key (and again after ForgetReminder).
local function Remind(reminderKey, text)
    if saidReminders[reminderKey] then
        return
    end
    saidReminders[reminderKey] = true
    if not _G["MentorFrame"] then
        Mentor.Print(MESSAGE_COLOR .. text .. "|r")
        return
    end
    reminders.Dismiss(reminderKey)
    table.insert(activeReminders, 1, { key = reminderKey, text = text })
    while #activeReminders > MAX_REMINDERS_SHOWN do
        table.remove(activeReminders)
    end
    UpdateReminderBox()
end

-- The situation changed (bought ammo, repaired ...): the reminder goes away.
local function ForgetReminder(reminderKey)
    saidReminders[reminderKey] = nil
    reminders.Dismiss(reminderKey)
end

local function GetItemCountCompat(itemId)
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemId) or 0
    end
    return GetItemCount and GetItemCount(itemId) or 0
end

local function IsSpellKnownByName(spellName)
    if not Mentor.ResolveSpell then
        return false
    end
    local success, resolvedSpell = pcall(Mentor.ResolveSpell, spellName)
    return success and resolvedSpell and resolvedSpell.isKnown == true
end

--------------------------------------------------------------------------------
-- Trainer: new spells after a level-up
--------------------------------------------------------------------------------
-- Names the spells that are new at this level; older spells you have not
-- trained yet are only counted (the Spells panel lists them).
function reminders.CheckTrainer(newLevel)
    if not IsOn("isTrainerReminderEnabled") then
        return
    end
    local _, classFileName = UnitClass("player")
    local newSpellNames, olderUntrainedCount = {}, 0
    for _, trainerEntry in ipairs(Mentor.TRAINER_SPELLS and Mentor.TRAINER_SPELLS[classFileName] or {}) do
        local spellLevel, spellName = trainerEntry[1], trainerEntry[2]
        if spellLevel <= newLevel and not IsSpellKnownByName(spellName) then
            if spellLevel == newLevel then
                table.insert(newSpellNames, spellName)
            else
                olderUntrainedCount = olderUntrainedCount + 1
            end
        end
    end
    local olderText = olderUntrainedCount > 0
        and string.format(" (+%d older spell%s you have not trained yet - see Spells & racials.)",
            olderUntrainedCount, olderUntrainedCount == 1 and "" or "s") or ""
    if #newSpellNames > 0 then
        Remind("trainer" .. newLevel, string.format("Level %d! New at your class trainer: %s.%s",
            newLevel, table.concat(newSpellNames, ", "), olderText))
    elseif olderUntrainedCount > 0 then
        Remind("trainer" .. newLevel, string.format("Level %d! Visit your class trainer:%s", newLevel, olderText))
    end
end

--------------------------------------------------------------------------------
-- Supplies: ammo, reagents, pet
--------------------------------------------------------------------------------
function reminders.CheckSupplies()
    if not IsOn("areSupplyRemindersEnabled") then
        return
    end
    local _, classFileName = UnitClass("player")

    -- Hunters: ammo in the ammo slot.
    if classFileName == "HUNTER" and GetInventorySlotInfo then
        local slotFound, ammoSlot = pcall(GetInventorySlotInfo, "AmmoSlot")
        if slotFound and ammoSlot then
            local ammoCount = GetInventoryItemCount("player", ammoSlot) or 0
            if ammoCount < LOW_AMMO_COUNT then
                Remind("ammo", string.format("Only %d arrows / bullets left - buy more before you leave town.", ammoCount))
            else
                ForgetReminder("ammo")
            end
        end
    end

    -- Hunters and warlocks: a pet that is unhappy fights badly.
    if GetPetHappiness and UnitExists and UnitExists("pet") then
        local petHappiness = GetPetHappiness()
        if petHappiness == PET_UNHAPPY then
            Remind("pet", "Your pet is unhappy and does less damage - feed it (Feed Pet).")
        else
            ForgetReminder("pet")
        end
    end

    -- Reagents for spells you already know.
    local remindedItems = {}
    for _, reagentCheck in ipairs(REAGENT_CHECKS) do
        local checkClass, spellName, itemId, itemName, warnBelow = unpack(reagentCheck)
        if checkClass == classFileName and not remindedItems[itemId] and IsSpellKnownByName(spellName) then
            remindedItems[itemId] = true
            local itemCount = GetItemCountCompat(itemId)
            if itemCount < warnBelow then
                Remind("reagent" .. itemId, string.format("You have %d %s - %s needs it.", itemCount, itemName, spellName))
            else
                ForgetReminder("reagent" .. itemId)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Repair
--------------------------------------------------------------------------------
function reminders.CheckRepair()
    if not IsOn("areSupplyRemindersEnabled") then
        return
    end
    local lowestPercent
    for inventorySlot = FIRST_EQUIPMENT_SLOT, LAST_EQUIPMENT_SLOT do
        local currentDurability, maxDurability = GetInventoryItemDurability(inventorySlot)
        if currentDurability and maxDurability and maxDurability > 0 then
            local slotPercent = currentDurability / maxDurability * 100
            lowestPercent = math.min(lowestPercent or slotPercent, slotPercent)
        end
    end
    if not lowestPercent then
        return
    end
    if lowestPercent <= REPAIR_WARNING_PERCENT and isRepairWarningArmed then
        isRepairWarningArmed = false
        if lowestPercent <= 0 then
            Remind("repair", "Some of your gear is broken and gives no stats - repair it at a vendor with an anvil icon.")
        else
            Remind("repair", string.format("Your gear is at %d%% durability - repair soon at a vendor with an anvil icon.", math.floor(lowestPercent)))
        end
    elseif lowestPercent >= REPAIR_REARM_PERCENT then
        isRepairWarningArmed = true
        ForgetReminder("repair")
    end
end

--------------------------------------------------------------------------------
-- Professions stuck at their cap
--------------------------------------------------------------------------------
function reminders.CheckProfessions()
    if not (IsOn("areBagRemindersEnabled") and Mentor.Journey) then
        return
    end
    local playerLevel = UnitLevel("player") or 1
    for _, profession in ipairs(Mentor.Journey.GetPlayerProfessions()) do
        local trainerHint = Mentor.Journey.GetProfessionTrainerHint(profession, playerLevel)
        local reminderKey = "profession" .. profession.name .. profession.maximum
        if trainerHint and profession.skill >= profession.maximum then
            Remind(reminderKey, trainerHint)
        end
    end
end

--------------------------------------------------------------------------------
-- Bags: empty bag slots and small bags
--------------------------------------------------------------------------------
local function GetBagSlotCountCompat(bagIndex)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagIndex) or 0
    end
    return GetContainerNumSlots and GetContainerNumSlots(bagIndex) or 0
end

function reminders.CheckBags()
    if not IsOn("areBagRemindersEnabled") then
        return
    end
    local emptyBagSlots, smallestBagSlots = 0, nil
    for bagIndex = FIRST_BAG_SLOT, LAST_BAG_SLOT do
        local slotCount = GetBagSlotCountCompat(bagIndex)
        if slotCount == 0 then
            emptyBagSlots = emptyBagSlots + 1
        else
            smallestBagSlots = math.min(smallestBagSlots or slotCount, slotCount)
        end
    end
    if emptyBagSlots > 0 then
        Remind("bagsEmpty" .. emptyBagSlots, string.format(
            "You have %d empty bag slot%s - buy a bag at a General Goods vendor, the auction house or a tailor for more space.",
            emptyBagSlots, emptyBagSlots == 1 and "" or "s"))
        return
    end
    ForgetReminder("bagsEmpty1"); ForgetReminder("bagsEmpty2"); ForgetReminder("bagsEmpty3"); ForgetReminder("bagsEmpty4")
    local playerLevel = UnitLevel("player") or 1
    if smallestBagSlots and smallestBagSlots < SMALL_BAG_SLOTS and playerLevel >= SMALL_BAG_REMINDER_LEVEL
        and (GetMoney() or 0) >= SMALL_BAG_REMINDER_MONEY then
        Remind("bagsSmall" .. smallestBagSlots, string.format(
            "Your smallest bag has only %d slots. A bigger bag (10 slots or more) from the auction house or a tailor gives you more room for loot.",
            smallestBagSlots))
    end
end

--------------------------------------------------------------------------------
-- Dying: how to get back without the spirit healer's penalty
--------------------------------------------------------------------------------
function reminders.OnPlayerDied()
    if not IsOn("areHelpTipsEnabled") then
        return
    end
    ForgetReminder("death")
    Remind("death", "You died. Click Release, run back to your corpse as a ghost and click Resurrect there. "
        .. "The spirit healer also revives you, but gives 10 minutes of Resurrection Sickness and damages your gear.")
end

function reminders.OnPlayerAlive()
    if UnitIsDeadOrGhost and not UnitIsDeadOrGhost("player") then
        ForgetReminder("death")
    end
end

-- Logging out away from an inn or a city: no rested XP builds up.
-- The tip gets its own small box right under the logout countdown (the
-- reminder box sits behind that popup, so it would not be seen). Several hooks
-- can start it (PLAYER_CAMPING, Logout(), Quit(), the CAMP / QUIT popup)
-- because not every client fires PLAYER_CAMPING.
local LOGOUT_TIP_TEXT = "Tip: log out in an inn or a city instead - there you build up rested XP, "
    .. "which doubles the XP from kills next time you play."
local LOGOUT_TIP_WIDTH = 320
local logoutTipBox

-- The visible logout countdown popup, or nil.
local function FindLogoutPopup()
    if not StaticPopup_Visible then
        return nil
    end
    for _, popupName in ipairs({ "CAMP", "QUIT" }) do
        local popupFrameName = StaticPopup_Visible(popupName)
        if popupFrameName and _G[popupFrameName] then
            return _G[popupFrameName]
        end
    end
    return nil
end

local function GetLogoutTipBox()
    if logoutTipBox then
        return logoutTipBox
    end
    logoutTipBox = CreateFrame("Frame", "MentorLogoutTipBox", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    -- Same layer as the popup, one step above it, so nothing covers the tip.
    logoutTipBox:SetFrameStrata("DIALOG")
    logoutTipBox:SetFrameLevel(100)
    logoutTipBox:SetWidth(LOGOUT_TIP_WIDTH)
    if logoutTipBox.SetBackdrop then
        logoutTipBox:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        logoutTipBox:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    end
    local logo = logoutTipBox:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\Mentor\\Media\\Logo")
    logo:SetSize(16, 16)
    logo:SetPoint("TOPLEFT", BOX_PADDING + 2, -BOX_PADDING)
    logoutTipBox.text = logoutTipBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    logoutTipBox.text:SetPoint("TOPLEFT", logo, "TOPRIGHT", 6, 0)
    logoutTipBox.text:SetWidth(LOGOUT_TIP_WIDTH - 2 * BOX_PADDING - 26)
    logoutTipBox.text:SetJustifyH("LEFT")
    logoutTipBox.text:SetText(LOGOUT_TIP_TEXT)
    logoutTipBox:SetHeight((logoutTipBox.text:GetStringHeight() or 24) + 2 * BOX_PADDING + 4)
    logoutTipBox:Hide()
    return logoutTipBox
end

function reminders.OnCamping()
    if not IsOn("areHelpTipsEnabled") then
        return
    end
    local playerLevel = UnitLevel("player") or 1
    local maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
    if not (playerLevel < maxLevel and IsResting and not IsResting()) then
        return
    end
    local tipBox = GetLogoutTipBox()
    tipBox:ClearAllPoints()
    local logoutPopup = FindLogoutPopup()
    if logoutPopup then
        tipBox:SetPoint("TOP", logoutPopup, "BOTTOM", 0, -6)
        -- Goes away together with the countdown (logout cancelled or done).
        if not logoutPopup.isMentorTipHooked then
            logoutPopup:HookScript("OnHide", function() if logoutTipBox then logoutTipBox:Hide() end end)
            logoutPopup.isMentorTipHooked = true
        end
    else
        tipBox:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end
    if not tipBox:IsShown() then
        tipBox:Show()
        Mentor.Print(MESSAGE_COLOR .. LOGOUT_TIP_TEXT .. "|r")
    end
end

-- Logout cancelled (you moved or clicked Cancel): hide the tip.
function reminders.OnLogoutCancelled()
    if logoutTipBox then
        logoutTipBox:Hide()
    end
end

if hooksecurefunc then
    for _, logoutFunctionName in ipairs({ "Logout", "Quit" }) do
        if type(_G[logoutFunctionName]) == "function" then
            hooksecurefunc(logoutFunctionName, function() pcall(reminders.OnCamping) end)
        end
    end
    if type(StaticPopup_Show) == "function" then
        hooksecurefunc("StaticPopup_Show", function(popupName)
            if popupName == "CAMP" or popupName == "QUIT" then
                pcall(reminders.OnCamping)
            end
        end)
    end
end

--------------------------------------------------------------------------------
local wasResting = nil

local eventFrame = CreateFrame("Frame")
for _, eventName in ipairs({ "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "PLAYER_UPDATE_RESTING",
    "UPDATE_INVENTORY_DURABILITY", "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "UNIT_HAPPINESS",
    "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_CAMPING", "LOGOUT_CANCEL" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end
eventFrame:SetScript("OnEvent", function(_, eventName, ...)
    if eventName == "PLAYER_LOGIN" then
        wasResting = IsResting and IsResting()
        C_Timer.After(5, function()
            pcall(reminders.CheckRepair)
            pcall(reminders.CheckProfessions)
            pcall(reminders.CheckBags)
        end)
    elseif eventName == "PLAYER_LEVEL_UP" then
        local newLevel = ...
        C_Timer.After(SECONDS_AFTER_LEVEL_UP, function()
            pcall(reminders.CheckTrainer, newLevel)
            pcall(reminders.CheckProfessions)
            pcall(reminders.CheckBags)
        end)
    elseif eventName == "PLAYER_UPDATE_RESTING" then
        -- Leaving a town or inn is the moment to check what you are bringing.
        local isResting = IsResting and IsResting()
        if wasResting and not isResting then
            pcall(reminders.CheckSupplies)
        end
        wasResting = isResting
    elseif eventName == "UPDATE_INVENTORY_DURABILITY" then
        pcall(reminders.CheckRepair)
    elseif eventName == "SKILL_LINES_CHANGED" then
        pcall(reminders.CheckProfessions)
    elseif eventName == "BAG_UPDATE_DELAYED" then
        pcall(reminders.CheckBags)
    elseif eventName == "UNIT_HAPPINESS" then
        pcall(reminders.CheckSupplies)
    elseif eventName == "PLAYER_DEAD" then
        pcall(reminders.OnPlayerDied)
    elseif eventName == "PLAYER_ALIVE" or eventName == "PLAYER_UNGHOST" then
        pcall(reminders.OnPlayerAlive)
    elseif eventName == "PLAYER_CAMPING" then
        pcall(reminders.OnCamping)
    elseif eventName == "LOGOUT_CANCEL" then
        pcall(reminders.OnLogoutCancelled)
    end
end)

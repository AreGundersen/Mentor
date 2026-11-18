--------------------------------------------------------------------------------
-- Mentor - DiagnosticsFeatures.lua
-- What each feature shows right now, for the bug report (see Diagnostics.lua).
-- Loaded after all features. Also remembers the last items and mobs the
-- player hovered, so "this arrow is wrong" explains itself without the
-- player attaching anything.
--------------------------------------------------------------------------------

local _, Mentor = ...

local MAX_RECENT_ITEMS = 4
local MAX_RECENT_MOBS = 4
local MAX_BAG_ITEMS_LISTED = 30

--------------------------------------------------------------------------------
-- Recently hovered items and mobs
--------------------------------------------------------------------------------
local recentItemLinks = {}   -- newest last
local recentMobs = {}        -- "Name (level 12 elite)", newest last

local function IsReadableText(value)
    return type(value) == "string" and not (issecretvalue and issecretvalue(value))
end

local function RememberRecent(list, value, maximumCount)
    for index = #list, 1, -1 do
        if list[index] == value then
            table.remove(list, index)
        end
    end
    table.insert(list, value)
    while #list > maximumCount do
        table.remove(list, 1)
    end
end

local function RememberHoveredItem(tooltip)
    if not (tooltip and tooltip.GetItem) then
        return
    end
    local _, itemLink = tooltip:GetItem()
    if IsReadableText(itemLink) then
        RememberRecent(recentItemLinks, itemLink, MAX_RECENT_ITEMS)
    end
end

local function RememberHoveredUnit(tooltip)
    if not (tooltip and tooltip.GetUnit) then
        return
    end
    local _, unitToken = tooltip:GetUnit()
    if not unitToken or (UnitIsPlayer and UnitIsPlayer(unitToken)) then
        return
    end
    local unitName = UnitName(unitToken)
    if not IsReadableText(unitName) then
        return
    end
    local unitLevel = UnitLevel and UnitLevel(unitToken)
    local classification = UnitClassification and UnitClassification(unitToken)
    RememberRecent(recentMobs, string.format("%s (level %s%s)", unitName,
        (type(unitLevel) == "number" and not (issecretvalue and issecretvalue(unitLevel))) and tostring(unitLevel) or "?",
        (IsReadableText(classification) and classification ~= "normal") and (" " .. classification) or ""), MAX_RECENT_MOBS)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function(tooltip)
        pcall(RememberHoveredItem, tooltip)
    end)
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tooltip)
        pcall(RememberHoveredUnit, tooltip)
    end)
end

Mentor.Diagnostics.GetRecentItemLinks = function() return recentItemLinks end

--------------------------------------------------------------------------------
-- Feature states
--------------------------------------------------------------------------------
local function GetWeights()
    local advice = Mentor.currentAdvice
    return advice and advice.specData and advice.specData.weights
end

-- Runs a /mentor ... debug command and returns what it printed.
local function CapturePrinted(printFunction)
    local printedLines = {}
    local originalPrint = Mentor.Print
    Mentor.Print = function(text) table.insert(printedLines, text) end
    local isSuccess, errorText = pcall(printFunction)
    Mentor.Print = originalPrint
    if not isSuccess then
        table.insert(printedLines, "(failed: " .. tostring(errorText) .. ")")
    end
    return printedLines
end

-- Every item in the bags that Mentor rates, with the verdict its arrow shows.
Mentor.RegisterDiagnostics("Bags (what the arrows say)", function(Add)
    local weights = GetWeights()
    if not (C_Container and C_Container.GetContainerItemLink and Mentor.CompareItem) then
        Add("bag functions not available")
        return
    end
    local listedCount, ratedCount = 0, 0
    for bagIndex = 0, 4 do
        for slotIndex = 1, (C_Container.GetContainerNumSlots(bagIndex) or 0) do
            local itemLink = C_Container.GetContainerItemLink(bagIndex, slotIndex)
            if itemLink then
                local isSuccess, result = pcall(Mentor.CompareItem, itemLink, weights)
                if isSuccess and result and result.kind and result.kind ~= "notGear" then
                    ratedCount = ratedCount + 1
                    if listedCount < MAX_BAG_ITEMS_LISTED then
                        listedCount = listedCount + 1
                        Add(string.format("%s: %s%s%s", itemLink, tostring(result.kind),
                            result.percent and string.format(" %+.0f%%", result.percent) or "",
                            result.replacedSlot and (" (slot " .. tostring(result.replacedSlot) .. ")") or ""))
                    end
                elseif not isSuccess then
                    Add(itemLink .. ": comparing failed - " .. tostring(result))
                end
            end
        end
    end
    Add(string.format("%d gear items rated%s", ratedCount, ratedCount > listedCount and (", first " .. listedCount .. " listed") or ""))
end)

Mentor.RegisterDiagnostics("Worn gear", function(Add)
    local wornItems = {}
    for slotId = 1, 19 do
        local itemLink = GetInventoryItemLink("player", slotId)
        if itemLink then
            table.insert(wornItems, slotId .. "=" .. itemLink)
        end
    end
    Add(#wornItems > 0 and table.concat(wornItems, ", ") or "nothing")
    local weights = GetWeights()
    if weights and Mentor.GetTotalEquippedScore then
        local isSuccess, totalScore = pcall(Mentor.GetTotalEquippedScore, weights)
        Add("Mentor's total gear score: " .. (isSuccess and string.format("%.1f", totalScore or 0) or ("failed - " .. tostring(totalScore))))
    end
end)

Mentor.RegisterDiagnostics("Proc alerts", function(Add)
    if not (Mentor.Procs and Mentor.Procs.PrintDebug) then
        Add("not loaded")
        return
    end
    for _, line in ipairs(CapturePrinted(Mentor.Procs.PrintDebug)) do
        Add(line)
    end
end)

Mentor.RegisterDiagnostics("Class trainer (Spells tab prices)", function(Add)
    if not (Mentor.Training and Mentor.Training.PrintDebug) then
        Add("not loaded")
        return
    end
    for _, line in ipairs(CapturePrinted(Mentor.Training.PrintDebug)) do
        Add(line)
    end
end)

Mentor.RegisterDiagnostics("Where to get upgrades", function(Add)
    if not Mentor.Upgrades then
        Add("not loaded")
        return
    end
    local dungeonResults, isDungeonLoading = Mentor.Upgrades.FindDungeonUpgrades()
    for dungeonIndex = 1, math.min(4, #dungeonResults) do
        local dungeonResult = dungeonResults[dungeonIndex]
        local itemTexts = {}
        for _, upgrade in ipairs(dungeonResult.upgrades or {}) do
            table.insert(itemTexts, upgrade.itemLink .. (upgrade.questName and " (quest)" or ""))
        end
        Add(dungeonResult.name .. ": " .. table.concat(itemTexts, ", "))
    end
    local vendorUpgrades, isVendorLoading = Mentor.Upgrades.FindVendorUpgrades()
    for _, upgrade in ipairs(vendorUpgrades) do
        Add("Vendor: " .. upgrade.itemLink .. " - " .. Mentor.Upgrades.FormatVendor(upgrade.vendors[1])
            .. (upgrade.reputation and (" (needs standing " .. upgrade.reputation.standingNeeded .. ", has "
                .. upgrade.reputation.playerStanding .. ")") or ""))
    end
    Add(string.format("%d dungeons, %d vendor items%s", #dungeonResults, #vendorUpgrades,
        (isDungeonLoading or isVendorLoading) and ", items still loading" or ""))
end)

Mentor.RegisterDiagnostics("Level pace", function(Add)
    local levelPaceFrame = _G.MentorLevelPaceFrame
    if not (levelPaceFrame and levelPaceFrame.values) then
        Add("off")
        return
    end
    local valueTexts = {}
    for key, fontString in pairs(levelPaceFrame.values) do
        table.insert(valueTexts, key .. "=" .. tostring(fontString:GetText()))
    end
    table.sort(valueTexts)
    Add((levelPaceFrame:IsShown() and "shown: " or "hidden: ") .. table.concat(valueTexts, ", "))
end)

Mentor.RegisterDiagnostics("Professions", function(Add)
    if not (Mentor.Journey and Mentor.Journey.GetPlayerProfessions) then
        Add("not loaded")
        return
    end
    local playerProfessions = Mentor.Journey.GetPlayerProfessions()
    if #playerProfessions == 0 then
        Add("none")
    end
    for _, profession in ipairs(playerProfessions) do
        local levelingText = Mentor.Professions and Mentor.Professions.GetJourneyText
            and Mentor.Professions.GetJourneyText(profession.name, profession.skill)
        Add(string.format("%s %d/%d%s", profession.name, profession.skill, profession.maximum,
            levelingText and (" - " .. levelingText:gsub("\n", " / ")) or ""))
    end
end)

Mentor.RegisterDiagnostics("Reminders shown", function(Add)
    local activeReminders = Mentor.Reminders and Mentor.Reminders.GetActive and Mentor.Reminders.GetActive()
    local reminderTexts = {}
    for reminderKey, reminderText in pairs(activeReminders or {}) do
        table.insert(reminderTexts, type(reminderText) == "string" and reminderText or tostring(reminderKey))
    end
    Add(#reminderTexts > 0 and table.concat(reminderTexts, " | ") or "none")
end)

Mentor.RegisterDiagnostics("Recently hovered mobs", function(Add)
    Add(#recentMobs > 0 and table.concat(recentMobs, ", ") or "none")
end)

Mentor.RegisterDiagnostics("Test checklist (test builds)", function(Add)
    local devChecklist = Mentor.DevChecklist
    if not (devChecklist and devChecklist.IsDevBuild()) then
        Add("not a test build")
        return
    end
    local savedChecklist = MentorAccountDB and MentorAccountDB.devChecklist
    local states = savedChecklist and savedChecklist.states or {}
    for _, item in ipairs(devChecklist.CHECKLIST_ITEMS) do
        Add(string.format("[%s] %s", states[item[1]] or " ", item[2]))
    end
end)

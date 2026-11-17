--------------------------------------------------------------------------------
-- Mentor - Training.lua
-- What to train, which rank, and what it costs. When you open your class
-- trainer, Mentor reads its whole list (also the ranks you can't learn yet)
-- with the price that trainer asks you - so your reputation discount there is
-- already included - and remembers it for this character. The "Spells" tab
-- then shows new ranks of spells you know, with rank and price, and new spells
-- get their price too.
--
-- The trainer API (GetNumTrainerServices and friends) is the old class trainer
-- one; every call is guarded in case this client does not have it.
--------------------------------------------------------------------------------

local _, Mentor = ...

local training = {}
Mentor.Training = training

local SERVICE_CATEGORIES_TO_SHOW = { "available", "unavailable", "used" }

local function SafeCall(apiFunction, ...)
    if type(apiFunction) ~= "function" then
        return nil
    end
    local results = { pcall(apiFunction, ...) }
    if not results[1] then
        return nil
    end
    return select(2, unpack(results))
end

-- "Rank 4" -> 4 (nil when the text has no rank number).
local function ReadRankNumber(rankText)
    if type(rankText) ~= "string" then
        return nil
    end
    return tonumber(rankText:match("(%d+)"))
end

--------------------------------------------------------------------------------
-- Reading the trainer
--------------------------------------------------------------------------------
local isReadingTrainer = false   -- changing the filters fires TRAINER_UPDATE again

local function IsClassTrainer()
    -- Profession trainers use the same window; their list is not class spells.
    local isTradeskillTrainer = SafeCall(IsTradeskillTrainer)
    return not isTradeskillTrainer
end

-- Reads every service the trainer offers. The trainer window can hide
-- "unavailable" (too low level) and "used" (known) entries, so the filters
-- are switched on while reading and put back afterwards.
local function ReadTrainerServices()
    if not GetNumTrainerServices or not GetTrainerServiceInfo then
        return nil
    end
    local savedFilters = {}
    if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
        for _, categoryName in ipairs(SERVICE_CATEGORIES_TO_SHOW) do
            savedFilters[categoryName] = SafeCall(GetTrainerServiceTypeFilter, categoryName)
            if not savedFilters[categoryName] then
                SafeCall(SetTrainerServiceTypeFilter, categoryName, 1)
            end
        end
    end

    local services = {}
    local serviceCount = SafeCall(GetNumTrainerServices) or 0
    for serviceIndex = 1, serviceCount do
        local serviceName, rankText, category = SafeCall(GetTrainerServiceInfo, serviceIndex)
        if serviceName and category ~= "header" then
            local requiredLevel = SafeCall(GetTrainerServiceLevelReq, serviceIndex) or 0
            local cost = SafeCall(GetTrainerServiceCost, serviceIndex) or 0
            table.insert(services, {
                name = serviceName,
                rank = ReadRankNumber(rankText),
                level = requiredLevel,
                cost = cost,
                isKnown = category == "used",
            })
        end
    end

    for categoryName, wasShown in pairs(savedFilters) do
        if not wasShown then
            SafeCall(SetTrainerServiceTypeFilter, categoryName, 0)
        end
    end
    return services
end

local function SaveTrainerList()
    if isReadingTrainer or not IsClassTrainer() then
        return
    end
    isReadingTrainer = true
    local services = ReadTrainerServices()
    isReadingTrainer = false
    if not services or #services == 0 then
        return
    end
    MentorDB = MentorDB or {}
    local trainerName = UnitName and UnitName("npc")
    MentorDB.classTrainerList = {
        trainerName = type(trainerName) == "string" and trainerName or nil,
        services = services,
    }
    if Mentor.ExtrasUI and Mentor.ExtrasUI.Refresh then
        pcall(Mentor.ExtrasUI.Refresh, Mentor.currentAdvice)
    end
end

local eventFrame = CreateFrame("Frame")
for _, eventName in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end
eventFrame:SetScript("OnEvent", function()
    pcall(SaveTrainerList)
end)

--------------------------------------------------------------------------------
-- What you know right now (ranks from the spellbook)
--------------------------------------------------------------------------------
-- { ["frostbolt"] = highest known rank (0 when known without a rank) }
local function ReadKnownRanks()
    local knownRanks = {}
    local spellBook = C_SpellBook
    if not (spellBook and spellBook.GetNumSpellBookSkillLines and spellBook.GetSpellBookItemInfo) then
        return knownRanks
    end
    local playerBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local spellItemType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    for skillLineIndex = 1, SafeCall(spellBook.GetNumSpellBookSkillLines) or 0 do
        local lineInfo = SafeCall(spellBook.GetSpellBookSkillLineInfo, skillLineIndex)
        if lineInfo then
            local firstIndex = (lineInfo.itemIndexOffset or 0) + 1
            local lastIndex = (lineInfo.itemIndexOffset or 0) + (lineInfo.numSpellBookItems or 0)
            for itemIndex = firstIndex, lastIndex do
                local itemInfo = SafeCall(spellBook.GetSpellBookItemInfo, itemIndex, playerBank)
                if itemInfo and itemInfo.name and (not spellItemType or itemInfo.itemType == spellItemType) then
                    local rankNumber = ReadRankNumber(itemInfo.subName) or 0
                    local nameKey = itemInfo.name:lower()
                    knownRanks[nameKey] = math.max(knownRanks[nameKey] or 0, rankNumber)
                end
            end
        end
    end
    return knownRanks
end

--------------------------------------------------------------------------------
-- For the Spells tab
--------------------------------------------------------------------------------
function training.HasTrainerList()
    local savedList = MentorDB and MentorDB.classTrainerList
    return savedList ~= nil and savedList.services ~= nil and #savedList.services > 0
end

function training.GetTrainerName()
    return MentorDB and MentorDB.classTrainerList and MentorDB.classTrainerList.trainerName
end

-- The trainer's price and rank for a spell name, for the lowest rank you
-- don't have yet: { rank, cost, level } or nil.
function training.GetNextRankInfo(spellName, knownRanks)
    if not training.HasTrainerList() or type(spellName) ~= "string" then
        return nil
    end
    knownRanks = knownRanks or ReadKnownRanks()
    local knownRank = knownRanks[spellName:lower()]
    local bestService
    for _, service in ipairs(MentorDB.classTrainerList.services) do
        if service.name:lower() == spellName:lower() and not service.isKnown
            and (not knownRank or (service.rank or 1) > knownRank)
            and (not bestService or (service.rank or 1) < (bestService.rank or 1)) then
            bestService = service
        end
    end
    return bestService
end

-- New ranks of spells you already know, from the saved trainer list:
-- { { name, rank, level, cost }, ... } up to maxLevel.
function training.GetRankUps(maxLevel)
    local rankUps = {}
    if not training.HasTrainerList() then
        return rankUps
    end
    local knownRanks = ReadKnownRanks()
    for _, service in ipairs(MentorDB.classTrainerList.services) do
        local knownRank = knownRanks[service.name:lower()]
        local isNewRank = knownRank and service.rank and service.rank > knownRank
        if isNewRank and not service.isKnown and service.level <= maxLevel then
            table.insert(rankUps, service)
        end
    end
    return rankUps
end

training.ReadKnownRanks = ReadKnownRanks

-- /mentor trainer: what Mentor read at the last class trainer.
function training.PrintDebug()
    local print = Mentor.Print or print
    local hasApi = GetNumTrainerServices ~= nil and GetTrainerServiceInfo ~= nil
    print("Trainer API in this client: " .. (hasApi and "yes" or "no")
        .. ", cost API: " .. (GetTrainerServiceCost and "yes" or "no")
        .. ", level API: " .. (GetTrainerServiceLevelReq and "yes" or "no"))
    if not training.HasTrainerList() then
        print("No trainer list saved yet - open your class trainer once.")
        return
    end
    local savedList = MentorDB.classTrainerList
    print(string.format("Saved from %s: %d entries.", savedList.trainerName or "your trainer", #savedList.services))
    for serviceIndex = 1, math.min(5, #savedList.services) do
        local service = savedList.services[serviceIndex]
        print(string.format("  %s rank %s, level %d, %s%s", service.name, tostring(service.rank), service.level,
            Mentor.FormatMoneyWithIcons and Mentor.FormatMoneyWithIcons(service.cost) or tostring(service.cost),
            service.isKnown and " (known)" or ""))
    end
end

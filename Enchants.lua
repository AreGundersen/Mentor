--------------------------------------------------------------------------------
-- Mentor - Enchants.lua
-- For enchanters: the best enchant for an item, in the item's tooltip.
--
--   Best enchant for Restoration:
--     Greater Intellect - you can make it
--     Better: Greater Spellpower - Formula: Enchant Bracer - Greater Spellpower
--
-- The enchants come from EnchantRecipes.lua (every released WoW Forever
-- enchant with its slot). What an enchant gives is read from its spell
-- description in game ("increase Intellect by 7") and scored with the same
-- stat weights Mentor uses for gear (specData.weights in Data.lua).
--
-- Which enchants you know is remembered per character each time your
-- Enchanting window is open (Professions.lua calls RememberKnownEnchants).
--------------------------------------------------------------------------------

local _, Mentor = ...

local enchants = {}
Mentor.Enchants = enchants

-- Which item slots each enchant slot fits (equip locations from the item).
local EQUIP_LOCATIONS_BY_ENCHANT_SLOT = {
    ["2H Weapon"] = { INVTYPE_2HWEAPON = true },
    ["Weapon"]    = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_2HWEAPON = true },
    ["Boots"]     = { INVTYPE_FEET = true },
    ["Bracer"]    = { INVTYPE_WRIST = true },
    ["Chest"]     = { INVTYPE_CHEST = true, INVTYPE_ROBE = true },
    ["Cloak"]     = { INVTYPE_CLOAK = true },
    ["Gloves"]    = { INVTYPE_HAND = true },
    ["Shield"]    = { INVTYPE_SHIELD = true },
    ["Necklace"]  = { INVTYPE_NECK = true },
    ["Off-Hand"]  = { INVTYPE_HOLDABLE = true },
}

-- What an enchant gives, read from its description (lower case). The stat
-- names are the ones in the weights tables (Data.lua). Order matters: the
-- spell-specific phrases come before the general "increase X by N".
local NUMBER = "(%d+)"
local EFFECT_PATTERNS = {
    { "damage and healing done by magical spells and effects by up to " .. NUMBER, "SPELLPOWER" },
    { "healing done by spells and effects by up to " .. NUMBER, "HEALING" },
    { "healing spells by up to " .. NUMBER, "HEALING" },
    { "spell damage by up to " .. NUMBER, "SPELLPOWER" },
    { "all stats by " .. NUMBER, "ALLSTATS" },
    { NUMBER .. " mana every 5 sec", "MP5" },
    { NUMBER .. " mana per 5 sec", "MP5" },
    { "attack power by " .. NUMBER, "AP" },
    { "defense by " .. NUMBER, "DEFENSE" },
    { "defense skill by " .. NUMBER, "DEFENSE" },
    { "armor by " .. NUMBER, "ARMOR" },
    { "strength by " .. NUMBER, "STR" },
    { "agility by " .. NUMBER, "AGI" },
    { "stamina by " .. NUMBER, "STA" },
    { "intellect by " .. NUMBER, "INT" },
    { "spirit by " .. NUMBER, "SPI" },
    { NUMBER .. " additional points? of damage", "WEAPONDAMAGE" },
    { "weapon damage by " .. NUMBER, "WEAPONDAMAGE" },
    -- Chest (and some other) enchants say "grant +8 Stamina" or "+3 to all stats".
    { "%+" .. NUMBER .. " to all stats", "ALLSTATS" },
    { "%+" .. NUMBER .. " all stats", "ALLSTATS" },
    { "%+" .. NUMBER .. " strength", "STR" },
    { "%+" .. NUMBER .. " agility", "AGI" },
    { "%+" .. NUMBER .. " stamina", "STA" },
    { "%+" .. NUMBER .. " intellect", "INT" },
    { "%+" .. NUMBER .. " spirit", "SPI" },
    { "%+" .. NUMBER .. " armor", "ARMOR" },
    { "%+" .. NUMBER .. " defense", "DEFENSE" },
    { "%+" .. NUMBER .. " attack power", "AP" },
    { "%+" .. NUMBER .. " spell power", "SPELLPOWER" },
    { "%+" .. NUMBER .. " healing", "HEALING" },
    { "%+" .. NUMBER .. " mana every 5", "MP5" },
    { "%+" .. NUMBER .. " health", "HEALTH" },
    { "health by " .. NUMBER, "HEALTH" },
    { "%+" .. NUMBER .. " mana%.", "MANA" },
    { "mana by " .. NUMBER, "MANA" },
}
-- Mana from an enchant is worth about what the Intellect giving it would be (1 Intellect = 15 mana).
local MANA_PER_INTELLECT = 15
-- Health from an enchant is worth about a tenth of Stamina (1 Stamina = 10 health).
local HEALTH_PER_STAMINA = 10
-- "Increases all stats by 3": the five base stats.
local BASE_STATS = { "STR", "AGI", "STA", "INT", "SPI" }

-- Enchants whose worth isn't in plain numbers in their description: a fair
-- stand-in for what they give on average.
local SPECIAL_EFFECTS = {
    ["Weapon:Crusader"]     = { STR = 30 },       -- 100 Strength procs, roughly 30 on average
    ["Weapon:Fiery Weapon"] = { WEAPONDAMAGE = 4 },
}

-- Average weapon speed for turning "+N weapon damage" into damage per second.
local ONE_HAND_SPEED, TWO_HAND_SPEED = 2.6, 3.3

-- Parsed effects per spell id: { stat = amount } (false while the spell text
-- hasn't loaded yet).
local effectsBySpellId = {}

local function GetSpellDescriptionText(spellId)
    if C_Spell and C_Spell.GetSpellDescription then
        local isSuccess, descriptionText = pcall(C_Spell.GetSpellDescription, spellId)
        if isSuccess and type(descriptionText) == "string" and not (issecretvalue and issecretvalue(descriptionText)) then
            return descriptionText
        end
    end
    return nil
end

local function GetEnchantEffects(recipe)
    local spellId, _, slotName, enchantName = unpack(recipe)
    local specialEffects = SPECIAL_EFFECTS[slotName .. ":" .. enchantName]
    if specialEffects then
        return specialEffects
    end
    if effectsBySpellId[spellId] then
        return effectsBySpellId[spellId]
    end
    local descriptionText = GetSpellDescriptionText(spellId)
    if not descriptionText or descriptionText == "" then
        -- Not loaded yet: ask for it; the next tooltip has it.
        if C_Spell and C_Spell.RequestLoadSpellData then
            pcall(C_Spell.RequestLoadSpellData, spellId)
        end
        return nil
    end
    local lowerText = descriptionText:lower()
    local effects = {}
    for _, patternInfo in ipairs(EFFECT_PATTERNS) do
        local amountText = lowerText:match(patternInfo[1])
        local statName = patternInfo[2]
        if amountText and not effects[statName] then
            if statName == "ALLSTATS" then
                for _, baseStat in ipairs(BASE_STATS) do
                    effects[baseStat] = (effects[baseStat] or 0) + tonumber(amountText)
                end
            else
                effects[statName] = tonumber(amountText)
            end
        end
    end
    effectsBySpellId[spellId] = effects
    return effects
end

-- Stats that matter much less than the spec's main stat are left out, so a
-- healer isn't told to put Crusader (Strength) on their weapon just because
-- nothing better fits it.
local FLAT_STATS = { "STR", "AGI", "STA", "INT", "SPI", "SPELLPOWER", "HEALING", "AP" }
local MINIMUM_SHARE_OF_MAIN_STAT = 0.3
local MINIMUM_DPS_WEIGHT = 1

local function IsFlatStat(statName)
    for _, flatStat in ipairs(FLAT_STATS) do
        if flatStat == statName then
            return true
        end
    end
    return false
end

local function GetMainStatWeight(weights)
    local mainStatWeight = 0
    for _, statName in ipairs(FLAT_STATS) do
        mainStatWeight = math.max(mainStatWeight, weights[statName] or 0)
    end
    return mainStatWeight
end

-- How much an enchant is worth for these weights on this kind of item.
local function ScoreEnchant(recipe, weights, equipLocation)
    local effects = GetEnchantEffects(recipe)
    if not effects then
        return nil
    end
    local minimumWeight = GetMainStatWeight(weights) * MINIMUM_SHARE_OF_MAIN_STAT
    local score = 0
    for statName, amount in pairs(effects) do
        if statName == "WEAPONDAMAGE" then
            local dpsWeight = weights.DPS or 0
            if dpsWeight >= MINIMUM_DPS_WEIGHT then
                local weaponSpeed = equipLocation == "INVTYPE_2HWEAPON" and TWO_HAND_SPEED or ONE_HAND_SPEED
                score = score + amount / weaponSpeed * dpsWeight
            end
        elseif statName == "MANA" then
            local intellectWeight = weights.INT or 0
            if intellectWeight >= minimumWeight then
                score = score + amount / MANA_PER_INTELLECT * intellectWeight
            end
        elseif statName == "HEALTH" then
            -- Counted as the Stamina it equals, if Stamina matters for the spec.
            local staminaWeight = weights.STA or 0
            if staminaWeight >= minimumWeight then
                score = score + amount / HEALTH_PER_STAMINA * staminaWeight
            end
        else
            local statWeight = weights[statName] or 0
            if statWeight >= minimumWeight or not IsFlatStat(statName) then
                score = score + amount * statWeight
            end
        end
    end
    return score
end

--------------------------------------------------------------------------------
-- Which enchants this character knows
--------------------------------------------------------------------------------
-- Called by Professions.lua with the open window's recipes when it shows
-- Enchanting: { { recipeId, isKnown, name }, ... }.
function enchants.RememberKnownEnchants(recipes)
    local knownSpellIds = {}
    for _, recipe in ipairs(recipes) do
        if recipe.isKnown and recipe.recipeId then
            knownSpellIds[recipe.recipeId] = true
        end
    end
    MentorDB.knownEnchantSpellIds = knownSpellIds
end

local function IsEnchanter()
    if not GetProfessions or not GetProfessionInfo then
        return false
    end
    for _, professionIndex in ipairs({ GetProfessions() }) do
        if professionIndex and GetProfessionInfo(professionIndex) == "Enchanting" then
            return true
        end
    end
    return false
end

-- "Formula: Enchant Bracer - Greater Spellpower" or "trainer".
local function GetRecipeSourceText(recipe)
    local formulaItemId = recipe[2]
    if formulaItemId == 0 then
        return "from the trainer"
    end
    local formulaName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(formulaItemId)
    return formulaName and ("from " .. formulaName) or "from a formula"
end

-- The best enchant you know and the best one overall for this item, for the
-- current spec: { known = recipe, knownScore, better = recipe } or nil.
function enchants.GetBestEnchants(itemLink, weights)
    local equipLocation = Mentor.GetEquipLocation and Mentor.GetEquipLocation(itemLink)
    if not equipLocation or not Mentor.ENCHANT_RECIPES then
        return nil
    end
    local knownSpellIds = MentorDB.knownEnchantSpellIds
    local bestKnown, bestKnownScore, bestOverall, bestOverallScore = nil, 0, nil, 0
    for _, recipe in ipairs(Mentor.ENCHANT_RECIPES) do
        local fitsLocations = EQUIP_LOCATIONS_BY_ENCHANT_SLOT[recipe[3]]
        if fitsLocations and fitsLocations[equipLocation] then
            local score = ScoreEnchant(recipe, weights, equipLocation)
            if score and score > 0 then
                if score > bestOverallScore then
                    bestOverall, bestOverallScore = recipe, score
                end
                if knownSpellIds and knownSpellIds[recipe[1]] and score > bestKnownScore then
                    bestKnown, bestKnownScore = recipe, score
                end
            end
        end
    end
    if not bestOverall then
        return nil
    end
    return {
        known = bestKnown,
        better = bestOverall ~= bestKnown and bestOverall or nil,
        hasKnownList = knownSpellIds ~= nil,
    }
end

--------------------------------------------------------------------------------
-- The tooltip lines
--------------------------------------------------------------------------------
local GOLD, WHITE, GREY = { 1, 0.82, 0 }, { 1, 1, 1 }, { 0.65, 0.65, 0.65 }

local function AddEnchantLines(tooltip)
    if not (MentorDB and MentorDB.isEnchantTipEnabled ~= false) then
        return
    end
    if not tooltip.GetItem or not IsEnchanter() then
        return
    end
    local _, itemLink = tooltip:GetItem()
    local advice = Mentor.currentAdvice
    local weights = advice and advice.specData and advice.specData.weights
    if not itemLink or not weights then
        return
    end
    local best = enchants.GetBestEnchants(itemLink, weights)
    if not best then
        return
    end
    tooltip:AddLine("Best enchant for " .. advice.specData.name .. ":", GOLD[1], GOLD[2], GOLD[3])
    if best.known then
        tooltip:AddLine("  " .. best.known[4] .. " - you can make it", WHITE[1], WHITE[2], WHITE[3])
    elseif not best.hasKnownList then
        tooltip:AddLine("  Open your Enchanting window once so Mentor knows your recipes.", GREY[1], GREY[2], GREY[3], true)
    end
    if best.better then
        tooltip:AddLine("  " .. (best.known and "Better: " or "") .. best.better[4] .. " - " .. GetRecipeSourceText(best.better),
            best.known and GREY[1] or WHITE[1], best.known and GREY[2] or WHITE[2], best.known and GREY[3] or WHITE[3], true)
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        if tooltip == GameTooltip or tooltip == ItemRefTooltip then
            pcall(AddEnchantLines, tooltip)
        end
    end)
end

-- /mentor enchant: why the tooltip shows (or doesn't show) a best enchant,
-- using the bracers you wear.
function enchants.PrintDiagnosis()
    local professionNames = {}
    if GetProfessions and GetProfessionInfo then
        for _, professionIndex in pairs({ GetProfessions() }) do
            table.insert(professionNames, tostring(GetProfessionInfo(professionIndex)))
        end
    end
    Mentor.Print("Professions: " .. table.concat(professionNames, ", ") .. " - enchanter: " .. tostring(IsEnchanter()))
    local advice = Mentor.currentAdvice
    Mentor.Print("Spec: " .. tostring(advice and advice.specData and advice.specData.name)
        .. ", setting on: " .. tostring(MentorDB.isEnchantTipEnabled ~= false))
    local knownCount = 0
    for _ in pairs(MentorDB.knownEnchantSpellIds or {}) do
        knownCount = knownCount + 1
    end
    Mentor.Print("Known enchants remembered: " .. (MentorDB.knownEnchantSpellIds and knownCount or "none yet (open Enchanting)"))
    local sampleDescription = GetSpellDescriptionText(13846)     -- Enchant Bracer - Greater Spirit
    Mentor.Print("Sample enchant text: " .. tostring(sampleDescription))
    local wristLink = GetInventoryItemLink("player", 9)
    if wristLink and advice and advice.specData then
        local best = enchants.GetBestEnchants(wristLink, advice.specData.weights)
        Mentor.Print("Your bracers (" .. tostring(Mentor.GetEquipLocation(wristLink)) .. "): best known "
            .. tostring(best and best.known and best.known[4]) .. ", better " .. tostring(best and best.better and best.better[4]))
    else
        Mentor.Print("No bracers equipped to test with.")
    end
end

-- For tests and diagnostics.
enchants.GetEnchantEffects = GetEnchantEffects
enchants.ScoreEnchant = ScoreEnchant

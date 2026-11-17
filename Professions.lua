--------------------------------------------------------------------------------
-- Mentor - Professions.lua
-- Help with your professions:
--   * What to craft to level a profession up, from Wowhead's WoW Forever
--     profession leveling guides ("step-by-step guide at a glance", 1-300),
--     and where to gather for Mining, Herbalism and Skinning.
--   * Which of your known recipes make an upgrade for the spec you play.
-- Shown in a Mentor panel next to the profession window, and as a row per
-- profession in the Journey tab (Journey.lua).
-- Two settings under Extra tools:
--   "Profession leveling"  what to craft to level up      (off by default -
--                          a lot of information for a new player)
--   "Craftable upgrades"   recipes that make you an upgrade (on by default)
--------------------------------------------------------------------------------

local _, Mentor = ...

local professions = {}
Mentor.Professions = professions

local MENTOR_GOLD = { 1.00, 0.78, 0.10 }
local PANEL_WIDTH = 260
local PANEL_PADDING = 10
local ROW_HEIGHT = 20
local MAX_UPGRADE_ROWS = 6
local MAX_SIDE_TAB_WIDTH = 120              -- ignore anything sticking out further than this
local LOGO_TEXTURE = "Interface\\AddOns\\Mentor\\Media\\Logo"
local PANEL_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

--------------------------------------------------------------------------------
-- Leveling routes. Crafting: { from skill, to skill, recipe, crafts }.
-- Source: https://www.wowhead.com/forever/profession-leveling-guides (Nov 2026).
--------------------------------------------------------------------------------
local CRAFTING_ROUTES = {
    Alchemy = {
        { 1, 12, "Elixir of Minor Force", 11 }, { 12, 55, "Elixir of Minor Defense", 43 },
        { 55, 65, "Minor Mana Potion", 10 }, { 65, 90, "Elixir of Minor Fortitude", 26 },
        { 90, 120, "Elixir of Wisdom", 30 }, { 120, 160, "Lesser Mana Potion", 43 },
        { 160, 195, "Mana Potion", 38 }, { 195, 205, "Elixir of Agility", 10 },
        { 205, 225, "Greater Mana Potion", 20 }, { 225, 226, "Philosopher's Stone", 1 },
        { 226, 240, "Greater Mana Potion", 20 }, { 240, 260, "Draught of Detect Undead", 23 },
        { 260, 270, "Superior Mana Potion", 10 }, { 270, 300, "Major Discolored Healing Potion", 31 },
    },
    Blacksmithing = {
        { 1, 30, "Rough Sharpening Stone", 32 }, { 30, 65, "Rough Grinding Stone", 42 },
        { 65, 75, "Copper Chain Belt", 10 }, { 75, 80, "Silver Skeleton Key", 5 },
        { 80, 90, "Rough Bronze Leggings", 10 }, { 90, 100, "Runed Copper Belt", 13 },
        { 100, 105, "Heavy Sharpening Stone", 5 }, { 105, 110, "Runed Copper Belt", 10 },
        { 110, 125, "Rough Bronze Leggings", 15 }, { 125, 129, "Iron Buckle", 6 },
        { 129, 140, "Bronze Warhammer", 11 }, { 140, 147, "Patterned Bronze Bracers", 17 },
        { 147, 155, "Green Iron Bracers", 8 }, { 155, 165, "Green Iron Leggings", 12 },
        { 165, 183, "Green Iron Bracers", 31 }, { 183, 190, "Heavy Mithril Gauntlet", 7 },
        { 190, 200, "Golden Scale Bracers", 16 }, { 200, 205, "Heavy Mithril Gauntlet", 5 },
        { 205, 210, "Mithril Plate Pants", 5 }, { 210, 215, "Heavy Mithril Gauntlet", 12 },
        { 215, 225, "Heavy Mithril Breastplate", 10 }, { 225, 235, "Dense Weightstone", 15 },
        { 235, 240, "Mithril Coif", 12 }, { 240, 246, "Heavy Mithril Boots", 17 },
        { 246, 250, "Big Black Mace", 12 }, { 250, 257, "Arcanite Skeleton Key", 10 },
        { 257, 270, "Ebon Shiv", 20 }, { 270, 275, "Bold Dirk", 5 },
        { 275, 279, "Ornate Thorium Handaxe", 4 }, { 279, 300, "Bold Dirk", 24 },
    },
    Enchanting = {
        { 1, 2, "Runed Copper Rod", 1 }, { 2, 20, "Disenchant green items", nil },
        { 20, 79, "Lesser Magic Wand", 59 }, { 79, 90, "Enchant Chest - Minor Absorption", 11 },
        { 90, 100, "Enchant Bracer - Minor Stamina", 10 }, { 100, 101, "Runed Silver Rod", 1 },
        { 101, 110, "Greater Magic Wand", 9 }, { 110, 135, "Enchant Cloak - Minor Agility", 25 },
        { 135, 155, "Enchant Bracer - Lesser Stamina", 20 }, { 155, 156, "Runed Golden Rod", 1 },
        { 156, 185, "Enchant Bracer - Lesser Strength", 36 }, { 185, 220, "Enchant Bracer - Strength", 41 },
        { 220, 225, "Enchant Cloak - Greater Defense", 5 }, { 225, 230, "Enchant Gloves - Agility", 5 },
        { 230, 235, "Enchant Boots - Stamina", 5 }, { 235, 250, "Enchant Chest - Superior Stamina", 16 },
        { 250, 265, "Lesser Mana Oil", 15 }, { 265, 294, "Enchant Shield - Greater Stamina", 30 },
        { 294, 295, "Runed Arcanite Rod", 1 }, { 295, 300, "Enchant Cloak - Superior Defense", 5 },
    },
    Engineering = {
        { 1, 30, "Rough Blasting Powder", 32 }, { 30, 50, "Handful of Copper Bolts", 20 },
        { 50, 51, "Arclight Spanner", 1 }, { 51, 75, "Rough Copper Bomb", 29 },
        { 75, 90, "Coarse Blasting Powder", 16 }, { 90, 100, "Coarse Dynamite", 15 },
        { 100, 105, "Silver Contact", 5 }, { 105, 125, "Bronze Tube", 25 },
        { 125, 135, "Standard Scope", 10 }, { 135, 150, "Whirring Bronze Gizmo", 23 },
        { 150, 160, "Bronze Framework", 12 }, { 160, 175, "Explosive Sheep", 15 },
        { 175, 194, "Solid Blasting Powder", 51 }, { 194, 195, "Gyromatic Micro-Adjustor", 1 },
        { 195, 200, "Mithril Tube", 5 }, { 200, 215, "Unstable Trigger", 18 },
        { 215, 238, "Mithril Casing", 33 }, { 238, 250, "Hi-Explosive Bomb", 15 },
        { 250, 260, "Dense Blasting Powder", 27 }, { 260, 285, "Thorium Widget", 25 },
        { 285, 300, "Thorium Tube", 15 },
    },
    Leatherworking = {
        { 1, 30, "Light Leather", 32 }, { 30, 45, "Light Armor Kit", 20 },
        { 45, 55, "Cured Light Hide", 10 }, { 55, 85, "Embossed Leather Gloves", 35 },
        { 85, 100, "Fine Leather Belt", 20 }, { 100, 115, "Dark Leather Pants", 15 },
        { 115, 118, "Gray Leather Boots", 7 }, { 118, 125, "Dark Leather Belt", 7 },
        { 125, 135, "Cured Heavy Hide", 10 }, { 135, 143, "Dark Leather Belt", 18 },
        { 143, 145, "Cured Heavy Hide", 12 }, { 145, 155, "Toughened Leather Gloves", 25 },
        { 155, 160, "Barbaric Shoulders", 5 }, { 160, 180, "Gem-studded Leather Belt", 20 },
        { 180, 185, "Barbaric Shoulders", 12 }, { 185, 190, "Gem-studded Leather Belt", 7 },
        { 190, 200, "Guardian Gloves", 20 }, { 200, 210, "Thick Armor Kit", 20 },
        { 210, 225, "Nightscape Pants", 15 }, { 225, 230, "Cured Rugged Hide", 6 },
        { 230, 240, "Nightscape Pants", 20 }, { 240, 255, "Wicked Leather Gauntlets", 15 },
        { 255, 260, "Heavy Scorpid Bracers", 6 }, { 260, 270, "Wicked Leather Gauntlets", 20 },
        { 270, 300, "Heavy Scorpid Helm", 33 },
    },
    Tailoring = {
        { 1, 43, "Bolt of Linen Cloth", 54 }, { 43, 45, "Brown Linen Vest", 2 },
        { 45, 70, "Linen Belt", 33 }, { 70, 75, "Reinforced Linen Cape", 7 },
        { 75, 81, "Bolt of Woolen Cloth", 12 }, { 81, 100, "Woolen Cape", 27 },
        { 100, 110, "Bolt of Silk Cloth", 10 }, { 110, 125, "Double-stitched Woolen Shoulders", 19 },
        { 125, 132, "Azure Silk Hood", 7 }, { 132, 139, "Lesser Wizard's Robe", 8 },
        { 139, 140, "Formal White Shirt", 1 }, { 140, 149, "Bolt of Mageweave", 11 },
        { 149, 160, "Earthen Vest", 11 }, { 160, 170, "Robe of Power", 10 },
        { 170, 180, "Black Mageweave Vest", 10 }, { 180, 190, "Orange Mageweave Shirt", 11 },
        { 190, 205, "Black Mageweave Gloves", 17 }, { 205, 214, "Bolt of Runecloth", 11 },
        { 214, 234, "Runecloth Belt", 21 }, { 234, 250, "Runecloth Cloak", 18 },
        { 250, 260, "Runecloth Boots", 12 }, { 260, 280, "Runecloth Cuffs", 25 },
        { 280, 285, "Wisdom of the Timbermaw", 8 }, { 285, 292, "Venomspew Gloves", 7 },
        { 292, 299, "Venomspew Cord", 9 }, { 299, 300, "Venomspew Footpads", 4 },
    },
    Cooking = {
        { 1, 50, "Brilliant Smallfish", 49 }, { 50, 100, "Longjaw Mud Snapper", 51 },
        { 100, 175, "Bristle Whisker Catfish", 120 }, { 175, 225, "Mithril Headed Trout", 51 },
        { 225, 275, "Spotted Yellowtail", 51 }, { 275, 300, "Mightfish Steak", 25 },
    },
    ["First Aid"] = {
        { 1, 40, "Linen Bandage", 41 }, { 40, 80, "Heavy Linen Bandage", 55 },
        { 80, 115, "Wool Bandage", 48 }, { 115, 150, "Heavy Wool Bandage", 48 },
        { 150, 180, "Silk Bandage", 41 }, { 180, 210, "Heavy Silk Bandage", 41 },
        { 210, 240, "Mageweave Bandage", 41 }, { 240, 260, "Heavy Mageweave Bandage", 24 },
        { 260, 290, "Runecloth Bandage", 40 }, { 290, 300, "Heavy Runecloth Bandage", 11 },
    },
}

-- Gathering: { from skill, to skill, what, where } (Wowhead's overview guides).
local GATHERING_ROUTES = {
    Mining = {
        { 1, 65, "Copper", "any starting zone" },
        { 65, 125, "Copper, Tin, Silver", "Ashenvale, Redridge Mountains, The Barrens, Thousand Needles" },
        { 125, 175, "Tin, Silver, Iron, Gold", "Arathi Highlands, Desolace, Stranglethorn Vale, Thousand Needles" },
        { 175, 225, "Gold, Mithril, Truesilver", "Azshara, Tanaris, The Hinterlands" },
    },
    Herbalism = {
        { 1, 70, "Peacebloom, Silverleaf, Earthroot", "any starting zone" },
        { 70, 115, "Mageroyal, Briarthorn, Stranglekelp", "Darkshore, Loch Modan, Silverpine Forest" },
        { 115, 170, "Bruiseweed, Wild Steelbloom, Kingsblood, Liferoot", "Hillsbrad Foothills, Wetlands, Stonetalon Mountains" },
        { 170, 205, "Kingsblood, Liferoot, Fadeleaf, Goldthorn, Khadgar's Whisker", "Stranglethorn Vale, Arathi Highlands" },
        { 205, 225, "Fadeleaf, Goldthorn, Khadgar's Whisker, Firebloom, Purple Lotus", "Alterac Mountains, Tanaris, Searing Gorge" },
    },
    Skinning = {
        { 1, 75, "beasts", "your starting zone" },
        { 75, 125, "beasts", "The Barrens, Loch Modan, Darkshore" },
        { 125, 175, "bears, lions and other beasts", "Hillsbrad Foothills, Wetlands, Ashenvale, Duskwood" },
        { 175, 225, "raptors and other beasts (level 30-40)", "Arathi Highlands, Stranglethorn Vale, Thousand Needles" },
    },
}

local function IsLevelingHelpOn()
    return MentorDB and MentorDB.isProfessionLevelingEnabled == true
end

local function AreCraftableUpgradesOn()
    return MentorDB and MentorDB.areCraftableUpgradesEnabled ~= false
end

-- The route key for a profession name ("Tailoring", or names with a prefix
-- such as "Classic Tailoring").
local function FindRouteName(professionName)
    if type(professionName) ~= "string" then
        return nil
    end
    for routeName in pairs(CRAFTING_ROUTES) do
        if professionName == routeName or professionName:find(routeName, 1, true) then
            return routeName
        end
    end
    for routeName in pairs(GATHERING_ROUTES) do
        if professionName == routeName or professionName:find(routeName, 1, true) then
            return routeName
        end
    end
    return nil
end
professions.FindRouteName = FindRouteName

--------------------------------------------------------------------------------
-- Where you are in the route
--------------------------------------------------------------------------------
-- Returns the step for this skill and the one after it (or nil).
-- A crafting step: { recipe, crafts left (estimate), to skill, from skill }.
function professions.GetLevelingStep(professionName, skillLevel)
    local routeName = FindRouteName(professionName)
    local craftingRoute = routeName and CRAFTING_ROUTES[routeName]
    local gatheringRoute = routeName and GATHERING_ROUTES[routeName]
    local route = craftingRoute or gatheringRoute
    if not route or not skillLevel then
        return nil
    end
    for stepIndex, step in ipairs(route) do
        local fromSkill, toSkill = step[1], step[2]
        if skillLevel >= fromSkill and skillLevel < toSkill then
            local currentStep
            if craftingRoute then
                local totalCrafts = step[4]
                local craftsLeft = totalCrafts and math.max(1, math.ceil(totalCrafts * (toSkill - skillLevel) / (toSkill - fromSkill)))
                currentStep = { kind = "craft", recipe = step[3], craftsLeft = craftsLeft, toSkill = toSkill, fromSkill = fromSkill }
            else
                currentStep = { kind = "gather", what = step[3], where = step[4], toSkill = toSkill, fromSkill = fromSkill }
            end
            local nextStep = route[stepIndex + 1]
            if nextStep and craftingRoute then
                currentStep.nextRecipe, currentStep.nextToSkill = nextStep[3], nextStep[2]
            end
            return currentStep
        end
    end
    return nil
end

-- One line for the Journey tab: "Craft Woolen Cape (about 13 more, to 100)".
function professions.GetJourneyText(professionName, skillLevel)
    if not IsLevelingHelpOn() then
        return nil
    end
    local step = professions.GetLevelingStep(professionName, skillLevel)
    if not step then
        return nil
    end
    if step.kind == "craft" then
        if not step.craftsLeft then
            return string.format("To level up: %s (to %d).", step.recipe, step.toSkill)
        end
        return string.format("To level up: craft %s - about %d more, to skill %d.", step.recipe, step.craftsLeft, step.toSkill)
    end
    return string.format("To level up: %s in %s (to %d).", step.what, step.where, step.toSkill)
end

--------------------------------------------------------------------------------
-- The open profession window (retail C_TradeSkillUI, or the classic API)
--------------------------------------------------------------------------------
local DIFFICULTY_COLORS = {          -- skill-up chance, the game's own colours
    optimal = "|cffff8040", medium = "|cffffff00", easy = "|cff40bf40", trivial = "|cff808080",
}
local RETAIL_DIFFICULTY_NAMES = { [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" }

-- name, skill, maximum of the profession shown in the window.
local function GetOpenProfession()
    if C_TradeSkillUI then
        for _, getInfo in ipairs({ C_TradeSkillUI.GetChildProfessionInfo, C_TradeSkillUI.GetBaseProfessionInfo }) do
            if getInfo then
                local success, professionInfo = pcall(getInfo)
                if success and type(professionInfo) == "table" and professionInfo.professionName
                    and professionInfo.professionName ~= "" and (professionInfo.maxSkillLevel or 0) > 0 then
                    return professionInfo.professionName, professionInfo.skillLevel, professionInfo.maxSkillLevel
                end
            end
        end
    end
    if GetTradeSkillLine then
        local success, professionName, skillLevel, maximumSkill = pcall(GetTradeSkillLine)
        if success and professionName and professionName ~= "UNKNOWN" then
            return professionName, skillLevel, maximumSkill
        end
    end
    return nil
end

-- Every recipe in the open window: { name, isKnown, difficulty, itemLink, recipeId, icon }.
local function GetOpenRecipes()
    local recipes = {}
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        local success, recipeIds = pcall(C_TradeSkillUI.GetAllRecipeIDs)
        if success and type(recipeIds) == "table" then
            for _, recipeId in ipairs(recipeIds) do
                local infoSuccess, recipeInfo = pcall(C_TradeSkillUI.GetRecipeInfo, recipeId)
                if infoSuccess and type(recipeInfo) == "table" and recipeInfo.name then
                    local itemLink
                    if C_TradeSkillUI.GetRecipeItemLink then
                        local linkSuccess, recipeItemLink = pcall(C_TradeSkillUI.GetRecipeItemLink, recipeId)
                        itemLink = linkSuccess and recipeItemLink or nil
                    end
                    if not itemLink and C_TradeSkillUI.GetRecipeOutputItemData then
                        local outputSuccess, outputData = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeId)
                        itemLink = outputSuccess and type(outputData) == "table" and outputData.hyperlink or nil
                    end
                    table.insert(recipes, {
                        name = recipeInfo.name, isKnown = recipeInfo.learned ~= false, recipeId = recipeId,
                        difficulty = RETAIL_DIFFICULTY_NAMES[recipeInfo.relativeDifficulty] or "trivial",
                        itemLink = itemLink, icon = recipeInfo.icon,
                    })
                end
            end
            return recipes
        end
    end
    if GetNumTradeSkills and GetTradeSkillInfo then
        for recipeIndex = 1, GetNumTradeSkills() or 0 do
            local recipeName, recipeType = GetTradeSkillInfo(recipeIndex)
            if recipeName and recipeType ~= "header" and recipeType ~= "subheader" then
                table.insert(recipes, {
                    name = recipeName, isKnown = true, difficulty = recipeType, recipeIndex = recipeIndex,
                    itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(recipeIndex) or nil,
                    icon = GetTradeSkillIcon and GetTradeSkillIcon(recipeIndex) or nil,
                })
            end
        end
    end
    return recipes
end

-- Known recipes that make an upgrade for the spec you play, best first.
function professions.GetCraftableUpgrades(recipes)
    local advice = Mentor.currentAdvice
    if not (advice and advice.specData and advice.specData.weights and Mentor.CompareItem) then
        return {}
    end
    local upgrades = {}
    for _, recipe in ipairs(recipes) do
        if recipe.isKnown and recipe.itemLink then
            local success, comparison = pcall(Mentor.CompareItem, recipe.itemLink, advice.specData.weights)
            if success and comparison and (comparison.kind == "upgrade" or comparison.kind == "empty") then
                table.insert(upgrades, { recipe = recipe, comparison = comparison,
                    sortValue = comparison.kind == "empty" and 1000 or (comparison.percent or 0) })
            end
        end
    end
    table.sort(upgrades, function(first, second) return first.sortValue > second.sortValue end)
    return upgrades
end

--------------------------------------------------------------------------------
-- The Mentor panel next to the profession window
--------------------------------------------------------------------------------
local panel
local upgradeRows = {}

local function GetProfessionWindow()
    if ProfessionsFrame and ProfessionsFrame:IsShown() then
        return ProfessionsFrame
    end
    if TradeSkillFrame and TradeSkillFrame:IsShown() then
        return TradeSkillFrame
    end
    return nil
end

-- Shows a recipe in the profession window, the same as clicking it in the
-- window's own recipe list. The retail window's list is used when it is
-- there; the game's OpenRecipe and the classic window are the fallbacks.
local function OpenRecipe(recipe)
    if recipe.recipeId and C_TradeSkillUI then
        local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
        local recipeList = craftingPage and craftingPage.RecipeList
        if recipeList and recipeList.SelectRecipe and C_TradeSkillUI.GetRecipeInfo then
            local infoSuccess, recipeInfo = pcall(C_TradeSkillUI.GetRecipeInfo, recipe.recipeId)
            if infoSuccess and recipeInfo then
                -- The crafting tab must be the one shown.
                if ProfessionsFrame.SetTab and ProfessionsFrame.recipesTabID then
                    pcall(ProfessionsFrame.SetTab, ProfessionsFrame, ProfessionsFrame.recipesTabID)
                end
                local selectSuccess = pcall(recipeList.SelectRecipe, recipeList, recipeInfo, true)
                if selectSuccess then
                    return
                end
            end
        end
        if C_TradeSkillUI.OpenRecipe then
            pcall(C_TradeSkillUI.OpenRecipe, recipe.recipeId)
        end
    elseif recipe.recipeIndex and TradeSkillFrame_SetSelection then
        pcall(TradeSkillFrame_SetSelection, recipe.recipeIndex)
        if TradeSkillFrame_Update then
            pcall(TradeSkillFrame_Update)
        end
    end
end

local function CreateTextLine(parentFrame, fontObject)
    local textLine = parentFrame:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
    textLine:SetJustifyH("LEFT")
    textLine:SetWidth(PANEL_WIDTH - 2 * PANEL_PADDING)
    return textLine
end

local function CreateRecipeRow()
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(PANEL_WIDTH - 2 * PANEL_PADDING, ROW_HEIGHT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_HEIGHT - 2, ROW_HEIGHT - 2)
    row.icon:SetPoint("LEFT", 0, 0)
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.nameText:SetPoint("RIGHT", -52, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)
    row.valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.valueText:SetPoint("RIGHT", 0, 0)
    local hoverHighlight = row:CreateTexture(nil, "HIGHLIGHT")
    hoverHighlight:SetAllPoints()
    hoverHighlight:SetColorTexture(1, 0.82, 0, 0.08)
    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetHyperlink, GameTooltip, self.itemLink)
            if self.recipe then
                GameTooltip:AddLine("|cff66ccffMentor:|r Click to show it in the profession window.", 0.65, 0.65, 0.65)
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if self.recipe then
            OpenRecipe(self.recipe)
        end
    end)
    return row
end

local function CreatePanel()
    panel = CreateFrame("Frame", "MentorProfessionPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetFrameStrata("HIGH")
    if panel.SetBackdrop then
        panel:SetBackdrop(PANEL_BACKDROP)
        panel:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.9)
    end
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(LOGO_TEXTURE)
    logo:SetSize(16, 16)
    logo:SetPoint("TOPLEFT", PANEL_PADDING, -PANEL_PADDING + 2)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    panel.levelHeader = CreateTextLine(panel, "GameFontNormalSmall")
    panel.levelHeader:SetText("Level up")
    panel.levelRow = CreateRecipeRow()
    panel.levelText = CreateTextLine(panel)
    panel.nextText = CreateTextLine(panel, "GameFontDisableSmall")
    panel.upgradeHeader = CreateTextLine(panel, "GameFontNormalSmall")
    panel.upgradeHeader:SetText("Upgrades you can make")
    panel.noUpgradesText = CreateTextLine(panel, "GameFontDisableSmall")
    panel.noUpgradesText:SetText("None of your recipes is an upgrade right now.")
    panel:Hide()
end

-- How far the window's own buttons (its side tabs) stick out to the right of
-- the window, so the panel can sit beside them instead of on top of them.
local function GetWidthOfSideTabs(professionWindow)
    local windowRight = professionWindow:GetRight()
    if not windowRight then
        return 0
    end
    local widestOverhang = 0
    local function CheckChildren(parentFrame, depth)
        for _, childFrame in ipairs({ parentFrame:GetChildren() }) do
            if childFrame:IsShown() and childFrame ~= panel then
                local childRight = childFrame.GetRight and childFrame:GetRight()
                local overhang = childRight and (childRight - windowRight) or 0
                if overhang > widestOverhang and overhang <= MAX_SIDE_TAB_WIDTH then
                    widestOverhang = overhang
                end
                if depth < 2 then
                    CheckChildren(childFrame, depth + 1)
                end
            end
        end
    end
    pcall(CheckChildren, professionWindow, 1)
    return widestOverhang
end

-- Lays out the panel from the top down and sets its height.
function professions.RefreshPanel()
    local professionWindow = GetProfessionWindow()
    local isLevelingShown, areUpgradesShown = IsLevelingHelpOn(), AreCraftableUpgradesOn()
    if not (isLevelingShown or areUpgradesShown) or not professionWindow then
        if panel then
            panel:Hide()
        end
        return
    end
    local professionName, skillLevel, maximumSkill = GetOpenProfession()
    if not professionName then
        return
    end
    if not panel then
        CreatePanel()
    end
    -- Level with the window's top, to the right of the tabs that stick out
    -- of the window's right side (so they stay free to click).
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", professionWindow, "TOPRIGHT", GetWidthOfSideTabs(professionWindow) + 4, 0)
    panel.title:SetText(string.format("%s  |cffffffff%d / %d|r", professionName, skillLevel or 0, maximumSkill or 0))

    local recipes = GetOpenRecipes()
    local recipesByName = {}
    for _, recipe in ipairs(recipes) do
        recipesByName[recipe.name] = recipe
    end

    local verticalOffset = -PANEL_PADDING - 22
    local function Place(region, height)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", PANEL_PADDING, verticalOffset)
        region:Show()
        verticalOffset = verticalOffset - height
    end

    -- Level up: the guide's recipe for your skill.
    if isLevelingShown then
        local step = professions.GetLevelingStep(professionName, skillLevel)
        Place(panel.levelHeader, 16)
        if step and step.kind == "craft" then
            local recipe = recipesByName[step.recipe]
            panel.levelRow.recipe = recipe
            panel.levelRow.itemLink = recipe and recipe.itemLink
            panel.levelRow.icon:SetTexture(recipe and recipe.icon or 134400)
            local colorCode = recipe and DIFFICULTY_COLORS[recipe.difficulty] or "|cffffffff"
            panel.levelRow.nameText:SetText(colorCode .. step.recipe .. "|r")
            panel.levelRow.valueText:SetText(step.craftsLeft and ("x" .. step.craftsLeft) or "")
            Place(panel.levelRow, ROW_HEIGHT + 2)
            if not recipe then
                panel.levelText:SetText("|cffff9933You don't know it yet - learn it from a trainer (or a recipe).|r")
            elseif recipe.difficulty == "trivial" then
                panel.levelText:SetText("|cffa6a6a6Grey: it no longer gives skill - move on to the next step.|r")
            else
                panel.levelText:SetText(string.format("Craft about %d to reach skill %d.", step.craftsLeft or 1, step.toSkill))
            end
            Place(panel.levelText, (panel.levelText:GetStringHeight() or 12) + 4)
            if step.nextRecipe then
                panel.nextText:SetText(string.format("Then: %s (to %d)", step.nextRecipe, step.nextToSkill))
                Place(panel.nextText, 16)
            else
                panel.nextText:Hide()
            end
        else
            panel.levelRow:Hide()
            panel.nextText:Hide()
            panel.levelText:SetText(step and step.kind == "gather"
                and string.format("%s in %s (to %d).", step.what, step.where, step.toSkill)
                or "|cffa6a6a6No leveling route for this profession.|r")
            Place(panel.levelText, (panel.levelText:GetStringHeight() or 12) + 4)
        end
    else
        for _, levelRegion in ipairs({ panel.levelHeader, panel.levelRow, panel.levelText, panel.nextText }) do
            levelRegion:Hide()
        end
    end

    -- Upgrades you can make.
    if areUpgradesShown then
        verticalOffset = verticalOffset - 6
        Place(panel.upgradeHeader, 16)
        local upgrades = professions.GetCraftableUpgrades(recipes)
        for rowIndex = 1, MAX_UPGRADE_ROWS do
            local upgrade = upgrades[rowIndex]
            local row = upgradeRows[rowIndex]
            if upgrade then
                row = row or CreateRecipeRow()
                upgradeRows[rowIndex] = row
                row.recipe, row.itemLink = upgrade.recipe, upgrade.recipe.itemLink
                row.icon:SetTexture(upgrade.recipe.icon or 134400)
                row.nameText:SetText(upgrade.recipe.itemLink or upgrade.recipe.name)
                local valueText = upgrade.comparison.kind == "empty" and "new slot"
                    or (Mentor.FormatPercentChange and Mentor.FormatPercentChange(upgrade.comparison.percent) or "")
                -- Yellow with the level when you can't wear it yet (like the bag arrows).
                if upgrade.comparison.requiredLevel then
                    row.valueText:SetText("|cffffd100" .. valueText .. " (" .. upgrade.comparison.requiredLevel .. ")|r")
                else
                    row.valueText:SetText("|cff40ff40" .. valueText .. "|r")
                end
                Place(row, ROW_HEIGHT)
            elseif row then
                row:Hide()
            end
        end
        if #upgrades == 0 then
            Place(panel.noUpgradesText, 16)
        else
            panel.noUpgradesText:Hide()
        end
    else
        panel.upgradeHeader:Hide()
        panel.noUpgradesText:Hide()
        for _, row in ipairs(upgradeRows) do
            row:Hide()
        end
    end
    panel:SetHeight(-verticalOffset + PANEL_PADDING)
    panel:Show()
end

local eventFrame = CreateFrame("Frame")
for _, eventName in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE",
    "TRADE_SKILL_DATA_SOURCE_CHANGED", "SKILL_LINES_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end
-- Events come in bursts (and item info arrives one item at a time): refresh once, a moment later.
local isRefreshQueued = false
eventFrame:SetScript("OnEvent", function(_, eventName)
    if eventName == "TRADE_SKILL_CLOSE" then
        if panel then
            panel:Hide()
        end
        return
    end
    if eventName == "GET_ITEM_INFO_RECEIVED" and not (panel and panel:IsShown()) then
        return
    end
    if isRefreshQueued or not C_Timer then
        return
    end
    isRefreshQueued = true
    C_Timer.After(0.2, function()
        isRefreshQueued = false
        pcall(professions.RefreshPanel)
    end)
end)

-- Also follow the window itself (the profession window can close without the event).
local function HookWindow(windowFrame)
    if windowFrame and not windowFrame.isMentorHooked then
        windowFrame:HookScript("OnShow", function() pcall(professions.RefreshPanel) end)
        windowFrame:HookScript("OnHide", function() if panel then panel:Hide() end end)
        windowFrame.isMentorHooked = true
    end
end
eventFrame:RegisterEvent("ADDON_LOADED")
local originalOnEvent = eventFrame:GetScript("OnEvent")
eventFrame:SetScript("OnEvent", function(self, eventName, ...)
    if eventName == "ADDON_LOADED" then
        HookWindow(ProfessionsFrame)
        HookWindow(TradeSkillFrame)
        return
    end
    originalOnEvent(self, eventName, ...)
end)

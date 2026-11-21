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
--   "Profession leveling"  what to craft to level up, where to get the
--                          recipe and the trainers     (on by default)
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

-- Where the guide's recipes come from (Wowhead's "Learned From" column).
-- Not listed: learned from the trainer (or known from the start).
-- Vendors: { name, place, faction ("Alliance", "Horde" or nil for both) }.
-- Pexmit is a rare roaming vendor: he moves between several spots in Dae'gun
-- (Mount Hyjal), is often away for hours, and may need Hyjal quests first.
local PEXMIT_PLACE = "roams Dae'gun, Mount Hyjal - often away for hours"

local RECIPE_SOURCES = {
    ["Philosopher's Stone"] = { vendors = { { "Alchemist Pestlezugg", "Gadgetzan, Tanaris" } } },
    ["Superior Mana Potion"] = { vendors = { { "Ulthir", "Craftsmen's Terrace, Darnassus", "Alliance" }, { "Algernon", "The Apothecarium, Undercity", "Horde" } } },
    ["Major Discolored Healing Potion"] = { note = "Taught after a short questline: the Odd Child in Westfall (Alliance) or Apothecary Renferrel at the Sepulcher, Silverpine Forest (Horde)." },
    ["Ebon Shiv"] = { vendors = { { "Magnus Frostwake", "Caer Darrow, Western Plaguelands" } } },
    ["Ornate Thorium Handaxe"] = { vendors = { { "Magnus Frostwake", "Caer Darrow, Western Plaguelands" } } },
    ["Bold Dirk"] = { vendors = { { "Pexmit", PEXMIT_PLACE } } },
    ["Enchant Cloak - Minor Agility"] = { vendors = { { "Dalria", "Astranaar, Ashenvale", "Alliance" }, { "Kulwia", "Sun Rock Retreat, Stonetalon Mountains", "Horde" } } },
    ["Enchant Bracer - Lesser Strength"] = { vendors = { { "Dalria", "Astranaar, Ashenvale", "Alliance" }, { "Kulwia", "Sun Rock Retreat, Stonetalon Mountains", "Horde" } } },
    ["Lesser Mana Oil"] = { vendors = { { "Kania", "Cenarion Hold, Silithus" } } },
    ["Enchant Shield - Greater Stamina"] = { vendors = { { "Mythrin'dir", "Craftsmen's Terrace, Darnassus", "Alliance" }, { "Daniel Bartlett", "Trade Quarter, Undercity", "Horde" } } },
    ["Runed Arcanite Rod"] = { vendors = { { "Lorelae Wintersong", "Nighthaven, Moonglade" } } },
    ["Enchant Cloak - Superior Defense"] = { vendors = { { "Lorelae Wintersong", "Nighthaven, Moonglade" } } },
    ["Thorium Widget"] = { vendors = { { "Gearcutter Cogspinner", "Tinker Town, Ironforge", "Alliance" }, { "Sovik", "Valley of Honor, Orgrimmar", "Horde" } } },
    ["Thorium Tube"] = { vendors = { { "Xizzer Fizzbolt", "Everlook, Winterspring" } } },
    ["Gem-studded Leather Belt"] = { vendors = { { "Rikqiz", "Booty Bay, Stranglethorn Vale" } } },
    ["Wicked Leather Gauntlets"] = { vendors = { { "Leonard Porter", "Chillwind Camp, Western Plaguelands", "Alliance" }, { "Werg Thickblade", "The Bulwark, Tirisfal Glades", "Horde" } } },
    ["Heavy Scorpid Bracers"] = { vendors = { { "Zannok Hidepiercer", "Cenarion Hold, Silithus" } } },
    ["Heavy Scorpid Helm"] = { vendors = { { "Zannok Hidepiercer", "Cenarion Hold, Silithus" } } },
    ["Runecloth Cloak"] = { vendors = { { "Darnall", "Nighthaven, Moonglade" } } },
    ["Runecloth Boots"] = { vendors = { { "Darnall", "Nighthaven, Moonglade" } } },
    ["Runecloth Cuffs"] = { vendors = { { "Pexmit", PEXMIT_PLACE } } },
    ["Wisdom of the Timbermaw"] = { vendors = { { "Meilosh", "Timbermaw Hold, Felwood (needs Timbermaw reputation)" } } },
    ["Venomspew Gloves"] = { vendors = { { "Mishta", "Cenarion Hold, Silithus" } } },
    ["Venomspew Cord"] = { vendors = { { "Mishta", "Cenarion Hold, Silithus" } } },
    ["Venomspew Footpads"] = { vendors = { { "Mishta", "Cenarion Hold, Silithus" } } },
    ["Brilliant Smallfish"] = { vendors = { { "Tharynn Bouden", "Goldshire, Elwynn Forest", "Alliance" }, { "Khara Deepwater", "Loch Modan", "Alliance" },
        { "Sewa Mistrunner", "Thunder Bluff", "Horde" }, { "Martine Tramblay", "Brill, Tirisfal Glades", "Horde" } } },
    ["Longjaw Mud Snapper"] = { vendors = { { "Nyalah Brightfire", "Valanaar, Zephras Isle" } } },
    ["Bristle Whisker Catfish"] = { vendors = { { "Kilxx", "Ratchet, The Barrens" } } },
    ["Mithril Headed Trout"] = { vendors = { { "Kelsey Yance", "Booty Bay, Stranglethorn Vale" } } },
    ["Spotted Yellowtail"] = { vendors = { { "Gikkix", "Tanaris" } } },
    ["Mightfish Steak"] = { vendors = { { "Vivianna", "Feathermoon Stronghold, Feralas", "Alliance" }, { "Sheendra Tallgrass", "Camp Mojache, Feralas", "Horde" } } },
    ["Heavy Silk Bandage"] = { vendors = { { "Deneb Walker", "Stromgarde, Arathi Highlands", "Alliance" }, { "Balai Lok'Wein", "Brackenwall Village, Dustwallow Marsh", "Horde" } } },
    ["Mageweave Bandage"] = { vendors = { { "Deneb Walker", "Stromgarde, Arathi Highlands", "Alliance" }, { "Balai Lok'Wein", "Brackenwall Village, Dustwallow Marsh", "Horde" } } },
    ["Heavy Mageweave Bandage"] = { note = "Trained by Doctor Gustaf VanHowzen in Theramore (Alliance) or Doctor Gregory Victor in Hammerfall (Horde)." },
    ["Runecloth Bandage"] = { note = "Trained by Doctor Gustaf VanHowzen in Theramore (Alliance) or Doctor Gregory Victor in Hammerfall (Horde)." },
    ["Heavy Runecloth Bandage"] = { note = "Trained by Doctor Gustaf VanHowzen in Theramore (Alliance) or Doctor Gregory Victor in Hammerfall (Horde)." },
}

-- How to get a recipe you don't know: "Sold by Ulthir (Craftsmen's Terrace, Darnassus)."
function professions.GetRecipeSourceText(recipeName)
    local recipeSource = RECIPE_SOURCES[recipeName]
    if not recipeSource then
        return "Learn it from your trainer."
    end
    if recipeSource.note then
        return recipeSource.note
    end
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
    local vendorTexts = {}
    for _, vendor in ipairs(recipeSource.vendors or {}) do
        local vendorName, vendorPlace, vendorFaction = vendor[1], vendor[2], vendor[3]
        if not vendorFaction or vendorFaction == playerFaction then
            table.insert(vendorTexts, "|cffffffff" .. vendorName .. "|r (" .. vendorPlace .. ")")
        end
    end
    if #vendorTexts == 0 then
        return "Bought from a vendor of the other faction - try the auction house."
    end
    return "Sold by " .. table.concat(vendorTexts, " or ") .. ", or on the auction house."
end

-- The game's own "where to get it" text for a recipe in the open window
-- (for example "Vendor: Rikqiz"), as one line without color codes, or nil.
local function GetClientRecipeSourceText(recipeId)
    if not (recipeId and C_TradeSkillUI and C_TradeSkillUI.GetRecipeSourceText) then
        return nil
    end
    local isSuccess, clientSourceText = pcall(C_TradeSkillUI.GetRecipeSourceText, recipeId)
    if not isSuccess or type(clientSourceText) ~= "string" or (issecretvalue and issecretvalue(clientSourceText)) then
        return nil
    end
    -- Strip color codes, textures and line breaks: "Vendor: Rikqiz Zone: ..."
    local plainText = clientSourceText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    plainText = plainText:gsub("|n", ", "):gsub("\n", ", "):gsub("%s+", " "):gsub("^[%s,]+", ""):gsub("[%s,]+$", "")
    if plainText == "" then
        return nil
    end
    return plainText .. "."
end

-- Where to get a recipe you haven't learned: Mentor's own list of vendor and
-- quest recipes first, then the game's source text, then the trainer.
-- recipe is the entry from the open profession window (may be nil).
function professions.GetUnknownRecipeSourceText(recipeName, recipe)
    if RECIPE_SOURCES[recipeName] then
        return professions.GetRecipeSourceText(recipeName)
    end
    local clientSourceText = recipe and GetClientRecipeSourceText(recipe.recipeId)
    if clientSourceText then
        return clientSourceText
    end
    return "Your trainer teaches it."
end

-- A recipe you know that still gives skill (orange first, then yellow), to
-- craft while you don't have the guide's recipe. Guide recipes are preferred.
local DIFFICULTY_RANK = { optimal = 1, medium = 2 }
function professions.GetAlternativeRecipe(recipes, professionName, excludedRecipeName)
    local routeName = professions.FindRouteName(professionName)     -- defined further down
    local isGuideRecipe = {}
    for _, step in ipairs(routeName and CRAFTING_ROUTES[routeName] or {}) do
        isGuideRecipe[step[3]] = true
    end
    local bestRecipe, bestScore
    for _, recipe in ipairs(recipes) do
        local difficultyRank = DIFFICULTY_RANK[recipe.difficulty]
        if recipe.isKnown and difficultyRank and recipe.name ~= excludedRecipeName then
            local recipeScore = difficultyRank * 2 + (isGuideRecipe[recipe.name] and 0 or 1)
            if not bestScore or recipeScore < bestScore then
                bestRecipe, bestScore = recipe, recipeScore
            end
        end
    end
    return bestRecipe
end

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
    return MentorDB and MentorDB.isProfessionLevelingShown ~= false
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
-- Trainers (data in ProfessionTrainers.lua)
--------------------------------------------------------------------------------
local RANK_ORDER = { Apprentice = 1, Journeyman = 2, Expert = 3, Artisan = 4, Master = 5 }
local CAPITAL_CITIES = { "Stormwind", "Ironforge", "Darnassus", "Orgrimmar", "Undercity", "Thunder Bluff" }
local MAX_TRAINERS_SHOWN = 3

-- The rank you need next, from your skill cap (75 -> Journeyman ...), or nil at the top.
function professions.GetNextRank(maximumSkill)
    if not maximumSkill or maximumSkill < 75 then
        return "Apprentice"
    elseif maximumSkill < 150 then
        return "Journeyman"
    elseif maximumSkill < 225 then
        return "Expert"
    elseif maximumSkill < 300 then
        return "Artisan"
    end
    return nil
end

local function IsInCapitalCity(placeText)
    for _, cityName in ipairs(CAPITAL_CITIES) do
        if placeText:find(cityName, 1, true) then
            return true
        end
    end
    return false
end

-- Up to three trainers of your faction (or neutral) that teach the rank you
-- need: { name, place, waypoint }. Trainers in the capital cities come first.
-- Returns nil when Mentor has no trainer list for the profession.
function professions.GetTrainers(professionName, neededRank)
    local routeName = FindRouteName(professionName) or professionName   -- Fishing has no route
    local trainerList = routeName and Mentor.PROFESSION_TRAINERS and Mentor.PROFESSION_TRAINERS[routeName]
    if not trainerList then
        return nil
    end
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
    local neededRankOrder = RANK_ORDER[neededRank or "Apprentice"] or 1
    local matchingTrainers = {}
    for _, trainer in ipairs(trainerList) do
        local trainerFaction, highestRank, trainerName, placeText, waypoint = trainer[1], trainer[2], trainer[3], trainer[4], trainer[5]
        local isForYourFaction = trainerFaction == playerFaction or trainerFaction == "Neutral"
        -- A trainer without a known rank teaches everything except where it
        -- is a starting-area trainer (those are listed as Apprentice).
        local teachesNeededRank = not highestRank or (RANK_ORDER[highestRank] or 1) >= neededRankOrder
        local isOnZephrasIsle = placeText:find("Zephras Isle", 1, true) ~= nil   -- the new-player island
        if isForYourFaction and teachesNeededRank and not isOnZephrasIsle then
            table.insert(matchingTrainers, { name = trainerName, place = placeText, waypoint = waypoint,
                sortKey = (IsInCapitalCity(placeText) and 0 or 1) + (trainerFaction == "Neutral" and 2 or 0) })
        end
    end
    table.sort(matchingTrainers, function(first, second)
        if first.sortKey ~= second.sortKey then
            return first.sortKey < second.sortKey
        end
        return first.name < second.name
    end)
    local shownTrainers = {}
    for trainerIndex = 1, math.min(MAX_TRAINERS_SHOWN, #matchingTrainers) do
        shownTrainers[trainerIndex] = matchingTrainers[trainerIndex]
    end
    return shownTrainers
end

-- How to get a rank that no trainer teaches (Expert and Artisan Cooking,
-- First Aid and Fishing): { lines = { "Book: ... from ... - place (x, y)" },
-- note = "Needs ..." } for your faction, or nil when a trainer teaches it.
function professions.GetRankSource(professionName, neededRank)
    -- Fishing has no leveling route, so also look it up by its own name.
    local routeName = FindRouteName(professionName) or professionName
    local sourcesByRank = routeName and Mentor.PROFESSION_RANK_SOURCES and Mentor.PROFESSION_RANK_SOURCES[routeName]
    local rankSources = sourcesByRank and sourcesByRank[neededRank]
    if not rankSources then
        return nil
    end
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
    local sourceLines = {}
    for _, source in ipairs(rankSources) do
        local sourceFaction, sourceKind, sourceName, npcName, placeText, waypoint = unpack(source)
        if sourceFaction == playerFaction or sourceFaction == "Neutral" then
            local waypointText = waypoint and (" |cffa6a6a6(" .. waypoint:gsub(" ", ", ") .. ")|r") or ""
            local howText = sourceKind == "Quest" and "quest from" or "sold by"
            table.insert(sourceLines, string.format("%s: |cffffffff%s|r, %s |cffffffff%s|r - %s%s",
                sourceKind, sourceName, howText, npcName, placeText, waypointText))
        end
    end
    return { lines = sourceLines, note = rankSources.note }
end

-- "Name - Place (x, y)" for one trainer.
function professions.FormatTrainer(trainer)
    local waypointText = trainer.waypoint and (" |cffa6a6a6(" .. trainer.waypoint:gsub(" ", ", ") .. ")|r") or ""
    return "|cffffffff" .. trainer.name .. "|r - " .. trainer.place .. waypointText
end

-- One line for the Journey tab's trainer hint: "Lucan Cordell - Mage Quarter, Stormwind (43, 64)".
function professions.GetTrainerHint(professionName, maximumSkill)
    local neededRank = professions.GetNextRank(maximumSkill)
    if not neededRank then
        return nil
    end
    -- Expert and Artisan of the secondary professions come from a book or a quest.
    local rankSource = professions.GetRankSource(professionName, neededRank)
    if rankSource and rankSource.lines[1] then
        return rankSource.lines[1]
    end
    local trainers = professions.GetTrainers(professionName, neededRank)
    if trainers == nil then
        return "Ask a city guard - they mark the trainer on your map."
    end
    if #trainers == 0 then
        return nil
    end
    return "Trainer: " .. professions.FormatTrainer(trainers[1])
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

--------------------------------------------------------------------------------
-- Materials and tools
--------------------------------------------------------------------------------
local MAX_MATERIAL_LINES = 5
local MAX_CRAFTABLE_LINES = 3
local DIFFICULTY_ORDER = { optimal = 1, medium = 2, easy = 3, trivial = 4 }

-- Tools a profession needs in your bags: groups of { itemId, "name" }
-- alternatives (any one of them works - a better enchanting rod also counts
-- for the older recipes), with fromSkill when the tool is only needed from
-- that skill on.
local PROFESSION_TOOLS = {
    Mining        = { { { 2901, "Mining Pick" } }, where = "Trade Supplies and blacksmithing vendors" },
    Skinning      = { { { 7005, "Skinning Knife" } }, where = "Trade Supplies and leatherworking vendors" },
    Blacksmithing = { { { 5956, "Blacksmith Hammer" } }, where = "Trade Supplies and blacksmithing vendors" },
    Engineering   = { { { 6219, "Arclight Spanner" } }, { { 10498, "Gyromatic Micro-Adjustor" }, fromSkill = 175 },
        where = "the Spanner from Trade Supplies vendors; you make the Micro-Adjustor yourself (skill 175)" },
    Enchanting    = { { { 16207, "Runed Arcanite Rod" }, { 11145, "Runed Truesilver Rod" }, { 11130, "Runed Golden Rod" },
        { 6339, "Runed Silver Rod" }, { 6218, "Runed Copper Rod" } },
        where = "you make the rods yourself (Copper Rod first) - newer recipes need a better rod" },
    Fishing       = { { { "FISHING_POLE", "a fishing pole" } }, where = "Fishing Supplies vendors and fishing trainers" },
}
local WEAPON_ITEM_CLASS_FOR_TOOLS = 2
local FISHING_POLE_SUBCLASS_FOR_TOOLS = 20

local function GetItemCountAnywhere(itemId)
    if C_Item and C_Item.GetItemCount then
        local isSuccess, itemCount = pcall(C_Item.GetItemCount, itemId)
        return isSuccess and itemCount or 0
    end
    return GetItemCount and GetItemCount(itemId) or 0
end

local function HasFishingPole()
    local mainHandLink = GetInventoryItemLink("player", 16)
    if mainHandLink and Mentor.GetProfessionToolName and Mentor.GetProfessionToolName(mainHandLink) == "Fishing" then
        return true
    end
    if not (C_Container and C_Container.GetContainerItemLink) then
        return false
    end
    for bagIndex = 0, 4 do
        for slotIndex = 1, C_Container.GetContainerNumSlots(bagIndex) or 0 do
            local itemLink = C_Container.GetContainerItemLink(bagIndex, slotIndex)
            if itemLink and Mentor.GetProfessionToolName and Mentor.GetProfessionToolName(itemLink) == "Fishing" then
                return true
            end
        end
    end
    return false
end

-- "Tools: Skinning Knife |cff40ff40yes|r" lines for a profession, or nil
-- when it needs none. Second value: true when a needed tool is missing.
function professions.GetToolLines(professionName, skillLevel)
    local toolGroups = PROFESSION_TOOLS[professionName]
    if not toolGroups then
        return nil, false
    end
    local toolLines, isAnyMissing = {}, false
    for _, alternatives in ipairs(toolGroups) do
        local isNeededAtYourSkill = (alternatives.fromSkill or 0) <= (skillLevel or 0)
        local ownedName
        for _, tool in ipairs(isNeededAtYourSkill and alternatives or {}) do
            local hasTool = tool[1] == "FISHING_POLE" and HasFishingPole() or (tool[1] ~= "FISHING_POLE" and GetItemCountAnywhere(tool[1]) > 0)
            if hasTool then
                ownedName = tool[2]
                break
            end
        end
        if not isNeededAtYourSkill then
            -- not needed yet at your skill: not listed
        elseif ownedName then
            table.insert(toolLines, "|cff40ff40+|r " .. ownedName)
        else
            isAnyMissing = true
            local wantedName = alternatives[#alternatives][2]   -- the first one you can get
            table.insert(toolLines, "|cffff6666- " .. wantedName .. " missing|r")
        end
    end
    if #toolLines == 0 then
        return nil, false
    end
    if isAnyMissing then
        table.insert(toolLines, "|cffa6a6a6Get it: " .. toolGroups.where .. ".|r")
    end
    return toolLines, isAnyMissing
end

-- The reagents of a recipe: { { itemId, quantity } }.
local function GetRecipeReagents(recipe)
    local reagents = {}
    if recipe.recipeId and C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        local isSuccess, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipe.recipeId, false)
        if isSuccess and type(schematic) == "table" then
            for _, reagentSlot in ipairs(schematic.reagentSlotSchematics or {}) do
                local firstReagent = reagentSlot.reagents and reagentSlot.reagents[1]
                if firstReagent and firstReagent.itemID then
                    table.insert(reagents, { firstReagent.itemID, reagentSlot.quantityRequired or 1 })
                end
            end
        end
    elseif recipe.recipeIndex and GetTradeSkillNumReagents and GetTradeSkillReagentItemLink then
        for reagentIndex = 1, GetTradeSkillNumReagents(recipe.recipeIndex) or 0 do
            local reagentLink = GetTradeSkillReagentItemLink(recipe.recipeIndex, reagentIndex)
            local _, _, quantity = GetTradeSkillReagentInfo(recipe.recipeIndex, reagentIndex)
            local itemId = reagentLink and tonumber(reagentLink:match("item:(%d+)"))
            if itemId then
                table.insert(reagents, { itemId, quantity or 1 })
            end
        end
    end
    return reagents
end

-- What you carry for this profession: { { itemId, count, recipeCount } }
-- (most first), and the recipes that still give skill that you can make
-- right now: { { recipe, craftableCount } } (hardest first).
function professions.GetMaterialsAndCraftable(recipes)
    local materialsById, craftable = {}, {}
    for _, recipe in ipairs(recipes) do
        if recipe.isKnown then
            local smallestCraftableCount
            for _, reagent in ipairs(GetRecipeReagents(recipe)) do
                local itemId, quantity = reagent[1], reagent[2]
                local carriedCount = GetItemCountAnywhere(itemId)
                if carriedCount > 0 then
                    materialsById[itemId] = materialsById[itemId] or { itemId = itemId, count = carriedCount, recipeCount = 0 }
                    materialsById[itemId].recipeCount = materialsById[itemId].recipeCount + 1
                end
                local craftsFromThis = math.floor(carriedCount / math.max(1, quantity))
                smallestCraftableCount = math.min(smallestCraftableCount or craftsFromThis, craftsFromThis)
            end
            if (smallestCraftableCount or 0) > 0 and recipe.difficulty ~= "trivial" then
                table.insert(craftable, { recipe = recipe, craftableCount = smallestCraftableCount })
            end
        end
    end
    local materials = {}
    for _, material in pairs(materialsById) do
        table.insert(materials, material)
    end
    table.sort(materials, function(first, second) return first.count > second.count end)
    table.sort(craftable, function(first, second)
        local firstOrder = DIFFICULTY_ORDER[first.recipe.difficulty] or 5
        local secondOrder = DIFFICULTY_ORDER[second.recipe.difficulty] or 5
        if firstOrder ~= secondOrder then
            return firstOrder < secondOrder
        end
        return first.craftableCount > second.craftableCount
    end)
    return materials, craftable
end

local function GetItemNameAndIcon(itemId)
    local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local isSuccess, itemName, _, _, _, _, _, _, _, _, itemIcon = pcall(getItemInfo, itemId)
    if isSuccess and itemName then
        return itemName, itemIcon
    end
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemId)
    end
    return "item " .. itemId, nil
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
-- True after the player closed the panel with X, until the profession window opens again.
local isPanelDismissed = false
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
    -- A WoW window ("Mentor" in the title bar, Mentor's portrait, the
    -- profession and skill beside it) or Mentor's own box.
    local nativeWindow = Mentor.NativeFrame and Mentor.NativeFrame.CreateWindow("MentorProfessionPanel", UIParent, "Mentor")
    panel = nativeWindow or CreateFrame("Frame", "MentorProfessionPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetFrameStrata("HIGH")
    panel.isNativeWindow = nativeWindow and true or false
    if nativeWindow then
        panel.title = Mentor.NativeFrame.CreateSubtitle(nativeWindow, "GameFontNormal")
        -- X: stay closed until the profession window is opened again, even
        -- when bag changes or new recipes would refresh the panel.
        Mentor.NativeFrame.SetCloseAction(nativeWindow, function()
            isPanelDismissed = true
            panel:Hide()
        end)
    else
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
    end
    panel.levelHeader = CreateTextLine(panel, "GameFontNormalSmall")
    panel.levelHeader:SetText("Level up")
    panel.levelRow = CreateRecipeRow()
    panel.levelText = CreateTextLine(panel)
    panel.nextText = CreateTextLine(panel, "GameFontDisableSmall")
    panel.alternativeHeader = CreateTextLine(panel, "GameFontDisableSmall")
    panel.alternativeRow = CreateRecipeRow()
    panel.upgradeHeader = CreateTextLine(panel, "GameFontNormalSmall")
    panel.upgradeHeader:SetText("Upgrades you can make")
    panel.noUpgradesText = CreateTextLine(panel, "GameFontDisableSmall")
    panel.noUpgradesText:SetText("None of your recipes is an upgrade right now.")
    panel.materialsHeader = CreateTextLine(panel, "GameFontNormalSmall")
    panel.materialsHeader:SetText("Your materials")
    panel.materialsText = CreateTextLine(panel)
    panel.toolsHeader = CreateTextLine(panel, "GameFontNormalSmall")
    panel.toolsHeader:SetText("Tools")
    panel.toolsText = CreateTextLine(panel)
    panel.trainerHeader = CreateTextLine(panel, "GameFontNormalSmall")
    panel.trainerLines = {}
    for trainerIndex = 1, MAX_TRAINERS_SHOWN do
        panel.trainerLines[trainerIndex] = CreateTextLine(panel)
    end
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
    if not (isLevelingShown or areUpgradesShown) or not professionWindow or isPanelDismissed then
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
        -- The window can list the same recipe more than once (a learned
        -- copy and an unlearned variant): the learned one wins.
        local earlierRecipe = recipesByName[recipe.name]
        if not earlierRecipe or (recipe.isKnown and not earlierRecipe.isKnown) then
            recipesByName[recipe.name] = recipe
        end
    end

    -- Under the portrait in the WoW window, under the title otherwise.
    local verticalOffset = panel.isNativeWindow and -(Mentor.NativeFrame.CONTENT_TOP - 4) or (-PANEL_PADDING - 22)
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
            local isKnown = recipe and recipe.isKnown
            local alternative
            if not isKnown then
                -- Where to get it, and what you can craft meanwhile. The window
                -- also lists unlearned recipes that come from a vendor or a
                -- drop, so being in the window doesn't mean the trainer has it.
                local sourceText = professions.GetUnknownRecipeSourceText(step.recipe, recipe)
                panel.levelText:SetText("|cffff9933You don't know it yet.|r " .. sourceText)
                alternative = professions.GetAlternativeRecipe(recipes, professionName, step.recipe)
            elseif recipe.difficulty == "trivial" then
                panel.levelText:SetText("|cffa6a6a6Grey: it no longer gives skill - move on to the next step.|r")
                alternative = professions.GetAlternativeRecipe(recipes, professionName, step.recipe)
            else
                panel.levelText:SetText(string.format("Craft about %d to reach skill %d.", step.craftsLeft or 1, step.toSkill))
            end
            Place(panel.levelText, (panel.levelText:GetStringHeight() or 12) + 4)
            if alternative then
                panel.alternativeHeader:SetText("Meanwhile you can craft:")
                Place(panel.alternativeHeader, 14)
                panel.alternativeRow.recipe = alternative
                panel.alternativeRow.itemLink = alternative.itemLink
                panel.alternativeRow.icon:SetTexture(alternative.icon or 134400)
                panel.alternativeRow.nameText:SetText((DIFFICULTY_COLORS[alternative.difficulty] or "|cffffffff") .. alternative.name .. "|r")
                panel.alternativeRow.valueText:SetText("")
                Place(panel.alternativeRow, ROW_HEIGHT + 2)
            else
                panel.alternativeHeader:Hide()
                panel.alternativeRow:Hide()
            end
            if step.nextRecipe then
                panel.nextText:SetText(string.format("Then: %s (to %d)", step.nextRecipe, step.nextToSkill))
                Place(panel.nextText, 16)
            else
                panel.nextText:Hide()
            end
        else
            panel.levelRow:Hide()
            panel.nextText:Hide()
            panel.alternativeHeader:Hide()
            panel.alternativeRow:Hide()
            panel.levelText:SetText(step and step.kind == "gather"
                and string.format("%s in %s (to %d).", step.what, step.where, step.toSkill)
                or "|cffa6a6a6No leveling route for this profession.|r")
            Place(panel.levelText, (panel.levelText:GetStringHeight() or 12) + 4)
        end
    else
        for _, levelRegion in ipairs({ panel.levelHeader, panel.levelRow, panel.levelText, panel.nextText,
            panel.alternativeHeader, panel.alternativeRow }) do
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
    -- What you carry for this profession, what you can craft right now, and
    -- its tools (with Profession leveling on).
    panel.materialsHeader:Hide()
    panel.materialsText:Hide()
    panel.toolsHeader:Hide()
    panel.toolsText:Hide()
    if isLevelingShown then
        local materials, craftable = professions.GetMaterialsAndCraftable(recipes)
        local materialLines = {}
        for craftableIndex = 1, math.min(MAX_CRAFTABLE_LINES, #craftable) do
            local craftableRecipe = craftable[craftableIndex]
            table.insert(materialLines, string.format("Craft now: %s%s|r x%d",
                DIFFICULTY_COLORS[craftableRecipe.recipe.difficulty] or "|cffffffff", craftableRecipe.recipe.name,
                craftableRecipe.craftableCount))
        end
        for materialIndex = 1, math.min(MAX_MATERIAL_LINES, #materials) do
            local material = materials[materialIndex]
            local materialName, materialIcon = GetItemNameAndIcon(material.itemId)
            table.insert(materialLines, string.format("%s%s x%d |cffa6a6a6(%d recipe%s)|r",
                materialIcon and ("|T" .. materialIcon .. ":14|t ") or "", materialName, material.count,
                material.recipeCount, material.recipeCount == 1 and "" or "s"))
        end
        if #materials > MAX_MATERIAL_LINES then
            table.insert(materialLines, string.format("|cffa6a6a6+%d more|r", #materials - MAX_MATERIAL_LINES))
        end
        verticalOffset = verticalOffset - 6
        Place(panel.materialsHeader, 16)
        panel.materialsText:SetText(#materialLines > 0 and table.concat(materialLines, "\n")
            or "|cffa6a6a6Nothing in your bags for your recipes yet.|r")
        Place(panel.materialsText, (panel.materialsText:GetStringHeight() or 12) + 4)
        local toolLines = professions.GetToolLines(professionName, skillLevel)
        if toolLines then
            verticalOffset = verticalOffset - 6
            Place(panel.toolsHeader, 16)
            panel.toolsText:SetText(table.concat(toolLines, "\n"))
            Place(panel.toolsText, (panel.toolsText:GetStringHeight() or 12) + 4)
        end
    end

    -- Trainers for the next rank (with Profession leveling on).
    local nextRank = professions.GetNextRank(maximumSkill)
    local trainers = isLevelingShown and nextRank and professions.GetTrainers(professionName, nextRank)
    for _, trainerLine in ipairs(panel.trainerLines) do
        trainerLine:Hide()
    end
    panel.trainerHeader:Hide()
    local rankSource = isLevelingShown and nextRank and professions.GetRankSource(professionName, nextRank)
    if rankSource then
        -- No trainer teaches this rank: where the book or quest is.
        verticalOffset = verticalOffset - 6
        panel.trainerHeader:SetText(string.format("How to get %s (skill cap %d)", nextRank, (RANK_ORDER[nextRank] or 1) * 75))
        Place(panel.trainerHeader, 16)
        local shownLines = {}
        for _, sourceLine in ipairs(rankSource.lines) do
            table.insert(shownLines, sourceLine)
        end
        if rankSource.note then
            table.insert(shownLines, "|cffa6a6a6" .. rankSource.note .. "|r")
        end
        for lineIndex = 1, math.min(#shownLines, #panel.trainerLines) do
            local sourceLine = panel.trainerLines[lineIndex]
            sourceLine:SetText(shownLines[lineIndex])
            Place(sourceLine, (sourceLine:GetStringHeight() or 12) + 3)
        end
    elseif isLevelingShown and nextRank then
        verticalOffset = verticalOffset - 6
        panel.trainerHeader:SetText(string.format("Trainers for %s (skill cap %d)", nextRank, (RANK_ORDER[nextRank] or 1) * 75))
        Place(panel.trainerHeader, 16)
        if trainers == nil then
            panel.trainerLines[1]:SetText("Ask a city guard - they mark the trainer on your map.")
            Place(panel.trainerLines[1], (panel.trainerLines[1]:GetStringHeight() or 12) + 3)
        else
            for trainerIndex, trainer in ipairs(trainers) do
                local trainerLine = panel.trainerLines[trainerIndex]
                trainerLine:SetText(professions.FormatTrainer(trainer))
                Place(trainerLine, (trainerLine:GetStringHeight() or 12) + 3)
            end
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
    if eventName == "TRADE_SKILL_SHOW" then
        isPanelDismissed = false      -- a newly opened profession window shows the panel again
    end
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
-- Kept here, not as a field on Blizzard's frame: writing fields into
-- Blizzard's frames can spread "taint" and block their secure actions.
local hookedWindows = {}
local function HookWindow(windowFrame)
    if windowFrame and not hookedWindows[windowFrame] then
        -- Run a moment later, outside Blizzard's own show/hide code: WoW
        -- moves its windows around (for example when the bank opens beside
        -- the profession window), and Mentor's code running in the middle of
        -- that could make WoW block right-clicking bag items afterwards.
        local function RunAfterBlizzard(callback)
            if C_Timer then
                C_Timer.After(0, function() pcall(callback) end)
            else
                pcall(callback)
            end
        end
        windowFrame:HookScript("OnShow", function()
            RunAfterBlizzard(function()
                isPanelDismissed = false
                professions.RefreshPanel()
            end)
        end)
        windowFrame:HookScript("OnHide", function()
            RunAfterBlizzard(function()
                if panel and not (GetProfessionWindow() and GetProfessionWindow():IsShown()) then
                    panel:Hide()
                end
            end)
        end)
        hookedWindows[windowFrame] = true
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

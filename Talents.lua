--------------------------------------------------------------------------------
-- Mentor - Talents.lua
-- Reads the real talent tree from the game, works out your spec and decides
-- which talent point to spend next.
--
-- WoW Forever runs on the modern client: talents live in the Traits system
-- (C_Traits), one tree per class with the three spec trees side by side. The
-- nodes are split into the three spec trees by their horizontal position and
-- matched to spec names using the talent names in Data.lua. Classic clients
-- (GetTalentInfo) are still supported as a fallback.
--
-- Spec:
--   * points spent  -> the spec tree with the most points
--   * no points yet -> the spec you picked in the Mentor window, otherwise the
--                      class' recommended leveling spec (shown as a suggestion)
--
-- Next talent:
--   1. the next learnable step of the build, in the build's own order
--   2. if none, and the main tree is below what the build plans for it,
--      the best learnable main-tree talent
--   3. anything learnable
--------------------------------------------------------------------------------

local _, Mentor = ...

local POINTS_PER_TIER = 5         -- each talent row needs 5 more points in that tree
local FIRST_TALENT_LEVEL = 10     -- first talent point arrives at level 10
local SPEC_TREE_COUNT = 3

local function IsReadable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function GetSpellNameAndIcon(spellId)
    if C_Spell and C_Spell.GetSpellInfo then
        local success, spellInfo = pcall(C_Spell.GetSpellInfo, spellId)
        if success and type(spellInfo) == "table" then
            return spellInfo.name, spellInfo.iconID
        end
    end
    if GetSpellInfo then
        local spellName, _, spellIcon = GetSpellInfo(spellId)
        return spellName, spellIcon
    end
    return nil, nil
end

-- Creates an empty tree record.
local function NewTree(treeIndex, treeName)
    return {
        index = treeIndex, name = treeName, pointsSpent = 0,
        talents = {}, talentsByName = {}, talentsByPosition = {},
    }
end

local function AddTalentToTree(tree, talent)
    talent.treeIndex = tree.index
    table.insert(tree.talents, talent)
    tree.talentsByName[talent.name:lower()] = talent
    tree.pointsSpent = tree.pointsSpent + talent.rank
end

--------------------------------------------------------------------------------
-- Modern clients (WoW Forever): Traits
--------------------------------------------------------------------------------
local function GetActiveTraitConfigId()
    local specInfo = C_SpecializationInfo
    if specInfo and specInfo.GetCombatConfigIDForSpecGroup and specInfo.GetActiveSpecGroup then
        local groupOk, specGroup = pcall(specInfo.GetActiveSpecGroup)
        if groupOk and IsReadable(specGroup) and specGroup then
            local configOk, configId = pcall(specInfo.GetCombatConfigIDForSpecGroup, specGroup)
            if configOk and IsReadable(configId) and configId then
                return configId
            end
        end
    end
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local configOk, configId = pcall(C_ClassTalents.GetActiveConfigID)
        if configOk and IsReadable(configId) and configId then
            return configId
        end
    end
    return nil
end

local function GetNodeRank(nodeInfo)
    -- currentRank includes clicked-but-not-applied ranks, so advice follows clicks.
    for _, fieldName in ipairs({ "currentRank", "ranksPurchased", "activeRank" }) do
        local rankValue = nodeInfo[fieldName]
        if IsReadable(rankValue) and tonumber(rankValue) then
            return tonumber(rankValue)
        end
    end
    return 0
end

-- Reads every visible talent node: { name, icon, nodeId, posX, posY, rank,
-- maxRank, canPurchase, isAvailable }. Returns nodes, unspentPoints.
local function ReadTraitNodes()
    if not (C_Traits and C_Traits.GetConfigInfo) then
        return nil
    end
    local configId = GetActiveTraitConfigId()
    if not configId then
        return nil
    end
    local configOk, configInfo = pcall(C_Traits.GetConfigInfo, configId)
    if not configOk or type(configInfo) ~= "table" or type(configInfo.treeIDs) ~= "table" or not configInfo.treeIDs[1] then
        return nil
    end
    local treeId = configInfo.treeIDs[1]
    local nodesOk, nodeIds = pcall(C_Traits.GetTreeNodes, treeId)
    if not nodesOk or type(nodeIds) ~= "table" then
        return nil
    end

    local talentNodes = {}
    for _, nodeId in ipairs(nodeIds) do
        local nodeOk, nodeInfo = pcall(C_Traits.GetNodeInfo, configId, nodeId)
        if nodeOk and type(nodeInfo) == "table" and IsReadable(nodeInfo.ID) and nodeInfo.ID ~= 0
            and nodeInfo.isVisible ~= false then
            local entryId = (nodeInfo.activeEntry and nodeInfo.activeEntry.entryID)
                or (nodeInfo.entryIDs and nodeInfo.entryIDs[1])
            local entryOk, entryInfo = false, nil
            if entryId then
                entryOk, entryInfo = pcall(C_Traits.GetEntryInfo, configId, entryId)
            end
            local definitionInfo
            if entryOk and type(entryInfo) == "table" and entryInfo.definitionID then
                local definitionOk, definitionResult = pcall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
                if definitionOk and type(definitionResult) == "table" then
                    definitionInfo = definitionResult
                end
            end
            local spellId = definitionInfo and definitionInfo.spellID
            if spellId and IsReadable(spellId) then
                local spellName, spellIcon = GetSpellNameAndIcon(spellId)
                local talentName = (definitionInfo.overrideName ~= "" and definitionInfo.overrideName) or spellName
                if talentName then
                    table.insert(talentNodes, {
                        name = talentName,
                        icon = definitionInfo.overrideIcon or spellIcon,
                        spellId = spellId,
                        nodeId = nodeInfo.ID,
                        posX = tonumber(nodeInfo.posX) or 0,
                        posY = tonumber(nodeInfo.posY) or 0,
                        rank = GetNodeRank(nodeInfo),
                        maxRank = tonumber(nodeInfo.maxRanks) or 1,
                        canPurchase = nodeInfo.canPurchaseRank == true,
                        isAvailable = nodeInfo.isAvailable ~= false and nodeInfo.meetsEdgeRequirements ~= false,
                    })
                end
            end
        end
    end

    local unspentPoints
    if C_Traits.GetTreeCurrencyInfo then
        local currencyOk, currencies = pcall(C_Traits.GetTreeCurrencyInfo, configId, treeId, false)
        local firstCurrency = currencyOk and type(currencies) == "table" and currencies[1]
        if firstCurrency and IsReadable(firstCurrency.quantity) then
            unspentPoints = firstCurrency.quantity
        end
    end
    return talentNodes, unspentPoints
end

-- Splits nodes into the three spec trees using the two widest horizontal gaps
-- (the trees are drawn side by side). Returns a list of node lists, left to right.
local function SplitNodesIntoColumns(talentNodes)
    local distinctPositions, seenPositions = {}, {}
    for _, talentNode in ipairs(talentNodes) do
        if not seenPositions[talentNode.posX] then
            seenPositions[talentNode.posX] = true
            table.insert(distinctPositions, talentNode.posX)
        end
    end
    table.sort(distinctPositions)
    if #distinctPositions < SPEC_TREE_COUNT then
        return { talentNodes }
    end
    -- Find the two biggest gaps between neighbouring positions.
    local gaps = {}
    for positionIndex = 1, #distinctPositions - 1 do
        table.insert(gaps, { size = distinctPositions[positionIndex + 1] - distinctPositions[positionIndex],
                             splitAfter = distinctPositions[positionIndex] })
    end
    table.sort(gaps, function(first, second) return first.size > second.size end)
    local firstSplit = math.min(gaps[1].splitAfter, gaps[2].splitAfter)
    local secondSplit = math.max(gaps[1].splitAfter, gaps[2].splitAfter)
    local columns = { {}, {}, {} }
    for _, talentNode in ipairs(talentNodes) do
        local columnIndex = (talentNode.posX <= firstSplit and 1) or (talentNode.posX <= secondSplit and 2) or 3
        table.insert(columns[columnIndex], talentNode)
    end
    return columns
end

-- Decides which spec each column is, using the talent names in the builds:
-- a column that contains a spec's main-tree talents is that spec's tree.
local function MatchColumnsToSpecs(columns, classData)
    local columnForSpec = {}
    if #columns ~= SPEC_TREE_COUNT then
        return nil
    end
    local usedColumns = {}
    for specNumber, specData in ipairs(classData.specs) do
        local mainTreeNames = {}
        for _, buildEntry in ipairs(specData.build) do
            if buildEntry[1] == specNumber then
                mainTreeNames[buildEntry[2]:lower()] = true
            end
        end
        local bestColumn, bestMatches = nil, 0
        for columnIndex, columnNodes in ipairs(columns) do
            local matchCount = 0
            for _, talentNode in ipairs(columnNodes) do
                if mainTreeNames[talentNode.name:lower()] then
                    matchCount = matchCount + 1
                end
            end
            if matchCount > bestMatches then
                bestColumn, bestMatches = columnIndex, matchCount
            end
        end
        -- Two or more matching names is enough evidence.
        if bestColumn and bestMatches >= 2 and not usedColumns[bestColumn] then
            columnForSpec[specNumber] = bestColumn
            usedColumns[bestColumn] = true
        end
    end
    -- Specs without enough evidence keep their left-to-right position.
    for specNumber = 1, SPEC_TREE_COUNT do
        if not columnForSpec[specNumber] and not usedColumns[specNumber] then
            columnForSpec[specNumber] = specNumber
            usedColumns[specNumber] = true
        end
    end
    return columnForSpec
end

local function ReadTraitTrees(classData)
    local talentNodes, unspentPoints = ReadTraitNodes()
    if not talentNodes or #talentNodes == 0 then
        return nil
    end
    local columns = SplitNodesIntoColumns(talentNodes)
    local columnForSpec = MatchColumnsToSpecs(columns, classData)
    local trees = {}
    if columnForSpec then
        for specNumber = 1, SPEC_TREE_COUNT do
            trees[specNumber] = NewTree(specNumber, classData.specs[specNumber].name)
            local columnNodes = columns[columnForSpec[specNumber]] or {}
            -- Rows: rank the distinct vertical positions inside this tree.
            local distinctRows, seenRows = {}, {}
            for _, talentNode in ipairs(columnNodes) do
                if not seenRows[talentNode.posY] then
                    seenRows[talentNode.posY] = true
                    table.insert(distinctRows, talentNode.posY)
                end
            end
            table.sort(distinctRows)
            local tierForRow = {}
            for rowIndex, rowPosition in ipairs(distinctRows) do
                tierForRow[rowPosition] = rowIndex
            end
            for _, talentNode in ipairs(columnNodes) do
                talentNode.tier = tierForRow[talentNode.posY] or 1
                talentNode.column = talentNode.posX
                AddTalentToTree(trees[specNumber], talentNode)
            end
        end
    else
        -- Could not split the tree: treat it as one tree.
        trees[1] = NewTree(1, "Talents")
        for _, talentNode in ipairs(talentNodes) do
            talentNode.tier, talentNode.column = 1, talentNode.posX
            AddTalentToTree(trees[1], talentNode)
        end
    end
    return trees, unspentPoints, "traits"
end

--------------------------------------------------------------------------------
-- Classic clients: GetTalentInfo
--------------------------------------------------------------------------------
local function GetClassicTabName(tabIndex)
    local tabInfo = { pcall(GetTalentTabInfo, tabIndex) }
    if not tabInfo[1] then
        return nil
    end
    for valueIndex = 2, #tabInfo do
        if type(tabInfo[valueIndex]) == "string" then
            return tabInfo[valueIndex]
        end
    end
    return nil
end

local function ReadClassicTrees()
    if not (GetNumTalentTabs and GetTalentInfo) then
        return nil
    end
    local trees = {}
    for tabIndex = 1, GetNumTalentTabs() or 0 do
        local tree = NewTree(tabIndex, GetClassicTabName(tabIndex) or ("Tree " .. tabIndex))
        for talentIndex = 1, GetNumTalents(tabIndex) or 0 do
            local talentName, iconTexture, tier, column, currentRank, maxRank = GetTalentInfo(tabIndex, talentIndex)
            if talentName then
                local talent = { index = talentIndex, name = talentName, icon = iconTexture,
                                 tier = tier or 1, column = column or 1,
                                 rank = currentRank or 0, maxRank = maxRank or 1 }
                tree.talentsByPosition[talent.tier] = tree.talentsByPosition[talent.tier] or {}
                tree.talentsByPosition[talent.tier][talent.column] = talent
                AddTalentToTree(tree, talent)
            end
        end
        trees[tabIndex] = tree
    end
    local unspentPoints = UnitCharacterPoints and UnitCharacterPoints("player")
    return trees, (type(unspentPoints) == "number") and unspentPoints or nil, "classic"
end

--------------------------------------------------------------------------------
-- Learnability
--------------------------------------------------------------------------------
local function ArePrerequisitesMet(tree, talent)
    if not GetTalentPrereqs or not talent.index then
        return true
    end
    local prerequisiteInfo = { pcall(GetTalentPrereqs, tree.index, talent.index) }
    if not prerequisiteInfo[1] then
        return true
    end
    for valueIndex = 2, #prerequisiteInfo, 3 do
        local requiredTier, requiredColumn = prerequisiteInfo[valueIndex], prerequisiteInfo[valueIndex + 1]
        if requiredTier and requiredColumn then
            local requiredTalent = tree.talentsByPosition[requiredTier]
                and tree.talentsByPosition[requiredTier][requiredColumn]
            if requiredTalent and requiredTalent.rank < requiredTalent.maxRank then
                return false
            end
        end
    end
    return true
end

-- True when one more point can go into this talent right now (or could, once
-- you have a free point).
function Mentor.IsTalentLearnable(tree, talent)
    if talent.rank >= talent.maxRank then
        return false
    end
    if talent.nodeId then
        -- Traits: the game decides. With a free point, canPurchase is exact.
        -- Without one, canPurchase is always false, so use "available"
        -- (prerequisites and row requirements met).
        if tree.hasFreePoints then
            return talent.canPurchase
        end
        return talent.isAvailable
    end
    if tree.pointsSpent < (talent.tier - 1) * POINTS_PER_TIER then
        return false
    end
    return ArePrerequisitesMet(tree, talent)
end

--------------------------------------------------------------------------------
-- Points and spec
--------------------------------------------------------------------------------
function Mentor.GetTotalPointsSpent(trees)
    local totalPoints = 0
    for _, tree in ipairs(trees) do
        totalPoints = totalPoints + tree.pointsSpent
    end
    return totalPoints
end

local function EstimateUnspentPoints(trees)
    local earnedPoints = math.max(0, (UnitLevel("player") or 1) - FIRST_TALENT_LEVEL + 1)
    return math.max(0, earnedPoints - Mentor.GetTotalPointsSpent(trees))
end

function Mentor.FindTreeForSpec(trees, classData, specNumber)
    local specData = classData.specs[specNumber]
    if specData then
        for _, tree in ipairs(trees) do
            if tree.name:lower() == specData.name:lower() then
                return tree
            end
        end
    end
    return trees[specNumber]
end

local function FindSpecNumberForTree(tree, classData)
    for specNumber, specData in ipairs(classData.specs) do
        if specData.name:lower() == tree.name:lower() then
            return specNumber
        end
    end
    return tree.index
end

-- Returns specNumber, howItWasFound:
--   "talents" (from your points), "chosen" (picked in Mentor), "suggested" (leveling default)
-- How well the spent points fit one spec's build: points that the build asks
-- for count as matched, points in talents the build never takes count as stray.
local function ScoreBuildAgainstSpentPoints(trees, specData)
    local wantedRankByTalent = {}
    for _, buildEntry in ipairs(specData.build) do
        local talentKey = buildEntry[2]:lower()
        wantedRankByTalent[talentKey] = math.max(wantedRankByTalent[talentKey] or 0, buildEntry[3])
    end
    local matchedPoints, strayPoints = 0, 0
    for _, tree in ipairs(trees) do
        for talentKey, talent in pairs(tree.talentsByName) do
            if (talent.rank or 0) > 0 then
                local wantedRank = wantedRankByTalent[talentKey] or 0
                matchedPoints = matchedPoints + math.min(talent.rank, wantedRank)
                strayPoints = strayPoints + math.max(0, talent.rank - wantedRank)
            end
        end
    end
    return matchedPoints, strayPoints
end

-- Picks the spec. Spent points decide, but by comparing them with each build
-- rather than by "most points in one tree": several guides start in another
-- tree (Frost Mage takes Arcane talents first), so counting trees would flip
-- a new Frost Mage over to Arcane after the first point.
function Mentor.DetectSpec(trees, classData)
    local chosenSpec = MentorDB and MentorDB.chosenSpec
    if chosenSpec and not classData.specs[chosenSpec] then chosenSpec = nil end

    -- The spec you click always wins, however your points are spent (you may
    -- be respeccing, or want to see another spec's gear and guide).
    if chosenSpec then
        return chosenSpec, "chosen"
    end

    local totalSpent = 0
    for _, tree in ipairs(trees) do totalSpent = totalSpent + (tree.pointsSpent or 0) end
    if totalSpent == 0 or #trees < 2 then
        return classData.defaultSpec, "suggested"
    end

    local bestSpec, bestScore
    for specNumber, specData in ipairs(classData.specs) do
        local matchedPoints, strayPoints = ScoreBuildAgainstSpentPoints(trees, specData)
        local score = matchedPoints - strayPoints
        if not bestScore or score > bestScore then bestSpec, bestScore = specNumber, score end
    end
    return bestSpec, "talents"
end

--------------------------------------------------------------------------------
-- Build progress and the next point
--------------------------------------------------------------------------------
function Mentor.EvaluateBuild(trees, classData, specNumber)
    local specData = classData.specs[specNumber]
    local steps = {}
    for _, buildEntry in ipairs(specData.build) do
        local treeNumber, talentName, targetRank = buildEntry[1], buildEntry[2], buildEntry[3]
        local tree = Mentor.FindTreeForSpec(trees, classData, treeNumber)
        local talent = tree and tree.talentsByName[talentName:lower()]
        if not talent then
            -- The single-tree fallback (or a moved talent): look in every tree.
            for _, otherTree in ipairs(trees) do
                if otherTree.talentsByName[talentName:lower()] then
                    tree, talent = otherTree, otherTree.talentsByName[talentName:lower()]
                    break
                end
            end
        end
        local step = {
            treeNumber = treeNumber, talentName = talentName, tree = tree, talent = talent,
            targetRank = talent and math.min(targetRank, talent.maxRank) or targetRank,
        }
        if not talent then
            step.status = "missing"
        elseif talent.rank >= step.targetRank then
            step.status = "done"
        else
            step.status = "waiting"
            step.isLearnable = Mentor.IsTalentLearnable(tree, talent)
        end
        table.insert(steps, step)
    end
    return steps
end

local function GetPlannedMainTreePoints(steps, mainTree)
    local highestTargetByTalent = {}
    for _, step in ipairs(steps) do
        if step.tree == mainTree then
            local talentKey = step.talentName:lower()
            highestTargetByTalent[talentKey] = math.max(highestTargetByTalent[talentKey] or 0, step.targetRank)
        end
    end
    local plannedPoints = 0
    for _, targetRank in pairs(highestTargetByTalent) do
        plannedPoints = plannedPoints + targetRank
    end
    return plannedPoints
end

local function FirstLearnableStep(steps, treeFilter)
    for _, step in ipairs(steps) do
        if step.status == "waiting" and step.isLearnable and (treeFilter == nil or treeFilter(step.tree)) then
            return step
        end
    end
    return nil
end

-- Best learnable talent: highest row first, then leftmost.
local function FindAutomaticSuggestion(treesToSearch)
    for _, tree in ipairs(treesToSearch) do
        local bestTalent
        for _, talent in ipairs(tree.talents) do
            if Mentor.IsTalentLearnable(tree, talent) then
                if not bestTalent or talent.tier > bestTalent.tier
                    or (talent.tier == bestTalent.tier and talent.column < bestTalent.column) then
                    bestTalent = talent
                end
            end
        end
        if bestTalent then
            return bestTalent, tree
        end
    end
    return nil, nil
end

-- Upcoming talents after the next one, for the numbered badges in the talent
-- window: the next few build steps that are not done yet (one per talent).
local function GetUpcomingTalents(steps, nextTalent, upcomingCount)
    local upcomingTalents, seenTalents = {}, {}
    if nextTalent then
        seenTalents[nextTalent] = true
    end
    for _, step in ipairs(steps) do
        if #upcomingTalents >= upcomingCount then
            break
        end
        if step.talent and step.status ~= "done" and not seenTalents[step.talent] then
            seenTalents[step.talent] = true
            table.insert(upcomingTalents, step.talent)
        end
    end
    return upcomingTalents
end

local UPCOMING_BADGE_COUNT = 4

-- Everything the UI needs about talents, in one table (nil for unknown classes).
function Mentor.GetTalentAdvice()
    local _, classFileName = UnitClass("player")
    local classData = Mentor.CLASS_DATA[classFileName]
    if not classData then
        return nil
    end

    local trees, unspentPoints, treeSource = ReadTraitTrees(classData)
    if not trees then
        trees, unspentPoints, treeSource = ReadClassicTrees()
    end
    trees = trees or {}
    unspentPoints = unspentPoints or EstimateUnspentPoints(trees)
    for _, tree in ipairs(trees) do
        tree.hasFreePoints = unspentPoints > 0
    end

    local specNumber, detectedBy = Mentor.DetectSpec(trees, classData)
    local steps = Mentor.EvaluateBuild(trees, classData, specNumber)
    local mainTree = Mentor.FindTreeForSpec(trees, classData, specNumber)

    -- The builds now use Forever's own talent names, so the build order is
    -- followed exactly (some guides put early points in another tree on
    -- purpose, e.g. Frost Mage takes Arcane talents first).
    local nextStep = FirstLearnableStep(steps)
    local mainTreeFiller
    if not nextStep and mainTree and mainTree.pointsSpent < GetPlannedMainTreePoints(steps, mainTree) then
        mainTreeFiller = FindAutomaticSuggestion({ mainTree })
    end
    if nextStep then
        nextStep.status = "next"
    end

    local advice = {
        classFileName = classFileName, classData = classData,
        specNumber = specNumber, specData = classData.specs[specNumber], detectedBy = detectedBy,
        trees = trees, treeSource = treeSource, steps = steps, mainTree = mainTree,
        unspentPoints = unspentPoints, level = UnitLevel("player") or 1,
    }
    if nextStep then
        advice.nextTalent, advice.nextTree, advice.isAutomatic = nextStep.talent, nextStep.tree, false
    elseif mainTreeFiller then
        advice.nextTalent, advice.nextTree, advice.isAutomatic = mainTreeFiller, mainTree, true
    elseif #trees > 0 then
        local searchOrder = { mainTree }
        for _, tree in ipairs(trees) do
            if tree ~= mainTree then
                table.insert(searchOrder, tree)
            end
        end
        advice.nextTalent, advice.nextTree = FindAutomaticSuggestion(searchOrder)
        advice.isAutomatic = advice.nextTalent ~= nil
    end
    advice.upcomingTalents = GetUpcomingTalents(steps, advice.nextTalent, UPCOMING_BADGE_COUNT)

    advice.missingCount = 0
    for _, step in ipairs(steps) do
        if step.status == "missing" then
            advice.missingCount = advice.missingCount + 1
        end
    end
    return advice
end

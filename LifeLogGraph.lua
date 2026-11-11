--------------------------------------------------------------------------------
-- Mentor - LifeLogGraph.lua
-- The gold graph of the Life log ("Gold graph" button in the Life log
-- window): your gold over time as a line, for the last 7 days, 30 days or
-- everything recorded. The points are recorded by LifeLog.lua
-- (characterDB.moneyHistory). Kept in its own file because LifeLog.lua is
-- close to Lua's limit of 200 local variables per file.
--------------------------------------------------------------------------------

local _, Mentor = ...
local lifeLog = Mentor.LifeLog
local mainFrame = _G["MentorLifeLogFrame"]
local MENTOR_GOLD = { 1.00, 0.78, 0.10 }

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

--------------------------------------------------------------------------------
-- Gold graph: your gold over time, as a line, next to the Life log window.
-- Ranges: last 7 days, last 30 days, or everything recorded.
--------------------------------------------------------------------------------
local GRAPH_WIDTH = 420
local GRAPH_HEIGHT = 260
local PLOT_LEFT, PLOT_RIGHT, PLOT_TOP, PLOT_BOTTOM = 70, 14, 58, 30
local GRAPH_RANGES = {
    { key = "week",  label = "7 days",  seconds = 7 * 86400 },
    { key = "month", label = "30 days", seconds = 30 * 86400 },
    { key = "all",   label = "All",     seconds = nil },
}
local MAX_PLOTTED_POINTS = 120
local goldGraph
local selectedGraphRange = "month"

local function FormatGoldShort(copperAmount)
    return lifeLog.FormatGold(copperAmount)
end

local function BuildGoldGraph()
    goldGraph = CreateFrame("Frame", "MentorLifeLogGoldGraph", mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    goldGraph:SetSize(GRAPH_WIDTH, GRAPH_HEIGHT)
    goldGraph:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 2, 0)
    if goldGraph.SetBackdrop then
        goldGraph:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        goldGraph:SetBackdropBorderColor(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.9)
    end
    goldGraph.title = goldGraph:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    goldGraph.title:SetPoint("TOPLEFT", 12, -10)
    goldGraph.title:SetText("Gold over time")
    goldGraph.summary = goldGraph:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    goldGraph.summary:SetPoint("TOPLEFT", 12, -28)
    goldGraph.summary:SetJustifyH("LEFT")

    -- Range buttons (top right).
    goldGraph.rangeButtons = {}
    local previousButton
    for rangeIndex = #GRAPH_RANGES, 1, -1 do
        local graphRange = GRAPH_RANGES[rangeIndex]
        local rangeButton = CreateFrame("Button", nil, goldGraph, "UIPanelButtonTemplate")
        rangeButton:SetSize(58, 18)
        if previousButton then
            rangeButton:SetPoint("RIGHT", previousButton, "LEFT", -3, 0)
        else
            rangeButton:SetPoint("TOPRIGHT", -10, -9)
        end
        rangeButton:SetText(graphRange.label)
        rangeButton:SetScript("OnClick", function()
            selectedGraphRange = graphRange.key
            lifeLog.RefreshGoldGraph()
        end)
        goldGraph.rangeButtons[graphRange.key] = rangeButton
        previousButton = rangeButton
    end

    -- Plot area with three gold guide lines and their labels.
    goldGraph.plot = CreateFrame("Frame", nil, goldGraph)
    goldGraph.plot:SetPoint("TOPLEFT", PLOT_LEFT, -PLOT_TOP)
    goldGraph.plot:SetPoint("BOTTOMRIGHT", -PLOT_RIGHT, PLOT_BOTTOM)
    goldGraph.guideLines, goldGraph.guideLabels = {}, {}
    for guideIndex = 1, 3 do
        local guideLine = goldGraph.plot:CreateTexture(nil, "BACKGROUND")
        guideLine:SetColorTexture(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 0.15)
        guideLine:SetHeight(1)
        goldGraph.guideLines[guideIndex] = guideLine
        local guideLabel = goldGraph:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        guideLabel:SetJustifyH("RIGHT")
        guideLabel:SetWidth(PLOT_LEFT - 8)
        goldGraph.guideLabels[guideIndex] = guideLabel
    end
    goldGraph.startDate = goldGraph:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    goldGraph.startDate:SetPoint("TOPLEFT", goldGraph.plot, "BOTTOMLEFT", 0, -4)
    goldGraph.endDate = goldGraph:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    goldGraph.endDate:SetPoint("TOPRIGHT", goldGraph.plot, "BOTTOMRIGHT", 0, -4)
    goldGraph.emptyText = goldGraph.plot:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    goldGraph.emptyText:SetPoint("CENTER")
    goldGraph.emptyText:SetText("Not enough data yet - play a little and come back.")
    goldGraph.segments = {}
    goldGraph:Hide()
end

-- A line segment between two points of the plot (a Line where the client has
-- them, otherwise a row of small dots).
local function GetSegment(segmentIndex)
    local segment = goldGraph.segments[segmentIndex]
    if not segment then
        if goldGraph.plot.CreateLine then
            segment = goldGraph.plot:CreateLine(nil, "ARTWORK")
            segment:SetThickness(2)
            segment:SetColorTexture(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 1)
        else
            segment = goldGraph.plot:CreateTexture(nil, "ARTWORK")
            segment:SetColorTexture(MENTOR_GOLD[1], MENTOR_GOLD[2], MENTOR_GOLD[3], 1)
            segment:SetSize(3, 3)
        end
        goldGraph.segments[segmentIndex] = segment
    end
    return segment
end

function lifeLog.RefreshGoldGraph()
    local characterDB = lifeLog.GetCharacterDB()
    if not (goldGraph and goldGraph:IsShown() and characterDB) then
        return
    end
    for rangeKey, rangeButton in pairs(goldGraph.rangeButtons) do
        rangeButton:SetEnabled(rangeKey ~= selectedGraphRange)
    end
    -- The points in the chosen range (plus "now").
    local rangeSeconds
    for _, graphRange in ipairs(GRAPH_RANGES) do
        if graphRange.key == selectedGraphRange then
            rangeSeconds = graphRange.seconds
        end
    end
    local now = time()
    local points = {}
    for _, moneyPoint in ipairs(characterDB.moneyHistory or {}) do
        if not rangeSeconds or now - moneyPoint.time <= rangeSeconds then
            table.insert(points, moneyPoint)
        end
    end
    local currentMoney = GetMoney()
    if not IsSecret(currentMoney) then
        table.insert(points, { time = now, copper = currentMoney })
    end
    -- Thin out to at most MAX_PLOTTED_POINTS points.
    if #points > MAX_PLOTTED_POINTS then
        local thinnedPoints, step = {}, #points / MAX_PLOTTED_POINTS
        for plotIndex = 0, MAX_PLOTTED_POINTS - 1 do
            table.insert(thinnedPoints, points[math.floor(plotIndex * step) + 1])
        end
        table.insert(thinnedPoints, points[#points])
        points = thinnedPoints
    end

    for _, segment in ipairs(goldGraph.segments) do
        segment:Hide()
    end
    local hasEnoughData = #points >= 2 and points[#points].time > points[1].time
    goldGraph.emptyText:SetShown(not hasEnoughData)
    for guideIndex = 1, 3 do
        goldGraph.guideLines[guideIndex]:SetShown(hasEnoughData)
        goldGraph.guideLabels[guideIndex]:SetShown(hasEnoughData)
    end
    if not hasEnoughData then
        goldGraph.summary:SetText("Now: " .. FormatGoldShort(IsSecret(currentMoney) and 0 or currentMoney))
        goldGraph.startDate:SetText("")
        goldGraph.endDate:SetText("")
        return
    end

    local firstTime, lastTime = points[1].time, points[#points].time
    local lowestCopper, highestCopper = math.huge, 0
    for _, plotPoint in ipairs(points) do
        lowestCopper = math.min(lowestCopper, plotPoint.copper)
        highestCopper = math.max(highestCopper, plotPoint.copper)
    end
    lowestCopper = math.max(0, lowestCopper - (highestCopper - lowestCopper) * 0.1)
    if highestCopper - lowestCopper < 100 then
        highestCopper = lowestCopper + 100
    end
    local plotWidth = GRAPH_WIDTH - PLOT_LEFT - PLOT_RIGHT
    local plotHeight = GRAPH_HEIGHT - PLOT_TOP - PLOT_BOTTOM
    local function ToPlot(plotPoint)
        local horizontal = (plotPoint.time - firstTime) / (lastTime - firstTime) * plotWidth
        local vertical = (plotPoint.copper - lowestCopper) / (highestCopper - lowestCopper) * plotHeight
        return horizontal, vertical
    end
    for segmentIndex = 1, #points - 1 do
        local startX, startY = ToPlot(points[segmentIndex])
        local endX, endY = ToPlot(points[segmentIndex + 1])
        local segment = GetSegment(segmentIndex)
        if segment.SetStartPoint then
            segment:SetStartPoint("BOTTOMLEFT", goldGraph.plot, startX, startY)
            segment:SetEndPoint("BOTTOMLEFT", goldGraph.plot, endX, endY)
        else
            segment:ClearAllPoints()
            segment:SetPoint("CENTER", goldGraph.plot, "BOTTOMLEFT", endX, endY)
        end
        segment:Show()
    end
    -- Guide lines at the bottom, middle and top, with their gold values.
    for guideIndex = 1, 3 do
        local fraction = (guideIndex - 1) / 2
        local guideY = fraction * plotHeight
        local guideLine = goldGraph.guideLines[guideIndex]
        guideLine:ClearAllPoints()
        guideLine:SetPoint("BOTTOMLEFT", goldGraph.plot, "BOTTOMLEFT", 0, guideY)
        guideLine:SetPoint("BOTTOMRIGHT", goldGraph.plot, "BOTTOMRIGHT", 0, guideY)
        local guideLabel = goldGraph.guideLabels[guideIndex]
        guideLabel:ClearAllPoints()
        guideLabel:SetPoint("RIGHT", goldGraph.plot, "BOTTOMLEFT", -6, guideY)
        guideLabel:SetText(FormatGoldShort(lowestCopper + fraction * (highestCopper - lowestCopper)))
    end
    goldGraph.startDate:SetText(date("%d %b", firstTime))
    goldGraph.endDate:SetText(date("%d %b", lastTime))
    local change = points[#points].copper - points[1].copper
    local changeColor = change >= 0 and "|cff40ff40+" or "|cffff4040-"
    goldGraph.summary:SetText("Now: " .. FormatGoldShort(points[#points].copper) .. "   Change: " .. changeColor
        .. FormatGoldShort(math.abs(change)) .. "|r")
end

function lifeLog.ToggleGoldGraph()
    if not goldGraph then
        BuildGoldGraph()
    end
    -- Right of the Life log window, or left of it when there is no room.
    goldGraph:ClearAllPoints()
    local windowRight = mainFrame:GetRight()
    local screenWidth = UIParent:GetWidth() or 0
    if windowRight and screenWidth > 0 and windowRight + GRAPH_WIDTH + 2 > screenWidth then
        goldGraph:SetPoint("TOPRIGHT", mainFrame, "TOPLEFT", -2, 0)
    else
        goldGraph:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 2, 0)
    end
    goldGraph:SetShown(not goldGraph:IsShown())
    lifeLog.RefreshGoldGraph()
end


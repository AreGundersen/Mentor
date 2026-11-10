--------------------------------------------------------------------------------
-- Mentor - MinimapButton.lua
-- A round button on the edge of the minimap, like Questie and AtlasLoot have.
--   Left-click   show / hide the Mentor window
--   Right-click  open the settings
--   Drag         move it around the minimap (the position is saved)
--------------------------------------------------------------------------------

local _, Mentor = ...

local BUTTON_SIZE = 31
local ICON_TEXTURE = "Interface\\Icons\\INV_Misc_Book_09"
local DISTANCE_OUTSIDE_EDGE = 5   -- pixels outside the minimap's edge

local minimapButtonModule = {}
Mentor.MinimapButton = minimapButtonModule
local minimapButton

-- Puts the button on the minimap's edge at the saved angle.
local function UpdatePosition()
    local angleRadians = math.rad(MentorDB.minimapAngle or 200)
    local radius = (Minimap:GetWidth() / 2) + DISTANCE_OUTSIDE_EDGE
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angleRadians) * radius, math.sin(angleRadians) * radius)
end

-- While dragging: the angle from the minimap's centre to the cursor.
local function FollowCursor()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local centerX, centerY = Minimap:GetCenter()
    local angleDegrees = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX))
    MentorDB.minimapAngle = angleDegrees % 360
    UpdatePosition()
end

function minimapButtonModule.Create()
    if minimapButton or not Minimap then
        return
    end
    minimapButton = CreateFrame("Button", "MentorMinimapButton", Minimap)
    minimapButton:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- The standard round minimap button look: dark disc, icon, gold ring.
    local background = minimapButton:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON_TEXTURE)
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    minimapButton:SetScript("OnClick", function(_, mouseButton)
        if IsShiftKeyDown and IsShiftKeyDown() then
            Mentor.BugReport.Open()
        elseif mouseButton == "RightButton" then
            Mentor.ToggleSettings()
        else
            Mentor.ToggleWindow()
        end
    end)
    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", FollowCursor)
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff66ccffMentor|r")
        local advice = Mentor.currentAdvice
        if advice and advice.nextTalent then
            GameTooltip:AddLine("Next talent: " .. advice.nextTalent.name, 1, 1, 1)
        end
        GameTooltip:AddLine("Left-click: show / hide", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Shift-click: report a bug", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: move", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
    minimapButtonModule.UpdateVisibility()
end

function minimapButtonModule.UpdateVisibility()
    if minimapButton then
        minimapButton:SetShown(MentorDB.isMinimapButtonShown ~= false)
    end
end

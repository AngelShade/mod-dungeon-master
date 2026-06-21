print("|cffffd159ACDM Debug:|r ACChallengePanel.lua loaded!")
local isDragging = false
local isInitialLogin = true

local function OnEvent(self, event, addonName, ...)
    if event == "ADDON_LOADED" and addonName == "ACChallengePanel" then
        self:UnregisterEvent("ADDON_LOADED")
        
        -- Initialize panels
        ACDM.CreateMainFrame()
        ACDM.CreateChallengeFlow()
        ACDM.CreateRoguelikeFlow()
        ACDM.CreateActiveRunPanel()
        ACDM.CreateStatsPanel()
        ACDM.CreateControlsPanel()
        print("|cffffd159ACDM Debug:|r CreateMasteryPanel type:", type(ACDM.CreateMasteryPanel))
        ACDM.CreateMasteryPanel()
        ACMP.CreateMainFrame()
        ACDM.CreateTrackerFrame()
        
        -- Setup database defaults
        if not ACChallengePanelDB then
            ACChallengePanelDB = { minimapPos = 45 }
        end
        if ACChallengePanelDB.accumulatedGold then
            ACDM.runInfo.accumulatedGold = ACChallengePanelDB.accumulatedGold
        end
        if ACChallengePanelDB.rewardedItems then
            ACDM.runInfo.rewardedItems = ACChallengePanelDB.rewardedItems
        end
        
        -- Position minimap button
        local angle = math.rad(ACChallengePanelDB.minimapPos or 45)
        local cx = math.cos(angle) * 80
        local cy = math.sin(angle) * 80
        ACChallengePanelMinimapButton:ClearAllPoints()
        ACChallengePanelMinimapButton:SetPoint("CENTER", Minimap, "CENTER", cx, cy)

        -- Register world load and teleport events
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_LEAVING_WORLD")
    elseif event == "PLAYER_LEAVING_WORLD" then
        ACDM.isZoning = true
    elseif event == "PLAYER_ENTERING_WORLD" then
        ACDM.isZoning = false
        -- Open main console by default on first login, or restore state on subsequent teleports
        if ACDMMainFrame then
            if isInitialLogin then
                isInitialLogin = false
                ACDMMainFrame:Show() -- triggers OnShow -> RequestQuery
                ACDM.RequestStats()
            elseif ACDM.isConsoleOpen then
                ACDMMainFrame:Show() -- triggers OnShow -> RequestQuery
                ACDM.RequestStats()
            else
                -- Query silently to restore HUD tracker if console is closed
                ACDM.RequestQuery()
                ACDM.RequestStats()
            end
        else
            ACDM.RequestQuery()
            ACDM.RequestStats()
        end
    end
end

local loaderFrame = CreateFrame("Frame")
loaderFrame:RegisterEvent("ADDON_LOADED")
loaderFrame:SetScript("OnEvent", OnEvent)

-- Register Slash commands
SLASH_ACCHALLENGEPANEL1 = "/acdm"
SLASH_ACCHALLENGEPANEL2 = "/challenge"
SLASH_ACCHALLENGEPANEL3 = "/dmui"
SlashCmdList.ACCHALLENGEPANEL = function(msg)
    if not ACDMMainFrame then return end
    local action = msg and msg:match("^%s*(.-)%s*$"):lower()
    if action == "reset" then
        ACDMMainFrame:ClearAllPoints()
        ACDMMainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        ACDMMainFrame:SetScale(1.0)
        ACDMMainFrame:SetSize(ACDM.PANEL_WIDTH or 520, ACDM.PANEL_HEIGHT or 560)
        ACDMMainFrame:Show()
        print("|cffffd159ACDM:|r Console position, size, and scale reset to center.")
        return
    end
    if ACDMMainFrame:IsShown() then
        ACDMMainFrame:Hide()
    else
        ACDMMainFrame:Show()
    end
end

SLASH_ACDMTEST1 = "/acdmtest"
SlashCmdList.ACDMTEST = function()
    print("|cffffd159ACDM Client Diagnostic Data:|r")
    print("Difficulties (" .. #ACDM.difficulties .. "):")
    for idx, diff in ipairs(ACDM.difficulties) do
        print(string.format("  [%d] ID: %d, Name: %s, Min: %d, Max: %d", idx, diff.Id, diff.Name, diff.MinLevel, diff.MaxLevel))
    end
    print("Themes (" .. #ACDM.themes .. "):")
    for idx, theme in ipairs(ACDM.themes) do
        print(string.format("  [%d] ID: %d, Name: %s", idx, theme.Id, theme.Name))
    end
    print("Dungeons (" .. #ACDM.dungeons .. "):")
    for idx, dg in ipairs(ACDM.dungeons) do
        print(string.format("  [%d] MapId: %s, Name: %s, Min: %s, Max: %s", idx, tostring(dg.MapId), tostring(dg.Name), tostring(dg.MinLevel), tostring(dg.MaxLevel)))
    end
    print("Selected diffId: " .. tostring(ACDM.selection.diffId))
    print("Flags: enabled=" .. (ACDM.flags.enabled or 0) .. ", inSession=" .. (ACDM.flags.inSession or 0) .. ", inRoguelike=" .. (ACDM.flags.inRoguelike or 0) .. ", playerLevel=" .. (ACDM.flags.playerLevel or 1))
end

-- Mythic Plus console toggle slash commands
SLASH_ACMPPANEL1 = "/acmp"
SLASH_ACMPPANEL2 = "/mythicui"
SLASH_ACMPPANEL3 = "/mplus"
SlashCmdList.ACMPPANEL = function(msg)
    if not ACMPMainFrame then return end
    local action = msg and msg:match("^%s*(.-)%s*$"):lower()
    if action == "reset" then
        ACMPMainFrame:ClearAllPoints()
        ACMPMainFrame:SetPoint("CENTER", UIParent, "CENTER", 50, 0)
        ACMPMainFrame:SetScale(1.0)
        ACMPMainFrame:SetSize(550, 520)
        ACMPMainFrame:Show()
        print("|cffffd159ACMP:|r Console position, size, and scale reset to center.")
        return
    end
    if ACMPMainFrame:IsShown() then
        ACMPMainFrame:Hide()
    else
        ACMPMainFrame:Show()
    end
end

-- Minimap button
local minimapButton = CreateFrame("Button", "ACChallengePanelMinimapButton", Minimap)
minimapButton:SetMovable(true)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Rune_06")
minimapButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
minimapButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", function(self)
    self:StartMoving()
    isDragging = true
end)
minimapButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    isDragging = false
end)

minimapButton:SetScript("OnUpdate", function(self)
    if isDragging then
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local angle = math.atan2(py - my, px - mx)
        local deg = math.deg(angle)
        if deg < 0 then deg = deg + 360 end
        ACChallengePanelDB.minimapPos = deg
        
        local cx = math.cos(angle) * 80
        local cy = math.sin(angle) * 80
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", cx, cy)
    end
end)

minimapButton:SetScript("OnClick", function()
    SlashCmdList.ACCHALLENGEPANEL()
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Challenge Console", 1, 0.82, 0.35)
    GameTooltip:AddLine("Open Dungeon Master and Mythic Plus controls.", 1, 1, 1, true)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Hook LFD Parent Frame to add a circular shortcut button next to the window
local function CreateLFDButton()
    if not LFDQueueFrame then return end
    if _G["ACChallengePanelLFDButton"] then return end -- prevent duplicate creation
    
    -- 1. Challenge Console Button
    local btn = CreateFrame("Button", "ACChallengePanelLFDButton", LFDQueueFrame)
    btn:SetSize(32, 32)
    
    -- Icon texture (using Dungeon Master runic icon)
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Rune_06")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- crop slightly to fit circle
    btn.icon = icon
    
    -- Circular gold border overlay (aligned using standard TOPLEFT 56x56 sizing)
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(56, 56)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    btn.border = border
    
    -- Highlight effect
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetPoint("CENTER", btn, "CENTER", 0, 0)
    highlight:SetSize(32, 32)
    
    -- Press animations
    btn:SetScript("OnMouseDown", function(self)
        icon:SetPoint("CENTER", btn, "CENTER", 1, -1)
    end)
    btn:SetScript("OnMouseUp", function(self)
        icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    end)
    
    btn:SetScript("OnClick", function()
        SlashCmdList.ACCHALLENGEPANEL()
    end)
    
    -- Tooltip for the button
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Challenge Console", 1, 0.82, 0.35)
        GameTooltip:AddLine("Open the custom Dungeon Master and Mythic Plus panel.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- 2. Mythic Plus Console Button
    local mpBtn = CreateFrame("Button", "ACMPLFDButton", LFDQueueFrame)
    mpBtn:SetSize(32, 32)
    
    -- Icon texture (using Keystone Key icon INV_Misc_Key_14)
    local mpIcon = mpBtn:CreateTexture(nil, "BACKGROUND")
    mpIcon:SetTexture("Interface\\Icons\\INV_Misc_Key_14")
    mpIcon:SetSize(20, 20)
    mpIcon:SetPoint("CENTER", mpBtn, "CENTER", 0, 0)
    mpIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    mpBtn.icon = mpIcon
    
    local mpBorder = mpBtn:CreateTexture(nil, "OVERLAY")
    mpBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    mpBorder:SetSize(56, 56)
    mpBorder:SetPoint("TOPLEFT", mpBtn, "TOPLEFT", 0, 0)
    mpBtn.border = mpBorder
    
    local mpHighlight = mpBtn:CreateTexture(nil, "HIGHLIGHT")
    mpHighlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    mpHighlight:SetBlendMode("ADD")
    mpHighlight:SetPoint("CENTER", mpBtn, "CENTER", 0, 0)
    mpHighlight:SetSize(32, 32)
    
    mpBtn:SetScript("OnMouseDown", function(self)
        mpIcon:SetPoint("CENTER", mpBtn, "CENTER", 1, -1)
    end)
    mpBtn:SetScript("OnMouseUp", function(self)
        mpIcon:SetPoint("CENTER", mpBtn, "CENTER", 0, 0)
    end)
    
    mpBtn:SetScript("OnClick", function()
        SlashCmdList.ACMPPANEL()
    end)
    
    mpBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Mythic Plus Console", 1, 0.82, 0.35)
        GameTooltip:AddLine("Open the custom Mythic Plus level selector, dungeon key manager, and standings.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    mpBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Function to update the button position dynamically to align horizontally with the close button
    local function UpdatePosition()
        local closeBtn = _G["LFDQueueFrameCancelButton"]
        if closeBtn then
            btn:ClearAllPoints()
            btn:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
            
            mpBtn:ClearAllPoints()
            mpBtn:SetPoint("RIGHT", btn, "LEFT", -5, 0)
        end
    end
    
    -- Hook OnShow to update positioning when the frame is rendered
    LFDQueueFrame:HookScript("OnShow", UpdatePosition)
    if LFDQueueFrame:IsShown() then
        UpdatePosition()
    else
        UpdatePosition() -- initial fallback
    end
end

-- Run button creation
if IsAddOnLoaded("Blizzard_LFGUI") or LFDParentFrame then
    CreateLFDButton()
else
    local lfgLoader = CreateFrame("Frame")
    lfgLoader:RegisterEvent("ADDON_LOADED")
    lfgLoader:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Blizzard_LFGUI" or LFDParentFrame then
            CreateLFDButton()
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end


ACDM.MainFrame = nil
ACDM.Tabs = {}
ACDM.TabFrames = {}

local function SetTextColor(fontString, color)
    fontString:SetTextColor(color.r, color.g, color.b)
end

function ACDM.CreateMainFrame()
    if ACDM.MainFrame then return end

    local f = CreateFrame("Frame", "ACDMMainFrame", UIParent)
    f:SetSize(ACDM.PANEL_WIDTH, ACDM.PANEL_HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    -- Resizing setup
    f:SetResizable(true)
    f:SetMinResize(100, 100) -- Set to low minimum since we handle scaling below 520x560 ourselves
    f:SetMaxResize(800, 800)

    -- Custom resizing functions to handle threshold scaling smoothly
    local function StartCustomResize(handle, edge)
        local targetLeft = f:GetLeft()
        local targetTop = f:GetTop()
        if not targetLeft or not targetTop then return end

        f.isResizing = true
        f.resizeEdge = edge
        
        local uiScale = UIParent:GetEffectiveScale() or 1
        f.startCursorX, f.startCursorY = GetCursorPosition()
        f.startScale = f:GetScale()
        f.startWidth = f:GetWidth()
        f.startHeight = f:GetHeight()
        
        f.targetLeft = targetLeft
        f.targetTop = targetTop
        
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", targetLeft, targetTop)
        
        handle:SetScript("OnUpdate", function(self, elapsed)
            local curX, curY = GetCursorPosition()
            local dx = (curX - f.startCursorX) / uiScale
            local dy = (curY - f.startCursorY) / uiScale
            
            -- Calculate requested physical size in UIParent space
            local W = f.startWidth * f.startScale + dx
            local H = f.startHeight * f.startScale - dy
            
            local baseWidth, baseHeight = 520, 600
            local maxWidth, maxHeight = 800, 800
            
            -- Calculate smooth scale based on minimum ratio
            local scaleX = W / baseWidth
            local scaleY = H / baseHeight
            local scale = math.min(scaleX, scaleY)
            scale = math.max(0.6, math.min(1.0, scale))
            
            -- Calculate logical dimensions
            local w_logical = W / scale
            local h_logical = H / scale
            
            -- Clamp logical size to allowed limits
            w_logical = math.max(baseWidth, math.min(maxWidth, w_logical))
            h_logical = math.max(baseHeight, math.min(maxHeight, h_logical))
            
            f:SetSize(w_logical, h_logical)
            f:SetScale(scale)
            
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", f.targetLeft * f.startScale / scale, f.targetTop * f.startScale / scale)
        end)
    end
    
    local function StopCustomResize(handle)
        f.isResizing = false
        handle:SetScript("OnUpdate", nil)
        
        if f.targetLeft and f.targetTop then
            local scale = f:GetScale()
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", f.targetLeft * f.startScale / scale, f.targetTop * f.startScale / scale)
        end
    end

    -- Create a visible grabber texture on bottom-right corner for resizing
    local resizeHandles = {
        {"BOTTOMRIGHT", 16, 16, "BOTTOMRIGHT", -7, 7, "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"},
    }

    f.resizeHandles = {}
    for _, handleData in ipairs(resizeHandles) do
        local edge, width, height, point, x, y, texture = unpack(handleData)
        local handle = CreateFrame("Button", nil, f)
        tinsert(f.resizeHandles, handle)
        
        -- Anchors handles along edges/corners correctly so they do not sit in the center of the frame
        if edge == "TOP" then
            handle:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -4)
            handle:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -4)
            handle:SetHeight(height)
        elseif edge == "BOTTOM" then
            handle:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 4)
            handle:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 4)
            handle:SetHeight(height)
        elseif edge == "LEFT" then
            handle:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -16)
            handle:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 16)
            handle:SetWidth(width)
        elseif edge == "RIGHT" then
            handle:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -16)
            handle:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 16)
            handle:SetWidth(width)
        else
            handle:SetPoint(point, f, point, x, y)
            handle:SetSize(width, height)
        end
        
        handle:SetFrameLevel(f:GetFrameLevel() + 10)
        
        if texture then
            handle:SetNormalTexture(texture)
            handle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
            handle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        end
        
        handle:EnableMouse(true)
        handle:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                StartCustomResize(self, edge)
            end
        end)
        handle:SetScript("OnMouseUp", function(self, button)
            StopCustomResize(self)
        end)
    end
    
    -- Backdrop setup
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetBackdropColor(0.08, 0.08, 0.08, 1.0)
    
    -- Title Header
    local titleBG = f:CreateTexture(nil, "ARTWORK")
    titleBG:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBG:SetWidth(320)
    titleBG:SetHeight(64)
    titleBG:SetPoint("TOP", f, "TOP", 0, 12)
    
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", titleBG, "TOP", 0, -14)
    f.title:SetText("Dungeon Master Console")
    SetTextColor(f.title, ACDM.Colors.Gold)

    -- Close Button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Minimize Button
    local minimize = CreateFrame("Button", nil, f)
    minimize:SetSize(32, 32)
    minimize:SetPoint("RIGHT", close, "LEFT", 0, 0)
    minimize:SetNormalTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Up")
    minimize:SetPushedTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Down")
    minimize:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")

    local function ToggleMinimize()
        if f.isMinimized then
            -- Expand
            f:SetHeight(f.preMinimizeHeight or ACDM.PANEL_HEIGHT)
            f.Content:Show()
            for _, tab in ipairs(ACDM.Tabs) do
                tab:Show()
            end
            if f.statusBar then
                f.statusBar:Show()
            end
            for _, handle in ipairs(f.resizeHandles) do
                handle:Show()
            end
            f:SetResizable(true)
            minimize:SetNormalTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Up")
            minimize:SetPushedTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Down")
            f.isMinimized = false
        else
            -- Minimize
            f.preMinimizeHeight = f:GetHeight()
            f:SetHeight(50)
            f.Content:Hide()
            for _, tab in ipairs(ACDM.Tabs) do
                tab:Hide()
            end
            if f.statusBar then
                f.statusBar:Hide()
            end
            for _, handle in ipairs(f.resizeHandles) do
                handle:Hide()
            end
            f:SetResizable(false)
            minimize:SetNormalTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Up")
            minimize:SetPushedTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Down")
            f.isMinimized = true
        end
    end
    minimize:SetScript("OnClick", ToggleMinimize)

    -- Status Bar at the bottom
    local statusBG = CreateFrame("Frame", nil, f)
    f.statusBar = statusBG
    statusBG:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 15, 15)
    statusBG:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 15)
    statusBG:SetHeight(26)
    statusBG:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    statusBG:SetBackdropColor(0, 0, 0, 0.8)
    statusBG:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.5)

    local statusText = statusBG:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", statusBG, "LEFT", 10, 0)
    statusText:SetText("Ready")
    f.statusText = statusText

    -- Cooldown ticking
    local lastTick = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        lastTick = lastTick + elapsed
        if lastTick >= 1.0 then
            lastTick = 0
            if ACDM.flags.cooldownRemSec and ACDM.flags.cooldownRemSec > 0 then
                ACDM.flags.cooldownRemSec = ACDM.flags.cooldownRemSec - 1
                ACDM.UpdateStatus()
            end
        end
    end)

    -- Content frames container
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -60)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 45)
    f.Content = content

    -- Create Tab Frames
    ACDM.TabFrames[1] = CreateFrame("Frame", nil, content)
    ACDM.TabFrames[2] = CreateFrame("Frame", nil, content)
    ACDM.TabFrames[3] = CreateFrame("Frame", nil, content)
    ACDM.TabFrames[4] = CreateFrame("Frame", nil, content)
    ACDM.TabFrames[5] = CreateFrame("Frame", nil, content)
    ACDM.TabFrames[6] = CreateFrame("Frame", nil, content)

    for i = 1, 6 do
        ACDM.TabFrames[i]:SetAllPoints(content)
        ACDM.TabFrames[i]:Hide()
    end

    -- Create Tab Buttons
    local tabNames = { "Challenge", "Roguelike", "Active Run", "Stats", "Controls", "Mastery" }
    for i = 1, 6 do
        local tab = CreateFrame("Button", "ACDMTab" .. i, f, "UIPanelButtonTemplate")
        tab:SetSize(76, 24)
        tab:SetText(tabNames[i])
        
        if i == 1 then
            tab:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -35)
        else
            tab:SetPoint("LEFT", ACDM.Tabs[i-1], "RIGHT", 4, 0)
        end

        tab:SetScript("OnClick", function()
            ACDM.ShowTab(i)
        end)

        ACDM.Tabs[i] = tab
    end

    f:SetScript("OnShow", function()
        ACDM.isConsoleOpen = true
        ACDM.ShowTab(1)
        ACDM.RequestQuery()
    end)

    f:SetScript("OnHide", function()
        if not ACDM.isZoning then
            ACDM.isConsoleOpen = false
        end
    end)

    f:Hide()
    ACDM.MainFrame = f
    tinsert(UISpecialFrames, "ACDMMainFrame")
end

function ACDM.ShowTab(tabIndex)
    for i = 1, 6 do
        if i == tabIndex then
            ACDM.TabFrames[i]:Show()
            ACDM.Tabs[i]:LockHighlight()
            ACDM.Tabs[i]:Disable()
        else
            ACDM.TabFrames[i]:Hide()
            ACDM.Tabs[i]:UnlockHighlight()
            ACDM.Tabs[i]:Enable()
        end
    end
    
    if tabIndex == 3 then
        ACDM.RequestQuery()
    elseif tabIndex == 4 then
        ACDM.RequestStats()
    elseif tabIndex == 6 then
        ACDM.RequestStats()
    end
end

function ACDM.UpdateStatus()
    if not ACDM.MainFrame then return end
    local text = ""
    
    if ACDM.flags.enabled == 0 then
        text = ACDM.ColorText("Dungeon Master Disabled", ACDM.Colors.Red)
    elseif ACDM.flags.cooldownRemSec and ACDM.flags.cooldownRemSec > 0 then
        text = ACDM.ColorText("Challenge On Cooldown: " .. ACDM.FormatTime(ACDM.flags.cooldownRemSec), ACDM.Colors.Red)
    elseif ACDM.flags.inRoguelike == 1 then
        text = ACDM.ColorText("Roguelike Run Active: Tier " .. (ACDM.flags.rlTier or 1) .. " (" .. (ACDM.flags.rlFloors or 0) .. " Floors Cleared)", ACDM.Colors.Cyan)
    elseif ACDM.flags.inSession == 1 then
        text = ACDM.ColorText("Active Challenge Session In Progress", ACDM.Colors.Green)
    else
        text = ACDM.ColorText("Ready to start challenge", ACDM.Colors.Green)
    end
    
    ACDM.MainFrame.statusText:SetText(text)
end

-- Hook complete callbacks to update status
ACDM.OnQueryComplete = function()
    ACDM.UpdateStatus()
    if ACDM.RefreshChallengeFlow then ACDM.RefreshChallengeFlow() end
    if ACDM.RefreshRoguelikeFlow then ACDM.RefreshRoguelikeFlow() end
    if ACDM.RefreshActiveRun then ACDM.RefreshActiveRun() end
    if ACDM.UpdateTrackerUI then ACDM.UpdateTrackerUI() end
end

ACDM.OnRunInfoReceived = function()
    if ACDM.RefreshActiveRun then ACDM.RefreshActiveRun() end
end

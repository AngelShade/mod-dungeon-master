ACMP.MainFrame = nil

local function SetTextColor(fontString, color)
    fontString:SetTextColor(color.r, color.g, color.b)
end

function ACMP.CreateMainFrame()
    if ACMP.MainFrame then return end

    local f = CreateFrame("Frame", "ACMPMainFrame", UIParent)
    f:SetSize(550, 520)
    f:SetPoint("CENTER", nil, "CENTER", 50, 0) -- offset slightly from center
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    -- Resizing setup
    f:SetResizable(true)
    f:SetMinResize(100, 100)
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
            
            local baseWidth, baseHeight = 550, 520
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
    local resizeHandle = CreateFrame("Button", nil, f)
    resizeHandle:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -7, 7)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetFrameLevel(f:GetFrameLevel() + 10)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    
    resizeHandle:EnableMouse(true)
    resizeHandle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            StartCustomResize(self, "BOTTOMRIGHT")
        end
    end)
    resizeHandle:SetScript("OnMouseUp", function(self, button)
        StopCustomResize(self)
    end)
    f.resizeHandle = resizeHandle

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
    f.title:SetText("Mythic Plus Console")
    SetTextColor(f.title, ACDM.Colors.Gold)

    -- Close Button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Active Level status label (Header panel area)
    local statusPanel = CreateFrame("Frame", nil, f)
    statusPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -45)
    statusPanel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, -45)
    statusPanel:SetHeight(50)
    statusPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    statusPanel:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    statusPanel:SetBackdropBorderColor(0.82, 0.68, 0.32, 0.5)

    local activeLevelText = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    activeLevelText:SetPoint("LEFT", statusPanel, "LEFT", 15, 0)
    activeLevelText:SetText("Active Level: None")
    f.activeLevelText = activeLevelText

    -- Reset level button
    local resetBtn = CreateFrame("Button", nil, statusPanel, "UIPanelButtonTemplate")
    resetBtn:SetSize(100, 24)
    resetBtn:SetPoint("RIGHT", statusPanel, "RIGHT", -125, 0)
    resetBtn:SetText("Reset Level")
    resetBtn:SetScript("OnClick", function()
        ACDM.SendCommand(".mythic reset")
    end)
    resetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset Level", 1, 0.82, 0.35)
        GameTooltip:AddLine("Resets your active Mythic Plus difficulty level to 0.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.resetBtn = resetBtn

    -- Get Keystone button
    local getKeystoneBtn = CreateFrame("Button", nil, statusPanel, "UIPanelButtonTemplate")
    getKeystoneBtn:SetSize(110, 24)
    getKeystoneBtn:SetPoint("RIGHT", statusPanel, "RIGHT", -10, 0)
    getKeystoneBtn:SetText("Get Keystone")
    getKeystoneBtn:SetScript("OnClick", function()
        ACDM.SendCommand(".mythic acquire")
    end)
    getKeystoneBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Get Keystone", 1, 0.82, 0.35)
        GameTooltip:AddLine("Acquire a Mythic Plus Keystone from the server (subject to cooldown).", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    getKeystoneBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.getKeystoneBtn = getKeystoneBtn

    -- Columns Container
    local columnsFrame = CreateFrame("Frame", nil, f)
    columnsFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -100)
    columnsFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 55)

    -- LEFT COLUMN: Capable Dungeons
    local leftCol = CreateFrame("Frame", nil, columnsFrame)
    leftCol:SetPoint("TOPLEFT", columnsFrame, "TOPLEFT", 0, 0)
    leftCol:SetPoint("BOTTOMLEFT", columnsFrame, "BOTTOMLEFT", 0, 0)
    leftCol:SetWidth(250)
    leftCol:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    leftCol:SetBackdropColor(0.04, 0.04, 0.04, 0.8)
    leftCol:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)

    local leftTitle = leftCol:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftTitle:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 12, -10)
    leftTitle:SetText("Capable Dungeons")
    SetTextColor(leftTitle, ACDM.Colors.Gold)

    local dngScroll = CreateFrame("ScrollFrame", "ACMPDngScrollFrame", leftCol, "FauxScrollFrameTemplate")
    dngScroll:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 0, -32)
    dngScroll:SetPoint("BOTTOMRIGHT", leftCol, "BOTTOMRIGHT", -24, 8)

    local dngRows = {}
    for i = 1, 11 do
        local row = CreateFrame("Frame", nil, leftCol)
        row:SetSize(224, 26)
        row:SetPoint("LEFT", leftCol, "LEFT", 8, 0)
        row:SetPoint("TOP", leftCol, "TOP", 0, -(i-1)*27 - 32)
        
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        bg:SetAlpha(0.1)
        row.bg = bg

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", row, "LEFT", 8, 0)
        text:SetWidth(150)
        text:SetJustifyH("LEFT")
        row.Text = text

        local diffText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        diffText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.DiffText = diffText

        row:Hide()
        dngRows[i] = row
    end

    local function UpdateDungeonList()
        local dungeons = ACMP.mythicDungeons or {}
        local size = #dungeons
        FauxScrollFrame_Update(dngScroll, size, 11, 27)
        local offset = FauxScrollFrame_GetOffset(dngScroll)

        for i = 1, 11 do
            local idx = offset + i
            local row = dngRows[i]
            if idx <= size then
                local data = dungeons[idx]
                row:Show()
                row.Text:SetText(data.name or "Unknown")
                if data.minDifficulty == "HEROIC" then
                    row.DiffText:SetText(ACDM.ColorText("H", ACDM.Colors.Red))
                else
                    row.DiffText:SetText(ACDM.ColorText("N", ACDM.Colors.Green))
                end
            else
                row:Hide()
            end
        end
    end

    dngScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 27, UpdateDungeonList)
    end)


    -- RIGHT COLUMN: Mythic Levels List
    local rightCol = CreateFrame("Frame", nil, columnsFrame)
    rightCol:SetPoint("TOPLEFT", columnsFrame, "TOPLEFT", 260, 0)
    rightCol:SetPoint("BOTTOMRIGHT", columnsFrame, "BOTTOMRIGHT", 0, 0)
    rightCol:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    rightCol:SetBackdropColor(0.04, 0.04, 0.04, 0.8)
    rightCol:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)

    local rightTitle = rightCol:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightTitle:SetPoint("TOPLEFT", rightCol, "TOPLEFT", 12, -10)
    rightTitle:SetText("Select Mythic Level")
    SetTextColor(rightTitle, ACDM.Colors.Gold)

    local lvlScroll = CreateFrame("ScrollFrame", "ACMPLvlScrollFrame", rightCol, "FauxScrollFrameTemplate")
    lvlScroll:SetPoint("TOPLEFT", rightCol, "TOPLEFT", 0, -32)
    lvlScroll:SetPoint("BOTTOMRIGHT", rightCol, "BOTTOMRIGHT", -24, 8)

    local lvlRows = {}
    f.selectedLevelData = nil

    local function DrawDetailsCard(levelData)
        f.selectedLevelData = levelData
        if f.DetailsCard then f.DetailsCard:Hide() end

        local card = CreateFrame("Frame", "ACMPDetailsCard", f)
        card:SetFrameStrata("DIALOG")
        card:SetFrameLevel(f:GetFrameLevel() + 20)
        card:SetSize(260, 365)
        card:SetPoint("TOPLEFT", f, "TOPRIGHT", -12, -100)
        card:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        card:SetBackdropColor(0.08, 0.08, 0.08, 1.0)
        f.DetailsCard = card

        -- Card Header
        local header = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOP", card, "TOP", 0, -18)
        header:SetText("Mythic Level " .. levelData.level)
        SetTextColor(header, ACDM.Colors.Gold)

        -- Close details button
        local cardClose = CreateFrame("Button", nil, card, "UIPanelCloseButton")
        cardClose:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)
        cardClose:SetScript("OnClick", function() card:Hide() end)

        -- Stats / Info inside card
        local timeLimitText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        timeLimitText:SetPoint("TOPLEFT", card, "TOPLEFT", 20, -50)
        timeLimitText:SetText(ACDM.ColorText("Time Limit: ", ACDM.Colors.Gold) .. ACDM.FormatTime(levelData.timeLimit))

        local randomAffixText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        randomAffixText:SetPoint("TOPLEFT", timeLimitText, "BOTTOMLEFT", 0, -6)
        randomAffixText:SetText(ACDM.ColorText("Random Affixes: ", ACDM.Colors.Gold) .. levelData.randomAffixCount)

        -- Affixes list header
        local affTitle = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        affTitle:SetPoint("TOPLEFT", randomAffixText, "BOTTOMLEFT", 0, -15)
        affTitle:SetText("Static Affixes")
        SetTextColor(affTitle, ACDM.Colors.Gold)

        local prevAff = affTitle
        if #levelData.affixes == 0 then
            local noneText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            noneText:SetPoint("TOPLEFT", affTitle, "BOTTOMLEFT", 10, -6)
            noneText:SetText("None")
            prevAff = noneText
        else
            for idx, aff in ipairs(levelData.affixes) do
                local affText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                if idx == 1 then
                    affText:SetPoint("TOPLEFT", affTitle, "BOTTOMLEFT", 10, -5)
                else
                    affText:SetPoint("TOPLEFT", prevAff, "BOTTOMLEFT", 0, -4)
                end
                affText:SetWidth(220)
                affText:SetJustifyH("LEFT")
                affText:SetText("• " .. aff)
                prevAff = affText
            end
        end

        -- Rewards header
        local rewardTitle = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rewardTitle:SetPoint("TOPLEFT", prevAff, "BOTTOMLEFT", -10, -12)
        rewardTitle:SetText("Completion Rewards")
        SetTextColor(rewardTitle, ACDM.Colors.Gold)

        -- Gold reward
        local goldText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        goldText:SetPoint("TOPLEFT", rewardTitle, "BOTTOMLEFT", 10, -5)
        local gold = math.floor(levelData.reward.money / 10000)
        local silver = math.floor((levelData.reward.money % 10000) / 100)
        local copper = levelData.reward.money % 100
        goldText:SetText(ACDM.ColorText("Gold: ", ACDM.Colors.Gold) .. string.format("%d|cffffd700g|r %d|cffc7c7cfs|r %d|cffeda55fc|r", gold, silver, copper))

        -- Tokens icons row
        local prevTokenPos = nil
        for tIdx, tok in ipairs(levelData.reward.tokens) do
            local itemBtn = CreateFrame("Button", nil, card)
            itemBtn:SetSize(28, 28)
            
            if tIdx == 1 then
                itemBtn:SetPoint("TOPLEFT", goldText, "BOTTOMLEFT", 0, -6)
            else
                itemBtn:SetPoint("LEFT", prevTokenPos, "RIGHT", 8, 0)
            end
            prevTokenPos = itemBtn

            local iconTexture = itemBtn:CreateTexture(nil, "BACKGROUND")
            iconTexture:SetAllPoints()
            iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            
            -- Query item details
            local itemName, itemLink, _, _, _, _, _, _, _, itemTexture = GetItemInfo(tok.itemId)
            if itemTexture then
                iconTexture:SetTexture(itemTexture)
            else
                -- Fallback to retry querying later
                local retryFrame = CreateFrame("Frame", nil, itemBtn)
                retryFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
                retryFrame:SetScript("OnEvent", function(self, event)
                    local name, _, _, _, _, _, _, _, _, tex = GetItemInfo(tok.itemId)
                    if tex then
                        iconTexture:SetTexture(tex)
                        self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
                    end
                end)
            end

            -- Overlay text for item count
            if tok.count > 1 then
                local countText = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                countText:SetPoint("BOTTOMRIGHT", itemBtn, "BOTTOMRIGHT", 2, -2)
                countText:SetText(tok.count)
                countText:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
            end

            itemBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local name, link = GetItemInfo(tok.itemId)
                if link then
                    GameTooltip:SetHyperlink(link)
                else
                    GameTooltip:SetText("Loading item info...")
                end
                GameTooltip:Show()
            end)
            itemBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        -- LARGE SET LEVEL BUTTON
        local selectBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
        selectBtn:SetSize(220, 36)
        selectBtn:SetPoint("BOTTOM", card, "BOTTOM", 0, 15)
        selectBtn:SetText("SET MYTHIC LEVEL")
        selectBtn:SetScript("OnClick", function()
            ACDM.SendCommand(".mythic select " .. levelData.level)
            selectBtn:Disable()
            selectBtn:SetText("Setting...")
        end)
    end

    for i = 1, 11 do
        local row = CreateFrame("Button", nil, rightCol, "UIPanelButtonTemplate")
        row:SetSize(224, 26)
        row:SetPoint("LEFT", rightCol, "LEFT", 8, 0)
        row:SetPoint("TOP", rightCol, "TOP", 0, -(i-1)*27 - 32)
        
        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", row, "LEFT", 15, 0)
        row.Text = text

        local rewardText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rewardText:SetPoint("RIGHT", row, "RIGHT", -15, 0)
        row.RewardText = rewardText

        row:Hide()
        lvlRows[i] = row
    end

    local function UpdateMythicLevels()
        local levels = ACMP.mythicLevels or {}
        local size = #levels
        FauxScrollFrame_Update(lvlScroll, size, 11, 27)
        local offset = FauxScrollFrame_GetOffset(lvlScroll)

        for i = 1, 11 do
            local idx = offset + i
            local row = lvlRows[i]
            if idx <= size then
                local data = levels[idx]
                row:Show()
                row.Text:SetText("Level " .. data.level)
                
                local gold = math.floor(data.reward.money / 10000)
                row.RewardText:SetText(gold .. "g")
                
                row:SetScript("OnClick", function()
                    DrawDetailsCard(data)
                end)
            else
                row:Hide()
            end
        end
    end

    lvlScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 27, UpdateMythicLevels)
    end)


    -- BOTTOM ROW BUTTONS
    local bottomPanel = CreateFrame("Frame", nil, f)
    bottomPanel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 15, 15)
    bottomPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 15)
    bottomPanel:SetHeight(32)

    local infoBtn = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    infoBtn:SetSize(130, 26)
    infoBtn:SetPoint("LEFT", bottomPanel, "LEFT", 10, 0)
    infoBtn:SetText("Run Info")
    infoBtn:SetScript("OnClick", function()
        ACDM.SendCommand(".mythic info")
    end)
    infoBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Run Info", 1, 0.82, 0.35)
        GameTooltip:AddLine("Prints the current Mythic Plus active run details in chat.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    infoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local leaveBtn = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    leaveBtn:SetSize(130, 26)
    leaveBtn:SetPoint("LEFT", infoBtn, "RIGHT", 10, 0)
    leaveBtn:SetText("Leave Run")
    leaveBtn:SetScript("OnClick", function()
        ACDM.SendCommand(".mythic leave")
    end)
    leaveBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Leave Run", 1, 0.82, 0.35)
        GameTooltip:AddLine("Abandons the active Mythic Plus run. All players will be resurrected and teleported out.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    leaveBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local closeBtn = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    closeBtn:SetSize(130, 26)
    closeBtn:SetPoint("RIGHT", bottomPanel, "RIGHT", -10, 0)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    -- Status updates
    function ACMP.UpdateStatus()
        if not f:IsShown() then return end
        
        local status = ACMP.mythicStatus
        if status.setLevel and status.setLevel > 0 then
            activeLevelText:SetText(ACDM.ColorText("Active Level: " .. status.setLevel, ACDM.Colors.Green))
            resetBtn:Enable()
        else
            activeLevelText:SetText(ACDM.ColorText("Active Level: None", ACDM.Colors.Grey))
            resetBtn:Disable()
        end

        if status.cooldownRemSec and status.cooldownRemSec > 0 then
            getKeystoneBtn:SetText("Keystone (" .. ACDM.FormatTime(status.cooldownRemSec) .. ")")
            getKeystoneBtn:Disable()
        else
            getKeystoneBtn:SetText("Get Keystone")
            getKeystoneBtn:Enable()
        end
    end

    -- Hook status timers
    local lastTick = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        lastTick = lastTick + elapsed
        if lastTick >= 1.0 then
            lastTick = 0
            if ACMP.mythicStatus.cooldownRemSec and ACMP.mythicStatus.cooldownRemSec > 0 then
                ACMP.mythicStatus.cooldownRemSec = ACMP.mythicStatus.cooldownRemSec - 1
                ACMP.UpdateStatus()
            end
        end
    end)

    f:SetScript("OnShow", function()
        if f.DetailsCard then f.DetailsCard:Hide() end
        ACMP.RequestQuery()
    end)

    -- Callback handlers
    ACMP.OnQueryComplete = function()
        UpdateDungeonList()
        UpdateMythicLevels()
        ACMP.UpdateStatus()
    end

    ACMP.OnSelectComplete = function(success, reason)
        if f.DetailsCard then f.DetailsCard:Hide() end
        ACMP.RequestQuery()
        if success then
            UIErrorsFrame:AddMessage("Mythic level set successfully!", 0, 1, 0, 1.0, 3)
        else
            UIErrorsFrame:AddMessage("Failed to set level: " .. (reason or "Unknown error"), 1, 0, 0, 1.0, 5)
        end
    end

    ACMP.OnResetComplete = function(success, reason)
        ACMP.RequestQuery()
        if success then
            UIErrorsFrame:AddMessage("Mythic level reset to 0.", 0, 1, 0, 1.0, 3)
        else
            UIErrorsFrame:AddMessage("Failed to reset level: " .. (reason or "Unknown error"), 1, 0, 0, 1.0, 5)
        end
    end

    ACMP.OnAcquireComplete = function(success)
        ACMP.RequestQuery()
        if success then
            UIErrorsFrame:AddMessage("Keystone acquired!", 0, 1, 0, 1.0, 3)
        else
            UIErrorsFrame:AddMessage("Failed to acquire Keystone. Cooldown active or inventory full.", 1, 0, 0, 1.0, 5)
        end
    end

    f:Hide()
    ACMP.MainFrame = f
    tinsert(UISpecialFrames, "ACMPMainFrame")
end

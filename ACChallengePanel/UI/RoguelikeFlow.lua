function ACDM.CreateRoguelikeFlow()
    local parent = ACDM.TabFrames[2]
    
    -- Sub-frames
    local wizardFrame = CreateFrame("Frame", nil, parent)
    wizardFrame:SetAllPoints(parent)
    
    local activeRunFrame = CreateFrame("Frame", nil, parent)
    activeRunFrame:SetAllPoints(parent)
    activeRunFrame:Hide()
    
    -- ===================================================
    -- ACTIVE RUN PANEL
    -- ===================================================
    local arBox = CreateFrame("Frame", nil, activeRunFrame)
    arBox:SetPoint("TOPLEFT", activeRunFrame, "TOPLEFT", 20, -50)
    arBox:SetPoint("BOTTOMRIGHT", activeRunFrame, "BOTTOMRIGHT", -20, 50)
    arBox:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 24, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    arBox:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    arBox:SetBackdropBorderColor(0, 0.8, 0.8, 0.8) -- Cyan border for Roguelike
    
    local arHeader = arBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    arHeader:SetPoint("TOP", arBox, "TOP", 0, -30)
    arHeader:SetText("ACTIVE ROGUELIKE RUN")
    arHeader:SetTextColor(ACDM.Colors.Cyan.r, ACDM.Colors.Cyan.g, ACDM.Colors.Cyan.b)
    
    local arDetails1 = arBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    arDetails1:SetPoint("TOP", arHeader, "BOTTOM", 0, -40)
    arDetails1:SetText("Tier: -")
    
    local arDetails2 = arBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    arDetails2:SetPoint("TOP", arDetails1, "BOTTOM", 0, -20)
    arDetails2:SetText("Floors Cleared: -")
    
    local quitBtn = CreateFrame("Button", nil, arBox, "UIPanelButtonTemplate")
    quitBtn:SetSize(220, 36)
    quitBtn:SetPoint("BOTTOM", arBox, "BOTTOM", 0, 40)
    quitBtn:SetText("Quit Roguelike Run")
    
    quitBtn:SetScript("OnClick", function()
        ACDM.SendCommand(".dm rlquit")
        quitBtn:Disable()
        quitBtn:SetText("Quitting...")
    end)
    
    ACDM.OnQuitRoguelike = function(success, reason)
        quitBtn:Enable()
        quitBtn:SetText("Quit Roguelike Run")
        if success then
            UIErrorsFrame:AddMessage("Quit Roguelike run.", 0, 1, 0, 1.0, 3)
            ACDM.RequestQuery()
        else
            UIErrorsFrame:AddMessage("Failed to quit: " .. (reason or "Unknown"), 1, 0, 0, 1.0, 5)
        end
    end
    
    -- ===================================================
    -- SETUP WIZARD PANEL
    -- ===================================================
    -- Info box at top explaining rules
    local infoBox = CreateFrame("Frame", nil, wizardFrame)
    infoBox:SetPoint("TOPLEFT", wizardFrame, "TOPLEFT", 10, -5)
    infoBox:SetPoint("TOPRIGHT", wizardFrame, "TOPRIGHT", -10, -5)
    infoBox:SetHeight(76)
    infoBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    infoBox:SetBackdropColor(0.02, 0.04, 0.08, 0.95)
    infoBox:SetBackdropBorderColor(0, 0.8, 0.8, 0.6)
    
    local rule1 = infoBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rule1:SetPoint("TOPLEFT", infoBox, "TOPLEFT", 15, -10)
    rule1:SetText("• Clear dungeons back-to-back. Each clear increases the difficulty Tier.")
    rule1:SetTextColor(ACDM.Colors.Cyan.r, ACDM.Colors.Cyan.g, ACDM.Colors.Cyan.b)
    
    local rule2 = infoBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rule2:SetPoint("TOPLEFT", rule1, "BOTTOMLEFT", 0, -6)
    rule2:SetText("• Enemies get harder, but players gain stacking powerful passive buffs.")
    
    local rule3 = infoBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rule3:SetPoint("TOPLEFT", rule2, "BOTTOMLEFT", 0, -6)
    rule3:SetText("• Lives & Survival: Wipes consume lives. Lives persist; every 10th floor restores 1 lost life.")
    rule3:SetTextColor(ACDM.Colors.Red.r, ACDM.Colors.Red.g, ACDM.Colors.Red.b)
    
    -- Wizard selection state
    local rlSelection = {
        diffId = nil,
        scaleParty = true,
        themeId = nil
    }
    
    local rlStep = 1
    
    -- Step sub-frames (4 steps now)
    local stepFrames = {}
    for i = 1, 4 do
        stepFrames[i] = CreateFrame("Frame", nil, wizardFrame)
        stepFrames[i]:SetPoint("TOPLEFT", wizardFrame, "TOPLEFT", 10, -118)
        stepFrames[i]:SetPoint("BOTTOMRIGHT", wizardFrame, "BOTTOMRIGHT", -10, 10)
        stepFrames[i]:Hide()
    end
    
    -- Breadcrumbs
    local breadcrumbFrame = CreateFrame("Frame", nil, wizardFrame)
    breadcrumbFrame:SetPoint("TOPLEFT", wizardFrame, "TOPLEFT", 10, -83)
    breadcrumbFrame:SetPoint("TOPRIGHT", wizardFrame, "TOPRIGHT", -10, -83)
    breadcrumbFrame:SetHeight(30)
    
    local stepLabels = { "Difficulty", "Scaling", "Theme", "Confirm" }
    local stepButtons = {}
    
    local function UpdateBreadcrumbs()
        for i = 1, 4 do
            local btn = stepButtons[i]
            if i < rlStep then
                btn:Enable()
                btn:UnlockHighlight()
            elseif i == rlStep then
                btn:LockHighlight()
                btn:Disable()
            else
                btn:Disable()
                btn:UnlockHighlight()
            end
        end
    end
    
    local function ShowRLStep(step)
        for i = 1, 4 do
            if i == step then
                stepFrames[i]:Show()
            else
                stepFrames[i]:Hide()
            end
        end
        rlStep = step
        UpdateBreadcrumbs()
        
        if step == 1 then
            ACDM.RefreshRLDifficultyList()
        elseif step == 3 then
            ACDM.RefreshRLThemeList()
        elseif step == 4 then
            ACDM.ShowRLConfirmation()
        end
    end
    
    for i = 1, 4 do
        local btn = CreateFrame("Button", nil, breadcrumbFrame, "UIPanelButtonTemplate")
        btn:SetSize(95, 22)
        btn:SetText(stepLabels[i])
        
        if i == 1 then
            btn:SetPoint("LEFT", breadcrumbFrame, "LEFT", 30, 0)
        else
            btn:SetPoint("LEFT", stepButtons[i-1], "RIGHT", 10, 0)
        end
        
        btn:SetScript("OnClick", function()
            ShowRLStep(i)
        end)
        
        stepButtons[i] = btn
    end
    
    -- ===================================================
    -- STEP 1: Difficulty Selection
    -- ===================================================
    local step1 = stepFrames[1]
    local header1 = step1:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header1:SetPoint("TOPLEFT", step1, "TOPLEFT", 10, -5)
    header1:SetText("Select Roguelike Base Difficulty")
    header1:SetTextColor(ACDM.Colors.Cyan.r, ACDM.Colors.Cyan.g, ACDM.Colors.Cyan.b)
    
    local diffContainer = CreateFrame("Frame", nil, step1)
    diffContainer:SetPoint("TOPLEFT", step1, "TOPLEFT", 5, -30)
    diffContainer:SetPoint("BOTTOMRIGHT", step1, "BOTTOMRIGHT", -5, 5)
    
    local diffButtons = {}
    for i = 1, 10 do
        local btn = CreateFrame("Button", nil, diffContainer, "UIPanelButtonTemplate")
        btn:SetHeight(28)
        btn:SetPoint("LEFT", diffContainer, "LEFT", 10, 0)
        btn:SetPoint("RIGHT", diffContainer, "RIGHT", -10, 0)
        btn:SetPoint("TOP", diffContainer, "TOP", 0, -(i-1)*31 - 5)
        
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", btn, "LEFT", 15, 0)
        btn.Text = text
        
        local subText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subText:SetPoint("RIGHT", btn, "RIGHT", -15, 0)
        btn.SubText = subText
        
        btn:Hide()
        diffButtons[i] = btn
    end
    
    function ACDM.RefreshRLDifficultyList()
        for i = 1, 10 do
            diffButtons[i]:Hide()
        end
        
        local pLvl = ACDM.flags.playerLevel or 1
        for idx, diff in ipairs(ACDM.difficulties) do
            if idx <= 10 then
                local btn = diffButtons[idx]
                btn:Show()
                local eligible = (pLvl >= diff.MinLevel)
                
                if not eligible then
                    btn.Text:SetText(ACDM.ColorText(diff.Name, ACDM.Colors.Grey) .. " " .. ACDM.ColorText("(Requires Lv " .. diff.MinLevel .. "+)", ACDM.Colors.Red))
                    btn.SubText:SetText(ACDM.ColorText("Locked", ACDM.Colors.Red))
                    btn:Disable()
                    btn:SetAlpha(0.5)
                else
                    btn:Enable()
                    btn:SetAlpha(1.0)
                    btn.Text:SetText(ACDM.ColorText(diff.Name, ACDM.Colors.Cyan) .. " " .. ACDM.ColorText("(Lv " .. diff.MinLevel .. "-" .. diff.MaxLevel .. ")", ACDM.Colors.Gold))
                    btn.SubText:SetText(ACDM.ColorText("Eligible", ACDM.Colors.Green))
                end
                
                btn:SetScript("OnClick", function()
                    rlSelection.diffId = diff.Id
                    ShowRLStep(2)
                end)
            end
        end
    end
    
    -- ===================================================
    -- STEP 2: Scaling
    -- ===================================================
    local step2 = stepFrames[2]
    local header2 = step2:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header2:SetPoint("TOPLEFT", step2, "TOPLEFT", 10, -5)
    header2:SetText("Choose Scaling Mode")
    header2:SetTextColor(ACDM.Colors.Cyan.r, ACDM.Colors.Cyan.g, ACDM.Colors.Cyan.b)
    
    local scalePartyBtn = CreateFrame("Button", nil, step2, "UIPanelButtonTemplate")
    scalePartyBtn:SetSize(320, 44)
    scalePartyBtn:SetPoint("TOP", step2, "TOP", 0, -40)
    scalePartyBtn:SetText("Scale to Party Level (Recommended)")
    
    local scalePartyDesc = step2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scalePartyDesc:SetPoint("TOP", scalePartyBtn, "BOTTOM", 0, -10)
    scalePartyDesc:SetWidth(380)
    scalePartyDesc:SetText("Dungeon creatures and bosses are dynamically scaled up or down to match your party's levels, ensuring a balanced challenge and proper rewards.")
    scalePartyDesc:SetTextColor(ACDM.Colors.Muted.r, ACDM.Colors.Muted.g, ACDM.Colors.Muted.b)
    
    local scaleDngBtn = CreateFrame("Button", nil, step2, "UIPanelButtonTemplate")
    scaleDngBtn:SetSize(320, 44)
    scaleDngBtn:SetPoint("TOP", scalePartyDesc, "BOTTOM", 0, -30)
    scaleDngBtn:SetText("Use Standard Dungeon Difficulty")
    
    local scaleDngDesc = step2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleDngDesc:SetPoint("TOP", scaleDngBtn, "BOTTOM", 0, -10)
    scaleDngDesc:SetWidth(380)
    scaleDngDesc:SetText("Creatures keep their natural dungeon levels. Recommended only if you want to run the dungeon at its standard level range.")
    scaleDngDesc:SetTextColor(ACDM.Colors.Muted.r, ACDM.Colors.Muted.g, ACDM.Colors.Muted.b)
    
    local backBtn2 = CreateFrame("Button", nil, step2, "UIPanelButtonTemplate")
    backBtn2:SetSize(120, 24)
    backBtn2:SetPoint("BOTTOM", step2, "BOTTOM", 0, 15)
    backBtn2:SetText("<< Back")
    
    scalePartyBtn:SetScript("OnClick", function()
        rlSelection.scaleParty = true
        ShowRLStep(3)
    end)
    scaleDngBtn:SetScript("OnClick", function()
        rlSelection.scaleParty = false
        ShowRLStep(3)
    end)
    backBtn2:SetScript("OnClick", function()
        ShowRLStep(1)
    end)
    
    -- ===================================================
    -- STEP 3: Theme Selection
    -- ===================================================
    local step3 = stepFrames[3]
    local header3 = step3:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header3:SetPoint("TOPLEFT", step3, "TOPLEFT", 10, -5)
    header3:SetText("Choose Creature Theme")
    header3:SetTextColor(ACDM.Colors.Cyan.r, ACDM.Colors.Cyan.g, ACDM.Colors.Cyan.b)
    
    local themeContainer = CreateFrame("Frame", nil, step3)
    themeContainer:SetPoint("TOPLEFT", step3, "TOPLEFT", 5, -30)
    themeContainer:SetSize(400, 300)
    
    local themeButtons = {}
    for i = 1, 16 do
        local btn = CreateFrame("Button", nil, themeContainer, "UIPanelButtonTemplate")
        btn:SetSize(190, 30)
        
        local col = ((i-1) % 2) + 1
        local row = math.floor((i-1) / 2) + 1
        
        if col == 1 then
            btn:SetPoint("TOPLEFT", themeContainer, "TOPLEFT", 20, -(row-1)*34 - 5)
        else
            btn:SetPoint("TOPLEFT", themeContainer, "TOPLEFT", 230, -(row-1)*34 - 5)
        end
        
        btn:Hide()
        themeButtons[i] = btn
    end
    
    local backBtn3 = CreateFrame("Button", nil, step3, "UIPanelButtonTemplate")
    backBtn3:SetSize(120, 24)
    backBtn3:SetPoint("BOTTOM", step3, "BOTTOM", 0, 15)
    backBtn3:SetText("<< Back")
    backBtn3:SetScript("OnClick", function() ShowRLStep(2) end)
    
    function ACDM.RefreshRLThemeList()
        for i = 1, 16 do
            themeButtons[i]:Hide()
        end
        for idx, theme in ipairs(ACDM.themes) do
            if idx <= 16 then
                local btn = themeButtons[idx]
                btn:Show()
                btn:SetText(theme.Name)
                btn:Enable()
                btn:SetScript("OnClick", function()
                    rlSelection.themeId = theme.Id
                    ShowRLStep(4)
                end)
            end
        end
    end
    
    -- ===================================================
    -- STEP 4: Confirmation Summary
    -- ===================================================
    local step4 = stepFrames[4]
    local header4 = step4:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header4:SetPoint("TOPLEFT", step4, "TOPLEFT", 10, -5)
    header4:SetText("Roguelike Setup Complete")
    header4:SetTextColor(ACDM.Colors.Cyan.r, ACDM.Colors.Cyan.g, ACDM.Colors.Cyan.b)
    
    local summaryFrame = CreateFrame("Frame", nil, step4)
    summaryFrame:SetPoint("TOPLEFT", step4, "TOPLEFT", 10, -35)
    summaryFrame:SetPoint("BOTTOMRIGHT", step4, "BOTTOMRIGHT", -10, 55)
    summaryFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 24, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    summaryFrame:SetBackdropColor(0.14, 0.14, 0.14, 1.0)
    summaryFrame:SetBackdropBorderColor(0, 0.8, 0.8, 0.8) -- Cyan border
    
    local sumText = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    sumText:SetPoint("TOP", summaryFrame, "TOP", 0, -15)
    sumText:SetText("Roguelike Run Summary")
    
    local function FormatGold(copperAmount)
        local g = math.floor(copperAmount / 10000)
        local s = math.floor((copperAmount % 10000) / 100)
        local c = math.floor(copperAmount % 100)
        
        local parts = {}
        if g > 0 then
            table.insert(parts, "|cffffd700" .. g .. "g|r")
        end
        if s > 0 then
            table.insert(parts, "|cffc7c7c7" .. s .. "s|r")
        end
        if c > 0 or (g == 0 and s == 0) then
            table.insert(parts, "|cffeda55f" .. c .. "c|r")
        end
        return table.concat(parts, " ")
    end

    local function CalculateEstimatedRLGold(diffId, scaleParty)
        local pLvl = ACDM.flags.playerLevel or UnitLevel("player") or 80
        local lvl = pLvl
        
        local diff = nil
        for _, d in ipairs(ACDM.difficulties) do
            if d.Id == diffId then
                diff = d
                break
            end
        end
        
        if not scaleParty and diff then
            lvl = math.floor((diff.MinLevel + diff.MaxLevel) / 2)
        end
        
        local levelScale = (lvl * lvl) / 400.0
        local baseGoldCfg = ACDM.flags.baseGold or 50000
        
        return baseGoldCfg * levelScale
    end

    local function GetRLGearText(tier)
        local epicChance = math.min(5 + (tier * 5), 80)
        local blueItems = 1
        local greenItems = 0
        local epicItems = 0
        
        if tier >= 9 then
            blueItems = 3
            epicItems = 1
        elseif tier >= 7 then
            blueItems = 2
            epicItems = 1
        elseif tier >= 5 then
            blueItems = 2
        elseif tier >= 3 then
            blueItems = 1
            greenItems = 1
        end
        
        local parts = {}
        if epicItems > 0 then
            if tier >= 9 then
                table.insert(parts, epicItems .. " Epic (25% Bonus)")
            else
                table.insert(parts, epicItems .. " Epic")
            end
        elseif epicChance > 0 then
            table.insert(parts, epicChance .. "% Epic")
        end
        
        if blueItems > 0 then
            table.insert(parts, blueItems .. " Rare")
        end
        if greenItems > 0 then
            table.insert(parts, greenItems .. " Uncommon")
        end
        
        return table.concat(parts, ", ")
    end

    local details = {}
    for i = 1, 6 do
        local det = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if i == 1 then
            det:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", 30, -35)
        else
            det:SetPoint("TOPLEFT", details[i-1], "BOTTOMLEFT", 0, -6)
        end
        det:SetPoint("RIGHT", summaryFrame, "RIGHT", -30, 0)
        det:SetJustifyH("LEFT")
        details[i] = det
    end
    
    local startBtn = CreateFrame("Button", nil, step4, "UIPanelButtonTemplate")
    startBtn:SetSize(220, 30)
    startBtn:SetPoint("BOTTOMRIGHT", step4, "BOTTOM", -5, 15)
    startBtn:SetText(">> START ROGUELIKE RUN <<")
    
    local backBtn4 = CreateFrame("Button", nil, step4, "UIPanelButtonTemplate")
    backBtn4:SetSize(120, 30)
    backBtn4:SetPoint("BOTTOMLEFT", step4, "BOTTOM", 5, 15)
    backBtn4:SetText("<< Back")
    backBtn4:SetScript("OnClick", function() ShowRLStep(3) end)

    local sep = summaryFrame:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", details[6], "BOTTOMLEFT", -10, -12)
    sep:SetPoint("TOPRIGHT", details[6], "BOTTOMRIGHT", 10, -12)
    sep:SetHeight(1)
    sep:SetTexture(0.4, 0.4, 0.4, 0.4)

    local infoHeader = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoHeader:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 10, -8)
    infoHeader:SetText("Module Rewards & Info")
    infoHeader:SetTextColor(ACDM.Colors.Cyan.r, ACDM.Colors.Cyan.g, ACDM.Colors.Cyan.b)

    local infoBullet1 = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoBullet1:SetPoint("TOPLEFT", infoHeader, "BOTTOMLEFT", 10, -6)
    infoBullet1:SetPoint("RIGHT", summaryFrame, "RIGHT", -20, 0)
    infoBullet1:SetJustifyH("LEFT")
    infoBullet1:SetText("• Scaling Rewards: Gold scales with Tier. Gear quality and quantity increase at higher Tiers.")

    local infoBullet2 = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoBullet2:SetPoint("TOPLEFT", infoBullet1, "BOTTOMLEFT", 0, -4)
    infoBullet2:SetPoint("RIGHT", summaryFrame, "RIGHT", -20, 0)
    infoBullet2:SetJustifyH("LEFT")
    infoBullet2:SetText("• Stacking Buffs: Players receive stacking stat buffs after clearing each floor.")

    local infoBullet3 = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoBullet3:SetPoint("TOPLEFT", infoBullet2, "BOTTOMLEFT", 0, -4)
    infoBullet3:SetPoint("RIGHT", summaryFrame, "RIGHT", -20, 0)
    infoBullet3:SetJustifyH("LEFT")
    infoBullet3:SetText("• Survival & Lives: Wipes consume lives. Remaining lives persist across floors; reaching every 10th floor restores 1 lost life.")
    
    function ACDM.ShowRLConfirmation()
        local diffName = "Unknown"
        local diffId = rlSelection.diffId or 1
        for _, d in ipairs(ACDM.difficulties) do
            if d.Id == diffId then diffName = d.Name break end
        end
        
        local themeName = "Random"
        for _, t in ipairs(ACDM.themes) do
            if t.Id == rlSelection.themeId then themeName = t.Name break end
        end
        
        local baseGold = CalculateEstimatedRLGold(diffId, rlSelection.scaleParty)
        local goldText = FormatGold(baseGold) .. " (+ " .. FormatGold(baseGold) .. " per tier)"
        local gearText = GetRLGearText(1) .. " (Improves per tier)"
        
        details[1]:SetText(ACDM.ColorText("Difficulty: ", ACDM.Colors.Cyan) .. ACDM.ColorText(diffName, ACDM.Colors.White))
        details[2]:SetText(ACDM.ColorText("Scaling Mode: ", ACDM.Colors.Cyan) .. (rlSelection.scaleParty and ACDM.ColorText("Scale to Party Level", ACDM.Colors.Green) or ACDM.ColorText("Dungeon Default", ACDM.Colors.Grey)))
        details[3]:SetText(ACDM.ColorText("Theme: ", ACDM.Colors.Cyan) .. ACDM.ColorText(themeName, ACDM.Colors.White))
        details[4]:SetText(ACDM.ColorText("Est. Tier 1 Gold: ", ACDM.Colors.Cyan) .. ACDM.ColorText(goldText, ACDM.Colors.White))
        details[5]:SetText(ACDM.ColorText("Est. Tier 1 Gear: ", ACDM.Colors.Cyan) .. ACDM.ColorText(gearText, ACDM.Colors.White))
        details[6]:SetText(ACDM.ColorText("Starting Affixes: ", ACDM.Colors.Cyan) .. ACDM.ColorText("None (Starts at Tier 3)", ACDM.Colors.White))
    end
    
    startBtn:SetScript("OnClick", function()
        local diff = rlSelection.diffId or 0
        local scale = rlSelection.scaleParty and 1 or 0
        local theme = rlSelection.themeId or 0
        ACDM.SendCommand(string.format(".dm roguelike %u %u %u", diff, scale, theme))
        startBtn:Disable()
        startBtn:SetText("Starting...")
    end)
    
    ACDM.OnBeginRoguelike = function(success, reason)
        startBtn:Enable()
        startBtn:SetText(">> START ROGUELIKE RUN <<")
        if success then
            ACDMMainFrame:Hide()
            UIErrorsFrame:AddMessage("Roguelike Run Started! Good luck!", 0, 1, 1, 1.0, 3)
        else
            UIErrorsFrame:AddMessage("Failed to start: " .. (reason or "Unknown"), 1, 0, 0, 1.0, 5)
        end
    end
    
    -- ===================================================
    -- FLOW SELECTOR / REFRESHER
    -- ===================================================
    function ACDM.RefreshRoguelikeFlow()
        if ACDM.flags.inRoguelike == 1 then
            wizardFrame:Hide()
            activeRunFrame:Show()
            arDetails1:SetText(ACDM.ColorText("Tier: " .. (ACDM.flags.rlTier or 1), ACDM.Colors.Cyan))
            arDetails2:SetText("Floors Cleared: " .. (ACDM.flags.rlFloors or 0))
        else
            activeRunFrame:Hide()
            wizardFrame:Show()
            if rlStep == 1 then
                ACDM.RefreshRLDifficultyList()
            end
        end
    end
    
    ShowRLStep(1)
end

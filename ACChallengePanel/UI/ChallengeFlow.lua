function ACDM.CreateChallengeFlow()
    local parent = ACDM.TabFrames[1]
    
    -- Selection state
    ACDM.selection.diffId = nil
    ACDM.selection.scaleParty = true
    ACDM.selection.themeId = nil
    ACDM.selection.mapId = nil
    
    local currentStep = 1
    
    -- Info box at top explaining rules
    local infoBox = CreateFrame("Frame", nil, parent)
    infoBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -5)
    infoBox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -5)
    infoBox:SetHeight(76)
    infoBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    infoBox:SetBackdropColor(0.02, 0.04, 0.08, 0.95)
    infoBox:SetBackdropBorderColor(0.82, 0.68, 0.32, 0.6) -- Gold border for Challenge
    
    local rule1 = infoBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rule1:SetPoint("TOPLEFT", infoBox, "TOPLEFT", 15, -10)
    rule1:SetText("• Set up custom dungeon runs with tailored difficulties and creature themes.")
    rule1:SetTextColor(ACDM.Colors.Gold.r, ACDM.Colors.Gold.g, ACDM.Colors.Gold.b)
    
    local rule2 = infoBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rule2:SetPoint("TOPLEFT", rule1, "BOTTOMLEFT", 0, -6)
    rule2:SetText("• Enable Party Scaling to automatically adjust creature levels to match your group.")
    
    local rule3 = infoBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rule3:SetPoint("TOPLEFT", rule2, "BOTTOMLEFT", 0, -6)
    rule3:SetText("• Complete challenges to earn rewards and track your fastest clear times.")

    -- Sub-frames for each step
    local stepFrames = {}
    for i = 1, 5 do
        stepFrames[i] = CreateFrame("Frame", nil, parent)
        stepFrames[i]:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -118)
        stepFrames[i]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)
        stepFrames[i]:Hide()
    end
    
    -- 1. Breadcrumbs
    local breadcrumbFrame = CreateFrame("Frame", nil, parent)
    breadcrumbFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -83)
    breadcrumbFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -83)
    breadcrumbFrame:SetHeight(30)
    
    local stepLabels = { "Difficulty", "Scaling", "Theme", "Dungeon", "Confirm" }
    local stepButtons = {}
    
    local function UpdateBreadcrumbs()
        for i = 1, 5 do
            local btn = stepButtons[i]
            if i < currentStep then
                btn:Enable()
                btn:UnlockHighlight()
            elseif i == currentStep then
                btn:Disable()
                btn:LockHighlight()
            else
                btn:Disable()
                btn:UnlockHighlight()
            end
        end
    end
    
    local function ShowStep(step)
        for i = 1, 5 do
            if i == step then
                stepFrames[i]:Show()
            else
                stepFrames[i]:Hide()
            end
        end
        currentStep = step
        UpdateBreadcrumbs()
        
        -- Refresh specific step data
        if step == 1 then
            ACDM.RefreshDifficultyList()
        elseif step == 3 then
            ACDM.RefreshThemeList()
        elseif step == 4 then
            ACDM.RefreshDungeonList()
        elseif step == 5 then
            ACDM.ShowConfirmation()
        end
    end
    
    for i = 1, 5 do
        local btn = CreateFrame("Button", nil, breadcrumbFrame, "UIPanelButtonTemplate")
        btn:SetSize(90, 22)
        btn:SetText(stepLabels[i])
        
        if i == 1 then
            btn:SetPoint("LEFT", breadcrumbFrame, "LEFT", 13, 0)
        else
            btn:SetPoint("LEFT", stepButtons[i-1], "RIGHT", 6, 0)
        end
        
        btn:SetScript("OnClick", function()
            ShowStep(i)
        end)
        
        stepButtons[i] = btn
    end
    
    -- ==========================================
    -- STEP 1: Difficulty
    -- ==========================================
    local step1 = stepFrames[1]
    local header1 = step1:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header1:SetPoint("TOPLEFT", step1, "TOPLEFT", 10, -5)
    header1:SetText("Select Challenge Difficulty")
    header1:SetTextColor(ACDM.Colors.Gold.r, ACDM.Colors.Gold.g, ACDM.Colors.Gold.b)
    
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
    
    function ACDM.RefreshDifficultyList()
        for i = 1, 10 do
            diffButtons[i]:Hide()
        end
        
        local pLvl = ACDM.flags.playerLevel or 1
        for idx, diff in ipairs(ACDM.difficulties) do
            if idx <= 10 then
                local btn = diffButtons[idx]
                btn:Show()
                
                local eligible = (pLvl >= diff.MinLevel)
                local onLevel = (pLvl >= diff.MinLevel and pLvl <= diff.MaxLevel)
                
                if not eligible then
                    btn.Text:SetText(ACDM.ColorText(diff.Name, ACDM.Colors.Grey) .. " " .. ACDM.ColorText("(Requires Lv " .. diff.MinLevel .. "+)", ACDM.Colors.Red))
                    btn.SubText:SetText(ACDM.ColorText("Locked", ACDM.Colors.Red))
                    btn:Disable()
                    btn:SetAlpha(0.5)
                else
                    btn:Enable()
                    btn:SetAlpha(1.0)
                    if onLevel then
                        btn.Text:SetText(ACDM.ColorText(diff.Name, ACDM.Colors.Green) .. " " .. ACDM.ColorText("(Lv " .. diff.MinLevel .. "-" .. diff.MaxLevel .. ")", ACDM.Colors.Gold))
                        btn.SubText:SetText(ACDM.ColorText("Eligible", ACDM.Colors.Green))
                    else
                        -- Over level (Easy)
                        btn.Text:SetText(ACDM.ColorText(diff.Name, ACDM.Colors.White) .. " " .. ACDM.ColorText("(Lv " .. diff.MinLevel .. "-" .. diff.MaxLevel .. " - Easy)", ACDM.Colors.Grey))
                        btn.SubText:SetText(ACDM.ColorText("Easy", ACDM.Colors.Grey))
                    end
                end
                
                btn:SetScript("OnClick", function()
                    ACDM.selection.diffId = diff.Id
                    ShowStep(2)
                end)
            end
        end
    end
    
    -- ==========================================
    -- STEP 2: Scaling Options
    -- ==========================================
    local step2 = stepFrames[2]
    local header2 = step2:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header2:SetPoint("TOPLEFT", step2, "TOPLEFT", 10, -5)
    header2:SetText("Choose Challenge Scaling Mode")
    header2:SetTextColor(ACDM.Colors.Gold.r, ACDM.Colors.Gold.g, ACDM.Colors.Gold.b)
    
    local scalePartyBtn = CreateFrame("Button", nil, step2, "UIPanelButtonTemplate")
    scalePartyBtn:SetSize(320, 48)
    scalePartyBtn:SetPoint("TOP", step2, "TOP", 0, -60)
    scalePartyBtn:SetText("Scale to Party Level (Recommended)")
    
    local scalePartyDesc = step2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scalePartyDesc:SetPoint("TOP", scalePartyBtn, "BOTTOM", 0, -10)
    scalePartyDesc:SetWidth(380)
    scalePartyDesc:SetText("Dungeon creatures and bosses are dynamically scaled up or down to match your party's levels, ensuring a balanced challenge and proper rewards.")
    scalePartyDesc:SetTextColor(ACDM.Colors.Muted.r, ACDM.Colors.Muted.g, ACDM.Colors.Muted.b)
    
    local scaleDngBtn = CreateFrame("Button", nil, step2, "UIPanelButtonTemplate")
    scaleDngBtn:SetSize(320, 48)
    scaleDngBtn:SetPoint("TOP", scalePartyDesc, "BOTTOM", 0, -40)
    scaleDngBtn:SetText("Use Default Dungeon Level/Difficulty")
    
    local scaleDngDesc = step2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleDngDesc:SetPoint("TOP", scaleDngBtn, "BOTTOM", 0, -10)
    scaleDngDesc:SetWidth(380)
    scaleDngDesc:SetText("Creatures keep their natural dungeon levels. Recommended only if you want to run the dungeon at its standard level range.")
    scaleDngDesc:SetTextColor(ACDM.Colors.Muted.r, ACDM.Colors.Muted.g, ACDM.Colors.Muted.b)
    
    scalePartyBtn:SetScript("OnClick", function()
        ACDM.selection.scaleParty = true
        ShowStep(3)
    end)
    
    scaleDngBtn:SetScript("OnClick", function()
        ACDM.selection.scaleParty = false
        ShowStep(3)
    end)

    local backBtn2 = CreateFrame("Button", nil, step2, "UIPanelButtonTemplate")
    backBtn2:SetSize(120, 24)
    backBtn2:SetPoint("BOTTOM", step2, "BOTTOM", 0, 15)
    backBtn2:SetText("<< Back")
    backBtn2:SetScript("OnClick", function()
        ShowStep(1)
    end)
    
    -- ==========================================
    -- STEP 3: Theme Selection
    -- ==========================================
    local step3 = stepFrames[3]
    local header3 = step3:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header3:SetPoint("TOPLEFT", step3, "TOPLEFT", 10, -5)
    header3:SetText("Select Creature Theme")
    header3:SetTextColor(ACDM.Colors.Gold.r, ACDM.Colors.Gold.g, ACDM.Colors.Gold.b)
    
    local themeContainer = CreateFrame("Frame", nil, step3)
    themeContainer:SetPoint("TOPLEFT", step3, "TOPLEFT", 5, -30)
    themeContainer:SetSize(400, 300)
    -- Align to grid or vertical list. Since there can be up to 10-15 themes, we'll do 2 columns.
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
    
    function ACDM.RefreshThemeList()
        for i = 1, 16 do
            themeButtons[i]:Hide()
        end
        for idx, theme in ipairs(ACDM.themes) do
            if idx <= 16 then
                local btn = themeButtons[idx]
                btn:Show()
                btn:SetText(theme.Name)
                btn:SetScript("OnClick", function()
                    ACDM.selection.themeId = theme.Id
                    ShowStep(4)
                end)
            end
        end
    end

    local backBtn3 = CreateFrame("Button", nil, step3, "UIPanelButtonTemplate")
    backBtn3:SetSize(120, 24)
    backBtn3:SetPoint("BOTTOM", step3, "BOTTOM", 0, 15)
    backBtn3:SetText("<< Back")
    backBtn3:SetScript("OnClick", function()
        ShowStep(2)
    end)
    
    -- ==========================================
    -- STEP 4: Dungeon Selection
    -- ==========================================
    local step4 = stepFrames[4]
    local header4 = step4:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header4:SetPoint("TOPLEFT", step4, "TOPLEFT", 10, -5)
    header4:SetText("Select Dungeon")
    header4:SetTextColor(ACDM.Colors.Gold.r, ACDM.Colors.Gold.g, ACDM.Colors.Gold.b)
    
    -- Random dungeon button
    local randomDngBtn = CreateFrame("Button", nil, step4, "UIPanelButtonTemplate")
    randomDngBtn:SetSize(400, 28)
    randomDngBtn:SetPoint("TOP", step4, "TOP", 0, -30)
    randomDngBtn:SetText("RANDOM DUNGEON (Recommended)")
    randomDngBtn:SetScript("OnClick", function()
        ACDM.selection.mapId = 0
        ShowStep(5)
    end)
    
    -- Filtered dungeon scroll frame
    local listFrame = CreateFrame("Frame", nil, step4)
    listFrame:SetPoint("TOPLEFT", step4, "TOPLEFT", 10, -64)
    listFrame:SetPoint("BOTTOMRIGHT", step4, "BOTTOMRIGHT", -30, 40)
    listFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    listFrame:SetBackdropColor(0, 0, 0, 0.6)
    listFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.4)
    
    local scrollFrame = CreateFrame("ScrollFrame", "ACDMChallengeDngScroll", listFrame, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -4, 4)
    
    local dungeonsData = {}
    
    local rows = {}
    for i = 1, 7 do
        local row = CreateFrame("Button", nil, listFrame, "UIPanelButtonTemplate")
        row:SetHeight(26)
        row:SetPoint("LEFT", listFrame, "LEFT", 8, 0)
        row:SetPoint("RIGHT", listFrame, "RIGHT", -8, 0)
        row:SetPoint("TOP", listFrame, "TOP", 0, -(i-1)*28 - 5)
        
        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", row, "LEFT", 15, 0)
        row.Text = text
        
        row:Hide()
        rows[i] = row
    end
    
    local function UpdateDungeonListScroll()
        local size = #dungeonsData
        FauxScrollFrame_Update(scrollFrame, size, 7, 28)
        local offset = FauxScrollFrame_GetOffset(scrollFrame)
        
        for i = 1, 7 do
            local idx = offset + i
            local row = rows[i]
            if idx <= size then
                local data = dungeonsData[idx]
                row:Show()
                row.Text:SetText(data.Name .. " " .. ACDM.ColorText("(Lv " .. data.MinLevel .. "-" .. data.MaxLevel .. ")", ACDM.Colors.Muted))
                row:SetScript("OnClick", function()
                    ACDM.selection.mapId = data.MapId
                    ShowStep(5)
                end)
            else
                row:Hide()
            end
        end
    end
    
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 28, UpdateDungeonListScroll)
    end)
    
    function ACDM.RefreshDungeonList()
        dungeonsData = {}
        -- Find selected difficulty details to filter level range
        local diff = nil
        for _, d in ipairs(ACDM.difficulties) do
            if d.Id == ACDM.selection.diffId then
                diff = d
                break
            end
        end
        
        local pLvl = ACDM.flags.playerLevel or 1
        if diff then
            -- Filter
            for _, dg in ipairs(ACDM.dungeons) do
                if dg.MinLevel <= diff.MaxLevel and dg.MaxLevel >= diff.MinLevel and pLvl >= dg.MinLevel then
                    table.insert(dungeonsData, dg)
                end
            end
            
            -- Sort alphabetically
            table.sort(dungeonsData, function(a, b) return a.Name < b.Name end)
        end
        
        UpdateDungeonListScroll()
    end

    local backBtn4 = CreateFrame("Button", nil, step4, "UIPanelButtonTemplate")
    backBtn4:SetSize(120, 24)
    backBtn4:SetPoint("BOTTOM", step4, "BOTTOM", 0, 15)
    backBtn4:SetText("<< Back")
    backBtn4:SetScript("OnClick", function()
        ShowStep(3)
    end)
    
    -- ==========================================
    -- STEP 5: Confirm Summary
    -- ==========================================
    local step5 = stepFrames[5]
    local header5 = step5:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header5:SetPoint("TOPLEFT", step5, "TOPLEFT", 10, -5)
    header5:SetText("Challenge Setup Complete")
    header5:SetTextColor(ACDM.Colors.Gold.r, ACDM.Colors.Gold.g, ACDM.Colors.Gold.b)
    
    local summaryFrame = CreateFrame("Frame", nil, step5)
    summaryFrame:SetPoint("TOPLEFT", step5, "TOPLEFT", 10, -40)
    summaryFrame:SetPoint("BOTTOMRIGHT", step5, "BOTTOMRIGHT", -10, 55)
    summaryFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 24, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    summaryFrame:SetBackdropColor(0.14, 0.14, 0.14, 1.0)
    summaryFrame:SetBackdropBorderColor(0.82, 0.68, 0.32, 0.8)
    
    local sumText = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    sumText:SetPoint("TOP", summaryFrame, "TOP", 0, -20)
    sumText:SetText("Challenge Summary")
    
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

    local function CalculateEstimatedGold(diffId, mapId, scaleParty)
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
        local goldPerMobCfg = ACDM.flags.goldPerMob or 50
        local goldPerBossCfg = ACDM.flags.goldPerBoss or 10000
        
        local rewardMult = diff and diff.RewardMultiplier or 1.0
        local mobCountMult = diff and diff.MobCountMultiplier or 1.0
        
        local baseGold = baseGoldCfg * levelScale
        local bossGold = goldPerBossCfg * 1 * levelScale
        
        if mapId and mapId > 0 then
            local dungeon = nil
            for _, dg in ipairs(ACDM.dungeons) do
                if dg.MapId == mapId then
                    dungeon = dg
                    break
                end
            end
            
            local spawnCount = dungeon and dungeon.Spawns or 80
            local fatigueMult = dungeon and (dungeon.Fatigue / 100.0) or 1.0
            
            local mobsToSpawn = math.floor(spawnCount * mobCountMult)
            local mobGold = goldPerMobCfg * mobsToSpawn * levelScale
            
            local total = (baseGold + mobGold + bossGold) * rewardMult * fatigueMult
            return total, fatigueMult, false
        else
            local minSpawns = 9999
            local maxSpawns = 0
            local totalSpawns = 0
            local count = 0
            
            for _, dg in ipairs(ACDM.dungeons) do
                if dg.MinLevel <= pLvl and dg.MaxLevel >= pLvl then
                    local sCount = dg.Spawns or 80
                    if sCount > 0 then
                        if sCount < minSpawns then minSpawns = sCount end
                        if sCount > maxSpawns then maxSpawns = sCount end
                        totalSpawns = totalSpawns + sCount
                        count = count + 1
                    end
                end
            end
            
            if count == 0 then
                minSpawns = 50
                maxSpawns = 120
                totalSpawns = 80
                count = 1
            end
            
            local avgSpawns = totalSpawns / count
            
            local minMobs = math.floor(minSpawns * mobCountMult)
            local maxMobs = math.floor(maxSpawns * mobCountMult)
            local avgMobs = math.floor(avgSpawns * mobCountMult)
            
            local minGold = (baseGold + (goldPerMobCfg * minMobs * levelScale) + bossGold) * rewardMult
            local maxGold = (baseGold + (goldPerMobCfg * maxMobs * levelScale) + bossGold) * rewardMult
            local avgGold = (baseGold + (goldPerMobCfg * avgMobs * levelScale) + bossGold) * rewardMult
            
            return avgGold, 1.0, true, minGold, maxGold
        end
    end

    local details = {}
    for i = 1, 7 do
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

    local startBtn = CreateFrame("Button", nil, step5, "UIPanelButtonTemplate")
    startBtn:SetSize(220, 30)
    startBtn:SetPoint("BOTTOMRIGHT", step5, "BOTTOM", -5, 15)
    startBtn:SetText(">> START CHALLENGE <<")

    local cancelBtn = CreateFrame("Button", nil, step5, "UIPanelButtonTemplate")
    cancelBtn:SetSize(120, 30)
    cancelBtn:SetPoint("BOTTOMLEFT", step5, "BOTTOM", 5, 15)
    cancelBtn:SetText("<< Back")

    local sep = summaryFrame:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", details[7], "BOTTOMLEFT", -10, -12)
    sep:SetPoint("TOPRIGHT", details[7], "BOTTOMRIGHT", 10, -12)
    sep:SetHeight(1)
    sep:SetTexture(0.4, 0.4, 0.4, 0.4)

    local infoHeader = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoHeader:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 10, -8)
    infoHeader:SetText("Module Rewards & Info")
    infoHeader:SetTextColor(ACDM.Colors.Gold.r, ACDM.Colors.Gold.g, ACDM.Colors.Gold.b)

    local infoBullet1 = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoBullet1:SetPoint("TOPLEFT", infoHeader, "BOTTOMLEFT", 10, -6)
    infoBullet1:SetPoint("RIGHT", summaryFrame, "RIGHT", -20, 0)
    infoBullet1:SetJustifyH("LEFT")
    infoBullet1:SetText("• Gold & Gear scale dynamically to player level and class/spec.")

    local infoBullet2 = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoBullet2:SetPoint("TOPLEFT", infoBullet1, "BOTTOMLEFT", 0, -4)
    infoBullet2:SetPoint("RIGHT", summaryFrame, "RIGHT", -20, 0)
    infoBullet2:SetJustifyH("LEFT")
    infoBullet2:SetText("• Speed Bonus: Complete fast for up to +25% Gold.")

    local infoBullet3 = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoBullet3:SetPoint("TOPLEFT", infoBullet2, "BOTTOMLEFT", 0, -4)
    infoBullet3:SetPoint("RIGHT", summaryFrame, "RIGHT", -20, 0)
    infoBullet3:SetJustifyH("LEFT")
    infoBullet3:SetText("• Fatigue: Running the same dungeon repeatedly inflicts Dungeon Fatigue.")

    function ACDM.ShowConfirmation()
        local diffId = ACDM.selection.diffId or 1
        local mapId = ACDM.selection.mapId or 0
        local scaleParty = ACDM.selection.scaleParty
        
        local diff = nil
        local diffName = "Unknown"
        for _, d in ipairs(ACDM.difficulties) do
            if d.Id == diffId then 
                diff = d
                diffName = d.Name 
                break 
            end
        end
        
        local themeName = "Random"
        for _, t in ipairs(ACDM.themes) do
            if t.Id == ACDM.selection.themeId then themeName = t.Name break end
        end
        
        local dungeonName = "Random Dungeon"
        if mapId and mapId > 0 then
            for _, dg in ipairs(ACDM.dungeons) do
                if dg.MapId == mapId then dungeonName = dg.Name break end
            end
        end
        
        local goldAvg, fatigueMult, isRandom, goldMin, goldMax = CalculateEstimatedGold(diffId, mapId, scaleParty)
        
        local fatigueText = ""
        local fatiguePercent = math.floor(fatigueMult * 100)
        if fatiguePercent == 100 then
            fatigueText = "|cff00ff00100% (Full Rewards)|r"
        elseif fatiguePercent == 75 then
            fatigueText = "|cffff800075% (Light Fatigue)|r"
        else
            fatigueText = "|cffff000050% (Heavy Fatigue - Repeat Penalty)|r"
        end
        
        local goldText = ""
        if isRandom then
            goldText = "~" .. FormatGold(goldAvg) .. " (" .. FormatGold(goldMin) .. " - " .. FormatGold(goldMax) .. ")"
        else
            goldText = FormatGold(goldAvg)
        end
        
        local itemChance = math.floor((ACDM.flags.itemChance or 80) * fatigueMult)
        local epicChance = ACDM.flags.epicChance or 15
        local rareChance = ACDM.flags.rareChance or 40
        local gearText = itemChance .. "% chance (" .. epicChance .. "% Epic, " .. rareChance .. "% Rare)"
        
        details[1]:SetText(ACDM.ColorText("Difficulty: ", ACDM.Colors.Gold) .. ACDM.ColorText(diffName, ACDM.Colors.White))
        details[2]:SetText(ACDM.ColorText("Scaling Mode: ", ACDM.Colors.Gold) .. (scaleParty and ACDM.ColorText("Scale to Party Level", ACDM.Colors.Green) or ACDM.ColorText("Dungeon Default", ACDM.Colors.Grey)))
        details[3]:SetText(ACDM.ColorText("Theme: ", ACDM.Colors.Gold) .. ACDM.ColorText(themeName, ACDM.Colors.White))
        details[4]:SetText(ACDM.ColorText("Dungeon: ", ACDM.Colors.Gold) .. ACDM.ColorText(dungeonName, ACDM.Colors.White))
        details[5]:SetText(ACDM.ColorText("Rewards Mult: ", ACDM.Colors.Gold) .. fatigueText)
        details[6]:SetText(ACDM.ColorText("Est. Gold: ", ACDM.Colors.Gold) .. goldText)
        details[7]:SetText(ACDM.ColorText("Est. Gear: ", ACDM.Colors.Gold) .. ACDM.ColorText(gearText, ACDM.Colors.White))
    end
    
    startBtn:SetScript("OnClick", function()
        local diff = ACDM.selection.diffId or 0
        local scale = ACDM.selection.scaleParty and 1 or 0
        local theme = ACDM.selection.themeId or 0
        local map = ACDM.selection.mapId or 0
        ACDM.SendCommand(string.format(".dm begin %u %u %u %u", diff, scale, theme, map))
        startBtn:Disable()
        startBtn:SetText("Starting...")
    end)
    
    cancelBtn:SetScript("OnClick", function()
        ShowStep(4)
    end)
    
    ACDM.OnBeginChallenge = function(success, reason)
        startBtn:Enable()
        startBtn:SetText(">> START CHALLENGE <<")
        if success then
            ACDMMainFrame:Hide()
            UIErrorsFrame:AddMessage("Challenge started successfully!", 0, 1, 0, 1.0, 3)
        else
            UIErrorsFrame:AddMessage("Failed to start: " .. (reason or "Unknown error"), 1, 0, 0, 1.0, 5)
        end
    end
    
    ACDM.RefreshChallengeFlow = function()
        if currentStep == 1 then
            ACDM.RefreshDifficultyList()
        end
    end
    
    -- Show Step 1 initially
    ShowStep(1)
end

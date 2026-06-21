function ACDM.CreateActiveRunPanel()
    local parent = ACDM.TabFrames[3] -- Tab 3 is "Active Run"
    
    local function SetTextColor(fontString, color)
        fontString:SetTextColor(color.r, color.g, color.b)
    end

    -- Title Header
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -8)
    header:SetText("Active Run Status")
    SetTextColor(header, ACDM.Colors.Gold)

    local subtitle = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("Monitor active challenge status, track boss coordinates, and reset stuck bosses.")
    SetTextColor(subtitle, ACDM.Colors.Muted)

    -- Status Badge / Banner at the top-right
    local statusBadge = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statusBadge:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -15, -10)
    statusBadge:SetText("|cff808080Status:|r |cffff0000INACTIVE|r")

    -- 1. Dungeon & Session Status Card
    local detailsCard = CreateFrame("Frame", nil, parent)
    detailsCard:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -55)
    detailsCard:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -55)
    detailsCard:SetHeight(130)
    detailsCard:SetFrameLevel(parent:GetFrameLevel() + 2)
    detailsCard:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 24, edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    detailsCard:SetBackdropColor(0.14, 0.14, 0.14, 1.0)
    detailsCard:SetBackdropBorderColor(0.82, 0.68, 0.32, 0.8)

    local dngLabel = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dngLabel:SetPoint("TOPLEFT", detailsCard, "TOPLEFT", 20, -15)
    dngLabel:SetText("No Active Session")
    SetTextColor(dngLabel, ACDM.Colors.White)

    local timerLabel = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    timerLabel:SetPoint("TOPRIGHT", detailsCard, "TOPRIGHT", -20, -15)
    timerLabel:SetText("--:--")
    SetTextColor(timerLabel, ACDM.Colors.Gold)

    -- Details fields
    local detailTexts = {}
    for i = 1, 3 do
        local t = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetPoint("TOPLEFT", detailsCard, "TOPLEFT", 20, -45 - (i-1)*22)
        t:SetJustifyH("LEFT")
        detailTexts[i] = t
    end

    -- Gambits Section
    local gambitsLabel = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gambitsLabel:SetPoint("TOPLEFT", detailsCard, "TOPLEFT", 20, -114)
    gambitsLabel:SetText("Gambits:")
    SetTextColor(gambitsLabel, ACDM.Colors.Gold)
    gambitsLabel:Hide()

    local gambitLabels = { "Time Trial", "Glass Cannon", "Pacifist" }
    local gambitTooltips = {
        "Time Trial: Complete the floor within a strict time limit. (+25% reward bonus)",
        "Glass Cannon: Deal 50% more damage, but take 50% more damage. (+25% reward bonus)",
        "Pacifist: Trash mobs yield no loot or gold. (+25% reward bonus)"
    }
    local gambitCBs = {}
    for i = 1, 3 do
        local cb = CreateFrame("CheckButton", "ACDMGambitCheck" .. i, detailsCard, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        if i == 1 then
            cb:SetPoint("LEFT", gambitsLabel, "RIGHT", 15, 0)
        elseif i == 2 then
            cb:SetPoint("LEFT", gambitCBs[1].Text, "RIGHT", 25, 0)
        else
            cb:SetPoint("LEFT", gambitCBs[2].Text, "RIGHT", 25, 0)
        end
        
        local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        text:SetText(gambitLabels[i])
        cb.Text = text

        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(gambitLabels[i], 1, 0.82, 0.35)
            GameTooltip:AddLine(gambitTooltips[i], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)

        cb:SetScript("OnClick", function(self)
            ACDM.SendCommand(".dm rltogglegambit " .. i)
        end)

        cb:Hide()
        gambitCBs[i] = cb
    end

    -- Active Affixes Section
    local affixesLabel = detailsCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    affixesLabel:SetPoint("TOPLEFT", detailsCard, "TOPLEFT", 20, -148)
    affixesLabel:SetText("Active Affixes:")
    SetTextColor(affixesLabel, ACDM.Colors.Gold)

    local affixIcons = {}
    for i = 1, 3 do
        local btn = CreateFrame("Button", nil, detailsCard)
        btn:SetSize(26, 26)
        if i == 1 then
            btn:SetPoint("LEFT", affixesLabel, "RIGHT", 10, 0)
        else
            btn:SetPoint("LEFT", affixIcons[i-1], "RIGHT", 8, 0)
        end

        local tex = btn:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        btn.Icon = tex

        local border = btn:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetSize(42, 42)
        border:SetPoint("CENTER", btn, "CENTER", 0, 0)
        border:SetBlendMode("ADD")
        btn.Border = border

        -- Veto button overlay
        local veto = CreateFrame("Button", nil, btn)
        veto:SetSize(14, 14)
        veto:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 3, 3)
        veto:SetFrameLevel(btn:GetFrameLevel() + 5)
        
        local vetoTex = veto:CreateTexture(nil, "ARTWORK")
        vetoTex:SetAllPoints()
        vetoTex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        veto.Icon = vetoTex
        
        veto:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        
        veto:SetScript("OnLeave", function() GameTooltip:Hide() end)
        veto:Hide()
        btn.VetoButton = veto

        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:Hide()
        affixIcons[i] = btn
    end
    detailsCard.gambitsLabel = gambitsLabel
    detailsCard.gambitCBs = gambitCBs
    detailsCard.affixesLabel = affixesLabel
    detailsCard.affixIcons = affixIcons

    -- 2. Boss Tracker Card
    local bossCard = CreateFrame("Frame", nil, parent)
    bossCard:SetPoint("TOPLEFT", detailsCard, "BOTTOMLEFT", 0, -15)
    bossCard:SetPoint("TOPRIGHT", detailsCard, "BOTTOMRIGHT", 0, -15)
    bossCard:SetHeight(230)
    bossCard:SetFrameLevel(parent:GetFrameLevel() + 2)
    bossCard:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 24, edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bossCard:SetBackdropColor(0.14, 0.14, 0.14, 1.0)
    bossCard:SetBackdropBorderColor(0.82, 0.68, 0.32, 0.8)

    local bossTitle = bossCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bossTitle:SetPoint("TOPLEFT", bossCard, "TOPLEFT", 20, -15)
    bossTitle:SetText("ACTIVE BOSS TRACKING")
    SetTextColor(bossTitle, ACDM.Colors.Gold)

    local bossNameLabel = bossCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    bossNameLabel:SetPoint("TOPLEFT", bossTitle, "BOTTOMLEFT", 0, -8)
    bossNameLabel:SetText("No Active Boss")
    SetTextColor(bossNameLabel, ACDM.Colors.Grey)

    local bossCoordsLabel = bossCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bossCoordsLabel:SetPoint("TOPLEFT", bossNameLabel, "BOTTOMLEFT", 0, -4)
    bossCoordsLabel:SetText("Coordinates: N/A")
    SetTextColor(bossCoordsLabel, ACDM.Colors.Muted)

    -- Reset Boss Button
    local resetBtn = CreateFrame("Button", nil, bossCard, "UIPanelButtonTemplate")
    resetBtn:SetSize(280, 40)
    resetBtn:SetPoint("TOP", bossCard, "TOP", 0, -105)
    resetBtn:SetFrameLevel(bossCard:GetFrameLevel() + 2)
    resetBtn:SetText("Reset Boss")
    resetBtn:Disable()
    
    resetBtn:SetScript("OnClick", function()
        ACDM.SendCommand(".dm resetboss")
    end)

    local resetDesc = bossCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resetDesc:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", -60, -15)
    resetDesc:SetPoint("BOTTOMRIGHT", bossCard, "BOTTOMRIGHT", -20, 15)
    resetDesc:SetText("Teleports the active boss back to its initial spawn point, clears threat, and heals it to full. Use this if the boss gets stuck inside walls or falls through the floor. Cooldown: 10 minutes.")
    resetDesc:SetJustifyH("LEFT")
    resetDesc:SetJustifyV("TOP")
    SetTextColor(resetDesc, ACDM.Colors.Muted)

    -- Refresh UI Callback
    function ACDM.RefreshActiveRun()
        local inRun = (ACDM.flags.inSession == 1) or (ACDM.flags.inRoguelike == 1)
        
        -- Update Status Badge
        if ACDM.flags.sessionState == 4 then
            if ACDM.flags.inRoguelike == 1 then
                statusBadge:SetText("|cff808080Status:|r |cff00ff00FLOOR CLEARED|r")
            else
                statusBadge:SetText("|cff808080Status:|r |cff00ff00COMPLETED|r")
            end
        elseif ACDM.flags.inRoguelike == 1 then
            statusBadge:SetText("|cff808080Status:|r |cff00ffffROGUELIKE RUN|r")
        elseif ACDM.flags.inSession == 1 then
            statusBadge:SetText("|cff808080Status:|r |cff00ff00ACTIVE RUN|r")
        else
            statusBadge:SetText("|cff808080Status:|r |cffff0000INACTIVE|r")
        end

        if not inRun then
            -- Fallback Display
            dngLabel:SetText("No Active Session")
            SetTextColor(dngLabel, ACDM.Colors.Grey)
            timerLabel:SetText("--:--")
            detailTexts[1]:SetText(ACDM.ColorText("Difficulty: ", ACDM.Colors.Gold) .. ACDM.ColorText("N/A", ACDM.Colors.Grey))
            detailTexts[2]:SetText(ACDM.ColorText("Scaling Mode: ", ACDM.Colors.Gold) .. ACDM.ColorText("N/A", ACDM.Colors.Grey))
            detailTexts[3]:SetText(ACDM.ColorText("Theme: ", ACDM.Colors.Gold) .. ACDM.ColorText("N/A", ACDM.Colors.Grey))
            
            affixesLabel:Hide()
            gambitsLabel:Hide()
            for i = 1, 3 do
                affixIcons[i]:Hide()
                affixIcons[i].VetoButton:Hide()
                gambitCBs[i]:Hide()
            end
            detailsCard:SetHeight(130)

            bossNameLabel:SetText("No Active Boss")
            SetTextColor(bossNameLabel, ACDM.Colors.Grey)
            bossCoordsLabel:SetText("Coordinates: N/A")
            resetBtn:Disable()
            return
        end

        -- Active Display
        if inRun and (#ACDM.dungeons == 0) and (ACDM.queryState == "idle") then
            ACDM.RequestQuery()
        end

        SetTextColor(dngLabel, ACDM.Colors.White)
        detailsCard:SetHeight(185)
        
        -- Determine map name
        local dngName = "Dungeon Challenge"
        if ACDM.selection.mapId and ACDM.selection.mapId > 0 then
            for _, dg in ipairs(ACDM.dungeons) do
                if dg.MapId == ACDM.selection.mapId then
                    dngName = dg.Name
                    break
                end
            end
        elseif ACDM.flags.inRoguelike == 1 then
            dngName = "Roguelike: Tier " .. (ACDM.flags.rlTier or 1)
        end
        dngLabel:SetText(dngName)

        -- Detail fields
        local diffName = "Normal"
        if ACDM.selection.diffId then
            for _, d in ipairs(ACDM.difficulties) do
                if d.Id == ACDM.selection.diffId then diffName = d.Name break end
            end
        end

        local themeName = "Random Theme"
        if ACDM.selection.themeId then
            for _, t in ipairs(ACDM.themes) do
                if t.Id == ACDM.selection.themeId then themeName = t.Name break end
            end
        end

        detailTexts[1]:SetText(ACDM.ColorText("Difficulty: ", ACDM.Colors.Gold) .. ACDM.ColorText(diffName, ACDM.Colors.White))
        detailTexts[2]:SetText(ACDM.ColorText("Scaling Mode: ", ACDM.Colors.Gold) .. (ACDM.selection.scaleParty and ACDM.ColorText("Scale to Party Level", ACDM.Colors.Green) or ACDM.ColorText("Dungeon Default", ACDM.Colors.Grey)))
        detailTexts[3]:SetText(ACDM.ColorText("Theme: ", ACDM.Colors.Gold) .. ACDM.ColorText(themeName, ACDM.Colors.White))

        -- Update Gambits
        local isLeader = (GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0) or IsPartyLeader()
        local isPrep = (ACDM.flags.sessionState == 1)

        if ACDM.flags.inRoguelike == 1 then
            gambitsLabel:Show()

            local activeCount = 0
            local activeStates = {
                ACDM.flags.gambitTimeTrial == 1,
                ACDM.flags.gambitGlassCannon == 1,
                ACDM.flags.gambitPacifist == 1
            }
            for i = 1, 3 do
                if activeStates[i] then
                    activeCount = activeCount + 1
                end
            end

            for i = 1, 3 do
                local cb = gambitCBs[i]
                cb:Show()
                
                local active = activeStates[i]
                cb:SetChecked(active)
                
                if isLeader and isPrep then
                    if activeCount >= 2 and not active then
                        cb:Disable()
                        cb.Text:SetTextColor(ACDM.Colors.Grey.r, ACDM.Colors.Grey.g, ACDM.Colors.Grey.b)
                    else
                        cb:Enable()
                        cb.Text:SetTextColor(ACDM.Colors.White.r, ACDM.Colors.White.g, ACDM.Colors.White.b)
                    end
                else
                    cb:Disable()
                    if active then
                        cb.Text:SetTextColor(ACDM.Colors.Green.r, ACDM.Colors.Green.g, ACDM.Colors.Green.b)
                    else
                        cb.Text:SetTextColor(ACDM.Colors.Grey.r, ACDM.Colors.Grey.g, ACDM.Colors.Grey.b)
                    end
                end
            end
        else
            gambitsLabel:Hide()
            for i = 1, 3 do
                gambitCBs[i]:Hide()
            end
        end

        -- Update Veto tokens and overlay
        local vetoTokens = ACDM.flags.vetoTokens or 0
        if ACDM.flags.inRoguelike == 1 then
            affixesLabel:SetText("Active Affixes (Vetoes: " .. vetoTokens .. "):")
        else
            affixesLabel:SetText("Active Affixes:")
        end

        -- Update Active Affixes row
        local activeAffixes = ACDM.runInfo.activeAffixes or {}
        local numActive = #activeAffixes
        
        if numActive > 0 then
            affixesLabel:Show()
            
            for i = 1, 3 do
                local btn = affixIcons[i]
                if i <= numActive then
                    local affId = activeAffixes[i]
                    local info = ACDM.affixInfo[affId]
                    
                    if info then
                        local knownAffixMask = (ACDM.roguelikeStats and ACDM.roguelikeStats.knownAffixMask) or 0
                        local revealTier = ACDM.revealAffixTier or 5
                        local currentTier = ACDM.flags.rlTier or 1
                        
                        local bitVal = 2 ^ affId
                        local isKnown = (math.floor(knownAffixMask / bitVal) % 2 == 1)
                        local isRevealed = isKnown or (currentTier >= revealTier)
                        
                        if isRevealed then
                            btn.Icon:SetTexture(info.icon)
                            btn.Border:SetVertexColor(0.82, 0.68, 0.32) -- Gold border for active
                            btn.Border:Show()
                            
                            btn:SetScript("OnEnter", function(self)
                                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                GameTooltip:SetText(info.name, 1, 0.82, 0.35)
                                GameTooltip:AddLine(info.description, 1, 1, 1, true)
                                GameTooltip:Show()
                            end)
                        else
                            btn.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                            btn.Border:SetVertexColor(0.5, 0.5, 0.5) -- Gray border
                            btn.Border:Show()
                            
                            btn:SetScript("OnEnter", function(self)
                                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                GameTooltip:SetText("Undiscovered Affix", 1, 0.82, 0.35)
                                GameTooltip:AddLine("This affix is undiscovered. Clear dungeon floors at Tier " .. revealTier .. "+ or complete runs with this affix to reveal it.", 1, 1, 1, true)
                                GameTooltip:Show()
                            end)
                        end
                        
                        -- Veto overlay button logic
                        if isPrep and vetoTokens > 0 then
                            btn.VetoButton:Show()
                            btn.VetoButton:SetScript("OnClick", function()
                                ACDM.SendCommand(".dm rlveto " .. affId)
                            end)
                            btn.VetoButton:SetScript("OnEnter", function(self)
                                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                GameTooltip:SetText("Veto Affix", 1, 0.82, 0.35)
                                GameTooltip:AddLine("Spend 1 Veto Token to exclude this affix. Remaining tokens: " .. vetoTokens, 1, 1, 1, true)
                                GameTooltip:Show()
                            end)
                        else
                            btn.VetoButton:Hide()
                        end
                        
                        btn:Show()
                    else
                        btn:Hide()
                        btn.VetoButton:Hide()
                    end
                else
                    btn:Hide()
                    btn.VetoButton:Hide()
                end
            end
        else
            affixesLabel:Hide()
            for i = 1, 3 do
                affixIcons[i]:Hide()
                affixIcons[i].VetoButton:Hide()
            end
        end

        -- Boss Info
        if ACDM.flags.sessionState == 4 then
            local now = GetTime()
            local elapsedLocal = math.floor(now - (ACDM.runInfo.lastUpdate or now))
            local tpRem = math.max(0, (ACDM.runInfo.teleportRemaining or 0) - elapsedLocal)
            if tpRem > 0 then
                bossNameLabel:SetText(string.format("Teleporting in %d second%s...", tpRem, tpRem ~= 1 and "s" or ""))
                SetTextColor(bossNameLabel, ACDM.Colors.Gold)
                bossCoordsLabel:SetText("Boss Defeated! Dungeon challenge successful!")
            else
                bossNameLabel:SetText("Boss Defeated!")
                SetTextColor(bossNameLabel, ACDM.Colors.Green)
                bossCoordsLabel:SetText("Dungeon challenge successful!")
            end
            resetBtn:Disable()
        else
            local bName = ACDM.runInfo.bossName or "None"
            if bName == "None" or bName == "" then
                bossNameLabel:SetText("No Active Boss")
                SetTextColor(bossNameLabel, ACDM.Colors.Grey)
                bossCoordsLabel:SetText("Boss is currently not spawned or out of range.")
                resetBtn:Disable()
            else
                bossNameLabel:SetText(bName)
                SetTextColor(bossNameLabel, ACDM.Colors.Red)
                if ACDM.runInfo.bossX and ACDM.runInfo.bossX ~= 0 then
                    bossCoordsLabel:SetText(string.format("Coordinates: X=%.1f, Y=%.1f", ACDM.runInfo.bossX, ACDM.runInfo.bossY))
                else
                    bossCoordsLabel:SetText("Coordinates: Loaded in Instance")
                end
                
                -- Enable reset button only if boss is alive and reset cooldown is 0
                local now = GetTime()
                local elapsedLocal = math.floor(now - (ACDM.runInfo.lastUpdate or now))
                local cdRem = (ACDM.runInfo.bossResetCd or 0) - elapsedLocal
                if cdRem <= 0 then
                    resetBtn:Enable()
                    resetBtn:SetText("Reset Boss")
                else
                    resetBtn:Disable()
                end
            end
        end
        if ACDM.UpdateTrackerUI then
            ACDM.UpdateTrackerUI()
        end
    end

    -- Real-time ticker and cooldown update script
    local updateTimer = 0
    parent:SetScript("OnUpdate", function(self, elapsed)
        local inRun = (ACDM.flags.inSession == 1) or (ACDM.flags.inRoguelike == 1)
        if not inRun then return end
        
        updateTimer = updateTimer + elapsed
        if updateTimer >= 0.5 then
            updateTimer = 0
            
            local now = GetTime()
            local elapsedLocal = math.floor(now - (ACDM.runInfo.lastUpdate or now))
            
            -- 1. Tick run elapsed timer / prep countdown
            if ACDM.flags.sessionState == 1 then
                local prepRem = math.max(0, (ACDM.runInfo.preparationTimer or 30) - elapsedLocal)
                timerLabel:SetText(string.format("Prep: %ds", prepRem))
                timerLabel:SetTextColor(ACDM.Colors.Cyan.r, ACDM.Colors.Cyan.g, ACDM.Colors.Cyan.b)
            else
                local totalElapsed = (ACDM.runInfo.elapsed or 0) + elapsedLocal
                local m = math.floor(totalElapsed / 60)
                local s = totalElapsed % 60
                timerLabel:SetText(string.format("%02d:%02d", m, s))
                timerLabel:SetTextColor(ACDM.Colors.Gold.r, ACDM.Colors.Gold.g, ACDM.Colors.Gold.b)
            end

            -- 2. Tick boss reset cooldown button / teleport countdown
            if ACDM.flags.sessionState == 4 then
                resetBtn:Disable()
                resetBtn:SetText("Reset Boss")
                -- Tick the teleport countdown label
                local tpRem = math.max(0, (ACDM.runInfo.teleportRemaining or 0) - elapsedLocal)
                if tpRem > 0 then
                    bossNameLabel:SetText(string.format("Teleporting in %d second%s...", tpRem, tpRem ~= 1 and "s" or ""))
                    SetTextColor(bossNameLabel, ACDM.Colors.Gold)
                else
                    bossNameLabel:SetText("Boss Defeated!")
                    SetTextColor(bossNameLabel, ACDM.Colors.Green)
                end
            else
                local bName = ACDM.runInfo.bossName or "None"
                if bName ~= "None" and bName ~= "" then
                    local cdRem = (ACDM.runInfo.bossResetCd or 0) - elapsedLocal
                    if cdRem > 0 then
                        resetBtn:Disable()
                        local cdM = math.floor(cdRem / 60)
                        local cdS = cdRem % 60
                        resetBtn:SetText(string.format("Reset Boss (%02d:%02d)", cdM, cdS))
                    else
                        resetBtn:Enable()
                        resetBtn:SetText("Reset Boss")
                    end
                end
            end
        end
    end)

    -- Hook boss reset callbacks
    ACDM.OnResetBossComplete = function(success, reason)
        if success then
            UIErrorsFrame:AddMessage("Boss reset successful!", 0, 1, 0, 1.0, 3)
            ACDM.RequestQuery() -- fetch fresh runinfo to start the cooldown timer locally
        else
            UIErrorsFrame:AddMessage("Reset Failed: " .. (reason or "Unknown error"), 1, 0, 0, 1.0, 4)
        end
    end

    -- Initial load
    ACDM.RefreshActiveRun()
end

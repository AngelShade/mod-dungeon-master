function ACDM.CreateStatsPanel()
    local parent = ACDM.TabFrames[4]
    
    local currentView = "stats" -- "stats", "bestiary", "familiarity", "boards"
    local currentBoard = "normal" -- "normal", "rltier", "rlfloors"
    
    -- Sub-view containers
    local statsFrame = CreateFrame("Frame", nil, parent)
    statsFrame:SetAllPoints(parent)
    
    local bestiaryFrame = CreateFrame("Frame", nil, parent)
    bestiaryFrame:SetAllPoints(parent)
    bestiaryFrame:Hide()

    local familiarityFrame = CreateFrame("Frame", nil, parent)
    familiarityFrame:SetAllPoints(parent)
    familiarityFrame:Hide()

    local boardsFrame = CreateFrame("Frame", nil, parent)
    boardsFrame:SetAllPoints(parent)
    boardsFrame:Hide()
    
    -- Toggle buttons at the very top
    local toggleStatsBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    toggleStatsBtn:SetSize(110, 24)
    toggleStatsBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -5)
    toggleStatsBtn:SetText("My Stats")
    
    local toggleBestiaryBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    toggleBestiaryBtn:SetSize(110, 24)
    toggleBestiaryBtn:SetPoint("TOPLEFT", toggleStatsBtn, "TOPRIGHT", 5, 0)
    toggleBestiaryBtn:SetText("Bestiary")

    local toggleFamiliarityBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    toggleFamiliarityBtn:SetSize(110, 24)
    toggleFamiliarityBtn:SetPoint("TOPLEFT", toggleBestiaryBtn, "TOPRIGHT", 5, 0)
    toggleFamiliarityBtn:SetText("Familiarity")

    local toggleBoardsBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    toggleBoardsBtn:SetSize(110, 24)
    toggleBoardsBtn:SetPoint("TOPLEFT", toggleFamiliarityBtn, "TOPRIGHT", 5, 0)
    toggleBoardsBtn:SetText("Leaderboards")

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("RIGHT", parent, "TOPRIGHT", -15, -17)
    desc:SetText("View run records and stats.")
    desc:SetTextColor(ACDM.Colors.Muted.r, ACDM.Colors.Muted.g, ACDM.Colors.Muted.b)
    
    local function ShowView(view)
        currentView = view
        statsFrame:Hide()
        bestiaryFrame:Hide()
        familiarityFrame:Hide()
        boardsFrame:Hide()
        
        toggleStatsBtn:UnlockHighlight()
        toggleBestiaryBtn:UnlockHighlight()
        toggleFamiliarityBtn:UnlockHighlight()
        toggleBoardsBtn:UnlockHighlight()
        
        if view == "stats" then
            statsFrame:Show()
            toggleStatsBtn:LockHighlight()
            ACDM.RequestStats()
        elseif view == "bestiary" then
            bestiaryFrame:Show()
            toggleBestiaryBtn:LockHighlight()
            selectedBestiaryIndex = nil
            ACDM.RequestStats()
        elseif view == "familiarity" then
            familiarityFrame:Show()
            toggleFamiliarityBtn:LockHighlight()
            ACDM.RequestStats()
        elseif view == "boards" then
            boardsFrame:Show()
            toggleBoardsBtn:LockHighlight()
            ACDM.RequestBoards(currentBoard)
        end
    end
    
    toggleStatsBtn:SetScript("OnClick", function() ShowView("stats") end)
    toggleBestiaryBtn:SetScript("OnClick", function() ShowView("bestiary") end)
    toggleFamiliarityBtn:SetScript("OnClick", function() ShowView("familiarity") end)
    toggleBoardsBtn:SetScript("OnClick", function() ShowView("boards") end)
    
    -- ===================================================
    -- MY STATS VIEW
    -- ===================================================
    local normalStatsBox = CreateFrame("Frame", nil, statsFrame)
    normalStatsBox:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 10, -35)
    normalStatsBox:SetPoint("TOPRIGHT", statsFrame, "TOPRIGHT", -10, -35)
    normalStatsBox:SetHeight(190)
    normalStatsBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    normalStatsBox:SetBackdropColor(0.14, 0.14, 0.14, 1.0)
    normalStatsBox:SetBackdropBorderColor(0.82, 0.68, 0.32, 0.6)
    
    local nHeader = normalStatsBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nHeader:SetPoint("TOPLEFT", normalStatsBox, "TOPLEFT", 15, -10)
    nHeader:SetText("Normal Challenge Statistics")
    nHeader:SetTextColor(ACDM.Colors.Gold.r, ACDM.Colors.Gold.g, ACDM.Colors.Gold.b)
    
    local nStatsTexts = {}
    for i = 1, 8 do
        local txt = normalStatsBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local col = ((i-1) % 2) + 1
        local row = math.floor((i-1) / 2) + 1
        
        if col == 1 then
            txt:SetPoint("TOPLEFT", normalStatsBox, "TOPLEFT", 25, -28 - (row-1)*34)
        else
            txt:SetPoint("TOPLEFT", normalStatsBox, "TOPLEFT", 240, -28 - (row-1)*34)
        end
        txt:SetJustifyH("LEFT")
        nStatsTexts[i] = txt
    end
    
    local roguelikeStatsBox = CreateFrame("Frame", nil, statsFrame)
    roguelikeStatsBox:SetPoint("TOPLEFT", normalStatsBox, "BOTTOMLEFT", 0, -10)
    roguelikeStatsBox:SetPoint("TOPRIGHT", normalStatsBox, "BOTTOMRIGHT", 0, -10)
    roguelikeStatsBox:SetHeight(210)
    roguelikeStatsBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    roguelikeStatsBox:SetBackdropColor(0.14, 0.14, 0.14, 1.0)
    roguelikeStatsBox:SetBackdropBorderColor(0, 0.8, 0.8, 0.5)
    
    local rlHeader = roguelikeStatsBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rlHeader:SetPoint("TOPLEFT", roguelikeStatsBox, "TOPLEFT", 15, -10)
    rlHeader:SetText("Roguelike Statistics")
    rlHeader:SetTextColor(ACDM.Colors.Cyan.r, ACDM.Colors.Cyan.g, ACDM.Colors.Cyan.b)
    
    local rlStatsTexts = {}
    for i = 1, 10 do
        local txt = roguelikeStatsBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local col = ((i-1) % 2) + 1
        local row = math.floor((i-1) / 2) + 1
        
        if col == 1 then
            txt:SetPoint("TOPLEFT", roguelikeStatsBox, "TOPLEFT", 25, -28 - (row-1)*32)
        else
            txt:SetPoint("TOPLEFT", roguelikeStatsBox, "TOPLEFT", 240, -28 - (row-1)*32)
        end
        txt:SetJustifyH("LEFT")
        rlStatsTexts[i] = txt
    end
    
    local refreshStatsBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    refreshStatsBtn:SetSize(140, 22)
    refreshStatsBtn:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 5)
    refreshStatsBtn:SetText("Refresh Stats")
    refreshStatsBtn:SetScript("OnClick", function() ACDM.RequestStats() end)

    -- ===================================================
    -- DUNGEON BESTIARY VIEW
    -- ===================================================
    local bestiaryListFrame = CreateFrame("Frame", nil, bestiaryFrame)
    bestiaryListFrame:SetSize(180, 360)
    bestiaryListFrame:SetPoint("TOPLEFT", bestiaryFrame, "TOPLEFT", 10, -35)
    bestiaryListFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    bestiaryListFrame:SetBackdropColor(0, 0, 0, 0.6)
    bestiaryListFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.4)

    local bestiaryScroll = CreateFrame("ScrollFrame", "ACDMBestiaryScroll", bestiaryListFrame, "FauxScrollFrameTemplate")
    bestiaryScroll:SetPoint("TOPLEFT", bestiaryListFrame, "TOPLEFT", 0, -4)
    bestiaryScroll:SetPoint("BOTTOMRIGHT", bestiaryListFrame, "BOTTOMRIGHT", -20, 4)

    local bestiaryDetailBox = CreateFrame("Frame", nil, bestiaryFrame)
    bestiaryDetailBox:SetPoint("TOPLEFT", bestiaryListFrame, "TOPRIGHT", 10, 0)
    bestiaryDetailBox:SetPoint("BOTTOMRIGHT", bestiaryFrame, "BOTTOMRIGHT", -10, 35)
    bestiaryDetailBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    bestiaryDetailBox:SetBackdropColor(0.14, 0.14, 0.14, 1.0)
    bestiaryDetailBox:SetBackdropBorderColor(0.82, 0.68, 0.32, 0.6)

    local bDetailHeader = bestiaryDetailBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    bDetailHeader:SetPoint("TOPLEFT", bestiaryDetailBox, "TOPLEFT", 15, -12)
    bDetailHeader:SetText("Dungeon Bestiary")
    bDetailHeader:SetTextColor(ACDM.Colors.Gold.r, ACDM.Colors.Gold.g, ACDM.Colors.Gold.b)


    local bDetailMeta = bestiaryDetailBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bDetailMeta:SetPoint("TOPLEFT", bDetailHeader, "BOTTOMLEFT", 0, -6)
    bDetailMeta:SetJustifyH("LEFT")
    bDetailMeta:SetText("")

    local bestiaryHelpText = bestiaryDetailBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bestiaryHelpText:SetPoint("TOPLEFT", bestiaryDetailBox, "TOPLEFT", 20, -50)
    bestiaryHelpText:SetPoint("BOTTOMRIGHT", bestiaryDetailBox, "BOTTOMRIGHT", -20, 20)
    bestiaryHelpText:SetJustifyH("LEFT")
    bestiaryHelpText:SetJustifyV("TOP")
    bestiaryHelpText:SetText(
        "|cFFFFD700Dungeon Bestiary Guide|r\n\n" ..
        "• |cFF00FFFFHow it works:|r Defeating creatures of specific types (Beasts, Undead, Dragonkin, etc.) inside the Dungeon Challenge or Roguelike floors builds up your kill counts for those creatures on that specific map.\n\n" ..
        "• |cFF00FFFFMastery Ranks & Counterplay:|r As you reach kill milestones, you unlock permanent tactical counterplay tips:\n" ..
        "  - |cFF00FF00Tier 1 (50 Kills):|r Crowd Control vulnerabilities (e.g. Stun/Polymorph).\n" ..
        "  - |cFF00FF00Tier 2 (100 Kills):|r Special buffs or healing casts to watch out for.\n" ..
        "  - |cFF00FF00Tier 3 (250 Kills):|r Counter schools, melee resistance traits, and advanced strategies.\n\n" ..
        "Select a dungeon from the list on the left to view your progress, status, and hover over unlocked creature classes to view tactical counterplay tips!"
    )

    local bCreatureRows = {}
    for i = 1, 8 do
        local row = CreateFrame("Frame", nil, bestiaryDetailBox)
        row:SetSize(270, 26)
        row:SetPoint("TOPLEFT", bestiaryDetailBox, "TOPLEFT", 15, -80 - (i-1)*28)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.Icon = icon

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        label:SetJustifyH("LEFT")
        row.Label = label

        local tierLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tierLabel:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        tierLabel:SetJustifyH("RIGHT")
        row.TierLabel = tierLabel

        row:SetScript("OnEnter", function(self)
            if self.hintText and self.hintText ~= "" then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.typeName .. " Mastery Details", 1, 0.82, 0.35)
                GameTooltip:AddLine(self.hintText, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row:Hide()
        bCreatureRows[i] = row
    end

    local selectedBestiaryIndex = nil

    -- Persistent mini-hint shown at the bottom when a dungeon IS selected
    local bestiaryMiniHint = bestiaryDetailBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bestiaryMiniHint:SetPoint("BOTTOMLEFT", bestiaryDetailBox, "BOTTOMLEFT", 15, 10)
    bestiaryMiniHint:SetPoint("BOTTOMRIGHT", bestiaryDetailBox, "BOTTOMRIGHT", -15, 10)
    bestiaryMiniHint:SetJustifyH("LEFT")
    bestiaryMiniHint:SetTextColor(0.6, 0.6, 0.6, 1.0)
    bestiaryMiniHint:SetText("|cFF888888Kill creatures to unlock mastery tiers (50 / 100 / 250 kills). Hover creature types for tactical tips.|r")
    bestiaryMiniHint:Hide()

    local creatureTypeInfo = {
        [1] = { name = "Beast", icon = "Interface\\Icons\\Ability_Hunter_BeastTaming" },
        [2] = { name = "Dragonkin", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Black" },
        [3] = { name = "Demon", icon = "Interface\\Icons\\Spell_Shadow_SummonFelHunter" },
        [4] = { name = "Elemental", icon = "Interface\\Icons\\Spell_Nature_EarthBindTotem" },
        [5] = { name = "Giant", icon = "Interface\\Icons\\Ability_Racial_Avatar" },
        [6] = { name = "Undead", icon = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
        [7] = { name = "Humanoid", icon = "Interface\\Icons\\Achievement_Character_Human_Male" },
        [9] = { name = "Mechanical", icon = "Interface\\Icons\\Trade_Engineering" }
    }

    local creatureTypeOrder = { 1, 2, 3, 4, 5, 6, 7, 9 }

    local function UpdateBestiaryDetails()
        local dg = selectedBestiaryIndex and ACDM.dungeons[selectedBestiaryIndex]
        if not dg then
            bDetailHeader:SetText("Dungeon Bestiary")
            bDetailMeta:SetText("")
            bestiaryHelpText:Show()
            bestiaryMiniHint:Hide()
            for i = 1, 8 do bCreatureRows[i]:Hide() end
            return
        end

        bestiaryHelpText:Hide()
        bestiaryMiniHint:Show()
        bDetailHeader:SetText(dg.Name)
        
        local meta = ACDM.bestiaryMeta[dg.MapId] or {
            bossEncountered = false,
            bossBeaten = false,
            totalKills = 0,
            runsStarted = 0,
            runsCompleted = 0
        }

        local bossStatus = "Not Encountered"
        if meta.bossBeaten then
            bossStatus = ACDM.ColorText("Defeated", ACDM.Colors.Green)
        elseif meta.bossEncountered then
            bossStatus = ACDM.ColorText("Encountered", ACDM.Colors.Gold)
        end

        bDetailMeta:SetText(string.format(
            "Runs: %d Started / %d Cleared   |   Mobs Killed: %d\nBoss Status: %s",
            meta.runsStarted, meta.runsCompleted, meta.totalKills, bossStatus
        ))

        local killsMap = ACDM.bestiary[dg.MapId] or {}

        for idx, cType in ipairs(creatureTypeOrder) do
            local info = creatureTypeInfo[cType]
            local kills = killsMap[cType] or 0
            local row = bCreatureRows[idx]
            
            row:Show()
            row.typeName = info.name

            if kills > 0 then
                row.Icon:SetTexture(info.icon)
                row.Label:SetText(info.name .. ": " .. kills)

                local tier = 0
                local hint = ""
                local t1Limit = ACDM.bestiaryT1Limit or 50
                local t2Limit = ACDM.bestiaryT2Limit or 100
                local t3Limit = ACDM.bestiaryT3Limit or 250

                if kills >= t3Limit then
                    tier = 3
                    hint = "• Basic vulnerability: Takes 10% more damage from counter schools.\n• Elite traits: Highly resistant to base melee. Interruption required!\n• Counterplay: Safe to kite; interrupt critical spells."
                elseif kills >= t2Limit then
                    tier = 2
                    hint = "• Basic vulnerability: Takes 10% more damage from counter schools.\n• Elite traits: Periodically casts powerful buffs or healing.\n• Next mastery at " .. t3Limit .. " kills."
                elseif kills >= t1Limit then
                    tier = 1
                    hint = "• Basic vulnerability: Susceptible to crowd control (Stun/Polymorph).\n• Next mastery at " .. t2Limit .. " kills."
                else
                    hint = "• Traits unknown.\n• Next mastery at " .. t1Limit .. " kills."
                end

                row.TierLabel:SetText(ACDM.ColorText("Mastery " .. tier .. "/3", ACDM.Colors.Gold))
                row.hintText = hint
            else
                row.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                row.Label:SetText("??? : " .. kills)
                row.TierLabel:SetText(ACDM.ColorText("Locked", ACDM.Colors.Muted))
                row.hintText = "Defeat this creature type in this dungeon to unlock mastery rankings and tactical advice."
            end
        end
    end

    local function UpdateBestiaryListScroll()
        local size = #ACDM.dungeons
        FauxScrollFrame_Update(bestiaryScroll, size, 12, 28)
        local offset = FauxScrollFrame_GetOffset(bestiaryScroll)

        for i = 1, 12 do
            local row = _G["ACDMBestiaryRow" .. i]
            if not row then
                row = CreateFrame("Button", "ACDMBestiaryRow" .. i, bestiaryListFrame, "UIPanelButtonTemplate")
                row:SetSize(160, 26)
            end
            row:SetPoint("TOPLEFT", bestiaryListFrame, "TOPLEFT", 8, -4 - (i-1)*28)
            
            local idx = offset + i
            if idx <= size then
                local dg = ACDM.dungeons[idx]
                row:Show()
                
                local meta = ACDM.bestiaryMeta[dg.MapId]
                if meta and meta.runsStarted > 0 then
                    row:SetText(dg.Name)
                else
                    row:SetText(ACDM.ColorText(dg.Name, ACDM.Colors.Muted))
                end

                if idx == selectedBestiaryIndex then
                    row:LockHighlight()
                else
                    row:UnlockHighlight()
                end

                row:SetScript("OnClick", function()
                    if selectedBestiaryIndex == idx then
                        selectedBestiaryIndex = nil
                    else
                        selectedBestiaryIndex = idx
                    end
                    UpdateBestiaryListScroll()
                    UpdateBestiaryDetails()
                end)
            else
                row:Hide()
            end
        end
    end

    bestiaryScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 28, UpdateBestiaryListScroll)
    end)

    -- ===================================================
    -- AFFIX FAMILIARITY VIEW
    -- ===================================================
    local famBox = CreateFrame("Frame", nil, familiarityFrame)
    famBox:SetPoint("TOPLEFT", familiarityFrame, "TOPLEFT", 10, -35)
    famBox:SetPoint("BOTTOMRIGHT", familiarityFrame, "BOTTOMRIGHT", -10, 35)
    famBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    famBox:SetBackdropColor(0.14, 0.14, 0.14, 1.0)
    famBox:SetBackdropBorderColor(0, 0.8, 0.8, 0.5)

    local fHeader = famBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fHeader:SetPoint("TOPLEFT", famBox, "TOPLEFT", 15, -12)
    fHeader:SetText("Affix Familiarity & Resistance")
    fHeader:SetTextColor(ACDM.Colors.Cyan.r, ACDM.Colors.Cyan.g, ACDM.Colors.Cyan.b)

    local fDesc = famBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fDesc:SetPoint("TOPLEFT", fHeader, "BOTTOMLEFT", 0, -6)
    fDesc:SetPoint("TOPRIGHT", famBox, "TOPRIGHT", -15, 0)
    fDesc:SetJustifyH("LEFT")
    fDesc:SetText(
        "Defeating dungeons with active affixes builds Familiarity for those affixes.\n\n" ..
        "• |cFF00FFFFResistance:|r Each clear with an active affix adds |cFF00FF00+3.0%|r resistance, up to a cap of |cFFFFD70015.0%|r permanent damage and health mitigation against that affix's effects.\n" ..
        "• |cFF00FFFFParty Scaling:|r Resistance scales down affix bonuses when running in a party (calculated as the average familiarity of all party members)."
    )

    local famRows = {}
    local affixNames = {
        [1] = "Fortified",
        [2] = "Tyrannical",
        [3] = "Raging",
        [4] = "Bolstering",
        [5] = "Savage"
    }

    for i = 1, 5 do
        local row = CreateFrame("Frame", nil, famBox)
        row:SetSize(460, 48)
        row:SetPoint("TOPLEFT", famBox, "TOPLEFT", 15, -115 - (i-1)*54)

        local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameTxt:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        nameTxt:SetText(affixNames[i])
        nameTxt:SetTextColor(ACDM.Colors.Gold.r, ACDM.Colors.Gold.g, ACDM.Colors.Gold.b)
        row.Name = nameTxt

        local countTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countTxt:SetPoint("TOPRIGHT", row, "TOPRIGHT", -5, 0)
        countTxt:SetText("Encounters: 0")
        row.Count = countTxt

        local barBorder = CreateFrame("Frame", nil, row)
        barBorder:SetSize(460, 16)
        barBorder:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 4)
        barBorder:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 12, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        barBorder:SetBackdropColor(0, 0, 0, 0.8)
        barBorder:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)

        local bar = barBorder:CreateTexture(nil, "ARTWORK")
        bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetVertexColor(0, 0.7, 0.7, 0.8)
        bar:SetPoint("TOPLEFT", barBorder, "TOPLEFT", 2, -2)
        bar:SetPoint("BOTTOMLEFT", barBorder, "BOTTOMLEFT", 2, 2)
        bar:SetWidth(1)
        row.Bar = bar

        local pctTxt = barBorder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
        pctTxt:SetPoint("CENTER", barBorder, "CENTER", 0, 0)
        pctTxt:SetText("0% / 15%")
        row.Pct = pctTxt

        famRows[i] = row
    end

    local function UpdateFamiliarityUI()
        local maxFamiliarity = ACDM.maxFamiliarityPct or 15.0
        for i = 1, 5 do
            local row = famRows[i]
            local data = ACDM.familiarity[i] or { encounters = 0, resistancePct = 0.0 }
            
            row.Count:SetText("Completed Runs: " .. data.encounters)
            row.Pct:SetText(string.format("%.1f%% / %.1f%% Resistance", data.resistancePct, maxFamiliarity))

            local pct = 0
            if maxFamiliarity > 0 then
                pct = math.min(1.0, data.resistancePct / maxFamiliarity)
            end
            
            local width = math.max(1, pct * 456)
            row.Bar:SetWidth(width)
        end
    end

    -- ===================================================
    -- LEADERBOARDS VIEW
    -- ===================================================
    local boardSelector = CreateFrame("Frame", nil, boardsFrame)
    boardSelector:SetPoint("TOPLEFT", boardsFrame, "TOPLEFT", 10, -35)
    boardSelector:SetPoint("TOPRIGHT", boardsFrame, "TOPRIGHT", -10, -35)
    boardSelector:SetHeight(30)
    
    local boardBtns = {}
    local boardTypes = { "normal", "rltier", "rlfloors" }
    local boardLabels = { "Fastest Clears", "Highest Tier", "Most Floors" }
    
    local function SwitchBoard(boardType)
        currentBoard = boardType
        for idx, btn in ipairs(boardBtns) do
            if boardTypes[idx] == boardType then
                btn:LockHighlight()
            else
                btn:UnlockHighlight()
            end
        end
        ACDM.RequestBoards(boardType)
    end
    
    for i = 1, 3 do
        local btn = CreateFrame("Button", nil, boardSelector, "UIPanelButtonTemplate")
        btn:SetSize(150, 22)
        btn:SetText(boardLabels[i])
        if i == 1 then
            btn:SetPoint("LEFT", boardSelector, "LEFT", 5, 0)
        else
            btn:SetPoint("LEFT", boardBtns[i-1], "RIGHT", 10, 0)
        end
        btn:SetScript("OnClick", function() SwitchBoard(boardTypes[i]) end)
        boardBtns[i] = btn
    end
    
    local tableFrame = CreateFrame("Frame", nil, boardsFrame)
    tableFrame:SetPoint("TOPLEFT", boardSelector, "BOTTOMLEFT", 0, -5)
    tableFrame:SetPoint("BOTTOMRIGHT", boardsFrame, "BOTTOMRIGHT", -10, 35)
    tableFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    tableFrame:SetBackdropColor(0.14, 0.14, 0.14, 1.0)
    tableFrame:SetBackdropBorderColor(0.82, 0.68, 0.32, 0.6)
    
    local hRank = tableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hRank:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 15, -8)
    hRank:SetText("Rank")
    
    local hPlayer = tableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hPlayer:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 60, -8)
    hPlayer:SetText("Character")
    
    local hVal = tableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hVal:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 180, -8)
    hVal:SetText("Value")
    
    local hDetails = tableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hDetails:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 260, -8)
    hDetails:SetText("Details")
    
    local listRows = {}
    for i = 1, 10 do
        local r = CreateFrame("Frame", nil, tableFrame)
        r:SetHeight(28)
        r:SetPoint("LEFT", tableFrame, "LEFT", 5, 0)
        r:SetPoint("RIGHT", tableFrame, "RIGHT", -25, 0)
        r:SetPoint("TOP", tableFrame, "TOP", 0, -(i-1)*32 - 28)
        
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        r.bg:SetVertexColor(1, 1, 1, 0.05)
        
        local rank = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rank:SetPoint("LEFT", r, "LEFT", 10, 0)
        r.Rank = rank
        
        local name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("LEFT", r, "LEFT", 55, 0)
        r.Name = name
        
        local val = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        val:SetPoint("LEFT", r, "LEFT", 175, 0)
        r.Val = val
        
        local det = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        det:SetPoint("LEFT", r, "LEFT", 255, 0)
        det:SetJustifyH("LEFT")
        r.Det = det
        
        r:Hide()
        listRows[i] = r
    end
    
    local refreshBoardBtn = CreateFrame("Button", nil, boardsFrame, "UIPanelButtonTemplate")
    refreshBoardBtn:SetSize(140, 22)
    refreshBoardBtn:SetPoint("BOTTOMRIGHT", boardsFrame, "BOTTOMRIGHT", -10, 5)
    refreshBoardBtn:SetText("Refresh Board")
    refreshBoardBtn:SetScript("OnClick", function() ACDM.RequestBoards(currentBoard) end)
    
    ACDM.OnStatsComplete = function()
        local ns = ACDM.normalStats
        local rs = ACDM.roguelikeStats
        
        local normalWinRate = 0
        if ns.totalRuns and ns.totalRuns > 0 then
            normalWinRate = math.floor((ns.completed / ns.totalRuns) * 100)
        end
        
        nStatsTexts[1]:SetText(ACDM.ColorText("Total Runs: ", ACDM.Colors.Gold) .. (ns.totalRuns or 0))
        nStatsTexts[2]:SetText(ACDM.ColorText("Completed: ", ACDM.Colors.Gold) .. ACDM.ColorText(tostring(ns.completed or 0), ACDM.Colors.Green))
        nStatsTexts[3]:SetText(ACDM.ColorText("Failed: ", ACDM.Colors.Gold) .. ACDM.ColorText(tostring(ns.failed or 0), ACDM.Colors.Red))
        nStatsTexts[4]:SetText(ACDM.ColorText("Win Rate: ", ACDM.Colors.Gold) .. normalWinRate .. "%")
        nStatsTexts[5]:SetText(ACDM.ColorText("Mobs Killed: ", ACDM.Colors.Gold) .. (ns.mobsKilled or 0))
        nStatsTexts[6]:SetText(ACDM.ColorText("Bosses Slain: ", ACDM.Colors.Gold) .. (ns.bossesKilled or 0))
        nStatsTexts[7]:SetText(ACDM.ColorText("Deaths: ", ACDM.Colors.Gold) .. ACDM.ColorText(tostring(ns.deaths or 0), ACDM.Colors.Red))
        nStatsTexts[8]:SetText(ACDM.ColorText("Fastest Clear: ", ACDM.Colors.Gold) .. ACDM.FormatTime(ns.fastestClearSec))
        
        local rlAvgFloors = 0
        if rs.totalRuns and rs.totalRuns > 0 then
            rlAvgFloors = math.floor((rs.totalFloors / rs.totalRuns) * 10) / 10
        end
        
        rlStatsTexts[1]:SetText(ACDM.ColorText("Total Runs: ", ACDM.Colors.Cyan) .. (rs.totalRuns or 0))
        rlStatsTexts[2]:SetText(ACDM.ColorText("Highest Tier: ", ACDM.Colors.Cyan) .. (rs.highestTier or 0))
        rlStatsTexts[3]:SetText(ACDM.ColorText("Most Floors: ", ACDM.Colors.Cyan) .. (rs.mostFloors or 0))
        rlStatsTexts[4]:SetText(ACDM.ColorText("Total Floors: ", ACDM.Colors.Cyan) .. (rs.totalFloors or 0))
        rlStatsTexts[5]:SetText(ACDM.ColorText("Avg Floors/Run: ", ACDM.Colors.Cyan) .. rlAvgFloors)
        rlStatsTexts[6]:SetText(ACDM.ColorText("Mobs Killed: ", ACDM.Colors.Cyan) .. (rs.mobsKilled or 0))
        rlStatsTexts[7]:SetText(ACDM.ColorText("Bosses Slain: ", ACDM.Colors.Cyan) .. (rs.bossesKilled or 0))
        rlStatsTexts[8]:SetText(ACDM.ColorText("Deaths: ", ACDM.Colors.Cyan) .. ACDM.ColorText(tostring(rs.deaths or 0), ACDM.Colors.Red))
        rlStatsTexts[9]:SetText(ACDM.ColorText("Longest Run: ", ACDM.Colors.Cyan) .. ACDM.FormatTime(rs.longestRunSec))
        rlStatsTexts[10]:SetText("")

        -- Phase 1 Bestiary & Familiarity Updates
        UpdateBestiaryListScroll()
        UpdateBestiaryDetails()
        UpdateFamiliarityUI()
    end
    
    ACDM.OnBoardComplete = function()
        for i = 1, 10 do
            listRows[i]:Hide()
        end
        
        local myName = UnitName("player")
        
        if currentBoard == "normal" then
            hVal:SetText("Time")
        elseif currentBoard == "rltier" then
            hVal:SetText("Highest Tier")
        else
            hVal:SetText("Floors")
        end
        
        for idx, entry in ipairs(ACDM.leaderboard) do
            if idx <= 10 then
                local r = listRows[idx]
                r:Show()
                
                if entry.charName == myName then
                    r.bg:SetVertexColor(0, 1, 0, 0.15)
                else
                    r.bg:SetVertexColor(1, 1, 1, (idx % 2 == 0) and 0.08 or 0.02)
                end
                
                r.Rank:SetText(entry.rank)
                r.Name:SetText(entry.charName)
                
                if currentBoard == "normal" then
                    r.Val:SetText(ACDM.FormatTime(entry.val1))
                    local scaleText = entry.val5 == 1 and "Scaled" or "Static"
                    r.Det:SetText(string.format("Map %u | Diff %u | Party %u (%s)",
                        entry.val2, entry.val3, entry.val4, scaleText))
                else
                    if currentBoard == "rltier" then
                        r.Val:SetText(ACDM.ColorText("Tier " .. entry.val1, ACDM.Colors.Cyan))
                        r.Det:SetText(string.format("Floors Cleared: %u | Kills: %u | Duration: %s",
                            entry.val2, entry.val4, ACDM.FormatTime(entry.val3)))
                    else
                        r.Val:SetText(ACDM.ColorText(tostring(entry.val2), ACDM.Colors.Green) .. " floors")
                        r.Det:SetText(string.format("Tier Reached: %u | Kills: %u | Duration: %s",
                            entry.val1, entry.val4, ACDM.FormatTime(entry.val3)))
                    end
                end
            end
        end
    end
    
    ShowView("stats")
end

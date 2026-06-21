-- Floating HUD Tracker Overlay for Dungeon Master Sessions

local hudPerks = {
    { id = 0, name = "Scout", icon = "Interface\\Icons\\Spell_Nature_EyeOfTheStorm", desc = "Reveals hidden active dungeon affixes in pre-run previews." },
    { id = 1, name = "Veteran", icon = "Interface\\Icons\\Ability_Warrior_ShieldWall", desc = "Reduces all damage taken inside challenges by 5%." },
    { id = 2, name = "Pathfinder", icon = "Interface\\Icons\\Ability_Hunter_Pathfinding", desc = "Generates 4 branching choices (instead of 3) when clearing floors." },
    { id = 3, name = "Gladiator", icon = "Interface\\Icons\\Ability_Warrior_InnerRage", desc = "Increases all damage dealt inside challenges by 5%." },
    { id = 4, name = "Survivor", icon = "Interface\\Icons\\Spell_Holy_Resurrection", desc = "Increases your starting wipes/lives count by 1 in Roguelike mode." }
}

function ACDM.CreateTrackerFrame()
    if ACDM.TrackerFrame then return end

    -- Main Frame
    local tracker = CreateFrame("Frame", "ACDMTrackerFrame", UIParent)
    tracker:SetSize(230, 140) -- initial size, height will auto-adjust
    tracker:SetClampedToScreen(true)
    
    -- Load/Restore Position
    if ACChallengePanelDB and ACChallengePanelDB.trackerX then
        tracker:ClearAllPoints()
        tracker:SetPoint(ACChallengePanelDB.trackerPoint or "CENTER", UIParent, ACChallengePanelDB.trackerRelativePoint or "CENTER", ACChallengePanelDB.trackerX, ACChallengePanelDB.trackerY)
    else
        tracker:ClearAllPoints()
        tracker:SetPoint("CENTER", UIParent, "CENTER", 250, 120) -- Default premium offset position
    end

    -- Enable Dragging
    tracker:SetMovable(true)
    tracker:EnableMouse(true)
    tracker:RegisterForDrag("LeftButton")
    tracker:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    tracker:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        if not ACChallengePanelDB then
            ACChallengePanelDB = {}
        end
        ACChallengePanelDB.trackerPoint = point
        ACChallengePanelDB.trackerRelativePoint = relativePoint
        ACChallengePanelDB.trackerX = xOfs
        ACChallengePanelDB.trackerY = yOfs
    end)

    -- Backdrop (Premium Glassmorphic Dark styling)
    tracker:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 24, edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    tracker:SetBackdropColor(0.08, 0.08, 0.10, 0.88)
    tracker:SetBackdropBorderColor(0.82, 0.68, 0.32, 0.9) -- Sleek Gold Border

    -- Golden Circular Indicator for Lives
    local circleFrame = CreateFrame("Frame", nil, tracker)
    circleFrame:SetSize(40, 40)
    circleFrame:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, -14)

    local circleBg = circleFrame:CreateTexture(nil, "BACKGROUND")
    circleBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    circleBg:SetSize(38, 38)
    circleBg:SetPoint("CENTER", circleFrame, "CENTER", 0, 0)
    circleBg:SetAlpha(0.6)

    local circleBorder = circleFrame:CreateTexture(nil, "OVERLAY")
    circleBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    circleBorder:SetSize(68, 68)
    circleBorder:SetPoint("TOPLEFT", circleFrame, "TOPLEFT", 0, 0)

    local livesText = circleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    livesText:SetPoint("CENTER", circleFrame, "CENTER", 0, 0)
    livesText:SetTextColor(1.0, 0.82, 0.35)
    livesText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    livesText:SetText("∞")
    tracker.livesText = livesText

    -- Title text (Dungeon Name)
    local titleText = tracker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", circleFrame, "TOPRIGHT", 12, -2)
    titleText:SetTextColor(1.0, 1.0, 1.0)
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    titleText:SetText("Dungeon Challenge")
    tracker.titleText = titleText

    -- Subtitle/Status text
    local descText = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    descText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -3)
    descText:SetTextColor(0.78, 0.66, 0.45)
    descText:SetText("Active Run")
    tracker.descText = descText

    -- Timer text
    local timerText = tracker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timerText:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", -26, -17)
    timerText:SetTextColor(1.0, 0.82, 0.35)
    timerText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    timerText:SetText("00:00")
    tracker.timerText = timerText

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, tracker)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", -8, -8)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function()
        ACDM.runInfo.trackerClosedByUser = true
        tracker:Hide()
    end)

    -- Helper to create progress bars
    local function CreateProgressBar(parent, color)
        local bar = CreateFrame("StatusBar", nil, parent)
        bar:SetSize(202, 14)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(color.r, color.g, color.b, 0.85)
        
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bg:SetAllPoints(bar)
        bg:SetVertexColor(color.r, color.g, color.b, 0.18)
        bar.bg = bg
        
        local border = CreateFrame("Frame", nil, bar)
        border:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
        border:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        border:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.85)
        bar.border = border
        
        local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("CENTER", bar, "CENTER", 0, 1)
        text:SetTextColor(1, 1, 1)
        text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        bar.text = text
        
        bar:EnableMouse(true)
        return bar
    end

    -- Create Progress Bars
    ACDM.AttunementBar = CreateProgressBar(tracker, { r = 0.1, g = 0.8, b = 0.2 }) -- Emerald Green
    ACDM.MobPowerBar = CreateProgressBar(tracker, { r = 0.9, g = 0.4, b = 0.0 }) -- Ember Orange
    ACDM.WeaknessBar = CreateProgressBar(tracker, { r = 0.85, g = 0.15, b = 0.15 }) -- Crimson Red

    -- Tooltip Handlers for Progress Bars
    ACDM.AttunementBar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Dungeon Attunement", 1.0, 0.82, 0.35)
        GameTooltip:AddLine("Increases outgoing damage and healing by 10% per stack. Adaptively increases enemy damage and health by 4% per stack.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    ACDM.AttunementBar:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    ACDM.WeaknessBar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Dungeon Weakness", 1.0, 0.82, 0.35)
        GameTooltip:AddLine("Decreases outgoing damage and healing by 15% per stack, and increases damage taken by 15% per stack.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    ACDM.WeaknessBar:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    ACDM.MobPowerBar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Mob Power Adaptation", 1.0, 0.82, 0.35)
        GameTooltip:AddLine("Dungeon creatures adapt to your survival success.", 1, 1, 1, true)
        GameTooltip:AddLine("Each stack of Attunement increases enemies' damage dealt by +4% and effective health by +4%.", 0.85, 0.15, 0.15, true)
        GameTooltip:Show()
    end)
    ACDM.MobPowerBar:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Create Boss Label
    local bossLabel = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossLabel:SetTextColor(1, 0.4, 0.4)
    bossLabel:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    tracker.bossLabel = bossLabel

    -- Helper to create dividers
    local function CreateDivider(parent)
        local tex = parent:CreateTexture(nil, "ARTWORK")
        tex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        tex:SetSize(202, 1)
        tex:SetVertexColor(0.82, 0.68, 0.32, 0.4) -- muted gold line
        return tex
    end

    tracker.divider1 = CreateDivider(tracker)
    tracker.divider2 = CreateDivider(tracker)

    -- New Run Details Section FontStrings
    local diffLabel = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    diffLabel:SetTextColor(1, 1, 1)
    diffLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    tracker.diffLabel = diffLabel

    local themeLabel = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    themeLabel:SetTextColor(1, 1, 1)
    themeLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    tracker.themeLabel = themeLabel

    local scalingLabel = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scalingLabel:SetTextColor(1, 1, 1)
    scalingLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    tracker.scalingLabel = scalingLabel

    local gambitLabel = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gambitLabel:SetTextColor(1, 1, 1)
    gambitLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    tracker.gambitLabel = gambitLabel

    -- Active Perks Section in HUD
    local perksLabel = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    perksLabel:SetTextColor(1, 1, 1)
    perksLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    perksLabel:SetText("Mastery:")
    tracker.perksLabel = perksLabel

    tracker.perkIcons = {}
    for i = 1, 5 do
        local btn = CreateFrame("Button", nil, tracker)
        btn:SetSize(16, 16)

        local tex = btn:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        btn.Icon = tex

        local border = btn:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetSize(28, 28)
        border:SetPoint("CENTER", btn, "CENTER", 0, 0)
        border:SetBlendMode("ADD")
        border:SetVertexColor(0, 1, 0, 0.7) -- Nice Green Border for Perks
        btn.Border = border

        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:Hide()
        tracker.perkIcons[i] = btn
    end

    -- Active Affixes Section in HUD
    local affixesLabel = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    affixesLabel:SetTextColor(1, 1, 1)
    affixesLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    tracker.affixesLabel = affixesLabel

    tracker.affixIcons = {}
    for i = 1, 3 do
        local btn = CreateFrame("Button", nil, tracker)
        btn:SetSize(16, 16)

        local tex = btn:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        btn.Icon = tex

        local border = btn:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetSize(28, 28)
        border:SetPoint("CENTER", btn, "CENTER", 0, 0)
        border:SetBlendMode("ADD")
        btn.Border = border

        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:Hide()
        tracker.affixIcons[i] = btn
    end

    -- New Rewards Section FontStrings
    local rewardsSectionTitle = tracker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rewardsSectionTitle:SetTextColor(1, 0.82, 0.35)
    rewardsSectionTitle:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    rewardsSectionTitle:SetText("Run Rewards")
    tracker.rewardsSectionTitle = rewardsSectionTitle

    local rewardsGoldLabel = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rewardsGoldLabel:SetTextColor(1, 1, 1)
    rewardsGoldLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    tracker.rewardsGoldLabel = rewardsGoldLabel

    -- Item slots row
    tracker.rewardItemSlots = {}
    for i = 1, 5 do
        local slot = CreateFrame("Button", nil, tracker)
        slot:SetSize(22, 22)
        
        local icon = slot:CreateTexture(nil, "BACKGROUND")
        icon:SetAllPoints(slot)
        slot.icon = icon
        
        local border = slot:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetSize(36, 36)
        border:SetPoint("CENTER", slot, "CENTER", 0, 0)
        border:SetBlendMode("ADD")
        slot.border = border
        
        local text = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("CENTER", slot, "CENTER", 0, 0)
        text:SetTextColor(1, 1, 1)
        text:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        slot.text = text
        
        slot:SetScript("OnEnter", function(self)
            if self.isPlusSlot then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Additional Rewards", 1, 0.82, 0.35)
                for idx = 5, #ACDM.runInfo.rewardedItems do
                    local itemInfo = ACDM.runInfo.rewardedItems[idx]
                    local name, link = GetItemInfo(itemInfo.id)
                    if name then
                        GameTooltip:AddLine(link)
                    else
                        GameTooltip:AddLine("Retrieving Item Info...")
                    end
                end
                GameTooltip:Show()
            elseif self.itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
            end
        end)
        slot:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        slot:SetScript("OnClick", function(self)
            if not self.isPlusSlot and self.itemLink then
                HandleModifiedItemClick(self.itemLink)
            end
        end)
        
        tracker.rewardItemSlots[i] = slot
    end

    -- Transition Control Buttons (Roguelike completed floor only)
    local advanceBtn = CreateFrame("Button", nil, tracker, "UIPanelButtonTemplate")
    advanceBtn:SetSize(96, 20)
    advanceBtn:SetText("Next Floor")
    advanceBtn:SetNormalFontObject("GameFontNormalSmall")
    advanceBtn:SetHighlightFontObject("GameFontHighlightSmall")
    advanceBtn:SetScript("OnClick", function()
        ACDM.SendCommand(".dm rladvance")
    end)
    tracker.advanceBtn = advanceBtn

    local quitBtn = CreateFrame("Button", nil, tracker, "UIPanelButtonTemplate")
    quitBtn:SetSize(96, 20)
    quitBtn:SetText("Exit & Claim")
    quitBtn:SetNormalFontObject("GameFontNormalSmall")
    quitBtn:SetHighlightFontObject("GameFontHighlightSmall")
    quitBtn:SetScript("OnClick", function()
        ACDM.SendCommand(".dm rlquit")
    end)
    tracker.quitBtn = quitBtn

    -- Rearrange/layout the bars dynamically
    local function RearrangeBars()
        local yOffset = -62
        
        -- Attunement Bar
        ACDM.AttunementBar:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset)
        yOffset = yOffset - 22
        
        -- Mob Power Bar
        ACDM.MobPowerBar:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset)
        yOffset = yOffset - 22
        
        -- Weakness Bar (conditionally shown)
        local debuffs = ACDM.runInfo.debuffs or 0
        if debuffs > 0 then
            ACDM.WeaknessBar:Show()
            ACDM.WeaknessBar:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset)
            yOffset = yOffset - 22
        else
            ACDM.WeaknessBar:Hide()
        end

        -- Active Boss Status
        local showBoss = false
        local inRun = (ACDM.flags.inSession == 1) or (ACDM.flags.inRoguelike == 1)
        if inRun then
            local bName = ACDM.runInfo.bossName or "None"
            if ACDM.flags.sessionState == 4 then
                tracker.bossLabel:SetText(ACDM.ColorText("Boss: ", ACDM.Colors.Gold) .. ACDM.ColorText("Defeated!", ACDM.Colors.Green))
                showBoss = true
            elseif bName ~= "None" and bName ~= "" then
                tracker.bossLabel:SetText(ACDM.ColorText("Boss: ", ACDM.Colors.Gold) .. ACDM.ColorText(bName, ACDM.Colors.Red))
                showBoss = true
            end
        end

        if showBoss then
            tracker.bossLabel:Show()
            tracker.bossLabel:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset)
            yOffset = yOffset - 16
        else
            tracker.bossLabel:Hide()
        end

        -- Run Details Section
        if inRun then
            tracker.divider1:Show()
            tracker.divider1:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset - 4)
            yOffset = yOffset - 10
            
            tracker.diffLabel:Show()
            tracker.diffLabel:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset)
            yOffset = yOffset - 15
            
            tracker.themeLabel:Show()
            tracker.themeLabel:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset)
            yOffset = yOffset - 15
            
            tracker.scalingLabel:Show()
            tracker.scalingLabel:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset)
            yOffset = yOffset - 15

            if ACDM.flags.inRoguelike == 1 then
                tracker.gambitLabel:Show()
                tracker.gambitLabel:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset)
                yOffset = yOffset - 15
            else
                tracker.gambitLabel:Hide()
            end

            -- Layout Active Perks Row in Tracker
            local mask = ACDM.purchasedMask or 0
            local activePerks = {}
            for _, pk in ipairs(hudPerks) do
                if (math.floor(mask / (2 ^ pk.id)) % 2 == 1) then
                    table.insert(activePerks, pk)
                end
            end

            local numPerks = #activePerks
            if numPerks > 0 then
                tracker.perksLabel:Show()
                tracker.perksLabel:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset)
                
                for i = 1, 5 do
                    local btn = tracker.perkIcons[i]
                    if i <= numPerks then
                        local perk = activePerks[i]
                        btn.Icon:SetTexture(perk.icon)
                        btn:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetText("Mastery Perk: " .. perk.name, 0.0, 1.0, 0.0)
                            GameTooltip:AddLine(perk.desc, 1, 1, 1, true)
                            GameTooltip:Show()
                        end)
                        btn:Show()
                        btn:ClearAllPoints()
                        if i == 1 then
                            btn:SetPoint("LEFT", tracker.perksLabel, "RIGHT", 6, 0)
                        else
                            btn:SetPoint("LEFT", tracker.perkIcons[i-1], "RIGHT", 6, 0)
                        end
                    else
                        btn:Hide()
                    end
                end
                yOffset = yOffset - 20
            else
                tracker.perksLabel:Hide()
                for i = 1, 5 do
                    tracker.perkIcons[i]:Hide()
                end
            end

            -- Layout Active Affixes Row in Tracker
            local activeAffixes = ACDM.runInfo.activeAffixes or {}
            local numActive = #activeAffixes
            if numActive > 0 then
                tracker.affixesLabel:Show()
                tracker.affixesLabel:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset)
                
                for i = 1, 3 do
                    local btn = tracker.affixIcons[i]
                    if i <= numActive then
                        btn:Show()
                        btn:ClearAllPoints()
                        if i == 1 then
                            btn:SetPoint("LEFT", tracker.affixesLabel, "RIGHT", 6, 0)
                        else
                            btn:SetPoint("LEFT", tracker.affixIcons[i-1], "RIGHT", 6, 0)
                        end
                    else
                        btn:Hide()
                    end
                end
                yOffset = yOffset - 20
            else
                tracker.affixesLabel:Hide()
                for i = 1, 3 do
                    tracker.affixIcons[i]:Hide()
                end
            end
        else
            tracker.divider1:Hide()
            tracker.diffLabel:Hide()
            tracker.themeLabel:Hide()
            tracker.scalingLabel:Hide()
            tracker.gambitLabel:Hide()
            tracker.affixesLabel:Hide()
            for i = 1, 3 do
                tracker.affixIcons[i]:Hide()
            end
            tracker.perksLabel:Hide()
            for i = 1, 5 do
                tracker.perkIcons[i]:Hide()
            end
        end

        -- Cumulative Rewards Summary
        local gold = ACDM.runInfo.accumulatedGold or 0
        local itemsCount = ACDM.runInfo.rewardedItems and #ACDM.runInfo.rewardedItems or 0
        local hasRewards = inRun and (gold > 0 or itemsCount > 0)
        
        if hasRewards then
            tracker.divider2:Show()
            tracker.divider2:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset - 4)
            yOffset = yOffset - 10
            
            tracker.rewardsSectionTitle:Show()
            tracker.rewardsSectionTitle:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset)
            yOffset = yOffset - 15
            
            if gold > 0 then
                tracker.rewardsGoldLabel:Show()
                tracker.rewardsGoldLabel:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset)
                yOffset = yOffset - 15
            else
                tracker.rewardsGoldLabel:Hide()
            end
            
            if itemsCount > 0 then
                local startX = 14
                for i = 1, 5 do
                    local slot = tracker.rewardItemSlots[i]
                    if i <= itemsCount then
                        slot:Show()
                        slot:SetPoint("TOPLEFT", tracker, "TOPLEFT", startX, yOffset - 2)
                        startX = startX + 26
                    else
                        slot:Hide()
                    end
                end
                yOffset = yOffset - 28
            else
                for i = 1, 5 do
                    tracker.rewardItemSlots[i]:Hide()
                end
            end
        else
            tracker.divider2:Hide()
            tracker.rewardsSectionTitle:Hide()
            tracker.rewardsGoldLabel:Hide()
            for i = 1, 5 do
                tracker.rewardItemSlots[i]:Hide()
            end
        end

        -- Transition Buttons (Roguelike completed floor only - disabled in Tracker UI in favor of branching choices frame)
        local showButtons = false

        if showButtons then
            tracker.advanceBtn:Show()
            tracker.quitBtn:Show()
            tracker.advanceBtn:SetPoint("TOPLEFT", tracker, "TOPLEFT", 14, yOffset - 4)
            tracker.quitBtn:SetPoint("LEFT", tracker.advanceBtn, "RIGHT", 10, 0)
            yOffset = yOffset - 28
        else
            tracker.advanceBtn:Hide()
            tracker.quitBtn:Hide()
        end
        
        -- Resize main frame based on contents
        tracker:SetHeight(math.abs(yOffset) + 14)
    end
    tracker.RearrangeBars = RearrangeBars

    -- Real-time update ticker (local extrapolation & uncached item resolution)
    local tickerTimer = 0
    tracker:SetScript("OnUpdate", function(self, elapsed)
        local inRun = (ACDM.flags.inSession == 1) or (ACDM.flags.inRoguelike == 1)
        if not inRun then
            self:Hide()
            return
        end

        tickerTimer = tickerTimer + elapsed
        if tickerTimer >= 0.2 then
            tickerTimer = 0
            
            local now = GetTime()
            local elapsedLocal = math.floor(now - (ACDM.runInfo.lastUpdate or now))
            
            -- 1. Tick run timer and compare to Personal Best
            local totalElapsed = (ACDM.runInfo.elapsed or 0) + elapsedLocal
            local m = math.floor(totalElapsed / 60)
            local s = totalElapsed % 60
            
            local pbTime = 0
            local mapId = ACDM.selection.mapId
            local diffId = ACDM.selection.diffId
            if mapId and diffId and ACDM.personalBests and ACDM.personalBests[mapId] then
                pbTime = ACDM.personalBests[mapId][diffId] or 0
            end
            
            local pbStr = ""
            if pbTime > 0 then
                local diff = totalElapsed - pbTime
                if diff < 0 then
                    local absDiff = math.abs(diff)
                    local pm = math.floor(absDiff / 60)
                    local ps = absDiff % 60
                    pbStr = string.format(" |cFF00FF00-(%d:%02d)|r", pm, ps)
                elseif diff > 0 then
                    local pm = math.floor(diff / 60)
                    local ps = diff % 60
                    pbStr = string.format(" |cFFFF0000+(%d:%02d)|r", pm, ps)
                else
                    pbStr = " |cFF00FF00(+0:00)|r"
                end
            end
            self.timerText:SetText(string.format("%02d:%02d", m, s) .. pbStr)
            
            -- 2. Tick Attunement progress
            local timeAlive = ACDM.runInfo.timeAlive or 0
            local timeAliveLocal = timeAlive + elapsedLocal
            local progress = timeAliveLocal % 300
            ACDM.AttunementBar:SetValue(progress)
            
            local attunementStacks = math.floor(timeAliveLocal / 300)
            ACDM.AttunementBar.text:SetText(string.format("Attunement: +%d%% (%d)", attunementStacks * 10, attunementStacks))
            
            -- 2b. Tick Mob Power adaptation scaling
            local mobPowerPct = attunementStacks * 4
            local mobMax = math.max(10, attunementStacks)
            ACDM.MobPowerBar:SetMinMaxValues(0, mobMax)
            ACDM.MobPowerBar:SetValue(attunementStacks)
            ACDM.MobPowerBar.text:SetText(string.format("Mob Power: +%d%%", mobPowerPct))
            
            -- 3. Tick Weakness timer if active
            local debuffStacks = ACDM.runInfo.debuffs or 0
            local debuffTimer = ACDM.runInfo.debuffTimer or 0
            if debuffStacks > 0 then
                local debuffTimerLocal = math.max(0, debuffTimer - elapsedLocal)
                if debuffTimerLocal <= 0 then
                    ACDM.runInfo.debuffs = 0
                    ACDM.runInfo.debuffTimer = 0
                    ACDM.WeaknessBar:Hide()
                    self.RearrangeBars()
                else
                    ACDM.WeaknessBar:SetValue(debuffTimerLocal)
                    
                    local debuffM = math.floor(debuffTimerLocal / 60)
                    local debuffS = debuffTimerLocal % 60
                    ACDM.WeaknessBar.text:SetText(string.format("Weakened (%d): %02d:%02d", debuffStacks, debuffM, debuffS))
                end
            end

            -- 4. Check for uncached items in slots
            local itemsCount = ACDM.runInfo.rewardedItems and #ACDM.runInfo.rewardedItems or 0
            if itemsCount > 0 then
                for i = 1, math.min(5, itemsCount) do
                    local slot = self.rewardItemSlots[i]
                    if slot:IsShown() and not slot.isPlusSlot and not slot.itemLink then
                        local itemInfo = ACDM.runInfo.rewardedItems[i]
                        local itemId = itemInfo.id
                        local name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(itemId)
                        if name then
                            slot.icon:SetTexture(texture)
                            slot.itemLink = link
                            local r, g, b = GetItemQualityColor(quality)
                            slot.border:SetVertexColor(r, g, b)
                            slot.border:Show()
                        end
                    end
                end
            end
        end
    end)

    ACDM.TrackerFrame = tracker
    ACDM.TrackerFrame:Hide() -- initially hidden until active run detected
end

function ACDM.UpdateTrackerUI()
    if not ACDM.TrackerFrame then return end
    
    local inRun = (ACDM.flags.inSession == 1) or (ACDM.flags.inRoguelike == 1)
    if not inRun then
        ACDM.TrackerFrame:Hide()
        return
    end

    if inRun and (#ACDM.dungeons == 0) and (ACDM.queryState == "idle") then
        ACDM.RequestQuery()
    end
    
    if ACDM.runInfo.trackerClosedByUser then
        ACDM.TrackerFrame:Hide()
        return
    end
    
    ACDM.TrackerFrame:Show()
    
    -- Update Lives Text
    local wipes = ACDM.runInfo.wipes or 0
    local maxWipes = ACDM.runInfo.maxWipes or 0
    local livesStr = ""
    if maxWipes == 0 then
        livesStr = "∞"
    else
        local lives = maxWipes - wipes
        if lives < 0 then lives = 0 end
        livesStr = tostring(lives)
    end
    ACDM.TrackerFrame.livesText:SetText(livesStr)
    
    -- Update Title (Dungeon Name / Roguelike Info)
    local dngName = "Dungeon Challenge"
    local runTypeStr = "Active Run"
    if ACDM.flags.inRoguelike == 1 then
        dngName = "Roguelike Run"
        runTypeStr = "Floor " .. ((ACDM.flags.rlFloors or 0) + 1) .. " (Tier " .. (ACDM.flags.rlTier or 1) .. ")"
    elseif ACDM.selection.mapId and ACDM.selection.mapId > 0 then
        for _, dg in ipairs(ACDM.dungeons) do
            if dg.MapId == ACDM.selection.mapId then
                dngName = dg.Name
                break
            end
        end
    end
    
    if strlen(dngName) > 22 then
        dngName = strsub(dngName, 1, 19) .. "..."
    end
    ACDM.TrackerFrame.titleText:SetText(dngName)
    ACDM.TrackerFrame.descText:SetText(runTypeStr)
    
    -- Update Attunement Stacks & Potency
    local attunementStacks = ACDM.runInfo.survivalBuffs or 0
    ACDM.AttunementBar:SetMinMaxValues(0, 300)
    local progress = (ACDM.runInfo.timeAlive or 0) % 300
    ACDM.AttunementBar:SetValue(progress)
    ACDM.AttunementBar.text:SetText(string.format("Attunement: +%d%% (%d)", attunementStacks * 10, attunementStacks))
    
    -- Update Mob Power adaptation scaling
    local mobPowerPct = attunementStacks * 4
    local mobMax = math.max(10, attunementStacks)
    ACDM.MobPowerBar:SetMinMaxValues(0, mobMax)
    ACDM.MobPowerBar:SetValue(attunementStacks)
    ACDM.MobPowerBar.text:SetText(string.format("Mob Power: +%d%%", mobPowerPct))
    
    -- Update Weakness Bar if active
    local debuffStacks = ACDM.runInfo.debuffs or 0
    local debuffTimer = ACDM.runInfo.debuffTimer or 0
    if debuffStacks > 0 then
        ACDM.WeaknessBar:SetMinMaxValues(0, 180)
        ACDM.WeaknessBar:SetValue(debuffTimer)
        local debuffM = math.floor(debuffTimer / 60)
        local debuffS = debuffTimer % 60
        ACDM.WeaknessBar.text:SetText(string.format("Weakened (%d): %02d:%02d", debuffStacks, debuffM, debuffS))
    end
    
    -- Update Run Details (Difficulty & Theme)
    local diffName = "Normal"
    if ACDM.selection.diffId then
        for _, d in ipairs(ACDM.difficulties) do
            if d.Id == ACDM.selection.diffId then
                diffName = d.Name
                break
            end
        end
    end
    ACDM.TrackerFrame.diffLabel:SetText(ACDM.ColorText("Difficulty: ", ACDM.Colors.Gold) .. ACDM.ColorText(diffName, ACDM.Colors.White))
    
    local themeName = "Random Theme"
    if ACDM.selection.themeId then
        for _, t in ipairs(ACDM.themes) do
            if t.Id == ACDM.selection.themeId then
                themeName = t.Name
                break
            end
        end
    end
    ACDM.TrackerFrame.themeLabel:SetText(ACDM.ColorText("Theme: ", ACDM.Colors.Gold) .. ACDM.ColorText(themeName, ACDM.Colors.White))
    -- Set Scaling Mode text
    local scalingStr = ACDM.flags.scaleParty == 1 and "Scale to Party Level" or "Dungeon Default"
    local scalingColor = ACDM.flags.scaleParty == 1 and ACDM.Colors.Green or ACDM.Colors.Grey
    ACDM.TrackerFrame.scalingLabel:SetText(ACDM.ColorText("Scaling: ", ACDM.Colors.Gold) .. ACDM.ColorText(scalingStr, scalingColor))
    
    if ACDM.flags.inRoguelike == 1 then
        local activeGambits = {}
        if ACDM.flags.gambitTimeTrial == 1 then table.insert(activeGambits, "Time Trial") end
        if ACDM.flags.gambitGlassCannon == 1 then table.insert(activeGambits, "Glass Cannon") end
        if ACDM.flags.gambitPacifist == 1 then table.insert(activeGambits, "Pacifist") end

        local gambitsStr = "None"
        if #activeGambits > 0 then
            gambitsStr = table.concat(activeGambits, ", ")
        end
        ACDM.TrackerFrame.gambitLabel:SetText(ACDM.ColorText("Gambits: ", ACDM.Colors.Gold) .. ACDM.ColorText(gambitsStr, ACDM.Colors.White))
    end

    -- Update Active Affixes row in Tracker
    local activeAffixes = ACDM.runInfo.activeAffixes or {}
    local numActive = #activeAffixes
    if numActive > 0 then
        ACDM.TrackerFrame.affixesLabel:SetText(ACDM.ColorText("Affixes: ", ACDM.Colors.Gold))
        
        for i = 1, 3 do
            local btn = ACDM.TrackerFrame.affixIcons[i]
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
                        btn.Border:SetVertexColor(0.82, 0.68, 0.32) -- Gold border
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
                    btn:Show()
                else
                    btn:Hide()
                end
            else
                btn:Hide()
            end
        end
    else
        ACDM.TrackerFrame.affixesLabel:Hide()
        for i = 1, 3 do
            ACDM.TrackerFrame.affixIcons[i]:Hide()
        end
    end
    
    -- Update Cumulative Rewards (Gold & Item icon slots)
    local gold = ACDM.runInfo.accumulatedGold or 0
    if gold > 0 then
        local g = math.floor(gold / 10000)
        local s = math.floor((gold % 10000) / 100)
        local c = gold % 100
        local goldStr = ""
        if g > 0 then goldStr = goldStr .. "|cffffd700" .. g .. "g|r " end
        if s > 0 then goldStr = goldStr .. "|cffc7c7c7" .. s .. "s|r " end
        if c > 0 or goldStr == "" then goldStr = goldStr .. "|cffeda55f" .. c .. "c|r" end
        ACDM.TrackerFrame.rewardsGoldLabel:SetText(ACDM.ColorText("Gold: ", ACDM.Colors.Gold) .. goldStr)
    end
    
    local itemsCount = ACDM.runInfo.rewardedItems and #ACDM.runInfo.rewardedItems or 0
    if itemsCount > 0 then
        for i = 1, 5 do
            local slot = ACDM.TrackerFrame.rewardItemSlots[i]
            if i <= itemsCount then
                if i == 5 and itemsCount > 5 then
                    slot.isPlusSlot = true
                    slot.itemLink = nil
                    slot.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_07")
                    slot.border:SetVertexColor(0.82, 0.68, 0.32) -- gold color
                    slot.border:Show()
                    slot.text:SetText("+" .. (itemsCount - 4))
                    slot.text:Show()
                else
                    slot.isPlusSlot = false
                    slot.text:Hide()
                    local itemInfo = ACDM.runInfo.rewardedItems[i]
                    local itemId = itemInfo.id
                    local name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(itemId)
                    if name then
                        slot.icon:SetTexture(texture)
                        slot.itemLink = link
                        local r, g, b = GetItemQualityColor(quality)
                        slot.border:SetVertexColor(r, g, b)
                        slot.border:Show()
                    else
                        slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        slot.itemLink = nil
                        slot.border:Hide()
                    end
                end
            end
        end
    end
    
    ACDM.TrackerFrame.RearrangeBars()
end

function ACDM.PrintRewardNotification(gold, itemId, isMailed)
    local goldStr = ""
    local rawGoldStr = ""
    if gold > 0 then
        local g = math.floor(gold / 10000)
        local s = math.floor((gold % 10000) / 100)
        local c = gold % 100
        if g > 0 then
            goldStr = goldStr .. "|cffffd700" .. g .. "g|r "
            rawGoldStr = rawGoldStr .. g .. "g "
        end
        if s > 0 then
            goldStr = goldStr .. "|cffc7c7c7" .. s .. "s|r "
            rawGoldStr = rawGoldStr .. s .. "s "
        end
        if c > 0 or goldStr == "" then
            goldStr = goldStr .. "|cffeda55f" .. c .. "c|r"
            rawGoldStr = rawGoldStr .. c .. "c"
        end
    end

    local itemLink = nil
    if itemId > 0 then
        local _, link = GetItemInfo(itemId)
        itemLink = link
    end

    -- Construct Chat Message
    local chatMsg = "|cFF00FF00[Dungeon Master]|r |cffffd159Reward Gained:|r "
    if goldStr ~= "" and itemLink then
        chatMsg = chatMsg .. goldStr .. "and " .. itemLink
    elseif goldStr ~= "" then
        chatMsg = chatMsg .. goldStr
    elseif itemLink then
        chatMsg = chatMsg .. itemLink
    else
        chatMsg = chatMsg .. "None"
    end

    if itemId > 0 and isMailed then
        chatMsg = chatMsg .. " |cffff0000(Sent to Mailbox due to full bags)|r"
    end
    chatMsg = chatMsg .. "!"

    -- Print to chat
    DEFAULT_CHAT_FRAME:AddMessage(chatMsg)

    -- Construct and display Raid Warning screen alert
    local screenMsg = "|cFF00FF00[Reward Received] |r"
    if rawGoldStr ~= "" and itemId > 0 then
        screenMsg = screenMsg .. "|cffffffff" .. rawGoldStr .. "|r + |cffffd159Gear!|r"
    elseif rawGoldStr ~= "" then
        screenMsg = screenMsg .. "|cffffffff" .. rawGoldStr .. "|r"
    elseif itemId > 0 then
        screenMsg = screenMsg .. "|cffffd159New Gear!|r"
    else
        screenMsg = screenMsg .. "|cffffffffCompleted!|r"
    end

    RaidNotice_AddMessage(RaidBossEmoteFrame, screenMsg, ChatTypeInfo["RAID_WARNING"])
end

function ACDM.ShowRewardPopup(gold, itemId, isMailed)
    -- Play Sound
    PlaySoundFile("Sound\\Interface\\LevelUp.ogg")

    -- Reuse existing frame or create new
    local popup = ACDM.RewardPopupFrame
    if not popup then
        popup = CreateFrame("Frame", "ACDMRewardPopupFrame", UIParent)
        popup:SetSize(320, 120)
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
        popup:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 24, edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        popup:SetBackdropColor(0.08, 0.08, 0.12, 0.94)
        popup:SetBackdropBorderColor(0.85, 0.72, 0.15, 1.0) -- Premium Gold Border
        popup:SetMovable(true)
        popup:EnableMouse(true)
        popup:RegisterForDrag("LeftButton")
        popup:SetScript("OnDragStart", function(self) self:StartMoving() end)
        popup:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

        -- Close Button
        local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -2, -2)
        closeBtn:SetScript("OnClick", function()
            popup:Hide()
            popup:SetScript("OnUpdate", nil)
        end)

        -- Title Text
        local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", popup, "TOP", 0, -12)
        title:SetTextColor(1.0, 0.82, 0.0) -- Gold
        title:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        title:SetText("CHALLENGE REWARD!")
        popup.title = title

        -- Gold Info
        local goldText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        goldText:SetPoint("TOP", title, "BOTTOM", 0, -8)
        goldText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        popup.goldText = goldText

        -- Item Button/Icon
        local itemBtn = CreateFrame("Button", nil, popup)
        itemBtn:SetSize(36, 36)
        itemBtn:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 20, 20)
        
        local icon = itemBtn:CreateTexture(nil, "BACKGROUND")
        icon:SetAllPoints(itemBtn)
        itemBtn.icon = icon

        local border = itemBtn:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetSize(60, 60)
        border:SetPoint("CENTER", itemBtn, "CENTER", 0, 0)
        border:SetBlendMode("ADD")
        itemBtn.border = border

        itemBtn:SetScript("OnEnter", function(self)
            if self.itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
            end
        end)
        itemBtn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        itemBtn:SetScript("OnClick", function(self)
            if self.itemLink then
                HandleModifiedItemClick(self.itemLink)
            end
        end)

        popup.itemBtn = itemBtn

        -- Item Text
        local itemText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        itemText:SetPoint("LEFT", itemBtn, "RIGHT", 10, 0)
        itemText:SetPoint("RIGHT", popup, "RIGHT", -20, 0)
        itemText:SetJustifyH("LEFT")
        itemText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        popup.itemText = itemText

        -- Mail indicator
        local mailText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mailText:SetPoint("TOPLEFT", itemText, "BOTTOMLEFT", 0, -2)
        mailText:SetTextColor(1, 0.4, 0.4)
        mailText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        mailText:SetText("(Sent to Mailbox)")
        popup.mailText = mailText

        ACDM.RewardPopupFrame = popup
    end

    popup.notificationPrinted = false

    -- Format Gold
    if gold > 0 then
        local g = math.floor(gold / 10000)
        local s = math.floor((gold % 10000) / 100)
        local c = gold % 100
        local gStr = ""
        if g > 0 then gStr = gStr .. g .. "g " end
        if s > 0 then gStr = gStr .. s .. "s " end
        if c > 0 or gStr == "" then gStr = gStr .. c .. "c" end
        popup.goldText:SetText(ACDM.ColorText("Gained: ", ACDM.Colors.Gold) .. ACDM.ColorText(gStr, ACDM.Colors.White))
        popup.goldText:Show()
    else
        popup.goldText:Hide()
    end

    -- Handle Item Info
    if itemId > 0 then
        popup.itemBtn:Show()
        popup.itemText:Show()
        if isMailed then
            popup.mailText:Show()
        else
            popup.mailText:Hide()
        end

        popup.hasItemInfo = false
        popup.itemId = itemId

        local name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(itemId)
        if name then
            popup.hasItemInfo = true
            popup.itemText:SetText(link)
            popup.itemBtn.icon:SetTexture(texture)
            popup.itemBtn.itemLink = link
            local r, g, b = GetItemQualityColor(quality)
            popup.itemBtn.border:SetVertexColor(r, g, b)
            popup.itemBtn.border:Show()

            if not popup.notificationPrinted then
                ACDM.PrintRewardNotification(gold, itemId, isMailed)
                popup.notificationPrinted = true
            end
        else
            popup.itemText:SetText("Retrieving Item Info...")
            popup.itemBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            popup.itemBtn.border:Hide()
            popup.itemBtn.itemLink = nil
        end
        
        -- Adjust height with item
        popup:SetHeight(130)
        if gold > 0 then
            popup.goldText:SetPoint("TOP", popup.title, "BOTTOM", 0, -8)
            popup.itemBtn:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 20, 20)
        else
            -- Center item vertically if no gold
            popup.itemBtn:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 20, 30)
        end
    else
        popup.itemBtn:Hide()
        popup.itemText:Hide()
        popup.mailText:Hide()
        popup:SetHeight(90)

        if not popup.notificationPrinted then
            ACDM.PrintRewardNotification(gold, itemId, isMailed)
            popup.notificationPrinted = true
        end
    end

    popup:Show()

    -- Set Auto-close and retry loop script
    local elapsed = 0
    local retryElapsed = 0
    popup:SetScript("OnUpdate", function(self, el)
        elapsed = elapsed + el
        if elapsed >= 8 then
            self:Hide()
            self:SetScript("OnUpdate", nil)
            return
        end

        if itemId > 0 and not self.hasItemInfo then
            retryElapsed = retryElapsed + el
            if retryElapsed >= 0.2 then
                retryElapsed = 0
                local name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(itemId)
                if name then
                    self.hasItemInfo = true
                    self.itemText:SetText(link)
                    self.itemBtn.icon:SetTexture(texture)
                    self.itemBtn.itemLink = link
                    local r, g, b = GetItemQualityColor(quality)
                    self.itemBtn.border:SetVertexColor(r, g, b)
                    self.itemBtn.border:Show()

                    if not self.notificationPrinted then
                        ACDM.PrintRewardNotification(gold, itemId, isMailed)
                        self.notificationPrinted = true
                    end
                end
            end
        end
    end)
end

function ACDM.OnAdvanceRoguelike(success, reason)
    if ACDM.TrackerFrame then
        ACDM.TrackerFrame.advanceBtn:Enable()
        ACDM.TrackerFrame.quitBtn:Enable()
    end
    if not success then
        UIErrorsFrame:AddMessage("Failed to advance: " .. (reason or "Unknown"), 1, 0, 0, 1.0, 5)
    else
        UIErrorsFrame:AddMessage("Advancing to the next floor!", 0, 1, 0, 1.0, 3)
    end
end

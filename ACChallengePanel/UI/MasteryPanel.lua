-- UI/MasteryPanel.lua
-- Dedicated meta-progression mastery tree UI panel for ACDM

function ACDM.CreateMasteryPanel()
    local parent = ACDM.TabFrames[6]

    -- Title
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -15)
    title:SetText("Dungeon Mastery Perks")
    title:SetTextColor(ACDM.Colors.Gold.r, ACDM.Colors.Gold.g, ACDM.Colors.Gold.b)

    -- Subtitle / Mastery Points display
    local pointsText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    pointsText:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -15, -15)
    pointsText:SetText("Mastery Points Available: " .. ACDM.ColorText("0", ACDM.Colors.Green))
    parent.PointsText = pointsText

    -- Description
    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(480)
    desc:SetJustifyH("LEFT")
    desc:SetText("Unlock permanent character perks using Mastery Points earned by completing Dungeon Challenges and clearing Roguelike floors.")
    desc:SetTextColor(ACDM.Colors.Muted.r, ACDM.Colors.Muted.g, ACDM.Colors.Muted.b)

    -- Center Area for Tree
    local treeBox = CreateFrame("Frame", nil, parent)
    treeBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -70)
    treeBox:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 35)
    treeBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    treeBox:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    treeBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    parent.TreeBox = treeBox

    -- Perk details configuration
    local perks = {
        { id = 0, name = "Scout", cost = 1, icon = "Interface\\Icons\\Spell_Nature_EyeOfTheStorm", desc = "Reveals hidden active dungeon affixes in pre-run previews." },
        { id = 1, name = "Veteran", cost = 2, icon = "Interface\\Icons\\Ability_Warrior_ShieldWall", desc = "Reduces all damage taken inside challenges by 5%." },
        { id = 2, name = "Pathfinder", cost = 3, icon = "Interface\\Icons\\Ability_Hunter_Pathfinding", desc = "Generates 4 branching choices (instead of 3) when clearing floors." },
        { id = 3, name = "Gladiator", cost = 4, icon = "Interface\\Icons\\Ability_Warrior_InnerRage", desc = "Increases all damage dealt inside challenges by 5%." },
        { id = 4, name = "Survivor", cost = 5, icon = "Interface\\Icons\\Spell_Holy_Resurrection", desc = "Increases your starting wipes/lives count by 1 in Roguelike mode." }
    }

    -- Create perk buttons
    parent.Buttons = {}
    for i, perk in ipairs(perks) do
        -- Visual Connector Line (Draw line from previous perk to this perk)
        if i > 1 then
            local line = treeBox:CreateTexture(nil, "BACKGROUND")
            line:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
            line:SetVertexColor(0.3, 0.3, 0.3, 0.5)
            line:SetWidth(4)
            -- Vertical line from bottom of previous button to top of this button
            line:SetPoint("TOP", treeBox, "TOP", 0, -20 - (i-2)*70 - 56)
            line:SetPoint("BOTTOM", treeBox, "TOP", 0, -20 - (i-1)*70)
            perk.connectorLine = line
        end

        local btn = CreateFrame("Button", nil, treeBox)
        btn:SetSize(440, 56)
        -- Lay out vertically centered in treeBox
        btn:SetPoint("TOP", treeBox, "TOP", 0, -20 - (i-1) * 70)
        btn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        btn:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
        btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

        -- Icon
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", btn, "LEFT", 10, 0)
        icon:SetTexture(perk.icon)
        btn.Icon = icon

        -- Name Text
        local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 2)
        nameText:SetText(perk.name)
        btn.NameText = nameText

        -- Cost Text
        local costText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        costText:SetPoint("RIGHT", btn, "RIGHT", -45, 0)
        btn.CostText = costText

        -- Description Text
        local descText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        descText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)
        descText:SetWidth(300)
        descText:SetJustifyH("LEFT")
        descText:SetText(perk.desc)
        descText:SetTextColor(0.7, 0.7, 0.7)
        btn.DescText = descText

        -- Lock Icon / Glow overlay
        local statusOverlay = btn:CreateTexture(nil, "OVERLAY")
        statusOverlay:SetSize(20, 20)
        statusOverlay:SetPoint("RIGHT", btn, "RIGHT", -12, 0)
        btn.StatusOverlay = statusOverlay

        -- Mouse Highlight
        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\Buttons\\UI-ListboxHighlight")
        highlight:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
        highlight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
        highlight:SetBlendMode("ADD")


        -- Tooltip script
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(perk.name, 1, 0.82, 0)
            GameTooltip:AddLine(perk.desc, 1, 1, 1, true)
            GameTooltip:AddLine("Cost: " .. perk.cost .. " Mastery Points", 0, 1, 0)
            
            local hasPerk = (math.floor((ACDM.purchasedMask or 0) / (2 ^ perk.id)) % 2 == 1)
            if hasPerk then
                GameTooltip:AddLine("STATUS: UNLOCKED", 0, 1, 1)
            else
                local points = ACDM.masteryPoints or 0
                if points >= perk.cost then
                    GameTooltip:AddLine("Click to unlock perk!", 0, 1, 0)
                else
                    GameTooltip:AddLine("Requires " .. (perk.cost - points) .. " more Mastery Points.", 1, 0, 0)
                end
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Confirmation click script
        btn:SetScript("OnClick", function()
            local points = ACDM.masteryPoints or 0
            local hasPerk = (math.floor((ACDM.purchasedMask or 0) / (2 ^ perk.id)) % 2 == 1)
            
            if hasPerk then
                return
            end

            if points < perk.cost then
                UIErrorsFrame:AddMessage("|cFFFF0000Not enough Mastery Points to unlock " .. perk.name .. "!|r", 1.0, 0.1, 0.1, 1.0, 5)
                return
            end

            StaticPopupDialogs["CONFIRM_BUY_PERK"] = {
                text = "Are you sure you want to purchase " .. perk.name .. " for " .. perk.cost .. " Mastery Points?",
                button1 = "Yes",
                button2 = "No",
                OnAccept = function()
                    ACDM.SendCommand(".dm rlbuymastery " .. perk.id)
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("CONFIRM_BUY_PERK")
        end)

        parent.Buttons[perk.id] = btn
    end

    -- Bottom refresh button
    local refreshBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    refreshBtn:SetSize(140, 22)
    refreshBtn:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 5)
    refreshBtn:SetText("Refresh Tree")
    refreshBtn:SetScript("OnClick", function() ACDM.RequestStats() end)

    function ACDM.RefreshMasteryPanel()
        if not parent:IsVisible() then return end
        
        pointsText:SetText("Mastery Points Available: " .. ACDM.ColorText(tostring(ACDM.masteryPoints or 0), ACDM.Colors.Green))
        
        local mask = ACDM.purchasedMask or 0
        local points = ACDM.masteryPoints or 0
        
        for _, perk in ipairs(perks) do
            local btn = parent.Buttons[perk.id]
            local hasPerk = (math.floor(mask / (2 ^ perk.id)) % 2 == 1)
            
            if hasPerk then
                -- Purchased state
                btn:SetBackdropColor(0.05, 0.25, 0.05, 0.6)
                btn:SetBackdropBorderColor(0.0, 1.0, 0.0, 0.8)
                btn.Icon:SetVertexColor(1.0, 1.0, 1.0)
                btn.NameText:SetTextColor(0.0, 1.0, 0.0)
                btn.CostText:SetText("|cFF00FFFFUnlocked|r")
                btn.StatusOverlay:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                btn.StatusOverlay:SetTexCoord(0, 1, 0, 1)
                btn.StatusOverlay:Show()
                if perk.connectorLine then
                    perk.connectorLine:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
                    perk.connectorLine:SetVertexColor(0.0, 0.8, 0.0, 0.8)
                end
            else
                if points >= perk.cost then
                    -- Affordable state
                    btn:SetBackdropColor(0.2, 0.18, 0.05, 0.6)
                    btn:SetBackdropBorderColor(0.8, 0.8, 0.0, 0.8)
                    btn.Icon:SetVertexColor(1.0, 1.0, 1.0)
                    btn.NameText:SetTextColor(1.0, 1.0, 1.0)
                    btn.CostText:SetText("|cFFFFD700Cost: " .. perk.cost .. "|r")
                    btn.StatusOverlay:Hide()
                else
                    -- Locked/Unaffordable state
                    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.4)
                    btn.Icon:SetVertexColor(0.4, 0.4, 0.4)
                    btn.NameText:SetTextColor(0.5, 0.5, 0.5)
                    btn.CostText:SetText("|cFFFF4444Cost: " .. perk.cost .. "|r")
                    btn.StatusOverlay:SetTexture("Interface\\PetPackages\\MountJournal") -- Lock icon
                    btn.StatusOverlay:SetTexCoord(0.65, 0.95, 0.05, 0.35) -- Zoom to lock icon
                    btn.StatusOverlay:Show()
                end
                if perk.connectorLine then
                    perk.connectorLine:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
                    perk.connectorLine:SetVertexColor(0.3, 0.3, 0.3, 0.5)
                end
            end
        end
    end

    -- Hook show event to refresh automatically
    parent:SetScript("OnShow", function()
        ACDM.RefreshMasteryPanel()
    end)
end

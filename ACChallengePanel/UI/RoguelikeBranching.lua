-- UI/RoguelikeBranching.lua
-- Branching choices dialog frame displayed when transitioning dungeon floors in Roguelike mode

function ACDM.ShowBranchingChoices()
    if not ACDM.branchChoices or #ACDM.branchChoices == 0 then
        return
    end

    if not ACDMBranchChoicesFrame then
        local f = CreateFrame("Frame", "ACDMBranchChoicesFrame", UIParent)
        f:SetSize(520, 260)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        f:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)

        -- Title Header
        local titleBG = f:CreateTexture(nil, "ARTWORK")
        titleBG:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
        titleBG:SetWidth(300)
        titleBG:SetHeight(64)
        titleBG:SetPoint("TOP", f, "TOP", 0, 12)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", titleBG, "TOP", 0, -14)
        title:SetText("Select Next Dungeon Branch")
        title:SetTextColor(ACDM.Colors.Cyan.r, ACDM.Colors.Cyan.g, ACDM.Colors.Cyan.b)
        f.Title = title

        -- Subtitle explaining the choice
        local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subtitle:SetPoint("TOP", f, "TOP", 0, -35)
        subtitle:SetText("Choose one of the branching paths. Click to select and transition.")
        subtitle:SetTextColor(ACDM.Colors.Muted.r, ACDM.Colors.Muted.g, ACDM.Colors.Muted.b)

        -- Choice cards (up to 4)
        f.Cards = {}
        for i = 1, 4 do
            local card = CreateFrame("Button", nil, f)
            card:SetSize(140, 150)
            
            -- Backdrop for cards
            card:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 }
            })
            card:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
            card:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

            -- Highlight texture on hover
            local highlight = card:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetTexture("Interface\\Buttons\\UI-ListboxHighlight")
            highlight:SetPoint("TOPLEFT", card, "TOPLEFT", 3, -3)
            highlight:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -3, 3)
            highlight:SetBlendMode("ADD")


            -- Dungeon Title (with word wrap)
            local dngText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            dngText:SetPoint("TOP", card, "TOP", 0, -20)
            dngText:SetWidth(120)
            dngText:SetJustifyH("CENTER")
            card.DngText = dngText

            -- Separator
            local sep = card:CreateTexture(nil, "ARTWORK")
            sep:SetPoint("TOP", dngText, "BOTTOM", 0, -10)
            sep:SetSize(110, 1)
            sep:SetTexture(0.3, 0.3, 0.3, 0.5)
            card.Separator = sep

            -- Theme Title
            local themeText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            themeText:SetPoint("TOP", sep, "BOTTOM", 0, -12)
            themeText:SetWidth(120)
            themeText:SetJustifyH("CENTER")
            card.ThemeText = themeText

            -- Risk Title
            local riskText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            riskText:SetPoint("BOTTOM", card, "BOTTOM", 0, 20)
            riskText:SetWidth(120)
            riskText:SetJustifyH("CENTER")
            card.RiskText = riskText

            f.Cards[i] = card
        end

        ACDMBranchChoicesFrame = f
    end

    -- Update card values and dynamic width/layout
    local choices = ACDM.branchChoices
    local numChoices = #choices
    if numChoices > 0 then
        local frameWidth = numChoices * 140 + (numChoices - 1) * 15 + 50
        ACDMBranchChoicesFrame:SetWidth(frameWidth)
    end

    for i = 1, 4 do
        local card = ACDMBranchChoicesFrame.Cards[i]
        local choice = choices[i]
        
        if choice then
            card:Show()
            card:ClearAllPoints()
            card:SetPoint("LEFT", ACDMBranchChoicesFrame, "LEFT", 25 + (i - 1) * 155, -15)
            
            -- Lookup dungeon name
            local dungeonName = "Unknown Dungeon"
            local dg = ACDM.dungeons[choice.dungeonIndex]
            if dg then
                dungeonName = dg.Name
            end
            card.DngText:SetText(ACDM.ColorText(dungeonName, ACDM.Colors.White))

            -- Lookup theme name
            local themeName = "Unknown Theme"
            if choice.themeId > 0 then
                for _, theme in ipairs(ACDM.themes) do
                    if theme.Id == choice.themeId then
                        themeName = theme.Name
                        break
                    end
                end
            else
                themeName = "???"
            end
            card.ThemeText:SetText(ACDM.ColorText("Theme:", ACDM.Colors.Cyan) .. "\n" .. ACDM.ColorText(themeName, ACDM.Colors.White))

            -- Set risk name & color
            local riskLabel = "Unknown"
            local riskColor = ACDM.Colors.Grey
            if choice.risk == 1 then
                riskLabel = "Low"
                riskColor = ACDM.Colors.Green
            elseif choice.risk == 2 then
                riskLabel = "Medium"
                riskColor = ACDM.Colors.Gold
            elseif choice.risk == 3 then
                riskLabel = "High"
                riskColor = ACDM.Colors.Red
            end
            card.RiskText:SetText(ACDM.ColorText("Risk: ", ACDM.Colors.Muted) .. ACDM.ColorText(riskLabel, riskColor))

            -- Border color matching risk
            card:SetBackdropBorderColor(riskColor.r, riskColor.g, riskColor.b, 0.8)

            -- Click handler
            card:SetScript("OnClick", function()
                ACDM.SendCommand(string.format(".dm rlselect %u %u", choice.dungeonIndex, choice.themeId))
                ACDMBranchChoicesFrame:Hide()
            end)
        else
            card:Hide()
        end
    end

    ACDMBranchChoicesFrame:Show()
end

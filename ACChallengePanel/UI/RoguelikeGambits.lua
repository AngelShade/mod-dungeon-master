-- UI/RoguelikeGambits.lua
-- Gambit selection popup frame displayed during the preparation phase in Roguelike mode

ACDM.lastGambitFloor = nil
ACDM.lastGambitState = nil

function ACDM.ShowGambitSelection()
    if ACDM.flags.inRoguelike ~= 1 or ACDM.flags.sessionState ~= 1 then
        return
    end

    if not ACDMGambitSelectionFrame then
        local f = CreateFrame("Frame", "ACDMGambitSelectionFrame", UIParent)
        f:SetSize(400, 260)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
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
        titleBG:SetWidth(280)
        titleBG:SetHeight(64)
        titleBG:SetPoint("TOP", f, "TOP", 0, 12)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", titleBG, "TOP", 0, -14)
        title:SetText("Choose Your Gambits")
        title:SetTextColor(ACDM.Colors.Gold.r, ACDM.Colors.Gold.g, ACDM.Colors.Gold.b)
        f.Title = title

        -- Subtitle / Instructions
        local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subtitle:SetPoint("TOP", f, "TOP", 0, -35)
        subtitle:SetWidth(360)
        subtitle:SetText("Choose up to 2 Gambits to increase your rewards by +25% each.")
        subtitle:SetTextColor(ACDM.Colors.Muted.r, ACDM.Colors.Muted.g, ACDM.Colors.Muted.b)
        f.Subtitle = subtitle

        -- Timer countdown text
        local timerText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        timerText:SetPoint("TOP", subtitle, "BOTTOM", 0, -10)
        timerText:SetText("Preparation Phase: 30s remaining")
        timerText:SetTextColor(ACDM.Colors.Cyan.r, ACDM.Colors.Cyan.g, ACDM.Colors.Cyan.b)
        f.TimerText = timerText

        -- Checkboxes
        local gambitLabels = { "Time Trial", "Glass Cannon", "Pacifist" }
        local gambitTooltips = {
            "Time Trial: Complete the floor within a strict time limit. (+25% reward bonus)",
            "Glass Cannon: Deal 50% more damage, but take 50% more damage. (+25% reward bonus)",
            "Pacifist: Trash mobs yield no loot or gold. (+25% reward bonus)"
        }

        f.CBs = {}
        for i = 1, 3 do
            local cb = CreateFrame("CheckButton", "ACDMGambitPopupCheck" .. i, f, "UICheckButtonTemplate")
            cb:SetSize(22, 22)
            cb:SetPoint("TOPLEFT", f, "TOPLEFT", 40, -85 - (i-1)*32)

            local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", cb, "RIGHT", 8, 0)
            text:SetText(gambitLabels[i])
            cb.Text = text

            -- Tooltip
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(gambitLabels[i], 1, 0.82, 0.35)
                GameTooltip:AddLine(gambitTooltips[i], 1, 1, 1, true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", function() GameTooltip:Hide() end)

            -- Click
            cb:SetScript("OnClick", function(self)
                ACDM.SendCommand(".dm rltogglegambit " .. i)
            end)

            f.CBs[i] = cb
        end

        -- Bottom Buttons: Start / Lock in and Close
        local startBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        startBtn:SetSize(130, 24)
        startBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 45, 25)
        startBtn:SetText("Lock In & Start")
        startBtn:SetScript("OnClick", function()
            ACDM.SendCommand(".dm rlstart")
            f:Hide()
        end)
        f.StartBtn = startBtn

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(130, 24)
        closeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -45, 25)
        closeBtn:SetText("Close")
        closeBtn:SetScript("OnClick", function()
            f:Hide()
        end)
        f.CloseBtn = closeBtn

        ACDMGambitSelectionFrame = f
    end

    ACDM.UpdateGambitSelectionUI()
    ACDMGambitSelectionFrame:Show()
end

function ACDM.HideGambitSelection()
    if ACDMGambitSelectionFrame then
        ACDMGambitSelectionFrame:Hide()
    end
end

function ACDM.UpdateGambitSelectionUI()
    if not ACDMGambitSelectionFrame or not ACDMGambitSelectionFrame:IsShown() then
        return
    end

    local f = ACDMGambitSelectionFrame

    -- Check if we are the leader
    local isLeader = (GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0) or IsPartyLeader()
    local isPrep = (ACDM.flags.sessionState == 1)

    -- Count active gambits
    local activeCount = 0
    local states = {
        ACDM.flags.gambitTimeTrial == 1,
        ACDM.flags.gambitGlassCannon == 1,
        ACDM.flags.gambitPacifist == 1
    }

    for i = 1, 3 do
        if states[i] then
            activeCount = activeCount + 1
        end
    end

    -- Update checkboxes
    for i = 1, 3 do
        local cb = f.CBs[i]
        cb:SetChecked(states[i])

        if isPrep then
            if isLeader then
                -- Leader can toggle
                -- But if limit of 2 is reached, only allow unchecking already checked ones
                if activeCount >= 2 and not states[i] then
                    cb:Disable()
                    cb.Text:SetTextColor(ACDM.Colors.Grey.r, ACDM.Colors.Grey.g, ACDM.Colors.Grey.b)
                else
                    cb:Enable()
                    cb.Text:SetTextColor(ACDM.Colors.White.r, ACDM.Colors.White.g, ACDM.Colors.White.b)
                end
            else
                -- Non-leaders cannot check
                cb:Disable()
                if states[i] then
                    cb.Text:SetTextColor(ACDM.Colors.Green.r, ACDM.Colors.Green.g, ACDM.Colors.Green.b)
                else
                    cb.Text:SetTextColor(ACDM.Colors.Grey.r, ACDM.Colors.Grey.g, ACDM.Colors.Grey.b)
                end
            end
        else
            -- Outside prep, disable all
            cb:Disable()
            cb.Text:SetTextColor(ACDM.Colors.Grey.r, ACDM.Colors.Grey.g, ACDM.Colors.Grey.b)
        end
    end

    -- Update Start button
    if isLeader and isPrep then
        f.StartBtn:Show()
        f.StartBtn:Enable()
    else
        f.StartBtn:Hide()
    end

    -- Update countdown timer
    local prepTime = ACDM.runInfo.preparationTimer or 30
    f.TimerText:SetText(string.format("Preparation Phase: %ds remaining", prepTime))
    if prepTime <= 5 then
        f.TimerText:SetTextColor(ACDM.Colors.Red.r, ACDM.Colors.Red.g, ACDM.Colors.Red.b)
    else
        f.TimerText:SetTextColor(ACDM.Colors.Cyan.r, ACDM.Colors.Cyan.g, ACDM.Colors.Cyan.b)
    end
end

-- Checks if we should auto-pop the Gambit Selection dialog
function ACDM.CheckAutoShowGambits()
    if ACDM.flags.inRoguelike == 1 and ACDM.flags.sessionState == 1 then
        local currentFloor = ACDM.flags.rlFloors or 0
        local currentState = ACDM.flags.sessionState

        -- Only auto-pop if we are on a new floor or transitioned into prep state
        if ACDM.lastGambitFloor ~= currentFloor or ACDM.lastGambitState ~= currentState then
            ACDM.lastGambitFloor = currentFloor
            ACDM.lastGambitState = currentState
            ACDM.ShowGambitSelection()
        end
    end
end

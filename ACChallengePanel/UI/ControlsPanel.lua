function ACDM.CreateControlsPanel()
    local parent = ACDM.TabFrames[5]
    
    local function SetTextColor(fontString, color)
        fontString:SetTextColor(color.r, color.g, color.b)
    end

    local function CreateSection(title, y, height)
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
        frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y)
        frame:SetHeight(height)
        frame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 24, edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        frame:SetBackdropColor(0.14, 0.14, 0.14, 1.0)
        frame:SetBackdropBorderColor(0.82, 0.68, 0.32, 0.8)

        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -10)
        label:SetText(title)
        SetTextColor(label, ACDM.Colors.Gold)

        return frame
    end

    local function CreateButton(sec, text, x, y, width, command, tooltip)
        local button = CreateFrame("Button", nil, sec, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", sec, "TOPLEFT", x, y)
        button:SetSize(width, 24)
        button:SetText(text)
        
        button:SetScript("OnClick", function()
            if command:find("^/") then
                if command == "/reload" then
                    ReloadUI()
                end
            else
                ACDM.SendCommand(command)
            end
        end)
        
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, 1, 0.82, 0.35)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:AddLine(command, 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        return button
    end

    local subtitle = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -8)
    subtitle:SetText("Quick access commands for leaving active runs or reloading the user interface.")
    SetTextColor(subtitle, ACDM.Colors.Muted)

    -- 1. Dungeon Master section
    local dmSec = CreateSection("Dungeon Master Controls", -28, 185)
    
    local leaveBtn = CreateButton(dmSec, "Leave Challenge", 20, -40, 200, ".dm leave", 
        "Abandons the active Dungeon Master session and returns the party to their saved entry locations.")
    
    local exitBtn = CreateButton(dmSec, "Exit Challenge", 240, -40, 200, ".dm exit", 
        "Same as Leave Challenge.")

    local rejoinBtn = CreateButton(dmSec, "Rejoin Challenge", 20, -72, 200, ".dm rejoin", 
        "Teleports you back into your active Dungeon Master challenge from outside the instance.")
        
    local dmNote = dmSec:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dmNote:SetPoint("TOPLEFT", dmSec, "TOPLEFT", 20, -110)
    dmNote:SetPoint("BOTTOMRIGHT", dmSec, "BOTTOMRIGHT", -20, 10)
    dmNote:SetText("Use Leave/Exit while inside a started challenge. The server returns each player to their pre-challenge position. If you disconnect, you have 5 minutes to reconnect before the session expires. Use Rejoin to return to an active challenge from outside.")
    dmNote:SetJustifyH("LEFT")
    SetTextColor(dmNote, ACDM.Colors.Muted)

    -- 2. Panel/Utility section
    local utilSec = CreateSection("Panel Controls", -223, 112)
    
    local reloadBtn = CreateButton(utilSec, "Reload UI", 20, -38, 200, "/reload", 
        "Reloads the client UI.")
        
    local closeBtn = CreateButton(utilSec, "Close Panel", 240, -38, 200, "Close", 
        "Closes the Dungeon Master Console.")
    
    closeBtn:SetScript("OnClick", function()
        ACDMMainFrame:Hide()
    end)

    local trackerBtn = CreateButton(utilSec, "Toggle HUD Tracker", 20, -70, 200, "Toggle HUD", 
        "Toggles the visibility of the floating HUD tracker overlay.")
    trackerBtn:SetScript("OnClick", function()
        if ACDM.TrackerFrame then
            if ACDM.TrackerFrame:IsShown() then
                ACDM.runInfo.trackerClosedByUser = true
                ACDM.TrackerFrame:Hide()
            else
                ACDM.runInfo.trackerClosedByUser = false
                ACDM.TrackerFrame:Show()
                ACDM.UpdateTrackerUI()
            end
        end
    end)
end

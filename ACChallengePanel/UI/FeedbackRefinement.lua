-- FeedbackRefinement.lua
-- Phase 4: Execution Feedback & Refinement UI components
--   - Floor Completion Grade Frame
--   - Loot & Reward Toast
--   - Death Recap Window & Chat Logger

local function FormatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%d:%02d", m, s)
end

local function FormatGold(gold)
    if gold <= 0 then return "0c" end
    local g = math.floor(gold / 10000)
    local s = math.floor((gold % 10000) / 100)
    local c = gold % 100
    
    local str = ""
    if g > 0 then
        str = str .. g .. "|cFFFFD700g|r "
    end
    if s > 0 then
        str = str .. s .. "|cFFC0C0C0s|r "
    end
    if c > 0 or str == "" then
        str = str .. c .. "|cFFFF8C00c|r"
    end
    return str
end

local SchoolColors = {
    [1] = "FFFFFFFF",  -- Physical
    [2] = "FFFFFF00",  -- Holy
    [4] = "FFFF4500",  -- Fire
    [8] = "FF00FF00",  -- Nature
    [16] = "FF00FFFF", -- Frost
    [32] = "FF800080", -- Shadow
    [64] = "FFDA70D6", -- Arcane
}

local SchoolNames = {
    [1] = "Physical",
    [2] = "Holy",
    [4] = "Fire",
    [8] = "Nature",
    [16] = "Frost",
    [32] = "Shadow",
    [64] = "Arcane",
}

local function GetSchoolColorAndName(mask)
    if bit and bit.band then
        if bit.band(mask, 64) > 0 then return "FFDA70D6", "Arcane"
        elseif bit.band(mask, 32) > 0 then return "FF800080", "Shadow"
        elseif bit.band(mask, 16) > 0 then return "FF00FFFF", "Frost"
        elseif bit.band(mask, 8) > 0 then return "FF00FF00", "Nature"
        elseif bit.band(mask, 4) > 0 then return "FFFF4500", "Fire"
        elseif bit.band(mask, 2) > 0 then return "FFFFFF00", "Holy"
        else return "FFFFFFFF", "Physical"
        end
    else
        return SchoolColors[mask] or "FFFFFFFF", SchoolNames[mask] or "Physical"
    end
end

-------------------------------------------------------------------------------
-- 1. Animated Sliding Loot & Reward Toast
-------------------------------------------------------------------------------
function ACDM.ShowRewardPopup(gold, itemId, isMailed)
    -- Play Sound
    PlaySoundFile("Sound\\Interface\\LevelUp.ogg")

    local toast = ACDM.LootToastFrame
    if not toast then
        toast = CreateFrame("Frame", "ACDMLootToastFrame", UIParent)
        toast:SetSize(300, 85)
        toast:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        toast:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
        toast:SetBackdropBorderColor(0.85, 0.72, 0.15, 1.0) -- Gold Border
        toast:SetClampedToScreen(true)

        -- Title
        local title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", toast, "TOPLEFT", 12, -10)
        title:SetText("CHALLENGE REWARD")
        title:SetTextColor(1.0, 0.82, 0.0)
        title:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        toast.title = title

        -- Gold Gained
        local goldText = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        goldText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        goldText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        toast.goldText = goldText

        -- Item Icon Button
        local itemBtn = CreateFrame("Button", nil, toast)
        itemBtn:SetSize(36, 36)
        itemBtn:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -12, 10)
        
        local icon = itemBtn:CreateTexture(nil, "BACKGROUND")
        icon:SetAllPoints(itemBtn)
        itemBtn.icon = icon

        local border = itemBtn:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetSize(58, 58)
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
        toast.itemBtn = itemBtn

        -- Item Link Text
        local itemText = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        itemText:SetPoint("LEFT", toast, "LEFT", 12, 0)
        itemText:SetPoint("RIGHT", itemBtn, "LEFT", -8, 0)
        itemText:SetPoint("BOTTOM", toast, "BOTTOM", 0, 10)
        itemText:SetJustifyH("LEFT")
        itemText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        toast.itemText = itemText

        -- Mail text
        local mailText = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mailText:SetPoint("TOPLEFT", itemText, "BOTTOMLEFT", 0, -1)
        mailText:SetTextColor(1, 0.4, 0.4)
        mailText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        mailText:SetText("(Sent to Mailbox)")
        toast.mailText = mailText

        ACDM.LootToastFrame = toast
    end

    -- Setup contents
    if gold > 0 then
        toast.goldText:SetText("Gained: " .. FormatGold(gold))
        toast.goldText:Show()
    else
        toast.goldText:Hide()
    end

    if itemId > 0 then
        toast.itemBtn:Show()
        toast.itemText:Show()
        if isMailed then
            toast.mailText:Show()
        else
            toast.mailText:Hide()
        end

        local name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(itemId)
        if name then
            toast.itemText:SetText(link)
            toast.itemBtn.icon:SetTexture(texture)
            toast.itemBtn.itemLink = link
            local r, g, b = GetItemQualityColor(quality)
            toast.itemBtn.border:SetVertexColor(r, g, b)
            toast.itemBtn.border:Show()
        else
            toast.itemText:SetText("Retrieving Item Info...")
            toast.itemBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            toast.itemBtn.border:Hide()
            toast.itemBtn.itemLink = nil
        end
    else
        toast.itemBtn:Hide()
        toast.itemText:Hide()
        toast.mailText:Hide()
    end

    -- Animate sliding
    toast:Show()
    local startX = 350
    local targetX = -20
    local currentX = startX
    local elapsed = 0
    local state = "slide_in" -- slide_in, show, slide_out

    toast:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", currentX, 120)
    toast:SetScript("OnUpdate", function(self, el)
        elapsed = elapsed + el
        if state == "slide_in" then
            local dx = targetX - currentX
            currentX = currentX + dx * el * 10
            if math.abs(dx) < 1 then
                currentX = targetX
                state = "show"
                elapsed = 0
            end
            self:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", currentX, 120)
        elseif state == "show" then
            if itemId > 0 and not self.itemBtn.itemLink then
                local name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(itemId)
                if name then
                    self.itemText:SetText(link)
                    self.itemBtn.icon:SetTexture(texture)
                    self.itemBtn.itemLink = link
                    local r, g, b = GetItemQualityColor(quality)
                    self.itemBtn.border:SetVertexColor(r, g, b)
                    self.itemBtn.border:Show()
                end
            end
            if elapsed >= 5.0 then
                state = "slide_out"
                elapsed = 0
            end
        elseif state == "slide_out" then
            local dx = startX - currentX
            currentX = currentX + dx * el * 10
            if math.abs(dx) < 1 then
                self:Hide()
                self:SetScript("OnUpdate", nil)
            end
            self:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", currentX, 120)
        end
    end)
end

-------------------------------------------------------------------------------
-- 2. Floor Completion Grade Frame
-------------------------------------------------------------------------------
function ACDM.ShowFloorGradeFrame(grade, elapsed, parTime, deaths, efficiency)
    if grade == "S" then
        PlaySoundFile("Sound\\Dungeons\\Boss_Death_01.ogg")
    else
        PlaySoundFile("Sound\\Interface\\LevelUp.ogg")
    end

    local frame = ACDM.FloorGradeFrame
    if not frame then
        frame = CreateFrame("Frame", "ACDMFloorGradeFrame", UIParent)
        frame:SetSize(360, 240)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
        frame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        frame:SetBackdropColor(0.04, 0.04, 0.06, 0.96)
        frame:SetBackdropBorderColor(0.85, 0.72, 0.15, 1.0)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

        -- Title
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", frame, "TOP", 0, -16)
        title:SetText("FLOOR COMPLETED")
        title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        title:SetTextColor(1.0, 0.82, 0.0)

        -- Grade Label
        local gradeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        gradeLabel:SetPoint("TOP", title, "BOTTOM", 0, -10)
        gradeLabel:SetFont("Fonts\\FRIZQT__.TTF", 46, "OUTLINE")
        frame.gradeLabel = gradeLabel

        -- Breakdown Section
        local timeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        timeText:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -115)
        timeText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        frame.timeText = timeText

        local deathsText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        deathsText:SetPoint("TOPLEFT", timeText, "BOTTOMLEFT", 0, -12)
        deathsText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        frame.deathsText = deathsText

        local effText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        effText:SetPoint("TOPLEFT", deathsText, "BOTTOMLEFT", 0, -12)
        effText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        frame.effText = effText

        -- Close button
        local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        close:SetSize(100, 24)
        close:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
        close:SetText("Dismiss")
        close:SetScript("OnClick", function() frame:Hide() end)

        ACDM.FloorGradeFrame = frame
    end

    local gradeColor = "FFFFFFFF"
    local gradeText = grade
    if grade == "S" then
        gradeColor = "FFFFD700" -- sparkling gold
        gradeText = "S-Tier"
    elseif grade == "A" then
        gradeColor = "FFA335EE" -- purple
        gradeText = "A-Tier"
    elseif grade == "B" then
        gradeColor = "FF0070DD" -- blue
        gradeText = "B-Tier"
    elseif grade == "C" then
        gradeColor = "FF1EFF00" -- green
        gradeText = "C-Tier"
    elseif grade == "D" then
        gradeColor = "FF9D9D9D" -- gray
        gradeText = "D-Tier"
    end

    frame.gradeLabel:SetText("|c" .. gradeColor .. gradeText .. "|r")

    local timeColor = elapsed <= parTime and "|cFF1EFF00" or "|cFFFF3333"
    frame.timeText:SetText("Time Taken: " .. timeColor .. FormatTime(elapsed) .. "|r (Par: " .. FormatTime(parTime) .. ")")

    local deathColor = deaths == 0 and "|cFF1EFF00" or (deaths <= 2 and "|cFFFFCC00" or "|cFFFF3333")
    frame.deathsText:SetText("Total Deaths: " .. deathColor .. deaths .. "|r")

    local effColor = efficiency >= 3.0 and "|cFF1EFF00" or (efficiency >= 1.5 and "|cFFFFCC00" or "|cFFFF3333")
    frame.effText:SetText(string.format("Combat Efficiency: %s%.2fx|r (Damage Dealt vs Taken)", effColor, efficiency))

    frame:Show()
    frame:SetAlpha(0)
    
    local elapsedShow = 0
    frame:SetScript("OnUpdate", function(self, el)
        elapsedShow = elapsedShow + el
        if elapsedShow < 0.3 then
            self:SetAlpha(elapsedShow / 0.3)
        else
            self:SetAlpha(1.0)
        end

        if elapsedShow >= 15 then
            self:Hide()
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-------------------------------------------------------------------------------
-- 3. Death Recap Window & Chat Log
-------------------------------------------------------------------------------
function ACDM.ShowDeathRecap(dataStr)
    -- Parse hits payload
    local hits = {}
    local rawHits = { strsplit("|", dataStr) }
    for _, rawHit in ipairs(rawHits) do
        local source, dmg, spellId, school = strsplit(",", rawHit)
        if source and dmg then
            table.insert(hits, {
                source = source,
                damage = tonumber(dmg) or 0,
                spellId = tonumber(spellId) or 0,
                school = tonumber(school) or 1
            })
        end
    end

    if #hits == 0 then return end

    -- Print to chat
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Dungeon Master] Death Recap (Last " .. #hits .. " Damaging Hits):|r")
    for i, hit in ipairs(hits) do
        local schoolColor, schoolName = GetSchoolColorAndName(hit.school)
        local spellDesc = "Melee"
        if hit.spellId > 0 then
            local name = GetSpellInfo(hit.spellId)
            if name then
                spellDesc = "|cFF71C5EF" .. name .. "|r"
            else
                spellDesc = "Spell #" .. hit.spellId
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  [%d] |cFFFFFFFF%s|r hit you for |cFFFF3333%d|r damage using %s (|c%s%s|r)",
            i, hit.source, hit.damage, spellDesc, schoolColor, schoolName
        ))
    end

    -- Create/Show UI Frame
    local frame = ACDM.DeathRecapFrame
    if not frame then
        frame = CreateFrame("Frame", "ACDMDeathRecapFrame", UIParent)
        frame:SetSize(350, 220)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -100) -- Anchor below release frame
        frame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        frame:SetBackdropColor(0.06, 0.03, 0.03, 0.96) -- Blood red hint
        frame:SetBackdropBorderColor(0.8, 0.1, 0.1, 1.0) -- Red Border
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

        -- Title
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", frame, "TOP", 0, -14)
        title:SetText("DEATH RECAP")
        title:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        title:SetTextColor(0.9, 0.2, 0.2)

        -- Close Button
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

        -- Setup rows (max 3 hits)
        frame.rows = {}
        for i = 1, 3 do
            local row = CreateFrame("Button", nil, frame)
            row:SetSize(310, 42)
            row:SetPoint("TOP", frame, "TOP", 0, -45 - (i - 1) * 46)

            -- Row Background
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(row)
            bg:SetTexture(1, 1, 1, 0.03)
            row.bg = bg

            -- Spell Icon
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(28, 28)
            icon:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.icon = icon

            -- Source Name
            local sourceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            sourceText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 2)
            sourceText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
            sourceText:SetTextColor(1, 1, 1)
            row.sourceText = sourceText

            -- Spell Name & School
            local spellText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            spellText:SetPoint("BOTTOMLEFT", icon, "TOPRIGHT", 10, -14)
            spellText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            row.spellText = spellText

            -- Damage Amount
            local dmgText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            dmgText:SetPoint("RIGHT", row, "RIGHT", -10, 0)
            dmgText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
            dmgText:SetTextColor(1, 0.2, 0.2)
            row.dmgText = dmgText

            -- Hover tooltip handlers
            row:SetScript("OnEnter", function(self)
                self.bg:SetTexture(1, 1, 1, 0.08)
                if self.spellId and self.spellId > 0 then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink("spell:" .. self.spellId)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function(self)
                self.bg:SetTexture(1, 1, 1, 0.03)
                GameTooltip:Hide()
            end)

            table.insert(frame.rows, row)
        end

        ACDM.DeathRecapFrame = frame
    end

    -- Update row data
    for i = 1, 3 do
        local row = frame.rows[i]
        local hit = hits[i]
        if hit then
            row:Show()
            row.spellId = hit.spellId

            -- Icon
            local texture = "Interface\\Icons\\INV_Sword_04" -- fallback
            if hit.spellId > 0 then
                local t = GetSpellTexture(hit.spellId)
                if t then texture = t end
            end
            row.icon:SetTexture(texture)

            -- Source
            row.sourceText:SetText(hit.source)

            -- Spell name & school
            local schoolColor, schoolName = GetSchoolColorAndName(hit.school)
            local spellDesc = "Melee"
            if hit.spellId > 0 then
                local name = GetSpellInfo(hit.spellId)
                if name then spellDesc = name end
            end
            row.spellText:SetText(spellDesc .. " (|c" .. schoolColor .. schoolName .. "|r)")

            -- Damage
            row.dmgText:SetText("-" .. hit.damage)
        else
            row:Hide()
        end
    end

    frame:Show()
end

-- Auto-hide death recap on resurrection
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_UNGHOST")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if ACDM.DeathRecapFrame then
        ACDM.DeathRecapFrame:Hide()
    end
end)

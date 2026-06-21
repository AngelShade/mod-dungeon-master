ACDM.queryState = "idle"
ACMP.queryState = "idle"

-- Suppression filter
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(self, event, msg, ...)
    if msg and (msg:find("^DMDATA:") or msg:find("^MPDATA:")) then
        return true -- suppress
    end
end)

function ACDM.SendCommand(cmd)
    SendChatMessage(cmd, "SAY")
end

-- Hidden event receiver frame
local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_SYSTEM")
commFrame:SetScript("OnEvent", function(self, event, msg, ...)
    if not msg then return end
    
    if msg:find("^MPDATA:") then
        local payload = msg:sub(8) -- strip "MPDATA:"
        local colonIdx = payload:find(":")
        
        if not colonIdx then
            -- Handle END / OK commands
            if payload == "END" then
                ACMP.queryState = "idle"
                if ACMP.OnQueryComplete then
                    ACMP.OnQueryComplete()
                end
            elseif payload == "SELECT_OK" then
                if ACMP.OnSelectComplete then
                    ACMP.OnSelectComplete(true)
                end
            elseif payload == "RESET_OK" then
                if ACMP.OnResetComplete then
                    ACMP.OnResetComplete(true)
                end
            elseif payload == "ACQUIRE_OK" then
                if ACMP.OnAcquireComplete then
                    ACMP.OnAcquireComplete(true)
                end
            elseif payload == "ACQUIRE_FAIL" then
                if ACMP.OnAcquireComplete then
                    ACMP.OnAcquireComplete(false)
                end
            end
            return
        end
        
        local prefix = payload:sub(1, colonIdx - 1)
        local dataStr = payload:sub(colonIdx + 1)
        
        if prefix == "SELECT_FAIL" then
            if ACMP.OnSelectComplete then
                ACMP.OnSelectComplete(false, dataStr)
            end
        elseif prefix == "RESET_FAIL" then
            if ACMP.OnResetComplete then
                ACMP.OnResetComplete(false, dataStr)
            end
        elseif prefix == "LEVEL" then
            -- format: level|timeLimit|randomAffixCount|money
            local lvl, timeLim, affCnt, money = strsplit("|", dataStr)
            if lvl then
                local levelNum = tonumber(lvl)
                local found = nil
                for _, l in ipairs(ACMP.mythicLevels) do
                    if l.level == levelNum then
                        found = l
                        break
                    end
                end
                if not found then
                    found = {
                        level = levelNum,
                        timeLimit = tonumber(timeLim) or 0,
                        randomAffixCount = tonumber(affCnt) or 0,
                        reward = {
                            money = tonumber(money) or 0,
                            tokens = {}
                        },
                        affixes = {}
                    }
                    table.insert(ACMP.mythicLevels, found)
                    table.sort(ACMP.mythicLevels, function(a, b) return a.level < b.level end)
                else
                    found.timeLimit = tonumber(timeLim) or 0
                    found.randomAffixCount = tonumber(affCnt) or 0
                    found.reward.money = tonumber(money) or 0
                end
            end
        elseif prefix == "TOKEN" then
            -- format: level|itemEntry|count
            local lvl, itemEntry, count = strsplit("|", dataStr)
            if lvl then
                local levelNum = tonumber(lvl)
                for _, l in ipairs(ACMP.mythicLevels) do
                    if l.level == levelNum then
                        local tokenExists = false
                        local itemIdNum = tonumber(itemEntry)
                        for _, tok in ipairs(l.reward.tokens) do
                            if tok.itemId == itemIdNum then
                                tokenExists = true
                                tok.count = tonumber(count) or 1
                                break
                            end
                        end
                        if not tokenExists then
                            table.insert(l.reward.tokens, {
                                itemId = itemIdNum,
                                count = tonumber(count) or 1
                            })
                        end
                        break
                    end
                end
            end
        elseif prefix == "AFFIX" then
            -- format: level|affixName
            local lvl, affixName = strsplit("|", dataStr)
            if lvl then
                local levelNum = tonumber(lvl)
                for _, l in ipairs(ACMP.mythicLevels) do
                    if l.level == levelNum then
                        local affixExists = false
                        for _, aff in ipairs(l.affixes) do
                            if aff == affixName then
                                affixExists = true
                                break
                            end
                        end
                        if not affixExists then
                            table.insert(l.affixes, affixName)
                        end
                        break
                    end
                end
            end
        elseif prefix == "DNG" then
            -- format: mapId|mapName|minDifficulty
            local mapId, name, minDiff = strsplit("|", dataStr)
            if mapId then
                local mapNum = tonumber(mapId)
                local exists = false
                for _, d in ipairs(ACMP.mythicDungeons) do
                    if d.mapId == mapNum then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(ACMP.mythicDungeons, {
                        mapId = mapNum,
                        name = name,
                        minDifficulty = minDiff
                    })
                end
            end
        elseif prefix == "STATUS" then
            -- format: enabled|setLevel|leaderLevel|cooldownRemSec|hasKeystone
            local enabled, setLvl, leadLvl, cdRem, hasKey = strsplit("|", dataStr)
            ACMP.mythicStatus.enabled = tonumber(enabled) or 0
            ACMP.mythicStatus.setLevel = tonumber(setLvl) or 0
            ACMP.mythicStatus.leaderLevel = tonumber(leadLvl) or 0
            ACMP.mythicStatus.cooldownRemSec = tonumber(cdRem) or 0
            ACMP.mythicStatus.hasKeystone = tonumber(hasKey) or 0
            
            if ACMP.UpdateStatus then
                ACMP.UpdateStatus()
            end
        end
        return
    end

    if not msg:find("^DMDATA:") then return end
    
    local payload = msg:sub(8) -- strip "DMDATA:"
    local colonIdx = payload:find(":")
    
    if not colonIdx then
        -- Handle END marker commands
        if payload == "END" then
            ACDM.queryState = "idle"
            if ACDM.OnQueryComplete then
                ACDM.OnQueryComplete()
            end
        elseif payload == "STATS_END" then
            if ACDM.OnStatsComplete then
                ACDM.OnStatsComplete()
            end
        elseif payload == "BOARD_END" then
            if ACDM.OnBoardComplete then
                ACDM.OnBoardComplete()
            end
        elseif payload == "BEGIN_OK" then
            if ACDM.OnBeginChallenge then
                ACDM.OnBeginChallenge(true)
            end
        elseif payload == "RL_OK" then
            if ACDM.OnBeginRoguelike then
                ACDM.OnBeginRoguelike(true)
            end
        elseif payload == "RLQUIT_OK" then
            if ACDM.OnQuitRoguelike then
                ACDM.OnQuitRoguelike(true)
            end
        elseif payload == "RLADVANCE_OK" then
            if ACDM.OnAdvanceRoguelike then
                ACDM.OnAdvanceRoguelike(true)
            end
        elseif payload == "RESETBOSS_OK" then
            if ACDM.OnResetBossComplete then
                ACDM.OnResetBossComplete(true)
            end
        elseif payload == "RLBUYMASTERY_OK" then
            UIErrorsFrame:AddMessage("|cFF00FF00Mastery perk purchased successfully!|r", 0.1, 1.0, 0.1, 1.0, 5)
            PlaySoundFile("Sound\\Interface\\LevelUp.ogg")
            ACDM.RequestStats()
        end
        return
    end
    
    local prefix = payload:sub(1, colonIdx - 1)
    local dataStr = payload:sub(colonIdx + 1)
    
    if prefix == "RESETBOSS_FAIL" then
        if ACDM.OnResetBossComplete then
            ACDM.OnResetBossComplete(false, dataStr)
        end
    elseif prefix == "RLBUYMASTERY_FAIL" then
        UIErrorsFrame:AddMessage("|cFFFF0000Mastery Purchase Failed:|r " .. dataStr, 1.0, 0.1, 0.1, 1.0, 5)
    elseif prefix == "RUNINFO" then
        local elapsed, bossName, bx, by, bossResetCd, survivalBuffs, debuffs, debuffTimer, wipes, maxWipes, timeAlive, teleportRemaining, preparationTimer = strsplit(",", dataStr)
        ACDM.runInfo.elapsed = tonumber(elapsed) or 0
        ACDM.runInfo.bossName = bossName or "None"
        ACDM.runInfo.bossX = tonumber(bx) or 0
        ACDM.runInfo.bossY = tonumber(by) or 0
        ACDM.runInfo.bossResetCd = tonumber(bossResetCd) or 0
        ACDM.runInfo.survivalBuffs = tonumber(survivalBuffs) or 0
        ACDM.runInfo.debuffs = tonumber(debuffs) or 0
        ACDM.runInfo.debuffTimer = tonumber(debuffTimer) or 0
        ACDM.runInfo.wipes = tonumber(wipes) or 0
        ACDM.runInfo.maxWipes = tonumber(maxWipes) or 0
        ACDM.runInfo.timeAlive = tonumber(timeAlive) or 0
        ACDM.runInfo.teleportRemaining = tonumber(teleportRemaining) or 0
        ACDM.runInfo.preparationTimer = tonumber(preparationTimer) or 0
        ACDM.runInfo.lastUpdate = GetTime()
        if ACDM.OnRunInfoReceived then
            ACDM.OnRunInfoReceived()
        end
        if ACDM.UpdateTrackerUI then
            ACDM.UpdateTrackerUI()
        end
        if ACDM.UpdateGambitSelectionUI then
            ACDM.UpdateGambitSelectionUI()
        end
    elseif prefix == "BRANCH_OPTIONS" then
        ACDM.branchChoices = {}
        local options = { strsplit("|", dataStr) }
        for _, optStr in ipairs(options) do
            local dngIdx, themeId, risk = strsplit(",", optStr)
            if dngIdx then
                table.insert(ACDM.branchChoices, {
                    dungeonIndex = tonumber(dngIdx),
                    themeId = tonumber(themeId) or 0,
                    risk = tonumber(risk) or 0
                })
            end
        end
        if ACDM.ShowBranchingChoices then
            ACDM.ShowBranchingChoices()
        end
    elseif prefix == "BEGIN_FAIL" then
        if ACDM.OnBeginChallenge then
            ACDM.OnBeginChallenge(false, dataStr)
        end
    elseif prefix == "RL_FAIL" then
        if ACDM.OnBeginRoguelike then
            ACDM.OnBeginRoguelike(false, dataStr)
        end
    elseif prefix == "RLQUIT_FAIL" then
        if ACDM.OnQuitRoguelike then
            ACDM.OnQuitRoguelike(false, dataStr)
        end
    elseif prefix == "RLADVANCE_FAIL" then
        if ACDM.OnAdvanceRoguelike then
            ACDM.OnAdvanceRoguelike(false, dataStr)
        end
    elseif prefix == "RLGAMBIT_FAIL" then
        UIErrorsFrame:AddMessage("|cFFFF0000Gambit Error:|r " .. dataStr, 1.0, 0.1, 0.1, 1.0, 5)
    elseif prefix == "DIFF" then
        local id, name, minLvl, maxLvl, hpMult, dmgMult, rewardMult, mobCountMult = strsplit(",", dataStr)
        if id then
            local exists = false
            for _, diff in ipairs(ACDM.difficulties) do
                if diff.Id == tonumber(id) then
                    exists = true
                    diff.HealthMultiplier = tonumber(hpMult) or 1.0
                    diff.DamageMultiplier = tonumber(dmgMult) or 1.0
                    diff.RewardMultiplier = tonumber(rewardMult) or 1.0
                    diff.MobCountMultiplier = tonumber(mobCountMult) or 1.0
                    break
                end
            end
            if not exists then
                table.insert(ACDM.difficulties, {
                    Id = tonumber(id),
                    Name = name,
                    MinLevel = tonumber(minLvl),
                    MaxLevel = tonumber(maxLvl),
                    HealthMultiplier = tonumber(hpMult) or 1.0,
                    DamageMultiplier = tonumber(dmgMult) or 1.0,
                    RewardMultiplier = tonumber(rewardMult) or 1.0,
                    MobCountMultiplier = tonumber(mobCountMult) or 1.0
                })
            end
        end
    elseif prefix == "THEME" then
        local id, name = strsplit(",", dataStr)
        if id then
            local exists = false
            for _, theme in ipairs(ACDM.themes) do
                if theme.Id == tonumber(id) then
                    exists = true
                    break
                end
            end
            if not exists then
                table.insert(ACDM.themes, {
                    Id = tonumber(id),
                    Name = name
                })
            end
        end
    elseif prefix == "DNG" then
        local mapId, name, minLvl, maxLvl, fatigue, spawns = strsplit(",", dataStr)
        if mapId then
            local exists = false
            for _, dg in ipairs(ACDM.dungeons) do
                if dg.MapId == tonumber(mapId) then
                    exists = true
                    dg.Fatigue = tonumber(fatigue) or 100
                    dg.Spawns = tonumber(spawns) or 0
                    break
                end
            end
            if not exists then
                table.insert(ACDM.dungeons, {
                    MapId = tonumber(mapId),
                    Name = name,
                    MinLevel = tonumber(minLvl),
                    MaxLevel = tonumber(maxLvl),
                    Fatigue = tonumber(fatigue) or 100,
                    Spawns = tonumber(spawns) or 0
                })
            end
        end
    elseif prefix == "FLAGS" then
        local enabled, rlEnabled, cdRem, inSession, inRl, plyLvl, rlTier, rlFloors, sessionState, diffId, scaleParty, themeId, mapId, baseGold, goldPerMob, goldPerBoss, itemChance, rareChance, epicChance, vetoTokens, gambitTimeTrial, gambitGlassCannon, gambitPacifist = strsplit(",", dataStr)
        
        local wasInSession = ACDM.flags.inSession or 0
        local wasInRl = ACDM.flags.inRoguelike or 0
        local wasFloors = ACDM.flags.rlFloors or 0

        ACDM.flags.enabled = tonumber(enabled) or 0
        ACDM.flags.roguelikeEnabled = tonumber(rlEnabled) or 0
        ACDM.flags.cooldownRemSec = tonumber(cdRem) or 0
        ACDM.flags.inSession = tonumber(inSession) or 0
        ACDM.flags.inRoguelike = tonumber(inRl) or 0
        ACDM.flags.playerLevel = tonumber(plyLvl) or 1
        ACDM.flags.rlTier = tonumber(rlTier) or 0
        ACDM.flags.rlFloors = tonumber(rlFloors) or 0
        ACDM.flags.sessionState = tonumber(sessionState) or 0
        ACDM.flags.baseGold = tonumber(baseGold) or 50000
        ACDM.flags.goldPerMob = tonumber(goldPerMob) or 50
        ACDM.flags.goldPerBoss = tonumber(goldPerBoss) or 10000
        ACDM.flags.itemChance = tonumber(itemChance) or 80
        ACDM.flags.rareChance = tonumber(rareChance) or 40
        ACDM.flags.epicChance = tonumber(epicChance) or 15
        ACDM.flags.vetoTokens = tonumber(vetoTokens) or 0
        ACDM.flags.gambitTimeTrial = tonumber(gambitTimeTrial) or 0
        ACDM.flags.gambitGlassCannon = tonumber(gambitGlassCannon) or 0
        ACDM.flags.gambitPacifist = tonumber(gambitPacifist) or 0

        if not ACDM.isInitialFlags then
            if (wasInSession == 0 and ACDM.flags.inSession == 1 and ACDM.flags.inRoguelike == 0) or
               (wasInRl == 0 and ACDM.flags.inRoguelike == 1) or
               (ACDM.flags.inRoguelike == 1 and ACDM.flags.rlFloors == 0 and wasFloors > 0) then
                ACDM.runInfo.accumulatedGold = 0
                ACDM.runInfo.rewardedItems = {}
                ACDM.runInfo.trackerClosedByUser = false
                if ACChallengePanelDB then
                    ACChallengePanelDB.accumulatedGold = 0
                    ACChallengePanelDB.rewardedItems = {}
                end
            end
        else
            ACDM.isInitialFlags = false
        end

        if ACDM.flags.inSession == 1 or ACDM.flags.inRoguelike == 1 then
            if diffId and diffId ~= "" then ACDM.selection.diffId = tonumber(diffId) end
            if scaleParty and scaleParty ~= "" then ACDM.selection.scaleParty = (tonumber(scaleParty) == 1) end
            if themeId and themeId ~= "" then ACDM.selection.themeId = tonumber(themeId) end
            if mapId and mapId ~= "" then ACDM.selection.mapId = tonumber(mapId) end
        end

        if ACDM.UpdateStatus then ACDM.UpdateStatus() end
        if ACDM.RefreshChallengeFlow then ACDM.RefreshChallengeFlow() end
        if ACDM.RefreshRoguelikeFlow then ACDM.RefreshRoguelikeFlow() end
        if ACDM.RefreshActiveRun then ACDM.RefreshActiveRun() end
        if ACDM.UpdateTrackerUI then ACDM.UpdateTrackerUI() end

        if ACDM.flags.inRoguelike == 1 and ACDM.flags.sessionState == 1 then
            if ACDM.CheckAutoShowGambits then ACDM.CheckAutoShowGambits() end
            if ACDM.UpdateGambitSelectionUI then ACDM.UpdateGambitSelectionUI() end
        else
            if ACDM.HideGambitSelection then ACDM.HideGambitSelection() end
        end
    elseif prefix == "MASTERY" then
        local pts, mask = strsplit(",", dataStr)
        ACDM.masteryPoints = tonumber(pts) or 0
        ACDM.purchasedMask = tonumber(mask) or 0
        if ACDM.RefreshMasteryPanel then
            ACDM.RefreshMasteryPanel()
        end
    elseif prefix == "PBEST" then
        local mapId, diffId, time = strsplit(",", dataStr)
        if mapId then
            local mId = tonumber(mapId)
            local dId = tonumber(diffId)
            local clearTime = tonumber(time) or 0
            if not ACDM.personalBests[mId] then
                ACDM.personalBests[mId] = {}
            end
            ACDM.personalBests[mId][dId] = clearTime
        end
    elseif prefix == "NSTATS" then
        local total, comp, fail, mobs, bosses, deaths, fastest = strsplit(",", dataStr)
        ACDM.normalStats = {
            totalRuns = tonumber(total) or 0,
            completed = tonumber(comp) or 0,
            failed = tonumber(fail) or 0,
            mobsKilled = tonumber(mobs) or 0,
            bossesKilled = tonumber(bosses) or 0,
            deaths = tonumber(deaths) or 0,
            fastestClearSec = tonumber(fastest) or 0
        }
    elseif prefix == "RLSTATS" then
        local total, highT, mostFl, totFl, mobs, bosses, deaths, longest, mask = strsplit(",", dataStr)
        ACDM.roguelikeStats = {
            totalRuns = tonumber(total) or 0,
            highestTier = tonumber(highT) or 0,
            mostFloors = tonumber(mostFl) or 0,
            totalFloors = tonumber(totFl) or 0,
            mobsKilled = tonumber(mobs) or 0,
            bossesKilled = tonumber(bosses) or 0,
            deaths = tonumber(deaths) or 0,
            longestRunSec = tonumber(longest) or 0,
            knownAffixMask = tonumber(mask) or 0
        }
    elseif prefix == "BESTIARY_META" then
        local mapId, bossEnc, bossBeat, totalKills, runsStarted, runsCompleted = strsplit(",", dataStr)
        if mapId then
            ACDM.bestiaryMeta[tonumber(mapId)] = {
                bossEncountered = tonumber(bossEnc) == 1,
                bossBeaten = tonumber(bossBeat) == 1,
                totalKills = tonumber(totalKills) or 0,
                runsStarted = tonumber(runsStarted) or 0,
                runsCompleted = tonumber(runsCompleted) or 0
            }
        end
    elseif prefix == "BESTIARY" then
        local mapId, creatureType, killCount = strsplit(",", dataStr)
        if mapId then
            local mId = tonumber(mapId)
            if not ACDM.bestiary[mId] then
                ACDM.bestiary[mId] = {}
            end
            ACDM.bestiary[mId][tonumber(creatureType)] = tonumber(killCount) or 0
        end
    elseif prefix == "FAMILIARITY" then
        local affixId, encounters, resistancePct = strsplit(",", dataStr)
        if affixId then
            ACDM.familiarity[tonumber(affixId)] = {
                encounters = tonumber(encounters) or 0,
                resistancePct = tonumber(resistancePct) or 0.0
            }
        end
    elseif prefix == "CONFIG" then
        local t1, t2, t3, maxFam, revTier = strsplit(",", dataStr)
        ACDM.bestiaryT1Limit = tonumber(t1) or 50
        ACDM.bestiaryT2Limit = tonumber(t2) or 100
        ACDM.bestiaryT3Limit = tonumber(t3) or 250
        ACDM.maxFamiliarityPct = tonumber(maxFam) or 15.0
        ACDM.revealAffixTier = tonumber(revTier) or 5
    elseif prefix == "ACTIVE_AFFIXES" then
        ACDM.runInfo.activeAffixes = {}
        if dataStr and dataStr ~= "" then
            local affs = { strsplit(",", dataStr) }
            for _, affId in ipairs(affs) do
                local idNum = tonumber(affId)
                if idNum and idNum > 0 then
                    table.insert(ACDM.runInfo.activeAffixes, idNum)
                end
            end
        end
        if ACDM.RefreshActiveRun then ACDM.RefreshActiveRun() end
        if ACDM.UpdateTrackerUI then ACDM.UpdateTrackerUI() end
    elseif prefix == "REWARD" then
        local gold, itemId, isMailed = strsplit(",", dataStr)
        local goldNum = tonumber(gold) or 0
        local itemIdNum = tonumber(itemId) or 0
        local isMailedNum = tonumber(isMailed) or 0

        ACDM.runInfo.accumulatedGold = (ACDM.runInfo.accumulatedGold or 0) + goldNum
        if itemIdNum > 0 then
            table.insert(ACDM.runInfo.rewardedItems, { id = itemIdNum, mailed = (isMailedNum == 1) })
        end

        if ACChallengePanelDB then
            ACChallengePanelDB.accumulatedGold = ACDM.runInfo.accumulatedGold
            ACChallengePanelDB.rewardedItems = ACDM.runInfo.rewardedItems
        end

        if ACDM.ShowRewardPopup then
            ACDM.ShowRewardPopup(goldNum, itemIdNum, isMailedNum == 1)
        end

        if ACDM.UpdateTrackerUI then
            ACDM.UpdateTrackerUI()
        end
    elseif prefix == "GRADE" then
        local grade, elapsed, parTime, deaths, efficiency = strsplit(",", dataStr)
        if ACDM.ShowFloorGradeFrame then
            ACDM.ShowFloorGradeFrame(grade, tonumber(elapsed) or 0, tonumber(parTime) or 300, tonumber(deaths) or 0, tonumber(efficiency) or 1.0)
        end
    elseif prefix == "DEATHRECAP" then
        if ACDM.ShowDeathRecap then
            ACDM.ShowDeathRecap(dataStr)
        end
    elseif prefix == "NBOARD" or prefix == "RTBOARD" or prefix == "RFBOARD" then
        local fields = { strsplit(",", dataStr) }
        table.insert(ACDM.leaderboard, {
            type = prefix,
            rank = tonumber(fields[1]) or 0,
            charName = fields[2] or "",
            val1 = tonumber(fields[3]) or 0,
            val2 = tonumber(fields[4]) or 0,
            val3 = tonumber(fields[5]) or 0,
            val4 = tonumber(fields[6]) or 0,
            val5 = tonumber(fields[7]) or 0
        })
    end
end)

ACDM.bestiary = {}
ACDM.bestiaryMeta = {}
ACDM.familiarity = {}
ACDM.masteryPoints = 0
ACDM.purchasedMask = 0
ACDM.personalBests = {}

function ACDM.RequestQuery()
    ACDM.difficulties = {}
    ACDM.themes = {}
    ACDM.dungeons = {}
    ACDM.queryState = "querying"
    ACDM.SendCommand(".dm query")
end

function ACDM.RequestStats()
    ACDM.normalStats = {}
    ACDM.roguelikeStats = {}
    ACDM.bestiary = {}
    ACDM.bestiaryMeta = {}
    ACDM.familiarity = {}
    ACDM.masteryPoints = 0
    ACDM.purchasedMask = 0
    ACDM.personalBests = {}
    ACDM.SendCommand(".dm mystats")
end

function ACDM.RequestBoards(boardType)
    ACDM.leaderboard = {}
    ACDM.SendCommand(".dm boards " .. boardType)
end

function ACMP.RequestQuery()
    ACMP.mythicLevels = {}
    ACMP.mythicDungeons = {}
    ACMP.queryState = "querying"
    ACDM.SendCommand(".mythic query")
end

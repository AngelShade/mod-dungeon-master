/*
 * mod-dungeon-master — RoguelikeMgr.cpp
 * Roguelike run manager: multi-dungeon progression, buffs, affixes, transitions.
 */

#include "RoguelikeMgr.h"
#include "DungeonMasterMgr.h"
#include "DMConfig.h"
#include "Player.h"
#include "Group.h"
#include "Creature.h"
#include "ObjectAccessor.h"
#include "Chat.h"
#include "GameTime.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "SpellAuras.h"
#include "SpellAuraEffects.h"
#include <random>
#include <algorithm>
#include <cstdio>
#include <cstring>

namespace DungeonMaster
{

// RNG helpers (thread-local for safety)
static thread_local std::mt19937 tRng{ std::random_device{}() };

template<typename T>
static T RandInt(T lo, T hi)
{
    return std::uniform_int_distribution<T>(lo, hi)(tRng);
}

// Singleton
RoguelikeMgr::RoguelikeMgr()  = default;
RoguelikeMgr::~RoguelikeMgr() = default;

RoguelikeMgr* RoguelikeMgr::Instance()
{
    static RoguelikeMgr inst;
    return &inst;
}

// Initialization
void RoguelikeMgr::Initialize()
{
    BuildAffixPool();
    LoadAllRoguelikePlayerStats();
    LOG_INFO("module", "RoguelikeMgr: Initialized — {} affix definitions, {} buff pool entries.",
        _affixDefs.size(), sDMConfig->GetRoguelikeBuffPool().size());
}

void RoguelikeMgr::BuildAffixPool()
{
    _affixDefs.clear();

    // Fortified — trash mobs are significantly harder
    {
        AffixDef a;
        a.Id           = AFFIX_FORTIFIED;
        a.Name         = "Fortified";
        a.TrashHpMult  = 1.30f;
        a.TrashDmgMult = 1.15f;
        a.BossHpMult   = 1.0f;
        a.BossDmgMult  = 1.0f;
        _affixDefs.push_back(a);
    }
    // Tyrannical — bosses are significantly harder
    {
        AffixDef a;
        a.Id           = AFFIX_TYRANNICAL;
        a.Name         = "Tyrannical";
        a.TrashHpMult  = 1.0f;
        a.TrashDmgMult = 1.0f;
        a.BossHpMult   = 1.40f;
        a.BossDmgMult  = 1.20f;
        _affixDefs.push_back(a);
    }
    // Raging — everything hits harder
    {
        AffixDef a;
        a.Id           = AFFIX_RAGING;
        a.Name         = "Raging";
        a.TrashHpMult  = 1.0f;
        a.TrashDmgMult = 1.25f;
        a.BossHpMult   = 1.0f;
        a.BossDmgMult  = 1.25f;
        _affixDefs.push_back(a);
    }
    // Bolstering — everything has more health
    {
        AffixDef a;
        a.Id           = AFFIX_BOLSTERING;
        a.Name         = "Bolstering";
        a.TrashHpMult  = 1.20f;
        a.TrashDmgMult = 1.0f;
        a.BossHpMult   = 1.20f;
        a.BossDmgMult  = 1.0f;
        _affixDefs.push_back(a);
    }
    // Savage — more elites, elites are nastier
    {
        AffixDef a;
        a.Id              = AFFIX_SAVAGE;
        a.Name            = "Savage";
        a.TrashHpMult     = 1.0f;
        a.TrashDmgMult    = 1.10f;
        a.BossHpMult      = 1.0f;
        a.BossDmgMult     = 1.0f;
        a.EliteChanceMult = 2.0f;
        _affixDefs.push_back(a);
    }
}

// RUN LIFECYCLE

bool RoguelikeMgr::StartRun(Player* leader, uint32 difficultyId, uint32 themeId, bool scaleToParty)
{
    if (!leader)
        return false;

    if (!sDMConfig->IsRoguelikeEnabled())
    {
        ChatHandler(leader->GetSession()).SendSysMessage(
            "|cFFFF0000[Roguelike]|r Roguelike mode is disabled.");
        return false;
    }

    // Check: player not already in a run
    if (IsPlayerInRun(leader->GetGUID()))
    {
        ChatHandler(leader->GetSession()).SendSysMessage(
            "|cFFFF0000[Roguelike]|r You are already in a roguelike run!");
        return false;
    }

    // Check: player not in a DM session
    if (sDungeonMasterMgr->GetSessionByPlayer(leader->GetGUID()))
    {
        ChatHandler(leader->GetSession()).SendSysMessage(
            "|cFFFF0000[Roguelike]|r You are in an active dungeon challenge!");
        return false;
    }

    std::vector<Player*> members;
    if (Group* g = leader->GetGroup())
    {
        for (GroupReference* ref = g->GetFirstMember(); ref; ref = ref->next())
        {
            if (Player* m = ref->GetSource())
                members.push_back(m);
        }
    }
    else
    {
        members.push_back(leader);
    }

    // Check: cooldown
    for (Player* member : members)
    {
        if (sDungeonMasterMgr->IsOnCooldown(member->GetGUID()))
        {
            uint32 rem = sDungeonMasterMgr->GetRemainingCooldown(member->GetGUID());
            char buf[256];
            snprintf(buf, sizeof(buf),
                "|cFFFF0000[Roguelike]|r Player %s must wait %u min %u sec before starting.",
                member->GetName().c_str(), rem / 60, rem % 60);
            ChatHandler(leader->GetSession()).SendSysMessage(buf);
            return false;
        }
    }

    // Check: can create a session
    if (!sDungeonMasterMgr->CanCreateNewSession())
    {
        ChatHandler(leader->GetSession()).SendSysMessage(
            "|cFFFF0000[Roguelike]|r Too many active challenges. Try again later.");
        return false;
    }

    // Use the difficulty selected by the player (or fall back to first available)
    const DifficultyTier* diff = sDMConfig->GetDifficulty(difficultyId);
    uint32 finalDifficultyId = difficultyId;
    if (!diff)
    {
        const auto& diffs = sDMConfig->GetDifficulties();
        finalDifficultyId = diffs.empty() ? 1 : diffs[0].Id;
        diff = sDMConfig->GetDifficulty(finalDifficultyId);
    }

    if (diff)
    {
        for (Player* member : members)
        {
            if (!diff->IsValidForLevel(member->GetLevel()))
            {
                char buf[256];
                snprintf(buf, sizeof(buf),
                    "|cFFFF0000[Roguelike]|r Player %s does not meet the level requirement (%u) for this difficulty.",
                    member->GetName().c_str(), diff->MinLevel);
                ChatHandler(leader->GetSession()).SendSysMessage(buf);
                return false;
            }
        }
    }

    // Build the run
    RoguelikeRun run;
    {
        std::lock_guard<std::mutex> lock(_runMutex);
        run.RunId          = _nextRunId++;
    }
    run.LeaderGuid     = leader->GetGUID();
    run.State          = RoguelikeRunState::Active;
    run.ThemeId        = themeId;
    run.ScaleToParty   = scaleToParty;
    run.CurrentTier    = 1;
    run.RunStartTime   = GameTime::GetGameTime().count();
    run.BaseDifficultyId = finalDifficultyId;

    // Store original positions for ALL party members
    RoguelikePlayerData ld;
    ld.PlayerGuid       = leader->GetGUID();
    ld.OriginalMapId    = leader->GetMapId();
    ld.OriginalPosition = { leader->GetPositionX(), leader->GetPositionY(),
                            leader->GetPositionZ(), leader->GetOrientation() };
    run.Players.push_back(ld);

    if (Group* g = leader->GetGroup())
    {
        for (GroupReference* ref = g->GetFirstMember(); ref; ref = ref->next())
        {
            Player* m = ref->GetSource();
            if (m && m != leader && m->IsInWorld())
            {
                // Check: group member not in another run
                if (IsPlayerInRun(m->GetGUID()))
                    continue;
                if (sDungeonMasterMgr->GetSessionByPlayer(m->GetGUID()))
                    continue;

                RoguelikePlayerData md;
                md.PlayerGuid       = m->GetGUID();
                md.OriginalMapId    = m->GetMapId();
                md.OriginalPosition = { m->GetPositionX(), m->GetPositionY(),
                                        m->GetPositionZ(), m->GetOrientation() };
                run.Players.push_back(md);
            }
        }
    }

    // Clear cooldowns for all party members so they can enter
    for (const auto& pd : run.Players)
        sDungeonMasterMgr->ClearCooldown(pd.PlayerGuid);

    // No buff on tier 1 — first +10% earned after clearing floor 1
    run.BuffStacks = 0;
    run.Wipes = 0;

    // Grace period for async teleport
    run.TransitionStartTime = GameTime::GetGameTime().count();

    // Select affixes for tier 1 (may be none if affix start tier > 1)
    SelectAffixesForTier(run);

    // Generate branching options for the first floor
    GenerateBranchChoices(run);
    if (run.BranchChoices.empty())
    {
        ChatHandler(leader->GetSession()).SendSysMessage(
            "|cFFFF0000[Roguelike]|r No dungeons available for your level!");
        return false;
    }

    // Register the run
    {
        std::lock_guard<std::mutex> lock(_runMutex);
        _activeRuns[run.RunId] = run;
        for (const auto& pd : run.Players)
            _playerToRun[pd.PlayerGuid] = run.RunId;
    }

    // Announce
    const Theme* theme = sDMConfig->GetTheme(themeId);
    char buf[256];
    snprintf(buf, sizeof(buf),
        "|cFF00FFFF[Roguelike]|r |cFFFFD700%s|r started a Roguelike Run! "
        "Theme: |cFF00FF00%s|r — How far can you go?",
        leader->GetName().c_str(),
        theme ? theme->Name.c_str() : "Random");

    for (const auto& pd : run.Players)
        if (Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid))
            ChatHandler(p->GetSession()).SendSysMessage(buf);

    // Send the first floor branching choices immediately!
    SendBranchChoicesToParty(run);

    LOG_INFO("module", "RoguelikeMgr: Run {} started (awaiting branch choice) — leader {}, party {}, theme {}",
        run.RunId, leader->GetName(), run.Players.size(),
        theme ? theme->Name.c_str() : "Random");

    return true;
}


void RoguelikeMgr::FinalizeCompletedFloor(uint32 runId)
{
    RoguelikeRun* run = nullptr;
    {
        std::lock_guard<std::mutex> lock(_runMutex);
        auto it = _activeRuns.find(runId);
        if (it == _activeRuns.end()) return;
        run = &it->second;
    }

    uint32 sessionId = run->CurrentSessionId;
    if (sessionId == 0)
        return;

    // Copy data before cleanup invalidates the session
    uint32 sessionMobsKilled   = 0;
    uint32 sessionBossesKilled = 0;
    uint32 sessionDeaths       = 0;
    uint32 sessionDungeonIndex = 0;
    {
        Session* session = sDungeonMasterMgr->GetSession(sessionId);
        if (session)
        {
            if (session->State != SessionState::Completed)
                return;

            sessionMobsKilled   = session->MobsKilled;
            sessionBossesKilled = session->BossesKilled;
            sessionDungeonIndex = session->DungeonIndex;
            for (const auto& pd : session->Players)
                sessionDeaths += pd.Deaths;

            run->SurvivalBuffStacks = session->SurvivalBuffStacks;
            run->WipeDebuffStacks   = session->WipeDebuffStacks;
            run->WipeDebuffTimer    = session->WipeDebuffTimer;

            // Distribute per-floor rewards while session pointer is still valid
            sDungeonMasterMgr->DistributeRewards(session);
        }
        else
        {
            return;
        }
    }

    // Accumulate stats
    run->TotalMobsKilled   += sessionMobsKilled;
    run->TotalBossesKilled += sessionBossesKilled;
    run->TotalDeaths       += sessionDeaths;

    ++run->DungeonsCleared;
    run->PreviousDungeonIndex = sessionDungeonIndex;

    // Clean up the DM session (no teleport, no cooldown)
    sDungeonMasterMgr->CleanupRoguelikeSession(sessionId, true);

    // Remove old session mapping
    {
        std::lock_guard<std::mutex> lock(_runMutex);
        _sessionToRun.erase(sessionId);
    }

    run->CurrentSessionId = 0;
}


void RoguelikeMgr::OnDungeonCompleted(uint32 runId, uint32 sessionId)
{
    RoguelikeRun* run = nullptr;
    {
        std::lock_guard<std::mutex> lock(_runMutex);
        auto it = _activeRuns.find(runId);
        if (it == _activeRuns.end()) return;
        run = &it->second;
    }

    if (run->CurrentSessionId != sessionId)
    {
        LOG_WARN("module", "RoguelikeMgr: OnDungeonCompleted — session {} != current {}",
            sessionId, run->CurrentSessionId);
        return;
    }

    // Copy data before cleanup invalidates the session
    uint32 sessionMobsKilled   = 0;
    uint32 sessionBossesKilled = 0;
    uint32 sessionDeaths       = 0;
    uint32 sessionMapId        = 0;
    uint32 sessionDungeonIndex = 0;
    {
        Session* session = sDungeonMasterMgr->GetSession(sessionId);
        if (session)
        {
            sessionMobsKilled   = session->MobsKilled;
            sessionBossesKilled = session->BossesKilled;
            sessionMapId        = session->MapId;
            sessionDungeonIndex = session->DungeonIndex;
            for (const auto& pd : session->Players)
                sessionDeaths += pd.Deaths;

            run->SurvivalBuffStacks = session->SurvivalBuffStacks;
            run->WipeDebuffStacks   = session->WipeDebuffStacks;
            run->WipeDebuffTimer    = session->WipeDebuffTimer;

            // Distribute per-floor rewards while session pointer is still valid
            sDungeonMasterMgr->DistributeRewards(session);
        }
    }

    // Accumulate stats
    run->TotalMobsKilled   += sessionMobsKilled;
    run->TotalBossesKilled += sessionBossesKilled;
    run->TotalDeaths       += sessionDeaths;

    // Increment runs_completed in bestiary meta
    if (sDMConfig->IsBestiaryEnabled())
    {
        for (const auto& pd : run->Players)
        {
            uint32 guidLow = pd.PlayerGuid.GetCounter();
            sDungeonMasterMgr->IncrementBestiaryMetaRunsCompleted(guidLow, sessionMapId);
            sDungeonMasterMgr->SavePlayerDungeonData(guidLow);
        }
    }

    // Phase 1: Increment familiarity encounters and update known affix mask
    for (const auto& pd : run->Players)
    {
        uint32 guidLow = pd.PlayerGuid.GetCounter();
        for (RoguelikeAffix afxId : run->ActiveAffixes)
        {
            sDungeonMasterMgr->IncrementAffixFamiliarityEncounters(guidLow, afxId);
            
            // Update known affix mask in RoguelikePlayerStats
            {
                std::lock_guard<std::mutex> lock(_rlStatsMutex);
                auto& ps = _roguelikeStats[guidLow];
                ps.KnownAffixMask |= (1 << afxId);
            }
        }

        // Update TotalFloorsCleared and handle Veto Token earning
        {
            std::lock_guard<std::mutex> lock(_rlStatsMutex);
            auto& ps = _roguelikeStats[guidLow];
            ps.TotalFloorsCleared++;

            if (run->CurrentTier >= sDMConfig->GetRoguelikeVetoUnlockTier())
            {
                if (ps.TotalFloorsCleared % sDMConfig->GetRoguelikeFloorsPerVeto() == 0)
                {
                    if (ps.VetoTokens < sDMConfig->GetRoguelikeMaxVetoTokens())
                    {
                        ps.VetoTokens++;
                        Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid);
                        if (p && p->GetSession())
                        {
                            char announceBuf[256];
                            snprintf(announceBuf, sizeof(announceBuf),
                                "|cFF00FFFF[Roguelike]|r You earned a |cFFFFD700Veto Token|r! Remaining: |cFFFFFFFF%u/%u|r",
                                ps.VetoTokens, sDMConfig->GetRoguelikeMaxVetoTokens());
                            ChatHandler(p->GetSession()).SendSysMessage(announceBuf);
                        }
                    }
                }
            }
        }

        // Save the bestiary/familiarity data
        sDungeonMasterMgr->SavePlayerDungeonData(guidLow);

        // Save RoguelikePlayerStats to DB immediately
        RoguelikePlayerStats ps;
        {
            std::lock_guard<std::mutex> lock(_rlStatsMutex);
            ps = _roguelikeStats[guidLow];
        }
        char query[512];
        snprintf(query, sizeof(query),
            "REPLACE INTO dm_roguelike_player_stats "
            "(guid, total_runs, highest_tier, most_floors_cleared, "
            "total_floors_cleared, total_mobs_killed, total_bosses_killed, "
            "total_deaths, longest_run_time, known_affix_mask, veto_tokens) "
            "VALUES (%u, %u, %u, %u, %u, %u, %u, %u, %u, %u, %u)",
            guidLow, ps.TotalRuns, ps.HighestTier, ps.MostFloorsCleared,
            ps.TotalFloorsCleared, ps.TotalMobsKilled, ps.TotalBossesKilled,
            ps.TotalDeaths, ps.LongestRunTime, ps.KnownAffixMask, ps.VetoTokens);
        CharacterDatabase.Execute(query);
    }

    ++run->DungeonsCleared;
    run->PreviousDungeonIndex = sessionDungeonIndex;

    // Clean up the DM session (no teleport, no cooldown)
    sDungeonMasterMgr->CleanupRoguelikeSession(sessionId, true);

    // Remove old session mapping
    {
        std::lock_guard<std::mutex> lock(_runMutex);
        _sessionToRun.erase(sessionId);
    }

    // Increment tier
    ++run->CurrentTier;

    // Select new affixes
    SelectAffixesForTier(*run);

    // Apply a new buff stack (+10% all stats)
    IncrementBuffStacks(run->RunId);

    // Announce progress
    char buf[512];
    snprintf(buf, sizeof(buf),
        "|cFF00FFFF[Roguelike]|r |cFFFFD700Floor %u cleared!|r "
        "Advancing to |cFFFF0000Tier %u|r...",
        run->DungeonsCleared, run->CurrentTier);

    // Append active affixes
    std::string affixStr;
    for (RoguelikeAffix afxId : run->ActiveAffixes)
    {
        for (const auto& def : _affixDefs)
        {
            if (def.Id == afxId)
            {
                if (!affixStr.empty()) affixStr += ", ";
                affixStr += "|cFFFF8800" + def.Name + "|r";
                break;
            }
        }
    }
    if (!affixStr.empty())
    {
        size_t len = strlen(buf);
        snprintf(buf + len, sizeof(buf) - len, " Affixes: %s", affixStr.c_str());
    }

    AnnounceToRun(*run, buf);

    // Grace period for abandoned detection
    run->TransitionStartTime = GameTime::GetGameTime().count();

    // Generate branching options and wait for leader selection
    GenerateBranchChoices(*run);
    if (run->BranchChoices.empty())
    {
        // Failed to find next dungeons — end the run gracefully
        char failBuf[256];
        snprintf(failBuf, sizeof(failBuf),
            "|cFFFF0000[Roguelike]|r No more dungeons available! "
            "Run ended at |cFFFFD700Tier %u|r after |cFFFFFFFF%u|r floors.",
            run->CurrentTier, run->DungeonsCleared);
        AnnounceToRun(*run, failBuf);
        EndRun(run->RunId, true);
    }
    else
    {
        SendBranchChoicesToParty(*run);
    }
}

// Handle party wipe
void RoguelikeMgr::OnPartyWipe(uint32 runId)
{
    RoguelikeRun* run = nullptr;
    {
        std::lock_guard<std::mutex> lock(_runMutex);
        auto it = _activeRuns.find(runId);
        if (it == _activeRuns.end()) return;
        run = &it->second;
    }

    // Accumulate stats from the final session
    Session* session = sDungeonMasterMgr->GetSession(run->CurrentSessionId);
    if (session)
    {
        run->TotalMobsKilled   += session->MobsKilled;
        run->TotalBossesKilled += session->BossesKilled;
        for (const auto& pd : session->Players)
            run->TotalDeaths += pd.Deaths;
    }

    // Announce the wipe
    uint32 duration = static_cast<uint32>(
        GameTime::GetGameTime().count() - run->RunStartTime);
    uint32 dm = duration / 60, ds = duration % 60;

    char buf[512];
    snprintf(buf, sizeof(buf),
        "|cFFFF0000[Roguelike]|r |cFFFF4444TOTAL PARTY WIPE!|r "
        "Your run has ended.\n"
        "|cFF00FFFF[Roguelike]|r Final Results:\n"
        "  Tier Reached: |cFFFFD700%u|r\n"
        "  Floors Cleared: |cFFFFFFFF%u|r\n"
        "  Mobs Killed: |cFFFFFFFF%u|r\n"
        "  Bosses Slain: |cFFFFFFFF%u|r\n"
        "  Total Deaths: |cFFFF0000%u|r\n"
        "  Run Duration: |cFF00FFFF%um %02us|r",
        run->CurrentTier, run->DungeonsCleared,
        run->TotalMobsKilled, run->TotalBossesKilled,
        run->TotalDeaths, dm, ds);

    // Resurrect dead players
    for (const auto& pd : run->Players)
    {
        Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid);
        if (!p || !p->IsInWorld()) continue;
        p->RemoveFlag(PLAYER_FIELD_BYTES, PLAYER_FIELD_BYTE_NO_RELEASE_WINDOW);
        if (!p->IsAlive())
        {
            p->ResurrectPlayer(1.0f);
            p->SpawnCorpseBones();
        }
    }

    AnnounceToRun(*run, buf);

    // Save leaderboard
    SaveRoguelikeLeaderboard(*run);

    // Remove all buff stacks (skip mid-teleport players)
    for (const auto& pd : run->Players)
    {
        Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid);
        if (p && p->IsInWorld())
            RemoveBuffStacks(p, run->RunId);
    }

    bool entered = (run->DungeonsCleared > 0);
    if (!entered && run->CurrentSessionId != 0)
    {
        if (Session* s = sDungeonMasterMgr->GetSession(run->CurrentSessionId))
        {
            if (s->InstanceId != 0)
                entered = true;
        }
    }

    // Clean up the DM session
    if (run->CurrentSessionId != 0)
        sDungeonMasterMgr->CleanupRoguelikeSession(run->CurrentSessionId, false);

    // Teleport everyone back to their original positions
    TeleportRunPlayersOut(*run);

    // Set cooldowns
    if (entered)
    {
        for (const auto& pd : run->Players)
            sDungeonMasterMgr->SetCooldown(pd.PlayerGuid);
    }

    // Save before erase invalidates the pointer
    uint32 savedTier    = run->CurrentTier;
    uint32 savedCleared = run->DungeonsCleared;
    uint32 savedSessId  = run->CurrentSessionId;

    std::vector<ObjectGuid> playerGuids;
    for (const auto& pd : run->Players)
        playerGuids.push_back(pd.PlayerGuid);

    // Clean up run
    {
        std::lock_guard<std::mutex> lock(_runMutex);
        _sessionToRun.erase(savedSessId);
        for (const auto& pd : run->Players)
            _playerToRun.erase(pd.PlayerGuid);
        _activeRuns.erase(runId);
    }

    sDungeonMasterMgr->SendInactiveUpdateToPlayers(playerGuids);

    LOG_INFO("module", "RoguelikeMgr: Run {} ended (wipe) — tier {}, {} floors cleared.",
        runId, savedTier, savedCleared);
}

// End run gracefully (voluntary exit or no dungeons left)
void RoguelikeMgr::EndRun(uint32 runId, bool announceResults)
{
    RoguelikeRun* run = nullptr;
    {
        std::lock_guard<std::mutex> lock(_runMutex);
        auto it = _activeRuns.find(runId);
        if (it == _activeRuns.end()) return;
        run = &it->second;
    }

    if (announceResults)
    {
        uint32 duration = static_cast<uint32>(
            GameTime::GetGameTime().count() - run->RunStartTime);
        uint32 dm = duration / 60, ds = duration % 60;

        char buf[512];
        snprintf(buf, sizeof(buf),
            "|cFF00FFFF[Roguelike]|r Run complete!\n"
            "  Tier Reached: |cFFFFD700%u|r\n"
            "  Floors Cleared: |cFFFFFFFF%u|r\n"
            "  Mobs Killed: |cFFFFFFFF%u|r\n"
            "  Bosses Slain: |cFFFFFFFF%u|r\n"
            "  Run Duration: |cFF00FFFF%um %02us|r",
            run->CurrentTier, run->DungeonsCleared,
            run->TotalMobsKilled, run->TotalBossesKilled,
            dm, ds);
        AnnounceToRun(*run, buf);

        SaveRoguelikeLeaderboard(*run);
    }

    // Resurrect all dead players (skip mid-teleport players)
    for (const auto& pd : run->Players)
    {
        Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid);
        if (!p || !p->IsInWorld()) continue;
        p->RemoveFlag(PLAYER_FIELD_BYTES, PLAYER_FIELD_BYTE_NO_RELEASE_WINDOW);
        if (!p->IsAlive())
        {
            p->ResurrectPlayer(1.0f);
            p->SpawnCorpseBones();
        }
    }

    // Remove buff stacks (skip mid-teleport players)
    for (const auto& pd : run->Players)
        if (Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid))
            if (p->IsInWorld())
                RemoveBuffStacks(p, run->RunId);

    // Distribute roguelike rewards (scaled by tier)
    if (run->DungeonsCleared > 0)
    {
        // Compute effective level from the leader (or first available player)
        uint8 effectiveLevel = 1;
        for (const auto& pd : run->Players)
        {
            Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid);
            if (p) { effectiveLevel = p->GetLevel(); break; }
        }

        std::vector<ObjectGuid> guids;
        for (const auto& pd : run->Players)
            guids.push_back(pd.PlayerGuid);

        sDungeonMasterMgr->DistributeRoguelikeRewards(
            run->CurrentTier, effectiveLevel, guids);
    }

    bool entered = (run->DungeonsCleared > 0);
    if (!entered && run->CurrentSessionId != 0)
    {
        if (Session* s = sDungeonMasterMgr->GetSession(run->CurrentSessionId))
        {
            if (s->InstanceId != 0)
                entered = true;
        }
    }

    // Clean up DM session if one is active
    if (run->CurrentSessionId != 0)
        sDungeonMasterMgr->CleanupRoguelikeSession(run->CurrentSessionId, false);

    // Teleport out
    TeleportRunPlayersOut(*run);

    // Set cooldowns
    if (entered)
    {
        for (const auto& pd : run->Players)
            sDungeonMasterMgr->SetCooldown(pd.PlayerGuid);
    }

    std::vector<ObjectGuid> playerGuids;
    for (const auto& pd : run->Players)
        playerGuids.push_back(pd.PlayerGuid);

    // Save before erase invalidates the pointer
    uint32 savedTier    = run->CurrentTier;
    uint32 savedCleared = run->DungeonsCleared;
    uint32 savedSessId  = run->CurrentSessionId;

    // Erase run
    {
        std::lock_guard<std::mutex> lock(_runMutex);
        _sessionToRun.erase(savedSessId);
        for (const auto& pd : run->Players)
            _playerToRun.erase(pd.PlayerGuid);
        _activeRuns.erase(runId);
    }

    sDungeonMasterMgr->SendInactiveUpdateToPlayers(playerGuids);

    LOG_INFO("module", "RoguelikeMgr: Run {} ended (graceful) — tier {}, {} floors.",
        runId, savedTier, savedCleared);
}

void RoguelikeMgr::AbandonRun(uint32 runId)
{
    EndRun(runId, true);
}

void RoguelikeMgr::QuitRun(ObjectGuid playerGuid)
{
    uint32 runId = 0;
    {
        std::lock_guard<std::mutex> lock(_runMutex);
        auto it = _playerToRun.find(playerGuid);
        if (it != _playerToRun.end())
            runId = it->second;
    }
    if (runId != 0)
        AbandonRun(runId);
}

// QUERIES

RoguelikeRun* RoguelikeMgr::GetRun(uint32 runId)
{
    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _activeRuns.find(runId);
    return it != _activeRuns.end() ? &it->second : nullptr;
}

RoguelikeRun* RoguelikeMgr::GetRunBySession(uint32 sessionId)
{
    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _sessionToRun.find(sessionId);
    if (it != _sessionToRun.end())
    {
        auto rit = _activeRuns.find(it->second);
        return rit != _activeRuns.end() ? &rit->second : nullptr;
    }
    return nullptr;
}

RoguelikeRun* RoguelikeMgr::GetRunByPlayer(ObjectGuid guid)
{
    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _playerToRun.find(guid);
    if (it != _playerToRun.end())
    {
        auto rit = _activeRuns.find(it->second);
        return rit != _activeRuns.end() ? &rit->second : nullptr;
    }
    return nullptr;
}

uint32 RoguelikeMgr::GetRunIdBySession(uint32 sessionId) const
{
    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _sessionToRun.find(sessionId);
    return it != _sessionToRun.end() ? it->second : 0;
}

bool RoguelikeMgr::IsPlayerInRun(ObjectGuid guid) const
{
    std::lock_guard<std::mutex> lock(_runMutex);
    return _playerToRun.count(guid) > 0;
}

uint32 RoguelikeMgr::GetActiveRunCount() const
{
    std::lock_guard<std::mutex> lock(_runMutex);
    return static_cast<uint32>(_activeRuns.size());
}

// Scaling (called from PopulateDungeon)

float RoguelikeMgr::GetTierHealthMultiplier(uint32 runId) const
{
    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _activeRuns.find(runId);
    if (it == _activeRuns.end()) return 1.0f;

    uint32 tier = it->second.CurrentTier;
    if (tier <= 1) return 1.0f;

    float baseScale = sDMConfig->GetRoguelikeHpScaling();
    uint32 expThresh = sDMConfig->GetRoguelikeExpThreshold();
    float  expFactor = sDMConfig->GetRoguelikeExpFactor();

    if (tier <= expThresh)
        return 1.0f + (tier - 1) * baseScale;

    // Exponential scaling past threshold
    float linearPart = (expThresh - 1) * baseScale;
    float expPart    = 0.0f;
    for (uint32 t = expThresh; t < tier; ++t)
        expPart += baseScale * std::pow(expFactor, static_cast<float>(t - expThresh + 1));

    return 1.0f + linearPart + expPart;
}

float RoguelikeMgr::GetTierDamageMultiplier(uint32 runId) const
{
    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _activeRuns.find(runId);
    if (it == _activeRuns.end()) return 1.0f;

    uint32 tier = it->second.CurrentTier;
    if (tier <= 1) return 1.0f;

    float baseScale = sDMConfig->GetRoguelikeDmgScaling();
    uint32 expThresh = sDMConfig->GetRoguelikeExpThreshold();
    float  expFactor = sDMConfig->GetRoguelikeExpFactor();

    if (tier <= expThresh)
        return 1.0f + (tier - 1) * baseScale;

    float linearPart = (expThresh - 1) * baseScale;
    float expPart    = 0.0f;
    for (uint32 t = expThresh; t < tier; ++t)
        expPart += baseScale * std::pow(expFactor, static_cast<float>(t - expThresh + 1));

    return 1.0f + linearPart + expPart;
}

float RoguelikeMgr::GetTierArmorMultiplier(uint32 runId) const
{
    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _activeRuns.find(runId);
    if (it == _activeRuns.end()) return 1.0f;

    uint32 tier = it->second.CurrentTier;
    if (tier <= 1) return 1.0f;

    float baseScale = sDMConfig->GetRoguelikeArmorScaling();
    return 1.0f + (tier - 1) * baseScale;   // Armor scales linearly only
}

void RoguelikeMgr::GetAffixMultipliers(
    uint32 runId, bool isBoss, bool /*isElite*/,
    float& outHpMult, float& outDmgMult, float& outEliteChanceMult) const
{
    outHpMult   = 1.0f;
    outDmgMult  = 1.0f;
    outEliteChanceMult = 1.0f;

    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _activeRuns.find(runId);
    if (it == _activeRuns.end()) return;

    for (RoguelikeAffix afxId : it->second.ActiveAffixes)
    {
        for (const auto& def : _affixDefs)
        {
            if (def.Id == afxId)
            {
                // Calculate average familiarity resistance for the party
                float totalResistance = 0.0f;
                uint32 playerOnlineCount = 0;
                for (const auto& pd : it->second.Players)
                {
                    Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid);
                    if (p)
                    {
                        uint32 guidLow = pd.PlayerGuid.GetCounter();
                        float playerRes = sDungeonMasterMgr->GetAffixFamiliarity(guidLow, afxId).ResistancePct;
                        uint32 encounters = sDungeonMasterMgr->GetAffixFamiliarity(guidLow, afxId).Encounters;
                        float calcRes = std::min(sDMConfig->GetRoguelikeMaxFamiliarityPct(), encounters * sDMConfig->GetRoguelikeFamiliarityPerEncounter());
                        playerRes = std::max(playerRes, calcRes);

                        totalResistance += playerRes;
                        playerOnlineCount++;
                    }
                }
                float avgResistance = (playerOnlineCount > 0) ? (totalResistance / playerOnlineCount) : 0.0f;
                float resistanceFactor = 1.0f - (avgResistance / 100.0f);

                float baseHpMult = 1.0f;
                float baseDmgMult = 1.0f;

                if (isBoss)
                {
                    baseHpMult = def.BossHpMult;
                    baseDmgMult = def.BossDmgMult;
                }
                else
                {
                    baseHpMult = def.TrashHpMult;
                    baseDmgMult = def.TrashDmgMult;
                }

                // Apply resistance factor to the multiplier increases
                float hpIncrease = baseHpMult - 1.0f;
                float dmgIncrease = baseDmgMult - 1.0f;

                float adjustedHpMult = 1.0f + (hpIncrease * resistanceFactor);
                float adjustedDmgMult = 1.0f + (dmgIncrease * resistanceFactor);

                outHpMult *= adjustedHpMult;
                outDmgMult *= adjustedDmgMult;
                outEliteChanceMult *= def.EliteChanceMult;
                break;
            }
        }
    }
}

bool RoguelikeMgr::HasActiveAffixes(uint32 runId) const
{
    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _activeRuns.find(runId);
    return it != _activeRuns.end() && !it->second.ActiveAffixes.empty();
}

std::string RoguelikeMgr::GetActiveAffixNames(uint32 runId) const
{
    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _activeRuns.find(runId);
    if (it == _activeRuns.end()) return "";

    std::string result;
    for (RoguelikeAffix afxId : it->second.ActiveAffixes)
    {
        for (const auto& def : _affixDefs)
        {
            if (def.Id == afxId)
            {
                if (!result.empty()) result += ", ";
                result += "|cFFFF8800" + def.Name + "|r";
                break;
            }
        }
    }
    return result;
}

std::string RoguelikeMgr::GetActiveAffixNamesForPlayer(uint32 runId, ObjectGuid playerGuid) const
{
    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _activeRuns.find(runId);
    if (it == _activeRuns.end()) return "";

    std::string result;
    RoguelikePlayerStats stats = GetRoguelikePlayerStats(playerGuid);
    uint32 revealTier = sDMConfig->GetRoguelikeRevealAffixTier();

    for (RoguelikeAffix afxId : it->second.ActiveAffixes)
    {
        bool isKnown = (stats.KnownAffixMask & (1 << afxId)) != 0;
        bool isRevealed = isKnown || (it->second.CurrentTier >= revealTier);

        for (const auto& def : _affixDefs)
        {
            if (def.Id == afxId)
            {
                if (!result.empty()) result += ", ";
                if (isRevealed)
                {
                    result += "|cFFFF8800" + def.Name + "|r";
                }
                else
                {
                    result += "|cFF808080???|r";
                }
                break;
            }
        }
    }
    return result;
}

// Buff system (+10% all stats per stack via direct stat modification)
// In 3.3.5 clients, spell tooltips are hardcoded in the DBC and can't be updated
// Buff system (+10% all stats per stack via BoK aura with visual stack count)
// SetStackAmount(n) both displays the stack number on the buff icon AND
// auto-multiplies the base 10% effect by n (so 3 stacks = 30%).

static constexpr uint32 BUFF_SPELL_ID = 25898;  // Greater Blessing of Kings

void RoguelikeMgr::ApplyBuffAura(Player* player, uint32 stacks)
{
    if (!player || !player->IsInWorld() || stacks == 0) return;

    // Remove old aura before reapplying with new stack count
    player->RemoveAura(BUFF_SPELL_ID);

    Aura* aura = player->AddAura(BUFF_SPELL_ID, player);
    if (aura)
    {
        aura->SetStackAmount(static_cast<uint8>(stacks));
        aura->SetMaxDuration(-1);
        aura->SetDuration(-1);
    }
}

void RoguelikeMgr::IncrementBuffStacks(uint32 runId)
{
    RoguelikeRun* run = nullptr;
    {
        std::lock_guard<std::mutex> lock(_runMutex);
        auto it = _activeRuns.find(runId);
        if (it == _activeRuns.end()) return;
        run = &it->second;
    }

    ++run->BuffStacks;

    for (const auto& pd : run->Players)
    {
        Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid);
        if (p && p->IsInWorld())
            ApplyBuffAura(p, run->BuffStacks);
    }

    // Announce
    float totalPct = BUFF_PCT_PER_STACK * run->BuffStacks;
    char buf[256];
    snprintf(buf, sizeof(buf),
        "|cFF00FFFF[Roguelike]|r |cFF00FF00+%.0f%% All Stats|r (Stack %u)",
        totalPct, run->BuffStacks);
    AnnounceToRun(*run, buf);
}

void RoguelikeMgr::ApplyBuffStacks(Player* player, uint32 runId)
{
    if (!player || !player->IsInWorld()) return;

    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _activeRuns.find(runId);
    if (it == _activeRuns.end()) return;

    if (it->second.BuffStacks == 0) return;
    ApplyBuffAura(player, it->second.BuffStacks);
}

void RoguelikeMgr::RemoveBuffStacks(Player* player, uint32 runId)
{
    if (!player || !player->IsInWorld()) return;
    player->RemoveAura(BUFF_SPELL_ID);
}

// AFFIX SELECTION

void RoguelikeMgr::SelectAffixesForTier(RoguelikeRun& run)
{
    run.ActiveAffixes.clear();

    uint32 affixStart  = sDMConfig->GetRoguelikeAffixStartTier();
    uint32 secondAffix = sDMConfig->GetRoguelikeSecondAffixTier();
    uint32 thirdAffix  = sDMConfig->GetRoguelikeThirdAffixTier();

    if (run.CurrentTier < affixStart || _affixDefs.empty())
        return;

    uint32 numAffixes = 1;
    if (run.CurrentTier >= thirdAffix)
        numAffixes = 3;
    else if (run.CurrentTier >= secondAffix)
        numAffixes = 2;


    std::vector<RoguelikeAffix> pool;
    for (const auto& def : _affixDefs)
        if (def.Id != AFFIX_NONE)
            pool.push_back(def.Id);

    std::shuffle(pool.begin(), pool.end(), tRng);

    for (uint32 i = 0; i < numAffixes && i < pool.size(); ++i)
        run.ActiveAffixes.push_back(pool[i]);
}

// DUNGEON SELECTION

uint32 RoguelikeMgr::SelectRandomDungeon(const RoguelikeRun& run) const
{
    const DifficultyTier* diff = sDMConfig->GetDifficulty(run.BaseDifficultyId);
    std::vector<const DungeonInfo*> dgs;
    if (diff)
    {
        dgs = sDMConfig->GetDungeonsForLevel(diff->MinLevel, diff->MaxLevel);
    }
    else
    {
        dgs = sDMConfig->GetDungeonsForLevel(1, 80);
    }

    if (dgs.empty()) return 0xFFFFFFFF;

    // Filter by player level: every player in the run must meet the dungeon's min level requirement
    std::vector<const DungeonInfo*> eligible;
    for (const DungeonInfo* d : dgs)
    {
        bool partyEligible = true;
        for (const auto& pd : run.Players)
        {
            if (Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid))
            {
                if (p->GetLevel() < d->MinLevel)
                {
                    partyEligible = false;
                    break;
                }
            }
        }
        if (partyEligible)
        {
            eligible.push_back(d);
        }
    }

    if (eligible.empty()) return 0xFFFFFFFF;

    // Try to avoid repeating the same dungeon
    if (eligible.size() > 1 && run.DungeonsCleared > 0)
    {
        std::vector<const DungeonInfo*> filtered;
        for (const auto* d : eligible)
            if (d->Index != run.PreviousDungeonIndex)
                filtered.push_back(d);

        if (!filtered.empty())
            return filtered[RandInt<size_t>(0, filtered.size() - 1)]->Index;
    }

    return eligible[RandInt<size_t>(0, eligible.size() - 1)]->Index;
}

// Transition between dungeons

bool RoguelikeMgr::TransitionToNextDungeon(RoguelikeRun& run, uint32 dungeonIndex, uint32 themeId)
{
    const DungeonInfo* dg = sDMConfig->GetDungeon(dungeonIndex);
    if (!dg)
    {
        LOG_WARN("module", "RoguelikeMgr: Invalid dungeon index {} for run {}", dungeonIndex, run.RunId);
        return false;
    }

    // Find leader or first online player
    Player* leader = ObjectAccessor::FindPlayer(run.LeaderGuid);
    if (!leader)
    {
        for (const auto& pd : run.Players)
        {
            leader = ObjectAccessor::FindPlayer(pd.PlayerGuid);
            if (leader) { run.LeaderGuid = leader->GetGUID(); break; }
        }
    }

    if (!leader)
    {
        LOG_WARN("module", "RoguelikeMgr: No online leader for run {}", run.RunId);
        return false;
    }

    // Clear cooldowns (EndSession might have set them)
    for (const auto& pd : run.Players)
        sDungeonMasterMgr->ClearCooldown(pd.PlayerGuid);

    // Create the new DM session
    Session* session = sDungeonMasterMgr->CreateSession(
        leader, run.BaseDifficultyId, themeId, dungeonIndex, run.ScaleToParty);
    if (!session)
    {
        LOG_ERROR("module", "RoguelikeMgr: Failed to create session for run {} tier {}",
            run.RunId, run.CurrentTier);
        return false;
    }

    uint32 nextFloor = run.DungeonsCleared + 1;
    if (nextFloor % 10 == 0)
    {
        if (run.Wipes > 0)
        {
            --run.Wipes;
            char recoverMsg[256];
            snprintf(recoverMsg, sizeof(recoverMsg),
                "|cFF00FFFF[Roguelike]|r You have reached Floor %u! You gained 1 life back!",
                nextFloor);
            AnnounceToRun(run, recoverMsg);
        }
    }

    session->SurvivalBuffStacks = run.SurvivalBuffStacks;
    session->TimeAlive          = run.SurvivalBuffStacks * 300;
    session->WipeDebuffStacks   = run.WipeDebuffStacks;
    session->WipeDebuffTimer    = run.WipeDebuffTimer;
    session->Wipes              = run.Wipes;

    // Tag as roguelike
    session->RoguelikeRunId = run.RunId;
    run.CurrentSessionId    = session->SessionId;

    // Register session mapping
    {
        std::lock_guard<std::mutex> lock(_runMutex);
        _sessionToRun[session->SessionId] = run.RunId;
    }

    // Start and teleport
    if (!sDungeonMasterMgr->StartDungeon(session))
    {
        LOG_ERROR("module", "RoguelikeMgr: StartDungeon failed for run {}", run.RunId);
        sDungeonMasterMgr->CleanupRoguelikeSession(session->SessionId, false);
        {
            std::lock_guard<std::mutex> lock2(_runMutex);
            _sessionToRun.erase(session->SessionId);
        }
        return false;
    }

    if (!sDungeonMasterMgr->TeleportPartyIn(session))
    {
        LOG_ERROR("module", "RoguelikeMgr: Teleport failed for run {}", run.RunId);
        sDungeonMasterMgr->CleanupRoguelikeSession(session->SessionId, false);
        {
            std::lock_guard<std::mutex> lock2(_runMutex);
            _sessionToRun.erase(session->SessionId);
        }
        return false;
    }

    run.State = RoguelikeRunState::Active;
    run.TransitionStartTime = GameTime::GetGameTime().count();

    dg = sDMConfig->GetDungeon(dungeonIndex);
    char buf[256];
    snprintf(buf, sizeof(buf),
        "|cFF00FFFF[Roguelike]|r Entering |cFFFFFFFF%s|r — Tier |cFFFF0000%u|r",
        dg ? dg->Name.c_str() : "Unknown", run.CurrentTier);
    AnnounceToRun(run, buf);

    LOG_INFO("module", "RoguelikeMgr: Run {} transitioned to tier {} — dungeonIndex {} ({})",
        run.RunId, run.CurrentTier, dungeonIndex,
        dg ? dg->Name.c_str() : "?");

    return true;
}

void RoguelikeMgr::TeleportRunPlayersOut(RoguelikeRun& run)
{
    for (const auto& pd : run.Players)
    {
        Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid);
        if (!p) continue;

        // Skip players that are mid-teleport or not fully in the world.
        if (!p->IsInWorld())
            continue;

        p->RemoveFlag(PLAYER_FIELD_BYTES, PLAYER_FIELD_BYTE_NO_RELEASE_WINDOW);
        if (!p->IsAlive())
        {
            p->ResurrectPlayer(1.0f);
            p->SpawnCorpseBones();
        }

        p->TeleportTo(pd.OriginalMapId,
            pd.OriginalPosition.GetPositionX(),
            pd.OriginalPosition.GetPositionY(),
            pd.OriginalPosition.GetPositionZ(),
            pd.OriginalPosition.GetOrientation());
    }
}

// ANNOUNCEMENTS

void RoguelikeMgr::AnnounceToRun(const RoguelikeRun& run, const char* msg)
{
    for (const auto& pd : run.Players)
        if (Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid))
            if (p->GetSession())
                ChatHandler(p->GetSession()).SendSysMessage(msg);
}

void RoguelikeMgr::AnnounceCountdown(const RoguelikeRun& run, uint32 remainingSec)
{
    char buf[128];
    snprintf(buf, sizeof(buf),
        "|cFF00FFFF[Roguelike]|r Next dungeon in |cFFFFFFFF%u|r second%s...",
        remainingSec, remainingSec != 1 ? "s" : "");
    AnnounceToRun(run, buf);
}


void RoguelikeMgr::Update(uint32 diff)
{
    _updateTimer += diff;
    if (_updateTimer < UPDATE_INTERVAL)
        return;
    _updateTimer = 0;

    std::vector<uint32> toAbandon;

    {
        std::lock_guard<std::mutex> lock(_runMutex);

        for (auto& [rid, run] : _activeRuns)
        {
            // ---- Transition grace period ----
            if (run.TransitionStartTime > 0)
            {
                uint64 elapsed = GameTime::GetGameTime().count() - run.TransitionStartTime;
                if (elapsed < 300)
                    continue;   // still in grace window
                // Grace expired — clear flag so normal detection resumes
                run.TransitionStartTime = 0;
            }

            // ---- Abandoned detection: all players offline ----
            bool anyOnline = false;
            for (const auto& pd : run.Players)
            {
                Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid);
                if (p && p->GetSession()) { anyOnline = true; break; }
            }

            if (!anyOnline)
            {
                toAbandon.push_back(rid);
                continue;
            }

            // ---- Re-apply buff aura after death ----
            if (run.State == RoguelikeRunState::Active && run.BuffStacks > 0)
            {
                for (const auto& pd : run.Players)
                {
                    Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid);
                    if (!p || !p->IsInWorld() || !p->IsAlive()) continue;

                    if (!p->HasAura(BUFF_SPELL_ID))
                        ApplyBuffAura(p, run.BuffStacks);
                }
            }
        }
    }

    for (uint32 rid : toAbandon)
    {
        LOG_INFO("module", "RoguelikeMgr: Run {} — all players offline, abandoning.", rid);
        EndRun(rid, false);
    }
}

// LEADERBOARD

void RoguelikeMgr::SaveRoguelikeLeaderboard(const RoguelikeRun& run)
{
    uint32 duration = 0;
    if (GameTime::GetGameTime().count() > static_cast<time_t>(run.RunStartTime))
        duration = static_cast<uint32>(GameTime::GetGameTime().count() - run.RunStartTime);

    std::string leaderName = "Unknown";
    if (Player* leader = ObjectAccessor::FindPlayer(run.LeaderGuid))
        leaderName = leader->GetName();

    std::string safeName = leaderName;
    size_t pos = 0;
    while ((pos = safeName.find('\'', pos)) != std::string::npos)
    {
        safeName.replace(pos, 1, "''");
        pos += 2;
    }

    uint8 partySize = static_cast<uint8>(run.Players.size());

    char query[512];
    snprintf(query, sizeof(query),
        "INSERT INTO dm_roguelike_leaderboard "
        "(guid, char_name, tier_reached, dungeons_cleared, total_kills, "
        "total_bosses, total_deaths, run_duration, party_size) "
        "VALUES (%u, '%s', %u, %u, %u, %u, %u, %u, %u)",
        run.LeaderGuid.GetCounter(), safeName.c_str(),
        run.CurrentTier, run.DungeonsCleared,
        run.TotalMobsKilled + run.TotalBossesKilled,
        run.TotalBossesKilled, run.TotalDeaths,
        duration, partySize);
    CharacterDatabase.Execute(query);

    // Also update per-player roguelike stats
    UpdateRoguelikePlayerStats(run);
}

std::vector<RoguelikeLeaderboardEntry> RoguelikeMgr::GetRoguelikeLeaderboard(
    uint32 limit, bool sortByFloors) const
{
    std::vector<RoguelikeLeaderboardEntry> entries;

    char query[512];
    if (sortByFloors)
        snprintf(query, sizeof(query),
            "SELECT id, guid, char_name, tier_reached, dungeons_cleared, "
            "total_kills, total_bosses, total_deaths, run_duration, party_size "
            "FROM dm_roguelike_leaderboard "
            "ORDER BY dungeons_cleared DESC, tier_reached DESC, run_duration ASC "
            "LIMIT %u", limit);
    else
        snprintf(query, sizeof(query),
            "SELECT id, guid, char_name, tier_reached, dungeons_cleared, "
            "total_kills, total_bosses, total_deaths, run_duration, party_size "
            "FROM dm_roguelike_leaderboard "
            "ORDER BY tier_reached DESC, dungeons_cleared DESC, run_duration ASC "
            "LIMIT %u", limit);

    QueryResult result = CharacterDatabase.Query(query);
    if (!result) return entries;

    do
    {
        Field* f = result->Fetch();
        RoguelikeLeaderboardEntry e;
        e.Id              = f[0].Get<uint32>();
        e.Guid            = f[1].Get<uint32>();
        e.CharName        = f[2].Get<std::string>();
        e.TierReached     = f[3].Get<uint32>();
        e.DungeonsCleared = f[4].Get<uint32>();
        e.TotalKills      = f[5].Get<uint32>();
        e.TotalBosses     = f[6].Get<uint32>();
        e.TotalDeaths     = f[7].Get<uint32>();
        e.RunDuration     = f[8].Get<uint32>();
        e.PartySize       = f[9].Get<uint8>();
        entries.push_back(e);
    } while (result->NextRow());

    return entries;
}

// ---------------------------------------------------------------------------
// Roguelike Player Stats
// ---------------------------------------------------------------------------

void RoguelikeMgr::LoadAllRoguelikePlayerStats()
{
    std::lock_guard<std::mutex> lock(_rlStatsMutex);
    _roguelikeStats.clear();

    QueryResult result = CharacterDatabase.Query(
        "SELECT guid, total_runs, highest_tier, most_floors_cleared, "
        "total_floors_cleared, total_mobs_killed, total_bosses_killed, "
        "total_deaths, longest_run_time, known_affix_mask, veto_tokens "
        "FROM dm_roguelike_player_stats");

    if (!result)
    {
        LOG_INFO("module", "RoguelikeMgr: No roguelike player stats found.");
        return;
    }

    uint32 count = 0;
    do
    {
        Field* f = result->Fetch();
        uint32 guidLow = f[0].Get<uint32>();

        RoguelikePlayerStats ps;
        ps.TotalRuns          = f[1].Get<uint32>();
        ps.HighestTier        = f[2].Get<uint32>();
        ps.MostFloorsCleared  = f[3].Get<uint32>();
        ps.TotalFloorsCleared = f[4].Get<uint32>();
        ps.TotalMobsKilled    = f[5].Get<uint32>();
        ps.TotalBossesKilled  = f[6].Get<uint32>();
        ps.TotalDeaths        = f[7].Get<uint32>();
        ps.LongestRunTime     = f[8].Get<uint32>();
        ps.KnownAffixMask     = f[9].Get<uint32>();
        ps.VetoTokens         = f[10].Get<uint32>();

        _roguelikeStats[guidLow] = ps;
        ++count;
    } while (result->NextRow());

    LOG_INFO("module", "RoguelikeMgr: Loaded roguelike stats for {} players.", count);
}

RoguelikePlayerStats RoguelikeMgr::GetRoguelikePlayerStats(ObjectGuid guid) const
{
    std::lock_guard<std::mutex> lock(_rlStatsMutex);
    uint32 guidLow = guid.GetCounter();
    auto it = _roguelikeStats.find(guidLow);
    if (it != _roguelikeStats.end())
        return it->second;
    return {};
}

void RoguelikeMgr::UpdateRoguelikePlayerStats(const RoguelikeRun& run)
{
    uint32 duration = 0;
    if (GameTime::GetGameTime().count() > static_cast<time_t>(run.RunStartTime))
        duration = static_cast<uint32>(GameTime::GetGameTime().count() - run.RunStartTime);

    for (const auto& pd : run.Players)
    {
        uint32 guidLow = pd.PlayerGuid.GetCounter();

        {
            std::lock_guard<std::mutex> lock(_rlStatsMutex);
            auto& ps = _roguelikeStats[guidLow];
            ps.TotalRuns++;
            if (run.CurrentTier > ps.HighestTier)
                ps.HighestTier = run.CurrentTier;
            if (run.DungeonsCleared > ps.MostFloorsCleared)
                ps.MostFloorsCleared = run.DungeonsCleared;
            // ps.TotalFloorsCleared is updated per-floor in OnDungeonCompleted
            ps.TotalMobsKilled    += run.TotalMobsKilled;
            ps.TotalBossesKilled  += run.TotalBossesKilled;
            ps.TotalDeaths        += run.TotalDeaths;
            if (duration > ps.LongestRunTime)
                ps.LongestRunTime = duration;
        }

        // Persist
        RoguelikePlayerStats ps;
        {
            std::lock_guard<std::mutex> lock(_rlStatsMutex);
            ps = _roguelikeStats[guidLow];
        }

        char query[512];
        snprintf(query, sizeof(query),
            "REPLACE INTO dm_roguelike_player_stats "
            "(guid, total_runs, highest_tier, most_floors_cleared, "
            "total_floors_cleared, total_mobs_killed, total_bosses_killed, "
            "total_deaths, longest_run_time, known_affix_mask, veto_tokens) "
            "VALUES (%u, %u, %u, %u, %u, %u, %u, %u, %u, %u, %u)",
            guidLow, ps.TotalRuns, ps.HighestTier, ps.MostFloorsCleared,
            ps.TotalFloorsCleared, ps.TotalMobsKilled, ps.TotalBossesKilled,
            ps.TotalDeaths, ps.LongestRunTime, ps.KnownAffixMask, ps.VetoTokens);
    }
}

void RoguelikeMgr::GenerateBranchChoices(RoguelikeRun& run)
{
    run.BranchChoices.clear();
    run.AwaitingBranchSelection = true;

    // Get leader low GUID for bestiary and risk lookups
    uint32 leaderGuidLow = run.LeaderGuid.GetCounter();

    // Get eligible dungeons
    const DifficultyTier* diff = sDMConfig->GetDifficulty(run.BaseDifficultyId);
    if (!diff) return;

    auto dgs = sDMConfig->GetDungeonsForLevel(diff->MinLevel, diff->MaxLevel);
    std::vector<const DungeonInfo*> eligible;
    for (const DungeonInfo* d : dgs)
    {
        bool partyEligible = true;
        for (const auto& pd : run.Players)
        {
            if (Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid))
            {
                if (p->GetLevel() < d->MinLevel)
                {
                    partyEligible = false;
                    break;
                }
            }
        }
        if (partyEligible)
            eligible.push_back(d);
    }

    if (eligible.empty())
        return;

    // Shuffle/randomly select up to 3 unique dungeons
    std::vector<const DungeonInfo*> candidates = eligible;
    std::random_device rd;
    std::mt19937 g(rd());
    std::shuffle(candidates.begin(), candidates.end(), g);

    // If possible, filter out previous dungeon
    if (candidates.size() > 1 && run.DungeonsCleared > 0)
    {
        for (auto it = candidates.begin(); it != candidates.end(); ++it)
        {
            if ((*it)->Index == run.PreviousDungeonIndex)
            {
                candidates.erase(it);
                break;
            }
        }
    }

    uint32 maxChoices = sDMConfig->GetRoguelikeBranchChoices();
    if (sDungeonMasterMgr->HasMasteryPerk(leaderGuidLow, 2)) // Pathfinder perk is bit 2
    {
        maxChoices = 4;
    }

    uint32 count = std::min<uint32>(maxChoices, static_cast<uint32>(candidates.size()));
    if (count == 0 && !eligible.empty())
    {
        candidates = eligible;
        count = 1;
    }

    for (uint32 i = 0; i < count; ++i)
    {
        const DungeonInfo* dg = candidates[i];
        BranchOption opt;
        opt.DungeonIndex = dg->Index;

        // Theme selection: run theme if locked, else random theme
        uint32 themeId = run.ThemeId;
        if (themeId == 0)
        {
            const auto& themes = sDMConfig->GetThemes();
            if (!themes.empty())
            {
                themeId = themes[RandInt<size_t>(0, themes.size() - 1)].Id;
            }
        }
        opt.ThemeId = themeId;

        // Check if theme is known/discovered on this map for the leader
        const Theme* th = sDMConfig->GetTheme(themeId);
        bool bestiaryPermits = false;
        if (th)
        {
            DungeonKnowledgeEntry meta = sDungeonMasterMgr->GetBestiaryMeta(leaderGuidLow, dg->MapId);
            if (meta.RunsCompleted > 0 || meta.TotalKills > 0)
            {
                bestiaryPermits = true;
            }
            else
            {
                for (uint32 ct : th->CreatureTypes)
                {
                    if (ct == uint32(-1) || sDungeonMasterMgr->GetBestiaryKills(leaderGuidLow, dg->MapId, ct) > 0)
                    {
                        bestiaryPermits = true;
                        break;
                    }
                }
            }
        }
        opt.ThemeDiscovered = bestiaryPermits;

        // Risk level lookup
        DungeonKnowledgeEntry meta = sDungeonMasterMgr->GetBestiaryMeta(leaderGuidLow, dg->MapId);
        if (meta.RunsStarted == 0)
        {
            opt.Risk = RiskLevel::Unknown;
        }
        else
        {
            float winRate = static_cast<float>(meta.RunsCompleted) / meta.RunsStarted;
            if (winRate >= 0.75f)
                opt.Risk = RiskLevel::Low;
            else if (winRate >= 0.40f)
                opt.Risk = RiskLevel::Medium;
            else
                opt.Risk = RiskLevel::High;
        }

        run.BranchChoices.push_back(opt);
    }
}

void RoguelikeMgr::SendBranchChoicesToParty(const RoguelikeRun& run)
{
    std::string payload = "DMDATA:BRANCH_OPTIONS:";
    for (size_t i = 0; i < run.BranchChoices.size(); ++i)
    {
        if (i > 0) payload += "|";
        const auto& opt = run.BranchChoices[i];
        payload += std::to_string(opt.DungeonIndex + 1) + "," +
                   std::to_string(opt.ThemeDiscovered ? opt.ThemeId : 0) + "," +
                   std::to_string(static_cast<uint32>(opt.Risk));
    }
    
    AnnounceToRun(run, payload.c_str());
}

bool RoguelikeMgr::ConsumeVetoToken(ObjectGuid playerGuid)
{
    std::lock_guard<std::mutex> lock(_rlStatsMutex);
    uint32 guidLow = playerGuid.GetCounter();
    auto it = _roguelikeStats.find(guidLow);
    if (it == _roguelikeStats.end() || it->second.VetoTokens == 0)
        return false;

    it->second.VetoTokens--;

    // Persist
    RoguelikePlayerStats ps = it->second;
    char query[512];
    snprintf(query, sizeof(query),
        "REPLACE INTO dm_roguelike_player_stats "
        "(guid, total_runs, highest_tier, most_floors_cleared, "
        "total_floors_cleared, total_mobs_killed, total_bosses_killed, "
        "total_deaths, longest_run_time, known_affix_mask, veto_tokens) "
        "VALUES (%u, %u, %u, %u, %u, %u, %u, %u, %u, %u, %u)",
        guidLow, ps.TotalRuns, ps.HighestTier, ps.MostFloorsCleared,
        ps.TotalFloorsCleared, ps.TotalMobsKilled, ps.TotalBossesKilled,
        ps.TotalDeaths, ps.LongestRunTime, ps.KnownAffixMask, ps.VetoTokens);
    CharacterDatabase.Execute(query);
    return true;
}

bool RoguelikeMgr::VetoAffixForRun(uint32 runId, uint32 vetoedAffixId, std::string& outNewAffixName)
{
    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _activeRuns.find(runId);
    if (it == _activeRuns.end())
        return false;

    RoguelikeRun& run = it->second;

    // Find the vetoed affix in currently active affixes
    auto affIt = std::find(run.ActiveAffixes.begin(), run.ActiveAffixes.end(), static_cast<RoguelikeAffix>(vetoedAffixId));
    if (affIt == run.ActiveAffixes.end())
        return false;

    // Remove the vetoed affix
    run.ActiveAffixes.erase(affIt);

    // Build the remaining pool of affixes (exclude vetoed and currently active)
    std::vector<RoguelikeAffix> pool;
    for (const auto& def : _affixDefs)
    {
        if (def.Id == AFFIX_NONE || def.Id == static_cast<RoguelikeAffix>(vetoedAffixId))
            continue;

        if (std::find(run.ActiveAffixes.begin(), run.ActiveAffixes.end(), def.Id) != run.ActiveAffixes.end())
            continue;

        pool.push_back(def.Id);
    }

    if (!pool.empty())
    {
        std::shuffle(pool.begin(), pool.end(), tRng);
        RoguelikeAffix newAfx = pool[0];
        run.ActiveAffixes.push_back(newAfx);

        for (const auto& def : _affixDefs)
        {
            if (def.Id == newAfx)
            {
                outNewAffixName = def.Name;
                break;
            }
        }
    }
    else
    {
        outNewAffixName = "None";
    }

    return true;
}

void RoguelikeMgr::ClearTransitionTime(uint32 runId)
{
    std::lock_guard<std::mutex> lock(_runMutex);
    auto it = _activeRuns.find(runId);
    if (it != _activeRuns.end())
    {
        it->second.TransitionStartTime = 0;
        LOG_INFO("module", "RoguelikeMgr: Run {} cleared transition grace period on player map enter.", runId);
    }
}

} // namespace DungeonMaster

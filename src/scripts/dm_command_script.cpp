/*
 * mod-dungeon-master — dm_command_script.cpp
 * Player & GM commands: .dm reload, .dm status, .dm list, .dm end, .dm clearcooldown, .dm query, .dm begin, .dm roguelike, .dm mystats, .dm boards, .dm rlquit
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "ChatCommand.h"
#include "Player.h"
#include "Group.h"
#include "GroupMgr.h"
#include "InstanceSaveMgr.h"
#include "DungeonMasterMgr.h"
#include "DMConfig.h"
#include "RoguelikeMgr.h"
#include "RoguelikeTypes.h"
#include "ObjectAccessor.h"
#include "GameTime.h"
#include <cstdio>
#include <random>

using namespace Acore::ChatCommands;
using namespace DungeonMaster;

class dm_command_script : public CommandScript
{
public:
    dm_command_script() : CommandScript("dm_command_script") {}

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable dmTable =
        {
            { "reload",        HandleReload,        SEC_ADMINISTRATOR,  Console::Yes },
            { "status",        HandleStatus,        SEC_GAMEMASTER,     Console::Yes },
            { "list",          HandleList,           SEC_GAMEMASTER,     Console::Yes },
            { "leave",         HandleLeave,          SEC_PLAYER,         Console::No  },
            { "exit",          HandleLeave,          SEC_PLAYER,         Console::No  },
            { "end",           HandleEnd,            SEC_ADMINISTRATOR,  Console::No  },
            { "clearcooldown", HandleClearCD,        SEC_GAMEMASTER,     Console::No  },
            { "query",         HandleQuery,         SEC_PLAYER,         Console::No  },
            { "begin",         HandleBegin,         SEC_PLAYER,         Console::No  },
            { "roguelike",     HandleRoguelike,     SEC_PLAYER,         Console::No  },
            { "mystats",       HandleMyStats,       SEC_PLAYER,         Console::No  },
            { "boards",        HandleBoards,        SEC_PLAYER,         Console::No  },
            { "rlquit",        HandleRLQuit,         SEC_PLAYER,         Console::No  },
            { "rladvance",     HandleRLAdvance,     SEC_PLAYER,         Console::No  },
            { "rlselect",      HandleRLSelect,      SEC_PLAYER,         Console::No  },
            { "rltogglegambit",HandleRLToggleGambit,SEC_PLAYER,         Console::No  },
            { "rlveto",        HandleRLVeto,        SEC_PLAYER,         Console::No  },
            { "rlstart",       HandleRLStart,       SEC_PLAYER,         Console::No  },
            { "resetboss",     HandleResetBoss,     SEC_PLAYER,         Console::No  },
            { "rejoin",        HandleRejoin,        SEC_PLAYER,         Console::No  },
            { "rlbuymastery",  HandleRLBuyMastery,  SEC_PLAYER,         Console::No  },
        };
        static ChatCommandTable root = { { "dm", dmTable } };
        return root;
    }

    static bool HandleReload(ChatHandler* h)
    {
        sDMConfig->LoadConfig(true);
        h->SendSysMessage("DungeonMaster: Configuration reloaded.");
        return true;
    }

    static bool HandleStatus(ChatHandler* h)
    {
        char buf[256];
        h->SendSysMessage("=== Dungeon Master Status ===");
        snprintf(buf, sizeof(buf), "Enabled: %s", sDMConfig->IsEnabled() ? "Yes" : "No");
        h->SendSysMessage(buf);
        snprintf(buf, sizeof(buf), "Active: %u / %u",
            sDungeonMasterMgr->GetActiveSessionCount(), sDMConfig->GetMaxConcurrentRuns());
        h->SendSysMessage(buf);
        snprintf(buf, sizeof(buf), "Level Band: +/-%u", sDMConfig->GetLevelBand());
        h->SendSysMessage(buf);
        snprintf(buf, sizeof(buf), "Difficulties: %u  Themes: %u  Dungeons: %u",
            uint32(sDMConfig->GetDifficulties().size()),
            uint32(sDMConfig->GetThemes().size()),
            uint32(sDMConfig->GetDungeons().size()));
        h->SendSysMessage(buf);
        return true;
    }

    static bool HandleList(ChatHandler* h)
    {
        uint32 n = sDungeonMasterMgr->GetActiveSessionCount();
        char buf[128];
        snprintf(buf, sizeof(buf), "Active DM sessions: %u", n);
        h->SendSysMessage(buf);
        return true;
    }

    static bool HandleLeave(ChatHandler* h)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        Session* s = sDungeonMasterMgr->GetSessionByPlayer(player->GetGUID());
        if (!s)
        {
            // Player is not in an active session. Check if they have a saved return position in DB
            char query[256];
            snprintf(query, sizeof(query), "SELECT map_id, position_x, position_y, position_z, orientation FROM `dm_player_return_position` WHERE `guid` = %u", player->GetGUID().GetCounter());
            QueryResult result = CharacterDatabase.Query(query);

            if (result)
            {
                Field* f = result->Fetch();
                uint32 mapId = f[0].Get<uint32>();
                float px = f[1].Get<float>();
                float py = f[2].Get<float>();
                float pz = f[3].Get<float>();
                float po = f[4].Get<float>();

                player->TeleportTo(mapId, px, py, pz, po);
                
                char delQuery[256];
                snprintf(delQuery, sizeof(delQuery), "DELETE FROM `dm_player_return_position` WHERE `guid` = %u", player->GetGUID().GetCounter());
                CharacterDatabase.Execute(delQuery);

                h->SendSysMessage("Dungeon Master session not found in memory, but relocated you to your saved pre-challenge position.");
            }
            else
            {
                // Fall back to homebind/hearthstone coordinates
                player->TeleportTo(player->m_homebindMapId, player->m_homebindX, player->m_homebindY, player->m_homebindZ, player->GetOrientation());
                h->SendSysMessage("No active session or saved return position found. Relocating you to your homebind location.");
            }
            return true;
        }

        uint32 id = s->SessionId;
        sDungeonMasterMgr->EndSession(id, false);
        h->SendSysMessage("Dungeon Master challenge abandoned. Returning party to saved entry locations.");
        return true;
    }

    static bool HandleEnd(ChatHandler* h, Optional<uint32> sessionId)
    {
        char buf[128];
        if (sessionId)
        {
            Session* s = sDungeonMasterMgr->GetSession(*sessionId);
            if (!s) { snprintf(buf, sizeof(buf), "Session %u not found.", *sessionId); h->SendSysMessage(buf); return false; }
            sDungeonMasterMgr->EndSession(*sessionId, false);
            snprintf(buf, sizeof(buf), "Session %u ended.", *sessionId); h->SendSysMessage(buf);
        }
        else
        {
            // Try the invoker's own session first
            Player* invoker = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
            Session* s = invoker ? sDungeonMasterMgr->GetSessionByPlayer(invoker->GetGUID()) : nullptr;

            // Fall back to selected player's session
            if (!s)
            {
                Player* t = h->getSelectedPlayer();
                s = t ? sDungeonMasterMgr->GetSessionByPlayer(t->GetGUID()) : nullptr;
            }

            if (!s) { h->SendSysMessage("Not in a DM session. Select a player or provide session ID."); return false; }
            uint32 id = s->SessionId;
            sDungeonMasterMgr->EndSession(id, false);
            snprintf(buf, sizeof(buf), "Session %u ended (all players teleported out).", id); h->SendSysMessage(buf);
        }
        return true;
    }

    static bool HandleClearCD(ChatHandler* h)
    {
        Player* invoker = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!invoker) { h->SendSysMessage("In-game only."); return false; }

        // If invoker is in a group, clear cooldown for ALL group members
        Group* g = invoker->GetGroup();
        if (g)
        {
            uint32 cleared = 0;
            for (GroupReference* ref = g->GetFirstMember(); ref; ref = ref->next())
            {
                Player* member = ref->GetSource();
                if (member)
                {
                    sDungeonMasterMgr->ClearCooldown(member->GetGUID());
                    ++cleared;
                }
            }
            char buf[128];
            snprintf(buf, sizeof(buf), "Cooldown cleared for %u group member(s).", cleared);
            h->SendSysMessage(buf);
        }
        else
        {
            // Solo — clear for self or selected player
            Player* t = h->getSelectedPlayer();
            if (!t) t = invoker;
            sDungeonMasterMgr->ClearCooldown(t->GetGUID());
            char buf[128];
            snprintf(buf, sizeof(buf), "Cooldown cleared for %s.", t->GetName().c_str());
            h->SendSysMessage(buf);
        }
        return true;
    }

    static bool HandleQuery(ChatHandler* h)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        char buf[256];

        // Difficulties
        for (const auto& diff : sDMConfig->GetDifficulties())
        {
            snprintf(buf, sizeof(buf), "DMDATA:DIFF:%u,%s,%u,%u,%.2f,%.2f,%.2f,%.2f",
                diff.Id, diff.Name.c_str(), diff.MinLevel, diff.MaxLevel,
                diff.HealthMultiplier, diff.DamageMultiplier, diff.RewardMultiplier, diff.MobCountMultiplier);
            h->SendSysMessage(buf);
        }

        // Themes
        for (const auto& theme : sDMConfig->GetThemes())
        {
            snprintf(buf, sizeof(buf), "DMDATA:THEME:%u,%s",
                theme.Id, theme.Name.c_str());
            h->SendSysMessage(buf);
        }

        // Dungeons
        for (const auto& dg : sDMConfig->GetDungeons())
        {
            if (dg.IsAvailable)
            {
                float fatigueMult = sDungeonMasterMgr->GetPlayerMapHistoryMultiplier(player->GetGUID(), dg.MapId);
                uint32 spawnCount = sDungeonMasterMgr->GetDungeonSpawnCount(dg.MapId);
                snprintf(buf, sizeof(buf), "DMDATA:DNG:%u,%s,%u,%u,%u,%u",
                    dg.Index + 1, dg.Name.c_str(), dg.MinLevel, dg.MaxLevel,
                    static_cast<uint32>(fatigueMult * 100.0f), spawnCount);
                h->SendSysMessage(buf);
            }
        }

        // Flags
        uint32 cooldownRem = sDungeonMasterMgr->GetRemainingCooldown(player->GetGUID());
        Session* s = sDungeonMasterMgr->GetSessionByPlayer(player->GetGUID());
        bool inSession = (s != nullptr);
        
        RoguelikeRun* run = sRoguelikeMgr->GetRunByPlayer(player->GetGUID());
        bool inRoguelike = (run != nullptr && run->IsActive());
        uint32 rlTier = inRoguelike ? run->CurrentTier : 0;
        uint32 rlFloors = inRoguelike ? run->DungeonsCleared : 0;

        uint32 sessionState = 0;
        uint32 diffId = 0;
        uint32 scaleParty = 1;
        uint32 themeId = 0;
        uint32 mapId = 0;

        if (inSession && s)
        {
            sessionState = static_cast<uint32>(s->State);
            diffId = s->DifficultyId;
            scaleParty = s->ScaleToParty ? 1 : 0;
            themeId = s->ThemeId;
            mapId = s->DungeonIndex + 1;
        }
        else if (inRoguelike && run)
        {
            sessionState = 0;
            diffId = run->BaseDifficultyId;
            scaleParty = run->ScaleToParty ? 1 : 0;
            themeId = run->ThemeId;
            mapId = 0;
        }

        snprintf(buf, sizeof(buf), "DMDATA:FLAGS:%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u",
            sDMConfig->IsEnabled() ? 1 : 0,
            sDMConfig->IsRoguelikeEnabled() ? 1 : 0,
            cooldownRem,
            inSession ? 1 : 0,
            inRoguelike ? 1 : 0,
            player->GetLevel(),
            rlTier,
            rlFloors,
            sessionState,
            diffId,
            scaleParty,
            themeId,
            mapId,
            sDMConfig->GetBaseGold(),
            sDMConfig->GetGoldPerMob(),
            sDMConfig->GetGoldPerBoss(),
            sDMConfig->GetItemChance(),
            sDMConfig->GetRareChance(),
            sDMConfig->GetEpicChance(),
            sRoguelikeMgr->GetRoguelikePlayerStats(player->GetGUID()).VetoTokens,
            (inSession && s) ? (s->GambitTimeTrial ? 1 : 0) : 0,
            (inSession && s) ? (s->GambitGlassCannon ? 1 : 0) : 0,
            (inSession && s) ? (s->GambitPacifist ? 1 : 0) : 0);
        h->SendSysMessage(buf);

        if (inSession && s)
        {
            std::string bossName;
            float bx = 0.0f, by = 0.0f;
            sDungeonMasterMgr->GetActiveBossInfo(player->GetGUID(), bossName, bx, by);
            uint32 bossResetCd = sDungeonMasterMgr->GetRemainingBossResetCooldown(player->GetGUID());
            uint64 elapsed = GameTime::GetGameTime().count() - s->StartTime;

            uint32 teleportRemaining = 0;
            if (s->State == SessionState::Completed && s->EndTime != 0)
            {
                uint32 delay = (s->RoguelikeRunId != 0)
                    ? sDMConfig->GetRoguelikeTransitionDelay()
                    : sDMConfig->GetCompletionTeleportDelay();
                uint64 sinceEnd = GameTime::GetGameTime().count() - s->EndTime;
                teleportRemaining = (sinceEnd < delay) ? static_cast<uint32>(delay - sinceEnd) : 0;
            }

            snprintf(buf, sizeof(buf), "DMDATA:RUNINFO:%llu,%s,%.1f,%.1f,%u,%u,%u,%u,%u,%u,%u,%u,%u",
                (unsigned long long)elapsed,
                bossName.empty() ? "None" : bossName.c_str(),
                bx, by,
                bossResetCd,
                s->SurvivalBuffStacks,
                s->WipeDebuffStacks,
                s->WipeDebuffTimer,
                s->Wipes,
                sDMConfig->GetMaxWipes(),
                s->TimeAlive,
                teleportRemaining,
                s->PreparationTimer);
            h->SendSysMessage(buf);
        }

        std::string affList;
        if (inRoguelike && run)
        {
            for (RoguelikeAffix afxId : run->ActiveAffixes)
            {
                if (!affList.empty()) affList += ",";
                affList += std::to_string(afxId);
            }
        }
        snprintf(buf, sizeof(buf), "DMDATA:ACTIVE_AFFIXES:%s", affList.c_str());
        h->SendSysMessage(buf);

        h->SendSysMessage("DMDATA:END");
        return true;
    }

    static bool HandleBegin(ChatHandler* h, Tail args)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        std::string argsStr(args);
        if (argsStr.empty())
        {
            h->SendSysMessage("DMDATA:BEGIN_FAIL:Missing arguments. Usage: .dm begin <diffId> <scaleParty> <themeId> <mapId>");
            return false;
        }

        uint32 diffId = 0;
        uint32 scalePartyInt = 0;
        uint32 themeId = 0;
        uint32 dungeonIndexParam = 0;

        if (sscanf(argsStr.c_str(), "%u %u %u %u", &diffId, &scalePartyInt, &themeId, &dungeonIndexParam) < 4)
        {
            h->SendSysMessage("DMDATA:BEGIN_FAIL:Invalid argument format. Usage: .dm begin <diffId> <scaleParty> <themeId> <dungeonIndex>");
            return false;
        }

        bool scaleParty = (scalePartyInt != 0);

        if (!sDMConfig->IsEnabled())
        {
            h->SendSysMessage("DMDATA:BEGIN_FAIL:Dungeon Master system is disabled.");
            return false;
        }

        ObjectGuid guid = player->GetGUID();

        if (sDungeonMasterMgr->GetSessionByPlayer(guid))
        {
            h->SendSysMessage("DMDATA:BEGIN_FAIL:You are already in a Dungeon Master challenge.");
            return false;
        }

        if (sRoguelikeMgr->IsPlayerInRun(guid))
        {
            h->SendSysMessage("DMDATA:BEGIN_FAIL:You are already in a Roguelike run.");
            return false;
        }

        std::vector<Player*> members;
        if (Group* g = player->GetGroup())
        {
            for (GroupReference* ref = g->GetFirstMember(); ref; ref = ref->next())
            {
                if (Player* m = ref->GetSource())
                    members.push_back(m);
            }
        }
        else
        {
            members.push_back(player);
        }

        for (Player* member : members)
        {
            if (sDungeonMasterMgr->IsOnCooldown(member->GetGUID()))
            {
                char buf[256];
                snprintf(buf, sizeof(buf), "DMDATA:BEGIN_FAIL:Player %s is on cooldown for %u seconds.",
                    member->GetName().c_str(), sDungeonMasterMgr->GetRemainingCooldown(member->GetGUID()));
                h->SendSysMessage(buf);
                return false;
            }
        }

        if (!sDungeonMasterMgr->CanCreateNewSession())
        {
            h->SendSysMessage("DMDATA:BEGIN_FAIL:Server has reached maximum concurrent sessions.");
            return false;
        }

        const DifficultyTier* diff = sDMConfig->GetDifficulty(diffId);
        if (!diff)
        {
            h->SendSysMessage("DMDATA:BEGIN_FAIL:Invalid difficulty ID.");
            return false;
        }

        for (Player* member : members)
        {
            if (!diff->IsValidForLevel(member->GetLevel()))
            {
                char buf[256];
                snprintf(buf, sizeof(buf), "DMDATA:BEGIN_FAIL:Player %s does not meet the level requirement (%u) for this difficulty.",
                    member->GetName().c_str(), diff->MinLevel);
                h->SendSysMessage(buf);
                return false;
            }
        }

        uint32 dungeonIndex = 0;
        bool isRandom = (dungeonIndexParam == 0);

        if (!isRandom)
        {
            dungeonIndex = dungeonIndexParam - 1;
            const DungeonInfo* dg = sDMConfig->GetDungeon(dungeonIndex);
            if (!dg || !dg->IsAvailable)
            {
                h->SendSysMessage("DMDATA:BEGIN_FAIL:Invalid or unavailable dungeon.");
                return false;
            }
            for (Player* member : members)
            {
                if (member->GetLevel() < dg->MinLevel)
                {
                    char buf[256];
                    snprintf(buf, sizeof(buf), "DMDATA:BEGIN_FAIL:Player %s is too low level for this dungeon (requires %u).",
                        member->GetName().c_str(), dg->MinLevel);
                    h->SendSysMessage(buf);
                    return false;
                }
            }
        }
        else
        {
            auto dgs = sDMConfig->GetDungeonsForLevel(diff->MinLevel, diff->MaxLevel);
            std::vector<const DungeonInfo*> eligibleDungeons;
            for (const DungeonInfo* dg : dgs)
            {
                bool partyEligible = true;
                for (Player* member : members)
                {
                    if (member->GetLevel() < dg->MinLevel)
                    {
                        partyEligible = false;
                        break;
                    }
                }
                if (partyEligible)
                {
                    eligibleDungeons.push_back(dg);
                }
            }

            if (eligibleDungeons.empty())
            {
                h->SendSysMessage("DMDATA:BEGIN_FAIL:No dungeons available for your party's level range in this difficulty.");
                return false;
            }
            static thread_local std::mt19937 rng{ std::random_device{}() };
            dungeonIndex = eligibleDungeons[std::uniform_int_distribution<size_t>(0, eligibleDungeons.size()-1)(rng)]->Index;
        }

        Session* s = sDungeonMasterMgr->CreateSession(player, diffId, themeId, dungeonIndex, scaleParty);
        if (!s)
        {
            h->SendSysMessage("DMDATA:BEGIN_FAIL:Failed to create session.");
            return false;
        }

        if (!sDungeonMasterMgr->StartDungeon(s))
        {
            h->SendSysMessage("DMDATA:BEGIN_FAIL:Failed to initialize dungeon.");
            sDungeonMasterMgr->AbandonSession(s->SessionId);
            return false;
        }

        if (!sDungeonMasterMgr->TeleportPartyIn(s))
        {
            h->SendSysMessage("DMDATA:BEGIN_FAIL:Teleport failed.");
            sDungeonMasterMgr->AbandonSession(s->SessionId);
            return false;
        }

        if (sDMConfig->ShouldAnnounceCompletion())
        {
            const Theme* theme = sDMConfig->GetTheme(themeId);
            const DungeonInfo* dg = sDMConfig->GetDungeon(dungeonIndex);
            char announceBuf[256];
            snprintf(announceBuf, sizeof(announceBuf),
                "|cFF00FF00[Dungeon Master]|r |cFFFFFFFF%s|r started a |cFFFFD700%s|r |cFF00FFFF%s|r challenge!",
                player->GetName().c_str(), diff->Name.c_str(),
                theme ? theme->Name.c_str() : "Random");

            char detailBuf[256];
            snprintf(detailBuf, sizeof(detailBuf),
                "|cFFFFD700[Dungeon Master]|r Difficulty: |cFF00FF00%s|r  Theme: |cFF00FF00%s|r  Dungeon: |cFF00FF00%s|r  Scaling: |cFF00FF00%s|r",
                diff->Name.c_str(),
                theme ? theme->Name.c_str() : "Random",
                dg ? dg->Name.c_str() : "Random",
                scaleParty ? "Party Level" : "Dungeon Difficulty");

            for (const auto& pd : s->Players)
            {
                if (Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid))
                {
                    ChatHandler(p->GetSession()).SendSysMessage(announceBuf);
                    ChatHandler(p->GetSession()).SendSysMessage(detailBuf);
                }
            }
        }

        h->SendSysMessage("DMDATA:BEGIN_OK");
        return true;
    }

    static bool HandleRoguelike(ChatHandler* h, Tail args)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        std::string argsStr(args);
        if (argsStr.empty())
        {
            h->SendSysMessage("DMDATA:RL_FAIL:Missing arguments. Usage: .dm roguelike <diffId> <scaleParty> <themeId>");
            return false;
        }

        uint32 diffId = 0;
        uint32 scalePartyInt = 0;
        uint32 themeId = 0;

        if (sscanf(argsStr.c_str(), "%u %u %u", &diffId, &scalePartyInt, &themeId) < 3)
        {
            h->SendSysMessage("DMDATA:RL_FAIL:Invalid argument format. Usage: .dm roguelike <diffId> <scaleParty> <themeId>");
            return false;
        }

        bool scaleParty = (scalePartyInt != 0);

        if (!sDMConfig->IsEnabled() || !sDMConfig->IsRoguelikeEnabled())
        {
            h->SendSysMessage("DMDATA:RL_FAIL:Roguelike system is disabled.");
            return false;
        }

        ObjectGuid guid = player->GetGUID();

        if (sDungeonMasterMgr->GetSessionByPlayer(guid))
        {
            h->SendSysMessage("DMDATA:RL_FAIL:You are already in an active challenge session.");
            return false;
        }

        if (sRoguelikeMgr->IsPlayerInRun(guid))
        {
            h->SendSysMessage("DMDATA:RL_FAIL:You are already in a Roguelike run.");
            return false;
        }

        std::vector<Player*> members;
        if (Group* g = player->GetGroup())
        {
            for (GroupReference* ref = g->GetFirstMember(); ref; ref = ref->next())
            {
                if (Player* m = ref->GetSource())
                    members.push_back(m);
            }
        }
        else
        {
            members.push_back(player);
        }

        for (Player* member : members)
        {
            if (sDungeonMasterMgr->IsOnCooldown(member->GetGUID()))
            {
                char buf[256];
                snprintf(buf, sizeof(buf), "DMDATA:RL_FAIL:Player %s is on cooldown for %u seconds.",
                    member->GetName().c_str(), sDungeonMasterMgr->GetRemainingCooldown(member->GetGUID()));
                h->SendSysMessage(buf);
                return false;
            }
        }

        const DifficultyTier* diff = sDMConfig->GetDifficulty(diffId);
        if (!diff)
        {
            h->SendSysMessage("DMDATA:RL_FAIL:Invalid difficulty ID.");
            return false;
        }

        for (Player* member : members)
        {
            if (!diff->IsValidForLevel(member->GetLevel()))
            {
                char buf[256];
                snprintf(buf, sizeof(buf), "DMDATA:RL_FAIL:Player %s does not meet the level requirement (%u) for this difficulty.",
                    member->GetName().c_str(), diff->MinLevel);
                h->SendSysMessage(buf);
                return false;
            }
        }

        if (!sRoguelikeMgr->StartRun(player, diffId, themeId, scaleParty))
        {
            h->SendSysMessage("DMDATA:RL_FAIL:Failed to start roguelike run.");
            return false;
        }

        h->SendSysMessage("DMDATA:RL_OK");
        return true;
    }

    static bool HandleMyStats(ChatHandler* h)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        ObjectGuid guid = player->GetGUID();
        uint32 guidLow = guid.GetCounter();
        PlayerStats ns = sDungeonMasterMgr->GetPlayerStats(guid);
        RoguelikePlayerStats rs = sRoguelikeMgr->GetRoguelikePlayerStats(guid);

        char buf[256];
        snprintf(buf, sizeof(buf), "DMDATA:NSTATS:%u,%u,%u,%u,%u,%u,%u",
            ns.TotalRuns, ns.CompletedRuns, ns.FailedRuns, ns.TotalMobsKilled, ns.TotalBossesKilled, ns.TotalDeaths, ns.FastestClear);
        h->SendSysMessage(buf);

        snprintf(buf, sizeof(buf), "DMDATA:RLSTATS:%u,%u,%u,%u,%u,%u,%u,%u,%u",
            rs.TotalRuns, rs.HighestTier, rs.MostFloorsCleared, rs.TotalFloorsCleared, rs.TotalMobsKilled, rs.TotalBossesKilled, rs.TotalDeaths, rs.LongestRunTime, rs.KnownAffixMask);
        h->SendSysMessage(buf);

        // Send Bestiary Meta
        const auto* metaMap = sDungeonMasterMgr->GetPlayerBestiaryMetaMap(guidLow);
        if (metaMap)
        {
            for (const auto& [mapId, entry] : *metaMap)
            {
                snprintf(buf, sizeof(buf), "DMDATA:BESTIARY_META:%u,%u,%u,%u,%u,%u",
                    mapId, entry.BossEncountered ? 1 : 0, entry.BossBeaten ? 1 : 0,
                    entry.TotalKills, entry.RunsStarted, entry.RunsCompleted);
                h->SendSysMessage(buf);
            }
        }

        // Send Bestiary Details
        const auto* bestiaryMap = sDungeonMasterMgr->GetPlayerBestiaryMap(guidLow);
        if (bestiaryMap)
        {
            for (const auto& [mapId, innerMap] : *bestiaryMap)
            {
                for (const auto& [creatureType, killCount] : innerMap)
                {
                    snprintf(buf, sizeof(buf), "DMDATA:BESTIARY:%u,%u,%u",
                        mapId, creatureType, killCount);
                    h->SendSysMessage(buf);
                }
            }
        }

        // Send Affix Familiarity
        const auto* familiarityMap = sDungeonMasterMgr->GetPlayerFamiliarityMap(guidLow);
        if (familiarityMap)
        {
            for (const auto& [affixId, entry] : *familiarityMap)
            {
                snprintf(buf, sizeof(buf), "DMDATA:FAMILIARITY:%u,%u,%f",
                    affixId, entry.Encounters, entry.ResistancePct);
                h->SendSysMessage(buf);
            }
        }

        // Send Configuration limits
        snprintf(buf, sizeof(buf), "DMDATA:CONFIG:%u,%u,%u,%f,%u",
            sDMConfig->GetBestiaryTier1Kills(),
            sDMConfig->GetBestiaryTier2Kills(),
            sDMConfig->GetBestiaryTier3Kills(),
            sDMConfig->GetRoguelikeMaxFamiliarityPct(),
            sDMConfig->GetRoguelikeRevealAffixTier());
        h->SendSysMessage(buf);

        // Send Player Mastery and Personal Bests
        sDungeonMasterMgr->SendPlayerMastery(player);
        sDungeonMasterMgr->SendPlayerPersonalBests(player);

        h->SendSysMessage("DMDATA:STATS_END");
        return true;
    }

    static bool HandleBoards(ChatHandler* h, Tail args)
    {
        std::string boardType(args);
        if (boardType.empty())
        {
            h->SendSysMessage("Usage: .dm boards <normal|rltier|rlfloors>");
            return false;
        }

        char buf[256];

        if (boardType == "normal")
        {
            auto entries = sDungeonMasterMgr->GetOverallLeaderboard(10);
            for (const auto& entry : entries)
            {
                snprintf(buf, sizeof(buf), "DMDATA:NBOARD:%u,%s,%u,%u,%u,%u,%u",
                    entry.Id, entry.CharName.c_str(), entry.ClearTime, entry.MapId, entry.DifficultyId, entry.PartySize, entry.Scaled ? 1 : 0);
                h->SendSysMessage(buf);
            }
        }
        else if (boardType == "rltier" || boardType == "rlfloors")
        {
            bool sortByFloors = (boardType == "rlfloors");
            auto entries = sRoguelikeMgr->GetRoguelikeLeaderboard(10, sortByFloors);
            uint32 rank = 1;
            for (const auto& entry : entries)
            {
                snprintf(buf, sizeof(buf), "DMDATA:%s:%u,%s,%u,%u,%u,%u,%u",
                    sortByFloors ? "RFBOARD" : "RTBOARD",
                    rank++, entry.CharName.c_str(), entry.TierReached, entry.DungeonsCleared, entry.RunDuration, entry.TotalKills, entry.PartySize);
                h->SendSysMessage(buf);
            }
        }
        else
        {
            h->SendSysMessage("Invalid board type. Use 'normal', 'rltier', or 'rlfloors'.");
            return false;
        }

        h->SendSysMessage("DMDATA:BOARD_END");
        return true;
    }

    static bool HandleRLQuit(ChatHandler* h)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        ObjectGuid guid = player->GetGUID();
        if (!sRoguelikeMgr->IsPlayerInRun(guid))
        {
            h->SendSysMessage("DMDATA:RLQUIT_FAIL:You are not in a Roguelike run.");
            return false;
        }

        if (RoguelikeRun* run = sRoguelikeMgr->GetRunByPlayer(guid))
        {
            if (run->CurrentSessionId != 0)
            {
                if (Session* session = sDungeonMasterMgr->GetSession(run->CurrentSessionId))
                {
                    if (session->State == SessionState::Completed)
                    {
                        sRoguelikeMgr->FinalizeCompletedFloor(run->RunId);
                    }
                }
            }
        }

        sRoguelikeMgr->QuitRun(guid);
        h->SendSysMessage("DMDATA:RLQUIT_OK");
        return true;
    }

    static bool HandleRLAdvance(ChatHandler* h)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        ObjectGuid guid = player->GetGUID();
        if (!sRoguelikeMgr->IsPlayerInRun(guid))
        {
            h->SendSysMessage("DMDATA:RLADVANCE_FAIL:You are not in a Roguelike run.");
            return false;
        }

        RoguelikeRun* run = sRoguelikeMgr->GetRunByPlayer(guid);
        if (!run || run->CurrentSessionId == 0)
        {
            h->SendSysMessage("DMDATA:RLADVANCE_FAIL:No active session.");
            return false;
        }

        Session* session = sDungeonMasterMgr->GetSession(run->CurrentSessionId);
        if (!session || session->State != SessionState::Completed)
        {
            h->SendSysMessage("DMDATA:RLADVANCE_FAIL:Dungeon is not completed yet.");
            return false;
        }

        sRoguelikeMgr->OnDungeonCompleted(run->RunId, session->SessionId);
        h->SendSysMessage("DMDATA:RLADVANCE_OK");
        return true;
    }

    static bool HandleResetBoss(ChatHandler* h)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        std::string errReason;
        if (sDungeonMasterMgr->ResetActiveBoss(player->GetGUID(), errReason))
        {
            h->SendSysMessage("DMDATA:RESETBOSS_OK");
        }
        else
        {
            char buf[256];
            snprintf(buf, sizeof(buf), "DMDATA:RESETBOSS_FAIL:%s", errReason.c_str());
            h->SendSysMessage(buf);
        }
        return true;
    }

    static bool HandleRejoin(ChatHandler* h)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        Session* s = sDungeonMasterMgr->GetSessionByPlayer(player->GetGUID());
        if (!s || !s->IsActive())
        {
            h->SendSysMessage("DMDATA:REJOIN_FAIL:You do not have an active Dungeon Master challenge to rejoin.");
            return false;
        }

        // ── Restore group if disbanded ──
        Group* existingGroup = nullptr;
        for (const auto& pd : s->Players)
        {
            Player* mate = ObjectAccessor::FindPlayer(pd.PlayerGuid);
            if (mate && mate->GetGroup())
            {
                existingGroup = mate->GetGroup();
                break;
            }
        }

        if (existingGroup)
        {
            if (player->GetGroup() != existingGroup)
            {
                if (player->GetGroup())
                {
                    player->RemoveFromGroup();
                }

                // If the group is full (e.g. because of NPCBots), dismiss bots to make room
                while (existingGroup->IsFull())
                {
                    GroupBotReference* bRef = existingGroup->GetFirstBotMember();
                    if (!bRef)
                        break; // No bots left to remove

                    Creature* bot = bRef->GetSource();
                    if (!bot)
                        break;

                    existingGroup->RemoveMember(bot->GetGUID(), GROUP_REMOVEMETHOD_KICK);
                }

                existingGroup->AddMember(player);
                LOG_INFO("module", "DungeonMaster: Rejoin cmd – added player {} to existing group (leader: {})",
                    player->GetName(), existingGroup->GetLeaderName());
            }
        }
        else
        {
            // No existing group – create a new one if player is not in a group
            if (!player->GetGroup())
            {
                Group* newGroup = new Group;
                if (newGroup->Create(player))
                {
                    sGroupMgr->AddGroup(newGroup);
                    LOG_INFO("module", "DungeonMaster: Rejoin cmd – created new group for player {}",
                        player->GetName());
                }
                else
                {
                    delete newGroup;
                    LOG_ERROR("module", "DungeonMaster: Rejoin cmd – failed to create group for player {}",
                        player->GetName());
                }
            }
        }

        // ── Bind player to the session's instance ──
        if (s->InstanceId != 0)
        {
            InstanceSave* save = sInstanceSaveMgr->GetInstanceSave(s->InstanceId);
            if (save)
            {
                sInstanceSaveMgr->PlayerBindToInstance(player->GetGUID(), save, false, player);
                LOG_INFO("module", "DungeonMaster: Rejoin cmd – bound player {} to instance {} (map {})",
                    player->GetName(), s->InstanceId, s->MapId);
            }
            else
            {
                LOG_WARN("module", "DungeonMaster: Rejoin cmd – instance save {} not found for player {}",
                    s->InstanceId, player->GetName());
                h->SendSysMessage("DMDATA:REJOIN_FAIL:Dungeon instance no longer exists.");
                return false;
            }
        }

        // ── Teleport to the dungeon entrance ──
        player->TeleportTo(s->MapId, s->EntrancePos.GetPositionX(), s->EntrancePos.GetPositionY(), s->EntrancePos.GetPositionZ(), s->EntrancePos.GetOrientation());
        h->SendSysMessage("DMDATA:REJOIN_OK");
        return true;
    }

    static bool HandleRLBuyMastery(ChatHandler* h, Tail args)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        std::string argsStr(args);
        uint32 perkId = 999;
        if (sscanf(argsStr.c_str(), "%u", &perkId) < 1)
        {
            h->SendSysMessage("DMDATA:RLBUYMASTERY_FAIL:Invalid format. Usage: .dm rlbuymastery <perkId>");
            return false;
        }

        if (perkId > 4)
        {
            h->SendSysMessage("DMDATA:RLBUYMASTERY_FAIL:Invalid perk ID. Perk IDs: Scout = 0, Veteran = 1, Pathfinder = 2, Gladiator = 3, Survivor = 4.");
            return false;
        }

        uint32 guidLow = player->GetGUID().GetCounter();
        if (sDungeonMasterMgr->BuyMasteryPerk(guidLow, perkId))
        {
            h->SendSysMessage("DMDATA:RLBUYMASTERY_OK");
            sDungeonMasterMgr->SendPlayerMastery(player);
            return true;
        }
        else
        {
            h->SendSysMessage("DMDATA:RLBUYMASTERY_FAIL:Failed to purchase mastery perk. Check your mastery points or if you already own this perk.");
            return false;
        }
    }

    static bool HandleRLSelect(ChatHandler* h, Tail args)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        ObjectGuid guid = player->GetGUID();
        RoguelikeRun* run = sRoguelikeMgr->GetRunByPlayer(guid);
        if (!run)
        {
            h->SendSysMessage("DMDATA:RLSELECT_FAIL:You are not in a Roguelike run.");
            return false;
        }

        if (run->LeaderGuid != guid)
        {
            h->SendSysMessage("DMDATA:RLSELECT_FAIL:Only the party leader can select branching paths.");
            return false;
        }

        if (!run->AwaitingBranchSelection)
        {
            h->SendSysMessage("DMDATA:RLSELECT_FAIL:Not currently choosing branching paths.");
            return false;
        }

        std::string argsStr(args);
        uint32 dungeonIndexParam = 0;
        uint32 themeIdParam = 0;
        if (sscanf(argsStr.c_str(), "%u %u", &dungeonIndexParam, &themeIdParam) < 2)
        {
            h->SendSysMessage("DMDATA:RLSELECT_FAIL:Invalid select format. Usage: .dm rlselect <dungeonIndex> <themeId>");
            return false;
        }

        uint32 dungeonIndex = dungeonIndexParam - 1;

        bool validSelection = false;
        uint32 actualThemeId = 0;
        for (const auto& opt : run->BranchChoices)
        {
            if (opt.DungeonIndex == dungeonIndex)
            {
                validSelection = true;
                actualThemeId = opt.ThemeId;
                break;
            }
        }

        if (!validSelection)
        {
            h->SendSysMessage("DMDATA:RLSELECT_FAIL:Invalid branch choice selection.");
            return false;
        }

        run->AwaitingBranchSelection = false;
        run->BranchChoices.clear();

        if (!sRoguelikeMgr->TransitionToNextDungeon(*run, dungeonIndex, actualThemeId))
        {
            h->SendSysMessage("DMDATA:RLSELECT_FAIL:Failed to transition to the next dungeon floor.");
            return false;
        }

        h->SendSysMessage("DMDATA:RLSELECT_OK");
        return true;
    }

    static bool HandleRLToggleGambit(ChatHandler* h, Tail args)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        if (!sDMConfig->IsEnabled() || !sDMConfig->IsGambitsEnabled())
        {
            h->SendSysMessage("DMDATA:RLGAMBIT_FAIL:Gambits system is disabled.");
            return false;
        }

        Session* session = sDungeonMasterMgr->GetSessionByPlayer(player->GetGUID());
        if (!session)
        {
            h->SendSysMessage("DMDATA:RLGAMBIT_FAIL:You are not in an active challenge session.");
            return false;
        }

        if (session->LeaderGuid != player->GetGUID())
        {
            h->SendSysMessage("DMDATA:RLGAMBIT_FAIL:Only the party leader can toggle Gambits.");
            return false;
        }

        if (session->State != SessionState::Preparing)
        {
            h->SendSysMessage("DMDATA:RLGAMBIT_FAIL:Gambits can only be configured during the preparation phase.");
            return false;
        }

        std::string argsStr(args);
        uint32 gambitId = 0;
        if (sscanf(argsStr.c_str(), "%u", &gambitId) < 1)
        {
            h->SendSysMessage("DMDATA:RLGAMBIT_FAIL:Usage: .dm rltogglegambit <gambitId>");
            return false;
        }

        bool* targetGambit = nullptr;
        std::string gambitName;
        if (gambitId == 1) { targetGambit = &session->GambitTimeTrial; gambitName = "Time Trial"; }
        else if (gambitId == 2) { targetGambit = &session->GambitGlassCannon; gambitName = "Glass Cannon"; }
        else if (gambitId == 3) { targetGambit = &session->GambitPacifist; gambitName = "Pacifist"; }
        else
        {
            h->SendSysMessage("DMDATA:RLGAMBIT_FAIL:Invalid Gambit ID. Valid IDs: 1 (Time Trial), 2 (Glass Cannon), 3 (Pacifist)");
            return false;
        }

        bool newState = !(*targetGambit);

        if (newState)
        {
            uint32 activeCount = 0;
            if (session->GambitTimeTrial) activeCount++;
            if (session->GambitGlassCannon) activeCount++;
            if (session->GambitPacifist) activeCount++;

            if (activeCount >= sDMConfig->GetGambitsMaxPerFloor())
            {
                char limitBuf[128];
                snprintf(limitBuf, sizeof(limitBuf), "DMDATA:RLGAMBIT_FAIL:You can only activate up to %u Gambits per floor.",
                    sDMConfig->GetGambitsMaxPerFloor());
                h->SendSysMessage(limitBuf);
                return false;
            }
        }

        *targetGambit = newState;

        if (session->GambitTimeTrial)
        {
            session->TimeLimit = sDMConfig->GetGambitsTimeTrialMinutes() * 60;
        }
        else if (sDMConfig->IsTimeLimitEnabled())
        {
            session->TimeLimit = sDMConfig->GetTimeLimitMinutes() * 60;
        }
        else
        {
            session->TimeLimit = 0;
        }

        char announceBuf[256];
        snprintf(announceBuf, sizeof(announceBuf),
            "|cFF00FFFF[Roguelike]|r Gambit |cFFFFD700%s|r has been %s by the leader.",
            gambitName.c_str(), newState ? "|cFF00FF00ACTIVATED|r" : "|cFFFF0000DEACTIVATED|r");
        
        for (const auto& pd : session->Players)
            if (Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid))
                ChatHandler(p->GetSession()).SendSysMessage(announceBuf);

        sDungeonMasterMgr->SendSessionUpdateToPlayers(session);
        return true;
    }

    static bool HandleRLVeto(ChatHandler* h, Tail args)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        Session* session = sDungeonMasterMgr->GetSessionByPlayer(player->GetGUID());
        if (!session || session->RoguelikeRunId == 0)
        {
            h->SendSysMessage("DMDATA:RLVETO_FAIL:You are not in an active Roguelike session.");
            return false;
        }

        if (session->State != SessionState::Preparing)
        {
            h->SendSysMessage("DMDATA:RLVETO_FAIL:Vetoes can only be applied during the preparation phase.");
            return false;
        }

        RoguelikeRun* run = sRoguelikeMgr->GetRun(session->RoguelikeRunId);
        if (!run)
        {
            h->SendSysMessage("DMDATA:RLVETO_FAIL:Roguelike run not found.");
            return false;
        }

        std::string argsStr(args);
        uint32 affixId = 0;
        if (sscanf(argsStr.c_str(), "%u", &affixId) < 1)
        {
            h->SendSysMessage("DMDATA:RLVETO_FAIL:Usage: .dm rlveto <affixId>");
            return false;
        }

        auto it = std::find(run->ActiveAffixes.begin(), run->ActiveAffixes.end(), static_cast<RoguelikeAffix>(affixId));
        if (it == run->ActiveAffixes.end())
        {
            h->SendSysMessage("DMDATA:RLVETO_FAIL:Selected affix is not active on this floor.");
            return false;
        }

        if (!sRoguelikeMgr->ConsumeVetoToken(player->GetGUID()))
        {
            h->SendSysMessage("DMDATA:RLVETO_FAIL:You do not have any Veto Tokens.");
            return false;
        }

        std::string newAffixName;
        if (!sRoguelikeMgr->VetoAffixForRun(run->RunId, affixId, newAffixName))
        {
            h->SendSysMessage("DMDATA:RLVETO_FAIL:Failed to veto affix.");
            return false;
        }

        char announceBuf[256];
        snprintf(announceBuf, sizeof(announceBuf),
            "|cFF00FFFF[Roguelike]|r |cFFFFFFFF%s|r vetoed an affix! Rolled new affix: |cFFFF8800%s|r.",
            player->GetName().c_str(), newAffixName.c_str());
        
        for (const auto& pd : session->Players)
            if (Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid))
                ChatHandler(p->GetSession()).SendSysMessage(announceBuf);

        // Resend active affixes and flags update to players
        std::string affList;
        for (RoguelikeAffix afxId : run->ActiveAffixes)
        {
            if (!affList.empty()) affList += ",";
            affList += std::to_string(afxId);
        }
        char affBuf[256];
        snprintf(affBuf, sizeof(affBuf), "DMDATA:ACTIVE_AFFIXES:%s", affList.c_str());
        
        for (const auto& pd : session->Players)
        {
            if (Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid))
            {
                if (p->GetSession())
                {
                    ChatHandler(p->GetSession()).SendSysMessage(affBuf);
                }
            }
        }

        sDungeonMasterMgr->SendSessionUpdateToPlayers(session);
        return true;
    }

    static bool HandleRLStart(ChatHandler* h)
    {
        Player* player = h->GetSession() ? h->GetSession()->GetPlayer() : nullptr;
        if (!player)
        {
            h->SendSysMessage("In-game only.");
            return false;
        }

        Session* session = sDungeonMasterMgr->GetSessionByPlayer(player->GetGUID());
        if (!session || session->RoguelikeRunId == 0)
        {
            h->SendSysMessage("DMDATA:RLSTART_FAIL:You are not in an active Roguelike session.");
            return false;
        }

        if (session->LeaderGuid != player->GetGUID())
        {
            h->SendSysMessage("DMDATA:RLSTART_FAIL:Only the party leader can start the challenge early.");
            return false;
        }

        if (session->State != SessionState::Preparing)
        {
            h->SendSysMessage("DMDATA:RLSTART_FAIL:Challenge has already started.");
            return false;
        }

        // Start immediately by ending countdown
        session->PreparationTimer = 0;
        session->State = SessionState::InProgress;
        session->StartTime = GameTime::GetGameTime().count(); // Reset start time so speed run is accurate!

        for (const auto& pd : session->Players)
            if (Player* p = ObjectAccessor::FindPlayer(pd.PlayerGuid))
                ChatHandler(p->GetSession()).SendSysMessage(
                    "|cFF00FF00[Roguelike]|r The leader started the challenge! Good luck!");

        sDungeonMasterMgr->SendSessionUpdateToPlayers(session);
        return true;
    }
};

void AddSC_dm_command_script()
{
    new dm_command_script();
}

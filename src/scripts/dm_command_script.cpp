/*
 * mod-dungeon-master — dm_command_script.cpp
 * Player & GM commands: .dm reload, .dm status, .dm list, .dm end, .dm clearcooldown, .dm query, .dm begin, .dm roguelike, .dm mystats, .dm boards, .dm rlquit
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "ChatCommand.h"
#include "Player.h"
#include "Group.h"
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
            { "resetboss",     HandleResetBoss,     SEC_PLAYER,         Console::No  },
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
            h->SendSysMessage("You are not in a Dungeon Master challenge.");
            return false;
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
            snprintf(buf, sizeof(buf), "DMDATA:DIFF:%u,%s,%u,%u",
                diff.Id, diff.Name.c_str(), diff.MinLevel, diff.MaxLevel);
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
                snprintf(buf, sizeof(buf), "DMDATA:DNG:%u,%s,%u,%u",
                    dg.MapId, dg.Name.c_str(), dg.MinLevel, dg.MaxLevel);
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

        snprintf(buf, sizeof(buf), "DMDATA:FLAGS:%u,%u,%u,%u,%u,%u,%u,%u",
            sDMConfig->IsEnabled() ? 1 : 0,
            sDMConfig->IsRoguelikeEnabled() ? 1 : 0,
            cooldownRem,
            inSession ? 1 : 0,
            inRoguelike ? 1 : 0,
            player->GetLevel(),
            rlTier,
            rlFloors);
        h->SendSysMessage(buf);

        if (inSession && s)
        {
            std::string bossName;
            float bx = 0.0f, by = 0.0f;
            sDungeonMasterMgr->GetActiveBossInfo(player->GetGUID(), bossName, bx, by);
            uint32 bossResetCd = sDungeonMasterMgr->GetRemainingBossResetCooldown(player->GetGUID());
            uint64 elapsed = GameTime::GetGameTime().count() - s->StartTime;

            snprintf(buf, sizeof(buf), "DMDATA:RUNINFO:%llu,%s,%.1f,%.1f,%u",
                (unsigned long long)elapsed, bossName.c_str(), bx, by, bossResetCd);
            h->SendSysMessage(buf);
        }

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
        uint32 mapId = 0;

        if (sscanf(argsStr.c_str(), "%u %u %u %u", &diffId, &scalePartyInt, &themeId, &mapId) < 4)
        {
            h->SendSysMessage("DMDATA:BEGIN_FAIL:Invalid argument format. Usage: .dm begin <diffId> <scaleParty> <themeId> <mapId>");
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

        if (sDungeonMasterMgr->IsOnCooldown(guid))
        {
            char buf[128];
            snprintf(buf, sizeof(buf), "DMDATA:BEGIN_FAIL:Challenge is on cooldown for %u seconds.",
                sDungeonMasterMgr->GetRemainingCooldown(guid));
            h->SendSysMessage(buf);
            return false;
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

        if (!diff->IsValidForLevel(player->GetLevel()))
        {
            h->SendSysMessage("DMDATA:BEGIN_FAIL:Level requirement not met for this difficulty.");
            return false;
        }

        if (mapId > 0)
        {
            const DungeonInfo* dg = sDMConfig->GetDungeon(mapId);
            if (!dg || !dg->IsAvailable)
            {
                h->SendSysMessage("DMDATA:BEGIN_FAIL:Invalid or unavailable dungeon.");
                return false;
            }
            if (player->GetLevel() < dg->MinLevel)
            {
                h->SendSysMessage("DMDATA:BEGIN_FAIL:Level too low for this dungeon.");
                return false;
            }
        }
        else
        {
            auto dgs = sDMConfig->GetDungeonsForLevel(diff->MinLevel, diff->MaxLevel);
            if (dgs.empty())
            {
                h->SendSysMessage("DMDATA:BEGIN_FAIL:No dungeons available for this difficulty level range.");
                return false;
            }
            static thread_local std::mt19937 rng{ std::random_device{}() };
            mapId = dgs[std::uniform_int_distribution<size_t>(0, dgs.size()-1)(rng)]->MapId;
        }

        Session* s = sDungeonMasterMgr->CreateSession(player, diffId, themeId, mapId, scaleParty);
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
            const DungeonInfo* dg = sDMConfig->GetDungeon(mapId);
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

        if (sDungeonMasterMgr->IsOnCooldown(guid))
        {
            char buf[128];
            snprintf(buf, sizeof(buf), "DMDATA:RL_FAIL:Challenge is on cooldown for %u seconds.",
                sDungeonMasterMgr->GetRemainingCooldown(guid));
            h->SendSysMessage(buf);
            return false;
        }

        const DifficultyTier* diff = sDMConfig->GetDifficulty(diffId);
        if (!diff)
        {
            h->SendSysMessage("DMDATA:RL_FAIL:Invalid difficulty ID.");
            return false;
        }

        if (!diff->IsValidForLevel(player->GetLevel()))
        {
            h->SendSysMessage("DMDATA:RL_FAIL:Level requirement not met for this difficulty.");
            return false;
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
        PlayerStats ns = sDungeonMasterMgr->GetPlayerStats(guid);
        RoguelikePlayerStats rs = sRoguelikeMgr->GetRoguelikePlayerStats(guid);

        char buf[256];
        snprintf(buf, sizeof(buf), "DMDATA:NSTATS:%u,%u,%u,%u,%u,%u,%u",
            ns.TotalRuns, ns.CompletedRuns, ns.FailedRuns, ns.TotalMobsKilled, ns.TotalBossesKilled, ns.TotalDeaths, ns.FastestClear);
        h->SendSysMessage(buf);

        snprintf(buf, sizeof(buf), "DMDATA:RLSTATS:%u,%u,%u,%u,%u,%u,%u,%u",
            rs.TotalRuns, rs.HighestTier, rs.MostFloorsCleared, rs.TotalFloorsCleared, rs.TotalMobsKilled, rs.TotalBossesKilled, rs.TotalDeaths, rs.LongestRunTime);
        h->SendSysMessage(buf);

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

        sRoguelikeMgr->QuitRun(guid);
        h->SendSysMessage("DMDATA:RLQUIT_OK");
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
};

void AddSC_dm_command_script()
{
    new dm_command_script();
}

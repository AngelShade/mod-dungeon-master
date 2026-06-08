/*
 * mod-dungeon-master — dm_player_script.cpp
 * Player death handling: blocks spirit release, checks for wipe.
 * Login handling: redirects player to homebind if they logged out in DM map without active session.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "DungeonMasterMgr.h"
#include "DMConfig.h"
#include "RoguelikeMgr.h"
#include "RoguelikeTypes.h"
#include "Chat.h"
#include "MapMgr.h"
#include <unordered_set>

using namespace DungeonMaster;

class dm_player_script : public PlayerScript
{
public:
    dm_player_script() : PlayerScript("dm_player_script") {}

    void OnPlayerLoadFromDB(Player* player) override
    {
        if (!sDMConfig->IsEnabled() || !player)
            return;

        // Check if player's DB map is a Dungeon Master map
        if (sDMConfig->GetDungeon(player->GetMapId()) == nullptr)
            return;

        // Check if they have an active session or roguelike run in memory
        Session* session = sDungeonMasterMgr->GetSessionByPlayer(player->GetGUID());
        bool hasActiveSession = session && session->IsActive();
        bool hasActiveRun = sRoguelikeMgr->IsPlayerInRun(player->GetGUID());

        if (!hasActiveSession && !hasActiveRun)
        {
            // Remember they were relocated
            _relocatedPlayers.insert(player->GetGUID());

            // Check if they are dead in DB loaded representation
            if (!player->IsAlive())
            {
                _relocatedDeadPlayers.insert(player->GetGUID());
            }

            // Relocate player to homebind
            player->Relocate(player->m_homebindX, player->m_homebindY, player->m_homebindZ, player->GetOrientation());

            Map* homebindMap = sMapMgr->CreateMap(player->m_homebindMapId, player);
            if (homebindMap)
            {
                player->ResetMap();
                player->SetMap(homebindMap);
                player->UpdatePositionData();
            }

            LOG_INFO("module", "DungeonMaster: Relocated player {} to homebind map {} during database load to prevent login teleport crashes",
                player->GetName(), player->m_homebindMapId);
        }
    }

    void OnPlayerLogin(Player* player) override
    {
        if (!sDMConfig->IsEnabled() || !player)
            return;

        auto it = _relocatedPlayers.find(player->GetGUID());
        if (it != _relocatedPlayers.end())
        {
            _relocatedPlayers.erase(it);

            // Resurrect if they were relocated dead
            auto deadIt = _relocatedDeadPlayers.find(player->GetGUID());
            if (deadIt != _relocatedDeadPlayers.end())
            {
                _relocatedDeadPlayers.erase(deadIt);
                
                player->RemoveFlag(PLAYER_FIELD_BYTES, PLAYER_FIELD_BYTE_NO_RELEASE_WINDOW);
                if (!player->IsAlive())
                {
                    player->ResurrectPlayer(1.0f);
                    player->SpawnCorpseBones();
                }
            }

            if (player->GetSession())
            {
                ChatHandler(player->GetSession()).SendSysMessage(
                    "|cFFFF0000[Dungeon Master]|r Your challenge session has ended. Returning you to your homebind location.");
            }
        }
    }

    void OnPlayerKilledByCreature(Creature* /*killer*/, Player* player) override
    {
        if (!sDMConfig->IsEnabled() || !player)
            return;

        Session* session = sDungeonMasterMgr->GetSessionByPlayer(player->GetGUID());
        if (!session || !session->IsActive())
            return;

        if (player->GetMapId() != session->MapId)
            return;

        sDungeonMasterMgr->HandlePlayerDeath(player, session);
    }

private:
    static std::unordered_set<ObjectGuid> _relocatedPlayers;
    static std::unordered_set<ObjectGuid> _relocatedDeadPlayers;
};

// Initialize static member variables
std::unordered_set<ObjectGuid> dm_player_script::_relocatedPlayers;
std::unordered_set<ObjectGuid> dm_player_script::_relocatedDeadPlayers;

void AddSC_dm_player_script()
{
    new dm_player_script();
}

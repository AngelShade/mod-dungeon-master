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
#include "DatabaseEnv.h"
#include "Group.h"
#include "GroupMgr.h"
#include "InstanceSaveMgr.h"
#include "ObjectAccessor.h"
#include <unordered_set>

using namespace DungeonMaster;

class dm_player_script : public PlayerScript
{
public:
    dm_player_script() : PlayerScript("dm_player_script") {}

    void OnLoadFromDB(Player* player) override
    {
        if (!sDMConfig->IsEnabled() || !player)
            return;

        // Check if player's DB map is a Dungeon Master map
        if (!sDMConfig->IsDungeonMap(player->GetMapId()))
            return;

        // Check if they have an active session or roguelike run in memory
        Session* session = sDungeonMasterMgr->GetSessionByPlayer(player->GetGUID());
        bool hasActiveSession = session && session->IsActive();
        bool hasActiveRun = sRoguelikeMgr->IsPlayerInRun(player->GetGUID());

        if (hasActiveSession)
        {
            // ── REJOIN: Restore group if disbanded on logout ──
            Group* existingGroup = nullptr;
            for (const auto& pd : session->Players)
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
                    LOG_INFO("module", "DungeonMaster: Rejoin – added player {} to existing group (leader: {})",
                        player->GetName(), existingGroup->GetLeaderName());
                }
            }
            else
            {
                // No existing group found – create a new one for the player if they are not in a group
                if (!player->GetGroup())
                {
                    Group* newGroup = new Group;
                    if (newGroup->Create(player))
                    {
                        sGroupMgr->AddGroup(newGroup);
                        LOG_INFO("module", "DungeonMaster: Rejoin – created new group for player {}",
                            player->GetName());
                    }
                    else
                    {
                        delete newGroup;
                        LOG_ERROR("module", "DungeonMaster: Rejoin – failed to create group for player {}",
                            player->GetName());
                    }
                }
            }

            // ── REJOIN: Bind player to the session's instance ──
            if (session->InstanceId != 0)
            {
                InstanceSave* save = sInstanceSaveMgr->GetInstanceSave(session->InstanceId);
                if (save)
                {
                    sInstanceSaveMgr->PlayerBindToInstance(player->GetGUID(), save, false, player);
                    LOG_INFO("module", "DungeonMaster: Rejoin – bound player {} to instance {} (map {})",
                        player->GetName(), session->InstanceId, session->MapId);
                }
                else
                {
                    LOG_WARN("module", "DungeonMaster: Rejoin – instance save {} not found for player {}",
                        session->InstanceId, player->GetName());
                }
            }
        }
        else if (!hasActiveRun)
        {
            // Remember they were relocated
            _relocatedPlayers.insert(player->GetGUID());

            // Check if they are dead in DB loaded representation
            if (!player->IsAlive())
            {
                _relocatedDeadPlayers.insert(player->GetGUID());
            }

            // Check if there is a saved return position in Character DB
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

                player->Relocate(px, py, pz, po);
                Map* targetMap = sMapMgr->CreateMap(mapId, player);
                if (targetMap)
                {
                    player->ResetMap();
                    player->SetMap(targetMap);
                    player->UpdatePositionData();
                }

                _relocatedToSavedPlayers.insert(player->GetGUID());

                char delQuery[256];
                snprintf(delQuery, sizeof(delQuery), "DELETE FROM `dm_player_return_position` WHERE `guid` = %u", player->GetGUID().GetCounter());
                CharacterDatabase.Execute(delQuery);

                LOG_INFO("module", "DungeonMaster: Relocated player {} to saved return position (map {}) during database load",
                    player->GetName(), mapId);
            }
            else
            {
                // Relocate player to homebind (fallback)
                player->Relocate(player->m_homebindX, player->m_homebindY, player->m_homebindZ, player->GetOrientation());

                Map* homebindMap = sMapMgr->CreateMap(player->m_homebindMapId, player);
                if (homebindMap)
                {
                    player->ResetMap();
                    player->SetMap(homebindMap);
                    player->UpdatePositionData();
                }

                LOG_INFO("module", "DungeonMaster: Relocated player {} to homebind map {} during database load (no saved return position)",
                    player->GetName(), player->m_homebindMapId);
            }
        }
    }

    void OnLogin(Player* player) override
    {
        if (!sDMConfig->IsEnabled() || !player)
            return;

        sDungeonMasterMgr->LoadPlayerDungeonData(player->GetGUID().GetCounter());
        sDungeonMasterMgr->SendPlayerMastery(player);
        sDungeonMasterMgr->SendPlayerPersonalBests(player);

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

            auto savedIt = _relocatedToSavedPlayers.find(player->GetGUID());
            bool wasSaved = (savedIt != _relocatedToSavedPlayers.end());
            if (wasSaved)
            {
                _relocatedToSavedPlayers.erase(savedIt);
            }

            if (player->GetSession())
            {
                if (wasSaved)
                {
                    ChatHandler(player->GetSession()).SendSysMessage(
                        "|cFF00FF00[Dungeon Master]|r Your challenge session has ended. Returning you to your pre-challenge location.");
                }
                else
                {
                    ChatHandler(player->GetSession()).SendSysMessage(
                        "|cFFFF0000[Dungeon Master]|r Your challenge session has ended. Returning you to your homebind location.");
                }
            }
        }
    }

    void OnLogout(Player* player) override
    {
        if (!sDMConfig->IsEnabled() || !player)
            return;

        sDungeonMasterMgr->FlushPlayerDungeonData(player->GetGUID().GetCounter());
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
    static std::unordered_set<ObjectGuid> _relocatedToSavedPlayers;
};

// Initialize static member variables
std::unordered_set<ObjectGuid> dm_player_script::_relocatedPlayers;
std::unordered_set<ObjectGuid> dm_player_script::_relocatedDeadPlayers;
std::unordered_set<ObjectGuid> dm_player_script::_relocatedToSavedPlayers;

void AddSC_dm_player_script()
{
    new dm_player_script();
}

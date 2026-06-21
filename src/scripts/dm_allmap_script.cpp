/*
 * mod-dungeon-master — dm_allmap_script.cpp
 * Triggers dungeon population when a player enters the instance map.
 */

#include "ScriptMgr.h"
#include "Map.h"
#include "Player.h"
#include "DungeonMasterMgr.h"
#include "RoguelikeMgr.h"
#include "DMConfig.h"
#include "Chat.h"
#include "Log.h"
#include "AllGameObjectScript.h"
#include "GameObject.h"
#include "AllCreatureScript.h"
#include "Creature.h"
#include <cstdio>

using namespace DungeonMaster;

class dm_allmap_script : public AllMapScript
{
public:
    dm_allmap_script() : AllMapScript("dm_allmap_script") {}

    void OnPlayerEnterAll(Map* map, Player* player) override
    {
        if (!sDMConfig->IsEnabled() || !map || !player)
            return;

        // Only care about dungeon maps
        if (!map->IsDungeon())
            return;

        Session* session = sDungeonMasterMgr->GetSessionByPlayer(player->GetGUID());
        if (!session)
        {
            LOG_DEBUG("module", "DungeonMaster: OnPlayerEnterAll — {} entered map {} but has no session",
                player->GetName(), map->GetId());
            return;
        }

        // Sync session data to player immediately upon entering map (prevents loading screen message loss)
        sDungeonMasterMgr->SendSessionUpdateToPlayers(session);

        if (session->RoguelikeRunId != 0)
        {
            sRoguelikeMgr->ClearTransitionTime(session->RoguelikeRunId);
        }

        LOG_INFO("module", "DungeonMaster: OnPlayerEnterAll — {} entered map {} (session {} state {} mapId {} mobs {} bosses {})",
            player->GetName(), map->GetId(), session->SessionId,
            static_cast<int>(session->State), session->MapId,
            session->TotalMobs, session->TotalBosses);

        if (session->State != SessionState::InProgress)
            return;

        if (map->GetId() != session->MapId)
            return;

        InstanceMap* instance = map->ToInstanceMap();
        if (!instance)
            return;

        // Check if map recreated (e.g. after server crash/restart)
        if (session->InstanceId != 0 && session->InstanceId != instance->GetInstanceId())
        {
            LOG_INFO("module", "DungeonMaster: Session {} instance mapping changed from {} to {} (map recreated). Resetting creature lists.",
                session->SessionId, session->InstanceId, instance->GetInstanceId());
            session->SpawnedCreatures.clear();
            session->TotalMobs = 0;
            session->MobsKilled = 0;
            session->TotalBosses = 0;
            session->BossesKilled = 0;
        }

        if (session->TotalMobs > 0 || session->TotalBosses > 0)
            return;

        session->InstanceId = instance->GetInstanceId();

        ChatHandler(player->GetSession()).SendSysMessage(
            "|cFF00FF00[Dungeon Master]|r Preparing the challenge...");

        sDungeonMasterMgr->PopulateDungeon(session, instance);

        LOG_INFO("module", "DungeonMaster: Session {} — populated via OnPlayerEnterAll (player {}, map {}, mobs {}, bosses {})",
            session->SessionId, player->GetName(), map->GetId(),
            session->TotalMobs, session->TotalBosses);

        char buf[256];
        snprintf(buf, sizeof(buf),
            "|cFF00FF00[Dungeon Master]|r |cFFFFFFFF%u|r enemies and |cFFFFFFFF%u|r boss(es) spawned. "
            "Creature levels: |cFFFFFFFF%u-%u|r. Good luck!",
            session->TotalMobs, session->TotalBosses,
            session->LevelBandMin, session->LevelBandMax);
        ChatHandler(player->GetSession()).SendSysMessage(buf);
    }
};

class dm_gameobject_script : public AllGameObjectScript
{
public:
    dm_gameobject_script() : AllGameObjectScript("dm_gameobject_script") {}

    void OnGameObjectAddWorld(GameObject* go) override
    {
        if (!sDMConfig->IsEnabled() || !go || !go->IsInWorld())
            return;

        Map* map = go->GetMap();
        if (!map || !map->IsDungeon())
            return;

        InstanceMap* inst = map->ToInstanceMap();
        if (!inst)
            return;

        Session* session = sDungeonMasterMgr->GetSessionByInstance(inst->GetInstanceId());
        if (!session)
            return;

        if (go->GetGoType() == GAMEOBJECT_TYPE_DOOR || go->GetGoType() == GAMEOBJECT_TYPE_BUTTON)
        {
            go->Delete();
            LOG_DEBUG("module", "DungeonMaster: Dynamically removed door/button {} (Entry {}) from instance Map {}.",
                go->GetName(), go->GetEntry(), map->GetId());
        }
    }
};

class dm_creature_script : public AllCreatureScript
{
public:
    dm_creature_script() : AllCreatureScript("dm_creature_script") {}

    void OnCreatureAddWorld(Creature* c) override
    {
        if (!sDMConfig->IsEnabled() || !c)
            return;

        Map* map = c->GetMap();
        if (!map || !map->IsDungeon())
            return;

        InstanceMap* inst = map->ToInstanceMap();
        if (!inst)
            return;

        Session* session = sDungeonMasterMgr->GetSessionByInstance(inst->GetInstanceId());
        if (!session || !session->IsActive())
            return;

        // Skip pets, guardians, totems, and the Dungeon Master NPC itself
        if (c->IsPet() || c->IsGuardian() || c->IsTotem() || c->GetEntry() == sDMConfig->GetNpcEntry())
            return;

        // Skip temporary summons (custom themed creatures spawned by the module, or script-summoned minions)
        if (c->IsSummon())
            return;

        // Set respawn time to 7 days and despawn it
        c->SetRespawnTime(7 * DAY);
        c->DespawnOrUnsummon();

        LOG_DEBUG("module", "DungeonMaster: Dynamically despawned native creature '{}' (entry {}, guid {}) on grid load.",
            c->GetName(), c->GetEntry(), c->GetGUID().ToString());
    }
};

void AddSC_dm_allmap_script()
{
    new dm_allmap_script();
    new dm_gameobject_script();
    new dm_creature_script();
}

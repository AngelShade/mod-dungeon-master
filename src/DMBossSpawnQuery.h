/*
 * mod-dungeon-master — Boss spawn-point SQL helpers.
 *
 * NOTE: The original query joined `creature_immunities` (a table from the
 * playerbot-flavoured AzerothCore schema).  Our build uses NPCBots and that
 * table does not exist.  The MechanicsMask value is only used for debug
 * logging in DungeonMasterMgr; it has no effect on spawn selection logic.
 * We therefore return 0 for MechanicsMask and remove the JOIN entirely so
 * that boss creatures (rank >= 1) are found correctly without any dependency
 * on the missing table.
 */

#ifndef DM_BOSS_SPAWN_QUERY_H
#define DM_BOSS_SPAWN_QUERY_H

#include "Define.h"

#include <string>

namespace DungeonMaster
{

inline std::string BuildBossSpawnPointQuery(uint32 mapId)
{
    return
        "SELECT c.position_x, c.position_y, c.position_z, c.orientation, "
        "0 AS MechanicsMask, ct.`rank`, ct.entry "
        "FROM creature c "
        "JOIN creature_template ct ON c.id1 = ct.entry "
        "WHERE c.map = " + std::to_string(mapId) + " "
        "AND ct.`rank` >= 1 "
        "ORDER BY ct.`rank` DESC";
}

} // namespace DungeonMaster

#endif // DM_BOSS_SPAWN_QUERY_H

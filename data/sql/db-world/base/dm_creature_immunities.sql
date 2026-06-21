-- mod-dungeon-master: Add creature_immunities support
-- Creates the creature_immunities table and adds CreatureImmunitiesId to creature_template.
-- Used by DMBossSpawnQuery to detect boss mechanic immunity sets for Roguelike/Challenge mode.

CREATE TABLE IF NOT EXISTS `creature_immunities` (
    `ID` int unsigned NOT NULL AUTO_INCREMENT,
    `MechanicsMask` int unsigned NOT NULL DEFAULT '0',
    PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Creature mechanic immunity sets, referenced by creature_template.CreatureImmunitiesId';

-- Note: ALTER TABLE ... ADD COLUMN IF NOT EXISTS requires MySQL 8.0+
-- For older MySQL, run this only if the column does not already exist.
ALTER TABLE `creature_template`
    ADD COLUMN `CreatureImmunitiesId` int unsigned NOT NULL DEFAULT '0'
    COMMENT 'FK to creature_immunities.ID (0 = no special immunities)';

-- Global addon table
ACDM = {}
ACMP = {}

-- Storage for Mythic Plus received from server
ACMP.mythicLevels = {}
ACMP.mythicDungeons = {}
ACMP.mythicStatus = {
    enabled = 0,
    setLevel = 0,
    leaderLevel = 0,
    cooldownRemSec = 0,
    hasKeystone = 0
}

-- Color definitions (NPC gossip colors)
ACDM.Colors = {
    Gold = { r = 1.0, g = 0.82, b = 0.35, hex = "ffffd159" },
    Green = { r = 0.0, g = 1.0, b = 0.0, hex = "ff00ff00" },
    Red = { r = 1.0, g = 0.0, b = 0.0, hex = "ffff0000" },
    Cyan = { r = 0.0, g = 1.0, b = 1.0, hex = "ff00ffff" },
    Muted = { r = 0.78, g = 0.66, b = 0.45, hex = "ffc7a873" },
    Grey = { r = 0.5, g = 0.5, b = 0.5, hex = "ff808080" },
    White = { r = 1.0, g = 1.0, b = 1.0, hex = "ffffffff" }
}

ACDM.PANEL_WIDTH = 520
ACDM.PANEL_HEIGHT = 600

-- Storage for data received from server
ACDM.difficulties = {}
ACDM.themes = {}
ACDM.dungeons = {}
ACDM.flags = {
    enabled = 0,
    roguelikeEnabled = 0,
    cooldownRemSec = 0,
    inSession = 0,
    inRoguelike = 0,
    playerLevel = 1,
    rlTier = 0,
    rlFloors = 0,
    sessionState = 0,
    vetoTokens = 0,
    gambitTimeTrial = 0,
    gambitGlassCannon = 0,
    gambitPacifist = 0
}

-- Current user selection
ACDM.selection = {
    diffId = nil,
    scaleParty = true,
    themeId = nil,
    mapId = nil
}

-- Stats storage
ACDM.normalStats = {}
ACDM.roguelikeStats = {}

-- Current run info
ACDM.runInfo = {
    elapsed = 0,
    bossName = "None",
    bossX = 0,
    bossY = 0,
    bossResetCd = 0,
    survivalBuffs = 0,
    debuffs = 0,
    debuffTimer = 0,
    wipes = 0,
    maxWipes = 0,
    timeAlive = 0,
    teleportRemaining = 0,
    accumulatedGold = 0,
    rewardedItems = {},
    activeAffixes = {},
    lastUpdate = 0
}

ACDM.affixInfo = {
    [1] = {
        name = "Fortified",
        icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
        description = "Non-boss enemies have 30% more health and inflict 15% more damage."
    },
    [2] = {
        name = "Tyrannical",
        icon = "Interface\\Icons\\Achievement_Boss_KingYmiron",
        description = "Boss enemies have 40% more health and inflict up to 20% more damage."
    },
    [3] = {
        name = "Raging",
        icon = "Interface\\Icons\\Ability_Druid_Enrage",
        description = "Non-boss enemies enrage at 30% health, dealing 25% increased damage."
    },
    [4] = {
        name = "Bolstering",
        icon = "Interface\\Icons\\Ability_Warrior_CommandingShout",
        description = "Non-boss enemies have 20% increased maximum health."
    },
    [5] = {
        name = "Savage",
        icon = "Interface\\Icons\\Ability_Warrior_Cruelty",
        description = "Elite chance is doubled, and elite creatures deal 10% more damage."
    }
}

ACDM.isInitialFlags = true

-- Leaderboards storage
ACDM.leaderboard = {}

-- Helper to color string
function ACDM.ColorText(text, color)
    return "|c" .. color.hex .. text .. "|r"
end

-- Formatting duration
function ACDM.FormatTime(seconds)
    if not seconds or seconds == 0 then return "N/A" end
    if seconds < 60 then
        return seconds .. "s"
    elseif seconds < 3600 then
        local m = math.floor(seconds / 60)
        local s = seconds % 60
        return m .. "m " .. s .. "s"
    else
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        local s = seconds % 60
        return h .. "h " .. m .. "m " .. s .. "s"
    end
end

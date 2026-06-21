/*
 * mod-dungeon-master — dm_unit_script.cpp
 * Scales ALL incoming damage for session players:
 *   - Session boss spells/melee: scaled by level ratio (template level → session level)
 *   - Session trash: already scaled by custom AI melee, passed through
 *   - Environmental (non-session): capped at 3% max HP
 *
 * Modified to implement:
 *   - Stacking Wipe Debuff ("Dungeon Weakness") and Survival Buff ("Dungeon Attunement") scaling.
 *   - Mob attunement/adaptation scaling.
 *   - Support for NPCBots and another player.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "SpellInfo.h"
#include "DungeonMasterMgr.h"
#include "DMConfig.h"
#include "botmgr.h"
#include "bot_ai.h"

using namespace DungeonMaster;

static constexpr float ENV_DAMAGE_MAX_PCT = 0.03f;

class dm_unit_script : public UnitScript
{
public:
    dm_unit_script() : UnitScript("dm_unit_script") {}

    void ModifyPeriodicDamageAurasTick(Unit* target, Unit* attacker, uint32& damage, SpellInfo const* spellInfo) override
    {
        ScaleDamage(target, attacker, damage, spellInfo);
    }

    void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo) override
    {
        if (damage <= 0) return;
        uint32 udmg = static_cast<uint32>(damage);
        ScaleDamage(target, attacker, udmg, spellInfo);
        damage = static_cast<int32>(udmg);
    }

    void ModifyMeleeDamage(Unit* target, Unit* attacker, uint32& damage) override
    {
        ScaleDamage(target, attacker, damage, nullptr);
    }

    void OnHeal(Unit* healer, Unit* /*reciever*/, uint32& gain) override
    {
        if (!sDMConfig->IsEnabled() || gain == 0)
            return;

        Session* session = GetDMPlayerSession(healer);
        if (session && session->IsActive())
        {
            float healMult = 1.0f;
            // Apply Wipe Debuff (damage/healing dealt reduced by 15% per stack)
            if (session->WipeDebuffTimer > 0 && session->WipeDebuffStacks > 0)
            {
                healMult -= 0.15f * session->WipeDebuffStacks;
            }
            // Apply Survival Buff (damage/healing dealt increased by 10% per stack)
            if (session->SurvivalBuffStacks > 0)
            {
                healMult += 0.10f * session->SurvivalBuffStacks;
            }
            healMult = std::max(0.1f, healMult);
            gain = static_cast<uint32>(gain * healMult);
        }
    }

    void OnUnitDeath(Unit* unit, Unit* killer) override
    {
        if (!sDMConfig->IsEnabled() || !unit)
            return;

        Creature* creature = unit->ToCreature();
        if (!creature)
            return;

        // Check if the deceased creature is an NPCBot
        if (creature->IsNPCBot())
        {
            if (bot_ai* ai = creature->GetBotAI())
            {
                Player* master = ai->GetBotOwner();
                if (master)
                {
                    Session* session = sDungeonMasterMgr->GetSessionByPlayer(master->GetGUID());
                    if (session && session->IsActive() && creature->GetMapId() == session->MapId)
                    {
                        if (session->IsPartyWiped())
                        {
                            sDungeonMasterMgr->HandlePlayerDeath(master, session);
                        }
                    }
                }
            }
            return;
        }

        // Original logic for dungeon mobs/bosses
        Player* player = GetAssociatedPlayer(killer);

        Session* session = nullptr;
        if (player)
            session = sDungeonMasterMgr->GetSessionByPlayer(player->GetGUID());

        if (!session || !session->IsActive())
            return;

        if (creature->GetMapId() != session->MapId)
            return;

        sDungeonMasterMgr->HandleCreatureDeath(creature, session);
    }

private:
    Player* GetAssociatedPlayer(Unit* unit)
    {
        if (!unit)
            return nullptr;

        Player* p = unit->ToPlayer();
        if (p)
            return p;

        if (unit->GetOwner())
        {
            p = unit->GetOwner()->ToPlayer();
            if (p)
                return p;
        }

        if (unit->GetTypeId() == TYPEID_UNIT && unit->ToCreature()->IsNPCBot())
        {
            if (bot_ai* ai = unit->ToCreature()->GetBotAI())
                return ai->GetBotOwner();
        }

        return nullptr;
    }

    Session* GetDMPlayerSession(Unit* unit)
    {
        if (Player* p = GetAssociatedPlayer(unit))
            return sDungeonMasterMgr->GetSessionByPlayer(p->GetGUID());

        return nullptr;
    }

    void ScaleDamage(Unit* target, Unit* attacker, uint32& damage, SpellInfo const* spellInfo = nullptr)
    {
        if (!sDMConfig->IsEnabled() || damage == 0)
            return;

        Session* targetSession = GetDMPlayerSession(target);
        Session* attackerSession = GetDMPlayerSession(attacker);

        // --- Outgoing damage from Player/Bot (Attacker) ---
        if (attackerSession && attackerSession->IsActive())
        {
            float dmgMult = 1.0f;
            // Gladiator perk (bit 3): +5% damage dealt
            if (Player* attPlayer = GetAssociatedPlayer(attacker))
            {
                if (sDungeonMasterMgr->HasMasteryPerk(attPlayer->GetGUID().GetCounter(), 3))
                {
                    dmgMult += 0.05f;
                }
            }

            // Apply Wipe Debuff Penalty (damage dealt reduced by 15% per stack)
            if (attackerSession->WipeDebuffTimer > 0 && attackerSession->WipeDebuffStacks > 0)
            {
                dmgMult -= 0.15f * attackerSession->WipeDebuffStacks;
            }
            // Apply Survival Buff Bonus (damage dealt increased by 10% per stack)
            if (attackerSession->SurvivalBuffStacks > 0)
            {
                dmgMult += 0.10f * attackerSession->SurvivalBuffStacks;
            }
            dmgMult = std::max(0.1f, dmgMult);
            damage = static_cast<uint32>(damage * dmgMult);

            if (attackerSession->GambitGlassCannon)
            {
                damage = static_cast<uint32>(damage * 1.5f);
            }

            // Mobs adapt: if attacker is player/bot and target is a mob,
            // they effectively have more health, meaning they take less damage.
            if (!targetSession)
            {
                if (attackerSession->SurvivalBuffStacks > 0)
                {
                    float hpAdaptScale = 1.0f / (1.0f + 0.04f * attackerSession->SurvivalBuffStacks);
                    damage = static_cast<uint32>(damage * hpAdaptScale);
                }
            }
        }

        // --- Incoming damage to Player/Bot (Target) ---
        if (targetSession && targetSession->IsActive())
        {
            float targetDmgMult = 1.0f;
            // Veteran perk (bit 1): -5% damage taken
            if (Player* tgtPlayer = GetAssociatedPlayer(target))
            {
                if (sDungeonMasterMgr->HasMasteryPerk(tgtPlayer->GetGUID().GetCounter(), 1))
                {
                    targetDmgMult -= 0.05f;
                }
            }
            damage = static_cast<uint32>(damage * targetDmgMult);

            if (targetSession->GambitGlassCannon)
            {
                damage = static_cast<uint32>(damage * 1.5f);
            }

            if (!attackerSession) // Attacker is a dungeon monster or hazard
            {
                if (attacker)
                {
                    // For GUID checks, use the session leader
                    ObjectGuid targetGuid = target->IsPlayer() ? target->GetGUID() : targetSession->LeaderGuid;
                    ObjectGuid attackerGuid = attacker->GetGUID();

                    if (sDungeonMasterMgr->IsSessionCreature(targetGuid, attackerGuid))
                    {
                        float scale = sDungeonMasterMgr->GetSessionCreatureDamageScale(targetGuid, attackerGuid);
                        if (scale < 1.0f)
                            damage = std::max(1u, static_cast<uint32>(damage * scale));
                    }
                    else
                    {
                        // Env damage cap
                        float envScale = sDungeonMasterMgr->GetEnvironmentalDamageScale(targetGuid);
                        if (envScale < 1.0f)
                            damage = static_cast<uint32>(damage * envScale);

                        uint32 maxHp = target->GetMaxHealth();
                        uint32 cap = std::max(1u, static_cast<uint32>(maxHp * ENV_DAMAGE_MAX_PCT));
                        if (damage > cap)
                            damage = cap;
                    }
                }

                // Mobs adapt: they deal +4% damage per stack of Attunement
                if (targetSession->SurvivalBuffStacks > 0)
                {
                    float mobDmgMult = 1.0f + (0.04f * targetSession->SurvivalBuffStacks);
                    damage = static_cast<uint32>(damage * mobDmgMult);
                }

                // Apply Wipe Debuff Penalty (damage taken increased by 15% per stack)
                if (targetSession->WipeDebuffTimer > 0 && targetSession->WipeDebuffStacks > 0)
                {
                    float takenMult = 1.0f + (0.15f * targetSession->WipeDebuffStacks);
                    damage = static_cast<uint32>(damage * takenMult);
                }
            }
        }

        if (damage == 0)
            damage = 1;

        // --- Track Damage Stats and Recent Hits ---
        Player* targetPlayer = GetAssociatedPlayer(target);
        if (targetPlayer && targetSession && targetSession->IsActive())
        {
            if (PlayerSessionData* pd = targetSession->GetPlayerData(targetPlayer->GetGUID()))
            {
                pd->DamageTaken += damage;

                // Only record the hit in the death recap buffer if it hit the human player directly
                if (target->IsPlayer())
                {
                    DamageHit hit;
                    hit.SourceName = attacker ? attacker->GetName() : "Environmental / Hazard";
                    hit.Damage = damage;
                    hit.SpellId = spellInfo ? spellInfo->Id : 0;
                    hit.School = spellInfo ? spellInfo->SchoolMask : 1; // SPELL_SCHOOL_MASK_NORMAL is 1 (Physical)
                    hit.Timestamp = static_cast<uint32>(time(nullptr));

                    pd->RecentHits.push_back(hit);
                    if (pd->RecentHits.size() > 3)
                    {
                        pd->RecentHits.erase(pd->RecentHits.begin());
                    }
                }
            }
        }

        Player* attackerPlayer = GetAssociatedPlayer(attacker);
        if (attackerPlayer && attackerSession && attackerSession->IsActive())
        {
            if (PlayerSessionData* pd = attackerSession->GetPlayerData(attackerPlayer->GetGUID()))
            {
                pd->DamageDealt += damage;
            }
        }
    }
};

void AddSC_dm_unit_script()
{
    new dm_unit_script();
}

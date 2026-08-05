#include "ai/AIController.h"

namespace {

struct SkillChoice {
    int idx = -1;
    float mult = 0.0f;
};

// 找到当前可释放（AP 足够）且倍率最高的技能
SkillChoice bestAffordableSkill(const Character& me) {
    SkillChoice best;
    for (size_t i = 0; i < me.skills.size(); ++i) {
        const Skill& sk = me.skills[i];
        if (sk.apCost <= me.ap && sk.multiplier > best.mult) {
            best.idx = static_cast<int>(i);
            best.mult = sk.multiplier;
        }
    }
    return best;
}

} // namespace

void AIController::decideAction(BattleSystem& b, Side aiSide) {
    Side foeSide = otherSide(aiSide);
    Character& me = b.teams_[b.idx(aiSide)].active();
    const Character& foe = b.teams_[b.idx(foeSide)].active();

    // 1. 血量过低且后备有更健康角色时换人
    if (me.hp <= me.maxHp * 0.35f) {
        for (int idx : b.team(aiSide).aliveBench()) {
            const Character& bench = b.teams_[b.idx(aiSide)].roster[idx];
            if (bench.hp > me.hp) {
                b.performSwap(idx);
                return;
            }
        }
    }

    // 2. 若普通攻击即可击杀目标，直接攻击
    int attackDmg = BattleSystem::estimateDamage(me, 1.0f, foe, foe.defending);
    if (attackDmg >= foe.hp) {
        b.performAttack();
        return;
    }

    // 3. 选择可释放的最强技能
    SkillChoice sc = bestAffordableSkill(me);
    if (sc.idx >= 0) {
        // 若最强技能即可击杀，优先使用
        int skDmg = BattleSystem::estimateDamage(me, sc.mult, foe, foe.defending);
        if (skDmg >= foe.hp) {
            b.performSkill(sc.idx);
            return;
        }
        // 行动点充足或已有一定积攒时释放技能
        if (me.ap >= 4) {
            b.performSkill(sc.idx);
            return;
        }
    }

    // 4. 血量极低且无更优选择时防御
    if (me.hp <= me.maxHp * 0.2f) {
        b.performDefend();
        return;
    }

    // 5. 默认普通攻击（积攒行动点）
    b.performAttack();
}

void AIController::chooseDeathReplacement(BattleSystem& b, Side aiSide) {
    int bestIdx = -1;
    int bestHp = -1;
    for (int idx : b.team(aiSide).aliveAll()) {
        const Character& c = b.teams_[b.idx(aiSide)].roster[idx];
        if (c.hp > bestHp) {
            bestHp = c.hp;
            bestIdx = idx;
        }
    }
    if (bestIdx >= 0)
        b.doReplacement(aiSide, bestIdx);
}

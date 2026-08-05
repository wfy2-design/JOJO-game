#include "core/BattleSystem.h"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cmath>
#include <cstdlib>
#include <random>

#include "ai/AIController.h"
#include "config/ConfigParser.h"

namespace {

std::mt19937 makeRng() {
    std::random_device device;
    const auto ticks = std::chrono::high_resolution_clock::now()
                           .time_since_epoch()
                           .count();
    const std::uint64_t timeSeed = static_cast<std::uint64_t>(ticks);
    std::seed_seq seed{
        device(), device(), device(), device(),
        static_cast<std::uint32_t>(timeSeed),
        static_cast<std::uint32_t>(timeSeed >> 32)};
    return std::mt19937(seed);
}

std::mt19937& rng() {
    static std::mt19937 gen = makeRng();
    return gen;
}

// 随机 [0,1)
float rand01() {
    std::uniform_real_distribution<float> d(0.0f, 1.0f);
    return d(rng());
}

// 随机抛硬币，返回 true 表示正面（队伍A 先手）
bool coinFlip() { return rand01() < 0.5f; }

} // namespace

BattleSystem::BattleSystem() {
    startBattle();
}

void BattleSystem::startBattle() {
    phase_ = Phase::Menu;
    vsAI_ = false;
    winner_ = Side::A;
    deathSide_ = -1;
    events_.clear();
    timer_ = 0.0f;
}

void BattleSystem::beginBattle() {
    std::vector<Character> teamA, teamB;
    std::string error;

    std::vector<std::string> candidates = {"config/characters.cfg",
                                           "../config/characters.cfg"};
    bool loaded = false;
    for (const auto& p : candidates) {
        if (ConfigParser::loadCharacters(p, teamA, teamB, error)) {
            loaded = true;
            break;
        }
    }
    if (!loaded) {
        pushInfo("角色配置加载失败: " + error);
        phase_ = Phase::Menu;
        return;
    }

    teams_[0].side = Side::A;
    teams_[1].side = Side::B;
    teams_[0].roster = teamA;
    teams_[1].roster = teamB;
    teams_[0].activeIndex = 0;
    teams_[1].activeIndex = 0;

    if (teams_[0].roster.empty() || teams_[1].roster.empty()) {
        pushInfo("双方队伍都需要至少一名角色");
        phase_ = Phase::Menu;
        return;
    }

    // 抛硬币决定先后手
    coinWinner_ = coinFlip() ? Side::A : Side::B;
    speedBar_[0] = (coinWinner_ == Side::A) ? 0.0f : 0.1f;
    speedBar_[1] = (coinWinner_ == Side::B) ? 0.0f : 0.1f;

    pushInfo(coinWinner_ == Side::A ? "抛硬币结果：正面 —— 队伍A 先手"
                                    : "抛硬币结果：反面 —— 队伍B 先手");

    deathSide_ = -1;
    phase_ = Phase::CoinToss;
    timer_ = 1.6f; // 展示抛硬币结果
}

void BattleSystem::update(float dt) {
    switch (phase_) {
    case Phase::Menu:
        return;
    case Phase::CoinToss:
        timer_ -= dt;
        if (timer_ <= 0.0f) {
            setNextActor(coinWinner_);
        }
        break;
    case Phase::Action:
        if (vsAI_ && currentActor_ == Side::B)
            aiUpdate(dt);
        break;
    case Phase::DeathSelect:
        if (vsAI_ && deathSide_ == static_cast<int>(Side::B))
            aiUpdate(dt);
        break;
    case Phase::SkillSelect:
    case Phase::SwapSelect:
    case Phase::GameOver:
        break; // 等待玩家输入
    }
}

bool BattleSystem::handleKey(Key key) {
    switch (phase_) {
    case Phase::Menu: {
        if (key == Key::Num1) {
            vsAI_ = false;
            beginBattle();
            return true;
        }
        if (key == Key::Num2) {
            vsAI_ = true;
            beginBattle();
            return true;
        }
        return false;
    }
    case Phase::Action: {
        if (vsAI_ && currentActor_ == Side::B)
            return false; // AI 回合忽略玩家输入
        switch (key) {
        case Key::A:
            performAttack();
            return true;
        case Key::C:
            performDefend();
            return true;
        case Key::E:
            if (team(currentActor_).active().skills.empty()) {
                pushInfo("该角色没有技能");
            } else {
                phase_ = Phase::SkillSelect;
                pushInfo("选择技能（1~" +
                         std::to_string(team(currentActor_).active().skills.size()) +
                         "），按 Esc 返回");
            }
            return true;
        case Key::T: {
            auto bench = team(currentActor_).aliveBench();
            if (bench.empty()) {
                pushInfo("队伍中没有可换上的角色");
            } else {
                phase_ = Phase::SwapSelect;
                pushInfo("选择要换上的角色（1~" + std::to_string(bench.size()) + "）");
            }
            return true;
        }
        default:
            return false;
        }
    }
    case Phase::SkillSelect: {
        const auto& ch = team(currentActor_).active();
        if (key == Key::Escape) {
            phase_ = Phase::Action;
            return true;
        }
        int n = -1;
        if (key == Key::Num1) n = 0;
        else if (key == Key::Num2) n = 1;
        else if (key == Key::Num3) n = 2;
        if (n >= 0 && n < static_cast<int>(ch.skills.size())) {
            performSkill(n);
            return true;
        }
        return false;
    }
    case Phase::SwapSelect: {
        if (key == Key::Escape) {
            phase_ = Phase::Action;
            return true;
        }
        auto bench = team(currentActor_).aliveBench();
        int n = -1;
        if (key == Key::Num1) n = 0;
        else if (key == Key::Num2) n = 1;
        else if (key == Key::Num3) n = 2;
        if (n >= 0 && n < static_cast<int>(bench.size())) {
            performSwap(bench[n]);
            return true;
        }
        return false;
    }
    case Phase::DeathSelect: {
        if (vsAI_ && deathSide_ == static_cast<int>(Side::B))
            return false; // 人机模式下 AI 的补位由 AI 决定
        int n = -1;
        if (key == Key::Num1) n = 0;
        else if (key == Key::Num2) n = 1;
        else if (key == Key::Num3) n = 2;
        auto alive = team(static_cast<Side>(deathSide_)).aliveAll();
        if (n >= 0 && n < static_cast<int>(alive.size())) {
            doReplacement(static_cast<Side>(deathSide_), alive[n]);
            return true;
        }
        return false;
    }
    case Phase::GameOver: {
        if (key == Key::Enter || key == Key::Space) {
            startBattle();
            return true;
        }
        return false;
    }
    case Phase::CoinToss:
        return false;
    }
    return false;
}

// ---------- 回合推进 ----------

void BattleSystem::setNextActor(Side s) {
    currentActor_ = s;
    // 轮到该角色行动时清除其防御状态（防御持续到下一次行动开始）
    teams_[idx(s)].active().defending = false;
    phase_ = Phase::Action;
    BattleEvent ev;
    ev.type = BattleEvent::Type::Turn;
    ev.side = s;
    ev.actor = teams_[idx(s)].active().name;
    ev.text = s == Side::A ? "队伍A" : "队伍B";
    events_.push_back(ev);
}

void BattleSystem::startActorTurn(Side s) {
    setNextActor(s);
}

void BattleSystem::endTurn(Side acted) {
    // 行动完成后速度条增加 p
    speedBar_[idx(acted)] += static_cast<float>(team(acted).active().speed);
    // 对比双方速度条，值小者下一次行动（平手时让对方优先，防御性处理）
    Side next;
    if (speedBar_[idx(Side::A)] < speedBar_[idx(Side::B)])
        next = Side::A;
    else if (speedBar_[idx(Side::B)] < speedBar_[idx(Side::A)])
        next = Side::B;
    else
        next = otherSide(acted);
    setNextActor(next);
}

// ---------- 行动执行 ----------

void BattleSystem::performAttack() {
    Character& atk = teams_[idx(currentActor_)].active();
    // 普通攻击积攒行动点（常规 +1，上限为 maxAp）
    if (atk.ap < atk.maxAp) atk.ap++;
    Side targetSide = otherSide(currentActor_);
    Character& def = teams_[idx(targetSide)].active();

    int dmg = computeDamage(atk, 1.0f, def, def.defending);

    if (dmg < 0) {
        BattleEvent ev;
        ev.type = BattleEvent::Type::Miss;
        ev.side = targetSide;
        ev.actor = def.name;
        ev.amount = 0;
        events_.push_back(ev);
    } else {
        BattleEvent ev;
        ev.type = BattleEvent::Type::Damage;
        ev.side = targetSide;
        ev.actor = def.name;
        ev.amount = dmg;
        events_.push_back(ev);
        applyDamageTo(targetSide, dmg);
    }
    if (teams_[idx(targetSide)].active().isDead()) {
        handleDeath(targetSide);
    } else {
        endTurn(currentActor_);
    }
}

void BattleSystem::performDefend() {
    Character& ch = teams_[idx(currentActor_)].active();
    ch.defending = true;
    BattleEvent ev;
    ev.type = BattleEvent::Type::Defend;
    ev.side = currentActor_;
    ev.actor = ch.name;
    events_.push_back(ev);
    endTurn(currentActor_);
}

bool BattleSystem::performSkill(int skillIdx) {
    Character& ch = teams_[idx(currentActor_)].active();
    if (skillIdx < 0 || skillIdx >= static_cast<int>(ch.skills.size()))
        return false;
    const Skill& sk = ch.skills[skillIdx];
    if (ch.ap < sk.apCost) {
        pushInfo("行动点不足！无法释放「" + sk.name + "」（需要 " +
                 std::to_string(sk.apCost) + "，当前 " + std::to_string(ch.ap) + "）");
        return false; // 停留在技能选择，玩家需变更操作
    }

    ch.ap -= sk.apCost;
    Side targetSide = otherSide(currentActor_);
    Character& def = teams_[idx(targetSide)].active();

    BattleEvent ev;
    ev.type = BattleEvent::Type::Skill;
    ev.side = currentActor_;
    ev.actor = ch.name;
    ev.text = sk.name;
    events_.push_back(ev);

    int dmg = computeDamage(ch, sk.multiplier, def, def.defending);
    if (dmg < 0) {
        BattleEvent mev;
        mev.type = BattleEvent::Type::Miss;
        mev.side = targetSide;
        mev.actor = def.name;
        mev.amount = 0;
        events_.push_back(mev);
    } else {
        BattleEvent dev;
        dev.type = BattleEvent::Type::Damage;
        dev.side = targetSide;
        dev.actor = def.name;
        dev.amount = dmg;
        events_.push_back(dev);
        applyDamageTo(targetSide, dmg);
    }
    if (teams_[idx(targetSide)].active().isDead()) {
        handleDeath(targetSide);
    } else {
        endTurn(currentActor_);
    }
    return true;
}

void BattleSystem::performSwap(int benchIdx) {
    Side s = currentActor_;
    Team& t = teams_[idx(s)];
    if (benchIdx == t.activeIndex || !t.roster[benchIdx].alive || t.roster[benchIdx].hp <= 0)
        return;

    Character& incoming = t.roster[benchIdx];
    t.activeIndex = benchIdx;

    // 退场更换机制：
    //   新上场角色速度条 0.1；对方当前角色速度条归 0（防止平手）；
    //   换下的角色速度条归 0
    speedBar_[idx(s)] = 0.1f;
    speedBar_[idx(otherSide(s))] = 0.0f;

    BattleEvent ev;
    ev.type = BattleEvent::Type::Swap;
    ev.side = s;
    ev.actor = incoming.name;
    ev.text = incoming.name;
    events_.push_back(ev);

    // 换人占用本回合行动，不再 +p，直接由对方行动
    setNextActor(otherSide(s));
}

// ---------- 伤害与阵亡 ----------

int BattleSystem::computeDamage(const Character& atk, float mult, const Character& def,
                                bool defIsDefending) {
    // Luck evasion remains part of the real attack resolution only.
    if (rand01() < static_cast<float>(def.luck) / 50.0f)
        return -1;
    return estimateDamage(atk, mult, def, defIsDefending);
}

int BattleSystem::estimateDamage(const Character& atk, float mult, const Character& def,
                                 bool defIsDefending) {
    // 攻击伤害 = 基础伤害 × 技能倍率 × (1 + x/50)
    float dmg = atk.baseDamage * mult * (1.0f + static_cast<float>(atk.strength) / 50.0f);
    // 防御减伤（常规 50%）
    if (defIsDefending) dmg *= 0.5f;
    // 受到伤害 = 攻击伤害 × (1/(1 + y/50))，四舍五入取整
    dmg *= 1.0f / (1.0f + static_cast<float>(def.defense) / 50.0f);
    return static_cast<int>(std::round(dmg));
}

void BattleSystem::applyDamageTo(Side targetSide, int dmg) {
    Character& ch = teams_[idx(targetSide)].active();
    ch.hp -= dmg;
    if (ch.hp < 0) ch.hp = 0;
}

void BattleSystem::handleDeath(Side deadSide) {
    Character& dead = teams_[idx(deadSide)].active();
    dead.alive = false;
    dead.hp = 0;

    BattleEvent ev;
    ev.type = BattleEvent::Type::Death;
    ev.side = deadSide;
    ev.actor = dead.name;
    events_.push_back(ev);

    if (teams_[idx(deadSide)].allDead()) {
        winner_ = otherSide(deadSide);
        phase_ = Phase::GameOver;
        BattleEvent wev;
        wev.type = BattleEvent::Type::Info;
        wev.side = otherSide(deadSide);
        wev.actor = otherSide(deadSide) == Side::A ? "队伍A" : "队伍B";
        wev.text = "游戏结束！" + wev.actor + " 获胜！";
        events_.push_back(wev);
        return;
    }

    // 由该方指定下一位出场角色
    deathSide_ = static_cast<int>(deadSide);
    phase_ = Phase::DeathSelect;
    auto alive = teams_[idx(deadSide)].aliveAll();
    pushInfo("「" + dead.name + "」阵亡！请选择下一位出场角色（1~" +
             std::to_string(alive.size()) + "）");
}

void BattleSystem::doReplacement(Side s, int rosterIdx) {
    deathSide_ = -1;
    Team& t = teams_[idx(s)];
    t.activeIndex = rosterIdx;
    // 退场更换机制：新上场 0.1，对方归 0
    speedBar_[idx(s)] = 0.1f;
    speedBar_[idx(otherSide(s))] = 0.0f;

    BattleEvent ev;
    ev.type = BattleEvent::Type::Swap;
    ev.side = s;
    ev.actor = t.active().name;
    ev.text = t.active().name;
    events_.push_back(ev);

    setNextActor(otherSide(s));
}

// ---------- 事件与预览 ----------

void BattleSystem::pushEvent(const BattleEvent& ev) { events_.push_back(ev); }

void BattleSystem::pushInfo(const std::string& msg) {
    BattleEvent ev;
    ev.type = BattleEvent::Type::Info;
    ev.side = currentActor_;
    ev.actor = currentActor_ == Side::A ? "队伍A" : "队伍B";
    ev.text = msg;
    events_.push_back(ev);
}

std::vector<BattleEvent> BattleSystem::takeEvents() {
    std::vector<BattleEvent> out;
    out.swap(events_);
    return out;
}

std::vector<Side> BattleSystem::previewTurnOrder(int n) const {
    std::vector<Side> seq;
    if (phase_ == Phase::Menu || phase_ == Phase::GameOver)
        return seq;
    float barA = speedBar_[0];
    float barB = speedBar_[1];
    Side last = currentActor_;
    for (int i = 0; i < n; ++i) {
        Side next;
        if (barA < barB)
            next = Side::A;
        else if (barB < barA)
            next = Side::B;
        else
            next = otherSide(last);
        last = next;
        seq.push_back(next);
        if (next == Side::A)
            barA += static_cast<float>(team(Side::A).active().speed);
        else
            barB += static_cast<float>(team(Side::B).active().speed);
    }
    return seq;
}

// ---------- AI ----------

void BattleSystem::aiUpdate(float dt) {
    if (!aiThinking_) {
        aiThinking_ = true;
        timer_ = 0.6f;
    }
    timer_ -= dt;
    if (timer_ > 0.0f) return;
    aiThinking_ = false;

    if (phase_ == Phase::DeathSelect) {
        AIController::chooseDeathReplacement(*this, Side::B);
        return;
    }
    if (phase_ == Phase::Action && vsAI_ && currentActor_ == Side::B) {
        AIController::decideAction(*this, Side::B);
    }
}

void BattleSystem::aiExecuteDecision() {}

#pragma once

#include <vector>

#include "core/Character.h"
#include "core/Team.h"
#include "core/Types.h"

class AIController;

// 战斗系统：负责状态机、行动顺序、伤害计算、换人/退场、胜负判定
// 友元：AI 需要调用内部行动执行方法
class BattleSystem {
    friend class AIController;
public:
    BattleSystem();

    void startBattle(); // 进入主菜单

    // 每帧调用；dt 为帧间隔（秒）
    void update(float dt);

    // 按键输入，返回 true 表示已消费
    bool handleKey(Key key);

    // 查询接口
    Phase phase() const { return phase_; }
    bool vsAI() const { return vsAI_; }
    Side currentActor() const { return currentActor_; }
    Side coinWinner() const { return coinWinner_; }
    Side winner() const { return winner_; }
    int deathSide() const { return deathSide_; } // 需要补位的队伍，-1 表示无
    const Team& team(Side s) const { return teams_[idx(s)]; }
    float speedBar(Side s) const { return speedBar_[idx(s)]; }

    // 事件队列（UI 每帧取出消费）
    std::vector<BattleEvent> takeEvents();

    // 预览接下来 n 回合的行动方顺序（用于 UI 左侧行动顺序栏）
    std::vector<Side> previewTurnOrder(int n) const;

    // 伤害计算（返回 -1 表示闪避）
    static int computeDamage(const Character& atk, float mult, const Character& def,
                             bool defIsDefending);

    // Deterministic damage value without the luck-based evasion roll.
    static int estimateDamage(const Character& atk, float mult, const Character& def,
                              bool defIsDefending);

private:
    enum class SideIdx { A = 0, B = 1 };

    static int idx(Side s) { return s == Side::A ? 0 : 1; }

    void beginBattle();       // 从菜单进入战斗，进行抛硬币
    void endTurn(Side acted); // 正常回合结束（+p 后计算下一行动方）
    void startActorTurn(Side s);
    void setNextActor(Side s);

    void performAttack();
    void performDefend();
    void performSwap(int benchIdx);
    bool performSkill(int skillIdx);

    void applyDamageTo(Side targetSide, int dmg);
    void handleDeath(Side deadSide);
    void doReplacement(Side side, int rosterIdx);

    void pushEvent(const BattleEvent& ev);
    void pushInfo(const std::string& msg);

    void aiUpdate(float dt);
    void aiExecuteDecision();

    Team teams_[2];
    float speedBar_[2];
    float timer_ = 0.0f;
    bool vsAI_ = false;
    Phase phase_ = Phase::Menu;
    Side currentActor_ = Side::A;
    Side coinWinner_ = Side::A;
    Side winner_ = Side::A;
    int deathSide_ = -1;
    bool aiThinking_ = false;
    std::vector<BattleEvent> events_;
};

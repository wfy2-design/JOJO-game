// 核心逻辑自动化测试（不依赖 SFML/UI）
#include <cstdio>
#include <cstring>

#include "config/ConfigParser.h"
#include "core/BattleSystem.h"
#include "core/Team.h"

static int failures = 0;

#define CHECK(cond, msg)                                          \
    do {                                                          \
        if (!(cond)) {                                            \
            printf("FAIL: %s\n", msg);                            \
            ++failures;                                           \
        }                                                         \
    } while (0)

int main(int argc, char** argv) {
    // Used by test_coin_toss.ps1 to verify independent process launches.
    if (argc == 2 && std::strcmp(argv[1], "--coin-only") == 0) {
        BattleSystem probe;
        if (!probe.handleKey(Key::Num1)) return 2;
        std::printf("%c\n", probe.coinWinner() == Side::A ? 'A' : 'B');
        return 0;
    }

    // ---- 1. 配置解析 ----
    std::vector<Character> teamA, teamB;
    std::string err;
    bool ok = ConfigParser::loadCharacters("config/characters.cfg", teamA, teamB, err);
    if (!ok) {
        printf("CONFIG FAIL: %s\n", err.c_str());
        return 1;
    }
    CHECK(teamA.size() == 3, "队伍A应有3名角色");
    CHECK(teamB.size() == 3, "队伍B应有3名角色");
    CHECK(teamA[0].name == u8"空条承太郎" && teamB[0].name == u8"迪奥",
          "演示双方首发角色应正确加载");
    for (const Character& character : teamA)
        CHECK(character.imagePath.find("graph/graph/") == 0,
              "队伍A角色应配置graph/graph图片");
    for (const Character& character : teamB)
        CHECK(character.imagePath.find("graph/graph/") == 0,
              "队伍B角色应配置graph/graph图片");
    CHECK(teamA[0].skills.size() == 2, "角色技能应从配置中完整加载");
    CHECK(teamA[0].skills[0].apCost == 3, "技能AP消耗应正确解析");
    printf("配置解析: 队伍A=%zu 队伍B=%zu\n", teamA.size(), teamB.size());

    // ---- 2. 伤害公式 ----
    // 战士: 基础伤害30 力量14  → 攻击伤害 = 30*(1+14/50) = 38.4
    // 骑士: 防御12             → 38.4/(1+12/50) = 30.97 → 四舍五入 31
    // 骑士运气4 → 8% 概率 miss，结果为 31 或 -1
    const Character& warrior = teamA[1];
    const Character& knight = teamA[0];
    int dmg = BattleSystem::computeDamage(warrior, 1.0f, knight, false);
    CHECK(dmg == -1 || dmg == 31, "攻击伤害应=31（或闪避）");
    printf("普通攻击伤害: %d (期望31或闪避)\n", dmg);

    // 防御减伤50%: 38.4*0.5/1.24 = 15.48 → 15
    int dmgD = BattleSystem::computeDamage(warrior, 1.0f, knight, true);
    CHECK(dmgD == -1 || dmgD == 15, "防御状态下伤害应=15（或闪避）");
    printf("防御状态伤害: %d (期望15或闪避)\n", dmgD);

    // 技能倍率: 致命一击 mult=2.4 → 30*2.4*1.28/1.24 = 74.32 → 74
    int dmgS = BattleSystem::computeDamage(warrior, 2.4f, knight, false);
    CHECK(dmgS == -1 || dmgS == 74, "技能伤害应=74（或闪避）");
    printf("技能(致命一击)伤害: %d (期望74或闪避)\n", dmgS);

    // AI estimates must be stable and must not consume an evasion roll.
    CHECK(BattleSystem::estimateDamage(warrior, 1.0f, knight, false) == 31,
          "确定性普通攻击估算应=31");
    CHECK(BattleSystem::estimateDamage(warrior, 1.0f, knight, true) == 15,
          "确定性防御伤害估算应=15");
    CHECK(BattleSystem::estimateDamage(warrior, 2.4f, knight, false) == 74,
          "确定性技能伤害估算应=74");

    // ---- 3. 战斗流程模拟（双人模式，双方无脑普攻）----
    BattleSystem battle;
    CHECK(battle.handleKey(Key::Num1), "选择双人模式");
    CHECK(battle.phase() == Phase::CoinToss, "进入抛硬币阶段");

    int guard = 0;
    bool sawDeathSelection = false;
    while (battle.phase() != Phase::GameOver && guard < 5000) {
        switch (battle.phase()) {
        case Phase::Action:
            battle.handleKey(Key::A);
            break;
        case Phase::DeathSelect:
            sawDeathSelection = true;
            CHECK(!battle.handleKey(Key::Escape), "阵亡补位不可取消");
            CHECK(battle.phase() == Phase::DeathSelect, "Esc不应退出阵亡补位");
            battle.handleKey(Key::Num1);
            break;
        case Phase::SkillSelect:
        case Phase::SwapSelect:
            battle.handleKey(Key::Escape);
            break;
        default:
            break;
        }
        battle.update(0.016f);
        ++guard;
    }
    printf("模拟结束: 阶段=%d 胜者=%d 迭代=%d\n", (int)battle.phase(),
           (int)battle.winner(), guard);
    CHECK(battle.phase() == Phase::GameOver, "战斗应正常结束");
    CHECK(battle.winner() == Side::A || battle.winner() == Side::B, "应有一方获胜");
    CHECK(sawDeathSelection, "战斗流程应经过阵亡补位阶段");

    // ---- 4. 普攻积攒行动点 ----
    {
        BattleSystem b3;
        b3.handleKey(Key::Num1);
        int g = 0;
        while (b3.phase() != Phase::Action && g < 500) {
            b3.update(0.016f);
            ++g;
        }
        CHECK(b3.phase() == Phase::Action, "到达行动阶段");
        Side actor = b3.currentActor();
        int apBefore = b3.team(actor).active().ap;
        b3.handleKey(Key::A);
        int apAfter = b3.team(actor).active().ap;
        printf("攻击前后AP: %d -> %d\n", apBefore, apAfter);
        CHECK(apAfter == (apBefore < 10 ? apBefore + 1 : 10), "普攻应+1行动点(上限10)");
    }

    // ---- 5. 选择页返回与 AI 输入屏蔽 ----
    {
        BattleSystem selection;
        selection.handleKey(Key::Num1);
        int g = 0;
        while (selection.phase() != Phase::Action && g < 500) {
            selection.update(0.016f);
            ++g;
        }
        CHECK(selection.handleKey(Key::E), "E应打开技能页");
        CHECK(selection.phase() == Phase::SkillSelect, "应进入技能选择页");
        CHECK(selection.handleKey(Key::Escape), "Esc应返回行动页");
        CHECK(selection.phase() == Phase::Action, "技能页Esc后应回到行动页");
        CHECK(selection.handleKey(Key::T), "T应打开换人页");
        CHECK(selection.phase() == Phase::SwapSelect, "应进入换人选择页");
        CHECK(selection.handleKey(Key::Escape), "Esc应返回行动页");
        CHECK(selection.phase() == Phase::Action, "换人页Esc后应回到行动页");
    }

    {
        BattleSystem aiBattle;
        aiBattle.handleKey(Key::Num2);
        int g = 0;
        while (!(aiBattle.phase() == Phase::Action &&
                 aiBattle.currentActor() == Side::B) && g < 2000) {
            if (aiBattle.phase() == Phase::Action &&
                aiBattle.currentActor() == Side::A)
                aiBattle.handleKey(Key::A);
            else
                aiBattle.update(0.016f);
            ++g;
        }
        CHECK(aiBattle.phase() == Phase::Action && aiBattle.currentActor() == Side::B,
              "应能推进到AI行动回合");
        CHECK(!aiBattle.handleKey(Key::A), "AI回合应屏蔽玩家战斗输入");
    }

    // ---- 6. 换人机制（手动构造快速验证）----
    // 单独构造战斗：队A攻击队B直到阵亡，验证退场机制不会崩溃、且能回到可行动状态
    if (failures == 0) {
        BattleSystem b2;
        b2.handleKey(Key::Num1);
        int guard2 = 0;
        while (b2.phase() != Phase::GameOver && guard2 < 5000) {
            switch (b2.phase()) {
            case Phase::Action:
                b2.handleKey(Key::A);
                break;
            case Phase::DeathSelect:
                b2.handleKey(Key::Num1);
                break;
            case Phase::SkillSelect:
            case Phase::SwapSelect:
                b2.handleKey(Key::Escape);
                break;
            default:
                break;
            }
            b2.update(0.016f);
            ++guard2;
        }
        CHECK(b2.phase() == Phase::GameOver, "第二场模拟也应正常结束");
        printf("第二场模拟结束: 胜者=%d 迭代=%d\n", (int)b2.winner(), guard2);
    }

    if (failures == 0) {
        printf("ALL TESTS PASSED\n");
        return 0;
    }
    printf("%d 项检查失败\n", failures);
    return 1;
}

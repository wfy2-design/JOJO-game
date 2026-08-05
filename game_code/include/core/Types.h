#pragma once

#include <string>
#include <vector>

// 队伍标识
enum class Side { A, B };

inline Side otherSide(Side s) { return (s == Side::A) ? Side::B : Side::A; }

// 游戏流程阶段
enum class Phase {
    Menu,        // 主菜单（选择模式）
    CoinToss,    // 抛硬币决定先后手
    Action,      // 当前角色选择行动
    SkillSelect, // 选择技能
    SwapSelect,  // 选择换上的角色
    DeathSelect, // 角色阵亡，选择补位角色
    GameOver     // 胜负结算
};

// 行动方式
enum class Action { Attack, Skill, Defend, Swap };

// 输入按键（与 SFML 解耦）
enum class Key { E, A, C, T, Num1, Num2, Num3, Escape, Enter, Space };

// 战斗事件（供 UI 表现使用）
struct BattleEvent {
    enum class Type {
        Damage, // 造成伤害 { amount = 伤害值 }
        Miss,   // 闪避
        Defend, // 进入防御
        Skill,  // 释放技能 { text = 技能名 }
        Swap,   // 换人 { text = 上场角色名 }
        Death,  // 阵亡
        Info,   // 系统提示 { text = 提示内容 }
        Turn    // 回合轮换 { side = 当前行动方 }
    };
    Type type;
    Side side;         // 事件归属方（如受到伤害的一方）
    std::string actor; // 相关角色名
    std::string text;  // 附加文本
    int amount;        // 数值
};

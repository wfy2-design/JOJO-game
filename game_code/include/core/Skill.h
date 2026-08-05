#pragma once

#include <string>

// 技能定义
struct Skill {
    std::string name;      // 技能名称
    int apCost = 0;        // 行动点消耗
    float multiplier = 1.0f; // 伤害倍率（作用于基础伤害）
};

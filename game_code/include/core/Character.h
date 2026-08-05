#pragma once

#include <string>
#include <vector>

#include "Skill.h"

// 角色运行时状态
struct Character {
    std::string name;
    std::string imagePath;
    int teamId = 1; // 1 = 队伍A, 2 = 队伍B
    int maxHp = 0;
    int hp = 0;
    int maxAp = 10; // 行动点上限固定为 10
    int ap = 0;     // 当前行动点（初始值取自配置）
    int baseDamage = 0;
    int strength = 0; // 力量 x
    int defense = 0;  // 防御 y
    int luck = 0;     // 运气 z
    int speed = 0;    // 速度 p（整数）
    bool defending = false;
    bool alive = true;
    std::vector<Skill> skills;

    void reset() {
        hp = maxHp;
        ap = 0; // 初始行动点由配置注入后调用 reset 前的 ap 值保留，见 Team::fromConfig
        defending = false;
        alive = true;
    }

    bool isDead() const { return !alive || hp <= 0; }
    int maxApCap() const { return maxAp; }
};

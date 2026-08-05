#pragma once

#include <vector>

#include "Character.h"
#include "Types.h"

// 队伍：由若干角色组成，activeIndex 指向当前上场角色
struct Team {
    Side side;
    std::vector<Character> roster;
    int activeIndex = 0;

    Character& active() { return roster[activeIndex]; }
    const Character& active() const { return roster[activeIndex]; }

    bool allDead() const {
        for (const auto& c : roster)
            if (c.alive && c.hp > 0) return false;
        return true;
    }

    // 返回所有未阵亡且非当前上场的角色下标
    std::vector<int> aliveBench() const {
        std::vector<int> idx;
        for (size_t i = 0; i < roster.size(); ++i)
            if (static_cast<int>(i) != activeIndex && roster[i].alive && roster[i].hp > 0)
                idx.push_back(static_cast<int>(i));
        return idx;
    }

    // 返回所有未阵亡角色下标（含当前）
    std::vector<int> aliveAll() const {
        std::vector<int> idx;
        for (size_t i = 0; i < roster.size(); ++i)
            if (roster[i].alive && roster[i].hp > 0)
                idx.push_back(static_cast<int>(i));
        return idx;
    }
};

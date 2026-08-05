#pragma once

#include "core/BattleSystem.h"

// 简易人机 AI
class AIController {
public:
    // 在 aiSide 的行动回合做出决策并执行
    static void decideAction(BattleSystem& b, Side aiSide);

    // aiSide 角色阵亡时选择补位角色并执行
    static void chooseDeathReplacement(BattleSystem& b, Side aiSide);
};

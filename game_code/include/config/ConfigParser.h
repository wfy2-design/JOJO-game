#pragma once

#include <string>
#include <vector>

#include "core/Character.h"

namespace ConfigParser {

// 从配置文件加载角色，按队伍 1(A) / 2(B) 分组返回
// 失败时返回 false，并将错误信息写入 error
bool loadCharacters(const std::string& path, std::vector<Character>& teamA,
                    std::vector<Character>& teamB, std::string& error);

} // namespace ConfigParser

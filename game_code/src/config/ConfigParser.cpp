#include "config/ConfigParser.h"

#include <cstdlib>
#include <fstream>
#include <sstream>

namespace {

std::string trim(const std::string& s) {
    size_t b = s.find_first_not_of(" \t\r\n");
    if (b == std::string::npos) return "";
    size_t e = s.find_last_not_of(" \t\r\n");
    return s.substr(b, e - b + 1);
}

bool parseSkillLine(const std::string& line, Skill& out) {
    // 行格式：技能名 cost=3 mult=1.6
    std::istringstream iss(line);
    std::string token;
    if (!(iss >> out.name)) return false;
    std::string key, value;
    while (iss >> token) {
        auto eq = token.find('=');
        if (eq == std::string::npos) return false;
        key = token.substr(0, eq);
        value = token.substr(eq + 1);
        if (key == "cost")
            out.apCost = std::atoi(value.c_str());
        else if (key == "mult")
            out.multiplier = std::atof(value.c_str());
    }
    return out.apCost > 0;
}

} // namespace

namespace ConfigParser {

bool loadCharacters(const std::string& path, std::vector<Character>& teamA,
                    std::vector<Character>& teamB, std::string& error) {
    teamA.clear();
    teamB.clear();

    std::ifstream file(path);
    if (!file.is_open()) {
        error = "无法打开配置文件: " + path;
        return false;
    }

    Character cur;
    bool inCharacter = false;
    bool inSkills = false;
    bool curParsed = false;

    std::string line;
    while (std::getline(file, line)) {
        std::string t = trim(line);
        if (t.empty()) continue;
        if (t[0] == '#') continue;

        if (t == "[character]") {
            // 收尾上一个角色
            if (inCharacter && curParsed) {
                if (cur.name.empty()) {
                    error = "角色缺少名称";
                    return false;
                }
                if (cur.teamId == 1)
                    teamA.push_back(cur);
                else if (cur.teamId == 2)
                    teamB.push_back(cur);
                else {
                    error = "角色 " + cur.name + " 的队伍编号无效: " + std::to_string(cur.teamId);
                    return false;
                }
            }
            cur = Character();
            inCharacter = true;
            inSkills = false;
            curParsed = false;
            continue;
        }

        if (!inCharacter) {
            error = "配置格式错误（字段出现在 [character] 之外）: " + t;
            return false;
        }

        // Skill rows contain their own cost=/mult= fields and must be parsed
        // before treating the first '=' as a character property assignment.
        if (inSkills && t.find("cost=") != std::string::npos) {
            Skill sk;
            if (!parseSkillLine(t, sk)) {
                error = "技能配置格式错误: " + t;
                return false;
            }
            cur.skills.push_back(sk);
            continue;
        }

        if (t.find('=') == std::string::npos) continue;

        auto eq = t.find('=');
        std::string key = trim(t.substr(0, eq));
        std::string value = trim(t.substr(eq + 1));

        if (key == "name") {
            cur.name = value;
        } else if (key == "team") {
            cur.teamId = std::atoi(value.c_str());
        } else if (key == "hp") {
            cur.maxHp = cur.hp = std::atoi(value.c_str());
        } else if (key == "ap") {
            cur.ap = std::atoi(value.c_str());
        } else if (key == "baseDamage") {
            cur.baseDamage = std::atoi(value.c_str());
        } else if (key == "strength") {
            cur.strength = std::atoi(value.c_str());
        } else if (key == "defense") {
            cur.defense = std::atoi(value.c_str());
        } else if (key == "luck") {
            cur.luck = std::atoi(value.c_str());
        } else if (key == "speed") {
            cur.speed = std::atoi(value.c_str());
        } else if (key == "skills") {
            inSkills = true;
            continue;
        } else {
            continue; // 忽略未知字段
        }
        curParsed = true;
    }

    // 收尾最后一个角色
    if (inCharacter && curParsed) {
        if (cur.name.empty()) {
            error = "角色缺少名称";
            return false;
        }
        if (cur.teamId == 1)
            teamA.push_back(cur);
        else if (cur.teamId == 2)
            teamB.push_back(cur);
        else {
            error = "角色 " + cur.name + " 的队伍编号无效: " + std::to_string(cur.teamId);
            return false;
        }
    }

    if (teamA.empty() && teamB.empty()) {
        error = "配置文件中没有有效角色";
        return false;
    }
    return true;
}

} // namespace ConfigParser

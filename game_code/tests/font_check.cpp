// 诊断：字体加载 + 中文字符串编码检查（不依赖窗口）
#include <SFML/Graphics.hpp>
#include <cstdio>
#include <string>

int main() {
    // 1. 字体加载
    const char* paths[] = {"assets/fonts/simhei.ttf", "../assets/fonts/simhei.ttf"};
    sf::Font font;
    bool ok = false;
    for (auto p : paths) {
        if (font.loadFromFile(p)) {
            printf("FONT LOADED: %s\n", p);
            printf("font family: %s\n", font.getInfo().family.c_str());
            ok = true;
            break;
        }
    }
    if (!ok) {
        printf("FONT FAILED TO LOAD\n");
        return 1;
    }

    // 2. 检查中文字符串在内存中的字节是否为有效 UTF-8
    std::string s = u8"回合制对战 行动顺序";
    printf("string bytes:");
    for (unsigned char c : s)
        printf(" %02X", c);
    printf("\n");

    // 3. 用字体检查这些字符是否有字形（返回非 0 字形索引）
    bool allGlyphs = true;
    for (size_t i = 0; i < s.length();) {
        unsigned int cp = 0;
        unsigned char c = s[i];
        if (c < 0x80) { cp = c; ++i; }
        else if ((c >> 5) == 0x6) { cp = ((c & 0x1F) << 6) | (s[i+1] & 0x3F); i += 2; }
        else if ((c >> 4) == 0xE) { cp = ((c & 0x0F) << 12) | ((s[i+1] & 0x3F) << 6) | (s[i+2] & 0x3F); i += 3; }
        else if ((c >> 3) == 0x1E) { cp = ((c & 0x07) << 18) | ((s[i+1] & 0x3F) << 12) | ((s[i+2] & 0x3F) << 6) | (s[i+3] & 0x3F); i += 4; }
        else { printf("BAD UTF-8 byte: %02X\n", c); return 1; }
        if (cp >= 0x80) {
            sf::Glyph g = font.getGlyph(static_cast<sf::Uint32>(cp), 20, false, 0.0f);
            if (g.advance == 0) {
                printf("NO GLYPH for U+%04X\n", cp);
                allGlyphs = false;
            }
        }
    }
    printf("all CJK glyphs present: %s\n", allGlyphs ? "YES" : "NO");
    return allGlyphs ? 0 : 2;
}

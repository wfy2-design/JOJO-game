// 验证窗口标题：用 SFML 创建窗口，再通过 Win32 读取标题原始 UTF-16 字节
#include <SFML/Graphics.hpp>
#include <windows.h>
#include <cstdio>

int main() {
    sf::RenderWindow win(sf::VideoMode(400, 200), u8"回合制对战",
                         sf::Style::Titlebar | sf::Style::Close);
    win.display();

    wchar_t buf[128] = {0};
    int n = GetWindowTextW(win.getSystemHandle(), buf, 127);
    printf("title length=%d\n", n);
    printf("UTF-16 code units: ");
    for (int i = 0; i < n; ++i)
        printf("%04X ", (unsigned)buf[i]);
    printf("\n");
    // 正确期望: 回=56DE 合=5408 制=5236 对=5BF9 战=6218
    printf("expected : 56DE 5408 5236 5BF9 6218\n");

    // 用 fromUtf8 方式创建第二个窗口对比
    std::string s = u8"回合制对战";
    sf::RenderWindow win2(sf::VideoMode(400, 200),
                          sf::String::fromUtf8(s.begin(), s.end()),
                          sf::Style::Titlebar | sf::Style::Close);
    win2.display();
    wchar_t buf2[128] = {0};
    int n2 = GetWindowTextW(win2.getSystemHandle(), buf2, 127);
    printf("fromUtf8 title length=%d\n", n2);
    printf("fromUtf8 UTF-16 : ");
    for (int i = 0; i < n2; ++i)
        printf("%04X ", (unsigned)buf2[i]);
    printf("\n");
    printf("FIX_VALID = %s\n",
           (n2 == 5 && buf2[0]==0x56DE && buf2[4]==0x6218) ? "YES" : "NO");
    return 0;
}

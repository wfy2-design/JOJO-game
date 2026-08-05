// 决定性验证：将中文字符串渲染到图像，分析像素确认文字确实被绘制
#include <SFML/Graphics.hpp>
#include <cstdio>
#include <string>

static int countInk(const sf::Image& img) {
    int n = 0;
    for (unsigned y = 0; y < img.getSize().y; ++y)
        for (unsigned x = 0; x < img.getSize().x; ++x) {
            sf::Color c = img.getPixel(x, y);
            if (c.a > 0 && (c.r < 200 || c.g < 200 || c.b < 200))
                ++n;
        }
    return n;
}

int main() {
    sf::Font font;
    if (!font.loadFromFile("assets/fonts/simhei.ttf")) {
        printf("FONT FAILED\n");
        return 1;
    }

    sf::Image fighter;
    if (!fighter.loadFromFile("assets/images/pixel_fighter.jpg")) {
        printf("FIGHTER ASSET FAILED\n");
        return 1;
    }
    sf::Color bg = fighter.getPixel(0, 0);
    int transparent = 0;
    int opaque = 0;
    for (unsigned y = 0; y < fighter.getSize().y; ++y) {
        for (unsigned x = 0; x < fighter.getSize().x; ++x) {
            sf::Color pixel = fighter.getPixel(x, y);
            int dr = static_cast<int>(pixel.r) - bg.r;
            int dg = static_cast<int>(pixel.g) - bg.g;
            int db = static_cast<int>(pixel.b) - bg.b;
            if (dr * dr + dg * dg + db * db < 1150) {
                pixel.a = 0;
                fighter.setPixel(x, y, pixel);
                ++transparent;
            } else {
                ++opaque;
            }
        }
    }
    if (transparent < 1000 || opaque < 1000) {
        printf("FIGHTER MASK FAILED transparent=%d opaque=%d\n", transparent, opaque);
        return 1;
    }

    sf::Texture fighterTexture;
    if (!fighterTexture.loadFromImage(fighter)) {
        printf("FIGHTER TEXTURE FAILED\n");
        return 1;
    }
    fighterTexture.setSmooth(false);

    sf::RenderTexture rt;
    if (!rt.create(640, 320)) {
        printf("RENDER TEXTURE FAILED\n");
        return 1;
    }
    rt.clear(sf::Color::White);

    sf::Text t(u8"回合制对战 行动顺序", font, 32);
    t.setFillColor(sf::Color::Black);
    t.setPosition(10, 20);
    rt.draw(t);
    sf::Sprite fighterSprite(fighterTexture);
    fighterSprite.setPosition(300, 40);
    rt.draw(fighterSprite);
    rt.display();
    sf::Image img = rt.getTexture().copyToImage();

    int ink = countInk(img);
    printf("rendered ink pixels: %d (非背景像素)\n", ink);
    bool ok = ink > 2000;
    printf("RESULT: %s\n", ok ? "中文字符被正确绘制" : "渲染失败/文字为空");
    return ok ? 0 : 1;
}

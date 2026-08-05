#include "ui/UIManager.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <queue>
#include <sstream>
#include <vector>

#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif

namespace {

sf::String toUtf8(const std::string& s) {
    return sf::String::fromUtf8(s.begin(), s.end());
}

const sf::Color C_BG(11, 12, 20);
const sf::Color C_INK(8, 8, 12);
const sf::Color C_PANEL(20, 22, 32);
const sf::Color C_WHITE(247, 244, 235);
const sf::Color C_MUTED(160, 164, 178);
const sf::Color C_RED(238, 35, 47);
const sf::Color C_RED_DARK(116, 16, 26);
const sf::Color C_BLUE(53, 137, 224);
const sf::Color C_CYAN(66, 205, 202);
const sf::Color C_YELLOW(255, 210, 65);
const sf::Color C_HP(238, 45, 62);
const sf::Color C_AP(221, 66, 183);

sf::Color teamColor(Side side) { return side == Side::A ? C_BLUE : C_RED; }

float clamp01(float value) { return std::max(0.0f, std::min(1.0f, value)); }

float easeOut(float value) {
    value = clamp01(value);
    float inv = 1.0f - value;
    return 1.0f - inv * inv * inv;
}

sf::Color withAlpha(sf::Color color, float alpha) {
    color.a = static_cast<sf::Uint8>(255.0f * clamp01(alpha));
    return color;
}

bool readUtf8File(const std::string& path, std::vector<char>& bytes) {
#ifdef _WIN32
    int length = MultiByteToWideChar(CP_UTF8, 0, path.c_str(), -1, nullptr, 0);
    if (length <= 0) return false;
    std::wstring wide(static_cast<size_t>(length), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, path.c_str(), -1, &wide[0], length);
    std::FILE* file = _wfopen(wide.c_str(), L"rb");
#else
    std::FILE* file = std::fopen(path.c_str(), "rb");
#endif
    if (!file) return false;
    std::fseek(file, 0, SEEK_END);
    long size = std::ftell(file);
    std::rewind(file);
    if (size <= 0) {
        std::fclose(file);
        return false;
    }
    bytes.resize(static_cast<size_t>(size));
    bool ok = std::fread(bytes.data(), 1, bytes.size(), file) == bytes.size();
    std::fclose(file);
    return ok;
}

bool loadImageFromGamePath(const std::string& path, sf::Image& image) {
    const std::vector<std::string> prefixes = {"", "../", "../../"};
    std::vector<char> bytes;
    for (const std::string& prefix : prefixes) {
        if (readUtf8File(prefix + path, bytes) &&
            image.loadFromMemory(bytes.data(), bytes.size()))
            return true;
    }
    return false;
}

bool isBackgroundWhite(const sf::Color& color) {
    return color.r >= 225 && color.g >= 225 && color.b >= 225;
}

bool maskAndCropFighter(sf::Image& image) {
    const sf::Vector2u size = image.getSize();
    if (size.x == 0 || size.y == 0) return false;

    std::vector<unsigned char> visited(static_cast<size_t>(size.x) * size.y, 0);
    std::queue<unsigned> pending;
    auto enqueue = [&](unsigned x, unsigned y) {
        size_t index = static_cast<size_t>(y) * size.x + x;
        if (visited[index] || !isBackgroundWhite(image.getPixel(x, y))) return;
        visited[index] = 1;
        sf::Color pixel = image.getPixel(x, y);
        pixel.a = 0;
        image.setPixel(x, y, pixel);
        pending.push(static_cast<unsigned>(index));
    };

    for (unsigned x = 0; x < size.x; ++x) {
        enqueue(x, 0);
        enqueue(x, size.y - 1);
    }
    for (unsigned y = 0; y < size.y; ++y) {
        enqueue(0, y);
        enqueue(size.x - 1, y);
    }

    while (!pending.empty()) {
        unsigned index = pending.front();
        pending.pop();
        unsigned x = index % size.x;
        unsigned y = index / size.x;
        if (x > 0) enqueue(x - 1, y);
        if (x + 1 < size.x) enqueue(x + 1, y);
        if (y > 0) enqueue(x, y - 1);
        if (y + 1 < size.y) enqueue(x, y + 1);
    }

    unsigned left = size.x, top = size.y, right = 0, bottom = 0;
    bool visible = false;
    for (unsigned y = 0; y < size.y; ++y) {
        for (unsigned x = 0; x < size.x; ++x) {
            if (image.getPixel(x, y).a == 0) continue;
            visible = true;
            left = std::min(left, x);
            top = std::min(top, y);
            right = std::max(right, x);
            bottom = std::max(bottom, y);
        }
    }
    if (!visible) return false;

    const unsigned margin = 8;
    left = left > margin ? left - margin : 0;
    top = top > margin ? top - margin : 0;
    right = std::min(size.x - 1, right + margin);
    bottom = std::min(size.y - 1, bottom + margin);
    sf::Image cropped;
    cropped.create(right - left + 1, bottom - top + 1, sf::Color::Transparent);
    cropped.copy(image, 0, 0, sf::IntRect(left, top, right - left + 1,
                                          bottom - top + 1), true);
    image = cropped;
    return true;
}

} // namespace

UIManager::UIManager(BattleSystem& battle) : battle_(battle) {
    createWindow(true);
    const std::vector<std::string> fontPaths = {
        "assets/fonts/simhei.ttf", "../assets/fonts/simhei.ttf",
        "C:/Windows/Fonts/msyh.ttc", "C:/Windows/Fonts/simhei.ttf"};
    for (const auto& path : fontPaths) {
        if (font_.loadFromFile(path)) {
            fontLoaded_ = true;
            break;
        }
    }
    lastPhase_ = battle_.phase();
}

void UIManager::createWindow(bool fullscreen) {
    fullscreen_ = fullscreen;
    sf::String title = toUtf8(u8"回合制对战");
    if (fullscreen_) {
        sf::VideoMode desktop = sf::VideoMode::getDesktopMode();
        window_.create(desktop, title, sf::Style::None);
        window_.setPosition(sf::Vector2i(0, 0));
    } else {
        window_.create(sf::VideoMode(static_cast<unsigned>(W), static_cast<unsigned>(H)),
                       title, sf::Style::Titlebar | sf::Style::Close);
    }
    window_.setFramerateLimit(60);
    updateView();
}

void UIManager::updateView() {
    sf::Vector2u size = window_.getSize();
    if (size.x == 0 || size.y == 0) return;

    float windowRatio = static_cast<float>(size.x) / size.y;
    float viewRatio = W / H;
    sf::FloatRect viewport(0.0f, 0.0f, 1.0f, 1.0f);
    if (windowRatio > viewRatio) {
        viewport.width = viewRatio / windowRatio;
        viewport.left = (1.0f - viewport.width) * 0.5f;
    } else if (windowRatio < viewRatio) {
        viewport.height = windowRatio / viewRatio;
        viewport.top = (1.0f - viewport.height) * 0.5f;
    }

    sf::View view(sf::FloatRect(0.0f, 0.0f, W, H));
    view.setViewport(viewport);
    window_.setView(view);
}

void UIManager::toggleFullscreen() {
    createWindow(!fullscreen_);
}
bool UIManager::loadFighterTexture(const std::string& path, sf::Texture& texture) {
    sf::Image image;
    if (!loadImageFromGamePath(path, image) || !maskAndCropFighter(image) ||
        !texture.loadFromImage(image))
        return false;
    texture.setSmooth(true);
    return true;
}

sf::Texture* UIManager::textureFor(const Character& character) {
    if (character.imagePath.empty()) return nullptr;
    auto found = fighterTextures_.find(character.imagePath);
    if (found != fighterTextures_.end()) return found->second.get();
    if (failedTexturePaths_.count(character.imagePath) != 0) return nullptr;

    std::unique_ptr<sf::Texture> texture(new sf::Texture());
    if (!loadFighterTexture(character.imagePath, *texture)) {
        failedTexturePaths_.insert(character.imagePath);
        return nullptr;
    }
    sf::Texture* result = texture.get();
    fighterTextures_[character.imagePath] = std::move(texture);
    return result;
}

bool UIManager::pollEvents(Key& outKey, bool& quit) {
    quit = false;
    sf::Event event;
    while (window_.pollEvent(event)) {
        if (event.type == sf::Event::Closed) {
            quit = true;
            return false;
        }
        if (event.type == sf::Event::Resized) {
            updateView();
            continue;
        }
        if (event.type != sf::Event::KeyPressed) continue;
        if (event.key.code == sf::Keyboard::F11) {
            toggleFullscreen();
            return false;
        }

        switch (event.key.code) {
        case sf::Keyboard::E: outKey = Key::E; return true;
        case sf::Keyboard::A: outKey = Key::A; return true;
        case sf::Keyboard::C: outKey = Key::C; return true;
        case sf::Keyboard::T: outKey = Key::T; return true;
        case sf::Keyboard::Num1: outKey = Key::Num1; return true;
        case sf::Keyboard::Num2: outKey = Key::Num2; return true;
        case sf::Keyboard::Num3: outKey = Key::Num3; return true;
        case sf::Keyboard::Escape: outKey = Key::Escape; return true;
        case sf::Keyboard::Enter: outKey = Key::Enter; return true;
        case sf::Keyboard::Space: outKey = Key::Space; return true;
        default: break;
        }
    }
    return false;
}

void UIManager::updateTransition(float dt) {
    if (battle_.phase() != lastPhase_) {
        lastPhase_ = battle_.phase();
        transition_ = 0.0f;
    }
    transition_ = std::min(1.0f, transition_ + dt * 7.5f);

    Phase phase = battle_.phase();
    if (phase != Phase::Menu && phase != Phase::CoinToss &&
        battle_.currentActor() != viewActor_) {
        previousViewActor_ = viewActor_;
        viewActor_ = battle_.currentActor();
        viewTransition_ = 0.0f;
    }
    viewTransition_ = std::min(1.0f, viewTransition_ + dt * 3.5f);
}

void UIManager::render(float dt) {
    consumeEvents();
    updateFloats(dt);
    updateTransition(dt);
    window_.clear(C_BG);
    drawBackground();

    if (battle_.phase() == Phase::Menu) {
        drawMenu();
    } else {
        drawBattleScene();
        drawTurnOrderPanel();

        switch (battle_.phase()) {
        case Phase::CoinToss:
            drawCoinToss();
            break;
        case Phase::Action:
            if (battle_.vsAI() && battle_.currentActor() == Side::B)
                drawAiTurnNotice();
            else
                drawActionMenu();
            break;
        case Phase::SkillSelect:
        case Phase::SwapSelect:
        case Phase::DeathSelect:
            drawSelectionPanel();
            break;
        case Phase::GameOver:
            drawGameOver();
            break;
        case Phase::Menu:
            break;
        }
    }

    drawFloats();
    drawInfoBar();
    window_.display();
}

sf::Text UIManager::makeText(const std::string& str, unsigned size,
                             const sf::Color& color, sf::Vector2f pos) const {
    sf::Text text(toUtf8(str), font_, size);
    text.setFillColor(color);
    text.setPosition(pos);
    return text;
}

void UIManager::drawSkewPanel(const sf::FloatRect& rect, const sf::Color& fill,
                              const sf::Color& outline, float slant) {
    sf::ConvexShape shape(4);
    shape.setPoint(0, sf::Vector2f(rect.left + slant, rect.top));
    shape.setPoint(1, sf::Vector2f(rect.left + rect.width, rect.top));
    shape.setPoint(2, sf::Vector2f(rect.left + rect.width - slant,
                                  rect.top + rect.height));
    shape.setPoint(3, sf::Vector2f(rect.left, rect.top + rect.height));
    shape.setFillColor(fill);
    shape.setOutlineColor(outline);
    shape.setOutlineThickness(2.0f);
    window_.draw(shape);
}

void UIManager::drawBar(sf::Vector2f pos, sf::Vector2f size, float ratio,
                        const sf::Color& fill) {
    ratio = clamp01(ratio);
    sf::ConvexShape bg(4);
    bg.setPoint(0, sf::Vector2f(pos.x + 8, pos.y));
    bg.setPoint(1, sf::Vector2f(pos.x + size.x, pos.y));
    bg.setPoint(2, sf::Vector2f(pos.x + size.x - 8, pos.y + size.y));
    bg.setPoint(3, sf::Vector2f(pos.x, pos.y + size.y));
    bg.setFillColor(sf::Color(55, 57, 68));
    window_.draw(bg);

    if (ratio <= 0.0f) return;
    sf::ConvexShape value(4);
    float width = size.x * ratio;
    value.setPoint(0, sf::Vector2f(pos.x + std::min(8.0f, width), pos.y));
    value.setPoint(1, sf::Vector2f(pos.x + width, pos.y));
    value.setPoint(2, sf::Vector2f(pos.x + std::max(0.0f, width - 8), pos.y + size.y));
    value.setPoint(3, sf::Vector2f(pos.x, pos.y + size.y));
    value.setFillColor(fill);
    window_.draw(value);
}

void UIManager::drawConnector(sf::Vector2f from, sf::Vector2f to,
                              const sf::Color& color, float thickness) {
    sf::Vector2f delta(to.x - from.x, to.y - from.y);
    float length = std::sqrt(delta.x * delta.x + delta.y * delta.y);
    if (length <= 0.0f) return;
    float angle = std::atan2(delta.y, delta.x) * 180.0f / 3.14159265f;
    sf::RectangleShape line(sf::Vector2f(length, thickness));
    line.setOrigin(0.0f, thickness * 0.5f);
    line.setPosition(from);
    line.setRotation(angle);
    line.setFillColor(color);
    window_.draw(line);
}

void UIManager::drawBackground() {
    sf::ConvexShape navy(4);
    navy.setPoint(0, sf::Vector2f(0, 0));
    navy.setPoint(1, sf::Vector2f(W, 0));
    navy.setPoint(2, sf::Vector2f(W, 510));
    navy.setPoint(3, sf::Vector2f(0, 650));
    navy.setFillColor(sf::Color(14, 20, 48));
    window_.draw(navy);

    sf::ConvexShape redSlash(4);
    redSlash.setPoint(0, sf::Vector2f(0, 0));
    redSlash.setPoint(1, sf::Vector2f(390, 0));
    redSlash.setPoint(2, sf::Vector2f(330, 34));
    redSlash.setPoint(3, sf::Vector2f(0, 62));
    redSlash.setFillColor(C_RED);
    window_.draw(redSlash);

    for (int i = 0; i < 7; ++i) {
        sf::ConvexShape slash(4);
        float x = 260.0f + i * 180.0f;
        slash.setPoint(0, sf::Vector2f(x, 120));
        slash.setPoint(1, sf::Vector2f(x + 34, 112));
        slash.setPoint(2, sf::Vector2f(x - 100, 590));
        slash.setPoint(3, sf::Vector2f(x - 132, 600));
        slash.setFillColor(sf::Color(29, 36, 76, 100));
        window_.draw(slash);
    }

    sf::Text title = makeText("MIDNIGHT // BATTLE", 20, C_WHITE, sf::Vector2f(24, 11));
    title.setStyle(sf::Text::Bold);
    window_.draw(title);
}

UIManager::FighterLayout UIManager::targetFighterLayout(Side side, Side actor) const {
    bool foreground = side == actor;
    float x = side == Side::A ? 485.0f : 935.0f;
    return {sf::Vector2f(x, foreground ? 530.0f : 382.0f),
            foreground ? 330.0f : 210.0f};
}

UIManager::FighterLayout UIManager::fighterLayout(Side side) const {
    FighterLayout from = targetFighterLayout(side, previousViewActor_);
    FighterLayout to = targetFighterLayout(side, viewActor_);
    float t = clamp01(viewTransition_);
    t = t * t * (3.0f - 2.0f * t);
    return {sf::Vector2f(from.ground.x + (to.ground.x - from.ground.x) * t,
                         from.ground.y + (to.ground.y - from.ground.y) * t),
            from.height + (to.height - from.height) * t};
}

sf::Vector2f UIManager::fighterCenter(Side side) const {
    FighterLayout layout = fighterLayout(side);
    return sf::Vector2f(layout.ground.x, layout.ground.y - layout.height * 0.5f);
}
void UIManager::drawBattleScene() {
    sf::ConvexShape floor(4);
    floor.setPoint(0, sf::Vector2f(215, 420));
    floor.setPoint(1, sf::Vector2f(W, 330));
    floor.setPoint(2, sf::Vector2f(W, H));
    floor.setPoint(3, sf::Vector2f(170, H));
    floor.setFillColor(sf::Color(24, 22, 42));
    window_.draw(floor);

    sf::ConvexShape redFloor(4);
    redFloor.setPoint(0, sf::Vector2f(230, 565));
    redFloor.setPoint(1, sf::Vector2f(1050, 440));
    redFloor.setPoint(2, sf::Vector2f(930, 470));
    redFloor.setPoint(3, sf::Vector2f(260, 620));
    redFloor.setFillColor(sf::Color(117, 17, 34, 125));
    window_.draw(redFloor);

    FighterLayout a = fighterLayout(Side::A);
    FighterLayout b = fighterLayout(Side::B);
    if (a.ground.y <= b.ground.y) {
        drawFighter(Side::A, a, false);
        drawFighter(Side::B, b, true);
    } else {
        drawFighter(Side::B, b, true);
        drawFighter(Side::A, a, false);
    }
    drawStatusHud(Side::A, sf::FloatRect(270, 590, 475, 108));
    drawStatusHud(Side::B, sf::FloatRect(790, 35, 460, 108));
}

void UIManager::drawFighter(Side side, const FighterLayout& layout, bool mirrored) {
    const Character& character = battle_.team(side).active();
    bool active = battle_.phase() != Phase::CoinToss &&
                  battle_.phase() != Phase::GameOver &&
                  battle_.currentActor() == side;
    float roleScale = layout.height / 330.0f;
    sf::Vector2f center(layout.ground.x, layout.ground.y - layout.height * 0.5f);

    if (active) {
        float rayLength = layout.height * 0.47f;
        for (int i = 0; i < 12; ++i) {
            float b = (static_cast<float>(i) * 30.0f + 13.0f) * 3.14159265f / 180.0f;
            float c = (static_cast<float>(i) * 30.0f - 13.0f) * 3.14159265f / 180.0f;
            sf::ConvexShape ray(3);
            ray.setPoint(0, center);
            ray.setPoint(1, sf::Vector2f(center.x + std::cos(b) * rayLength,
                                         center.y + std::sin(b) * rayLength));
            ray.setPoint(2, sf::Vector2f(center.x + std::cos(c) * rayLength,
                                         center.y + std::sin(c) * rayLength));
            ray.setFillColor(withAlpha(teamColor(side), 0.18f));
            window_.draw(ray);
        }
    }

    sf::CircleShape shadow(70.0f);
    shadow.setOrigin(70.0f, 70.0f);
    shadow.setPosition(layout.ground.x, layout.ground.y + 2.0f);
    shadow.setScale(1.45f * roleScale, 0.24f * roleScale);
    shadow.setFillColor(sf::Color(0, 0, 0, 150));
    window_.draw(shadow);

    sf::Texture* texture = textureFor(character);
    if (texture) {
        sf::Sprite sprite(*texture);
        sf::Vector2u size = texture->getSize();
        sprite.setOrigin(size.x * 0.5f, static_cast<float>(size.y));
        sprite.setPosition(layout.ground);
        float scale = layout.height / static_cast<float>(size.y);
        if (character.isDead()) scale *= 0.9f;
        sprite.setScale(mirrored ? -scale : scale, scale);
        if (character.isDead())
            sprite.setColor(sf::Color(120, 120, 130, 180));
        window_.draw(sprite);
    } else {
        sf::CircleShape head(28.0f * roleScale);
        head.setOrigin(28.0f * roleScale, 28.0f * roleScale);
        head.setPosition(center.x, center.y - 42.0f * roleScale);
        head.setFillColor(C_WHITE);
        head.setOutlineColor(teamColor(side));
        head.setOutlineThickness(5.0f * roleScale);
        window_.draw(head);
        sf::ConvexShape body(4);
        body.setPoint(0, sf::Vector2f(center.x - 42.0f * roleScale,
                                      center.y - 12.0f * roleScale));
        body.setPoint(1, sf::Vector2f(center.x + 42.0f * roleScale,
                                      center.y - 12.0f * roleScale));
        body.setPoint(2, sf::Vector2f(center.x + 28.0f * roleScale,
                                      layout.ground.y));
        body.setPoint(3, sf::Vector2f(center.x - 28.0f * roleScale,
                                      layout.ground.y));
        body.setFillColor(C_INK);
        body.setOutlineColor(teamColor(side));
        body.setOutlineThickness(5.0f * roleScale);
        window_.draw(body);
    }

    float tagWidth = 160.0f * std::max(0.72f, roleScale);
    float tagHeight = 30.0f * std::max(0.78f, roleScale);
    float tagY = layout.ground.y + 10.0f;
    drawSkewPanel(sf::FloatRect(layout.ground.x - tagWidth * 0.5f, tagY,
                                tagWidth, tagHeight),
                  active ? teamColor(side) : C_INK, C_WHITE, 10.0f);
    unsigned tagSize = std::max(11u, static_cast<unsigned>(15.0f * roleScale));
    sf::Text tag = makeText(side == Side::A ? "TEAM A" : "TEAM B", tagSize, C_WHITE,
                            sf::Vector2f(layout.ground.x - tagWidth * 0.30f,
                                         tagY + 4.0f));
    tag.setStyle(sf::Text::Bold);
    window_.draw(tag);
}

void UIManager::drawStatusHud(Side side, const sf::FloatRect& rect) {
    const Team& team = battle_.team(side);
    const Character& ch = team.active();
    sf::Color accent = teamColor(side);

    drawSkewPanel(sf::FloatRect(rect.left + 7, rect.top + 7, rect.width, rect.height),
                  accent, C_INK, 24.0f);
    drawSkewPanel(rect, sf::Color(9, 9, 14, 242), C_WHITE, 24.0f);

    sf::Text teamTag = makeText(side == Side::A ? "PLAYER / A" : "RIVAL / B", 13,
                                accent, sf::Vector2f(rect.left + 22, rect.top + 8));
    teamTag.setStyle(sf::Text::Bold);
    window_.draw(teamTag);

    sf::Text name = makeText(ch.name, 25, C_WHITE,
                             sf::Vector2f(rect.left + 22, rect.top + 25));
    name.setStyle(sf::Text::Bold);
    window_.draw(name);

    if (ch.defending && !ch.isDead()) {
        sf::Text defend = makeText("防御中 -50%", 14, C_YELLOW,
                                   sf::Vector2f(rect.left + 128, rect.top + 31));
        window_.draw(defend);
    }

    sf::Vector2f hpPos(rect.left + 220, rect.top + 22);
    drawBar(hpPos, sf::Vector2f(205, 17),
            ch.maxHp > 0 ? static_cast<float>(ch.hp) / ch.maxHp : 0.0f, C_HP);
    sf::Text hp = makeText("HP  " + std::to_string(ch.hp) + " / " +
                               std::to_string(ch.maxHp),
                           13, C_WHITE, sf::Vector2f(hpPos.x + 8, hpPos.y - 1));
    window_.draw(hp);

    sf::Vector2f apPos(rect.left + 220, rect.top + 48);
    drawBar(apPos, sf::Vector2f(205, 15),
            ch.maxAp > 0 ? static_cast<float>(ch.ap) / ch.maxAp : 0.0f, C_AP);
    sf::Text ap = makeText("AP  " + std::to_string(ch.ap) + " / " +
                               std::to_string(ch.maxAp),
                           12, C_WHITE, sf::Vector2f(apPos.x + 8, apPos.y - 1));
    window_.draw(ap);

    std::ostringstream stats;
    stats << "STR " << ch.strength << "   DEF " << ch.defense << "   LUK "
          << ch.luck;
    sf::Text statText = makeText(stats.str(), 12, C_MUTED,
                                 sf::Vector2f(rect.left + 22, rect.top + 57));
    window_.draw(statText);

    std::string bench = "后备 ";
    for (size_t i = 0; i < team.roster.size(); ++i) {
        if (static_cast<int>(i) == team.activeIndex) continue;
        const Character& member = team.roster[i];
        bench += "  " + member.name + " " + std::to_string(member.hp);
        if (member.isDead()) bench += "[退场]";
    }
    sf::Text benchText = makeText(bench, 12, C_MUTED,
                                  sf::Vector2f(rect.left + 22, rect.top + 82));
    window_.draw(benchText);
}

void UIManager::drawTurnOrderPanel() {
    drawSkewPanel(sf::FloatRect(18, 78, 215, 474), sf::Color(7, 8, 14, 232),
                  C_WHITE, 16.0f);
    sf::ConvexShape header(4);
    header.setPoint(0, sf::Vector2f(22, 82));
    header.setPoint(1, sf::Vector2f(230, 82));
    header.setPoint(2, sf::Vector2f(214, 126));
    header.setPoint(3, sf::Vector2f(22, 126));
    header.setFillColor(C_RED);
    window_.draw(header);

    sf::Text title = makeText("NEXT ACTION", 18, C_WHITE, sf::Vector2f(36, 91));
    title.setStyle(sf::Text::Bold);
    window_.draw(title);

    std::vector<Side> order = battle_.previewTurnOrder(6);
    for (size_t i = 0; i < order.size(); ++i) {
        Side side = order[i];
        const Character& ch = battle_.team(side).active();
        float y = 139.0f + static_cast<float>(i) * 65.0f;
        sf::Color accent = teamColor(side);
        sf::Color fill = i == 0 ? accent : sf::Color(28, 29, 39, 245);
        drawSkewPanel(sf::FloatRect(32, y, 181, 53), fill,
                      i == 0 ? C_WHITE : sf::Color(74, 76, 89), 12.0f);

        sf::CircleShape number(16.0f);
        number.setPosition(39, y + 10);
        number.setFillColor(i == 0 ? C_INK : accent);
        number.setOutlineColor(C_WHITE);
        number.setOutlineThickness(2.0f);
        window_.draw(number);
        sf::Text n = makeText(std::to_string(i + 1), 15, C_WHITE,
                              sf::Vector2f(50, y + 16));
        window_.draw(n);

        sf::Text team = makeText(side == Side::A ? "A" : "B", 12,
                                 i == 0 ? C_INK : accent,
                                 sf::Vector2f(79, y + 7));
        team.setStyle(sf::Text::Bold);
        window_.draw(team);
        sf::Text name = makeText(ch.name, 16, i == 0 ? C_INK : C_WHITE,
                                 sf::Vector2f(79, y + 24));
        name.setStyle(sf::Text::Bold);
        window_.draw(name);
    }
}

void UIManager::drawCommandBlade(const std::string& key, const std::string& label,
                                 sf::Vector2f center, sf::Vector2f target,
                                 float rotation) {
    float p = easeOut(transition_);
    sf::Vector2f pos(center.x + (target.x - center.x) * p,
                     center.y + (target.y - center.y) * p);
    float scale = 0.72f + p * 0.28f;
    float alpha = p;
    const float width = 192.0f;
    const float height = 56.0f;

    sf::ConvexShape accent(4);
    accent.setPoint(0, sf::Vector2f(0, 10));
    accent.setPoint(1, sf::Vector2f(width - 20, 0));
    accent.setPoint(2, sf::Vector2f(width, height - 8));
    accent.setPoint(3, sf::Vector2f(18, height));
    accent.setOrigin(width * 0.5f, height * 0.5f);
    accent.setPosition(pos.x + 7, pos.y + 7);
    accent.setRotation(rotation);
    accent.setScale(scale, scale);
    accent.setFillColor(withAlpha(C_RED, alpha));
    window_.draw(accent);

    sf::ConvexShape blade(4);
    blade.setPoint(0, sf::Vector2f(0, 10));
    blade.setPoint(1, sf::Vector2f(width - 20, 0));
    blade.setPoint(2, sf::Vector2f(width, height - 8));
    blade.setPoint(3, sf::Vector2f(18, height));
    blade.setOrigin(width * 0.5f, height * 0.5f);
    blade.setPosition(pos);
    blade.setRotation(rotation);
    blade.setScale(scale, scale);
    blade.setFillColor(withAlpha(C_INK, alpha));
    blade.setOutlineColor(withAlpha(C_WHITE, alpha));
    blade.setOutlineThickness(2.5f);
    window_.draw(blade);

    sf::CircleShape badge(22.0f * scale);
    badge.setOrigin(22.0f * scale, 22.0f * scale);
    badge.setPosition(pos.x - 70.0f * scale, pos.y);
    badge.setFillColor(withAlpha(C_WHITE, alpha));
    badge.setOutlineColor(withAlpha(C_INK, alpha));
    badge.setOutlineThickness(4.0f);
    window_.draw(badge);

    sf::Text keyText = makeText(key, static_cast<unsigned>(24.0f * scale),
                                withAlpha(C_INK, alpha),
                                sf::Vector2f(pos.x - 78.0f * scale,
                                             pos.y - 17.0f * scale));
    keyText.setStyle(sf::Text::Bold);
    window_.draw(keyText);

    sf::Text labelText = makeText(label, static_cast<unsigned>(21.0f * scale),
                                  withAlpha(C_WHITE, alpha),
                                  sf::Vector2f(pos.x - 38.0f * scale,
                                               pos.y - 15.0f * scale));
    labelText.setStyle(sf::Text::Bold);
    labelText.setRotation(rotation);
    window_.draw(labelText);
}

void UIManager::drawActionMenu() {
    Side side = battle_.currentActor();
    sf::Vector2f center = fighterCenter(side);
    sf::Vector2f attack(center.x + 155.0f, center.y + 72.0f);
    sf::Vector2f skill(center.x + 145.0f, center.y - 96.0f);
    sf::Vector2f defend(center.x - 155.0f, center.y + 76.0f);
    sf::Vector2f swap(center.x - 145.0f, center.y - 94.0f);
    float p = easeOut(transition_);

    drawConnector(center, sf::Vector2f(center.x + (attack.x - center.x) * p,
                                       center.y + (attack.y - center.y) * p),
                  withAlpha(C_RED, p), 8.0f);
    drawConnector(center, sf::Vector2f(center.x + (skill.x - center.x) * p,
                                       center.y + (skill.y - center.y) * p),
                  withAlpha(C_RED, p), 8.0f);
    drawConnector(center, sf::Vector2f(center.x + (defend.x - center.x) * p,
                                       center.y + (defend.y - center.y) * p),
                  withAlpha(C_RED, p), 8.0f);
    drawConnector(center, sf::Vector2f(center.x + (swap.x - center.x) * p,
                                       center.y + (swap.y - center.y) * p),
                  withAlpha(C_RED, p), 8.0f);

    drawCommandBlade("A", "普通攻击", center, attack, 5.0f);
    drawCommandBlade("E", "释放技能", center, skill, -6.0f);
    drawCommandBlade("C", "防御", center, defend, -5.0f);
    drawCommandBlade("T", "下达指示", center, swap, 6.0f);

    sf::Text prompt = makeText("选择行动", 18, C_YELLOW,
                               sf::Vector2f(center.x - 40, center.y - 155));
    prompt.setStyle(sf::Text::Bold);
    window_.draw(prompt);
}

void UIManager::drawSelectionPanel() {
    Phase phase = battle_.phase();
    Side side = phase == Phase::DeathSelect
                    ? static_cast<Side>(battle_.deathSide())
                    : battle_.currentActor();
    const Team& team = battle_.team(side);
    std::vector<std::string> names;
    std::vector<std::string> details;
    std::vector<bool> enabled;
    std::string title;
    std::string subtitle;

    if (phase == Phase::SkillSelect) {
        const Character& ch = team.active();
        title = "技能 / PERSONA";
        subtitle = ch.name + "   当前 AP " + std::to_string(ch.ap);
        for (const Skill& skill : ch.skills) {
            names.push_back(skill.name);
            details.push_back("AP " + std::to_string(skill.apCost) + "   威力 x" +
                              std::to_string(skill.multiplier).substr(0, 3));
            enabled.push_back(ch.ap >= skill.apCost);
        }
    } else {
        bool forced = phase == Phase::DeathSelect;
        title = forced ? "选择替补 / REPLACEMENT" : "下达指示 / ORDER";
        subtitle = forced ? "当前角色已退场，必须选择下一位出场角色"
                          : "换人将消耗本回合行动";
        std::vector<int> candidates = forced ? team.aliveAll() : team.aliveBench();
        for (int index : candidates) {
            const Character& ch = team.roster[index];
            names.push_back(ch.name);
            details.push_back("HP " + std::to_string(ch.hp) + " / " +
                              std::to_string(ch.maxHp));
            enabled.push_back(true);
        }
    }

    float p = easeOut(transition_);
    float targetX = side == Side::A ? 640.0f : 280.0f;
    float x = targetX + (side == Side::A ? 80.0f : -80.0f) * (1.0f - p);
    float y = 170.0f;
    float height = 116.0f + static_cast<float>(names.size()) * 66.0f;
    drawSkewPanel(sf::FloatRect(x + 9, y + 9, 585, height), C_RED_DARK, C_INK, 28.0f);
    drawSkewPanel(sf::FloatRect(x, y, 585, height), sf::Color(8, 9, 15, 247),
                  C_WHITE, 28.0f);

    sf::ConvexShape titleBar(4);
    titleBar.setPoint(0, sf::Vector2f(x + 22, y - 13));
    titleBar.setPoint(1, sf::Vector2f(x + 420, y - 13));
    titleBar.setPoint(2, sf::Vector2f(x + 395, y + 35));
    titleBar.setPoint(3, sf::Vector2f(x + 8, y + 35));
    titleBar.setFillColor(C_RED);
    window_.draw(titleBar);
    sf::Text titleText = makeText(title, 24, C_WHITE, sf::Vector2f(x + 35, y - 6));
    titleText.setStyle(sf::Text::Bold);
    window_.draw(titleText);

    sf::Text sub = makeText(subtitle, 15, C_MUTED, sf::Vector2f(x + 28, y + 49));
    window_.draw(sub);

    for (size_t i = 0; i < names.size(); ++i) {
        float rowY = y + 82.0f + static_cast<float>(i) * 66.0f;
        sf::Color fill = enabled[i] ? sf::Color(30, 31, 42) : sf::Color(22, 22, 28);
        sf::Color outline = enabled[i] ? teamColor(side) : sf::Color(68, 68, 76);
        drawSkewPanel(sf::FloatRect(x + 26, rowY, 525, 52), fill, outline, 14.0f);

        sf::CircleShape number(19.0f);
        number.setPosition(x + 38, rowY + 7);
        number.setFillColor(enabled[i] ? C_WHITE : sf::Color(90, 90, 98));
        window_.draw(number);
        sf::Text key = makeText(std::to_string(i + 1), 18, C_INK,
                                sf::Vector2f(x + 49, rowY + 14));
        key.setStyle(sf::Text::Bold);
        window_.draw(key);

        sf::Color textColor = enabled[i] ? C_WHITE : sf::Color(106, 106, 116);
        sf::Text name = makeText(names[i], 20, textColor,
                                 sf::Vector2f(x + 94, rowY + 5));
        name.setStyle(sf::Text::Bold);
        window_.draw(name);
        sf::Text detail = makeText(details[i], 13, enabled[i] ? C_MUTED : C_RED,
                                   sf::Vector2f(x + 94, rowY + 31));
        window_.draw(detail);
        if (!enabled[i]) {
            sf::Text locked = makeText("AP不足", 14, C_RED,
                                       sf::Vector2f(x + 452, rowY + 16));
            locked.setStyle(sf::Text::Bold);
            window_.draw(locked);
        }
    }

    std::string footer = phase == Phase::DeathSelect ? "按数字键确认出场角色"
                                                      : "数字键选择   ESC 返回";
    sf::Text hint = makeText(footer, 14, C_YELLOW,
                             sf::Vector2f(x + 29, y + height - 27));
    window_.draw(hint);
}

void UIManager::drawCoinToss() {
    sf::RectangleShape overlay(sf::Vector2f(W, H));
    overlay.setFillColor(sf::Color(0, 0, 0, 150));
    window_.draw(overlay);

    float p = easeOut(transition_);
    drawSkewPanel(sf::FloatRect(393, 250, 520, 176), sf::Color(8, 8, 13, 245),
                  C_WHITE, 34.0f);
    sf::CircleShape coin(42.0f * p);
    coin.setOrigin(42.0f * p, 42.0f * p);
    coin.setPosition(480, 335);
    coin.setFillColor(C_YELLOW);
    coin.setOutlineColor(C_INK);
    coin.setOutlineThickness(8.0f);
    window_.draw(coin);
    sf::Text q = makeText("?", static_cast<unsigned>(42.0f * p), C_INK,
                          sf::Vector2f(467, 303));
    q.setStyle(sf::Text::Bold);
    window_.draw(q);
    sf::Text title = makeText("先攻判定", 37, C_WHITE, sf::Vector2f(550, 278));
    title.setStyle(sf::Text::Bold);
    window_.draw(title);
    sf::Text sub = makeText("抛硬币决定首位行动者", 19, C_MUTED,
                            sf::Vector2f(550, 339));
    window_.draw(sub);
}

void UIManager::drawAiTurnNotice() {
    float p = easeOut(transition_);
    drawSkewPanel(sf::FloatRect(846, 460 + (1.0f - p) * 28.0f, 340, 58),
                  sf::Color(8, 8, 13, 235), C_RED, 18.0f);
    sf::Text text = makeText("RIVAL THINKING...", 21, C_WHITE,
                             sf::Vector2f(889, 475 + (1.0f - p) * 28.0f));
    text.setStyle(sf::Text::Bold);
    window_.draw(text);
}

void UIManager::drawMenu() {
    sf::ConvexShape whiteSlash(4);
    whiteSlash.setPoint(0, sf::Vector2f(0, 145));
    whiteSlash.setPoint(1, sf::Vector2f(1080, 35));
    whiteSlash.setPoint(2, sf::Vector2f(970, 245));
    whiteSlash.setPoint(3, sf::Vector2f(0, 360));
    whiteSlash.setFillColor(C_WHITE);
    window_.draw(whiteSlash);

    sf::ConvexShape blackSlash(4);
    blackSlash.setPoint(0, sf::Vector2f(0, 190));
    blackSlash.setPoint(1, sf::Vector2f(1010, 78));
    blackSlash.setPoint(2, sf::Vector2f(900, 222));
    blackSlash.setPoint(3, sf::Vector2f(0, 335));
    blackSlash.setFillColor(C_INK);
    window_.draw(blackSlash);

    sf::Text title = makeText("回合制对战", 70, C_WHITE, sf::Vector2f(110, 161));
    title.setStyle(sf::Text::Bold);
    window_.draw(title);
    sf::Text english = makeText("TURN-BASED BATTLE", 24, C_RED,
                                sf::Vector2f(116, 254));
    english.setStyle(sf::Text::Bold);
    window_.draw(english);

    drawSkewPanel(sf::FloatRect(410, 390, 490, 74), C_INK, C_WHITE, 24.0f);
    drawSkewPanel(sf::FloatRect(435, 484, 490, 74), C_INK, C_WHITE, 24.0f);
    sf::Text pvp = makeText("1   双人对战", 28, C_WHITE, sf::Vector2f(457, 409));
    pvp.setStyle(sf::Text::Bold);
    window_.draw(pvp);
    sf::Text ai = makeText("2   人机对战", 28, C_WHITE, sf::Vector2f(482, 503));
    ai.setStyle(sf::Text::Bold);
    window_.draw(ai);
    sf::Text hint = makeText("按数字键开始", 18, C_YELLOW, sf::Vector2f(568, 593));
    window_.draw(hint);
}

void UIManager::drawGameOver() {
    sf::RectangleShape overlay(sf::Vector2f(W, H));
    overlay.setFillColor(sf::Color(0, 0, 0, 188));
    window_.draw(overlay);

    Side winner = battle_.winner();
    sf::Color accent = teamColor(winner);
    sf::ConvexShape band(4);
    band.setPoint(0, sf::Vector2f(0, 245));
    band.setPoint(1, sf::Vector2f(W, 175));
    band.setPoint(2, sf::Vector2f(W, 452));
    band.setPoint(3, sf::Vector2f(0, 518));
    band.setFillColor(accent);
    window_.draw(band);
    sf::ConvexShape inner(4);
    inner.setPoint(0, sf::Vector2f(0, 273));
    inner.setPoint(1, sf::Vector2f(W, 205));
    inner.setPoint(2, sf::Vector2f(W, 419));
    inner.setPoint(3, sf::Vector2f(0, 486));
    inner.setFillColor(C_INK);
    window_.draw(inner);

    sf::Text over = makeText("BATTLE COMPLETE", 54, C_WHITE,
                             sf::Vector2f(344, 268));
    over.setStyle(sf::Text::Bold);
    window_.draw(over);
    std::string win = winner == Side::A ? "队伍 A 获胜" : "队伍 B 获胜";
    sf::Text result = makeText(win, 34, accent, sf::Vector2f(505, 354));
    result.setStyle(sf::Text::Bold);
    window_.draw(result);
    sf::Text hint = makeText("ENTER / SPACE 返回主菜单", 18, C_MUTED,
                             sf::Vector2f(487, 445));
    window_.draw(hint);
}

void UIManager::consumeEvents() {
    std::vector<BattleEvent> events = battle_.takeEvents();
    for (const BattleEvent& event : events) {
        switch (event.type) {
        case BattleEvent::Type::Damage: {
            sf::Vector2f pos = fighterCenter(event.side);
            pos.x -= 40.0f;
            pos.y -= 28.0f;
            sf::Text text = makeText("-" + std::to_string(event.amount), 42, C_RED, pos);
            text.setStyle(sf::Text::Bold);
            floats_.push_back({text, 0.0f, 1.4f, pos});
            break;
        }
        case BattleEvent::Type::Miss: {
            sf::Vector2f pos = fighterCenter(event.side);
            pos.x -= 55.0f;
            pos.y -= 28.0f;
            sf::Text text = makeText("MISS!", 35, C_WHITE, pos);
            text.setStyle(sf::Text::Bold);
            floats_.push_back({text, 0.0f, 1.4f, pos});
            break;
        }
        case BattleEvent::Type::Skill: {
            sf::Text text = makeText(event.actor + " 使用「" + event.text + "」", 19,
                                     C_YELLOW, sf::Vector2f());
            infos_.push_back({text, 0.0f, 2.2f, sf::Vector2f()});
            break;
        }
        case BattleEvent::Type::Defend: {
            sf::Text text = makeText(event.actor + " 进入防御状态", 19, C_YELLOW,
                                     sf::Vector2f());
            infos_.push_back({text, 0.0f, 2.0f, sf::Vector2f()});
            break;
        }
        case BattleEvent::Type::Swap: {
            sf::Text text = makeText(event.text + " 上场", 19, C_YELLOW,
                                     sf::Vector2f());
            infos_.push_back({text, 0.0f, 2.2f, sf::Vector2f()});
            break;
        }
        case BattleEvent::Type::Death: {
            sf::Text text = makeText(event.actor + " 已退场", 20, C_RED,
                                     sf::Vector2f());
            infos_.push_back({text, 0.0f, 2.8f, sf::Vector2f()});
            break;
        }
        case BattleEvent::Type::Info: {
            sf::Text text = makeText(event.text, 18, C_WHITE, sf::Vector2f());
            infos_.push_back({text, 0.0f, 2.6f, sf::Vector2f()});
            break;
        }
        case BattleEvent::Type::Turn: {
            sf::Text text = makeText(event.actor + " 的回合 / " + event.text, 18,
                                     C_WHITE, sf::Vector2f());
            infos_.push_back({text, 0.0f, 1.8f, sf::Vector2f()});
            break;
        }
        }
    }
}

void UIManager::updateFloats(float dt) {
    for (FloatText& item : floats_) {
        item.age += dt;
        item.text.setPosition(item.start.x, item.start.y - item.age * 46.0f);
        sf::Color color = item.text.getFillColor();
        color.a = static_cast<sf::Uint8>(255.0f * clamp01(1.0f - item.age / item.ttl));
        item.text.setFillColor(color);
    }
    floats_.erase(std::remove_if(floats_.begin(), floats_.end(),
                                 [](const FloatText& item) { return item.age >= item.ttl; }),
                  floats_.end());

    for (FloatText& item : infos_) {
        item.age += dt;
        sf::Color color = item.text.getFillColor();
        color.a = static_cast<sf::Uint8>(255.0f * clamp01(1.0f - item.age / item.ttl));
        item.text.setFillColor(color);
    }
    infos_.erase(std::remove_if(infos_.begin(), infos_.end(),
                                [](const FloatText& item) { return item.age >= item.ttl; }),
                 infos_.end());
}

void UIManager::drawFloats() {
    for (const FloatText& item : floats_) window_.draw(item.text);
}

void UIManager::drawInfoBar() {
    if (infos_.empty() || battle_.phase() == Phase::Menu) return;
    size_t first = infos_.size() > 3 ? infos_.size() - 3 : 0;
    size_t line = 0;
    for (size_t i = first; i < infos_.size(); ++i, ++line) {
        float y = 54.0f + static_cast<float>(line) * 36.0f;
        sf::Color textColor = infos_[i].text.getFillColor();
        float alpha = static_cast<float>(textColor.a) / 255.0f;
        drawSkewPanel(sf::FloatRect(286, y, 470, 29),
                      withAlpha(sf::Color(7, 8, 13), alpha * 0.88f),
                      withAlpha(C_RED, alpha), 10.0f);
        sf::Text text = infos_[i].text;
        text.setPosition(306, y + 3);
        window_.draw(text);
    }
}

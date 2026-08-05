#pragma once

#include <SFML/Graphics.hpp>
#include <vector>
#include <map>
#include <memory>
#include <set>
#include <string>

#include "core/BattleSystem.h"
#include "core/Types.h"

struct FloatText {
    sf::Text text;
    float age = 0.0f;
    float ttl = 1.5f;
    sf::Vector2f start;
};

class UIManager {
public:
    explicit UIManager(BattleSystem& battle);

    bool windowOpen() const { return window_.isOpen(); }
    bool pollEvents(Key& outKey, bool& quit);
    void render(float dt);

private:
    struct FighterLayout {
        sf::Vector2f ground;
        float height = 0.0f;
    };

    void consumeEvents();
    void updateTransition(float dt);
    void createWindow(bool fullscreen);
    void updateView();
    void toggleFullscreen();
    bool loadFighterTexture(const std::string& path, sf::Texture& texture);
    sf::Texture* textureFor(const Character& character);
    FighterLayout targetFighterLayout(Side side, Side actor) const;
    FighterLayout fighterLayout(Side side) const;
    sf::Vector2f fighterCenter(Side side) const;

    void drawBackground();
    void drawBattleScene();
    void drawTurnOrderPanel();
    void drawFighter(Side side, const FighterLayout& layout, bool mirrored);
    void drawStatusHud(Side side, const sf::FloatRect& rect);
    void drawActionMenu();
    void drawCommandBlade(const std::string& key, const std::string& label,
                          sf::Vector2f center, sf::Vector2f target, float rotation);
    void drawSelectionPanel();
    void drawCoinToss();
    void drawMenu();
    void drawGameOver();
    void drawAiTurnNotice();
    void updateFloats(float dt);
    void drawFloats();
    void drawInfoBar();

    sf::Text makeText(const std::string& str, unsigned size, const sf::Color& color,
                      sf::Vector2f pos) const;
    void drawSkewPanel(const sf::FloatRect& rect, const sf::Color& fill,
                       const sf::Color& outline, float slant = 18.0f);
    void drawBar(sf::Vector2f pos, sf::Vector2f size, float ratio,
                 const sf::Color& fill);
    void drawConnector(sf::Vector2f from, sf::Vector2f to, const sf::Color& color,
                       float thickness);

    BattleSystem& battle_;
    sf::RenderWindow window_;
    sf::Font font_;
    bool fontLoaded_ = false;
    std::map<std::string, std::unique_ptr<sf::Texture>> fighterTextures_;
    std::set<std::string> failedTexturePaths_;
    std::vector<FloatText> floats_;
    std::vector<FloatText> infos_;
    Phase lastPhase_ = Phase::Menu;
    float transition_ = 1.0f;
    Side previousViewActor_ = Side::A;
    Side viewActor_ = Side::A;
    float viewTransition_ = 1.0f;
    bool fullscreen_ = true;

    static constexpr float W = 1280.0f;
    static constexpr float H = 720.0f;
};

#pragma once

#include <SFML/Graphics.hpp>
#include <vector>

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
    void consumeEvents();
    void updateTransition(float dt);
    bool loadFighterTexture();

    void drawBackground();
    void drawBattleScene();
    void drawTurnOrderPanel();
    void drawFighter(Side side, sf::Vector2f center, bool mirrored);
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
    sf::Texture fighterTexture_;
    bool fontLoaded_ = false;
    bool fighterLoaded_ = false;
    std::vector<FloatText> floats_;
    std::vector<FloatText> infos_;
    Phase lastPhase_ = Phase::Menu;
    float transition_ = 1.0f;

    static constexpr float W = 1280.0f;
    static constexpr float H = 720.0f;
};

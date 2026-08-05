#include <SFML/System/Clock.hpp>

#include "core/BattleSystem.h"
#include "ui/UIManager.h"

int main() {
    BattleSystem battle;
    UIManager ui(battle);
    sf::Clock clock;

    while (ui.windowOpen()) {
        Key key;
        bool quit = false;
        if (ui.pollEvents(key, quit)) {
            battle.handleKey(key);
        }
        if (quit) break;

        float dt = clock.restart().asSeconds();
        if (dt > 0.05f) dt = 0.05f;

        battle.update(dt);
        ui.render(dt);
    }
    return 0;
}

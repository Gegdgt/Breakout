local Feedback = require("src.feedback")
local Life = {}
function Life.lose(game)
    if game.state ~= "playing" or game.quitRequested then return false end
    -- Un ataque afecta a la ronda completa; la ausencia de pelotas no descontara otra vida.
    for _, id in ipairs(game.world:query("Ball")) do game.world:destroy(id) end
    game.lives = game.lives - 1
    if game.lives > 0 then game:respawnRound() else game:gameOver() end
    Feedback.emit(game, "life_lost", game.config.WIDTH / 2, game.config.PADDLE_Y)
    return true
end
return Life

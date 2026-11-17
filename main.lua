-- Punto de entrada del proyecto.
local Game = require("src.game")
local game

function love.load()
    game = Game.new()
end

function love.update(dt)
    game:update(dt)
end

function love.draw()
    game:draw()
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" and (game.state == "won" or game.state == "lost") then
        game:reset()
    end
end

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

function love.keypressed(key, scancode, isrepeat)
    game:keypressed(key, isrepeat)
end

function love.focus(focused)
    game:focus(focused)
end

function love.quit()
    if game then game:quit() end
end

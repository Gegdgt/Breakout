-- Vistas de componentes para las pruebas; no duplican ni simulan el estado ECS.
local Ball = require("src.ball")
local Helpers = {}

function Helpers.entity(game, id)
    if not id then return nil end
    return {id = id, position = game.world:get(id, "Position"),
            velocity = game.world:get(id, "Velocity"), collider = game.world:get(id, "Collider"),
            powerUp = game.world:get(id, "PowerUp")}
end

function Helpers.query(game, component)
    local result = {}
    for _, id in ipairs(game.world:query(component)) do
        result[#result + 1] = Helpers.entity(game, id)
    end
    return result
end

function Helpers.balls(game) return Helpers.query(game, "Ball") end
function Helpers.bricks(game) return Helpers.query(game, "Brick") end
function Helpers.powers(game) return Helpers.query(game, "PowerUp") end
function Helpers.paddle(game) return Helpers.query(game, "PaddleControl")[1] end

function Helpers.setBallCount(game, count)
    for _, id in ipairs(game.world:query("Ball")) do game.world:destroy(id) end
    for index = 1, count do Ball.spawn(game.world, game.config) end
end

function Helpers.keepBricks(game, indices)
    local ids = game.world:query("Brick")
    local keep = {}
    for _, index in ipairs(indices) do keep[ids[index]] = true end
    for _, id in ipairs(ids) do
        if not keep[id] then game.world:destroy(id) end
    end
    game.remaining = game.world:count("Brick")
end

return Helpers

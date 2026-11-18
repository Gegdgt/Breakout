-- Sistema de poderes: fabrica, sorteo, caida, recoleccion y MULTIBALL.
local Components = require("src.ecs.components")
local Collision = require("src.collision")
local Movement = require("src.ecs.systems.movement_system")
local Ball = require("src.ball")
local Powerups = {}
Powerups.MULTIBALL = "multiball"

function Powerups.spawn(world, config, kind, centerX, centerY)
    assert(kind == Powerups.MULTIBALL, "Tipo de power-up desconocido")
    local renderable = Components.renderable({0.98, 0.81, 0.35}, 3, 20)
    renderable.label = "x3"
    renderable.labelColor = {0.08, 0.10, 0.14}
    return world:create({
        Position = Components.position(centerX - config.POWERUP_W / 2, centerY - config.POWERUP_H / 2),
        Velocity = Components.velocity(0, config.POWERUP_FALL_SPEED),
        Collider = Components.collider(config.POWERUP_W, config.POWERUP_H),
        Renderable = renderable,
        PowerUp = Components.powerUp(kind, "MULTIBALL x3"),
    })
end

function Powerups.trySpawn(world, config, position, collider, chance)
    if love.math.random() < chance then
        return Powerups.spawn(world, config, Powerups.MULTIBALL,
            position.x + collider.w / 2, position.y + collider.h / 2)
    end
end

function Powerups.activate(game, kind)
    if game.state ~= "playing" or game.quitRequested then return end
    if kind == Powerups.MULTIBALL then
        local world, config = game.world, game.config
        local originals = world:query("Ball", "Position", "Velocity", "Collider")
        local angle = math.rad(config.MULTIBALL_SPREAD_DEGREES)
        -- Instantanea: las copias no se vuelven a multiplicar en este recorrido.
        for _, id in ipairs(originals) do
            if world:has(id, "Ball") then
                for direction = -1, 1, 2 do
                    if world:count("Ball") >= config.MAX_BALLS then return end
                    Ball.cloneRotated(world, id, direction * angle, config)
                end
            end
        end
    end
end

function Powerups.update(game, dt)
    local world, config = game.world, game.config
    local collected = {}
    local paddles = world:query("PaddleControl", "Position", "Collider")
    local powers = world:query("PowerUp", "Position", "Velocity", "Collider")
    for index = #powers, 1, -1 do
        local id = powers[index]
        if world:has(id, "PowerUp") then
            Movement.step(world, id, dt)
            local position = world:get(id, "Position")
            local collider = world:get(id, "Collider")
            local pickedUp = false
            for _, paddle in ipairs(paddles) do
                if world:has(paddle, "PaddleControl") and Collision.overlaps(
                    position, collider, world:get(paddle, "Position"), world:get(paddle, "Collider")) then
                    collected[#collected + 1] = world:get(id, "PowerUp").kind
                    world:destroy(id)
                    pickedUp = true
                    break
                end
            end
            if not pickedUp and position.y >= config.HEIGHT then world:destroy(id) end
        end
    end
    -- Resolver todas las recogidas antes de crear pelotas, como en el juego original.
    for _, kind in ipairs(collected) do Powerups.activate(game, kind) end
end

return Powerups

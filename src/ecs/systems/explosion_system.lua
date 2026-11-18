local Components = require("src.ecs.components")
local Movement = require("src.ecs.systems.movement_system")
local Damage = require("src.ecs.systems.damage_system")
local Feedback = require("src.feedback")
local Explosion = {}

function Explosion.reset(game)
    game.explosions = {queue = {}, head = 1, tail = 0}
end

local function particles(game, event, available)
    local count = math.min(game.config.EXPLOSION_PARTICLES, available)
    local duration = game.config.EXPLOSION_VISUAL_SECONDS
    for index = 1, count do
        local angle = index / count * math.pi * 2
        game.world:create({Position = Components.position(event.x, event.y),
            Velocity = Components.velocity(math.cos(angle) * event.radius / duration, math.sin(angle) * event.radius / duration),
            Collider = Components.collider(3, 3), Renderable = Components.renderable({1, 0.65, 0.25}, 0, 25),
            ExplosionParticle = {remaining = duration, duration = duration}})
    end
    return count
end

function Explosion.pending(game) return game.explosions.head <= game.explosions.tail end

function Explosion.process(game)
    if game.quitRequested or not Explosion.pending(game) then return end
    local world, events, config = game.world, game.explosions, game.config
    local ids = world:query("Brick", "Position", "Collider")
    local available = math.max(0, config.MAX_EXPLOSION_PARTICLES - world:count("ExplosionParticle"))
    local processed = 0
    -- Cola iterativa: cada explosivo se elimina antes de encolar su unico evento.
    while Explosion.pending(game) and processed < config.MAX_EXPLOSIONS_PER_UPDATE do
        local event = events.queue[events.head]
        events.queue[events.head], events.head = nil, events.head + 1
        processed = processed + 1
        Feedback.emit(game, "explosion", event.x, event.y)
        available = available - particles(game, event, available)
        for _, id in ipairs(ids) do
            if world:has(id, "Brick", "Position", "Collider") then
                local p, size = world:get(id, "Position"), world:get(id, "Collider")
                local dx = math.max(p.x - event.x, 0, event.x - p.x - size.w)
                local dy = math.max(p.y - event.y, 0, event.y - p.y - size.h)
                if dx * dx + dy * dy <= event.radius * event.radius then Damage.hit(game, id, event.damage, "explosion") end
            end
        end
    end
    if not Explosion.pending(game) then Explosion.reset(game) end
end

function Explosion.updateVisuals(world, dt)
    for _, id in ipairs(world:query("ExplosionParticle", "Position", "Velocity", "Renderable")) do
        local particle = world:get(id, "ExplosionParticle")
        particle.remaining = particle.remaining - dt
        if particle.remaining <= 0 then world:destroy(id)
        else
            Movement.step(world, id, dt)
            world:get(id, "Renderable").alpha = particle.remaining / particle.duration
        end
    end
end

return Explosion

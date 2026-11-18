local Components = require("src.ecs.components")
local Movement = require("src.ecs.systems.movement_system")
local Damage = require("src.ecs.systems.damage_system")
local Feedback = require("src.feedback")
local Explosion = {}

function Explosion.reset(game)
    game.explosions = {queue = {}, head = 1, tail = 0, processed = {}}
end

local function particles(game, event, available)
    local count = math.min(game.config.EXPLOSION_PARTICLES, available)
    local duration = game.config.EXPLOSION_VISUAL_SECONDS
    for index = 1, count do
        local direction = (index - 1) % 4
        local fraction = math.ceil(index / 4) / math.ceil(count / 4)
        local vx = direction == 0 and 1 or (direction == 2 and -1 or 0)
        local vy = direction == 1 and 1 or (direction == 3 and -1 or 0)
        game.world:create({Position = Components.position(event.x, event.y),
            Velocity = Components.velocity(vx * event.reachX * fraction / duration, vy * event.reachY * fraction / duration),
            Collider = Components.collider(3, 3), Renderable = Components.renderable({1, 0.65, 0.25}, 0, 25),
            ExplosionParticle = {remaining = duration, duration = duration}})
    end
    return count
end

function Explosion.pending(game) return game.explosions.head <= game.explosions.tail end

function Explosion.process(game)
    if game.quitRequested or not Explosion.pending(game) then return end
    local world, events, config = game.world, game.explosions, game.config
    local cells = {}
    for _, id in ipairs(world:query("Brick", "GridPosition")) do
        local grid = world:get(id, "GridPosition")
        cells[grid.row .. ":" .. grid.column] = id
    end
    local available = math.max(0, config.MAX_EXPLOSION_PARTICLES - world:count("ExplosionParticle"))
    local processed = 0
    -- Cola iterativa: cada explosivo se elimina antes de encolar su unico evento.
    while Explosion.pending(game) and processed < config.MAX_EXPLOSIONS_PER_UPDATE do
        local event = events.queue[events.head]
        events.queue[events.head], events.head = nil, events.head + 1
        processed = processed + 1
        if not events.processed[event.source] then
            events.processed[event.source] = true
            Feedback.emit(game, "explosion", event.x, event.y)
            available = available - particles(game, event, available)
            if event.row and event.column then
                for _, offset in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}}) do
                    local id = cells[(event.row + offset[1]) .. ":" .. (event.column + offset[2])]
                    if id then Damage.hit(game, id, event.damage, "explosion") end
                end
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

local Components = require("src.ecs.components")
local Movement = require("src.ecs.systems.movement_system")
local Particles = {}
local normalTrail, fireTrail = {0.6, 0.82, 1}, {1, 0.42, 0.12}

local function spawn(game, x, y, vx, vy, style, color, trail)
    local bus = game.feedback
    if bus.particleCount >= game.config.MAX_FEEDBACK_PARTICLES then return false end
    if trail and bus.trailCount >= game.config.MAX_TRAIL_PARTICLES then return false end
    local visual = Components.renderable(color, 0, 5)
    visual.alpha = style.alpha
    game.world:create({Position = Components.position(x, y), Velocity = Components.velocity(vx, vy),
        Renderable = visual, Particle = Components.particle(style, trail)})
    bus.particleCount = bus.particleCount + 1
    if trail then bus.trailCount = bus.trailCount + 1 end
    return true
end

function Particles.emit(game, event, budget)
    local style = game.config.FEEDBACK_STYLES[event.kind]
    if not style or not event.x or not event.y then return 0 end
    if event.kind == "victory" or event.kind == "level_complete" or event.kind == "life_lost" then
        local needed = math.min(style.count, budget) - (game.config.MAX_FEEDBACK_PARTICLES - game.feedback.particleCount)
        -- Reservar el resultado reemplazando efectos antiguos, nunca entidades de juego.
        if needed > 0 then
            for _, id in ipairs(game.world:query("Particle")) do
                local particle = game.world:get(id, "Particle")
                if particle.trail then game.feedback.trailCount = game.feedback.trailCount - 1 end
                game.world:destroy(id)
                game.feedback.particleCount = game.feedback.particleCount - 1
                needed = needed - 1
                if needed <= 0 then break end
            end
        end
    end
    local count = math.min(style.count, budget, game.config.MAX_FEEDBACK_PARTICLES - game.feedback.particleCount)
    for index = 1, count do
        local angle = index / style.count * math.pi * 2 + event.serial * 0.7
        local speed = style.speed * (0.55 + (index % 4) * 0.15)
        spawn(game, event.x, event.y, math.cos(angle) * speed, math.sin(angle) * speed,
            style, event.color or style.color, false)
    end
    return count
end

function Particles.update(game, dt)
    local state, world, bus, config = game.state, game.world, game.feedback, game.config
    if game.quitRequested or state == "paused" or state == "menu" or state == "options"
        or state == "level_select" or state == "level_intro" or state == "encyclopedia" then return end
    local count, trails = 0, 0
    for _, id in ipairs(world:query("Particle", "Position", "Velocity", "Renderable")) do
        local particle, p, v = world:get(id, "Particle"), world:get(id, "Position"), world:get(id, "Velocity")
        particle.remaining = particle.remaining - dt
        if particle.remaining <= 0 then world:destroy(id)
        else
            -- Integracion exacta de aceleracion constante, independiente de la particion de dt.
            p.y = p.y + particle.gravity * dt * dt / 2
            Movement.step(world, id, dt)
            v.vy = v.vy + particle.gravity * dt
            world:get(id, "Renderable").alpha = particle.alpha * particle.remaining / particle.duration
            count = count + 1; if particle.trail then trails = trails + 1 end
        end
    end
    bus.particleCount, bus.trailCount = count, trails
    if state ~= "playing" or dt <= 0 then return end
    bus.trailClock = bus.trailClock + dt
    if bus.trailClock < config.TRAIL_INTERVAL then return end
    bus.trailClock = bus.trailClock % config.TRAIL_INTERVAL -- Sin rafaga de recuperacion tras un dt largo.
    local balls = world:query("Ball", "Position", "Collider", "Velocity")
    if #balls == 0 then return end
    local attempts = math.min(#balls, config.TRAILS_PER_TICK)
    for _ = 1, attempts do
        bus.trailCursor = bus.trailCursor % #balls + 1
        local id = balls[bus.trailCursor]
        local ball, p, c, v = world:get(id, "Ball"), world:get(id, "Position"), world:get(id, "Collider"), world:get(id, "Velocity")
        if not ball.held and (v.vx ~= 0 or v.vy ~= 0) then
            spawn(game, p.x + c.w / 2, p.y + c.h / 2, 0, 0, config.TRAIL_STYLE,
                ball.fire and fireTrail or normalTrail, true)
        end
    end
end

return Particles

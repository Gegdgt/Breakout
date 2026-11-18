-- Efectos compartidos de la ronda; los datos viven en el paddle y las pelotas.
local Components = require("src.ecs.components")
local Ball = require("src.ball")
local Effects = {}

function Effects.get(game)
    return game.world:get(game.paddleId, "TimedEffect"), game.world:get(game.paddleId, "PaddlePower")
end

local function resize(game, width)
    local world, id = game.world, game.paddleId
    local p, c = world:get(id, "Position"), world:get(id, "Collider")
    local center = p.x + c.w / 2
    c.w = math.min(width, game.config.WIDTH)
    p.x = math.max(0, math.min(center - c.w / 2, game.config.WIDTH - c.w))
end

function Effects.release(game)
    local _, power = Effects.get(game)
    local id = power and power.heldBall
    if not id then return false end
    power.heldBall = nil
    if not game.world:has(id, "Ball") then return false end
    game.world:get(id, "Ball").held = nil
    Ball.limitSpeed(game.world:get(id, "Velocity"), game.config)
    return true
end

function Effects.follow(game)
    local _, power = Effects.get(game)
    local id = power and power.heldBall
    if not id then return end
    local world = game.world
    if not world:has(id, "Ball") then power.heldBall = nil; return end
    local ball, p, c = world:get(id, "Ball"), world:get(id, "Position"), world:get(id, "Collider")
    local pp, pc = world:get(game.paddleId, "Position"), world:get(game.paddleId, "Collider")
    ball.held.offset = math.max(-pc.w / 2, math.min(pc.w / 2, ball.held.offset))
    p.x = math.max(0, math.min(pp.x + pc.w / 2 + ball.held.offset - c.w / 2, game.config.WIDTH - c.w))
    p.y = pp.y - c.h
end

function Effects.capture(game, id)
    local timers, power = Effects.get(game)
    if not timers or timers.magnet <= 0 or power.heldBall then return false end
    local world = game.world
    local p, c = world:get(id, "Position"), world:get(id, "Collider")
    local pp, pc = world:get(game.paddleId, "Position"), world:get(game.paddleId, "Collider")
    world:get(id, "Ball").held = {offset = math.max(-pc.w / 2, math.min(pc.w / 2, p.x + c.w / 2 - pp.x - pc.w / 2))}
    power.heldBall = id
    Effects.follow(game)
    return true
end

function Effects.activate(game, kind)
    local timers, power = Effects.get(game)
    if not timers then return false end
    local world, config = game.world, game.config
    if kind == "giant_paddle" then
        timers.giant_paddle = config.GIANT_PADDLE_SECONDS
        resize(game, power.baseWidth * config.GIANT_PADDLE_SCALE)
        Effects.follow(game)
    elseif kind == "fireball" then
        timers.fireball = config.FIREBALL_SECONDS
        for _, id in ipairs(world:query("Ball")) do Ball.setFire(world, id, true) end
    elseif kind == "magnet" then
        timers.magnet = config.MAGNET_SECONDS
    elseif kind == "laser" then
        power.ammo = config.LASER_AMMO
    elseif kind == "shield" then
        timers.shield = config.SHIELD_SECONDS
        if power.shieldId then world:destroy(power.shieldId) end
        local visual = Components.renderable({0.35, 0.75, 1}, 2, 25)
        power.shieldId = world:create({
            Position = Components.position(0, config.HEIGHT - config.SHIELD_BOTTOM_MARGIN),
            Collider = Components.collider(config.WIDTH, config.SHIELD_HEIGHT),
            Renderable = visual, Shield = {hits = config.SHIELD_HITS, maximum = config.SHIELD_HITS},
        })
    elseif kind == "extra_life" then
        game.lives = math.min(config.MAX_LIVES, game.lives + 1)
    else return false end
    return true
end

function Effects.hitShield(game, id, previousY)
    local timers, power = Effects.get(game)
    local world = game.world
    local shieldId = power and power.shieldId
    if not shieldId or not world:has(shieldId, "Shield") then return false end
    local p, v, c = world:get(id, "Position"), world:get(id, "Velocity"), world:get(id, "Collider")
    local top = world:get(shieldId, "Position").y
    if v.vy <= 0 or previousY + c.h > top + game.config.CONTACT_EPSILON or p.y + c.h < top then return false end
    p.y, v.vy = top - c.h, -math.abs(v.vy)
    Ball.limitSpeed(v, game.config)
    local shield = world:get(shieldId, "Shield")
    shield.hits = shield.hits - 1
    if shield.hits <= 0 then
        world:destroy(shieldId)
        power.shieldId, timers.shield = nil, 0
    else world:get(shieldId, "Renderable").alpha = 0.35 + 0.65 * shield.hits / shield.maximum end
    return true
end

function Effects.update(game, dt)
    local timers, power = Effects.get(game)
    if not timers then return end
    power.cooldown = math.max(0, power.cooldown - dt)
    for kind, remaining in pairs(timers) do
        if remaining > 0 then
            timers[kind] = remaining <= dt + 0.000000001 and 0 or remaining - dt
            if timers[kind] == 0 then
                if kind == "giant_paddle" then resize(game, power.baseWidth)
                elseif kind == "fireball" then
                    for _, id in ipairs(game.world:query("Ball")) do Ball.setFire(game.world, id, false) end
                elseif kind == "magnet" then Effects.release(game)
                elseif kind == "shield" then
                    if power.shieldId then game.world:destroy(power.shieldId) end
                    power.shieldId = nil
                end
            end
        end
    end
end

function Effects.clear(game)
    local timers, power = Effects.get(game)
    if timers then
        Effects.release(game)
        resize(game, power.baseWidth)
        for kind in pairs(timers) do timers[kind] = 0 end
        power.ammo, power.cooldown, power.guaranteedElapsed, power.shieldId = 0, 0, 0, nil
        power.bossLaserElapsed = 0
        for _, id in ipairs(game.world:query("Ball")) do Ball.setFire(game.world, id, false) end
    end
    for _, component in ipairs({"PowerUp", "Projectile", "Shield", "EnemyProjectile"}) do
        for _, id in ipairs(game.world:query(component)) do game.world:destroy(id) end
    end
end

return Effects

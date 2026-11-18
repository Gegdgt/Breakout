local Components = require("src.ecs.components")
local Collision = require("src.collision")
local Movement = require("src.ecs.systems.movement_system")
local Effects = require("src.ecs.systems.power_effect_system")
local Damage = require("src.ecs.systems.damage_system")
local Feedback = require("src.feedback")
local Projectiles = {}

function Projectiles.fire(game)
    if game.state ~= "playing" or game.quitRequested then return false end
    local _, power = Effects.get(game)
    local world, config = game.world, game.config
    if not power or power.ammo <= 0 or power.cooldown > 0
        or world:count("Projectile") + 2 > config.MAX_PLAYER_PROJECTILES then return false end
    local p, c = world:get(game.paddleId, "Position"), world:get(game.paddleId, "Collider")
    for _, offset in ipairs({c.w * 0.12, c.w * 0.88}) do
        local visual = Components.renderable(config.POWERUP_TYPES.laser.color, 1, 35)
        visual.borderColor = {1, 0.9, 1}
        world:create({Position = Components.position(p.x + offset - config.LASER_W / 2, p.y - config.LASER_H),
            Velocity = Components.velocity(0, -config.LASER_SPEED),
            Collider = Components.collider(config.LASER_W, config.LASER_H), Renderable = visual,
            Projectile = Components.projectile(config)})
    end
    power.ammo, power.cooldown = power.ammo - 1, config.LASER_INTERVAL
    Feedback.emit(game, "laser", p.x + c.w / 2, p.y)
    return true
end

local function nearest(world, targets, x, y, dx, dy, shape, best, time)
    for _, id in ipairs(targets) do
        if world:has(id, "Position", "Collider") then
            local ghost, health = world:get(id, "Ghost"), world:get(id, "Health")
            if (not ghost or ghost.solid) and (not health or health.current > 0) then
                local p, c = world:get(id, "Position"), world:get(id, "Collider")
                local m = world:get(id, "Motion") or world:get(id, "PreviousPosition")
                local bx, by = m and m.previousX or p.x, m and m.previousY or p.y
                local hit = Collision.sweep(x, y, dx - (p.x - bx), dy - (p.y - by), shape, bx, by, c)
                if hit and hit < time then best, time = id, hit end
            end
        end
    end
    return best, time
end

function Projectiles.update(game, dt)
    local world = game.world
    local shots = world:query("Projectile", "Position", "Velocity", "Collider")
    if #shots == 0 then return end
    local bricks = world:query("Brick", "Position", "Collider")
    local obstacles = world:query("MovingObstacle", "Position", "Collider")
    -- Jefes y proyectiles interceptables comparten Health + Damageable.
    local receivers = world:query("Damageable", "Health", "Position", "Collider")
    for _, id in ipairs(shots) do
        if game.state ~= "playing" or game.quitRequested then return end
        local x, y = Movement.step(world, id, dt)
        local p, c = world:get(id, "Position"), world:get(id, "Collider")
        local target, time = nearest(world, bricks, x, y, p.x - x, p.y - y, c, nil, math.huge)
        target, time = nearest(world, obstacles, x, y, p.x - x, p.y - y, c, target, time)
        target, time = nearest(world, receivers, x, y, p.x - x, p.y - y, c, target, time)
        if target then
            local shot = world:get(id, "Projectile")
            local tp, tc = world:get(target, "Position"), world:get(target, "Collider")
            local previous = world:get(target, "Motion") or world:get(target, "PreviousPosition")
            local tx = previous and previous.previousX + (tp.x - previous.previousX) * time or tp.x
            local ty = previous and previous.previousY + (tp.y - previous.previousY) * time or tp.y
            local hitX = tp.x + math.max(0, math.min(tc.w, x + (p.x - x) * time + c.w / 2 - tx))
            local hitY = tp.y + math.max(0, math.min(tc.h, y + (p.y - y) * time + c.h / 2 - ty))
            Damage.hit(game, target, shot.damage, shot.source, hitX, hitY)
            world:destroy(id)
        elseif p.y + c.h < 0 or p.y > game.config.HEIGHT or p.x + c.w < 0 or p.x > game.config.WIDTH then
            world:destroy(id)
        end
    end
end

return Projectiles

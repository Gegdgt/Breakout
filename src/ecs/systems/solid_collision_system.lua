local Collision = require("src.collision")
local Ball = require("src.ball")
local Damage = require("src.ecs.systems.damage_system")
local Solid = {}

local function penetrable(world, id, fire)
    local behavior = world:get(id, "BrickBehavior")
    return fire and behavior and (behavior.kind ~= "armored" or behavior.vulnerableTo.fireball)
end

local function candidate(world, ids, x, y, dx, dy, size, best, time, nx, ny, fire)
    for index = #ids, 1, -1 do
        local id = ids[index]
        if world:has(id, "Position", "Collider") then
            local ghost = world:get(id, "Ghost")
            if (not ghost or ghost.solid) and not penetrable(world, id, fire) then
                local p, target = world:get(id, "Position"), world:get(id, "Collider")
                local motion = world:get(id, "Motion") or world:get(id, "PreviousPosition")
                local bx, by = motion and motion.previousX or p.x, motion and motion.previousY or p.y
                local hit, hitX, hitY = Collision.sweep(x, y, dx - (p.x - bx), dy - (p.y - by), size, bx, by, target)
                if hit and hit < time then best, time, nx, ny = id, hit, hitX, hitY end
            end
        end
    end
    return best, time, nx, ny
end

function Solid.resolve(game, id, previousX, previousY, bricks, obstacles)
    local world = game.world
    local position, size = world:get(id, "Position"), world:get(id, "Collider")
    local velocity, ball = world:get(id, "Velocity"), world:get(id, "Ball")
    local epsilon = game.config.CONTACT_EPSILON
    -- Solo un daño por par pelota/bloque hasta que se separen realmente.
    for target in pairs(ball.contacts) do
        local p, shape = world:get(target, "Position"), world:get(target, "Collider")
        local motion = world:get(target, "Motion") or world:get(target, "PreviousPosition")
        local x, y = p and (motion and motion.previousX or p.x), p and (motion and motion.previousY or p.y)
        if not p or not shape or previousX + size.w < x - epsilon or previousX > x + shape.w + epsilon
            or previousY + size.h < y - epsilon or previousY > y + shape.h + epsilon then ball.contacts[target] = nil end
    end
    local dx, dy = position.x - previousX, position.y - previousY
    local target, time, nx, ny = candidate(world, bricks, previousX, previousY, dx, dy, size, nil, math.huge, nil, nil, ball.fire)
    target, time, nx, ny = candidate(world, obstacles, previousX, previousY, dx, dy, size, target, time, nx, ny)
    if ball.fire then
        for _, brick in ipairs(bricks) do
            if world:has(brick, "Brick") and not ball.contacts[brick] and penetrable(world, brick, true) then
                local ghost = world:get(brick, "Ghost")
                local p, c, motion = world:get(brick, "Position"), world:get(brick, "Collider"), world:get(brick, "Motion")
                local bx, by = motion and motion.previousX or p.x, motion and motion.previousY or p.y
                local hit = Collision.sweep(previousX, previousY, dx - (p.x - bx), dy - (p.y - by), size, bx, by, c)
                if hit and hit <= time and (not ghost or ghost.solid) then
                    ball.contacts[brick] = true
                    Damage.hit(game, brick, game.config.FIREBALL_DAMAGE, "fireball")
                end
            end
        end
    end
    if not target then return end
    local p, collider = world:get(target, "Position"), world:get(target, "Collider")
    local targetVelocity = world:get(target, "Velocity")
    local vx, vy = targetVelocity and targetVelocity.vx or 0, targetVelocity and targetVelocity.vy or 0
    position.x, position.y = previousX + dx * time, previousY + dy * time
    if nx ~= 0 then
        position.x = nx < 0 and p.x - size.w or p.x + collider.w
        if (velocity.vx - vx) * nx < 0 then velocity.vx = 2 * vx - velocity.vx end
    else
        position.y = ny < 0 and p.y - size.h or p.y + collider.h
        if (velocity.vy - vy) * ny < 0 then velocity.vy = 2 * vy - velocity.vy end
    end
    Ball.limitSpeed(velocity, game.config)
    if not ball.contacts[target] then
        ball.contacts[target] = true
        if world:has(target, "Brick") or world:has(target, "Boss") then
            local hitX = math.max(p.x, math.min(p.x + collider.w, position.x + size.w / 2))
            local hitY = math.max(p.y, math.min(p.y + collider.h, position.y + size.h / 2))
            if world:has(target, "Boss") then
                -- El punto debil se evalua en la pose del impacto, no al final del frame.
                local previous = world:get(target, "PreviousPosition")
                local bx = previous.previousX + (p.x - previous.previousX) * time
                local by = previous.previousY + (p.y - previous.previousY) * time
                hitX = p.x + math.max(0, math.min(collider.w, previousX + dx * time + size.w / 2 - bx))
                hitY = p.y + math.max(0, math.min(collider.h, previousY + dy * time + size.h / 2 - by))
            end
            Damage.hit(game, target, ball.fire and game.config.FIREBALL_DAMAGE or game.config.BALL_DAMAGE,
                ball.fire and "fireball" or "ball", hitX, hitY)
        end
    end
end

return Solid

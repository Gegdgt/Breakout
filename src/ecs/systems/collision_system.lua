local Collision = require("src.collision")
local Movement = require("src.ecs.systems.movement_system")
local Bricks = require("src.bricks")
local Powerups = require("src.powerups")
local CollisionSystem = {}

local function accelerate(velocity, multiplier)
    velocity.vx = velocity.vx * multiplier
    velocity.vy = velocity.vy * multiplier
end

local function updateBall(game, id, dt)
    local world, config = game.world, game.config
    local position = world:get(id, "Position")
    local velocity = world:get(id, "Velocity")
    local collider = world:get(id, "Collider")
    local ball = world:get(id, "Ball")
    local previousX, previousY = Movement.step(world, id, dt)

    local left = position.x <= 0
    local right = position.x + collider.w >= config.WIDTH
    if config.ECS_ASSIGNMENT_MODE and (left or right) then
        print("ECS: pelota toco la pared " .. (left and "izquierda" or "derecha"))
        io.stdout:flush()
        game.quitRequested = true
        love.event.quit()
        return -- Sin rebote, aceleracion ni mas sistemas tras solicitar el cierre.
    end

    if left then
        position.x = 0
        if velocity.vx < 0 then
            velocity.vx = math.abs(velocity.vx)
            accelerate(velocity, ball.wallMultiplier)
        end
    elseif right then
        position.x = config.WIDTH - collider.w
        if velocity.vx > 0 then
            velocity.vx = -math.abs(velocity.vx)
            accelerate(velocity, ball.wallMultiplier)
        end
    end
    if position.y <= 0 then
        position.y = 0
        if velocity.vy < 0 then
            velocity.vy = math.abs(velocity.vy)
            accelerate(velocity, ball.wallMultiplier)
        end
    end

    if position.y + collider.h >= config.HEIGHT then
        world:destroy(id)
        return
    end

    for _, paddle in ipairs(world:query("PaddleControl", "Position", "Collider")) do
        local paddlePosition = world:get(paddle, "Position")
        local paddleCollider = world:get(paddle, "Collider")
        if velocity.vy > 0 and Collision.overlaps(position, collider,
            paddlePosition, paddleCollider) then
            local ballCenterX = position.x + collider.w / 2
            local paddleCenterX = paddlePosition.x + paddleCollider.w / 2
            local impact = (ballCenterX - paddleCenterX) / (paddleCollider.w / 2)
            impact = math.max(-1, math.min(1, impact))
            local angle = impact * math.rad(60)
            local speed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)
                * ball.paddleMultiplier
            -- Separar antes de salir hacia arriba para evitar contactos repetidos.
            position.y = paddlePosition.y - collider.h
            velocity.vx = speed * math.sin(angle)
            velocity.vy = -speed * math.cos(angle)
        end
    end

    local bricks = world:query("Brick", "Position", "Collider")
    for index = #bricks, 1, -1 do
        local brick = bricks[index]
        local brickPosition = world:get(brick, "Position")
        local brickCollider = world:get(brick, "Collider")
        if Collision.overlaps(position, collider, brickPosition, brickCollider) then
            Collision.bounceFromBrick(position, collider, velocity,
                brickPosition, brickCollider, previousX, previousY)
            local chance = world:get(brick, "Brick").dropChance
            if Bricks.destroy(game, brick) then
                Powerups.trySpawn(world, config, brickPosition, brickCollider, chance)
            end
            break
        end
    end
end

function CollisionSystem.update(game, dt)
    local world = game.world
    local balls = world:query("Ball", "Position", "Velocity", "Collider")
    -- Conservar el orden original: mover y resolver cada pelota, de ultima a primera.
    for index = #balls, 1, -1 do
        local id = balls[index]
        if world:has(id, "Ball", "Position", "Velocity", "Collider") then
            updateBall(game, id, dt)
        end
        if game.state == "won" or game.quitRequested then return end
    end
end

return CollisionSystem

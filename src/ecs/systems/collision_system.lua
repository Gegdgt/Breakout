local Collision = require("src.collision")
local Movement = require("src.ecs.systems.movement_system")
local Ball = require("src.ball")
local Solid = require("src.ecs.systems.solid_collision_system")
local Effects = require("src.ecs.systems.power_effect_system")
local Feedback = require("src.feedback")
local CollisionSystem = {}

local function accelerate(velocity, multiplier, config)
    velocity.vx = velocity.vx * multiplier
    velocity.vy = velocity.vy * multiplier
    Ball.limitSpeed(velocity, config)
end

local function updateBall(game, id, dt, paddles, bricks, obstacles)
    local world, config = game.world, game.config
    local position = world:get(id, "Position")
    local velocity = world:get(id, "Velocity")
    local collider = world:get(id, "Collider")
    local ball = world:get(id, "Ball")
    if ball.held then return end
    -- Respaldo para velocidades modificadas por otros sistemas antes de integrar.
    Ball.limitSpeed(velocity, config)
    local previousX, previousY = Movement.step(world, id, dt)
    ball.previousX, ball.previousY = previousX, previousY

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
            accelerate(velocity, ball.wallMultiplier, config)
            Feedback.emit(game, "wall", position.x, position.y + collider.h / 2)
        end
    elseif right then
        position.x = config.WIDTH - collider.w
        if velocity.vx > 0 then
            velocity.vx = -math.abs(velocity.vx)
            accelerate(velocity, ball.wallMultiplier, config)
            Feedback.emit(game, "wall", position.x + collider.w, position.y + collider.h / 2)
        end
    end
    if position.y <= 0 then
        position.y = 0
        if velocity.vy < 0 then
            velocity.vy = math.abs(velocity.vy)
            accelerate(velocity, ball.wallMultiplier, config)
            Feedback.emit(game, "wall", position.x + collider.w / 2, position.y)
        end
    end

    for _, paddle in ipairs(paddles) do
        local paddlePosition = world:get(paddle, "Position")
        local paddleCollider = world:get(paddle, "Collider")
        local overlaps = Collision.overlaps(position, collider, paddlePosition, paddleCollider)
        local hit = velocity.vy > 0 and Collision.sweep(previousX, previousY,
            position.x - previousX, position.y - previousY, collider, paddlePosition.x, paddlePosition.y, paddleCollider)
        if hit then
            -- Conservar el impacto direccional original; barrer solo evita saltar un paddle fino.
            if not overlaps then position.x = previousX + (position.x - previousX) * hit end
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
            Ball.limitSpeed(velocity, config)
            Feedback.emit(game, "paddle", ballCenterX, paddlePosition.y)
            if Effects.capture(game, id) then return end
        end
    end

    Effects.hitShield(game, id, previousY)
    if position.y + collider.h >= config.HEIGHT then
        world:destroy(id)
        return
    end

    Solid.resolve(game, id, previousX, previousY, bricks, obstacles)
end

function CollisionSystem.update(game, dt)
    local world = game.world
    local balls = world:query("Ball", "Position", "Velocity", "Collider")
    local paddles = world:query("PaddleControl", "Position", "Collider")
    local bricks = world:query("Brick", "Position", "Collider")
    local obstacles = world:query("MovingObstacle", "Position", "Collider")
    if world:has(game.bossId, "Boss") and not world:get(game.bossId, "Boss").defeated then
        obstacles[#obstacles + 1] = game.bossId
    end
    -- Conservar el orden original: mover y resolver cada pelota, de ultima a primera.
    for index = #balls, 1, -1 do
        local id = balls[index]
        if world:has(id, "Ball", "Position", "Velocity", "Collider") then
            updateBall(game, id, dt, paddles, bricks, obstacles)
        end
        if game.state ~= "playing" or game.quitRequested then return end
    end
end

return CollisionSystem

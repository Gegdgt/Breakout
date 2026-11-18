-- Fabrica de paddle y sistema de entrada horizontal.
local Components = require("src.ecs.components")
local Movement = require("src.ecs.systems.movement_system")
local Paddle = {}

function Paddle.spawn(world, config, level)
    local renderable = Components.renderable({0.78, 0.83, 0.88}, 5, 30)
    renderable.borderColor = {0.44, 0.52, 0.60}
    return world:create({
        Position = Components.position(level and level.spawn.paddle.x or (config.WIDTH - config.PADDLE_W) / 2,
                                       level and level.spawn.paddle.y or config.PADDLE_Y),
        Velocity = Components.velocity(0, 0),
        Collider = Components.collider(config.PADDLE_W, config.PADDLE_H),
        Renderable = renderable,
        PaddleControl = Components.paddleControl(config),
        TimedEffect = Components.timedEffect(),
        PaddlePower = Components.paddlePower(config),
        Invulnerability = {remaining = config.PADDLE_INVULNERABILITY_SECONDS},
        PreviousPosition = Components.previousPosition(level and level.spawn.paddle.x or (config.WIDTH - config.PADDLE_W) / 2,
            level and level.spawn.paddle.y or config.PADDLE_Y),
    })
end

-- Reposicion entre vidas: conserva la entidad, su ancho y todos sus poderes.
function Paddle.resetPosition(world, config, id, level)
    local position, collider = world:get(id, "Position"), world:get(id, "Collider")
    local velocity, previous = world:get(id, "Velocity"), world:get(id, "PreviousPosition")
    position.x, position.y = (config.WIDTH - collider.w) / 2, level.spawn.paddle.y
    velocity.vx, velocity.vy = 0, 0
    previous.previousX, previous.previousY = position.x, position.y
    world:get(id, "PaddleControl").sprinting = false
    world:get(id, "Invulnerability").remaining = config.PADDLE_INVULNERABILITY_SECONDS
end

function Paddle.update(world, config, dt)
    local shiftDown = love.keyboard.isDown(unpack(config.CONTROLS.sprint))
    for _, id in ipairs(world:query("PaddleControl", "Position", "Velocity", "Collider")) do
        local control = world:get(id, "PaddleControl")
        local position = world:get(id, "Position")
        local velocity = world:get(id, "Velocity")
        local collider = world:get(id, "Collider")
        local previous = world:get(id, "PreviousPosition")
        previous.previousX, previous.previousY = position.x, position.y
        local direction = 0
        if love.keyboard.isDown(unpack(control.leftKeys)) then direction = direction - 1 end
        if love.keyboard.isDown(unpack(control.rightKeys)) then direction = direction + 1 end
        local sprint = shiftDown and direction ~= 0
        local speed = control.speed * (sprint and control.sprintMultiplier or 1)
        velocity.vx, velocity.vy = direction * speed, 0
        Movement.step(world, id, dt)
        position.x = math.max(0, math.min(position.x, config.WIDTH - collider.w))
        -- El HUD indica desplazamiento real, no un intento de salir por el borde.
        control.sprinting = sprint and position.x ~= previous.previousX
    end
end

return Paddle

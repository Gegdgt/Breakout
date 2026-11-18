-- Fabrica de paddle y sistema de entrada horizontal.
local Components = require("src.ecs.components")
local Movement = require("src.ecs.systems.movement_system")
local Paddle = {}

function Paddle.spawn(world, config)
    local renderable = Components.renderable({0.78, 0.83, 0.88}, 5, 30)
    renderable.borderColor = {0.44, 0.52, 0.60}
    return world:create({
        Position = Components.position((config.WIDTH - config.PADDLE_W) / 2, config.PADDLE_Y),
        Velocity = Components.velocity(0, 0),
        Collider = Components.collider(config.PADDLE_W, config.PADDLE_H),
        Renderable = renderable,
        PaddleControl = Components.paddleControl(config),
    })
end

function Paddle.update(world, config, dt)
    for _, id in ipairs(world:query("PaddleControl", "Position", "Velocity", "Collider")) do
        local control = world:get(id, "PaddleControl")
        local position = world:get(id, "Position")
        local velocity = world:get(id, "Velocity")
        local collider = world:get(id, "Collider")
        local direction = 0
        if love.keyboard.isDown(unpack(control.leftKeys)) then direction = direction - 1 end
        if love.keyboard.isDown(unpack(control.rightKeys)) then direction = direction + 1 end
        velocity.vx, velocity.vy = direction * control.speed, 0
        Movement.step(world, id, dt)
        position.x = math.max(0, math.min(position.x, config.WIDTH - collider.w))
    end
end

return Paddle

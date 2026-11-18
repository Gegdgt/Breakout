-- Fabrica de pelotas y sistema de reglas (copias y perdida de la ultima pelota).
local Components = require("src.ecs.components")
local Ball = {}

function Ball.spawn(world, config)
    return world:create({
        Position = Components.position((config.WIDTH - config.BALL_SIZE) / 2, config.PADDLE_Y - 85),
        Velocity = Components.velocity(config.BALL_START_VX, config.BALL_START_VY),
        Collider = Components.collider(config.BALL_SIZE, config.BALL_SIZE),
        Renderable = Components.renderable({0.98, 0.98, 0.98}, 0, 40),
        Ball = Components.ball(config),
    })
end

-- Misma dispersion y normalizacion que antes; cada copia tiene datos propios.
function Ball.cloneRotated(world, id, angle, config)
    local position = world:get(id, "Position")
    local velocity = world:get(id, "Velocity")
    local collider = world:get(id, "Collider")
    local clone = Ball.spawn(world, config)
    local clonePosition = world:get(clone, "Position")
    local cloneVelocity = world:get(clone, "Velocity")
    local cloneCollider = world:get(clone, "Collider")
    clonePosition.x, clonePosition.y = position.x, position.y
    cloneCollider.w, cloneCollider.h = collider.w, collider.h

    local vx, vy = velocity.vx, velocity.vy
    local speed = math.sqrt(vx * vx + vy * vy)
    if speed < 0.000001 then
        vx, vy = config.BALL_START_VX, config.BALL_START_VY
        speed = math.sqrt(vx * vx + vy * vy)
    end
    local cosine, sine = math.cos(angle), math.sin(angle)
    local rotatedX = vx * cosine - vy * sine
    local rotatedY = vx * sine + vy * cosine
    local minimumAxisSpeed = speed * 0.10
    if math.abs(rotatedX) < minimumAxisSpeed then
        rotatedX = (rotatedX < 0 and -1 or 1) * minimumAxisSpeed
    end
    if math.abs(rotatedY) < minimumAxisSpeed then
        rotatedY = (rotatedY < 0 and -1 or 1) * minimumAxisSpeed
    end
    local rotatedSpeed = math.sqrt(rotatedX * rotatedX + rotatedY * rotatedY)
    cloneVelocity.vx = rotatedX * speed / rotatedSpeed
    cloneVelocity.vy = rotatedY * speed / rotatedSpeed
    return clone
end

-- Se ejecuta una sola vez despues de las colisiones de todas las pelotas.
function Ball.checkRound(game)
    if game.world:count("Ball") > 0 then return false end
    game.lives = game.lives - 1
    if game.lives > 0 then
        game:resetRound()
    else
        game.state = "lost"
        print("Game Over")
        io.stdout:flush()
    end
    return true
end

return Ball

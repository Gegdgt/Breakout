-- Fabrica de pelotas y sistema de reglas (copias y perdida de la ultima pelota).
local Components = require("src.ecs.components")
local Ball = {}

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- Punto comun para toda escritura de velocidad, incluidos futuros poderes/portales.
-- Modifica el componente de datos sin crear tablas y conserva la direccion finita.
function Ball.limitSpeed(velocity, config)
    local vx, vy, maximum = velocity.vx, velocity.vy, config.BALL_MAX_SPEED
    if not finite(vx) or not finite(vy) or not finite(maximum) or maximum <= 0 then
        velocity.vx, velocity.vy = 0, 0 -- No propagar NaN/infinito a Position.
        return 0
    end
    local speed = math.sqrt(vx * vx + vy * vy)
    if speed > maximum then
        if speed == math.huge then
            -- Entradas finitas extremas pueden desbordar al elevarse al cuadrado.
            local scale = math.max(math.abs(vx), math.abs(vy))
            vx, vy = vx / scale, vy / scale
            speed = math.sqrt(vx * vx + vy * vy)
        end
        velocity.vx = (vx / speed) * maximum
        velocity.vy = (vy / speed) * maximum
        return maximum
    end
    return speed -- Incluye cero: nunca dividir por una rapidez nula.
end

function Ball.spawn(world, config, level)
    local spawn = level and level.spawn.ball
    local initial = level and level.initialVelocity
    local velocity = Components.velocity(initial and initial.vx or config.BALL_START_VX,
                                         initial and initial.vy or config.BALL_START_VY)
    Ball.limitSpeed(velocity, config)
    local id = world:create({
        Position = Components.position(spawn and spawn.x or (config.WIDTH - config.BALL_SIZE) / 2,
                                       spawn and spawn.y or config.PADDLE_Y - 85),
        Velocity = velocity,
        Collider = Components.collider(config.BALL_SIZE, config.BALL_SIZE),
        Renderable = Components.renderable({0.98, 0.98, 0.98}, 0, 40),
        Ball = Components.ball(config),
    })
    -- Toda fabrica de pelotas hereda el efecto global de la ronda, tambien MULTIBALL.
    for _, effects in pairs(world.components.TimedEffect or {}) do
        if effects.fireball > 0 then Ball.setFire(world, id, true); break end
    end
    return id
end

function Ball.setFire(world, id, active)
    local ball, visual = world:get(id, "Ball"), world:get(id, "Renderable")
    ball.fire = active
    visual.color = active and {1, 0.40, 0.12} or {0.98, 0.98, 0.98}
    visual.borderColor = active and {1, 1, 0.85} or nil
end

-- Misma dispersion y normalizacion que antes; cada copia tiene datos propios.
function Ball.cloneRotated(world, id, angle, config, level)
    local position = world:get(id, "Position")
    local velocity = world:get(id, "Velocity")
    local collider = world:get(id, "Collider")
    local clone = Ball.spawn(world, config, level)
    local clonePosition = world:get(clone, "Position")
    local cloneVelocity = world:get(clone, "Velocity")
    local cloneCollider = world:get(clone, "Collider")
    clonePosition.x, clonePosition.y = position.x, position.y
    cloneCollider.w, cloneCollider.h = collider.w, collider.h

    local speed = Ball.limitSpeed(velocity, config)
    local vx, vy = velocity.vx, velocity.vy
    if speed < 0.000001 then
        -- La fabrica ya limito la velocidad inicial de este nivel.
        vx, vy = cloneVelocity.vx, cloneVelocity.vy
        speed = math.sqrt(vx * vx + vy * vy)
    end
    if speed == 0 then return clone end
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
    Ball.limitSpeed(cloneVelocity, config)
    return clone
end

-- Se ejecuta una sola vez despues de las colisiones de todas las pelotas.
function Ball.checkRound(game)
    if game.world:count("Ball") > 0 then return false end
    game:loseLife()
    return true
end

return Ball

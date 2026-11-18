-- Constructores de datos. Ningun componente contiene metodos o comportamiento.
local Components = {}

function Components.position(x, y)
    return {x = x, y = y}
end

function Components.velocity(vx, vy)
    return {vx = vx, vy = vy}
end

function Components.collider(w, h)
    return {w = w, h = h}
end

function Components.renderable(color, radius, layer)
    return {color = {unpack(color)}, radius = radius, layer = layer}
end

function Components.paddleControl(config)
    return {speed = config.PADDLE_SPEED, leftKeys = {"left", "a"}, rightKeys = {"right", "d"}}
end

function Components.ball(config)
    return {paddleMultiplier = config.PADDLE_SPEED_MULTIPLIER,
            wallMultiplier = config.WALL_SPEED_MULTIPLIER}
end

function Components.brick(config)
    return {dropChance = config.POWERUP_DROP_CHANCE}
end

function Components.powerUp(kind, name)
    return {kind = kind, name = name}
end

return Components

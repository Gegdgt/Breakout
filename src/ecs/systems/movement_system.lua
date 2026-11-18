local Movement = {}

-- Integrador comun a paddle, pelotas y poderes. Devuelve la posicion anterior
-- para resolver el lado de entrada al bloque sin duplicar el movimiento.
function Movement.step(world, id, dt)
    if not world:has(id, "Position", "Velocity") then return end
    local position = world:get(id, "Position")
    local velocity = world:get(id, "Velocity")
    local previousX, previousY = position.x, position.y
    position.x = position.x + velocity.vx * dt
    position.y = position.y + velocity.vy * dt
    return previousX, previousY
end

return Movement

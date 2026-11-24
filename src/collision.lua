local Collision = {}

-- Intervalo en segundos durante el cual los rectángulos coinciden en un eje.
local function axisTimes(position, size, target, targetSize, velocity)
    if velocity == 0 then
        if position + size <= target or position >= target + targetSize then return end
        return -math.huge, math.huge
    end

    local near = (target - position - size) / velocity
    local far = (target + targetSize - position) / velocity
    return math.min(near, far), math.max(near, far)
end

function Collision.sweep(ball, target, vx, vy)
    local enterX, leaveX = axisTimes(ball.x, ball.w, target.x, target.w, vx)
    local enterY, leaveY = axisTimes(ball.y, ball.h, target.y, target.h, vy)
    if not enterX or not enterY then return end

    -- El choque sucede al coincidir en ambos ejes. El último eje indica el lado.
    local enter = math.max(enterX, enterY)
    if enter < 0 or enter >= math.min(leaveX, leaveY) then return end

    local axis = enterX > enterY and "x" or "y"
    return enter, axis
end

return Collision

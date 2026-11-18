-- Colisiones AABB: misma geometria, usando componentes separados.
local Collision = {}

function Collision.overlaps(a, aSize, b, bSize)
    return a.x < b.x + bSize.w
       and a.x + aSize.w > b.x
       and a.y < b.y + bSize.h
       and a.y + aSize.h > b.y
end

-- Barrido AABB en coordenadas relativas al objetivo (tambien sirve si se mueve).
-- Devuelve tiempo normalizado [0,1] y normal de salida, sin asignar tablas.
function Collision.sweep(x, y, dx, dy, size, bx, by, target)
    if x < bx + target.w and x + size.w > bx and y < by + target.h and y + size.h > by then
        local left, right, top, bottom = x + size.w - bx, bx + target.w - x,
            y + size.h - by, by + target.h - y
        local minimum = math.min(left, right, top, bottom)
        if minimum == top then return 0, 0, -1
        elseif minimum == bottom then return 0, 0, 1
        elseif minimum == left then return 0, -1, 0
        else return 0, 1, 0 end
    end
    local enterX, exitX, enterY, exitY = -math.huge, math.huge, -math.huge, math.huge
    if dx == 0 then
        if x + size.w <= bx or x >= bx + target.w then return end
    else
        enterX, exitX = (bx - x - size.w) / dx, (bx + target.w - x) / dx
        if enterX > exitX then enterX, exitX = exitX, enterX end
    end
    if dy == 0 then
        if y + size.h <= by or y >= by + target.h then return end
    else
        enterY, exitY = (by - y - size.h) / dy, (by + target.h - y) / dy
        if enterY > exitY then enterY, exitY = exitY, enterY end
    end
    local enter, leave = math.max(enterX, enterY), math.min(exitX, exitY)
    if enter < 0 or enter > 1 or enter > leave then return end
    if enterY >= enterX then return enter, 0, dy > 0 and -1 or 1 end
    return enter, dx > 0 and -1 or 1, 0
end

-- Decide por que lado entro la pelota al bloque para dar un rebote adecuado.
function Collision.bounceFromBrick(ball, size, velocity, brick, brickSize, previousX, previousY)
    local oldRight = previousX + size.w
    local oldBottom = previousY + size.h

    if oldBottom <= brick.y then
        ball.y = brick.y - size.h
        velocity.vy = -math.abs(velocity.vy)
    elseif previousY >= brick.y + brickSize.h then
        ball.y = brick.y + brickSize.h
        velocity.vy = math.abs(velocity.vy)
    elseif oldRight <= brick.x then
        ball.x = brick.x - size.w
        velocity.vx = -math.abs(velocity.vx)
    elseif previousX >= brick.x + brickSize.w then
        ball.x = brick.x + brickSize.w
        velocity.vx = math.abs(velocity.vx)
    else
        -- Si se cruzaron las esquinas, reflejar el eje de menor penetracion.
        local overlapX = math.min(ball.x + size.w - brick.x,
                                  brick.x + brickSize.w - ball.x)
        local overlapY = math.min(ball.y + size.h - brick.y,
                                  brick.y + brickSize.h - ball.y)
        if overlapX < overlapY then
            velocity.vx = -velocity.vx
        else
            velocity.vy = -velocity.vy
        end
    end
end

return Collision

-- Colisiones AABB: misma geometria, usando componentes separados.
local Collision = {}

function Collision.overlaps(a, aSize, b, bSize)
    return a.x < b.x + bSize.w
       and a.x + aSize.w > b.x
       and a.y < b.y + bSize.h
       and a.y + aSize.h > b.y
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

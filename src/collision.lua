-- Colisiones entre rectangulos (AABB).
local Collision = {}

function Collision.overlaps(a, b)
    return a.x < b.x + b.w
       and a.x + a.w > b.x
       and a.y < b.y + b.h
       and a.y + a.h > b.y
end

-- Decide por que lado entro la pelota al bloque para dar un rebote adecuado.
function Collision.bounceFromBrick(ball, brick, previousX, previousY)
    local oldRight = previousX + ball.w
    local oldBottom = previousY + ball.h

    if oldBottom <= brick.y then
        ball.y = brick.y - ball.h
        ball.vy = -math.abs(ball.vy)
    elseif previousY >= brick.y + brick.h then
        ball.y = brick.y + brick.h
        ball.vy = math.abs(ball.vy)
    elseif oldRight <= brick.x then
        ball.x = brick.x - ball.w
        ball.vx = -math.abs(ball.vx)
    elseif previousX >= brick.x + brick.w then
        ball.x = brick.x + brick.w
        ball.vx = math.abs(ball.vx)
    else
        -- Si se cruzaron las esquinas, reflejar el eje de menor penetracion.
        local overlapX = math.min(ball.x + ball.w - brick.x,
                                  brick.x + brick.w - ball.x)
        local overlapY = math.min(ball.y + ball.h - brick.y,
                                  brick.y + brick.h - ball.y)
        if overlapX < overlapY then
            ball.vx = -ball.vx
        else
            ball.vy = -ball.vy
        end
    end
end

return Collision

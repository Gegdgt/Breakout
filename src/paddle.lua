local Paddle = {}

function Paddle.new(width, height)
    local w, h = 110, 14
    return {x = (width - w) / 2, y = height - 52, w = w, h = h, speed = 520}
end

function Paddle.inputVelocity(paddle)
    local direction = 0
    if love.keyboard.isDown("left", "a") then
        direction = direction - 1
    end
    if love.keyboard.isDown("right", "d") then
        direction = direction + 1
    end
    return direction * paddle.speed
end

-- La velocidad es constante hasta llegar al borde o agotar el tiempo.
function Paddle.motion(paddle, velocity, width, dt)
    if velocity == 0 then return 0, dt end

    local edge = velocity < 0 and 0 or width - paddle.w
    local timeToEdge = (edge - paddle.x) / velocity
    if timeToEdge <= 0 then return 0, dt end

    return velocity, math.min(dt, timeToEdge)
end

function Paddle.move(paddle, velocity, width, dt)
    paddle.x = math.max(0, math.min(width - paddle.w, paddle.x + velocity * dt))
end

function Paddle.draw(paddle)
    love.graphics.setColor(0.83, 0.87, 0.95)
    love.graphics.rectangle("fill", paddle.x, paddle.y, paddle.w, paddle.h)
end

return Paddle

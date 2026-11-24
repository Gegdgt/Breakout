local Bricks = require("src.bricks")
local Collision = require("src.collision")

local Ball = {}
local PADDLE_SPEED_GAIN = 3

function Ball.new(width, paddleY)
    local w, h = 12, 10
    return {x = (width - w) / 2, y = paddleY - 75, w = w, h = h, vx = 215, vy = -325}
end

local function timeToEdge(position, velocity, edge)
    if velocity == 0 then return math.huge end
    return (edge - position) / velocity
end

function Ball.move(ball, paddle, paddleVelocity, bricks, width, height, dt)
    local edgeX = ball.vx < 0 and 0 or width - ball.w
    local edgeY = ball.vy < 0 and 0 or height - ball.h
    local wallTimeX = timeToEdge(ball.x, ball.vx, edgeX)
    local wallTimeY = timeToEdge(ball.y, ball.vy, edgeY)

    local paddleTime = math.huge
    if ball.vy > 0 then
        -- Restar el movimiento del paddle para calcular el contacto entre ambos.
        paddleTime = Collision.sweep(ball, paddle, ball.vx - paddleVelocity, ball.vy) or math.huge
    end
    local brickIndex, brickTime, brickAxis = Bricks.firstHit(bricks, ball)
    local elapsed = math.min(dt, wallTimeX, wallTimeY, paddleTime, brickTime)
    ball.x = ball.x + ball.vx * elapsed
    ball.y = ball.y + ball.vy * elapsed

    if elapsed == paddleTime then
        ball.y = paddle.y - ball.h
        ball.vx = -ball.vx
        ball.vy = -ball.vy - PADDLE_SPEED_GAIN
    elseif elapsed == brickTime then
        local brick = table.remove(bricks, brickIndex)
        if brickAxis == "x" then
            ball.x = ball.vx > 0 and brick.x - ball.w or brick.x + brick.w
            ball.vx = -ball.vx
        else
            ball.y = ball.vy > 0 and brick.y - ball.h or brick.y + brick.h
            ball.vy = -ball.vy
        end
    else
        if elapsed == wallTimeX then
            ball.x = edgeX
            ball.vx = -ball.vx
        end
        if elapsed == wallTimeY then
            ball.y = edgeY
            if ball.vy > 0 then return elapsed, true end
            ball.vy = -ball.vy
        end
    end

    return elapsed, false
end

function Ball.draw(ball)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", ball.x, ball.y, ball.w, ball.h)
end

return Ball

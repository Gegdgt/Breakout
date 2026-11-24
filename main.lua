local Paddle = require("src.paddle")
local Ball = require("src.ball")
local Bricks = require("src.bricks")

local width, height
local paddle, ball, bricks
local finished

function love.load()
    width, height = love.window.getMode()
    paddle = Paddle.new(width, height)
    ball = Ball.new(width, paddle.y)
    bricks = Bricks.new(width)
    finished = false
end

local function finish(message)
    finished = true
    print(message)
    love.event.quit()
end

function love.update(dt)
    if finished then return end

    local inputVelocity = Paddle.inputVelocity(paddle)
    while dt > 0 do
        -- Avanzar hasta el primer impacto o hasta agotar el tiempo del frame.
        local paddleVelocity, time = Paddle.motion(paddle, inputVelocity, width, dt)
        local elapsed, lost = Ball.move(ball, paddle, paddleVelocity, bricks, width, height, time)
        Paddle.move(paddle, paddleVelocity, width, elapsed)

        if lost then
            return finish("Game Over")
        end
        if #bricks == 0 then
            return finish("You Win!")
        end

        dt = dt - elapsed
    end
end

function love.draw()
    love.graphics.clear(0.055, 0.065, 0.09)
    Bricks.draw(bricks)
    Paddle.draw(paddle)
    Ball.draw(ball)
end

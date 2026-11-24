local Paddle = require("src.paddle")
local Ball = require("src.ball")
local Bricks = require("src.bricks")

local width, height
local paddle, ball, bricks
local resultMessage

local function startAttempt()
    paddle = Paddle.new(width, height)
    ball = Ball.new(width, paddle.y)
    resultMessage = nil
end

function love.load()
    width, height = love.window.getMode()
    bricks = Bricks.new(width)
    startAttempt()
    love.graphics.setNewFont(32)
end

local function finish(message)
    resultMessage = message
    print(message)
end

function love.update(dt)
    if resultMessage then return end

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

function love.keypressed(key, _, isRepeat)
    if not resultMessage or isRepeat then return end
    if key ~= "space" and key ~= "return" and key ~= "kpenter" then return end

    if #bricks == 0 then
        bricks = Bricks.new(width)
    end
    startAttempt()
end

function love.draw()
    love.graphics.clear(0.055, 0.065, 0.09)
    Bricks.draw(bricks)
    Paddle.draw(paddle)
    Ball.draw(ball)

    if resultMessage then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(resultMessage, 0, height / 2 - 18, width, "center")
    end
end

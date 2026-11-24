local Collision = require("src.collision")

local Bricks = {}
local COLUMNS = 12
local GAP = 6
local MARGIN = 45
local TOP = 48
local HEIGHT = 20

local colors = {
    {0.90, 0.32, 0.34},
    {0.96, 0.53, 0.30},
    {0.97, 0.76, 0.32},
    {0.39, 0.77, 0.42},
    {0.26, 0.73, 0.77},
    {0.37, 0.53, 0.90},
}

function Bricks.new(width)
    local bricks = {}
    local w = (width - 2 * MARGIN - (COLUMNS - 1) * GAP) / COLUMNS

    for row, color in ipairs(colors) do
        for column = 1, COLUMNS do
            bricks[#bricks + 1] = {
                x = MARGIN + (column - 1) * (w + GAP),
                y = TOP + (row - 1) * (HEIGHT + GAP),
                w = w,
                h = HEIGHT,
                color = color,
            }
        end
    end

    return bricks
end

function Bricks.firstHit(bricks, ball)
    local index, axis
    local nearest = math.huge
    for i, brick in ipairs(bricks) do
        local time, hitAxis = Collision.sweep(ball, brick, ball.vx, ball.vy)
        if time and time < nearest then
            index, nearest, axis = i, time, hitAxis
        end
    end
    return index, nearest, axis
end

function Bricks.draw(bricks)
    for _, brick in ipairs(bricks) do
        love.graphics.setColor(brick.color)
        love.graphics.rectangle("fill", brick.x, brick.y, brick.w, brick.h)
    end
end

return Bricks

local Bricks = {}

function Bricks.create(config)
    local result = {}
    local gap = config.BRICK_GAP
    local columns = config.BRICK_COLS
    local width = (config.WIDTH - config.BRICK_SIDE_MARGIN * 2
                   - gap * (columns - 1)) / columns

    for row = 1, config.BRICK_ROWS do
        for column = 1, columns do
            result[#result + 1] = {
                x = config.BRICK_SIDE_MARGIN + (column - 1) * (width + gap),
                y = config.BRICK_TOP + (row - 1) * (config.BRICK_HEIGHT + gap),
                w = width,
                h = config.BRICK_HEIGHT,
                color = config.BRICK_COLORS[row]
            }
        end
    end

    return result
end

function Bricks.draw(bricks)
    for _, brick in ipairs(bricks) do
        local color = brick.color
        love.graphics.setColor(color[1], color[2], color[3])
        love.graphics.rectangle("fill", brick.x, brick.y, brick.w, brick.h, 2, 2)
        love.graphics.setColor(1, 1, 1, 0.12)
        love.graphics.rectangle("fill", brick.x + 2, brick.y + 2,
                                brick.w - 4, 2)
    end
end

return Bricks

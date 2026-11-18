-- Fabrica de bloques y sistema de destruccion/victoria.
local Components = require("src.ecs.components")
local Bricks = {}

function Bricks.create(world, config)
    local gap = config.BRICK_GAP
    local columns = config.BRICK_COLS
    local width = (config.WIDTH - config.BRICK_SIDE_MARGIN * 2
                   - gap * (columns - 1)) / columns
    for row = 1, config.BRICK_ROWS do
        for column = 1, columns do
            local renderable = Components.renderable(config.BRICK_COLORS[row], 2, 10)
            renderable.highlight = true
            world:create({
                Position = Components.position(
                    config.BRICK_SIDE_MARGIN + (column - 1) * (width + gap),
                    config.BRICK_TOP + (row - 1) * (config.BRICK_HEIGHT + gap)),
                Collider = Components.collider(width, config.BRICK_HEIGHT),
                Renderable = renderable,
                Brick = Components.brick(config),
            })
        end
    end
end

function Bricks.destroy(game, id)
    if not game.world:has(id, "Brick") then return false end
    game.world:destroy(id)
    game.remaining = game.world:count("Brick")
    if game.remaining == 0 then
        game.state = "won"
        print("You Win!")
        io.stdout:flush()
    end
    return true
end

return Bricks

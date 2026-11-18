-- Fabrica de bloques y sistema de destruccion/victoria.
local Components = require("src.ecs.components")
local Score = require("src.ecs.systems.score_system")
local Feedback = require("src.feedback")
local Bricks = {}

function Bricks.create(world, config, level)
    for _, spec in ipairs(level.bricks) do
        Bricks.spawn(world, config, level, spec)
    end
end

function Bricks.spawn(world, config, level, spec)
    local definition = spec.definition
    local renderable = Components.renderable(config.BRICK_TYPE_COLORS[definition.kind] or spec.color, 2, 10)
    renderable.highlight = true
    renderable.baseColor = {unpack(renderable.color)}
    renderable.labelColor = {0.06, 0.08, 0.12}
    local health = definition.health or 1
    local labels = {resistant = "R" .. health, explosive = "*", moving = "<>", ghost = "G", armored = "A", unbreakable = "[=]"}
    renderable.label = labels[definition.kind]
    if definition.kind == "armored" then renderable.borderColor = {0.85, 0.93, 1} end
    if definition.kind == "unbreakable" then
        renderable.borderColor, renderable.labelColor = {0.65, 0.73, 0.82}, {0.85, 0.90, 0.95}
    end
    local data = {
        Position = Components.position(spec.x, spec.y),
        Collider = Components.collider(spec.w, spec.h),
        Renderable = renderable,
        Brick = Components.brick(config, spec, level),
        Health = Components.health(health),
        ScoreValue = Components.scoreValue(config.SCORE_VALUES[definition.kind]),
        BrickBehavior = Components.brickBehavior(definition),
    }
    if definition.kind == "unbreakable" then
        data.Health, data.ScoreValue = nil, nil
        data.Brick.dropChance = 0
    end
    if spec.row and spec.column then data.GridPosition = {row = spec.row, column = spec.column} end
    if definition.kind == "ghost" then
        data.Ghost = Components.ghost(definition)
        renderable.alpha = data.Ghost.solid and 1 or 0.22
    end
    if spec.support then
        data.BossSupport = spec.support
        data.ScoreValue.points = 0 -- Conserva el sorteo de poderes del nivel, sin puntos ni combo.
    end
    if definition.kind == "moving" then
        data.Motion = Components.motion(spec.x, spec.y, definition.motion)
        data.Velocity = Components.velocity(0, 0)
    end
    return world:create(data)
end

function Bricks.remaining(world)
    return #world:query("Brick", "Health")
end

function Bricks.destroy(game, id)
    if not game.world:has(id, "Brick") then return false end
    if game.world:get(id, "Brick").kind == "unbreakable" then return false end
    Score.award(game, id)
    local p, c, visual = game.world:get(id, "Position"), game.world:get(id, "Collider"), game.world:get(id, "Renderable")
    if game.world:get(id, "Brick").kind ~= "explosive" then
        Feedback.emit(game, "brick", p.x + c.w / 2, p.y + c.h / 2, visual.color)
    end
    game.world:destroy(id)
    game.remaining = Bricks.remaining(game.world)
    if game.remaining == 0 then
        game:completeLevel()
    end
    return true
end

return Bricks

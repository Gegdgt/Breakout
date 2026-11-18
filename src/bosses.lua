local Components = require("src.ecs.components")
local Rules = require("src.boss_rules")
local Bosses = {}
function Bosses.create(game)
    game.bossId = nil
    local definition = game.level.boss
    if not definition then return end
    local behavior = {}
    for key, value in pairs(definition) do behavior[key] = value end
    -- Regiones locales compartidas por daño y dibujo; el cuerpo resuelve un solo rebote.
    behavior.weakPoint = Rules.weakPoint(definition, game.config)
    behavior.topWeakPoint = Rules.topWeakPoint(definition, game.config)
    local visual = Components.renderable({0.18, 0.24, 0.32}, 7, 18)
    visual.borderColor = game.level.theme.primary
    game.bossId = game.world:create({Position = Components.position(definition.x, definition.y),
        Velocity = Components.velocity(0, 0), Collider = Components.collider(definition.w, definition.h),
        Renderable = visual, Health = Components.health(definition.health),
        Boss = Components.boss(definition, game.config), BossBehavior = behavior,
        PreviousPosition = Components.previousPosition(definition.x, definition.y),
        Damageable = {sources = {ball = true, fireball = true, laser = true}, enabled = false},
        ScoreValue = Components.scoreValue(game.config.BOSS_SCORE_VALUES[definition.id])})
end
return Bosses

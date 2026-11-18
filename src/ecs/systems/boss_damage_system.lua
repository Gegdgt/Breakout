local Score = require("src.ecs.systems.score_system")
local Feedback = require("src.feedback")
local BossDamage = {}
function BossDamage.hit(game, id, amount, source, x, y)
    local world = game.world
    local boss, health = world:get(id, "Boss"), world:get(id, "Health")
    local receiver, definition = world:get(id, "Damageable"), world:get(id, "BossBehavior")
    if not boss or boss.defeated or boss.hitCooldown > 0 or boss.pendingPhase or not receiver.enabled
        or not receiver.sources[source] or type(x) ~= "number" or type(y) ~= "number" then return false end
    local p, weak = world:get(id, "Position"), definition.weakPoint
    if not (x >= p.x + weak.x and x <= p.x + weak.x + weak.w
        and y >= p.y + weak.y and y <= p.y + weak.y + weak.h + game.config.CONTACT_EPSILON) then return false end
    local floor = 0
    if definition.phases then
        for phase = boss.phase + 1, #definition.phases do floor = floor + definition.phases[phase].health end
    end
    health.current = math.max(floor, health.current - amount)
    boss.hitCooldown, boss.flash = game.config.BOSS_HIT_COOLDOWN, game.config.BOSS_HIT_FLASH
    Feedback.emit(game, "boss_hit", x, y)
    if health.current == 0 then
        boss.defeated, receiver.enabled = true, false
        world:get(id, "Velocity").vx, world:get(id, "Velocity").vy = 0, 0
        Score.award(game, id)
        Feedback.emit(game, "boss_defeat", p.x + definition.w / 2, p.y + definition.h / 2)
        for _, shot in ipairs(world:query("EnemyProjectile")) do world:destroy(shot) end
        game:completeLevel()
    elseif health.current == floor then
        boss.pendingPhase, receiver.enabled = boss.phase + 1, false
    end
    return true
end
return BossDamage

local Bricks = require("src.bricks")
local Powerups = require("src.powerups")
local BossDamage = require("src.ecs.systems.boss_damage_system")
local Feedback = require("src.feedback")
local Damage = {}

-- Fuentes explicitas y un solo punto de destruccion para todos los ataques.
function Damage.hit(game, id, amount, source, hitX, hitY)
    local world = game.world
    if game.quitRequested or game.state ~= "playing" then return false end
    if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then return false end
    if world:has(id, "Boss") then return BossDamage.hit(game, id, amount, source, hitX, hitY) end
    if not world:has(id, "Brick", "Health", "BrickBehavior") then
        local receiver, health = world:get(id, "Damageable"), world:get(id, "Health")
        if not receiver or not health or health.current <= 0 or receiver.enabled == false
            or not receiver.sources[source] then return false end
        health.current = math.max(0, health.current - amount)
        return true
    end
    local behavior, health = world:get(id, "BrickBehavior"), world:get(id, "Health")
    local ghost = world:get(id, "Ghost")
    if ghost and not ghost.solid then return false end
    if behavior.kind == "armored" and (source == "ball" or not behavior.vulnerableTo[source]) then return false end
    health.current = math.max(0, health.current - amount)
    if health.current > 0 then
        local visual = world:get(id, "Renderable")
        if visual and behavior.kind == "resistant" then
            local ratio = 0.4 + 0.6 * health.current / health.maximum
            for channel = 1, 3 do visual.color[channel] = visual.baseColor[channel] * ratio end
            visual.label = "R" .. health.current
            local p, c = world:get(id, "Position"), world:get(id, "Collider")
            Feedback.emit(game, "resistant", p.x + c.w / 2, p.y + c.h / 2, visual.color)
        end
        return true
    end
    local position, collider = world:get(id, "Position"), world:get(id, "Collider")
    local chance = world:get(id, "Brick").dropChance
    if behavior.kind == "explosive" then
        local events = game.explosions
        events.tail = events.tail + 1
        events.queue[events.tail] = {source = id, x = position.x + collider.w / 2,
            y = position.y + collider.h / 2, radius = behavior.radius, damage = behavior.damage}
    end
    if Bricks.destroy(game, id) then
        Powerups.trySpawn(world, game.config, position, collider, chance, game.level.activePowerups, game.level.boss)
    end
    return true
end

return Damage

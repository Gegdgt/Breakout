local Components = require("src.ecs.components")
local Collision = require("src.collision")
local Movement = require("src.ecs.systems.movement_system")
local Feedback = require("src.feedback")
local Enemy = {}

function Enemy.aim(game, bossId, aimX)
    local world, config = game.world, game.config
    local p, c = world:get(bossId, "Position"), world:get(bossId, "Collider")
    local cx, cy = p.x + c.w / 2, p.y + c.h + 3
    local paddleY = world:get(game.paddleId, "Position").y
    local slope = math.max(-config.ENEMY_PROJECTILE_MAX_AIM_RATIO,
        math.min(config.ENEMY_PROJECTILE_MAX_AIM_RATIO, (aimX - cx) / math.max(40, paddleY - cy)))
    return math.atan(slope), cx, cy, cx + slope * (paddleY - cy)
end

function Enemy.emit(game, bossId, aimX)
    local world, config = game.world, game.config
    local boss = world:get(bossId, "Boss")
    local available = config.MAX_ENEMY_PROJECTILES - world:count("EnemyProjectile")
    local count = boss.phase == 3 and 3 or 1
    if available < count then return end -- Una oleada completa o ninguna, sin acumular deuda.
    boss.wave = boss.wave + 1
    local angle, cx, cy = Enemy.aim(game, bossId, aimX)
    Feedback.emit(game, "boss_attack", cx, cy)
    local speed = config.CORE_PROJECTILE_SPEEDS[boss.phase]
    for index = 1, count do
        local direction = angle + (index - (count + 1) / 2) * math.rad(config.CORE_FAN_DEGREES)
        local destructible = (boss.wave + index) % 3 ~= 0
        local visual = Components.renderable(destructible and {1, 0.38, 0.45} or {1, 0.75, 0.25}, 2, 35)
        visual.borderColor = destructible and {1, 0.9, 0.9} or {0.35, 0.12, 0.02}
        local x, y = cx - config.ENEMY_PROJECTILE_SIZE / 2, cy
        world:create({Position = Components.position(x, y), Collider = Components.collider(config.ENEMY_PROJECTILE_SIZE, config.ENEMY_PROJECTILE_SIZE),
            Velocity = Components.velocity(math.sin(direction) * speed, math.cos(direction) * speed),
            Renderable = visual, PreviousPosition = Components.previousPosition(x, y),
            EnemyProjectile = {remaining = config.ENEMY_PROJECTILE_LIFETIME, destructible = destructible, owner = bossId},
            Health = Components.health(1), Damageable = {sources = {laser = destructible}, enabled = destructible}})
    end
end

function Enemy.updateInvulnerability(game, dt)
    local protection = game.world:get(game.paddleId, "Invulnerability")
    if protection then protection.remaining = math.max(0, protection.remaining - dt) end
end

function Enemy.move(game, dt)
    local world = game.world
    for _, id in ipairs(world:query("EnemyProjectile", "Position", "Velocity", "Collider")) do
        local shot, p, c = world:get(id, "EnemyProjectile"), world:get(id, "Position"), world:get(id, "Collider")
        local previous = world:get(id, "PreviousPosition")
        previous.previousX, previous.previousY = p.x, p.y
        shot.remaining = shot.remaining - dt
        Movement.step(world, id, dt)
        if shot.remaining <= 0 or p.y > game.config.HEIGHT or p.x + c.w < 0 or p.x > game.config.WIDTH
            or world:get(id, "Health").current <= 0 then world:destroy(id) end
    end
end

function Enemy.resolve(game)
    if game.state ~= "playing" or game.quitRequested then return false end
    local world, paddle = game.world, game.paddleId
    local pp, pc = world:get(paddle, "Position"), world:get(paddle, "Collider")
    local previousPaddle = world:get(paddle, "PreviousPosition")
    local protection = world:get(paddle, "Invulnerability")
    for _, id in ipairs(world:query("EnemyProjectile", "Position", "Collider")) do
        local p, c, previous = world:get(id, "Position"), world:get(id, "Collider"), world:get(id, "PreviousPosition")
        if world:get(id, "Health").current <= 0 then world:destroy(id)
        else
            local hit = Collision.sweep(previous.previousX, previous.previousY,
                p.x - previous.previousX - (pp.x - previousPaddle.previousX),
                p.y - previous.previousY - (pp.y - previousPaddle.previousY), c,
                previousPaddle.previousX, previousPaddle.previousY, pc)
            if hit then
                world:destroy(id)
                if protection.remaining <= 0 then return game:loseLife() end
            end
        end
    end
    return false
end

return Enemy

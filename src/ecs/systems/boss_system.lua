local Bricks = require("src.bricks")
local Movement = require("src.ecs.systems.movement_system")
local Enemy = require("src.ecs.systems.enemy_projectile_system")
local BossSystem = {}

local function free(world, x, y, size, except)
    -- Solo al crear protectores o teletransportarse, nunca una consulta por pelota.
    for _, id in ipairs(world:query("Position", "Collider")) do
        if id ~= except and (world:has(id, "Ball") or world:has(id, "Brick") or world:has(id, "Boss")
            or world:has(id, "MovingObstacle") or world:has(id, "Portal")) then
            local p, c = world:get(id, "Position"), world:get(id, "Collider")
            if x < p.x + c.w and x + size.w > p.x and y < p.y + c.h and y + size.h > p.y then return false end
        end
    end
    return true
end

function BossSystem.support(game, kind)
    local world, config, id = game.world, game.config, game.bossId
    local p, c, boss = world:get(id, "Position"), world:get(id, "Collider"), world:get(id, "Boss")
    local capacity = math.min(config.BOSS_SUPPORT_LIMIT - world:count("BossSupport"), config.MAX_LEVEL_BRICKS - world:count("Brick"))
    local size = {w = config.BOSS_SUPPORT_WIDTH, h = config.BOSS_SUPPORT_HEIGHT}
    for _, offset in ipairs({0, c.w - size.w}) do
        local x, y = p.x + offset, p.y + c.h + config.BOSS_SUPPORT_GAP
        if capacity > 0 and y + size.h < game.level.spawn.paddle.y - config.KINEMATIC_PADDLE_CLEARANCE
            and free(world, x, y, size) then
            boss.supportSerial = boss.supportSerial + 1
            local definition = kind == "ghost" and game.level.brickTypes.G or {kind = "resistant", health = config.BOSS_SUPPORT_HEALTH}
            Bricks.spawn(world, config, game.level, {key = "support" .. boss.supportSerial,
                x = x, y = y, w = size.w, h = size.h, color = {0.5, 0.65, 1}, definition = definition,
                support = {owner = id, remaining = config.BOSS_SUPPORT_LIFETIME}})
            capacity = capacity - 1
        end
    end
    game.remaining = world:count("Brick")
end

local function cleanupSupport(game, dt)
    local changed = false
    for _, id in ipairs(game.world:query("BossSupport")) do
        local support = game.world:get(id, "BossSupport")
        support.remaining = support.remaining - dt
        if support.remaining <= 0 then game.world:destroy(id); changed = true end
    end
    if changed then game.remaining = game.world:count("Brick") end
end

function BossSystem.roundReset(game)
    local boss = game.world:get(game.bossId, "Boss")
    if boss then
        boss.grace, boss.attackClock, boss.aimX = game.config.PADDLE_INVULNERABILITY_SECONDS, 0, nil
    end
end

local function moveTo(world, id, x, y, dt)
    local p, v = world:get(id, "Position"), world:get(id, "Velocity")
    if dt > 0 then v.vx, v.vy = (x - p.x) / dt, (y - p.y) / dt; Movement.step(world, id, dt)
    else v.vx, v.vy = 0, 0 end
end

local function guardian(game, id, dt)
    local world, config = game.world, game.config
    local boss, d, p = world:get(id, "Boss"), world:get(id, "BossBehavior"), world:get(id, "Position")
    world:get(id, "Damageable").enabled = true
    boss.warning = nil
    if boss.state == "moving" then
        local target = d.x + (boss.targetIndex % 2 == 1 and -1 or 1) * d.motion.amplitude
        local distance = target - p.x
        moveTo(world, id, p.x + math.max(-config.GUARDIAN_SPEED * dt, math.min(config.GUARDIAN_SPEED * dt, distance)), p.y, dt)
        if math.abs(p.x - target) < 0.001 then
            boss.state, boss.timer, boss.targetIndex = "resting", config.GUARDIAN_REST_SECONDS, boss.targetIndex + 1
        end
    else
        world:get(id, "Velocity").vx = 0
        boss.timer = boss.timer - dt
        if boss.state == "warning" then
            boss.warning = "MOVIMIENTO"
            boss.destinationX = d.x + (boss.targetIndex % 2 == 1 and -1 or 1) * d.motion.amplitude
        end
        if boss.timer <= 0 then
            if boss.state == "resting" then boss.state, boss.timer = "warning", config.BOSS_ACTION_WARNING
            else boss.state = "moving"; BossSystem.support(game, "resistant") end
        end
    end
end

local function patrol(game, id, dt)
    local world = game.world
    local boss, d = world:get(id, "Boss"), world:get(id, "BossBehavior")
    local amplitude = d.motion.amplitude
    local span = amplitude * 2
    boss.travel = (boss.travel + game.config.CORE_SPEEDS[boss.phase] * dt) % (span * 2)
    local x = d.x - amplitude + (boss.travel <= span and boss.travel or span * 2 - boss.travel)
    moveTo(world, id, x, d.y, dt)
end

local function teleport(game, id)
    local world = game.world
    local boss, d, size = world:get(id, "Boss"), world:get(id, "BossBehavior"), world:get(id, "Collider")
    local target = d.teleportPositions[boss.teleportIndex]
    if not free(world, target.x, target.y, size, id) then return false end
    local p, previous = world:get(id, "Position"), world:get(id, "PreviousPosition")
    p.x, p.y, previous.previousX, previous.previousY = target.x, target.y, target.x, target.y
    boss.teleportIndex = boss.teleportIndex % #d.teleportPositions + 1
    BossSystem.support(game, "ghost")
    return true
end

local function core(game, id, dt)
    local world, config = game.world, game.config
    local boss, receiver = world:get(id, "Boss"), world:get(id, "Damageable")
    boss.warning = nil
    if boss.phase < 3 then patrol(game, id, dt) end
    if boss.phase == 1 then
        local cycle = config.CORE_DEFENSE_CLOSED_SECONDS + config.BOSS_ACTION_WARNING + config.CORE_DEFENSE_OPEN_SECONDS
        local phase = boss.clock % cycle
        receiver.enabled = phase >= config.CORE_DEFENSE_CLOSED_SECONDS + config.BOSS_ACTION_WARNING
        if not receiver.enabled and phase >= config.CORE_DEFENSE_CLOSED_SECONDS then boss.warning = "ABRIENDO NUCLEO" end
        local count = math.floor(boss.clock / cycle)
        if boss.defenseCycle ~= count then boss.defenseCycle = count; BossSystem.support(game, "resistant") end
        return
    end
    receiver.enabled = true
    if boss.phase == 3 then
        boss.teleportClock = boss.teleportClock + dt
        local d = world:get(id, "BossBehavior")
        local target = d.teleportPositions[boss.teleportIndex]
        if boss.teleportClock >= config.CORE_TELEPORT_INTERVAL - config.BOSS_ACTION_WARNING then
            boss.warning, boss.destinationX, boss.destinationY = "TELETRANSPORTE", target.x, target.y
        end
        if boss.teleportClock >= config.CORE_TELEPORT_INTERVAL and teleport(game, id) then
            boss.teleportClock, boss.attackClock, boss.aimX, boss.grace = 0, 0, nil, config.BOSS_ACTION_WARNING
        end
    end
    if boss.grace > 0 then return end
    boss.attackClock = boss.attackClock + dt
    local interval = config.CORE_ATTACK_INTERVALS[boss.phase]
    if boss.attackClock >= interval - config.BOSS_ACTION_WARNING then
        if not boss.aimX then
            local p, c = world:get(game.paddleId, "Position"), world:get(game.paddleId, "Collider")
            boss.aimX = p.x + c.w / 2 -- Objetivo fijo durante aviso y vuelo, no perseguidor.
        end
        boss.warning = boss.warning or "DISPARO"
        local _, _, _, target = Enemy.aim(game, id, boss.aimX)
        boss.aimDisplayX = target
    end
    if boss.attackClock >= interval then
        Enemy.emit(game, id, boss.aimX)
        boss.attackClock, boss.aimX = 0, nil
    end
end

function BossSystem.update(game, dt)
    local world, id = game.world, game.bossId
    if not world:has(id, "Boss") or game.state ~= "playing" or game.quitRequested then return end
    cleanupSupport(game, dt)
    local boss, p, previous = world:get(id, "Boss"), world:get(id, "Position"), world:get(id, "PreviousPosition")
    boss.warning, boss.destinationX, boss.destinationY = nil, nil, nil
    previous.previousX, previous.previousY = p.x, p.y
    local velocity = world:get(id, "Velocity")
    velocity.vx, velocity.vy = 0, 0
    boss.hitCooldown, boss.flash = math.max(0, boss.hitCooldown - dt), math.max(0, boss.flash - dt)
    boss.grace = math.max(0, boss.grace - dt)
    if boss.pendingPhase then
        boss.phase, boss.pendingPhase = boss.pendingPhase, nil
        boss.intro, boss.clock, boss.attackClock, boss.aimX = game.config.BOSS_INTRO_SECONDS, 0, 0, nil
        boss.teleportClock = 0
        for _, shot in ipairs(world:query("EnemyProjectile")) do world:destroy(shot) end
        if boss.phase == 3 then
            for _, support in ipairs(world:query("BossSupport")) do world:destroy(support) end
            BossSystem.support(game, "ghost")
        end
    end
    if boss.intro > 0 then
        boss.intro = math.max(0, boss.intro - dt)
        boss.warning = "PREPARATE"
        world:get(id, "Damageable").enabled = false
        return
    end
    boss.clock = boss.clock + dt
    if boss.kind == "mechanical_guardian" then guardian(game, id, dt) else core(game, id, dt) end
end

function BossSystem.updateVisuals(game, dt)
    local boss = game.world:get(game.bossId, "Boss")
    if boss and boss.defeated then
        boss.defeatElapsed = math.min(game.config.BOSS_DEFEAT_SECONDS, boss.defeatElapsed + dt)
        game.world:get(game.bossId, "Renderable").alpha = 1 - boss.defeatElapsed / game.config.BOSS_DEFEAT_SECONDS
    end
end

return BossSystem

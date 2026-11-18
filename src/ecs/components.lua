-- Constructores de datos. Ningun componente contiene metodos o comportamiento.
local Components = {}

function Components.position(x, y)
    return {x = x, y = y}
end

function Components.velocity(vx, vy)
    return {vx = vx, vy = vy}
end

function Components.collider(w, h)
    return {w = w, h = h}
end

function Components.renderable(color, radius, layer)
    return {color = {unpack(color)}, radius = radius, layer = layer}
end

function Components.paddleControl(config)
    return {speed = config.PADDLE_NORMAL_SPEED or config.PADDLE_SPEED,
            sprintMultiplier = config.PADDLE_SPRINT_MULTIPLIER or 1, sprinting = false,
            leftKeys = {unpack(config.CONTROLS.left)}, rightKeys = {unpack(config.CONTROLS.right)}}
end

function Components.ball(config)
    return {paddleMultiplier = config.PADDLE_SPEED_MULTIPLIER,
            wallMultiplier = config.WALL_SPEED_MULTIPLIER, contacts = {}}
end

function Components.brick(config, spec, level)
    return {dropChance = level and level.difficulty.dropChance or config.POWERUP_DROP_CHANCE,
            kind = spec and spec.definition.kind or "normal",
            configuredType = spec and spec.definition.kind or "normal",
            levelId = level and level.id, key = spec and spec.key}
end

function Components.health(value)
    return {current = value, maximum = value}
end

function Components.scoreValue(value)
    return {points = value, awarded = false}
end

function Components.brickBehavior(definition)
    local vulnerable = {}
    for _, source in ipairs(definition.vulnerableTo or {}) do vulnerable[source] = true end
    return {kind = definition.kind, damage = definition.damage,
            vulnerableTo = vulnerable}
end

function Components.ghost(definition)
    local elapsed = definition.offset or 0
    return {elapsed = elapsed, solid = elapsed % (definition.solidSeconds + definition.intangibleSeconds) < definition.solidSeconds,
            waiting = false, warning = false,
            solidSeconds = definition.solidSeconds, intangibleSeconds = definition.intangibleSeconds,
            warningSeconds = definition.warningSeconds}
end

function Components.motion(x, y, definition)
    local pattern = definition.pattern
    local axis = pattern == "group" and (definition.axis or "horizontal") or pattern
    local amplitude = definition.amplitude or 0
    return {originX = x, originY = y, previousX = x, previousY = y, elapsed = 0,
            pattern = pattern, axis = axis, group = definition.group,
            amplitudeX = axis == "vertical" and 0 or (definition.amplitudeX or amplitude),
            amplitudeY = axis == "horizontal" and 0 or (definition.amplitudeY or amplitude),
            period = definition.period, phase = definition.phase or 0}
end

function Components.powerUp(kind, name)
    return {kind = kind, name = name}
end

function Components.timedEffect()
    return {giant_paddle = 0, fireball = 0, magnet = 0, shield = 0}
end

function Components.paddlePower(config)
    return {baseWidth = config.PADDLE_W, ammo = 0, cooldown = 0, guaranteedElapsed = 0, bossLaserElapsed = 0}
end

function Components.projectile(config)
    return {source = "laser", damage = config.LASER_DAMAGE}
end

function Components.boss(definition, config)
    return {kind = definition.id, phase = 1, defeated = false, clock = 0,
        intro = config.BOSS_INTRO_SECONDS, hitCooldown = 0, flash = 0, defeatElapsed = 0,
        state = "warning", timer = config.BOSS_ACTION_WARNING, targetIndex = 1,
        travel = definition.motion.amplitude, wave = 0, attackClock = 0, grace = 0,
        teleportClock = 0, teleportIndex = 1, defenseCycle = -1, supportSerial = 0}
end

function Components.previousPosition(x, y)
    return {previousX = x, previousY = y}
end

function Components.particle(style, trail)
    return {remaining = style.seconds, duration = style.seconds, size = style.size,
        alpha = style.alpha, gravity = style.gravity or 0, trail = trail == true}
end

return Components

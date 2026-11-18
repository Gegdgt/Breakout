local Rules = {}
local function finite(x) return type(x) == "number" and x == x and math.abs(x) < math.huge end
local function inside(x, y, w, h, config, paddleY)
    return finite(x) and finite(y) and finite(w) and finite(h) and w > 0 and h > 0
        and x >= 0 and x + w <= config.WIDTH and y >= config.BRICK_TOP
        and y + h < paddleY - config.KINEMATIC_PADDLE_CLEARANCE
end

-- Geometria efectiva compartida por daño y dibujo, sin modificar el cuerpo ni el nivel.
function Rules.weakPoint(boss, config)
    local base = boss.weakPoint
    local scale = math.min(config.BOSS_WEAK_POINT_SIZE_MULTIPLIER, boss.w / base.w, boss.h / base.h)
    local w, h = base.w * scale, base.h * scale
    return {x = math.max(0, math.min(base.x + base.w / 2 - w / 2, boss.w - w)),
            y = boss.h - h, w = w, h = h}
end

function Rules.validate(level, config)
    local b = level.boss
    if not b then
        assert(level.victory.kind == "clear_bricks", "Falta jefe para la victoria")
        return
    end
    for _, key in ipairs({"BOSS_HIT_COOLDOWN", "BOSS_HIT_FLASH", "BOSS_INTRO_SECONDS", "BOSS_DEFEAT_SECONDS",
        "BOSS_ACTION_WARNING", "BOSS_SUPPORT_LIFETIME", "CORE_DEFENSE_OPEN_SECONDS", "CORE_DEFENSE_CLOSED_SECONDS",
        "CORE_TELEPORT_INTERVAL", "PADDLE_INVULNERABILITY_SECONDS", "ENEMY_PROJECTILE_LIFETIME", "GUARDIAN_SPEED",
        "BOSS_WEAK_POINT_SIZE_MULTIPLIER", "BOSS_LASER_DROP_WEIGHT_MULTIPLIER", "BOSS_LASER_SUPPLY_INTERVAL"}) do
        assert(finite(config[key]) and config[key] > 0, "Parametro de jefe invalido: " .. key)
    end
    assert(finite(config.BOSS_LASER_SUPPLY_CHANCE) and config.BOSS_LASER_SUPPLY_CHANCE >= 0
        and config.BOSS_LASER_SUPPLY_CHANCE <= 1, "Probabilidad de suministro laser invalida")
    assert(finite(config.BOSS_LASER_SUPPLY_BLOCK_THRESHOLD) and config.BOSS_LASER_SUPPLY_BLOCK_THRESHOLD >= 0
        and config.BOSS_LASER_SUPPLY_BLOCK_THRESHOLD % 1 == 0, "Umbral de suministro laser invalido")
    assert(config.BOSS_HIT_COOLDOWN < config.CORE_DEFENSE_OPEN_SECONDS, "Ventana de daño insuficiente")
    assert(config.CORE_TELEPORT_INTERVAL > config.BOSS_ACTION_WARNING, "Falta aviso de teletransporte")
    for _, key in ipairs({"BOSS_SUPPORT_LIMIT", "MAX_ENEMY_PROJECTILES"}) do
        assert(finite(config[key]) and config[key] >= 0 and config[key] % 1 == 0, "Limite de entidades invalido")
    end
    for phase = 2, 3 do
        assert(finite(config.CORE_ATTACK_INTERVALS[phase]) and config.CORE_ATTACK_INTERVALS[phase] > config.BOSS_ACTION_WARNING
            and finite(config.CORE_PROJECTILE_SPEEDS[phase]) and config.CORE_PROJECTILE_SPEEDS[phase] > 0,
            "Ataque sin aviso o velocidad valida")
    end
    assert(b.id == "mechanical_guardian" or b.id == "chaos_core", "Comportamiento de jefe desconocido")
    assert(level.victory.kind == "boss_defeated", "El jefe requiere victoria por derrota")
    assert(finite(b.health) and b.health >= 1 and b.health % 1 == 0, "Salud de jefe invalida")
    assert(inside(b.x, b.y, b.w, b.h, config, level.spawn.paddle.y), "Jefe fuera del area segura")
    local weak = b.weakPoint
    assert(type(weak) == "table" and finite(weak.x) and finite(weak.y) and finite(weak.w) and finite(weak.h)
        and weak.x >= 0 and weak.y >= 0 and weak.w >= config.BALL_SIZE * 2 and weak.h > 0
        and weak.x + weak.w <= b.w and weak.y + weak.h == b.h, "Punto debil inaccesible o invalido")
    assert(Rules.weakPoint(b, config).w >= config.BALL_SIZE * 2, "Punto debil efectivo demasiado estrecho")
    assert(b.motion and b.motion.pattern == "horizontal" and finite(b.motion.amplitude) and b.motion.amplitude > 0
        and b.x - b.motion.amplitude >= 0 and b.x + b.motion.amplitude + b.w <= config.WIDTH, "Ruta de jefe invalida")
    assert(b.protectorType == "resistant", "Protector de jefe desconocido")
    local reward = config.BOSS_SCORE_VALUES[b.id]
    assert(finite(reward) and reward > 0 and reward % 1 == 0 and reward <= config.SCORE_MAX, "Recompensa de jefe invalida")
    if b.id == "chaos_core" then
        assert(type(b.phases) == "table" and #b.phases == 3, "El nucleo requiere tres fases")
        local total = 0
        for index, pattern in ipairs({"barriers", "aimed_projectiles", "teleport_ghosts"}) do
            local phase = b.phases[index]
            assert(phase.pattern == pattern and type(phase.name) == "string" and finite(phase.health)
                and phase.health > 0 and phase.health % 1 == 0, "Fase de jefe invalida")
            total = total + phase.health
        end
        assert(total == b.health, "Salud de fases no coincide con el total")
        assert(type(b.teleportPositions) == "table" and #b.teleportPositions >= 2, "Faltan destinos de teletransporte")
        for _, p in ipairs(b.teleportPositions) do
            assert(inside(p.x, p.y, b.w, b.h, config, level.spawn.paddle.y), "Destino de jefe inseguro")
        end
    end
end
return Rules

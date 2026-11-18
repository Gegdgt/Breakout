-- Validacion de mecanicas activas; los datos de fases futuras no se ejecutan.
local Rules = {}
local kinds = {normal = true, resistant = true, explosive = true, moving = true, ghost = true, armored = true, unbreakable = true}
local patterns = {horizontal = true, vertical = true, oscillatory = true, group = true}

local function number(value, minimum)
    return type(value) == "number" and value == value and value < math.huge and value >= minimum
end

local function motion(spec, groups)
    assert(type(spec) == "table" and patterns[spec.pattern], "Trayectoria desconocida")
    assert(number(spec.period, 0) and spec.period > 0, "Periodo de movimiento invalido")
    for _, key in ipairs({"amplitude", "amplitudeX", "amplitudeY", "phase"}) do
        assert(spec[key] == nil or number(spec[key], 0), "Parametro de trayectoria invalido: " .. key)
    end
    if spec.pattern == "group" then
        assert(type(spec.group) == "string" and #spec.group > 0, "El movimiento en grupo requiere un ID")
        assert(spec.axis == nil or spec.axis == "horizontal" or spec.axis == "vertical", "Eje de grupo invalido")
    end
    if spec.group then
        local previous = groups[spec.group]
        if previous then
            for _, key in ipairs({"pattern", "axis", "period", "phase"}) do
                assert(previous[key] == spec[key], "Los miembros del grupo deben compartir trayectoria y fase")
            end
        else groups[spec.group] = spec end
    end
end

function Rules.validate(level, config)
    assert(#level.bricks <= config.MAX_LEVEL_BRICKS, "Demasiados bloques en el nivel")
    local powers = {}
    for _, kind in ipairs(level.powerups) do
        local definition = config.POWERUP_TYPES[kind]
        assert(definition and not powers[kind] and number(definition.weight, 0) and definition.weight > 0,
            "Poder desconocido, duplicado o sin peso")
        powers[kind] = true
    end
    local guaranteed = level.difficulty.guaranteedPowerup
    if guaranteed then
        assert(type(guaranteed) == "table" and powers[guaranteed.kind]
            and number(guaranteed.everySeconds, 0) and guaranteed.everySeconds > 0, "Poder garantizado invalido")
    end
    local groups, bombs, armor = {}, {}, {}
    for _, brick in ipairs(level.bricks) do
        local d = brick.definition
        assert(kinds[d.kind], "Tipo de bloque desconocido: " .. d.kind)
        if d.kind == "unbreakable" then assert(d.health == nil, "Irrompible no debe tener salud") end
        local health = d.health or 1
        assert(number(health, 1) and health % 1 == 0, "Salud invalida")
        if d.kind == "resistant" then assert(health >= 2 and health <= 4, "Resistentes: entre 2 y 4 impactos") end
        if d.kind == "explosive" then
            assert(number(d.damage, 1), "Explosion invalida")
            bombs[#bombs + 1] = brick
        elseif d.kind == "moving" then
            assert(brick.y + brick.h <= level.spawn.paddle.y - config.KINEMATIC_PADDLE_CLEARANCE,
                "Bloque movil demasiado cerca del paddle")
            motion(d.motion, groups)
        elseif d.kind == "ghost" then
            assert(d.offset == nil or number(d.offset, 0), "Desfase fantasma invalido")
            assert(number(d.solidSeconds, 0) and d.solidSeconds > 0
                and number(d.intangibleSeconds, 0) and d.intangibleSeconds > 0
                and number(d.warningSeconds, 0)
                and d.warningSeconds < math.min(d.solidSeconds, d.intangibleSeconds), "Ciclo fantasma invalido")
        elseif d.kind == "armored" then
            assert(type(d.vulnerableTo) == "table", "Faltan vulnerabilidades del blindaje")
            for _, source in ipairs(d.vulnerableTo) do
                assert(source == "fireball" or source == "laser" or source == "explosion", "Fuente de daño de blindado invalida")
            end
            armor[#armor + 1] = brick
        end
    end
    local objectives = 0
    for _, brick in ipairs(level.bricks) do
        if brick.definition.kind ~= "unbreakable" then objectives = objectives + 1 end
    end
    assert(objectives > 0 or level.boss, "El nivel necesita objetivos destructibles o un jefe")
    -- Una bomba suficiente o una fuente renovable de fuego/laser evita depender del azar.
    for _, target in ipairs(armor) do
        local acceptsExplosion, covered = false, false
        for _, source in ipairs(target.definition.vulnerableTo) do
            if source == "explosion" then acceptsExplosion = true end
            if guaranteed and source == guaranteed.kind and (source == "fireball" or source == "laser") then covered = true end
        end
        if acceptsExplosion then
            for _, bomb in ipairs(bombs) do
                if target.row and bomb.row and target.column and bomb.column
                    and math.abs(target.row - bomb.row) + math.abs(target.column - bomb.column) == 1
                    and bomb.definition.damage >= (target.definition.health or 1) then covered = true; break end
            end
        end
        assert(covered, "Blindado sin via garantizada de destruccion: " .. level.id .. "/" .. target.key)
    end
    local obstacleIds = {}
    for _, obstacle in ipairs(level.obstacles) do
        assert(type(obstacle.id) == "string" and not obstacleIds[obstacle.id], "ID de obstaculo invalido/duplicado")
        obstacleIds[obstacle.id] = true
        assert(number(obstacle.x, 0) and number(obstacle.y, config.BRICK_TOP)
            and number(obstacle.w, 1) and number(obstacle.h, 1)
            and obstacle.x + obstacle.w <= config.WIDTH
            and obstacle.y + obstacle.h <= level.spawn.paddle.y - config.KINEMATIC_PADDLE_CLEARANCE,
            "Obstaculo fuera de su area segura")
        motion(obstacle.motion, groups)
    end
    assert(#level.portals <= config.MAX_PORTAL_PAIRS, "Demasiados pares de portales")
    local portalIds, endpoints = {}, {}
    for _, pair in ipairs(level.portals) do
        assert(type(pair.id) == "string" and #pair.id > 0 and not portalIds[pair.id], "ID de portal invalido/duplicado")
        portalIds[pair.id] = true
        assert(number(pair.cooldown, 0) and pair.cooldown > 0
            and type(pair.rotationDegrees) == "number" and pair.rotationDegrees == pair.rotationDegrees
            and math.abs(pair.rotationDegrees) < math.huge, "Rotacion/cooldown de portal invalido")
        for _, key in ipairs({"entry", "exit"}) do
            local p = pair[key]
            assert(type(p) == "table" and number(p.radius, 1) and number(p.x, p.radius)
                and number(p.y, config.BRICK_TOP + p.radius) and p.x + p.radius < config.WIDTH
                and p.y + p.radius < level.spawn.paddle.y - config.KINEMATIC_PADDLE_CLEARANCE, "Portal fuera del area segura")
            for _, other in ipairs(endpoints) do
                assert((p.x - other.x)^2 + (p.y - other.y)^2 > (p.radius + other.radius)^2, "Portales superpuestos")
            end
            endpoints[#endpoints + 1] = p
        end
    end
end

return Rules

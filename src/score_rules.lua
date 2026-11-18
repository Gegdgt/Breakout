-- Formulas compartidas por los sistemas y la validacion de mapas; sin estado mutable.
local Rules = {}

local function integer(value, minimum)
    return type(value) == "number" and value == value and value < math.huge
        and value >= minimum and value % 1 == 0
end

function Rules.multiplier(config, chain)
    return math.min(config.COMBO_MAX_MULTIPLIER, 1 + math.floor((math.max(1, chain) - 1) / config.COMBO_STEP))
end

function Rules.stars(level, score, lives)
    if score >= level.stars.threeScore and lives >= level.stars.minLives then return 3 end
    if score >= level.stars.twoScore then return 2 end
    return 1 -- Se invoca solamente al completar el nivel.
end

function Rules.prepare(level, config)
    assert(integer(config.SCORE_MAX, 1) and config.SCORE_MAX <= 2147483647, "Limite de puntuacion invalido")
    assert(integer(config.COMBO_STEP, 1) and integer(config.COMBO_MAX_MULTIPLIER, 1)
        and config.COMBO_MAX_MULTIPLIER <= 5, "Progresion de combo invalida")
    assert(type(config.COMBO_WINDOW) == "number" and config.COMBO_WINDOW > 0
        and config.COMBO_WINDOW < math.huge, "Ventana de combo invalida")
    assert(type(config.COMBO_PULSE_SECONDS) == "number" and config.COMBO_PULSE_SECONDS > 0
        and config.COMBO_PULSE_SECONDS < math.huge, "Duracion de pulso invalida")
    local values, base = {}, 0
    for _, brick in ipairs(level.bricks) do
        if brick.definition.kind ~= "unbreakable" then
            local value = config.SCORE_VALUES[brick.definition.kind]
            assert(integer(value, 1) and value <= config.SCORE_MAX, "Puntos de bloque invalidos")
            values[#values + 1], base = value, base + value
        end
    end
    -- Cota maxima con una cadena completa y los bloques mas valiosos al final.
    -- El jefe se premia una vez; los protectores renovables no aportan puntos.
    if level.boss then
        local reward = config.BOSS_SCORE_VALUES[level.boss.id]
        values[#values + 1], base = reward, base + reward
    end
    table.sort(values)
    local maximum = 0
    for chain, value in ipairs(values) do maximum = maximum + value * Rules.multiplier(config, chain) end
    local stars = level.stars
    assert(type(stars) == "table" and integer(stars.twoScore, 1)
        and integer(stars.threeScore, 1) and stars.twoScore < stars.threeScore
        and stars.threeScore <= math.min(maximum, config.SCORE_MAX), "Umbrales de estrellas invalidos o inalcanzables")
    assert(integer(stars.minLives, 1) and stars.minLives <= math.min(config.STARTING_LIVES, config.MAX_LIVES),
        "Las tres estrellas deben poder obtenerse empezando con las vidas iniciales")
    level.baseScore, level.maxScore = base, maximum
end

return Rules

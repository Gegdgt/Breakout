local Catalog = require("src.levels.catalog")
local Rules = require("src.level_rules")
local ScoreRules = require("src.score_rules")
local BossRules = require("src.boss_rules")
local LevelManager = {}
LevelManager.__index = LevelManager

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function inside(position, w, h, config)
    return type(position) == "table" and finite(position.x) and finite(position.y)
        and position.x >= 0 and position.y >= 0
        and position.x + w <= config.WIDTH and position.y + h <= config.HEIGHT
end

-- Tambien valida niveles nuevos antes de que lleguen al mundo ECS.
function LevelManager.prepare(source, config)
    local level = copy(source)
    assert(type(level.id) == "string" and level.id:match("^[a-z][a-z0-9_]*$"), "ID de nivel invalido")
    assert(type(level.name) == "string" and #level.name > 0, "Nombre de nivel requerido")
    local layout = level.layout
    assert(type(layout) == "table" and type(layout.rows) == "table" and #layout.rows > 0, "Mapa requerido")
    assert(finite(layout.columns) and layout.columns > 0 and layout.columns % 1 == 0, "Columnas invalidas")
    assert(finite(layout.x) and layout.x >= 0 and finite(layout.y) and layout.y >= config.BRICK_TOP,
        "Origen del mapa invalido")
    assert(finite(layout.gap) and layout.gap >= 0 and finite(layout.height) and layout.height > 0,
        "Dimensiones del mapa invalidas")
    local width = (config.WIDTH - layout.x * 2 - layout.gap * (layout.columns - 1)) / layout.columns
    assert(width > 0, "Bloques sin ancho")
    assert(type(level.spawn) == "table"
        and inside(level.spawn.paddle, config.PADDLE_W, config.PADDLE_H, config)
        and inside(level.spawn.ball, config.BALL_SIZE, config.BALL_SIZE, config), "Posiciones iniciales invalidas")
    local velocity = level.initialVelocity
    assert(type(velocity) == "table" and finite(velocity.vx) and finite(velocity.vy) and velocity.vy < 0,
        "Velocidad inicial invalida")
    level.initialBallSpeed = math.sqrt(velocity.vx ^ 2 + velocity.vy ^ 2)
    assert(type(level.powerups) == "table" and type(level.obstacles) == "table"
        and type(level.portals) == "table" and type(level.difficulty) == "table", "Configuracion incompleta")
    assert(finite(level.difficulty.dropChance) and level.difficulty.dropChance >= 0
        and level.difficulty.dropChance <= 1, "Probabilidad invalida")
    assert(level.victory and (level.victory.kind == "clear_bricks" or level.victory.kind == "boss_defeated"),
        "Condicion de victoria desconocida")
    assert(level.victory.kind ~= "boss_defeated" or type(level.boss) == "table", "Falta jefe")
    for _, name in ipairs({"background", "primary"}) do
        local color = level.theme and level.theme[name]
        assert(type(color) == "table" and #color == 3, "Color de nivel requerido")
        for _, channel in ipairs(color) do
            assert(finite(channel) and channel >= 0 and channel <= 1, "Color fuera de rango")
        end
    end

    level.bricks = {}
    for row, cells in ipairs(layout.rows) do
        assert(type(cells) == "string" and #cells == layout.columns, "Fila de mapa invalida")
        for column = 1, layout.columns do
            local symbol = cells:sub(column, column)
            if symbol ~= "." then
                local definition = level.brickTypes[symbol]
                assert(type(definition) == "table" and type(definition.kind) == "string", "Tipo de bloque desconocido")
                local x = layout.x + (column - 1) * (width + layout.gap)
                local y = layout.y + (row - 1) * (layout.height + layout.gap)
                assert(inside({x = x, y = y}, width, layout.height, config)
                    and y + layout.height < level.spawn.ball.y, "Bloques fuera del area de juego")
                level.bricks[#level.bricks + 1] = {
                    key = row .. ":" .. column, row = row, column = column,
                    x = x, y = y, w = width, h = layout.height,
                    color = copy(config.BRICK_COLORS[(row - 1) % #config.BRICK_COLORS + 1]),
                    definition = copy(definition),
                }
            end
        end
    end
    assert(#level.bricks > 0, "El nivel necesita objetivos jugables")
    Rules.validate(level, config)
    BossRules.validate(level, config)
    ScoreRules.prepare(level, config)
    level.activeVictory = level.victory.kind
    level.activePowerups = {}
    for _, kind in ipairs(level.powerups) do
        level.activePowerups[#level.activePowerups + 1] = kind
    end
    return level
end

function LevelManager.new(config, sources)
    local self = setmetatable({levels = {}, ids = {}}, LevelManager)
    for index, source in ipairs(sources or Catalog) do
        local level = LevelManager.prepare(type(source) == "string" and require(source) or source, config)
        assert(not self.ids[level.id], "ID de nivel duplicado: " .. level.id)
        self.ids[level.id] = index
        self.levels[index] = level
    end
    assert(#self.levels > 0, "Campaña vacia")
    return self
end

function LevelManager:count() return #self.levels end

function LevelManager:get(index)
    assert(type(index) == "number" and index % 1 == 0 and self.levels[index], "Nivel inexistente")
    return copy(self.levels[index])
end

return LevelManager

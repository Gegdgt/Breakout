-- Valores comunes declarativos. Cada llamada crea datos independientes.
-- N normal; R resistente; E explosivo; M movil; G fantasma; A blindado.
local Definition = {}
local Defaults = require("src.config").BRICK_DEFAULTS

function Definition.make(data)
    data.layout = {rows = data.rows, columns = 12, x = 44, y = 94, gap = 5, height = 25}
    data.rows = nil
    data.spawn = {paddle = {x = 424, y = 587}, ball = {x = 473.5, y = 502}}
    data.brickTypes = {
        N = {kind = "normal"},
        R = {kind = "resistant", health = Defaults.health},
        E = {kind = "explosive", radius = Defaults.explosionRadius, damage = Defaults.explosionDamage},
        M = {kind = "moving", motion = {pattern = "horizontal", amplitude = Defaults.motionAmplitude, period = Defaults.motionPeriod}},
        V = {kind = "moving", motion = {pattern = "vertical", amplitude = 14, period = 5}},
        O = {kind = "moving", motion = {pattern = "oscillatory", amplitudeX = 20, amplitudeY = 12, period = 5}},
        T = {kind = "moving", motion = {pattern = "group", group = "formation", axis = "horizontal", amplitude = 24, period = 4}},
        G = {kind = "ghost", solidSeconds = Defaults.solidSeconds,
             intangibleSeconds = Defaults.intangibleSeconds, warningSeconds = Defaults.warningSeconds},
        A = {kind = "armored", vulnerableTo = {"fireball", "laser", "explosion"}},
    }
    data.obstacles = data.obstacles or {}
    data.portals = data.portals or {}
    data.boss = data.boss or false
    data.victory = {kind = data.boss and "boss_defeated" or "clear_bricks", fallback = "clear_bricks"}
    data.theme = {background = data.background, primary = data.primary}
    data.background, data.primary = nil, nil
    return data
end

return Definition

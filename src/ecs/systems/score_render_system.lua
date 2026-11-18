-- Presentacion de puntuacion: reutiliza fuentes y no decide premios ni transiciones.
local Render = {}
local star = {}
for point = 0, 9 do
    local angle, radius = -math.pi / 2 + point * math.pi / 5, point % 2 == 0 and 1 or 0.45
    star[#star + 1], star[#star + 2] = math.cos(angle) * radius, math.sin(angle) * radius
end
-- Triangulos desde el centro: la estrella es concava y un polygon relleno requiere convexidad.
local triangles = {}
for index = 1, #star, 2 do
    local nextIndex = index + 2 > #star and 1 or index + 2
    triangles[#triangles + 1] = {0, 0, star[index], star[index + 1], star[nextIndex], star[nextIndex + 1]}
end

function Render.star(x, y, size, earned)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(size, size)
    if earned then love.graphics.setColor(1, 0.78, 0.24)
    else love.graphics.setColor(0.28, 0.33, 0.37) end
    for _, triangle in ipairs(triangles) do love.graphics.polygon("fill", triangle) end
    love.graphics.pop()
end

function Render.hud(game)
    local run, config = game.run, game.config
    love.graphics.setFont(game.font)
    love.graphics.setColor(0.98, 0.86, 0.43)
    love.graphics.print("Puntos: " .. run.score, 44, 5)
    love.graphics.setFont(game.effectFont)
    love.graphics.setColor(0.69, 0.77, 0.83)
    love.graphics.print("Récord: " .. game.progress.bestScore, 140, 28)
    local combo = run.combo
    local label = "COMBO: " .. combo.chain .. "   x" .. combo.multiplier
    local pulse = combo.pulse / config.COMBO_PULSE_SECONDS
    local scale = 1 + 0.18 * pulse
    local x, width = config.WIDTH - 310, 266
    love.graphics.setColor(0.15, 0.22, 0.28)
    love.graphics.rectangle("fill", x, 45, width, 3, 1, 1)
    if combo.remaining > 0 then
        love.graphics.setColor(0.98, 0.70, 0.22)
        love.graphics.rectangle("fill", x, 45, width * combo.remaining / config.COMBO_WINDOW, 3, 1, 1)
    end
    love.graphics.push()
    love.graphics.translate(x + width / 2, 23)
    love.graphics.scale(scale, scale)
    if pulse > 0 then
        love.graphics.setColor(1, 0.6, 0.18, pulse * 0.22)
        love.graphics.rectangle("fill", -width / 2, -13, width, 26, 6, 6)
    end
    love.graphics.setFont(game.font)
    if combo.chain > 0 then love.graphics.setColor(1, 0.83, 0.34)
    else love.graphics.setColor(0.50, 0.57, 0.63) end
    love.graphics.printf(label, -width / 2, -game.font:getHeight() / 2, width, "center")
    love.graphics.pop()
end

function Render.result(game)
    local centerY, run = game.config.HEIGHT / 2, game.run
    love.graphics.setFont(game.font)
    love.graphics.setColor(0.98, 0.86, 0.43)
    love.graphics.printf("Nivel: " .. run.levelScore .. " puntos   |   Total: " .. run.score
        .. "   |   Récord: " .. game.progress.bestScore, 0, centerY + 87, game.config.WIDTH, "center")
    local result = run.levelResult
    if not result then return end
    for index = 1, 3 do
        local reveal = math.max(0, math.min(1, (game.ui.elapsed - (index - 1) * game.config.UI_STAR_INTERVAL)
            / game.config.UI_ANIMATION_SECONDS))
        Render.star(game.config.WIDTH / 2 + (index - 2) * 38, centerY + 127,
            14 * (0.65 + 0.35 * reveal), index <= result.stars and reveal > 0)
    end
    love.graphics.setFont(game.effectFont)
    love.graphics.setColor(0.93, 0.96, 0.99)
    love.graphics.printf("Estrellas: " .. result.stars .. " / 3   |   Mejor: "
        .. game.progress.levels[result.levelId].stars .. " / 3", 0, centerY + 148, game.config.WIDTH, "center")
end

function Render.menu(game)
    love.graphics.setFont(game.font)
    love.graphics.setColor(0.98, 0.86, 0.43)
    love.graphics.printf("Récord general: " .. game.progress.bestScore .. "   |   Mejor combo: " .. game.progress.bestCombo,
        0, 497, game.config.WIDTH, "center")
    local level = game.levels.levels[game.progress.maxUnlocked]
    local record = game.progress.levels[level.id]
    love.graphics.setColor(0.69, 0.77, 0.83)
    love.graphics.printf("Nivel " .. game.progress.maxUnlocked .. ": " .. record.bestScore
        .. " puntos   |   Estrellas: " .. record.stars .. " / 3", 0, 529, game.config.WIDTH, "center")
end

return Render

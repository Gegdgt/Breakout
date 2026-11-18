-- Pantallas y transiciones: geometria y fuentes ya creadas, sin mutar la partida.
local Interface = require("src.ecs.systems.interface_system")
local ScoreRender = require("src.ecs.systems.score_render_system")
local BossRender = require("src.ecs.systems.boss_render_system")
local Audio = require("src.ecs.systems.audio_system")
local Encyclopedia = require("src.ui.encyclopedia")
local Screen = {}
local normal = {0.93, 0.96, 0.99}
local muted = {0.64, 0.72, 0.80}

local function text(game, label, y, font, color)
    love.graphics.setFont(font or game.font)
    love.graphics.setColor(color or normal)
    love.graphics.printf(label, 44, y, game.config.WIDTH - 88, "center")
end

local function ease(game)
    local t = math.min(1, game.ui.elapsed / game.config.UI_ANIMATION_SECONDS)
    return 1 - (1 - t) ^ 3
end

local function row(game, label, index, x, y, width, height)
    local selected = game.ui.selection == index
    love.graphics.setColor(selected and 0.16 or 0.09, selected and 0.23 or 0.13, selected and 0.31 or 0.18)
    love.graphics.rectangle("fill", x, y, width, height, 7, 7)
    if selected then
        love.graphics.setColor(game.level.theme.primary)
        love.graphics.rectangle("line", x, y, width, height, 7, 7)
        love.graphics.rectangle("fill", x + 12, y + height / 2 - 3, 6, 6)
    end
    love.graphics.setFont(game.font)
    love.graphics.setColor(selected and normal or muted)
    love.graphics.printf(label, x + 24, y + (height - game.font:getHeight()) / 2, width - 48, "center")
end

local function heading(game, title, subtitle)
    text(game, "BREAKOUT ARCADE", 25, game.effectFont, game.level.theme.primary)
    text(game, title, 63, game.titleFont)
    text(game, subtitle, 106, game.font, muted)
end

function Screen.warning(game)
    if not game.saveWarning then return end
    love.graphics.setColor(0.12, 0.09, 0.04, 0.98)
    love.graphics.rectangle("fill", 0, 590, game.config.WIDTH, 24)
    text(game, game.saveWarning, 594, game.effectFont, {1, 0.8, 0.35})
end

local function menu(game)
    text(game, "BREAKOUT ARCADE", 91, game.messageFont, game.level.theme.primary)
    text(game, game.levels:count() .. " niveles · 2 jefes · Una campaña arcade", 155, game.font, muted)
    for i, label in ipairs(Interface.menuItems) do row(game, label, i, 300, 220 + (i - 1) * 50, 360, 44) end
    ScoreRender.menu(game)
    text(game, "C: jugar nivel " .. game.progress.maxUnlocked .. " — " .. game.levels.levels[game.progress.maxUnlocked].name,
        565, game.effectFont, muted)
    text(game, "Flechas / W S: elegir     Enter: aceptar", 620, game.effectFont, muted)
end

local function selector(game)
    heading(game, "SELECCIONAR NIVEL", "Cada intento comienza con " .. game.config.STARTING_LIVES .. " vidas y cero puntos.")
    local columns, gap = game.config.LEVEL_SELECT_COLUMNS, 12
    local width = (game.config.WIDTH - 88 - (columns - 1) * gap) / columns
    for index, level in ipairs(game.levels.levels) do
        local x = 44 + ((index - 1) % columns) * (width + gap)
        local y = 152 + math.floor((index - 1) / columns) * 178
        local unlocked, selected = index <= game.progress.maxUnlocked, index == game.ui.selectedLevel
        local record = game.progress.levels[level.id]
        love.graphics.setColor(unlocked and 0.10 or 0.07, unlocked and 0.16 or 0.10, unlocked and 0.22 or 0.14)
        love.graphics.rectangle("fill", x, y, width, 164, 8, 8)
        love.graphics.setColor(selected and game.level.theme.primary or {0.21, 0.28, 0.35})
        love.graphics.rectangle("line", x, y, width, 164, 8, 8)
        love.graphics.setFont(game.titleFont)
        love.graphics.setColor(unlocked and level.theme.primary or muted)
        love.graphics.print(string.format("%02d", index), x + 12, y + 10)
        love.graphics.setFont(game.font)
        love.graphics.setColor(unlocked and normal or muted)
        love.graphics.printf(level.name, x + 12, y + 48, width - 24, "left")
        for star = 1, 3 do ScoreRender.star(x + 20 + (star - 1) * 22, y + 103, 8, star <= record.stars) end
        love.graphics.setFont(game.effectFont)
        love.graphics.setColor(unlocked and normal or muted)
        love.graphics.print(unlocked and "DESBLOQUEADO" or "BLOQUEADO", x + 12, y + 120)
        love.graphics.print("Récord: " .. record.bestScore, x + 12, y + 141)
    end
    local level = game.levels.levels[game.ui.selectedLevel]
    text(game, "Nivel " .. game.ui.selectedLevel .. " — " .. level.name, 518, game.font, game.level.theme.primary)
    text(game, game.ui.notice or ("Dificultad: " .. level.difficulty.label), 552, game.font, muted)
    text(game, "Flechas / W A S D: elegir     Enter: jugar     ESC: volver", 620, game.effectFont, muted)
end

local function options(game)
    heading(game, "OPCIONES", "Preferencias guardadas en este dispositivo")
    local settings = game.progress.settings
    local values = {settings.masterVolume, settings.musicVolume, settings.sfxVolume}
    for i, label in ipairs(Interface.optionItems) do
        local y = 168 + (i - 1) * 68
        local value = values[i]
        local shown = label
        if value then shown = label .. ": " .. math.floor(value * 100 + 0.5) .. "%"
        elseif i == 4 then shown = label .. ": " .. (settings.muted and "ACTIVADO" or "DESACTIVADO") end
        row(game, shown, i, 240, y, 480, 46)
        if value then
            love.graphics.setColor(0.18, 0.24, 0.30)
            love.graphics.rectangle("fill", 260, y + 52, 440, 3)
            love.graphics.setColor(game.level.theme.primary)
            love.graphics.rectangle("fill", 260, y + 52, 440 * value, 3)
        end
    end
    text(game, Audio.status(game), 545, game.effectFont, muted)
    text(game, "Arriba / abajo: elegir     Izquierda / derecha: ajustar     Enter: silencio / volver     ESC: guardar y volver",
        620, game.effectFont, muted)
end

function Screen.fullscreen(game)
    if game.state == "encyclopedia" then Encyclopedia.draw(game); return true end
    if game.state ~= "menu" and game.state ~= "level_select" and game.state ~= "options" then return false end
    love.graphics.push()
    love.graphics.translate(0, -(1 - ease(game)) * 12)
    if game.state == "menu" then menu(game)
    elseif game.state == "level_select" then selector(game)
    else options(game) end
    love.graphics.pop()
    Screen.warning(game)
    return true
end

local function backdrop(game)
    love.graphics.setColor(0.02, 0.04, 0.07, 0.68)
    love.graphics.rectangle("fill", 0, 94, game.config.WIDTH, game.config.HEIGHT - 94)
end

local function intro(game)
    backdrop(game)
    love.graphics.push()
    love.graphics.translate(0, (1 - ease(game)) * 12)
    love.graphics.setColor(0.04, 0.075, 0.095, 0.96)
    love.graphics.rectangle("fill", 158, 188, game.config.WIDTH - 316, 286, 10, 10)
    local entry = game.entryRemaining > game.config.LEVEL_COUNTDOWN_SECONDS
    local label = entry and (game.level.boss and "JEFE EN CAMINO" or "NUEVO NIVEL") or "PREPÁRATE"
    text(game, label, 208, game.font, game.level.theme.primary)
    text(game, "Nivel " .. game.levelIndex .. " — " .. game.level.name, 247, game.titleFont)
    if not entry then
        local seconds = math.ceil(game.entryRemaining)
        local fraction = game.entryRemaining - math.floor(game.entryRemaining)
        local scale = 1 + 0.18 * fraction
        love.graphics.push()
        love.graphics.translate(game.config.WIDTH / 2, 340)
        love.graphics.scale(scale)
        love.graphics.setFont(game.messageFont)
        love.graphics.setColor(normal)
        love.graphics.printf(tostring(seconds), -80, -24, 160, "center")
        love.graphics.pop()
    end
    text(game, game.level.boss and "Ataca el núcleo superior o el punto débil frontal." or "Destruye los bloques rompibles para avanzar.",
        421, game.font, muted)
    love.graphics.pop()
    text(game, "ESC / P: pausa     M: menú", 620, game.effectFont, muted)
end

local function paused(game)
    backdrop(game)
    love.graphics.setColor(0.04, 0.075, 0.095, 0.96)
    love.graphics.rectangle("fill", 190, 172, game.config.WIDTH - 380, 380, 10, 10)
    text(game, "PAUSA", 190, game.messageFont, game.level.theme.primary)
    text(game, "Tu partida está detenida", 252, game.font, muted)
    for i, label in ipairs(Interface.pauseItems) do row(game, label, i, 280, 305 + (i - 1) * 58, 400, 46) end
    text(game, "Reiniciar restaura este nivel con " .. game.config.STARTING_LIVES
        .. " vidas y descarta los puntos de este intento.", 513, game.effectFont, muted)
    text(game, "Flechas: elegir     Enter: aceptar     ESC / P: continuar", 620, game.effectFont, muted)
end

local function result(game)
    local config, won, completed = game.config, game.state == "campaign_complete", game.state == "level_complete"
    love.graphics.push()
    love.graphics.translate(0, (1 - ease(game)) * 16)
    love.graphics.setColor(0.04, 0.075, 0.095, 0.96)
    love.graphics.rectangle("fill", 24, won and 190 or 242, config.WIDTH - 48, won and 418 or 366, 10, 10)
    text(game, won and "YOU WIN!" or (completed and "LEVEL COMPLETE" or "GAME OVER"), 272, game.messageFont,
        (won or completed) and {0.3, 0.9, 0.42} or {1, 0.3, 0.32})
    local detail = "R: reiniciar este nivel   |   M: menú"
    if won then detail = "Campaña completada — " .. game.levels:count() .. " niveles superados"
    elseif completed then detail = "Siguiente: " .. game.levels.levels[game.levelIndex + 1].name
        .. "   |   " .. math.ceil(game.transitionRemaining or 0) .. " s" end
    text(game, detail, 344)
    if won or completed then
        text(game, "Vidas: " .. game.lives .. " / " .. config.MAX_LIVES .. " — recuperas " .. config.LEVEL_LIFE_REWARD
            .. " al completar (máximo " .. config.MAX_LIVES .. ")", 378)
    end
    ScoreRender.result(game)
    if not completed then
        row(game, won and "Nueva campaña" or "Reiniciar nivel", 1, 300, 510, 360, 36)
        row(game, "Volver al menú", 2, 300, 558, 360, 36)
    else
        text(game, "Preparando el siguiente nivel…     M / ESC: menú", 550, game.effectFont, muted)
    end
    BossRender.victory(game)
    love.graphics.pop()
    if not completed then text(game, "Flechas: elegir     Enter: aceptar     R: reiniciar     M / ESC: menú", 620, game.effectFont, muted) end
end

function Screen.overlay(game)
    if game.state == "level_intro" then intro(game)
    elseif game.state == "paused" then paused(game)
    elseif game.state == "level_complete" or game.state == "game_over" or game.state == "campaign_complete" then result(game) end
    Screen.warning(game)
end

return Screen

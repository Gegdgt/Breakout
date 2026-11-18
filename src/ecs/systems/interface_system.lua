-- Navegacion y preferencias; no mueve entidades ni decide puntos o victorias.
local State = require("src.ecs.systems.state_system")
local Feedback = require("src.feedback")
local Interface = {}
Interface.menuItems = {"Jugar", "Seleccionar nivel", "Opciones", "Salir"}
Interface.pauseItems = {"Continuar", "Reiniciar nivel", "Volver al menú"}
Interface.optionItems = {"Volumen general", "Música", "Efectos", "Silencio", "Volver"}
local volumeKeys = {"masterVolume", "musicVolume", "sfxVolume"}

function Interface.initialize(game)
    game.ui = {selection = 1, selectedLevel = game.progress.maxUnlocked, elapsed = 0, noticeRemaining = 0}
    State.change(game, "menu")
end

function Interface.update(game, dt)
    if game.state == "paused" then return true end
    local ui = game.ui
    ui.elapsed = math.min(ui.elapsed + dt, game.config.UI_CLOCK_LIMIT)
    ui.noticeRemaining = math.max(0, ui.noticeRemaining - dt)
    if ui.noticeRemaining == 0 then ui.notice = nil end
    if game.state == "level_intro" then
        game.entryRemaining = math.max(0, game.entryRemaining - dt)
        if game.entryRemaining <= 0.000000001 then
            game.entryRemaining = nil
            State.change(game, "playing")
        end
        return true -- Incluso con dt grande, no mover entidades al acabar la cuenta.
    end
    return game.state == "menu" or game.state == "level_select" or game.state == "options"
end

local function selectRow(game, delta, count)
    game.ui.selection = (game.ui.selection - 1 + delta) % count + 1
    Feedback.emit(game, "ui")
end

local function option(game, delta)
    local index, settings = game.ui.selection, game.progress.settings
    if index == 4 then settings.muted = not settings.muted
    elseif index <= 3 then
        local key = volumeKeys[index]
        local value = math.max(0, math.min(1, math.floor((settings[key] + delta * game.config.OPTION_VOLUME_STEP) * 100 + 0.5) / 100))
        if settings[key] == value then return end
        settings[key] = value
    else return end
    game.progressDirty = true -- Guardar al salir de opciones o cerrar, no en cada pulsacion.
    Feedback.emit(game, "ui")
end

local function back(game, selection)
    game:goToMenu()
    game.ui.selection = selection or 1
end

function Interface.keypressed(game, key, isrepeat)
    if game.quitRequested then return true end
    local up, down = key == "up" or key == "w", key == "down" or key == "s"
    local left, right = key == "left" or key == "a", key == "right" or key == "d"
    local confirm = key == "return" or key == "kpenter"
    if isrepeat and not (up or down or left or right) then return true end
    local state, ui = game.state, game.ui
    if key == "m" and state ~= "menu" then back(game); return true end
    if state == "playing" or state == "level_intro" then
        if key == "escape" or key == "p" then State.pause(game); return true end
        return state == "level_intro"
    elseif state == "paused" then
        if key == "escape" or key == "p" then State.resume(game)
        elseif up then selectRow(game, -1, 3)
        elseif down then selectRow(game, 1, 3)
        elseif confirm then
            if ui.selection == 1 then State.resume(game)
            elseif ui.selection == 2 then game:restartLevel()
            else back(game) end
        end
    elseif state == "menu" then
        if up then selectRow(game, -1, 4)
        elseif down then selectRow(game, 1, 4)
        elseif key == "c" then game:startCampaign(game.progress.maxUnlocked)
        elseif confirm then
            if ui.selection == 1 then game:reset()
            elseif ui.selection == 2 then State.change(game, "level_select")
            elseif ui.selection == 3 then State.change(game, "options")
            else game:quit(); game.quitRequested = true; love.event.quit() end
        end
    elseif state == "level_select" then
        local selected, columns = ui.selectedLevel, game.config.LEVEL_SELECT_COLUMNS
        if left then selected = math.max(1, selected - 1)
        elseif right then selected = math.min(game.levels:count(), selected + 1)
        elseif up and selected > columns then selected = selected - columns
        elseif down and selected + columns <= game.levels:count() then selected = selected + columns
        elseif key == "escape" then back(game, 2)
        elseif confirm then
            if selected <= game.progress.maxUnlocked then game:startCampaign(selected)
            else
                ui.notice = "Completa el nivel " .. (selected - 1) .. " para desbloquearlo."
                ui.noticeRemaining = game.config.UI_NOTICE_SECONDS
            end
        end
        if selected ~= ui.selectedLevel then Feedback.emit(game, "ui") end
        ui.selectedLevel = selected
    elseif state == "options" then
        if up then selectRow(game, -1, 5)
        elseif down then selectRow(game, 1, 5)
        elseif left or right then option(game, left and -1 or 1)
        elseif key == "escape" or (confirm and ui.selection == 5) then back(game, 3)
        elseif confirm and ui.selection == 4 then option(game, 1) end
    elseif state == "game_over" or state == "campaign_complete" then
        if key == "escape" then back(game)
        elseif up or down then selectRow(game, 1, 2)
        elseif key == "r" or (confirm and ui.selection == 1) then
            if state == "game_over" then game:restartLevel() else game:reset() end
        elseif confirm then back(game) end
    elseif state == "level_complete" and key == "escape" then back(game) end
    return true
end

return Interface

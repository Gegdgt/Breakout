-- Unico escritor de estados. Cambios inmediatos y validos; el coordinador retorna
-- tras cada transicion para no simular dos estados en el mismo frame.
local State = {}
local allowed = {
    menu = {level_select = true, options = true, level_intro = true},
    level_select = {menu = true, level_intro = true},
    options = {menu = true},
    level_intro = {playing = true, paused = true, menu = true, level_intro = true},
    playing = {paused = true, level_complete = true, game_over = true, campaign_complete = true,
        menu = true, level_intro = true},
    paused = {playing = true, level_intro = true, menu = true},
    level_complete = {level_intro = true, menu = true},
    game_over = {level_intro = true, menu = true},
    campaign_complete = {level_intro = true, menu = true},
}

function State.canChange(game, target)
    if game.quitRequested or not allowed[target] then return false end
    if not game.state then return target == "menu" end
    return allowed[game.state] and allowed[game.state][target] == true
end

function State.change(game, target)
    if not State.canChange(game, target) then return false end
    game.state = target
    game.ui.elapsed, game.ui.selection = 0, 1
    game.ui.notice, game.ui.noticeRemaining = nil, 0
    if target ~= "paused" then game.ui.resumeState = nil end
    return true
end

function State.pause(game)
    if game.state ~= "playing" and game.state ~= "level_intro" then return false end
    local previous, elapsed = game.state, game.ui.elapsed
    if not State.change(game, "paused") then return false end
    game.ui.resumeState, game.ui.resumeElapsed = previous, elapsed
    return true
end

function State.resume(game)
    if game.state ~= "paused" or not game.ui.resumeState then return false end
    local previous, elapsed = game.ui.resumeState, game.ui.resumeElapsed
    if not State.change(game, previous) then return false end
    game.ui.elapsed = elapsed
    return true
end

return State

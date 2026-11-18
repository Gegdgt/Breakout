-- Eventos de presentacion, independientes de la cola de daño/explosiones.
local Feedback = {}
local important = {life_lost = 1, game_over = 2, level_complete = 3, victory = 4}

function Feedback.reset(game)
    game.feedback = {events = {}, count = 0, serial = 0, particleCount = 0, trailCount = 0,
        trailClock = 0, trailCursor = 0}
end

function Feedback.clear(game)
    for _, id in ipairs(game.world:query("Particle")) do game.world:destroy(id) end
    Feedback.reset(game)
end

function Feedback.emit(game, kind, x, y, color)
    local bus = game.feedback
    if not bus or game.quitRequested or game.state == "paused" then return false end
    if game.state ~= "playing" and not important[kind] and kind ~= "ui" then return false end
    local priority = important[kind]
    if priority then
        if bus.important and important[bus.important.kind] >= priority then return false end
    elseif bus.count >= game.config.MAX_FEEDBACK_EVENTS then return false end
    bus.serial = bus.serial + 1
    local event = {kind = kind, x = x, y = y, color = color, serial = bus.serial}
    if priority then bus.important = event
    else bus.count = bus.count + 1; bus.events[bus.count] = event end
    return true
end

return Feedback

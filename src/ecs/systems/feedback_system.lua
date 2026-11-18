local Audio = require("src.ecs.systems.audio_system")
local Particles = require("src.ecs.systems.particle_system")
local System = {}

function System.flush(game)
    local bus = game.feedback
    Audio.sync(game)
    if game.quitRequested then bus.events, bus.count, bus.important = {}, 0, nil; return end
    if game.state == "paused" then return end
    local budget = game.config.FEEDBACK_EMIT_BUDGET
    -- La celebracion y el resultado no se pierden en una rafaga de 90 contactos.
    if bus.important then
        budget = budget - Particles.emit(game, bus.important, budget)
        Audio.play(game, bus.important.kind)
    end
    for index = 1, bus.count do
        local event = bus.events[index]
        budget = budget - Particles.emit(game, event, budget)
        if not bus.important or event.kind == "boss_defeat" then Audio.play(game, event.kind) end
        bus.events[index] = nil
    end
    bus.count, bus.important = 0, nil
end

return System

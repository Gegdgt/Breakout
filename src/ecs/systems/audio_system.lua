local Catalog = require("src.audio_catalog")
local Audio = {}

local function call(audio, slot, method, ...)
    if not slot.source then return nil end
    local ok, result = pcall(slot.source[method], slot.source, ...)
    if not ok then
        pcall(slot.source.stop, slot.source)
        slot.source, slot.paused = nil, false
        audio.errors = audio.errors + 1
        return nil
    end
    return result
end

function Audio.initialize(game, backend)
    local audio = {effects = {}, voices = {}, music = {}, cooldowns = {}, time = 0, errors = 0, available = false}
    game.audio = audio
    backend = backend or love.audio
    if not backend or not backend.newSource then return end
    local function load(definition, mode)
        local ok, source = pcall(backend.newSource, definition.file, mode)
        if not ok or not source then audio.errors = audio.errors + 1; return nil end
        audio.available = true
        return {source = source, gain = definition.gain, priority = definition.priority or 0, definition = definition}
    end
    for name, definition in pairs(Catalog.effects) do
        local first = load(definition, "static")
        local pool = {}; audio.effects[name] = pool
        if first then
            pool[1], audio.voices[#audio.voices + 1] = first, first
            for _ = 2, game.config.AUDIO_POOL_PER_EFFECT do
                local ok, clone = pcall(first.source.clone, first.source)
                if ok and clone then
                    local slot = {source = clone, gain = definition.gain, priority = definition.priority, definition = definition}
                    pool[#pool + 1], audio.voices[#audio.voices + 1] = slot, slot
                else audio.errors = audio.errors + 1 end
            end
        end
    end
    for name, definition in pairs(Catalog.music) do
        local slot = load(definition, "stream")
        if slot then
            slot.fade = 0; audio.music[name] = slot
            call(audio, slot, "setLooping", true)
            call(audio, slot, "setVolume", 0)
        end
    end
end

function Audio.stop(game)
    local audio = game.audio
    if not audio then return end
    for _, slot in ipairs(audio.voices) do call(audio, slot, "stop"); slot.paused = false end
    for _, slot in pairs(audio.music) do call(audio, slot, "stop"); slot.active, slot.fade, slot.paused = false, 0, false end
    audio.wanted, audio.state = nil, nil
end

local function wanted(game)
    if game.state == "menu" or game.state == "level_select" or game.state == "options" or game.state == "encyclopedia" then return "menu" end
    if game.state == "playing" or game.state == "level_intro" then return game.level.boss and "boss" or "level" end
end

local function volumes(game)
    local settings = game.progress.settings
    if settings.muted then return 0, 0 end
    return settings.masterVolume * settings.musicVolume, settings.masterVolume * settings.sfxVolume
end

function Audio.sync(game)
    local audio = game.audio
    if not audio then return end
    if game.quitRequested then Audio.stop(game); return end
    local musicVolume, sfxVolume = volumes(game)
    local paused = game.state == "paused"
    local desired = paused and audio.wanted or wanted(game)
    local newRound = audio.paddleId ~= nil and audio.paddleId ~= game.paddleId
    local resume = not newRound and audio.state == "paused" and (game.state == "playing" or game.state == "level_intro")
    if newRound then
        for _, slot in ipairs(audio.voices) do call(audio, slot, "stop"); slot.paused = false end
    end
    audio.paddleId = game.paddleId
    if desired ~= audio.wanted then
        -- Como maximo dos pistas durante un fundido, aun navegando muy deprisa.
        for name, slot in pairs(audio.music) do
            if name ~= desired and name ~= audio.wanted then
                call(audio, slot, "stop"); slot.active, slot.fade, slot.paused = false, 0, false
            end
        end
        audio.wanted = desired
        local nextTrack = desired and audio.music[desired]
        if nextTrack then nextTrack.active = true end
        -- Los sonidos del combate no pasan al menu, a otro nivel ni al resultado.
        for _, slot in ipairs(audio.voices) do call(audio, slot, "stop"); slot.paused = false end
    end
    for _, slot in ipairs(audio.voices) do
        call(audio, slot, "setVolume", slot.gain * sfxVolume)
        if sfxVolume == 0 then call(audio, slot, "stop"); slot.paused = false
        elseif paused then
            if call(audio, slot, "isPlaying") then call(audio, slot, "pause"); slot.paused = true end
        elseif slot.paused then
            if resume then call(audio, slot, "play") else call(audio, slot, "stop") end
            slot.paused = false
        end
    end
    for _, slot in pairs(audio.music) do
        call(audio, slot, "setVolume", slot.gain * slot.fade * musicVolume)
        if paused or musicVolume == 0 then
            if call(audio, slot, "isPlaying") then call(audio, slot, "pause"); slot.paused = true end
        elseif slot.active and not call(audio, slot, "isPlaying") then
            call(audio, slot, "play"); slot.paused = false
        end
    end
    audio.state = game.state
end

function Audio.update(game, dt)
    Audio.sync(game)
    local audio = game.audio
    if not audio or game.quitRequested or game.state == "paused" then return end
    audio.time = audio.time + dt
    for name, slot in pairs(audio.music) do
        if slot.active then
            local target = name == audio.wanted and 1 or 0
            local step = dt / game.config.MUSIC_FADE_SECONDS
            slot.fade = target == 1 and math.min(1, slot.fade + step) or math.max(0, slot.fade - step)
            if slot.fade == 0 and target == 0 then
                call(audio, slot, "stop"); slot.active, slot.paused = false, false
            end
        end
    end
    local musicVolume = volumes(game)
    for _, slot in pairs(audio.music) do call(audio, slot, "setVolume", slot.gain * slot.fade * musicVolume) end
end

function Audio.play(game, name)
    local audio, definition = game.audio, Catalog.effects[name]
    if not audio or not definition or game.quitRequested or game.state == "paused" then return false end
    local _, volume = volumes(game)
    if volume == 0 or (audio.cooldowns[name] or 0) > audio.time then return false end
    local pool, free = audio.effects[name] or {}
    for _, slot in ipairs(pool) do
        if slot.source and not slot.paused and not call(audio, slot, "isPlaying") then free = slot; break end
    end
    if not free then return false end
    local active, weakest = 0, nil
    for _, slot in ipairs(audio.voices) do
        if call(audio, slot, "isPlaying") then
            active = active + 1
            if not weakest or slot.priority < weakest.priority then weakest = slot end
        end
    end
    if definition.priority >= 7 then
        for _, slot in ipairs(audio.voices) do call(audio, slot, "stop"); slot.paused = false end
    elseif active >= game.config.MAX_SFX_VOICES then
        if not weakest or weakest.priority >= definition.priority then return false end
        call(audio, weakest, "stop")
    end
    call(audio, free, "setVolume", free.gain * volume)
    if not free.source then return false end
    local played = call(audio, free, "play")
    if played == false then
        call(audio, free, "stop"); free.source = nil; audio.errors = audio.errors + 1
    end
    if not free.source then return false end
    audio.cooldowns[name] = audio.time + (definition.interval or game.config.AUDIO_EVENT_INTERVAL)
    return true
end

function Audio.status(game)
    if not game.audio or not game.audio.available then return "Audio no disponible; puedes seguir jugando." end
    if game.audio.errors > 0 then return "Algunos recursos de audio no están disponibles." end
    return "Volumen y silencio se aplican al instante."
end

return Audio

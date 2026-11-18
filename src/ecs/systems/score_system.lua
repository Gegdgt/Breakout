local Rules = require("src.score_rules")
local Victory = require("src.victory")
local Score = {}

function Score.resetCombo(game)
    if not game.run then return end
    local combo = game.run.combo
    combo.chain, combo.multiplier, combo.remaining, combo.pulse = 0, 1, 0, 0
end

function Score.startCampaign(game)
    game.run = {score = 0, levelScore = 0, levelStartScore = 0, bestCombo = 0,
        combo = {chain = 0, multiplier = 1, remaining = 0, pulse = 0}}
end

function Score.startLevel(game, retry)
    local run = game.run
    if retry then run.score = run.levelStartScore end -- No sumar otra vez los mismos bloques al reintentar.
    run.levelStartScore, run.levelScore, run.levelResult = run.score, 0, nil
    Score.resetCombo(game)
end

local function improve(game, record, field, value)
    if value > record[field] then record[field], game.progressDirty = value, true end
end

function Score.record(game)
    local run = game.run
    if not run or not game.level then return end
    improve(game, game.progress, "bestScore", run.score)
    improve(game, game.progress, "bestCombo", run.bestCombo)
    improve(game, game.progress.levels[game.level.id], "bestScore", run.levelScore)
end

function Score.checkpoint(game)
    Score.record(game)
    if game.progressDirty then return game:saveProgress() end
    return true
end

-- Se llama ANTES de retirar la entidad y de evaluar la victoria del ultimo bloque.
-- La marca impide repetir la recompensa incluso si otro sistema conserva su ID.
function Score.award(game, id)
    if game.state ~= "playing" or game.quitRequested or not game.world:has(id, "ScoreValue") then return 0 end
    local value = game.world:get(id, "ScoreValue")
    if value.awarded then return 0 end
    value.awarded = true
    if value.points <= 0 then return 0 end -- Protectores renovables: sin puntos ni combo.
    local run, config = game.run, game.config
    local combo = run.combo
    if combo.remaining <= 0 then combo.chain = 0 end
    combo.chain = combo.chain + 1
    combo.multiplier = Rules.multiplier(config, combo.chain)
    combo.remaining = config.COMBO_WINDOW
    if combo.multiplier >= config.COMBO_CELEBRATION_MULTIPLIER then combo.pulse = config.COMBO_PULSE_SECONDS end
    local points = value.points * combo.multiplier
    run.score = math.min(config.SCORE_MAX, run.score + points)
    run.levelScore = math.min(config.SCORE_MAX, run.levelScore + points)
    run.bestCombo = math.max(run.bestCombo, combo.chain)
    Score.record(game) -- Solo memoria; nunca escribir al disco por cada impacto.
    return points
end

function Score.update(game, dt)
    if game.state ~= "playing" or game.quitRequested then return end
    local combo = game.run.combo
    combo.pulse = math.max(0, combo.pulse - dt)
    if combo.remaining > 0 then
        combo.remaining = combo.remaining <= dt + 0.000000001 and 0 or combo.remaining - dt
        if combo.remaining == 0 then Score.resetCombo(game) end
    end
end

function Score.completeLevel(game)
    local run = game.run
    if run.levelResult then return run.levelResult end
    if game.state ~= "playing" or game.quitRequested or not Victory.satisfied(game) then return nil end
    local stars = Rules.stars(game.level, run.levelScore, game.lives)
    run.levelResult = {levelId = game.level.id, score = run.levelScore, total = run.score,
        stars = stars, lives = game.lives}
    Score.record(game)
    improve(game, game.progress.levels[game.level.id], "stars", stars)
    return run.levelResult
end

return Score

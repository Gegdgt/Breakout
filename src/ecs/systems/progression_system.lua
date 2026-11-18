-- Reglas de campaña sobre recursos de Game; las entidades siguen en World.
local Bricks = require("src.bricks")
local Obstacles = require("src.obstacles")
local Motion = require("src.ecs.systems.motion_system")
local Explosion = require("src.ecs.systems.explosion_system")
local Portals = require("src.ecs.systems.portal_system")
local Score = require("src.ecs.systems.score_system")
local Bosses = require("src.bosses")
local Victory = require("src.victory")
local State = require("src.ecs.systems.state_system")
local Feedback = require("src.feedback")
local Progression = {}

function Progression.loadLevel(game, index, retry)
    if not State.canChange(game, "level_intro") then return false end
    local level = game.levels:get(index) -- Validar antes de tocar el mundo actual.
    game.world:clear()
    game.bossId = nil
    game.levelIndex, game.level = index, level
    Score.startLevel(game, retry)
    game.transitionRemaining = nil
    Explosion.reset(game)
    game:resetRound()
    Bricks.create(game.world, game.config, level)
    Obstacles.create(game.world, level)
    Portals.create(game.world, level)
    Bosses.create(game)
    Motion.configure(game.world, game.config, level.spawn.paddle.y)
    game.remaining = Bricks.remaining(game.world)
    game.entryRemaining = game.config.LEVEL_ENTRY_SECONDS + game.config.LEVEL_COUNTDOWN_SECONDS
    State.change(game, "level_intro")
    return true
end

function Progression.startCampaign(game, index)
    index = index or 1
    if not State.canChange(game, "level_intro") or type(index) ~= "number" or index % 1 ~= 0 or index < 1
        or index > game.progress.maxUnlocked or index > game.levels:count() then return false end
    Score.checkpoint(game)
    Score.startCampaign(game)
    game.lives = game.config.STARTING_LIVES
    game.quitRequested = false
    Progression.loadLevel(game, index)
    return true
end

function Progression.restartLevel(game)
    if not State.canChange(game, "level_intro") or not game.levelIndex then return false end
    Score.checkpoint(game)
    -- Nuevo intento completo: restaura los bloques y las tres vidas, no los desbloqueos.
    game.lives = game.config.STARTING_LIVES
    Progression.loadLevel(game, game.levelIndex, true)
    return true
end

function Progression.completeLevel(game)
    if game.state ~= "playing" or game.quitRequested or not Victory.satisfied(game) then return false end
    Score.completeLevel(game) -- Ultimo bloque incluido; evaluar vidas antes de la recompensa.
    game.lives = math.min(game.config.MAX_LIVES, game.lives + game.config.LEVEL_LIFE_REWARD)
    game.progress.maxUnlocked = math.max(game.progress.maxUnlocked,
        math.min(game.levelIndex + 1, game.levels:count()))
    game:saveProgress()
    if game.levelIndex == game.levels:count() then
        State.change(game, "campaign_complete")
        Feedback.emit(game, "victory", game.config.WIDTH / 2, 210)
        print("You Win!")
        io.stdout:flush()
    else
        State.change(game, "level_complete")
        Feedback.emit(game, "level_complete", game.config.WIDTH / 2, 210)
        game.transitionRemaining = game.config.LEVEL_TRANSITION_SECONDS
    end
    return true
end

function Progression.update(game, dt)
    if game.state ~= "level_complete" or game.quitRequested then return end
    game.transitionRemaining = math.max(0, game.transitionRemaining - dt)
    if game.transitionRemaining == 0 then Progression.loadLevel(game, game.levelIndex + 1) end
end

function Progression.gameOver(game)
    if game.state ~= "playing" or game.quitRequested then return end
    Score.resetCombo(game)
    Score.checkpoint(game)
    State.change(game, "game_over")
    Feedback.emit(game, "game_over")
    print("Game Over")
    io.stdout:flush()
end

function Progression.menu(game)
    if game.quitRequested then return end
    Score.checkpoint(game)
    Feedback.clear(game)
    if game.state ~= "menu" then State.change(game, "menu") end
    game.transitionRemaining = nil
    game.entryRemaining = nil
end

return Progression

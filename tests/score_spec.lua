local Config = require("src.config")
local Components = require("src.ecs.components")
local Bricks = require("src.bricks")
local Helpers = require("tests.helpers")
local LevelManager = require("src.level_manager")
local ProgressStore = require("src.progress_store")
local Rules = require("src.score_rules")
local Score = require("src.ecs.systems.score_system")
local Damage = require("src.ecs.systems.damage_system")
local Explosion = require("src.ecs.systems.explosion_system")
local Projectiles = require("src.ecs.systems.projectile_system")
local Effects = require("src.ecs.systems.power_effect_system")

local function near(a, b) return math.abs(a - b) < 0.00001 end
local function first(game) return game.world:query("Brick")[1] end
local function destroy(game) return Bricks.destroy(game, first(game)) end
local function clear(game)
    for _, id in ipairs(game.world:query("Brick")) do Bricks.destroy(game, id) end
end
local function add(game, kind, x, y, health)
    local spec = game.level.brickTypes[kind]
    if health then spec = {kind = "resistant", health = health} end
    return Bricks.spawn(game.world, Config, game.level, {key = "fixture", x = x or 100, y = y or 200,
        w = 60, h = 25, color = {1, 0.3, 0.3}, definition = spec})
end
local function fixture()
    local game = Helpers.newGame()
    for _, id in ipairs(game.world:query("Brick")) do game.world:destroy(id) end
    add(game, "N", 880, 94)
    game.remaining = 1
    return game
end
local function lose(game)
    for _, id in ipairs(game.world:query("Ball")) do game.world:destroy(id) end
    game:update(0)
end

local function run(root)
    local random, keyboard, quit, mode = love.math.random, love.keyboard.isDown, love.event.quit, Config.ECS_ASSIGNMENT_MODE
    local passed, quits = 0, 0
    love.math.random = function() return 0.99 end
    love.keyboard.isDown = function() return false end
    love.event.quit = function() quits = quits + 1 end
    Config.ECS_ASSIGNMENT_MODE = false
    local function test(name, fn)
        quits = 0
        fn()
        passed = passed + 1
        print("OK FASE4 " .. passed .. ": " .. name)
    end
    local ok, err = xpcall(function()
        test("Cada tipo tiene ScoreValue independiente y puntua solo al destruirse", function()
            for _, case in ipairs({{"N", 100}, {"R", 150}, {"E", 200}, {"M", 200}, {"G", 250}, {"A", 300}}) do
                local game = fixture()
                local id = add(game, case[1])
                local value = game.world:get(id, "ScoreValue")
                assert(value.points == case[2] and value.awarded == false)
                assert(getmetatable(value) == nil and type(value.points) == "number")
                local health = game.world:get(id, "Health").current
                for _ = 1, health - 1 do
                    assert(Damage.hit(game, id, 1, "fireball"))
                    assert(game.run.score == 0 and game.run.combo.chain == 0)
                end
                assert(Damage.hit(game, id, 1, "fireball"))
                assert(game.run.score == case[2] and game.run.levelScore == case[2] and game.run.combo.chain == 1)
                assert(value.awarded and not game.world:has(id, "ScoreValue"))
                assert(Score.award(game, id) == 0 and not Damage.hit(game, id, 1, "laser"))
                assert(not game.world:get(first(game), "ScoreValue").awarded)
            end
        end)

        test("La marca de recompensa y el borrado ECS impiden puntos duplicados", function()
            local game = Helpers.newGame(); local id = first(game)
            assert(Score.award(game, id) == 100 and Score.award(game, id) == 0)
            assert(Bricks.destroy(game, id) and not Bricks.destroy(game, id))
            assert(game.run.score == 100 and game.run.combo.chain == 1)
            local before = game.run.score
            game.world:destroy(first(game)) -- Limpieza administrativa, no destruccion del juego.
            assert(game.run.score == before)
        end)

        test("Ni daño parcial, inmunidad, fantasmas, poderes ni obstaculos suman puntos", function()
            local game = fixture()
            local resistant, armor, ghost = add(game, "R"), add(game, "A", 300), add(game, "G", 500)
            game.world:get(ghost, "Ghost").solid = false
            assert(Damage.hit(game, resistant, 1, "laser"))
            assert(not Damage.hit(game, armor, 1, "ball") and not Damage.hit(game, ghost, 1, "fireball"))
            local obstacle = game.world:create({MovingObstacle = {}, Health = Components.health(10)})
            assert(not Damage.hit(game, obstacle, 100, "laser"))
            for _, kind in ipairs(game.levels:get(10).activePowerups) do game:activatePowerup(kind) end
            assert(game.run.score == 0 and game.run.combo.chain == 0 and game.progress.bestScore == 0)
        end)

        test("90 pelotas golpean el mismo resistente: una recompensa de 150", function()
            local game = fixture(); local id = add(game, "R")
            Helpers.setBallCount(game, 90)
            for _, ball in ipairs(Helpers.balls(game)) do
                ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = 120, 188, 0, 300
            end
            game:update(0.01)
            assert(not game.world:has(id) and game.run.score == 150 and game.run.combo.chain == 1)
            assert(game.world:count("Ball") == 90)
        end)

        test("90 pelotas de fuego comparten las recompensas de dos objetivos", function()
            local game = fixture(); add(game, "N"); add(game, "A", 100, 224)
            Helpers.setBallCount(game, 90); game:activatePowerup("fireball")
            for _, ball in ipairs(Helpers.balls(game)) do
                ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = 120, 190, 0, 550
            end
            game:update(0.05)
            assert(game.run.score == 400 and game.run.combo.chain == 2 and game.remaining == 1)
        end)

        test("Dos lasers y una pelota no repiten la recompensa del bloque destruido en el frame", function()
            local game = fixture(); local paddle = Helpers.paddle(game)
            local id = add(game, "N", paddle.position.x, 550)
            game.world:get(id, "Collider").w = paddle.collider.w
            game:activatePowerup("laser"); game:keypressed("space")
            Projectiles.update(game, 0.05)
            assert(game.run.score == 100 and game.run.combo.chain == 1)
            assert(not Damage.hit(game, id, 1, "ball") and Score.award(game, id) == 0)
            assert(game.run.score == 100)
        end)

        test("Cadena de 90 explosivos: puntos y combo una vez por entidad con eventos diferidos", function()
            local game = fixture()
            local ids = {}
            for n = 1, 90 do ids[n] = add(game, "E", 100 + n % 9, 200 + n % 10) end
            local budget = Config.MAX_EXPLOSIONS_PER_UPDATE
            Config.MAX_EXPLOSIONS_PER_UPDATE = 2
            local success, failure = xpcall(function()
                Damage.hit(game, ids[1], 1, "ball")
                local expected = 0
                for chain = 1, 90 do expected = expected + 200 * math.min(5, 1 + math.floor((chain - 1) / 3)) end
                for _ = 1, 50 do Explosion.process(game) end
                assert(not Explosion.pending(game) and game.run.score == expected)
                assert(game.run.combo.chain == 90 and game.progress.bestCombo == 90 and game.remaining == 1)
                assert(game.progressStore.filesystem.writes == 0)
            end, debug.traceback)
            Config.MAX_EXPLOSIONS_PER_UPDATE = budget
            assert(success, failure)
        end)

        test("Combo aumenta cada tres destrucciones hasta x5 y multiplica el bloque actual", function()
            local game, total = Helpers.newGame(), 0
            for chain = 1, 30 do
                destroy(game)
                local expected = math.min(5, 1 + math.floor((chain - 1) / 3))
                total = total + 100 * expected
                assert(game.run.score == total and game.run.combo.chain == chain and game.run.combo.multiplier == expected)
                assert(game.run.combo.remaining == 3)
                if chain >= 7 then assert(game.run.combo.pulse == Config.COMBO_PULSE_SECONDS) end
            end
            assert(game.run.bestCombo == 30 and game.progress.bestCombo == 30)
        end)

        test("Ventana de tres segundos: renueva antes del limite, expira en el limite y conserva records", function()
            local game = Helpers.newGame()
            destroy(game); Score.update(game, 2.999); destroy(game)
            assert(game.run.combo.chain == 2 and game.run.combo.remaining == 3)
            Score.update(game, 3)
            assert(game.run.combo.chain == 0 and game.run.combo.multiplier == 1 and game.run.combo.remaining == 0)
            assert(game.run.score == 200 and game.progress.bestCombo == 2)
            destroy(game)
            assert(game.run.combo.chain == 1 and game.run.score == 300 and game.progress.bestCombo == 2)
        end)

        test("Temporizador y pulso usan dt dividido y la ventana se procesa antes de las colisiones", function()
            local game = Helpers.newGame()
            for _ = 1, 7 do destroy(game) end
            local pulse = game.run.combo.pulse
            Score.update(game, 0.1)
            assert(near(game.run.combo.pulse, pulse - 0.1))
            for _ = 1, 58 do Score.update(game, 0.05) end
            assert(game.run.combo.chain == 0)
            destroy(game)
            game.run.combo.remaining = 0.01
            local brick, ball = Helpers.bricks(game)[1], Helpers.balls(game)[1]
            ball.position.x, ball.position.y = brick.position.x, brick.position.y + 1
            ball.velocity.vx, ball.velocity.vy = 0, 0
            game:update(0.01)
            assert(game.run.combo.chain == 1 and game.run.combo.remaining == 3)
        end)

        test("Daño sin destruccion y rebotes no renuevan la ventana", function()
            local game = fixture(); local resistant = add(game, "R")
            Damage.hit(game, add(game, "N", 300), 1, "ball")
            Score.update(game, 2)
            Damage.hit(game, resistant, 1, "ball")
            game:activatePowerup("multiball")
            assert(game.run.combo.remaining == 1)
            Score.update(game, 1)
            assert(game.run.combo.chain == 0 and game.run.score == 100)
        end)

        test("Puntos y combo se congelan fuera de playing y no premian destrucciones tardias", function()
            for _, state in ipairs({"menu", "level_complete", "campaign_complete", "game_over", "paused"}) do
                local game = Helpers.newGame(); destroy(game)
                game.state, game.transitionRemaining = state, 2
                game:update(0.25); Score.update(game, 0.5)
                assert(Score.award(game, first(game)) == 0 and not Damage.hit(game, first(game), 1, "laser"))
                assert(game.run.score == 100 and game.run.combo.remaining == 3)
            end
        end)

        test("Perder una vida conserva puntos, reinicia combo y no restaura bloques", function()
            local game = Helpers.newGame()
            for _ = 1, 7 do destroy(game) end
            local points, remaining = game.run.score, game.remaining
            lose(game)
            assert(game.lives == 2 and game.run.score == points and game.run.levelScore == points)
            assert(game.run.combo.chain == 0 and game.remaining == remaining and game.progress.bestCombo == 7)
            destroy(game); assert(game.run.score == points + 100 and game.run.combo.chain == 1)
        end)

        test("El ultimo bloque se puntua antes de estrellas, record, vida y guardado unico", function()
            for _, lives in ipairs({2, 3}) do
                local fs = Helpers.memoryFilesystem(); local game = Helpers.newGame(fs)
                Helpers.keepNormalBricks(game, 3)
                game.level.stars = {twoScore = 200, threeScore = 300, minLives = 3}
                game.lives = lives
                destroy(game); destroy(game)
                assert(game.run.score == 200 and fs.writes == 0 and game.progress.levels[game.level.id].stars == 0)
                local id = first(game); Damage.hit(game, id, 1, "ball")
                local expected = lives == 3 and 3 or 2
                assert(game.run.levelResult.score == 300 and game.run.levelResult.stars == expected)
                assert(game.run.levelResult.lives == lives and game.lives == lives + 1 and fs.writes == 2)
                local loaded = Helpers.newGame(fs).progress
                assert(loaded.bestScore == 300 and loaded.levels[game.level.id].bestScore == 300)
                assert(loaded.levels[game.level.id].stars == expected and loaded.maxUnlocked == 2)
                assert(not Bricks.destroy(game, id) and not game:completeLevel() and fs.writes == 2)
            end
        end)

        test("Estrellas 1-3 respetan umbrales exactos y vidas sin usar el record historico", function()
            local level = Helpers.newGame().level
            local s = level.stars
            for _, case in ipairs({{0, 5, 1}, {s.twoScore - 1, 5, 1}, {s.twoScore, 1, 2},
                {s.threeScore - 1, 5, 2}, {s.threeScore, s.minLives - 1, 2}, {s.threeScore, s.minLives, 3}}) do
                assert(Rules.stars(level, case[1], case[2]) == case[3])
            end
            local game = Helpers.newGame()
            assert(Score.completeLevel(game) == nil and game.progress.levels[game.level.id].stars == 0)
            game.progress.levels[game.level.id].bestScore = 999999
            Helpers.keepNormalBricks(game, 1); destroy(game)
            assert(game.run.levelResult.stars == 1 and game.progress.levels[game.level.id].bestScore == 999999)
        end)

        test("Puntuacion total continua entre niveles; el subtotal y combo empiezan desde cero", function()
            local game = Helpers.newGame(); clear(game)
            local total = game.run.score
            assert(total == 33000 and game.run.levelResult.stars == 3)
            game:update(Config.LEVEL_TRANSITION_SECONDS); Helpers.finishIntro(game)
            assert(game.levelIndex == 2 and game.run.score == total and game.run.levelScore == 0)
            assert(game.run.levelStartScore == total and game.run.combo.chain == 0 and not game.run.levelResult)
            local amount = game.world:get(first(game), "ScoreValue").points
            destroy(game)
            assert(game.run.score == total + amount and game.run.levelScore == amount)
            assert(game.progress.levels[game.level.id].bestScore == amount)
        end)

        test("Reintentar elimina puntos del intento fallido sin borrar niveles previos ni records", function()
            local game = Helpers.newGame(); clear(game); game:update(Config.LEVEL_TRANSITION_SECONDS); Helpers.finishIntro(game)
            local entry = game.run.score
            for _ = 1, 4 do destroy(game) end
            local peak, levelScore = game.run.score, game.run.levelScore
            for _ = 1, game.lives do lose(game) end
            assert(game.state == "game_over" and game.run.score == peak)
            game:keypressed("r"); Helpers.finishIntro(game)
            assert(game.run.score == entry and game.run.levelScore == 0 and game.levelIndex == 2)
            assert(game.progress.bestScore == peak and game.progress.levels[game.level.id].bestScore == levelScore)
            assert(game.progress.levels[game.level.id].stars == 0)
        end)

        test("Nueva campaña y acceso al ultimo desbloqueado empiezan en cero conservando records", function()
            local fs = Helpers.memoryFilesystem(); local game = Helpers.newGame(fs)
            clear(game); local high = game.progress.bestScore
            game:goToMenu(); game:keypressed("c"); Helpers.finishIntro(game)
            assert(game.levelIndex == 2 and game.run.score == 0 and game.run.bestCombo == 0)
            assert(game.progress.bestScore == high)
            destroy(game); local before = game.run.score
            assert(not Helpers.startCampaign(game, 99) and game.run.score == before)
            game:reset(); Helpers.finishIntro(game)
            assert(game.levelIndex == 1 and game.run.score == 0 and game.progress.bestScore == high)
            local reloaded = Helpers.newGame(fs)
            assert(reloaded.run.score == 0 and reloaded.progress.bestScore == high)
        end)

        test("Repetir con menos puntos o estrellas conserva los mejores valores", function()
            local fs = Helpers.memoryFilesystem(); local game = Helpers.newGame(fs)
            clear(game)
            local record, high = game.progress.levels[game.level.id], game.run.score
            assert(record.stars == 3)
            game:reset(); Helpers.finishIntro(game); Helpers.keepNormalBricks(game, 1); destroy(game)
            assert(game.run.levelResult.stars == 1 and game.progress.levels[game.level.id].stars == 3)
            assert(game.progress.bestScore == high and game.progress.levels[game.level.id].bestScore == high)
            local loaded = Helpers.newGame(fs)
            assert(loaded.progress.levels.el_comienzo.stars == 3 and loaded.progress.bestCombo == 72)
        end)

        test("Los diez mapas tienen umbrales alcanzables con daño real y recompensa unica de jefe", function()
            local game = Helpers.newGame(); game.progress.maxUnlocked = 10
            for index = 1, 10 do
                Helpers.startCampaign(game, index)
                local level = game.level
                assert(level.stars.twoScore > level.baseScore and level.stars.threeScore <= level.maxScore)
                -- Una cadena con daño legal: sin cambiar salud, puntos, vidas ni umbrales.
                for _, id in ipairs(game.world:query("Brick")) do
                    local brick = game.world:get(id, "Brick")
                    if brick then
                        for _ = 1, 4 do
                            if game.world:has(id) then Damage.hit(game, id, 1, "fireball") end
                        end
                        Explosion.process(game)
                    end
                end
                Helpers.defeatBoss(game)
                assert(game.remaining == 0 and game.run.levelResult.stars == 3, "Umbral no alcanzado en nivel " .. index)
                assert(game.run.score <= level.maxScore and game.world:count("Boss") == (level.boss and 1 or 0))
            end
            assert(game.state == "campaign_complete" and Config.BOSS_SCORE_VALUES.chaos_core > 0)
        end)

        test("Rechazar umbrales imposibles, vidas extra obligatorias y configuraciones no numericas", function()
            local manager = LevelManager.new(Config)
            for _, mutate in ipairs({
                function(l) l.stars = nil end,
                function(l) l.stars.twoScore = -1 end,
                function(l) l.stars.threeScore = 1.5 end,
                function(l) l.stars.threeScore = l.stars.twoScore end,
                function(l) l.stars.threeScore = l.maxScore + 1 end,
                function(l) l.stars.threeScore = math.huge end,
                function(l) l.stars.minLives = Config.STARTING_LIVES + 1 end,
                function(l) l.stars.minLives = 0/0 end,
            }) do
                local level = manager:get(1); mutate(level)
                assert(not pcall(LevelManager.prepare, level, Config))
            end
            local copy = manager:get(1); copy.stars.minLives = 1
            assert(manager:get(1).stars.minLives == 3)
        end)

        test("Valores y combo centralizados respetan configuracion; saturacion evita salir del formato persistente", function()
            local game = fixture()
            local config = {}; for key, value in pairs(Config) do config[key] = value end
            config.SCORE_VALUES = {normal = 123, resistant = 150, explosive = 200, moving = 200, ghost = 250, armored = 300}
            config.COMBO_STEP, config.COMBO_MAX_MULTIPLIER, config.COMBO_WINDOW = 1, 2, 1.5
            game.config = config
            for _ = 1, 3 do
                local id = Bricks.spawn(game.world, config, game.level, {key = "custom", x = 100, y = 100, w = 50, h = 25,
                    color = {1, 0, 0}, definition = {kind = "normal"}})
                Bricks.destroy(game, id)
            end
            assert(game.run.score == 615 and game.run.combo.multiplier == 2 and game.run.combo.remaining == 1.5)
            game.run.score, game.run.levelScore = Config.SCORE_MAX - 1, Config.SCORE_MAX - 1
            Bricks.destroy(game, add(game, "N"))
            assert(game.run.score == Config.SCORE_MAX and game.run.levelScore == Config.SCORE_MAX)
            Score.checkpoint(game)
            assert(Helpers.newGame(game.progressStore.filesystem).progress.bestScore == Config.SCORE_MAX)
        end)

        test("Records de intentos incompletos se guardan al perder, abandonar o salir; estrellas siguen en cero", function()
            for _, action in ipairs({"game_over", "menu", "exit_menu", "quit"}) do
                local fs = Helpers.memoryFilesystem(); local game = Helpers.newGame(fs)
                for _ = 1, 5 do destroy(game) end
                local score = game.run.score
                assert(fs.writes == 0 and game.progressDirty)
                if action == "game_over" then game.lives = 1; lose(game)
                elseif action == "menu" then game:keypressed("m")
                elseif action == "exit_menu" then
                    game:keypressed("m"); game:keypressed("up"); game:keypressed("return")
                else game:quit() end
                assert(fs.writes == 2 and not game.progressDirty)
                game:quit(); assert(fs.writes == 2, "No repetir guardado sin cambios")
                local data = Helpers.newGame(fs).progress
                assert(data.bestScore == score and data.bestCombo == 5 and data.levels.el_comienzo.bestScore == score)
                assert(data.levels.el_comienzo.stars == 0 and data.maxUnlocked == 1)
            end
        end)

        test("love.quit real guarda records y permite cerrar la ventana", function()
            local Game = require("src.game")
            local original, callbacks = Game.new, {}
            for _, name in ipairs({"load", "update", "draw", "keypressed", "quit", "focus"}) do callbacks[name] = love[name] end
            local fs = Helpers.memoryFilesystem(); local game = Helpers.newGame(fs); destroy(game)
            local success, failure = xpcall(function()
                Game.new = function() return game end
                assert(loadfile(root .. "/main.lua"))(); love.load()
                assert(love.quit() == nil and fs.writes == 2)
                Game.new = original
                assert(Helpers.newGame(fs).progress.bestScore == 100)
            end, debug.traceback)
            Game.new = original
            for _, name in ipairs({"load", "update", "draw", "keypressed", "quit", "focus"}) do love[name] = callbacks[name] end
            assert(success, failure)
        end)

        test("Fallo de guardado conserva records en memoria y los reintenta sin perder puntuacion", function()
            local fs = Helpers.memoryFilesystem(); local game = Helpers.newGame(fs)
            local write = fs.write
            fs.write = function() return false end
            destroy(game); game:goToMenu()
            assert(game.progressDirty and game.saveWarning and game.progress.bestScore == 100)
            fs.write = write; game:quit()
            assert(not game.progressDirty and not game.saveWarning and game.run.score == 100)
            assert(Helpers.newGame(fs).progress.bestScore == 100)
        end)

        test("Guardados anteriores, incompletos y corruptos conservan compatibilidad sin guardar la partida activa", function()
            local fs = Helpers.memoryFilesystem()
            fs.files[Config.SAVE_FILE] = "BREAKOUT_PROGRESS 1\nmaxUnlocked=4\nsettings.musicVolume=0.25\n"
            local game = Helpers.newGame(fs); destroy(game); game:goToMenu()
            local loaded = Helpers.newGame(fs)
            assert(loaded.progress.bestScore == 100 and loaded.progress.maxUnlocked == 4)
            assert(loaded.progress.settings.musicVolume == 0.25 and loaded.run.score == 0)
            local raw = fs.files[Config.SAVE_FILE]
            assert(not raw:find("levelStartScore", 1, true) and not raw:find("remaining", 1, true))
            destroy(loaded); destroy(loaded); loaded:quit()
            fs.files[Config.SAVE_FILE] = "corrupto"
            local recovered = Helpers.newGame(fs)
            assert(recovered.progress.bestScore == 100 and recovered.progress.maxUnlocked == 4 and recovered.saveWarning)
        end)

        test("love.filesystem real conserva puntuacion, combo, estrellas y desbloqueo en identidad de pruebas", function()
            local config = {}; for key, value in pairs(Config) do config[key] = value end
            config.SAVE_FILE, config.SAVE_BACKUP_FILE = "phase4_integration.dat", "phase4_integration.bak"
            love.filesystem.remove(config.SAVE_FILE); love.filesystem.remove(config.SAVE_BACKUP_FILE)
            local success, failure = xpcall(function()
                local game = Helpers.newGame()
                game.progressStore = ProgressStore.new(config, game.levels, love.filesystem)
                game.progress = game.progressStore:load()
                clear(game)
                local loaded = ProgressStore.new(config, game.levels, love.filesystem):load()
                assert(loaded.bestScore == 33000 and loaded.bestCombo == 72)
                assert(loaded.levels.el_comienzo.stars == 3 and loaded.levels.el_comienzo.bestScore == 33000)
                assert(loaded.maxUnlocked == 2)
            end, debug.traceback)
            love.filesystem.remove(config.SAVE_FILE); love.filesystem.remove(config.SAVE_BACKUP_FILE)
            assert(success, failure)
        end)

        test("ECS_ASSIGNMENT_MODE cierra sin puntos, combo ni desbloqueos adicionales", function()
            local game = Helpers.newGame(); destroy(game)
            local score, combo = game.run.score, game.run.combo.chain
            Helpers.setBallCount(game, 90)
            local ball = Helpers.balls(game)[90]
            ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = 0, 400, -330, -440
            Config.ECS_ASSIGNMENT_MODE = true
            game:update(0); game:update(1)
            assert(quits == 1 and game.quitRequested and game.run.score == score and game.run.combo.chain == combo)
            assert(Score.award(game, first(game)) == 0 and game.progress.maxUnlocked == 1 and game.lives == 3)
            game:quit(); assert(Helpers.newGame(game.progressStore.filesystem).progress.bestScore == score)
            Config.ECS_ASSIGNMENT_MODE = false
        end)

        test("Canvas real muestra puntos, combo, estrellas actuales y mejores sin crear recursos por frame", function()
            local game = Helpers.newGame(); for _ = 1, 13 do destroy(game) end
            local canvas = love.graphics.newCanvas(Config.WIDTH, Config.HEIGHT)
            local newFont, newCanvas, newImage = love.graphics.newFont, love.graphics.newCanvas, love.graphics.newImage
            local printText, printf = love.graphics.print, love.graphics.printf
            local labels = {}
            love.graphics.newFont = function() error("Fuente por frame") end
            love.graphics.newCanvas = function() error("Canvas por frame") end
            love.graphics.newImage = function() error("Imagen por frame") end
            love.graphics.print = function(text, ...) labels[text] = true; return printText(text, ...) end
            love.graphics.printf = function(text, ...) labels[text] = true; return printf(text, ...) end
            local success, failure = xpcall(function()
                love.graphics.setCanvas(canvas); game:draw(); love.graphics.setCanvas()
                assert(labels["Puntos: " .. game.run.score] and labels["COMBO: 13   x5"])
                assert(labels["Pelotas: 1 / 90"] and labels["Vidas: 3"])
                clear(game)
                love.graphics.setCanvas(canvas); game:draw(); love.graphics.setCanvas()
                assert(labels["Estrellas: 3 / 3   |   Mejor: 3 / 3"] and labels["LEVEL COMPLETE"])
                game:goToMenu()
                love.graphics.setCanvas(canvas); game:draw(); love.graphics.setCanvas()
                assert(labels["Récord general: 33000   |   Mejor combo: 72"])
            end, debug.traceback)
            love.graphics.setCanvas()
            love.graphics.newFont, love.graphics.newCanvas, love.graphics.newImage = newFont, newCanvas, newImage
            love.graphics.print, love.graphics.printf = printText, printf
            canvas:release(); assert(success, failure)
        end)
    end, debug.traceback)
    love.math.random, love.keyboard.isDown, love.event.quit, Config.ECS_ASSIGNMENT_MODE = random, keyboard, quit, mode
    if not ok then error(err, 0) end
    return passed
end

return {run = run}

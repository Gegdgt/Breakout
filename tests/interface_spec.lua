local Game = require("src.game")
local Config = require("src.config")
local Helpers = require("tests.helpers")
local State = require("src.ecs.systems.state_system")
local Bricks = require("src.bricks")
local Effects = require("src.ecs.systems.power_effect_system")
local Enemy = require("src.ecs.systems.enemy_projectile_system")
local ScoreRender = require("src.ecs.systems.score_render_system")

local function fresh(fs) return Game.new({filesystem = fs or Helpers.memoryFilesystem()}) end
local function press(game, ...)
    for _, key in ipairs({...}) do game:keypressed(key) end
end
local function open(game, screen)
    game:goToMenu()
    game.ui.selection = 1
    if screen == "level_select" then press(game, "down", "return")
    elseif screen == "options" then press(game, "down", "down", "return") end
    assert(game.state == screen)
end
local function serial(value)
    if type(value) ~= "table" then return tostring(value) end
    local keys, parts = {}, {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. serial(value[key]) end
    return "{" .. table.concat(parts, ";") .. "}"
end
local function snapshot(game)
    return serial({components = game.world.components, ids = game.world.entities, nextId = game.world.nextId,
        run = game.run, lives = game.lives, remaining = game.remaining, explosions = game.explosions,
        entry = game.entryRemaining, transition = game.transitionRemaining, progress = game.progress})
end
local function clear(game)
    for _, id in ipairs(game.world:query("Brick")) do Bricks.destroy(game, id) end
    Helpers.defeatBoss(game)
end
local function at(index)
    local game = Helpers.newGame(); game.progress.maxUnlocked = 10
    Helpers.startCampaign(game, index)
    return game
end

local function run(root)
    local passed, quits, held = 0, 0, false
    local originalKeyboard, originalQuit, originalMode = love.keyboard.isDown, love.event.quit, Config.ECS_ASSIGNMENT_MODE
    love.keyboard.isDown = function() return held end
    love.event.quit = function() quits = quits + 1 end
    Config.ECS_ASSIGNMENT_MODE = false
    local function test(name, fn)
        quits, held = 0, false
        fn(); passed = passed + 1; print("OK FASE6 " .. passed .. ": " .. name)
    end
    local ok, err = xpcall(function()
        test("Inicio real abre menu sin simular ni crear entidades o escribir progreso", function()
            local fs = Helpers.memoryFilesystem(); local game = fresh(fs)
            assert(game.state == "menu" and game.world:count() == 0 and game.run.score == 0)
            local before = snapshot(game); held = true
            game:update(100); press(game, "space", "r", "escape")
            assert(snapshot(game) == before and fs.writes == 0 and quits == 0)
        end)

        test("Menu con cinco opciones y navegacion circular por flechas y W S", function()
            local game = fresh()
            press(game, "up"); assert(game.ui.selection == 5)
            press(game, "s"); assert(game.ui.selection == 1)
            press(game, "w", "down", "return")
            assert(game.state == "level_intro" and game.levelIndex == 1 and game.lives == 3)
        end)

        test("Selector recorre diez posiciones, mantiene limites y bloquea niveles cerrados", function()
            local game = fresh(); open(game, "level_select")
            press(game, "left", "up"); assert(game.ui.selectedLevel == 1)
            press(game, "down", "right", "right", "right", "right", "right", "down")
            assert(game.ui.selectedLevel == 10)
            local before = snapshot(game)
            press(game, "return")
            assert(game.state == "level_select" and game.ui.notice and snapshot(game) == before)
            game:update(Config.UI_NOTICE_SECONDS); assert(game.ui.notice == nil)
            press(game, "up", "left"); assert(game.ui.selectedLevel == 4)
            press(game, "escape"); assert(game.state == "menu" and game.ui.selection == 2)
        end)

        test("Selector permite repetir cada nivel desbloqueado con partida independiente", function()
            local game = fresh(); game.progress.maxUnlocked = 10
            for index = 1, 10 do
                open(game, "level_select"); game.ui.selectedLevel = index
                press(game, "return")
                assert(game.state == "level_intro" and game.levelIndex == index and game.lives == 3 and game.run.score == 0)
                assert(game.world:count("Ball") == 1 and game.remaining == require("src.bricks").remaining(game.world))
                assert(game.world:count("Boss") == ((index == 5 or index == 10) and 1 or 0))
            end
        end)

        test("Atajo C conserva acceso al maximo desbloqueado y pasa por la entrada", function()
            local game = fresh(); game.progress.maxUnlocked = 7
            press(game, "c")
            assert(game.state == "level_intro" and game.levelIndex == 7)
            Helpers.finishIntro(game); assert(game.state == "playing")
            press(game, "m", "return")
            assert(game.state == "level_intro" and game.levelIndex == 1)
        end)

        test("Opciones limitan volumen a 0-100, alternan silencio y guardan al volver", function()
            local fs = Helpers.memoryFilesystem(); local game = fresh(fs); open(game, "options")
            for _ = 1, 20 do press(game, "left") end
            assert(game.progress.settings.masterVolume == 0)
            for _ = 1, 20 do press(game, "right") end
            assert(game.progress.settings.masterVolume == 1)
            press(game, "down", "left", "down", "right", "down", "return")
            assert(game.progress.settings.musicVolume == 0.5 and game.progress.settings.sfxVolume == 0.9)
            assert(game.progress.settings.muted and fs.writes == 0)
            press(game, "down", "return")
            assert(game.state == "menu" and game.ui.selection == 3 and fs.writes == 2 and not game.progressDirty)
            local loaded = fresh(fs)
            assert(serial(loaded.progress.settings) == serial(game.progress.settings))
        end)

        test("Opciones sin cambios no escriben; ESC y M guardan cambios pendientes", function()
            local fs = Helpers.memoryFilesystem(); local game = fresh(fs)
            open(game, "options"); press(game, "escape"); assert(fs.writes == 0)
            open(game, "options"); press(game, "left", "escape"); assert(fs.writes == 2)
            open(game, "options"); press(game, "left", "m"); assert(fs.writes == 4)
            assert(fresh(fs).progress.settings.masterVolume == 0.8)
        end)

        test("Fallo al guardar opciones se muestra y se reintenta sin perder preferencias", function()
            local fs = Helpers.memoryFilesystem(); local write = fs.write; local game = fresh(fs)
            open(game, "options"); press(game, "left")
            fs.write = function() return false end
            press(game, "escape")
            assert(game.state == "menu" and game.progressDirty and game.saveWarning)
            fs.write = write
            open(game, "options"); press(game, "escape")
            assert(not game.progressDirty and not game.saveWarning and fresh(fs).progress.settings.masterVolume == 0.9)
        end)

        test("Salir del menu guarda una vez y solicita cierre sin mas entradas", function()
            local fs = Helpers.memoryFilesystem(); local game = fresh(fs)
            open(game, "options"); press(game, "left", "escape", "down", "down", "return")
            assert(game.quitRequested and quits == 1 and fs.writes == 2)
            press(game, "return", "escape", "c"); game:update(100)
            assert(quits == 1 and game.state == "menu" and game.world:count() == 0)
        end)

        test("ESC congela todos los componentes, combos, colas y poderes con 90 pelotas", function()
            for _, index in ipairs({4, 7, 10}) do
                local game = at(index); Helpers.setBallCount(game, 90)
                for _, power in ipairs({"giant_paddle", "fireball", "magnet", "shield", "laser"}) do game:activatePowerup(power) end
                game:keypressed("space")
                game.run.combo.chain, game.run.combo.remaining = 7, 2
                if game.bossId then
                    game.world:get(game.bossId, "Boss").phase = 3
                    Enemy.emit(game, game.bossId, 500)
                end
                press(game, "escape"); assert(game.state == "paused" and quits == 0)
                local before, writes, elapsed = snapshot(game), game.progressStore.filesystem.writes, game.ui.elapsed
                held = true
                for _ = 1, 4 do game:update(30); press(game, "space"); game:activatePowerup("extra_life") end
                assert(snapshot(game) == before and game.progressStore.filesystem.writes == writes and game.ui.elapsed == elapsed)
                held = false
            end
        end)

        test("Continuar conserva entidades y retoma dt sin descontar tiempo pausado", function()
            local game = at(4); game:activatePowerup("fireball")
            local ball = Helpers.balls(game)[1]; local x, id = ball.position.x, ball.id
            press(game, "p"); game:update(20); press(game, "return")
            assert(game.state == "playing" and game.world:has(id) and ball.position.x == x)
            assert(Effects.get(game).fireball == 10)
            game:update(0.01)
            assert(ball.position.x ~= x and math.abs(Effects.get(game).fireball - 9.99) < 0.00001)
        end)

        test("P y ESC alternan pausa; autorepeticion no reanuda ni reinicia accidentalmente", function()
            local game = Helpers.newGame(); press(game, "p")
            game:keypressed("p", true); game:keypressed("escape", true); game:keypressed("return", true)
            assert(game.state == "paused" and quits == 0)
            press(game, "escape"); assert(game.state == "playing")
            game:keypressed("escape", true); assert(game.state == "playing")
        end)

        test("Reiniciar desde pausa restaura jefe/bloques y puntos al entrar, no los records", function()
            local game = at(10)
            game.run.levelStartScore, game.run.score, game.run.levelScore = 500, 600, 100
            game.world:get(game.bossId, "Health").current = 12
            local old = game.world.nextId; game.lives = 1
            press(game, "escape", "down", "return")
            assert(game.state == "level_intro" and game.lives == 3 and game.run.score == 500 and game.run.levelScore == 0)
            assert(game.remaining == require("src.bricks").remaining(game.world) and game.world:get(game.bossId, "Health").current == 23)
            assert(game.progress.bestScore == 600 and game.progress.maxUnlocked == 10)
            for _, id in ipairs(game.world:query()) do assert(id > old) end
        end)

        test("Volver al menu desde pausa abandona el intento y no permite reanudarlo", function()
            local game = Helpers.newGame(); Bricks.destroy(game, game.world:query("Brick")[1])
            press(game, "p", "down", "down", "return")
            assert(game.state == "menu" and not State.resume(game) and game.progress.bestScore == 100)
            local before = snapshot(game); game:update(10); assert(before == snapshot(game))
            press(game, "return"); Helpers.finishIntro(game)
            assert(game.state == "playing" and game.remaining == 72 and game.run.score == 0)
        end)

        test("Cuenta regresiva muestra tres segundos y congela la entrada completa", function()
            local game = fresh(); press(game, "return")
            local components = serial(game.world.components)
            game:update(Config.LEVEL_ENTRY_SECONDS)
            assert(game.state == "level_intro" and math.ceil(game.entryRemaining) == 3)
            for expected = 2, 1, -1 do
                game:update(1); assert(math.ceil(game.entryRemaining) == expected)
                assert(serial(game.world.components) == components)
            end
            game:update(1)
            assert(game.state == "playing" and not game.entryRemaining and serial(game.world.components) == components)
            game:update(0.01); assert(serial(game.world.components) ~= components)
        end)

        test("Entrada usa dt real y no simula el nivel con el excedente de un frame largo", function()
            local game = fresh(); press(game, "return")
            local before = serial(game.world.components); game:update(100)
            assert(game.state == "playing" and before == serial(game.world.components))
            local split = fresh(); press(split, "return")
            for _ = 1, 36 do split:update(0.1) end
            assert(split.state == "playing" and before == serial(split.world.components))
        end)

        test("Pausar entrada conserva cuenta, presentacion y punto exacto de reanudacion", function()
            local game = fresh(); game.progress.maxUnlocked = 5; press(game, "c")
            game:update(1); local remaining, elapsed = game.entryRemaining, game.ui.elapsed
            local bossIntro = game.world:get(game.bossId, "Boss").intro
            press(game, "p"); local before = snapshot(game); game:update(100)
            assert(snapshot(game) == before)
            press(game, "escape")
            assert(game.state == "level_intro" and game.entryRemaining == remaining and game.ui.elapsed == elapsed)
            Helpers.finishIntro(game)
            assert(game.state == "playing" and game.world:get(game.bossId, "Boss").intro == bossIntro)
        end)

        test("Entrada ignora lanzamiento, poderes y R; M cancela sin simular", function()
            local game = fresh(); press(game, "return")
            local before = snapshot(game)
            press(game, "space", "r"); game:activatePowerup("multiball")
            assert(snapshot(game) == before)
            press(game, "m"); game:update(100)
            assert(game.state == "menu" and not game.entryRemaining and game.world:count("Ball") == 1)
        end)

        test("Perder foco pausa partida o entrada, recuperar foco exige continuar", function()
            local game = fresh(); game:focus(false); assert(game.state == "menu")
            press(game, "return"); game:focus(false); assert(game.state == "paused")
            game:focus(true); assert(game.state == "paused")
            press(game, "return"); Helpers.finishIntro(game); game:focus(false)
            assert(game.state == "paused" and game.ui.resumeState == "playing")
            game:focus(false); press(game, "p"); assert(game.state == "playing")
        end)

        test("LEVEL COMPLETE guarda, anima estrellas y entra al siguiente sin simularlo", function()
            local fs = Helpers.memoryFilesystem(); local game = Helpers.newGame(fs)
            clear(game)
            assert(game.state == "level_complete" and game.ui.elapsed == 0 and game.progress.maxUnlocked == 2)
            local writes, lives = fs.writes, game.lives
            game:update(0.5)
            assert(game.ui.elapsed == 0.5 and game.state == "level_complete" and game.run.levelResult.stars == 3)
            press(game, "p"); assert(game.state == "level_complete")
            game:update(100)
            assert(game.state == "level_intro" and game.levelIndex == 2 and game.lives == lives and fs.writes == writes)
            assert(Helpers.balls(game)[1].position.y == game.level.spawn.ball.y)
            Helpers.finishIntro(game); assert(game.state == "playing")
        end)

        test("Abandonar LEVEL COMPLETE cancela su temporizador sin perder desbloqueo", function()
            local game = Helpers.newGame(); clear(game)
            press(game, "escape"); game:update(100)
            assert(game.state == "menu" and not game.transitionRemaining and game.levelIndex == 1)
            open(game, "level_select"); press(game, "right", "return")
            assert(game.state == "level_intro" and game.levelIndex == 2)
        end)

        test("GAME OVER mantiene acciones de teclado, animacion y reinicio R", function()
            local game = at(5); game.lives = 1; game:loseLife()
            assert(game.state == "game_over" and game.lives == 0)
            game:update(0.2); press(game, "p"); assert(game.state == "game_over" and game.ui.elapsed == 0.2)
            game:keypressed("r", true); assert(game.state == "game_over")
            press(game, "r"); assert(game.state == "level_intro" and game.levelIndex == 5 and game.lives == 3)
            Helpers.finishIntro(game); game.lives = 1; game:loseLife()
            press(game, "down", "return"); assert(game.state == "menu")
        end)

        test("Victoria final muestra resultado persistente y R inicia una campaña nueva", function()
            local game = at(10); Helpers.defeatBoss(game)
            local score, writes = game.run.score, game.progressStore.filesystem.writes
            assert(game.state == "campaign_complete" and game.run.levelResult)
            game:update(30); press(game, "p")
            assert(game.state == "campaign_complete" and game.progressStore.filesystem.writes == writes)
            press(game, "r")
            assert(game.state == "level_intro" and game.levelIndex == 1 and game.run.score == 0 and game.progress.bestScore == score)
        end)

        test("Transiciones invalidas no modifican mundo, puntuacion ni guardados", function()
            local game = fresh(); local before = snapshot(game)
            assert(not State.change(game, "playing") and not State.change(game, "unknown") and not game:completeLevel())
            assert(snapshot(game) == before and game.state == "menu")
            press(game, "return"); Helpers.finishIntro(game)
            before = snapshot(game)
            assert(not State.change(game, "options") and not game:startCampaign(10))
            assert(snapshot(game) == before)
            clear(game)
            assert(not State.change(game, "game_over") and not State.pause(game) and not game:completeLevel())
            assert(game.state == "level_complete")
        end)

        test("Animaciones de interfaz usan dt y el reloj permanece acotado", function()
            local a, b = fresh(), fresh()
            a:update(0.3); for _ = 1, 3 do b:update(0.1) end
            assert(math.abs(a.ui.elapsed - b.ui.elapsed) < 0.00001)
            a:update(10000); assert(a.ui.elapsed == Config.UI_CLOCK_LIMIT)
        end)

        test("Selector dibuja los diez nombres, bloqueos, mejores estrellas y records", function()
            local game = fresh(); game.progress.maxUnlocked = 3
            game.progress.levels.el_comienzo.stars, game.progress.levels.el_comienzo.bestScore = 3, 12000
            open(game, "level_select")
            local labels, stars = {}, 0
            local printf, printText, star = love.graphics.printf, love.graphics.print, ScoreRender.star
            love.graphics.printf = function(label, ...) labels[label] = true; return printf(label, ...) end
            love.graphics.print = function(label, ...) labels[label] = true; return printText(label, ...) end
            ScoreRender.star = function(x, y, size, earned) if earned then stars = stars + 1 end; return star(x, y, size, earned) end
            local success, failure = xpcall(function()
                game:draw()
                for _, level in ipairs(game.levels.levels) do assert(labels[level.name]) end
                assert(labels.BLOQUEADO and labels.DESBLOQUEADO and labels["Récord: 12000"] and stars == 3)
            end, debug.traceback)
            love.graphics.printf, love.graphics.print, ScoreRender.star = printf, printText, star
            assert(success, failure)
        end)

        test("HUD muestra todos los poderes, tiempos, municion, bolas, vidas, puntos y jefe", function()
            local game = at(10); Helpers.setBallCount(game, 90)
            for _, power in ipairs({"giant_paddle", "fireball", "shield", "magnet", "laser"}) do game:activatePowerup(power) end
            game.run.score, game.run.combo.chain, game.run.combo.multiplier = 12345, 13, 5
            local printf, printText, labels = love.graphics.printf, love.graphics.print, {}
            love.graphics.printf = function(label, ...) labels[#labels + 1] = label; return printf(label, ...) end
            love.graphics.print = function(label, ...) labels[#labels + 1] = label; return printText(label, ...) end
            local success, failure = xpcall(function()
                game:draw(); local all = table.concat(labels, "\n")
                for _, expected in ipairs({"Pelotas: 90 / 90", "Vidas: 3", "Puntos: 12345", "COMBO: 13   x5", "GIGANTE 15s",
                    "FUEGO 10s", "IMAN 15s", "ESCUDO 3/3 20s", "LASER: 20", "23 / 23", "Fase 1 / 3", "Nivel 10 / 10"}) do
                    assert(all:find(expected, 1, true), expected)
                end
            end, debug.traceback)
            love.graphics.printf, love.graphics.print = printf, printText
            assert(success, failure)
        end)

        test("Canvas real recorre pantallas sin mutaciones ni recursos nuevos por frame", function()
            local game = fresh(); game.progress.maxUnlocked = 10
            local canvas = love.graphics.newCanvas(Config.WIDTH, Config.HEIGHT)
            local font, image, newCanvas = love.graphics.newFont, love.graphics.newImage, love.graphics.newCanvas
            local function forbidden() error("Recurso creado durante draw") end
            love.graphics.newFont, love.graphics.newImage, love.graphics.newCanvas = forbidden, forbidden, forbidden
            local success, failure = xpcall(function()
                local function draw()
                    local before = snapshot(game)
                    love.graphics.setCanvas(canvas); game:draw(); love.graphics.setCanvas()
                    assert(snapshot(game) == before)
                end
                draw(); open(game, "level_select"); draw(); open(game, "options"); draw()
                press(game, "escape"); game.ui.selection = 1; press(game, "return"); draw()
                game:update(Config.LEVEL_ENTRY_SECONDS); draw(); press(game, "p"); draw(); press(game, "p")
                Helpers.finishIntro(game); draw(); clear(game); game:update(0.7); draw()
                game:goToMenu(); game:startCampaign(10); draw(); Helpers.finishIntro(game)
                Helpers.defeatBoss(game); game:update(0.7); draw()
                game:reset(); Helpers.finishIntro(game); game.lives = 1; game:loseLife(); game:update(0.4); draw()
            end, debug.traceback)
            love.graphics.setCanvas()
            love.graphics.newFont, love.graphics.newImage, love.graphics.newCanvas = font, image, newCanvas
            canvas:release(); assert(success, failure)
        end)

        test("Estrellas aparecen con dt sin cambiar premios ni escribir otra vez", function()
            local game = Helpers.newGame(); clear(game)
            local writes, score = game.progressStore.filesystem.writes, game.run.score
            local star, earned = ScoreRender.star, 0
            ScoreRender.star = function(x, y, size, hasStar) if hasStar then earned = earned + 1 end; return star(x, y, size, hasStar) end
            local success, failure = xpcall(function()
                game:draw(); assert(earned == 0)
                game:update(0.1); earned = 0; game:draw(); assert(earned == 1)
                game:update(0.6); earned = 0; game:draw(); assert(earned == 3)
                assert(game.run.score == score and game.progressStore.filesystem.writes == writes)
            end, debug.traceback)
            ScoreRender.star = star; assert(success, failure)
        end)

        test("Modo ECS no colisiona pausado y cierra una vez al reanudar con 90 pelotas", function()
            for _, x in ipairs({0, Config.WIDTH - Config.BALL_SIZE}) do
                local game = at(10); Helpers.setBallCount(game, 90)
                local ball = Helpers.balls(game)[90]
                ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = x, 400, x == 0 and -330 or 330, -440
                Config.ECS_ASSIGNMENT_MODE = true; quits = 0
                press(game, "p"); game:update(20); assert(quits == 0 and game.state == "paused")
                press(game, "p"); game:update(0); game:update(20)
                assert(game.quitRequested and quits == 1 and game.lives == 3 and game.run.score == 0)
                press(game, "escape"); assert(game.state == "playing")
                Config.ECS_ASSIGNMENT_MODE = false
            end
        end)

        test("MULTIBALL tras pausa mantiene 90, 550 px/s y vida solo al perder la ultima", function()
            local game = Helpers.newGame()
            for _ = 1, 5 do game:activatePowerup("multiball") end
            press(game, "p"); game:update(10); press(game, "p")
            game:activatePowerup("multiball"); assert(game.world:count("Ball") == 90)
            local balls = Helpers.balls(game)
            for i = 1, 89 do balls[i].position.y = 640 end
            game:update(0); assert(game.lives == 3 and game.world:count("Ball") == 1)
            local ball = Helpers.balls(game)[1]
            ball.velocity.vx, ball.velocity.vy = 3000, -4000; game:update(0)
            assert(math.sqrt(ball.velocity.vx ^ 2 + ball.velocity.vy ^ 2) <= 550.00001)
            ball.position.y = 640; game:update(0)
            assert(game.lives == 2 and game.world:count("Ball") == 1 and game.state == "playing")
        end)

        test("Callbacks reales de main transmiten pausa, foco, repeticiones y cierre", function()
            local callbacks, original = {}, Game.new
            for _, key in ipairs({"load", "update", "draw", "keypressed", "focus", "quit"}) do callbacks[key] = love[key] end
            local game = fresh()
            local success, failure = xpcall(function()
                Game.new = function() return game end
                assert(loadfile(root .. "/main.lua"))(); love.load()
                love.keypressed("return", nil, false); Helpers.finishIntro(game)
                love.keypressed("escape", nil, false); assert(game.state == "paused" and quits == 0)
                love.keypressed("escape", nil, true); assert(game.state == "paused")
                love.keypressed("escape", nil, false); love.focus(false); assert(game.state == "paused")
                love.focus(true); assert(game.state == "paused")
                assert(love.quit() == nil)
            end, debug.traceback)
            Game.new = original
            for _, key in ipairs({"load", "update", "draw", "keypressed", "focus", "quit"}) do love[key] = callbacks[key] end
            assert(success, failure)
        end)
    end, debug.traceback)
    love.keyboard.isDown, love.event.quit, Config.ECS_ASSIGNMENT_MODE = originalKeyboard, originalQuit, originalMode
    if not ok then error(err, 0) end
    return passed
end
return {run = run}

local Config = require("src.config")
local LevelManager = require("src.level_manager")
local Bricks = require("src.bricks")
local Powerups = require("src.powerups")
local Helpers = require("tests.helpers")

local function clear(game)
    for _, id in ipairs(game.world:query("Brick")) do assert(Bricks.destroy(game, id)) end
    Helpers.defeatBoss(game)
end

local function loseRound(game)
    for _, id in ipairs(game.world:query("Ball")) do game.world:destroy(id) end
    game:update(0)
end

local function run()
    local passed = 0
    local function test(name, fn)
        fn()
        passed = passed + 1
        print("OK NIVELES " .. passed .. ": " .. name)
    end

    test("Diez mapas manuales distintos, IDs unicos y dificultad progresiva", function()
        local manager = LevelManager.new(Config)
        assert(manager:count() == 10)
        local names, layouts, previousSpeed = {}, {}, 0
        for index = 1, manager:count() do
            local level = manager:get(index)
            local layout = table.concat(level.layout.rows)
            assert(not names[level.id] and not layouts[layout])
            names[level.id], layouts[layout] = true, true
            assert(level.initialBallSpeed > previousSpeed and level.initialBallSpeed < 450)
            previousSpeed = level.initialBallSpeed
            assert(level.difficulty.rank == index and #level.bricks > 0)
            assert(level.activeVictory == (level.boss and "boss_defeated" or "clear_bricks") and #level.activePowerups == #level.powerups)
            assert(level.activePowerups[1] == "multiball")
        end
        assert(manager:get(5).boss.health == 20)
        assert(manager:get(10).boss.health == 45 and #manager:get(10).boss.phases == 3)
        assert(#manager:get(4).obstacles == 1 and #manager:get(7).portals == 1)
        for index = 7, 10 do
            assert(manager:get(index).difficulty.guaranteedPowerup.kind == "fireball")
        end
    end)

    test("Carga aislada: los datos de un nivel no modifican su plantilla ni otros niveles", function()
        local manager = LevelManager.new(Config)
        local first, second = manager:get(1), manager:get(2)
        first.spawn.ball.x = -100
        first.brickTypes.R.health = 99
        first.bricks[1].color[1] = 0
        assert(manager:get(1).spawn.ball.x == 473.5)
        assert(second.brickTypes.R.health == 3 and manager:get(1).brickTypes.R.health == 3)
        assert(Config.BRICK_COLORS[1][1] == 1)
    end)

    test("Rechazar indices, IDs duplicados y mapas o posiciones invalidos", function()
        local manager = LevelManager.new(Config)
        for _, index in ipairs({0, 11, 1.5, "1"}) do
            assert(not pcall(function() manager:get(index) end))
        end
        assert(not pcall(function() LevelManager.new(Config, {manager:get(1), manager:get(1)}) end))
        for _, mutate in ipairs({
            function(level) level.layout.rows[1] = "N" end,
            function(level) level.layout.rows[1] = "?NNNNNNNNNNN" end,
            function(level) level.layout.y = 600 end,
            function(level) level.spawn.ball.x = -10 end,
            function(level) level.initialVelocity.vy = 0 end,
            function(level) level.difficulty.dropChance = 2 end,
        }) do
            local level = manager:get(1)
            mutate(level)
            assert(not pcall(function() LevelManager.prepare(level, Config) end))
        end
    end)

    test("Los diez niveles crean entidades ECS, posiciones, velocidades y tipos previstos", function()
        local game = Helpers.newGame()
        game.progress.maxUnlocked = 10
        local world, lastId = game.world, 0
        for index = 1, 10 do
            assert(Helpers.startCampaign(game, index))
            assert(game.world == world and game.lives == 3)
            assert(game.remaining == #game.level.bricks
                and world:count() == game.remaining + 2 + #game.level.obstacles + #game.level.portals * 2 + (game.level.boss and 1 or 0))
            assert(world:count("MovingObstacle") == #game.level.obstacles)
            local ball, paddle = Helpers.balls(game)[1], Helpers.paddle(game)
            assert(ball.position.x == game.level.spawn.ball.x and ball.position.y == game.level.spawn.ball.y)
            assert(ball.velocity.vx == game.level.initialVelocity.vx and ball.velocity.vy == game.level.initialVelocity.vy)
            assert(paddle.position.x == game.level.spawn.paddle.x)
            for _, id in ipairs(world:query()) do assert(id > lastId) end
            lastId = world.nextId
            for n, id in ipairs(world:query("Brick")) do
                local brick = world:get(id, "Brick")
                assert(brick.kind == game.level.bricks[n].definition.kind and brick.configuredType == brick.kind)
                assert(brick.levelId == game.level.id)
            end
            assert(world:count("Boss") == (game.level.boss and 1 or 0) and world:count("Portal") == #game.level.portals * 2)
            game:activatePowerup("giant_paddle")
            assert(paddle.collider.w == Config.PADDLE_W * Config.GIANT_PADDLE_SCALE)
            clear(game) -- Fixture de progresion; el daño real se verifica en special_bricks_spec.
        end
        assert(game.state == "campaign_complete")
    end)

    test("Progresion completa 1 a 10, desbloqueo inmediato y vida limitada a cinco", function()
        local fs = Helpers.memoryFilesystem()
        local game = Helpers.newGame(fs)
        for index = 1, 10 do
            local lives, writes = game.lives, fs.writes
            clear(game)
            assert(game.levelIndex == index and game.remaining == 0)
            assert(game.lives == math.min(5, lives + 1))
            assert(game.progress.maxUnlocked == math.min(10, index + 1) and fs.writes == writes + 2)
            assert(not game:completeLevel() and fs.writes == writes + 2, "Premiar solo una vez")
            if index < 10 then
                assert(game.state == "level_complete")
                game:update(Config.LEVEL_TRANSITION_SECONDS); Helpers.finishIntro(game)
                assert(game.levelIndex == index + 1 and game.state == "playing")
                assert(game.world:count("Ball") == 1 and game.world:count("PowerUp") == 0)
            end
        end
        assert(game.state == "campaign_complete" and game.lives == 5)
        game:update(100); Helpers.finishIntro(game)
        assert(game.state == "campaign_complete" and game.levelIndex == 10)
        local reloaded = Helpers.newGame(fs)
        assert(reloaded.progress.maxUnlocked == 10 and reloaded.levelIndex == 1 and reloaded.lives == 3)
    end)

    test("Transicion con dt real congela entidades y no salta mas de un nivel", function()
        local game = Helpers.newGame()
        Powerups.spawn(game.world, Config, "multiball", 100, 400)
        game:activatePowerup("multiball")
        clear(game)
        local ball = Helpers.balls(game)[1]
        local power = Helpers.powers(game)[1]
        local x, y, powerY = ball.position.x, ball.position.y, power.position.y
        game:update(0.75)
        assert(game.state == "level_complete" and game.transitionRemaining == 1.25)
        game:activatePowerup("multiball")
        assert(game.world:count("Ball") == 3 and ball.position.x == x and ball.position.y == y and power.position.y == powerY)
        game:update(0)
        assert(game.transitionRemaining == 1.25)
        game:update(100); Helpers.finishIntro(game)
        assert(game.levelIndex == 2 and game.state == "playing" and game.world:count("PowerUp") == 0)
        assert(Helpers.balls(game)[1].position.y == game.level.spawn.ball.y, "No mover al entrar")
        local split = Helpers.newGame()
        clear(split)
        for _ = 1, 8 do split:update(0.25) end
        Helpers.finishIntro(split)
        assert(split.levelIndex == 2 and split.state == "playing")
    end)

    test("Perder vidas conserva bloques y velocidad inicial del nivel actual", function()
        local game = Helpers.newGame()
        game.progress.maxUnlocked = 6
        Helpers.startCampaign(game, 6)
        local removed = game.world:query("Brick")[1]
        Bricks.destroy(game, removed)
        local remaining, first = game.remaining, game.world:query("Brick")[1]
        loseRound(game)
        assert(game.lives == 2 and game.remaining == remaining and game.world:has(first))
        assert(not game.world:has(removed) and game.levelIndex == 6)
        assert(Helpers.balls(game)[1].velocity.vy == game.level.initialVelocity.vy)
        clear(game)
        assert(game.lives == 3)
        game:update(Config.LEVEL_TRANSITION_SECONDS); Helpers.finishIntro(game)
        assert(game.levelIndex == 7 and game.lives == 3)
    end)

    test("Derrota y R reinician el nivel actual; una campaña nueva conserva el progreso", function()
        local game = Helpers.newGame()
        game.progress.maxUnlocked = 4
        Helpers.startCampaign(game, 4)
        Bricks.destroy(game, game.world:query("Brick")[1])
        for _ = 1, 3 do loseRound(game) end
        assert(game.state == "game_over" and game.lives == 0)
        local count = game.remaining
        game:update(10)
        assert(game.remaining == count and game.world:count("Ball") == 0)
        game:keypressed("r"); Helpers.finishIntro(game)
        assert(game.state == "playing" and game.levelIndex == 4 and game.lives == 3)
        assert(game.remaining == #game.level.bricks)
        local ball = Helpers.balls(game)[1].id
        game:keypressed("r"); Helpers.finishIntro(game)
        assert(game.world:has(ball), "R se ignora durante playing")
        game:reset(); Helpers.finishIntro(game)
        assert(game.levelIndex == 1 and game.lives == 3 and game.progress.maxUnlocked == 4)
    end)

    test("Menu cancela transiciones, bloquea simulacion y permite nueva campaña o ultimo desbloqueado", function()
        local game = Helpers.newGame()
        clear(game)
        game:keypressed("m")
        assert(game.state == "menu" and game.transitionRemaining == nil)
        game:update(100); Helpers.finishIntro(game)
        assert(game.levelIndex == 1 and game.state == "menu")
        game:keypressed("c"); Helpers.finishIntro(game)
        assert(game.levelIndex == 2 and game.lives == 3 and game.state == "playing")
        local id, remaining = Helpers.balls(game)[1].id, game.remaining
        for _, index in ipairs({0, 3, 1.5, "2", 100}) do assert(not Helpers.startCampaign(game, index)) end
        assert(game.world:has(id) and game.remaining == remaining and game.lives == 3)
        game:keypressed("m")
        game:keypressed("return"); Helpers.finishIntro(game)
        assert(game.levelIndex == 1 and game.lives == 3)
    end)

    test("Victoria de nivel prioritaria sobre ultima caida; doble contacto no duplica premio", function()
        for _, winningIndex in ipairs({1, 2}) do
            local game = Helpers.newGame()
            game.lives = 1
            Helpers.keepBricks(game, {1})
            Helpers.setBallCount(game, 2)
            local brick = Helpers.bricks(game)[1]
            local balls = Helpers.balls(game)
            local winner, loser = balls[winningIndex], balls[3 - winningIndex]
            winner.position.x, winner.position.y = brick.position.x, brick.position.y + 1
            winner.velocity.vx, winner.velocity.vy = 0, -280
            loser.position.x, loser.position.y = 400, Config.HEIGHT
            game:update(0)
            assert(game.state == "level_complete" and game.lives == 2)
            assert(not Bricks.destroy(game, brick.id) and not game:completeLevel())
            assert(game.lives == 2 and game.progress.maxUnlocked == 2)
        end
    end)

    test("Un fallo de disco no interrumpe progresion ni pierde desbloqueos de la sesion", function()
        local fs = Helpers.memoryFilesystem()
        fs.write = function() error("Disco no disponible") end
        local game = Helpers.newGame(fs)
        clear(game)
        assert(game.state == "level_complete" and game.progress.maxUnlocked == 2 and game.saveWarning)
        game:update(Config.LEVEL_TRANSITION_SECONDS); Helpers.finishIntro(game)
        assert(game.levelIndex == 2)
    end)

    test("ECS_ASSIGNMENT_MODE tras avanzar: cierre lateral sin vida ni desbloqueo adicionales", function()
        local game = Helpers.newGame()
        clear(game)
        game:update(Config.LEVEL_TRANSITION_SECONDS); Helpers.finishIntro(game)
        local originalMode, originalQuit, originalPrint = Config.ECS_ASSIGNMENT_MODE, love.event.quit, print
        local quits, message = 0, nil
        Config.ECS_ASSIGNMENT_MODE = true
        love.event.quit = function() quits = quits + 1 end
        print = function(value) message = value end
        local ok, err = xpcall(function()
            game:activatePowerup("multiball")
            local ball = Helpers.balls(game)[2]
            ball.position.x, ball.position.y = 0, 400
            ball.velocity.vx = -200
            game:update(0)
            assert(game.quitRequested and quits == 1 and message == "ECS: pelota toco la pared izquierda")
            assert(ball.velocity.vx == -200 and game.lives == 4 and game.progress.maxUnlocked == 2)
            game:update(10)
            assert(quits == 1 and game.levelIndex == 2)
        end, debug.traceback)
        Config.ECS_ASSIGNMENT_MODE, love.event.quit, print = originalMode, originalQuit, originalPrint
        assert(ok, err)
    end)

    test("Canvas real: diez niveles, transicion, menu y victoria de campaña", function()
        local game = Helpers.newGame()
        game.progress.maxUnlocked = 10
        local canvas = love.graphics.newCanvas(Config.WIDTH, Config.HEIGHT)
        local ok, err = xpcall(function()
            for index = 1, 10 do
                Helpers.startCampaign(game, index)
                love.graphics.setCanvas(canvas)
                game:draw()
                love.graphics.setCanvas()
                local pixels = canvas:newImageData()
                local r, g, b = pixels:getPixel(2, 93) -- Debajo del HUD, fuera de los bloques.
                local background = game.level.theme.background
                assert(math.abs(r - background[1]) < 0.01 and math.abs(g - background[2]) < 0.01
                    and math.abs(b - background[3]) < 0.01)
                pixels:release()
                clear(game)
                love.graphics.setCanvas(canvas)
                game:draw()
                love.graphics.setCanvas()
            end
            game:goToMenu()
            love.graphics.setCanvas(canvas)
            game:draw()
        end, debug.traceback)
        love.graphics.setCanvas()
        canvas:release()
        assert(ok, err)
    end)
    return passed
end

return {run = run}

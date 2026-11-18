local Game = require("src.game")
local World = require("src.ecs.world")
local Components = require("src.ecs.components")
local Config = require("src.config")
local Powerups = require("src.powerups")
local CollisionSystem = require("src.ecs.systems.collision_system")
local Helpers = require("tests.helpers")
local balls, paddle = Helpers.balls, Helpers.paddle

local function near(a, b) return math.abs(a - b) < 0.000001 end

local function speed(ball)
    return math.sqrt(ball.velocity.vx * ball.velocity.vx + ball.velocity.vy * ball.velocity.vy)
end

local function dataOnly(value)
    assert(type(value) ~= "function", "Los componentes solo contienen datos")
    if type(value) == "table" then
        assert(getmetatable(value) == nil, "Los componentes no tienen metodos heredados")
        for _, child in pairs(value) do dataOnly(child) end
    end
end

local function run()
    local realKeyboard, realRandom, realQuit, realPrint = love.keyboard.isDown, love.math.random, love.event.quit, print
    local originalMode = Config.ECS_ASSIGNMENT_MODE
    local realPrintText, realPrintf = love.graphics.print, love.graphics.printf
    local keys, quits, messages, passed = {}, 0, {}, 0
    love.keyboard.isDown = function(...)
        for index = 1, select("#", ...) do
            if keys[select(index, ...)] then return true end
        end
        return false
    end
    love.math.random = function() return 0.99 end
    love.event.quit = function() quits = quits + 1 end
    print = function(message) messages[#messages + 1] = message end

    local function test(name, fn)
        keys, quits, messages = {}, 0, {}
        Config.ECS_ASSIGNMENT_MODE = false
        fn()
        passed = passed + 1
        realPrint("OK ECS " .. passed .. ": " .. name)
    end

    local ok, err = xpcall(function()
        test("IDs unicos, componentes de datos independientes y limpieza al reiniciar", function()
            local game = Helpers.newGame()
            local world = game.world
            assert(world:count() == 74 and world:count("Brick") == 72)
            assert(world:count("Position", "Collider", "Renderable") == 74)
            assert(world:count("Velocity") == 2 and world:count("PaddleControl") == 1)
            Powerups.spawn(world, Config, Powerups.MULTIBALL, 40, 400)
            assert(world:count("PowerUp", "Velocity", "Position", "Collider", "Renderable") == 1)
            game:activatePowerup(Powerups.MULTIBALL)
            local originals = balls(game)
            assert(#originals == 3)
            for _, storage in pairs(world.components) do
                for id, data in pairs(storage) do
                    assert(type(id) == "number" and world:has(id))
                    dataOnly(data)
                end
            end
            for index = 2, 3 do
                for _, name in ipairs({"Position", "Velocity", "Collider", "Renderable", "Ball"}) do
                    assert(world:get(originals[1].id, name) ~= world:get(originals[index].id, name),
                        "Cada pelota debe tener componentes propios")
                end
            end
            originals[2].position.x = 17
            assert(originals[1].position.x ~= 17 and originals[3].position.x ~= 17)
            local oldIds, lastId = world:query(), world.nextId
            game:reset(); Helpers.finishIntro(game)
            assert(game.world == world and world:count() == 74)
            for _, id in ipairs(oldIds) do
                assert(not world:has(id) and world:get(id, "Position") == nil)
            end
            for _, id in ipairs(world:query()) do assert(id > lastId, "No reciclar IDs antiguos") end
        end)

        test("Consultas por componentes estables durante altas y bajas", function()
            local world = World.new()
            local first = world:create({Position = Components.position(0, 0)})
            local second = world:create({Position = Components.position(1, 1), Velocity = Components.velocity(2, 3)})
            local third = world:create({Position = Components.position(2, 2)})
            assert(world:count("Position", "Velocity") == 1 and world:count("Ball") == 0)
            local snapshot = world:query("Position")
            local visited, created = {}, nil
            for _, id in ipairs(snapshot) do
                if world:has(id, "Position") then
                    visited[#visited + 1] = id
                    if id == first then
                        assert(world:destroy(second) and not world:destroy(second))
                        created = world:create({Position = Components.position(3, 3)})
                    end
                end
            end
            assert(#snapshot == 3 and #visited == 2 and visited[2] == third)
            assert(world:get(second, "Position") == nil and world:get(second, "Velocity") == nil)
            assert(world:count("Position") == 3 and world:has(created))
        end)

        test("Flechas y A/D, eje horizontal, limites y teclas opuestas", function()
            for _, key in ipairs({"left", "a", "right", "d"}) do
                local game = Helpers.newGame()
                local player = paddle(game)
                local x, y = player.position.x, player.position.y
                local direction = (key == "left" or key == "a") and -1 or 1
                keys = {[key] = true}
                game:update(0.02)
                assert(near(player.position.x, x + direction * Config.PADDLE_SPEED * 0.02))
                assert(player.position.y == y and player.velocity.vy == 0)
                player.position.x = direction < 0 and 1 or Config.WIDTH - player.collider.w - 1
                game:update(0.02)
                assert(player.position.x == (direction < 0 and 0 or Config.WIDTH - player.collider.w))
                keys = {left = true, d = true}
                x = player.position.x
                game:update(0.02)
                assert(player.position.x == x and player.position.y == y)
                keys = {}
                game:update(0.02)
                assert(player.position.x == x and player.velocity.vx == 0)
            end
        end)

        test("Igual desplazamiento con dt dividido para paddle, pelota y poder", function()
            local coarse, fine = Helpers.newGame(), Helpers.newGame()
            for _, game in ipairs({coarse, fine}) do
                Powerups.spawn(game.world, Config, Powerups.MULTIBALL, 100, 400)
            end
            keys = {right = true}
            coarse:update(0.04)
            for step = 1, 4 do fine:update(0.01) end
            for _, tag in ipairs({"PaddleControl", "Ball", "PowerUp"}) do
                local a, b = Helpers.query(coarse, tag)[1], Helpers.query(fine, tag)[1]
                assert(near(a.position.x, b.position.x) and near(a.position.y, b.position.y), tag .. " usa dt")
            end
            local ball = balls(coarse)[1]
            local x = ball.position.x
            coarse:update(0)
            assert(ball.position.x == x)
            coarse:update(1)
            assert(near(ball.position.x, x + ball.velocity.vx * 0.05), "Conservar limite de dt original")
        end)

        test("Paddle separa la pelota y no acelera dos veces el mismo contacto", function()
            local game = Helpers.newGame()
            local ball, player = balls(game)[1], paddle(game)
            ball.position.x = player.position.x + (player.collider.w - ball.collider.w) / 2
            ball.position.y = player.position.y - ball.collider.h + 1
            ball.velocity.vx, ball.velocity.vy = 195, 280
            local expectedSpeed = speed(ball) * Config.PADDLE_SPEED_MULTIPLIER
            game:update(0)
            local vx, vy = ball.velocity.vx, ball.velocity.vy
            assert(near(vx, 0) and near(vy, -expectedSpeed))
            assert(ball.position.y + ball.collider.h == player.position.y)
            game:update(0)
            assert(ball.velocity.vx == vx and ball.velocity.vy == vy)
            -- Incluso con solapamiento, una pelota que ya sube no vuelve a rebotar.
            ball.position.y = ball.position.y + 1
            game:update(0)
            assert(ball.velocity.vx == vx and ball.velocity.vy == vy)
            game:update(0.01)
            assert(ball.position.y + ball.collider.h < player.position.y)
            assert(ball.velocity.vx == vx and ball.velocity.vy == vy)
            -- Un contacto posterior si debe volver a aumentar la rapidez.
            ball.position.y = player.position.y - ball.collider.h + 1
            ball.velocity.vy = -vy
            game:update(0)
            assert(near(ball.velocity.vy, vy * Config.PADDLE_SPEED_MULTIPLIER))
        end)

        local bounceCases = {
            {name = "extremo izquierdo", impact = -1, x = -math.sqrt(3) / 2, up = 0.5},
            {name = "zona izquierda intermedia", impact = -0.5, x = -0.5, up = math.sqrt(3) / 2},
            {name = "centro", impact = 0, x = 0, up = 1},
            {name = "zona derecha intermedia", impact = 0.5, x = 0.5, up = math.sqrt(3) / 2},
            {name = "extremo derecho", impact = 1, x = math.sqrt(3) / 2, up = 0.5},
        }
        for _, case in ipairs(bounceCases) do
            test("Rebote direccional: " .. case.name, function()
                for _, mode in ipairs({false, true}) do
                    Config.ECS_ASSIGNMENT_MODE = mode
                    for _, incomingX in ipairs({-195, 0, 195}) do
                        local game = Helpers.newGame()
                        local ball, player = balls(game)[1], paddle(game)
                        ball.velocity.vx, ball.velocity.vy = incomingX, 280
                        ball.position.x = player.position.x + player.collider.w / 2
                            + case.impact * player.collider.w / 2 - ball.collider.w / 2 - incomingX * 0.01
                        ball.position.y = player.position.y - ball.collider.h - 1
                        local expectedSpeed = speed(ball) * Config.PADDLE_SPEED_MULTIPLIER
                        game:update(0.01)
                        assert(near(ball.velocity.vx, expectedSpeed * case.x), "Direccion horizontal segun impacto")
                        assert(near(ball.velocity.vy, -expectedSpeed * case.up), "Angulo respecto a la vertical")
                        assert(near(speed(ball), expectedSpeed), "Conservar aumento de rapidez")
                        assert(ball.position.y + ball.collider.h == player.position.y and quits == 0)
                    end
                end
            end)
        end

        test("Rebote progresivo usa los centros y anchos actuales de los colliders", function()
            local game = Helpers.newGame()
            local ball, player = balls(game)[1], paddle(game)
            player.collider.w, ball.collider.w = 160, 19
            local previousX
            for step = -20, 20 do
                ball.position.x = player.position.x + player.collider.w / 2
                    + step / 20 * player.collider.w / 2 - ball.collider.w / 2
                ball.position.y = player.position.y - ball.collider.h + 1
                ball.velocity.vx, ball.velocity.vy = 195, 280
                local expectedSpeed = speed(ball) * Config.PADDLE_SPEED_MULTIPLIER
                game:update(0)
                local vx, vy = ball.velocity.vx, ball.velocity.vy
                if previousX then
                    assert(vx > previousX and vx - previousX < expectedSpeed * 0.06,
                        "La direccion varia gradualmente, sin zonas de direccion fija")
                end
                assert(vy < 0 and near(speed(ball), expectedSpeed))
                if step == 0 then assert(near(vx, 0), "Usar centros, no esquinas") end
                previousX = vx
            end
        end)

        test("Impactos con el centro fuera del paddle se limitan a 60 grados", function()
            for _, side in ipairs({-1, 1}) do
                local game = Helpers.newGame()
                local ball, player = balls(game)[1], paddle(game)
                local edge = player.position.x + (side == 1 and player.collider.w or 0)
                ball.position.x = edge + side * (ball.collider.w / 2 - 1) - ball.collider.w / 2
                ball.position.y = player.position.y - ball.collider.h + 1
                ball.velocity.vx, ball.velocity.vy = 195, 280
                local expectedSpeed = speed(ball) * Config.PADDLE_SPEED_MULTIPLIER
                game:update(0)
                assert(near(ball.velocity.vx, side * expectedSpeed * math.sqrt(3) / 2))
                assert(near(ball.velocity.vy, -expectedSpeed / 2))
                assert(ball.position.y + ball.collider.h == player.position.y)
            end
        end)

        test("MULTIBALL x3 rebota simultaneamente con direcciones y rapidez independientes", function()
            local game = Helpers.newGame()
            game:activatePowerup(Powerups.MULTIBALL)
            local active, player = balls(game), paddle(game)
            local impacts, directions = {-0.75, 0, 0.75}, {-math.sqrt(0.5), 0, math.sqrt(0.5)}
            local incoming = {{195, 280}, {-120, 400}, {300, 225}}
            local expectedSpeeds = {}
            assert(#active == 3)
            for index, ball in ipairs(active) do
                ball.velocity.vx, ball.velocity.vy = unpack(incoming[index])
                ball.position.x = player.position.x + player.collider.w / 2
                    + impacts[index] * player.collider.w / 2 - ball.collider.w / 2 - ball.velocity.vx * 0.01
                ball.position.y = player.position.y - ball.collider.h - 1
                expectedSpeeds[index] = speed(ball) * Config.PADDLE_SPEED_MULTIPLIER
            end
            game:update(0.01)
            for index, ball in ipairs(active) do
                assert(near(ball.velocity.vx, expectedSpeeds[index] * directions[index]))
                assert(near(ball.velocity.vy, -expectedSpeeds[index] * (index == 2 and 1 or math.sqrt(0.5))))
                assert(near(speed(ball), expectedSpeeds[index]))
                assert(ball.position.y + ball.collider.h == player.position.y)
            end
            game:update(0.01)
            for index, ball in ipairs(active) do
                assert(ball.position.y + ball.collider.h < player.position.y)
                assert(near(speed(ball), expectedSpeeds[index]), "No repetir aceleracion al separarse")
            end
            assert(game.world:count("Ball") == 3 and game.lives == 3 and game.remaining == 72)
        end)

        test("Paredes normales: contacto exacto, mayor rapidez y sin rebotes repetidos", function()
            for _, side in ipairs({"left", "right", "top"}) do
                local game = Helpers.newGame()
                local ball = balls(game)[1]
                ball.position.x, ball.position.y = 400, 400
                ball.velocity.vx, ball.velocity.vy = -195, -280
                if side == "left" then ball.position.x = 0 end
                if side == "right" then
                    ball.position.x = Config.WIDTH - ball.collider.w
                    ball.velocity.vx = 195
                end
                if side == "top" then ball.position.y = 0 end
                local oldSpeed = math.sqrt(195 * 195 + 280 * 280)
                game:update(0)
                local vx, vy = ball.velocity.vx, ball.velocity.vy
                assert(near(math.sqrt(vx * vx + vy * vy), oldSpeed * Config.WALL_SPEED_MULTIPLIER))
                assert((side == "left" and vx > 0) or (side == "right" and vx < 0) or (side == "top" and vy > 0))
                game:update(0)
                assert(ball.velocity.vx == vx and ball.velocity.vy == vy and quits == 0)
            end
        end)

        test("Entrega ECS: cualquiera de las pelotas cierra en ambos laterales sin rebotar", function()
            Config.ECS_ASSIGNMENT_MODE = true
            for _, side in ipairs({"izquierda", "derecha"}) do
                for _, touchingIndex in ipairs({1, 2, 3}) do
                    for _, dt in ipairs({0, 0.01}) do
                        quits, messages = 0, {}
                        local game = Helpers.newGame()
                        Helpers.setBallCount(game, 3)
                        local ball = balls(game)[touchingIndex]
                        local left = side == "izquierda"
                        local edge = left and 0 or Config.WIDTH - ball.collider.w
                        ball.position.x, ball.position.y = edge, 400
                        ball.velocity.vx, ball.velocity.vy = left and -195 or 195, -280
                        local vx, vy = ball.velocity.vx, ball.velocity.vy
                        local player = paddle(game)
                        Powerups.spawn(game.world, Config, Powerups.MULTIBALL, player.position.x + 10, player.position.y)
                        game:update(dt)
                        assert(quits == 1 and game.quitRequested and #messages == 1)
                        assert(messages[1] == "ECS: pelota toco la pared " .. side)
                        assert(ball.velocity.vx == vx and ball.velocity.vy == vy, "No rebotar ni acelerar")
                        assert(near(ball.position.x, edge + vx * dt), "No corregir posicion antes del cierre")
                        assert(game.lives == 3 and game.world:count("Ball") == 3 and game.world:count("PowerUp") == 1)
                        game:update(0.01)
                        game:activatePowerup(Powerups.MULTIBALL)
                        assert(quits == 1 and #messages == 1 and game.world:count("Ball") == 3)
                    end
                end
            end
        end)

        test("Entrega ECS conserva rebote superior y vidas al caer sin tocar laterales", function()
            Config.ECS_ASSIGNMENT_MODE = true
            local game = Helpers.newGame()
            local ball = balls(game)[1]
            ball.position.x, ball.position.y = 400, 0
            ball.velocity.vy = -280
            game:update(0)
            assert(near(ball.velocity.vy, 280 * Config.WALL_SPEED_MULTIPLIER) and quits == 0)
            ball.position.x, ball.position.y = 400, Config.HEIGHT - ball.collider.h
            game:update(0)
            assert(game.lives == 2 and game.world:count("Ball") == 1 and quits == 0)
        end)

        test("Consultas acotadas con 90 pelotas para colisiones y MULTIBALL", function()
            for _, count in ipairs({1, Config.MAX_BALLS}) do
                local game = Helpers.newGame()
                Helpers.setBallCount(game, count)
                local calls, query = 0, game.world.query
                game.world.query = function(world, ...)
                    calls = calls + 1
                    return query(world, ...)
                end
                CollisionSystem.update(game, 0)
                assert(calls <= 4, "Una consulta por tipo: pelotas, paddles, bloques y obstaculos")
            end
            local game = Helpers.newGame()
            Helpers.setBallCount(game, 81)
            local calls, query = 0, game.world.query
            game.world.query = function(world, ...)
                calls = calls + 1
                return query(world, ...)
            end
            game:activatePowerup(Powerups.MULTIBALL)
            assert(calls <= 2, "Calcular capacidad una sola vez, no contar por cada copia")
            assert(game.world:count("Ball") == Config.MAX_BALLS)
        end)

        test("Entrega ECS con 90 pelotas: ambos laterales cierran sin rebote ni descuento", function()
            Config.ECS_ASSIGNMENT_MODE = true
            for _, side in ipairs({"izquierda", "derecha"}) do
                for _, touchingIndex in ipairs({1, 45, Config.MAX_BALLS}) do
                    quits, messages = 0, {}
                    local game = Helpers.newGame()
                    Helpers.setBallCount(game, Config.MAX_BALLS)
                    local ball = balls(game)[touchingIndex]
                    ball.position.x = side == "izquierda" and 0 or Config.WIDTH - ball.collider.w
                    ball.position.y = 400
                    ball.velocity.vx = side == "izquierda" and -330 or 330
                    ball.velocity.vy = -440
                    local vx, vy = ball.velocity.vx, ball.velocity.vy
                    game:update(0)
                    assert(quits == 1 and game.quitRequested and #messages == 1)
                    assert(messages[1] == "ECS: pelota toco la pared " .. side)
                    assert(ball.velocity.vx == vx and ball.velocity.vy == vy)
                    assert(game.lives == 3 and game.remaining == 72 and game.world:count("Ball") == Config.MAX_BALLS)
                    game:update(0.01)
                    assert(quits == 1)
                end
            end
        end)

        test("90 pelotas a maxima rapidez: 120 frames y Canvas real sin crear fuentes", function()
            local game = Helpers.newGame()
            Helpers.setBallCount(game, Config.MAX_BALLS)
            local active = balls(game)
            local canvas = love.graphics.newCanvas(Config.WIDTH, Config.HEIGHT)
            local realNewFont, label = love.graphics.newFont, false
            love.graphics.newFont = function() error("No crear fuentes durante update/draw") end
            love.graphics.printf = function(value, ...)
                if value == "Pelotas: " .. Config.MAX_BALLS .. " / " .. Config.MAX_BALLS then label = true end
                return realPrintf(value, ...)
            end
            local success, err = xpcall(function()
                for _ = 1, 120 do
                    for index, ball in ipairs(active) do
                        ball.position.x, ball.position.y = 20 + (index * 37) % 880, 350 + (index * 13) % 150
                        ball.velocity.vx, ball.velocity.vy = 330, -440
                        if index % 10 == 0 then ball.position.x, ball.velocity.vx = 0, -330 end
                    end
                    game:update(1 / 60)
                    love.graphics.setCanvas(canvas)
                    game:draw()
                    love.graphics.setCanvas()
                    assert(game.world:count("Ball") == Config.MAX_BALLS and game.lives == 3 and game.remaining == 72)
                    for _, ball in ipairs(active) do assert(near(speed(ball), Config.BALL_MAX_SPEED)) end
                end
                assert(label, "HUD muestra 90 / 90 desde Config")
            end, debug.traceback)
            love.graphics.setCanvas()
            love.graphics.newFont, love.graphics.printf = realNewFont, realPrintf
            canvas:release()
            assert(success, err)
        end)

        test("Dibujo real en Canvas: contadores, x3 y mensajes de victoria/derrota", function()
            local game = Helpers.newGame()
            Powerups.spawn(game.world, Config, Powerups.MULTIBALL, 100, 400)
            local text = {}
            love.graphics.print = function(value, ...)
                text[value] = true
                return realPrintText(value, ...)
            end
            love.graphics.printf = function(value, ...)
                text[value] = true
                return realPrintf(value, ...)
            end
            local canvas = love.graphics.newCanvas(Config.WIDTH, Config.HEIGHT)
            for _, state in ipairs({"playing", "campaign_complete", "game_over"}) do
                game.state = state
                text = {}
                love.graphics.setCanvas(canvas)
                game:draw()
                love.graphics.setCanvas()
                assert(text["Vidas: 3"] and text["Pelotas: 1 / " .. Config.MAX_BALLS]
                    and text["Bloques restantes: 72"] and text.x3)
                if state == "playing" then
                    assert(not text["YOU WIN!"] and not text["GAME OVER"])
                else
                    assert(text[state == "campaign_complete" and "YOU WIN!" or "GAME OVER"] and text[state == "campaign_complete"
                        and "Campaña completada — 10 niveles superados"
                        or "R: reiniciar este nivel   |   M: menú"])
                end
                local pixels = canvas:newImageData()
                local r, g, b = pixels:getPixel(45, 95)
                assert(math.abs(r - 1) < 0.01 and math.abs(g - 0.33) < 0.01 and math.abs(b - 0.32) < 0.01,
                    "Bloques conservan color y posicion")
                pixels:release()
            end
            canvas:release()
            love.graphics.print, love.graphics.printf = realPrintText, realPrintf
        end)
    end, debug.traceback)

    love.graphics.setCanvas()
    love.graphics.print, love.graphics.printf = realPrintText, realPrintf
    love.keyboard.isDown, love.math.random, love.event.quit, print = realKeyboard, realRandom, realQuit, realPrint
    Config.ECS_ASSIGNMENT_MODE = originalMode
    if not ok then error(err, 0) end
    return passed
end

return {run = run}

local Game = require("src.game")
local Ball = require("src.ball")
local Config = require("src.config")
local Powerups = require("src.powerups")

local function check(condition, message)
    assert(condition, message)
end

local function near(a, b)
    return math.abs(a - b) < 0.000001
end

local function speed(ball)
    return math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
end

local function setBallCount(game, count)
    game.balls = {}
    for index = 1, count do game.balls[index] = Ball.new(Config) end
end

local function falling(ball)
    ball.x = Config.WIDTH - ball.w - 1
    ball.y = Config.HEIGHT - ball.h - 1
    ball.vx, ball.vy = 0, 600
end

local function aimAt(ball, brick)
    ball.x = brick.x + (brick.w - ball.w) / 2
    ball.y = brick.y - ball.h - 1
    ball.vx, ball.vy = 0, 280
end

local function pickup(game)
    return game.powerups:spawn(Powerups.MULTIBALL,
        game.paddle.x + game.paddle.w / 2, game.paddle.y + game.paddle.h / 2)
end

local function resetEntities(game)
    check(#game.balls == 1, "Debe quedar una sola pelota")
    local ball = game.balls[1]
    check(ball.x == (Config.WIDTH - ball.w) / 2 and ball.y == Config.PADDLE_Y - 85,
          "Posicion inicial de pelota")
    check(ball.vx == Config.BALL_START_VX and ball.vy == Config.BALL_START_VY,
          "Velocidad inicial de pelota")
    check(game.paddle.x == (Config.WIDTH - game.paddle.w) / 2, "Paddle centrado")
    check(#game.powerups.items == 0, "No deben quedar poderes")
end

local function frozen(game)
    local balls, powers = {}, {}
    for index, ball in ipairs(game.balls) do balls[index] = {ball.x, ball.y} end
    for index, power in ipairs(game.powerups.items) do powers[index] = {power.x, power.y} end
    local px, lives, remaining, state = game.paddle.x, game.lives, game.remaining, game.state
    for frame = 1, 120 do game:update(1 / 60) end
    game:activatePowerup(Powerups.MULTIBALL)
    check(#game.balls == #balls and #game.powerups.items == #powers, "Estado final no crea entidades")
    check(game.paddle.x == px and game.lives == lives and game.remaining == remaining
          and game.state == state, "Estado final estable")
    for index, ball in ipairs(game.balls) do
        check(ball.x == balls[index][1] and ball.y == balls[index][2], "Pelota detenida")
    end
    for index, power in ipairs(game.powerups.items) do
        check(power.x == powers[index][1] and power.y == powers[index][2], "Poder detenido")
    end
end

local function run(root)
    local realRandom, realKeyboard, realQuit, realPrint = love.math.random, love.keyboard.isDown, love.event.quit, print
    local originalNew = Game.new
    local savedCallbacks = {load = love.load, update = love.update, draw = love.draw, keypressed = love.keypressed}
    local randomValue, randomCalls, heldKey, quitCalls, notices
    local passed = 0

    love.math.random = function() randomCalls = randomCalls + 1; return randomValue end
    love.keyboard.isDown = function(...)
        for index = 1, select("#", ...) do
            if select(index, ...) == heldKey then return true end
        end
        return false
    end
    love.event.quit = function() quitCalls = quitCalls + 1 end
    print = function(message)
        if message == "Game Over" or message == "You Win!" then
            notices[message] = (notices[message] or 0) + 1
        else
            realPrint(message)
        end
    end

    local function test(name, fn)
        randomValue, randomCalls, heldKey, quitCalls, notices = 0.99, 0, nil, 0, {}
        fn()
        check(quitCalls == 0, "El juego no debe cerrarse automaticamente")
        passed = passed + 1
        realPrint("OK " .. passed .. ": " .. name)
    end

    local ok, err = xpcall(function()
        test("Una pelota cae: una vida, bloques conservados y ronda limpia", function()
            local game = Game.new()
            check(game.lives == 3 and game.state == "playing", "Inicio con tres vidas")
            aimAt(game.balls[1], game.bricks[1])
            game:update(0.01)
            local bricks, remaining = game.bricks, game.remaining
            check(remaining == 71, "Destruir un bloque antes de caer")
            pickup(game)
            game.paddle.x = 0
            falling(game.balls[1])
            game:update(0.01)
            check(game.lives == 2 and game.state == "playing", "Se descuenta una vida")
            check(game.bricks == bricks and game.remaining == remaining, "Se conservan los bloques")
            resetEntities(game)
            game:update(0.01)
            check(game.lives == 2, "No repetir descuento al siguiente frame")
        end)

        test("Tres pelotas, cae la del medio: quedan dos y no se pierde vida", function()
            local game = Game.new()
            setBallCount(game, 3)
            local first, third = game.balls[1], game.balls[3]
            local oldX = first.x
            falling(game.balls[2])
            game:update(0.01)
            check(#game.balls == 2 and game.lives == 3, "Conservar vidas y dos pelotas")
            check(game.balls[1] == first and game.balls[2] == third, "Eliminar solo la que cayo")
            check(near(first.x, oldX + first.vx * 0.01) and near(third.x, oldX + third.vx * 0.01),
                  "Ambas sobrevivientes se actualizan")
        end)

        test("Dos pelotas caen en el mismo frame: se descuenta exactamente una vida", function()
            local game = Game.new()
            setBallCount(game, 2)
            for _, ball in ipairs(game.balls) do falling(ball) end
            game:update(0.01)
            check(game.lives == 2 and game.state == "playing", "Solo una vida por ronda")
            resetEntities(game)
        end)

        test("Recoger x3 con una pelota: tres, originales intactas y dispersion de 25 grados", function()
            local game = Game.new()
            local original = game.balls[1]
            local vx, vy = original.vx, original.vy
            pickup(game)
            game:update(0)
            check(#game.balls == 3 and #game.powerups.items == 0, "Recogida produce tres pelotas")
            check(game.balls[1] == original and original.vx == vx and original.vy == vy, "Original conservada")
            for index = 2, 3 do
                local clone = game.balls[index]
                check(clone ~= original and clone.x == original.x and clone.y == original.y, "Copia independiente")
                check(near(speed(clone), speed(original)), "Misma rapidez")
                local cosine = (clone.vx * vx + clone.vy * vy) / (speed(clone) * speed(original))
                check(near(cosine, math.cos(math.rad(25))), "Angulo de 25 grados")
                local cross = vx * clone.vy - vy * clone.vx
                check((index == 2 and cross < 0) or (index == 3 and cross > 0), "Dispersion a ambos lados")
            end
            game:update(0)
            check(#game.balls == 3, "El poder se aplica solo una vez")
        end)

        test("Recoger x3 con tres pelotas: nueve", function()
            local game = Game.new()
            setBallCount(game, 3)
            pickup(game)
            game:update(0)
            check(#game.balls == 9, "3 -> 9")
        end)

        test("Limite de 30, incluyendo 27/29 pelotas y poderes simultaneos", function()
            for _, count in ipairs({10, 11, 27, 29, 30}) do
                local game = Game.new()
                setBallCount(game, count)
                local originals = {}
                for index, ball in ipairs(game.balls) do originals[index] = ball end
                pickup(game)
                pickup(game)
                game:update(0)
                check(#game.balls == 30 and #game.powerups.items == 0, "No superar 30")
                for index, ball in ipairs(originals) do check(game.balls[index] == ball, "Conservar originales") end
                for _, ball in ipairs(game.balls) do falling(ball) end
                game:update(0.01)
                check(game.lives == 2 and #game.balls == 1, "Treinta caidas solo cuestan una vida")
            end
        end)

        test("Dos ultimos bloques destruidos en el mismo frame: una sola victoria", function()
            local game = Game.new()
            game.bricks = {game.bricks[1], game.bricks[4]}
            game.remaining = 2
            setBallCount(game, 2)
            aimAt(game.balls[1], game.bricks[1])
            aimAt(game.balls[2], game.bricks[2])
            pickup(game)
            game:update(0.01)
            check(game.state == "won" and game.remaining == 0 and #game.bricks == 0, "Victoria al ultimo bloque")
            check(#game.balls == 2 and #game.powerups.items == 1, "No recoger poderes tras ganar")
            heldKey = "right"
            frozen(game)
            check(notices["You Win!"] == 1, "Victoria no se repite")
        end)

        test("Tercera vida: GAME OVER, sin movimiento ni nuevas pelotas", function()
            local game = Game.new()
            for round = 1, 3 do
                pickup(game)
                falling(game.balls[1])
                game:update(0.01)
                check(game.lives == 3 - round, "Una vida por ronda")
            end
            check(game.state == "lost" and #game.balls == 0, "Derrota sin pelotas")
            heldKey = "right"
            frozen(game)
            check(notices["Game Over"] == 1, "Derrota no se repite")
        end)

        test("R real de main.lua reinicia desde won/lost y se ignora durante playing", function()
            for _, state in ipairs({"won", "lost"}) do
                local game = Game.new()
                setBallCount(game, 9)
                pickup(game)
                game.state, game.lives, game.bricks, game.remaining = state, 0, {}, 0
                Game.new = function() return game end
                assert(loadfile(root .. "/main.lua"))()
                love.load()
                local keypressed = love.keypressed
                Game.new = originalNew
                love.load, love.update, love.draw, love.keypressed = savedCallbacks.load, savedCallbacks.update, savedCallbacks.draw, savedCallbacks.keypressed
                keypressed("r")
                check(game.state == "playing" and game.lives == 3 and #game.bricks == 72 and game.remaining == 72,
                      "Reinicio completo")
                resetEntities(game)
                local ball = game.balls[1]
                local x = ball.x
                game:update(0.01)
                check(ball.x ~= x, "Movimiento despues de R")
                keypressed("r")
                check(game.balls[1] == ball and ball.x ~= x, "R no reinicia durante playing")
            end
        end)

        test("Dos pelotas golpean el mismo bloque: una destruccion y un solo sorteo", function()
            local game = Game.new()
            game.bricks = {game.bricks[1], game.bricks[4]}
            game.remaining = 2
            setBallCount(game, 2)
            for _, ball in ipairs(game.balls) do aimAt(ball, game.bricks[1]) end
            randomValue = 0
            game:update(0.01)
            check(game.remaining == 1 and #game.bricks == 1, "Eliminar una sola vez")
            check(randomCalls == 1 and #game.powerups.items == 1, "Un solo poder por bloque")
        end)

        test("Recoger x3 con dos pelotas: seis", function()
            local game = Game.new()
            setBallCount(game, 2)
            pickup(game)
            game:update(0)
            check(#game.balls == 6, "2 -> 6")
        end)

        test("Victoria prioritaria con caida y poder en el mismo frame, en ambos ordenes", function()
            for _, winningIndex in ipairs({1, 2}) do
                local game = Game.new()
                game.lives = 1
                game.bricks = {game.bricks[1]}
                game.remaining = 1
                setBallCount(game, 2)
                aimAt(game.balls[winningIndex], game.bricks[1])
                falling(game.balls[3 - winningIndex])
                pickup(game)
                game:update(0.01)
                check(game.state == "won" and game.lives == 1, "Victoria antes de descontar vidas")
                check(#game.balls <= 2 and #game.powerups.items == 1, "Sin multiplicar tras victoria")
            end
        end)

        test("Probabilidad 15%, origen en el bloque, caida con dt y limpieza fuera de pantalla", function()
            local game = Game.new()
            local brick = game.bricks[1]
            randomValue = 0.149999
            local power = game.powerups:trySpawn(brick)
            check(power and power.name == "MULTIBALL x3", "Valor menor a 0.15 genera poder")
            check(near(power.x + power.w / 2, brick.x + brick.w / 2)
                  and near(power.y + power.h / 2, brick.y + brick.h / 2), "Poder centrado en el bloque")
            randomValue = 0.15
            check(game.powerups:trySpawn(brick) == nil, "Valor desde 0.15 no genera poder")
            local x, y = power.x, power.y
            game:update(0.02)
            check(power.x == x and near(power.y, y + Config.POWERUP_FALL_SPEED * 0.02), "Caida vertical con dt")
            game.powerups:spawn(Powerups.MULTIBALL, 0, Config.HEIGHT + 30)
            power.y = Config.HEIGHT
            game:update(0)
            check(#game.powerups.items == 0 and #game.balls == 1, "Eliminar todos los poderes perdidos")
        end)

        test("Dos poderes recogidos en el mismo frame: 1 -> 3 -> 9", function()
            local game = Game.new()
            pickup(game)
            pickup(game)
            game:update(0)
            check(#game.balls == 9 and #game.powerups.items == 0, "Ambos poderes se recogen una sola vez")
        end)

        test("Dispersion valida con ejes casi detenidos y pelota sin velocidad", function()
            local angle = math.rad(25)
            local vectors = {{0, 0}, {0.000000000001, 0}, {195, 0}, {0, -280},
                             {300 * math.cos(angle), 300 * math.sin(angle)}}
            for _, vector in ipairs(vectors) do
                local ball = Ball.new(Config)
                local initialSpeed = speed(ball)
                ball.vx, ball.vy = vector[1], vector[2]
                for _, direction in ipairs({-1, 1}) do
                    local clone = ball:cloneRotated(direction * angle, Config)
                    check(clone.vx == clone.vx and clone.vy == clone.vy and math.abs(clone.vx) > 0 and math.abs(clone.vy) > 0,
                          "Velocidad finita y activa en ambos ejes")
                    check(near(speed(clone), speed(ball) < 0.000001 and initialSpeed or speed(ball)), "Rapidez conservada o restaurada")
                end
            end
        end)

        test("Colisiones individuales, movimiento con dt y aceleracion del paddle", function()
            local game = Game.new()
            setBallCount(game, 3)
            local left, right, top = game.balls[1], game.balls[2], game.balls[3]
            left.x, left.y, left.vx = -1, 400, -195
            right.x, right.y, right.vx = Config.WIDTH, 400, 195
            top.x, top.y, top.vy = 10, -1, -280
            game:update(0)
            check(left.x == 0 and left.vx == 195, "Pared izquierda")
            check(right.x == Config.WIDTH - right.w and right.vx == -195, "Pared derecha")
            check(top.y == 0 and top.vy == 280, "Pared superior")
            game:resetRound()
            local ball = game.balls[1]
            local x, y, px = ball.x, ball.y, game.paddle.x
            heldKey = "right"
            game:update(0.01)
            check(near(ball.x, x + ball.vx * 0.01) and near(ball.y, y + ball.vy * 0.01), "Pelota usa dt")
            check(near(game.paddle.x, px + Config.PADDLE_SPEED * 0.01), "Paddle usa dt")
            heldKey = nil
            ball.x, ball.y = game.paddle.x + 10, game.paddle.y - ball.h - 1
            ball.vx, ball.vy = 195, 280
            game:update(0.01)
            check(near(ball.vx, -195 * Config.PADDLE_SPEED_MULTIPLIER)
                  and near(ball.vy, -280 * Config.PADDLE_SPEED_MULTIPLIER), "Rebote acelera ambos ejes")
        end)
    end, debug.traceback)

    love.math.random, love.keyboard.isDown, love.event.quit, print = realRandom, realKeyboard, realQuit, realPrint
    Game.new = originalNew
    love.load, love.update, love.draw, love.keypressed = savedCallbacks.load, savedCallbacks.update, savedCallbacks.draw, savedCallbacks.keypressed
    if not ok then error(err, 0) end
    return passed
end

return {run = run}

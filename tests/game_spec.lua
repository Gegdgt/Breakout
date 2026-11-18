local Game = require("src.game")
local Ball = require("src.ball")
local Config = require("src.config")
local Powerups = require("src.powerups")
local Helpers = require("tests.helpers")
local balls, bricks, powers, paddle = Helpers.balls, Helpers.bricks, Helpers.powers, Helpers.paddle
local setBallCount, keepBricks = Helpers.setBallCount, Helpers.keepBricks

local function check(condition, message)
    assert(condition, message)
end

local function near(a, b)
    return math.abs(a - b) < 0.000001
end

local function speed(ball)
    return math.sqrt(ball.velocity.vx * ball.velocity.vx + ball.velocity.vy * ball.velocity.vy)
end

local function falling(ball)
    ball.position.x = Config.WIDTH - ball.collider.w - 1
    ball.position.y = Config.HEIGHT - ball.collider.h - 1
    ball.velocity.vx, ball.velocity.vy = 0, 600
end

local function aimAt(ball, brick)
    ball.position.x = brick.position.x + (brick.collider.w - ball.collider.w) / 2
    ball.position.y = brick.position.y - ball.collider.h - 1
    ball.velocity.vx, ball.velocity.vy = 0, 280
end

local function trySpawn(game, brick)
    return Helpers.entity(game, Powerups.trySpawn(game.world, Config, brick.position, brick.collider,
        game.world:get(brick.id, "Brick").dropChance))
end

local function pickup(game)
    return Powerups.spawn(game.world, Config, Powerups.MULTIBALL,
        paddle(game).position.x + paddle(game).collider.w / 2, paddle(game).position.y + paddle(game).collider.h / 2)
end

local function resetEntities(game, remainingPowers)
    check(#balls(game) == 1, "Debe quedar una sola pelota")
    local ball = balls(game)[1]
    check(ball.position.x == (Config.WIDTH - ball.collider.w) / 2 and ball.position.y == Config.PADDLE_Y - 85,
          "Posicion inicial de pelota")
    check(ball.velocity.vx == Config.BALL_START_VX and ball.velocity.vy == Config.BALL_START_VY,
          "Velocidad inicial de pelota")
    check(paddle(game).position.x == (Config.WIDTH - paddle(game).collider.w) / 2, "Paddle centrado")
    check(#powers(game) == (remainingPowers or 0), "Conservar solo los objetos esperados")
end

local function frozen(game)
    local savedBalls, savedPowers = {}, {}
    for index, ball in ipairs(balls(game)) do savedBalls[index] = {ball.position.x, ball.position.y} end
    for index, power in ipairs(powers(game)) do savedPowers[index] = {power.position.x, power.position.y} end
    local px, lives, remaining, state = paddle(game).position.x, game.lives, game.remaining, game.state
    for frame = 1, 120 do game:update(1 / 60) end
    game:activatePowerup(Powerups.MULTIBALL)
    check(#balls(game) == #savedBalls and #powers(game) == #savedPowers, "Estado final no crea entidades")
    check(paddle(game).position.x == px and game.lives == lives and game.remaining == remaining
          and game.state == state, "Estado final estable")
    for index, ball in ipairs(balls(game)) do
        check(ball.position.x == savedBalls[index][1] and ball.position.y == savedBalls[index][2], "Pelota detenida")
    end
    for index, power in ipairs(powers(game)) do
        check(power.position.x == savedPowers[index][1] and power.position.y == savedPowers[index][2], "Poder detenido")
    end
end

local function run(root)
    local realRandom, realKeyboard, realQuit, realPrint = love.math.random, love.keyboard.isDown, love.event.quit, print
    local originalNew = Game.new
    local savedCallbacks = {load = love.load, update = love.update, draw = love.draw, keypressed = love.keypressed, quit = love.quit, focus = love.focus}
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
        test("Una pelota cae: una vida, bloques y poder caido conservados", function()
            local game = Helpers.newGame()
            check(game.lives == 3 and game.state == "playing", "Inicio con tres vidas")
            aimAt(balls(game)[1], bricks(game)[1])
            game:update(0.01)
            local savedBricks, remaining = bricks(game), game.remaining
            check(remaining == 71, "Destruir un bloque antes de caer")
            local pendingPower = pickup(game)
            paddle(game).position.x = 0
            falling(balls(game)[1])
            game:update(0.01)
            check(game.lives == 2 and game.state == "playing", "Se descuenta una vida")
            check(bricks(game)[1].id == savedBricks[1].id and game.remaining == remaining, "Se conservan los bloques")
            resetEntities(game, 1)
            check(game.world:has(pendingPower, "PowerUp"), "El objeto no recogido conserva su entidad")
            game:update(0.01)
            check(game.lives == 2, "No repetir descuento al siguiente frame")
        end)

        test("Tres pelotas, cae la del medio: quedan dos y no se pierde vida", function()
            local game = Helpers.newGame()
            setBallCount(game, 3)
            local first, third = balls(game)[1], balls(game)[3]
            local oldX = first.position.x
            falling(balls(game)[2])
            game:update(0.01)
            check(#balls(game) == 2 and game.lives == 3, "Conservar vidas y dos pelotas")
            check(balls(game)[1].id == first.id and balls(game)[2].id == third.id, "Eliminar solo la que cayo")
            check(near(first.position.x, oldX + first.velocity.vx * 0.01) and near(third.position.x, oldX + third.velocity.vx * 0.01),
                  "Ambas sobrevivientes se actualizan")
        end)

        test("Dos pelotas caen en el mismo frame: se descuenta exactamente una vida", function()
            local game = Helpers.newGame()
            setBallCount(game, 2)
            for _, ball in ipairs(balls(game)) do falling(ball) end
            game:update(0.01)
            check(game.lives == 2 and game.state == "playing", "Solo una vida por ronda")
            resetEntities(game)
        end)

        test("Recoger x3 con una pelota: tres, originales intactas y dispersion de 25 grados", function()
            local game = Helpers.newGame()
            local original = balls(game)[1]
            local vx, vy = original.velocity.vx, original.velocity.vy
            pickup(game)
            game:update(0)
            check(#balls(game) == 3 and #powers(game) == 0, "Recogida produce tres pelotas")
            check(balls(game)[1].id == original.id and original.velocity.vx == vx and original.velocity.vy == vy, "Original conservada")
            for index = 2, 3 do
                local clone = balls(game)[index]
                check(clone.id ~= original.id and clone.position.x == original.position.x and clone.position.y == original.position.y, "Copia independiente")
                check(near(speed(clone), speed(original)), "Misma rapidez")
                local cosine = (clone.velocity.vx * vx + clone.velocity.vy * vy) / (speed(clone) * speed(original))
                check(near(cosine, math.cos(math.rad(25))), "Angulo de 25 grados")
                local cross = vx * clone.velocity.vy - vy * clone.velocity.vx
                check((index == 2 and cross < 0) or (index == 3 and cross > 0), "Dispersion a ambos lados")
            end
            game:update(0)
            check(#balls(game) == 3, "El poder se aplica solo una vez")
        end)

        test("Recoger x3 con tres pelotas: nueve", function()
            local game = Helpers.newGame()
            setBallCount(game, 3)
            pickup(game)
            game:update(0)
            check(#balls(game) == 9, "3 -> 9")
        end)

        test("Limite configurable, incluyendo 81/89 pelotas y poderes simultaneos", function()
            for _, count in ipairs({10, 11, 27, 29, Config.MAX_BALLS / 3,
                                    81, Config.MAX_BALLS - 3, Config.MAX_BALLS - 1, Config.MAX_BALLS}) do
                local game = Helpers.newGame()
                setBallCount(game, count)
                local originals = {}
                for index, ball in ipairs(balls(game)) do originals[index] = ball end
                pickup(game)
                pickup(game)
                game:update(0)
                check(#balls(game) == Config.MAX_BALLS and #powers(game) == 0, "No superar MAX_BALLS")
                for index, ball in ipairs(originals) do check(balls(game)[index].id == ball.id, "Conservar originales") end
                for _, ball in ipairs(balls(game)) do falling(ball) end
                game:update(0.01)
                check(game.lives == 2 and #balls(game) == 1, "Todas las caidas solo cuestan una vida")
            end
        end)

        test("Dos ultimos bloques en el mismo frame: el jefe sigue vivo y su derrota da una sola victoria", function()
            local game = Helpers.newGame()
            game.progress.maxUnlocked = game.levels:count()
            assert(Helpers.startCampaign(game, game.levels:count()))
            Helpers.keepNormalBricks(game, 2)
            game.remaining = 2
            setBallCount(game, 2)
            aimAt(balls(game)[1], bricks(game)[1])
            aimAt(balls(game)[2], bricks(game)[2])
            game:update(0.01)
            check(game.state == "playing" and game.remaining == 0, "Vaciar bloques no derrota al jefe")
            pickup(game)
            Helpers.defeatBoss(game)
            check(game.state == "campaign_complete" and game.remaining == 0 and #bricks(game) == 0, "Victoria al ultimo bloque")
            check(#balls(game) == 2 and #powers(game) == 1, "No recoger poderes tras ganar")
            heldKey = "right"
            frozen(game)
            check(notices["You Win!"] == 1, "Victoria no se repite")
        end)

        test("Tercera vida: GAME OVER, sin movimiento ni nuevas pelotas", function()
            local game = Helpers.newGame()
            for round = 1, 3 do
                pickup(game)
                falling(balls(game)[1])
                game:update(0.01)
                check(game.lives == 3 - round, "Una vida por ronda")
            end
            check(game.state == "game_over" and #balls(game) == 0, "Derrota sin pelotas")
            heldKey = "right"
            frozen(game)
            check(notices["Game Over"] == 1, "Derrota no se repite")
        end)

        test("R real de main.lua reinicia desde campaign_complete/game_over y se ignora durante playing", function()
            for _, state in ipairs({"campaign_complete", "game_over"}) do
                local game = Helpers.newGame()
                setBallCount(game, 9)
                pickup(game)
                keepBricks(game, {})
                game.state, game.lives = state, 0
                Game.new = function() return game end
                assert(loadfile(root .. "/main.lua"))()
                love.load()
                local keypressed = love.keypressed
                Game.new = originalNew
                love.load, love.update, love.draw, love.keypressed = savedCallbacks.load, savedCallbacks.update, savedCallbacks.draw, savedCallbacks.keypressed
                love.quit = savedCallbacks.quit
                love.focus = savedCallbacks.focus
                keypressed("r"); Helpers.finishIntro(game)
                check(game.state == "playing" and game.lives == 3 and #bricks(game) == 72 and game.remaining == 72,
                      "Reinicio completo")
                resetEntities(game)
                local ball = balls(game)[1]
                local x = ball.position.x
                game:update(0.01)
                check(ball.position.x ~= x, "Movimiento despues de R")
                keypressed("r"); Helpers.finishIntro(game)
                check(balls(game)[1].id == ball.id and ball.position.x ~= x, "R no reinicia durante playing")
            end
        end)

        test("Dos pelotas golpean el mismo bloque: una destruccion y un solo sorteo", function()
            local game = Helpers.newGame()
            keepBricks(game, {1, 4})
            game.remaining = 2
            setBallCount(game, 2)
            for _, ball in ipairs(balls(game)) do aimAt(ball, bricks(game)[1]) end
            randomValue = 0
            game:update(0.01)
            check(game.remaining == 1 and #bricks(game) == 1, "Eliminar una sola vez")
            check(randomCalls == 1 and #powers(game) == 1, "Un solo poder por bloque")
        end)

        test("Recoger x3 con dos pelotas: seis", function()
            local game = Helpers.newGame()
            setBallCount(game, 2)
            pickup(game)
            game:update(0)
            check(#balls(game) == 6, "2 -> 6")
        end)

        test("Victoria prioritaria con caida y poder en el mismo frame, en ambos ordenes", function()
            for _, winningIndex in ipairs({1, 2}) do
                local game = Helpers.newGame()
                game.progress.maxUnlocked = game.levels:count()
                assert(Helpers.startCampaign(game, game.levels:count()))
                game.lives = 1
                Helpers.keepNormalBricks(game, 1)
                game.remaining = 1
                setBallCount(game, 2)
                Helpers.aimAtFinalBossHit(game, balls(game)[winningIndex])
                falling(balls(game)[3 - winningIndex])
                pickup(game)
                game:update(0.01)
                check(game.state == "campaign_complete" and game.lives == 2, "Victoria antes de descontar vidas")
                check(#balls(game) <= 2 and #powers(game) == 1, "Sin multiplicar tras victoria")
            end
        end)

        test("Probabilidad 15%, origen en el bloque, caida con dt y limpieza fuera de pantalla", function()
            local game = Helpers.newGame()
            local brick = bricks(game)[1]
            randomValue = 0.149999
            local power = trySpawn(game, brick)
            check(power and power.powerUp.name == "MULTIBALL x3", "Valor menor a 0.15 genera poder")
            check(near(power.position.x + power.collider.w / 2, brick.position.x + brick.collider.w / 2)
                  and near(power.position.y + power.collider.h / 2, brick.position.y + brick.collider.h / 2), "Poder centrado en el bloque")
            randomValue = 0.15
            check(trySpawn(game, brick) == nil, "Valor desde 0.15 no genera poder")
            local x, y = power.position.x, power.position.y
            game:update(0.02)
            check(power.position.x == x and near(power.position.y, y + Config.POWERUP_FALL_SPEED * 0.02), "Caida vertical con dt")
            Powerups.spawn(game.world, Config, Powerups.MULTIBALL, 0, Config.HEIGHT + 30)
            power.position.y = Config.HEIGHT
            game:update(0)
            check(#powers(game) == 0 and #balls(game) == 1, "Eliminar todos los poderes perdidos")
        end)

        test("Dos poderes recogidos en el mismo frame: 1 -> 3 -> 9", function()
            local game = Helpers.newGame()
            pickup(game)
            pickup(game)
            game:update(0)
            check(#balls(game) == 9 and #powers(game) == 0, "Ambos poderes se recogen una sola vez")
        end)

        test("Dispersion valida con ejes casi detenidos y pelota sin velocidad", function()
            local angle = math.rad(25)
            local vectors = {{0, 0}, {0.000000000001, 0}, {195, 0}, {0, -280},
                             {300 * math.cos(angle), 300 * math.sin(angle)}}
            for _, vector in ipairs(vectors) do
                local game = Helpers.newGame()
                local ball = balls(game)[1]
                local initialSpeed = speed(ball)
                ball.velocity.vx, ball.velocity.vy = vector[1], vector[2]
                for _, direction in ipairs({-1, 1}) do
                    local clone = Helpers.entity(game, Ball.cloneRotated(game.world, ball.id, direction * angle, Config))
                    check(clone.velocity.vx == clone.velocity.vx and clone.velocity.vy == clone.velocity.vy and math.abs(clone.velocity.vx) > 0 and math.abs(clone.velocity.vy) > 0,
                          "Velocidad finita y activa en ambos ejes")
                    check(near(speed(clone), speed(ball) < 0.000001 and initialSpeed or speed(ball)), "Rapidez conservada o restaurada")
                end
            end
        end)

        test("Limitar rapidez conserva direccion, ejes y velocidades inferiores al maximo", function()
            check(Config.BALL_MAX_SPEED == 550 and Config.MAX_BALLS == 90, "Limites predeterminados")
            for _, vector in ipairs({{600, 800}, {-600, 800}, {600, -800}, {-600, -800},
                                     {1000, 0}, {0, -1000}, {330, 440}, {100, -200}, {0, 0}}) do
                local velocity = {vx = vector[1], vy = vector[2]}
                local before = math.sqrt(vector[1] ^ 2 + vector[2] ^ 2)
                Ball.limitSpeed(velocity, Config)
                local after = math.sqrt(velocity.vx ^ 2 + velocity.vy ^ 2)
                check(near(after, math.min(before, Config.BALL_MAX_SPEED)), "Rapidez total, no limite por eje")
                if before > 0 then
                    check(near(velocity.vx / after, vector[1] / before)
                        and near(velocity.vy / after, vector[2] / before), "Misma direccion")
                end
                if before <= Config.BALL_MAX_SPEED then
                    check(velocity.vx == vector[1] and velocity.vy == vector[2], "Sin modificar velocidades permitidas")
                end
            end
        end)

        test("Velocidades nulas, invalidas o extremas no provocan divisiones por cero ni NaN", function()
            for _, vector in ipairs({{0 / 0, 10}, {10, math.huge}, {-math.huge, 10}, {"invalid", 1}}) do
                local velocity = {vx = vector[1], vy = vector[2]}
                check(Ball.limitSpeed(velocity, Config) == 0 and velocity.vx == 0 and velocity.vy == 0)
            end
            local extreme = {vx = 1e308, vy = -1e308}
            Ball.limitSpeed(extreme, Config)
            check(near(extreme.vx, Config.BALL_MAX_SPEED / math.sqrt(2)) and near(extreme.vy, -extreme.vx))
            local game = Helpers.newGame()
            local ball = balls(game)[1]
            ball.velocity.vx, ball.velocity.vy = 0 / 0, math.huge
            game:update(0.01)
            check(ball.position.x == ball.position.x and ball.position.y == ball.position.y, "No contaminar Position")
            for _, maximum in ipairs({0, -1, math.huge, 0 / 0}) do
                local config = setmetatable({BALL_MAX_SPEED = maximum}, {__index = Config})
                local id = Ball.cloneRotated(game.world, ball.id, math.rad(25), config)
                local clone = Helpers.entity(game, id)
                check(clone.velocity.vx == 0 and clone.velocity.vy == 0, "Limite invalido: detener sin dividir")
            end
        end)

        test("Rebotes en paredes aceleran progresivamente hasta el limite y luego mantienen rapidez", function()
            for _, side in ipairs({"left", "right", "top"}) do
                local game = Helpers.newGame()
                local ball = balls(game)[1]
                for _ = 1, 40 do
                    ball.position.x, ball.position.y = 400, 400
                    if side == "left" then ball.position.x, ball.velocity.vx = 0, -math.abs(ball.velocity.vx)
                    elseif side == "right" then
                        ball.position.x = Config.WIDTH - ball.collider.w
                        ball.velocity.vx = math.abs(ball.velocity.vx)
                    else ball.position.y, ball.velocity.vy = 0, -math.abs(ball.velocity.vy) end
                    local expected = math.min(speed(ball) * Config.WALL_SPEED_MULTIPLIER, Config.BALL_MAX_SPEED)
                    game:update(0)
                    check(near(speed(ball), expected), "Mantener aumento 1.08 antes del limite")
                    check(side == "top" and ball.velocity.vy > 0 or side == "left" and ball.velocity.vx > 0
                        or side == "right" and ball.velocity.vx < 0, "Rebote conserva el sentido correcto")
                end
                check(near(speed(ball), Config.BALL_MAX_SPEED), "La rapidez se estabiliza")
            end
        end)

        test("Paddle mantiene sus 41 direcciones de impacto al alcanzar velocidad maxima", function()
            local game = Helpers.newGame()
            local ball, player = balls(game)[1], paddle(game)
            for step = -20, 20 do
                local impact = step / 20
                ball.position.x = player.position.x + player.collider.w / 2
                    + impact * player.collider.w / 2 - ball.collider.w / 2
                ball.position.y = player.position.y - ball.collider.h + 1
                ball.velocity.vx, ball.velocity.vy = 330, 440
                game:update(0)
                check(near(speed(ball), Config.BALL_MAX_SPEED))
                check(near(ball.velocity.vx, Config.BALL_MAX_SPEED * math.sin(impact * math.rad(60)))
                    and near(ball.velocity.vy, -Config.BALL_MAX_SPEED * math.cos(impact * math.rad(60))))
                check(ball.position.y + ball.collider.h == player.position.y, "Separar del paddle")
            end
        end)

        test("Nivel con velocidad inicial excesiva: limitar spawn, reposicion y clones detenidos", function()
            local game = Helpers.newGame()
            game.level.initialVelocity.vx, game.level.initialVelocity.vy = 600, -800
            game:resetRound()
            local ball = balls(game)[1]
            check(near(ball.velocity.vx, 330) and near(ball.velocity.vy, -440))
            ball.velocity.vx, ball.velocity.vy = 0, 0
            game:activatePowerup(Powerups.MULTIBALL)
            for index = 2, 3 do check(near(speed(balls(game)[index]), Config.BALL_MAX_SPEED)) end
            check(game.level.initialVelocity.vx == 600, "No modificar los datos del nivel")
            for _, active in ipairs(balls(game)) do falling(active) end
            game:update(0.01)
            check(game.lives == 2 and near(speed(balls(game)[1]), Config.BALL_MAX_SPEED))
        end)

        test("Velocidad modificada por otro sistema se limita antes del movimiento con dt", function()
            for _, dt in ipairs({0, 0.01, 0.05}) do
                local game = Helpers.newGame()
                local ball = balls(game)[1]
                ball.position.x, ball.position.y = 400, 400
                ball.velocity.vx, ball.velocity.vy = 600, 800
                game:update(dt)
                check(near(ball.position.x, 400 + 330 * dt) and near(ball.position.y, 400 + 440 * dt))
                check(near(speed(ball), Config.BALL_MAX_SPEED), "Limitar antes de integrar, no al frame siguiente")
            end
        end)

        test("MULTIBALL encadenado 1 -> 3 -> 9 -> 27 -> 81 -> 90 sin superar rapidez maxima", function()
            local game = Helpers.newGame()
            balls(game)[1].velocity.vx, balls(game)[1].velocity.vy = 600, -800
            for _, expected in ipairs({3, 9, 27, 81, 90, 90}) do
                local originals = balls(game)
                game:activatePowerup(Powerups.MULTIBALL)
                local active = balls(game)
                check(#active == expected)
                for index, original in ipairs(originals) do check(active[index].id == original.id) end
                for _, ball in ipairs(active) do
                    check(near(speed(ball), Config.BALL_MAX_SPEED), "Limite para originales y copias")
                end
                check(active[1].velocity.vx ~= active[2].velocity.vx
                    and active[2].velocity.vx ~= active[3].velocity.vx, "Mantener dispersion")
            end
            local lastId = game.world.nextId
            for _, ball in ipairs(balls(game)) do ball.velocity.vx, ball.velocity.vy = 600, -800 end
            game:activatePowerup(Powerups.MULTIBALL)
            check(game.world.nextId == lastId and game.world:count("Ball") == Config.MAX_BALLS)
            for _, ball in ipairs(balls(game)) do check(near(speed(ball), Config.BALL_MAX_SPEED)) end
        end)

        test("Ambos limites se obtienen de config y no de valores fijos en los sistemas", function()
            local game = Helpers.newGame()
            game.config = setmetatable({BALL_MAX_SPEED = 250, MAX_BALLS = 7}, {__index = Config})
            game:resetRound()
            for _ = 1, 4 do game:activatePowerup(Powerups.MULTIBALL) end
            check(game.world:count("Ball") == 7)
            for _, ball in ipairs(balls(game)) do check(near(speed(ball), 250)) end
        end)

        test("Caen 89 de 90: sin perder vida; cae la ultima: limpiar ECS y descontar una sola", function()
            local game = Helpers.newGame()
            setBallCount(game, Config.MAX_BALLS)
            local active = balls(game)
            for index = 2, #active do falling(active[index]) end
            game:update(0.01)
            check(game.lives == 3 and #balls(game) == 1 and balls(game)[1].id == active[1].id)
            for index = 2, #active do
                check(not game.world:has(active[index].id))
                for _, storage in pairs(game.world.components) do check(storage[active[index].id] == nil) end
            end
            falling(active[1])
            game:update(0.01)
            check(game.lives == 2 and #balls(game) == 1 and not game.world:has(active[1].id))
            game:update(0)
            check(game.lives == 2)
        end)

        test("Noventa contactos contra un bloque: una destruccion y un sorteo", function()
            local game = Helpers.newGame()
            keepBricks(game, {1, 4})
            setBallCount(game, Config.MAX_BALLS)
            local target = bricks(game)[1]
            for _, ball in ipairs(balls(game)) do aimAt(ball, target) end
            randomValue = 0
            game:update(0.01)
            check(game.remaining == 1 and #bricks(game) == 1 and not game.world:has(target.id))
            check(randomCalls == 1 and #powers(game) == 1 and #balls(game) == Config.MAX_BALLS)
        end)

        test("Noventa pelotas destruyen los dos ultimos bloques: una sola transicion", function()
            local game = Helpers.newGame()
            keepBricks(game, {1, 4})
            setBallCount(game, Config.MAX_BALLS)
            local targets = bricks(game)
            for index, ball in ipairs(balls(game)) do aimAt(ball, targets[index % 2 + 1]) end
            game:update(0.01)
            check(game.remaining == 0 and #bricks(game) == 0 and game.state == "level_complete")
            check(game.lives == 4 and game.progress.maxUnlocked == 2 and randomCalls == 2)
            check(not game:completeLevel() and game.lives == 4)
        end)

        test("Colisiones individuales, movimiento con dt y aceleracion del paddle", function()
            local game = Helpers.newGame()
            setBallCount(game, 3)
            local left, right, top = balls(game)[1], balls(game)[2], balls(game)[3]
            left.position.x, left.position.y, left.velocity.vx = -1, 400, -195
            right.position.x, right.position.y, right.velocity.vx = Config.WIDTH, 400, 195
            top.position.x, top.position.y, top.velocity.vy = 10, -1, -280
            game:update(0)
            check(left.position.x == 0 and near(left.velocity.vx, 195 * Config.WALL_SPEED_MULTIPLIER), "Pared izquierda")
            check(right.position.x == Config.WIDTH - right.collider.w and near(right.velocity.vx, -195 * Config.WALL_SPEED_MULTIPLIER), "Pared derecha")
            check(top.position.y == 0 and near(top.velocity.vy, 280 * Config.WALL_SPEED_MULTIPLIER), "Pared superior")
            game:resetRound()
            local ball = balls(game)[1]
            local x, y, px = ball.position.x, ball.position.y, paddle(game).position.x
            heldKey = "right"
            game:update(0.01)
            check(near(ball.position.x, x + ball.velocity.vx * 0.01) and near(ball.position.y, y + ball.velocity.vy * 0.01), "Pelota usa dt")
            check(near(paddle(game).position.x, px + Config.PADDLE_SPEED * 0.01), "Paddle usa dt")
            heldKey = nil
            ball.position.x = paddle(game).position.x + (paddle(game).collider.w - ball.collider.w) / 2 - 195 * 0.01
            ball.position.y = paddle(game).position.y - ball.collider.h - 1
            ball.velocity.vx, ball.velocity.vy = 195, 280
            local expectedSpeed = speed(ball) * Config.PADDLE_SPEED_MULTIPLIER
            game:update(0.01)
            check(near(ball.velocity.vx, 0) and near(ball.velocity.vy, -expectedSpeed),
                  "Impacto central tras movimiento con dt: salida vertical y rapidez aumentada")
        end)
    end, debug.traceback)

    love.math.random, love.keyboard.isDown, love.event.quit, print = realRandom, realKeyboard, realQuit, realPrint
    Game.new = originalNew
    love.load, love.update, love.draw, love.keypressed = savedCallbacks.load, savedCallbacks.update, savedCallbacks.draw, savedCallbacks.keypressed
    love.quit = savedCallbacks.quit
    love.focus = savedCallbacks.focus
    if not ok then error(err, 0) end
    return passed
end

return {run = run}

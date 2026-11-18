local Config = require("src.config")
local Components = require("src.ecs.components")
local Ball = require("src.ball")
local Bricks = require("src.bricks")
local Powerups = require("src.powerups")
local Helpers = require("tests.helpers")
local Rules = require("src.level_rules")
local Effects = require("src.ecs.systems.power_effect_system")
local Projectiles = require("src.ecs.systems.projectile_system")
local Portals = require("src.ecs.systems.portal_system")
local Collisions = require("src.ecs.systems.collision_system")
local Explosion = require("src.ecs.systems.explosion_system")
local Damage = require("src.ecs.systems.damage_system")
local Collision = require("src.collision")

local function near(a, b) return math.abs(a - b) < 0.00001 end
local function speed(ball) return math.sqrt(ball.velocity.vx^2 + ball.velocity.vy^2) end
local function addBrick(game, kind, x, y, w, h, definition)
    return Bricks.spawn(game.world, Config, game.level, {key = "fixture", x = x, y = y, w = w or 60, h = h or 25,
        color = {1, 0.3, 0.3}, definition = definition or game.level.brickTypes[kind],
        row = math.floor((y - 200) / 30) + 1, column = math.floor((x - 100) / 70) + 1})
end
local function empty()
    local game = Helpers.newGame()
    for _, id in ipairs(game.world:query("Brick")) do game.world:destroy(id) end
    addBrick(game, "N", 900, 94, 30, 20) -- Evitar victorias accidentales de la fixture.
    game.remaining = 1
    return game
end
local function active(game)
    for _, kind in ipairs({"giant_paddle", "fireball", "magnet", "shield", "laser"}) do game:activatePowerup(kind) end
end
local function clean(game)
    local timers, power = Effects.get(game)
    for _, value in pairs(timers) do assert(value == 0) end
    assert(power.ammo == 0 and not power.heldBall and not power.shieldId)
    assert(Helpers.paddle(game).collider.w == Config.PADDLE_W)
    for _, component in ipairs({"Projectile", "Shield", "PowerUp"}) do assert(game.world:count(component) == 0) end
    for _, id in ipairs(game.world:query("Ball")) do assert(not game.world:get(id, "Ball").fire) end
end
local function capture(game, ball, offset)
    local paddle = Helpers.paddle(game)
    ball.position.x = paddle.position.x + paddle.collider.w / 2 + (offset or 0) - ball.collider.w / 2
    ball.position.y = paddle.position.y - ball.collider.h + 1
    ball.velocity.vx, ball.velocity.vy = 100, 350
    Collisions.update(game, 0)
    assert(game.world:get(ball.id, "Ball").held)
end
local function pair(game, rotation, radius)
    Portals.create(game.world, {portals = {{id = "test", cooldown = 0.4, rotationDegrees = rotation or 90,
        entry = {x = 200, y = 350, radius = radius or 22}, exit = {x = 700, y = 350, radius = radius or 22}}}})
    return game.world:query("Portal")
end
local function place(ball, x, y, vx, vy)
    ball.position.x, ball.position.y = x - ball.collider.w / 2, y - ball.collider.h / 2
    ball.velocity.vx, ball.velocity.vy = vx or 200, vy or -300
end

local function run()
    local random, keyboard, quit, mode = love.math.random, love.keyboard.isDown, love.event.quit, Config.ECS_ASSIGNMENT_MODE
    local passed, roll, calls, held, quits = 0, 0.99, 0, nil, 0
    love.math.random = function() calls = calls + 1; return roll end
    love.keyboard.isDown = function(...)
        for n = 1, select("#", ...) do if select(n, ...) == held then return true end end
        return false
    end
    love.event.quit = function() quits = quits + 1 end
    Config.ECS_ASSIGNMENT_MODE = false
    local function test(name, fn)
        roll, calls, held, quits = 0.99, 0, nil, 0
        fn()
        passed = passed + 1
        print("OK FASE3 " .. passed .. ": " .. name)
    end
    local ok, err = xpcall(function()
        test("Los siete poderes se desbloquean por nivel y tienen simbolo, nombre y color", function()
            local game = Helpers.newGame()
            local first = {multiball = 1, giant_paddle = 1, shield = 2, fireball = 3, laser = 4, magnet = 5, extra_life = 6}
            for index = 1, 10 do
                local enabled = {}
                for _, kind in ipairs(game.levels:get(index).activePowerups) do enabled[kind] = true end
                for kind, level in pairs(first) do assert(not not enabled[kind] == (index >= level)) end
            end
            for kind, definition in pairs(Config.POWERUP_TYPES) do
                local id = Powerups.spawn(game.world, Config, kind, 100, 400)
                local visual = game.world:get(id, "Renderable")
                assert(visual.label == definition.label and visual.color[1] == definition.color[1])
                assert(game.world:get(id, "PowerUp").name == definition.name)
                Powerups.update(game, 0.1)
                assert(near(game.world:get(id, "Position").y, 400 - Config.POWERUP_H / 2 + Config.POWERUP_FALL_SPEED * 0.1))
                game.world:destroy(id)
            end
        end)

        test("Un solo sorteo: 15 por ciento total, pesos de todos los tipos y vida extra infrecuente", function()
            local game, counts, total = Helpers.newGame(), {}, 0
            local available = game.levels:get(10).activePowerups
            for n = 0, 9999 do
                roll = (n + 0.5) / 10000
                local id = Powerups.trySpawn(game.world, Config, {x = 100, y = 200}, {w = 50, h = 25}, 0.15, available)
                if id then
                    local kind = game.world:get(id, "PowerUp").kind
                    counts[kind], total = (counts[kind] or 0) + 1, total + 1
                    game.world:destroy(id)
                end
            end
            assert(total == 1500 and calls == 10000)
            local weight = 0
            for _, kind in ipairs(available) do weight = weight + Config.POWERUP_TYPES[kind].weight end
            for _, kind in ipairs(available) do assert(math.abs(counts[kind] - 1500 * Config.POWERUP_TYPES[kind].weight / weight) <= 1) end
            assert(counts.extra_life < counts.laser and counts.laser < counts.multiball)
            roll = 0
            assert(not Powerups.trySpawn(game.world, Config, {x = 0, y = 0}, {w = 10, h = 10}, 0, available))
            assert(not Powerups.trySpawn(game.world, Config, {x = 0, y = 0}, {w = 10, h = 10}, 1, {}))
        end)

        test("Objetos limitados y fuego garantizado renovable incluso con la pantalla llena", function()
            local game = Helpers.newGame()
            game.progress.maxUnlocked = 10; Helpers.startCampaign(game, 7)
            for _ = 1, Config.MAX_FALLING_POWERUPS + 5 do Powerups.spawn(game.world, Config, "multiball", 100, 400) end
            assert(game.world:count("PowerUp") == Config.MAX_FALLING_POWERUPS)
            Powerups.guaranteed(game, 11.9)
            for _, id in ipairs(game.world:query("PowerUp")) do assert(game.world:get(id, "PowerUp").kind == "multiball") end
            Powerups.guaranteed(game, 0.1)
            local newest = Helpers.powers(game)[Config.MAX_FALLING_POWERUPS]
            assert(newest.powerUp.kind == "fireball" and calls == 0)
            assert(game.world:count("PowerUp") == Config.MAX_FALLING_POWERUPS)
            for _ = 1, 20 do Powerups.update(game, 0.05) end
            assert(Effects.get(game).fireball > 0, "Se puede recoger sin depender de otro bloque")
        end)

        test("Validacion de poderes, garantia, pares, cooldown, rotacion y salidas", function()
            local manager = Helpers.newGame().levels
            for _, mutate in ipairs({
                function(l) l.powerups = {"unknown"} end,
                function(l) l.powerups = {"multiball", "multiball"} end,
                function(l) l.difficulty.guaranteedPowerup.everySeconds = 0 end,
                function(l) l.portals[1].cooldown = 0 end,
                function(l) l.portals[1].rotationDegrees = 0/0 end,
                function(l) l.portals[1].exit.x = -100 end,
                function(l) l.portals[1].exit = l.portals[1].entry end,
                function(l) l.portals[2] = l.portals[1] end,
            }) do
                local level = manager:get(7); mutate(level)
                assert(not pcall(Rules.validate, level, Config))
            end
            local level = manager:get(7)
            level.bricks = {{key = "armor", x = 100, y = 100, w = 50, h = 25,
                definition = {kind = "armored", vulnerableTo = {"fireball"}}}}
            assert(pcall(Rules.validate, level, Config))
            level.difficulty.guaranteedPowerup = nil
            assert(not pcall(Rules.validate, level, Config), "Una probabilidad aleatoria no garantiza completar")
        end)

        test("Gigante conserva centro, limita bordes, renueva 15 segundos y restaura ancho base", function()
            for _, edge in ipairs({0, 424, Config.WIDTH - Config.PADDLE_W}) do
                local game, expected = Helpers.newGame(), Config.PADDLE_W * 1.5
                local paddle = Helpers.paddle(game); paddle.position.x = edge
                game:activatePowerup("giant_paddle")
                assert(paddle.collider.w == expected and paddle.position.x >= 0 and paddle.position.x + expected <= Config.WIDTH)
                Effects.update(game, 5); game:activatePowerup("giant_paddle")
                assert(paddle.collider.w == expected and Effects.get(game).giant_paddle == 15)
                Effects.update(game, 15)
                assert(paddle.collider.w == Config.PADDLE_W and paddle.position.x >= 0)
            end
        end)

        test("Fuego alcanza pelotas activas, nuevas y 90 copias; renueva y expira sin cambiar rapidez", function()
            local game = Helpers.newGame()
            game:activatePowerup("fireball")
            Ball.spawn(game.world, Config, game.level)
            for _ = 1, 5 do game:activatePowerup("multiball") end
            assert(game.world:count("Ball") == Config.MAX_BALLS)
            local before = {}
            for _, ball in ipairs(Helpers.balls(game)) do
                assert(game.world:get(ball.id, "Ball").fire and speed(ball) <= Config.BALL_MAX_SPEED + 0.00001)
                before[ball.id] = speed(ball)
            end
            Effects.update(game, 9); game:activatePowerup("fireball")
            assert(Effects.get(game).fireball == 10)
            Effects.update(game, 10)
            for _, ball in ipairs(Helpers.balls(game)) do
                assert(not game.world:get(ball.id, "Ball").fire and near(speed(ball), before[ball.id]))
                assert(game.world:get(ball.id, "Renderable").color[1] == 0.98)
            end
        end)

        test("Fuego barre varios bloques finos en un frame sin rebotar ni duplicar destrucciones", function()
            local game = empty()
            local first = addBrick(game, "N", 100, 200, 60, 2)
            local second = addBrick(game, "N", 100, 210, 60, 2)
            local ball = Helpers.balls(game)[1]
            place(ball, 125, 190, 0, 550)
            game:activatePowerup("fireball"); roll = 0
            game:update(0.05)
            assert(not game.world:has(first) and not game.world:has(second) and calls == 2)
            assert(ball.velocity.vy == 550 and near(ball.position.y, 190 - 6.5 + 27.5))
        end)

        test("Fuego daña resistente una vez por contacto; separar permite dañar nuevamente", function()
            local game = empty()
            local id = addBrick(game, "R", 100, 200)
            local ball = Helpers.balls(game)[1]
            place(ball, 125, 205, 0, 0); game:activatePowerup("fireball")
            for _ = 1, 8 do game:update(0) end
            assert(game.world:get(id, "Health").current == 2)
            place(ball, 125, 300, 0, 0); game:update(0)
            place(ball, 125, 205, 0, 0); game:update(0)
            assert(game.world:get(id, "Health").current == 1)
        end)

        test("Fuego destruye blindados vulnerables y rebota contra los inmunes", function()
            for _, allowed in ipairs({true, false}) do
                local game = empty()
                local id = addBrick(game, "A", 100, 200, 60, 25,
                    {kind = "armored", vulnerableTo = {allowed and "fireball" or "laser"}})
                local ball = Helpers.balls(game)[1]
                place(ball, 125, 190, 0, 300); game:activatePowerup("fireball"); game:update(0.05)
                assert(game.world:has(id) == not allowed)
                assert((ball.velocity.vy > 0) == allowed)
            end
        end)

        test("Fuego respeta fantasmas intangibles y obstaculos que bloquean el resto del barrido", function()
            local game = empty()
            local ghost = addBrick(game, "G", 100, 200)
            game.world:get(ghost, "Ghost").solid = false
            local ball = Helpers.balls(game)[1]
            place(ball, 125, 190, 0, 550); game:activatePowerup("fireball")
            Collisions.update(game, 0.05)
            assert(game.world:has(ghost) and ball.velocity.vy == 550)
            game.world:destroy(ghost)
            local behind = addBrick(game, "N", 100, 215, 60, 2)
            game.world:create({Position = Components.position(100, 200), Collider = Components.collider(60, 2), MovingObstacle = {}})
            place(ball, 125, 190, 0, 550); Collisions.update(game, 0.05)
            assert(game.world:has(behind) and ball.velocity.vy < 0)
        end)

        test("90 pelotas de fuego y explosiones comparten destruccion y sorteo unicos", function()
            local game = empty()
            local explosive = addBrick(game, "E", 100, 200)
            local armor = addBrick(game, "A", 170, 200)
            Helpers.setBallCount(game, 90); game:activatePowerup("fireball"); roll = 0
            for _, ball in ipairs(Helpers.balls(game)) do place(ball, 125, 205, 0, 0) end
            game:update(0)
            assert(not game.world:has(explosive) and not game.world:has(armor) and calls == 2)
            assert(game.world:count("PowerUp") == 2 and not Explosion.pending(game))
        end)

        test("Laser: Espacio dispara dos canones, consume una de 20 cargas y respeta intervalo/limite", function()
            local game = Helpers.newGame()
            game:activatePowerup("laser")
            local _, power = Effects.get(game)
            for n = 1, 20 do
                game:keypressed("space")
                assert(power.ammo == 20 - n and game.world:count("Projectile") == n * 2)
                game:keypressed("space")
                assert(power.ammo == 20 - n)
                Effects.update(game, Config.LASER_INTERVAL)
            end
            game:keypressed("space")
            assert(game.world:count("Projectile") == Config.MAX_PLAYER_PROJECTILES)
            game:activatePowerup("laser"); game:keypressed("space")
            assert(power.ammo == 20, "Capacidad llena no consume municion")
            game.world:destroy(game.world:query("Projectile")[1]); game:keypressed("space")
            assert(power.ammo == 20, "No crear medio par")
        end)

        test("Proyectiles usan dt y se eliminan fuera de pantalla", function()
            local game = empty(); game:activatePowerup("laser"); game:keypressed("space")
            local ids = game.world:query("Projectile")
            local y = game.world:get(ids[1], "Position").y
            Projectiles.update(game, 0.1)
            assert(near(game.world:get(ids[1], "Position").y, y - Config.LASER_SPEED * 0.1))
            Projectiles.update(game, 2)
            assert(game.world:count("Projectile") == 0)
        end)

        test("Laser barre bloque fino y no duplica sorteo con dos impactos simultaneos", function()
            local game = empty()
            local paddle = Helpers.paddle(game)
            local id = addBrick(game, "N", paddle.position.x, 550, paddle.collider.w, 1)
            game:activatePowerup("laser"); game:keypressed("space"); roll = 0
            Projectiles.update(game, 0.05)
            assert(not game.world:has(id) and calls == 1 and game.world:count("PowerUp") == 1)
            assert(game.world:count("Projectile") == 1, "El otro disparo continua tras un bloque ya destruido")
        end)

        test("Laser daña resistentes/blindados, atraviesa fantasmas intangibles y se detiene en obstaculos", function()
            for _, kind in ipairs({"R", "A", "G", "obstacle"}) do
                local game = empty()
                local p = Helpers.paddle(game)
                local id
                if kind == "obstacle" then
                    id = game.world:create({Position = Components.position(p.position.x, 550),
                        Collider = Components.collider(p.collider.w, 1), MovingObstacle = {}})
                else
                    id = addBrick(game, kind, p.position.x, 550, p.collider.w, 1)
                    if kind == "G" then game.world:get(id, "Ghost").solid = false end
                end
                game:activatePowerup("laser"); game:keypressed("space"); Projectiles.update(game, 0.05)
                if kind == "R" then assert(game.world:get(id, "Health").current == 1)
                elseif kind == "A" then assert(not game.world:has(id))
                elseif kind == "G" then assert(game.world:has(id) and game.world:count("Projectile") == 2)
                else assert(game.world:has(id) and game.world:count("Projectile") == 0) end
            end
        end)

        test("Interfaz Health/Damageable admite laser para futuros jefes sin activar comportamiento de jefe", function()
            local game = empty()
            local p = Helpers.paddle(game)
            local id = game.world:create({Position = Components.position(p.position.x, 550),
                Collider = Components.collider(p.collider.w, 10), Health = Components.health(20),
                Damageable = {sources = {laser = true}, enabled = true}})
            game:activatePowerup("laser"); game:keypressed("space"); Projectiles.update(game, 0.05)
            assert(game.world:get(id, "Health").current == 18 and game.world:count("Boss") == 0)
            game.world:get(id, "Damageable").enabled = false
            assert(not Damage.hit(game, id, 1, "laser"))
        end)

        test("Escudo salva tres pelotas simultaneas, luego desaparece sin descontar vida", function()
            local game = empty()
            Helpers.setBallCount(game, 4); game:activatePowerup("shield")
            for _, ball in ipairs(Helpers.balls(game)) do place(ball, 50, 600, 0, 550) end
            game:update(0.05)
            game:update(0.05) -- La cuarta termina de cruzar el espacio entre escudo y fondo.
            assert(game.world:count("Ball") == 3 and game.lives == 3 and game.world:count("Shield") == 0)
            for _, ball in ipairs(Helpers.balls(game)) do assert(ball.velocity.vy == -550) end
            assert(Effects.get(game).shield == 0)
        end)

        test("Escudo y gigante coexisten; renovar escudo repone tres impactos y veinte segundos", function()
            local game = empty(); game:activatePowerup("giant_paddle"); game:activatePowerup("shield")
            local _, power = Effects.get(game)
            local old = power.shieldId
            local ball = Helpers.balls(game)[1]
            place(ball, 50, 600, 0, 400); game:update(0.05)
            assert(game.world:get(old, "Shield").hits == 2 and game.world:get(old, "Renderable").alpha < 1)
            game:activatePowerup("shield")
            assert(not game.world:has(old) and game.world:get(power.shieldId, "Shield").hits == 3)
            assert(Effects.get(game).shield == 20 and Helpers.paddle(game).collider.w == 168)
            Effects.update(game, 20)
            assert(game.world:count("Shield") == 0 and Helpers.paddle(game).collider.w == 112)
        end)

        test("Iman captura una sola pelota, sigue al paddle y Espacio lanza antes que disparar", function()
            local game = empty(); Helpers.setBallCount(game, 2)
            game:activatePowerup("magnet"); game:activatePowerup("laser")
            local first, second = unpack(Helpers.balls(game))
            capture(game, first, 20)
            local vx, vy = first.velocity.vx, first.velocity.vy
            local paddle = Helpers.paddle(game)
            place(second, paddle.position.x + paddle.collider.w / 2, paddle.position.y - 5, 0, 300)
            Collisions.update(game, 0)
            assert(not game.world:get(second.id, "Ball").held and second.velocity.vy < 0)
            held = "right"; local x = first.position.x; game:update(0.05); held = nil
            assert(near(first.position.x - x, Config.PADDLE_SPEED * 0.05) and first.position.y == paddle.position.y - first.collider.h)
            game:keypressed("space")
            local _, power = Effects.get(game)
            assert(not power.heldBall and game.world:count("Projectile") == 0 and power.ammo == 20)
            assert(near(first.velocity.vx, vx) and near(first.velocity.vy, vy) and vy < 0)
            game:keypressed("space"); assert(power.ammo == 19 and game.world:count("Projectile") == 2)
        end)

        test("Iman retenido cuenta como pelota; MULTIBALL solo conserva una captura y fuego en todas", function()
            local game = empty(); active(game)
            local ball = Helpers.balls(game)[1]; capture(game, ball, -20)
            game:activatePowerup("multiball")
            local captured = 0
            for _, id in ipairs(game.world:query("Ball")) do
                local data = game.world:get(id, "Ball")
                assert(data.fire)
                if data.held then captured = captured + 1 else game.world:destroy(id) end
            end
            game:update(0.05)
            assert(captured == 1 and game.lives == 3 and game.world:count("Ball") == 1)
            Effects.update(game, 10); game:activatePowerup("magnet")
            assert(Effects.get(game).magnet == 15)
            Effects.update(game, 15)
            assert(not game.world:get(ball.id, "Ball").held and ball.velocity.vy < 0)
            local y = ball.position.y; game:update(0.05); assert(ball.position.y < y)
        end)

        test("Vida extra nunca supera cinco, incluso con recogidas simultaneas", function()
            local game = Helpers.newGame()
            local paddle = Helpers.paddle(game)
            for _ = 1, 8 do Powerups.spawn(game.world, Config, "extra_life", paddle.position.x + 30, paddle.position.y + 3) end
            game:update(0)
            assert(game.lives == 5 and game.world:count("PowerUp") == 0)
            game:activatePowerup("extra_life"); assert(game.lives == 5)
        end)

        test("Recogidas simultaneas de fuego y MULTIBALL funcionan en ambos ordenes", function()
            for _, kinds in ipairs({{"fireball", "multiball"}, {"multiball", "fireball"}}) do
                local game = Helpers.newGame(); local p = Helpers.paddle(game)
                for _, kind in ipairs(kinds) do Powerups.spawn(game.world, Config, kind, p.position.x + 30, p.position.y) end
                game:update(0)
                assert(game.world:count("Ball") == 3)
                for _, id in ipairs(game.world:query("Ball")) do assert(game.world:get(id, "Ball").fire) end
            end
        end)

        test("Perder ultima pelota conserva poderes y objetos; GAME OVER si los limpia", function()
            for _, lives in ipairs({3, 1}) do
                local game = Helpers.newGame(); game.lives = lives; active(game); game:keypressed("space")
                Powerups.spawn(game.world, Config, "magnet", 100, 400)
                local remaining = game.remaining
                for _, id in ipairs(game.world:query("Ball")) do game.world:destroy(id) end
                game:update(0)
                assert(game.lives == lives - 1 and game.remaining == remaining)
                if lives == 1 then clean(game)
                else
                    local timers, power = Effects.get(game)
                    assert(timers.giant_paddle == Config.GIANT_PADDLE_SECONDS and timers.fireball == Config.FIREBALL_SECONDS)
                    assert(timers.magnet == Config.MAGNET_SECONDS and timers.shield == Config.SHIELD_SECONDS)
                    assert(power.ammo == Config.LASER_AMMO - 1 and power.cooldown == Config.LASER_INTERVAL)
                    assert(game.world:count("Projectile") == 2 and game.world:count("PowerUp") == 1)
                    assert(game.world:count("Shield") == 1 and game.world:get(Helpers.balls(game)[1].id, "Ball").fire)
                end
                assert(game.state == (lives == 1 and "game_over" or "playing"))
            end
        end)

        test("Cambio y reinicio de nivel limpian efectos sin perder progreso o reciclar IDs", function()
            local game = Helpers.newGame(); active(game); game:keypressed("space")
            for _, id in ipairs(game.world:query("Brick")) do Bricks.destroy(game, id) end
            game:update(Config.LEVEL_TRANSITION_SECONDS); Helpers.finishIntro(game)
            clean(game); assert(game.levelIndex == 2 and game.lives == 4)
            active(game); local old = game.world.nextId
            game:restartLevel(); Helpers.finishIntro(game); clean(game)
            for _, id in ipairs(game.world:query()) do assert(id > old) end
            assert(game.progress.maxUnlocked == 2)
        end)

        test("Menu y transicion congelan efectos/proyectiles y no aceptan Espacio ni poderes", function()
            for _, state in ipairs({"menu", "level_complete", "campaign_complete"}) do
                local game = Helpers.newGame(); active(game); game:keypressed("space")
                local timers, power = Effects.get(game)
                local shot = game.world:query("Projectile")[1]; local y = game.world:get(shot, "Position").y
                game.state, game.transitionRemaining = state, 2
                game:update(0.5); game:keypressed("space"); game:activatePowerup("extra_life")
                assert(timers.fireball == 10 and power.ammo == 19 and game.lives == 3)
                assert(game.world:get(shot, "Position").y == y)
            end
        end)

        test("Portales bidireccionales conservan rapidez y aplican rotacion inversa al regresar", function()
            local game = empty(); local ids = pair(game)
            assert(game.world:get(ids[1], "Portal").target == ids[2] and game.world:get(ids[2], "Portal").target == ids[1])
            local ball = Helpers.balls(game)[1]; place(ball, 200, 350, 300, -400)
            Portals.update(game, 0)
            assert(ball.position.x > 600 and near(ball.velocity.vx, 400) and near(ball.velocity.vy, 300) and near(speed(ball), 500))
            local data = game.world:get(ball.id, "Ball")
            data.portalCooldown, data.previousX, data.previousY = 0, nil, nil
            place(ball, 700, 350, 400, 300); Portals.update(game, 0)
            assert(ball.position.x < 300 and near(ball.velocity.vx, 300) and near(ball.velocity.vy, -400))
            assert(game.world:count("PortalPulse") == 4)
        end)

        test("Entrada de portal barrida detecta cruces rapidos sin solapamiento al final", function()
            local game = empty(); pair(game, 0, 2)
            local ball = Helpers.balls(game)[1]
            place(ball, 185, 350, 550, 0); game:update(0.05)
            assert(ball.position.x > 650 and near(speed(ball), 550))
        end)

        test("Cooldown por pelota evita bucles, conserva fuego y nunca mueve una pelota atrapada", function()
            local game = empty(); pair(game, 0); game:activatePowerup("fireball")
            local ball = Helpers.balls(game)[1]; place(ball, 200, 350, 300, -400)
            Portals.update(game, 0)
            local data = game.world:get(ball.id, "Ball")
            place(ball, 700, 350, 300, -400); data.previousX, data.previousY = nil, nil
            Portals.update(game, 0.1)
            assert(ball.position.x > 600 and near(data.portalCooldown, 0.3) and data.fire)
            Portals.update(game, 0.31); assert(ball.position.x < 300)
            game:activatePowerup("magnet"); capture(game, ball)
            local x, y = ball.position.x, ball.position.y
            Portals.update(game, 1); assert(ball.position.x == x and ball.position.y == y)
        end)

        test("Salida totalmente obstruida cancela teletransporte sin mover ni perder la pelota", function()
            local game = empty(); pair(game, 90)
            addBrick(game, "R", 550, 200, 300, 300)
            local ball = Helpers.balls(game)[1]; place(ball, 200, 350, 300, -400)
            local x, y = ball.position.x, ball.position.y
            Portals.update(game, 0)
            assert(ball.position.x == x and ball.position.y == y and ball.velocity.vx == 300 and ball.velocity.vy == -400)
            assert(game.lives == 3 and game.world:count("PortalPulse") == 0)
        end)

        test("Salida busca espacio libre sin incrustar pelota en fantasma u obstaculo", function()
            local game = empty(); pair(game, 0)
            local id = addBrick(game, "G", 720, 320, 40, 80)
            game.world:get(id, "Ghost").solid = false
            local obstacle = game.world:create({Position = Components.position(690, 370), Collider = Components.collider(80, 20), MovingObstacle = {}})
            local ball = Helpers.balls(game)[1]; place(ball, 200, 350, 500, 0)
            Portals.update(game, 0)
            assert(ball.position.x > 600 and ball.velocity.vx == 500)
            for _, solid in ipairs({id, obstacle}) do
                assert(not Collision.overlaps(ball.position, ball.collider, game.world:get(solid, "Position"), game.world:get(solid, "Collider")))
            end
        end)

        test("90 teletransportes independientes mantienen 550 px/s y limitan/limpian efectos visuales", function()
            local game = empty(); pair(game, -90); Helpers.setBallCount(game, 90)
            for _, ball in ipairs(Helpers.balls(game)) do place(ball, 200, 350, 3000, 4000) end
            Portals.update(game, 0)
            for _, ball in ipairs(Helpers.balls(game)) do
                assert(ball.position.x > 600 and near(speed(ball), 550) and ball.velocity.vx > 0 and ball.velocity.vy < 0)
            end
            assert(game.world:count("PortalPulse") == Config.MAX_PORTAL_PULSES and game.world:count("Ball") == 90)
            Portals.updateVisuals(game.world, Config.PORTAL_PULSE_SECONDS)
            assert(game.world:count("PortalPulse") == 0)
        end)

        test("Los portales reales de niveles 7 y 9 tienen salidas utilizables en ambos sentidos", function()
            for _, level in ipairs({7, 9}) do
                for endpoint = 1, 2 do
                    local game = Helpers.newGame(); game.progress.maxUnlocked = 10; Helpers.startCampaign(game, level)
                    local portals = game.world:query("Portal")
                    local p, c = game.world:get(portals[endpoint], "Position"), game.world:get(portals[endpoint], "Collider")
                    local ball = Helpers.balls(game)[1]
                    place(ball, p.x + c.w / 2, p.y + c.h / 2, 200, -300)
                    local x, y = ball.position.x, ball.position.y
                    Portals.update(game, 0)
                    assert(math.abs(ball.position.x - x) + math.abs(ball.position.y - y) > 100)
                    assert(near(speed(ball), math.sqrt(130000)))
                end
            end
        end)

        test("ECS_ASSIGNMENT_MODE conserva cierre prioritario con todos los poderes, laser y portales", function()
            local game = empty(); pair(game); active(game); game:keypressed("space"); Helpers.setBallCount(game, 90)
            local ball = Helpers.balls(game)[90]; place(ball, 6.5, 400, -330, -440)
            Config.ECS_ASSIGNMENT_MODE = true
            local before = game.world:count("Projectile")
            game:update(0); game:keypressed("space"); game:update(0.05)
            assert(quits == 1 and game.quitRequested and game.lives == 3 and ball.velocity.vx == -330)
            assert(game.world:count("Projectile") == before and game.world:count("PortalPulse") == 0)
            Config.ECS_ASSIGNMENT_MODE = false
        end)

        test("Todos los pares de poderes conservan efectos independientes en ambos ordenes", function()
            local kinds = Helpers.newGame().levels:get(10).activePowerups
            for _, first in ipairs(kinds) do
                for _, second in ipairs(kinds) do
                    local game = Helpers.newGame()
                    game:activatePowerup(first); game:activatePowerup(second)
                    local timers, power = Effects.get(game)
                    local selected = {[first] = true, [second] = true}
                    local multiplies = (first == "multiball" and 1 or 0) + (second == "multiball" and 1 or 0)
                    assert(game.world:count("Ball") == 3^multiplies)
                    assert(game.lives == 3 + (first == "extra_life" and 1 or 0) + (second == "extra_life" and 1 or 0))
                    for kind, duration in pairs(timers) do assert((duration > 0) == not not selected[kind]) end
                    assert((power.ammo > 0) == not not selected.laser)
                    for _, id in ipairs(game.world:query("Ball")) do assert(not not game.world:get(id, "Ball").fire == not not selected.fireball) end
                    local function dataOnly(value)
                        assert(type(value) ~= "function")
                        if type(value) == "table" then for _, child in pairs(value) do dataOnly(child) end end
                    end
                    dataOnly(game.world.components)
                end
            end
        end)

        test("Temporizadores con dt dividido expiran a tiempo; gigante e iman ajustan la captura al encogerse", function()
            local game = empty(); game:activatePowerup("giant_paddle"); game:activatePowerup("magnet")
            local ball = Helpers.balls(game)[1]; capture(game, ball, 80)
            local timers = Effects.get(game); timers.magnet = 30
            for _ = 1, 300 do Effects.update(game, 0.05); Effects.follow(game) end
            local paddle = Helpers.paddle(game)
            assert(timers.giant_paddle == 0 and near(timers.magnet, 15) and paddle.collider.w == Config.PADDLE_W)
            assert(ball.position.x + ball.collider.w / 2 <= paddle.position.x + paddle.collider.w)
            assert(game.world:get(ball.id, "Ball").held)
        end)

        test("Laser considera desplazamiento relativo de un obstaculo que cruza un proyectil", function()
            local game = empty(); game:activatePowerup("laser"); game:keypressed("space")
            local shots = game.world:query("Projectile")
            game.world:destroy(shots[2])
            local p, v = game.world:get(shots[1], "Position"), game.world:get(shots[1], "Velocity")
            p.x, p.y, v.vx, v.vy = 450, 400, 0, 0
            local obstacle = game.world:create({Position = Components.position(500, 400), Collider = Components.collider(5, 30),
                MovingObstacle = {}, Motion = {previousX = 400, previousY = 400}})
            Projectiles.update(game, 0.05)
            assert(game.world:has(obstacle) and game.world:count("Projectile") == 0)
        end)

        test("Portales resuelven primera entrada y velocidades nulas sin NaN ni teletransportes dobles", function()
            local game = empty()
            -- Crear primero el mas lejano para que el orden de IDs no determine el resultado.
            Portals.create(game.world, {portals = {
                {id = "far", cooldown = 0.4, rotationDegrees = 0, entry = {x = 240, y = 350, radius = 3}, exit = {x = 800, y = 350, radius = 3}},
                {id = "near", cooldown = 0.4, rotationDegrees = 0, entry = {x = 200, y = 350, radius = 3}, exit = {x = 600, y = 350, radius = 3}},
            }})
            local ball = Helpers.balls(game)[1]; local data = game.world:get(ball.id, "Ball")
            place(ball, 260, 350, 550, 0); data.previousX, data.previousY = 180 - 6.5, 350 - 6.5
            Portals.update(game, 0)
            assert(ball.position.x > 590 and ball.position.x < 700 and game.world:count("PortalPulse") == 2)
            data.portalCooldown, data.previousX, data.previousY = 0, nil, nil
            place(ball, 200, 350, 0, 0); Portals.update(game, 0)
            assert(ball.position.x == ball.position.x and ball.position.y == ball.position.y and speed(ball) == 0)
        end)

        test("Canvas real con siete etiquetas, timers, municion, escudo y portal sin fuentes por frame", function()
            local game = empty(); pair(game); active(game)
            for index, kind in ipairs(game.levels:get(10).activePowerups) do Powerups.spawn(game.world, Config, kind, 100 + index * 90, 420) end
            local canvas = love.graphics.newCanvas(Config.WIDTH, Config.HEIGHT)
            local newFont, printf = love.graphics.newFont, love.graphics.printf
            local labels, hud = {}, false
            love.graphics.newFont = function() error("Fuente creada durante draw") end
            love.graphics.printf = function(value, ...)
                labels[value] = true
                if value:find("GIGANTE 15s", 1, true) and value:find("ESCUDO 3/3 20s", 1, true)
                    and value:find("LASER: 20", 1, true) then hud = true end
                return printf(value, ...)
            end
            local success, failure = xpcall(function()
                love.graphics.setCanvas(canvas); game:draw(); love.graphics.setCanvas()
                for _, definition in pairs(Config.POWERUP_TYPES) do assert(labels[definition.name] and labels[definition.label]) end
                assert(hud)
            end, debug.traceback)
            love.graphics.setCanvas(); love.graphics.newFont, love.graphics.printf = newFont, printf
            canvas:release(); assert(success, failure)
        end)
    end, debug.traceback)
    love.math.random, love.keyboard.isDown, love.event.quit, Config.ECS_ASSIGNMENT_MODE = random, keyboard, quit, mode
    if not ok then error(err, 0) end
    return passed
end

return {run = run}

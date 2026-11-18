local Config = require("src.config")
local Components = require("src.ecs.components")
local Bricks = require("src.bricks")
local Obstacles = require("src.obstacles")
local Rules = require("src.level_rules")
local LevelManager = require("src.level_manager")
local Damage = require("src.ecs.systems.damage_system")
local Explosion = require("src.ecs.systems.explosion_system")
local Motion = require("src.ecs.systems.motion_system")
local Ghost = require("src.ecs.systems.ghost_system")
local Helpers = require("tests.helpers")

local function near(a, b) return math.abs(a - b) < 0.00001 end

local function fixture(specs, obstacles, sentinel)
    local game = Helpers.newGame()
    for _, id in ipairs(game.world:query("Brick")) do game.world:destroy(id) end
    local ids = {}
    for index, spec in ipairs(specs) do
        ids[index] = Bricks.spawn(game.world, Config, game.level, {
            row = spec.row or 1, column = spec.column or index,
            key = "test" .. index, x = spec.x or 100, y = spec.y or 200,
            w = spec.w or 60, h = spec.h or 25, color = {1, 0.3, 0.3},
            definition = spec.definition or game.level.brickTypes[spec.type or "N"],
        })
    end
    if sentinel ~= false then
        Bricks.spawn(game.world, Config, game.level, {key = "sentinel", x = 880, y = 94, w = 40, h = 20,
            color = {1, 0.3, 0.3}, definition = {kind = "normal"}})
    end
    Obstacles.create(game.world, {obstacles = obstacles or {}})
    Motion.configure(game.world, Config)
    game.remaining = Bricks.remaining(game.world)
    return game, ids
end

local function aim(game, ball, target)
    local p, size = game.world:get(target, "Position"), game.world:get(target, "Collider")
    ball.position.x, ball.position.y = p.x + (size.w - ball.collider.w) / 2, p.y - ball.collider.h - 1
    ball.velocity.vx, ball.velocity.vy = 0, 280
end

local function run()
    local random, keyboard, quit, mode = love.math.random, love.keyboard.isDown, love.event.quit, Config.ECS_ASSIGNMENT_MODE
    local calls, passed = 0, 0
    love.math.random = function() calls = calls + 1; return 0 end
    love.keyboard.isDown = function() return false end
    Config.ECS_ASSIGNMENT_MODE = false
    local function test(name, fn)
        calls = 0
        fn()
        passed = passed + 1
        print("OK FASE2 " .. passed .. ": " .. name)
    end
    local ok, err = xpcall(function()
        test("Resistentes configurables de 2, 3 y 4 impactos: salud, color y un solo poder", function()
            for health = 2, 4 do
                calls = 0
                local game, ids = fixture({{definition = {kind = "resistant", health = health}}})
                local id, initial = ids[1], game.world:get(ids[1], "Renderable").color[1]
                for hit = 1, health do
                    assert(Damage.hit(game, id, 1, "ball"))
                    if hit < health then
                        assert(game.world:get(id, "Health").current == health - hit)
                        assert(game.world:get(id, "Renderable").color[1] < initial)
                        assert(game.remaining == 2 and calls == 0)
                    end
                end
                assert(not game.world:has(id) and game.remaining == 1 and calls == 1)
                assert(game.world:count("PowerUp") == 1 and not Damage.hit(game, id, 1, "ball"))
            end
        end)

        test("Contacto continuo no repite daño; una separacion permite el siguiente impacto", function()
            local game, ids = fixture({{type = "R"}})
            local ball = Helpers.balls(game)[1]
            aim(game, ball, ids[1])
            game:update(0.01)
            assert(game.world:get(ids[1], "Health").current == 2)
            for _ = 1, 8 do
                ball.position.y = 200 - ball.collider.h + 0.0001
                ball.velocity.vx, ball.velocity.vy = 0, 0
                game:update(0)
            end
            assert(game.world:get(ids[1], "Health").current == 2)
            ball.position.y = 150
            game:update(0)
            aim(game, ball, ids[1])
            game:update(0.01)
            assert(game.world:get(ids[1], "Health").current == 1)
        end)

        test("90 pelotas sobre un resistente: tres daños, una destruccion y un sorteo", function()
            local game, ids = fixture({{type = "R"}})
            Helpers.setBallCount(game, 90)
            for _, ball in ipairs(Helpers.balls(game)) do aim(game, ball, ids[1]) end
            game:update(0.01)
            assert(not game.world:has(ids[1]) and game.remaining == 1 and calls == 1)
            assert(game.world:count("Ball") == 90 and game.world:count("PowerUp") == 1)
        end)

        test("Explosion afecta una vez al vecino ortogonal y no a dos celdas", function()
            local game, ids = fixture({{type = "E"}, {type = "R", x = 190}, {type = "R", x = 300}})
            Damage.hit(game, ids[1], 1, "ball")
            assert(Explosion.pending(game) and game.world:get(ids[2], "Health").current == 3)
            Explosion.process(game)
            assert(game.world:get(ids[2], "Health").current == 2 and game.world:get(ids[3], "Health").current == 3)
            assert(not Explosion.pending(game))
            Explosion.process(game)
            assert(game.world:get(ids[2], "Health").current == 2)
        end)

        test("Cadena de 90 explosivos sin recursion, daños duplicados ni particulas ilimitadas", function()
            local specs = {}
            for index = 1, 90 do specs[index] = {type = "E", x = 100 + index % 3, y = 200} end
            local game, ids = fixture(specs)
            Damage.hit(game, ids[1], 1, "ball")
            Explosion.process(game)
            assert(game.remaining == 1 and calls == 90 and not Explosion.pending(game))
            for _, id in ipairs(ids) do assert(not game.world:has(id)) end
            assert(game.world:count("ExplosionParticle") == Config.MAX_EXPLOSION_PARTICLES)
            Explosion.updateVisuals(game.world, Config.EXPLOSION_VISUAL_SECONDS / 2)
            for _, id in ipairs(game.world:query("ExplosionParticle")) do
                assert(near(game.world:get(id, "Renderable").alpha, 0.5))
            end
            Explosion.updateVisuals(game.world, Config.EXPLOSION_VISUAL_SECONDS)
            assert(game.world:count("ExplosionParticle") == 0)
        end)

        test("Cola conserva trabajo entre frames cuando se reduce el presupuesto de eventos", function()
            local game, ids = fixture({{type = "E"}, {type = "E", x = 170}, {type = "E", x = 240}})
            game.config = setmetatable({MAX_EXPLOSIONS_PER_UPDATE = 1}, {__index = Config})
            Damage.hit(game, ids[1], 1, "ball")
            Explosion.process(game)
            assert(Explosion.pending(game) and not game.world:has(ids[2]))
            for _ = 1, 3 do Explosion.process(game) end
            assert(not Explosion.pending(game) and game.remaining == 1 and calls == 3)
        end)

        test("Explosiones distintas pueden dañar un resistente sin repetir el evento original", function()
            local game, ids = fixture({{type = "E"}, {type = "E", x = 170},
                {type = "E", row = 2, column = 1}, {type = "R", row = 2, column = 2, x = 170, y = 240}})
            Damage.hit(game, ids[1], 1, "ball")
            Explosion.process(game)
            assert(game.world:get(ids[4], "Health").current == 1 and calls == 3)
        end)

        test("Blindados rechazan pelotas y respetan fuentes de daño configuradas", function()
            local game, ids = fixture({{definition = {kind = "armored", vulnerableTo = {"laser", "explosion"}}}})
            assert(not Damage.hit(game, ids[1], 1, "ball"))
            assert(not Damage.hit(game, ids[1], 1, "fireball"))
            local ball = Helpers.balls(game)[1]
            aim(game, ball, ids[1]); game:update(0.01)
            assert(ball.velocity.vy < 0 and game.world:get(ids[1], "Health").current == 1)
            assert(Damage.hit(game, ids[1], 1, "laser") and not game.world:has(ids[1]))
            local fireGame, fireIds = fixture({{type = "A"}})
            assert(Damage.hit(fireGame, fireIds[1], 1, "fireball")) -- El poder completo se verifica en powers_portals_spec.
        end)

        test("Validacion rechaza blindados sin explosivo eficaz y ciclos o trayectorias invalidos", function()
            local manager = LevelManager.new(Config)
            for _, mutate in ipairs({
                function(level) level.bricks = {{key = "A", x = 100, y = 100, w = 50, h = 25,
                    definition = {kind = "armored", vulnerableTo = {"explosion"}}}} end,
                function(level) level.bricks[1].definition = {kind = "resistant", health = 5} end,
                function(level) level.bricks[1].definition = {kind = "moving", motion = {pattern = "vertical", period = 0}} end,
                function(level) level.bricks[1].definition = {kind = "ghost", solidSeconds = 3, intangibleSeconds = 0, warningSeconds = 1} end,
                function(level) level.obstacles = {{id = "bad", x = 200, y = 580, w = 50, h = 14}} end,
            }) do
                local level = manager:get(1); mutate(level)
                assert(not pcall(function() Rules.validate(level, Config) end))
            end
        end)

        test("Todos los niveles se completan con daño legal y suministro garantizado en ambos ordenes", function()
            for _, direction in ipairs({1, -1}) do
                local game = Helpers.newGame()
                game.progress.maxUnlocked = 10
                for index = 1, 10 do
                    Helpers.startCampaign(game, index)
                    local ids = game.world:query("Brick")
                    for n = direction == 1 and 1 or #ids, direction == 1 and #ids or 1, direction do
                        local id = ids[n]
                        local brick = game.world:get(id, "Brick")
                        if brick and brick.kind ~= "unbreakable" then
                            Helpers.waitForGhost(game, id)
                            for _ = 1, 4 do
                                if game.world:has(id) then
                                    Damage.hit(game, id, 1, brick.kind == "armored" and game.level.difficulty.guaranteedPowerup.kind or "ball")
                                end
                            end
                            Explosion.process(game)
                        end
                    end
                    assert(game.remaining == 0, "Nivel incompletable: " .. index)
                    Helpers.defeatBoss(game)
                    assert(game.state == (index == 10 and "campaign_complete" or "level_complete"))
                    assert(game.world:count("Boss") == (game.level.boss and 1 or 0) and game.world:count("Portal") == #game.level.portals * 2)
                end
            end
        end)

        test("Fantasma avisa antes de alternar y su ciclo es determinista con dt dividido", function()
            local a, idsA = fixture({{type = "G"}})
            local b, idsB = fixture({{type = "G"}})
            Ghost.update(a.world, 2.75)
            for _ = 1, 11 do Ghost.update(b.world, 0.25) end
            local ga, gb = a.world:get(idsA[1], "Ghost"), b.world:get(idsB[1], "Ghost")
            assert(ga.solid and ga.warning and gb.warning and near(ga.elapsed, gb.elapsed))
            Ghost.update(a.world, 0.25)
            assert(not ga.solid and a.world:get(idsA[1], "Renderable").alpha < 0.5)
            Ghost.update(a.world, 2)
            assert(ga.solid and not ga.waiting)
        end)

        test("Fantasma intangible no rebota ni recibe daño de pelotas o explosiones", function()
            local game, ids = fixture({{type = "G"}})
            Ghost.update(game.world, 3)
            local ball = Helpers.balls(game)[1]
            aim(game, ball, ids[1]); game:update(0.05)
            assert(ball.velocity.vy > 0 and game.world:get(ids[1], "Health").current == 1)
            assert(not Damage.hit(game, ids[1], 1, "explosion"))
            ball.position.y = 400
            Ghost.update(game.world, 2)
            aim(game, ball, ids[1]); game:update(0.01)
            assert(not game.world:has(ids[1]) and ball.velocity.vy < 0)
        end)

        test("Fantasma espera hasta que salgan todas las pelotas antes de volverse solido", function()
            local game, ids = fixture({{type = "G"}})
            Ghost.update(game.world, 3)
            game:activatePowerup("multiball")
            local balls = Helpers.balls(game)
            for _, ball in ipairs(balls) do ball.position.x, ball.position.y = 110, 205 end
            Ghost.update(game.world, 2)
            local data = game.world:get(ids[1], "Ghost")
            assert(not data.solid and data.waiting)
            for index = 1, 2 do balls[index].position.y = 400 end
            Ghost.update(game.world, 0)
            assert(not data.solid and data.waiting)
            balls[3].position.y = 400
            Ghost.update(game.world, 0)
            assert(data.solid and not data.waiting)
        end)

        test("Trayectorias horizontal, vertical y oscilatoria tienen posiciones predecibles", function()
            for _, pattern in ipairs({"horizontal", "vertical", "oscillatory"}) do
                local game, ids = fixture({{x = 200, y = 300, definition = {kind = "moving",
                    motion = {pattern = pattern, amplitude = 20, period = 4}}}})
                Motion.update(game.world, 0.5)
                local p = game.world:get(ids[1], "Position")
                assert(near(p.x, pattern == "vertical" and 200 or 200 + 20 / math.sqrt(2)))
                assert(near(p.y, pattern == "horizontal" and 300 or (pattern == "vertical" and 300 + 20 / math.sqrt(2) or 320)))
                assert(game.world:has(ids[1], "Velocity", "Motion", "Collider"))
            end
        end)

        test("Movimiento con dt dividido y grupos conservan formacion incluso junto al borde", function()
            local definition = {kind = "moving", motion = {pattern = "group", group = "pair", period = 4, amplitude = 40}}
            local a, ia = fixture({{x = 5, definition = definition}, {x = 105, definition = definition}})
            local b, ib = fixture({{x = 5, definition = definition}, {x = 105, definition = definition}})
            Motion.update(a.world, 1)
            for _ = 1, 10 do Motion.update(b.world, 0.1) end
            for index = 1, 2 do assert(near(a.world:get(ia[index], "Position").x, b.world:get(ib[index], "Position").x)) end
            assert(near(a.world:get(ia[2], "Position").x - a.world:get(ia[1], "Position").x, 100))
            assert(near(a.world:get(ia[1], "Position").x, 10))
        end)

        test("Bloques y obstaculos moviles respetan limites del campo, paddle y rapidez", function()
            local game = fixture({{x = 5, y = 100, definition = {kind = "moving",
                motion = {pattern = "oscillatory", amplitude = 800, period = 0.1}}}},
                {{id = "edge", x = 900, y = 480, w = 50, h = 10,
                    motion = {pattern = "oscillatory", amplitude = 800, period = 0.1}}})
            for _ = 1, 200 do
                Motion.update(game.world, 0.005)
                for _, id in ipairs(game.world:query("Motion")) do
                    local p, v, size = game.world:get(id, "Position"), game.world:get(id, "Velocity"), game.world:get(id, "Collider")
                    assert(p.x >= 0 and p.x + size.w <= Config.WIDTH and p.y >= Config.BRICK_TOP)
                    assert(p.y + size.h <= Config.PADDLE_Y - Config.KINEMATIC_PADDLE_CLEARANCE)
                    assert(math.sqrt(v.vx ^ 2 + v.vy ^ 2) <= Config.KINEMATIC_MAX_SPEED + 0.001)
                end
            end
        end)

        test("Obstaculo fino no se atraviesa a 550 px/s y no recibe daño ni cuenta para ganar", function()
            local game, ids = fixture({{type = "N", x = 100}},
                {{id = "thin", x = 350, y = 290, w = 100, h = 2, motion = {pattern = "horizontal", amplitude = 0, period = 4}}}, false)
            local obstacle = game.world:query("MovingObstacle")[1]
            local ball = Helpers.balls(game)[1]
            ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = 380, 270, 0, 550
            game:update(0.05)
            assert(ball.velocity.vy == -550 and ball.position.y == 290 - ball.collider.h)
            assert(not Damage.hit(game, obstacle, 100, "explosion") and game.remaining == 1)
            game:update(0.01)
            assert(ball.velocity.vy == -550, "No volver a reflejar al salir del contacto")
            Damage.hit(game, ids[1], 1, "ball")
            assert(game.state == "level_complete" and game.remaining == 0 and game.world:has(obstacle))
        end)

        test("Barrido usa el movimiento relativo: obstaculo alcanza una pelota detenida", function()
            local game = fixture({}, {{id = "push", x = 350, y = 300, w = 100, h = 14,
                motion = {pattern = "vertical", amplitude = 20, period = 0.4}}})
            local ball = Helpers.balls(game)[1]
            ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = 380, 316, 0, 0
            game:update(0.05)
            local obstacle = game.world:query("MovingObstacle")[1]
            assert(ball.velocity.vy > 0 and ball.velocity.vy <= Config.BALL_MAX_SPEED)
            assert(near(ball.position.y, game.world:get(obstacle, "Position").y + 14))
        end)

        test("Barrido selecciona el objeto mas cercano, independiente del ID y del orden de creacion", function()
            local game = fixture({}, {
                {id = "near", x = 350, y = 210, w = 100, h = 2, motion = {pattern = "horizontal", amplitude = 0, period = 4}},
                {id = "far", x = 350, y = 200, w = 100, h = 2, motion = {pattern = "horizontal", amplitude = 0, period = 4}},
            })
            local ball = Helpers.balls(game)[1]
            ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = 380, 225, 0, -550
            game:update(0.05)
            assert(ball.position.y == 212 and ball.velocity.vy == 550)
        end)

        test("Bloque fino tampoco se atraviesa y la bola movil conserva el limite global", function()
            local game, ids = fixture({{type = "N", x = 350, y = 290, h = 2, w = 100}})
            local ball = Helpers.balls(game)[1]
            ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = 380, 270, 0, 550
            game:update(0.05)
            assert(not game.world:has(ids[1]) and ball.velocity.vy == -550)
        end)

        test("Perder vida conserva salud y trayectorias; reiniciar nivel limpia cola y particulas", function()
            local game = Helpers.newGame()
            game.progress.maxUnlocked = 4; Helpers.startCampaign(game, 4)
            local resistant, moving
            for _, id in ipairs(game.world:query("Brick")) do
                local kind = game.world:get(id, "Brick").kind
                if kind == "resistant" then resistant = id elseif kind == "moving" then moving = id end
            end
            Damage.hit(game, resistant, 1, "ball")
            Motion.update(game.world, 0.5)
            local elapsed = game.world:get(moving, "Motion").elapsed
            for _, id in ipairs(game.world:query("Ball")) do game.world:destroy(id) end
            game:update(0)
            assert(game.lives == 2 and game.world:get(resistant, "Health").current == 2)
            assert(game.world:get(moving, "Motion").elapsed == elapsed)
            game:restartLevel(); Helpers.finishIntro(game)
            assert(not game.world:has(resistant) and not game.world:has(moving))
            assert(not Explosion.pending(game) and game.world:count("ExplosionParticle") == 0)
            for _, id in ipairs(game.world:query("Motion")) do assert(game.world:get(id, "Motion").elapsed == 0) end
        end)

        test("Menu congela trayectorias y fantasmas; un nuevo intento elimina eventos pendientes", function()
            local game, ids = fixture({{type = "M"}, {type = "G", x = 200}, {type = "E", x = 300}})
            Damage.hit(game, ids[3], 1, "ball")
            game:goToMenu(); game:update(10)
            assert(game.world:get(ids[1], "Motion").elapsed == 0 and game.world:get(ids[2], "Ghost").elapsed == 0)
            assert(Explosion.pending(game))
            game:reset(); Helpers.finishIntro(game)
            assert(not Explosion.pending(game) and game.world:count("ExplosionParticle") == 0)
        end)

        test("Area de movimiento respeta una altura de paddle distinta por nivel", function()
            local game = fixture({}, {{id = "low", x = 400, y = 330, w = 100, h = 14,
                motion = {pattern = "vertical", amplitude = 100, period = 4}}})
            Motion.configure(game.world, Config, 450)
            Motion.update(game.world, 1)
            local obstacle = game.world:query("MovingObstacle")[1]
            assert(game.world:get(obstacle, "Position").y + 14 <= 450 - Config.KINEMATIC_PADDLE_CLEARANCE)
            local level = LevelManager.new(Config):get(4)
            level.spawn.paddle.y = 430
            assert(not pcall(function() Rules.validate(level, Config) end))
        end)

        test("Particulas del ultimo explosivo se limpian tambien tras la victoria final", function()
            local game = Helpers.newGame()
            game.progress.maxUnlocked = 10; Helpers.startCampaign(game, 10)
            local explosive
            for _, id in ipairs(game.world:query("Brick")) do
                if not explosive and game.world:get(id, "Brick").kind == "explosive" then explosive = id
                else game.world:destroy(id) end
            end
            game.remaining = 1
            Damage.hit(game, explosive, 1, "ball"); Explosion.process(game)
            Helpers.defeatBoss(game)
            assert(game.state == "campaign_complete" and game.world:count("ExplosionParticle") > 0)
            game:update(Config.EXPLOSION_VISUAL_SECONDS + 1)
            assert(game.state == "campaign_complete" and game.world:count("ExplosionParticle") == 0)
        end)

        test("Entrega ECS con bloques especiales y obstaculos conserva cierre y prioridad", function()
            local game, ids = fixture({{type = "E"}, {type = "G", x = 200}},
                {{id = "wall", x = 400, y = 350, w = 100, h = 14, motion = {pattern = "horizontal", amplitude = 50, period = 4}}})
            Config.ECS_ASSIGNMENT_MODE = true
            local quits = 0
            love.event.quit = function() quits = quits + 1 end
            local ball = Helpers.balls(game)[1]
            ball.position.x, ball.position.y, ball.velocity.vx = 0, 400, -195
            Damage.hit(game, ids[1], 1, "ball") -- Evento pendiente que no debe procesarse despues del cierre.
            game:update(0)
            assert(quits == 1 and game.quitRequested and ball.velocity.vx == -195 and game.lives == 3)
            assert(Explosion.pending(game) and game.world:count("ExplosionParticle") == 0)
            Config.ECS_ASSIGNMENT_MODE, love.event.quit = false, quit
        end)
    end, debug.traceback)
    love.math.random, love.keyboard.isDown, love.event.quit, Config.ECS_ASSIGNMENT_MODE = random, keyboard, quit, mode
    if not ok then error(err, 0) end
    return passed
end

return {run = run}

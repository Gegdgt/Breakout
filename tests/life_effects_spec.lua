local Config = require("src.config")
local H = require("tests.helpers")
local Components = require("src.ecs.components")
local Effects = require("src.ecs.systems.power_effect_system")
local Damage = require("src.ecs.systems.damage_system")
local Powerups = require("src.powerups")
local Bricks = require("src.bricks")

local function near(a, b) return math.abs(a - b) < .000001 end
local function activate(game)
    for _, kind in ipairs({"giant_paddle", "fireball", "magnet", "shield", "laser"}) do game:activatePowerup(kind) end
end
local function drop(ball)
    -- Ya debajo del escudo: una pelota salvada por el escudo no cuenta como perdida.
    ball.position.x, ball.position.y = 400, Config.HEIGHT
    ball.velocity.vx, ball.velocity.vy = 0, 100
end
local function lose(game, dt)
    for _, ball in ipairs(H.balls(game)) do drop(ball) end
    game:update(dt or 0)
end
local function clean(game)
    local timers, power = Effects.get(game)
    for _, value in pairs(timers) do assert(value == 0) end
    assert(power.ammo == 0 and power.cooldown == 0 and not power.shieldId and not power.heldBall)
    assert(power.guaranteedElapsed == 0 and power.bossLaserElapsed == 0)
    assert(H.paddle(game).collider.w == Config.PADDLE_W)
    for _, component in ipairs({"Shield", "PowerUp", "Projectile", "EnemyProjectile"}) do
        assert(game.world:count(component) == 0)
    end
    for _, ball in ipairs(H.balls(game)) do assert(not game.world:get(ball.id, "Ball").fire) end
end

local function run()
    local keyboard, random, quit, mode = love.keyboard.isDown, love.math.random, love.event.quit, Config.ECS_ASSIGNMENT_MODE
    local held, passed, quits, rolls = {}, 0, 0, 0
    love.keyboard.isDown = function(...)
        for _, key in ipairs({...}) do if held[key] then return true end end
        return false
    end
    love.math.random = function() rolls = rolls + 1; return .99 end
    love.event.quit = function() quits = quits + 1 end
    Config.ECS_ASSIGNMENT_MODE = false
    local function test(name, fn)
        held, quits, rolls = {}, 0, 0
        fn(); passed = passed + 1; print("OK VIDAS/PODERES " .. passed .. ": " .. name)
    end
    local ok, err = xpcall(function()
        test("Gigante conserva entidad, ancho y 8 s; centra usando el ancho actual", function()
            local game = H.newGame(); game:activatePowerup("giant_paddle")
            local p, timers, power = H.paddle(game), Effects.get(game)
            timers.giant_paddle, timers.futureEffect = 8, 6
            p.position.x = 0; p.velocity.vx = 855
            game.world:get(game.paddleId, "PaddleControl").sprinting = true
            local id, width = game.paddleId, p.collider.w
            lose(game)
            assert(game.lives == 2 and game.paddleId == id and game.world:get(id, "TimedEffect") == timers)
            assert(game.world:get(id, "PaddlePower") == power and timers.giant_paddle == 8 and timers.futureEffect == 6)
            assert(width == Config.PADDLE_W * 1.5 and p.collider.w == width and p.position.x == (Config.WIDTH - width) / 2)
            assert(p.velocity.vx == 0 and p.velocity.vy == 0 and not game.world:get(id, "PaddleControl").sprinting)
            local previous = game.world:get(id, "PreviousPosition")
            assert(previous.previousX == p.position.x and previous.previousY == p.position.y)
        end)

        test("Laser conserva exactamente 12 disparos y el intervalo ya iniciado", function()
            local game = H.newGame(); game:activatePowerup("laser")
            for _ = 1, 8 do Effects.update(game, Config.LASER_INTERVAL); game:keypressed("space") end
            local _, power = Effects.get(game); local shots = game.world:query("Projectile")
            assert(power.ammo == 12 and #shots == 16)
            lose(game)
            assert(power.ammo == 12 and power.cooldown == Config.LASER_INTERVAL and game.world:count("Projectile") == 16)
            for _, id in ipairs(shots) do assert(game.world:has(id, "Projectile")) end
            game:keypressed("space"); assert(power.ammo == 12)
            for _ = 1, 6 do game:update(.05) end
            game:keypressed("space"); assert(power.ammo == 11)
        end)

        test("Escudo conserva su entidad, 2 impactos y duracion; despues se consume normalmente", function()
            local game = H.newGame(); game:activatePowerup("shield")
            local timers, power = Effects.get(game); local shieldId = power.shieldId
            local shield, top = game.world:get(shieldId, "Shield"), game.world:get(shieldId, "Position").y
            local function hit()
                local ball = H.balls(game)[1]
                ball.position.y, ball.velocity.vy = top - ball.collider.h + 1, 200
                assert(Effects.hitShield(game, ball.id, top - ball.collider.h - 1))
            end
            hit(); timers.shield = 9; assert(shield.hits == 2)
            local alpha = game.world:get(shieldId, "Renderable").alpha
            lose(game)
            assert(power.shieldId == shieldId and game.world:get(shieldId, "Shield") == shield)
            assert(shield.hits == 2 and timers.shield == 9 and game.world:count("Shield") == 1)
            assert(game.world:get(shieldId, "Renderable").alpha == alpha)
            hit(); assert(shield.hits == 1); hit()
            assert(not power.shieldId and timers.shield == 0 and game.world:count("Shield") == 0 and game.lives == 2)
        end)

        test("Nueva pelota hereda fuego vigente y velocidad inicial; el efecto expira sin renovarse", function()
            local game = H.newGame(); game:activatePowerup("fireball")
            local timers = Effects.get(game); timers.fireball = 3.25
            local old = H.balls(game)[1].id; lose(game)
            local ball = H.balls(game)[1]
            assert(ball.id ~= old and not game.world:has(old) and game.world:get(ball.id, "Ball").fire)
            assert(timers.fireball == 3.25 and ball.velocity.vx == game.level.initialVelocity.vx and ball.velocity.vy == game.level.initialVelocity.vy)
            assert(game.world:get(ball.id, "Renderable").borderColor)
            Effects.update(game, 3.25)
            assert(timers.fireball == 0 and not game.world:get(ball.id, "Ball").fire)
        end)

        test("Iman conserva 7 s, libera referencia perdida y captura la nueva pelota con sprint", function()
            local game = H.newGame(); activate(game)
            local timers, power = Effects.get(game); timers.magnet, power.ammo = 7, 12
            local p, old = H.paddle(game), H.balls(game)[1]
            old.position.x = p.position.x + p.collider.w / 2 - old.collider.w / 2
            assert(Effects.capture(game, old.id))
            -- Un ataque puede perder la ronda aunque haya una pelota capturada.
            game:loseLife()
            assert(not power.heldBall and not game.world:has(old.id) and timers.magnet == 7)
            local ball = H.balls(game)[1]
            ball.position.x, ball.position.y = p.position.x + p.collider.w / 2 - ball.collider.w / 2, p.position.y - ball.collider.h + 1
            ball.velocity.vx, ball.velocity.vy = 0, 300; game:update(0)
            assert(power.heldBall == ball.id and game.world:get(ball.id, "Ball").held)
            local x, offset = p.position.x, ball.position.x - p.position.x
            held = {rshift = true, d = true}; game:update(.02)
            assert(near(p.position.x - x, 855 * .02) and near(ball.position.x - p.position.x, offset))
            local vx, vy = ball.velocity.vx, ball.velocity.vy
            game:keypressed("space")
            assert(not power.heldBall and power.ammo == 12 and game.world:count("Projectile") == 0)
            assert(ball.velocity.vx == vx and ball.velocity.vy == vy)
        end)

        test("89 bajas no cuestan vida; la ultima de 90 resta una y repone solo una pelota", function()
            local game = H.newGame(); game:activatePowerup("fireball"); game:activatePowerup("giant_paddle")
            for _ = 1, 5 do game:activatePowerup("multiball") end
            local balls = H.balls(game); assert(#balls == 90)
            for index = 2, #balls do drop(balls[index]) end
            game:update(0); assert(game.lives == 3 and game.world:count("Ball") == 1)
            local timers = Effects.get(game); local remaining = timers.giant_paddle
            drop(balls[1]); game:update(0)
            assert(game.lives == 2 and game.world:count("Ball") == 1 and timers.giant_paddle == remaining)
            for _, ball in ipairs(balls) do
                assert(not game.world:has(ball.id))
                for _, storage in pairs(game.world.components) do assert(storage[ball.id] == nil) end
            end
            for _ = 1, 10 do game:update(0) end
            assert(game.lives == 2 and game.world:count("Ball") == 1 and game.world:count("PowerUp") == 0)
        end)

        test("Reposicion no recrea efectos ni recoge otra vez poderes; conserva objetos y relojes", function()
            local game = H.newGame(); activate(game); game:keypressed("space")
            local timers, power = Effects.get(game)
            timers.giant_paddle, timers.fireball, timers.magnet, timers.shield = 8, 3, 7, 9
            power.ammo, power.cooldown, power.guaranteedElapsed, power.bossLaserElapsed = 12, .17, 4, 6
            game.world:get(power.shieldId, "Shield").hits = 2
            local pickup = Powerups.spawn(game.world, Config, "multiball", 100, 400)
            local enemy = game.world:create({Position = Components.position(50, 350), Velocity = Components.velocity(0, 200),
                Collider = Components.collider(10, 10), PreviousPosition = Components.previousPosition(50, 350),
                EnemyProjectile = {remaining = 5, destructible = false}, Health = Components.health(1)})
            local shieldId, paddleId, shots, before = power.shieldId, game.paddleId, game.world:query("Projectile"), rolls
            game.lives = 5
            for life = 4, 1, -1 do
                game:loseLife()
                assert(game.lives == life and game.world:count("Ball") == 1 and game.paddleId == paddleId)
                assert(timers.giant_paddle == 8 and timers.fireball == 3 and timers.magnet == 7 and timers.shield == 9)
                assert(power.ammo == 12 and power.cooldown == .17 and power.guaranteedElapsed == 4 and power.bossLaserElapsed == 6)
                assert(power.shieldId == shieldId and game.world:get(shieldId, "Shield").hits == 2)
                assert(game.world:has(pickup, "PowerUp") and game.world:has(enemy, "EnemyProjectile"))
                for _, id in ipairs(shots) do assert(game.world:has(id, "Projectile")) end
                assert(game.world:count("Shield") == 1 and game.world:count("PowerUp") == 1 and game.world:count("Projectile") == 2)
            end
            assert(rolls == before)
        end)

        test("La reposicion inmediata no consume tiempo adicional y la pausa lo congela", function()
            local game = H.newGame(); activate(game)
            local timers, power = Effects.get(game)
            timers.giant_paddle, timers.fireball, timers.magnet, timers.shield = 8, 3, 7, 9
            power.cooldown = .2
            lose(game, .03) -- Los .03 s de juego antes de caer si se consumen una vez.
            assert(game.state == "playing" and near(timers.giant_paddle, 7.97) and near(timers.fireball, 2.97))
            assert(near(timers.magnet, 6.97) and near(timers.shield, 8.97) and near(power.cooldown, .17))
            for _ = 1, 5 do game:update(0) end
            game:keypressed("p"); game:update(100)
            assert(near(timers.giant_paddle, 7.97) and near(power.cooldown, .17))
            game:keypressed("p"); game:update(.02)
            assert(near(timers.giant_paddle, 7.95) and near(power.cooldown, .15))
        end)

        test("Efectos agotados en el frame de la caida no reaparecen", function()
            local game = H.newGame(); activate(game)
            local timers, power = Effects.get(game)
            for kind in pairs(timers) do timers[kind] = .01 end
            power.ammo = 0; lose(game, .02)
            assert(game.lives == 2 and game.world:count("Ball") == 1); clean(game)
        end)

        test("Perder vida conserva bloques, puntos y jefe; reinicia combo segun las reglas existentes", function()
            for _, level in ipairs({1, 5, 10}) do
                local game = H.newGame(); game.progress.maxUnlocked = 10; H.startCampaign(game, level)
                local target
                for _, id in ipairs(game.world:query("Brick")) do if game.world:get(id, "Brick").kind == "normal" then target = id; break end end
                Damage.hit(game, target, 1, "ball")
                local score, remaining, bossId = game.run.score, game.remaining, game.bossId
                if bossId then game.world:get(bossId, "Health").current = game.level.boss.health - 1 end
                activate(game); lose(game)
                assert(game.levelIndex == level and game.remaining == remaining and not game.world:has(target))
                assert(game.run.score == score and game.run.combo.chain == 0 and game.bossId == bossId)
                if bossId then assert(game.world:get(bossId, "Health").current == game.level.boss.health - 1) end
            end
        end)

        test("Nueva campaña y reinicio completo limpian poderes, municion, bloques y datos temporales", function()
            for _, campaign in ipairs({false, true}) do
                local game = H.newGame(); activate(game); game:keypressed("space")
                local destroyed = game.world:query("Brick")[1]; Damage.hit(game, destroyed, 1, "ball")
                local oldPaddle = game.paddleId; lose(game)
                if campaign then assert(game:reset()) else assert(game:restartLevel()) end
                clean(game)
                assert(game.state == "level_intro" and game.lives == 3 and game.run.score == 0)
                assert(game.remaining == Bricks.remaining(game.world) and game.world:count("Ball") == 1 and not game.world:has(oldPaddle))
                assert(game.progress.bestScore > 0, "Los records persistentes no se borran")
            end
        end)

        test("Cambio de nivel conserva la limpieza previa de efectos", function()
            local game = H.newGame(); activate(game); lose(game)
            local old = game.paddleId
            for _, id in ipairs(game.world:query("Brick")) do Bricks.destroy(game, id) end
            assert(game.state == "level_complete")
            game:update(Config.LEVEL_TRANSITION_SECONDS); clean(game)
            assert(game.levelIndex == 2 and game.state == "level_intro" and not game.world:has(old))
        end)

        test("GAME OVER limpia efectos sin pelota nueva y R comienza un intento limpio", function()
            local game = H.newGame(); activate(game); game:keypressed("space"); game.lives = 1
            Powerups.spawn(game.world, Config, "laser", 100, 400); lose(game)
            assert(game.state == "game_over" and game.lives == 0 and game.world:count("Ball") == 0); clean(game)
            game:keypressed("r"); clean(game)
            assert(game.lives == 3 and game.world:count("Ball") == 1 and game.state == "level_intro")
        end)

        test("Los diez niveles mantienen sprint y pelota inicial limitada despues de reponer", function()
            local game = H.newGame(); game.progress.maxUnlocked = 10
            for index = 1, 10 do
                held = {}; H.startCampaign(game, index); activate(game); lose(game)
                local ball, p = H.balls(game)[1], H.paddle(game)
                assert(math.sqrt(ball.velocity.vx ^ 2 + ball.velocity.vy ^ 2) <= Config.BALL_MAX_SPEED)
                local x = p.position.x; held = {d = true, lshift = true}; game:update(.02)
                assert(near(p.position.x - x, 855 * .02) and game.world:get(game.paddleId, "PaddleControl").sprinting)
                assert(Config.MAX_BALLS == 90 and Config.BALL_MAX_SPEED == 550 and game.levelIndex == index)
            end
        end)

        test("Entrega ECS sigue cerrando por ambos laterales tras perder vida con poderes", function()
            Config.ECS_ASSIGNMENT_MODE = true
            for _, right in ipairs({false, true}) do
                local game = H.newGame(); activate(game); lose(game)
                local ball = H.balls(game)[1]; ball.position.x = right and Config.WIDTH - ball.collider.w or 0
                local before, timers = quits, Effects.get(game)
                game:update(0)
                assert(game.quitRequested and quits == before + 1 and game.lives == 2 and timers.fireball == Config.FIREBALL_SECONDS)
            end
        end)
    end, debug.traceback)
    love.keyboard.isDown, love.math.random, love.event.quit, Config.ECS_ASSIGNMENT_MODE = keyboard, random, quit, mode
    if not ok then error(err, 0) end
    return passed
end

return {run = run}

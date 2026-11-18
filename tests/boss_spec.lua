local Config = require("src.config")
local Components = require("src.ecs.components")
local Helpers = require("tests.helpers")
local Bricks = require("src.bricks")
local LevelManager = require("src.level_manager")
local Damage = require("src.ecs.systems.damage_system")
local BossSystem = require("src.ecs.systems.boss_system")
local Enemy = require("src.ecs.systems.enemy_projectile_system")
local Projectiles = require("src.ecs.systems.projectile_system")
local Collisions = require("src.ecs.systems.collision_system")
local Score = require("src.ecs.systems.score_system")
local Effects = require("src.ecs.systems.power_effect_system")
local Collision = require("src.collision")

local function near(a, b) return math.abs(a - b) < 0.00001 end
local function gameAt(index)
    local game = Helpers.newGame(); game.progress.maxUnlocked = 10; Helpers.startCampaign(game, index)
    return game, game.world:get(game.bossId, "Boss"), game.world:get(game.bossId, "Health")
end
local function expose(game, phase)
    local world, id = game.world, game.bossId
    local boss = world:get(id, "Boss")
    boss.phase, boss.intro, boss.hitCooldown, boss.pendingPhase = phase or 1, 0, 0, nil
    world:get(id, "Damageable").enabled = true
    return boss
end
local function hit(game, amount, source)
    local world, id = game.world, game.bossId
    local p, c = world:get(id, "Position"), world:get(id, "Collider")
    return Damage.hit(game, id, amount or 1, source or "ball", p.x + c.w / 2, p.y + c.h)
end
local function aim(game, ball, speed)
    local p, c = game.world:get(game.bossId, "Position"), game.world:get(game.bossId, "Collider")
    ball.position.x, ball.position.y = p.x + (c.w - ball.collider.w) / 2, p.y + c.h + 1
    ball.velocity.vx, ball.velocity.vy = 0, -(speed or 400)
end
local function emptyBricks(game)
    for _, id in ipairs(game.world:query("Brick")) do game.world:destroy(id) end
    game.remaining = 0
end
local function stepBoss(game, seconds)
    for _ = 1, math.floor(seconds * 60 + 0.5) do BossSystem.update(game, 1 / 60) end
end
local function bullet(game, x, y, vx, vy, destructible)
    return game.world:create({Position = Components.position(x, y), Velocity = Components.velocity(vx, vy),
        Collider = Components.collider(10, 10), PreviousPosition = Components.previousPosition(x, y),
        EnemyProjectile = {remaining = 6, destructible = destructible}, Health = Components.health(1),
        Damageable = {sources = {laser = destructible}, enabled = destructible}})
end
local function clearShots(game)
    for _, id in ipairs(game.world:query("EnemyProjectile")) do game.world:destroy(id) end
end

local function run()
    local random, keyboard, quit, mode = love.math.random, love.keyboard.isDown, love.event.quit, Config.ECS_ASSIGNMENT_MODE
    local passed, quits = 0, 0
    love.math.random = function() return 0.99 end
    love.keyboard.isDown = function() return false end
    love.event.quit = function() quits = quits + 1 end
    Config.ECS_ASSIGNMENT_MODE = false
    local function test(name, fn)
        quits = 0; fn(); passed = passed + 1; print("OK FASE5 " .. passed .. ": " .. name)
    end
    local ok, err = xpcall(function()
        test("Solo niveles 5 y 10 crean jefe ECS con salud, colision, comportamiento y recompensa", function()
            local game = Helpers.newGame(); game.progress.maxUnlocked = 10
            for index = 1, 10 do
                Helpers.startCampaign(game, index)
                assert(game.world:count("Boss") == ((index == 5 or index == 10) and 1 or 0))
                if game.bossId then
                    assert(game.world:has(game.bossId, "Position", "Velocity", "Collider", "Health", "BossBehavior", "Renderable", "ScoreValue", "Damageable"))
                    assert(game.world:get(game.bossId, "Health").current == (index == 5 and 20 or 45))
                    assert(game.level.activeVictory == "boss_defeated" and not game:completeLevel())
                    local function dataOnly(value)
                        assert(type(value) ~= "function")
                        if type(value) == "table" then for _, child in pairs(value) do dataOnly(child) end end
                    end
                    dataOnly(game.world.components)
                end
            end
        end)

        test("Validacion rechaza fases, salud, punto debil, patrones y destinos invalidos", function()
            local manager = LevelManager.new(Config)
            for _, mutate in ipairs({
                function(l) l.boss.id = "unknown" end,
                function(l) l.boss.health = 44 end,
                function(l) l.boss.phases[1].health = 0 end,
                function(l) l.boss.phases[2].pattern = "unknown" end,
                function(l) l.boss.weakPoint.y = 1 end,
                function(l) l.boss.weakPoint.w = 1 end,
                function(l) l.boss.motion.amplitude = 9999 end,
                function(l) l.boss.teleportPositions[1].y = 590 end,
                function(l) l.boss.teleportPositions[1].x = 0/0 end,
                function(l) l.victory.kind = "clear_bricks" end,
            }) do
                local level = manager:get(10); mutate(level)
                assert(not pcall(LevelManager.prepare, level, Config))
            end
        end)

        test("Introduccion anuncia el jefe y bloquea daño y ataques antes de comenzar", function()
            for _, level in ipairs({5, 10}) do
                local game, boss, health = gameAt(level)
                assert(not hit(game) and health.current == health.maximum)
                BossSystem.update(game, 0.5)
                assert(boss.warning == "PREPARATE" and not hit(game) and game.world:count("EnemyProjectile") == 0)
            end
        end)

        test("Punto debil admite pelota, fuego y laser; cuerpo cerrado y explosiones rechazan daño", function()
            local game, boss, health = gameAt(5); expose(game)
            local p = game.world:get(game.bossId, "Position")
            assert(not Damage.hit(game, game.bossId, 1, "ball", p.x + 5, p.y + 5))
            assert(not Damage.hit(game, game.bossId, 1, "laser"))
            assert(not hit(game, 1, "explosion") and health.current == 20)
            for _, source in ipairs({"ball", "fireball", "laser"}) do
                boss.hitCooldown = 0; assert(hit(game, 1, source))
            end
            assert(health.current == 17 and game.run.score == 0 and boss.flash > 0)
        end)

        test("Pelota normal y de fuego rebotan en jefe, dañan punto debil y mantienen 550 px/s", function()
            for _, fire in ipairs({false, true}) do
                local game, _, health = gameAt(5); expose(game)
                if fire then game:activatePowerup("fireball") end
                local ball = Helpers.balls(game)[1]; aim(game, ball, 550)
                Collisions.update(game, 0.05)
                assert(health.current == 19 and near(ball.velocity.vy, 550))
                assert(game.world:get(ball.id, "Ball").contacts[game.bossId])
            end
        end)

        test("Contacto continuo y 90 pelotas no repiten daño al jefe en el mismo instante", function()
            local game, boss, health = gameAt(5); expose(game); Helpers.setBallCount(game, 90)
            for _, ball in ipairs(Helpers.balls(game)) do aim(game, ball, 550) end
            Collisions.update(game, 0.05)
            assert(health.current == 19)
            local ball = Helpers.balls(game)[1]
            boss.hitCooldown = 0
            local p, c = game.world:get(game.bossId, "Position"), game.world:get(game.bossId, "Collider")
            for _ = 1, 10 do
                ball.position.y, ball.velocity.vy = p.y + c.h - 1, 0
                Collisions.update(game, 0)
            end
            assert(health.current == 19)
            ball.position.y = 500; Collisions.update(game, 0)
            aim(game, ball); Collisions.update(game, 0.01)
            assert(health.current == 18)
        end)

        test("Punto debil movil usa la posicion al impacto, incluso cerca del borde", function()
            for _, valid in ipairs({true, false}) do
                local game, _, health = gameAt(5); expose(game)
                local p = game.world:get(game.bossId, "Position")
                local previous = game.world:get(game.bossId, "PreviousPosition")
                previous.previousX, p.x = 400, 410
                local ball = Helpers.balls(game)[1]
                -- Impacta a un cuarto del frame; comprueba ambos lados del borde efectivo.
                local weak = game.world:get(game.bossId, "BossBehavior").weakPoint
                local edge = previous.previousX + (p.x - previous.previousX) * .25 + weak.x
                ball.position.x = edge + (valid and .5 or -.5) - ball.collider.w / 2
                ball.position.y, ball.velocity.vx, ball.velocity.vy = 165, 0, -400
                Collisions.update(game, 0.05)
                assert(health.current == (valid and 19 or 20) and ball.velocity.vy > 0)
            end
        end)

        test("Laser real barre el punto debil del jefe movil y consume el proyectil", function()
            local game, _, health = gameAt(5); expose(game)
            game:activatePowerup("laser"); game:keypressed("space")
            local shots = game.world:query("Projectile")
            game.world:destroy(shots[2])
            local p, c = game.world:get(game.bossId, "Position"), game.world:get(game.bossId, "Collider")
            local previous = game.world:get(game.bossId, "PreviousPosition")
            previous.previousX, previous.previousY = p.x - 5, p.y
            local shot = game.world:get(shots[1], "Position")
            shot.x, shot.y = p.x + c.w / 2, p.y + c.h + 5
            Projectiles.update(game, 0.05)
            assert(health.current == 19 and not game.world:has(shots[1]))
        end)

        test("Guardian anuncia destinos, se mueve horizontalmente y respeta rapidez/limites", function()
            local game, boss = gameAt(5); expose(game)
            local p = game.world:get(game.bossId, "Position"); local start = p.x
            BossSystem.update(game, 0.1)
            assert(p.x == start and boss.warning == "MOVIMIENTO" and boss.destinationX < start)
            local moved, supports = false, false
            for _ = 1, 900 do
                BossSystem.update(game, 1 / 60)
                moved = moved or p.x ~= start
                supports = supports or game.world:count("BossSupport") > 0
                assert(p.x >= game.level.boss.x - 160 and p.x <= game.level.boss.x + 160 and p.y == 100)
                assert(math.abs(game.world:get(game.bossId, "Velocity").vx) <= Config.GUARDIAN_SPEED + 0.00001)
            end
            assert(moved and supports and game.world:count("EnemyProjectile") == 0)
        end)

        test("Patrones de guardian y nucleo son deterministas con la misma secuencia dt", function()
            for _, level in ipairs({5, 10}) do
                local a, ba = gameAt(level); local b, bb = gameAt(level)
                for _ = 1, 600 do BossSystem.update(a, 1 / 60); BossSystem.update(b, 1 / 60) end
                assert(near(a.world:get(a.bossId, "Position").x, b.world:get(b.bossId, "Position").x))
                assert(ba.phase == bb.phase and ba.state == bb.state and ba.warning == bb.warning)
            end
            local a = gameAt(10); local b = gameAt(10); expose(a, 2); expose(b, 2)
            BossSystem.update(a, 0.5); for _ = 1, 10 do BossSystem.update(b, 0.05) end
            assert(near(a.world:get(a.bossId, "Position").x, b.world:get(b.bossId, "Position").x))
        end)

        test("Protectores limitados son destructibles, caducan y no dan puntos ni combo; el sorteo puede fallar", function()
            local game = gameAt(5); expose(game); emptyBricks(game)
            local p = game.world:get(game.bossId, "Position")
            for n = 1, 8 do p.x = 80 + (n % 3) * 260; BossSystem.support(game, "resistant") end
            assert(game.world:count("BossSupport") == Config.BOSS_SUPPORT_LIMIT)
            local id = game.world:query("BossSupport")[1]
            Damage.hit(game, id, 1, "ball"); Damage.hit(game, id, 1, "ball")
            assert(not game.world:has(id) and game.run.score == 0 and game.run.combo.chain == 0 and game.world:count("PowerUp") == 0)
            for _, support in ipairs(game.world:query("BossSupport")) do game.world:get(support, "BossSupport").remaining = 0.01 end
            game.world:get(game.bossId, "Boss").intro = 1
            BossSystem.update(game, 0.05)
            assert(game.world:count("BossSupport") == 0 and game.remaining == 0 and game.state == "playing")
        end)

        test("Protector nunca aparece superpuesto a una pelota o bloque", function()
            local game = gameAt(5); emptyBricks(game)
            local ball = Helpers.balls(game)[1]; local p, c = game.world:get(game.bossId, "Position"), game.world:get(game.bossId, "Collider")
            ball.position.x, ball.position.y = p.x, p.y + c.h + Config.BOSS_SUPPORT_GAP
            BossSystem.support(game, "ghost")
            assert(game.world:count("BossSupport") == 1)
            for _, id in ipairs(game.world:query("BossSupport")) do
                assert(not Collision.overlaps(ball.position, ball.collider, game.world:get(id, "Position"), game.world:get(id, "Collider")))
            end
        end)

        test("Defensa alterna cierre, aviso y apertura previsibles sin proyectiles", function()
            local game, boss, health = gameAt(10); expose(game)
            BossSystem.update(game, 0)
            assert(not hit(game) and health.current == 45)
            boss.clock = Config.CORE_DEFENSE_CLOSED_SECONDS
            BossSystem.update(game, 0)
            assert(boss.warning == "ABRIENDO NUCLEO" and not hit(game))
            boss.clock = Config.CORE_DEFENSE_CLOSED_SECONDS + Config.BOSS_ACTION_WARNING
            BossSystem.update(game, 0)
            assert(hit(game) and health.current == 44 and game.world:count("EnemyProjectile") == 0)
            boss.clock = boss.clock + Config.CORE_DEFENSE_OPEN_SECONDS
            BossSystem.update(game, 0)
            assert(not game.world:get(game.bossId, "Damageable").enabled)
        end)

        test("Nucleo reparte 45 HP en tres fases y ningun daño masivo salta una fase", function()
            local game, boss, health = gameAt(10); expose(game)
            assert(hit(game, 1000) and health.current == 30 and boss.pendingPhase == 2)
            assert(not hit(game, 1000))
            BossSystem.update(game, 0)
            assert(boss.phase == 2 and boss.intro > 0 and not hit(game, 1000))
            stepBoss(game, 1.3)
            assert(hit(game, 1000) and health.current == 15 and boss.pendingPhase == 3)
            BossSystem.update(game, 0); stepBoss(game, 1.3)
            assert(boss.phase == 3 and hit(game, 1000) and health.current == 0)
            assert(game.state == "campaign_complete" and game.run.score == Config.BOSS_SCORE_VALUES.chaos_core)
        end)

        test("Fase de ataque avisa, fija el objetivo y emite una oleada esquivable sin seguimiento", function()
            local game, boss = gameAt(10); expose(game, 2)
            boss.attackClock = Config.CORE_ATTACK_INTERVALS[2] - Config.BOSS_ACTION_WARNING
            BossSystem.update(game, 0)
            local aimX = boss.aimX
            assert(aimX and boss.warning == "DISPARO" and game.world:count("EnemyProjectile") == 0)
            local angle, cx, cy, endpoint = Enemy.aim(game, game.bossId, -10000)
            assert(near(math.tan(angle), -Config.ENEMY_PROJECTILE_MAX_AIM_RATIO))
            assert(near(endpoint, cx + math.tan(angle) * (Helpers.paddle(game).position.y - cy)))
            Helpers.paddle(game).position.x = 0
            stepBoss(game, 0.8)
            assert(game.world:count("EnemyProjectile") == 1 and boss.aimX == nil)
            local shot = game.world:query("EnemyProjectile")[1]; local v = game.world:get(shot, "Velocity")
            local vx, vy = v.vx, v.vy
            assert(near(math.sqrt(vx*vx + vy*vy), 210) and vy > 0)
            Enemy.move(game, 0.1); Helpers.paddle(game).position.x = 800; Enemy.move(game, 0.1)
            assert(v.vx == vx and v.vy == vy and game.world:get(shot, "Position").y < Config.PADDLE_Y)
        end)

        test("Caos aumenta frecuencia, dispara abanicos y respeta limite y caducidad de proyectiles", function()
            local game, boss = gameAt(10); expose(game, 3)
            assert(Config.CORE_ATTACK_INTERVALS[3] < Config.CORE_ATTACK_INTERVALS[2])
            for _ = 1, 30 do Enemy.emit(game, game.bossId, 500) end
            assert(game.world:count("EnemyProjectile") == Config.MAX_ENEMY_PROJECTILES)
            local directions, destructible, armored = {}, false, false
            for _, id in ipairs(game.world:query("EnemyProjectile")) do
                local v, shot = game.world:get(id, "Velocity"), game.world:get(id, "EnemyProjectile")
                directions[string.format("%.1f", v.vx)] = true
                destructible, armored = destructible or shot.destructible, armored or not shot.destructible
                assert(near(math.sqrt(v.vx*v.vx + v.vy*v.vy), 240) and v.vy > 0)
            end
            local count = 0; for _ in pairs(directions) do count = count + 1 end
            assert(count == 3 and destructible and armored)
            Enemy.move(game, Config.ENEMY_PROJECTILE_LIFETIME)
            assert(game.world:count("EnemyProjectile") == 0)
        end)

        test("Laser intercepta proyectil rojo y respeta proyectil blindado sin sumar puntos", function()
            for _, destructible in ipairs({true, false}) do
                local game = gameAt(10); emptyBricks(game)
                game:activatePowerup("laser"); game:keypressed("space")
                local shots = game.world:query("Projectile"); game.world:destroy(shots[2])
                local p = game.world:get(shots[1], "Position")
                local enemy = bullet(game, p.x, 550, 0, 200, destructible)
                Enemy.move(game, 0.05); Projectiles.update(game, 0.05); Enemy.resolve(game)
                assert(game.world:has(enemy) == not destructible and not game.world:has(shots[1]))
                assert(game.run.score == 0 and game.run.combo.chain == 0)
            end
        end)

        test("Teletransporte anuncia destino, respeta posiciones y crea fantasmas sin barrer el camino", function()
            local game, boss = gameAt(10); expose(game, 3)
            boss.teleportClock = Config.CORE_TELEPORT_INTERVAL - Config.BOSS_ACTION_WARNING
            local p = game.world:get(game.bossId, "Position"); local oldX = p.x
            BossSystem.update(game, 0)
            assert(boss.warning == "TELETRANSPORTE" and p.x == oldX and boss.destinationX == game.level.boss.teleportPositions[1].x)
            stepBoss(game, 0.8)
            assert(p.x == game.level.boss.teleportPositions[1].x and boss.teleportIndex == 2)
            local previous = game.world:get(game.bossId, "PreviousPosition")
            assert(previous.previousX == p.x and game.world:get(game.bossId, "Velocity").vx == 0)
            assert(game.world:count("BossSupport", "Ghost") > 0 and boss.grace > 0)
        end)

        test("Destino ocupado retrasa teletransporte hasta que salga la pelota", function()
            local game, boss = gameAt(10); expose(game, 3)
            local target = game.level.boss.teleportPositions[1]
            local ball = Helpers.balls(game)[1]; ball.position.x, ball.position.y = target.x + 10, target.y + 10
            local p = game.world:get(game.bossId, "Position"); local x = p.x
            boss.teleportClock = Config.CORE_TELEPORT_INTERVAL
            BossSystem.update(game, 0)
            assert(p.x == x and boss.warning == "TELETRANSPORTE")
            ball.position.y = 500; BossSystem.update(game, 0)
            assert(p.x == target.x and boss.teleportIndex == 2)
        end)

        test("Golpe enemigo con 90 pelotas cuesta una vida y conserva poderes y salud del jefe", function()
            local game, _, health = gameAt(10); expose(game, 2); hit(game)
            local hp, remaining = health.current, game.remaining
            Helpers.setBallCount(game, 90)
            game:activatePowerup("fireball"); game:activatePowerup("laser"); game:keypressed("space")
            local paddle = Helpers.paddle(game)
            game.world:get(game.paddleId, "Invulnerability").remaining = 0
            for _ = 1, 5 do bullet(game, paddle.position.x + 20, paddle.position.y, 0, 200, true) end
            assert(Enemy.resolve(game))
            assert(game.lives == 2 and game.world:count("Ball") == 1 and game.remaining == remaining and health.current == hp)
            local timers, power = Effects.get(game)
            assert(game.world:count("EnemyProjectile") == 4 and game.world:count("Projectile") == 2)
            assert(timers.fireball == Config.FIREBALL_SECONDS and power.ammo == Config.LASER_AMMO - 1)
            assert(game.world:get(game.paddleId, "Invulnerability").remaining == 2)
            assert(not Enemy.resolve(game) and game.world:count("EnemyProjectile") == 0 and game.lives == 2)
        end)

        test("Invulnerabilidad evita daños sucesivos y deja de proteger al expirar", function()
            local game = gameAt(10)
            local function impact()
                local p = Helpers.paddle(game).position
                bullet(game, p.x + 20, p.y, 0, 200, true)
                return Enemy.resolve(game)
            end
            assert(not impact() and game.lives == 3 and game.world:count("EnemyProjectile") == 0)
            Enemy.updateInvulnerability(game, 1.9); assert(not impact() and game.lives == 3)
            Enemy.updateInvulnerability(game, 0.11); assert(impact() and game.lives == 2)
            assert(not impact() and game.lives == 2)
        end)

        test("Barrido enemigo detecta paddle fino y su movimiento horizontal", function()
            local game = gameAt(10); local paddle = Helpers.paddle(game)
            game.world:get(game.paddleId, "Invulnerability").remaining = 0
            bullet(game, paddle.position.x + 20, paddle.position.y - 20, 0, 1000, true)
            Enemy.move(game, 0.05); assert(Enemy.resolve(game) and game.lives == 2)
            paddle = Helpers.paddle(game)
            local previous = game.world:get(game.paddleId, "PreviousPosition")
            previous.previousX, paddle.position.x = 300, 500
            game.world:get(game.paddleId, "Invulnerability").remaining = 0
            bullet(game, 450, paddle.position.y, 0, 0, true)
            assert(Enemy.resolve(game) and game.lives == 1)
        end)

        test("Ultima pelota y ataque en el mismo frame descuentan solo una vida", function()
            local game = gameAt(10)
            local p = Helpers.paddle(game).position
            game.world:get(game.paddleId, "Invulnerability").remaining = 0
            bullet(game, p.x + 20, p.y, 0, 200, true)
            local ball = Helpers.balls(game)[1]
            ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = 900, 640, 0, 400
            game:update(0)
            -- La reposicion no borra ataques: la invulnerabilidad consume el contacto al reanudar.
            assert(game.lives == 2 and game.world:count("EnemyProjectile") == 1)
            game:update(0)
            assert(game.lives == 2 and game.world:count("Ball") == 1 and game.world:count("EnemyProjectile") == 0)
        end)

        test("Ataque letal produce GAME OVER sin pelotas ni ataques; R reconstruye jefe y bloques", function()
            local game, _, health = gameAt(10); expose(game, 2); hit(game)
            local oldBoss = game.bossId
            game.lives = 1
            game.world:get(game.paddleId, "Invulnerability").remaining = 0
            Helpers.setBallCount(game, 90)
            local p = Helpers.paddle(game).position; bullet(game, p.x + 20, p.y, 0, 200, true)
            assert(Enemy.resolve(game))
            assert(game.state == "game_over" and game.lives == 0 and game.world:count("Ball") == 0 and health.current == 44)
            game:keypressed("r"); Helpers.finishIntro(game)
            assert(game.state == "playing" and game.lives == 3 and game.bossId > oldBoss and not game.world:has(oldBoss))
            assert(game.world:get(game.bossId, "Health").current == 45 and game.world:get(game.bossId, "Boss").phase == 1)
        end)

        test("Vencer al jefe gana con bloques restantes, recompensa unica y guardado anterior a transicion", function()
            for _, index in ipairs({5, 10}) do
                local game, boss, health = gameAt(index); expose(game, index == 10 and 3 or 1)
                health.current = 1
                local remaining, writes = game.remaining, game.progressStore.filesystem.writes
                assert(hit(game))
                local expected = Config.BOSS_SCORE_VALUES[boss.kind]
                assert(game.remaining == remaining and remaining > 0 and game.lives == 4 and game.run.score == expected)
                assert(game.state == (index == 5 and "level_complete" or "campaign_complete") and game.run.levelResult)
                assert(game.progressStore.filesystem.writes == writes + 2 and not hit(game) and not game:completeLevel())
                assert(game.run.score == expected)
                if index == 5 then game:update(2); Helpers.finishIntro(game); assert(game.levelIndex == 6 and game.world:count("Boss") == 0) end
            end
        end)

        test("Victoria por pelota y laser tiene prioridad sobre ataques letales en el mismo frame", function()
            for _, source in ipairs({"ball", "laser"}) do
                local game, _, health = gameAt(10); expose(game, 3); health.current = 1; game.lives = 1
                local p = Helpers.paddle(game).position
                game.world:get(game.paddleId, "Invulnerability").remaining = 0
                bullet(game, p.x + 20, p.y, 0, 200, true)
                if source == "ball" then aim(game, Helpers.balls(game)[1])
                else
                    game:activatePowerup("laser"); game:keypressed("space")
                    local shots = game.world:query("Projectile"); game.world:destroy(shots[2])
                    local bp, bc = game.world:get(game.bossId, "Position"), game.world:get(game.bossId, "Collider")
                    local shot = game.world:get(shots[1], "Position"); shot.x, shot.y = bp.x + bc.w / 2, bp.y + bc.h + 1
                end
                game:update(0.05)
                assert(game.state == "campaign_complete" and game.lives == 2 and game.world:count("EnemyProjectile") == 0)
            end
        end)

        test("Derrota anima al jefe sin generar entidades y termina tambien en la victoria final", function()
            local game, boss, health = gameAt(10); expose(game, 3); health.current = 1; hit(game)
            local count = game.world:count()
            game:update(0.3)
            assert(boss.defeatElapsed == 0.3 and game.world:get(game.bossId, "Renderable").alpha < 1)
            game:update(10)
            assert(boss.defeatElapsed == Config.BOSS_DEFEAT_SECONDS and game.world:count() == count)
            assert(game.world:get(game.bossId, "Renderable").alpha == 0 and game.state == "campaign_complete")
        end)

        test("Menu congela jefe, proyectiles y proteccion; reinicio limpia entidades antiguas", function()
            local game, boss = gameAt(10); expose(game, 2); Enemy.emit(game, game.bossId, 500)
            local shot = game.world:query("EnemyProjectile")[1]
            local y, clock = game.world:get(shot, "Position").y, boss.clock
            local protection = game.world:get(game.paddleId, "Invulnerability").remaining
            game:goToMenu(); game:update(20)
            assert(game.world:get(shot, "Position").y == y and boss.clock == clock)
            assert(game.world:get(game.paddleId, "Invulnerability").remaining == protection)
            local old = game.bossId; game:reset(); Helpers.finishIntro(game)
            assert(not game.world:has(old) and not game.world:has(shot) and not game.bossId and game.world:count("Ball") == 1)
        end)

        test("Ambos jefes pueden vencerse con pelotas normales sin poderes aleatorios", function()
            for _, index in ipairs({5, 10}) do
                local game = gameAt(index)
                Helpers.defeatBoss(game)
                assert(game.world:get(game.bossId, "Health").current == 0 and game.run.score > 0)
                assert(game.world:count("PowerUp") == 0)
            end
        end)

        test("ECS_ASSIGNMENT_MODE conserva prioridad con jefe, ataques y 90 pelotas", function()
            for _, x in ipairs({0, Config.WIDTH - Config.BALL_SIZE}) do
                local game, _, health = gameAt(10); expose(game, 3); Enemy.emit(game, game.bossId, 500)
                Helpers.setBallCount(game, 90)
                local ball = Helpers.balls(game)[90]
                ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = x, 400, x == 0 and -330 or 330, -440
                Config.ECS_ASSIGNMENT_MODE = true; quits = 0
                local count = game.world:count("EnemyProjectile")
                game:update(0); game:update(0.05)
                assert(quits == 1 and game.quitRequested and game.lives == 3 and health.current == 45)
                assert(game.world:count("EnemyProjectile") == count and game.run.score == 0)
                Config.ECS_ASSIGNMENT_MODE = false
            end
        end)

        test("Canvas real muestra salud, fases, punto debil y victoria especial sin recursos por frame", function()
            local game, boss, health = gameAt(10); expose(game, 3)
            local canvas = love.graphics.newCanvas(Config.WIDTH, Config.HEIGHT)
            local newFont, printf = love.graphics.newFont, love.graphics.printf
            local labels = {}
            love.graphics.newFont = function() error("Fuente creada durante frame") end
            love.graphics.printf = function(text, ...) labels[text] = true; return printf(text, ...) end
            local success, failure = xpcall(function()
                love.graphics.setCanvas(canvas); game:draw(); love.graphics.setCanvas()
                assert(labels["45 / 45   |   Fase 3 / 3 - Caos"] and labels.GOLPEA)
                health.current = 1; hit(game)
                love.graphics.setCanvas(canvas); game:draw(); love.graphics.setCanvas()
                assert(labels["YOU WIN!"] and labels["NUCLEO DEL CAOS DESACTIVADO"])
                assert(labels["Defensa, Ataque y Caos superados"])
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

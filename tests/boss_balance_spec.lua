local Config = require("src.config")
local H = require("tests.helpers")
local BossRules = require("src.boss_rules")
local LevelManager = require("src.level_manager")
local Powerups = require("src.powerups")
local Effects = require("src.ecs.systems.power_effect_system")
local BossSystem = require("src.ecs.systems.boss_system")
local BossRender = require("src.ecs.systems.boss_render_system")
local Damage = require("src.ecs.systems.damage_system")
local Collisions = require("src.ecs.systems.collision_system")
local Projectiles = require("src.ecs.systems.projectile_system")

local function near(a, b) return math.abs(a - b) < .000001 end
local function at(index)
    local game = H.newGame(); game.progress.maxUnlocked = 10; H.startCampaign(game, index)
    return game
end
local function expose(game)
    local boss = game.world:get(game.bossId, "Boss")
    boss.intro, boss.hitCooldown = 0, 0
    game.world:get(game.bossId, "Damageable").enabled = true
    return boss
end
local function scarce(game, count)
    local keep = {}; for i = 1, count or 0 do keep[i] = i end
    H.keepBricks(game, keep)
end
local function clearPowers(game)
    for _, id in ipairs(game.world:query("PowerUp")) do game.world:destroy(id) end
end
local function configure(game, key, value)
    local config = {}; for k, v in pairs(game.config) do config[k] = v end
    config[key] = value; game.config = config
end

local function run()
    local random, keyboard = love.math.random, love.keyboard.isDown
    local roll, calls, passed = .99, 0, 0
    love.math.random = function() calls = calls + 1; return roll end
    love.keyboard.isDown = function() return false end
    local function test(name, fn)
        roll, calls = .99, 0; fn(); passed = passed + 1; print("OK BALANCE " .. passed .. ": " .. name)
    end
    local ok, err = xpcall(function()
        test("Ambos puntos debiles crecen 60 por ciento por eje sin cambiar cuerpo ni salud", function()
            for _, index in ipairs({5, 10}) do
                local game = at(index); local base = game.level.boss.weakPoint
                for _ = 1, 3 do
                    local definition = game.world:get(game.bossId, "BossBehavior")
                    local weak, body = definition.weakPoint, game.world:get(game.bossId, "Collider")
                    assert(near(weak.w, base.w * 1.6) and near(weak.h, base.h * 1.6))
                    assert(near(weak.w / weak.h, base.w / base.h) and near(weak.y + weak.h, body.h))
                    assert(near(weak.x + weak.w / 2, base.x + base.w / 2))
                    assert(body.w == 160 and body.h == (index == 5 and 60 or 70))
                    assert(game.world:get(game.bossId, "Health").maximum == (index == 5 and 10 or 23))
                    assert(game.level.boss.weakPoint.w == (index == 5 and 56 or 60))
                    assert(definition.motion.amplitude == 160 and (index == 5 or #definition.phases == 3))
                    game:restartLevel(); H.finishIntro(game)
                end
            end
        end)

        test("Multiplicador configurable mantiene proporcion y limita la ampliacion al cuerpo", function()
            local game = at(10); local definition = game.level.boss
            for _, multiplier in ipairs({1, 1.6, 10}) do
                configure(game, "BOSS_WEAK_POINT_SIZE_MULTIPLIER", multiplier)
                local weak = BossRules.weakPoint(definition, game.config)
                assert(weak.x >= 0 and weak.y >= 0 and weak.x + weak.w <= definition.w)
                assert(near(weak.y + weak.h, definition.h) and near(weak.w / weak.h, 60 / 22))
                if multiplier == 1 then assert(weak.w == 60 and weak.h == 22) end
                if multiplier == 10 then assert(near(weak.w, definition.w)) end
                for _, target in ipairs(definition.teleportPositions) do
                    assert(target.x + weak.x >= 0 and target.x + weak.x + weak.w <= Config.WIDTH)
                    assert(target.y + weak.y >= 0 and target.y + weak.y + weak.h <= Config.HEIGHT)
                end
            end
        end)

        test("Validacion rechaza multiplicadores y suministro invalidos", function()
            local game = at(5)
            for _, key in ipairs({"BOSS_WEAK_POINT_SIZE_MULTIPLIER", "BOSS_LASER_DROP_WEIGHT_MULTIPLIER", "BOSS_LASER_SUPPLY_INTERVAL"}) do
                for _, value in ipairs({0, -1, math.huge, 0/0}) do
                    local config = {}; for k, v in pairs(Config) do config[k] = v end
                    config[key] = value
                    assert(not pcall(LevelManager.prepare, game.level, config), key)
                end
            end
            for key, value in pairs({BOSS_LASER_SUPPLY_CHANCE = 1.1, BOSS_LASER_SUPPLY_BLOCK_THRESHOLD = .5}) do
                local config = {}; for k, v in pairs(Config) do config[k] = v end
                config[key] = value; assert(not pcall(LevelManager.prepare, game.level, config))
            end
        end)

        test("Pelotas normales y de fuego golpean ambos extremos nuevos a 550 px/s", function()
            for _, index in ipairs({5, 10}) do
                for _, fire in ipairs({false, true}) do
                    for _, right in ipairs({false, true}) do
                        local game = at(index); expose(game); scarce(game)
                        if fire then game:activatePowerup("fireball") end
                        local p, c = game.world:get(game.bossId, "Position"), game.world:get(game.bossId, "Collider")
                        local weak = game.world:get(game.bossId, "BossBehavior").weakPoint
                        local x = p.x + weak.x + (right and weak.w - .5 or .5)
                        local base = game.level.boss.weakPoint
                        assert(x < p.x + base.x or x > p.x + base.x + base.w)
                        local ball = H.balls(game)[1]
                        ball.position.x, ball.position.y = x - ball.collider.w / 2, p.y + c.h + 1
                        ball.velocity.vx, ball.velocity.vy = 0, -550
                        Collisions.update(game, .05)
                        assert(game.world:get(game.bossId, "Health").current == game.level.boss.health - 1)
                        assert(near(ball.velocity.vy, 550) and ball.velocity.vx == 0)
                    end
                end
            end
        end)

        test("Laser barrido distingue dentro y fuera del punto ampliado durante movimiento", function()
            for _, index in ipairs({5, 10}) do
                for _, right in ipairs({false, true}) do
                    for _, valid in ipairs({false, true}) do
                        local game = at(index); expose(game); scarce(game)
                        game:activatePowerup("laser"); game:keypressed("space")
                        local shots = game.world:query("Projectile"); game.world:destroy(shots[2])
                        local p, c = game.world:get(game.bossId, "Position"), game.world:get(game.bossId, "Collider")
                        local previous = game.world:get(game.bossId, "PreviousPosition")
                        previous.previousX, p.x = 400, 410
                        local weak = game.world:get(game.bossId, "BossBehavior").weakPoint
                        local edge = 402.5 + weak.x + (right and weak.w or 0)
                        local shot, size = game.world:get(shots[1], "Position"), game.world:get(shots[1], "Collider")
                        shot.x = edge + (right and -1 or 1) * (valid and .25 or -.25) - size.w / 2
                        shot.y = p.y + c.h + Config.LASER_SPEED * .02 * .25
                        Projectiles.update(game, .02)
                        assert(not game.world:has(shots[1]))
                        assert(game.world:get(game.bossId, "Health").current == game.level.boss.health - (valid and 1 or 0))
                    end
                end
            end
        end)

        test("Dibujo y daño comparten rectangulo ampliado y conservan la proteccion", function()
            local canvas = love.graphics.newCanvas(Config.WIDTH, Config.HEIGHT)
            local rectangle = love.graphics.rectangle
            local drawn = {}
            love.graphics.rectangle = function(mode, x, y, w, h, ...)
                if mode == "fill" then drawn[#drawn + 1] = {x = x, y = y, w = w, h = h, color = {love.graphics.getColor()}} end
                return rectangle(mode, x, y, w, h, ...)
            end
            local success, failure = xpcall(function()
                for _, index in ipairs({5, 10}) do
                    local game = at(index); local boss = expose(game)
                    local p = game.world:get(game.bossId, "Position")
                    local weak = game.world:get(game.bossId, "BossBehavior").weakPoint
                    for _, open in ipairs({false, true}) do
                        boss.hitCooldown = 0; game.world:get(game.bossId, "Damageable").enabled = open
                        drawn = {}; love.graphics.setCanvas(canvas); BossRender.body(game, game.bossId); love.graphics.setCanvas()
                        local rect = assert(drawn[1])
                        assert(near(rect.x, p.x + weak.x) and near(rect.y, p.y + weak.y) and rect.w == weak.w and rect.h == weak.h)
                        assert(near(rect.color[2], open and 1 or .43))
                        assert(not Damage.hit(game, game.bossId, 1, "ball", rect.x - .1, rect.y + 1))
                        assert(not Damage.hit(game, game.bossId, 1, "ball", rect.x + 1, rect.y - .1))
                        assert(Damage.hit(game, game.bossId, 1, "ball", rect.x + 1, rect.y + 1) == open)
                    end
                end
            end, debug.traceback)
            love.graphics.setCanvas(); love.graphics.rectangle = rectangle; canvas:release(); assert(success, failure)
        end)

        test("Los diez niveles mantienen 15 por ciento total; solo jefes triplican peso laser", function()
            local game = H.newGame()
            for index = 1, 10 do
                local level, counts, total = game.levels:get(index), {}, 0
                local weight = 0
                for _, kind in ipairs(level.activePowerups) do
                    weight = weight + Config.POWERUP_TYPES[kind].weight * (level.boss and kind == "laser" and 3 or 1)
                end
                local before = calls
                for n = 0, 9999 do
                    roll = (n + .5) / 10000
                    local id = Powerups.trySpawn(game.world, Config, {x = 100, y = 200}, {w = 50, h = 25},
                        level.difficulty.dropChance, level.activePowerups, level.boss)
                    if id then
                        local kind = game.world:get(id, "PowerUp").kind
                        counts[kind], total = (counts[kind] or 0) + 1, total + 1; game.world:destroy(id)
                    end
                end
                assert(total == 1500 and calls - before == 10000)
                for _, kind in ipairs(level.activePowerups) do
                    local expected = 1500 * Config.POWERUP_TYPES[kind].weight * (level.boss and kind == "laser" and 3 or 1) / weight
                    assert(math.abs(counts[kind] - expected) <= 1, "Peso incorrecto en nivel " .. index .. ": " .. kind)
                end
            end
            assert(Config.POWERUP_TYPES.laser.weight == 10)
        end)

        test("Peso configurable sin depender del numero del nivel ni mutar pesos globales", function()
            local game = at(5); game.levelIndex = 1 -- El marcador boss, no el indice, activa el balance.
            roll = .105
            local normal = Powerups.trySpawn(game.world, Config, {x = 0, y = 0}, {w = 1, h = 1}, .15, game.level.activePowerups)
            assert(game.world:get(normal, "PowerUp").kind == "fireball"); clearPowers(game)
            local brick
            for _, id in ipairs(game.world:query("Brick")) do if game.world:get(id, "Brick").kind == "normal" then brick = id; break end end
            assert(Damage.hit(game, brick, 1, "ball"))
            assert(H.powers(game)[1].powerUp.kind == "laser"); clearPowers(game)
            configure(game, "BOSS_LASER_DROP_WEIGHT_MULTIPLIER", 1)
            local id = Powerups.trySpawn(game.world, game.config, {x = 0, y = 0}, {w = 1, h = 1}, .15,
                game.level.activePowerups, game.level.boss)
            assert(game.world:get(id, "PowerUp").kind == "fireball" and Config.POWERUP_TYPES.laser.weight == 10)
        end)

        test("Protectores sueltan laser una vez por destruccion, sin puntos ni premios al caducar", function()
            for _, kind in ipairs({"resistant", "ghost"}) do
                local game = at(5); expose(game); scarce(game); BossSystem.support(game, kind)
                local id = assert(game.world:query("BossSupport")[1]); local health = game.world:get(id, "Health")
                roll = .105; local before = calls
                if health.current > 1 then Damage.hit(game, id, health.current - 1, "ball"); assert(calls == before) end
                Damage.hit(game, id, 1, "ball")
                for _ = 1, 90 do assert(not Damage.hit(game, id, 1, "ball")) end
                assert(calls == before + 1 and game.world:count("PowerUp") == 1 and H.powers(game)[1].powerUp.kind == "laser")
                assert(game.run.score == 0 and game.run.combo.chain == 0)
                for _, support in ipairs(game.world:query("BossSupport")) do game.world:get(support, "BossSupport").remaining = .01 end
                game.world:get(game.bossId, "Boss").intro = 1; BossSystem.update(game, .05)
                assert(game.world:count("BossSupport") == 0 and calls == before + 1 and game.world:count("PowerUp") == 1)
            end
        end)

        test("Suministro escaso intenta cada 20 s con 50 por ciento y admite fallos", function()
            local game = at(5); expose(game); local _, power = Effects.get(game)
            roll = 0; Powerups.bossSupply(game, 20)
            assert(calls == 0 and game.world:count("PowerUp") == 0, "No ayudar mientras quedan muchos bloques")
            scarce(game, 3); BossSystem.support(game, "resistant")
            assert(game.world:count("Brick") > 3)
            roll = .5; Powerups.bossSupply(game, 19.9); assert(calls == 0)
            Powerups.bossSupply(game, .1); assert(calls == 1 and game.world:count("PowerUp") == 0)
            roll = .499; local id = Powerups.bossSupply(game, 20)
            assert(calls == 2 and id and game.world:get(id, "PowerUp").kind == "laser" and near(power.bossLaserElapsed, 0))
            local p, c = game.world:get(id, "Position"), game.world:get(id, "Collider")
            assert(p.x >= 0 and p.x + c.w <= Config.WIDTH and p.y >= Config.BRICK_TOP)
        end)

        test("Suministro respeta cupo, laser caido, municion y poderes desbloqueados", function()
            local game = at(10); expose(game); scarce(game); roll = 0
            for _ = 1, Config.MAX_FALLING_POWERUPS do Powerups.spawn(game.world, Config, "fireball", 100, 300) end
            local oldest = H.powers(game)[1].id
            Powerups.bossSupply(game, 20)
            assert(calls == 0 and game.world:count("PowerUp") == 12 and game.world:has(oldest))
            clearPowers(game); Powerups.spawn(game.world, Config, "laser", 100, 300)
            Powerups.bossSupply(game, 20); assert(calls == 0 and game.world:count("PowerUp") == 1)
            clearPowers(game); game:activatePowerup("laser"); Powerups.bossSupply(game, 20); assert(calls == 0)
            local _, power = Effects.get(game); power.ammo = 0
            game.level.activePowerups = {"multiball", "fireball"}
            Powerups.bossSupply(game, 20); assert(calls == 0 and game.world:count("PowerUp") == 0)
        end)

        test("Suministro inactivo sin jefe, durante entrada, pausa, resultados o cierre", function()
            for _, index in ipairs({1, 2, 3, 4, 6, 7, 8, 9}) do
                local game = at(index); scarce(game); Powerups.bossSupply(game, 100)
                assert(calls == 0 and game.world:count("PowerUp") == 0)
            end
            local game = at(5); scarce(game); local _, power = Effects.get(game)
            Powerups.bossSupply(game, 20); assert(power.bossLaserElapsed == 0)
            local boss = expose(game)
            for _, state in ipairs({"menu", "level_select", "options", "paused", "level_intro", "level_complete", "game_over", "campaign_complete"}) do
                game.state = state; Powerups.bossSupply(game, 100)
                assert(power.bossLaserElapsed == 0 and calls == 0)
            end
            game.state, boss.defeated = "playing", true; Powerups.bossSupply(game, 100)
            boss.defeated, game.quitRequested = false, true; Powerups.bossSupply(game, 100)
            assert(power.bossLaserElapsed == 0 and calls == 0 and game.world:count("PowerUp") == 0)
        end)

        test("Suministro usa dt, valores configurables y descarta intervalos atrasados", function()
            for _, frames in ipairs({1, 200}) do
                local game = at(5); expose(game); scarce(game)
                configure(game, "BOSS_LASER_SUPPLY_INTERVAL", 10)
                configure(game, "BOSS_LASER_SUPPLY_CHANCE", .25)
                roll = .249; local before = calls
                for _ = 1, frames do Powerups.bossSupply(game, 10 / frames) end
                assert(calls == before + 1 and game.world:count("PowerUp") == 1)
                clearPowers(game); before = calls; Powerups.bossSupply(game, 1000)
                assert(calls == before + 1 and game.world:count("PowerUp") == 1)
            end
        end)

        test("Integracion conserva reloj en pausa y al perder vida; reiniciar lo limpia", function()
            local game = at(5); expose(game); scarce(game)
            local _, power = Effects.get(game); power.bossLaserElapsed = 19.98; roll = 0
            game:update(.01); local clock = power.bossLaserElapsed
            game:keypressed("p"); game:update(100)
            assert(power.bossLaserElapsed == clock and calls == 0)
            game:keypressed("p"); game:update(.01)
            assert(game.world:count("PowerUp") == 1 and H.powers(game)[1].powerUp.kind == "laser")
            power.bossLaserElapsed = 7
            local pickup = H.powers(game)[1].id
            game:loseLife(); _, power = Effects.get(game)
            assert(power.bossLaserElapsed == 7 and game.world:has(pickup, "PowerUp") and game.world:count("PowerUp") == 1)
            power.bossLaserElapsed = 19; game:restartLevel(); _, power = Effects.get(game)
            assert(power.bossLaserElapsed == 0 and game.state == "level_intro")
        end)

        test("Ambos jefes siguen vencibles con impactos reales de pelota normal", function()
            for _, index in ipairs({5, 10}) do
                local game = at(index); scarce(game)
                local boss, ball = game.world:get(game.bossId, "Boss"), H.balls(game)[1]
                for _ = 1, 12000 do
                    if boss.defeated then break end
                    ball.position.x, ball.position.y = 480, 500; ball.velocity.vx, ball.velocity.vy = 0, 0
                    Collisions.update(game, 0) -- Separacion real libera el contacto anterior.
                    BossSystem.update(game, .05)
                    local p, c = game.world:get(game.bossId, "Position"), game.world:get(game.bossId, "Collider")
                    ball.position.x, ball.position.y = p.x + c.w / 2 - ball.collider.w / 2, p.y + c.h + 1
                    ball.velocity.vx, ball.velocity.vy = 0, -400
                    Collisions.update(game, .01)
                end
                assert(boss.defeated and game.world:get(game.bossId, "Health").current == 0)
                local _, power = Effects.get(game)
                assert(power.ammo == 0 and game.world:count("Projectile") == 0 and not game.world:get(ball.id, "Ball").fire)
                assert(game.state == (index == 5 and "level_complete" or "campaign_complete"))
            end
        end)
    end, debug.traceback)
    love.math.random, love.keyboard.isDown = random, keyboard
    if not ok then error(err, 0) end
    return passed
end

return {run = run}

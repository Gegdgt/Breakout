local Config = require("src.config")
local H = require("tests.helpers")
local Bricks = require("src.bricks")
local Damage = require("src.ecs.systems.damage_system")
local Explosion = require("src.ecs.systems.explosion_system")
local Collision = require("src.collision")
local Collisions = require("src.ecs.systems.collision_system")
local Projectiles = require("src.ecs.systems.projectile_system")
local Ghost = require("src.ecs.systems.ghost_system")
local Motion = require("src.ecs.systems.motion_system")
local BossSystem = require("src.ecs.systems.boss_system")
local Portals = require("src.ecs.systems.portal_system")
local Powerups = require("src.powerups")
local Encyclopedia = require("src.ui.encyclopedia")
local LevelManager = require("src.level_manager")
local Components = require("src.ecs.components")

local function near(a, b) return math.abs(a - b) < 0.00001 end
local function at(index)
    local game = H.newGame(); game.progress.maxUnlocked = 10; H.startCampaign(game, index)
    return game
end
local function empty()
    local game = at(1)
    for _, id in ipairs(game.world:query("Brick")) do game.world:destroy(id) end
    return game
end
local function add(game, symbol, row, column)
    local id = Bricks.spawn(game.world, game.config, game.level, {key = row .. ":" .. column,
        row = row, column = column, x = 100 + (column - 1) * 70, y = 160 + (row - 1) * 30,
        w = 65, h = 25, color = {1, 0.3, 0.3}, definition = game.level.brickTypes[symbol]})
    game.remaining = Bricks.remaining(game.world)
    return id
end
local function expose(game)
    local b = game.world:get(game.bossId, "Boss")
    b.intro, b.hitCooldown = 0, 0
    game.world:get(game.bossId, "Damageable").enabled = true
    return b
end
local function capture(game, name)
    local directory = os.getenv("BREAKOUT_CAPTURE_DIR")
    if not directory then return end
    local canvas = love.graphics.newCanvas(game.config.WIDTH, game.config.HEIGHT)
    love.graphics.push("all"); love.graphics.setCanvas(canvas); game:draw(); love.graphics.pop()
    local file = assert(io.open(directory .. "/" .. name .. ".png", "wb"))
    file:write(canvas:newImageData():encode("png"):getString()); file:close(); canvas:release()
end

-- Accesibilidad geométrica conservadora: pelota de tamaño real, cuadrícula fina,
-- irrompibles permanentes y envolvente completa de los obstáculos móviles.
-- Marca los objetivos cuyo borde es accesible y los retira por capas, sin atravesarlos.
local function peelReachable(game)
    local step, half = 5, Config.BALL_SIZE / 2
    local width, height = math.floor(Config.WIDTH / step), math.floor(500 / step)
    local targets, permanent = {}, {}
    for _, id in ipairs(game.world:query("Brick", "Position", "Collider")) do
        local p, c = game.world:get(id, "Position"), game.world:get(id, "Collider")
        local r = {x = p.x - half, y = p.y - half, w = c.w + 2 * half, h = c.h + 2 * half, id = id}
        if game.world:get(id, "Brick").kind == "unbreakable" then permanent[#permanent + 1] = r
        else targets[id] = r end
    end
    for _, id in ipairs(game.world:query("MovingObstacle")) do
        local m, c = game.world:get(id, "Motion"), game.world:get(id, "Collider")
        permanent[#permanent + 1] = {x = m.originX - m.amplitudeX - half, y = m.originY - m.amplitudeY - half,
            w = c.w + 2 * m.amplitudeX + 2 * half, h = c.h + 2 * m.amplitudeY + 2 * half}
    end
    local total = 0
    while next(targets) do
        local blocked, touched, queue, seen = {}, {}, {}, {}
        local function fill(r, id)
            for y = math.max(2, math.ceil(r.y / step)), math.min(height, math.floor((r.y + r.h) / step)) do
                for x = math.max(2, math.ceil(r.x / step)), math.min(width - 2, math.floor((r.x + r.w) / step)) do
                    local key = y * width + x
                    if blocked[key] ~= true then blocked[key] = id or true end
                end
            end
        end
        for _, r in ipairs(permanent) do fill(r) end
        for id, r in pairs(targets) do fill(r, id) end
        for x = 2, width - 2 do
            local key = height * width + x
            if not blocked[key] then queue[#queue + 1] = key; seen[key] = true end
        end
        local head = 1
        while head <= #queue do
            local key = queue[head]; head = head + 1
            for _, delta in ipairs({-1, 1, -width, width}) do
                local neighbor = key + delta
                local x, y = neighbor % width, math.floor(neighbor / width)
                if x >= 2 and x <= width - 2 and y >= 2 and y <= height and not seen[neighbor] then
                    seen[neighbor] = true
                    local obstruction = blocked[neighbor]
                    if type(obstruction) == "number" then touched[obstruction] = true
                    elseif not obstruction then queue[#queue + 1] = neighbor end
                end
            end
        end
        assert(next(touched), "Objetivos encerrados en nivel " .. game.levelIndex)
        for id in pairs(touched) do targets[id] = nil; total = total + 1 end
    end
    return total
end

local function run()
    local keyboard, random = love.keyboard.isDown, love.math.random
    local rolls, passed = 0, 0
    love.keyboard.isDown = function() return false end
    love.math.random = function() rolls = rolls + 1; return 0.99 end
    local function test(name, fn)
        fn(); passed = passed + 1; print("OK ARCADE " .. passed .. ": " .. name)
    end
    local ok, err = xpcall(function()
        test("Irrompible sin salud, puntos, poderes ni destruccion por ninguna fuente", function()
            local game = empty(); local id = add(game, "U", 1, 1); add(game, "N", 9, 9)
            local before = rolls
            for _, source in ipairs({"ball", "fireball", "laser", "explosion"}) do
                for _ = 1, 100 do assert(not Damage.hit(game, id, 1000, source)) end
            end
            assert(not Bricks.destroy(game, id) and game.world:has(id, "Brick"))
            assert(not game.world:has(id, "Health") and not game.world:has(id, "ScoreValue"))
            assert(rolls == before and game.run.score == 0 and game.world:count("PowerUp") == 0)
            assert(game.world:get(id, "Brick").dropChance == 0 and game.feedback.count > 0)
        end)

        test("Pelotas normales y fuego rebotan; laser se consume contra el irrompible", function()
            for _, fire in ipairs({false, true}) do
                local game = empty(); local id = add(game, "U", 2, 2); add(game, "N", 9, 9)
                if fire then game:activatePowerup("fireball") end
                local b, p = H.balls(game)[1], game.world:get(id, "Position")
                b.position.x, b.position.y, b.velocity.vx, b.velocity.vy = p.x + 20, p.y - b.collider.h - 1, 0, 550
                Collisions.update(game, .05)
                assert(b.velocity.vy == -550 and b.position.y + b.collider.h <= p.y and game.world:has(id))
                local shot = game.world:create({Position = Components.position(p.x + 20, p.y + 30),
                    Velocity = Components.velocity(0, -720), Collider = Components.collider(4, 14), Projectile = Components.projectile(Config)})
                Projectiles.update(game, .05)
                assert(not game.world:has(shot) and game.world:has(id))
            end
        end)

        test("Cinco irrompibles permiten victoria; no sustituyen la derrota del jefe", function()
            for _, index in ipairs({1, 5, 10}) do
                local game = at(index)
                for _, id in ipairs(game.world:query("Brick")) do game.world:destroy(id) end
                for col = 1, 5 do add(game, "U", 9, col) end
                local target = add(game, "N", 8, 8)
                assert(game.remaining == 1); Damage.hit(game, target, 1, "ball")
                assert(game.remaining == 0 and game.world:count("Brick") == 5)
                assert(game.state == (index == 1 and "level_complete" or "playing"))
                if index ~= 1 then H.defeatBoss(game) end
                assert(game.state == (index == 10 and "campaign_complete" or "level_complete"))
            end
        end)

        test("Vida redondeada a la mitad y fases a 15 y 8 HP sin saltos", function()
            for _, item in ipairs({{5, 20}, {10, 45}}) do
                local game = at(item[1]); local hp = game.world:get(game.bossId, "Health")
                assert(hp.maximum == math.ceil(item[2] / 2) and hp.current == hp.maximum)
                if item[1] == 10 then
                    for phase, threshold in ipairs({15, 8, 0}) do
                        local boss = expose(game); assert(boss.phase == phase)
                        local p = game.world:get(game.bossId, "Position")
                        assert(Damage.hit(game, game.bossId, 1000, "ball", p.x + 80, p.y))
                        assert(hp.current == threshold and not Damage.hit(game, game.bossId, 1000, "ball", p.x + 80, p.y))
                        if phase < 3 then
                            assert(math.abs(threshold / hp.maximum - (phase == 1 and 2 / 3 or 1 / 3)) < .03)
                            BossSystem.update(game, 0)
                            assert(boss.phase == phase + 1 and boss.intro > 0)
                        end
                    end
                    assert(game.state == "campaign_complete")
                end
                game:restartLevel(); H.finishIntro(game)
                assert(game.world:get(game.bossId, "Health").maximum == math.ceil(item[2] / 2))
            end
        end)

        test("Cruz exacta: cuatro vecinos, sin diagonales, sin segunda celda y particulas axiales", function()
            local game = empty(); local ids = {}
            for row = 1, 3 do
                for col = 1, 3 do ids[row .. ":" .. col] = add(game, row == 2 and col == 2 and "E" or "R", row, col) end
            end
            local far = add(game, "R", 2, 4)
            Damage.hit(game, ids["2:2"], 1, "ball"); Explosion.process(game)
            for key, id in pairs(ids) do
                if key ~= "2:2" then
                    local r, c = key:match("(%d+):(%d+)")
                    local adjacent = math.abs(r - 2) + math.abs(c - 2) == 1
                    assert(game.world:get(id, "Health").current == (adjacent and 2 or 3))
                end
            end
            assert(game.world:get(far, "Health").current == 3)
            local axes = {}
            for _, id in ipairs(game.world:query("ExplosionParticle")) do
                local v = game.world:get(id, "Velocity")
                assert((v.vx == 0) ~= (v.vy == 0))
                assert(math.abs(v.vx * Config.EXPLOSION_VISUAL_SECONDS) <= 70.00001 and math.abs(v.vy * Config.EXPLOSION_VISUAL_SECONDS) <= 30.00001)
                axes[v.vx > 0 and "right" or v.vx < 0 and "left" or v.vy > 0 and "down" or "up"] = true
            end
            assert(axes.left and axes.right and axes.up and axes.down)
        end)

        test("Explosion respeta blindados, fantasma intangible e irrompible", function()
            local game = empty(); local e = add(game, "E", 2, 2)
            local u, ghost, armor, normal = add(game, "U", 1, 2), add(game, "G", 3, 2), add(game, "A", 2, 1), add(game, "N", 2, 3)
            Ghost.update(game.world, 3)
            Damage.hit(game, e, 1, "ball"); Explosion.process(game)
            assert(game.world:has(u) and not game.world:has(u, "Health"))
            assert(game.world:get(ghost, "Health").current == 1 and not game.world:has(armor) and not game.world:has(normal))
        end)

        test("Cadena ciclica procesa cada explosivo una vez incluso con evento duplicado", function()
            local game = empty(); local ids = {}
            for row = 1, 2 do for col = 1, 2 do ids[#ids + 1] = add(game, "E", row, col) end end
            local resistant = add(game, "R", 2, 3); add(game, "N", 9, 9)
            local before = rolls
            Damage.hit(game, ids[1], 1, "ball")
            game.explosions.tail = 2; game.explosions.queue[2] = game.explosions.queue[1]
            game.config = setmetatable({MAX_EXPLOSIONS_PER_UPDATE = 1}, {__index = Config})
            for _ = 1, 10 do Explosion.process(game) end
            for _, id in ipairs(ids) do assert(not game.world:has(id)) end
            assert(rolls - before == 4 and not Explosion.pending(game))
            assert(game.world:get(resistant, "Health").current == 2 and game.run.combo.chain == 4)
        end)

        test("Moviles mantienen su vecindad logica aunque cambie la posicion visual", function()
            local game = empty(); local e = add(game, "E", 2, 2)
            local neighbor, diagonal = add(game, "M", 2, 3), add(game, "M", 3, 3)
            add(game, "N", 9, 9)
            game.world:get(neighbor, "Position").x = 800
            game.world:get(diagonal, "Position").x, game.world:get(diagonal, "Position").y = 170, 190
            Damage.hit(game, e, 1, "ball"); Explosion.process(game)
            assert(not game.world:has(neighbor) and game.world:has(diagonal))
        end)

        test("Ambos jefes reciben impactos descendentes arriba, en movimiento y a 550 px/s", function()
            for _, index in ipairs({5, 10}) do
                for _, fire in ipairs({false, true}) do
                    for _, valid in ipairs({false, true}) do
                        local game = at(index); local boss = expose(game)
                        if fire then game:activatePowerup("fireball") end
                        local w, id = game.world, game.bossId
                        local p, previous = w:get(id, "Position"), w:get(id, "PreviousPosition")
                        local top = w:get(id, "BossBehavior").topWeakPoint
                        assert(near(top.w / w:get(id, "Collider").w, .3) and top.h < w:get(id, "BossBehavior").weakPoint.h)
                        local ball = H.balls(game)[1]
                        previous.previousX, p.x = 400, 410
                        local edge = 402.5 + top.x
                        ball.position.x = edge + (valid and .5 or -.5) - ball.collider.w / 2
                        ball.position.y = p.y - ball.collider.h - 550 * .05 * .25
                        ball.velocity.vx, ball.velocity.vy = 0, 550
                        Collisions.update(game, .05)
                        assert(w:get(id, "Health").current == game.level.boss.health - (valid and 1 or 0))
                        assert(ball.velocity.vy == -550 and ball.position.y + ball.collider.h <= p.y)
                        if valid then assert(boss.hitZone == "top" and boss.flash > 0) end
                    end
                end
            end
        end)

        test("Contacto superior persistente, 90 pelotas e invulnerabilidad no duplican daño", function()
            local game = at(10); local boss = expose(game); H.setBallCount(game, 90)
            local p = game.world:get(game.bossId, "Position")
            for _, b in ipairs(H.balls(game)) do
                b.position.x, b.position.y, b.velocity.vx, b.velocity.vy = p.x + 75, p.y - b.collider.h - 1, 0, 550
            end
            Collisions.update(game, .05)
            assert(game.world:get(game.bossId, "Health").current == 22)
            boss.hitCooldown = 0
            for _, b in ipairs(H.balls(game)) do b.velocity.vx, b.velocity.vy = 0, 0 end
            for _ = 1, 10 do Collisions.update(game, 0) end
            assert(game.world:get(game.bossId, "Health").current == 22)
            game.world:get(game.bossId, "Damageable").enabled = false
            assert(not Damage.hit(game, game.bossId, 1, "ball", p.x + 80, p.y))
        end)

        test("Nivel 6 mantiene grupos alternos sin ocultar todos los fantasmas", function()
            local game = at(6); local offsets = {}
            local ghosts = game.world:query("Ghost")
            assert(#ghosts == 45)
            for _, id in ipairs(ghosts) do offsets[game.world:get(id, "Ghost").elapsed] = true end
            assert(offsets[0] and offsets[5 / 3] and offsets[10 / 3])
            local varied = false
            for _ = 1, 200 do
                Ghost.update(game.world, .05)
                local solid = 0
                for _, id in ipairs(ghosts) do if game.world:get(id, "Ghost").solid then solid = solid + 1 end end
                assert(solid > 0)
                if solid < #ghosts then varied = true end
            end
            assert(varied)
        end)

        test("Niveles 6-9 tienen rutas de tamaño real y se despejan sin premios aleatorios", function()
            for index = 6, 9 do
                local game = at(index)
                assert(peelReachable(game) == game.remaining)
                capture(game, "level" .. index)
                local guaranteed = game.level.difficulty.guaranteedPowerup
                if guaranteed then
                    Powerups.guaranteed(game, guaranteed.everySeconds)
                    local power = game.world:query("PowerUp")[1]
                    assert(power and game.world:get(power, "PowerUp").kind == "fireball")
                    -- Recoger físicamente el suministro encima del paddle.
                    local p = game.world:get(power, "Position")
                    p.y = game.world:get(game.paddleId, "Position").y
                    Powerups.update(game, 0)
                    assert(game.world:get(H.balls(game)[1].id, "Ball").fire)
                end
                for _, id in ipairs(game.world:query("Brick", "Health")) do
                    H.waitForGhost(game, id)
                    for _ = 1, 4 do Damage.hit(game, id, 1, guaranteed and "fireball" or "ball") end
                    Explosion.process(game)
                end
                assert(game.remaining == 0 and game.state == "level_complete")
                assert(game.world:count("Brick") > 0) -- Solo quedan los irrompibles.
                for _, id in ipairs(game.world:query("Brick")) do assert(game.world:get(id, "Brick").kind == "unbreakable") end
            end
        end)

        test("Todos los portales tienen salidas libres en ambos sentidos y sin bucles", function()
            for _, index in ipairs({7, 9}) do
                for _, time in ipairs({0, 1.25, 2.5, 4}) do
                    local game = at(index); Motion.update(game.world, time)
                    for _, portalId in ipairs(game.world:query("Portal")) do
                        for angle = 0, 7 do
                            local b = H.balls(game)[1]; local ball = game.world:get(b.id, "Ball")
                            local pp, pc = game.world:get(portalId, "Position"), game.world:get(portalId, "Collider")
                            b.position.x, b.position.y = pp.x + pc.w / 2 - b.collider.w / 2, pp.y + pc.h / 2 - b.collider.h / 2
                            b.velocity.vx, b.velocity.vy = 350 * math.cos(angle * math.pi / 4), 350 * math.sin(angle * math.pi / 4)
                            ball.previousX, ball.previousY, ball.portalCooldown = b.position.x, b.position.y, 0
                            local x, y = b.position.x, b.position.y
                            Portals.update(game, 0)
                            assert(b.position.x ~= x or b.position.y ~= y, "Salida bloqueada: " .. index .. "/" .. portalId)
                            assert(near(math.sqrt(b.velocity.vx^2 + b.velocity.vy^2), 350))
                            for _, component in ipairs({"Brick", "MovingObstacle", "Portal"}) do
                                for _, id in ipairs(game.world:query(component)) do
                                    assert(not Collision.overlaps(b.position, b.collider, game.world:get(id, "Position"), game.world:get(id, "Collider")))
                                end
                            end
                            x, y = b.position.x, b.position.y
                            Portals.update(game, .01)
                            assert(b.position.x == x and b.position.y == y and ball.portalCooldown > 0)
                            -- Continuar la trayectoria 2 s; comprobar que sale de la zona del portal.
                            local travelled = false
                            for _ = 1, 120 do
                                if not game.world:has(b.id) then travelled = true; break end
                                Motion.update(game.world, 1 / 60); Ghost.update(game.world, 1 / 60)
                                Collisions.update(game, 1 / 60); Portals.update(game, 1 / 60)
                                if math.abs(b.position.x - x) + math.abs(b.position.y - y) > 100 then travelled = true end
                            end
                            assert(travelled, "Pelota atrapada en portal")
                            if not game.world:has(b.id) then require("src.ball").spawn(game.world, Config, game.level) end
                        end
                    end
                end
            end
        end)

        test("Validador no acepta una bomba diagonal como unica solucion del blindaje", function()
            local level = LevelManager.new(Config):get(1)
            level.layout.rows = {"A...........", ".E.........."}
            level.powerups = {"multiball"}; level.difficulty.guaranteedPowerup = nil
            assert(not pcall(LevelManager.prepare, level, Config))
            level.layout.rows = {"AE.........."}
            level.stars = {twoScore = 200, threeScore = 400, minLives = 3}
            assert(LevelManager.prepare(level, Config))
        end)

        test("Enciclopedia contiene los siete poderes y bloques, jefes y valores reales", function()
            local game = H.newGame(); game:goToMenu(); assert(Encyclopedia.open(game))
            local cats = game.ui.encyclopedia.categories
            assert(#cats == 4 and #cats[1].entries == 7 and #cats[2].entries == 7 and #cats[3].entries == 2)
            local powers, bricks = {}, {}
            for _, e in ipairs(cats[1].entries) do powers[e.id] = e; assert(e.name == Config.POWERUP_TYPES[e.id].name) end
            for _, e in ipairs(cats[2].entries) do bricks[e.id] = e end
            for id in pairs(Config.POWERUP_TYPES) do assert(powers[id]) end
            for id in pairs(Config.BRICK_NAMES) do assert(bricks[id]) end
            assert(table.concat(powers.laser.paragraphs):find(tostring(Config.LASER_AMMO), 1, true))
            assert(cats[3].entries[1].boss.health == 10 and cats[3].entries[2].boss.health == 23)
        end)

        test("Controles configurados y enciclopedia comparten las mismas teclas y cantidades", function()
            local game = H.newGame(); local controls = {}
            for key, value in pairs(Config.CONTROLS) do controls[key] = value end
            controls.action, controls.pause = {"f"}, {"tab"}
            game.config = setmetatable({CONTROLS = controls, LASER_AMMO = 12}, {__index = Config})
            game:activatePowerup("laser")
            local power = game.world:get(game.paddleId, "PaddlePower")
            game:keypressed("space"); assert(power.ammo == 12)
            game:keypressed("f"); assert(power.ammo == 11)
            game:keypressed("tab"); assert(game.state == "paused")
            game:keypressed("tab"); assert(game.state == "playing")
            game:goToMenu(); Encyclopedia.open(game)
            local cats = game.ui.encyclopedia.categories
            local laser = cats[1].entries[4]
            assert(laser.paragraphs[2]:find("12 disparos", 1, true) and laser.paragraphs[2]:find("con F", 1, true))
            assert(table.concat(cats[4].entries[1].paragraphs):find("TAB", 1, true))
        end)

        test("Los mapas nuevos conservan MULTIBALL x3 hasta 90 y limite global en simulacion", function()
            for index = 6, 9 do
                local game = at(index)
                for _, expected in ipairs({3, 9, 27, 81, 90}) do
                    game:activatePowerup("multiball"); assert(game.world:count("Ball") == expected)
                end
                game:activatePowerup("fireball")
                for _ = 1, 120 do
                    game:update(1 / 60)
                    assert(game.world:count("Ball") <= 90)
                    for _, ball in ipairs(H.balls(game)) do
                        assert(ball.velocity.vx^2 + ball.velocity.vy^2 <= Config.BALL_MAX_SPEED^2 + .00001)
                    end
                end
            end
        end)

        test("Entrar y salir por teclado y mouse conserva progreso, entidades y puntuacion", function()
            local game = at(9); game:goToMenu()
            local fs = game.progressStore.filesystem
            local writes, raw, count, score, progress = fs.writes, fs.files[Config.SAVE_FILE], game.world:count(), game.run.score, game.progress
            local ball = H.balls(game)[1]; local x, y = ball.position.x, ball.position.y
            game.ui.selection = 4; game:keypressed("return"); assert(game.state == "encyclopedia")
            for _ = 1, 12 do game:keypressed("right"); game:keypressed("down"); game:keypressed("pagedown"); game:update(10) end
            assert(game.world:count() == count and ball.position.x == x and ball.position.y == y)
            game:keypressed("escape"); assert(game.state == "menu" and game.ui.selection == 4)
            game:mousepressed(480, 220 + 3 * 50 + 20, 1); assert(game.state == "encyclopedia")
            local g = Encyclopedia.layout(game)
            game:mousepressed(g.margin + 2 * (g.tabW + g.gap) + 10, 120, 1)
            assert(game.ui.encyclopedia.category == 3)
            game:mousepressed(g.margin + 10, g.y + 47 + 10, 1); assert(game.ui.encyclopedia.entry == 2)
            game:wheelmoved(0, -10); assert(game.ui.encyclopedia.scroll > 0)
            game:mousepressed(g.margin + 20, g.bottom + 10, 1)
            assert(game.state == "menu" and game.progress == progress and game.run.score == score)
            assert(fs.writes == writes and fs.files[Config.SAVE_FILE] == raw)
        end)

        test("Todas las fichas dibujan en Canvas, ajustan lineas y permiten desplazamiento", function()
            local game = H.newGame(); game:goToMenu(); Encyclopedia.open(game)
            for _, dimensions in ipairs({{960, 640}, {800, 600}}) do
                game.config = setmetatable({WIDTH = dimensions[1], HEIGHT = dimensions[2]}, {__index = Config})
                local canvas = love.graphics.newCanvas(dimensions[1], dimensions[2])
                love.graphics.push("all"); love.graphics.setCanvas(canvas)
                for cat, category in ipairs(game.ui.encyclopedia.categories) do
                    for index in ipairs(category.entries) do
                        game.ui.encyclopedia.category, game.ui.encyclopedia.entry, game.ui.encyclopedia.scroll = cat, index, 0
                        local lines, maximum = Encyclopedia.lines(game)
                        for _, line in ipairs(lines) do
                            assert(line == "" or game.font:hasGlyphs(line), "Glifo no disponible: " .. line)
                            assert(game.font:getWidth(line) <= Encyclopedia.layout(game).w - 48 + 1,
                                "Texto fuera de panel: " .. game.font:getWidth(line) .. "/" .. (Encyclopedia.layout(game).w - 48) .. " " .. line)
                        end
                        game:draw(); Encyclopedia.scroll(game, math.huge); assert(game.ui.encyclopedia.scroll == maximum)
                        game:draw(); Encyclopedia.scroll(game, -math.huge); assert(game.ui.encyclopedia.scroll == 0)
                    end
                end
                love.graphics.pop(); canvas:release()
            end
            game.config = Config
            for cat = 1, 4 do
                game.ui.encyclopedia.category, game.ui.encyclopedia.entry, game.ui.encyclopedia.scroll = cat, cat == 2 and 7 or cat == 3 and 2 or 1, 0
                capture(game, "encyclopedia" .. cat)
            end
            game:keypressed("escape"); capture(game, "menu")
            local bossGame = at(10); expose(bossGame); capture(bossGame, "boss_top")
        end)
    end, debug.traceback)
    love.keyboard.isDown, love.math.random = keyboard, random
    assert(ok, err)
    return passed
end
return {run = run}

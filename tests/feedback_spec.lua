local Config = require("src.config")
local Game = require("src.game")
local H = require("tests.helpers")
local Feedback = require("src.feedback")
local Particles = require("src.ecs.systems.particle_system")
local System = require("src.ecs.systems.feedback_system")
local Audio = require("src.ecs.systems.audio_system")
local Catalog = require("src.audio_catalog")
local Damage = require("src.ecs.systems.damage_system")
local Bricks = require("src.bricks")
local Collision = require("src.ecs.systems.collision_system")
local Explosion = require("src.ecs.systems.explosion_system")
local Enemy = require("src.ecs.systems.enemy_projectile_system")
local Portals = require("src.ecs.systems.portal_system")

local function near(a, b) return math.abs(a - b) < 0.00001 end
local function backend(fail)
    local b = {sources = {}, loads = 0, clones = 0}
    local function source(path)
        local s = {path = path, playing = false, position = 0, plays = 0, volume = 1}
        b.sources[#b.sources + 1] = s
        function s:clone() b.clones = b.clones + 1; return source(path) end
        function s:setVolume(value) assert(value >= 0 and value <= 1); self.volume = value end
        function s:setLooping(value) self.loop = value end
        function s:isPlaying() return self.playing end
        function s:play() self.playing = true; self.plays = self.plays + 1; return true end
        function s:pause() self.playing = false end
        function s:stop() self.playing = false; self.position = 0 end
        return s
    end
    function b.newSource(path, mode)
        b.loads = b.loads + 1
        assert(mode == "static" or mode == "stream")
        if fail and fail(path) then error("Recurso no disponible") end
        return source(path)
    end
    return b
end
local function audioGame(b)
    return Game.new({filesystem = H.memoryFilesystem(), audioBackend = b})
end
local function events(game, kind)
    local count = 0
    for _, e in ipairs(game.feedback.events) do if e.kind == kind then count = count + 1 end end
    return count
end
local function active(game)
    local count = 0
    for _, slot in ipairs(game.audio.voices) do if slot.source and slot.source:isPlaying() then count = count + 1 end end
    return count
end
local function playing(game)
    game:reset(); H.finishIntro(game); Feedback.clear(game)
end

local function run(root)
    local passed = 0
    local random, keyboard, quit, mode = love.math.random, love.keyboard.isDown, love.event.quit, Config.ECS_ASSIGNMENT_MODE
    local rolls, quits = 0, 0
    love.math.random = function() rolls = rolls + 1; return 0.99 end
    love.keyboard.isDown = function() return false end
    love.event.quit = function() quits = quits + 1 end
    Config.ECS_ASSIGNMENT_MODE = false
    local function test(name, fn)
        rolls, quits = 0, 0; fn(); passed = passed + 1; print("OK FASE7 " .. passed .. ": " .. name)
    end
    local ok, err = xpcall(function()
        test("Catalogo usa 19 WAV existentes, relativos, PCM y no vacios", function()
            local paths, count = {}, 0
            for _, group in ipairs({Catalog.effects, Catalog.music}) do
                for _, definition in pairs(group) do
                    local path = definition.file
                    assert(path:match("^assets/audio/[%w_]+%.wav$") and not paths[path])
                    paths[path], count = true, count + 1
                    local handle = assert(io.open(root .. "/" .. path, "rb"))
                    local bytes = handle:read("*a"); handle:close()
                    assert(#bytes > 1000 and bytes:sub(1, 4) == "RIFF" and bytes:sub(9, 12) == "WAVE")
                    assert(definition.gain > 0 and definition.gain <= 1)
                end
            end
            assert(count == 19)
        end)

        test("Audio precarga pools y pistas una vez; los frames no crean Sources ni clones", function()
            local b = backend(); local game = audioGame(b)
            assert(b.loads == 19 and b.clones == 16 and #b.sources == 35 and game.audio.available)
            playing(game)
            for _ = 1, 120 do Audio.update(game, 0.02); Audio.play(game, "wall") end
            assert(b.loads == 19 and b.clones == 16 and #b.sources == 35)
        end)

        test("Musica selecciona menu, niveles y jefes con fundidos y maximo dos pistas", function()
            local b = backend(); local game = audioGame(b)
            Audio.update(game, 0.4); assert(game.audio.wanted == "menu" and game.audio.music.menu.source.loop)
            playing(game); assert(game.audio.wanted == "level")
            game.progress.maxUnlocked = 10; game:startCampaign(5); Audio.sync(game)
            assert(game.audio.wanted == "boss")
            game:goToMenu(); Audio.sync(game)
            local count = 0
            for _, track in pairs(game.audio.music) do if track.source.playing then count = count + 1 end end
            assert(count <= 2 and game.audio.wanted == "menu")
            Audio.update(game, Config.MUSIC_FADE_SECONDS)
            assert(game.audio.music.menu.fade == 1 and not game.audio.music.boss.source.playing)
        end)

        test("Opciones aplican master por canal y silencio inmediatamente sin reiniciar pistas", function()
            local b = backend(); local game = audioGame(b); Audio.update(game, 1)
            local music = game.audio.music.menu.source
            game:keypressed("down"); game:keypressed("down"); game:keypressed("return")
            game:keypressed("left")
            assert(near(music.volume, .9 * .6 * Catalog.music.menu.gain))
            game:keypressed("down"); game:keypressed("left")
            assert(near(music.volume, .9 * .5 * Catalog.music.menu.gain))
            game:keypressed("down"); game:keypressed("left")
            local voice = game.audio.effects.wall[1].source
            assert(near(voice.volume, .9 * .7 * Catalog.effects.wall.gain))
            game:keypressed("down"); game:keypressed("return")
            assert(game.progress.settings.muted and not music.playing and active(game) == 0)
            assert(not Audio.play(game, "laser"))
            game:keypressed("return"); assert(not game.progress.settings.muted and music.playing)
            assert(b.loads == 19)
            game:keypressed("escape")
            local loaded = H.newGame(game.progressStore.filesystem)
            assert(near(loaded.progress.settings.masterVolume, .9) and near(loaded.progress.settings.sfxVolume, .7))
        end)

        test("Pausa y foco congelan musica, sonidos, fundido y reloj; reanudacion conserva posicion", function()
            local game = audioGame(backend()); playing(game); Audio.play(game, "laser")
            local music, voice = game.audio.music.level.source, game.audio.effects.laser[1].source
            music.position, voice.position = 3.2, .04
            game:focus(false)
            local time, fade = game.audio.time, game.audio.music.level.fade
            game:update(20); game:keypressed("down"); game:keypressed("up")
            assert(game.state == "paused" and not music.playing and not voice.playing)
            assert(game.audio.time == time and game.audio.music.level.fade == fade and game.feedback.count == 0)
            game:focus(true); assert(game.state == "paused")
            game:keypressed("p")
            assert(music.playing and voice.playing and music.position == 3.2 and voice.position == .04)
        end)

        test("Abandonar pausa no reanuda sonidos de combate ni deja mas de una pista al terminar fundido", function()
            local game = audioGame(backend()); playing(game); Audio.play(game, "laser")
            game:keypressed("p"); game:keypressed("m"); Audio.update(game, 1)
            assert(active(game) == 0 and game.audio.wanted == "menu" and game.audio.music.menu.source.playing)
            assert(not game.audio.music.level.source.playing)
        end)

        test("SFX limitados, enfriamiento por tipo y prioridad para resultados", function()
            local game = audioGame(backend()); playing(game)
            assert(Audio.play(game, "wall"))
            for _ = 1, 90 do assert(not Audio.play(game, "wall")) end
            Audio.update(game, .05); assert(Audio.play(game, "wall"))
            for _, name in ipairs({"paddle", "brick", "resistant", "laser", "ui", "portal", "powerup", "boss_hit"}) do Audio.play(game, name) end
            assert(active(game) <= Config.MAX_SFX_VOICES)
            assert(Audio.play(game, "victory") and active(game) == 1)
            assert(game.audio.effects.victory[1].source.playing)
        end)

        test("Reiniciar desde pausa no reanuda sonidos de la ronda anterior", function()
            local game = audioGame(backend()); playing(game); Audio.play(game, "laser")
            local source = game.audio.effects.laser[1].source
            local paddle = game.paddleId
            game:keypressed("p"); game:keypressed("down"); game:keypressed("return")
            assert(game.state == "level_intro" and game.paddleId ~= paddle and not source.playing)
            H.finishIntro(game)
            assert(not source.playing and source.plays == 1 and game.audio.music.level.source.playing)
        end)

        test("Pools reutilizan voces terminadas y no acumulan sonidos omitidos", function()
            local b = backend(); local game = audioGame(b); playing(game)
            Audio.play(game, "brick"); Audio.update(game, .05); Audio.play(game, "brick"); Audio.update(game, .05)
            assert(not Audio.play(game, "brick"))
            local first = game.audio.effects.brick[1].source; first:stop()
            assert(Audio.play(game, "brick") and first.plays == 2)
            Audio.update(game, 10)
            assert(first.plays == 2 and b.clones == 16)
        end)

        test("Ausencia total de audio o recursos nunca impide jugar", function()
            local game = audioGame(backend(function() return true end))
            assert(not game.audio.available and game.audio.errors == 19)
            playing(game); game:activatePowerup("multiball"); game:update(.01); game:draw()
            assert(game.world:count("Ball") == 3 and not Audio.play(game, "wall"))
            assert(Audio.status(game):find("no disponible", 1, true))
            Audio.initialize(game, {})
            Audio.update(game, 1); Audio.stop(game); assert(not game.audio.available)
        end)

        test("Un archivo corrupto o un fallo del dispositivo solo deshabilita ese recurso", function()
            local game = audioGame(backend(function(path) return path:find("brick.wav", 1, true) end))
            playing(game); assert(not Audio.play(game, "brick") and Audio.play(game, "paddle"))
            local voice = game.audio.effects.wall[1]
            voice.source.play = function() error("Dispositivo desconectado") end
            assert(not Audio.play(game, "wall") and not voice.source)
            Audio.update(game, .1); assert(Audio.play(game, "laser") and game.audio.errors >= 2)
            assert(Audio.status(game):find("Algunos", 1, true))
        end)

        test("Mute y volumen cero eliminan voces pendientes sin reproducirlas al reactivar", function()
            local game = audioGame(backend()); playing(game); Audio.play(game, "paddle")
            local voice = game.audio.effects.paddle[1].source
            game.progress.settings.sfxVolume = 0; Audio.sync(game)
            assert(not voice.playing and not Audio.play(game, "wall"))
            game.progress.settings.sfxVolume = 1; Audio.sync(game); assert(not voice.playing)
            game.progress.settings.masterVolume = 0; Audio.sync(game)
            assert(not game.audio.music.level.source.playing)
            game.progress.settings.masterVolume = 1; Audio.sync(game)
            assert(game.audio.music.level.source.playing and not voice.playing)
        end)

        test("Cola visual acotada reserva vida y resultado aun con 90 contactos", function()
            local game = H.newGame()
            for _ = 1, 200 do Feedback.emit(game, "wall", 0, 300) end
            assert(game.feedback.count == Config.MAX_FEEDBACK_EVENTS)
            assert(Feedback.emit(game, "life_lost", 480, 587))
            assert(Feedback.emit(game, "victory", 480, 210))
            assert(not Feedback.emit(game, "level_complete", 480, 210))
            System.flush(game)
            assert(game.feedback.count == 0 and not game.feedback.important)
            assert(game.world:count("Particle") <= Config.FEEDBACK_EMIT_BUDGET)
        end)

        test("Particulas son datos ECS sin colision, salud ni puntos", function()
            local game = H.newGame(); Feedback.emit(game, "brick", 200, 200); System.flush(game)
            assert(game.world:count("Particle") == Config.FEEDBACK_STYLES.brick.count)
            for _, id in ipairs(game.world:query("Particle")) do
                assert(game.world:has(id, "Position", "Velocity", "Renderable"))
                assert(not game.world:has(id, "Collider") and not game.world:has(id, "Health") and not game.world:has(id, "ScoreValue"))
                for _, value in pairs(game.world:get(id, "Particle")) do assert(type(value) ~= "function") end
            end
            assert(game.remaining == 72 and game.run.score == 0)
        end)

        test("Movimiento, gravedad, fade y caducidad de particulas dependen de dt", function()
            local a, b = H.newGame(), H.newGame()
            for _, game in ipairs({a, b}) do
                Feedback.emit(game, "level_complete", 480, 210); System.flush(game)
                game.state = "level_complete" -- Aislar reloj visual, sin generar estelas.
            end
            Particles.update(a, .2); Particles.update(b, .1); Particles.update(b, .1)
            local ia, ib = a.world:query("Particle")[1], b.world:query("Particle")[1]
            local pa, pb = a.world:get(ia, "Position"), b.world:get(ib, "Position")
            assert(near(pa.x, pb.x) and near(pa.y, pb.y) and a.world:get(ia, "Renderable").alpha < .65)
            Particles.update(a, 10); assert(a.world:count("Particle") == 0 and a.feedback.particleCount == 0)
        end)

        test("90 pelotas generan estelas repartidas con cupo y sin consumir RNG", function()
            local game = H.newGame(); H.setBallCount(game, 90)
            local before = rolls
            for index, ball in ipairs(H.balls(game)) do ball.position.x, ball.position.y = index * 9, 400 end
            for _ = 1, 90 do Particles.update(game, .04) end
            assert(game.world:count("Particle") <= Config.MAX_TRAIL_PARTICLES and rolls == before)
            local minimum, maximum = 9999, -9999
            for _, id in ipairs(game.world:query("Particle")) do
                local x = game.world:get(id, "Position").x
                minimum, maximum = math.min(minimum, x), math.max(maximum, x)
            end
            assert(minimum < 100 and maximum > 700 and game.world:count("Ball") == 90)
        end)

        test("Fuego colorea estelas, captura no emite y dt cero no genera entidades", function()
            local game = H.newGame(); game:activatePowerup("fireball"); Feedback.clear(game)
            Particles.update(game, 0); assert(game.world:count("Particle") == 0)
            Particles.update(game, .04)
            local id = game.world:query("Particle")[1]
            assert(game.world:get(id, "Renderable").color[1] == 1)
            Feedback.clear(game)
            game:activatePowerup("magnet"); require("src.ecs.systems.power_effect_system").capture(game, H.balls(game)[1].id)
            Particles.update(game, .04); assert(game.world:count("Particle") == 0)
        end)

        test("Saturacion de particulas conserva cupo y permite celebracion sin tocar bloques", function()
            local game = H.newGame()
            for _ = 1, 20 do
                for _ = 1, 64 do Feedback.emit(game, "brick", 200, 200) end
                System.flush(game)
            end
            assert(game.world:count("Particle") == Config.MAX_FEEDBACK_PARTICLES)
            local nextId = game.world.nextId
            Feedback.emit(game, "victory", 480, 210); System.flush(game)
            assert(game.world:count("Particle") == Config.MAX_FEEDBACK_PARTICLES and game.world.nextId > nextId)
            assert(game.world:count("Brick") == 72 and game.world:count("Ball") == 1)
        end)

        test("Pausa congela particulas y no acumula avisos; menu y reinicio limpian efectos", function()
            local game = H.newGame(); Feedback.emit(game, "powerup", 480, 550); System.flush(game)
            local id = game.world:query("Particle")[1]; local p = game.world:get(id, "Position")
            local x, remaining = p.x, game.world:get(id, "Particle").remaining
            game:keypressed("p"); game:update(20)
            assert(p.x == x and game.world:get(id, "Particle").remaining == remaining)
            assert(not Feedback.emit(game, "ui") and game.feedback.count == 0)
            game:keypressed("p"); game:update(.01); assert(p.x ~= x)
            game:keypressed("m"); assert(game.world:count("Particle") == 0 and game.feedback.count == 0)
            game:reset(); H.finishIntro(game); assert(game.world:count("Particle") == 0 and not game.world:has(id))
        end)

        test("Perder vida elimina estelas anteriores y emite una sola señal de ronda", function()
            local game = H.newGame(); H.setBallCount(game, 90); Particles.update(game, .04)
            local previous = game.world:query("Particle")
            for _, id in ipairs(game.world:query("Ball")) do game.world:destroy(id) end
            game:update(0)
            assert(game.lives == 2 and game.world:count("Ball") == 1)
            for _, id in ipairs(previous) do assert(not game.world:has(id)) end
            assert(game.world:count("Particle") == Config.FEEDBACK_STYLES.life_lost.count)
        end)

        test("Destruccion repetida produce un solo evento y no altera sorteo ni puntuacion", function()
            local game = H.newGame(); local id = game.world:query("Brick")[1]
            assert(Damage.hit(game, id, 1, "ball")); assert(not Damage.hit(game, id, 1, "ball"))
            assert(events(game, "brick") == 1 and rolls == 1 and game.run.score == 100)
            local count = rolls; System.flush(game); Particles.update(game, .04)
            assert(rolls == count and game.remaining == 71)
        end)

        test("90 colisiones sobre un bloque no duplican eventos de destruccion", function()
            local game = H.newGame(); H.setBallCount(game, 90)
            local brick = H.bricks(game)[1]
            for _, ball in ipairs(H.balls(game)) do
                ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = brick.position.x, brick.position.y + 1, 0, -300
            end
            Collision.update(game, 0)
            assert(events(game, "brick") == 1 and game.remaining == 71 and rolls == 1)
        end)

        test("Rebotes de pared y paddle emiten solo al resolver un impacto", function()
            local game = H.newGame(); local ball = H.balls(game)[1]
            ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = 0, 400, -300, 0
            Collision.update(game, 0); Collision.update(game, 0)
            assert(events(game, "wall") == 1)
            local pp = H.paddle(game)
            ball.position.x, ball.position.y = pp.position.x + pp.collider.w / 2, pp.position.y - ball.collider.h + 1
            ball.velocity.vx, ball.velocity.vy = 0, 300
            Collision.update(game, 0); Collision.update(game, 0)
            assert(events(game, "paddle") == 1)
        end)

        test("Daño resistente y cadena explosiva conservan salud, cola y señales", function()
            local game = H.newGame(); game.progress.maxUnlocked = 3; H.startCampaign(game, 3)
            local resistant, explosive
            for _, id in ipairs(game.world:query("Brick")) do
                local kind = game.world:get(id, "Brick").kind
                if kind == "resistant" then resistant = id elseif kind == "explosive" then explosive = id end
            end
            if not resistant then
                resistant = Bricks.spawn(game.world, Config, game.level, {key = "test", x = 100, y = 350, w = 50, h = 25,
                    color = {1, 0, 0}, definition = {kind = "resistant", health = 3}})
            end
            Damage.hit(game, resistant, 1, "ball"); assert(events(game, "resistant") == 1)
            assert(game.world:get(resistant, "Health").current == 2)
            Damage.hit(game, explosive, 1, "ball"); Explosion.process(game)
            assert(events(game, "explosion") > 0 and game.world:count("ExplosionParticle") <= Config.MAX_EXPLOSION_PARTICLES)
            System.flush(game); assert(game.world:count("Particle") <= Config.MAX_FEEDBACK_PARTICLES)
        end)

        test("Cada poder tiene señal, laser respeta municion y eventos omitidos por cooldown", function()
            local game = H.newGame()
            for kind in pairs(Config.POWERUP_TYPES) do game:activatePowerup(kind) end
            assert(events(game, "powerup") == 7)
            local shots = require("src.ecs.systems.projectile_system")
            assert(shots.fire(game)); assert(not shots.fire(game))
            assert(events(game, "laser") == 1 and game.world:count("Projectile") == 2)
        end)

        test("Portales emiten entrada y salida sin modificar velocidad ni duplicar contacto", function()
            local game = H.newGame(); game.progress.maxUnlocked = 7; H.startCampaign(game, 7)
            local id = game.world:query("Portal")[1]; local p, c = game.world:get(id, "Position"), game.world:get(id, "Collider")
            local ball = H.balls(game)[1]
            ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = p.x + c.w / 2, p.y + c.h / 2, 300, -400
            Portals.update(game, 0); Portals.update(game, 0)
            assert(events(game, "portal") == 2 and near(math.sqrt(ball.velocity.vx ^ 2 + ball.velocity.vy ^ 2), 500))
        end)

        test("Jefes anuncian ataques y daño valido; victoria produce sonido prioritario una vez", function()
            local b = backend(); local game = audioGame(b); game.progress.maxUnlocked = 10
            H.startCampaign(game, 10)
            local boss, health = game.world:get(game.bossId, "Boss"), game.world:get(game.bossId, "Health")
            boss.phase, boss.intro, health.current = 3, 0, 1
            game.world:get(game.bossId, "Damageable").enabled = true
            Enemy.emit(game, game.bossId, 480); assert(events(game, "boss_attack") == 1)
            local p, c = game.world:get(game.bossId, "Position"), game.world:get(game.bossId, "Collider")
            assert(Damage.hit(game, game.bossId, 1, "ball", p.x + c.w / 2, p.y + c.h))
            assert(events(game, "boss_hit") == 1 and events(game, "boss_defeat") == 1)
            System.flush(game)
            local victory = game.audio.effects.victory[1].source
            assert(victory.plays == 1 and game.audio.effects.boss_defeat[1].source.playing)
            assert(game.state == "campaign_complete" and not game:completeLevel())
            System.flush(game); assert(victory.plays == 1)
            game:update(10); assert(game.world:count("Particle") == 0)
        end)

        test("GAME OVER reemplaza sonido de perdida y no se repite en frames finales", function()
            local game = audioGame(backend()); playing(game); game.lives = 1; game:loseLife(); System.flush(game)
            assert(game.state == "game_over" and game.audio.wanted == nil)
            local source = game.audio.effects.game_over[1].source
            assert(source.plays == 1 and not game.audio.effects.life_lost[1].source.playing)
            for _ = 1, 10 do game:update(.1) end
            assert(source.plays == 1)
        end)

        test("Dibujo mantiene particulas fuera del HUD, pelotas encima y no crea recursos", function()
            local game = H.newGame(); game:activatePowerup("fireball"); Feedback.clear(game)
            Feedback.emit(game, "powerup", 480, 50); System.flush(game)
            local canvas = love.graphics.newCanvas(Config.WIDTH, Config.HEIGHT)
            local font, image, newCanvas = love.graphics.newFont, love.graphics.newImage, love.graphics.newCanvas
            local function forbidden() error("Recurso creado durante frame") end
            love.graphics.newFont, love.graphics.newImage, love.graphics.newCanvas = forbidden, forbidden, forbidden
            local success, failure = xpcall(function()
                love.graphics.setCanvas(canvas); game:draw(); love.graphics.setCanvas()
                local pixels = canvas:newImageData()
                local ball = H.balls(game)[1]
                local r, g, bl = pixels:getPixel(math.floor(ball.position.x + ball.collider.w / 2), math.floor(ball.position.y + ball.collider.h / 2))
                assert(r > .95 and g > .95 and bl > .9, "Nucleo claro visible con fuego")
                pixels:release()
                love.graphics.setScissor(10, 100, 200, 300)
                require("src.ecs.systems.feedback_render_system").particles(game)
                local x, y, w, h = love.graphics.getScissor(); assert(x == 10 and y == 100 and w == 200 and h == 300)
            end, debug.traceback)
            love.graphics.setScissor(); love.graphics.setCanvas()
            love.graphics.newFont, love.graphics.newImage, love.graphics.newCanvas = font, image, newCanvas
            canvas:release(); assert(success, failure)
        end)

        test("ECS_ASSIGNMENT_MODE descarta eventos tras cierre lateral y detiene audio", function()
            for _, x in ipairs({0, Config.WIDTH - Config.BALL_SIZE}) do
                local game = audioGame(backend()); playing(game); H.setBallCount(game, 90)
                local ball = H.balls(game)[90]
                ball.position.x, ball.position.y, ball.velocity.vx, ball.velocity.vy = x, 400, x == 0 and -300 or 300, 0
                Audio.play(game, "paddle"); Config.ECS_ASSIGNMENT_MODE = true; quits = 0
                game:update(0); game:update(1)
                assert(game.quitRequested and quits == 1 and events(game, "wall") == 0 and active(game) == 0)
                for _, track in pairs(game.audio.music) do assert(not track.source.playing) end
                assert(game.lives == 3 and game.world:count("Ball") == 90 and game.run.score == 0)
                Config.ECS_ASSIGNMENT_MODE = false
            end
        end)
    end, debug.traceback)
    love.math.random, love.keyboard.isDown, love.event.quit, Config.ECS_ASSIGNMENT_MODE = random, keyboard, quit, mode
    if not ok then error(err, 0) end
    return passed
end

return {run = run}

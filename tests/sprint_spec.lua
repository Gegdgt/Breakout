local Config = require("src.config")
local H = require("tests.helpers")
local Paddle = require("src.paddle")
local World = require("src.ecs.world")
local Effects = require("src.ecs.systems.power_effect_system")
local Collision = require("src.ecs.systems.collision_system")

local function near(a, b) return math.abs(a - b) < 0.000001 end

local function run()
    local keyboard, quit, mode = love.keyboard.isDown, love.event.quit, Config.ECS_ASSIGNMENT_MODE
    local held, passed, quits = {}, 0, 0
    love.keyboard.isDown = function(...)
        for _, key in ipairs({...}) do if held[key] then return true end end
        return false
    end
    love.event.quit = function() quits = quits + 1 end
    Config.ECS_ASSIGNMENT_MODE = false
    local function test(name, fn)
        held, quits = {}, 0
        fn(); passed = passed + 1; print("OK SPRINT " .. passed .. ": " .. name)
    end
    local function control(game) return game.world:get(game.paddleId, "PaddleControl") end
    local function move(game, dt) Paddle.update(game.world, game.config, dt) end
    local ok, err = xpcall(function()
        test("A/D y flechas conservan 475 px/s y movimiento horizontal", function()
            assert(Config.PADDLE_NORMAL_SPEED == 475 and Config.PADDLE_SPEED == 475)
            for key, direction in pairs({a = -1, d = 1, left = -1, right = 1}) do
                local game = H.newGame(); local p = H.paddle(game)
                local x, y = p.position.x, p.position.y
                held = {[key] = true}; move(game, .02)
                assert(near(p.position.x - x, direction * 475 * .02) and p.position.y == y)
                assert(p.velocity.vy == 0 and not control(game).sprinting)
            end
        end)

        test("Ambos Shift con cada direccion producen 855 px/s", function()
            for _, shift in ipairs({"lshift", "rshift"}) do
                for key, direction in pairs({a = -1, d = 1, left = -1, right = 1}) do
                    local game = H.newGame(); local p = H.paddle(game)
                    local x, y = p.position.x, p.position.y
                    held = {[shift] = true, [key] = true}; game:update(.02)
                    assert(near(p.position.x - x, direction * 855 * .02) and p.position.y == y)
                    assert(control(game).sprinting and p.velocity.vy == 0)
                end
            end
        end)

        test("Soltar Shift restaura la velocidad al instante y no hay cooldown", function()
            local game = H.newGame(); local p = H.paddle(game)
            for _ = 1, 100 do
                held = {lshift = true, a = true}; local x = p.position.x; move(game, .001)
                assert(near(p.position.x - x, -.855) and control(game).sprinting)
                held = {a = true}; x = p.position.x; move(game, .001)
                assert(near(p.position.x - x, -.475) and not control(game).sprinting)
            end
            assert(control(game).speed == 475 and game.lives == 3)
        end)

        test("Shift solo, direcciones opuestas y dt cero no activan sprint", function()
            local game = H.newGame(); local p = H.paddle(game)
            local x = p.position.x
            for _, keys in ipairs({{lshift = true}, {rshift = true}, {a = true, right = true, lshift = true}}) do
                held = keys; move(game, .1)
                assert(p.position.x == x and p.velocity.vx == 0 and not control(game).sprinting)
            end
            held = {a = true, left = true, lshift = true, rshift = true}; move(game, 0)
            assert(p.position.x == x and not control(game).sprinting)
            move(game, .02)
            assert(near(p.position.x - x, -855 * .02), "Las teclas equivalentes no duplican el multiplicador")
        end)

        test("Velocidad normal y multiplicador se configuran sin alterar las pelotas", function()
            local config = {}; for key, value in pairs(Config) do config[key] = value end
            config.PADDLE_NORMAL_SPEED, config.PADDLE_SPRINT_MULTIPLIER = 400, 2.25
            local world = World.new(); local id = Paddle.spawn(world, config)
            local p = world:get(id, "Position"); local x = p.x
            held = {d = true}; Paddle.update(world, config, .02)
            assert(near(p.x - x, 8))
            held.rshift = true; x = p.x; Paddle.update(world, config, .02)
            assert(near(p.x - x, 18) and Config.BALL_MAX_SPEED == 550 and Config.MAX_BALLS == 90)
        end)

        test("Paddle normal y gigante respetan ambos bordes incluso con dt alto", function()
            for _, giant in ipairs({false, true}) do
                for _, right in ipairs({false, true}) do
                    for _, dt in ipairs({.01, .25, 10}) do
                        local game = H.newGame()
                        if giant then game:activatePowerup("giant_paddle") end
                        local p = H.paddle(game); local edge = right and Config.WIDTH - p.collider.w or 0
                        p.position.x = edge + (right and -2 or 2)
                        held = {lshift = true, [right and "right" or "left"] = true}; move(game, dt)
                        assert(p.position.x == edge and control(game).sprinting)
                        move(game, dt)
                        assert(p.position.x == edge and not control(game).sprinting)
                    end
                end
            end
        end)

        test("Igual desplazamiento a 30, 60 y 120 FPS con y sin sprint", function()
            for _, shift in ipairs({false, true}) do
                for _, frames in ipairs({6, 12, 24}) do
                    local game = H.newGame(); local p = H.paddle(game); local x = p.position.x
                    held = {d = true, lshift = shift}
                    for _ = 1, frames do game:update(.2 / frames) end
                    assert(near(p.position.x - x, (shift and 855 or 475) * .2))
                end
            end
        end)

        test("El coordinador conserva el tope de dt, la pausa y el reinicio", function()
            local game = H.newGame(); local p = H.paddle(game); local x = p.position.x
            held = {d = true, rshift = true}; game:update(20)
            assert(near(p.position.x - x, 855 * .05))
            game:keypressed("p"); x = p.position.x; game:update(20)
            assert(game.state == "paused" and p.position.x == x)
            held = {a = true}; game:keypressed("p"); game:update(.02)
            assert(near(p.position.x - x, -475 * .02) and not control(game).sprinting)
            game:restartLevel(); held = {d = true, lshift = true}; p = H.paddle(game); x = p.position.x
            game:update(.1)
            assert(game.state == "level_intro" and p.position.x == x and not control(game).sprinting)
            game:goToMenu(); game:update(10); assert(p.position.x == x)
        end)

        test("Gigante e iman siguen el sprint, los bordes y la prioridad de lanzamiento", function()
            local game = H.newGame()
            for _, kind in ipairs({"giant_paddle", "magnet", "laser"}) do game:activatePowerup(kind) end
            local p, ball = H.paddle(game), H.balls(game)[1]
            ball.position.x = p.position.x + p.collider.w / 2 - ball.collider.w / 2 + 12
            ball.velocity.vx, ball.velocity.vy = 195, -280
            assert(Effects.capture(game, ball.id))
            local offset = ball.position.x - p.position.x
            for _, right in ipairs({false, true}) do
                held = {lshift = true, [right and "d" or "a"] = true}
                p.position.x = right and Config.WIDTH - p.collider.w - 2 or 2
                game:update(.02)
                assert(near(ball.position.x - p.position.x, offset))
                assert(ball.position.y == p.position.y - ball.collider.h and ball.velocity.vx == 195 and ball.velocity.vy == -280)
            end
            local _, power = Effects.get(game)
            game:keypressed("space")
            assert(not power.heldBall and power.ammo == Config.LASER_AMMO and game.world:count("Projectile") == 0)
            assert(ball.velocity.vx == 195 and ball.velocity.vy == -280)
        end)

        test("Los siete poderes conservan duraciones, municion y vidas durante sprint", function()
            for kind in pairs(Config.POWERUP_TYPES) do
                local normal, sprint = H.newGame(), H.newGame()
                normal:activatePowerup(kind); sprint:activatePowerup(kind)
                local x = H.paddle(sprint).position.x
                held = {d = true}; normal:update(.02)
                held.lshift = true; sprint:update(.02)
                assert(near(H.paddle(sprint).position.x - x, 855 * .02))
                local nt, np = Effects.get(normal); local st, sp = Effects.get(sprint)
                for effect, remaining in pairs(nt) do assert(st[effect] == remaining) end
                assert(np.ammo == sp.ammo and normal.lives == sprint.lives)
                assert(normal.world:count("Ball") == sprint.world:count("Ball"))
            end
        end)

        test("MULTIBALL hasta 90 conserva velocidad y solo la ultima caida cuesta vida", function()
            local game = H.newGame(); held = {a = true, lshift = true}
            for _, expected in ipairs({3, 9, 27, 81, 90, 90}) do
                game:activatePowerup("multiball"); assert(game.world:count("Ball") == expected)
            end
            local balls, velocities = H.balls(game), {}
            for index, ball in ipairs(balls) do
                ball.position.x, ball.position.y = 300 + index, 450
                velocities[index] = {ball.velocity.vx, ball.velocity.vy}
            end
            game:update(.02)
            for index, ball in ipairs(balls) do
                assert(near(ball.velocity.vx, velocities[index][1]) and near(ball.velocity.vy, velocities[index][2]))
                assert(math.sqrt(ball.velocity.vx ^ 2 + ball.velocity.vy ^ 2) <= 550 + .000001)
                if index < #balls then ball.position.y = Config.HEIGHT end
            end
            game:update(0); assert(game.lives == 3 and game.world:count("Ball") == 1)
            balls[#balls].position.y = Config.HEIGHT; game:update(0)
            assert(game.lives == 2 and game.world:count("Ball") == 1 and not control(game).sprinting)
        end)

        test("Sprint conserva rebotes direccionales y el limite de 550 px/s", function()
            for _, impact in ipairs({-.9, -.5, 0, .5, .9}) do
                for _, speed in ipairs({300, 550}) do
                    local game = H.newGame(); held = {d = true, rshift = true}; move(game, .02)
                    local p, ball = H.paddle(game), H.balls(game)[1]
                    ball.position.x = p.position.x + p.collider.w / 2 * (1 + impact) - ball.collider.w / 2
                    ball.position.y = p.position.y - ball.collider.h - 1
                    ball.velocity.vx, ball.velocity.vy = 0, speed
                    Collision.update(game, .01)
                    local expected = math.min(550, speed * Config.PADDLE_SPEED_MULTIPLIER)
                    assert(near(ball.velocity.vx, expected * math.sin(impact * math.rad(60))))
                    assert(near(ball.velocity.vy, -expected * math.cos(impact * math.rad(60))))
                end
            end
        end)

        test("HUD real cambia texto/color sin tapar la ayuda ni crear recursos", function()
            local game = H.newGame(); local canvas = love.graphics.newCanvas(Config.WIDTH, Config.HEIGHT)
            local printText, printf = love.graphics.print, love.graphics.printf
            local font, image, newCanvas = love.graphics.newFont, love.graphics.newImage, love.graphics.newCanvas
            local labels, helpLeft = {}, nil
            local function forbidden() error("Recurso creado durante draw") end
            love.graphics.newFont, love.graphics.newImage, love.graphics.newCanvas = forbidden, forbidden, forbidden
            love.graphics.print = function(label, x, y, ...)
                labels[label] = {color = {love.graphics.getColor()}, right = x + love.graphics.getFont():getWidth(label), y = y}
                return printText(label, x, y, ...)
            end
            love.graphics.printf = function(label, x, y, width, align, ...)
                if y == 620 then helpLeft = x + (width - love.graphics.getFont():getWidth(label)) / 2 end
                return printf(label, x, y, width, align, ...)
            end
            local success, failure = xpcall(function()
                local function draw() labels = {}; love.graphics.setCanvas(canvas); game:draw(); love.graphics.setCanvas() end
                draw(); local idle = assert(labels["SHIFT: Sprint"])
                assert(idle.right + 12 < helpLeft and idle.y + game.effectFont:getHeight() <= Config.HEIGHT)
                held = {d = true, lshift = true}; game:update(.02); draw()
                local active = assert(labels.SPRINT)
                assert(not labels["SHIFT: Sprint"] and active.color[2] > idle.color[2])
                assert(active.right + 12 < helpLeft)
                held = {d = true}; game:update(.02); draw(); assert(labels["SHIFT: Sprint"] and not labels.SPRINT)
                held.lshift = true; H.paddle(game).position.x = Config.WIDTH - H.paddle(game).collider.w
                game:update(.02); draw(); assert(labels["SHIFT: Sprint"] and not labels.SPRINT)
                game:keypressed("p"); draw(); assert(not labels.SPRINT)
            end, debug.traceback)
            love.graphics.setCanvas()
            love.graphics.print, love.graphics.printf = printText, printf
            love.graphics.newFont, love.graphics.newImage, love.graphics.newCanvas = font, image, newCanvas
            canvas:release(); assert(success, failure)
        end)

        test("ECS_ASSIGNMENT_MODE mantiene el cierre en ambos laterales con sprint", function()
            Config.ECS_ASSIGNMENT_MODE = true
            for _, right in ipairs({false, true}) do
                local game = H.newGame(); local ball = H.balls(game)[1]
                ball.position.x, ball.position.y = right and Config.WIDTH - ball.collider.w or 0, 450
                ball.velocity.vx, ball.velocity.vy = 0, -200
                local before = quits; held = {a = true, lshift = true}; game:update(.02)
                assert(game.quitRequested and quits == before + 1 and game.lives == 3)
                assert(ball.velocity.vx == 0 and ball.velocity.vy == -200)
            end
            Config.ECS_ASSIGNMENT_MODE = false
        end)
    end, debug.traceback)
    love.keyboard.isDown, love.event.quit, Config.ECS_ASSIGNMENT_MODE = keyboard, quit, mode
    if not ok then error(err, 0) end
    return passed
end

return {run = run}

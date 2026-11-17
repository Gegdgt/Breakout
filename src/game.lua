-- Controlador: conecta entidades, fisica, reglas y dibujado.
local Config = require("src.config")
local Collision = require("src.collision")
local Paddle = require("src.paddle")
local Ball = require("src.ball")
local Bricks = require("src.bricks")
local Powerups = require("src.powerups")

local Game = {}
Game.__index = Game

function Game.new()
    local self = setmetatable({}, Game)
    self.font = love.graphics.newFont(15)
    self.titleFont = love.graphics.newFont(27)
    self.messageFont = love.graphics.newFont(48)
    self:reset()
    return self
end

function Game:reset()
    self.state = "playing"
    self.lives = Config.STARTING_LIVES
    self:resetRound()
    self.bricks = Bricks.create(Config)
    self.remaining = #self.bricks
end

-- Reponer las entidades moviles sin restaurar los bloques destruidos.
function Game:resetRound()
    self.paddle = Paddle.new(Config)
    self.balls = {Ball.new(Config)}
    self.powerups = Powerups.new(Config)
end

function Game:activatePowerup(kind)
    if self.state ~= "playing" then
        return
    end

    if kind == Powerups.MULTIBALL then
        local originalCount = #self.balls
        local angle = math.rad(Config.MULTIBALL_SPREAD_DEGREES)
        -- Solo multiplicar las originales, nunca sus copias en este recorrido.
        for index = 1, originalCount do
            local original = self.balls[index]
            for direction = -1, 1, 2 do
                if #self.balls >= Config.MAX_BALLS then
                    return
                end
                self.balls[#self.balls + 1] = original:cloneRotated(direction * angle, Config)
            end
        end
    end
end

function Game:update(dt)
    if self.state ~= "playing" then
        return
    end

    -- Evita saltos enormes si se arrastra la ventana o se pausa el equipo.
    dt = math.min(dt, 0.05)
    self.paddle:update(dt)

    for index = #self.balls, 1, -1 do
        if not self:updateBall(self.balls[index], dt) then
            table.remove(self.balls, index)
        end
        -- La victoria tiene prioridad sobre caidas y poderes en este frame.
        if self.state == "won" then
            return
        end
    end

    -- Evaluar una sola vez, despues de retirar todas las pelotas que cayeron.
    if #self.balls == 0 then
        self.lives = self.lives - 1
        if self.lives > 0 then
            self:resetRound()
        else
            self.state = "lost"
            print("Game Over")
            io.stdout:flush()
        end
        return
    end

    local collected = self.powerups:update(dt, self.paddle)
    for _, powerup in ipairs(collected) do
        self:activatePowerup(powerup.kind)
    end
end

-- Devuelve false si esta pelota sale por abajo; no descuenta vidas aqui.
function Game:updateBall(ball, dt)
    local previousX, previousY = ball.x, ball.y
    ball:update(dt)

    -- Pared izquierda y derecha: invertir movimiento en X.
    if ball.x < 0 then
        ball.x = 0
        ball.vx = math.abs(ball.vx)
    elseif ball.x + ball.w > Config.WIDTH then
        ball.x = Config.WIDTH - ball.w
        ball.vx = -math.abs(ball.vx)
    end

    -- Pared superior: invertir movimiento en Y.
    if ball.y < 0 then
        ball.y = 0
        ball.vy = math.abs(ball.vy)
    end

    if ball.y + ball.h >= Config.HEIGHT then
        return false
    end

    -- Paddle: invertir X (lo solicitado) y Y (para volver a subir).
    if ball.vy > 0 and Collision.overlaps(ball, self.paddle) then
        ball.y = self.paddle.y - ball.h
        local multiplier = Config.PADDLE_SPEED_MULTIPLIER
        ball.vx = -ball.vx * multiplier
        ball.vy = -math.abs(ball.vy) * multiplier
    end

    -- Quitar un bloque cuando la pelota lo toca.
    for index = #self.bricks, 1, -1 do
        local brick = self.bricks[index]
        if Collision.overlaps(ball, brick) then
            Collision.bounceFromBrick(ball, brick, previousX, previousY)
            table.remove(self.bricks, index)
            self.remaining = #self.bricks
            -- El bloque ya no existe para las demas pelotas de este frame.
            self.powerups:trySpawn(brick)

            if self.remaining == 0 then
                self.state = "won"
                print("You Win!")
                io.stdout:flush()
            end
            break
        end
    end
    return true
end

function Game:draw()
    love.graphics.clear(0.040, 0.075, 0.095)

    -- Titulo y controles.
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.93, 0.96, 0.99)
    love.graphics.printf("BREAKOUT", 0, 19, Config.WIDTH, "center")

    love.graphics.setFont(self.font)
    love.graphics.print("Vidas: " .. self.lives, 44, 25)
    love.graphics.setColor(0.69, 0.77, 0.83)
    love.graphics.print("Bloques restantes: " .. self.remaining, 44, 58)
    love.graphics.printf("Pelotas: " .. #self.balls .. " / " .. Config.MAX_BALLS,
                         0, 58, Config.WIDTH - 44, "right")
    love.graphics.printf("Mover: A / D o flechas   |   ESC: salir", 0, 614,
                         Config.WIDTH, "center")

    Bricks.draw(self.bricks)
    self.powerups:draw(self.font)
    self.paddle:draw()
    for _, ball in ipairs(self.balls) do
        ball:draw()
    end

    if self.state == "won" or self.state == "lost" then
        local centerY = Config.HEIGHT / 2
        local message = self.state == "won" and "YOU WIN!" or "GAME OVER"
        love.graphics.setColor(0.04, 0.075, 0.095, 0.88)
        love.graphics.rectangle("fill", 0, centerY - 78, Config.WIDTH, 156)
        if self.state == "won" then
            love.graphics.setColor(0.30, 0.90, 0.42)
        else
            love.graphics.setColor(1.00, 0.25, 0.25)
        end
        love.graphics.setFont(self.messageFont)
        -- Negrita simulada con la fuente integrada, sin archivos externos.
        love.graphics.printf(message, -1, centerY - 48, Config.WIDTH, "center")
        love.graphics.printf(message, 1, centerY - 48, Config.WIDTH, "center")
        love.graphics.printf(message, 0, centerY - 49, Config.WIDTH, "center")
        love.graphics.printf(message, 0, centerY - 47, Config.WIDTH, "center")
        love.graphics.printf(message, 0, centerY - 48, Config.WIDTH, "center")
        love.graphics.setColor(0.93, 0.96, 0.99)
        love.graphics.setFont(self.font)
        love.graphics.printf("Presiona R para volver a jugar", 0, centerY + 24,
                             Config.WIDTH, "center")
    end
end

return Game

local Paddle = {}
Paddle.__index = Paddle

function Paddle.new(config)
    local self = setmetatable({}, Paddle)
    self.x = (config.WIDTH - config.PADDLE_W) / 2
    self.y = config.PADDLE_Y
    self.w = config.PADDLE_W
    self.h = config.PADDLE_H
    self.speed = config.PADDLE_SPEED
    self.screenWidth = config.WIDTH
    return self
end

function Paddle:update(dt)
    local direction = 0
    if love.keyboard.isDown("left", "a") then
        direction = direction - 1
    end
    if love.keyboard.isDown("right", "d") then
        direction = direction + 1
    end

    -- Movimiento time-based: velocidad (px/s) por tiempo transcurrido (s).
    self.x = self.x + direction * self.speed * dt
    self.x = math.max(0, math.min(self.x, self.screenWidth - self.w))
end

function Paddle:draw()
    love.graphics.setColor(0.78, 0.83, 0.88)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 5, 5)
    love.graphics.setColor(0.44, 0.52, 0.60)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 5, 5)
end

return Paddle

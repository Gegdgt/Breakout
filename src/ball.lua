local Ball = {}
Ball.__index = Ball

function Ball.new(config)
    local self = setmetatable({}, Ball)
    self.w = config.BALL_SIZE
    self.h = config.BALL_SIZE
    self.x = (config.WIDTH - self.w) / 2
    self.y = config.PADDLE_Y - 85
    self.vx = config.BALL_START_VX
    self.vy = config.BALL_START_VY
    return self
end

function Ball:update(dt)
    -- Delta time evita que la pelota dependa de los FPS.
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
end

-- Copiar la pelota y rotar su velocidad sin cambiar su rapidez.
function Ball:cloneRotated(angle, config)
    local clone = Ball.new(config)
    clone.x, clone.y = self.x, self.y
    clone.w, clone.h = self.w, self.h

    local vx, vy = self.vx, self.vy
    local speed = math.sqrt(vx * vx + vy * vy)
    if speed < 0.000001 then
        vx, vy = config.BALL_START_VX, config.BALL_START_VY
        speed = math.sqrt(vx * vx + vy * vy)
    end

    local cosine, sine = math.cos(angle), math.sin(angle)
    local rotatedX = vx * cosine - vy * sine
    local rotatedY = vx * sine + vy * cosine
    -- Evitar trayectorias casi horizontales o verticales tras la rotacion.
    local minimumAxisSpeed = speed * 0.10
    if math.abs(rotatedX) < minimumAxisSpeed then
        rotatedX = (rotatedX < 0 and -1 or 1) * minimumAxisSpeed
    end
    if math.abs(rotatedY) < minimumAxisSpeed then
        rotatedY = (rotatedY < 0 and -1 or 1) * minimumAxisSpeed
    end
    local rotatedSpeed = math.sqrt(rotatedX * rotatedX + rotatedY * rotatedY)
    clone.vx = rotatedX * speed / rotatedSpeed
    clone.vy = rotatedY * speed / rotatedSpeed
    return clone
end

function Ball:draw()
    love.graphics.setColor(0.98, 0.98, 0.98)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end

return Ball

-- Objetos que caen: generacion, movimiento, recoleccion y dibujado.
local Collision = require("src.collision")

local Powerups = {}
Powerups.__index = Powerups
Powerups.MULTIBALL = "multiball"

local types = {
    [Powerups.MULTIBALL] = {
        name = "MULTIBALL x3",
        label = "x3",
        color = {0.98, 0.81, 0.35},
    },
}

function Powerups.new(config)
    return setmetatable({items = {}, config = config}, Powerups)
end

function Powerups:spawn(kind, centerX, centerY)
    local definition = assert(types[kind], "Tipo de power-up desconocido")
    local item = {
        kind = kind,
        name = definition.name,
        x = centerX - self.config.POWERUP_W / 2,
        y = centerY - self.config.POWERUP_H / 2,
        w = self.config.POWERUP_W,
        h = self.config.POWERUP_H,
        vy = self.config.POWERUP_FALL_SPEED,
    }
    self.items[#self.items + 1] = item
    return item
end

function Powerups:trySpawn(brick)
    if love.math.random() < self.config.POWERUP_DROP_CHANCE then
        return self:spawn(Powerups.MULTIBALL,
                          brick.x + brick.w / 2, brick.y + brick.h / 2)
    end
end

function Powerups:update(dt, paddle)
    local collected = {}
    -- Recorrer al reves permite retirar objetos sin saltarse el siguiente.
    for index = #self.items, 1, -1 do
        local item = self.items[index]
        item.y = item.y + item.vy * dt
        if Collision.overlaps(item, paddle) then
            table.remove(self.items, index)
            collected[#collected + 1] = item
        elseif item.y >= self.config.HEIGHT then
            table.remove(self.items, index)
        end
    end
    return collected
end

function Powerups:draw(font)
    love.graphics.setFont(font)
    for _, item in ipairs(self.items) do
        local definition = types[item.kind]
        love.graphics.setColor(definition.color)
        love.graphics.rectangle("fill", item.x, item.y, item.w, item.h, 3, 3)
        love.graphics.setColor(0.08, 0.10, 0.14)
        love.graphics.printf(definition.label, item.x,
                             item.y + (item.h - font:getHeight()) / 2,
                             item.w, "center")
    end
end

return Powerups

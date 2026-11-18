-- Todo el dibujo de entidades depende de Position + Collider + Renderable.
local RenderSystem = {}

function RenderSystem.drawEntities(world, font)
    local ids = world:query("Position", "Collider", "Renderable")
    table.sort(ids, function(a, b)
        local first, second = world:get(a, "Renderable"), world:get(b, "Renderable")
        if first.layer == second.layer then return a < b end
        return first.layer < second.layer
    end)
    love.graphics.setFont(font)
    for _, id in ipairs(ids) do
        local position = world:get(id, "Position")
        local collider = world:get(id, "Collider")
        local visual = world:get(id, "Renderable")
        love.graphics.setColor(visual.color)
        love.graphics.rectangle("fill", position.x, position.y, collider.w, collider.h,
                                visual.radius, visual.radius)
        if visual.borderColor then
            love.graphics.setColor(visual.borderColor)
            love.graphics.rectangle("line", position.x, position.y, collider.w, collider.h,
                                    visual.radius, visual.radius)
        end
        if visual.highlight then
            love.graphics.setColor(1, 1, 1, 0.12)
            love.graphics.rectangle("fill", position.x + 2, position.y + 2, collider.w - 4, 2)
        end
        if visual.label then
            love.graphics.setColor(visual.labelColor)
            love.graphics.printf(visual.label, position.x,
                position.y + (collider.h - font:getHeight()) / 2, collider.w, "center")
        end
    end
end

function RenderSystem.draw(self)
    local Config = self.config
    love.graphics.clear(0.040, 0.075, 0.095)

    -- Titulo y controles.
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.93, 0.96, 0.99)
    love.graphics.printf("BREAKOUT", 0, 19, Config.WIDTH, "center")

    love.graphics.setFont(self.font)
    love.graphics.print("Vidas: " .. self.lives, 44, 25)
    love.graphics.setColor(0.69, 0.77, 0.83)
    love.graphics.print("Bloques restantes: " .. self.remaining, 44, 58)
    love.graphics.printf("Pelotas: " .. self.world:count("Ball") .. " / " .. Config.MAX_BALLS,
                         0, 58, Config.WIDTH - 44, "right")
    love.graphics.printf("Mover: A / D o flechas   |   ESC: salir", 0, 614,
                         Config.WIDTH, "center")

    RenderSystem.drawEntities(self.world, self.font)

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

return RenderSystem

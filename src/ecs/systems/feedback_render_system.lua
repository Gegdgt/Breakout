local Render = {}

function Render.particles(game)
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.intersectScissor(0, game.config.BRICK_TOP, game.config.WIDTH, game.config.HEIGHT - game.config.BRICK_TOP - 20)
    for _, id in ipairs(game.world:query("Particle", "Position", "Renderable")) do
        local p, particle, visual = game.world:get(id, "Position"), game.world:get(id, "Particle"), game.world:get(id, "Renderable")
        local size = particle.size * (0.5 + 0.5 * particle.remaining / particle.duration)
        love.graphics.setColor(visual.color[1], visual.color[2], visual.color[3], visual.alpha)
        love.graphics.rectangle("fill", p.x - size / 2, p.y - size / 2, size, size)
    end
    if sx then love.graphics.setScissor(sx, sy, sw, sh) else love.graphics.setScissor() end
end

function Render.ballCore(game, position, collider)
    local size = game.config.BALL_VISUAL_CORE_SIZE
    love.graphics.setColor(1, 1, 0.95)
    love.graphics.rectangle("fill", position.x + (collider.w - size) / 2, position.y + (collider.h - size) / 2, size, size)
end

return Render

-- El renderizador de entidades se conserva; HUD y pantallas tienen sus propios sistemas.
local RenderSystem = {}
local BossRender = require("src.ecs.systems.boss_render_system")
local Hud = require("src.ecs.systems.hud_render_system")
local Screen = require("src.ecs.systems.screen_render_system")
local FeedbackRender = require("src.ecs.systems.feedback_render_system")

function RenderSystem.drawEntities(world, font, labelFont, game)
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
        local alpha = visual.alpha or 1
        love.graphics.setColor(visual.color[1], visual.color[2], visual.color[3], alpha)
        if visual.shape == "ring" then
            love.graphics.ellipse("line", position.x + collider.w / 2, position.y + collider.h / 2, collider.w / 2, collider.h / 2)
            love.graphics.ellipse("line", position.x + collider.w / 2, position.y + collider.h / 2, collider.w / 2 - 3, collider.h / 2 - 3)
        else
            love.graphics.rectangle("fill", position.x, position.y, collider.w, collider.h, visual.radius, visual.radius)
        end
        if visual.borderColor then
            love.graphics.setColor(visual.borderColor[1], visual.borderColor[2], visual.borderColor[3], alpha)
            love.graphics.rectangle("line", position.x, position.y, collider.w, collider.h,
                                    visual.radius, visual.radius)
        end
        if visual.highlight then
            love.graphics.setColor(1, 1, 1, 0.12 * alpha)
            love.graphics.rectangle("fill", position.x + 2, position.y + 2, collider.w - 4, 2)
        end
        if visual.label then
            local textFont = world:has(id, "BossSupport") and labelFont or font
            love.graphics.setFont(textFont)
            love.graphics.setColor(visual.labelColor[1], visual.labelColor[2], visual.labelColor[3], alpha)
            love.graphics.printf(visual.label, position.x,
                position.y + (collider.h - textFont:getHeight()) / 2, collider.w, "center")
            love.graphics.setFont(font)
        end
        if game and world:has(id, "Boss") then BossRender.body(game, id) end
        if game and world:has(id, "Ball") then FeedbackRender.ballCore(game, position, collider) end
        local pickup = world:get(id, "PowerUp")
        if pickup and labelFont then
            love.graphics.setFont(labelFont)
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf(pickup.name, math.max(0, math.min(position.x + collider.w / 2 - 55,
                love.graphics.getWidth() - 110)), position.y + collider.h + 1, 110, "center")
            love.graphics.setFont(font)
        end
    end
end

function RenderSystem.draw(game)
    love.graphics.clear(game.level.theme.background)
    if Screen.fullscreen(game) then return end
    Hud.header(game)
    BossRender.signals(game)
    FeedbackRender.particles(game)
    RenderSystem.drawEntities(game.world, game.font, game.effectFont, game)
    Hud.effects(game)
    Screen.overlay(game)
end

return RenderSystem

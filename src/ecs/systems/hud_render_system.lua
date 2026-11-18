-- HUD dentro de la franja superior existente; no cambia el area de colision.
local Effects = require("src.ecs.systems.power_effect_system")
local BossRender = require("src.ecs.systems.boss_render_system")
local ScoreRender = require("src.ecs.systems.score_render_system")
local Hud = {}

function Hud.header(game)
    local config = game.config
    love.graphics.setColor(0.04, 0.07, 0.10, 0.8)
    love.graphics.rectangle("fill", 0, 0, config.WIDTH, 92)
    love.graphics.setColor(0.18, 0.25, 0.32)
    love.graphics.line(44, 53, config.WIDTH - 44, 53)
    if not BossRender.title(game) then
        love.graphics.setFont(game.titleFont)
        love.graphics.setColor(game.level.theme.primary)
        love.graphics.printf("BREAKOUT", 310, 14, config.WIDTH - 620, "center")
    end
    love.graphics.setFont(game.font)
    love.graphics.setColor(0.93, 0.96, 0.99)
    love.graphics.print("Vidas: " .. game.lives, 44, 25)
    love.graphics.setColor(0.69, 0.77, 0.83)
    love.graphics.print("Bloques restantes: " .. game.remaining, 44, 58)
    love.graphics.printf("Pelotas: " .. game.world:count("Ball") .. " / " .. config.MAX_BALLS,
        0, 58, config.WIDTH - 44, "right")
    love.graphics.printf("Nivel " .. game.levelIndex .. " / " .. game.levels:count() .. " — " .. game.level.name,
        240, 58, config.WIDTH - 480, "center")
    if game.state == "playing" then
        love.graphics.setFont(game.effectFont)
        local control = game.world:get(game.paddleId, "PaddleControl")
        local sprinting = control and control.sprinting
        if sprinting then love.graphics.setColor(0.35, 0.92, 0.55)
        else love.graphics.setColor(0.69, 0.77, 0.83) end
        love.graphics.print(sprinting and "SPRINT" or "SHIFT: Sprint", 20, 620)
        love.graphics.setColor(0.69, 0.77, 0.83)
        love.graphics.printf("A / D o flechas: mover   |   Espacio: lanzar / láser   |   ESC / P: pausa   |   M: menú",
            0, 620, config.WIDTH, "center")
    end
    ScoreRender.hud(game)
end

function Hud.effects(game)
    local timers, power = Effects.get(game)
    if not timers then return end
    local labels = {}
    for _, kind in ipairs({"giant_paddle", "fireball", "magnet", "shield"}) do
        if timers[kind] > 0 then
            local name = game.config.POWERUP_TYPES[kind].name
            local shield = power.shieldId and game.world:get(power.shieldId, "Shield")
            if kind == "shield" and shield then name = name .. " " .. shield.hits .. "/" .. shield.maximum end
            labels[#labels + 1] = name .. " " .. math.ceil(timers[kind]) .. "s"
        end
    end
    if power.ammo > 0 then labels[#labels + 1] = "LASER: " .. power.ammo end
    if power.heldBall then labels[#labels + 1] = "Espacio: lanzar" end
    love.graphics.setFont(game.effectFont)
    love.graphics.setColor(0.95, 0.92, 0.78)
    love.graphics.printf(table.concat(labels, "   |   "), 44, 78, game.config.WIDTH - 88, "center")
    local p, c = game.world:get(game.paddleId, "Position"), game.world:get(game.paddleId, "Collider")
    if timers.magnet > 0 then
        love.graphics.setColor(game.config.POWERUP_TYPES.magnet.color)
        love.graphics.rectangle("line", p.x, p.y, c.w, c.h, 5, 5)
    end
    if power.ammo > 0 then
        love.graphics.setColor(game.config.POWERUP_TYPES.laser.color)
        love.graphics.rectangle("fill", p.x + c.w * 0.12 - 3, p.y - 5, 6, 8)
        love.graphics.rectangle("fill", p.x + c.w * 0.88 - 3, p.y - 5, 6, 8)
    end
end

return Hud

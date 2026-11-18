-- Solo presentacion, con las fuentes existentes y geometria sencilla.
local Render = {}
function Render.title(game)
    local world, id = game.world, game.bossId
    if not world:has(id, "Boss") then return false end
    local boss, health, definition = world:get(id, "Boss"), world:get(id, "Health"), world:get(id, "BossBehavior")
    local phase = definition.phases and definition.phases[boss.phase].name or "Guardian"
    love.graphics.setFont(game.font)
    love.graphics.setColor(game.level.theme.primary)
    love.graphics.printf(game.level.name, 310, 4, game.config.WIDTH - 620, "center")
    love.graphics.setFont(game.effectFont)
    love.graphics.setColor(0.93, 0.96, 0.99)
    love.graphics.printf(health.current .. " / " .. health.maximum .. "   |   Fase " .. boss.phase .. " / "
        .. (definition.phases and #definition.phases or 1) .. " - " .. phase, 310, 25, game.config.WIDTH - 620, "center")
    local x, width = game.config.WIDTH / 2 - 120, 240
    love.graphics.setColor(0.18, 0.24, 0.3)
    love.graphics.rectangle("fill", x, 44, width, 6, 2, 2)
    love.graphics.setColor(game.level.theme.primary)
    love.graphics.rectangle("fill", x, 44, width * health.current / health.maximum, 6, 2, 2)
    return true
end

function Render.body(game, id)
    local world = game.world
    local boss, p, c = world:get(id, "Boss"), world:get(id, "Position"), world:get(id, "Collider")
    if boss.defeated then return end
    local weak = world:get(id, "BossBehavior").weakPoint
    local open = world:get(id, "Damageable").enabled
    if boss.flash > 0 then
        love.graphics.setColor(1, 1, 1, 0.65 * boss.flash / game.config.BOSS_HIT_FLASH)
        love.graphics.rectangle("fill", p.x, p.y, c.w, c.h, 7, 7)
    end
    if open then love.graphics.setColor(0.3, 1, 0.65)
    else love.graphics.setColor(0.38, 0.43, 0.5) end
    love.graphics.rectangle("fill", p.x + weak.x, p.y + weak.y, weak.w, weak.h, 3, 3)
    love.graphics.setFont(game.effectFont)
    love.graphics.setColor(0.05, 0.1, 0.12)
    love.graphics.printf(open and "GOLPEA" or "CERRADO", p.x + weak.x, p.y + weak.y + 3, weak.w, "center")
    love.graphics.setColor(1, 0.85, 0.35)
    love.graphics.printf(boss.warning or (open and "PUNTO DEBIL" or "DEFENSA"), p.x, p.y + 12, c.w, "center")
    love.graphics.setFont(game.font)
end

function Render.signals(game)
    local world, id = game.world, game.bossId
    local boss = world:get(id, "Boss")
    if not boss then return end
    local p, c = world:get(id, "Position"), world:get(id, "Collider")
    if boss.defeated then
        local ratio = boss.defeatElapsed / game.config.BOSS_DEFEAT_SECONDS
        if ratio < 1 then
            love.graphics.setColor(0.9, 0.7, 1, 1 - ratio)
            love.graphics.circle("line", p.x + c.w / 2, p.y + c.h / 2, c.w / 2 + 100 * ratio)
            love.graphics.circle("line", p.x + c.w / 2, p.y + c.h / 2, 20 + 65 * ratio)
        end
        return
    end
    if boss.warning and boss.destinationX then
        love.graphics.setColor(1, 0.8, 0.3, 0.5)
        love.graphics.rectangle("line", boss.destinationX, boss.destinationY or p.y, c.w, c.h, 7, 7)
    end
    if boss.aimX then
        love.graphics.setColor(1, 0.5, 0.35, 0.4)
        love.graphics.line(p.x + c.w / 2, p.y + c.h + 3, boss.aimDisplayX or boss.aimX, world:get(game.paddleId, "Position").y)
    end
    local protection = world:get(game.paddleId, "Invulnerability")
    if protection and protection.remaining > 0 then
        local pp, pc = world:get(game.paddleId, "Position"), world:get(game.paddleId, "Collider")
        love.graphics.setColor(0.55, 0.9, 1, 0.5 + 0.3 * math.sin(protection.remaining * 15))
        love.graphics.rectangle("line", pp.x - 3, pp.y - 3, pc.w + 6, pc.h + 6, 6, 6)
    end
end

function Render.victory(game)
    local boss = game.world:get(game.bossId, "Boss")
    if game.state == "campaign_complete" and boss and boss.defeated then
        love.graphics.setFont(game.titleFont)
        love.graphics.setColor(game.level.theme.primary)
        love.graphics.printf("NUCLEO DEL CAOS DESACTIVADO", 0, 205, game.config.WIDTH, "center")
        love.graphics.setFont(game.effectFont)
        love.graphics.setColor(0.9, 0.85, 1)
        love.graphics.printf("Defensa, Ataque y Caos superados", 0, 236, game.config.WIDTH, "center")
    end
end
return Render

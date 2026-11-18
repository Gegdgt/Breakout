local Data = require("src.ui.encyclopedia_data")
local State = require("src.ecs.systems.state_system")
local Feedback = require("src.feedback")
local Controls = require("src.controls")
local BossRules = require("src.boss_rules")
local Encyclopedia = {}

function Encyclopedia.open(game)
    if not State.change(game, "encyclopedia") then return false end
    game.ui.encyclopedia = {category = 1, entry = 1, scroll = 0, categories = Data.build(game)}
    return true
end

function Encyclopedia.layout(game)
    local w, h = game.config.WIDTH, game.config.HEIGHT
    local margin, gap = 28, 16
    local listW = math.min(224, w * 0.25)
    return {margin = margin, tabW = (w - 2 * margin - 3 * gap) / 4, gap = gap,
        listW = listW, x = margin + listW + gap, y = 162,
        w = w - 2 * margin - listW - gap, h = h - 238, bottom = h - 58}
end

local function content(game)
    local ui = game.ui.encyclopedia
    return ui.categories[ui.category].entries[ui.entry]
end

-- Mismo ajuste de lineas para calcular scroll y dibujar: no recortar texto largo.
function Encyclopedia.lines(game)
    local g, lines = Encyclopedia.layout(game), {}
    for _, paragraph in ipairs(content(game).paragraphs) do
        local _, wrapped = game.font:getWrap(paragraph, g.w - 48)
        for _, line in ipairs(wrapped) do lines[#lines + 1] = line:gsub("%s+$", "") end
        lines[#lines + 1] = ""
    end
    local height = #lines * (game.font:getHeight() + 6)
    return lines, math.max(0, height - (g.h - 148))
end

function Encyclopedia.scroll(game, delta)
    local ui = game.ui.encyclopedia
    local _, maximum = Encyclopedia.lines(game)
    ui.scroll = math.max(0, math.min(maximum, ui.scroll + delta))
end

local function select(game, category, entry)
    local ui = game.ui.encyclopedia
    ui.category, ui.entry, ui.scroll = category, entry, 0
    Feedback.emit(game, "ui")
end

local function back(game)
    game:goToMenu()
    game.ui.selection = 4
end

function Encyclopedia.keypressed(game, key)
    local ui = game.ui.encyclopedia
    if key == "escape" or Controls.matches(game.config, "menu", key) then back(game)
    elseif key == "left" or key == "a" then select(game, (ui.category - 2) % #ui.categories + 1, 1)
    elseif key == "right" or key == "d" or key == "tab" then select(game, ui.category % #ui.categories + 1, 1)
    elseif key == "up" or key == "w" then select(game, ui.category, (ui.entry - 2) % #ui.categories[ui.category].entries + 1)
    elseif key == "down" or key == "s" then select(game, ui.category, ui.entry % #ui.categories[ui.category].entries + 1)
    elseif key == "pagedown" then Encyclopedia.scroll(game, 150)
    elseif key == "pageup" then Encyclopedia.scroll(game, -150)
    elseif key == "home" then Encyclopedia.scroll(game, -math.huge)
    elseif key == "end" then Encyclopedia.scroll(game, math.huge) end
    return true
end

function Encyclopedia.mousepressed(game, x, y)
    local g, ui = Encyclopedia.layout(game), game.ui.encyclopedia
    if y >= g.bottom and y <= g.bottom + 34 and x >= g.margin and x <= g.margin + 140 then back(game); return end
    for i = 1, #ui.categories do
        local tx = g.margin + (i - 1) * (g.tabW + g.gap)
        if x >= tx and x <= tx + g.tabW and y >= 102 and y <= 144 then select(game, i, 1); return end
    end
    local rowH = math.min(47, g.h / #ui.categories[ui.category].entries)
    if x >= g.margin and x <= g.margin + g.listW and y >= g.y then
        local row = math.floor((y - g.y) / rowH) + 1
        if row <= #ui.categories[ui.category].entries then select(game, ui.category, row) end
    end
end

local function label(font, text, x, y, width, color, align)
    love.graphics.setFont(font)
    love.graphics.setColor(color or {0.9, 0.95, 1})
    love.graphics.printf(text, x, y, width, align or "left")
end

local function box(x, y, w, h, selected)
    love.graphics.setColor(selected and {0.10, 0.24, 0.30} or {0.065, 0.105, 0.16})
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(selected and {0.3, 0.85, 1} or {0.18, 0.27, 0.34})
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
end

local function icon(game, entry, x, y)
    love.graphics.setColor(entry.color)
    if entry.visual == "boss" then
        local b = entry.boss
        local scale = 0.8
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.scale(scale)
        love.graphics.setColor(0.19, 0.25, 0.33)
        love.graphics.rectangle("fill", 0, 0, b.w, b.h, 6, 6)
        local main, top = BossRules.weakPoint(b, game.config), BossRules.topWeakPoint(b, game.config)
        love.graphics.setColor(0.3, 1, 0.65)
        love.graphics.rectangle("fill", main.x, main.y, main.w, main.h, 3, 3)
        love.graphics.setColor(0.35, 0.85, 1)
        love.graphics.rectangle("fill", top.x, top.y, top.w, top.h, 3, 3)
        love.graphics.pop()
        label(game.effectFont, "AZUL: SUPERIOR\nVERDE: FRONTAL", x + 142, y + 14, 190)
    else
        love.graphics.rectangle("fill", x, y + 8, 88, 38, 5, 5)
        if entry.id == "unbreakable" or entry.id == "armored" then
            love.graphics.setColor(0.85, 0.93, 1)
            love.graphics.rectangle("line", x + 3, y + 11, 82, 32, 3, 3)
        end
        label(game.font, entry.label, x, y + 18, 88, {0.04, 0.07, 0.1}, "center")
    end
end

function Encyclopedia.draw(game)
    local ui, g, entry = game.ui.encyclopedia, Encyclopedia.layout(game), content(game)
    local accent, muted = {0.35, 0.85, 1}, {0.6, 0.73, 0.83}
    label(game.effectFont, "BREAKOUT ARCADE / GUÍA DE CAMPO", g.margin, 25, game.config.WIDTH - 56, accent)
    label(game.titleFont, "ENCICLOPEDIA", g.margin, 50, game.config.WIDTH - 56)
    for i, category in ipairs(ui.categories) do
        local x = g.margin + (i - 1) * (g.tabW + g.gap)
        box(x, 102, g.tabW, 42, ui.category == i)
        label(game.effectFont, category.name, x + 8, 117, g.tabW - 16, nil, "center")
    end
    local entries = ui.categories[ui.category].entries
    local rowH = math.min(47, g.h / #entries)
    for i, item in ipairs(entries) do
        local y = g.y + (i - 1) * rowH
        box(g.margin, y, g.listW, rowH - 6, ui.entry == i)
        label(game.font, item.name, g.margin + 12, y + 10, g.listW - 24, ui.entry == i and accent or muted)
    end
    box(g.x, g.y, g.w, g.h, false)
    local titleColor = entry.id == "unbreakable" and {0.78, 0.86, 0.94} or entry.color
    label(game.titleFont, entry.name, g.x + 24, g.y + 18, g.w - 48, titleColor)
    icon(game, entry, g.x + 24, g.y + 58)
    local lines, maximum = Encyclopedia.lines(game)
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.setScissor(g.x + 20, g.y + 132, g.w - 40, g.h - 148)
    for i, line in ipairs(lines) do
        label(game.font, line, g.x + 24, g.y + 132 + (i - 1) * (game.font:getHeight() + 6) - ui.scroll, g.w - 48)
    end
    if sx then love.graphics.setScissor(sx, sy, sw, sh) else love.graphics.setScissor() end
    if maximum > 0 then
        local track = g.h - 148
        local thumb = math.max(24, track * track / (maximum + track))
        love.graphics.setColor(accent)
        love.graphics.rectangle("fill", g.x + g.w - 10, g.y + 132 + (track - thumb) * ui.scroll / maximum, 3, thumb, 2, 2)
    end
    box(g.margin, g.bottom, 140, 34, false)
    label(game.effectFont, "ESC · VOLVER", g.margin, g.bottom + 10, 140, accent, "center")
    label(game.effectFont, "A/D: categoría   W/S: ficha   Rueda / RePág / AvPág: desplazar", g.margin + 160, g.bottom + 10, game.config.WIDTH - g.margin * 2 - 160, muted)
end

return Encyclopedia

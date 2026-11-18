local Components = require("src.ecs.components")
local Ball = require("src.ball")
local Feedback = require("src.feedback")
local Portals = {}

function Portals.create(world, level)
    for pairIndex, pair in ipairs(level.portals) do
        local ids = {}
        for index, endpoint in ipairs({pair.entry, pair.exit}) do
            local visual = Components.renderable(index == 1 and {0.2, 0.85, 1} or {0.85, 0.45, 1}, endpoint.radius, 12)
            visual.shape, visual.label, visual.labelColor = "ring", string.char(64 + pairIndex) .. index, {1, 1, 1}
            ids[index] = world:create({Position = Components.position(endpoint.x - endpoint.radius, endpoint.y - endpoint.radius),
                Collider = Components.collider(endpoint.radius * 2, endpoint.radius * 2), Renderable = visual,
                Portal = {pair = pair.id, cooldown = pair.cooldown,
                    rotation = math.rad(pair.rotationDegrees) * (index == 1 and 1 or -1)}})
        end
        world:get(ids[1], "Portal").target = ids[2]
        world:get(ids[2], "Portal").target = ids[1]
    end
end

-- Entrada circular barrida: tambien detecta una pelota que cruza entre dos frames.
local function entryTime(x, y, dx, dy, cx, cy, radius)
    local ox, oy = x - cx, y - cy
    local c = ox * ox + oy * oy - radius * radius
    if c <= 0 then return 0 end
    local a = dx * dx + dy * dy
    if a == 0 then return nil end
    local b = 2 * (ox * dx + oy * dy)
    local d = b * b - 4 * a * c
    if d < 0 then return nil end
    local t = (-b - math.sqrt(d)) / (2 * a)
    if t >= 0 and t <= 1 then return t end
end

local function blocked(world, ids, x, y, size)
    for _, id in ipairs(ids) do
        if world:has(id, "Position", "Collider") then
            -- Incluso los fantasmas intangibles: no salir dentro de un futuro solido.
            local p, c = world:get(id, "Position"), world:get(id, "Collider")
            if x < p.x + c.w and x + size.w > p.x and y < p.y + c.h and y + size.h > p.y then return true end
        end
    end
    return false
end

local function exitPosition(game, target, size, vx, vy, solids, portals)
    local world, config = game.world, game.config
    local p, c = world:get(target, "Position"), world:get(target, "Collider")
    local radius, half = c.w / 2, math.sqrt(size.w * size.w + size.h * size.h) / 2
    local angle = math.atan2(vy, vx)
    local paddleY = world:get(game.paddleId, "Position").y
    for step = 1, config.PORTAL_EXIT_SEARCH_STEPS do
        for turn = 0, 7 do
            local direction = angle + turn * math.pi / 4
            local distance = radius + half + 1 + (step - 1) * size.w
            local x = p.x + radius + math.cos(direction) * distance - size.w / 2
            local y = p.y + radius + math.sin(direction) * distance - size.h / 2
            if x > 0 and y >= config.BRICK_TOP and x + size.w < config.WIDTH and y + size.h < paddleY
                and not blocked(world, solids, x, y, size) and not blocked(world, portals, x, y, size) then return x, y end
        end
    end
end

local function pulse(world, id, config)
    local p, c, visual = world:get(id, "Position"), world:get(id, "Collider"), world:get(id, "Renderable")
    local render = Components.renderable(visual.color, c.w / 2, 45)
    render.shape = "ring"
    world:create({Position = Components.position(p.x, p.y), Collider = Components.collider(c.w, c.h),
        Renderable = render, PortalPulse = {remaining = config.PORTAL_PULSE_SECONDS,
            duration = config.PORTAL_PULSE_SECONDS, speed = config.PORTAL_PULSE_SPEED}})
end

function Portals.update(game, dt)
    local world = game.world
    local portals = world:query("Portal", "Position", "Collider")
    if #portals == 0 then return end
    local solids = world:query("Brick", "Position", "Collider")
    if world:has(game.bossId, "Boss") then solids[#solids + 1] = game.bossId end
    for _, id in ipairs(world:query("MovingObstacle", "Position", "Collider")) do solids[#solids + 1] = id end
    local capacity = math.max(0, game.config.MAX_PORTAL_PULSES - world:count("PortalPulse"))
    for _, id in ipairs(world:query("Ball", "Position", "Velocity", "Collider")) do
        local ball = world:get(id, "Ball")
        ball.portalCooldown = math.max(0, (ball.portalCooldown or 0) - dt)
        if not ball.held and ball.portalCooldown == 0 then
            local p, c, v = world:get(id, "Position"), world:get(id, "Collider"), world:get(id, "Velocity")
            local x, y = ball.previousX or p.x, ball.previousY or p.y
            local first, time = nil, math.huge
            for _, portal in ipairs(portals) do
                local pp, pc = world:get(portal, "Position"), world:get(portal, "Collider")
                local hit = entryTime(x + c.w / 2, y + c.h / 2, p.x - x, p.y - y, pp.x + pc.w / 2, pp.y + pc.h / 2, pc.w / 2)
                if hit and hit < time then first, time = portal, hit end
            end
            if first then
                local portal = world:get(first, "Portal")
                if world:has(portal.target, "Portal") then
                    Ball.limitSpeed(v, game.config)
                    local co, si = math.cos(portal.rotation), math.sin(portal.rotation)
                    local vx, vy = v.vx * co - v.vy * si, v.vx * si + v.vy * co
                    local ex, ey = exitPosition(game, portal.target, c, vx, vy, solids, portals)
                    ball.portalCooldown = portal.cooldown
                    if ex then
                        local entry, shape = world:get(first, "Position"), world:get(first, "Collider")
                        Feedback.emit(game, "portal", entry.x + shape.w / 2, entry.y + shape.h / 2)
                        Feedback.emit(game, "portal", ex + c.w / 2, ey + c.h / 2)
                        p.x, p.y, v.vx, v.vy = ex, ey, vx, vy
                        ball.previousX, ball.previousY, ball.contacts = ex, ey, {}
                        Ball.limitSpeed(v, game.config)
                        if capacity >= 2 then
                            pulse(world, first, game.config); pulse(world, portal.target, game.config)
                            capacity = capacity - 2
                        end
                    end -- Salida obstruida: conservar la pelota en su trayectoria actual.
                end
            end
        end
    end
end

function Portals.updateVisuals(world, dt)
    for _, id in ipairs(world:query("PortalPulse", "Position", "Collider", "Renderable")) do
        local effect = world:get(id, "PortalPulse")
        effect.remaining = effect.remaining - dt
        if effect.remaining <= 0 then world:destroy(id)
        else
            local p, c = world:get(id, "Position"), world:get(id, "Collider")
            local growth = effect.speed * dt
            p.x, p.y, c.w, c.h = p.x - growth, p.y - growth, c.w + 2 * growth, c.h + 2 * growth
            world:get(id, "Renderable").alpha = effect.remaining / effect.duration
        end
    end
end

return Portals

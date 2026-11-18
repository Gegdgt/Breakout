local Movement = require("src.ecs.systems.movement_system")
local Motion = {}

local function offset(data)
    local angle = (data.elapsed / data.period + data.phase) * math.pi * 2
    return data.amplitudeX * math.sin(angle),
        data.amplitudeY * math.sin(data.axis == "oscillatory" and angle * 2 or angle)
end

function Motion.configure(world, config, paddleY)
    paddleY = paddleY or config.PADDLE_Y
    local ids, groups = world:query("Motion", "Position", "Velocity", "Collider"), {}
    for _, id in ipairs(ids) do
        local data, size = world:get(id, "Motion"), world:get(id, "Collider")
        data.amplitudeX = math.max(0, math.min(data.amplitudeX, data.originX, config.WIDTH - size.w - data.originX))
        data.amplitudeY = math.max(0, math.min(data.amplitudeY, data.originY - config.BRICK_TOP,
            paddleY - config.KINEMATIC_PADDLE_CLEARANCE - size.h - data.originY))
        local peak = (data.amplitudeX + data.amplitudeY * (data.axis == "oscillatory" and 2 or 1))
            * math.pi * 2 / data.period
        local scale = peak > 0 and math.min(1, config.KINEMATIC_MAX_SPEED / peak) or 1
        data.amplitudeX, data.amplitudeY = data.amplitudeX * scale, data.amplitudeY * scale
        if data.group then
            local group = groups[data.group]
            if not group then group = {x = data.amplitudeX, y = data.amplitudeY}; groups[data.group] = group end
            group.x, group.y = math.min(group.x, data.amplitudeX), math.min(group.y, data.amplitudeY)
        end
    end
    for _, id in ipairs(ids) do
        local data, position = world:get(id, "Motion"), world:get(id, "Position")
        if data.group then data.amplitudeX, data.amplitudeY = groups[data.group].x, groups[data.group].y end
        local x, y = offset(data)
        position.x, position.y = data.originX + x, data.originY + y
        data.previousX, data.previousY = position.x, position.y
    end
end

function Motion.update(world, dt)
    for _, id in ipairs(world:query("Motion", "Position", "Velocity", "Collider")) do
        local data, position = world:get(id, "Motion"), world:get(id, "Position")
        local velocity = world:get(id, "Velocity")
        data.previousX, data.previousY = position.x, position.y
        data.elapsed = data.elapsed + dt
        local x, y = offset(data)
        if dt > 0 then
            velocity.vx, velocity.vy = (data.originX + x - position.x) / dt, (data.originY + y - position.y) / dt
            Movement.step(world, id, dt)
        else velocity.vx, velocity.vy = 0, 0 end
    end
end

return Motion

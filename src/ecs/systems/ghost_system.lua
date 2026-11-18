local Collision = require("src.collision")
local Ghost = {}

function Ghost.update(world, dt)
    local ghosts = world:query("Ghost", "Position", "Collider", "Renderable")
    if #ghosts == 0 then return end
    local balls = world:query("Ball", "Position", "Collider")
    for _, id in ipairs(ghosts) do
        local data, visual = world:get(id, "Ghost"), world:get(id, "Renderable")
        data.elapsed = data.elapsed + dt
        local phase = data.elapsed % (data.solidSeconds + data.intangibleSeconds)
        local desired = phase < data.solidSeconds
        data.waiting = false
        if desired and not data.solid then
            for _, ball in ipairs(balls) do
                if Collision.overlaps(world:get(id, "Position"), world:get(id, "Collider"),
                    world:get(ball, "Position"), world:get(ball, "Collider")) then
                    data.waiting = true
                    break
                end
            end
        end
        data.solid = desired and not data.waiting
        local remaining = desired and data.solidSeconds - phase
            or data.solidSeconds + data.intangibleSeconds - phase
        data.warning = remaining <= data.warningSeconds or data.waiting
        visual.alpha = data.solid and 1 or 0.22
        if data.warning then visual.alpha = (data.solid and 0.65 or 0.30) + 0.15 * math.sin(data.elapsed * 24) end
    end
end

return Ghost

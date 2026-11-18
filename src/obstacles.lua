local Components = require("src.ecs.components")
local Obstacles = {}

function Obstacles.create(world, level)
    for _, spec in ipairs(level.obstacles) do
        local visual = Components.renderable({0.24, 0.30, 0.36}, 4, 15)
        visual.borderColor = {0.56, 0.88, 0.95}
        world:create({
            Position = Components.position(spec.x, spec.y),
            Velocity = Components.velocity(0, 0),
            Collider = Components.collider(spec.w, spec.h), Renderable = visual,
            Motion = Components.motion(spec.x, spec.y, spec.motion),
            MovingObstacle = {key = spec.id, indestructible = true},
        })
    end
end

return Obstacles

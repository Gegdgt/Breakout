-- Sistema de poderes: fabrica, sorteo, caida, recoleccion y MULTIBALL.
local Components = require("src.ecs.components")
local Collision = require("src.collision")
local Movement = require("src.ecs.systems.movement_system")
local Ball = require("src.ball")
local Effects = require("src.ecs.systems.power_effect_system")
local Feedback = require("src.feedback")
local Powerups = {}
Powerups.MULTIBALL = "multiball"

function Powerups.spawn(world, config, kind, centerX, centerY)
    local definition = assert(config.POWERUP_TYPES[kind], "Tipo de power-up desconocido")
    if world:count("PowerUp") >= config.MAX_FALLING_POWERUPS then return nil end
    local renderable = Components.renderable(definition.color, 3, 20)
    renderable.label = definition.label
    renderable.labelColor = {0.08, 0.10, 0.14}
    return world:create({
        Position = Components.position(centerX - config.POWERUP_W / 2, centerY - config.POWERUP_H / 2),
        Velocity = Components.velocity(0, config.POWERUP_FALL_SPEED),
        Collider = Components.collider(config.POWERUP_W, config.POWERUP_H),
        Renderable = renderable,
        PowerUp = Components.powerUp(kind, definition.name),
    })
end

local function weight(config, kind, boss)
    local multiplier = boss and kind == "laser" and config.BOSS_LASER_DROP_WEIGHT_MULTIPLIER or 1
    return config.POWERUP_TYPES[kind].weight * multiplier
end

function Powerups.trySpawn(world, config, position, collider, chance, available, boss)
    available = available or {Powerups.MULTIBALL}
    -- Un unico sorteo por bloque: el tramo [0, chance) se reparte por peso.
    local roll, total = love.math.random(), 0
    for _, kind in ipairs(available) do total = total + weight(config, kind, boss) end
    if roll >= chance or chance <= 0 or total <= 0 then return end
    local choice = roll / chance * total
    for _, kind in ipairs(available) do
        choice = choice - weight(config, kind, boss)
        if choice < 0 then
            return Powerups.spawn(world, config, kind, position.x + collider.w / 2, position.y + collider.h / 2)
        end
    end
end

function Powerups.activate(game, kind)
    if game.state ~= "playing" or game.quitRequested then return end
    local p, c = game.world:get(game.paddleId, "Position"), game.world:get(game.paddleId, "Collider")
    if game.config.POWERUP_TYPES[kind] then
        Feedback.emit(game, "powerup", p.x + c.w / 2, p.y, game.config.POWERUP_TYPES[kind].color)
    end
    if kind == Powerups.MULTIBALL then
        local world, config = game.world, game.config
        local originals = world:query("Ball", "Position", "Velocity", "Collider")
        local angle = math.rad(config.MULTIBALL_SPREAD_DEGREES)
        local available = math.max(0, config.MAX_BALLS - world:count("Ball"))
        for _, id in ipairs(originals) do
            Ball.limitSpeed(world:get(id, "Velocity"), config)
        end
        -- Instantanea: las copias no se vuelven a multiplicar en este recorrido.
        for _, id in ipairs(originals) do
            if world:has(id, "Ball") then
                for direction = -1, 1, 2 do
                    if available == 0 then return end
                    Ball.cloneRotated(world, id, direction * angle, config, game.level)
                    available = available - 1
                end
            end
        end
    else Effects.activate(game, kind) end
end

function Powerups.guaranteed(game, dt)
    local rule = game.level.difficulty.guaranteedPowerup
    if not rule then return end
    local _, power = Effects.get(game)
    power.guaranteedElapsed = power.guaranteedElapsed + dt
    if power.guaranteedElapsed < rule.everySeconds then return end
    power.guaranteedElapsed = power.guaranteedElapsed % rule.everySeconds
    local world = game.world
    local falling = world:query("PowerUp")
    -- Reservar una oportunidad real incluso si los objetos aleatorios llenan el limite.
    if #falling >= game.config.MAX_FALLING_POWERUPS then world:destroy(falling[1]) end
    local p, c = world:get(game.paddleId, "Position"), world:get(game.paddleId, "Collider")
    Powerups.spawn(world, game.config, rule.kind, p.x + c.w / 2, p.y - game.config.GUARANTEED_POWERUP_OFFSET)
end

-- Ayuda opcional cuando escasean los bloques originales, nunca un laser garantizado.
function Powerups.bossSupply(game, dt)
    local world, config = game.world, game.config
    if game.state ~= "playing" or game.quitRequested or not game.level.boss then return end
    local boss = world:get(game.bossId, "Boss")
    local _, power = Effects.get(game)
    if not boss or boss.defeated or boss.intro > 0 or not power then return end
    power.bossLaserElapsed = power.bossLaserElapsed + dt
    if power.bossLaserElapsed + 0.000000001 < config.BOSS_LASER_SUPPLY_INTERVAL then return end
    power.bossLaserElapsed = math.max(0, power.bossLaserElapsed - config.BOSS_LASER_SUPPLY_INTERVAL)
        % config.BOSS_LASER_SUPPLY_INTERVAL -- Un intento como maximo; no acumular rafagas tras un dt grande.
    if power.ammo > 0 then return end
    local enabled = false
    for _, kind in ipairs(game.level.activePowerups) do if kind == "laser" then enabled = true; break end end
    if not enabled then return end
    local falling = world:query("PowerUp")
    if #falling >= config.MAX_FALLING_POWERUPS then return end
    for _, id in ipairs(falling) do if world:get(id, "PowerUp").kind == "laser" then return end end
    local remaining = 0
    for _, id in ipairs(world:query("Brick")) do
        if not world:has(id, "BossSupport") and world:get(id, "Brick").dropChance > 0 then
            remaining = remaining + 1
            if remaining > config.BOSS_LASER_SUPPLY_BLOCK_THRESHOLD then return end
        end
    end
    if love.math.random() >= config.BOSS_LASER_SUPPLY_CHANCE then return end
    local p, c = world:get(game.paddleId, "Position"), world:get(game.paddleId, "Collider")
    return Powerups.spawn(world, config, "laser", p.x + c.w / 2, p.y - config.GUARANTEED_POWERUP_OFFSET)
end

function Powerups.update(game, dt)
    local world, config = game.world, game.config
    local collected = {}
    local paddles = world:query("PaddleControl", "Position", "Collider")
    local powers = world:query("PowerUp", "Position", "Velocity", "Collider")
    for index = #powers, 1, -1 do
        local id = powers[index]
        if world:has(id, "PowerUp") then
            Movement.step(world, id, dt)
            local position = world:get(id, "Position")
            local collider = world:get(id, "Collider")
            local pickedUp = false
            for _, paddle in ipairs(paddles) do
                if world:has(paddle, "PaddleControl") and Collision.overlaps(
                    position, collider, world:get(paddle, "Position"), world:get(paddle, "Collider")) then
                    collected[#collected + 1] = world:get(id, "PowerUp").kind
                    world:destroy(id)
                    pickedUp = true
                    break
                end
            end
            if not pickedUp and position.y >= config.HEIGHT then world:destroy(id) end
        end
    end
    -- Resolver todas las recogidas antes de crear pelotas, como en el juego original.
    for _, kind in ipairs(collected) do Powerups.activate(game, kind) end
    Powerups.guaranteed(game, dt)
    Powerups.bossSupply(game, dt)
end

return Powerups

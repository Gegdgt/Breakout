-- Vistas de componentes para las pruebas; no duplican ni simulan el estado ECS.
local Ball = require("src.ball")
local Helpers = {}

-- Cada escenario recibe su propio disco en memoria: no usa el progreso del jugador.
function Helpers.memoryFilesystem()
    local fs = {files = {}, writes = 0}
    function fs.getInfo(path)
        local value = fs.files[path]
        if value then return {type = "file", size = #value} end
    end
    function fs.read(path) return fs.files[path] end
    function fs.write(path, contents)
        fs.writes = fs.writes + 1
        fs.files[path] = contents
        return true
    end
    return fs
end

function Helpers.newGame(filesystem)
    local game = require("src.game").new({filesystem = filesystem or Helpers.memoryFilesystem()})
    game:reset()
    Helpers.finishIntro(game)
    return game
end

-- Fixtures de mecanicas: atravesar la presentacion real, sin desactivar sistemas.
function Helpers.finishIntro(game)
    if game.state == "level_intro" then game:update(game.entryRemaining) end
end

function Helpers.startCampaign(game, index)
    local started = game:startCampaign(index)
    if started then Helpers.finishIntro(game) end
    return started
end

function Helpers.entity(game, id)
    if not id then return nil end
    return {id = id, position = game.world:get(id, "Position"),
            velocity = game.world:get(id, "Velocity"), collider = game.world:get(id, "Collider"),
            powerUp = game.world:get(id, "PowerUp")}
end

function Helpers.query(game, component)
    local result = {}
    for _, id in ipairs(game.world:query(component)) do
        result[#result + 1] = Helpers.entity(game, id)
    end
    return result
end

function Helpers.balls(game) return Helpers.query(game, "Ball") end
function Helpers.bricks(game) return Helpers.query(game, "Brick") end
function Helpers.powers(game) return Helpers.query(game, "PowerUp") end
function Helpers.paddle(game) return Helpers.query(game, "PaddleControl")[1] end

function Helpers.setBallCount(game, count)
    for _, id in ipairs(game.world:query("Ball")) do game.world:destroy(id) end
    for index = 1, count do Ball.spawn(game.world, game.config) end
end

function Helpers.keepBricks(game, indices)
    local ids = game.world:query("Brick")
    local keep = {}
    for _, index in ipairs(indices) do keep[ids[index]] = true end
    for _, id in ipairs(ids) do
        if not keep[id] then game.world:destroy(id) end
    end
    game.remaining = game.world:count("Brick")
end

function Helpers.keepNormalBricks(game, count)
    local indices = {}
    for index, id in ipairs(game.world:query("Brick")) do
        if game.world:get(id, "Brick").kind == "normal" and #indices < count then indices[#indices + 1] = index end
    end
    assert(#indices == count, "La fixture necesita suficientes bloques normales")
    Helpers.keepBricks(game, indices)
end

-- Fixture de progresion: aplica impactos legales en ventanas reales, sin simular habilidad humana.
function Helpers.defeatBoss(game)
    if not game.bossId then return end
    local BossSystem = require("src.ecs.systems.boss_system")
    local Damage = require("src.ecs.systems.damage_system")
    local Score = require("src.ecs.systems.score_system")
    local boss = game.world:get(game.bossId, "Boss")
    for _ = 1, 12000 do
        if boss.defeated then break end
        Score.update(game, 1 / 60)
        BossSystem.update(game, 1 / 60)
        -- Esta fixture aisla la condicion de victoria; los protectores tienen pruebas propias.
        for _, id in ipairs(game.world:query("BossSupport")) do game.world:destroy(id) end
        game.remaining = game.world:count("Brick")
        local p, c = game.world:get(game.bossId, "Position"), game.world:get(game.bossId, "Collider")
        Damage.hit(game, game.bossId, 1, "ball", p.x + c.w / 2, p.y + c.h)
    end
    assert(boss.defeated, "El jefe debe poder ser derrotado con pelotas normales")
end

function Helpers.aimAtFinalBossHit(game, ball)
    local world, id = game.world, game.bossId
    local boss, definition = world:get(id, "Boss"), world:get(id, "BossBehavior")
    boss.phase, boss.intro, boss.hitCooldown, boss.pendingPhase = definition.phases and #definition.phases or 1, 0, 0, nil
    world:get(id, "Health").current = 1
    world:get(id, "Damageable").enabled = true
    local p, c = world:get(id, "Position"), world:get(id, "Collider")
    ball.position.x, ball.position.y = p.x + c.w / 2 - ball.collider.w / 2, p.y + c.h + 1
    ball.velocity.vx, ball.velocity.vy = 0, -280
end

return Helpers

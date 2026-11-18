-- Coordinador ECS: recursos de partida y orden de los sistemas.
local Config = require("src.config")
local World = require("src.ecs.world")
local Paddle = require("src.paddle")
local Ball = require("src.ball")
local Powerups = require("src.powerups")
local CollisionSystem = require("src.ecs.systems.collision_system")
local RenderSystem = require("src.ecs.systems.render_system")
local Progression = require("src.ecs.systems.progression_system")
local LevelManager = require("src.level_manager")
local ProgressStore = require("src.progress_store")
local Motion = require("src.ecs.systems.motion_system")
local Ghost = require("src.ecs.systems.ghost_system")
local Explosion = require("src.ecs.systems.explosion_system")
local Effects = require("src.ecs.systems.power_effect_system")
local Projectiles = require("src.ecs.systems.projectile_system")
local Portals = require("src.ecs.systems.portal_system")
local Score = require("src.ecs.systems.score_system")
local BossSystem = require("src.ecs.systems.boss_system")
local Enemy = require("src.ecs.systems.enemy_projectile_system")
local Life = require("src.ecs.systems.life_system")
local State = require("src.ecs.systems.state_system")
local Interface = require("src.ecs.systems.interface_system")
local Feedback = require("src.feedback")
local FeedbackSystem = require("src.ecs.systems.feedback_system")
local Particles = require("src.ecs.systems.particle_system")
local Audio = require("src.ecs.systems.audio_system")
local Controls = require("src.controls")

local Game = {}
Game.__index = Game

function Game.new(options)
    options = options or {}
    local self = setmetatable({}, Game)
    self.config = Config
    self.world = World.new()
    self.levels = LevelManager.new(self.config)
    self.progressStore = ProgressStore.new(self.config, self.levels, options.filesystem or love.filesystem)
    self.progress, self.saveWarning = self.progressStore:load()
    self.font = love.graphics.newFont(15)
    self.effectFont = love.graphics.newFont(12)
    self.titleFont = love.graphics.newFont(27)
    self.messageFont = love.graphics.newFont(48)
    self.levelIndex, self.level = 1, self.levels:get(1)
    self.lives, self.remaining = Config.STARTING_LIVES, 0
    Score.startCampaign(self)
    Feedback.reset(self)
    Audio.initialize(self, options.audioBackend)
    Interface.initialize(self)
    Audio.sync(self)
    return self
end

function Game:reset()
    return Progression.startCampaign(self, 1)
end

function Game:startCampaign(index) return Progression.startCampaign(self, index) end
function Game:restartLevel() return Progression.restartLevel(self) end
function Game:completeLevel() return Progression.completeLevel(self) end
function Game:gameOver()
    if self.state == "playing" and not self.quitRequested then Effects.clear(self) end
    Progression.gameOver(self)
end
function Game:goToMenu() Progression.menu(self) end
function Game:quit() Score.checkpoint(self); Audio.stop(self) end
function Game:loseLife() return Life.lose(self) end

function Game:saveProgress()
    local ok, warning = self.progressStore:save(self.progress)
    self.saveWarning = warning
    self.progressDirty = not ok
    return ok
end

-- Inicializacion limpia al cargar/reiniciar un nivel o comenzar una campaña.
function Game:resetRound()
    Feedback.clear(self)
    Score.resetCombo(self)
    Effects.clear(self)
    for _, component in ipairs({"PaddleControl", "Ball", "PowerUp"}) do
        for _, id in ipairs(self.world:query(component)) do self.world:destroy(id) end
    end
    self.paddleId = Paddle.spawn(self.world, self.config, self.level)
    Ball.spawn(self.world, self.config, self.level)
    BossSystem.roundReset(self)
end

-- Life.lose ya retiro las pelotas perdidas. No recrear el paddle ni reactivar poderes.
function Game:respawnRound()
    Feedback.clear(self)
    Score.resetCombo(self)
    Effects.release(self) -- Descartar la referencia a una pelota capturada que ya no existe.
    Paddle.resetPosition(self.world, self.config, self.paddleId, self.level)
    Ball.spawn(self.world, self.config, self.level) -- Hereda fuego del TimedEffect conservado.
    BossSystem.roundReset(self)
end

function Game:activatePowerup(kind)
    Powerups.activate(self, kind)
end

local function updateSimulation(self, dt)
    if self.quitRequested then return end
    dt = math.max(0, dt)
    if Interface.update(self, dt) then return end
    if self.state == "level_complete" then
        BossSystem.updateVisuals(self, dt)
        Portals.updateVisuals(self.world, dt)
        Explosion.updateVisuals(self.world, dt)
        Explosion.process(self)
        Progression.update(self, dt)
        return
    end
    if self.state == "campaign_complete" or self.state == "game_over" then
        BossSystem.updateVisuals(self, dt)
        Portals.updateVisuals(self.world, dt)
        Explosion.updateVisuals(self.world, dt)
        Explosion.process(self)
        return
    end
    if self.state ~= "playing" or self.quitRequested then return end
    -- Conservar el limite original para pausas o arrastres de la ventana.
    dt = math.min(dt, 0.05)
    Score.update(self, dt)
    Explosion.updateVisuals(self.world, dt)
    Portals.updateVisuals(self.world, dt)
    Effects.update(self, dt)
    Enemy.updateInvulnerability(self, dt)
    Paddle.update(self.world, self.config, dt)
    Effects.follow(self)
    Motion.update(self.world, dt)
    BossSystem.update(self, dt)
    Ghost.update(self.world, dt)
    CollisionSystem.update(self, dt)
    if self.quitRequested then return end
    if self.state == "playing" then
        Enemy.move(self, dt)
        Projectiles.update(self, dt)
        if self.state == "playing" then Portals.update(self, dt) end
    end
    Explosion.process(self)
    -- Victoria antes que caidas o poderes, igual que antes de ECS.
    if self.state ~= "playing" or self.quitRequested then return end
    if Explosion.pending(self) then return end
    if Ball.checkRound(self) then return end
    if Enemy.resolve(self) then return end
    Powerups.update(self, dt)
end

function Game:update(dt)
    if self.quitRequested then return end
    dt = math.max(0, dt)
    Audio.update(self, dt)
    Particles.update(self, self.state == "playing" and math.min(dt, 0.05) or dt)
    updateSimulation(self, dt)
    FeedbackSystem.flush(self)
end

function Game:keypressed(key, isrepeat)
    local handled = Interface.keypressed(self, key, isrepeat)
    if not handled and Controls.matches(self.config, "action", key) and self.state == "playing" then
        if not Effects.release(self) then Projectiles.fire(self) end
    end
    FeedbackSystem.flush(self)
end

function Game:mousepressed(x, y, button) Interface.mousepressed(self, x, y, button) end
function Game:wheelmoved(x, y) Interface.wheelmoved(self, x, y) end

function Game:focus(focused)
    if not focused then State.pause(self) end
    Audio.sync(self)
end

function Game:draw()
    RenderSystem.draw(self)
end

return Game

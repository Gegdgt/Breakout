-- Coordinador ECS: recursos de partida y orden de los sistemas.
local Config = require("src.config")
local World = require("src.ecs.world")
local Paddle = require("src.paddle")
local Ball = require("src.ball")
local Bricks = require("src.bricks")
local Powerups = require("src.powerups")
local CollisionSystem = require("src.ecs.systems.collision_system")
local RenderSystem = require("src.ecs.systems.render_system")

local Game = {}
Game.__index = Game

function Game.new()
    local self = setmetatable({}, Game)
    self.config = Config
    self.world = World.new()
    self.font = love.graphics.newFont(15)
    self.titleFont = love.graphics.newFont(27)
    self.messageFont = love.graphics.newFont(48)
    self:reset()
    return self
end

function Game:reset()
    self.world:clear()
    self.state = "playing"
    self.quitRequested = false
    self.lives = self.config.STARTING_LIVES
    self:resetRound()
    Bricks.create(self.world, self.config)
    self.remaining = self.world:count("Brick")
end

-- Reponer las entidades moviles sin restaurar los bloques destruidos.
function Game:resetRound()
    for _, component in ipairs({"PaddleControl", "Ball", "PowerUp"}) do
        for _, id in ipairs(self.world:query(component)) do self.world:destroy(id) end
    end
    Paddle.spawn(self.world, self.config)
    Ball.spawn(self.world, self.config)
end

function Game:activatePowerup(kind)
    Powerups.activate(self, kind)
end

function Game:update(dt)
    if self.state ~= "playing" or self.quitRequested then return end
    -- Conservar el limite original para pausas o arrastres de la ventana.
    dt = math.min(dt, 0.05)
    Paddle.update(self.world, self.config, dt)
    CollisionSystem.update(self, dt)
    -- Victoria antes que caidas o poderes, igual que antes de ECS.
    if self.state == "won" or self.quitRequested then return end
    if Ball.checkRound(self) then return end
    Powerups.update(self, dt)
end

function Game:draw()
    RenderSystem.draw(self)
end

return Game

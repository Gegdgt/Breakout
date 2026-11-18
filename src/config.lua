-- Valores compartidos del juego. Son faciles de modificar.
return {
    ECS_ASSIGNMENT_MODE = false, -- true: mensaje y cierre al tocar un lateral.
    WIDTH = 960,
    HEIGHT = 640,
    STARTING_LIVES = 3,

    PADDLE_W = 112,
    PADDLE_H = 16,
    PADDLE_Y = 587,
    PADDLE_SPEED = 475,   -- Pixeles por segundo.

    BALL_SIZE = 13,
    BALL_START_VX = 195, -- Pixeles por segundo.
    BALL_START_VY = -280,
    PADDLE_SPEED_MULTIPLIER = 1.08,
    WALL_SPEED_MULTIPLIER = 1.08,
    MAX_BALLS = 30,
    MULTIBALL_SPREAD_DEGREES = 25,

    POWERUP_DROP_CHANCE = 0.15,
    POWERUP_FALL_SPEED = 150, -- Pixeles por segundo.
    POWERUP_W = 32,
    POWERUP_H = 22,

    BRICK_ROWS = 6,
    BRICK_COLS = 12,
    BRICK_TOP = 94,
    BRICK_SIDE_MARGIN = 44,
    BRICK_GAP = 5,
    BRICK_HEIGHT = 25,
    BRICK_COLORS = {
        {1.00, 0.33, 0.32}, -- Rojo
        {1.00, 0.58, 0.29}, -- Naranja
        {0.98, 0.81, 0.35}, -- Amarillo
        {0.39, 0.78, 0.45}, -- Verde
        {0.28, 0.65, 0.94}, -- Azul
        {0.61, 0.42, 0.88}, -- Morado
    }
}

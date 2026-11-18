-- Valores compartidos del juego. Son faciles de modificar.
local Config = {
    ECS_ASSIGNMENT_MODE = false, -- true: mensaje y cierre al tocar un lateral.
    WIDTH = 960,
    HEIGHT = 640,
    STARTING_LIVES = 3,
    MAX_LIVES = 5,
    LEVEL_LIFE_REWARD = 1,
    LEVEL_TRANSITION_SECONDS = 2,
    LEVEL_ENTRY_SECONDS = 0.6,
    LEVEL_COUNTDOWN_SECONDS = 3,
    UI_ANIMATION_SECONDS = 0.3,
    UI_STAR_INTERVAL = 0.18,
    UI_NOTICE_SECONDS = 2,
    UI_CLOCK_LIMIT = 60,
    LEVEL_SELECT_COLUMNS = 5,
    OPTION_VOLUME_STEP = 0.1,
    CONTROLS = {
        left = {"left", "a"}, right = {"right", "d"}, sprint = {"lshift", "rshift"},
        action = {"space"}, pause = {"escape", "p"}, restart = {"r"}, menu = {"m"},
    },
    MAX_FEEDBACK_EVENTS = 64, -- Mas un espacio reservado para vida/resultado.
    MAX_FEEDBACK_PARTICLES = 256,
    MAX_TRAIL_PARTICLES = 128,
    FEEDBACK_EMIT_BUDGET = 80,
    TRAILS_PER_TICK = 32,
    TRAIL_INTERVAL = 0.04,
    TRAIL_STYLE = {seconds = 0.14, size = 4, alpha = 0.35},
    FEEDBACK_STYLES = require("src.feedback_styles"),
    BALL_VISUAL_CORE_SIZE = 5,
    AUDIO_POOL_PER_EFFECT = 2,
    MAX_SFX_VOICES = 8,
    AUDIO_EVENT_INTERVAL = 0.045,
    MUSIC_FADE_SECONDS = 0.35,
    SAVE_FILE = "progress.dat",
    SAVE_BACKUP_FILE = "progress.bak",
    SAVE_MAX_BYTES = 65536,
    DEFAULT_SETTINGS = {masterVolume = 1, musicVolume = 0.6, sfxVolume = 0.8, muted = false},

    SCORE_VALUES = {normal = 100, resistant = 150, explosive = 200,
        moving = 200, ghost = 250, armored = 300},
    BOSS_SCORE_VALUES = {mechanical_guardian = 5000, chaos_core = 15000},
    BOSS_WEAK_POINT_SIZE_MULTIPLIER = 1.6,
    BOSS_TOP_WEAK_POINT_WIDTH_RATIO = 0.30,
    BOSS_TOP_WEAK_POINT_HEIGHT = 8,
    BOSS_LASER_DROP_WEIGHT_MULTIPLIER = 3.0,
    BOSS_LASER_SUPPLY_INTERVAL = 20,
    BOSS_LASER_SUPPLY_CHANCE = 0.5,
    BOSS_LASER_SUPPLY_BLOCK_THRESHOLD = 3, -- Bloques originales con posibilidad de soltar poderes.
    BOSS_HIT_COOLDOWN = 0.18,
    BOSS_HIT_FLASH = 0.18,
    BOSS_INTRO_SECONDS = 1.2,
    BOSS_DEFEAT_SECONDS = 1.2,
    BOSS_ACTION_WARNING = 0.75,
    BOSS_SUPPORT_LIMIT = 6,
    BOSS_SUPPORT_LIFETIME = 10,
    BOSS_SUPPORT_HEALTH = 2,
    BOSS_SUPPORT_WIDTH = 48,
    BOSS_SUPPORT_HEIGHT = 12,
    BOSS_SUPPORT_GAP = 8,
    GUARDIAN_SPEED = 90,
    GUARDIAN_REST_SECONDS = 2,
    CORE_SPEEDS = {35, 100, 0},
    CORE_DEFENSE_CLOSED_SECONDS = 2,
    CORE_DEFENSE_OPEN_SECONDS = 2.5,
    CORE_ATTACK_INTERVALS = {0, 2.4, 1.6},
    CORE_PROJECTILE_SPEEDS = {0, 210, 240},
    CORE_TELEPORT_INTERVAL = 4,
    CORE_FAN_DEGREES = 12,
    ENEMY_PROJECTILE_SIZE = 10,
    ENEMY_PROJECTILE_LIFETIME = 6,
    ENEMY_PROJECTILE_MAX_AIM_RATIO = 0.65,
    MAX_ENEMY_PROJECTILES = 18,
    PADDLE_INVULNERABILITY_SECONDS = 2,
    SCORE_MAX = 2147483647, -- Mismo rango entero del guardado existente.
    COMBO_WINDOW = 3,
    COMBO_STEP = 3, -- x1 en 1-3 destrucciones, x2 en 4-6, ..., x5 desde 13.
    COMBO_MAX_MULTIPLIER = 5,
    COMBO_CELEBRATION_MULTIPLIER = 3,
    COMBO_PULSE_SECONDS = 0.45,

    PADDLE_W = 112,
    PADDLE_H = 16,
    PADDLE_Y = 587,
    PADDLE_NORMAL_SPEED = 475, -- Pixeles por segundo; conserva la velocidad original.
    PADDLE_SPRINT_MULTIPLIER = 1.8,

    BALL_SIZE = 13,
    BALL_START_VX = 195, -- Pixeles por segundo.
    BALL_START_VY = -280,
    BALL_MAX_SPEED = 550, -- Rapidez total (ambos ejes), en pixeles por segundo.
    PADDLE_SPEED_MULTIPLIER = 1.08,
    WALL_SPEED_MULTIPLIER = 1.08,
    MAX_BALLS = 90,
    MULTIBALL_SPREAD_DEGREES = 25,
    BALL_DAMAGE = 1,
    CONTACT_EPSILON = 0.001,
    KINEMATIC_MAX_SPEED = 180,
    KINEMATIC_PADDLE_CLEARANCE = 85,
    MAX_LEVEL_BRICKS = 256,
    MAX_EXPLOSIONS_PER_UPDATE = 256,
    MAX_EXPLOSION_PARTICLES = 192,
    EXPLOSION_PARTICLES = 16,
    EXPLOSION_VISUAL_SECONDS = 0.45,
    BRICK_DEFAULTS = {
        health = 3, explosionDamage = 1,
        motionAmplitude = 24, motionPeriod = 4,
        solidSeconds = 3, intangibleSeconds = 2, warningSeconds = 0.5,
    },
    BRICK_TYPE_COLORS = {
        resistant = {0.72, 0.45, 0.93}, explosive = {1, 0.49, 0.18},
        moving = {0.17, 0.78, 0.90}, ghost = {0.72, 0.83, 1},
        armored = {0.42, 0.49, 0.58},
        unbreakable = {0.22, 0.27, 0.33},
    },
    BRICK_NAMES = {normal = "Normal", resistant = "Resistente", explosive = "Explosivo", moving = "Móvil",
        ghost = "Fantasma", armored = "Blindado", unbreakable = "Irrompible"},

    POWERUP_DROP_CHANCE = 0.15,
    POWERUP_FALL_SPEED = 150, -- Pixeles por segundo.
    POWERUP_W = 32,
    POWERUP_H = 22,
    MAX_FALLING_POWERUPS = 12,
    GUARANTEED_POWERUP_OFFSET = 100,
    GIANT_PADDLE_SCALE = 1.5,
    GIANT_PADDLE_SECONDS = 15,
    FIREBALL_SECONDS = 10,
    FIREBALL_DAMAGE = 1,
    MAGNET_SECONDS = 15,
    SHIELD_SECONDS = 20,
    SHIELD_HITS = 3,
    SHIELD_BOTTOM_MARGIN = 33,
    SHIELD_HEIGHT = 5,
    LASER_AMMO = 20, -- Una unidad dispara ambos canones.
    LASER_INTERVAL = 0.25,
    LASER_SPEED = 720,
    LASER_DAMAGE = 1,
    LASER_W = 4,
    LASER_H = 14,
    MAX_PLAYER_PROJECTILES = 40,
    MAX_PORTAL_PAIRS = 4,
    MAX_PORTAL_PULSES = 32,
    PORTAL_PULSE_SECONDS = 0.35,
    PORTAL_PULSE_SPEED = 35,
    PORTAL_EXIT_SEARCH_STEPS = 4,
    POWERUP_TYPES = {
        multiball = {name = "MULTIBALL x3", label = "x3", color = {0.98, 0.81, 0.35}, weight = 30},
        giant_paddle = {name = "GIGANTE", label = "<>", color = {0.35, 0.92, 0.55}, weight = 24},
        shield = {name = "ESCUDO", label = "SH", color = {0.35, 0.75, 1}, weight = 16},
        fireball = {name = "FUEGO", label = "F", color = {1, 0.4, 0.16}, weight = 12},
        laser = {name = "LASER", label = "II", color = {1, 0.35, 0.65}, weight = 10},
        magnet = {name = "IMAN", label = "U", color = {0.74, 0.5, 1}, weight = 12},
        extra_life = {name = "VIDA", label = "+1", color = {0.95, 0.98, 1}, weight = 3},
    },

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

-- Nombre anterior conservado para consumidores existentes; configurar PADDLE_NORMAL_SPEED.
Config.PADDLE_SPEED = Config.PADDLE_NORMAL_SPEED
return Config

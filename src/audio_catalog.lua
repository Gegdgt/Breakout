-- Recursos originales generados con tools/generate_audio.py. Rutas relativas a LÖVE.
return {
    effects = {
        paddle = {file = "assets/audio/paddle.wav", gain = 0.35, priority = 1},
        wall = {file = "assets/audio/wall.wav", gain = 0.18, priority = 1},
        brick = {file = "assets/audio/brick.wav", gain = 0.28, priority = 2},
        resistant = {file = "assets/audio/resistant.wav", gain = 0.25, priority = 2},
        explosion = {file = "assets/audio/explosion.wav", gain = 0.28, priority = 3, interval = 0.12},
        powerup = {file = "assets/audio/powerup.wav", gain = 0.4, priority = 4, interval = 0.12},
        laser = {file = "assets/audio/laser.wav", gain = 0.22, priority = 2},
        life_lost = {file = "assets/audio/life_lost.wav", gain = 0.4, priority = 7, interval = 0.6},
        level_complete = {file = "assets/audio/level_complete.wav", gain = 0.45, priority = 10, interval = 1.5},
        game_over = {file = "assets/audio/game_over.wav", gain = 0.45, priority = 10, interval = 1.5},
        victory = {file = "assets/audio/victory.wav", gain = 0.45, priority = 10, interval = 2},
        boss_attack = {file = "assets/audio/boss_attack.wav", gain = 0.3, priority = 4, interval = 0.12},
        boss_hit = {file = "assets/audio/boss_hit.wav", gain = 0.35, priority = 4, interval = 0.12},
        boss_defeat = {file = "assets/audio/boss_defeat.wav", gain = 0.4, priority = 6, interval = 1},
        portal = {file = "assets/audio/portal.wav", gain = 0.25, priority = 3, interval = 0.12},
        ui = {file = "assets/audio/ui.wav", gain = 0.18, priority = 1, interval = 0.08},
    },
    music = {
        menu = {file = "assets/audio/menu.wav", gain = 0.4},
        level = {file = "assets/audio/level.wav", gain = 0.35},
        boss = {file = "assets/audio/boss.wav", gain = 0.35},
    },
}

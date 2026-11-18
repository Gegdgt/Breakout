-- Datos visuales configurables; no usan ni consumen el RNG de los poderes.
return {
    brick = {count = 7, speed = 90, seconds = 0.32, size = 3, alpha = 0.65, color = {0.5, 0.8, 1}},
    resistant = {count = 3, speed = 70, seconds = 0.2, size = 2, alpha = 0.55, color = {0.8, 0.6, 1}},
    wall = {count = 4, speed = 65, seconds = 0.2, size = 2, alpha = 0.5, color = {0.65, 0.85, 1}},
    paddle = {count = 5, speed = 85, seconds = 0.25, size = 2, alpha = 0.55, color = {0.6, 0.9, 1}},
    powerup = {count = 16, speed = 100, seconds = 0.45, size = 3, alpha = 0.65, color = {1, 0.85, 0.4}},
    portal = {count = 8, speed = 75, seconds = 0.3, size = 2, alpha = 0.6, color = {0.55, 0.7, 1}},
    boss_hit = {count = 10, speed = 110, seconds = 0.3, size = 3, alpha = 0.65, color = {0.6, 1, 0.8}},
    boss_attack = {count = 5, speed = 65, seconds = 0.3, size = 2, alpha = 0.5, color = {1, 0.4, 0.45}},
    boss_defeat = {count = 24, speed = 150, seconds = 0.8, size = 3, alpha = 0.65, color = {1, 0.6, 0.9}},
    life_lost = {count = 12, speed = 95, seconds = 0.45, size = 3, alpha = 0.6, color = {1, 0.5, 0.25}},
    level_complete = {count = 36, speed = 160, seconds = 1.3, size = 4, alpha = 0.65, gravity = 70, color = {1, 0.8, 0.3}},
    victory = {count = 48, speed = 190, seconds = 1.6, size = 4, alpha = 0.65, gravity = 75, color = {1, 0.6, 0.9}},
}

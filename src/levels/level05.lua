return require("src.levels.definition").make({
    stars = {twoScore = 12000, threeScore = 18000, minLives = 3},
    id = "guardian_mecanico", name = "Guardián mecánico",
    rows = {"RR........RR", "RN........NR", "RN........NR",
            "RRNNNNNNNNRR", ".RRRRRRRRRR.", "...NN..NN..."},
    initialVelocity = {vx = 215, vy = -309},
    difficulty = {rank = 5, label = "Jefe intermedio", dropChance = 0.15},
    powerups = {"multiball", "giant_paddle", "shield", "fireball", "laser", "magnet"},
    boss = {id = "mechanical_guardian", x = 400, y = 100, w = 160, h = 60,
            health = 20, motion = {pattern = "horizontal", amplitude = 160, period = 6},
            weakPoint = {x = 52, y = 40, w = 56, h = 20}, protectorType = "resistant"},
    background = {0.065, 0.075, 0.10}, primary = {0.91, 0.70, 0.31},
})

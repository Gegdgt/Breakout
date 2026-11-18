return require("src.levels.definition").make({
    stars = {twoScore = 5200, threeScore = 8000, minLives = 3},
    id = "en_movimiento", name = "En movimiento",
    rows = {".MM..MM..MM.", "............", "VV..NN..VV..",
            "..TT..OO..TT", "............", ".RR..RR..RR."},
    initialVelocity = {vx = 210, vy = -302},
    difficulty = {rank = 4, label = "Media", dropChance = 0.15},
    powerups = {"multiball", "giant_paddle", "shield", "fireball", "laser"},
    obstacles = {{id = "sweeper", x = 400, y = 350, w = 110, h = 14,
                  motion = {pattern = "horizontal", amplitude = 180, period = 6}}},
    background = {0.035, 0.09, 0.08}, primary = {0.25, 0.87, 0.66},
})

return require("src.levels.definition").make({
    stars = {twoScore = 7500, threeScore = 11000, minLives = 3},
    id = "resistencia", name = "Resistencia",
    rows = {"RRNN....NNRR", "NRRN....NRRN", "NNRRNNNNRRNN",
            ".NNRRNNRRNN.", "..NNRRRRNN..", "...NNRRNN..."},
    initialVelocity = {vx = 200, vy = -288},
    difficulty = {rank = 2, label = "Baja-media", dropChance = 0.15},
    powerups = {"multiball", "giant_paddle", "shield"},
    background = {0.06, 0.06, 0.10}, primary = {0.70, 0.58, 0.95},
})

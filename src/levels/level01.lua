return require("src.levels.definition").make({
    stars = {twoScore = 8500, threeScore = 12000, minLives = 3},
    id = "el_comienzo", name = "El comienzo",
    rows = {"NNNNNNNNNNNN", "NNNNNNNNNNNN", "NNNNNNNNNNNN",
            "NNNNNNNNNNNN", "NNNNNNNNNNNN", "NNNNNNNNNNNN"},
    initialVelocity = {vx = 195, vy = -280},
    difficulty = {rank = 1, label = "Baja", dropChance = 0.15},
    powerups = {"multiball", "giant_paddle"},
    background = {0.040, 0.075, 0.095}, primary = {0.28, 0.65, 0.94},
})

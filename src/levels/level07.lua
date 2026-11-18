return require("src.levels.definition").make({
    stars = {twoScore = 8200, threeScore = 12500, minLives = 3},
    id = "otra_dimension", name = "Otra dimensión",
    rows = {"AAAE....EAAA", "AE.N....N.EA", "AE.N....N.EA",
            "ANNN....NNNA", "............", "..NEE..EEN.."},
    initialVelocity = {vx = 225, vy = -323},
    difficulty = {rank = 7, label = "Alta", dropChance = 0.15,
                  guaranteedPowerup = {kind = "fireball", everySeconds = 12}},
    powerups = {"multiball", "giant_paddle", "shield", "fireball", "laser", "magnet", "extra_life"},
    portals = {{id = "dimension_pair", cooldown = 0.4,
                entry = {x = 185, y = 330, radius = 22},
                exit = {x = 480, y = 140, radius = 22}, rotationDegrees = 90}},
    background = {0.025, 0.06, 0.13}, primary = {0.28, 0.85, 1},
})

return require("src.levels.definition").make({
    stars = {twoScore = 7000, threeScore = 10500, minLives = 3},
    id = "reaccion_en_cadena", name = "Reacción en cadena",
    rows = {".NEN....NEN.", "NEEEN..NEEEN", ".NEN....NEN.",
            "....NEEN....", "NEN.NEEN.NEN", "NNN......NNN"},
    initialVelocity = {vx = 205, vy = -295},
    difficulty = {rank = 3, label = "Media", dropChance = 0.15},
    powerups = {"multiball", "giant_paddle", "shield", "fireball"},
    background = {0.11, 0.045, 0.04}, primary = {1, 0.48, 0.22},
})

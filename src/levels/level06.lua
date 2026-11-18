return require("src.levels.definition").make({
    stars = {twoScore = 8500, threeScore = 13000, minLives = 3},
    id = "ahora_me_ves", name = "Ahora me ves",
    rows = {"G.G.G.G.G.G.", ".R.R.R.R.R.R", "G.G.G.G.G.G.",
            ".R.R.R.R.R.R", "GG..GG..GG..", "..RR..RR..RR"},
    initialVelocity = {vx = 220, vy = -316},
    difficulty = {rank = 6, label = "Media-alta", dropChance = 0.15},
    powerups = {"multiball", "giant_paddle", "shield", "fireball", "laser", "magnet", "extra_life"},
    background = {0.07, 0.04, 0.12}, primary = {0.71, 0.48, 0.98},
})

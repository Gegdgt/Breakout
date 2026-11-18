return require("src.levels.definition").make({
    stars = {twoScore = 17000, threeScore = 26000, minLives = 3},
    id = "ahora_me_ves", name = "Ahora me ves",
    rows = {"GGHH..JJGGHH", "RRU.GG.HURR.", "HHJJ..GGHHJJ", "G.U.R..R.U.G",
            "JJGG..HHJJGG", "RR..U..U..RR", "GHHG.RR.GJJG", "..U.G..H.U.."},
    initialVelocity = {vx = 220, vy = -316},
    difficulty = {rank = 6, label = "Media-alta", dropChance = 0.15},
    powerups = {"multiball", "giant_paddle", "shield", "fireball", "laser", "magnet", "extra_life"},
    background = {0.07, 0.04, 0.12}, primary = {0.71, 0.48, 0.98},
})

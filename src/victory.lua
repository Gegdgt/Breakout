-- Condicion unica compartida por progresion y estrellas; no muta la partida.
local Victory = {}
function Victory.satisfied(game)
    if game.level.activeVictory == "boss_defeated" then
        local boss = game.world:get(game.bossId, "Boss")
        return boss ~= nil and boss.defeated
    end
    return game.level.activeVictory == "clear_bricks" and game.remaining == 0
end
return Victory

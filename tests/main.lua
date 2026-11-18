-- Ejecutar desde la raiz: love tests
local root = love.filesystem.getSource() .. "/.."
package.path = root .. "/?.lua;" .. package.path
local quit = love.event.quit

function love.load()
    local ok, result = xpcall(function()
        local Config = require("src.config")
        local selectedMode = Config.ECS_ASSIGNMENT_MODE
        -- Probar siempre ambos modos, cualquiera que sea el elegido para jugar.
        Config.ECS_ASSIGNMENT_MODE = false
        local success, count = xpcall(function()
            return require("tests.game_spec").run(root) + require("tests.ecs_spec").run()
                + require("tests.levels_spec").run() + require("tests.progress_spec").run()
                + require("tests.special_bricks_spec").run()
                + require("tests.powers_portals_spec").run()
                + require("tests.score_spec").run(root)
                + require("tests.boss_spec").run()
                + require("tests.interface_spec").run(root)
                + require("tests.feedback_spec").run(root)
                + require("tests.sprint_spec").run()
                + require("tests.boss_balance_spec").run()
                + require("tests.life_effects_spec").run()
        end, debug.traceback)
        Config.ECS_ASSIGNMENT_MODE = selectedMode
        if not success then error(count, 0) end
        return count
    end, debug.traceback)
    if ok then
        print("PASS: " .. result .. " escenarios de Breakout")
    else
        print("FAIL: " .. result)
    end
    io.stdout:flush()
    -- Solo el ejecutor de pruebas se cierra automaticamente.
    quit(ok and 0 or 1)
end

-- Ejecutar desde la raiz: love tests
local root = love.filesystem.getSource() .. "/.."
package.path = root .. "/?.lua;" .. package.path
local quit = love.event.quit

function love.load()
    local ok, result = xpcall(function()
        return require("tests.game_spec").run(root)
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

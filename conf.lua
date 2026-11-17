-- Configuracion inicial de LÖVE 11.5.
function love.conf(t)
    t.identity = "breakout_engine_base"
    t.version = "11.5"
    t.console = true  -- Mostrar mensajes print() en Windows.

    t.window.title = "Breakout - Engine base"
    t.window.width = 960
    t.window.height = 640
    t.window.resizable = false
    t.window.vsync = 1
end

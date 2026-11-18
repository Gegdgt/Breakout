function love.conf(t)
    t.identity = "breakout_engine_tests" -- Nunca sobrescribir el guardado del juego.
    t.version = "11.5"
    t.console = true
    t.window.title = "Breakout - pruebas"
    t.window.width = 960
    t.window.height = 640
    t.modules.audio = false
end

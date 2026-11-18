local Config = require("src.config")
local LevelManager = require("src.level_manager")
local ProgressStore = require("src.progress_store")
local Helpers = require("tests.helpers")

local function run()
    local passed = 0
    local levels = LevelManager.new(Config)
    local function test(name, fn)
        fn()
        passed = passed + 1
        print("OK GUARDADO " .. passed .. ": " .. name)
    end
    local function store(fs) return ProgressStore.new(Config, levels, fs) end

    test("Archivo inexistente: valores iniciales y registros independientes", function()
        local disk = Helpers.memoryFilesystem()
        local progress = store(disk)
        local a, b = progress:load(), progress:load()
        assert(a.maxUnlocked == 1 and a.bestScore == 0 and a.bestCombo == 0 and disk.writes == 0)
        for _, level in ipairs(levels.levels) do
            assert(a.levels[level.id].stars == 0 and a.levels[level.id].bestScore == 0)
        end
        a.settings.musicVolume = 0
        a.levels.el_comienzo.stars = 3
        assert(b.settings.musicVolume == 0.6 and b.levels.el_comienzo.stars == 0)
    end)

    test("Round trip de desbloqueos, records, estrellas y configuracion sin datos de partida", function()
        local disk = Helpers.memoryFilesystem()
        local progress = store(disk)
        local data = progress:defaults()
        data.maxUnlocked, data.bestScore, data.bestCombo = 7, 42000, 24
        data.levels.resistencia = {bestScore = 12000, stars = 3}
        data.settings = {masterVolume = 0.4, musicVolume = 0.25, sfxVolume = 0, muted = true}
        data.lives, data.state, data.world = 5, "playing", {secret = true}
        assert(progress:save(data))
        local loaded = store(disk):load()
        assert(loaded.maxUnlocked == 7 and loaded.bestScore == 42000 and loaded.bestCombo == 24)
        assert(loaded.levels.resistencia.bestScore == 12000 and loaded.levels.resistencia.stars == 3)
        assert(loaded.settings.masterVolume == 0.4 and loaded.settings.musicVolume == 0.25)
        assert(loaded.settings.sfxVolume == 0 and loaded.settings.muted)
        assert(not loaded.lives and not loaded.state and not loaded.world)
        assert(not disk.files[Config.SAVE_FILE]:find("secret"))
    end)

    test("Datos incompletos o fuera de rango usan valores seguros campo por campo", function()
        local disk = Helpers.memoryFilesystem()
        disk.files[Config.SAVE_FILE] = table.concat({"BREAKOUT_PROGRESS 1", "maxUnlocked=4",
            "bestScore=-1", "bestCombo=1.5", "level.el_comienzo.stars=99", "level.resistencia.bestScore=1234",
            "settings.musicVolume=2", "settings.masterVolume=0.3", "settings.muted=true"}, "\n")
        local data = store(disk):load()
        assert(data.maxUnlocked == 4 and data.bestScore == 0 and data.bestCombo == 0)
        assert(data.levels.el_comienzo.stars == 0 and data.levels.resistencia.bestScore == 1234)
        assert(data.settings.musicVolume == 0.6 and data.settings.masterVolume == 0.3 and data.settings.muted)
        disk.files[Config.SAVE_FILE] = "BREAKOUT_PROGRESS 1\nmaxUnlocked=500\n"
        assert(store(disk):load().maxUnlocked == 1)
    end)

    test("Archivos corruptos, versiones desconocidas y codigo Lua nunca se ejecutan", function()
        local disk = Helpers.memoryFilesystem()
        _G.breakoutSaveExecuted = nil
        for _, raw in ipairs({"", "basura", "BREAKOUT_PROGRESS 99\nmaxUnlocked=10",
            "BREAKOUT_PROGRESS 1\nmaxUnlocked=2\nmaxUnlocked=10",
            "return {_G.breakoutSaveExecuted = true}",
            "BREAKOUT_PROGRESS 1\n_G.breakoutSaveExecuted = true",
            "BREAKOUT_PROGRESS 1\n" .. string.rep("x", Config.SAVE_MAX_BYTES)}) do
            disk.files[Config.SAVE_FILE] = raw
            local data = store(disk):load()
            assert(data.maxUnlocked == 1 and _G.breakoutSaveExecuted == nil)
        end
    end)

    test("Copia anterior valida recupera archivo corrupto o ausente", function()
        local disk = Helpers.memoryFilesystem()
        local progress = store(disk)
        local data = progress:defaults()
        data.maxUnlocked = 4
        assert(progress:save(data))
        data.maxUnlocked = 5
        assert(progress:save(data))
        for _, corrupt in ipairs({false, "archivo truncado"}) do
            disk.files[Config.SAVE_FILE] = corrupt or nil
            local recovered, warning = store(disk):load()
            assert(recovered.maxUnlocked == 4 and warning)
        end
        local recoveredStore = store(disk)
        local recovered = recoveredStore:load()
        recovered.maxUnlocked = 6
        assert(recoveredStore:save(recovered))
        assert(store(disk):load().maxUnlocked == 6)
    end)

    test("Disco inaccesible o funciones que lanzan errores no cierran el juego", function()
        local disk = {
            getInfo = function() error("sin acceso") end,
            read = function() error("sin acceso") end,
            write = function() error("sin acceso") end,
        }
        local progress = store(disk)
        local data = progress:load()
        assert(data.maxUnlocked == 1)
        local saved, warning = progress:save(data)
        assert(not saved and warning)
        assert(store(nil):load().maxUnlocked == 1 and not store(nil):save(data))
    end)

    test("Fallo al escribir copia protege principal; fallo del principal deja copia recuperable", function()
        local disk = Helpers.memoryFilesystem()
        local progress = store(disk)
        local data = progress:defaults()
        data.maxUnlocked = 3
        progress:save(data)
        local original = disk.files[Config.SAVE_FILE]
        data.maxUnlocked = 4
        disk.write = function() return nil, "lleno" end
        assert(not progress:save(data) and disk.files[Config.SAVE_FILE] == original)
        disk.write = function(path, contents)
            if path == Config.SAVE_FILE then
                disk.files[path] = "escritura interrumpida"
                return false
            end
            disk.files[path] = contents
            return true
        end
        assert(not progress:save(data))
        assert(store(disk):load().maxUnlocked == 3)
    end)

    test("Guardado sanea NaN, infinito, tipos invalidos y campos ajenos", function()
        local progress = store(Helpers.memoryFilesystem())
        local data = progress:normalize({maxUnlocked = 0 / 0, bestScore = math.huge, bestCombo = -10,
            levels = {resistencia = false, el_comienzo = {stars = -1}},
            settings = {musicVolume = "nan", muted = "true", sfxVolume = -2}, unknown = true})
        assert(data.maxUnlocked == 1 and data.bestScore == 0 and data.bestCombo == 0)
        assert(data.levels.resistencia.stars == 0 and data.levels.el_comienzo.stars == 0)
        assert(data.settings.musicVolume == 0.6 and data.settings.muted == false and data.settings.sfxVolume == 0.8)
        assert(data.unknown == nil)
    end)

    test("CRLF, claves futuras y niveles ajenos no rompen la carga", function()
        local progress = store(Helpers.memoryFilesystem())
        local data = progress:decode("BREAKOUT_PROGRESS 1\r\nmaxUnlocked=3\r\nfuture=ignored\r\nlevel.unknown.stars=3\r\n")
        assert(data.maxUnlocked == 3 and data.levels.unknown == nil)
    end)

    test("love.filesystem real: escribir, leer y recuperar en identidad aislada de pruebas", function()
        local config = {}
        for key, value in pairs(Config) do config[key] = value end
        config.SAVE_FILE, config.SAVE_BACKUP_FILE = "phase1_integration.dat", "phase1_integration.bak"
        assert(not config.SAVE_FILE:find("[/\\:]"))
        local fs = love.filesystem
        fs.remove(config.SAVE_FILE)
        fs.remove(config.SAVE_BACKUP_FILE)
        local ok, err = xpcall(function()
            local progress = ProgressStore.new(config, levels, fs)
            local data = progress:load()
            data.maxUnlocked = 8
            data.levels.caos_total.stars = 2
            assert(progress:save(data))
            local loaded = ProgressStore.new(config, levels, fs):load()
            assert(loaded.maxUnlocked == 8 and loaded.levels.caos_total.stars == 2)
            assert(fs.write(config.SAVE_FILE, "corrupto"))
            assert(ProgressStore.new(config, levels, fs):load().maxUnlocked == 8)
        end, debug.traceback)
        fs.remove(config.SAVE_FILE)
        fs.remove(config.SAVE_BACKUP_FILE)
        assert(ok, err)
    end)
    return passed
end

return {run = run}

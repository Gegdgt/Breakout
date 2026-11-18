-- Formato de texto versionado: nunca ejecuta Lua leido desde el disco.
local ProgressStore = {}
ProgressStore.__index = ProgressStore
local HEADER = "BREAKOUT_PROGRESS 1"

local function number(value, default, minimum, maximum, integer)
    if type(value) ~= "number" and type(value) ~= "string" then return default end
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return default end
    if integer and value % 1 ~= 0 then return default end
    if value < minimum or value > maximum then return default end
    return value
end

function ProgressStore.new(config, levels, filesystem)
    return setmetatable({config = config, levels = levels, filesystem = filesystem}, ProgressStore)
end

function ProgressStore:defaults()
    local data = {maxUnlocked = 1, bestScore = 0, bestCombo = 0, levels = {}, settings = {}}
    for _, level in ipairs(self.levels.levels) do data.levels[level.id] = {bestScore = 0, stars = 0} end
    for key, value in pairs(self.config.DEFAULT_SETTINGS) do data.settings[key] = value end
    return data
end

function ProgressStore:normalize(input)
    local data = self:defaults()
    input = type(input) == "table" and input or {}
    data.maxUnlocked = number(input.maxUnlocked, 1, 1, self.levels:count(), true)
    data.bestScore = number(input.bestScore, 0, 0, 2147483647, true)
    data.bestCombo = number(input.bestCombo, 0, 0, 2147483647, true)
    local records = type(input.levels) == "table" and input.levels or {}
    for id, record in pairs(data.levels) do
        local source = type(records[id]) == "table" and records[id] or {}
        record.bestScore = number(source.bestScore, 0, 0, 2147483647, true)
        record.stars = number(source.stars, 0, 0, 3, true)
    end
    local settings = type(input.settings) == "table" and input.settings or {}
    for key, default in pairs(data.settings) do
        if type(default) == "number" then
            data.settings[key] = number(settings[key], default, 0, 1, false)
        elseif type(settings[key]) == "boolean" then
            data.settings[key] = settings[key]
        end
    end
    return data
end

function ProgressStore:decode(text)
    if type(text) ~= "string" or #text > self.config.SAVE_MAX_BYTES then return nil end
    text = text:gsub("\r\n", "\n")
    if text:match("^([^\n]+)") ~= HEADER then return nil end
    local data, seen = {levels = {}, settings = {}}, {}
    for line in text:gmatch("[^\n]+") do
        if line ~= HEADER then
            local key, value = line:match("^([%w_%.]+)=([^=]+)$")
            if not key or seen[key] then return nil end
            seen[key] = true
            local id, field = key:match("^level%.([%w_]+)%.([%w_]+)$")
            local setting = key:match("^settings%.([%w_]+)$")
            if id then
                data.levels[id] = data.levels[id] or {}
                data.levels[id][field] = value
            elseif setting then
                if setting == "muted" then
                    data.settings[setting] = value == "true"
                else
                    data.settings[setting] = value
                end
            elseif key == "maxUnlocked" or key == "bestScore" or key == "bestCombo" then
                data[key] = value
            end
        end
    end
    return self:normalize(data)
end

function ProgressStore:encode(input)
    local data = self:normalize(input)
    local lines = {HEADER, "maxUnlocked=" .. data.maxUnlocked,
                   "bestScore=" .. data.bestScore, "bestCombo=" .. data.bestCombo}
    for _, level in ipairs(self.levels.levels) do
        local record = data.levels[level.id]
        lines[#lines + 1] = "level." .. level.id .. ".bestScore=" .. record.bestScore
        lines[#lines + 1] = "level." .. level.id .. ".stars=" .. record.stars
    end
    for _, key in ipairs({"masterVolume", "musicVolume", "sfxVolume", "muted"}) do
        lines[#lines + 1] = "settings." .. key .. "=" .. tostring(data.settings[key])
    end
    return table.concat(lines, "\n") .. "\n"
end

function ProgressStore:read(path)
    if not self.filesystem then return nil end
    local ok, contents = pcall(function()
        local info = self.filesystem.getInfo(path)
        if not info or info.type ~= "file" or info.size > self.config.SAVE_MAX_BYTES then return nil end
        return self.filesystem.read(path, self.config.SAVE_MAX_BYTES)
    end)
    if ok then return self:decode(contents), contents end
end

function ProgressStore:load()
    local data, raw = self:read(self.config.SAVE_FILE)
    if data then self.lastGood = raw; return data end
    data, raw = self:read(self.config.SAVE_BACKUP_FILE)
    if data then
        self.lastGood = raw
        return data, "Progreso recuperado desde la copia de seguridad."
    end
    return self:defaults()
end

function ProgressStore:save(data)
    if not self.filesystem then return false, "Guardado no disponible." end
    local contents = self:encode(data)
    local function write(path, value)
        local ok, result = pcall(self.filesystem.write, path, value)
        return ok and result == true
    end
    -- La copia se escribe antes del principal. Si falla, no arriesgar el principal.
    if not write(self.config.SAVE_BACKUP_FILE, self.lastGood or contents)
        or not write(self.config.SAVE_FILE, contents) then
        return false, "No se pudo guardar el progreso; se conserva en esta sesión."
    end
    self.lastGood = contents
    return true
end

return ProgressStore

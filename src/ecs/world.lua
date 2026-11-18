-- Entidades = IDs; los componentes se almacenan por tipo e ID.
local World = {}
World.__index = World

function World.new()
    return setmetatable({nextId = 0, entities = {}, components = {}}, World)
end

function World:create(components)
    self.nextId = self.nextId + 1
    local id = self.nextId
    self.entities[id] = true
    for name, data in pairs(components) do
        self.components[name] = self.components[name] or {}
        self.components[name][id] = data
    end
    return id
end

function World:get(id, name)
    local storage = self.components[name]
    return storage and storage[id]
end

function World:has(id, ...)
    if not self.entities[id] then return false end
    for index = 1, select("#", ...) do
        if not self:get(id, select(index, ...)) then return false end
    end
    return true
end

-- Instantanea ordenada: crear/destruir durante un recorrido no cambia su lista.
-- Antes de usar un ID de una instantanea antigua se comprueba world:has(id).
function World:query(...)
    local result = {}
    for id in pairs(self.entities) do
        if self:has(id, ...) then result[#result + 1] = id end
    end
    table.sort(result)
    return result
end

function World:count(...)
    return #self:query(...)
end

-- Borrado inmediato e idempotente: un bloque no recibe dos destrucciones.
function World:destroy(id)
    if not self.entities[id] then return false end
    self.entities[id] = nil
    for _, storage in pairs(self.components) do storage[id] = nil end
    return true
end

function World:clear()
    self.entities, self.components = {}, {}
    -- No reciclar IDs al reiniciar: las referencias antiguas siguen invalidas.
end

return World

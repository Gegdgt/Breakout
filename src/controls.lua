local Controls = {}
local names = {left = "Flecha izquierda", right = "Flecha derecha", lshift = "Shift izq.", rshift = "Shift der.", space = "Espacio", escape = "ESC"}
function Controls.matches(config, action, key)
    for _, binding in ipairs(config.CONTROLS[action]) do if binding == key then return true end end
    return false
end
function Controls.label(config, action)
    local labels = {}
    for _, binding in ipairs(config.CONTROLS[action]) do labels[#labels + 1] = names[binding] or binding:upper() end
    return table.concat(labels, " / ")
end
return Controls

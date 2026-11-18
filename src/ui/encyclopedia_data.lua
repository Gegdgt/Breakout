-- Contenido descriptivo; cantidades, colores, controles y jefes provienen del juego.
local Controls = require("src.controls")
local Data = {}

function Data.build(game)
    local c = game.config
    local action = Controls.label(c, "action")
    local powerText = {
        multiball = {"Cada pelota se convierte en tres, hasta " .. c.MAX_BALLS .. " pelotas en pantalla.",
            "Instantáneo al recogerlo. Solo pierdes una vida cuando cae la última pelota.", "Úsalo para mantener el combo y cubrir varias zonas."},
        giant_paddle = {"Amplía el paddle a " .. c.GIANT_PADDLE_SCALE .. " veces su ancho.",
            c.GIANT_PADDLE_SECONDS .. " segundos. Se activa al recogerlo.", "Sus extremos también permiten dirigir los rebotes."},
        fireball = {"La pelota atraviesa bloques destructibles y puede romper blindados.",
            c.FIREBALL_SECONDS .. " segundos. Automático al recogerlo; daño: " .. c.FIREBALL_DAMAGE .. ".",
            "Los irrompibles, obstáculos y jefes siguen haciendo rebotar la pelota."},
        laser = {"Dispara dos proyectiles desde el paddle. Daña bloques, blindados y zonas vulnerables de jefes.",
            c.LASER_AMMO .. " disparos dobles por recarga. Dispara con " .. action .. ".",
            "Apunta al núcleo abierto. Si tienes una pelota capturada, primero la liberas."},
        shield = {"Una barrera inferior devuelve las pelotas que iban a caer.",
            c.SHIELD_SECONDS .. " segundos o " .. c.SHIELD_HITS .. " impactos. Se activa al recogerlo.",
            "Aprovecha la protección para buscar un mejor ángulo de ataque."},
        magnet = {"El paddle captura una pelota al recibirla.",
            c.MAGNET_SECONDS .. " segundos. Libérala con " .. action .. ".",
            "Muévete hasta una posición favorable antes de lanzarla."},
        extra_life = {"Recupera una vida, hasta el máximo de " .. c.MAX_LIVES .. ".",
            "Efecto instantáneo al recogerlo.", "Las vidas restantes también cuentan para obtener tres estrellas."},
    }
    local powers = {}
    for _, kind in ipairs({"multiball", "giant_paddle", "fireball", "laser", "shield", "magnet", "extra_life"}) do
        local p = c.POWERUP_TYPES[kind]
        powers[#powers + 1] = {id = kind, name = p.name, label = p.label, color = p.color, paragraphs = powerText[kind], visual = "power"}
    end
    local brickText = {
        normal = {"Se destruye con un impacto normal, fuego, láser o una explosión.", "Busca cadenas rápidas para aumentar tu combo."},
        resistant = {"Tiene entre 2 y 4 puntos de vida; el valor habitual es " .. c.BRICK_DEFAULTS.health .. ". El número R indica la vida restante.",
            "Cada fuente aplica su daño configurado. El color se apaga al perder vida."},
        explosive = {"Al destruirse, daña solo una celda arriba, abajo, izquierda y derecha. Nunca las diagonales.",
            "Daño habitual: " .. c.BRICK_DEFAULTS.explosionDamage .. ". Puede activar otros explosivos una sola vez cada uno.",
            "La vecindad es lógica: los móviles conservan su celda de origen. Aprovecha las cadenas cortas."},
        moving = {"Se mueve de forma horizontal, vertical, oscilante o en grupo. Se destruye con los ataques habituales.",
            "Anticipa su recorrido; cambia el ángulo usando los extremos del paddle."},
        ghost = {"Alterna entre sólido e intangible. Habitualmente: " .. c.BRICK_DEFAULTS.solidSeconds .. " s sólido y " .. c.BRICK_DEFAULTS.intangibleSeconds .. " s intangible.",
            "Parpadea antes de cambiar. Solo recibe daño cuando es sólido; espera si una pelota ocupa su espacio.",
            "En niveles avanzados, los grupos tienen distintos desfases. Ataca el grupo visible."},
        armored = {"Rechaza pelotas normales. Sus vulnerabilidades de campaña son fuego, láser y explosiones.",
            "Los niveles con blindados ofrecen fuego renovable garantizado. Recógelo: no necesitas esperar un premio aleatorio.",
            "Una explosión solo ayuda si el blindado es vecino ortogonal."},
        unbreakable = {"No tiene vida y ningún ataque puede destruirlo. No entrega puntos ni poderes.",
            "Todas las pelotas, incluso las de fuego, rebotan como contra una pared.",
            "No cuenta para completar el nivel. Úsalo para alcanzar objetivos desde otros ángulos."},
    }
    local labels = {normal = "N", resistant = "R" .. c.BRICK_DEFAULTS.health, explosive = "*", moving = "<>", ghost = "G", armored = "A", unbreakable = "[=]"}
    local bricks = {}
    for _, kind in ipairs({"normal", "resistant", "explosive", "moving", "ghost", "armored", "unbreakable"}) do
        bricks[#bricks + 1] = {id = kind, name = c.BRICK_NAMES[kind], label = labels[kind],
            color = c.BRICK_TYPE_COLORS[kind] or c.BRICK_COLORS[1], paragraphs = brickText[kind], visual = "brick"}
    end
    local bosses = {}
    for _, index in ipairs({5, 10}) do
        local level = game.levels:get(index)
        local b = level.boss
        local paragraphs = {"NIVEL " .. index .. " · " .. b.health .. " puntos de vida · Una sola barra de salud.",
            "Ataca el punto frontal verde desde abajo o el núcleo azul superior con una pelota descendente. La zona superior ocupa el " .. math.floor(c.BOSS_TOP_WEAK_POINT_WIDTH_RATIO * 100) .. "% del ancho.",
            "Ambas zonas comparten daño y protección. Gris significa cerrado; espera a que se iluminen."}
        if index == 5 then
            paragraphs[#paragraphs + 1] = "Patrulla de lado a lado, anuncia sus desplazamientos y descansa. Genera bloques resistentes que protegen el frente. Rodéalo para atacar desde arriba."
        else
            local phases = b.phases
            paragraphs[#paragraphs + 1] = "1 · " .. phases[1].name .. ": barreras y ventanas de apertura.\n2 · " .. phases[2].name .. ": movimiento y proyectiles dirigidos.\n3 · " .. phases[3].name .. ": teletransportes anunciados, fantasmas y abanicos de proyectiles."
            paragraphs[#paragraphs + 1] = "Las fases siguientes empiezan con " .. (phases[2].health + phases[3].health) .. " y " .. phases[3].health .. " de vida restante. Cada transición conserva su aviso e invulnerabilidad."
        end
        paragraphs[#paragraphs + 1] = "El láser tiene " .. c.BOSS_LASER_DROP_WEIGHT_MULTIPLIER .. " veces su peso habitual en los premios del combate. También puedes vencer usando solo pelotas normales."
        bosses[#bosses + 1] = {id = b.id, name = level.name, color = level.theme.primary, visual = "boss", boss = b, paragraphs = paragraphs}
    end
    local mechanics = {
        {id = "controls", name = "Controles", label = "AD", paragraphs = {
            Controls.label(c, "left") .. ": izquierda.\n" .. Controls.label(c, "right") .. ": derecha.\n" .. Controls.label(c, "sprint") .. ": sprint mientras te mueves.",
            action .. ": liberar pelota magnética o disparar láser.\n" .. Controls.label(c, "pause") .. ": pausa y continuar.\n" .. Controls.label(c, "menu") .. ": menú.",
            Controls.label(c, "restart") .. ": reiniciar en GAME OVER o YOU WIN! Durante la pausa, elige Reiniciar nivel."}},
        {id = "bounce", name = "Rebotes y sprint", label = "<>", paragraphs = {
            "El centro del paddle devuelve la pelota hacia arriba. Los extremos la desvían hasta 60 grados hacia el lado del impacto.",
            "Sprint: " .. c.PADDLE_SPRINT_MULTIPLIER .. " veces la velocidad del paddle. No acelera la pelota; su límite es " .. c.BALL_MAX_SPEED .. " px/s.",
            "Los obstáculos móviles son superficies de rebote. Espera a que abran un paso."}},
        {id = "lives", name = "Vidas y poderes", label = "+1", paragraphs = {
            "Empiezas con " .. c.STARTING_LIVES .. " vidas. Solo pierdes una cuando cae la última pelota. Máximo: " .. c.MAX_LIVES .. ".",
            "Al perder una vida conservas poderes, munición y duraciones restantes; el combo se reinicia.",
            "Completar un nivel devuelve " .. c.LEVEL_LIFE_REWARD .. " vida. Reiniciar el nivel limpia los poderes y los puntos de ese intento."}},
        {id = "multiball", name = "MULTIBALL", label = "x3", paragraphs = powerText.multiball},
        {id = "combo", name = "Puntos y combos", label = "x5", paragraphs = {
            "Destruye otro bloque antes de " .. c.COMBO_WINDOW .. " segundos para mantener la cadena.",
            "El multiplicador sube cada " .. c.COMBO_STEP .. " destrucciones, hasta x" .. c.COMBO_MAX_MULTIPLIER .. ". Golpear sin destruir no aumenta la cadena.",
            "Irrompibles y protectores del jefe no dan puntos. Perder una vida o dejar vencer el tiempo reinicia el combo."}},
        {id = "stars", name = "Estrellas y progreso", label = "***", paragraphs = {
            "Completar un nivel da una estrella. La segunda requiere su umbral de puntuación; la tercera exige más puntos y las vidas mínimas indicadas por el nivel.",
            "Completar desbloquea el siguiente nivel. Récords, estrellas, preferencias y desbloqueos se guardan automáticamente.",
            "La enciclopedia conserva tu progreso. La selección de niveles muestra tus mejores resultados."}},
        {id = "portals", name = "Portales", label = "()", paragraphs = {
            "Cada portal está enlazado con otro: puedes usar ambos sentidos. Al cruzar, la trayectoria gira según el par y conserva su rapidez.",
            "Una breve espera evita saltos repetidos. Si la salida está obstruida, la pelota continúa su recorrido original.",
            "Utilízalos para llegar detrás de las defensas. Los pares tienen identificadores visuales distintos."}},
    }
    for _, entry in ipairs(mechanics) do entry.color, entry.visual = {0.4, 0.8, 1}, "power" end
    return {{name = "Power-ups", entries = powers}, {name = "Tipos de bloques", entries = bricks},
        {name = "Jefes", entries = bosses}, {name = "Controles y mecánicas", entries = mechanics}}
end
return Data

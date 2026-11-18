# Breakout Arcade — ECS con LÖVE 11.5

Juego en **Lua + LÖVE**, sin librerías externas. **Fases 1–7 implementadas:** diez
niveles manuales, progresión, guardado, bloques especiales, obstáculos, siete poderes,
portales, puntuación, combos, estrellas, dos jefes, menús, selector, pausa,
transiciones, partículas acotadas y audio original.
Se conserva el ECS existente y el modo normal sigue siendo el predeterminado.

## Actualización arcade: dificultad y enciclopedia

- **Irrompibles (`U` / `unbreakable`)**: metal oscuro con refuerzo `[=]`, sin
  `Health` ni `ScoreValue`. Rebotan incluso pelotas de fuego, detienen el láser y
  resisten explosiones; un impacto genera chispas. No dan poderes ni cuentan
  entre los objetivos. Los niveles con jefe siguen exigiendo derrotarlo.
- **Jefes**: Guardián **20 → 10 HP**; Núcleo **45 → 23 HP**. Las tres fases del
  Núcleo distribuyen 8/7/8 HP y cambian con **15 y 8 HP restantes** (65 % y 35 %,
  los enteros más cercanos a dos tercios y un tercio). Ataques, velocidades,
  daño por golpe, punto frontal ampliado y mayor peso del láser se conservan.
- **Núcleo superior**: zona azul centrada de **48 × 8 px**, el 30 % del ancho del
  jefe. El barrido del cuerpo calcula el contacto en la pose del impacto; la
  cara superior se identifica con su normal de colisión. Comparte salud,
  invulnerabilidad y cooldown con el frente. La pelota se separa y rebota una
  vez; `Ball.contacts` impide repetir daño hasta separarse. Tiene destello y
  partículas al acertar. No se añade otra barra ni otro cuerpo sólido.
- **Explosiones en cruz**: `GridPosition.row/column` conserva la celda de origen
  incluso al mover un bloque. Solo se consultan los cuatro vecinos ortogonales,
  a distancia Manhattan 1. Daño habitual: 1. La cola iterativa y su registro de
  fuentes procesadas evitan eventos duplicados; explosiones diferentes sí
  pueden dañar el mismo resistente. Las partículas recorren esos cuatro ejes.
- **Enciclopedia**: menú principal → **ENCICLOPEDIA**, con siete poderes, siete
  tipos de bloques, ambos jefes y controles/mecánicas. Flechas o A/D cambian
  categoría; arriba/abajo o W/S cambian ficha; rueda, RePág/AvPág y Home/End
  desplazan el texto; ESC, M o el botón Volver regresan al menú. También admite
  clics en categorías y fichas. No altera récords, desbloqueos ni guardados.
  Usa la resolución configurada y ajuste de líneas con recorte y barra de scroll.
  `src/ui/encyclopedia_data.lua` lee cantidades, colores, teclas y jefes reales;
  `src/ui/encyclopedia.lua` mantiene navegación y presentación fuera de `main.lua`.

### Dificultad de los niveles 6–9

| Nivel | Distribución y reto | Ayudas conservadas |
|---|---|---|
| 6 — Ahora me ves | 45 fantasmas en tres grupos desfasados, 12 resistentes y 8 irrompibles. Siempre hay un grupo sólido salvo espera por pelotas dentro. | Ciclo 3 s sólido / 2 s intangible y avisos previos. |
| 7 — Otra dimensión | 10 blindados, 20 resistentes, 12 irrompibles y dos pares de portales. Pasillos con accesos laterales. | Fuego garantizado cada 12 s; pares A1/A2 y B1/B2 identificados. |
| 8 — Precisión extrema | 14 móviles en tres patrones, 6 fantasmas, 8 resistentes, 8 irrompibles y tres obstáculos con fases distintas. | Movimientos suaves de 4–7 s y espacio libre cerca del paddle. |
| 9 — Caos total | 18 resistentes, 10 explosivos, 8 móviles, 10 fantasmas, 8 blindados, 10 irrompibles, dos pares de portales y dos obstáculos. | Cadenas cortas, fuego garantizado cada 10 s y varios accesos. |

Se conservan las velocidades iniciales, el límite de **550 px/s**, el sprint,
MULTIBALL hasta **90 pelotas**, tres vidas iniciales y conservación de poderes
entre vidas. La probabilidad aleatoria sigue siendo 15 %. Los umbrales de
estrellas de 6 y 9 se ajustaron al nuevo número de objetivos; los récords y las
estrellas ya guardados se conservan.

Las pruebas de acceso retiran objetivos por capas desde regiones alcanzables
por una pelota de tamaño real, considerando irrompibles y la envolvente completa
de obstáculos. También prueban daño legal, fuego garantizado, ventanas fantasma,
portales en ambos sentidos con ocho direcciones y varios instantes de movimiento,
y simulación con 90 pelotas. Son comprobaciones de geometría y reglas; no equivalen
a una campaña completa jugada por una persona ni miden la dificultad subjetiva.

### Archivos de esta actualización

| Área | Archivos modificados o nuevos |
|---|---|
| Entrada y configuración | `main.lua`, `src/game.lua`, `src/config.lua`, `src/controls.lua` (nuevo), `src/paddle.lua` |
| Bloques, mapas y validación | `src/bricks.lua`, `src/ecs/components.lua`, `src/level_manager.lua`, `src/level_rules.lua`, `src/score_rules.lua`, `src/levels/definition.lua`, `src/levels/level05.lua` a `level10.lua` |
| Jefes | `src/bosses.lua`, `src/boss_rules.lua`, `src/ecs/systems/boss_system.lua`, `boss_damage_system.lua`, `boss_render_system.lua` |
| Daño y progresión (en `src/ecs/systems/`) | `damage_system.lua`, `explosion_system.lua`, `solid_collision_system.lua`, `progression_system.lua`, `portal_system.lua` |
| Interfaz (en `src/ecs/systems/`) | `state_system.lua`, `interface_system.lua`, `screen_render_system.lua`, `audio_system.lua`, `particle_system.lua` |
| Enciclopedia nueva | `src/ui/encyclopedia.lua`, `src/ui/encyclopedia_data.lua` |
| Pruebas (en `tests/`) | `arcade_improvements_spec.lua` (nuevo), `main.lua`, `helpers.lua`, `boss_spec.lua`, `boss_balance_spec.lua`, `levels_spec.lua`, `interface_spec.lua`, `life_effects_spec.lua`, `powers_portals_spec.lua`, `score_spec.lua`, `special_bricks_spec.lua` |
| Documentación | `README.md` |

## Ejecutar

Desde la raíz del repositorio, en PowerShell:

```powershell
& "C:\Program Files\LOVE\lovec.exe" .
```

Si LÖVE está en el PATH, usa `love .`. Requiere LÖVE 11.5; la ventana conserva
960 × 640 y consola habilitada. Los sonidos y la música están incluidos en
`assets/audio/`; no se necesitan descargas, paquetes ni Python para jugar.

## Alcance de esta fase

Los diez niveles se pueden jugar y completar. Cada uno tiene ID estable, nombre,
mapa propio, posiciones iniciales, velocidad, dificultad, paleta y configuración
de poderes, obstáculos, portales, condición de victoria y jefe cuando corresponde.

La **Fase 2** activa resistentes, explosivos, móviles, fantasmas, blindados y
obstáculos móviles. La **Fase 3** añade gigante, fuego, láser, escudo, imán y vida
extra junto con MULTIBALL x3, y activa los portales de los niveles 7 y 9.
La **Fase 5** activa el Guardián mecánico y el Núcleo del caos. Los niveles 5 y 10
ahora se completan derrotando a su jefe, aunque todavía queden bloques.
Los blindados ahora rechazan las pelotas normales; los mapas garantizan su
destrucción mediante explosivos cercanos y suministro periódico de fuego, sin depender del azar.

La **Fase 4** calcula puntuación, combos y estrellas, y guarda los mejores resultados.
La **Fase 6** incorpora menú principal, selector de los diez niveles, opciones,
pausa, HUD organizado y transiciones con cuenta regresiva. La **Fase 7** añade
estelas, chispas, fragmentos y celebraciones, 16 efectos sonoros y tres pistas
originales de música. Las preferencias de volumen y silencio se aplican al
instante. Se conservan las reglas de las fases anteriores, incluidas 90 pelotas,
550 px/s, precisión de colisiones y cierre lateral del modo de entrega ECS.

## Controles

| Contexto | Tecla | Acción |
|---|---|---|
| Partida | A / D o flechas izquierda / derecha | Mover el paddle. |
| Partida | Shift izquierdo o derecho + dirección | Sprint del paddle mientras se mantiene la combinación. |
| Partida | Espacio | Lanzar la pelota atrapada; si no hay captura, disparar ambos cañones. |
| Partida o entrada de nivel | ESC / P | Pausar. |
| Pausa | ESC / P | Continuar exactamente desde el estado suspendido. |
| Partida, pausa, entrada, transición o pantalla final | M | Volver al menú; abandonar el intento actual. |
| GAME OVER | R | Reiniciar **el mismo nivel** con sus bloques completos y 3 vidas. |
| YOU WIN! | R | Nueva campaña desde el nivel 1 con 3 vidas. |
| Menús, pausa y resultados | Arriba / abajo o W / S; Enter | Elegir una opción y aceptarla. |
| Selector | Flechas o W / A / S / D; Enter | Elegir uno de los diez niveles e iniciar si está desbloqueado. |
| Opciones | Izquierda / derecha o A / D | Ajustar volumen; alternar silencio en su fila. |
| Opciones | Enter | Alternar silencio o aceptar Volver. |
| Selector, opciones o resultados | ESC | Volver al menú; guardar preferencias pendientes. |
| Menú | C | Empezar el nivel máximo desbloqueado con 3 vidas. |
| Menú principal | Seleccionar Salir y pulsar Enter | Guardar cambios pendientes y cerrar. |

R se ignora durante la partida, pausa y entrada/transición. C inicia un nuevo intento
del nivel desbloqueado: no restaura una partida suspendida. **Abrir el juego muestra
el menú principal**. Jugar inicia desde el nivel 1; Seleccionar nivel permite repetir
cualquier nivel desbloqueado. Espacio está reservado a los poderes durante la partida.
ESC ya no cierra el juego durante la partida: abre la pausa. Perder el foco de la
ventana también pausa; recuperarlo no reanuda automáticamente. La navegación es
por teclado; el menú principal y la enciclopedia también admiten mouse.

### Sprint del paddle

Mantén **Shift izquierdo o derecho** junto con A/D o las flechas para moverte a
**855 px/s**. Al soltar Shift vuelves a **475 px/s** en la siguiente actualización
de entrada, sin cooldown, energía ni límite de uso. Shift solo no mueve el paddle;
izquierda y derecha simultáneas se cancelan, y ambos Shift no duplican el efecto.

Configura en `src/config.lua`:

```lua
PADDLE_NORMAL_SPEED = 475,
PADDLE_SPRINT_MULTIPLIER = 1.8,
```

La velocidad normal conserva su valor anterior. `PADDLE_SPEED` permanece como
alias de lectura para consumidores existentes; ajusta `PADDLE_NORMAL_SPEED` para
cambiarla. El sistema de entrada de `src/paddle.lua` calcula la velocidad a partir
de `PaddleControl`, integra con el movimiento existente y aplica los mismos límites
de pantalla usando el ancho actual. Se conserva el tope de `dt` del coordinador.
Gigante e imán son compatibles: la pelota capturada sigue al paddle después de
moverlo y mantiene su velocidad de lanzamiento. El sprint no modifica las pelotas
ni los límites globales de **550 px/s** y **90 pelotas**.

La ayuda inferior del HUD muestra **SHIFT: Sprint**. Cuando el paddle se desplaza
con Shift cambia a **SPRINT** en verde, sin animaciones ni recursos gráficos nuevos.
Al detenerse contra un borde vuelve a la indicación habitual. Pausa, cuenta
regresiva y menús conservan sus reglas: Shift no mueve el paddle en esos estados.

Archivos de este ajuste: modificados `src/config.lua`, `src/ecs/components.lua`,
`src/paddle.lua`, `src/ecs/systems/hud_render_system.lua`, `tests/main.lua` y este
README; creado `tests/sprint_spec.lua`. No se agregan sistemas ECS ni se modifican
los sistemas de colisiones, poderes, vidas, jefes, puntuación o progresión.

## Progresión y reglas conservadas

- Una partida nueva empieza con **3 vidas** y una pelota.
- Al cargar o reiniciar un nivel hay **0,6 s de presentación y 3 s de cuenta
  regresiva**. El mundo permanece inmóvil hasta terminar; perder una vida dentro
  del mismo nivel conserva la reposición de ronda anterior, sin esa cuenta adicional.
- Al perder una pelota se elimina únicamente esa entidad. Se descuenta una vida
  solo al desaparecer **la última pelota**, aunque caigan 90 en el mismo frame.
- Un proyectil enemigo que golpea el paddle vulnerable también cuesta una vida:
  repone la ronda con una pelota, conserva los poderes y concede 2 s de
  invulnerabilidad. La salud y fase del jefe se conservan. Ambos motivos de pérdida
  en el mismo frame descuentan una sola vida; la victoria mantiene prioridad.
- Si quedan vidas se centra el mismo paddle conservando su ancho y poderes; se
  crea una sola pelota con la posición y velocidad iniciales del nivel actual.
  **Se conservan los bloques destruidos**, objetos caídos y proyectiles existentes.
- Al completar un nivel se recupera **1 vida, hasta un máximo de 5**. Se desbloquea
  y guarda inmediatamente el siguiente nivel, incluso antes de la transición.
- `LEVEL COMPLETE` congela la simulación durante **2 segundos**; las partículas
  terminan su animación y se limpian. Después se carga
  el siguiente mapa y su cuenta regresiva, conservando las vidas y limpiando pelotas/poderes anteriores.
- La transición usa `dt` real. La simulación conserva el límite original de
  `math.min(dt, 0.05)` para pausas o arrastres de ventana.
- El nivel 10 termina en **YOU WIN!** y `campaign_complete`. No existe un nivel 11.
- Con cero vidas aparece **GAME OVER**; R permite otro intento del nivel actual.
- La victoria conserva prioridad sobre pérdidas de vida y recogidas en el mismo
  frame. El premio y el desbloqueo se aplican una sola vez.
- Reiniciar una campaña o un nivel **no borra el progreso persistente**.

El paddle conserva el rebote direccional por punto de impacto: desde −60° hasta
+60° respecto a la vertical, con salida vertical en el centro. Se usa el centro
y el ancho actual de ambos colliders. La rapidez aumenta por **1.08** al rebotar
en el paddle o las paredes, hasta el máximo global de **550 px/s**. Solo se procesa
el contacto descendente con el paddle
y se separa la pelota para impedir aceleraciones repetidas en el mismo contacto.

La probabilidad **total** de aparición de poderes es del **15 %**, configurable en
`difficulty.dropChance` de cada nivel; se reparte entre los poderes desbloqueados.
Con MULTIBALL cada pelota original crea dos copias con
aproximadamente ±25° y la misma rapidez: 1 → 3 → 9 → 27 → 81 → 90. El límite ahora
es de **90 pelotas**, con componentes independientes y recogida simultánea de
poderes. Un bloque solo se destruye y sortea un poder una vez.

### Configurar los límites de pelotas

Ambas constantes están centralizadas en `src/config.lua`:

```lua
BALL_MAX_SPEED = 550, -- Píxeles por segundo: magnitud total de vx/vy.
MAX_BALLS = 90,       -- Máximo de pelotas activas por MULTIBALL.
```

`Ball.limitSpeed(velocity, config)`, en `src/ball.lua`, calcula
`sqrt(vx * vx + vy * vy)`. Cuando supera el máximo, escala ambos ejes
proporcionalmente para conservar la dirección. No modifica las velocidades
permitidas. Maneja cero, NaN, infinito y entradas finitas extremas sin propagar
valores inválidos a las posiciones; un vector inválido se detiene.

Se aplica en la creación (incluidas velocidades iniciales excesivas por nivel),
la clonación, MULTIBALL y cada rebote. También se comprueba antes de integrar el
movimiento con `dt`, la salida de portales, el escudo y el lanzamiento magnético.
Los sistemas futuros deben llamar al mismo limitador después de modificar `Velocity`.
La comprobación previa al movimiento sirve
como respaldo para otros sistemas. Un máximo no positivo o no finito detiene
la pelota de forma segura; configura un número positivo para jugar.

MULTIBALL cuenta los espacios disponibles una vez por activación. Al llegar a 90
no crea más entidades; con 81 añade solamente nueve. El HUD lee `MAX_BALLS`.
Colisiones obtiene una instantánea de pelotas, paddles, bloques y obstáculos por actualización,
en lugar de consultar y ordenar los bloques por cada pelota. Comprueba que un
bloque siga existiendo antes de procesarlo, evitando contactos y poderes duplicados.
Se mantienen los rebotes de paredes/paddle. Para bloques y obstáculos se añadió
un barrido AABB con movimiento relativo, descrito a continuación.

## Fase 2: bloques especiales y obstáculos

| Tipo | Apariencia | Comportamiento |
|---|---|---|
| Normal | Colores por fila | Un impacto; comportamiento anterior. |
| Resistente (B1) | Morado, etiqueta R3/R2/R1 | Salud configurable de 2 a 4; se oscurece y cambia la etiqueta con cada daño. |
| Explosivo (B2) | Naranja, asterisco | Daña los cuatro vecinos ortogonales de cuadrícula y puede activar otros explosivos. |
| Móvil (B3) | Cian, símbolo <> | Trayectoria horizontal, vertical, oscilatoria o compartida por un grupo. |
| Fantasma (B4) | Azul claro, G | Alterna entre sólido e intangible; transparencia y pulso de aviso. |
| Blindado (B5) | Gris con borde claro, A | Rebota pelotas normales sin recibir daño; acepta fuego, láser o explosiones según configuración. |
| Irrompible (U) | Metal oscuro, borde reforzado, [=] | Sin salud; inmune a todos los ataques, sin puntos/poderes y excluido de la victoria. |
| Obstáculo móvil (M3) | Barra oscura con borde cian | Indestructible, refleja pelotas y no cuenta para completar el nivel. |

Los resistentes registran **un daño por contacto continuo de cada pelota**. El
registro se libera al separarse; otra pelota puede causar un impacto independiente.
La destrucción retira todos los componentes inmediatamente y sortea un poder una
sola vez, incluso si llegan 90 pelotas durante la misma actualización.

Las explosiones usan una **cola iterativa**, sin llamadas recursivas. Cada bomba
se retira antes de encolar su único evento. Cada evento consulta las cuatro celdas
vecinas de `GridPosition`, nunca diagonales ni una segunda celda; se procesa una
sola vez por fuente. Explosiones distintas sí pueden dañar el mismo resistente.
Los irrompibles, obstáculos y fantasmas intangibles no reciben daño.
Partículas en cruz muestran el alcance y desaparecen en 0,45 segundos.

Las trayectorias usan senos y tiempo acumulado con `dt`, actualizando `Position`
mediante `Velocity` y el integrador existente. Los grupos comparten patrón, fase
y amplitudes efectivas para conservar su formación. Las amplitudes se reducen si
es necesario para mantener el movimiento dentro de la pantalla, debajo del HUD
y al menos 85 píxeles sobre el paddle. La rapidez de estas trayectorias se limita
a 180 px/s; las pelotas siguen limitadas a 550 px/s al rebotar contra ellas.

Los fantasmas permanecen sólidos 3 segundos e intangibles 2 segundos por defecto,
con aviso durante los últimos 0,5 segundos de cada estado. Si alguna pelota ocupa
el bloque cuando debe reaparecer, permanece intangible hasta que salgan **todas**.
El ciclo sigue siendo determinista. Perder una vida conserva salud, bloques
destruidos y tiempos de movimiento/fantasmas; reiniciar el nivel los restaura.

### Blindados y niveles completables

Los niveles 7, 9 y 10 incluyen blindados. `level_rules.lua` rechaza un
mapa si algún blindado no tiene una bomba ortogonal adyacente y eficaz ni una fuente
renovable garantizada de un poder al que sea vulnerable (`fireball` o `laser`).
Los mapas actuales con blindados suministran fuego renovable garantizado.
Una probabilidad aleatoria de conseguir el poder no basta para validar un mapa.

`Damage.hit(game, id, amount, source)` acepta las fuentes configuradas `explosion`,
`fireball` y `laser` para blindados. Los poderes y proyectiles utilizan este mismo
sistema de daño. Las pelotas normales nunca dañan blindados.

### Configuración y colisiones

`BRICK_DEFAULTS`, `BRICK_TYPE_COLORS`, `BALL_DAMAGE`, `KINEMATIC_MAX_SPEED`,
`KINEMATIC_PADDLE_CLEARANCE` y los límites de explosiones están en `src/config.lua`.
Cada prototipo de `src/levels/definition.lua` puede especificar salud,
daño, ciclo/desfase fantasma y trayectoria; un nivel puede sobrescribirlo.
El alcance explosivo es siempre una celda ortogonal, sin parámetro de radio.

Hay un máximo de **256 bloques por nivel**, **256 eventos de explosión procesados
por actualización** y **192 partículas de explosión simultáneas**. Al reducir el
presupuesto de eventos, la cola conserva el trabajo para la siguiente actualización.
No se descuenta una vida mientras queda daño pendiente por resolver. Los efectos
se limpian también en las pantallas finales y al cargar o reiniciar un nivel.
No se crean fuentes, texturas ni otros recursos gráficos dentro de cada frame.

El barrido de bloques y obstáculos considera el desplazamiento relativo de ambos
rectángulos y selecciona el primer contacto, incluso si al finalizar el frame ya
no se solapan. Se separa la pelota del objetivo para impedir atrapamientos. Los
obstáculos móviles reflejan la velocidad relativa; después se aplica el límite
global. Se resuelve un contacto **que produce rebote** por pelota y actualización, dejando
la pelota en el punto de contacto sin integrar el resto de ese segmento. No es
un solucionador general de múltiples rebotes por tiempo de impacto. El fuego
barre todos los bloques atravesables hasta ese contacto; el láser resuelve su
primer objetivo y desaparece. El paddle conserva su cálculo direccional anterior
y añade un barrido de respaldo para impedir atravesarlo entre frames.
La prioridad de cierre ECS se mantiene.

## Fase 3: poderes y portales

Todos los objetos caídos muestran color, símbolo y nombre. El HUD añade una fila
de temporizadores y munición, por encima de los bloques, con fuentes reutilizadas.

| Poder | Símbolo | Efecto | Disponible desde |
|---|---|---|---|
| MULTIBALL x3 | x3 amarillo | Dos copias por pelota, dispersión de ±25°, máximo 90. | Nivel 1 |
| Paddle gigante | <> verde | Ancho ×1,5 durante 15 s; conserva centro y respeta los bordes. | Nivel 1 |
| Escudo inferior | SH azul | Barrera a 33 px del fondo; 20 s o 3 impactos. | Nivel 2 |
| Pelota de fuego | F naranja | 10 s, atraviesa bloques vulnerables y causa 1 daño por contacto. | Nivel 3 |
| Cañón láser | II rosa | 20 disparos dobles, intervalo de 0,25 s; proyectiles a 720 px/s. | Nivel 4 |
| Paddle magnético | U violeta | Atrapa como máximo una pelota durante el efecto de 15 s. | Nivel 5 |
| Vida extra | +1 blanco | Añade una vida hasta el máximo de 5. | Nivel 6 |

La pelota de fuego afecta a todas las pelotas, incluidas las que crea MULTIBALL
o la fábrica mientras dure el efecto. Un resistente recibe como máximo un daño
por contacto continuo de cada pelota. Los fantasmas intangibles se atraviesan sin
daño; los obstáculos y blindados inmunes al fuego siguen produciendo rebotes.
Las pelotas naranjas tienen borde claro para distinguirlas entre muchos objetos.

Cada unidad de munición dispara **dos proyectiles**, uno por cañón. Espacio es
un disparo por pulsación y no consume munición si sigue el intervalo o no caben
ambos proyectiles. Recoger láser repone 20 cargas, sin acumularlas. Los proyectiles
se eliminan al golpear un objetivo sólido o salir de pantalla, con un máximo de 40.
La interfaz `Health` + `Damageable = {sources = {laser = true}, enabled = true}`
permite dañar el punto débil de los jefes y destruir proyectiles enemigos vulnerables.

El imán conserva la dirección de rebote que corresponde al punto de impacto.
La pelota atrapada sigue al paddle, cuenta como activa y se suelta automáticamente
al terminar el efecto. **Lanzar tiene prioridad sobre disparar:** esa pulsación de
Espacio no consume munición. MULTIBALL conserva una sola captura y crea copias
que salen en movimiento. Al encogerse el paddle se reajusta el punto de captura.

Los poderes distintos pueden combinarse. Recoger de nuevo gigante, fuego o imán
renueva su duración sin acumular tamaño ni tiempo; el escudo renueva duración y
tres impactos. Al perder **la última pelota**, si quedan vidas se conservan los
efectos, tiempos, munición e impactos restantes. GAME OVER sí limpia los poderes;
cargar o reiniciar un nivel también los reinicia. Menús, pausa, entrada de nivel
y pantallas de finalización congelan los temporizadores de poderes.

### Conservación de poderes entre vidas

La pérdida de vida usa `Game:respawnRound()`. Se conserva el ID del paddle y sus
componentes `TimedEffect`, `PaddlePower` y `Collider`; no se vuelve a activar ningún
poder. Un gigante con 8 s conserva su ancho y esos 8 s, un láser con 12 disparos
conserva exactamente 12 y un escudo con dos impactos conserva la misma entidad y
sus dos impactos. Se mantiene también el intervalo de disparo ya iniciado y los
relojes del suministro de poderes. Los usos consumidos no se reponen.

`Paddle.resetPosition` centra usando el ancho vigente, detiene el desplazamiento y
actualiza `PreviousPosition` para que el recentrado no cuente como un barrido.
Se conserva la invulnerabilidad de 2 s y la espera del jefe existentes. El sprint
sigue funcionando al volver a mover el paddle. Las pelotas anteriores se eliminan
del ECS y se crea **una sola pelota**, aunque hubiera 90. `Ball.spawn` ya hereda
el fuego vigente del paddle; no se restaura MULTIBALL ni se crean objetos recogidos.

La referencia a una pelota magnética perdida se libera. El imán conserva su tiempo
y puede capturar la pelota nueva en su siguiente impacto; Espacio mantiene la
prioridad de lanzamiento sobre láser. Los objetos que aún caen y los proyectiles
siguen su ciclo normal; la invulnerabilidad impide daños inmediatos de los ataques
que sigan tocando el paddle. No se crean escudos ni efectos duplicados.

La reposición entre vidas sigue siendo **inmediata**, dentro del frame de pérdida:
no añade cuenta regresiva ni consume `dt` adicional. El tiempo jugado antes de
perder esa vida sí se descuenta una vez; después se conserva el restante. Pausar
con ESC/P congela los poderes y continuar reanuda sus temporizadores. Un efecto
que ya expiró en el frame de la caída no se recupera.

| Acción | Poderes y entidades | Puntos y vidas |
|---|---|---|
| Perder una vida y seguir jugando | Mismo paddle/escudo, tiempos y usos restantes; una pelota nueva | Una vida menos, puntos conservados, combo reiniciado |
| Reiniciar el nivel | Mundo y poderes limpios, bloques/jefe restaurados | Tres vidas y puntuación que había al entrar al nivel |
| Nueva campaña | Mundo y poderes limpios desde el nivel 1 | Tres vidas, puntuación y combo de partida a cero |
| Pasar de nivel | Limpieza habitual y nuevo mapa | Total conservado y premio de vida habitual |
| GAME OVER | Limpieza de poderes, sin pelota de reemplazo | Resultado de derrota y récords conservados |

La inicialización limpia sigue usando `Game:resetRound()` desde el cargador del
nivel. Los récords, estrellas y desbloqueos persistentes nunca se borran al empezar
otra partida. Este ajuste modifica `src/game.lua`, `src/paddle.lua`,
`src/ecs/systems/life_system.lua`, `tests/main.lua`, `tests/game_spec.lua`,
`tests/powers_portals_spec.lua`, `tests/boss_spec.lua`, `tests/boss_balance_spec.lua`
y este README, y añade `tests/life_effects_spec.lua`.

### Distribución y configuración

`src/config.lua` centraliza duraciones, escala, daños, intervalo, velocidad del
láser, munición y límites. `POWERUP_TYPES` define nombres, colores, símbolos y
pesos: MULTIBALL 30, gigante 24, escudo 16, fuego 12, láser 10, imán 12, vida 3.
Un único número aleatorio por bloque decide primero si aparece un objeto y
después su tipo dentro de ese mismo intervalo ponderado. **No hay un 15 % por tipo.**
Se admiten hasta `MAX_FALLING_POWERUPS = 12` objetos caídos simultáneos.
En niveles configurados con jefe, el peso del láser pasa de 10 a 30; se conserva
el 15 % total por destrucción. Los detalles del suministro adicional y del ajuste
de puntos débiles están en la sección de balance de jefes.

`difficulty.guaranteedPowerup = {kind = "fireball", everySeconds = 12}` crea una
oportunidad de recoger fuego cada 12 s en niveles 7–8, y cada 10 s en 9–10. Cae
100 px por encima del paddle en su posición actual. Si los objetos llenan el
límite, sustituye el más antiguo; no depende de destruir otro bloque ni del azar.
El jugador todavía debe recogerlo. El temporizador se conserva entre vidas y se
reinicia al cargar o reiniciar un nivel.

### Portales

Cada par crea dos entidades `Portal` enlazadas por IDs. El contacto usa un barrido
circular del centro de la pelota, conservando rapidez y aplicando
`rotationDegrees`; el sentido inverso aplica la rotación opuesta. Cada pelota
tiene su propio `cooldown` (0,4 s en los mapas), también con 90 pelotas simultáneas.
Las capturas magnéticas no se teletransportan.

La salida se coloca fuera del portal y busca espacio libre sin entrar en bloques,
fantasmas, obstáculos, otros portales, HUD, paredes o paddle. Si no hay espacio
seguro se cancela ese traslado y se conserva la trayectoria actual. Se comprueba
el límite global de 550 px/s y se reinician los contactos anteriores al trasladarse.
Pulsos de entrada y salida duran 0,35 s, con un máximo de 32; omitir un pulso al
alcanzar el límite no impide teletransportar. Se permiten hasta cuatro pares por nivel.
Las salidas de niveles 7 y 9 se situaron en sus corredores centrales para hacerlas
visibles y utilizables. Portales y escudos no cuentan para completar un nivel.

## Fase 4: puntuación, combos y estrellas

### Puntos y continuidad de la partida

| Destrucción | Puntos base |
|---|---:|
| Normal | 100 |
| Resistente | 150 |
| Explosivo | 200 |
| Móvil, incluidas sus variantes | 200 |
| Fantasma | 250 |
| Blindado | 300 |

Los valores están en `SCORE_VALUES` de `src/config.lua`. Cada bloque recibe un
componente `ScoreValue` con puntos y una marca de recompensa. Se puntúa al
destruirlo, antes de retirarlo del ECS y de completar el nivel; un impacto parcial
no da puntos. Pelota, fuego, láser y explosión comparten ese punto de destrucción.
Ni contactos repetidos, ni 90 pelotas, ni cadenas de explosiones pueden premiar
dos veces la misma entidad. Quitar entidades al limpiar/reiniciar no da puntos.

La puntuación total se conserva entre niveles y al perder una vida. El subtotal
del nivel empieza en cero al entrar. Una campaña nueva, incluso si empieza en
el máximo desbloqueado, comienza con cero puntos. **Reintentar un nivel restaura
el total que había al entrar en él**: conserva los puntos de niveles anteriores y
descarta los del intento fallido para impedir acumularlos repitiendo bloques.
Los récords obtenidos durante ese intento se conservan.

`BOSS_SCORE_VALUES` concede 5000 por Guardián mecánico y 15000 por Núcleo del
caos, una sola vez al derrotarlos, con el multiplicador vigente. Sus recompensas
se incluyen en los umbrales de los niveles 5 y 10. Los protectores generados y los
proyectiles enemigos no conceden puntos, combo ni poderes; los bloques originales
del mapa conservan sus premios. `SCORE_MAX = 2147483647` limita los acumuladores al
rango entero del guardado. Se puede reducir; los récords históricos no se rebajan.

### Combos

Cada destrucción inicia o amplía una cadena. Si pasan **3 segundos de simulación**
sin destruir otro bloque, el combo termina; un impacto que no destruye no renueva
la ventana. Las destrucciones simultáneas cuentan como contactos independientes
solo si pertenecen a entidades distintas. El multiplicador se aplica al bloque
que acaba de aumentar la cadena:

| Bloques de la cadena | Multiplicador |
|---|---:|
| 1–3 | x1 |
| 4–6 | x2 |
| 7–9 | x3 |
| 10–12 | x4 |
| 13 en adelante | x5 |

`COMBO_WINDOW`, `COMBO_STEP` y `COMBO_MAX_MULTIPLIER` permiten ajustar estas reglas
en configuración; el máximo admitido es x5. El HUD muestra cadena, multiplicador
y barra de tiempo. Desde x3, un pulso de tamaño y brillo de 0,45 s celebra los
combos grandes, sin partículas adicionales ni recursos creados durante el frame.
`bestCombo` guarda la **cantidad de bloques** de la mayor cadena, no el multiplicador.

Perder una vida, reintentar o cambiar de nivel reinicia el combo; los puntos
permanecen según las reglas anteriores. Los menús, la pausa, la entrada y las pantallas finales congelan
sus temporizadores, igual que los demás efectos del juego.

### Estrellas por nivel

Completar concede **1 estrella**. Alcanzar `twoScore` concede **2**. Alcanzar
`threeScore` y conservar al menos `minLives` concede **3**. Se usa exclusivamente
la puntuación del intento actual en ese nivel, incluido el último bloque; no se
usan puntos de niveles anteriores ni récords históricos. Las vidas se evalúan
**antes de sumar la vida de recompensa**, para que esta no mejore artificialmente
la evaluación. Sin completar el nivel no se conceden estrellas.

Cada `src/levels/levelNN.lua` declara `stars = {twoScore, threeScore, minLives}`:

| Nivel | Puntos base disponibles | Dos estrellas | Tres estrellas | Vidas mínimas para tres |
|---|---:|---:|---:|---:|
| 1 | 7200 | 8500 | 12000 | 3 |
| 2 | 6300 | 7500 | 11000 | 3 |
| 3 | 5800 | 7000 | 10500 | 3 |
| 4 | 4300 | 5200 | 8000 | 3 |
| 5 | 9900 | 12000 | 18000 | 3 |
| 6 | 13050 | 17000 | 26000 | 3 |
| 7 | 6400 | 8200 | 12500 | 3 |
| 8 | 5500 | 9000 | 14000 | 3 |
| 9 | 11200 | 14500 | 23000 | 3 |
| 10 | 23400 | 28000 | 40000 | 3 |

Los objetivos requieren combos moderados y no exigen conseguir vidas extra.
`score_rules.lua` calcula `baseScore` y una cota superior `maxScore` con los bloques
reales, la recompensa del jefe cuando existe y una cadena completa. Rechaza umbrales fuera de esa cota o requisitos de
vidas superiores a las vidas iniciales. Si cambias puntos o multiplicadores,
revisa también los umbrales. Las pruebas alcanzan tres estrellas en los diez mapas
con daño válido; no sustituyen una evaluación humana de dificultad.

Las pantallas LEVEL COMPLETE y YOU WIN! muestran puntos del nivel, total y
estrellas del intento junto al mejor resultado guardado. Repetir con un resultado
inferior nunca reduce las estrellas ni la puntuación récord.

## Fase 5: jefes

Ambos jefes son entidades ECS sólidas con salud, comportamiento, un punto débil
en la cara inferior y un núcleo azul superior. El indicador **GOLPEA** verde acepta
pelota normal, fuego y láser; **CERRADO** gris rechaza daño en ambas zonas.
El resto del cuerpo protege al jefe. Las explosiones solo afectan vecinos de
cuadrícula, no al jefe ni a sus protectores generados fuera de ella. El fuego rebota
en el cuerpo del jefe, conservando su capacidad de atravesar bloques vulnerables.
Ningún combate exige conseguir un poder aleatorio para ganar.

### Guardián mecánico — nivel 5

- **10 HP**, recompensa base **5000**; puntos débiles abiertos después de la entrada.
- Entrada de 1,2 s. Anuncia **MOVIMIENTO** y dibuja el destino durante 0,75 s.
- Alterna posiciones horizontales a 90 px/s, con descansos de 2 s.
- Genera pares de protectores resistentes de 2 HP en espacios libres, dejando
  un hueco central hacia el punto débil. No dispara proyectiles.
- Derrotarlo termina el nivel; vaciar el mapa sin derrotarlo no lo completa.

### Núcleo del caos — nivel 10

Tiene **23 HP**, repartidos en tres presupuestos de **8, 7 y 8 HP**. Un impacto no puede
saltar fases. Al llegar a 15 u 8 HP, anuncia el nuevo patrón durante 1,2 s y limpia
los proyectiles enemigos; la barra muestra salud total, número y nombre de fase.

| Fase | Comportamiento |
|---|---|
| Defensa | Patrulla a 35 px/s y genera protectores. Punto débil cerrado 2 s, aviso de apertura 0,75 s y apertura 2,5 s, en un ciclo predecible. |
| Ataque | Patrulla a 100 px/s, punto débil abierto. Dispara cada 2,4 s a 210 px/s tras avisar 0,75 s. |
| Caos | Punto débil abierto. Anuncia un destino y se teletransporta cada 4 s; genera fantasmas. Abanico de tres proyectiles a 240 px/s cada 1,6 s, con aviso de 0,75 s. |

La línea de aviso indica la trayectoria central hacia la posición del paddle al
comenzar el aviso. Los proyectiles no persiguen al jugador; su dirección queda fija
al disparar. El objetivo horizontal está limitado para mantener trayectorias
descendentes. Los proyectiles **rojos con borde claro** se destruyen con láser;
los **ámbar con borde oscuro** deben esquivarse. El escudo inferior sigue protegiendo
solo contra la pérdida de pelotas, no contra ataques dirigidos al paddle.

Un destino ocupado por pelota, bloque, obstáculo o portal retrasa el teletransporte.
El cambio de posición no barre ni golpea todo el espacio intermedio. Se cancela el
disparo preparado y se concede una espera después de aparecer, evitando un ataque
instantáneo desde la nueva ubicación. Al morir, el jefe otorga **15000 puntos base**,
se desvanece con anillos de derrota y aparece **NÚCLEO DEL CAOS DESACTIVADO** junto
a YOU WIN!, puntos y estrellas. No se necesita eliminar los bloques restantes.

### Límites, daño y reinicios

- Los contactos continuos no repiten daño; además, cada jefe admite un impacto
  cada **0,18 s** como máximo, incluso con 90 pelotas o dos láseres simultáneos.
  Pelotas y láseres usan barridos relativos y evalúan el punto débil en el instante
  de impacto. Se conserva el máximo global de 550 px/s para las pelotas.
- Máximo **6 protectores generados**, vida útil **10 s** y máximo **18 proyectiles
  enemigos**, vida útil **6 s**. Al llenarse el cupo se omite la oleada, sin acumularla.
  Los protectores se crean en espacios libres y respetan el límite global de bloques.
- Los protectores generados no dan puntos ni combo para impedir puntuación infinita.
  Destruirlos permite un sorteo de poder con las reglas del nivel; caducarlos o
  limpiar una fase no genera poderes ni cuenta como destrucción puntuable.
- Un golpe enemigo contra el paddle descuenta una vida y repone la ronda entera.
  Conserva bloques destruidos, salud/fase del jefe, puntos y poderes; reinicia el combo.
  El paddle reaparece con **2 s de invulnerabilidad** y el jefe espera antes de atacar.
  Varias pelotas caídas o varios proyectiles no multiplican la pérdida de esa ronda.
- Con cero vidas se muestra GAME OVER. R reconstruye el nivel y el jefe desde el
  principio; M abandona el intento. Victoria y recompensa se deciden una sola vez,
  antes de evaluar pérdidas de vida en ese frame.
- La vida extra por completar, los récords y las estrellas se guardan mediante
  los sistemas existentes; no se serializa una pelea a medio terminar.

Configura velocidades, avisos, intervalos, invulnerabilidad y cupos en
`src/config.lua` (`BOSS_*`, `GUARDIAN_*`, `CORE_*`, `ENEMY_PROJECTILE_*`,
`MAX_ENEMY_PROJECTILES`, `PADDLE_INVULNERABILITY_SECONDS`). Salud, rectángulo base del
punto débil, amplitud horizontal, fases y destinos están en `src/levels/level05.lua`
y `level10.lua`. Los umbrales de estrellas de esos dos mapas incluyen ahora la
recompensa del jefe; el progreso y récords anteriores siguen siendo compatibles.

### Ajuste de balance: puntos débiles y láser

`BOSS_WEAK_POINT_SIZE_MULTIPLIER = 1.6` en `src/config.lua` aumenta ancho y alto
del punto débil un **60 %**, manteniendo su proporción y centro horizontal:

| Jefe | Tamaño base | Tamaño efectivo | Posición local efectiva |
|---|---|---|---|
| Guardián mecánico | 56 × 20 px | **89,6 × 32 px** | x=35,2; y=28 |
| Núcleo del caos | 60 × 22 px | **96 × 35,2 px** | x=32; y=34,8 |

El rectángulo sigue apoyado en el borde inferior del jefe para recibir rebotes
normales. La escala se limita uniformemente al tamaño del cuerpo si se configura
un multiplicador excesivo; no sobresale ni pierde su proporción. `boss_rules.lua`
calcula la geometría al crear la entidad y `BossBehavior.weakPoint` proporciona
**la misma zona vulnerable al sistema de daño y al dibujo**. El `Collider` del
cuerpo conserva 160×60 o 160×70 px. Los datos base de cada nivel no se modifican
ni se vuelve a multiplicar el tamaño al reiniciar. La salud ahora es 10/23;
daño, protecciones, ventanas de apertura, movimiento y ataques se conservan.
El nuevo núcleo superior usa `BossBehavior.topWeakPoint` y la misma protección.

`BOSS_LASER_DROP_WEIGHT_MULTIPLIER = 3.0` multiplica únicamente el peso del láser
en el sorteo existente. Se aplica por la presencia de `level.boss`, sin comprobar
el número del nivel. No muta `POWERUP_TYPES`, no elimina otros poderes y conserva
un único sorteo por destrucción. El peso base 10 se convierte en 30; al normalizar
todos los pesos, la probabilidad final del láser no es exactamente el triple:

| Nivel | Láser entre los poderes: antes → después | Láser por bloque destruido, con cupo libre |
|---|---|---|
| 5 | 9,62 % → **24,19 %** | **3,63 %**, dentro del 15 % total |
| 10 | 9,35 % → **23,62 %** | **3,54 %**, dentro del 15 % total |

Los ocho niveles sin jefe conservan sus distribuciones anteriores. Los protectores
resistentes y fantasma generados por jefes también pueden soltar poderes al ser
destruidos, incluido láser con peso aumentado. Un golpe no letal, un contacto
duplicado o la caducidad del protector no genera un objeto.

Al agotarse los bloques originales, el suministro aleatorio podría desaparecer.
Por ello, durante el combate se evalúa una ayuda controlada:

```lua
BOSS_LASER_SUPPLY_INTERVAL = 20,
BOSS_LASER_SUPPLY_CHANCE = 0.5,
BOSS_LASER_SUPPLY_BLOCK_THRESHOLD = 3,
```

Cada 20 segundos de combate activo, si quedan como máximo tres bloques originales
con posibilidad de soltar poderes, se intenta crear un láser con **50 % de
probabilidad**. Los protectores renovables no cuentan para ese umbral. Solo se
intenta si láser está habilitado en el nivel, no queda munición, no hay un láser
cayendo y el cupo de 12 objetos tiene espacio. Aparece 100 px por encima del paddle
y debe recogerse. No reemplaza otros objetos, no garantiza éxito por intervalo ni
acumula intentos tras un `dt` largo. El fuego garantizado del nivel 10 se conserva.

El reloj vive como dato en `PaddlePower`, se actualiza con `dt`, se conserva entre
vidas y se reinicia al cargar/reiniciar nivel. Se congela en pausa y durante la presentación
del jefe; no se generan ayudas en menús, victoria, derrota ni tras solicitar el
cierre ECS. Las consultas adicionales de objetos/bloques solo se hacen al vencer
el intervalo. Los jefes siguen siendo derrotables con pelotas normales.

Archivos de este ajuste: `src/config.lua`, `src/boss_rules.lua`, `src/bosses.lua`,
`src/bricks.lua`, `src/powerups.lua`, `src/ecs/components.lua`,
`src/ecs/systems/damage_system.lua`, `src/ecs/systems/power_effect_system.lua`,
`tests/main.lua`, `tests/boss_spec.lua` y este README; creado
`tests/boss_balance_spec.lua`. Se reutilizan los sistemas existentes sin cambiar
los barridos de colisión, el renderizador del jefe, sus patrones ni el sprint.

## Fase 6: interfaz y experiencia de usuario

### Menú, selector y opciones

El menú principal ofrece **Jugar**, **Seleccionar nivel**, **Opciones**, **ENCICLOPEDIA** y **Salir**.
Jugar comienza una campaña desde el primer nivel. El selector presenta dos filas
de cinco tarjetas con número, nombre, bloqueo/desbloqueo, mejores estrellas y
récord por nivel. Se puede enfocar una tarjeta bloqueada para leerla, pero Enter
no inicia el nivel y explica cuál hay que completar antes. La restricción también
se valida en `startCampaign`, no solo en el dibujo.

Repetir un nivel desbloqueado empieza con tres vidas y cero puntos; conserva
récords, estrellas y desbloqueos. El atajo C sigue disponible para el máximo nivel
desbloqueado. Las tarjetas consultan directamente el progreso existente, sin
duplicar datos ni cambiar el formato del guardado.

Opciones edita volumen general, música, efectos y silencio. Los volúmenes están
limitados a 0–100 %, en pasos configurables de 10 %. Música y efectos responden
al instante; el volumen general multiplica ambos canales. Un fallo de escritura
muestra un aviso y conserva los cambios
en memoria para reintentarlos en el siguiente punto de guardado.

### Pausa y estados

ESC o P pausa tanto la partida como la entrada de nivel. El panel ofrece:

- **Continuar:** conserva las mismas entidades, posiciones, vidas, puntos y tiempos.
- **Reiniciar nivel:** reconstruye el nivel y el jefe, con tres vidas, sin efectos,
  y recupera la puntuación que había al entrar en ese nivel. Los récords ya obtenidos
  y el progreso persistente permanecen.
- **Volver al menú:** guarda récords y abandona el intento; no deja una partida
  suspendida para continuar después desde el menú.

Durante la pausa no se ejecutan movimientos, colisiones, daño, portales, explosiones,
recogidas, disparos, suministro de poderes ni temporizadores de juego o de entrada.
Esto incluye ciclos fantasma, jefes, invulnerabilidad, combo, munición y pelota atrapada.
La pérdida de foco pausa y exige una acción explícita para continuar. La repetición
de teclas no alterna pausa/reanudación ni activa dos reinicios o salidas.

`state_system.lua` es el único escritor del estado de juego y rechaza cambios
incompatibles. `interface_system.lua` procesa navegación y tiempo de presentación;
el coordinador retorna antes de la simulación cuando corresponde.

| Estado | Comportamiento |
|---|---|
| `menu` | Menú principal; mundo detenido. |
| `level_select` | Diez niveles, bloqueo y récords. |
| `options` | Preferencias persistentes. |
| `encyclopedia` | Guía de cuatro categorías; mundo detenido y progreso conservado. |
| `level_intro` | Presentación del nivel/jefe y cuenta 3, 2, 1; entidades detenidas. |
| `playing` | Simulación ECS habitual. |
| `paused` | Mundo y temporizadores congelados; recuerda si se pausó partida o entrada. |
| `level_complete` | Resultado, estrellas y transición de 2 s al siguiente nivel. |
| `game_over` | Derrota, puntos y acciones para reintentar o volver. |
| `campaign_complete` | Victoria especial, estrellas y acciones para nueva campaña o menú. |

Al acabar una transición se entra en un solo estado y se retorna: un `dt` grande
no consume la cuenta regresiva del mapa recién cargado ni mueve sus pelotas. La victoria
conserva prioridad sobre una pérdida de vida en ese frame. P no convierte una derrota
o victoria en pausa. M/ESC puede cancelar la transición al siguiente nivel, manteniendo
el desbloqueo que ya se guardó.

### HUD y transiciones

La franja superior existente organiza puntos, récord, vidas, nivel, combo y su
ventana, bloques restantes y pelotas activas. Los poderes muestran nombre y segundos;
el escudo añade impactos restantes, el láser munición y el imán la indicación de
lanzamiento. En los niveles 5 y 10 también muestra salud, fase y nombre del jefe.
La geometría de los mapas y las colisiones no cambia; los bloques siguen desde y=94.

Los menús y paneles entran con interpolación sencilla. La entrada de nivel anuncia
su nombre y, cuando corresponde, **JEFE EN CAMINO** antes de la cuenta regresiva.
Cada número tiene un pulso de escala. LEVEL COMPLETE, GAME OVER y YOU WIN! animan
su panel; las estrellas se revelan secuencialmente. Continúan la aparición y avisos
del jefe durante el combate, así como su animación de derrota y título final.
Estas animaciones son de presentación: nunca otorgan premios ni interrumpen una
partida activa por sí solas.

En `src/config.lua` se ajustan `LEVEL_ENTRY_SECONDS`, `LEVEL_COUNTDOWN_SECONDS`,
`LEVEL_TRANSITION_SECONDS`, `UI_ANIMATION_SECONDS`, `UI_STAR_INTERVAL`,
`UI_NOTICE_SECONDS` y `OPTION_VOLUME_STEP`. Las fuentes se crean una vez por juego;
la geometría de estrellas se reutiliza. No se cargan imágenes, sonidos ni recursos
gráficos durante cada frame.

## Fase 7: efectos visuales, audio y pulido

### Partículas y legibilidad

`feedback.lua` recibe eventos visuales/sonoros de acciones ya resueltas: destrucción
de bloques, daño resistente, rebote, poder recogido, portal, daño/ataque de jefe,
pérdida de vida y resultado. No decide daño, puntos ni victoria; tampoco consume
el generador aleatorio utilizado por los poderes. Los contactos rechazados y las
destrucciones repetidas no producen nuevos eventos.

El componente `Particle` solo almacena duración, tamaño, transparencia, gravedad
y si pertenece a una estela. `particle_system.lua` lo mueve con `dt`, desvanece y
elimina; reutiliza `Position`, `Velocity`, `Renderable` y el sistema de movimiento.
Estas entidades **no tienen Collider**, salud ni valor de puntuación. La cola de
feedback es independiente de la cola que resuelve el daño de las explosiones.

- Los bloques emiten fragmentos de su color; paredes y paddle, chispas breves.
- Las pelotas dejan estelas azules o naranjas durante fuego. Un núcleo claro
  mantiene su contraste incluso con 90 pelotas. Las capturadas no dejan estela.
- Recoger poderes, cruzar portales y golpear/derrotar jefes produce ráfagas breves.
  Se conservan los anillos de portal y avisos de jefes; las explosiones ahora se dibujan en cruz.
- Completar un nivel o la campaña produce una celebración con gravedad; tiene
  prioridad sobre efectos antiguos cuando se alcanza el cupo.

Las nuevas partículas se dibujan **detrás de las entidades**, recortadas al campo
desde y=94 y antes de la ayuda inferior. No cubren el HUD ni cambian la geometría
de colisiones. La pausa congela sus posiciones y vidas; reiniciar, perder una vida
o volver al menú limpia las anteriores. Tras una derrota/victoria las restantes
terminan su animación y se eliminan, sin seguir simulando el combate.

| Límite configurable en `src/config.lua` | Valor |
|---|---:|
| Eventos ordinarios por lote: `MAX_FEEDBACK_EVENTS` | 64 |
| Nuevas partículas simultáneas: `MAX_FEEDBACK_PARTICLES` | 256 |
| Estelas dentro de ese cupo: `MAX_TRAIL_PARTICLES` | 128 |
| Partículas de eventos emitidas por lote: `FEEDBACK_EMIT_BUDGET` | 80 |
| Pelotas muestreadas por turno: `TRAILS_PER_TICK` | 32 |
| Intervalo y vida de estela: `TRAIL_INTERVAL`, `TRAIL_STYLE.seconds` | 0,04 / 0,14 s |

Hay un espacio adicional reservado para el resultado/pérdida de vida; victoria
y GAME OVER tienen prioridad para evitar sonidos contradictorios. Las estelas
rotan entre las pelotas activas, sin acumular emisiones atrasadas. Los cupos
anteriores de explosiones (192) y pulsos de portal (32) permanecen: el máximo
combinado es **480 entidades visuales**. Colores, tamaños, velocidades, duración
y cantidad de cada ráfaga están en `src/feedback_styles.lua`.

### Audio original, canales y recursos

`src/audio_catalog.lua` define rutas relativas, ganancias, prioridades e intervalos.
Se incluyen efectos para paddle, pared, bloque, resistente, explosión, poder,
láser, vida perdida, nivel completado, GAME OVER, victoria, ataque/daño/derrota de
jefe, portal y navegación. Música de menú, niveles y jefes cambia con el estado,
con fundidos de **0,35 s**; los resultados dejan lugar a su melodía breve.

Los **19 WAV originales** se sintetizan con osciladores, ruido determinista y
secuencias de notas propias. Son PCM mono, 16 bits, 22050 Hz, aproximadamente
1,36 MB en total. No contienen música comercial ni samples descargados. Su
procedencia y licencia CC0 están en [assets/audio/LICENSE.md](assets/audio/LICENSE.md).
El generador usa solo la biblioteca estándar de Python y produce archivos
idénticos al repetirlo:

```powershell
python tools/generate_audio.py
```

`audio_system.lua` precarga los efectos como fuentes estáticas y la música como
streams una vez por juego. Hay **dos voces por efecto** (32 fuentes reutilizadas),
tres streams y un máximo de **ocho efectos sonando simultáneamente**. Durante un
fundido pueden sonar dos pistas. `AUDIO_POOL_PER_EFFECT`, `MAX_SFX_VOICES`,
`AUDIO_EVENT_INTERVAL` y `MUSIC_FADE_SECONDS` controlan estos valores. Las ráfagas
de 90 contactos se agrupan por tipo/intervalo; los sonidos descartados no quedan
en espera. Perder vida y los resultados desplazan los efectos menos importantes.
No se crean fuentes de audio, fuentes tipográficas, imágenes ni Canvas por frame.

Opciones aplica `general × música` y `general × efectos`, además de la ganancia de
cada recurso. Silencio y volumen cero detienen los efectos y suspenden la música;
al reactivarlos no se repiten sonidos pendientes. Pausar por teclado o pérdida
de foco suspende música, efectos y fundidos; Continuar conserva la posición de
reproducción. Reiniciar desde pausa descarta los sonidos de la ronda anterior.
Salir, incluido el cierre lateral ECS, detiene el audio inmediatamente.

Las preferencias siguen usando el guardado existente. Si el dispositivo, el módulo
de audio o algún recurso no está disponible, el juego continúa y Opciones muestra
su estado. Los fallos se aíslan por recurso, sin volver a cargarlo cada frame.

### Balance conservado

Se revisaron límites, duraciones y disponibilidad: máximo de 550 px/s y 90 pelotas,
probabilidad base de poderes del 15 % distribuida por pesos, duración de gigante,
fuego, escudo e imán y suministro garantizado contra blindados. No se cambiaron
esos valores, los mapas ni las reglas de combate. Las pruebas de regresión siguen
comprobando completabilidad y premios; falta valorar la dificultad mediante una
campaña manual completa. Los efectos nuevos no alteran el azar, la precisión de
los barridos ni las condiciones de victoria.

## Los diez niveles

| Nivel | Nombre | Diseño manual | Mecánicas |
|---|---|---|---|
| 1 | El comienzo | Cuadrícula original de 72 bloques | Normales; MULTIBALL y paddle gigante. |
| 2 | Resistencia | Cuñas resistentes y abertura superior | Resistencia de 3 impactos; escudo. |
| 3 | Reacción en cadena | Racimos explosivos conectados | Explosiones; pelota de fuego. |
| 4 | En movimiento | Filas desplazadas con corredores | Cuatro patrones móviles y obstáculo horizontal; láser. |
| 5 | Guardián mecánico | Bastión protector con centro abierto | Imán; jefe de 10 HP, dos zonas vulnerables, patrulla y protectores. |
| 6 | Ahora me ves | Grupos fantasma desfasados | Precisión temporal, resistentes e irrompibles. |
| 7 | Otra dimensión | Cámaras y pasillos abiertos | Blindados, resistentes, irrompibles y dos pares de portales; fuego garantizado. |
| 8 | Precisión extrema | Objetivos móviles y pasos estrechos | 14 móviles, fantasmas, resistentes, irrompibles y tres obstáculos. |
| 9 | Caos total | Zonas con cadenas cortas | Todos los tipos especiales, dos obstáculos y dos pares de portales. |
| 10 | Núcleo del caos | Defensas alrededor del núcleo | Todos los poderes; jefe de 23 HP, dos zonas vulnerables, tres fases y teletransporte. |

La rapidez inicial aumenta gradualmente de unos **341 a 419 px/s**. Los colores
de fondo y acento cambian por nivel. Los normales conservan la paleta por filas;
los especiales tienen colores y etiquetas propios.

### Crear o modificar niveles

Cada archivo `src/levels/levelNN.lua` devuelve datos mediante `definition.make`.
El orden de la campaña está en `src/levels/catalog.lua`; Game no contiene casos
especiales por número de nivel. Para agregar otro nivel, crea el archivo y añádelo
al catálogo. Conserva el orden y los IDs existentes para mantener los guardados.

Símbolos del mapa: `N` normal, `R` resistente, `E` explosivo, `M` móvil,
`G` fantasma, `A` blindado y `.` espacio vacío. `V`, `O` y `T` son variantes
móviles vertical, oscilatoria y de grupo. Cada fila tiene 12 celdas.
`definition.lua` aporta geometría, posiciones, prototipos de bloques y condición
de victoria; un nivel puede sobrescribir esos datos antes de devolver su tabla.
`activeVictory` usa `clear_bricks` o `boss_defeated`; ya no se activa el antiguo
fallback provisional de los niveles con jefe.
Las filas se escriben a mano; el cargador únicamente convierte celdas en posiciones.

`LevelManager` valida IDs únicos, dimensiones, símbolos, posiciones dentro del
campo, velocidad, probabilidades, colores y condición de victoria. Devuelve
copias independientes y calcula `bricks`, `initialBallSpeed`, `activePowerups`,
`activeVictory`, `baseScore` y `maxScore`. `level_rules.lua` valida salud, ciclos, trayectorias, grupos,
obstáculos, cobertura de blindados, poderes, suministro garantizado y pares de
portales (IDs, posiciones, rotación y protección); `score_rules.lua` valida puntos y
umbrales de estrellas. `boss_rules.lua` valida salud, fases, rutas, punto débil,
destinos, recompensas, avisos y límites de los combates.

Los valores globales se encuentran en `src/config.lua`: vidas iniciales/máximas,
premio, duración de transición, límites de pelotas, multiplicadores y guardado.
La geometría, velocidad inicial y probabilidad de poderes de la campaña se editan
en las definiciones de niveles. Los antiguos `BRICK_ROWS`/`BRICK_COLS` ya no generan
los mapas manuales; `BALL_START_VX/VY` sirven como valores de fábrica sin nivel.

## Guardado local

`src/progress_store.lua` usa exclusivamente `love.filesystem` y los nombres
relativos **`progress.dat`** y **`progress.bak`**, dentro de la identidad existente
`breakout_engine_base`. No escribe archivos de progreso en el repositorio.

El formato de texto comienza con `BREAKOUT_PROGRESS 1` y admite:

| Dato | Campo |
|---|---|
| Máximo nivel desbloqueado | `maxUnlocked` |
| Récord general y mejor combo | `bestScore`, `bestCombo` |
| Récord y estrellas por ID estable | `level.<id>.bestScore`, `level.<id>.stars` |
| Preferencias de audio editables en Opciones | `settings.masterVolume`, `settings.musicVolume`, `settings.sfxVolume`, `settings.muted` |

El progreso vive en `game.progress`; la puntuación activa, subtotal, combo y
resultado actual viven por separado en `game.run`. Las vidas, entidades, nivel
en curso y partida activa no se serializan. Se reutiliza el formato de Fase 1,
sin migraciones: archivos anteriores o incompletos conservan sus valores válidos.

Los máximos de puntuación general, puntuación por nivel y combo se actualizan en
memoria al puntuar. Se guardan al completar un nivel, llegar a GAME OVER, volver
al menú, comenzar/reintentar una partida o cerrar desde Salir o la ventana. El callback
`love.quit` también funciona al cerrar por el modo de entrega ECS. No hay
escrituras por bloque ni por frame; cerrar después de un guardado sin cambios no
lo repite. Las estrellas y el desbloqueo se guardan al completar, en la misma
operación que los puntos del último bloque.

Opciones modifica las preferencias en memoria y guarda al volver con ESC, M o
Volver, y al cerrar la ventana. Cambiar un deslizador no escribe por cada pulsación;
abrir y cerrar sin cambios tampoco escribe. Pausar no crea un guardado de partida.

Los intentos incompletos pueden mejorar puntuación y combo, pero no estrellas.
Un fallo de guardado mantiene los mejores valores en memoria y marca los cambios
pendientes para reintentarlos en el siguiente punto de guardado. El menú muestra
el récord general, mejor combo y resultado guardado del máximo nivel desbloqueado.

Se validan rangos y tipos, se rellenan campos faltantes y se limita la lectura a
64 KiB. Los datos se interpretan como texto, **nunca mediante `load`/`loadstring`**.
Un archivo ausente inicia valores por defecto; uno ilegible, corrupto o de versión
desconocida intenta recuperar la copia. Si ambas fallan, el juego sigue con datos
por defecto. Las claves futuras desconocidas se ignoran.

Antes de guardar se escribe una copia del último contenido válido y después el
principal. Si falla la copia no se toca el principal; si falla el principal queda
la copia recuperable. La recuperación puede perder el último avance, pues la
copia conserva el guardado anterior. Un fallo de escritura muestra un aviso y
mantiene el progreso en memoria, sin impedir avanzar de nivel.

## Arquitectura ECS

`World` se conserva sin cambios: IDs numéricos únicos, componentes almacenados por
tipo/ID, consultas que devuelven instantáneas ordenadas y destrucción idempotente.
Limpiar el mundo no recicla IDs. No hay listas paralelas con copias del estado de
pelotas, paddle o bloques.

| Entidad | Componentes |
|---|---|
| Paddle | `Position`, `Velocity`, `Collider`, `Renderable`, `PaddleControl`, `TimedEffect`, `PaddlePower`, `PreviousPosition`, `Invulnerability` |
| Pelota | `Position`, `Velocity`, `Collider`, `Renderable`, `Ball` |
| Bloque | `Position`, `Collider`, `Renderable`, `Brick`, `Health`, `BrickBehavior`, `ScoreValue` |
| Bloque móvil | Los de bloque + `Velocity`, `Motion` |
| Bloque fantasma | Los de bloque + `Ghost` |
| Obstáculo | `Position`, `Velocity`, `Collider`, `Renderable`, `Motion`, `MovingObstacle` |
| Partícula de explosión | `Position`, `Velocity`, `Collider`, `Renderable`, `ExplosionParticle` |
| Partícula de feedback/estela | `Position`, `Velocity`, `Renderable`, `Particle` |
| Poder caído | `Position`, `Velocity`, `Collider`, `Renderable`, `PowerUp` |
| Láser | `Position`, `Velocity`, `Collider`, `Renderable`, `Projectile` |
| Escudo | `Position`, `Collider`, `Renderable`, `Shield` |
| Portal | `Position`, `Collider`, `Renderable`, `Portal` |
| Pulso de portal | `Position`, `Collider`, `Renderable`, `PortalPulse` |
| Jefe | `Position`, `Velocity`, `Collider`, `Renderable`, `Health`, `Boss`, `BossBehavior`, `PreviousPosition`, `Damageable`, `ScoreValue` |
| Protector generado | Componentes de bloque resistente/fantasma + `BossSupport` |
| Proyectil enemigo | `Position`, `Velocity`, `Collider`, `Renderable`, `Health`, `Damageable`, `PreviousPosition`, `EnemyProjectile` |

Los componentes siguen siendo tablas de datos. `Brick` contiene el tipo activo
`kind`, `configuredType`, `levelId` y `key` (fila:columna). `Ball.contacts` almacena
los IDs de contactos continuos, fuego, captura y protección de portales. Los tiempos,
munición y referencias a captura/escudo viven en componentes del paddle; `game.paddleId`
solo identifica esa entidad. La cola de explosiones es un recurso de la partida,
no un segundo almacén de entidades. Las posiciones y
velocidades iniciales se pasan a las fábricas existentes de paddle y pelota.
Cada entidad recibe componentes propios. `ScoreValue` solo contiene `points` y
`awarded`. `game.run` es un recurso de partida que no duplica entidades ni forma
parte del guardado; incluye `score`, `levelScore`, `levelStartScore`, `bestCombo`,
`combo` y el resultado `levelResult` al completar.

| Sistema o módulo | Responsabilidad |
|---|---|
| `ecs/world.lua` | Identidad, componentes, consultas y ciclo de vida; sin cambios. |
| `ecs/systems/movement_system.lua` | Integración con `dt`; sin cambios. |
| `ecs/systems/collision_system.lua` | Rebotes y contactos; detiene el frame al salir de `playing`. |
| `ecs/systems/solid_collision_system.lua` | Barrido de bloques/obstáculos, separación y contactos continuos. |
| `ecs/systems/damage_system.lua` | Salud, inmunidades, daño, destrucción única y sorteo de poderes. |
| `ecs/systems/explosion_system.lua` | Cola de explosiones y partículas acotadas de esas explosiones. |
| `ecs/systems/motion_system.lua` | Trayectorias, formación de grupos y límites de movimiento. |
| `ecs/systems/ghost_system.lua` | Ciclos sólido/intangible, avisos y reaparición segura. |
| `ecs/systems/power_effect_system.lua` | Activación, renovación y limpieza de efectos; tamaño, fuego, captura y escudo. |
| `ecs/systems/projectile_system.lua` | Disparo doble, munición, barrido, daño y limpieza de proyectiles. |
| `ecs/systems/portal_system.lua` | Pares enlazados, entrada barrida, salida segura, rotación, cooldown y pulsos. |
| `ecs/systems/score_system.lua` | Recompensa única, total/subtotal, combo, estrellas, récords y puntos de guardado. |
| `ecs/systems/score_render_system.lua` | HUD de puntos/combo, pulso, estrellas y presentación de récords. |
| `ecs/systems/boss_system.lua` | Patrones, avisos, fases, protectores, teletransporte y temporizador de derrota. |
| `ecs/systems/boss_damage_system.lua` | Punto débil, contacto, presupuestos de salud por fase, premio y derrota única. |
| `ecs/systems/enemy_projectile_system.lua` | Oleadas limitadas, movimiento, barridos relativos contra paddle e invulnerabilidad. |
| `ecs/systems/life_system.lua` | Pérdida única de vida por caída/ataque y reposición que conserva el paddle y sus poderes. |
| `ecs/systems/boss_render_system.lua` | Barra, fase, punto débil, avisos, destellos y victoria especial. |
| `ecs/systems/progression_system.lua` | Carga, victoria, recompensa, transición y reinicio de campaña. |
| `ecs/systems/state_system.lua` | Transiciones permitidas, pausa y reanudación del estado anterior. |
| `ecs/systems/interface_system.lua` | Navegación por teclado, opciones y tiempo de presentación/cuenta regresiva. |
| `ecs/systems/hud_render_system.lua` | HUD, efectos activos e indicadores del paddle; reutiliza puntuación y jefes. |
| `ecs/systems/screen_render_system.lua` | Menú, selector, opciones, pausa, entrada y resultados animados. |
| `ecs/systems/particle_system.lua` | Emisión acotada, estelas rotativas, movimiento, desvanecimiento y limpieza. |
| `ecs/systems/feedback_render_system.lua` | Partículas detrás del juego, recorte al campo y núcleo visible de pelotas. |
| `ecs/systems/audio_system.lua` | Fuentes reutilizadas, música por estado, mezcla, pausa y fallos de recursos. |
| `ecs/systems/feedback_system.lua` | Consume eventos una vez y reparte el presupuesto visual/sonoro. |
| `ecs/systems/render_system.lua` | Conserva el dibujo de entidades y coordina los renderizadores. |
| `feedback.lua` | Cola acotada de datos; prioridad de resultados y limpieza entre rondas. |
| `feedback_styles.lua`, `audio_catalog.lua` | Datos visuales y manifiesto de recursos sonoros. |
| `level_manager.lua` | Catálogo, validación y preparación independiente de mapas. |
| `level_rules.lua` | Validación de mecánicas activas y niveles completables. |
| `score_rules.lua` | Fórmula de multiplicadores, evaluación de estrellas y validación de umbrales. |
| `boss_rules.lua` | Validación de definiciones y configuración de combate. |
| `victory.lua` | Condición compartida por progresión y puntuación, sin duplicar decisiones. |
| `progress_store.lua` | Esquema persistente, saneamiento, lectura, copia y escritura. |
| `bricks.lua` | Crear desde el nivel y notificar una única finalización. |
| `obstacles.lua` | Fábrica de obstáculos con componentes ECS. |
| `bosses.lua` | Fábrica de jefes con componentes ECS. |
| `ball.lua`, `paddle.lua` | Fábricas, herencia de fuego, límites, MULTIBALL, vidas y entrada horizontal. |
| `powerups.lua` | Fábrica, sorteo ponderado, suministro garantizado, caída y recogida. |
| `game.lua` | Coordinar recursos, entrada y orden de actualización. |

Los nueve estados de la tabla de Fase 6 se gestionan con `state_system.lua`.
`game.ui` contiene selección, reloj visual, aviso y estado previo de pausa;
no duplica entidades ni se guarda como progreso. `World`, los componentes y
los sistemas de mecánicas existentes se conservan. Los renderizadores no deciden
victorias, puntos ni estrellas.

`game.feedback` contiene la cola y contadores visuales; `game.audio` mantiene las
fuentes reutilizadas y su estado de reproducción. Son recursos de presentación,
no copias de entidades ni datos persistentes. Los componentes ECS no contienen
objetos de audio ni funciones.

Orden de un frame activo: actualizar ventana del combo, partículas/pulsos, efectos e
invulnerabilidad → entrada/movimiento del paddle y seguimiento de captura →
trayectorias, jefes y fantasmas → movimiento/colisión de cada pelota → detener si se
pidió cierre ECS → mover proyectiles enemigos, resolver láseres y portales si sigue
la partida → procesar explosiones → detener si hubo victoria o quedan eventos →
comprobar última pelota → resolver ataques al paddle → mover/recoger/suministrar poderes.
Un láser que destruye un proyectil lo impide dañar al paddle en ese mismo frame.
Antes de ese recorrido se procesa el estado de interfaz: los menús, la pausa y
la entrada retornan sin ejecutar sistemas de juego. Una transición carga el
siguiente nivel en `level_intro` y retorna sin simularlo. Volver al menú cancela
transiciones y cuentas pendientes.
Cada destrucción notifica al sistema de puntuación antes de comprobar la victoria;
los renderizadores solo leen los resultados, nunca asignan puntos o estrellas.
La Fase 7 envuelve ese recorrido con actualización de audio y partículas antes
de la simulación y consumo del feedback después. Las partículas usan el mismo
tope de `dt` del juego activo; música, fundidos y resultados usan tiempo real.
Pausa/menús bloquean las emisiones de combate. Entrada de teclado y pérdida de
foco sincronizan inmediatamente el audio sin esperar a otro frame.

## Modo entrega ECS

En `src/config.lua`:

```lua
ECS_ASSIGNMENT_MODE = false,
```

Con `false`, los laterales rebotan y aceleran. Con `true`, el contacto de **cualquier
pelota** con un lateral imprime uno de los mensajes y ejecuta `love.event.quit()`:

```text
ECS: pelota toco la pared izquierda
ECS: pelota toco la pared derecha
```

No se rebota ni acelera esa pelota, ni se procesan otras pelotas, poderes o vidas
después del cierre. El contacto exacto cuenta. La pared superior conserva rebote
y aceleración. Funciona también después de avanzar de nivel. Restablece `false`
para jugar normalmente; no hace falta editar el sistema de colisiones.

## Pruebas

```powershell
& "C:\Program Files\LOVE\lovec.exe" tests
```

Resultado actual: 299 escenarios anteriores conservados y 19 de las mejoras arcade:

```text
PASS: 318 escenarios de Breakout
```

- **33 escenarios previos conservados**, con expectativas adaptadas a los estados
  nuevos: la victoria terminal se comprueba en el nivel 10 y ahora premia una vida.
  Siguen comprobándose movimiento, rebotes, vidas, MULTIBALL, el máximo de pelotas, colisiones
  simultáneas, IDs, componentes, entrada real de `main.lua` y ambos modos ECS.
- **13 escenarios de niveles:** mapas distintos, validación, aislamiento de datos,
  carga de los diez niveles, progresión 1→10, límite de vidas, transición con `dt`,
  limpieza de entidades, reinicio, menú, bloqueos y cierre ECS después de avanzar.
- **10 escenarios de guardado:** round trip, récords, estrellas y opciones de audio,
  archivos ausentes/incompletos/corruptos, rangos, versiones, recuperación, errores
  de disco y escritura/lectura real con `love.filesystem`.
- **14 escenarios nuevos de límites y carga:** aceleración hasta 550 px/s,
  dirección conservada, 41 puntos de impacto en el paddle al máximo, velocidades
  inválidas/extremas, niveles con velocidad inicial excesiva, integración con `dt`,
  cadena MULTIBALL hasta 90, límites configurables, limpieza de 89/90 bajas,
  contactos masivos sobre el mismo bloque, transición única, consultas acotadas,
  cierre ECS con 90 pelotas y 120 frames de simulación/renderizado sin crear fuentes.
- **25 escenarios de Fase 2:** salud de 2–4 impactos, contacto continuo, daños con
  90 pelotas, alcance y cadenas de 90 explosivos, presupuesto de eventos, partículas,
  inmunidad de blindados, niveles completables en dos órdenes de daño, ciclos y
  reaparición de fantasmas, cuatro patrones móviles, grupos, límites del paddle,
  barridos contra objetos finos/móviles, condición de victoria, reinicios y cierre ECS.
- **38 escenarios de Fase 3:** los siete poderes y sus 49 pares ordenados,
  duración/renovación con `dt`, probabilidades ponderadas, límites y suministro
  garantizado, fuego con 90 pelotas y contactos continuos, láser con blancos finos
  y móviles, interfaz de daño para jefes, escudo, prioridad de captura/lanzamiento,
  limpieza de rondas/estados, portales bidireccionales, barrido, salidas obstruidas,
  90 traslados, límite de pulsos, cierre ECS y dibujo real de etiquetas/HUD.
- **29 escenarios de Fase 4:** puntos por tipo y destrucción, duplicados, 90 pelotas
  y explosiones, fuentes de daño, ventana/límites del combo, pulso con `dt`, estados,
  vidas, último bloque y estrellas antes de la recompensa, campaña, reintentos,
  récords de intentos incompletos, umbrales de los diez mapas, saturación numérica,
  archivos anteriores/corruptos, fallo y reintento de guardado, `love.quit` real,
  `love.filesystem` real, modo de entrega y dibujo de puntos/combo/estrellas.

- **31 escenarios de Fase 5:** componentes y validación de jefes, entrada y punto
  débil, pelota normal/fuego/láser, impacto sobre punto débil móvil, 90 contactos,
  patrones deterministas, protectores sin premios y con cupo/caducidad, tres fases
  sin saltos, avisos, puntería limitada, proyectiles esquivables y su intercepción,
  teletransporte seguro, fantasmas, barridos contra paddle móvil/fino, una vida por
  ronda, invulnerabilidad, reinicio, derrota y prioridad de victoria, guardado y
  recompensa únicos, animación, menú, daño normal sin poderes, ambos laterales en
  modo ECS con 90 pelotas y dibujo de barra/fase/victoria sin crear fuentes por frame.

- **32 escenarios de Fase 6:** inicio en menú, navegación y bloqueo del selector,
  diez niveles seleccionables, atajo C, preferencias y límites, escritura diferida,
  fallos/reintentos de guardado, salida, pausa con todos los componentes congelados,
  90 pelotas, reanudación, repetición de teclas, reinicio y menú, cuenta con `dt`,
  pausa durante entrada, pérdida de foco, transición y desbloqueo, resultados,
  cambios de estado inválidos, animaciones acotadas, tarjetas/estrellas/récords,
  HUD con todos los poderes, Canvas sin recursos nuevos, revelado de estrellas,
  modo ECS al reanudar y callbacks reales de `main.lua`.

- **30 escenarios de Fase 7** (`tests/feedback_spec.lua`): manifiesto de WAV reales,
  precarga y reutilización, selección/fundido de música, volumen/silencio y guardado,
  pausa/foco/reanudación, reinicio desde pausa sin repetir sonidos anteriores,
  cupo y prioridad de voces, cooldown, backend ausente y archivos/fuentes fallidos;
  cola acotada y resultados prioritarios, componente de datos, integración con
  `dt`, estelas justas con 90 pelotas sin consumir azar, fuego/captura, saturación,
  limpieza y pausa; eventos únicos por destrucción, daño, rebotes, poderes,
  láseres, portales y jefes; pérdida de última pelota, GAME OVER/victoria únicos,
  recorte y núcleo claro en Canvas real, recursos constantes y cierre ECS.

Esta fase conserva **los 225 escenarios anteriores sin modificarlos ni eliminarlos**.
Se verificaron primero como línea base; la suite completa pasa con 30 casos nuevos.
Las pruebas de mecánicas siguen recorriendo la cuenta regresiva con
`Helpers.finishIntro`; no se añadió un modo de juego que omita sistemas.

El ajuste de sprint conserva los **255 escenarios de las fases anteriores** y suma
**14 escenarios** en `tests/sprint_spec.lua`: A/D y flechas, ambos Shift, retorno
inmediato sin cooldown, teclas opuestas, configuración, bordes con paddle normal
y gigante y `dt` alto, desplazamiento a 30/60/120 FPS, pausa/reinicio/entrada,
imán con gigante y prioridad de lanzamiento, compatibilidad con los siete poderes,
MULTIBALL hasta 90 y pérdida de última pelota, velocidades/rebotes de pelota,
texto/color/espacio del HUD en Canvas real sin recursos nuevos y ambos laterales
del modo ECS con sprint. Las pruebas usan entradas controladas, no una sesión
manual de teclado.

El balance de jefes añade **15 escenarios** en `tests/boss_balance_spec.lua`:
dimensiones y reinicios sin escala acumulada, límites/proporción y configuración
inválida, pelota normal/fuego a 550 px/s, láser contra ambos bordes durante movimiento,
Canvas con la misma zona de daño y protección, 100000 sorteos controlados repartidos
entre los diez niveles, peso configurable por marcador de jefe, protectores sin
duplicados ni premios al caducar, suministro escaso y sus fallos, cupos/munición,
estados, `dt`, pausa y limpieza. También se derrota a ambos jefes usando colisiones
reales de pelota normal en sus ventanas abiertas; la fixture coloca las pelotas
en la ruta central para comprobar accesibilidad, no simula habilidad humana.
Se conservan los 269 escenarios anteriores. En `boss_spec.lua` el caso de impacto
móvil calcula el borde a partir de la zona ampliada en lugar de usar coordenadas
antiguas; se actualiza la descripción del caso de protectores para reflejar el
sorteo de poderes habilitado. No se eliminó ninguna prueba.
Se inspeccionaron capturas reales de LÖVE de ambos puntos débiles ampliados y del
Núcleo cerrado: las etiquetas son legibles y la zona permanece dentro del cuerpo.
Esto no sustituye una partida manual para valorar la dificultad del enfrentamiento.

La conservación entre vidas añade **15 escenarios** en `tests/life_effects_spec.lua`:
identidad/ancho del gigante con 8 s, láser con 12 disparos e intervalo restante,
escudo de dos impactos, fuego heredado y caducidad, imán tras perder una captura,
sprint, 89/90 bajas y reposición única, efectos simultáneos sin duplicados,
objetos/proyectiles y relojes conservados, `dt` y pausa, expiración en el frame
de caída, bloques/puntos/combo/jefes, nueva campaña, reinicio/cambio de nivel,
GAME OVER, diez mapas y ambos cierres ECS tras reponer. Se conservan todos los
284 escenarios previos; se actualizan las expectativas de limpieza entre vidas
en cuatro archivos de pruebas para reflejar la nueva regla, sin eliminar casos.

La suite usa un backend de audio controlado para comprobar pausas, errores y cupos
sin depender de un dispositivo. **Además**, una sesión aislada con el módulo real
de audio de LÖVE 11.5 cargó los 19 WAV, reprodujo los 16 efectos y verificó duración,
loop, pausa/reanudación, posición congelada y silencio en los tres streams.
Se silenció la salida global de esa sesión: se comprobó la API real, **no se realizó
una escucha humana**. Una validación PCM confirmó formato, muestras no vacías,
ausencia de clipping individual y hashes idénticos al regenerar los 19 archivos.

La medición de Fase 7, con **600 frames tras 60 de calentamiento**, obtuvo
**5,32 ms de media / 7,73 ms p95 / 9,51 ms máximo** en el nivel 10, fase Caos.
Incluye actualización y envío de dibujo a Canvas con 90 pelotas de fuego, poderes,
láseres, fantasmas, 18 proyectiles enemigos y 64 eventos visuales por frame.
Se saturaron las 256 partículas nuevas y las 192 de explosiones. La fixture repone
posiciones, ataques e invulnerabilidad para mantener la carga; comprueba los cupos,
550 px/s y que las 19 cargas de audio no aumenten durante los frames.
Es una medición controlada adicional, sin presentación/vsync: no garantiza FPS
en otros equipos o durante una partida manual prolongada.

Se inspeccionaron capturas reales de LÖVE de opciones, explosiones, portales,
estelas con fuego, 90 pelotas con efectos saturados y celebración final. Los
núcleos de las pelotas y el HUD permanecen visibles. Se usaron estados de prueba
controlados y guardados en memoria, sin alterar la campaña del jugador.

Las pruebas usan discos en memoria para los escenarios y la identidad separada
`breakout_engine_tests` para la integración real: **no alteran el progreso del
jugador**. Renderizan los diez niveles y pantallas de campaña en Canvas de LÖVE y
comprueban texto/colores. Esto no representa una partida manual completa ni una
validación humana del balance de los diez niveles.

### Verificación interactiva

1. Inicia el juego: aparece el menú. Selecciona Jugar con Enter y espera la entrada
   y cuenta 3, 2, 1: nivel 1, 72 bloques, 3 vidas, una pelota. Mueve con A/D o flechas.
2. Comprueba rebotes direccionales y recoge x3. Deja caer algunas pelotas: mientras
   quede una, no debe descontarse una vida.
3. Destruye algunos bloques y pierde la última pelota. Deben seguir destruidos;
   el paddle se centra conservando su ancho/poderes y aparece una sola pelota inicial.
4. Completa un nivel: observa LEVEL COMPLETE, la vida recuperada y, tras dos
   segundos, la entrada del siguiente nombre/mapa. Nunca deben superarse cinco vidas.
5. Pulsa M y C para iniciar el máximo desbloqueado con tres vidas. Sal y vuelve
   a abrir el juego; M y C deben seguir permitiendo entrar al nivel desbloqueado.
6. Pierde todas las vidas en un nivel posterior: GAME OVER. R debe reconstruir
   ese nivel con tres vidas; M y Enter deben iniciar una campaña desde el primero.
7. Completa el nivel 10: YOU WIN! permanece hasta R (nueva campaña) o M (menú).
8. Activa temporalmente `ECS_ASSIGNMENT_MODE`, reinicia y verifica mensaje/cierre
   lateral. Después restaura `false`.
9. Recoge x3 repetidamente: el contador debe seguir 3, 9, 27, 81 y 90. Los siguientes
   poderes no deben aumentarlo. Tras varios rebotes, las pelotas deben dejar de
   acelerar y mantener su movimiento y rebotes direccionales.
10. Nivel 2: golpea un R3; debe pasar a R2/R1 y cambiar de color antes de desaparecer.
11. Nivel 3: destruye un asterisco naranja y observa la cadena y las partículas.
12. Nivel 4: observa los cuatro patrones y la barra móvil; esta rebota pelotas y
    permanece aunque se eliminen todos los bloques.
13. Nivel 6: comprueba el aviso y la alternancia de los G. Las pelotas atraviesan
    los bloques atenuados; un bloque ocupado debe esperar antes de hacerse sólido.
14. Niveles 7, 9 y 10: las A grises resisten pelotas normales. Apunta a los explosivos
    ortogonales adyacentes o recoge fuego; debe reaparecer una oportunidad cada 10–12 s.
15. Recoge gigante: dura 15 s y renueva sin seguir creciendo. Combínalo con escudo;
    observa tiempo e impactos restantes y la desaparición tras el tercer rebote.
16. Recoge fuego y después MULTIBALL: todas las pelotas deben ser naranjas con
    borde claro y atravesar bloques vulnerables, también las copias nuevas.
17. Desde nivel 4, recoge láser y pulsa Espacio: salen dos rayos por carga y el HUD
    baja desde 20. Pulsar muy rápido no debe saltarse el intervalo.
18. Desde nivel 5, recoge imán y recibe una pelota. Debe seguir al paddle; otra
    pelota rebota normalmente. Con láser activo, el primer Espacio solo lanza.
19. En niveles 7 y 9, entra por cada portal: la salida conserva rapidez, cambia
    dirección y muestra pulsos; no debe aparecer dentro de un bloque.
20. Pierde la última pelota con poderes activos y vidas disponibles: conserva ancho,
    tiempos, munición y resistencia del escudo. La pelota nueva hereda fuego y puede
    ser capturada por el imán. Pausa y comprueba que los tiempos no avanzan. Repite
    al cambiar/reiniciar nivel y en GAME OVER: esos casos sí limpian los poderes.
21. Destruye un normal sin combo: suma 100. Un resistente solo suma 150 al destruirse.
    Encadena bloques antes de tres segundos: observa x2 desde el cuarto, x3 desde
    el séptimo y x5 desde el decimotercero, junto a la barra y el pulso del HUD.
22. Espera tres segundos sin destruir: cadena a cero y x1, con puntos conservados.
    Pierde una vida: los puntos siguen y el combo empieza de nuevo.
23. Completa un nivel: verifica puntos y estrellas según los umbrales, con las vidas
    que tenías antes del premio. El siguiente nivel conserva el total y reinicia
    su subtotal. No se conceden estrellas al perder sin completar.
24. Vuelve al menú o cierra y abre el juego: los récords se conservan. Repite con
    menos puntos/estrellas: no deben bajar. R tras GAME OVER conserva solo los puntos
    de niveles previos; M y Enter comienzan una campaña con cero puntos.
25. Nivel 5: observa la barra de 10 HP, el aviso MOVIMIENTO y su destino. Abre paso
    entre los protectores y golpea el rectángulo verde inferior con pelota o láser.
    Un golpe en el cuerpo no quita salud; derrotarlo avanza al nivel 6 incluso si
    quedan bloques y concede una sola recompensa.
26. Nivel 10: comprueba el ciclo CERRADO → ABRIENDO NÚCLEO → GOLPEA. A 15 HP debe
    anunciar Ataque; a 8 HP, Caos. Observa la línea de aviso, desplázate antes de
    recibir un disparo y destruye proyectiles rojos con láser. Esquiva los ámbar.
27. En Caos, observa el contorno de destino antes del teletransporte, el abanico de
    tres disparos y los fantasmas. Un golpe enemigo al paddle, incluso con MULTIBALL,
    debe costar una sola vida y dejar una pelota, conservando salud/fase del jefe.
    Durante 2 s se ve el contorno de invulnerabilidad y otros ataques no restan vidas.
28. Derrota al Núcleo: verifica los 15000 puntos base (con combo si corresponde),
    el desvanecimiento, anillos, título especial, YOU WIN! y estrellas. Comprueba
    que R inicia una campaña nueva y que un GAME OVER previo reinicia con R el jefe
    completo del nivel actual.
29. En el menú, navega hasta Seleccionar nivel: deben verse diez tarjetas con
    nombre, estado, estrellas y récord. Intenta entrar a una bloqueada y comprueba
    el aviso. Repite una desbloqueada y verifica que empieza con cero puntos.
30. En Opciones, lleva los volúmenes a ambos extremos y alterna silencio. Vuelve
    con ESC, cierra y abre: los valores deben persistir. Música y efectos deben
    responder al instante; general en cero debe silenciar ambos canales.
31. Pausa con ESC o P mientras tengas poderes y varias pelotas. Espera: posiciones,
    vidas, combo, tiempos, disparos y salud del jefe deben quedar iguales. Continúa
    con Enter o ESC y comprueba que no se descontó el tiempo pasado en pausa.
32. Pausa durante la cuenta regresiva, espera y continúa: debe conservar el número
    y tiempo pendiente. Cambia de ventana durante la partida: debe pausarse y seguir
    pausada al regresar hasta que elijas Continuar.
33. Desde pausa, elige Reiniciar nivel: tres vidas, jefe/bloques restaurados,
    cuenta nueva y puntos de entrada recuperados. Volver al menú debe abandonar el
    intento y conservar sus récords. Selecciona Salir para cerrar el juego.
34. Escucha la música del menú, entra a un nivel normal y después a un jefe
    desbloqueado: deben cambiar las pistas con un fundido breve. Comprueba efectos
    distintos para rebote, daño resistente, explosión, láser, poderes y portales.
35. Con varias pelotas, observa estelas breves y núcleos claros; activa fuego para
    ver su color naranja. Las chispas y fragmentos no deben tapar el HUD. Pausa:
    partículas y reproducción deben detenerse y continuar desde la misma posición.
36. Reinicia desde pausa: no deben reaparecer partículas ni sonar impactos de la
    ronda anterior. Completa un nivel, pierde la última vida y vence al jefe final
    en distintos intentos: cada resultado debe reproducir su señal una sola vez;
    las celebraciones de nivel/campaña deben desaparecer por sí solas.
37. Muévete con A/D o flechas y mantén cada Shift: el desplazamiento debe aumentar
    un 80 % y el HUD mostrar SPRINT en verde. Suelta Shift sin soltar la dirección:
    vuelve a la velocidad normal y a SHIFT: Sprint. Comprueba que Shift solo y
    direcciones opuestas no mueven el paddle, y que ambos bordes detienen el sprint.
38. Repite con gigante e imán juntos: la pelota capturada debe acompañar el
    movimiento y los límites. Espacio sigue lanzándola antes de disparar láser;
    las pelotas libres conservan su rapidez. Pausar debe detener todo movimiento.
39. En los niveles 5 y 10, observa el rectángulo verde ampliado. Comprueba impactos
    de pelota y láser junto a sus nuevos extremos; el cuerpo fuera del rectángulo
    y la ventana CERRADO del Núcleo deben seguir rechazando daño.
40. Destruye bloques y protectores durante esos combates: aparecen distintos poderes,
    con mayor frecuencia relativa de láser. Con tres bloques originales o menos,
    sin munición ni láser cayendo, hay un intento del 50 % cada 20 s: un intervalo
    sin láser es normal. Pausa y reanuda para comprobar que la espera se conserva.

Para revisar los diez mapas sin jugarlos completos, la suite automatizada carga
y renderiza todos en una sesión aislada. No se añadieron atajos que desbloqueen
la campaña del jugador.

## Archivos de la Fase 7

- Creados: `src/feedback.lua`, `src/feedback_styles.lua`, `src/audio_catalog.lua`;
  `particle_system.lua`, `feedback_render_system.lua`, `audio_system.lua` y
  `feedback_system.lua` dentro de `src/ecs/systems/`; `tests/feedback_spec.lua`,
  `tools/generate_audio.py`, `assets/audio/LICENSE.md` y los 19 WAV de esa carpeta.
- Modificados: `src/config.lua`, `src/ecs/components.lua`, `src/game.lua`,
  `src/bricks.lua`, `src/powerups.lua`, `tests/main.lua` y este README.
- Sistemas existentes extendidos con notificaciones y presentación, todos en
  `src/ecs/systems/`: `damage_system.lua`, `explosion_system.lua`,
  `boss_damage_system.lua`, `life_system.lua`, `collision_system.lua`,
  `projectile_system.lua`, `enemy_projectile_system.lua`, `portal_system.lua`,
  `progression_system.lua`, `render_system.lua`, `screen_render_system.lua` e
  `interface_system.lua`.
- Se conservan sin cambios de esta fase `World`, movimiento, barridos sólidos,
  puntuación, persistencia, patrones de jefes, mapas, reglas de poderes y límites
  de velocidad/pelotas. Solo se añade `Particle` al catálogo de componentes.

## Verificaciones pendientes

Faltan una escucha humana para valorar la mezcla musical, una partida manual
completa para evaluar el balance y mediciones en otros equipos. Las pruebas
automáticas no simulan habilidad humana ni certifican la dificultad de una
campaña jugada de principio a fin. La navegación sigue siendo por teclado.
No se añadieron dependencias externas, no se crearon commits ni se cambió de rama.
La Fase 7 está completada; los ajustes posteriores se documentan en Controles y
en las secciones de balance de jefes y conservación de poderes entre vidas.

Mensaje de commit del ajuste: `fix(powerups): preserve active effects when respawning after life loss`.

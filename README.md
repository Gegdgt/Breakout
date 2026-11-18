# Breakout — ECS con LÖVE 11.5

Juego en **Lua + LÖVE (Love2D)**, sin dependencias externas ni recursos gráficos.
La adaptación conserva los controles, colores, dimensiones y reglas anteriores.
El modo normal sigue siendo el predeterminado.

## Ejecutar

Desde la carpeta que contiene `main.lua`, en PowerShell:

```powershell
& "C:\Program Files\LOVE\lovec.exe" .
```

Si LÖVE está en el PATH, también puedes usar `love .`. Si está instalado en
otra carpeta, ajusta la ruta. El proyecto usa **LÖVE 11.5**, disponible en
[love2d.org](https://love2d.org/). `lovec.exe` permite leer los mensajes de la
terminal; `conf.lua` conserva la consola habilitada y la ventana de 960 × 640.

## Controles y reglas conservados

- **Flecha izquierda / A:** mover el paddle hacia la izquierda.
- **Flecha derecha / D:** moverlo hacia la derecha.
- **Escape:** salir.
- **R:** reiniciar toda la partida después de ganar o perder; se ignora durante el juego.

Se comienza con **3 vidas**, **72 bloques** y **una pelota**. Los contadores de
vidas, bloques restantes y pelotas activas mantienen su apariencia y ubicación.

Una pelota que toca el fondo desaparece. Solo se descuenta una vida cuando
desaparece **la última pelota**, incluso si varias caen en la misma actualización.
Si quedan vidas, se centra el paddle, se crea una pelota con posición y velocidad
iniciales y se retiran los poderes pendientes. **Los bloques destruidos no se
restauran al perder una vida.**

Al perder las tres vidas aparece **GAME OVER** en rojo. Al destruir el último
bloque aparece **YOU WIN!** en verde. En ambos estados se detienen el paddle,
las pelotas y los poderes; la ventana permanece abierta. **R** restaura las tres
vidas, los 72 bloques, una pelota y el paddle centrado, y elimina todos los poderes.

El rebote con el paddle depende del punto de impacto: a la izquierda sale hacia
arriba e izquierda, en el centro sale verticalmente y a la derecha sale hacia
arriba y derecha. El ángulo varía progresivamente hasta **60° respecto a la
vertical** en los extremos. El sistema de colisiones ECS calcula
`impact = (ballCenterX - paddleCenterX) / (paddleWidth / 2)`, lo limita a `[-1, 1]`
y obtiene `angle = impact * math.rad(60)`. Aumenta la rapidez actual por **1.08**
y asigna `vx = speed * math.sin(angle)` y `vy = -speed * math.cos(angle)`.

Esto se aplica a cada pelota, incluidas las copias de MULTIBALL. Solo rebotan las
pelotas que bajan; se colocan encima del paddle para impedir que queden atrapadas
o aceleren varias veces durante el mismo contacto. Los rebotes en las paredes
siguen multiplicando ambos ejes por **1.08**.

### MULTIBALL x3

Cada bloque destruido conserva un **15 %** de probabilidad de soltar un rectángulo
amarillo con la etiqueta **x3**. El poder aparece centrado en el bloque, cae
verticalmente con `dt`, se recoge con el paddle y desaparece fuera de pantalla.

Cada pelota activa conserva su trayectoria y genera dos pelotas adicionales con
velocidades rotadas aproximadamente **−25° y +25°**, conservando la rapidez:
1 → 3, 2 → 6, 3 → 9. Las copias evitan ejes casi detenidos y usan la rapidez inicial
si la original estaba detenida. Se conserva el **máximo de 30 pelotas**; solo se
crean las copias que caben.

La destrucción de un bloque ocurre antes de procesar la siguiente pelota, por lo
que cada bloque solo puede desaparecer y sortear un poder una vez. La victoria
conserva su prioridad sobre el descuento de vidas y las recogidas del mismo frame.

## Modo normal y modo entrega ECS

La constante está al inicio de **`src/config.lua`**:

```lua
ECS_ASSIGNMENT_MODE = false,
```

| Valor | Comportamiento en pared izquierda o derecha |
|---|---|
| `false` (predeterminado) | Rebote lateral y aumento de rapidez; la ventana sigue abierta. |
| `true` | Mensaje que identifica el lateral y `love.event.quit()`, sin rebotar ni acelerar esa pelota. |

Para la entrega, cambia únicamente esa constante a `true`, guarda y vuelve a
iniciar el juego. Verás uno de estos mensajes antes del cierre:

```text
ECS: pelota toco la pared izquierda
ECS: pelota toco la pared derecha
```

El contacto de **cualquier pelota** activa el cierre, incluso si hay varias.
La comprobación incluye el contacto exacto con el borde. Una vez solicitado el
cierre no se procesan más pelotas, vidas ni poderes. La pared superior mantiene
el rebote y la aceleración en ambos modos. Para volver a la experiencia normal,
restablece `false` y reinicia el programa.

Las tres vidas, MULTIBALL y los demás sistemas existen en ambos modos; en la
entrega, un contacto lateral termina la aplicación antes de continuar la partida.
No es necesario editar ningún sistema de colisiones para cambiar el modo.

## Qué es ECS y cómo se implementa

**Entity Component System** separa la identidad de los objetos, sus datos y su
comportamiento:

- **Entidad:** un identificador numérico único dentro del mundo. No tiene métodos de juego.
- **Componente:** una tabla con datos. No contiene funciones ni hereda comportamiento.
- **Sistema:** funciones que consultan entidades por sus componentes y procesan esos datos.

`src/ecs/world.lua` administra los IDs, los componentes por tipo e ID, las
consultas y la destrucción. Los sistemas operan sobre el mismo mundo; no hay
colecciones paralelas de objetos `Ball`, `Paddle` o `Powerup` con estado duplicado.
Las funciones `spawn` de los módulos existentes son fábricas que ensamblan
componentes y devuelven un **ID**, no instancias con métodos `update` o `draw`.

### Entidades y componentes

| Entidad | Componentes |
|---|---|
| Paddle | `Position`, `Velocity`, `Collider`, `Renderable`, `PaddleControl` |
| Cada pelota | `Position`, `Velocity`, `Collider`, `Renderable`, `Ball` |
| Cada bloque | `Position`, `Collider`, `Renderable`, `Brick` |
| Cada poder que cae | `Position`, `Velocity`, `Collider`, `Renderable`, `PowerUp` |

Los constructores están en `src/ecs/components.lua`:

| Componente | Datos |
|---|---|
| `Position` | `x`, `y` |
| `Velocity` | `vx`, `vy`, en píxeles por segundo |
| `Collider` | Ancho `w` y alto `h` del rectángulo AABB |
| `Renderable` | Color, radio de esquinas, orden de dibujo, borde/brillo/etiqueta cuando corresponde |
| `PaddleControl` | Velocidad y teclas izquierda/derecha |
| `Ball` | Multiplicadores de rapidez para paddle y paredes |
| `Brick` | Probabilidad de soltar poder |
| `PowerUp` | Tipo y nombre del poder |

Cada pelota y cada copia tienen componentes propios. Las vidas, el estado de
partida, el contador de bloques, la configuración y las fuentes son **recursos
globales** del coordinador `Game`; no se duplican en cada entidad.

### Sistemas y módulos reutilizados

| Sistema | Archivo | Responsabilidad |
|---|---|---|
| Entrada del paddle | `src/paddle.lua` | Consulta `PaddleControl + Position + Velocity + Collider`, lee las mismas teclas, fija velocidad horizontal y limita X. |
| Movimiento | `src/ecs/systems/movement_system.lua` | Integra `Position + Velocity` usando `dt`; lo usan paddle, pelotas y poderes. |
| Colisiones | `src/ecs/systems/collision_system.lua` | Consulta pelotas, paddles y bloques; resuelve paredes, paddle, impactos y caída inferior. |
| Geometría AABB | `src/collision.lua` | Conserva el algoritmo de solapamiento y de rebote por el lado de entrada al bloque. |
| Reglas de pelotas | `src/ball.lua` | Fábrica, copias con velocidad rotada y pérdida de vida al quedar cero pelotas. |
| Bloques | `src/bricks.lua` | Construye la cuadrícula original, destruye una sola vez y determina la victoria. |
| Poderes | `src/powerups.lua` | Sorteo, generación, caída, recogida y multiplicación con límite de 30. |
| Renderizado | `src/ecs/systems/render_system.lua` | Consulta `Position + Collider + Renderable` y dibuja entidades, contadores y mensajes. |

Se reutilizan los nombres de los módulos anteriores para evitar una estructura
innecesariamente grande, pero sus entidades ahora son IDs y sus sistemas consultan
componentes reales. `main.lua` y `conf.lua` mantienen los callbacks, controles de
reinicio/salida y configuración de ventana originales.

Ejemplo de acceso a los datos de una pelota:

```lua
local ids = game.world:query("Ball", "Position", "Velocity", "Collider")
local id = ids[1]
local position = game.world:get(id, "Position")
local velocity = game.world:get(id, "Velocity")
-- position y velocity son tablas de datos independientes, sin métodos.
```

### Orden de actualización y seguridad de los recorridos

`love.update(dt)` llama a `Game:update(dt)`, que conserva el límite original de
`dt = math.min(dt, 0.05)` para pausas o arrastres de ventana. El desplazamiento es
velocidad × tiempo, nunca una cantidad fija por frame.

1. Leer controles, mover el paddle y limitarlo a la pantalla.
2. Recorrer las pelotas de última a primera: mover cada una y resolver sus colisiones.
3. Detener la actualización si hubo victoria o solicitud de cierre.
4. Revisar una sola vez si no quedan pelotas: descontar una vida y reiniciar la ronda o perder.
5. Mover y recoger poderes; aplicar cada MULTIBALL a las pelotas activas.

El movimiento se invoca desde la fase correspondiente para conservar el orden del
juego anterior. No se ejecuta además un segundo movimiento global.

Las consultas devuelven **instantáneas ordenadas de IDs**. Crear o borrar una
entidad no altera la lista que se está recorriendo. El borrado retira inmediatamente
todos sus componentes; `world:has(id, ...)` permite verificar IDs obtenidos antes.
`world:destroy(id)` es idempotente y los IDs no se reciclan al reiniciar.

MULTIBALL toma una instantánea de las originales: nunca multiplica las copias que
acaba de crear durante ese mismo poder. Los poderes recogidos se retiran antes de
aplicar sus efectos. Dos poderes simultáneos mantienen el comportamiento 1 → 3 → 9.

## Estructura

```text
Breakout/
├── main.lua
├── conf.lua
├── src/
│   ├── config.lua
│   ├── game.lua
│   ├── paddle.lua
│   ├── ball.lua
│   ├── bricks.lua
│   ├── powerups.lua
│   ├── collision.lua
│   └── ecs/
│       ├── world.lua
│       ├── components.lua
│       └── systems/
│           ├── movement_system.lua
│           ├── collision_system.lua
│           └── render_system.lua
├── tests/
│   ├── conf.lua
│   ├── main.lua
│   ├── helpers.lua
│   ├── game_spec.lua
│   └── ecs_spec.lua
└── README.md
```

## Cumplimiento de requisitos

| Requisito | Situación anterior | Implementación y verificación actuales |
|---|---|---|
| Paddle controlado con teclado, mismos controles | Existía | Flechas/A/D conservadas; pruebas para las cuatro teclas y teclas opuestas. |
| Paddle solo horizontal y dentro de pantalla | Existía | `PaddleControl`, velocidad Y cero y límites según ancho; pruebas de ambos extremos. |
| Movimiento con `dt` y `love.update(dt)` | Existía | Integrador común; prueba de igual desplazamiento con tiempo dividido para los tres tipos móviles. |
| Al menos una pelota en movimiento | Existía | Fábrica ECS con posición y velocidad iniciales originales. |
| Múltiples pelotas independientes | Existía sin ECS | Una entidad y componentes propios por pelota; pruebas de movimiento, bajas y copias independientes. |
| Rebote del paddle hacia arriba con mayor rapidez | Existía | Dirección progresiva según impacto, hasta 60° desde la vertical y factor 1.08; pruebas de cinco zonas, separación, límite angular y MULTIBALL simultáneo. |
| Rebote superior con aumento de rapidez | Faltaba acelerar | Reflexión Y y multiplicador de pared; prueba en ambos modos. |
| Rebote lateral y aceleración en modo normal | Faltaba acelerar | Reflexión X, multiplicador y contacto exacto; prueba de ambos laterales y sin cierre. |
| Mensaje y cierre lateral en entrega ECS | Faltaba | Constante `ECS_ASSIGNMENT_MODE`; pruebas de ambos lados con cualquiera de tres pelotas, sin rebote. |
| Bloques visibles, impactos y destrucción | Existía | Cuadrícula original y sistema de bloques; pruebas de impactos y renderizado. |
| Evitar doble destrucción o doble poder | Existía | Borrado inmediato; dos pelotas sobre el mismo bloque producen un único sorteo. |
| Power-up con probabilidad del 15 % | Existía | `Brick.dropChance`, caída y recogida conservadas; prueba del umbral y origen. |
| MULTIBALL x3 y máximo de 30 | Existía | Se conservan originales, dispersión y límite; pruebas 1→3, 2→6, 3→9 y casos 27/29/30. |
| Tres vidas y contador visual | Existía | Recurso `lives` y renderizado original; pruebas de tres rondas y del texto dibujado. |
| Descontar vida solo al caer la última pelota | Existía | Revisión única tras colisiones; pruebas con sobrevivientes y caídas simultáneas. |
| Reiniciar ronda sin restaurar bloques | Existía | Recrear solo entidades móviles; prueba de bloques conservados y limpieza de poderes. |
| GAME OVER al perder tres vidas | Existía | Estado `lost`, congelación y mensaje rojo; pruebas de lógica y dibujo. |
| YOU WIN! al destruir todos los bloques | Existía | Estado `won`, prioridad de victoria y mensaje verde; pruebas de lógica y dibujo. |
| R reinicia tras ganar/perder | Existía | Callback original sin cambios; prueba usando `main.lua` real. |
| ECS real en todos los objetos relevantes | Faltaba | IDs, almacenes de componentes y consultas de sistemas; pruebas de datos puros, independencia y ciclo de vida. |
| Creación/eliminación segura durante actualización | Existía para listas de objetos | Instantáneas de IDs y borrado idempotente; pruebas de altas/bajas, recogidas simultáneas y referencias invalidadas. |

## Pruebas

Desde la raíz del proyecto:

```powershell
& "C:\Program Files\LOVE\lovec.exe" tests
```

Resultado esperado:

```text
PASS: 33 escenarios de Breakout
```

La suite ejecuta **los 16 escenarios de regresión originales**, adaptando el acceso
a los datos al mundo ECS y las expectativas de rebote de paredes y paddle, más
**17 escenarios ECS**. El rebote direccional se comprueba en las cinco zonas en
ambos modos, con distintas velocidades de entrada, 41 puntos de impacto para
verificar la progresión, anchos de collider distintos, impactos fuera de los
centros extremos y tres pelotas de MULTIBALL simultáneas. Usa los módulos reales,
valores aleatorios y teclas controlados, y renderizado real de LÖVE a Canvas.
No necesita librerías adicionales. Prueba ambos modos aunque la constante esté
seleccionada para la entrega, y restaura su valor al terminar.
Solo el ejecutor de pruebas se cierra automáticamente.

En la validación de esta adaptación:

- Pasaron los 16 escenarios originales antes de editar y los 25 después de migrar.
- Compilaron los 19 archivos Lua con el runtime LuaJIT instalado con LÖVE.
- Se compararon imágenes renderizadas por LÖVE con la versión original
  (`b29fa9d`): inicio, poderes/MULTIBALL, victoria y derrota tuvieron **cero píxeles distintos**.
- Dos ejecuciones aisladas con el cierre real de LÖVE confirmaron mensaje,
  velocidad sin rebote y terminación del proceso tanto a izquierda como a derecha.
- La automatización de la ventana de Windows no pudo conectarse. No se presenta
  como realizada una partida manual completa: las teclas se verificaron con entrada
  controlada y la apariencia mediante Canvas e imágenes del motor real.

### Comprobación interactiva

1. Deja `ECS_ASSIGNMENT_MODE = false`, inicia y comprueba 3 vidas, una pelota y 72 bloques.
2. Mueve con A/D y flechas; verifica que el paddle mantenga su altura y no salga de pantalla.
3. Golpea el paddle en los extremos, zonas intermedias y centro: la salida debe variar de −60° a +60° respecto a la vertical, con salida vertical en el centro. Comprueba que la rapidez siga aumentando en paddle, techo y laterales.
4. Recoge x3; verifica dispersión, pelotas independientes y límite de 30.
5. Deja caer pelotas: las vidas se conservan mientras quede alguna; al caer la última se reinicia solo la ronda.
6. Pierde tres vidas, comprueba GAME OVER y pulsa R. Elimina todos los bloques, comprueba YOU WIN! y pulsa R.
7. Cambia la constante a `true` y vuelve a iniciar. El primer contacto lateral debe imprimir el lado y cerrar.
8. Restablece `false` para jugar normalmente.

Para forzar poderes o una victoria más rápida durante una prueba manual, puedes
cambiar temporalmente `POWERUP_DROP_CHANCE = 1` o `BRICK_ROWS = 1`.
Restablece **0.15** y **6** antes de ejecutar las pruebas automáticas, que verifican
la configuración original. Los controles y la apariencia no necesitan ajustes.

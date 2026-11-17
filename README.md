# Breakout — base de engine con LÖVE 11.5

Proyecto de ejemplo para la tarea del juego **Breakout**, programado en **Lua + LÖVE (Love2D)**. No requiere imagenes, audios ni otros paquetes.

## Preparar el ambiente (Windows)

1. Instala **LÖVE 11.5** desde https://love2d.org/ . Selecciona el instalador Windows 64-bit si usas Windows de 64 bits.
2. Instala **Visual Studio Code** (opcional) y abre la carpeta `breakout_love2d`.
3. Abre una terminal **PowerShell** dentro de la carpeta, justo donde esta `main.lua`.
4. Ejecuta:

   ```powershell
   & "C:\Program Files\LOVE\lovec.exe" .
   ```

   Si la ruta no existe, cambia `C:\Program Files\LOVE` por la carpeta donde instalaste LÖVE. Tambien puedes usar `love .` si lo agregaste al PATH.

**Importante:** usa `lovec.exe` para ver los mensajes `Game Over` y `You Win!` en la terminal. `conf.lua` habilita la consola en Windows.

## Controles

- **Flecha izquierda / A:** mover paddle a la izquierda.
- **Flecha derecha / D:** mover paddle a la derecha.
- **Escape:** salir.
- **R:** reiniciar despues de ganar o perder.

La partida comienza con **3 vidas** y una pelota. El contador de vidas aparece
arriba a la izquierda y el de pelotas activas arriba a la derecha. Una pelota
que toca el fondo desaparece; solo se pierde una vida cuando desaparece la
ultima. Aunque varias caigan en el mismo frame, se descuenta una sola vida.
Si quedan vidas, se crea una pelota con su posicion y velocidad iniciales,
se centra el paddle y se eliminan los poderes que estaban cayendo. Los bloques
destruidos permanecen destruidos.

Al ganar o perder, todas las entidades se detienen y la ventana permanece
abierta. **R** restaura las vidas y todos los bloques, elimina los poderes y
pelotas adicionales, y comienza una partida con una sola pelota. La ventana
solo se cierra manualmente (boton de cierre o **Escape**).

## Power-up MULTIBALL x3

Cada bloque destruido tiene un **15 %** de probabilidad de soltar un rectangulo
amarillo con el texto **x3**. Aparece centrado en el bloque y cae verticalmente;
se recoge con el paddle y desaparece si sale por debajo de la pantalla.

Al recogerlo, cada pelota activa conserva su trayectoria y genera dos copias
con direcciones de aproximadamente **-25 y +25 grados**, conservando su rapidez.
Asi, 1 pelota se convierte en 3, 2 en 6 y 3 en 9. Las copias evitan velocidades
casi nulas en un eje; si la original esta detenida, usan la rapidez inicial.
El limite es de **30 pelotas**: solo se crean las copias que caben.

Un bloque se elimina antes de revisar la siguiente pelota, de modo que no
puede destruirse ni soltar poderes dos veces. La victoria se comprueba al
eliminar el ultimo bloque y tiene prioridad sobre las caidas y la recoleccion
de poderes en ese frame. No se activan poderes en `won` ni en `lost`.

## Estructura

```text
breakout_love2d/
├── conf.lua           Configuracion de ventana y consola
├── main.lua           Entrada y callbacks de LÖVE
├── src/
│   ├── config.lua     Tamaños, velocidades, vidas y parametros de poderes
│   ├── game.lua       Coleccion de pelotas, vidas, efectos, victoria y derrota
│   ├── paddle.lua     Entrada de teclado y paddle
│   ├── ball.lua       Movimiento por delta time y copias con velocidad rotada
│   ├── powerups.lua   Generacion, caida, recoleccion y dibujo de poderes
│   ├── bricks.lua     Crear y dibujar bloques
│   └── collision.lua AABB y rebote contra bloques
├── tests/
│   ├── conf.lua       Ventana del ejecutor de pruebas
│   ├── main.lua       Ejecutor de pruebas con LÖVE
│   └── game_spec.lua  Escenarios de juego y regresiones
└── README.md
```

## Requisitos de la actividad

| Requisito | Solucion |
|---|---|
| Paddle horizontal con teclado | `src/paddle.lua`, `love.keyboard.isDown` |
| Movimiento basado en tiempo | `x = x + velocidad * dt`, `love.update(dt)` |
| Pelota rectangular en movimiento | `src/ball.lua` |
| Varias pelotas independientes, maximo 30 | `self.balls` en `src/game.lua`, `MAX_BALLS` en `src/config.lua` |
| Rebote en paddle, X invertida y mayor velocidad | `src/game.lua` (multiplicador de 1.08 para VX y VY) |
| Rebote en paredes superior y laterales | `src/game.lua` |
| Tres vidas y contador visible | `STARTING_LIVES` en `src/config.lua`, `self.lives` en `src/game.lua` |
| Caida de la ultima pelota | Descontar una vida y reiniciar pelota/paddle sin restaurar bloques |
| Sin vidas: GAME OVER en rojo | Estado `lost`, juego detenido y ventana abierta |
| Bloques eliminados al tocarse | `src/game.lua` y `src/bricks.lua` |
| Poder x3 con probabilidad del 15 % | `src/powerups.lua`, `POWERUP_DROP_CHANCE` en `src/config.lua` |
| Multiplicacion con dispersion de +/-25 grados | `Game:activatePowerup()` y `Ball:cloneRotated()` |
| Sin bloques: YOU WIN! en verde | Estado `won`, juego detenido y ventana abierta |
| R despues de ganar o perder | `main.lua` llama a `Game:reset()` para una partida nueva |

## Como probar

1. Ejecuta el juego. Comprueba que aparezcan `Vidas: 3`, `Pelotas: 1 / 30` y 72 bloques. Mueve el paddle de izquierda a derecha con las flechas o A/D.
2. Observa la pelota. Se mueve independientemente de los FPS gracias a `dt`.
3. Golpea el paddle: la velocidad aumenta y el movimiento horizontal se invierte.
4. Cuando la pelota toca los bloques, desaparecen y el contador baja.
5. **Poder x3:** espera a que caiga un rectangulo amarillo y recogelo con el paddle. Con una pelota aparecen tres; con tres aparecen nueve, siempre segun las que sigan activas al recogerlo. Observa que se separan en direcciones distintas. Un poder que no recoges desaparece al salir por abajo.
6. **Limite:** recoge poderes sucesivos. Si no cae ninguna pelota, el contador pasa por 1, 3, 9, 27 y 30. Recoger mas poderes nunca supera 30.
7. **Caidas:** con varias pelotas, deja caer una. El contador de pelotas baja, pero las vidas no cambian. Cuando cae la ultima, se descuenta una sola vida, se centra el paddle y aparece una pelota con velocidad inicial. Los bloques destruidos no reaparecen y los poderes pendientes desaparecen.
8. **Derrota:** pierde las tres rondas. Aparecen `Vidas: 0`, **GAME OVER** en rojo y `Presiona R para volver a jugar`. La ventana sigue abierta. Las flechas o A/D no mueven el paddle y los poderes quedan detenidos.
9. **Reinicio:** pulsa **R**. Deben volver las 3 vidas, los 72 bloques, una sola pelota con velocidad inicial y el paddle centrado; no quedan poderes ni mensaje. Durante una partida activa, **R** no reinicia.
10. **Victoria:** elimina todos los bloques. Aparecen **YOU WIN!** en verde y `Presiona R para volver a jugar`. Pelotas, poderes y paddle se detienen y la ventana sigue abierta. Pulsa **R** y comprueba el mismo reinicio completo.
11. Cierra la ventana manualmente o pulsa **Escape** para salir.

### Pruebas mas rapidas

Para ver poderes con mas frecuencia, cambia temporalmente
`POWERUP_DROP_CHANCE = 0.15` a `1` en `src/config.lua`. Para probar la victoria
mas rapido, cambia `BRICK_ROWS = 6` a `1`. Restablece ambos valores antes de
ejecutar las pruebas automaticas o jugar con la configuracion original.

### Pruebas automaticas

Desde la carpeta que contiene `main.lua`, ejecuta:

```powershell
& "C:\Program Files\LOVE\lovec.exe" tests
```

No requieren librerias adicionales. Usan los modulos reales y un valor aleatorio
controlado para reproducir los impactos, caidas y recogidas. Los primeros diez
escenarios corresponden a los diez casos solicitados: una caida individual,
caidas con sobrevivientes, caidas simultaneas, 1 -> 3, 3 -> 9, limite de 30,
victoria, derrota, reinicio con la tecla R real y un bloque golpeado por varias
pelotas. Tambien verifican 2 -> 6, prioridad de victoria, probabilidad del 15 %,
limpieza de poderes, recogidas simultaneas, velocidades casi nulas, `dt`, paredes
y aceleracion al tocar el paddle.

El resultado esperado es `PASS: 16 escenarios de Breakout`. Solo el ejecutor de
pruebas termina automaticamente; el juego normal conserva su ventana abierta.

## Conceptos de la clase

- `love.load()` inicializa objetos.
- `love.update(dt)` actualiza posiciones y comprueba colisiones.
- `love.draw()` dibuja en cada frame.
- `love.keypressed(key)` responde a teclas puntuales.
- La deteccion **AABB** comprueba solapamiento entre rectangulos.

Los archivos dentro de `src/` forman un esqueleto modular para extender a un engine mas grande.

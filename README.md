# Breakout Arcade

Videojuego arcade inspirado en Breakout, desarrollado con Lua y LÖVE (Love2D).
Supera 10 niveles progresivos con bloques especiales, power-ups y enfrentamientos contra jefes.
El proyecto utiliza una arquitectura Entity Component System (ECS).

## Video de demostración

[![Ver gameplay de Breakout Arcade](https://img.youtube.com/vi/gDHuYojg3lU/hqdefault.jpg)](https://youtu.be/gDHuYojg3lU)

[Ver el video en YouTube](https://youtu.be/gDHuYojg3lU)

## Cómo ejecutar el juego

1. Descarga e instala [LÖVE](https://love2d.org/).
2. Clona o descarga este repositorio de GitHub.
3. Abre una terminal dentro de la carpeta del proyecto, donde se encuentra `main.lua`.
4. Ejecuta el juego mediante LÖVE.

En Windows, desde PowerShell:

```powershell
& "C:\Program Files\LOVE\lovec.exe" .
```

La ruta puede variar según la instalación. Si LÖVE está agregado al PATH, también puedes ejecutar:

```bash
love .
```

## Controles

| Tecla | Acción |
|---|---|
| A / D o flechas izquierda / derecha | Mover el paddle. |
| Shift + dirección | Acelerar el paddle mientras mantienes las teclas. |
| Espacio | Liberar una pelota magnética; si no hay una capturada, disparar el láser cuando tengas munición. |
| ESC / P | Pausar durante la partida o la presentación de nivel; reanudar desde la pausa. |
| ESC | Volver al menú desde el selector, las opciones, la enciclopedia o las pantallas de resultado. |
| M | Volver al menú; durante una partida, abandonar el intento actual. |
| R | Reiniciar el nivel tras GAME OVER o comenzar una nueva campaña tras YOU WIN! |
| Arriba / abajo o W / S; Enter | Elegir y confirmar opciones del menú. |

Durante la partida, puedes reiniciar el nivel desde el menú de pausa. El menú principal y la enciclopedia también admiten mouse.

## Mecánicas del juego

### Paddle y pelotas

Controla horizontalmente el paddle para mantener las pelotas en juego. La dirección del rebote cambia según el punto de impacto: usa los extremos para apuntar y Shift para moverte más rápido.

### Vidas

Empiezas con tres vidas. Por caída, solo pierdes una cuando desaparece la última pelota activa; los proyectiles enemigos también pueden quitarte una vida. Si quedan vidas, conservas los poderes activos con su duración, munición y usos restantes.

### Niveles

La campaña tiene 10 niveles progresivos con distintas distribuciones, obstáculos móviles, portales y desafíos. Destruye los bloques necesarios para avanzar o derrota al jefe en los niveles que lo incluyen.

### Bloques

- **Normal:** se destruye con un impacto.
- **Resistente:** necesita varios impactos para romperse.
- **Explosivo:** daña los cuatro bloques vecinos en cruz y puede provocar reacciones en cadena.
- **Móvil:** cambia de posición siguiendo un recorrido.
- **Fantasma:** alterna entre sólido e intangible y solo recibe daño cuando es sólido.
- **Blindado:** resiste pelotas normales, pero puede destruirse con fuego, láser o explosiones.
- **Irrompible:** resiste cualquier ataque y sirve como superficie de rebote; no cuenta para completar el nivel.

### Power-ups

- **MULTIBALL x3:** convierte cada pelota en tres, hasta un máximo de 90 pelotas activas.
- **Paddle gigante:** aumenta temporalmente el ancho del paddle.
- **Pelota de fuego:** permite atravesar y dañar bloques destructibles, incluidos los blindados.
- **Cañón láser:** dispara desde el paddle con Espacio y consume munición limitada.
- **Escudo inferior:** devuelve las pelotas que caen mientras conserve tiempo e impactos disponibles.
- **Paddle magnético:** captura una pelota para que puedas liberarla con Espacio desde una mejor posición.
- **Vida extra:** recupera una vida, hasta un máximo de cinco.

### Jefes

El **Guardián mecánico** te espera en el nivel 5 y el **Núcleo del caos** en el nivel 10. Ambos tienen barra de salud, defensas y patrones propios; el Núcleo combina tres fases de ataque y protección. Aprovecha sus puntos débiles frontales o golpea el núcleo superior con una pelota que descienda.

### Puntuación y progreso

Destruir bloques otorga puntos y encadenar destrucciones aumenta el combo. Completa niveles para conseguir estrellas y desbloquear los siguientes; tus récords, estrellas y desbloqueos se guardan automáticamente.

### Enciclopedia

Abre **ENCICLOPEDIA** desde el menú principal para consultar los poderes, bloques, jefes y controles. Navega con teclado o mouse y regresa con ESC sin perder tu progreso guardado.

## Tecnologías

- Lua.
- LÖVE (Love2D).
- Entity Component System (ECS).

La arquitectura ECS organiza el juego en entidades que representan sus elementos, componentes que almacenan sus datos y sistemas que procesan su comportamiento.

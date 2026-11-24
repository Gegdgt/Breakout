# Breakout Básico

Juego clásico en Lua y LÖVE (Love2D). Mueve el paddle para mantener la pelota en juego y destruir las seis filas de bloques de colores.

## Video de la partida

[Ver la partida de Breakout Básico](./gameplay.mp4)

## Requisitos

- Lua, incluido en LÖVE.
- [LÖVE (Love2D) 11.5](https://love2d.org/).

## Cómo jugar

Abre una terminal en la carpeta que contiene el archivo `main.lua`. Ejecuta este comando en PowerShell si instalaste LÖVE en la ubicación predeterminada.

```powershell
& "C:\Program Files\LOVE\lovec.exe" .
```

Si LÖVE está disponible en el PATH, puedes ejecutar `love .` desde esa misma carpeta.

## Controles

- Flecha izquierda o `A` para mover el paddle a la izquierda.
- Flecha derecha o `D` para mover el paddle a la derecha.

## Cómo funciona

Cada intento comienza con una pelota que se mueve automáticamente. El paddle se desplaza de lado a lado en la parte inferior de la ventana. Ambos usan `dt`, el tiempo transcurrido entre fotogramas, para calcular cuánto avanzan.

La pelota rebota en las paredes laterales y superior. Cuando toca el paddle, invierte su velocidad horizontal, acelera un poco y sale hacia arriba.

El tablero tiene 72 bloques distribuidos en seis filas de doce, con un color por fila. Cada golpe elimina un bloque y la pelota rebota de acuerdo con el lado del impacto.

## Fin de la partida

La partida se detiene y el resultado permanece visible en la ventana. Pulsa `Espacio` o `Enter` para volver a jugar.

- Si la pelota toca el borde inferior, aparece `Game Over`. Puedes sacar otra pelota todas las veces que quieras y continuar con los bloques restantes.
- Si destruyes todos los bloques, aparece `You Win!`. La siguiente partida empieza con el tablero completo.

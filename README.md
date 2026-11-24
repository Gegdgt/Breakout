# Breakout Básico

Juego clásico en Lua y LÖVE (Love2D). Mueve el paddle para mantener la pelota en juego y destruir las seis filas de bloques de colores.

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

La pelota se mueve desde el inicio y rebota en las paredes laterales y superior. Al tocar el paddle, invierte su velocidad horizontal, acelera y vuelve hacia arriba. Cada bloque desaparece con un impacto y la pelota rebota según el lado que golpeó. El movimiento de la pelota y del paddle usa el tiempo transcurrido entre fotogramas.

## Fin de la partida

- Si la pelota toca el borde inferior, la terminal muestra `Game Over` y el juego se cierra.
- Si destruyes todos los bloques, la terminal muestra `You Win!` y el juego se cierra.

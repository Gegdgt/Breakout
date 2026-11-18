# Audio original de Breakout Arcade

Los 19 archivos WAV de esta carpeta se compusieron y sintetizaron específicamente
para este proyecto mediante `tools/generate_audio.py`. No contienen grabaciones,
samples, melodías descargadas ni recursos de terceros. Las secuencias de notas,
osciladores y ruido determinista están definidos en ese generador reproducible.

Los archivos de audio generados se ofrecen bajo **CC0 1.0 Universal**: se permite
copiarlos, modificarlos y distribuirlos, incluso comercialmente, sin atribución.
La dedicación corresponde a estos recursos de audio; no cambia la licencia del
resto del repositorio. Texto legal de CC0: https://creativecommons.org/publicdomain/zero/1.0/legalcode

Formato: WAV PCM mono de 16 bits, 22050 Hz. No se necesitan dependencias adicionales.
Regeneración desde la raíz: `python tools/generate_audio.py`.

Música original: `menu.wav` (96 BPM), `level.wav` (120 BPM), `boss.wav` (144 BPM).
Los demás archivos son efectos breves para los eventos del catálogo `src/audio_catalog.lua`.

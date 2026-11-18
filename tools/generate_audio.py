"""Original Breakout Arcade synthesis. Standard library only; no samples or downloads.

The generated WAV assets are dedicated to the public domain under CC0-1.0.
Run from any directory: python tools/generate_audio.py
"""
from array import array
from pathlib import Path
import math
import random
import sys
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"


def frequency(note):
    return 440 * 2 ** ((note - 69) / 12)


def envelope(t, duration, attack=0.006):
    return min(1, t / attack) * max(0, 1 - t / duration) ** 1.6


def oscillator(phase, kind="sine"):
    if kind == "triangle":
        return 2 / math.pi * math.asin(math.sin(phase))
    return math.sin(phase)


def write(name, values):
    peak = max(abs(x) for x in values) or 1
    scale = 0.75 / max(1, peak)
    pcm = array("h", (round(max(-1, min(1, x * scale)) * 32767) for x in values))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(OUT / (name + ".wav")), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())


def chirp(name, start, end, seconds, noise=0, seed=0):
    rng, phase = random.Random(seed), 0
    values = []
    for index in range(round(seconds * RATE)):
        t = index / RATE
        f = start + (end - start) * t / seconds
        phase += 2 * math.pi * f / RATE
        value = (oscillator(phase, "triangle") * (1 - noise) + rng.uniform(-1, 1) * noise)
        values.append(value * envelope(t, seconds))
    write(name, values)


def tune(name, notes, beat):
    duration = (len(notes) + 0.7) * beat
    values = [0.0] * round(duration * RATE)
    for step, note in enumerate(notes):
        start, length = round(step * beat * RATE), beat * 1.6
        for index in range(min(round(length * RATE), len(values) - start)):
            t = index / RATE
            values[start + index] += 0.65 * oscillator(2 * math.pi * frequency(note) * t, "triangle") * envelope(t, length)
    write(name, values)


def music(name, bpm, melody, roots):
    step = 30 / bpm
    duration = len(melody) * step
    values = [0.0] * round(duration * RATE)
    rng = random.Random(7100 + bpm)
    for index, note in enumerate(melody):
        root = roots[(index // 8) % len(roots)]
        start = round(index * step * RATE)
        for sample in range(min(round(step * RATE), len(values) - start)):
            t = sample / RATE
            lead = 0 if note is None else 0.28 * oscillator(2 * math.pi * frequency(note) * t, "triangle") * envelope(t, step)
            bass = 0.30 * math.sin(2 * math.pi * frequency(root) * t) * envelope(t, step)
            harmony = sum(math.sin(2 * math.pi * frequency(root + n + 12) * t) for n in (0, 3, 7))
            pad = 0.045 * harmony * envelope(t, step, 0.03)
            kick = 0.28 * math.sin(2 * math.pi * (75 * t - 45 * t * t / (2 * step))) * math.exp(-t * 26) if index % 4 == 0 else 0
            hat = 0.035 * rng.uniform(-1, 1) * math.exp(-t * 85) if index % 2 else 0
            # Every step begins and ends at zero: seamless loop with no boundary click.
            edge = min(1, t / 0.004, (step - t) / 0.008)
            values[start + sample] += (lead + bass + pad + kick + hat) * max(0, edge)
    write(name, values)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, start, end, seconds, noise in [
        ("paddle", 400, 700, .09, 0), ("wall", 650, 440, .055, 0),
        ("brick", 950, 500, .09, .05), ("resistant", 270, 190, .09, .18),
        ("explosion", 130, 35, .32, .68), ("laser", 1500, 360, .12, .02),
        ("boss_attack", 180, 95, .22, .08), ("boss_hit", 550, 220, .17, .18),
        ("boss_defeat", 240, 35, .65, .45), ("portal", 320, 1300, .22, 0),
        ("ui", 720, 880, .045, 0),
    ]:
        chirp(name, start, end, seconds, noise, sum(map(ord, name)))
    tune("powerup", [76, 81, 88], .085)
    tune("life_lost", [60, 55, 48], .14)
    tune("level_complete", [72, 76, 79, 83, 84], .12)
    tune("game_over", [64, 60, 57, 48], .23)
    tune("victory", [72, 79, 76, 84, 83, 79, 88, 84], .16)
    music("menu", 96, [69, None, 76, 72, 79, 76, None, 72, 67, None, 74, 71, 76, 74, 71, None,
                       65, 72, None, 69, 77, 72, 69, None, 64, 71, 76, None, 74, 71, 67, None], [45, 43, 41, 40])
    music("level", 120, [74, 77, 81, 77, 79, 74, 77, 81, 72, 76, 79, 76, 81, 79, 76, 72,
                         70, 74, 77, 81, 77, 74, 79, 77, 69, 73, 76, 79, 81, 76, 73, 69], [50, 48, 46, 45])
    music("boss", 144, [60, 67, 63, 72, 60, 70, 67, 63, 58, 65, 62, 70, 58, 68, 65, 62,
                        56, 63, 60, 68, 56, 67, 63, 60, 55, 62, 59, 67, 71, 67, 62, 59], [36, 34, 32, 31])
    print(f"Generated 16 effects and 3 music loops in {OUT}")


if __name__ == "__main__":
    main()

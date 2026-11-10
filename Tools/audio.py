#!/usr/bin/env python3
"""Synthesise every sound in Doodle Rescue 3D.

No samples, no third-party audio: all tones are built from sine/noise maths and
written as 16-bit mono WAVs. Run from the project root:

    python3 Tools/audio.py
"""

from __future__ import annotations

import math
import pathlib
import random
import struct
import wave

SR = 22050
ROOT = pathlib.Path(__file__).resolve().parent.parent
SFX = ROOT / "Assets" / "Audio" / "SFX"
MUSIC = ROOT / "Assets" / "Audio" / "Music"
rng = random.Random(7)


def write(path: pathlib.Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(0.001, max(abs(value) for value in samples))
    scale = min(1.0, 0.92 / peak)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        frames = bytearray()
        for value in samples:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, value * scale)) * 32767))
        handle.writeframes(bytes(frames))
    print(f"{path.relative_to(ROOT)}  {path.stat().st_size / 1024:6.1f} KiB")


def blank(seconds: float) -> list[float]:
    return [0.0] * int(SR * seconds)


def add(target: list[float], samples: list[float], at: float = 0.0, gain: float = 1.0) -> None:
    start = int(at * SR)
    for index, value in enumerate(samples):
        position = start + index
        if 0 <= position < len(target):
            target[position] += value * gain


def tone(freq: float, seconds: float, gain: float = 0.5, harmonics: int = 3,
         attack: float = 0.01, release: float = 0.2) -> list[float]:
    length = int(SR * seconds)
    out = []
    for i in range(length):
        t = i / SR
        envelope = min(1.0, t / max(0.001, attack)) * min(1.0, (seconds - t) / max(0.001, release))
        envelope = max(0.0, envelope)
        value = 0.0
        for h in range(1, harmonics + 1):
            value += math.sin(2.0 * math.pi * freq * h * t) / (h * 1.7)
        out.append(value * gain * envelope)
    return out


def noise(seconds: float, gain: float = 0.5, lowpass: float = 0.2,
          attack: float = 0.002, release: float = 0.1) -> list[float]:
    length = int(SR * seconds)
    out = []
    state = 0.0
    for i in range(length):
        t = i / SR
        state += (rng.uniform(-1.0, 1.0) - state) * lowpass
        envelope = min(1.0, t / max(0.001, attack)) * min(1.0, (seconds - t) / max(0.001, release))
        out.append(state * gain * max(0.0, envelope))
    return out


def bell(freq: float, seconds: float, gain: float = 0.4) -> list[float]:
    length = int(SR * seconds)
    out = []
    for i in range(length):
        t = i / SR
        envelope = math.exp(-t * 7.0)
        partials = math.sin(2 * math.pi * freq * t) + 0.5 * math.sin(2 * math.pi * freq * 2.01 * t)
        partials += 0.22 * math.sin(2 * math.pi * freq * 3.97 * t)
        out.append(partials * envelope * gain * min(1.0, t / 0.004))
    return out


def pad(freqs: list[float], seconds: float, gain: float = 0.16) -> list[float]:
    out = blank(seconds)
    for freq in freqs:
        add(out, tone(freq, seconds, gain, harmonics=2, attack=0.8, release=1.0))
    return out


def midi(note: int) -> float:
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


# --------------------------------------------------------------------------
# effects
# --------------------------------------------------------------------------

def effects() -> None:
    write(SFX / "ui_click.wav", tone(880, 0.075, 0.5, 2, 0.004, 0.05))
    write(SFX / "ui_back.wav", tone(520, 0.10, 0.4, 2, 0.004, 0.08))
    write(SFX / "draw.wav", noise(0.36, 0.32, 0.34, 0.01, 0.2))
    scratch = noise(0.22, 0.3, 0.5, 0.002, 0.15)
    add(scratch, tone(240, 0.12, 0.12, 2, 0.002, 0.1), 0.03)
    write(SFX / "snap.wav", scratch)
    pop = tone(620, 0.1, 0.32, 2, 0.002, 0.09)
    add(pop, noise(0.04, 0.15, 0.7), 0.0)
    write(SFX / "place.wav", pop)
    write(SFX / "star.wav", bell(midi(88), 0.5, 0.45))
    write(SFX / "chime.wav", bell(midi(79), 0.7, 0.35))

    win = blank(1.5)
    for index, note in enumerate([72, 76, 79, 84]):
        add(win, bell(midi(note), 0.9, 0.3), index * 0.14)
    add(win, tone(midi(60), 0.9, 0.1, 2, 0.02, 0.8), 0.2)
    write(SFX / "win.wav", win)

    sad = blank(1.1)
    for index, note in enumerate([72, 69, 65, 60]):
        add(sad, tone(midi(note), 0.42, 0.2, 3, 0.01, 0.3), index * 0.16)
    write(SFX / "sad.wav", sad)

    unlock = blank(1.2)
    for index, note in enumerate([79, 83, 86, 91, 95]):
        add(unlock, bell(midi(note), 0.7, 0.24), index * 0.08)
    write(SFX / "unlock.wav", unlock)

    thud = tone(64, 0.32, 0.55, 2, 0.002, 0.28)
    add(thud, noise(0.12, 0.25, 0.1), 0.0)
    write(SFX / "thud.wav", thud)

    wood = blank(0.3)
    add(wood, tone(196, 0.2, 0.4, 4, 0.001, 0.18), 0.0)
    add(wood, noise(0.05, 0.3, 0.35), 0.0)
    write(SFX / "wood.wav", wood)

    metal = blank(0.45)
    for freq in [880, 1320, 1764]:
        add(metal, bell(freq, 0.4, 0.16), 0.0)
    write(SFX / "metal.wav", metal)

    # a loopable bee bed: tremolo saw + air
    seconds = 3.0
    bees = blank(seconds)
    for i in range(len(bees)):
        t = i / SR
        wobble = math.sin(2 * math.pi * 0.35 * t) * 0.5 + 0.5
        value = math.sin(2 * math.pi * (168 + wobble * 10) * t)
        value += 0.4 * math.sin(2 * math.pi * 336 * t)
        bees[i] = value * 0.16 * (0.55 + wobble * 0.45)
    add(bees, noise(seconds, 0.05, 0.06), 0.0)
    write(SFX / "bees.wav", bees)


# --------------------------------------------------------------------------
# music
# --------------------------------------------------------------------------

MEADOW_CHORDS = [[60, 64, 67, 72], [57, 60, 64, 69], [65, 69, 72, 76], [55, 59, 62, 67]]
FOCUS_CHORDS = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]]


def music_bed(name: str, chords: list[list[int]], bpm: float = 84.0, gain: float = 0.5) -> None:
    beat = 60.0 / bpm
    bars = len(chords) * 2
    seconds = bars * 4 * beat
    track = blank(seconds)
    # pad, one chord per half-bar
    for index, chord in enumerate(chords):
        start = index * 8 * beat
        for note in chord:
            add(track, tone(midi(note), 8 * beat + 0.4, 0.055, 2, 0.5, 0.8), start)
    # gentle plucked melody from the pentatonic scale of the current chord
    for bar in range(bars):
        chord = chords[bar % len(chords)]
        for step in range(8):
            if (step + bar) % 3 == 0:
                continue
            note = chord[(step + bar) % len(chord)] + 12
            at = bar * 4 * beat + step * beat * 0.5
            add(track, bell(midi(note), 0.5, 0.07), at)
    # soft heartbeat / shaker
    for beat_index in range(int(bars * 4)):
        at = beat_index * beat
        add(track, noise(0.05, 0.035, 0.25), at)
    # fade edges so the loop point is not a click
    fade = int(SR * 0.05)
    for i in range(fade):
        track[i] *= i / fade
        track[-1 - i] *= i / fade
    write(MUSIC / f"{name}.wav", track)


def main() -> None:
    effects()
    music_bed("meadow", MEADOW_CHORDS, 84.0)
    music_bed("focus", FOCUS_CHORDS, 72.0)
    music_bed("workshop", [[62, 65, 69, 72], [60, 64, 67, 71], [57, 60, 64, 69], [59, 62, 66, 69]], 96.0)


if __name__ == "__main__":
    main()

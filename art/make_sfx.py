"""Scrapyard Derby - sound effects generator.

Makes every game sound from scratch with a tiny retro synth (sine and square
oscillators, noise, pitch sweeps, simple filters and envelopes), so all audio
is original. Standard library only; the same script always writes the same
files (fixed random seed).

    python3 art/make_sfx.py [out_dir]     (default: assets/audio/sfx)

Each sound is a function below; tweak the numbers and re-run.
"""

import math
import os
import random
import struct
import sys
import wave

RATE = 22050  # samples per second; plenty for retro effects, small files
rng = random.Random(7)


# ----------------------------------------------------------------- building blocks
# A "sound" is a plain list of floats in -1..1.

def silence(seconds):
    return [0.0] * int(seconds * RATE)


def tone(seconds, f0, f1=None, wave_type="sine", duty=0.5):
    """An oscillator sweeping (exponentially) from f0 to f1 Hz."""
    f1 = f0 if f1 is None else f1
    n = int(seconds * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / max(1, n - 1)
        freq = f0 * (f1 / f0) ** t
        phase = (phase + freq / RATE) % 1.0
        if wave_type == "sine":
            out.append(math.sin(2 * math.pi * phase))
        elif wave_type == "square":
            out.append(1.0 if phase < duty else -1.0)
        elif wave_type == "saw":
            out.append(2 * phase - 1)
        else:  # triangle
            out.append(4 * abs(phase - 0.5) - 1)
    return out


def noise(seconds):
    return [rng.uniform(-1, 1) for _ in range(int(seconds * RATE))]


def lowpass(samples, cutoff0, cutoff1=None):
    """One-pole low-pass filter; the cutoff can sweep from cutoff0 to cutoff1."""
    cutoff1 = cutoff0 if cutoff1 is None else cutoff1
    out, y, n = [], 0.0, len(samples)
    for i, x in enumerate(samples):
        t = i / max(1, n - 1)
        cutoff = cutoff0 * (cutoff1 / cutoff0) ** t
        a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def envelope(samples, attack=0.005, decay_power=1.0):
    """Quick fade-in, then a fall to zero by the end (higher power = faster)."""
    n = len(samples)
    a = max(1, int(attack * RATE))
    out = []
    for i, x in enumerate(samples):
        if i < a:
            g = i / a
        else:
            g = (1 - (i - a) / max(1, n - a)) ** decay_power
        out.append(x * g)
    return out


def ring(seconds, partials, decay=6.0):
    """Struck metal: a few inharmonic sine partials, each dying away."""
    n = int(seconds * RATE)
    out = [0.0] * n
    for freq, amp in partials:
        for i in range(n):
            t = i / RATE
            out[i] += amp * math.sin(2 * math.pi * freq * t) * math.exp(-decay * t * (freq / 600) ** 0.5)
    return out


def mix(*layers):
    """Adds sounds together, each as (samples, gain, start_seconds)."""
    length = max(int(start * RATE) + len(s) for s, _, start in layers)
    out = [0.0] * length
    for samples, gain, start in layers:
        offset = int(start * RATE)
        for i, x in enumerate(samples):
            out[offset + i] += x * gain
    return out


def seq(*parts):
    out = []
    for p in parts:
        out += p
    return out


def scale(samples, gain):
    return [x * gain for x in samples]


def normalize(samples, peak=0.85):
    top = max(1e-9, max(abs(x) for x in samples))
    return [x * peak / top for x in samples]


def write(path, samples):
    samples = normalize(samples)
    # Tiny fade at both ends so no sound starts or stops with a click.
    fade = min(len(samples) // 2, int(0.003 * RATE))
    for i in range(fade):
        samples[i] *= i / fade
        samples[-1 - i] *= i / fade
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(x * 32767)) for x in samples))


# ----------------------------------------------------------------- the sounds

def land_clean():
    """Springy boing with a bright ting: a good two-foot landing."""
    boing = envelope(tone(0.22, 220, 520, "square", duty=0.3), decay_power=2)
    boing = lowpass(boing, 2500)
    ting = envelope(tone(0.35, 1760), decay_power=3)
    click = envelope(highpass(noise(0.03), 2000), decay_power=2)
    return mix((boing, 0.5, 0), (ting, 0.35, 0.02), (click, 0.3, 0))


def land_onefoot():
    """A clunky thud with a short metal clank."""
    thud = envelope(tone(0.18, 150, 80), decay_power=2)
    dirt = envelope(lowpass(noise(0.15), 900), decay_power=2)
    clank = ring(0.25, [(610, 0.6), (1430, 0.3)], decay=12)
    return mix((thud, 0.8, 0), (dirt, 0.5, 0), (clank, 0.35, 0.01))


def land_crash():
    """Heavy smash: low boom, crunchy noise and rattling scrap."""
    boom = envelope(tone(0.45, 90, 38), decay_power=1.5)
    crunch = envelope(lowpass(noise(0.4), 3000, 400), decay_power=1.6)
    clangs = mix(
        (ring(0.4, [(430, 0.5), (1010, 0.35), (1730, 0.2)], decay=8), 1, 0),
        (ring(0.3, [(780, 0.4), (1950, 0.2)], decay=10), 1, 0.07),
        (ring(0.25, [(520, 0.3), (1320, 0.2)], decay=12), 1, 0.15),
    )
    return mix((boom, 0.9, 0), (crunch, 0.7, 0), (clangs, 0.4, 0.01))


def limb_break():
    """A metal snap and a falling 'bwoop' as a part comes off."""
    snap = envelope(highpass(noise(0.05), 1500), decay_power=3)
    twang = ring(0.6, [(523, 0.5), (1187, 0.35), (1873, 0.25)], decay=5)
    fall = envelope(tone(0.35, 700, 160, "square", duty=0.25), decay_power=1.5)
    fall = lowpass(fall, 1800)
    return mix((snap, 0.8, 0), (twang, 0.45, 0), (fall, 0.3, 0.05))


def rocket_launch():
    """Ignition pop, then a rising rocket whoosh (about the burn length)."""
    pop = envelope(tone(0.12, 160, 60), decay_power=2)
    whoosh = lowpass(noise(1.1), 300, 4000)
    whoosh = envelope(whoosh, attack=0.08, decay_power=1.2)
    whine = envelope(tone(0.9, 220, 880, "saw"), attack=0.05, decay_power=1.5)
    whine = lowpass(whine, 1500)
    return mix((pop, 0.9, 0), (whoosh, 0.8, 0.02), (whine, 0.22, 0.05))


def head_down():
    """The head lands: a dull bonk and a small rattle. The run is over."""
    bonk = envelope(tone(0.25, 260, 70), decay_power=2)
    can = ring(0.5, [(340, 0.5), (905, 0.3), (1480, 0.15)], decay=7)
    dirt = envelope(lowpass(noise(0.2), 700), decay_power=2)
    return mix((bonk, 0.8, 0), (can, 0.4, 0), (dirt, 0.4, 0))


def ui_click():
    """A short, soft blip for buttons."""
    return envelope(lowpass(tone(0.05, 880, 1320, "square", duty=0.25), 3000), decay_power=2)


def ui_buy():
    """Two quick rising notes, like scrap dropping into a till."""
    a = envelope(tone(0.08, 988, wave_type="square", duty=0.25), decay_power=1.5)
    b = envelope(tone(0.22, 1319, wave_type="square", duty=0.25), decay_power=2)
    clink = ring(0.25, [(2637, 0.3), (3950, 0.15)], decay=14)
    return mix((lowpass(seq(a, b), 4000), 0.6, 0), (clink, 0.3, 0.08))


def new_best():
    """A little rising fanfare (C, E, G, high C) with vibrato on the last note."""
    notes = [523.25, 659.25, 783.99]
    out = []
    for f in notes:
        out += envelope(tone(0.1, f, wave_type="square", duty=0.3), decay_power=0.8)
    n = int(0.5 * RATE)
    last, phase = [], 0.0
    for i in range(n):
        freq = 1046.5 * (1 + 0.012 * math.sin(2 * math.pi * 6 * i / RATE))
        phase = (phase + freq / RATE) % 1.0
        last.append(1.0 if phase < 0.3 else -1.0)
    out += envelope(last, attack=0.01, decay_power=1.3)
    return lowpass(out, 3500)


SOUNDS = {
    "land_clean": land_clean,
    "land_onefoot": land_onefoot,
    "land_crash": land_crash,
    "limb_break": limb_break,
    "rocket_launch": rocket_launch,
    "head_down": head_down,
    "ui_click": ui_click,
    "ui_buy": ui_buy,
    "new_best": new_best,
}


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join("assets", "audio", "sfx")
    os.makedirs(out_dir, exist_ok=True)
    for name, make in SOUNDS.items():
        path = os.path.join(out_dir, name + ".wav")
        samples = make()
        write(path, samples)
        print(f"{path}  {len(samples) / RATE:.2f} s")


if __name__ == "__main__":
    main()

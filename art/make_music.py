"""Scrapyard Derby - background music generator.

Composes and synthesizes the game's music loop from scratch: an original
calm "dusk over the scrapyard" piece for the floaty flow of a run. Standard
library only; the same script always writes the same file.

    python3 art/make_music.py [out_dir]     (default: assets/audio/music)

The piece is 16 bars at 88 BPM (about 44 s):
  bars 1-8   pad chords, echoing arpeggio, bass, light drums
  bars 9-16  the same, plus a lead melody
Every note that rings past the end wraps around to the start, so the file
loops seamlessly.

To change the music, edit the CHORDS / MELODY tables or the voices below.
"""

import math
import os
import random
import struct
import sys
import wave

RATE = 22050
BPM = 88
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 16
LENGTH = int(round(BARS * BAR * RATE))  # samples in one loop
rng = random.Random(11)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# ----------------------------------------------------------------- the score
# MIDI note numbers: 57 = A3, 60 = C4 (middle C), 69 = A4.

# One chord per bar: (bass note, chord notes for pad and arpeggio).
CHORDS = [
    (45, [57, 60, 64, 67, 71]),  # Am9
    (41, [53, 57, 60, 64]),      # Fmaj7
    (48, [55, 60, 64, 71]),      # Cmaj7
    (43, [55, 59, 62, 64]),      # G6
    (45, [57, 60, 64, 67, 71]),  # Am9
    (41, [53, 57, 60, 64]),      # Fmaj7
    (50, [62, 65, 69, 72, 64]),  # Dm9
    (40, [52, 57, 59, 62]),      # E7sus4, leading back to Am
] * 2

# Lead melody for bars 9-16: (bar, beat in bar, length in beats, note).
MELODY = [
    (8, 0, 1.5, 76), (8, 1.5, 0.5, 74), (8, 2, 1, 72), (8, 3, 1, 71),
    (9, 0, 2, 69), (9, 2, 1, 72), (9, 3, 1, 76),
    (10, 0, 1.5, 79), (10, 1.5, 0.5, 76), (10, 2, 2, 74),
    (11, 0, 1, 71), (11, 1, 1, 74), (11, 2, 2, 76),
    (12, 0, 1, 76), (12, 1, 0.5, 79), (12, 1.5, 1.5, 81), (12, 3, 1, 79),
    (13, 0, 1, 76), (13, 1, 1, 72), (13, 2, 2, 69),
    (14, 0, 1.5, 77), (14, 1.5, 0.5, 76), (14, 2, 1, 74), (14, 3, 1, 72),
    (15, 0, 3, 71),
]

# Arpeggio: which chord note plays on each 8th note of a bar (0 = lowest).
ARP_PATTERN = [0, 1, 2, 3, 2, 1, 2, 3]


# ----------------------------------------------------------------- mixing helpers

def add(buf, start_seconds, samples, gain):
    """Adds a note into the loop buffer, wrapping past the end to the start."""
    start = int(start_seconds * RATE)
    n = len(buf)
    for i, x in enumerate(samples):
        buf[(start + i) % n] += x * gain


def lowpass(samples, cutoff):
    a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def adsr(n, attack, release, sustain_until):
    """Gain per sample: rise over attack, hold, then fade over release."""
    a, r, s = int(attack * RATE), int(release * RATE), int(sustain_until * RATE)
    out = []
    for i in range(n):
        if i < a:
            g = i / max(1, a)
        elif i < s:
            g = 1.0
        else:
            g = max(0.0, 1 - (i - s) / max(1, r))
        out.append(g)
    return out


def osc(freq, n, shape, phase=0.0, vibrato=0.0, vibrato_delay=0.0):
    out = []
    for i in range(n):
        t = i / RATE
        f = freq
        if vibrato and t > vibrato_delay:
            f *= 1 + vibrato * math.sin(2 * math.pi * 5.2 * t)
        phase = (phase + f / RATE) % 1.0
        if shape == "sine":
            out.append(math.sin(2 * math.pi * phase))
        elif shape == "triangle":
            out.append(4 * abs(phase - 0.5) - 1)
        else:  # square, 25% duty: softer and hollower than 50%
            out.append(1.0 if phase < 0.25 else -1.0)
    return out


# ----------------------------------------------------------------- voices

def pad(note, seconds):
    """Warm chord pad: two slightly detuned triangles and a sine, slow swell."""
    release = 1.2
    n = int((seconds + release) * RATE)
    f = hz(note)
    a = osc(f * 1.003, n, "triangle", rng.random())
    b = osc(f * 0.997, n, "triangle", rng.random())
    c = osc(f, n, "sine")
    env = adsr(n, 0.7, release, seconds)
    return lowpass([(x + y + 0.8 * z) * g for x, y, z, g in zip(a, b, c, env)], 1400)


def arp(note):
    """A soft plucky square for the arpeggio."""
    seconds = BEAT * 0.9
    n = int(seconds * RATE)
    tone = osc(hz(note), n, "square")
    return lowpass([x * math.exp(-i / RATE * 7) for i, x in enumerate(tone)], 1700)


def bass(note, seconds):
    n = int(seconds * RATE)
    f = hz(note)
    tri = osc(f, n, "triangle")
    sub = osc(f / 2, n, "sine")
    env = adsr(n, 0.01, 0.25, seconds - 0.25)
    return lowpass([(0.7 * x + 0.6 * y) * g for x, y, g in zip(tri, sub, env)], 600)


def lead(note, beats):
    """Flute-ish lead: sine plus a little triangle, with a gentle vibrato."""
    seconds = beats * BEAT
    release = 0.35
    n = int((seconds + release) * RATE)
    f = hz(note)
    s = osc(f, n, "sine", vibrato=0.006, vibrato_delay=0.18)
    t = osc(f, n, "triangle", vibrato=0.006, vibrato_delay=0.18)
    env = adsr(n, 0.04, release, seconds * 0.92)
    return lowpass([(x + 0.25 * y) * g for x, y, g in zip(s, t, env)], 2600)


def kick():
    n = int(0.25 * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = 45 + 70 * math.exp(-t * 30)
        phase = (phase + f / RATE) % 1.0
        out.append(math.sin(2 * math.pi * phase) * math.exp(-t * 14))
    return out


def hat():
    n = int(0.05 * RATE)
    noise = highpass([rng.uniform(-1, 1) for _ in range(n)], 6000)
    return [x * math.exp(-i / RATE * 90) for i, x in enumerate(noise)]


def snare():
    """A soft, brushed lo-fi snare."""
    n = int(0.18 * RATE)
    noise = highpass(lowpass([rng.uniform(-1, 1) for _ in range(n)], 3500), 400)
    body = osc(190, n, "sine")
    return [
        (0.8 * x + 0.3 * y) * math.exp(-i / RATE * 22)
        for i, (x, y) in enumerate(zip(noise, body))
    ]


def echo(buf, delay_seconds, feedback, passes=3):
    """Looping echo: repeats wrap around, so the loop point stays seamless."""
    d = int(delay_seconds * RATE)
    n = len(buf)
    out = buf[:]
    tap = buf[:]
    for _ in range(passes):
        tap = [tap[(i - d) % n] * feedback for i in range(n)]
        out = [o + t for o, t in zip(out, tap)]
    return out


# ----------------------------------------------------------------- arrangement

def compose():
    pads = [0.0] * LENGTH
    arps = [0.0] * LENGTH
    basses = [0.0] * LENGTH
    leads = [0.0] * LENGTH
    drums = [0.0] * LENGTH

    k, h, s = kick(), hat(), snare()
    for bar, (root, chord) in enumerate(CHORDS):
        t0 = bar * BAR
        for note in chord:
            add(pads, t0, pad(note, BAR), 0.10)
        # Arpeggio an octave up, 8th notes, a little quieter on the off-beats.
        for step, index in enumerate(ARP_PATTERN):
            note = chord[index % len(chord)] + 12
            add(arps, t0 + step * BEAT / 2, arp(note), 0.16 if step % 2 == 0 else 0.11)
        # Bass: root on beat 1 and a push on the "and" of beat 3.
        add(basses, t0, bass(root, BEAT * 2.4), 0.5)
        add(basses, t0 + 2.5 * BEAT, bass(root, BEAT * 1.3), 0.35)
        # Drums: kick on 1 and the "and" of 3, soft snare on 2 and 4,
        # off-beat hats. The first two bars of the loop are lighter.
        light = bar < 2
        add(drums, t0, k, 0.55)
        add(drums, t0 + 2.5 * BEAT, k, 0.4)
        if not light:
            add(drums, t0 + BEAT, s, 0.22)
            add(drums, t0 + 3 * BEAT, s, 0.22)
        for beat in range(4):
            add(drums, t0 + (beat + 0.5) * BEAT, h, 0.12 if not light else 0.06)

    for bar, beat, length, note in MELODY:
        add(leads, bar * BAR + beat * BEAT, lead(note, length), 0.22)

    arps = echo(arps, BEAT * 0.75, 0.35)
    leads = echo(leads, BEAT * 0.75, 0.2, passes=2)

    mix = [p + a + b + l + d for p, a, b, l, d in zip(pads, arps, basses, leads, drums)]
    # A gentle low-pass over everything for a warm, slightly lo-fi tone.
    # Run it twice around the loop so the filter has settled at the seam.
    warm = lowpass(mix + mix, 5000)[LENGTH:]
    peak = max(abs(x) for x in warm)
    return [x * 0.8 / peak for x in warm]


def write(path, samples):
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(x * 32767)) for x in samples))


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join("assets", "audio", "music")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "scrapyard_dusk.wav")
    samples = compose()
    write(path, samples)
    print(f"{path}  {len(samples) / RATE:.1f} s")


if __name__ == "__main__":
    main()

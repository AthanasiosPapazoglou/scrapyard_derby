"""Scrapyard Derby - background music generator.

Composes and synthesizes the game's music from scratch: one original loop
per level, from the calm "dusk over the scrapyard" of level 1 to the slow,
menacing drone of level 6. Standard library only; the same script always
writes the same files.

    python3 art/make_music.py [out_dir]     (default: assets/audio/music)

Every track is 16 bars:
  bars 1-8   pad chords, arpeggio, bass, drums
  bars 9-16  the same, plus a lead melody
Every note that rings past the end wraps around to the start, so the files
loop seamlessly.

A track is a dict in TRACKS (tempo, chords, melody and the style of each
voice); the defaults are the level 1 sound. To change the music, edit the
tables there or the voices below.
"""

import math
import os
import random
import struct
import sys
import wave

RATE = 22050
BARS = 16
rng = random.Random(11)

# Set per track by set_tempo().
BPM = 88
BEAT = 60 / BPM
BAR = 4 * BEAT
LENGTH = int(round(BARS * BAR * RATE))  # samples in one loop


def set_tempo(bpm):
    global BPM, BEAT, BAR, LENGTH
    BPM = bpm
    BEAT = 60 / BPM
    BAR = 4 * BEAT
    LENGTH = int(round(BARS * BAR * RATE))


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# ----------------------------------------------------------------- the score
# MIDI note numbers: 57 = A3, 60 = C4 (middle C), 69 = A4.

# Level 1, "Scrapyard Dusk", 88 BPM, A minor.
# One chord per bar: (bass note, chord notes for pad and arpeggio).
DUSK_CHORDS = [
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
DUSK_MELODY = [
    (8, 0, 1.5, 76), (8, 1.5, 0.5, 74), (8, 2, 1, 72), (8, 3, 1, 71),
    (9, 0, 2, 69), (9, 2, 1, 72), (9, 3, 1, 76),
    (10, 0, 1.5, 79), (10, 1.5, 0.5, 76), (10, 2, 2, 74),
    (11, 0, 1, 71), (11, 1, 1, 74), (11, 2, 2, 76),
    (12, 0, 1, 76), (12, 1, 0.5, 79), (12, 1.5, 1.5, 81), (12, 3, 1, 79),
    (13, 0, 1, 76), (13, 1, 1, 72), (13, 2, 2, 69),
    (14, 0, 1.5, 77), (14, 1.5, 0.5, 76), (14, 2, 1, 74), (14, 3, 1, 72),
    (15, 0, 3, 71),
]

# Arpeggio: which chord note plays on each step of a bar (0 = lowest).
DUSK_ARP = [0, 1, 2, 3, 2, 1, 2, 3]

# Levels 2-6: darker keys, slower or harder grooves, rougher voices.
CINDER_CHORDS = [
    (38, [50, 53, 57, 60, 64]),  # Dm9
    (34, [46, 50, 53, 57]),      # Bbmaj7
    (43, [55, 58, 62, 65, 69]),  # Gm9
    (45, [57, 62, 64, 67]),      # A7sus4
    (38, [50, 53, 57, 60, 64]),  # Dm9
    (34, [46, 50, 53, 57]),      # Bbmaj7
    (40, [52, 55, 58, 62]),      # Em7b5
    (45, [57, 61, 64, 67]),      # A7
] * 2
CINDER_MELODY = [
    (8, 0, 1.5, 74), (8, 1.5, 0.5, 72), (8, 2, 2, 69),
    (9, 0, 1, 70), (9, 1, 1, 69), (9, 2, 2, 65),
    (10, 0, 1.5, 67), (10, 1.5, 0.5, 69), (10, 2, 1, 70), (10, 3, 1, 74),
    (11, 0, 3, 73), (11, 3, 1, 69),
    (12, 0, 1.5, 74), (12, 1.5, 0.5, 76), (12, 2, 2, 77),
    (13, 0, 1, 74), (13, 1, 1, 70), (13, 2, 2, 69),
    (14, 0, 1, 67), (14, 1, 1, 70), (14, 2, 1, 69), (14, 3, 1, 67),
    (15, 0, 3, 69),
]

SMOG_CHORDS = [
    (40, [52, 55, 59, 66]),  # Em(add9)
    (41, [53, 57, 60, 64]),  # Fmaj7 (the dark flat second)
    (40, [52, 55, 59, 64]),  # Em
    (40, [50, 53, 57, 62]),  # Dm over E
    (36, [48, 55, 59, 64]),  # Cmaj7
    (41, [53, 57, 59, 64]),  # Fmaj7#11
    (45, [57, 60, 64, 67]),  # Am7
    (47, [59, 63, 66, 69]),  # B7
] * 2
SMOG_MELODY = [
    (8, 0, 2, 71), (8, 2, 2, 72), (9, 0, 4, 71),
    (10, 0, 2, 67), (10, 2, 1, 69), (10, 3, 1, 71), (11, 0, 4, 69),
    (12, 0, 2, 72), (12, 2, 2, 71), (13, 0, 2, 69), (13, 2, 2, 67),
    (14, 0, 2, 65), (14, 2, 2, 64), (15, 0, 4, 63),
]

STORM_CHORDS = [
    (36, [48, 51, 55, 60]),  # Cm
    (32, [44, 48, 51, 56]),  # Ab
    (41, [53, 56, 60, 65]),  # Fm
    (43, [55, 59, 62, 67]),  # G
    (36, [48, 51, 55, 60]),  # Cm
    (32, [44, 48, 51, 56]),  # Ab
    (39, [51, 55, 58, 63]),  # Eb
    (43, [55, 59, 62, 65]),  # G7
] * 2
STORM_MELODY = [
    (8, 0, 1, 72), (8, 1, 1, 75), (8, 2, 1, 79), (8, 3, 1, 75),
    (9, 0, 2, 80), (9, 2, 2, 79),
    (10, 0, 1, 77), (10, 1, 1, 75), (10, 2, 2, 72),
    (11, 0, 3, 74), (11, 3, 1, 71),
    (12, 0, 1, 72), (12, 1, 1, 75), (12, 2, 1, 79), (12, 3, 1, 84),
    (13, 0, 2, 80), (13, 2, 2, 79),
    (14, 0, 1, 75), (14, 1, 1, 74), (14, 2, 2, 72),
    (15, 0, 2, 71), (15, 2, 2, 67),
]

FURNACE_CHORDS = [
    (42, [54, 57, 61, 66]),  # F#m
    (43, [55, 59, 62, 67]),  # G (flat second)
    (42, [54, 57, 61, 66]),  # F#m
    (38, [50, 54, 57, 62]),  # D
    (35, [47, 50, 54, 59]),  # Bm
    (43, [55, 59, 62, 67]),  # G
    (37, [49, 53, 56, 59]),  # C#7
    (37, [49, 53, 56, 59]),  # C#7
] * 2
FURNACE_MELODY = [
    (8, 0, 2, 66), (8, 2, 2, 67), (9, 0, 4, 66),
    (10, 0, 1, 69), (10, 1, 1, 67), (10, 2, 2, 66), (11, 0, 4, 64),
    (12, 0, 2, 66), (12, 2, 2, 67), (13, 0, 2, 69), (13, 2, 2, 71),
    (14, 0, 2, 67), (14, 2, 2, 65), (15, 0, 4, 66),
]

OBSIDIAN_CHORDS = [
    (35, [47, 50, 54, 59]),  # Bm
    (36, [48, 52, 55, 60]),  # C (flat second)
    (35, [47, 50, 54, 59]),  # Bm
    (41, [53, 57, 60, 65]),  # F (the tritone)
    (35, [47, 50, 54, 59]),  # Bm
    (36, [48, 52, 55, 60]),  # C
    (35, [46, 50, 55, 58]),  # Gm over B
    (41, [53, 57, 60, 65]),  # F
] * 2
OBSIDIAN_MELODY = [
    (8, 0, 3, 71), (8, 3, 1, 72), (9, 0, 4, 65),
    (10, 0, 2, 71), (10, 2, 2, 74), (11, 0, 4, 72),
    (12, 0, 2, 77), (12, 2, 2, 76), (13, 0, 4, 71),
    (14, 0, 2, 72), (14, 2, 2, 65), (15, 0, 4, 71),
]

# One track per level, in order. Missing keys use DEFAULTS (level 1).
DEFAULTS = {
    "seed": 11,
    "arp_pattern": DUSK_ARP,
    "arp_steps": 8,          # arpeggio notes per bar
    "arp_voice": "pluck",    # pluck | triangle | bell
    "lead_voice": "flute",   # flute | square | bell | low
    "bass_style": "push",    # push | pulse | drone | grit
    "drums": "lofi",         # lofi | sparse | driving | toms | heartbeat
    "pad_cutoff": 1400,
    "pad_attack": 0.7,
    "warmth": 5000,          # final low-pass over the whole mix
}
TRACKS = [
    {"file": "scrapyard_dusk.wav", "bpm": 88,
     "chords": DUSK_CHORDS, "melody": DUSK_MELODY},
    {"file": "cinder_wind.wav", "bpm": 84, "seed": 12,
     "chords": CINDER_CHORDS, "melody": CINDER_MELODY,
     "arp_pattern": [0, 2, 1, 3, 2, 1, 3, 2], "pad_cutoff": 1200,
     "warmth": 4200},
    {"file": "smog_lanterns.wav", "bpm": 76, "seed": 13,
     "chords": SMOG_CHORDS, "melody": SMOG_MELODY,
     "arp_pattern": [0, 2, 1, 3], "arp_steps": 4, "arp_voice": "triangle",
     "lead_voice": "low", "bass_style": "drone", "drums": "sparse",
     "pad_cutoff": 900, "pad_attack": 1.2, "warmth": 3200},
    {"file": "crusher_storm.wav", "bpm": 96, "seed": 14,
     "chords": STORM_CHORDS, "melody": STORM_MELODY,
     "arp_pattern": [0, 2, 3, 2, 0, 2, 3, 2], "lead_voice": "square",
     "bass_style": "pulse", "drums": "driving", "pad_cutoff": 1100,
     "warmth": 4500},
    {"file": "furnace_heart.wav", "bpm": 74, "seed": 15,
     "chords": FURNACE_CHORDS, "melody": FURNACE_MELODY,
     "arp_pattern": [0, 1, 0, 2], "arp_steps": 4, "arp_voice": "triangle",
     "lead_voice": "low", "bass_style": "grit", "drums": "toms",
     "pad_cutoff": 800, "pad_attack": 1.0, "warmth": 3000},
    {"file": "obsidian_maw.wav", "bpm": 66, "seed": 16,
     "chords": OBSIDIAN_CHORDS, "melody": OBSIDIAN_MELODY,
     "arp_pattern": [0, 3, 1, 2], "arp_steps": 4, "arp_voice": "bell",
     "lead_voice": "bell", "bass_style": "drone", "drums": "heartbeat",
     "pad_cutoff": 700, "pad_attack": 1.5, "warmth": 2600},
]


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

def pad(note, seconds, cutoff=1400, attack=0.7):
    """Warm chord pad: two slightly detuned triangles and a sine, slow swell."""
    release = 1.2
    n = int((seconds + release) * RATE)
    f = hz(note)
    a = osc(f * 1.003, n, "triangle", rng.random())
    b = osc(f * 0.997, n, "triangle", rng.random())
    c = osc(f, n, "sine")
    env = adsr(n, attack, release, seconds)
    return lowpass([(x + y + 0.8 * z) * g for x, y, z, g in zip(a, b, c, env)], cutoff)


def arp(note, voice="pluck", seconds=None):
    """The arpeggio: a soft plucky square, a hollow triangle, or a cold bell."""
    seconds = seconds or BEAT * 0.9
    n = int(seconds * RATE)
    if voice == "bell":
        return bell(note, seconds)
    tone = osc(hz(note), n, "square" if voice == "pluck" else "triangle")
    return lowpass([x * math.exp(-i / RATE * 7) for i, x in enumerate(tone)], 1700)


def bell(note, seconds):
    """A cold bell: a sine plus an out-of-tune partial, long ring."""
    n = int((seconds + 1.0) * RATE)
    f = hz(note)
    a = osc(f, n, "sine")
    b = osc(f * 2.76, n, "sine")
    return [
        (x + 0.35 * y * math.exp(-i / RATE * 3)) * math.exp(-i / RATE * 1.6)
        for i, (x, y) in enumerate(zip(a, b))
    ]


def bass(note, seconds, grit=False):
    """Triangle bass with a sub; [grit] squares and clips it, like a furnace."""
    n = int(seconds * RATE)
    f = hz(note)
    tri = osc(f, n, "square" if grit else "triangle")
    sub = osc(f / 2, n, "sine")
    env = adsr(n, 0.01, 0.25, seconds - 0.25)
    mix = [(0.7 * x + 0.6 * y) * g for x, y, g in zip(tri, sub, env)]
    if grit:
        mix = [math.tanh(2.5 * x) * 0.6 for x in mix]
    return lowpass(mix, 600)


def lead(note, beats, voice="flute"):
    """The lead: flute-ish (sine and triangle, gentle vibrato), a harsh
    square, a low wavering sine, or a bell."""
    seconds = beats * BEAT
    if voice == "bell":
        return bell(note, seconds)
    release = 0.35
    n = int((seconds + release) * RATE)
    f = hz(note)
    if voice == "square":
        s = osc(f, n, "square", vibrato=0.004, vibrato_delay=0.1)
        t = osc(f * 1.005, n, "square")
        env = adsr(n, 0.01, release, seconds * 0.9)
        return lowpass([(0.5 * x + 0.3 * y) * g for x, y, g in zip(s, t, env)], 2200)
    if voice == "low":
        s = osc(f, n, "sine", vibrato=0.015, vibrato_delay=0.3)
        t = osc(f, n, "triangle", vibrato=0.015, vibrato_delay=0.3)
        env = adsr(n, 0.25, release, seconds * 0.92)
        return lowpass([(x + 0.4 * y) * g for x, y, g in zip(s, t, env)], 1500)
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


def tom(freq):
    """A deep hand drum / tom."""
    n = int(0.45 * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = freq * (1 + 0.6 * math.exp(-t * 25))
        phase = (phase + f / RATE) % 1.0
        out.append(math.sin(2 * math.pi * phase) * math.exp(-t * 7))
    return out


def clank():
    """A metal hit: a few inharmonic sines, quick decay."""
    n = int(0.6 * RATE)
    partials = [(523, 1.0), (1311, 0.6), (2087, 0.4), (3170, 0.25)]
    tones = [osc(f, n, "sine") for f, _ in partials]
    return [
        sum(g * t[i] for (_, g), t in zip(partials, tones)) * math.exp(-i / RATE * 9)
        for i in range(n)
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

def compose(track):
    t = dict(DEFAULTS, **track)
    set_tempo(t["bpm"])
    rng.seed(t["seed"])
    pads = [0.0] * LENGTH
    arps = [0.0] * LENGTH
    basses = [0.0] * LENGTH
    leads = [0.0] * LENGTH
    drums = [0.0] * LENGTH

    k, h, s = kick(), hat(), snare()
    style = t["drums"]
    extra = {}
    if style == "driving":
        extra["clank"] = clank()
    if style == "toms":
        extra["tom"], extra["low_tom"], extra["clank"] = tom(110), tom(70), clank()
    if style == "heartbeat":
        extra["boom"] = tom(45)

    steps = t["arp_steps"]
    for bar, (root, chord) in enumerate(t["chords"]):
        t0 = bar * BAR
        for note in chord:
            add(pads, t0, pad(note, BAR, t["pad_cutoff"], t["pad_attack"]), 0.10)
        # Arpeggio an octave up; a little quieter on the off-steps.
        step_len = BAR / steps
        for step in range(steps):
            index = t["arp_pattern"][step % len(t["arp_pattern"])]
            note = chord[index % len(chord)] + 12
            voice = t["arp_voice"]
            sound = arp(note) if voice == "pluck" else arp(note, voice, step_len * 0.95)
            gain = 0.16 if step % 2 == 0 else 0.11
            if voice == "bell":
                gain *= 0.8
            add(arps, t0 + step * step_len, sound, gain)
        add_bass(basses, t0, root, t["bass_style"])
        add_drums(drums, bar, t0, style, k, h, s, extra)

    for bar, beat, length, note in t["melody"]:
        add(leads, bar * BAR + beat * BEAT, lead(note, length, t["lead_voice"]), 0.22)

    arps = echo(arps, BEAT * 0.75, 0.35)
    leads = echo(leads, BEAT * 0.75, 0.2, passes=2)

    mix = [p + a + b + l + d for p, a, b, l, d in zip(pads, arps, basses, leads, drums)]
    # A gentle low-pass over everything for a warm, slightly lo-fi tone
    # (darker on later levels). Run it twice around the loop so the filter
    # has settled at the seam.
    warm = lowpass(mix + mix, t["warmth"])[LENGTH:]
    peak = max(abs(x) for x in warm)
    return [x * 0.8 / peak for x in warm]


def add_bass(basses, t0, root, style):
    if style == "push":
        # Root on beat 1 and a push on the "and" of beat 3.
        add(basses, t0, bass(root, BEAT * 2.4), 0.5)
        add(basses, t0 + 2.5 * BEAT, bass(root, BEAT * 1.3), 0.35)
    elif style == "pulse":
        # Driving 8th notes, accents on the beat.
        for step in range(8):
            add(basses, t0 + step * BEAT / 2, bass(root, BEAT * 0.45),
                0.42 if step % 2 == 0 else 0.3)
    elif style == "drone":
        add(basses, t0, bass(root, BAR * 1.02), 0.45)
    else:  # grit: a held, clipped root with a stab on beat 3
        add(basses, t0, bass(root, BEAT * 2.2, grit=True), 0.45)
        add(basses, t0 + 2 * BEAT, bass(root, BEAT * 1.8, grit=True), 0.35)


def add_drums(drums, bar, t0, style, k, h, s, extra):
    light = bar < 2  # the first two bars of each loop are lighter
    if style == "lofi":
        # Kick on 1 and the "and" of 3, soft snare on 2 and 4, off-beat hats.
        add(drums, t0, k, 0.55)
        add(drums, t0 + 2.5 * BEAT, k, 0.4)
        if not light:
            add(drums, t0 + BEAT, s, 0.22)
            add(drums, t0 + 3 * BEAT, s, 0.22)
        for beat in range(4):
            add(drums, t0 + (beat + 0.5) * BEAT, h, 0.12 if not light else 0.06)
    elif style == "sparse":
        # A slow kick and a faint tick: footsteps in the fog.
        add(drums, t0, k, 0.5)
        add(drums, t0 + 2 * BEAT, k, 0.25)
        for beat in (1, 3):
            add(drums, t0 + beat * BEAT, h, 0.08)
    elif style == "driving":
        add(drums, t0, k, 0.6)
        add(drums, t0 + 0.5 * BEAT, k, 0.3)
        add(drums, t0 + 2 * BEAT, k, 0.55)
        add(drums, t0 + BEAT, s, 0.32)
        add(drums, t0 + 3 * BEAT, s, 0.32)
        for step in range(8):
            add(drums, t0 + step * BEAT / 2, h, 0.13 if step % 2 else 0.08)
        if bar % 2 == 0 and not light:
            add(drums, t0, extra["clank"], 0.16)
    elif style == "toms":
        # Furnace hammering: kick, toms, a metal hit on 4.
        add(drums, t0, k, 0.6)
        add(drums, t0 + 1.5 * BEAT, k, 0.4)
        add(drums, t0 + 2 * BEAT, extra["tom"], 0.35)
        add(drums, t0 + 2.5 * BEAT, extra["low_tom"], 0.35)
        if not light:
            add(drums, t0 + 3 * BEAT, extra["clank"], 0.14)
    else:  # heartbeat: a slow double thump, a deep boom every 4 bars
        add(drums, t0, k, 0.6)
        add(drums, t0 + 0.35 * BEAT, k, 0.45)
        add(drums, t0 + 2 * BEAT, k, 0.5)
        add(drums, t0 + 2.35 * BEAT, k, 0.35)
        if bar % 4 == 0:
            add(drums, t0, extra["boom"], 0.4)


def write(path, samples):
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(x * 32767)) for x in samples))


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join("assets", "audio", "music")
    os.makedirs(out_dir, exist_ok=True)
    for track in TRACKS:
        path = os.path.join(out_dir, track["file"])
        samples = compose(track)
        write(path, samples)
        print(f"{path}  {track['bpm']} BPM  {len(samples) / RATE:.1f} s")


if __name__ == "__main__":
    main()

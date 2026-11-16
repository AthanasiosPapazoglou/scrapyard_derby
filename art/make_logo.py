"""Scrapyard Derby - the title logo.

Chunky scrap-metal lettering, drawn as thick rounded "tubes" (no fonts):
every letter has an ink outline, a dark drop-shadow, a highlight streak and
a rivet, and is tilted and nudged a little so the title looks hand-cut from
scrap. SCRAPYARD in hazard yellow on top; DERBY in rust on a bolted steel
banner, with a gear and a lightning bolt.

    python3 art/make_logo.py [out_dir]      (default: assets/logo)

Writes `logo.svg`. Standard library only; the same script always writes the
same file (fixed random seed). Colours follow the game palette.
"""

import math
import os
import random
import sys

INK = "#2B1D16"
RUST = "#C4622D"
RUST_D = "#8A3B1C"
RUST_L = "#E39056"
STEEL = "#6B7B8C"
STEEL_D = "#4A5563"
STEEL_L = "#B4C0CB"
HAZ = "#F2B233"
HAZ_D = "#B97F14"
HAZ_L = "#FFD873"
GLOW = "#5FE3D0"

rng = random.Random(11)

# Letters on a 4 x 6 grid (x right, y down), as polylines.
LETTERS = {
    "S": [[(4, .6), (3.4, 0), (.6, 0), (0, .6), (0, 2.4), (.6, 3), (3.4, 3),
           (4, 3.6), (4, 5.4), (3.4, 6), (.6, 6), (0, 5.4)]],
    "C": [[(4, .6), (3.4, 0), (.6, 0), (0, .6), (0, 5.4), (.6, 6), (3.4, 6),
           (4, 5.4)]],
    "R": [[(0, 6), (0, 0), (3.4, 0), (4, .6), (4, 2.4), (3.4, 3), (0, 3)],
          [(2, 3), (4, 6)]],
    "A": [[(0, 6), (0, 1.2), (1.2, 0), (2.8, 0), (4, 1.2), (4, 6)],
          [(0, 3.4), (4, 3.4)]],
    "P": [[(0, 6), (0, 0), (3.4, 0), (4, .6), (4, 2.4), (3.4, 3), (0, 3)]],
    "Y": [[(0, 0), (2, 3), (4, 0)], [(2, 3), (2, 6)]],
    "D": [[(0, 0), (0, 6), (2.6, 6), (4, 4.6), (4, 1.4), (2.6, 0), (0, 0)]],
    "E": [[(4, 0), (0, 0), (0, 6), (4, 6)], [(0, 3), (3, 3)]],
    "B": [[(0, 0), (0, 6), (3.3, 6), (4, 5.3), (4, 3.7), (3.3, 3), (0, 3)],
          [(0, 0), (3, 0), (3.6, .6), (3.6, 2.4), (3, 3)]],
}


def poly(points, ox=0.0, oy=0.0):
    return " ".join(f"{x + ox:.1f},{y + oy:.1f}" for x, y in points)


def tube(points, color, width, ox=0.0, oy=0.0, opacity=1.0):
    extra = f' stroke-opacity="{opacity}"' if opacity < 1 else ""
    return (f'<polyline points="{poly(points, ox, oy)}" fill="none" '
            f'stroke="{color}" stroke-width="{width:.1f}" '
            f'stroke-linecap="round" stroke-linejoin="round"{extra}/>')


def rivet(x, y, r=3.2):
    return (f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{STEEL_L}" '
            f'stroke="{INK}" stroke-width="1.6"/>'
            f'<circle cx="{x - r * 0.3:.1f}" cy="{y - r * 0.3:.1f}" '
            f'r="{r * 0.35:.1f}" fill="#FFFFFF" fill-opacity="0.7"/>')


def word(text, x, y, unit, gap, fill, shadow, light, tilt=5.0):
    """One word: each letter tilted and nudged a little, with outline,
    drop-shadow, fill, highlight and a rivet. Returns (svg, width)."""
    sw = unit * 1.35  # tube width
    out = []
    cx = x
    for ch in text:
        strokes = [[(px * unit, py * unit) for px, py in s] for s in LETTERS[ch]]
        angle = rng.uniform(-tilt, tilt)
        dy = rng.uniform(-unit * 0.35, unit * 0.35)
        w, h = 4 * unit, 6 * unit
        g = [f'<g transform="translate({cx:.1f} {y + dy:.1f}) '
             f'rotate({angle:.1f} {w / 2:.1f} {h / 2:.1f})">']
        drop = sw * 0.35
        for s in strokes:  # drop-shadow
            g.append(tube(s, INK, sw + 9, drop * 0.6, drop))
        for s in strokes:  # outline
            g.append(tube(s, INK, sw + 9))
        for s in strokes:  # shadow side
            g.append(tube(s, shadow, sw, 0, sw * 0.18))
        for s in strokes:  # fill
            g.append(tube(s, fill, sw * 0.8, 0, -sw * 0.05))
        for s in strokes:  # highlight streak
            g.append(tube(s, light, sw * 0.22, -sw * 0.12, -sw * 0.22, 0.9))
        # A rivet where the first stroke starts.
        px, py = strokes[0][0]
        g.append(rivet(px, py))
        g.append("</g>")
        out.append("".join(g))
        cx += w + gap
    return "".join(out), cx - gap - x


def gear(cx, cy, r, teeth=8):
    pts = []
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4) - math.pi / 2
        rr = r if (i % 4) in (0, 1) else r * 0.78
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    path = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"
    return (f'<path d="{path}" fill="{STEEL}" stroke="{INK}" stroke-width="6" '
            f'stroke-linejoin="round"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r * 0.42:.1f}" fill="{STEEL_D}" '
            f'stroke="{INK}" stroke-width="5"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r * 0.16:.1f}" fill="{HAZ}" '
            f'stroke="{INK}" stroke-width="3"/>'
            f'<path d="M{cx - r * 0.7:.1f},{cy - r * 0.35:.1f} '
            f'A{r * 0.78:.1f},{r * 0.78:.1f} 0 0 1 {cx - r * 0.1:.1f},'
            f'{cy - r * 0.76:.1f}" fill="none" stroke="{STEEL_L}" '
            f'stroke-width="4" stroke-linecap="round"/>')


def bolt(x, y, s):
    pts = [(0.55, 0), (0, 1.05), (0.42, 1.05), (0.2, 2), (1, 0.75), (0.55, 0.75),
           (0.85, 0)]
    path = "M" + " L".join(f"{x + px * s:.1f},{y + py * s:.1f}" for px, py in pts)
    return (f'<path d="{path} Z" fill="{GLOW}" stroke="{INK}" stroke-width="6" '
            f'stroke-linejoin="round"/>')


def banner(x, y, w, h, angle):
    cx, cy = x + w / 2, y + h / 2
    out = [f'<g transform="rotate({angle} {cx:.1f} {cy:.1f})">',
           # drop shadow
           f'<rect x="{x + 6}" y="{y + 9}" width="{w}" height="{h}" rx="16" '
           f'fill="{INK}"/>',
           f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="16" '
           f'fill="{STEEL}" stroke="{INK}" stroke-width="7"/>',
           f'<rect x="{x + 10}" y="{y + 8}" width="{w - 20}" height="9" rx="4.5" '
           f'fill="{STEEL_L}" fill-opacity="0.55"/>',
           f'<rect x="{x + 10}" y="{y + h - 16}" width="{w - 20}" height="7" '
           f'rx="3.5" fill="{STEEL_D}" fill-opacity="0.8"/>']
    for rx, ry in [(x + 16, y + 16), (x + w - 16, y + 16),
                   (x + 16, y + h - 16), (x + w - 16, y + h - 16)]:
        out.append(rivet(rx, ry, 5))
    out.append("</g>")
    return "".join(out)


def logo():
    width, height = 820, 430
    parts = []
    # SCRAPYARD
    top_unit, top_gap = 14, 18
    top_w = 9 * 4 * top_unit + 8 * top_gap
    top, _ = word("SCRAPYARD", (width - top_w) / 2, 34, top_unit, top_gap,
                  HAZ, HAZ_D, HAZ_L)
    # DERBY on a banner, with a gear and a bolt
    unit, gap = 20, 26
    derby_w = 5 * 4 * unit + 4 * gap
    bx, by, bw, bh = (width - derby_w) / 2 - 46, 168, derby_w + 92, 6 * unit + 74
    parts.append(gear(bx - 14, by + bh - 34, 58))
    parts.append(banner(bx, by, bw, bh, -2.5))
    derby, _ = word("DERBY", (width - derby_w) / 2, by + 37, unit, gap,
                    RUST, RUST_D, RUST_L, tilt=3.5)
    parts.append(derby)
    parts.append(bolt(bx + bw - 26, by - 46, 66))
    parts.append(top)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} '
            f'{height}" width="{width}" height="{height}">'
            + "".join(parts) + "</svg>")


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join("assets", "logo")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "logo.svg")
    with open(path, "w") as f:
        f.write(logo())
    print(path)


if __name__ == "__main__":
    main()

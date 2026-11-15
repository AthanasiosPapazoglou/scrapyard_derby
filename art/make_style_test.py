"""Scrapyard Derby - art style test.

Each robot part is drawn around its own pivot (the physics joint), so the same
part art can later be exported as separate game sprites.
"""

INK = "#2B1D16"      # outline
RUST = "#C4622D"
RUST_D = "#8A3B1C"
RUST_L = "#E39056"
STEEL = "#6B7B8C"
STEEL_D = "#4A5563"
STEEL_L = "#B4C0CB"
HAZ = "#F2B233"
HAZ_D = "#B97F14"
GLOW = "#5FE3D0"
OUT = 6

def torso():
    # barrel, origin = centre
    return f"""
<g id="torso">
  <path d="M-58,-64 Q0,-78 58,-64 L62,64 Q0,80 -62,64 Z" fill="{RUST}"/>
  <path d="M30,-70 Q46,-68 58,-64 L62,64 Q48,70 32,74 Q40,0 30,-70 Z" fill="{RUST_D}"/>
  <path d="M-46,-58 L-36,-60 Q-40,0 -36,56 L-46,58 Q-50,0 -46,-58 Z" fill="{RUST_L}"/>
  <path d="M-60,-28 Q0,-40 60,-28" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
  <path d="M-61,30 Q0,18 61,30" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
  <!-- patch plate -->
  <g transform="rotate(-7 4 0)">
    <rect x="-20" y="-16" width="46" height="34" rx="4" fill="{STEEL_L}" stroke="{INK}" stroke-width="4"/>
    <path d="M-16,10 L-6,-12 M-4,14 L8,-12 M8,14 L20,-12" stroke="{HAZ}" stroke-width="5"/>
    <rect x="-20" y="-16" width="46" height="34" rx="4" fill="none" stroke="{INK}" stroke-width="4"/>
    <circle cx="-14" cy="-10" r="3" fill="{INK}"/><circle cx="20" cy="-10" r="3" fill="{INK}"/>
    <circle cx="-14" cy="12" r="3" fill="{INK}"/><circle cx="20" cy="12" r="3" fill="{INK}"/>
  </g>
  <!-- dent and rust spots -->
  <path d="M-30,44 q8,-8 16,0" fill="none" stroke="{RUST_D}" stroke-width="4" stroke-linecap="round"/>
  <circle cx="40" cy="-44" r="4" fill="{RUST_D}"/><circle cx="-24" cy="-48" r="3" fill="{RUST_D}"/>
  <path d="M-58,-64 Q0,-78 58,-64 L62,64 Q0,80 -62,64 Z" fill="none" stroke="{INK}" stroke-width="{OUT}" stroke-linejoin="round"/>
</g>"""

def head():
    # paint-can head, origin = neck joint (bottom)
    return f"""
<g id="head">
  <path d="M-10,0 l20,-3 l-20,-3 l20,-3 l-20,-3" fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>
  <path d="M-10,0 l20,-3 l-20,-3 l20,-3 l-20,-3" fill="none" stroke="{STEEL_L}" stroke-width="4" stroke-linecap="round"/>
  <path d="M-36,-66 L36,-66 L38,-16 Q0,-6 -38,-16 Z" fill="{STEEL}"/>
  <path d="M18,-66 L36,-66 L38,-16 Q28,-13 20,-12 Z" fill="{STEEL_D}"/>
  <path d="M-30,-60 L-24,-60 L-25,-18 L-31,-19 Z" fill="{STEEL_L}"/>
  <path d="M-36,-66 L36,-66 L38,-16 Q0,-6 -38,-16 Z" fill="none" stroke="{INK}" stroke-width="{OUT}" stroke-linejoin="round"/>
  <ellipse cx="0" cy="-66" rx="37" ry="8" fill="{STEEL_L}" stroke="{INK}" stroke-width="5"/>
  <!-- fork antenna -->
  <path d="M-14,-72 L-20,-98 L-30,-106" fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M-14,-72 L-20,-98 L-30,-106" fill="none" stroke="{STEEL_L}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="-32" cy="-108" r="7" fill="{HAZ}" stroke="{INK}" stroke-width="4"/>
  <!-- eyes: one big camera lens, one small warning light -->
  <circle cx="12" cy="-40" r="17" fill="{INK}"/>
  <circle cx="12" cy="-40" r="11" fill="{GLOW}"/>
  <circle cx="12" cy="-40" r="5" fill="#1C6B66"/>
  <circle cx="7" cy="-45" r="3" fill="#FFFFFF"/>
  <circle cx="-20" cy="-36" r="6" fill="{HAZ}" stroke="{INK}" stroke-width="4"/>
  <path d="M-16,-24 q10,5 20,0" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>
</g>"""

def arm(id_):
    # corrugated hose + claw, origin = shoulder, hangs along +y
    return f"""
<g id="{id_}">
  <path d="M0,0 Q-8,34 0,62" fill="none" stroke="{INK}" stroke-width="26" stroke-linecap="round"/>
  <path d="M0,0 Q-8,34 0,62" fill="none" stroke="{STEEL_L}" stroke-width="15" stroke-linecap="round"/>
  <path d="M0,0 Q-8,34 0,62" fill="none" stroke="{STEEL}" stroke-width="15" stroke-dasharray="4 7"/>
  <path d="M-8,70 l-8,22 l9,2 l8,-18 Z" fill="{STEEL}" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>
  <path d="M8,70 l6,22 l-9,2 l-6,-18 Z" fill="{STEEL}" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>
  <circle cx="0" cy="66" r="11" fill="{HAZ}" stroke="{INK}" stroke-width="5"/>
  <circle cx="0" cy="66" r="3" fill="{INK}"/>
</g>"""

def leg(id_):
    # pipe leg + spring knee + tread foot, origin = hip
    return f"""
<g id="{id_}">
  <path d="M0,0 L0,64" stroke="{INK}" stroke-width="22" stroke-linecap="round"/>
  <path d="M0,0 L0,64" stroke="{STEEL}" stroke-width="12" stroke-linecap="round"/>
  <path d="M3,2 L3,60" stroke="{STEEL_D}" stroke-width="4"/>
  <path d="M-13,22 L13,27 L-13,32 L13,37 L-13,42" fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M-13,22 L13,27 L-13,32 L13,37 L-13,42" fill="none" stroke="{HAZ}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
  <rect x="-24" y="62" width="58" height="18" rx="6" fill="{HAZ}"/>
  <rect x="-24" y="73" width="58" height="7" rx="3" fill="{HAZ_D}"/>
  <path d="M-14,80 v-5 M-2,80 v-5 M10,80 v-5 M22,80 v-5" stroke="{INK}" stroke-width="4"/>
  <rect x="-24" y="62" width="58" height="18" rx="6" fill="none" stroke="{INK}" stroke-width="5"/>
</g>"""

def robot(x, y, angle, left_arm=35, right_arm=-140, left_leg=12, right_leg=-22, head_tilt=-8):
    return f"""
<g transform="translate({x} {y}) rotate({angle})">
  <g transform="translate(-24 66) rotate({left_leg})">{leg('leg_l')}</g>
  <g transform="translate(24 66) rotate({right_leg})">{leg('leg_r')}</g>
  <g transform="translate(-56 -42) rotate({left_arm})">{arm('arm_l')}</g>
  {torso()}
  <g transform="translate(0 -72) rotate({head_tilt})">{head()}</g>
  <g transform="translate(58 -42) rotate({right_arm})">{arm('arm_r')}</g>
</g>"""

def scene():
    W, H = 1200, 800
    sky = f"""
<defs>
  <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#2E3558"/>
    <stop offset="0.55" stop-color="#C9605A"/>
    <stop offset="1" stop-color="#F4B868"/>
  </linearGradient>
</defs>
<rect width="{W}" height="{H}" fill="url(#sky)"/>
<circle cx="900" cy="430" r="110" fill="#FCD98A" opacity="0.9"/>"""
    # far junk heaps (silhouettes)
    far = f"""
<path d="M0,520 L60,470 L110,490 L170,420 L230,450 L300,400 L360,440 L420,410 L470,455 L540,430 L600,470 L680,420 L760,460 L820,430 L900,470 L980,430 L1060,470 L1130,440 L1200,470 L1200,800 L0,800 Z" fill="#6E3F4E"/>
<g fill="#6E3F4E" stroke="#6E3F4E">
  <circle cx="300" cy="398" r="26"/><rect x="660" y="392" width="70" height="36" rx="6" transform="rotate(-12 695 410)"/>
  <path d="M1000,436 l30,-60 l8,4 l-26,60 Z"/><circle cx="1130" cy="438" r="20"/>
</g>
<circle cx="300" cy="398" r="11" fill="#8A5363"/><circle cx="1130" cy="438" r="8" fill="#8A5363"/>"""
    near = f"""
<path d="M0,560 L120,520 L220,540 L320,500 L430,530 L520,500 L640,540 L760,520 L860,560 L980,540 L1100,580 L1200,570 L1200,800 L0,800 Z" fill="#4E2B38"/>"""
    # the race hill: bumpy downhill to the right
    # very steep downhill: drops ~840px over the width (~35 degrees) with bumps
    hill_top = ("M0,60 C80,50 120,110 180,160 C240,210 270,205 320,250 "
                "C390,310 420,355 480,385 C540,415 570,415 620,460 "
                "C690,525 720,560 790,595 C850,625 880,630 930,675 "
                "C1000,740 1060,775 1110,820 C1150,855 1180,880 1200,900")
    hill = f"""
<path d="{hill_top} L1200,900 L0,900 Z" fill="#7A4A30"/>
<path d="{hill_top}" fill="none" stroke="#B8743E" stroke-width="14"/>
<path d="{hill_top}" fill="none" stroke="{INK}" stroke-width="6"/>
<!-- junk stuck in the hill -->
<g stroke="{INK}" stroke-width="5">
  <circle cx="140" cy="140" r="22" fill="#3A2A2A"/><circle cx="140" cy="140" r="9" fill="#7A4A30"/>
  <rect x="540" y="402" width="54" height="30" rx="4" fill="{STEEL}" transform="rotate(35 567 417)"/>
  <path d="M955,700 l18,-34 l14,6 l-14,34 Z" fill="{HAZ}"/>
  <circle cx="1060" cy="790" r="16" fill="#3A2A2A"/>
</g>
<g fill="#5C3522">
  <circle cx="90" cy="300" r="6"/><circle cx="300" cy="420" r="5"/><circle cx="150" cy="600" r="7"/><circle cx="420" cy="700" r="5"/><circle cx="560" cy="560" r="6"/><circle cx="780" cy="720" r="5"/>
</g>"""
    # speed lines + flying bolt (a lost part)
    fx = f"""
<g stroke="#FFF2D6" stroke-width="6" stroke-linecap="round" opacity="0.8">
  <path d="M470,160 l-90,-63"/><path d="M455,222 l-130,-91"/><path d="M445,282 l-80,-56"/>
</g>
<g transform="translate(820 160) rotate(25)">
  <path d="M-12,-10 h24 l6,10 l-6,10 h-24 l-6,-10 Z" fill="{STEEL_L}" stroke="{INK}" stroke-width="4"/>
  <circle r="5" fill="{INK}"/>
</g>
<g stroke="{HAZ}" stroke-width="5" stroke-linecap="round">
  <path d="M330,246 l-16,-14"/><path d="M342,238 l-4,-22"/><path d="M354,242 l12,-16"/>
</g>"""
    bot = robot(610, 240, -24)
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">{sky}{far}{near}{hill}{fx}{bot}</svg>'

def parts_sheet():
    W, H = 1200, 420
    cells = [
        ("translate(150 210)", torso(), "Torso"),
        ("translate(370 250)", head(), "Head"),
        ("translate(560 140)", arm('a1'), "Arm"),
        ("translate(740 150)", leg('l1'), "Leg"),
        ("translate(1000 230) scale(0.9)", robot(0, 0, 0, left_arm=20, right_arm=-20, left_leg=0, right_leg=0, head_tilt=0), "Assembled"),
    ]
    out = [f'<rect width="{W}" height="{H}" fill="#F3E9DC"/>']
    for tf, g, label in cells:
        out.append(f'<g transform="{tf}">{g}</g>')
    labels = [(150, "Torso"), (370, "Head"), (560, "Arm"), (740, "Leg"), (1000, "Assembled")]
    for x, t in labels:
        out.append(f'<text x="{x}" y="395" font-family="DejaVu Sans, sans-serif" font-size="22" font-weight="bold" fill="{INK}" text-anchor="middle">{t}</text>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">{"".join(out)}</svg>'

# Game sprites: one SVG per part. Each viewBox is placed so that (0, 0) is
# the part's joint pivot (torso: its centre), the same point the physics
# body's origin sits on. The game reads the viewBox to line them up.
# Boxes are in art pixels and include the outline and a little padding.
SPRITE_BOXES = {
    "torso": (-70, -86, 140, 172),
    "head": (-46, -120, 92, 130),
    "arm": (-26, -16, 52, 116),
    "leg": (-32, -14, 72, 100),
}


def sprite_svgs():
    parts = {
        "torso": torso(),
        "head": head(),
        "arm": arm("arm"),
        "leg": leg("leg"),
    }
    out = {}
    for name, g in parts.items():
        x, y, w, h = SPRITE_BOXES[name]
        out[name] = (
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" '
            f'width="{w}" height="{h}">{g}</svg>'
        )
    return out


if __name__ == "__main__":
    # Usage: python3 art/make_style_test.py art [assets/robot]
    #   1st folder: style test sheets; optional 2nd folder: game sprites.
    import sys, pathlib
    out = pathlib.Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    (out / "style_test_scene.svg").write_text(scene())
    (out / "style_test_parts.svg").write_text(parts_sheet())
    if len(sys.argv) > 2:
        sprites = pathlib.Path(sys.argv[2])
        sprites.mkdir(parents=True, exist_ok=True)
        for name, svg in sprite_svgs().items():
            (sprites / f"{name}.svg").write_text(svg)

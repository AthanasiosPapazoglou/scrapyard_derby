"""Scrapyard Derby - upgradeable robot parts.

Every Workshop slot (legs, arms, body, head, core) has six parts, tier 0 to
tier 5. Tier 0 is the original scrap robot from make_style_test.py; each
tier after it looks more advanced, from rusty cartoon junk to a sleek,
black-and-crimson obsidian build. Every tier keeps the thick-outline cutout style and a
happy face, so mixed parts still look like one cheerful robot.

    python3 art/make_parts.py [sprites_dir] [sheet_dir]
        defaults: assets/robot  art

Writes one SVG per part, `<slot>_<tier>.svg` (e.g. legs_3.svg), with the
joint pivot at (0, 0) of the viewBox like the original sprites (the body
and core: the torso centre), plus `art/parts_sheet.svg`, a preview of every
part and of fully matched robots per tier.

Each part covers its collision shape in tuning.dart (same pivots, similar
silhouettes), so upgrades change the look without changing the physics.
test/robot_sprites_test.dart checks every tier.
"""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import make_style_test as base  # noqa: E402  (tier 0 art)

INK = base.INK
OUT = base.OUT
GLOW = base.GLOW

# Tier palettes: (fill, shadow, light, accent, accent shadow, glow).
TIERS = [
    # 0 Scrap: rust and hazard yellow (the original robot).
    dict(fill=base.RUST, dark=base.RUST_D, light=base.RUST_L, acc=base.HAZ,
         acc_d=base.HAZ_D, glow=GLOW, metal=base.STEEL, metal_d=base.STEEL_D,
         metal_l=base.STEEL_L),
    # 1 Refurbished: clean steel, neat hazard stripes.
    dict(fill="#7D8C9C", dark="#56616F", light="#B9C5D0", acc=base.HAZ,
         acc_d=base.HAZ_D, glow=GLOW, metal="#6B7B8C", metal_d="#4A5563",
         metal_l="#C9D3DC"),
    # 2 Workshop racer: red enamel, cream stripes, chrome.
    dict(fill="#C8413A", dark="#8E2622", light="#EA7066", acc="#FFF2D6",
         acc_d="#D9C7A6", glow=GLOW, metal="#A9B4BF", metal_d="#6F7A86",
         metal_l="#E6ECF1"),
    # 3 Industrial pro: gunmetal, safety orange, teal light seams.
    dict(fill="#4C5464", dark="#333945", light="#76808F", acc="#F28C28",
         acc_d="#B5600F", glow="#4FE6D6", metal="#5E6878", metal_d="#3B424F",
         metal_l="#9AA5B3"),
    # 4 Cyber: charcoal, neon cyan, magenta.
    dict(fill="#2D3142", dark="#1C1F2B", light="#4A5068", acc="#FF4FA3",
         acc_d="#B8306F", glow="#3CF2FF", metal="#3A3F54", metal_d="#23263A",
         metal_l="#5C6380"),
    # 5 Obsidian: matte black, crimson trim, red glow. Sinister, but still
    # a happy face.
    dict(fill="#24222A", dark="#141318", light="#3E3A46", acc="#D4213D",
         acc_d="#8E1426", glow="#FF4057", metal="#2E2B33", metal_d="#0E0D11",
         metal_l="#5A5560"),
]

SLOTS = ["legs", "arms", "body", "head", "core"]

# viewBox per slot (x, y, w, h) in art pixels, pivot at (0, 0). Generous
# enough for every tier, and covering the collision shapes.
BOXES = {
    "body": (-74, -92, 148, 184),
    "core": (-40, -34, 80, 68),
    "head": (-54, -132, 108, 142),
    "arms": (-30, -20, 60, 124),
    "legs": (-36, -16, 78, 104),
}


# ----------------------------------------------------------------- helpers

def path(d, fill="none", stroke=None, w=None, cap="round", extra=""):
    s = f'<path d="{d}" fill="{fill}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{w}" stroke-linecap="{cap}" stroke-linejoin="round"'
    return s + f"{extra}/>"


def ink(d, fill, w=OUT):
    """A filled shape with the thick dark cutout outline."""
    return path(d, fill, INK, w)


def line(d, color, w):
    return path(d, "none", color, w)


def inked_line(d, color, w, edge=5):
    """A stroke with an ink border (pipes, springs)."""
    return line(d, INK, w + edge) + line(d, color, w)


def circle(cx, cy, r, fill, stroke=INK, w=4):
    st = f' stroke="{stroke}" stroke-width="{w}"' if stroke else ""
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"{st}/>'


def rect(x, y, w, h, rx, fill, stroke=INK, sw=4, extra=""):
    st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" '
            f'fill="{fill}"{st}{extra}/>')


def glow_line(d, color, w=4):
    """A light seam: a soft wide glow under a bright thin core."""
    return (path(d, "none", color, w + 6, extra=' opacity="0.35"')
            + path(d, "none", color, w))


def rivets(points, r=3):
    return "".join(circle(x, y, r, INK, None) for x, y in points)


def group(id_, *parts):
    return f'<g id="{id_}">' + "".join(parts) + "</g>"


# ----------------------------------------------------------------- body
# Torso box: x ±61, y ±78. The core is drawn on top, centred at (0, 0), so
# every body leaves the middle of the chest clear.

def body(tier):
    c = TIERS[tier]
    if tier == 0:
        # The original barrel, minus its patch plate (now the tier-0 core).
        return group(
            "body",
            path("M-58,-64 Q0,-78 58,-64 L62,64 Q0,80 -62,64 Z", c["fill"]),
            path("M30,-70 Q46,-68 58,-64 L62,64 Q48,70 32,74 Q40,0 30,-70 Z", c["dark"]),
            path("M-46,-58 L-36,-60 Q-40,0 -36,56 L-46,58 Q-50,0 -46,-58 Z", c["light"]),
            line("M-60,-28 Q0,-40 60,-28", INK, 5),
            line("M-61,30 Q0,18 61,30", INK, 5),
            line("M-30,44 q8,-8 16,0", c["dark"], 4),
            circle(40, -44, 4, c["dark"], None), circle(-24, -48, 3, c["dark"], None),
            ink("M-58,-64 Q0,-78 58,-64 L62,64 Q0,80 -62,64 Z", "none"),
        )
    # From tier 1 up the frame gets more athletic: broader shoulders, a
    # narrower waist, then pec plates (tier 3) and ab plates (tier 4-5).
    if tier == 1:
        # Riveted drum: steel, tapering a little to the waist, hazard skirt.
        shell = "M-57,-74 Q0,-82 57,-74 L53,70 Q0,80 -53,70 Z"
        stripes = "".join(
            path(f"M{x},74 L{x + 9},58 L{x + 19},58 L{x + 10},74 Z", INK)
            for x in range(-50, 40, 20)
        )
        return group(
            "body",
            path(shell, c["fill"]),
            path("M33,-79 Q47,-77 57,-74 L53,70 Q47,74 35,77 Q42,0 33,-79 Z", c["dark"]),
            path("M-45,-72 L-37,-73 Q-40,0 -36,62 L-43,63 Q-48,0 -45,-72 Z", c["light"]),
            rect(-58, -52, 116, 12, 3, c["metal_l"]),
            rivets([(x, -46) for x in range(-48, 56, 16)]),
            path("M-54,56 L54,56 L53,70 Q0,80 -53,70 Z", c["acc"]),
            stripes,
            line("M-54,56 L54,56", INK, 4),
            line("M-44,-30 L-44,-18 M-43,20 L-43,36", c["dark"], 4),
            ink(shell, "none"),
        )
    if tier == 2:
        # Racer chassis: broad red shoulders tapering to the waist, chest
        # line, cream racing stripes, side vents.
        shell = ("M-52,-78 L52,-78 Q64,-78 63,-64 L57,36 Q53,78 38,78 "
                 "L-38,78 Q-53,78 -57,36 L-63,-64 Q-64,-78 -52,-78 Z")
        vents = "".join(line(f"M40,{y} L52,{y}", INK, 4) for y in (-30, -20, -10))
        return group(
            "body",
            path(shell, c["fill"]),
            path("M38,-78 L52,-78 Q64,-78 63,-64 L57,36 Q53,78 38,78 L30,78 Q46,0 38,-78 Z", c["dark"]),
            path("M-26,-78 L-12,-78 L-12,78 L-26,78 Z", c["acc"]),
            path("M-6,-78 L0,-78 L0,-34 L-6,-34 Z M-6,34 L0,34 L0,78 L-6,78 Z", c["acc"]),
            path("M-52,-66 L-44,-66 L-42,30 L-49,30 Z", c["light"], extra=' opacity="0.8"'),
            line("M-46,-26 Q-24,-14 -4,-26 M4,-26 Q24,-14 46,-26", c["dark"], 4),
            vents,
            rect(-44, 62, 88, 9, 4, c["metal_l"]),
            ink(shell, "none"),
        )
    if tier == 3:
        # Industrial frame: a V-shaped gunmetal torso with chest plates and
        # ab plates around the core, orange shoulder yoke, light seams.
        shell = ("M-46,-80 L46,-80 L64,-64 L60,-20 L46,60 L36,78 "
                 "L-36,78 L-46,60 L-60,-20 L-64,-64 Z")
        abs_ = "".join(
            rect(x, y, w, 11, 3, c["light"], INK, 3)
            for x, y, w in [(-22, 34, 20), (2, 34, 20), (-19, 50, 17), (2, 50, 17)]
        )
        return group(
            "body",
            path(shell, c["fill"]),
            path("M34,-80 L46,-80 L64,-64 L60,-20 L46,60 L36,78 L28,78 L40,0 Z", c["dark"]),
            ink("M-54,-58 L-8,-58 L-8,-34 L-20,-26 L-50,-30 Z", c["light"], 4),
            ink("M54,-58 L8,-58 L8,-34 L20,-26 L50,-30 Z", c["light"], 4),
            abs_,
            path("M-46,-80 L46,-80 L64,-64 L-64,-64 Z", c["acc"]),
            line("M-64,-64 L64,-64", INK, 4),
            glow_line("M-56,-20 L-44,40", c["glow"], 3),
            glow_line("M56,-20 L44,40", c["glow"], 3),
            rivets([(-40, -72), (40, -72)]),
            ink(shell, "none"),
        )
    if tier == 4:
        # Neon hull: a strong V, glowing pec edges, segmented abs.
        shell = ("M-38,-82 L38,-82 L66,-60 L60,-14 L42,62 L32,80 "
                 "L-32,80 L-42,62 L-60,-14 L-66,-60 Z")
        abs_ = "".join(
            rect(x, y, w, 11, 3, c["metal"], INK, 3)
            for x, y, w in [(-21, 32, 19), (2, 32, 19), (-19, 47, 17), (2, 47, 17), (-16, 62, 14), (2, 62, 14)]
        )
        return group(
            "body",
            path(shell, c["fill"]),
            path("M26,-82 L38,-82 L66,-60 L60,-14 L42,62 L32,80 L24,80 L40,0 Z", c["dark"]),
            ink("M-56,-58 L-6,-58 L-6,-34 L-22,-24 L-52,-28 Z", c["dark"], 4),
            ink("M56,-58 L6,-58 L6,-34 L22,-24 L52,-28 Z", c["dark"], 4),
            glow_line("M-50,-30 L-22,-26 L-8,-35", c["acc"], 2),
            glow_line("M50,-30 L22,-26 L8,-35", c["acc"], 2),
            abs_,
            glow_line("M-34,-76 L34,-76 L58,-58", c["glow"], 3),
            glow_line("M-58,-14 L-42,58", c["glow"], 3),
            ink(shell, "none"),
        )
    # tier 5: obsidian frame - the most athletic build. Matte black, broad
    # rounded shoulders, sculpted pecs and abs, crimson trim and glow.
    shell = ("M-36,-84 Q0,-90 36,-84 Q62,-80 66,-60 Q66,-36 58,-14 "
             "Q48,30 40,64 Q36,80 22,82 L-22,82 Q-36,80 -40,64 "
             "Q-48,30 -58,-14 Q-66,-36 -66,-60 Q-62,-80 -36,-84 Z")
    abs_ = "".join(
        rect(x, y, w, 11, 4, c["light"], INK, 3)
        for x, y, w in [(-21, 32, 19), (2, 32, 19), (-19, 47, 17), (2, 47, 17), (-15, 62, 13), (2, 62, 13)]
    )
    return group(
        "body",
        path(shell, c["fill"]),
        path("M40,-84 Q62,-80 66,-60 Q66,-36 58,-14 Q48,30 40,64 Q36,80 26,82 Q46,0 40,-84 Z", c["dark"]),
        ink("M-50,-60 Q-28,-68 -6,-60 L-6,-34 Q-26,-22 -48,-30 Q-56,-44 -50,-60 Z", c["light"], 4),
        ink("M50,-60 Q28,-68 6,-60 L6,-34 Q26,-22 48,-30 Q56,-44 50,-60 Z", c["light"], 4),
        path("M-44,-56 Q-32,-61 -20,-58", "none", c["metal_l"], 3),
        abs_,
        line("M-30,-80 Q0,-86 30,-80", c["acc"], 4),
        glow_line("M-58,-14 Q-48,30 -40,64", c["glow"], 3),
        glow_line("M58,-14 Q48,30 40,64", c["glow"], 3),
        ink(shell, "none"),
    )


# ----------------------------------------------------------------- core
# Drawn on the chest, centred on the torso centre (0, 0).

def core(tier):
    c = TIERS[tier]
    if tier == 0:
        # The original hazard patch plate.
        return group(
            "core",
            '<g transform="rotate(-7 4 0)">',
            rect(-20, -16, 46, 34, 4, base.STEEL_L),
            line("M-16,10 L-6,-12 M-4,14 L8,-12 M8,14 L20,-12", base.HAZ, 5),
            rect(-20, -16, 46, 34, 4, "none"),
            rivets([(-14, -10), (20, -10), (-14, 12), (20, 12)]),
            "</g>",
        )
    if tier == 1:
        # Car battery: terminals, a charge gauge and a little lightning bolt.
        return group(
            "core",
            rect(-10, -24, 8, 8, 2, "#C8413A"), rect(8, -24, 8, 8, 2, INK),
            rect(-24, -18, 50, 36, 5, c["metal_l"]),
            rect(-24, -18, 50, 10, 4, c["acc"]),
            path("M2,-4 L-6,8 L1,8 L-3,16 L8,2 L1,2 L5,-4 Z", c["acc"], INK, 3),
            rect(10, -2, 10, 14, 2, INK, None),
            rect(12, 4, 6, 6, 1, c["glow"], None),
        )
    if tier == 2:
        # Tube amp: a glowing vacuum tube in a chrome cradle.
        return group(
            "core",
            rect(-24, 6, 48, 16, 6, c["metal_l"]),
            path("M-12,8 L-12,-14 Q-12,-26 0,-26 Q12,-26 12,-14 L12,8 Z", "#FFD9A0", INK, 4),
            path("M-6,4 L-6,-12 Q0,-20 6,-12 L6,4", "none", "#F28C28", 4),
            circle(0, -10, 4, "#FFF2D6", None),
            rivets([(-17, 14), (17, 14)]),
        )
    if tier == 3:
        # Turbine core: a fan in a heavy ring, glowing in the middle.
        blades = "".join(
            path(f"M0,0 L{dx},{dy} Q{qx},{qy} {ex},{ey} Z", c["metal_l"], INK, 3)
            for dx, dy, qx, qy, ex, ey in [
                (0, -20, 12, -18, 14, -12), (20, 0, 18, 12, 12, 14),
                (0, 20, -12, 18, -14, 12), (-20, 0, -18, -12, -12, -14)]
        )
        return group(
            "core",
            circle(0, 0, 27, c["metal_d"], INK, 5),
            circle(0, 0, 21, c["dark"], None),
            blades,
            circle(0, 0, 8, c["glow"], INK, 3),
            rivets([(0, -24), (24, 0), (0, 24), (-24, 0)], 2.5),
        )
    if tier == 4:
        # Plasma cell: a glowing hexagon in a magenta ring.
        hexagon = "M0,-24 L21,-12 L21,12 L0,24 L-21,12 L-21,-12 Z"
        inner = "M0,-14 L12,-7 L12,7 L0,14 L-12,7 L-12,-7 Z"
        return group(
            "core",
            circle(0, 0, 29, c["dark"], INK, 5),
            glow_line("M0,-26 A26,26 0 1 1 -0.1,-26", c["acc"], 3),
            ink(hexagon, c["metal"], 4),
            path(inner, c["glow"], extra=' opacity="0.45"'),
            path("M0,-9 L8,-4 L8,4 L0,9 L-8,4 L-8,-4 Z", c["glow"]),
            circle(0, 0, 3, "#FFFFFF", None),
        )
    # tier 5: ember heart - a crimson-ringed reactor with a glowing heart.
    heart = "M0,10 C-14,0 -14,-12 -6,-12 C-2,-12 0,-8 0,-6 C0,-8 2,-12 6,-12 C14,-12 14,0 0,10 Z"
    return group(
        "core",
        circle(0, 0, 28, c["metal"], INK, 5),
        circle(0, 0, 22, c["acc"], INK, 3),
        circle(0, 0, 17, c["metal_d"], None),
        circle(0, 0, 15, c["glow"], None, 0) .replace("/>", ' opacity="0.3"/>'),
        path(heart, c["glow"], INK, 3),
        circle(-3, -8, 2, "#FFFFFF", None),
    )


# ----------------------------------------------------------------- head
# Neck pivot at (0, 0); the collision circle is r=38 centred at (0, -40).

def neck(c):
    return inked_line("M0,0 L0,-12", c["metal"], 8)


def head(tier):
    c = TIERS[tier]
    if tier == 0:
        return base.head()
    if tier == 1:
        # Lantern box: riveted steel, two round eyes, grille smile, bulb.
        box = "M-36,-74 L36,-74 Q40,-74 40,-70 L40,-14 Q40,-10 36,-10 L-36,-10 Q-40,-10 -40,-14 L-40,-70 Q-40,-74 -36,-74 Z"
        return group(
            "head", neck(c),
            path(box, c["fill"]),
            path("M22,-74 L36,-74 Q40,-74 40,-70 L40,-14 Q40,-10 36,-10 L24,-10 Z", c["dark"]),
            path("M-32,-68 L-26,-68 L-26,-18 L-32,-18 Z", c["light"]),
            ink(box, "none"),
            inked_line("M0,-74 L0,-92", c["metal_l"], 4),
            circle(0, -98, 8, c["acc"], INK, 4),
            circle(-15, -48, 11, INK, None), circle(-15, -48, 7, c["glow"], None),
            circle(15, -48, 11, INK, None), circle(15, -48, 7, c["glow"], None),
            circle(-18, -51, 2.5, "#FFFFFF", None), circle(12, -51, 2.5, "#FFFFFF", None),
            path("M-14,-28 Q0,-18 14,-28", "none", INK, 4),
            rivets([(-34, -68), (34, -68), (-34, -16), (34, -16)], 2.5),
        )
    if tier == 2:
        # Racer helmet: rounded red shell, cream stripe, big happy eyes.
        shell = "M-40,-36 Q-40,-82 0,-82 Q40,-82 40,-36 L40,-18 Q40,-8 30,-8 L-30,-8 Q-40,-8 -40,-18 Z"
        return group(
            "head", neck(c),
            path(shell, c["fill"]),
            path("M24,-78 Q40,-70 40,-36 L40,-18 Q40,-8 30,-8 L26,-8 Q34,-40 24,-78 Z", c["dark"]),
            path("M-6,-82 L6,-82 L6,-60 L-6,-60 Z", c["acc"]),
            ink(shell, "none"),
            ink("M-32,-58 L32,-58 Q34,-58 34,-54 L34,-26 Q34,-20 28,-20 L-28,-20 Q-34,-20 -34,-26 L-34,-54 Q-34,-58 -32,-58 Z", "#20232B", 4),
            circle(-13, -42, 9, c["glow"], None), circle(13, -42, 9, c["glow"], None),
            circle(-16, -45, 3, "#FFFFFF", None), circle(10, -45, 3, "#FFFFFF", None),
            path("M-8,-30 Q0,-24 8,-30", "none", c["glow"], 3),
            circle(-32, -64, 3, c["light"], None),
        )
    if tier == 3:
        # Foreman: angular gunmetal head, orange headlamp, LED eyes and smile.
        shell = "M-30,-78 L30,-78 L40,-66 L40,-16 L32,-8 L-32,-8 L-40,-16 L-40,-66 Z"
        return group(
            "head", neck(c),
            path(shell, c["fill"]),
            path("M22,-78 L30,-78 L40,-66 L40,-16 L32,-8 L24,-8 Z", c["dark"]),
            ink(shell, "none"),
            rect(-12, -92, 24, 14, 4, c["acc"]),
            path("M-8,-86 L8,-86", "none", "#FFF2D6", 3),
            ink("M-32,-62 L32,-62 L32,-22 L-32,-22 Z", "#1B1E26", 4),
            rect(-24, -54, 16, 10, 2, c["glow"], None),
            rect(8, -54, 16, 10, 2, c["glow"], None),
            glow_line("M-12,-34 Q0,-27 12,-34", c["glow"], 3),
            line("M-40,-40 L-46,-40 M40,-40 L46,-40", INK, 6),
            rivets([(-34, -72), (34, -72)], 2.5),
        )
    if tier == 4:
        # Neon visor: rounded charcoal head, full visor with ^ ^ eyes, fin.
        shell = "M-34,-80 L34,-80 Q42,-80 42,-72 L42,-16 Q42,-8 34,-8 L-34,-8 Q-42,-8 -42,-16 L-42,-72 Q-42,-80 -34,-80 Z"
        return group(
            "head", neck(c),
            ink("M8,-80 L22,-104 L28,-104 L22,-80 Z", c["metal"], 4),
            circle(26, -106, 4, c["acc"], INK, 3),
            path(shell, c["fill"]),
            path("M26,-80 L34,-80 Q42,-80 42,-72 L42,-16 Q42,-8 34,-8 L28,-8 Z", c["dark"]),
            ink(shell, "none"),
            ink("M-36,-64 L36,-64 Q38,-64 38,-60 L38,-28 Q38,-24 34,-24 L-34,-24 Q-38,-24 -38,-28 L-38,-60 Q-38,-64 -36,-64 Z", "#0C0E16", 4),
            glow_line("M-22,-42 L-14,-50 L-6,-42", c["glow"], 4),
            glow_line("M6,-42 L14,-50 L22,-42", c["glow"], 4),
            glow_line("M-10,-34 Q0,-28 10,-34", c["glow"], 3),
            rect(-48, -52, 8, 18, 3, c["metal"]), rect(40, -52, 8, 18, 3, c["metal"]),
            glow_line("M-44,-48 L-44,-38", c["acc"], 2),
            glow_line("M44,-48 L44,-38", c["acc"], 2),
        )
    # tier 5: obsidian grin - black oval head, a glowing smile and blush.
    # Sinister look, happy robot.
    shell = "M0,-84 Q42,-84 42,-46 Q42,-8 0,-8 Q-42,-8 -42,-46 Q-42,-84 0,-84 Z"
    return group(
        "head", neck(c),
        path(shell, c["fill"]),
        path("M18,-80 Q42,-72 42,-46 Q42,-20 20,-11 Q34,-46 18,-80 Z", c["dark"]),
        path("M-26,-72 Q-18,-80 -8,-82 L-10,-74 Q-18,-72 -24,-66 Z", c["light"]),
        ink(shell, "none"),
        ink("M-30,-58 Q0,-66 30,-58 Q34,-40 26,-26 Q0,-18 -26,-26 Q-34,-40 -30,-58 Z", c["metal_d"], 4),
        glow_line("M-20,-42 Q-13,-50 -6,-42", c["glow"], 4),
        glow_line("M6,-42 Q13,-50 20,-42", c["glow"], 4),
        glow_line("M-9,-33 Q0,-27 9,-33", c["glow"], 3),
        circle(-20, -34, 3.5, "#FF8FB8", None), circle(20, -34, 3.5, "#FF8FB8", None),
        circle(-42, -46, 6, c["acc"], INK, 4), circle(42, -46, 6, c["acc"], INK, 4),
    )


# ----------------------------------------------------------------- arms
# Shoulder pivot at (0, 0), hanging along +y. Collision capsule: (0,0) to
# (0,80), radius 13.

def arms(tier):
    c = TIERS[tier]
    if tier == 0:
        return base.arm("arms")
    if tier == 1:
        # Pipe arm: steel pipe, bolted elbow, two-finger gripper.
        return group(
            "arms",
            inked_line("M0,0 L0,36", c["fill"], 16),
            inked_line("M0,40 L0,70", c["fill"], 14),
            line("M4,2 L4,34 M4,42 L4,68", c["dark"], 4),
            circle(0, 38, 10, c["acc"], INK, 5), circle(0, 38, 3, INK, None),
            ink("M-9,72 L-13,94 L-5,96 L-1,76 Z", c["metal"], 4),
            ink("M9,72 L13,94 L5,96 L1,76 Z", c["metal"], 4),
            rect(-11, 66, 22, 10, 3, c["metal_l"]),
        )
    if tier == 2:
        # Racer arm: red enamel, chrome elbow, round three-finger mitt.
        return group(
            "arms",
            ink("M-12,-4 Q0,-12 12,-4 L10,36 L-10,36 Z", c["fill"]),
            path("M5,-6 Q10,-4 12,-4 L10,34 L6,34 Z", c["dark"]),
            path("M-12,10 L12,10 L11,18 L-11,18 Z", c["acc"]),
            circle(0, 40, 9, c["metal_l"], INK, 5),
            ink("M-10,44 L10,44 L9,72 L-9,72 Z", c["fill"]),
            ink("M-14,74 Q-16,96 -6,96 Q-2,90 0,96 Q2,90 6,96 Q16,96 14,74 Q0,68 -14,74 Z", c["acc"], 5),
        )
    if tier == 3:
        # Hydraulic arm: gunmetal casing, exposed piston, heavy pincer.
        return group(
            "arms",
            ink("M-13,-6 L13,-6 L12,34 L-12,34 Z", c["fill"]),
            path("M6,-6 L13,-6 L12,34 L6,34 Z", c["dark"]),
            glow_line("M-6,4 L-6,26", c["glow"], 2),
            inked_line("M0,36 L0,58", c["metal_l"], 6),
            rect(-10, 56, 20, 12, 3, c["acc"]),
            ink("M-12,68 L-16,94 L-6,96 L-2,74 Z", c["metal"], 4),
            ink("M12,68 L16,94 L6,96 L2,74 Z", c["metal"], 4),
            circle(0, 36, 8, c["acc"], INK, 4),
        )
    if tier == 4:
        # Gyro arm: segmented charcoal, a glowing gyro ring at the elbow.
        return group(
            "arms",
            ink("M-12,-4 L12,-4 L10,32 L-10,32 Z", c["fill"]),
            path("M5,-4 L12,-4 L10,32 L5,32 Z", c["dark"]),
            ink("M-10,46 L10,46 L8,72 L-8,72 Z", c["fill"]),
            circle(0, 39, 12, c["metal_d"], INK, 5),
            glow_line("M-8,39 A8,8 0 1 1 -8,39.1", c["glow"], 3),
            glow_line("M-6,8 L6,8", c["acc"], 2),
            ink("M-9,72 L-15,92 L-9,96 L-3,78 Z", c["metal"], 4),
            ink("M9,72 L15,92 L9,96 L3,78 Z", c["metal"], 4),
            circle(-12, 94, 2.5, c["acc"], None), circle(12, 94, 2.5, c["acc"], None),
        )
    # tier 5: obsidian arm, dark elbow with a crimson ring, rounded hand.
    return group(
        "arms",
        ink("M-12,0 Q-13,-8 0,-8 Q13,-8 12,0 L10,32 Q0,36 -10,32 Z", c["fill"]),
        path("M4,-7 Q12,-6 12,0 L10,32 Q8,33 6,33 Z", c["dark"]),
        circle(0, 40, 10, c["metal"], INK, 5),
        circle(0, 40, 5, c["acc"], None),
        ink("M-10,48 Q0,44 10,48 L8,72 Q0,75 -8,72 Z", c["fill"]),
        glow_line("M-5,56 L-5,66", c["glow"], 2),
        ink("M-12,76 Q-14,96 0,96 Q14,96 12,76 Q0,70 -12,76 Z", c["fill"], 5),
        path("M-4,82 L-4,90 M4,82 L4,90", "none", c["dark"], 3),
    )


# ----------------------------------------------------------------- legs
# Hip pivot at (0, 0). Collision: capsule (0,0)-(0,64) r=11 and a foot box
# x -24..34, y 62..80.

def legs(tier):
    c = TIERS[tier]
    if tier == 0:
        return base.leg("legs")
    if tier == 1:
        # Coil hopper: steel shin, double spring, cleated steel foot.
        return group(
            "legs",
            inked_line("M0,0 L0,20", c["fill"], 13),
            inked_line("M-12,22 L12,26 L-12,30 L12,34 L-12,38 L12,42 L-12,46", c["acc"], 4, 5),
            inked_line("M0,48 L0,62", c["fill"], 13),
            ink("M-24,64 Q-24,60 -18,60 L30,60 Q36,60 36,66 L36,80 L-24,80 Z", c["metal_l"], 5),
            path("M-24,74 L36,74 L36,80 L-24,80 Z", c["dark"]),
            line("M-14,80 v-6 M0,80 v-6 M14,80 v-6 M28,80 v-6", INK, 4),
            ink("M-24,64 Q-24,60 -18,60 L30,60 Q36,60 36,66 L36,80 L-24,80 Z", "none", 5),
        )
    if tier == 2:
        # Racer spring: red enamel thigh, chrome spring, cream sneaker foot.
        return group(
            "legs",
            ink("M-11,-4 L11,-4 L9,24 L-9,24 Z", c["fill"]),
            path("M5,-4 L11,-4 L9,24 L5,24 Z", c["dark"]),
            inked_line("M-10,28 L10,32 L-10,36 L10,40 L-10,44 L10,48", c["metal_l"], 4, 5),
            ink("M-22,62 Q-22,54 -10,54 L14,54 Q34,56 36,70 L36,80 L-22,80 Z", c["acc"], 5),
            path("M-22,72 L36,72 L36,80 L-22,80 Z", c["fill"]),
            path("M2,58 L22,58 L20,64 L4,64 Z", c["fill"]),
            ink("M-22,62 Q-22,54 -10,54 L14,54 Q34,56 36,70 L36,80 L-22,80 Z", "none", 5),
        )
    if tier == 3:
        # Piston strider: gunmetal, orange shock spring, heavy steel boot.
        return group(
            "legs",
            ink("M-12,-4 L12,-4 L11,22 L-11,22 Z", c["fill"]),
            path("M5,-4 L12,-4 L11,22 L5,22 Z", c["dark"]),
            inked_line("M0,22 L0,58", c["metal_l"], 6),
            inked_line("M-11,28 L11,32 L-11,36 L11,40 L-11,44 L11,48", c["acc"], 3, 5),
            ink("M-24,60 L28,60 L36,68 L36,80 L-24,80 Z", c["metal"], 5),
            path("M-24,74 L36,74 L36,80 L-24,80 Z", c["metal_d"]),
            glow_line("M-16,67 L24,67", c["glow"], 2),
            ink("M-24,60 L28,60 L36,68 L36,80 L-24,80 Z", "none", 5),
        )
    if tier == 4:
        # Mag shock: charcoal leg, glowing coil, angular boot with a lit sole.
        return group(
            "legs",
            ink("M-11,-4 L11,-4 L8,26 L-8,26 Z", c["fill"]),
            path("M4,-4 L11,-4 L8,26 L4,26 Z", c["dark"]),
            inked_line("M0,26 L0,56", c["metal"], 6),
            glow_line("M-9,32 L9,36 L-9,40 L9,44 L-9,48", c["glow"], 3),
            ink("M-22,58 L22,58 L36,70 L36,78 L-24,78 L-24,64 Z", c["fill"], 5),
            path("M14,58 L22,58 L36,70 L36,78 L24,78 Z", c["dark"]),
            glow_line("M-20,79 L34,79", c["glow"], 3),
            glow_line("M-14,66 L4,66", c["acc"], 2),
        )
    # tier 5: obsidian leg, dark knee with a crimson ring, glowing boot.
    return group(
        "legs",
        ink("M-11,0 Q-11,-6 0,-6 Q11,-6 11,0 L9,24 L-9,24 Z", c["fill"]),
        path("M4,-6 Q11,-5 11,0 L9,24 L5,24 Z", c["dark"]),
        circle(0, 30, 9, c["metal"], INK, 5),
        circle(0, 30, 4, c["acc"], None),
        ink("M-8,38 L8,38 L7,58 L-7,58 Z", c["fill"]),
        ink("M-24,66 Q-24,58 -14,58 L18,58 Q36,60 36,72 L36,78 L-24,78 Z", c["fill"], 5),
        path("M18,58 Q36,60 36,72 L36,78 L26,78 Q30,64 18,58 Z", c["dark"]),
        glow_line("M-20,80 L34,80", c["glow"], 3),
        line("M-12,64 L6,64", c["acc"], 3),
    )


DRAW = {"legs": legs, "arms": arms, "body": body, "head": head, "core": core}

# Part names per slot and tier, shown in the Workshop (also in the game's
# robot_stats.dart; keep the two lists in step).
NAMES = {
    "legs": ["Scrap Springs", "Coil Hoppers", "Racer Springs", "Piston Striders", "Mag Shocks", "Obsidian Steps"],
    "arms": ["Hose Claws", "Pipe Grippers", "Racer Mitts", "Hydraulic Pincers", "Gyro Claws", "Obsidian Hands"],
    "body": ["Rust Barrel", "Riveted Drum", "Racer Chassis", "Iron Works Frame", "Neon Hull", "Obsidian Frame"],
    "head": ["Paint Can", "Lantern Box", "Racer Helmet", "Foreman", "Neon Visor", "Obsidian Grin"],
    "core": ["Patch Battery", "Car Battery", "Tube Amp", "Turbine Core", "Plasma Cell", "Ember Heart"],
}


# ----------------------------------------------------------------- output

def sprite(slot, tier):
    x, y, w, h = BOXES[slot]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" '
            f'width="{w}" height="{h}">{DRAW[slot](tier)}</svg>')


def robot(tiers, angle=0, arm_l=18, arm_r=-18):
    """A whole robot; tiers maps slot -> tier."""
    t = tiers
    return f"""
<g transform="rotate({angle})">
  <g transform="translate(-56 -42) rotate({arm_l})">{arms(t['arms'])}</g>
  <g transform="translate(-24 66)">{legs(t['legs'])}</g>
  <g transform="translate(24 66)">{legs(t['legs'])}</g>
  {body(t['body'])}{core(t['core'])}
  <g transform="translate(0 -72)">{head(t['head'])}</g>
  <g transform="translate(58 -42) rotate({arm_r})">{arms(t['arms'])}</g>
</g>"""


def sheet():
    cell, left, top = 170, 150, 70
    w = left + 6 * cell + 20
    rows = len(SLOTS)
    robots_top = top + rows * cell + 40
    h = robots_top + 320
    out = [f'<rect width="{w}" height="{h}" fill="#2E3558"/>',
           f'<rect y="{robots_top - 30}" width="{w}" height="{h}" fill="#C9605A"/>']
    for t in range(6):
        out.append(f'<text x="{left + t * cell + cell / 2}" y="40" font-family="Helvetica" '
                   f'font-size="22" font-weight="bold" fill="#FFF2D6" text-anchor="middle">Tier {t}</text>')
    scale = {"body": 0.8, "core": 1.4, "head": 0.95, "arms": 1.1, "legs": 1.2}
    centre = {"body": (0, 0), "core": (0, 0), "head": (0, -50), "arms": (0, 40), "legs": (5, 34)}
    for r, slot in enumerate(SLOTS):
        y = top + r * cell + cell / 2
        out.append(f'<text x="20" y="{y + 8}" font-family="Helvetica" font-size="22" '
                   f'font-weight="bold" fill="#FFF2D6">{slot.title()}</text>')
        for t in range(6):
            x = left + t * cell + cell / 2
            cx, cy = centre[slot]
            s = scale[slot]
            out.append(f'<rect x="{x - cell / 2 + 6}" y="{y - cell / 2 + 6}" width="{cell - 12}" '
                       f'height="{cell - 28}" rx="12" fill="#F3E9DC"/>')
            out.append(f'<g transform="translate({x} {y - 8}) scale({s}) translate({-cx} {-cy})">'
                       f'{DRAW[slot](t)}</g>')
            out.append(f'<text x="{x}" y="{y + cell / 2 - 4}" font-family="Helvetica" font-size="13" '
                       f'fill="#FFF2D6" text-anchor="middle">{NAMES[slot][t]}</text>')
    for t in range(6):
        x = left + t * cell + cell / 2
        out.append(f'<g transform="translate({x} {robots_top + 150}) scale(0.62)">'
                   f'{robot({s: t for s in SLOTS})}</g>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
            f'width="{w}" height="{h}">{"".join(out)}</svg>')


def main():
    sprites = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "assets/robot")
    sheets = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "art")
    sprites.mkdir(parents=True, exist_ok=True)
    for slot in SLOTS:
        for tier in range(6):
            (sprites / f"{slot}_{tier}.svg").write_text(sprite(slot, tier))
    (sheets / "parts_sheet.svg").write_text(sheet())
    print(f"wrote {len(SLOTS) * 6} parts to {sprites}/ and {sheets}/parts_sheet.svg")


if __name__ == "__main__":
    main()

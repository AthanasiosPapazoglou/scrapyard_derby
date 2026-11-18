"""Scrapyard Derby - the app icon.

The scrap robot's paint-can head (the same drawing as the game sprite, from
make_style_test.py), big and tilted, peeking over the dirt hill in front of
the dusk sky, the low sun and the scrap heaps.

    python3 art/make_icon.py

Writes three 1024 x 1024 SVGs to art/icon/:
  icon.svg                  the full icon (iOS, web, older Android)
  adaptive_background.svg   Android adaptive icon, back layer (sky, sun,
                            heaps)
  adaptive_foreground.svg   Android adaptive icon, front layer (head and
                            hill, shrunk into the safe zone)
plus icon_maskable.svg (web "maskable" icon: the full icon with the
content shrunk into the safe circle).

`flutter test tool/render_icons_test.dart` turns them into every PNG the
platforms need. Standard library only.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_style_test import head  # noqa: E402  (the game's own drawing)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icon")
S = 1024
C = S / 2

# World colours (lib/game/palette.dart).
SKY_TOP = "#2E3558"
SKY_MID = "#C9605A"
SKY_HORIZON = "#F4B868"
SUN = "#FCD98A"
HEAP_FAR = "#6E3F4E"
HEAP_NEAR = "#4E2B38"
DIRT = "#7A4A30"
DIRT_HIGHLIGHT = "#B8743E"
DIRT_SPECK = "#5C3522"
INK = "#2B1D16"

DEFS = f"""<defs>
  <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{SKY_TOP}"/>
    <stop offset="0.55" stop-color="{SKY_MID}"/>
    <stop offset="1" stop-color="{SKY_HORIZON}"/>
  </linearGradient>
</defs>"""


def back():
    """Sky, low sun and two rows of scrap heaps, full bleed."""
    return f"""
<rect width="{S}" height="{S}" fill="url(#sky)"/>
<circle cx="805" cy="585" r="140" fill="{SUN}"/>
<path d="M0,690 L90,610 L170,650 L250,560 L330,620 L420,590 L470,640
         L560,560 L640,600 L720,540 L800,610 L880,570 L960,630 L1024,600
         L1024,1024 L0,1024 Z" fill="{HEAP_FAR}"/>
<rect x="780" y="520" width="120" height="26" rx="6" fill="{HEAP_FAR}"
      transform="rotate(-18 840 533)"/>
<path d="M0,760 L120,700 L230,740 L330,690 L470,745 L600,700 L720,750
         L850,705 L1024,745 L1024,1024 L0,1024 Z" fill="{HEAP_NEAR}"/>"""


def front():
    """The head peeking over the hill crest (ink-outlined dirt)."""
    # The head's origin is its neck joint; ~112 units tall with antenna.
    return f"""
<g transform="translate(500 868) rotate(-9) scale(6.2)">{head()}</g>
<path d="M-900,900 Q200,790 512,818 Q820,846 1924,740 L1924,1900 L-900,1900 Z"
      fill="{DIRT}" stroke="{INK}" stroke-width="14" stroke-linejoin="round"/>
<path d="M-900,930 Q200,822 512,850 Q820,878 1924,772" fill="none"
      stroke="{DIRT_HIGHLIGHT}" stroke-width="22" stroke-linecap="round"/>
<circle cx="250" cy="935" r="16" fill="{DIRT_SPECK}"/>
<circle cx="700" cy="960" r="22" fill="{DIRT_SPECK}"/>
<circle cx="880" cy="915" r="12" fill="{DIRT_SPECK}"/>
<circle cx="430" cy="990" r="11" fill="{DIRT_SPECK}"/>"""


def shrunk(body, k):
    """[body] scaled by [k] around the centre (safe zones)."""
    return (f'<g transform="translate({C} {C}) scale({k}) '
            f'translate({-C} {-C})">{body}</g>')


def svg(body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}" '
            f'width="{S}" height="{S}">\n{DEFS}\n{body}\n</svg>\n')


def main():
    os.makedirs(OUT, exist_ok=True)
    files = {
        "icon.svg": svg(back() + front()),
        # Android masks the 108 dp layers to ~72 dp and may shift them a
        # little: keep the head inside the middle ~2/3.
        "adaptive_background.svg": svg(back()),
        "adaptive_foreground.svg": svg(shrunk(front(), 0.68)),
        # Web maskable icons: everything important inside the 80% circle.
        "icon_maskable.svg": svg(back() + shrunk(front(), 0.8)),
    }
    for name, text in files.items():
        with open(os.path.join(OUT, name), "w") as f:
            f.write(text)
        print("wrote", os.path.join("art/icon", name))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate Crater Bowl brand SVGs (original art). Wordmark glyphs are converted to
paths from assets/fonts/Oswald.ttf (OFL) so the SVGs render without the font.
Usage: python3 tools/brand/build_logo.py  -> assets/brand/*.svg"""
import os
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "brand")
SPACE, NAVY, CYAN, ORANGE, GOLD, CREAM, GREY = "#07080F", "#0E1424", "#5CE1FF", "#FF6A1F", "#F2BF26", "#FFF4E0", "#8A8C94"

font = TTFont(os.path.join(ROOT, "assets", "fonts", "Oswald.ttf"))
font = instantiateVariableFont(font, {"wght": 700})
gs, cmap, hmtx = font.getGlyphSet(), font.getBestCmap(), font["hmtx"]
UPM = font["head"].unitsPerEm

def text_path(s, x, y, size, tracking=0.04):
    """SVG path data for s, baseline at (x, y), cap height ~ size*0.81."""
    sc = size / UPM
    d, cx = [], x
    for ch in s:
        g = cmap.get(ord(ch))
        if g is None:
            continue
        pen = SVGPathPen(gs)
        gs[g].draw(TransformPen(pen, (sc, 0, 0, -sc, cx, y)))
        d.append(pen.getCommands())
        cx += hmtx[g][0] * sc + size * tracking
    return " ".join(d), cx - x - size * tracking

def emblem(cx=128, cy=128, s=1.0):
    """The mark: a football launching out of a lunar crater, cyan crater rim."""
    def p(x, y): return f"{cx + x * s:.1f} {cy + y * s:.1f}"
    stars = "".join(f'<circle cx="{cx + x * s:.1f}" cy="{cy + y * s:.1f}" r="{r * s:.1f}" fill="{CREAM}" opacity="{o}"/>'
                    for x, y, r, o in [(-78, -82, 2.2, .9), (-40, -98, 1.4, .6), (70, -92, 1.8, .8), (90, -50, 1.2, .5), (-96, -30, 1.3, .5)])
    return f'''
  {stars}
  <ellipse cx="{cx}" cy="{cy + 52 * s:.1f}" rx="{100 * s:.1f}" ry="{34 * s:.1f}" fill="{GREY}" opacity="0.35"/>
  <ellipse cx="{cx}" cy="{cy + 50 * s:.1f}" rx="{86 * s:.1f}" ry="{26 * s:.1f}" fill="{NAVY}" stroke="{CYAN}" stroke-width="{6 * s:.1f}"/>
  <ellipse cx="{cx}" cy="{cy + 54 * s:.1f}" rx="{64 * s:.1f}" ry="{15 * s:.1f}" fill="{SPACE}"/>
  <path d="M {p(-30, 40)} Q {p(-14, -6)} {p(18, -30)}" stroke="{ORANGE}" stroke-width="{9 * s:.1f}" stroke-linecap="round" fill="none" opacity="0.9"/>
  <path d="M {p(-48, 44)} Q {p(-36, 8)} {p(-6, -18)}" stroke="{ORANGE}" stroke-width="{5 * s:.1f}" stroke-linecap="round" fill="none" opacity="0.55"/>
  <g transform="translate({cx + 22 * s:.1f} {cy - 34 * s:.1f}) rotate(-38) scale({s})">
    <path d="M -58 0 Q 0 -46 58 0 Q 0 46 -58 0 Z" fill="{GOLD}" stroke="{SPACE}" stroke-width="5"/>
    <path d="M -40 -13 Q -46 0 -40 13 M 40 -13 Q 46 0 40 13" stroke="{SPACE}" stroke-width="4" fill="none" opacity="0.55"/>
    <path d="M -20 0 L 20 0" stroke="{CREAM}" stroke-width="5" stroke-linecap="round"/>
    {"".join(f'<path d="M {x} -7 L {x} 7" stroke="{CREAM}" stroke-width="4" stroke-linecap="round"/>' for x in (-14, -5, 5, 14))}
  </g>'''

def write(name, svg):
    with open(os.path.join(OUT, name), "w") as f:
        f.write(svg)
    print("wrote", name)

def icon():
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs><radialGradient id="bg" cx="50%" cy="38%" r="70%"><stop offset="0" stop-color="#16203A"/><stop offset="1" stop-color="{SPACE}"/></radialGradient></defs>
  <rect x="8" y="8" width="240" height="240" rx="52" fill="url(#bg)"/>
  <rect x="8" y="8" width="240" height="240" rx="52" fill="none" stroke="{CYAN}" stroke-opacity="0.35" stroke-width="3"/>
  {emblem(128, 132, 0.95)}
</svg>'''

def wordmark_svg(stacked):
    if stacked:
        w, h = 640, 520
        d1, w1 = text_path("CRATER", 0, 0, 150)
        d2, w2 = text_path("BOWL", 0, 0, 150)
        body = emblem(320, 150, 1.25)
        body += f'<path transform="translate({(w - w1) / 2:.1f} 390)" d="{d1}" fill="{CREAM}"/>'
        body += f'<path transform="translate({(w - w2) / 2:.1f} 510)" d="{d2}" fill="{CYAN}"/>'
        h = 530
    else:
        w, h = 1200, 300
        d1, w1 = text_path("CRATER", 0, 0, 190)
        d2, w2 = text_path("BOWL", 0, 0, 190)
        gap = 40
        x0 = 290
        body = emblem(140, 150, 1.0)
        body += f'<path transform="translate({x0} 232)" d="{d1}" fill="{CREAM}"/>'
        body += f'<path transform="translate({x0 + w1 + gap:.1f} 232)" d="{d2}" fill="{CYAN}"/>'
        w = int(x0 + w1 + gap + w2 + 30)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}\n</svg>'

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("icon.svg", icon())
    write("logo_wide.svg", wordmark_svg(False))
    write("logo_stacked.svg", wordmark_svg(True))

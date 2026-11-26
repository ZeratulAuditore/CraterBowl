#!/usr/bin/env python3
"""Build the UI/body fonts from their google/fonts originals (OFL, no Reserved Font Name).

Every font size in the game was tuned for Oswald, whose capitals are 0.81 em tall. Teko's are
0.62 em and Barlow Semi Condensed's 0.70, so at the same font_size they read 15-25% smaller.
Rather than retune ~100 sizes, rescale the fonts once: lowering unitsPerEm scales glyphs,
advances and metrics together (renderers draw size/UPM per unit). Teko's line box is then reset
to Oswald's proportions (in Oswald-sized em) so layouts keep their height.

Usage: python3 tools/brand/scale_fonts.py   (sources in tools/brand/font_src -> assets/fonts)"""
import os
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools", "brand", "font_src")
OUT = os.path.join(ROOT, "assets", "fonts")
OSWALD_CAP, OSWALD_ASC, OSWALD_DESC = 0.810, 1.193, 0.289  # em, from Oswald's OS/2 + hhea

def build(src, dst, cap_target, line_like_oswald):
    f = TTFont(os.path.join(SRC, src))
    os2, hhea, head = f["OS/2"], f["hhea"], f["head"]
    upm = round(os2.sCapHeight / cap_target)          # cap height -> cap_target em
    head.unitsPerEm = upm
    if line_like_oswald:
        # same room above the capitals and below the baseline as Oswald, so text centers the same
        asc, desc = round((cap_target + OSWALD_ASC - OSWALD_CAP) * upm), round(OSWALD_DESC * upm)
        hhea.ascent, hhea.descent, hhea.lineGap = asc, -desc, 0
        os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = asc, -desc, 0
        os2.usWinAscent, os2.usWinDescent = asc, desc
    f.save(os.path.join(OUT, dst))
    print("%s -> %s  upm %d" % (src, dst, upm))

# Teko a little under Oswald's cap height: it is wider, so a full match overflows the nav bar.
build("Teko-VF.ttf", "Teko-UI.ttf", 0.75, True)
# Body text: match x-height feel without making lines much wider (caps 0.77 em).
build("BarlowSemiCondensed-Medium.ttf", "BarlowSemiCondensed-Medium-UI.ttf", 0.77, False)
build("BarlowSemiCondensed-SemiBold.ttf", "BarlowSemiCondensed-SemiBold-UI.ttf", 0.77, False)

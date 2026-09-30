"""The WWII pack's facility pictures: each of its 15 facilities drawn as a
1940s engineering plate - ink line and a light wash on the look's paper - in
the original's three sizes (SCHEMA.md section 14):

    packs/ww2/art/facilities/<id>.png              400x200  Encyclopedia picture: the plate
    packs/ww2/art/portraits/facilities/<id>.png    122x50   portrait: the drawing alone
    packs/ww2/art/miniatures/facilities/<id>.png    61x25   list miniature

    python tools\\look\\make_ww2_facilities.py [<id> ...]

Everything is drawn here, from straight lines, arcs and hatching - no
photograph, scan or third-party picture goes in - so the pictures are the
project's own work and the same bytes come out every run. No flag, badge or
marking is drawn on anything (TeeJ, 2026-09-29: no Nazi symbols in the game
at all; a pennant is plain).

Each drawing is a side elevation (a section, for the minefield and the
fortress line) in its own 368 x 150 space, the ground line at y = 128. The
plate draws it at 1:1 inside a double border over a title strip (the plate's
number, in the pack's order, and the facility's name from facilities.json);
the portrait and the miniature draw it again smaller with heavier lines, so
it still reads. Colours are look.json's tokens; the paper is
packs/ww2/look/paper.png and the lettering the look's own faces. Needs Pillow
and numpy.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PACK = os.path.join(ROOT, "packs", "ww2")
ART = os.path.join(PACK, "art")
SS = 4                     # drawn at four times the size, then brought down
W, H, GL = 368.0, 150.0, 128.0


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


LOOK = json.load(open(os.path.join(PACK, "look.json"), encoding="utf-8"))
PAPER = hexrgb(LOOK["colors"]["paper"])
PAPER_EDGE = hexrgb(LOOK["colors"]["paper_edge"])
INK = hexrgb(LOOK["colors"]["ink"])
INK_MUTED = hexrgb(LOOK["colors"]["ink_muted"])
WASH = (0xdc, 0xcf, 0xae)          # a light wash: the paper, shaded
WASH_DARK = (0xc4, 0xb4, 0x8e)     # and a darker one, for what is in shadow
GLASS = (0x8e, 0x86, 0x74)         # a window, a door, an opening
FONT_NAME = os.path.join(PACK, "look", "fonts", "Oswald-Variable.ttf")
FONT_PLATE = os.path.join(PACK, "look", "fonts", "CourierPrime-Bold.ttf")


class Pen:
    """Draws in the 368 x 150 drawing space onto an RGBA canvas at SS times
    the output size: `k` output px per unit, offset (ox, oy) in output px,
    strokes `wm` times heavier (the small sizes), hatching only when `fine`."""

    def __init__(self, canvas, k, ox, oy, wm=1.0, fine=True):
        self.c, self.k, self.ox, self.oy, self.wm, self.fine = canvas, k, ox, oy, wm, fine
        self.d = ImageDraw.Draw(canvas)

    def P(self, x, y):
        return ((self.ox + x * self.k) * SS, (self.oy + y * self.k) * SS)

    def w(self, w):
        return max(1, int(round(w * self.k * self.wm * SS)))

    def line(self, pts, w=1.0, color=INK):
        pts = [self.P(*p) for p in pts]
        self.d.line(pts, fill=color + (255,), width=self.w(w), joint="curve")

    def poly(self, pts, fill=WASH, w=1.0, color=INK):
        q = [self.P(*p) for p in pts]
        if fill is not None:
            self.d.polygon(q, fill=fill + (255,))
        if w:
            self.d.line(q + [q[0]], fill=color + (255,), width=self.w(w), joint="curve")

    def rect(self, x0, y0, x1, y1, fill=WASH, w=1.0):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill, w)

    def ellipse(self, x0, y0, x1, y1, fill=WASH, w=1.0, color=INK):
        a, b = self.P(x0, y0), self.P(x1, y1)
        self.d.ellipse([a, b], fill=None if fill is None else fill + (255,), outline=color + (255,) if w else None, width=self.w(w) if w else 0)

    def circle(self, cx, cy, r, fill=WASH, w=1.0):
        self.ellipse(cx - r, cy - r, cx + r, cy + r, fill, w)

    def arc(self, x0, y0, x1, y1, a0, a1, w=1.0, color=INK):
        self.d.arc([self.P(x0, y0), self.P(x1, y1)], a0, a1, fill=color + (255,), width=self.w(w))

    def hatch(self, pts, spacing=3.0, angle=45.0, w=0.5, color=INK_MUTED):
        """Parallel lines clipped to the polygon: shade, earth, concrete."""
        if not self.fine and spacing < 4:
            spacing *= 1.6
        mask = Image.new("L", self.c.size, 0)
        ImageDraw.Draw(mask).polygon([self.P(*p) for p in pts], fill=255)
        lay = Image.new("RGBA", self.c.size, color + (0,))
        ld = ImageDraw.Draw(lay)
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        cx, cy, r = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, math.hypot(max(xs) - min(xs), max(ys) - min(ys))
        t = math.radians(angle)
        dx, dy, nx, ny = math.cos(t), math.sin(t), -math.sin(t), math.cos(t)
        width = max(1, int(round(w * self.k * SS * (1.0 if self.fine else 0.8))))
        s = -r
        while s <= r:
            a = (cx + nx * s - dx * r, cy + ny * s - dy * r)
            b = (cx + nx * s + dx * r, cy + ny * s + dy * r)
            ld.line([self.P(*a), self.P(*b)], fill=color + (255,), width=width)
            s += spacing
        a = np.asarray(lay.getchannel("A"), np.uint16) * np.asarray(mask, np.uint16) // 255
        lay.putalpha(Image.fromarray(a.astype(np.uint8), "L"))
        self.c.alpha_composite(lay)

    # ---- the pieces every drawing uses ----

    def ground(self, x0=0.0, x1=W, y=GL, depth=10.0):
        self.hatch([(x0, y), (x1, y), (x1, y + depth), (x0, y + depth)], 3.2, 55, 0.5)
        self.line([(x0, y), (x1, y)], 1.8)

    def water(self, x0, x1, y, rows=3, gap=5.0):
        for i in range(rows):
            yy = y + i * gap
            n = max(2, int((x1 - x0) / 2))
            pts = [(x0 + (x1 - x0) * j / n, yy + 1.2 * math.sin((x0 + (x1 - x0) * j / n) / 4.0 + i)) for j in range(n + 1)]
            self.line(pts, 0.9 if i == 0 else 0.6, INK if i == 0 else INK_MUTED)

    def windows(self, x0, y0, cols, rows, ww, wh, gx, gy):
        for r in range(rows):
            for c in range(cols):
                x, y = x0 + c * (ww + gx), y0 + r * (wh + gy)
                self.rect(x, y, x + ww, y + wh, GLASS, 0.5)

    def lattice(self, x0, y0, x1, y1, bays, w=0.7, vertical=True):
        """A braced girder or tower: two chords, cross-braced bays."""
        if vertical:
            self.line([(x0, y0), (x0, y1)], w * 1.4)
            self.line([(x1, y0), (x1, y1)], w * 1.4)
            for i in range(bays):
                a, b = y0 + (y1 - y0) * i / bays, y0 + (y1 - y0) * (i + 1) / bays
                self.line([(x0, a), (x1, b)], w)
                self.line([(x1, a), (x0, b)], w)
                self.line([(x0, b), (x1, b)], w)
        else:
            self.line([(x0, y0), (x1, y0)], w * 1.4)
            self.line([(x0, y1), (x1, y1)], w * 1.4)
            for i in range(bays):
                a, b = x0 + (x1 - x0) * i / bays, x0 + (x1 - x0) * (i + 1) / bays
                self.line([(a, y0), (b, y1)], w)
                self.line([(a, y1), (b, y0)], w)
                self.line([(b, y0), (b, y1)], w)

    def smoke(self, x, y, n=4):
        for i in range(n):
            r = 3.0 + i * 1.6
            self.circle(x + i * 4.5, y - i * 6.5, r, None, 0.5)

    def pennant(self, x, y0, y1):
        """A flagpole with a plain pennant: no emblem on anything."""
        self.line([(x, y0), (x, y1)], 0.9)
        self.poly([(x, y1), (x + 16, y1 + 4), (x, y1 + 8)], WASH_DARK, 0.6)

    def tree(self, x, y, s=1.0):
        self.line([(x, y), (x, y - 10 * s)], 1.0)
        self.circle(x, y - 16 * s, 8 * s, WASH, 0.7)


# ---- the fifteen drawings ---------------------------------------------------

def headquarters(p):
    p.tree(22, GL, 1.1)
    p.tree(346, GL, 1.1)
    for x0, x1 in ((42, 134), (234, 326)):                                   # the wings
        p.rect(x0, 76, x1, 122)
        p.rect(x0 - 2, 72, x1 + 2, 76, WASH_DARK, 0.8)
        p.windows(x0 + 9, 82, 5, 2, 9, 13, 7.5, 9)
        p.rect(x0, 118, x1, 122, WASH_DARK, 0.6)
    p.rect(132, 64, 236, 122)                                                # the portico
    p.poly([(128, 62), (184, 36), (240, 62)], WASH, 1.0)
    p.poly([(140, 59), (184, 41), (228, 59)], None, 0.5)
    p.rect(128, 58, 240, 64, WASH_DARK, 0.9)
    for i in range(6):
        x = 140 + i * 17.6
        p.rect(x - 2.6, 64, x + 2.6, 118, WASH, 0.7)
        p.hatch([(x + 0.6, 64), (x + 2.6, 64), (x + 2.6, 118), (x + 0.6, 118)], 1.4, 90, 0.35)
    p.rect(172, 96, 196, 118, GLASS, 0.6)                                    # the door
    for i, (a, b) in enumerate(((150, 218), (144, 224), (138, 230))):         # the steps
        p.rect(a, 118 + i * 3.4, b, 121.4 + i * 3.4, WASH, 0.6)
    p.pennant(184, 36, 14)
    p.ground()


def shipyard(p):
    p.ground(0, 262)
    p.water(262, W, GL + 3, 4, 5)
    p.line([(20, 120), (300, 138)], 1.2)                                     # the slipway
    p.rect(4, 96, 40, GL, WASH, 0.9)                                         # the shed
    p.poly([(2, 96), (22, 84), (42, 96)], WASH_DARK, 0.9)
    p.rect(14, 108, 30, GL, GLASS, 0.6)
    # the hull on the slip, keel along the ways: plated aft, bare frames forward
    def keel(x):
        return 115.0 + (x - 80) * 0.054

    def deck(x):
        return 70.0 - (x - 70) * 0.033

    plated = [(70, deck(70)), (170, deck(170)), (170, keel(170))] + \
        [(80 - 14 * math.sin(math.pi / 2 * i / 8), keel(80) - (keel(80) - 96) * i / 8 - 0 * i) for i in range(9)]
    p.poly(plated, WASH, 1.2)
    p.hatch(plated, 2.2, 0, 0.4)
    for i in range(1, 13):                                                  # the frames
        x = 170 + i * 7.6
        top = deck(x)
        bottom = keel(x) if x < 246 else keel(246) - (x - 246) * 2.6
        p.line([(x, top), (x, bottom)], 0.6)
    p.line([(170, deck(170)), (262, deck(262))], 1.0)                        # the sheer strake
    p.line([(170, keel(170)), (246, keel(246)), (266, deck(266) + 2), (268, deck(268) - 2)], 1.2)  # keel and stem
    for x in (100, 150, 200):                                                # the blocks under her
        p.rect(x - 4, 116 + (x - 20) * 0.064, x + 4, 121 + (x - 20) * 0.064, WASH_DARK, 0.6)
    # the gantry crane over the slip
    p.lattice(52, 22, 60, 118, 8)
    p.lattice(278, 22, 286, 134, 9)
    p.lattice(52, 16, 286, 24, 20, 0.6, vertical=False)
    p.rect(168, 24, 180, 30, WASH_DARK, 0.7)
    p.line([(174, 30), (174, 58)], 0.6)
    p.line([(170, 58), (178, 58), (174, 62)], 0.7)


def advanced_shipyard(p):
    p.rect(0, 100, 92, GL + 10, WASH, 1.0)                                   # the quay
    p.hatch([(0, 100), (92, 100), (92, GL + 10), (0, GL + 10)], 3.2, 55, 0.5)
    p.line([(0, 100), (92, 100)], 1.8)
    p.water(92, W, 108, 5, 5)
    # a battleship alongside: hull, turrets, bridge, funnel, mast - no flag
    hull = [(104, 88), (330, 88), (352, 84), (340, 108), (116, 108), (106, 100)]
    p.poly(hull, WASH, 1.2)
    p.hatch([(116, 100), (340, 100), (336, 108), (116, 108)], 2.0, 0, 0.4)
    p.rect(150, 80, 290, 88, WASH, 0.8)
    for x, base, d, glen in ((180, 80, -1, 30), (292, 80, 1, 22), (322, 88, 1, 24)):   # turrets, guns
        p.line([(x + 8 * d, base - 5), (x + (8 + glen) * d, base - 7)], 1.4)
        p.poly([(x - 10, base), (x + 10, base), (x + 8, base - 8), (x - 8, base - 8)], WASH_DARK, 0.8)
    p.rect(214, 58, 246, 80, WASH, 0.9)                                      # the bridge
    p.rect(220, 44, 240, 58, WASH, 0.8)
    p.windows(223, 48, 3, 1, 4, 3, 2, 0)
    p.rect(252, 50, 264, 80, WASH_DARK, 0.9)                                 # the funnel
    p.rect(250, 47, 266, 51, WASH_DARK, 0.7)
    p.line([(230, 44), (230, 14)], 0.9)                                      # the tripod mast
    p.line([(230, 22), (222, 44)], 0.6)
    p.line([(230, 22), (238, 44)], 0.6)
    p.rect(225, 18, 235, 24, WASH, 0.6)                                      # its fire-control top
    # the hammerhead crane on the quay
    p.lattice(38, 26, 50, 100, 9)
    p.lattice(6, 16, 126, 26, 16, 0.6, vertical=False)
    p.rect(30, 12, 56, 18, WASH_DARK, 0.7)
    p.line([(116, 26), (116, 60)], 0.6)
    p.line([(112, 60), (120, 60), (116, 64)], 0.7)


def training_facility(p):
    for i in range(3):                                                       # the huts
        x = 12 + i * 78
        p.rect(x, 98, x + 66, GL)
        p.poly([(x - 3, 98), (x + 33, 82), (x + 69, 98)], WASH_DARK, 0.9)
        p.hatch([(x + 33, 82), (x + 69, 98), (x + 33, 98)], 2.0, 70, 0.35)
        p.windows(x + 6, 104, 4, 1, 8, 8, 7.5, 0)
        p.rect(x + 28, 114, x + 38, GL, GLASS, 0.6)
    p.pennant(252, GL, 50)
    # the assault course: a wall, a scramble frame, hurdles
    p.rect(270, 104, 286, GL, WASH, 0.9)
    p.hatch([(270, 104), (286, 104), (286, GL), (270, GL)], 2.4, 0, 0.35)
    p.line([(296, GL), (314, 90), (332, GL)], 1.0)
    for i in range(1, 5):
        y = GL - i * 7.6
        p.line([(296 + (GL - y) * 18 / 38, y), (332 - (GL - y) * 18 / 38, y)], 0.6)
    for x in (340, 356):
        p.line([(x, GL), (x, 116)], 0.8)
        p.line([(x + 8, GL), (x + 8, 116)], 0.8)
        p.line([(x - 1, 116), (x + 9, 116)], 1.0)
    p.ground()


def advanced_training_facility(p):
    p.rect(14, 70, 206, GL)                                                  # two storeys
    p.rect(12, 66, 208, 70, WASH_DARK, 0.8)
    p.windows(22, 78, 9, 2, 8, 12, 12.5, 10)
    p.rect(92, 30, 128, 70, WASH, 1.0)                                       # the clock tower
    p.poly([(88, 30), (110, 14), (132, 30)], WASH_DARK, 0.9)
    p.circle(110, 44, 8, WASH, 0.8)
    p.line([(110, 44), (110, 38.5)], 0.7)
    p.line([(110, 44), (114, 46)], 0.7)
    p.rect(102, 108, 118, GL, GLASS, 0.6)
    # the range: three targets on posts
    for x in (222, 240, 258):
        p.line([(x, GL), (x, 112)], 0.8)
        p.rect(x - 6, 96, x + 6, 112, WASH, 0.7)
        p.circle(x, 104, 4.2, None, 0.5)
        p.circle(x, 104, 1.6, INK_MUTED, 0.4)
    # the parachute tower, a canopy coming down beside it
    p.lattice(288, 22, 312, GL, 10)
    p.line([(270, 22), (330, 22)], 1.2)
    p.line([(276, 22), (276, 30)], 0.5)
    p.arc(318, 34, 352, 58, 180, 360, 1.0)
    p.line([(318, 46), (335, 74)], 0.4)
    p.line([(352, 46), (335, 74)], 0.4)
    p.line([(335, 46), (335, 74)], 0.4)
    p.circle(335, 77, 2.6, INK_MUTED, 0.4)
    p.ground()


def construction_yard(p):
    p.rect(8, 84, 110, GL)                                                   # the workshop
    p.poly([(4, 84), (59, 62), (114, 84)], WASH_DARK, 0.9)
    p.rect(34, 96, 84, GL, GLASS, 0.6)
    for x in (46.5, 59, 71.5):
        p.line([(x, 96), (x, GL)], 0.5, INK)
    p.lattice(132, 30, 140, GL, 10)                                          # the derrick
    p.line([(136, 110), (228, 42)], 1.4)
    p.line([(136, 30), (228, 42)], 0.6)
    p.line([(228, 42), (228, 76)], 0.6)
    p.rect(206, 76, 250, 82, WASH_DARK, 0.8)                                 # a girder on the hook
    p.line([(228, 42), (206, 76)], 0.3)
    p.line([(228, 42), (250, 76)], 0.3)
    # a Bailey bridge over a stream
    p.ground(0, 262, GL)
    p.poly([(262, GL), (272, 140), (330, 140), (340, GL), (W, GL), (W, 146), (262, 146)], WASH, 0)
    p.hatch([(262, GL), (272, 140), (262, 140)], 3.0, 55, 0.5)
    p.hatch([(340, GL), (W, GL), (W, 140), (330, 140)], 3.0, 55, 0.5)
    p.line([(262, GL), (272, 140), (330, 140), (340, GL), (W, GL)], 1.6)
    p.water(274, 328, 134, 2, 3)
    p.lattice(252, 104, 352, 124, 8, 0.8, vertical=False)
    p.rect(250, 124, 354, GL, WASH_DARK, 0.8)


def advanced_construction_yard(p):
    p.rect(12, 76, 222, GL)                                                  # the works, sawtooth roofed
    for i in range(7):
        x = 12 + i * 30
        p.poly([(x, 76), (x + 22, 56), (x + 22, 76)], WASH_DARK, 0.8)
        p.rect(x + 22, 56, x + 30, 76, GLASS, 0.5)
    p.windows(20, 86, 12, 1, 10, 14, 7.2, 0)
    p.rect(92, 106, 132, GL, GLASS, 0.6)
    for x in (236, 256):                                                     # the chimneys
        p.poly([(x, GL), (x + 2, 22), (x + 10, 22), (x + 12, GL)], WASH, 0.9)
        for y in (32, 46):
            p.line([(x + 1.6, y), (x + 10.4, y)], 0.6)
        p.smoke(x + 6, 14, 4)
    # the travelling crane over the stock
    p.lattice(284, 44, 290, GL, 8)
    p.lattice(350, 44, 356, GL, 8)
    p.lattice(280, 38, 360, 44, 10, 0.6, vertical=False)
    p.line([(318, 44), (318, 84)], 0.6)
    p.rect(300, 84, 336, 90, WASH_DARK, 0.7)
    for i in range(3):
        p.rect(296 + i * 4, 116 - i * 6, 344 - i * 4, 122 - i * 6, WASH_DARK, 0.6)
    p.rect(292, 122, 348, GL, WASH_DARK, 0.6)
    p.ground()


def mine(p):
    heap = [(12, GL), (74, 80), (146, GL)]                                   # the spoil heap
    p.poly(heap, WASH, 1.0)
    p.hatch(heap, 3.0, 30, 0.45)
    p.lattice(158, 36, 186, GL, 7)                                           # the headframe
    p.line([(172, 36), (218, 100)], 1.2)
    p.circle(172, 30, 11, WASH, 1.0)
    for a in range(0, 180, 30):
        t = math.radians(a)
        p.line([(172 - 11 * math.cos(t), 30 - 11 * math.sin(t)), (172 + 11 * math.cos(t), 30 + 11 * math.sin(t))], 0.5)
    p.line([(183, 30), (226, 90)], 0.4)                                      # the winding rope
    p.rect(204, 84, 276, GL)                                                 # the engine house
    p.poly([(200, 84), (240, 66), (280, 84)], WASH_DARK, 0.9)
    p.windows(212, 92, 4, 1, 9, 14, 8, 0)
    p.poly([(286, GL), (289, 26), (299, 26), (302, GL)], WASH, 0.9)          # its chimney
    p.smoke(294, 18, 4)
    p.line([(150, GL - 1.5), (W, GL - 1.5)], 0.7)                            # the rails, a tub
    p.poly([(318, 110), (348, 110), (344, 124), (322, 124)], WASH_DARK, 0.9)
    p.circle(326, 125.5, 2.6, WASH, 0.6)
    p.circle(340, 125.5, 2.6, WASH, 0.6)
    p.ground()


def refinery(p):
    for x0, x1, top in ((40, 56, 18), (72, 84, 38)):                        # the columns
        p.rect(x0, top, x1, GL)
        p.ellipse(x0, top - 3, x1, top + 3, WASH, 0.8)
        for y in range(top + 16, int(GL) - 6, 22):
            p.line([(x0 - 5, y), (x1 + 5, y)], 0.8)
            p.line([(x0 - 5, y), (x0 - 5, y - 5)], 0.4)
            p.line([(x1 + 5, y), (x1 + 5, y - 5)], 0.4)
        p.line([(x1 + 2, top + 4), (x1 + 2, GL)], 0.4)
    for x0, x1, top in ((140, 204, 86), (216, 262, 96)):                    # the tanks
        p.rect(x0, top, x1, GL)
        p.arc(x0, top - 7, x1, top + 7, 180, 360, 0.9)
        p.hatch([(x1 - 10, top), (x1, top), (x1, GL), (x1 - 10, GL)], 1.8, 90, 0.35)
        p.line([(x0 + 6, top + 4), (x0 + 6, GL)], 0.4)
    p.circle(304, 82, 22, WASH, 1.0)                                         # the sphere on legs
    p.arc(282, 74, 326, 90, 0, 180, 0.4)
    for x in (286, 298, 310, 322):
        p.line([(x, 96), (x, GL)], 0.8)
    for y in (106, 112):                                                     # the pipes
        p.line([(56, y), (140, y)], 0.9)
        p.line([(204, y + 4), (216, y + 4)], 0.9)
        p.line([(262, y + 2), (286, y + 2)], 0.9)
    p.line([(348, GL), (348, 16)], 1.0)                                      # the flare stack
    p.poly([(348, 16), (345, 9), (348, 2), (351, 9)], WASH, 0.6)
    p.ground()


def minefield(p):
    # a section through the sea: moored mines on their cables, sinkers on the bed
    p.water(0, W, 40, 1, 0)
    for y in range(52, 120, 11):
        p.water(0, W, y, 1, 0)
    bed = [(0, 130), (60, 127), (130, 131), (200, 126), (270, 130), (330, 127), (W, 129)]
    p.poly(bed + [(W, 146), (0, 146)], WASH, 0)
    p.hatch(bed + [(W, 146), (0, 146)], 3.2, 55, 0.5)
    p.line(bed, 1.8)
    for x, y in ((56, 60), (138, 72), (222, 58), (302, 68)):
        yb = next(b for a, b in reversed(bed) if a <= x) - 1
        p.line([(x, y + 9), (x, yb - 4)], 0.6)
        p.rect(x - 5, yb - 4, x + 5, yb + 1, WASH_DARK, 0.7)
        for a in range(-150, 180, 60):
            t = math.radians(a - 90)
            p.line([(x + 8 * math.cos(t), y + 8 * math.sin(t)), (x + 12 * math.cos(t), y + 12 * math.sin(t))], 0.8)
            p.circle(x + 12.6 * math.cos(t), y + 12.6 * math.sin(t), 1.2, INK, 0.3)
        p.circle(x, y, 9, WASH, 1.1)
        p.arc(x - 9, y - 3, x + 9, y + 3, 0, 180, 0.4)


def coastal_battery(p):
    cliff = [(0, 70), (196, 70), (206, 88), (214, 104), (226, 122), (232, 146), (0, 146)]
    p.poly(cliff, WASH, 0)
    p.hatch(cliff, 3.2, 55, 0.5)
    p.line(cliff[:6], 1.8)
    p.water(226, W, 120, 5, 5)
    # the casemate: sloped concrete, an embrasure, the gun
    cas = [(104, 70), (104, 48), (170, 44), (188, 58), (188, 70)]
    p.poly(cas, WASH, 1.2)
    p.hatch([(170, 44), (188, 58), (188, 70), (170, 70)], 2.0, 80, 0.4)
    p.rect(176, 55, 188, 62, GLASS, 0.6)
    p.line([(182, 58), (236, 54)], 2.2)
    p.line([(232, 52.6), (238, 52.2), (238, 55.8)], 0.6)
    p.rect(40, 56, 66, 70, WASH, 0.9)                                        # the observation post
    p.rect(44, 60, 62, 63, GLASS, 0.4)
    p.line([(20, 70), (20, 40)], 0.6)
    p.line([(20, 40), (30, 70)], 0.3)


def heavy_coastal_battery(p):
    bluff = [(0, 100), (244, 100), (258, 114), (270, 132), (272, 146), (0, 146)]
    p.poly(bluff, WASH, 0)
    p.hatch(bluff, 3.2, 55, 0.5)
    p.line(bluff[:5], 1.8)
    p.water(268, W, 130, 4, 5)
    p.poly([(78, 100), (96, 80), (224, 80), (238, 100)], WASH, 1.2)          # the emplacement
    p.hatch([(78, 100), (96, 80), (104, 80), (88, 100)], 1.8, 60, 0.35)
    # the turret, rounded, with two guns
    p.poly([(116, 80), (116, 62), (124, 54), (196, 54), (206, 62), (206, 80)], WASH, 1.2)
    p.hatch([(196, 54), (206, 62), (206, 80), (196, 80)], 2.0, 90, 0.35)
    for y in (62, 70):
        p.line([(204, y), (300, y - 10)], 2.4)
        p.line([(298, y - 11.6), (302, y - 12), (302, y - 8)], 0.5)
    p.lattice(26, 30, 42, 100, 6)                                            # the rangefinder tower
    p.rect(18, 22, 50, 30, WASH_DARK, 0.9)
    p.line([(10, 26), (58, 26)], 1.0)


def fortifications(p):
    for row in range(3):                                                     # dragon's teeth
        for i in range(5):
            x = 14 + i * 22 + row * 11
            y = GL - row * 5
            tooth = [(x, y), (x + 7, y - 13), (x + 14, y)]
            p.poly(tooth, WASH, 0.8)
            p.hatch([(x + 7, y - 13), (x + 14, y), (x + 7, y)], 1.5, 80, 0.35)
    berm = [(128, GL), (160, 96), (236, 96), (262, GL)]                      # the pillbox under its berm
    p.poly(berm, WASH, 0.8)
    p.hatch(berm, 3.0, 40, 0.45)
    p.poly([(150, GL), (150, 96), (160, 86), (236, 86), (246, 96), (246, GL)], WASH, 1.2)
    for x in (166, 212):
        p.rect(x, 98, x + 18, 104, GLASS, 0.7)
    p.hatch([(236, 86), (246, 96), (246, GL), (236, GL)], 1.8, 90, 0.35)
    for x in range(272, 366, 18):                                            # the wire
        p.line([(x - 5, GL), (x + 5, 104)], 0.8)
        p.line([(x + 5, GL), (x - 5, 104)], 0.8)
    for x in range(272, 356, 6):
        p.circle(x + 3, 112, 4.4, None, 0.35)
    p.line([(266, 104), (360, 104)], 0.4)
    p.ground()


def hardened_airbase(p):
    arch = [(18 + 128 * (1 - math.cos(math.pi * i / 24)) / 2, GL - 58 * math.sin(math.pi * i / 24)) for i in range(25)]
    earth = [(10 + 144 * (1 - math.cos(math.pi * i / 24)) / 2, GL - 66 * math.sin(math.pi * i / 24)) for i in range(25)]
    p.poly(earth, WASH, 0.9)                                                 # the shelter, earthed over
    p.hatch(earth, 3.0, 45, 0.45)
    p.poly(arch, WASH, 1.2)
    p.poly([(38, GL), (38, 96), (126, 96), (126, GL)], GLASS, 0.7)
    for x in (60, 82, 104):
        p.line([(x, 96), (x, GL)], 0.5)
    p.rect(176, 66, 200, GL)                                                 # the control tower
    p.rect(170, 52, 206, 66, WASH, 0.9)
    p.windows(173, 55, 4, 1, 6, 7, 2.6, 0)
    p.rect(168, 49, 208, 52, WASH_DARK, 0.7)
    p.line([(188, 49), (188, 30)], 0.6)
    p.windows(182, 76, 1, 3, 12, 8, 0, 8)
    # a single-engined monoplane, no markings
    fus = [(234, 110), (248, 104), (318, 106), (346, 108), (346, 112), (318, 114), (248, 118)]
    p.poly(fus, WASH, 1.0)
    p.poly([(330, 108), (338, 92), (346, 94), (346, 108)], WASH, 0.9)
    p.line([(268, 114), (300, 114)], 2.0)
    p.rect(262, 103, 276, 106, GLASS, 0.5)
    p.line([(232, 98), (232, 124)], 0.9)
    p.line([(254, 118), (252, 124)], 0.8)
    p.circle(252, 125, 2.6, WASH_DARK, 0.6)
    p.circle(342, 116, 1.6, WASH_DARK, 0.5)
    p.line([(356, GL), (356, 86)], 0.6)                                      # the windsock
    p.poly([(356, 86), (368, 89), (368, 93), (356, 94)], WASH_DARK, 0.5)
    p.ground()


def fortress_line(p):
    # a section: the works on the surface, galleries in the ground below
    top = 66.0
    earth = [(0, top), (W, top), (W, 150), (0, 150)]
    p.poly(earth, WASH, 0)
    p.hatch(earth, 3.2, 55, 0.5)
    for shape in ([(66, top), (154, top), (154, 108), (66, 108)],             # the block
                  [(164, top), (176, top), (176, 118), (164, 118)],            # the shaft
                  [(40, 118), (340, 118), (340, 132), (40, 132)]):             # the gallery
        p.poly(shape, PAPER, 0.9)
    p.line([(46, 129), (334, 129)], 0.5)
    for i in range(6):                                                       # stairs in the block
        p.line([(140 - i * 6, 108 - i * 6.4), (146 - i * 6, 108 - i * 6.4)], 0.5)
    p.line([(0, top), (W, top)], 1.8)
    p.poly([(90, top), (92, 56), (100, 50), (120, 50), (128, 56), (130, top)], WASH, 1.2)   # the turret
    p.line([(128, 58), (168, 52)], 2.0)
    dome = [(211 + 12 * math.cos(math.pi * i / 16), top - 11 * math.sin(math.pi * i / 16)) for i in range(17)]
    p.poly(dome, WASH, 1.0)                                                  # a cloche
    p.rect(204, top - 7, 218, top - 4.6, GLASS, 0.5)
    for x in range(252, 360, 16):                                            # anti-tank rails
        p.line([(x, top), (x + 8, top - 16)], 1.3)


DRAW = {
    "headquarters": headquarters, "shipyard": shipyard, "advanced_shipyard": advanced_shipyard,
    "training_facility": training_facility, "advanced_training_facility": advanced_training_facility,
    "construction_yard": construction_yard, "advanced_construction_yard": advanced_construction_yard,
    "mine": mine, "refinery": refinery, "minefield": minefield, "coastal_battery": coastal_battery,
    "heavy_coastal_battery": heavy_coastal_battery, "fortifications": fortifications,
    "hardened_airbase": hardened_airbase, "fortress_line": fortress_line,
}


# ---- the three sizes ----------------------------------------------------------

def paper(w, h, seed):
    """The look's parchment, a different corner of it for each plate, darkened
    a little towards the edges."""
    tex = np.asarray(Image.open(os.path.join(PACK, "look", "paper.png")).convert("RGB"), np.float64)
    ox, oy = (seed * 97) % (tex.shape[1] - w), (seed * 53) % (tex.shape[0] - h)
    a = tex[oy:oy + h, ox:ox + w].copy()
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)).astype(np.float64)
    a *= (1.0 - 0.08 * np.clip(1.0 - edge / 12.0, 0.0, 1.0))[..., None]
    return Image.fromarray(np.round(a).astype(np.uint8), "RGB").convert("RGBA")


def font(path, px, weight=None):
    f = ImageFont.truetype(path, px * SS)
    if weight is not None:
        f.set_variation_by_axes([weight])
    return f


def render(fid, w, h, k, ox, oy, wm, fine):
    canvas = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    DRAW[fid](Pen(canvas, k, ox, oy, wm, fine))
    return canvas


def plate(fid, number, name):
    art = render(fid, 400, 200, 1.0, 16, 16, 1.0, True)
    d = ImageDraw.Draw(art)
    s = SS
    d.rectangle([7 * s, 7 * s, 393 * s - 1, 193 * s - 1], outline=INK + (255,), width=int(1.6 * s))
    d.rectangle([10 * s, 10 * s, 390 * s - 1, 190 * s - 1], outline=INK + (255,), width=int(0.6 * s))
    d.line([(10 * s, 170 * s), (390 * s, 170 * s)], fill=INK + (255,), width=int(0.6 * s))
    d.line([(88 * s, 170 * s), (88 * s, 190 * s)], fill=INK + (255,), width=int(0.6 * s))
    d.text((49 * s, 180.5 * s), "PLATE %d" % number, font=font(FONT_PLATE, 10), fill=INK + (255,), anchor="mm")
    label = " ".join(name.upper())                                           # letter-spaced, as a draughtsman's
    d.text((239 * s, 180.5 * s), label, font=font(FONT_NAME, 11, 500), fill=INK + (255,), anchor="mm")
    base = paper(400, 200, number)
    base.alpha_composite(art.resize((400, 200), Image.LANCZOS))
    return base.convert("RGB")


def small(fid, number, w, h, wm, fine, border):
    k = (w - 2 * border) / W
    oy = (h - H * k) / 2
    art = render(fid, w, h, k, border, oy, wm, fine)
    base = paper(w, h, number + 40)
    base.alpha_composite(art.resize((w, h), Image.LANCZOS))
    ImageDraw.Draw(base).rectangle([0, 0, w - 1, h - 1], outline=INK_MUTED + (255,))
    return base.convert("RGB")


def save(im, rel):
    path = os.path.join(ART, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)


def main():
    rows = json.load(open(os.path.join(PACK, "facilities.json"), encoding="utf-8"))["facilities"]
    ids = [r["id"] for r in rows]
    missing = sorted(set(ids) - set(DRAW))
    if missing:
        sys.exit("no drawing for: %s" % ", ".join(missing))
    only = sys.argv[1:]
    for number, r in enumerate(rows, 1):
        fid = r["id"]
        if only and fid not in only:
            continue
        save(plate(fid, number, r["display_name"]), "facilities/%s.png" % fid)
        save(small(fid, number, 122, 50, 2.3, True, 2), "portraits/facilities/%s.png" % fid)
        save(small(fid, number, 61, 25, 3.6, False, 1), "miniatures/facilities/%s.png" % fid)
        print("plate %2d  %s" % (number, fid))


if __name__ == "__main__":
    main()

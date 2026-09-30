"""The WWII pack's unit pictures: each of its 77 unit types drawn as a 1940s
engineering plate - ink line and a light wash on the look's paper, in the
style of the facility plates (make_ww2_facilities.py, whose pen and paper this
uses) - in the original's three sizes (SCHEMA.md section 14):

    packs/ww2/art/units/<id>.png                400x200  Encyclopedia picture: the plate
    packs/ww2/art/portraits/units/<id>.png      122x50   portrait: the drawing alone
    packs/ww2/art/miniatures/units/<id>.png      61x25   list miniature

    python tools\\look\\make_ww2_units.py [<id> ...]

Ships in side elevation on the water, told apart by their turrets, funnels,
bridges and decks; aircraft in side view in flight, by engine, canopy and
tail (a squadron's plate shows three in echelon, its small pictures the lead
alone); divisions by their soldiers' helmets and hats - the German, British,
American, Soviet, Japanese, Italian and French helmets, the Alpini's hat, the
Commonwealth's slouch hat - and their vehicles and boats; the special forces
by their work. Plates are numbered on from the fifteen facilities', in the
pack's order.

Everything is drawn here, from straight lines, arcs and hatching - no
photograph, scan or third-party picture goes in - so the pictures are the
project's own work and the same bytes come out every run. No flag, badge,
roundel, rune or marking is drawn on anything (TeeJ, 2026-09-29: no Nazi
symbols in the game at all).

Also writes the pictures' entry in packs/ww2/credits.json ("Unit plates"),
leaving every other entry as it is. Needs Pillow and numpy.
"""
import json
import math
import os
import re
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_ww2_facilities as F   # noqa: E402  the pen, the paper, the colours

W, H, SS = F.W, F.H, F.SS
PAPER, INK, INK_MUTED = F.PAPER, F.INK, F.INK_MUTED
WASH, WASH_DARK, GLASS = F.WASH, F.WASH_DARK, F.GLASS
PACK, ART = F.PACK, F.ART
WL = 110.0                  # a ship's waterline in the 368 x 150 drawing
FIRST_PLATE = 16            # the facilities are plates 1-15


class View:
    """A drawing's own coordinates on the pen: offset (dx, dy), scaled by s,
    mirrored with flip (so a thing drawn nose-right can face left). Strokes
    thin with the scale, a little."""

    def __init__(self, p, dx=0.0, dy=0.0, s=1.0, flip=False):
        self.p, self.dx, self.dy, self.s, self.flip = p, dx, dy, s, flip
        self.ws = max(0.55, s ** 0.5)
        self.fine = p.fine

    def T(self, x, y):
        return (self.dx + (-x if self.flip else x) * self.s, self.dy + y * self.s)

    def sub(self, dx, dy, s=1.0):
        x, y = self.T(dx, dy)
        return View(self.p, x, y, self.s * s, self.flip)

    def line(self, pts, w=1.0, color=INK):
        self.p.line([self.T(*q) for q in pts], w * self.ws, color)

    def poly(self, pts, fill=WASH, w=1.0, color=INK):
        self.p.poly([self.T(*q) for q in pts], fill, w * self.ws if w else 0, color)

    def rect(self, x0, y0, x1, y1, fill=WASH, w=1.0):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill, w)

    def circle(self, cx, cy, r, fill=WASH, w=1.0):
        x, y = self.T(cx, cy)
        self.p.circle(x, y, r * self.s, fill, w * self.ws if w else 0)

    def ellipse(self, x0, y0, x1, y1, fill=WASH, w=1.0):
        a, b = self.T(x0, y0), self.T(x1, y1)
        self.p.ellipse(min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1]), fill, w * self.ws if w else 0)

    def hatch(self, pts, spacing=3.0, angle=45.0, w=0.5):
        self.p.hatch([self.T(*q) for q in pts], spacing * max(0.7, self.s), -angle if self.flip else angle, w * self.ws)

    def curve(self, pts, n=12):
        """A smooth line through the points (Catmull-Rom), for hulls and wings."""
        out = []
        ext = [pts[0]] + list(pts) + [pts[-1]]
        for i in range(1, len(ext) - 2):
            p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
            for j in range(n):
                t = j / n
                t2, t3 = t * t, t * t * t
                out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                        + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
        out.append(pts[-1])
        return out


def small_pen(v):
    """True when the drawing is a portrait's or a miniature's: one of a thing,
    not a formation, and no fine detail."""
    return v.p.k < 0.6


# ---- the sea -----------------------------------------------------------------

def sea(p, x0=0.0, x1=W, y=WL):
    p.water(x0, x1, y + 2.5, 4, 5.5)


# ---- ships (bow to the right, the waterline at y = 0 of the ship's view) ------

def hull(v, L, free, sheer=5.0, bow_rake=10.0, stern=6.0, fill=WASH):
    """The hull above the water: freeboard `free` amidships, rising `sheer` to
    the bow, the stem raked forward by `bow_rake`."""
    top = v.curve([(0, -free + 1), (L * 0.35, -free), (L * 0.7, -free - sheer * 0.3), (L, -free - sheer)])
    pts = [(-stern * 0.2, 0)] + top + [(L + bow_rake * 0.25, -free - sheer), (L + bow_rake * 0.1, -free * 0.4), (L - bow_rake * 0.5, 0)]
    v.poly(pts, fill, 1.1)
    v.line([(0, -1.6), (L - bow_rake * 0.45, -1.6)], 0.4, INK_MUTED)          # the boot-topping
    return top


def deck_y(top, x):
    """The deck's height at x, from the hull's top line."""
    best = top[0]
    for q in top:
        if abs(q[0] - x) < abs(best[0] - x):
            best = q
    return best[1]


def turret(v, x, y, size=1.0, guns=2, fore=True, raised=0.0):
    """A gun turret on its barbette at deck height y, its barrels to the bow
    (fore) or the stern."""
    w, h = 16 * size, 6.5 * size
    if raised:
        v.rect(x - w * 0.35, y - raised, x + w * 0.35, y, WASH_DARK, 0.7)
    yb = y - raised
    d = 1 if fore else -1
    face = x + d * w * 0.5
    v.poly([(x - w * 0.5, yb), (x + w * 0.5, yb), (x + w * 0.5 - d * 2.5 * size if fore else x + w * 0.5, yb - h),
            (x - w * 0.5 if fore else x - w * 0.5 + 2.5 * size, yb - h)], WASH, 0.9)
    for g in range(guns):
        gy = yb - h * (0.35 + 0.3 * g / max(1, guns - 1)) if guns > 1 else yb - h * 0.5
        v.line([(face, gy), (face + d * 17 * size, gy - 0.6 * size)], 1.2 * size ** 0.5)


def funnel(v, x, y, w=8.0, h=16.0, rake=3.0, cap=True):
    v.poly([(x - w / 2, y), (x + w / 2, y), (x + w / 2 - rake, y - h), (x - w / 2 - rake, y - h)], WASH_DARK, 0.9)
    if cap:
        v.rect(x - w / 2 - rake - 0.6, y - h - 1.6, x + w / 2 - rake + 0.6, y - h, INK_MUTED, 0.5)


def mast(v, x, y, h=30.0, yards=1, rake=0.0):
    v.line([(x, y), (x - rake, y - h)], 0.8)
    for i in range(yards):
        yy = y - h * (0.72 + 0.12 * i)
        xx = x - rake * (0.72 + 0.12 * i)
        v.line([(xx - 6 + i * 2, yy), (xx + 6 - i * 2, yy)], 0.6)


def tower(v, x, y, tiers, w0=22.0, dw=4.0, th=6.0):
    """A bridge: `tiers` decks stacked, each narrower; windows on the top one."""
    for i in range(tiers):
        w = w0 - i * dw
        v.rect(x - w / 2, y - (i + 1) * th, x + w / 2, y - i * th, WASH if i % 2 == 0 else WASH_DARK, 0.7)
    top = y - tiers * th
    wt = w0 - (tiers - 1) * dw
    for i in range(int(wt // 4)):
        xx = x - wt / 2 + 1.5 + i * 4
        v.rect(xx, top + 1.4, xx + 2.2, top + 3.2, GLASS, 0.3)
    return top


def warship(v, s):
    """A gun ship from its spec: length, freeboard, turrets (x fraction, size,
    guns, raised, fore), funnels (x fraction, w, h), bridge (x fraction, tiers),
    masts (x fraction, h)."""
    L = s["len"]
    top = hull(v, L, s.get("free", 12), s.get("sheer", 5), s.get("rake", 10))
    for x0, x1, h in s.get("houses", []):
        a, b = x0 * L, x1 * L
        y = min(deck_y(top, a), deck_y(top, b))
        v.rect(a, y - h, b, y + 0.5, WASH, 0.8)
    for fx, size, guns, raised, fore in s.get("turrets", []):
        x = fx * L
        turret(v, x, deck_y(top, x), size, guns, fore, raised)
    for bx, tiers in s.get("bridge", []):
        x = bx * L
        y = deck_y(top, x) - s.get("house_h", 0)
        t = tower(v, x, y, tiers, s.get("bridge_w", 22), s.get("bridge_dw", 4), s.get("tier_h", 6))
        if s.get("director", True):
            v.rect(x - 4, t - 4, x + 4, t, WASH_DARK, 0.6)
    for fx, w, h, rake in s.get("funnels", []):
        x = fx * L
        funnel(v, x, deck_y(top, x) - s.get("house_h", 0), w, h, rake)
    for mx, h in s.get("masts", []):
        x = mx * L
        mast(v, x, deck_y(top, x) - s.get("house_h", 0), h, 2 if h > 30 else 1)
    for tx in s.get("tubes", []):
        x = tx * L
        y = deck_y(top, x)
        v.rect(x - 7, y - 2.6, x + 7, y, WASH_DARK, 0.5)
        v.line([(x - 9, y - 1.3), (x + 9, y - 1.3)], 0.9)
    if s.get("aircraft_crane"):
        x = s["aircraft_crane"] * L
        y = deck_y(top, x)
        v.line([(x, y), (x, y - 18), (x + 14, y - 12)], 0.6)


def carrier(v, s):
    L = s["len"]
    deck_h = s.get("deck_h", 22)
    hull(v, L, s.get("free", 12), 3, 6)
    y0 = -deck_h
    # the hangar: closed sides (armoured) or open galleries
    v.rect(L * 0.04, y0 + 2, L * 0.94, -s.get("free", 12) + 1, WASH, 0.8)
    if s.get("open_hangar"):
        for i in range(10):
            x = L * (0.1 + 0.08 * i)
            v.rect(x, y0 + 5, x + L * 0.05, y0 + 11, GLASS, 0.3)
    else:
        v.hatch([(L * 0.06, y0 + 4), (L * 0.92, y0 + 4), (L * 0.92, y0 + 9), (L * 0.06, y0 + 9)], 2.2, 90, 0.3)
    v.poly([(-L * 0.02, y0 + 2), (L * 1.03, y0 + 2), (L * 1.0, y0), (L * 0.0, y0)], WASH_DARK, 1.0)   # the flight deck
    ix = s.get("island", 0.62) * L
    iw = s.get("island_w", 26)
    v.rect(ix - iw / 2, y0 - 12, ix + iw / 2, y0, WASH, 0.8)
    v.rect(ix - iw / 2 + 3, y0 - 18, ix + iw / 2 - 4, y0 - 12, WASH, 0.7)
    for i in range(int((iw - 8) // 5)):
        v.rect(ix - iw / 2 + 4.5 + i * 5, y0 - 16.5, ix - iw / 2 + 6.8 + i * 5, y0 - 14.6, GLASS, 0.3)
    if s.get("funnel_in_island", True):
        funnel(v, ix + iw * 0.25, y0 - 12, 7, 10, 1.5)
    mast(v, ix - iw * 0.2, y0 - 18, 16, 1)
    if not small_pen(v):
        for i in range(s.get("planes", 3)):                                # aircraft parked aft
            x = L * (0.1 + 0.09 * i)
            v.poly([(x, y0), (x + 11, y0), (x + 12, y0 - 2.5), (x + 2, y0 - 2.5), (x, y0 - 5)], WASH, 0.5)


def submarine(v, s):
    L = s["len"]
    body = v.curve([(0, -1), (L * 0.1, -5), (L * 0.5, -6.5), (L * 0.9, -5.5), (L, -2)])
    v.poly([(0, 0)] + body + [(L + 3, 0)], WASH_DARK, 1.0)
    if s.get("saddle"):
        v.poly([(L * 0.3, -3), (L * 0.62, -3), (L * 0.6, 0), (L * 0.32, 0)], WASH, 0.6)
    cx = s.get("tower", 0.45) * L
    tw = s.get("tower_w", 26)
    v.poly([(cx - tw / 2, -6), (cx - tw / 2 + 4, -18), (cx + tw / 2 - 2, -18), (cx + tw / 2 + 3, -6)], WASH, 0.9)
    v.rect(cx - tw / 2 + 5, -20, cx + tw / 2 - 3, -18, WASH_DARK, 0.5)
    v.line([(cx + 2, -20), (cx + 2, -31)], 0.7)                                # the periscope standards
    v.line([(cx + 6, -20), (cx + 6, -27)], 0.6)
    gx = s.get("gun", 0.62) * L
    v.line([(gx, -6.5), (gx, -10)], 0.9)
    v.line([(gx - 2, -10), (gx + 10, -11)], 1.0)
    v.line([(L * 0.08, -6), (L * 0.95, -6)], 0.3, INK_MUTED)                  # the jumping wire's deck


def merchant(v, s):
    """A cargo ship, a tanker or a liner: forecastle, bridge house, funnel(s),
    masts with derricks, the holds between."""
    L = s["len"]
    kind = s.get("kind", "cargo")
    top = hull(v, L, s.get("free", 13), 4, 7)
    if kind == "liner":
        v.rect(L * 0.18, -s["free"] - 16, L * 0.8, -s["free"] + 0.5, WASH, 0.8)
        v.rect(L * 0.24, -s["free"] - 24, L * 0.72, -s["free"] - 16, WASH, 0.7)
        for i in range(int(L * 0.5 // 7)):
            v.circle(L * 0.2 + i * 7, -s["free"] - 10, 1.1, GLASS, 0.3)
        for i in range(4):                                                  # the lifeboats
            x = L * 0.3 + i * L * 0.1
            v.ellipse(x, -s["free"] - 28, x + L * 0.07, -s["free"] - 24.5, WASH_DARK, 0.4)
        for fx in s.get("funnels", [0.42, 0.58]):
            funnel(v, fx * L, -s["free"] - 24, 9, 16, 2.5)
        mast(v, L * 0.1, -s["free"], 26, 1, 1.5)
        mast(v, L * 0.9, -s["free"] - 2, 28, 1, 1.5)
        return
    bx = s.get("bridge", 0.5 if kind == "cargo" else 0.62) * L
    if kind == "tanker":
        v.line([(L * 0.08, -s["free"] - 3), (L * 0.95, -s["free"] - 5)], 0.5)   # the catwalk
        v.rect(bx - 12, -s["free"] - 14, bx + 12, -s["free"] + 0.5, WASH, 0.8)
        tower(v, bx, -s["free"] - 14, 1, 16, 3, 5)
        v.rect(L * 0.02, -s["free"] - 12, L * 0.16, -s["free"] + 0.5, WASH, 0.8)
        funnel(v, L * 0.08, -s["free"] - 12, 8, 12, 2)
        return
    v.rect(L * 0.84, -s["free"] - 8, L * 0.98, -s["free"] - 3, WASH, 0.7)       # the forecastle
    v.rect(bx - 16, -s["free"] - 12, bx + 16, -s["free"] + 0.5, WASH, 0.8)
    tower(v, bx, -s["free"] - 12, 2, 20, 4, 5)
    funnel(v, bx - 4, -s["free"] - 22, 8, 12, 1.5)
    for mx in (0.22, 0.74):                                                 # masts, their derricks
        x = mx * L
        mast(v, x, -s["free"], 34, 1)
        v.line([(x, -s["free"] - 6), (x + (14 if mx > 0.5 else -14), -s["free"] - 20)], 0.5)
        v.line([(x, -s["free"] - 6), (x - (14 if mx > 0.5 else -14), -s["free"] - 20)], 0.5)
    for hx in (0.12, 0.3, 0.64, 0.8):                                       # the hatches
        x = hx * L
        v.rect(x - 6, -s["free"] - 3, x + 6, -s["free"] + 0.5, WASH_DARK, 0.5)
    if s.get("deck_cargo"):
        for i, hx in enumerate((0.3, 0.64)):
            x = hx * L
            v.rect(x - 9, -s["free"] - 9, x + 9, -s["free"] - 3, WASH, 0.6)


def fleet(p, draw, specs, lead_x=None):
    """Ships in line abreast going away: the last is drawn first, smaller and
    higher (further off); the lead in front. A small picture shows the lead."""
    sea(p)
    base = View(p)
    if small_pen(base):
        specs = specs[:1]
    n = len(specs)
    if n > 1:                                                                # the sea runs back to a horizon
        far = WL - [0, 36, 60][n - 1]
        p.line([(0, far + 3), (W, far + 3)], 0.5, INK_MUTED)
        y = far + 10
        while y < WL - 4:                                                    # a light swell, finer towards the horizon
            p.line([(W * j / 60, y + 0.8 * math.sin(j * 1.3 + y)) for j in range(61)], 0.35, INK_MUTED)
            y += 7 + (y - far) * 0.12
    for i in reversed(range(n)):
        s = specs[i]
        scale = [1.0, 0.55, 0.36][i]
        L = s["len"] * scale
        lead = specs[0]["len"]
        x = ((lead_x if lead_x is not None else (W - lead) / 2 - 20) + [0, 70, 170][i]) if n > 1 else (W - L) / 2
        y = WL - [0, 36, 60][i] if n > 1 else WL
        draw(View(p, x, y, scale), s)


def one_ship(p, draw, s):
    sea(p)
    L = s["len"]
    draw(View(p, (W - L) / 2 - 6, WL), s)


# ---- aircraft (nose to the right, the fuselage's axis at y = 0) ----------------

def aircraft(v, s):
    """A side view in flight from its spec: length, engine ("inline" - a
    pointed spinner - or "radial" - a blunt cowling), canopy ("framed",
    "bubble", "long" for a crew of two or three, "hump"), tail ("round",
    "square", "pointed"), and the extras: a belly scoop, a chin radiator,
    fixed wheels in spats, a ball turret, a bomb, a camera port."""
    L = s.get("len", 120.0)
    d = s.get("depth", 11.0)
    radial = s.get("engine") == "radial"
    nose = L
    top = [(0, -d * 0.22), (L * 0.12, -d * 0.3), (L * 0.55, -d * 0.52), (L * 0.8, -d * 0.55), (nose - 3, -d * (0.55 if radial else 0.38))]
    bot = [(nose - 3, d * (0.5 if radial else 0.3)), (L * 0.8, d * 0.48), (L * 0.5, d * 0.46), (L * 0.15, d * 0.15), (0, d * 0.05)]
    v.poly(v.curve(top, 6) + v.curve(bot, 6), WASH, 1.0)
    if radial:                                                               # the cowling
        v.poly([(nose - 12, -d * 0.62), (nose - 1, -d * 0.58), (nose + 1, 0), (nose - 1, d * 0.56), (nose - 12, d * 0.54)], WASH_DARK, 0.9)
        v.line([(nose - 8, -d * 0.5), (nose - 8, d * 0.5)], 0.4, INK_MUTED)
        hub = nose + 2
    else:
        v.poly([(nose - 3, -d * 0.38), (nose + 7, -1), (nose + 7, 1), (nose - 3, d * 0.3)], WASH_DARK, 0.9)   # the spinner
        for i in range(3):                                                  # exhaust stubs
            v.line([(nose - 22 + i * 4, -d * 0.25), (nose - 20 + i * 4, -d * 0.25)], 0.9)
        hub = nose + 7
    v.ellipse(hub - 1.4, -d * 1.25, hub + 1.4, d * 1.25, None, 0.5)          # the propeller, turning
    v.line([(hub, -d * 1.2), (hub, d * 1.2)], 0.4, INK_MUTED)
    wx0, wx1 = L * s.get("wing", (0.5, 0.75))[0], L * s.get("wing", (0.5, 0.75))[1]
    wy = d * s.get("wing_y", 0.25)
    v.poly([(wx0, wy), (wx0 + (wx1 - wx0) * 0.25, wy - 2.2), (wx1, wy - 1.2), (wx1 + 2, wy + 0.6), (wx0 + 4, wy + 2)], WASH_DARK, 0.8)
    tail = s.get("tail", "round")
    if tail == "round":
        fin = v.curve([(L * 0.02, -d * 0.2), (L * 0.03, -d * 1.2), (L * 0.09, -d * 1.55), (L * 0.15, -d * 1.2), (L * 0.18, -d * 0.42)], 5)
    elif tail == "square":
        fin = [(L * 0.01, -d * 0.2), (L * 0.02, -d * 1.45), (L * 0.1, -d * 1.5), (L * 0.17, -d * 0.45)]
    else:
        fin = [(L * 0.0, -d * 0.2), (L * 0.03, -d * 1.5), (L * 0.07, -d * 1.5), (L * 0.2, -d * 0.45)]
    v.poly(fin, WASH, 0.9)
    v.poly([(L * 0.0, -d * 0.05), (L * 0.14, -d * 0.2), (L * 0.18, d * 0.05), (L * 0.02, d * 0.12)], WASH_DARK, 0.7)
    c = s.get("canopy", "framed")
    cx = L * s.get("cockpit", 0.62)
    ct = -d * 0.5
    if c == "bubble":
        v.poly(v.curve([(cx - 12, ct), (cx - 7, ct - 6.5), (cx + 3, ct - 7), (cx + 10, ct - 1.5)], 5) + [(cx + 10, ct)], GLASS, 0.7)
    elif c == "long":
        v.poly([(cx - 26, ct), (cx - 24, ct - 5), (cx + 6, ct - 6), (cx + 12, ct)], GLASS, 0.7)
        for i in range(1, 5):
            v.line([(cx - 24 + i * 7, ct), (cx - 24 + i * 7, ct - 5.5)], 0.4)
    elif c == "hump":
        v.poly([(cx - 20, ct + 0.5), (cx - 10, ct - 6), (cx + 4, ct - 6.5), (cx + 11, ct)], GLASS, 0.7)
        v.line([(cx - 3, ct - 6.4), (cx - 3, ct)], 0.4)
    else:
        v.poly([(cx - 12, ct), (cx - 9, ct - 6), (cx + 5, ct - 6.5), (cx + 11, ct)], GLASS, 0.7)
        v.line([(cx - 2, ct - 6.3), (cx - 2, ct)], 0.4)
        v.line([(cx + 5, ct - 6.4), (cx + 7, ct)], 0.4)
    if s.get("scoop"):                                                        # a belly radiator (the P-51)
        v.poly([(L * 0.3, d * 0.42), (L * 0.36, d * 0.95), (L * 0.52, d * 0.95), (L * 0.56, d * 0.46)], WASH_DARK, 0.7)
    if s.get("chin"):                                                         # a chin radiator (the P-40)
        v.poly([(nose - 16, d * 0.36), (nose - 12, d * 0.95), (nose - 3, d * 0.8), (nose - 2, d * 0.3)], WASH_DARK, 0.7)
    if s.get("spats"):                                                        # fixed wheels in spats
        gx = L * 0.66
        v.poly([(gx - 1.5, wy + 1), (gx + 1.5, wy + 1), (gx + 3, d * 1.3), (gx, d * 1.3)], WASH_DARK, 0.6)
        v.poly(v.curve([(gx - 6, d * 1.75), (gx - 1, d * 1.2), (gx + 6, d * 1.3), (gx + 9, d * 1.75), (gx + 5, d * 2.25), (gx - 3, d * 2.2), (gx - 6, d * 1.75)], 3), WASH_DARK, 0.7)
    if s.get("turret"):                                                       # a ball turret (the Avenger)
        v.circle(cx - 22, ct - 2, 4.6, GLASS, 0.6)
    if s.get("bomb"):                                                         # a bomb under the belly, fins aft
        bx, by = L * 0.5, d * 0.95
        v.poly(v.curve([(bx, by - 2), (bx + 10, by - 2.6), (bx + 15, by), (bx + 10, by + 2.6), (bx, by + 2), (bx, by - 2)], 3), WASH_DARK, 0.6)
        v.poly([(bx, by - 2), (bx - 4, by - 3.4), (bx - 4, by + 3.4), (bx, by + 2)], WASH, 0.5)
        v.line([(bx + 6, by - 2.4), (bx + 6, d * 0.45)], 0.5)
    if s.get("camera"):                                                       # a reconnaissance camera's port
        v.circle(L * 0.35, d * 0.3, 1.8, GLASS, 0.5)


def bomber(v, s):
    """A multi-engined bomber side-on: a long fuselage, the near engines on the
    wing, turrets, and one fin or two (the far one behind)."""
    L = s.get("len", 200.0)
    d = s.get("depth", 15.0)
    glazed = s.get("glazed_nose", False)
    top = [(0, -d * 0.2), (L * 0.2, -d * 0.4), (L * 0.6, -d * 0.55), (L * 0.88, -d * 0.52), (L, -d * (0.1 if glazed else 0.25))]
    bot = [(L, d * 0.2), (L * 0.88, d * 0.5), (L * 0.5, d * 0.5), (L * 0.2, d * 0.3), (0, d * 0.05)]
    v.poly(v.curve(top, 6) + v.curve(bot, 6), WASH, 1.1)
    if glazed:                                                               # a rounded glass nose (the B-29)
        v.poly(v.curve([(L * 0.9, -d * 0.5), (L * 0.97, -d * 0.35), (L + 1, 0), (L * 0.97, d * 0.3), (L * 0.9, d * 0.45)], 4), GLASS, 0.7)
        for i in range(3):
            v.line([(L * (0.92 + 0.025 * i), -d * 0.45), (L * (0.92 + 0.025 * i), d * 0.42)], 0.35)
    else:
        v.circle(L - 3, 0, d * 0.35, GLASS, 0.7)                             # a nose turret
        v.poly([(L * 0.7, -d * 0.5), (L * 0.74, -d * 0.85), (L * 0.84, -d * 0.82), (L * 0.88, -d * 0.5)], GLASS, 0.7)
    for ex in s.get("engines", (0.62, 0.7)):                                 # the near engines on the wing
        x = L * ex
        v.poly([(x - 16, d * 0.1), (x - 4, -d * 0.12), (x + 14, -d * 0.1), (x + 16, d * 0.35), (x - 10, d * 0.45)], WASH_DARK, 0.8)
        v.ellipse(x + 15.5, -d * 0.75, x + 18, d * 0.95, None, 0.4)
    v.poly([(L * 0.45, d * 0.2), (L * 0.52, -d * 0.02), (L * 0.78, 0), (L * 0.8, d * 0.25)], WASH_DARK, 0.6)   # the wing, edge-on
    if s.get("twin_fin"):
        for dx in (0.05, 0.0):
            fx = L * dx
            v.poly(v.curve([(fx + 4, -d * 0.3), (fx + 2, -d * 1.4), (fx + 8, -d * 1.9), (fx + 16, -d * 1.5), (fx + 14, -d * 0.3)], 4), WASH_DARK if dx else WASH, 0.8)
    else:                                                                    # one tall fin
        v.poly([(L * 0.0, -d * 0.2), (L * 0.025, -d * 1.9), (L * 0.085, -d * 2.05), (L * 0.17, -d * 0.45)], WASH, 0.9)
    v.poly([(0, 0), (L * 0.12, -d * 0.12), (L * 0.15, d * 0.1), (L * 0.01, d * 0.14)], WASH_DARK, 0.7)
    for tx, ty in s.get("turrets", ((0.55, -0.55),)):                        # dorsal and belly turrets
        v.circle(L * tx, d * ty, d * 0.25, GLASS, 0.6)
    v.circle(1.5, 0, d * 0.22, GLASS, 0.6)                                   # the tail gunner
    v.line([(L * 0.4, d * 0.5), (L * 0.56, d * 0.5)], 1.4, INK_MUTED)        # the bomb doors


def squadron(p, s, draw=aircraft):
    """Three in echelon, the lead largest and forward; in a small picture the
    lead alone, filling it."""
    base = View(p)
    L = s.get("len", 200.0 if draw is bomber else 120.0)
    if small_pen(base):
        k = 300.0 / L
        draw(View(p, (W - L * k) / 2 - 8, 74, k), s)
        return
    if draw is bomber:
        k = 200.0 / L
        draw(View(p, 18, 38, 0.5 * k), s)
        draw(View(p, 62, 66, 0.7 * k), s)
        draw(View(p, 100, 104, 1.1 * k), s)
        return
    k = 120.0 / L
    draw(View(p, 30, 36, 0.8 * k), s)
    draw(View(p, 92, 116, 0.8 * k), s)
    draw(View(p, 128, 76, 1.5 * k), s)


def clouds(p, spots):
    for x, y, r in spots:
        for dx, dy, rr in ((0, 0, 1.0), (r * 0.9, -r * 0.35, 0.8), (r * 1.7, 0, 0.9), (-r * 0.8, r * 0.2, 0.6)):
            p.ellipse(x + dx - r * rr * 1.4, y + dy - r * rr * 0.7, x + dx + r * rr * 1.4, y + dy + r * rr * 0.7, None, 0.4)


# ---- soldiers (facing right, feet at y = 0, about 47 tall) ----------------------

HATS = {
    # the side's helmet or hat, the one thing that tells the soldiers apart
    "stahlhelm": [(-5.8, -37.2), (-5, -41.5), (-2.5, -45.5), (1.5, -47), (4.8, -45), (6.2, -41.5), (5.2, -40.6), (4.2, -41.2), (-3.8, -40.5), (-5, -38)],
    "jump":      [(-5, -38.8), (-4.8, -43), (-1.5, -46.5), (2, -47), (5, -44.5), (5.6, -41), (-5, -39)],
    "brodie":    [(-8, -41.8), (-4, -42), (-3, -45.6), (1, -46.6), (5, -45.6), (6, -42), (9.5, -41.9), (9.5, -41), (-8, -41)],
    "m1":        [(-6, -40.4), (-5, -44), (-2, -46.8), (2, -47), (5, -45), (6.5, -41.5), (7.8, -41.1), (7.8, -40.4)],
    "ssh40":     [(-5.8, -39.2), (-5.2, -43.5), (-2, -47.3), (2.5, -47.5), (5.5, -44.5), (6.4, -40.6), (5.4, -40.2), (-4.4, -40.2)],
    "type90":    [(-5, -41), (-4.5, -44.5), (-1, -47), (3, -46.5), (5.5, -43.5), (6.8, -41), (-5, -40.6)],
    "m33":       [(-5.6, -38.8), (-5.2, -43.5), (-2, -46.8), (2.5, -47), (5.5, -44), (7.4, -41.8), (5.6, -41.2), (-4, -40.2)],
    "adrian":    [(-7.6, -40.4), (-4.5, -41.5), (-3.5, -45), (-1.8, -46.3), (-1.2, -47.6), (3.4, -47.8), (4, -46.4), (4.5, -45), (5.5, -41.5), (8.6, -40.2), (8.4, -39.6), (-7.4, -39.8)],
    "alpini":    [(-7, -40.4), (-4.5, -41.5), (-3.5, -46), (3, -46.6), (5, -42.2), (8.4, -42.2), (8.4, -41.4), (-7, -39.8)],
    "slouch":    [(-9.5, -41.9), (-3.5, -42), (-3, -47.2), (3.5, -47.6), (4.5, -42.4), (10.5, -41.8), (10.5, -41), (-9.5, -41)],
    "cap":       [(-4.6, -41), (-4.2, -45.4), (3.6, -45.6), (4.6, -41.4), (8.6, -40.4), (8.2, -39.8), (-4.6, -40.4)],
    "peaked":    [(-4.6, -41), (-6, -46.8), (4.8, -47.4), (4.6, -41.4), (8.4, -40.2), (8, -39.6), (-4.6, -40.4)],
    "fedora":    [(-7.8, -42.2), (-4, -42.2), (-3.6, -47), (0, -46), (3.6, -47.6), (4.6, -42.6), (8.8, -43), (8.8, -42.2), (-7.8, -41.4)],
    "beret":     [(-5, -41.2), (-4.6, -45), (1.5, -46.4), (6.2, -44), (5.2, -41.6)],
    "knit":      [(-4.6, -41), (-4.2, -45), (0, -47.6), (4, -45.6), (5, -41.6)],
}


def soldier(v, x, hat, carry="rifle", coat=False, stride=1.0, kneel=False, fill=WASH):
    """One figure: legs in stride, tunic (or a long coat), pack, head and its
    hat, and what it carries - a rifle at the slope, a sub-machine gun, a
    briefcase, a radio set - or nothing."""
    f = v.sub(x, 0)
    hip = -22.0 if not kneel else -14.0
    if kneel:
        f.line([(-1, hip), (-8, -1), (-12, 0)], 2.4)
        f.line([(1, hip), (8, -8), (9, 0)], 2.4)
    else:
        f.line([(-1, hip), (-6 * stride, -0.5)], 2.4)
        f.line([(1, hip), (7 * stride, -0.5)], 2.4)
        f.rect(-8.5 * stride, -1.6, -4 * stride, 0, INK_MUTED, 0.3)
        f.rect(5 * stride, -1.6, 10 * stride, 0, INK_MUTED, 0.3)
    if coat:
        f.poly([(-5, hip - 14), (5.5, hip - 15), (7, hip + 12), (-7, hip + 12)], fill, 0.8)
    else:
        f.poly([(-4.6, hip + 1), (4.8, hip + 1), (5.6, hip - 14.5), (-5, hip - 13.5)], fill, 0.8)
        f.line([(-4.6, hip - 2), (4.8, hip - 2)], 0.6)                      # the belt
    if carry in ("rifle", "smg"):
        f.rect(-9, hip - 14, -4.6, hip - 4, WASH_DARK, 0.5)                  # the pack
    shoulder = (2.0, hip - 12.5)
    if carry == "rifle":
        # At the slope: the hand holds the butt low in front, the rifle lies
        # over the shoulder and its muzzle points up and BACK, behind the
        # head (TeeJ, 2026-09-30: "rifles should go BACK over a soldier's
        # shoulder ... pointing forward makes it look like they are giving a
        # Nazi salute"). The arm hangs down to the butt - never raised
        # forward. The head and hat are drawn over it below.
        f.line([(7, hip - 4), (-11, hip - 33)], 1.2)
        f.line([(shoulder[0], shoulder[1]), (6.5, hip - 5)], 1.3)
    elif carry == "smg":
        f.line([(shoulder[0], shoulder[1]), (8, hip - 8)], 1.3)
        f.line([(2, hip - 9), (15, hip - 10)], 1.4)
        f.circle(6, hip - 6.5, 2.4, WASH_DARK, 0.5)                          # the drum
    elif carry == "case":
        f.line([(shoulder[0], shoulder[1]), (3.5, hip - 1)], 1.3)
        f.rect(1, hip - 1, 9, hip + 5, WASH_DARK, 0.6)
    elif carry == "radio":
        f.line([(shoulder[0], shoulder[1]), (5, hip - 2)], 1.3)
        f.rect(3, hip - 2, 14, hip + 6, WASH_DARK, 0.6)
        f.line([(12, hip - 2), (16, hip - 26)], 0.4)
    else:
        f.line([(shoulder[0], shoulder[1]), (4, hip - 1)], 1.3)
    # the head and its hat last, over whatever is carried, a fifth larger than
    # life: the hat is what tells one side's soldiers from another's
    hx0, hy0, big = 1.2, hip - 18.5, 1.2
    f.circle(hx0, hy0, 4.2 * big, PAPER, 0.7)
    f.poly([(hx0 + (hx - 1.2) * big, hy0 + (hy + 40.5) * big) for hx, hy in HATS[hat]], WASH_DARK, 0.7)
    if hat == "alpini":                                                      # the feather
        f.line([(hx0 - 4.4 * big, hy0 - 4.5 * big), (hx0 - 12 * big, hy0 - 15 * big)], 1.1)


def squad(v, hats, x0=40.0, gap=36.0, carry="rifle", **kw):
    """Soldiers marching in file, each its hat."""
    for i, hat in enumerate(hats):
        soldier(v, x0 + i * gap, hat, carry if isinstance(carry, str) else carry[i], **kw)


# ---- vehicles, boats and scenery ----------------------------------------------

def wheels(v, xs, y, r, fill=WASH_DARK):
    for x in xs:
        v.circle(x, y, r, fill, 0.7)
        v.circle(x, y, r * 0.35, INK_MUTED, 0.3)


def tank(v, kind):
    """A tank side-on, gun to the right, tracks on y = 0: the Panzer IV (a box
    hull, eight small wheels, a turret aft of centre), the Sherman (a tall
    hull, a sloped front, bogies of paired wheels, a round turret), the T-34
    (a sloped glacis, five big wheels, the turret forward)."""
    if kind == "t34":
        v.poly([(0, -6), (8, -16), (70, -16), (90, -8), (88, -2), (4, -2)], WASH, 1.0)
        v.poly([(28, -16), (32, -26), (58, -26), (64, -16)], WASH, 0.9)
        v.line([(62, -21.5), (100, -21)], 1.8)
        wheels(v, [12, 28, 44, 60, 76], -4.5, 6.5)
    elif kind == "sherman":
        v.poly([(0, -8), (6, -24), (62, -24), (84, -14), (86, -6), (2, -3)], WASH, 1.0)
        v.poly(v.curve([(24, -24), (27, -33), (40, -36), (54, -33), (58, -24)], 4), WASH, 0.9)
        v.line([(57, -30), (92, -29.5)], 1.7)
        for bx in (14, 38, 62):
            v.rect(bx - 9, -9, bx + 9, -3, WASH_DARK, 0.5)
            wheels(v, [bx - 5, bx + 5], -3, 3.4)
    else:
        v.poly([(0, -6), (2, -20), (74, -20), (82, -12), (82, -3), (2, -3)], WASH, 1.0)
        v.rect(6, -24, 70, -20, WASH_DARK, 0.6)
        v.poly([(20, -24), (22, -34), (50, -34), (54, -24)], WASH, 0.9)
        v.line([(52, -30), (92, -29.6)], 1.6)
        wheels(v, [10 + i * 8.6 for i in range(8)], -4, 3.2)
        for rx in (16, 36, 56):
            v.circle(rx, -13, 1.6, WASH_DARK, 0.4)
    v.poly(v.curve([(-2, -4), (2, 0), (40, 1.2), (84, 0), (90, -5)], 4) + [(84, -8), (4, -8)], None, 1.0)   # the track's run


def halftrack(v):
    v.poly([(0, -6), (4, -22), (40, -24), (58, -18), (72, -14), (74, -6)], WASH, 1.0)
    v.line([(4, -22), (6, -27), (38, -28), (40, -24)], 0.6)
    wheels(v, [64], -4, 6)
    v.poly(v.curve([(4, -3), (8, 1), (40, 1), (46, -4)], 3) + [(42, -9), (8, -9)], None, 1.0)
    wheels(v, [12, 20, 28, 36], -4, 3.4)


def field_gun(v):
    v.poly([(10, -24), (22, -26), (22, -10), (12, -10)], WASH, 0.8)          # the shield
    v.line([(14, -19), (48, -23)], 1.6)
    v.line([(10, -8), (-22, 0)], 1.4)                                         # the trail
    wheels(v, [16], -7, 7, WASH)


def landing_craft(v, L=90.0, ramp=True, pointed=False):
    """A landing boat on the water line y = 0, bow ramp to the right."""
    pts = [(0, -12), (L - 8, -12), (L, -4 if not pointed else -8), (L - 4, 2), (4, 2), (0, -2)]
    v.poly(pts, WASH, 1.0)
    v.rect(4, -18, 16, -12, WASH_DARK, 0.6)                                   # the coxswain's station
    if ramp:
        v.line([(L - 8, -12), (L + 2, -2)], 1.6)


def parachute(v, x, y, r=16.0):
    canopy = [(x - r + r * 2 * i / 12, y - r * 0.55 * math.sin(math.pi * i / 12)) for i in range(13)]
    v.poly(canopy + [(x + r, y + 2), (x - r, y + 2)], WASH, 0.9)
    for i in range(0, 13, 3):
        v.line([canopy[i], (x, y + r * 1.4)], 0.35)


def slope(v, pts):
    v.poly(pts, WASH, 0.9)
    v.hatch(pts, 3.4, 60, 0.4)


def dinghy(v, L=70.0):
    v.poly(v.curve([(0, -4), (4, -9), (L - 6, -9), (L, -4)], 4) + [(L - 4, 1), (4, 1)], WASH_DARK, 1.0)


def rails(v, x0, x1, y):
    v.line([(x0, y - 3), (x1, y - 3)], 1.2)
    v.line([(x0, y - 1), (x1, y - 1)], 0.6)
    for x in range(int(x0), int(x1), 9):
        v.rect(x, y - 1.2, x + 5, y + 1.2, WASH_DARK, 0.4)


def truss_bridge(v, x0, x1, y, h=26.0, bays=6):
    """A girder bridge: the deck, the top chord, braced bays."""
    v.rect(x0, y - 3, x1, y, WASH_DARK, 0.8)
    v.line([(x0, y - h), (x1, y - h)], 1.0)
    for i in range(bays):
        a, b = x0 + (x1 - x0) * i / bays, x0 + (x1 - x0) * (i + 1) / bays
        v.line([(a, y - 3), (b, y - h)], 0.6)
        v.line([(a, y - h), (b, y - 3)], 0.6)
        v.line([(b, y - 3), (b, y - h)], 0.7)
    v.line([(x0, y - 3), (x0, y - h)], 0.9)


def office(v):
    """A desk with a typewriter and a telephone, a filing cabinet, a wireless
    set on a shelf, a lamp."""
    v.rect(40, -38, 150, -34, WASH, 0.9)                                      # the desk top
    v.rect(46, -34, 52, 0, WASH_DARK, 0.6)
    v.rect(134, -34, 144, 0, WASH_DARK, 0.6)
    v.rect(110, -34, 134, -8, WASH, 0.7)                                      # its drawers
    for y in (-26, -17):
        v.line([(110, y), (134, y)], 0.5)
    v.poly([(64, -38), (96, -38), (92, -48), (68, -48)], WASH_DARK, 0.8)      # the typewriter
    v.rect(66, -54, 94, -48, PAPER, 0.5)
    v.rect(104, -42, 116, -38, WASH_DARK, 0.6)                                # the telephone
    v.line([(104, -46), (116, -46)], 1.6)
    v.line([(122, -38), (126, -58), (138, -60)], 0.7)                         # the lamp
    v.poly([(134, -62), (144, -62), (141, -56), (136, -56)], WASH_DARK, 0.6)
    v.rect(170, -60, 200, 0, WASH, 0.9)                                       # the filing cabinet
    for y in (-45, -30, -15):
        v.line([(170, y), (200, y)], 0.5)
    for y in (-52, -37, -22, -7):
        v.rect(182, y - 1, 188, y + 1, WASH_DARK, 0.3)
    v.rect(220, -76, 290, -72, WASH_DARK, 0.6)                                # a shelf, the wireless on it
    v.rect(228, -96, 266, -76, WASH, 0.8)
    v.circle(238, -86, 4, GLASS, 0.5)
    v.circle(252, -86, 4, GLASS, 0.5)
    v.line([(262, -96), (270, -118)], 0.5)


def street(v):
    """A lamp-post and a wall of brick, at night."""
    v.rect(0, -70, 120, 0, WASH, 0.8)
    for row in range(10):
        y = -row * 7
        v.line([(0, y), (120, y)], 0.3)
        for i in range(8):
            x = i * 15 + (7.5 if row % 2 else 0)
            v.line([(x, y), (x, y - 7)], 0.3)
    v.line([(300, 0), (300, -92)], 1.4)
    v.poly([(292, -92), (308, -92), (304, -104), (296, -104)], GLASS, 0.7)
    v.poly([(290, 0), (310, 0), (304, -8), (296, -8)], WASH_DARK, 0.6)


def barrier(v, x):
    v.rect(x, -34, x + 8, 0, WASH_DARK, 0.7)
    v.line([(x + 4, -26), (x + 120, -28)], 2.4)
    for i in range(6):
        v.line([(x + 16 + i * 18, -30), (x + 24 + i * 18, -25)], 1.2)
    v.rect(x - 40, -60, x - 8, 0, WASH, 0.8)                                  # the guard hut
    v.poly([(x - 44, -60), (x - 24, -72), (x - 4, -60)], WASH_DARK, 0.8)
    v.rect(x - 32, -48, x - 16, -36, GLASS, 0.5)


# ---- the scenes ------------------------------------------------------------------

GL = F.GL


def folk(p, hats, carry="rifle", s=1.5, x0=None, gap=40.0, **kw):
    """Soldiers in file on the ground, centred unless placed."""
    v = View(p, 0, GL, s)
    if x0 is None:
        x0 = (W / s - (len(hats) - 1) * gap) / 2
    squad(v, hats, x0, gap, carry, **kw)


def infantry(hats, carry="rifle"):
    def draw(p):
        folk(p, hats[:3], carry, 1.9, gap=50)
        p.ground()
    return draw


def armour(kind, riders=(), rider_hat="ssh40"):
    def draw(p):
        v = View(p, 30, GL - 1, 2.8)
        tank(v, kind)
        for i, x in enumerate(riders):
            soldier(View(p, 0, GL, 1.35), x, rider_hat, "smg")
        p.ground()
    return draw


def landing(hats, pointed=False, carry="rifle"):
    """A landing boat run in on the left, its men ashore on the right."""
    def draw(p):
        sea(p, 0, 200)
        landing_craft(View(p, 20, WL, 1.6), 90, True, pointed)
        p.ground(186, W)
        slope(View(p), [(186, GL), (200, WL + 4), (214, GL)])
        folk(p, hats, carry, 1.5, x0=156, gap=34)
    return draw


def airborne(p):
    for x, y, r in ((70, 30, 18), (150, 18, 15), (236, 40, 17)):
        parachute(View(p), x, y, r)
        soldier(View(p, x, y + r * 1.4 + 26, 0.62), 0, "jump", "none")
    parachute(View(p), 300, GL - 6, 12)                                       # one down, its canopy collapsing
    soldier(View(p, 0, GL, 1.5), 212, "jump", "smg")
    p.ground()


def alpini(p):
    slope(View(p), [(0, GL), (40, 64), (92, 30), (150, 70), (210, 22), (300, 80), (W, 58), (W, GL)])
    v = View(p, 0, GL, 1.5)
    squad(v, ["alpini", "alpini", "alpini"], 64, 46, "rifle")
    p.ground()


def commonwealth(p):
    folk(p, ["slouch", "brodie", "slouch"], "rifle", 1.9, gap=50)
    p.ground()


def guards_rifles(p):
    field_gun(View(p, 250, GL - 1, 1.9))
    folk(p, ["ssh40", "ssh40", "ssh40"], "smg", 1.5, x0=26, gap=44)
    p.ground()


def waffen(p):
    halftrack(View(p, 186, GL - 1, 2.2))
    folk(p, ["stahlhelm", "stahlhelm", "stahlhelm"], "rifle", 1.5, x0=22, gap=36)
    p.ground()


def abwehr(p):
    street(View(p, 0, GL, 1.0))
    v = View(p, 0, GL, 1.55)
    soldier(v, 104, "fedora", "case", coat=True, stride=0.6)
    soldier(v, 142, "fedora", "none", coat=True, stride=0.5)
    p.ground()


def sd_cell(p):
    office(View(p, 20, GL, 1.0))
    soldier(View(p, 0, GL, 1.5), 208, "fedora", "case", coat=True, stride=0.4)
    p.ground()


def brandenburgers(p):
    sea(p, 0, W, GL - 16)
    truss_bridge(View(p), 0, W, GL - 24, 34, 8)
    v = View(p, 0, GL - 24, 1.3)
    for i, x in enumerate((60, 120, 180)):
        soldier(v, x, "cap", "smg", kneel=(i != 1))


def kempeitai(p):
    barrier(View(p, 0, GL, 1.0), 220)
    v = View(p, 0, GL, 1.55)
    soldier(v, 70, "peaked", "none", coat=True, stride=0.5)
    soldier(v, 108, "peaked", "rifle", stride=0.6)
    p.ground()


def resistance(p):
    rails(View(p), 0, W, GL - 2)
    v = View(p, 0, GL, 1.55)
    soldier(v, 90, "beret", "case", kneel=True)
    soldier(v, 140, "beret", "smg", stride=0.7)
    p.ground()


def commando_raid(p):
    sea(p, 0, W)
    slope(View(p), [(250, WL + 6), (268, 40), (300, 30), (330, 44), (W, 20), (W, WL + 6)])
    dinghy(View(p, 40, WL, 2.2))
    v = View(p, 0, WL - 6, 1.3)
    for x in (48, 78, 108):
        soldier(v, x, "knit", "smg", kneel=True)


def photo_recon(p):
    clouds(p, ((60, 112, 14), (250, 30, 12), (300, 120, 10)))
    if small_pen(View(p)):
        aircraft(View(p, (W - 300) / 2 - 8, 74, 2.5), PLANES["spitfire_pr"])
        return
    aircraft(View(p, 80, 72, 1.6), PLANES["spitfire_pr"])


def soe(p):
    parachute(View(p), 70, GL - 10, 20)
    for x in (300, 340):
        p.tree(x, GL, 1.6)
    soldier(View(p, 0, GL, 1.55), 128, "fedora", "radio", coat=True, stride=0.6)
    p.ground()


# the ships and the aircraft, by type
def bb(len_, fore, aft, funnels, bridge=3, masts=((0.52, 40),), guns=2, size=1.1, rake=10, sheer=5, houses=((0.3, 0.64, 8),), house_h=8,
       fw=11, fh=16, frake=1.5, **kw):
    t = []
    fx = [0.8, 0.71, 0.62][:fore]
    for i, x in enumerate(fx):
        t.append((x, size, guns, 6.0 if i == 1 else (4.0 if i == 2 else 0.0), True))
    ax = [0.14, 0.23][:aft]
    for i, x in enumerate(ax):
        t.append((x, size, guns, 6.0 if i == 1 else 0.0, False))
    s = {"len": len_, "free": 12, "sheer": sheer, "rake": rake, "turrets": t, "houses": list(houses), "house_h": house_h,
         "bridge": [(0.6, bridge)], "funnels": [(x, fw, fh, frake) for x in funnels], "masts": list(masts)}
    s.update(kw)
    return s


SHIPS = {
    "bismarck_class_battleship": bb(300, 2, 2, (0.46,), 3),
    "scharnhorst_class_battlecruiser": bb(300, 2, 1, (0.46,), 3, guns=3, rake=16),
    "littorio_class_battleship": bb(300, 2, 1, (0.44,), 4, guns=3, bridge_w=20, masts=((0.36, 36),)),
    "yamato_class_battleship": bb(320, 2, 1, (0.46,), 6, guns=3, size=1.35, sheer=9, bridge_w=26, bridge_dw=3, masts=((0.4, 32),),
                                  fw=13, fh=18, frake=6),
    "king_george_v_class_battleship": bb(300, 2, 1, (0.42, 0.5), 3, guns=2, size=1.25),
    "iowa_class_battleship": bb(330, 2, 1, (0.46, 0.53), 4, guns=3),
    "north_carolina_class_battleship": bb(310, 2, 1, (0.45, 0.52), 4, guns=3, bridge_w=18),
    "gangut_class_battleship": {"len": 300, "free": 9, "sheer": 1, "rake": 3, "house_h": 5, "houses": [(0.42, 0.7, 5)],
                                "turrets": [(0.82, 1.0, 3, 0, True), (0.6, 1.0, 3, 0, True), (0.38, 1.0, 3, 0, False), (0.16, 1.0, 3, 0, False)],
                                "bridge": [(0.72, 2)], "funnels": [(0.5, 10, 14, 0), (0.66, 10, 14, 0)], "masts": [(0.74, 34), (0.26, 30)], "director": False},
    "hipper_class_heavy_cruiser": bb(280, 2, 2, (0.48,), 3, size=0.9, tubes=[0.36], fw=14, fh=17, frake=2),
    "zara_class_heavy_cruiser": bb(280, 2, 2, (0.44, 0.52), 3, size=0.9),
    "takao_class_heavy_cruiser": {"len": 290, "free": 12, "sheer": 8, "rake": 10, "house_h": 6, "houses": [(0.3, 0.62, 6)],
                                  "turrets": [(0.86, 0.8, 2, 0, True), (0.78, 0.8, 2, 5, True), (0.7, 0.8, 2, 0, True), (0.22, 0.8, 2, 5, False), (0.14, 0.8, 2, 0, False)],
                                  "bridge": [(0.6, 6)], "bridge_w": 30, "bridge_dw": 3, "funnels": [(0.46, 18, 17, 5)], "masts": [(0.36, 30)], "tubes": [0.3]},
    "town_class_cruiser": bb(270, 2, 2, (0.44, 0.54), 3, guns=3, size=0.85),
    "cleveland_class_cruiser": bb(270, 2, 2, (0.44, 0.54), 3, guns=3, size=0.85, bridge_w=18),
    "kirov_class_cruiser": bb(270, 1, 2, (0.5,), 4, guns=3, size=0.9, bridge_w=16),
}
DESTROYER = {"len": 220, "free": 10, "sheer": 6, "rake": 10, "house_h": 4, "houses": [(0.35, 0.7, 4)],
             "turrets": [(0.86, 0.6, 1, 0, True), (0.78, 0.6, 1, 3, True), (0.2, 0.6, 1, 3, False), (0.12, 0.6, 1, 0, False)],
             "bridge": [(0.68, 2)], "bridge_w": 16, "funnels": [(0.5, 9, 13, 2), (0.58, 9, 13, 2)], "masts": [(0.62, 28)], "tubes": [0.4], "director": False}
BRITISH_DESTROYER = dict(DESTROYER, funnels=[(0.53, 11, 14, 2)])
FLETCHER = dict(DESTROYER, turrets=[(0.86, 0.6, 1, 0, True), (0.78, 0.6, 1, 3, True), (0.28, 0.6, 1, 3, False), (0.2, 0.6, 1, 3, False), (0.12, 0.6, 1, 0, False)])
CORVETTE = {"len": 150, "free": 9, "sheer": 10, "rake": 8, "house_h": 4, "houses": [(0.42, 0.7, 4)],
            "turrets": [(0.84, 0.5, 1, 0, True)], "bridge": [(0.64, 2)], "bridge_w": 14, "funnels": [(0.5, 9, 13, 1)], "masts": [(0.72, 28)], "director": False}
UBOAT = {"len": 220, "saddle": True, "tower": 0.5, "gun": 0.66}
GATO = {"len": 260, "tower": 0.5, "tower_w": 30, "gun": 0.34}
CARRIERS = {
    "shokaku_class_carrier": {"len": 310, "deck_h": 24, "island": 0.72, "island_w": 18, "funnel_in_island": False},
    "illustrious_class_carrier": {"len": 290, "deck_h": 24, "island": 0.62, "island_w": 28},
    "essex_class_carrier": {"len": 320, "deck_h": 24, "island": 0.6, "island_w": 30, "open_hangar": True},
}
CARGO = {"len": 240, "free": 13, "kind": "cargo"}
LIBERTY = {"len": 240, "free": 13, "kind": "cargo", "deck_cargo": True}
TANKER = {"len": 250, "free": 10, "kind": "tanker"}
LINER = {"len": 260, "free": 14, "kind": "liner"}

PLANES = {
    "bf_109": {"len": 110, "depth": 10, "engine": "inline", "canopy": "framed", "tail": "square"},
    "fw_190": {"len": 110, "depth": 11, "engine": "radial", "canopy": "bubble", "tail": "pointed"},
    "ju_87": {"len": 125, "depth": 12, "engine": "inline", "canopy": "long", "tail": "square", "spats": True, "bomb": True, "cockpit": 0.66},
    "zero": {"len": 118, "depth": 10, "engine": "radial", "canopy": "long", "tail": "round", "cockpit": 0.64},
    "spitfire": {"len": 112, "depth": 10, "engine": "inline", "canopy": "bubble", "tail": "round"},
    "spitfire_pr": {"len": 112, "depth": 10, "engine": "inline", "canopy": "bubble", "tail": "round", "camera": True},
    "p_51": {"len": 118, "depth": 10.5, "engine": "inline", "canopy": "bubble", "tail": "square", "scoop": True},
    "sbd": {"len": 118, "depth": 12, "engine": "radial", "canopy": "long", "tail": "round", "bomb": True, "cockpit": 0.66},
    "macchi": {"len": 112, "depth": 10, "engine": "inline", "canopy": "hump", "tail": "round"},
    "ki_43": {"len": 110, "depth": 10, "engine": "radial", "canopy": "bubble", "tail": "round"},
    "d3a": {"len": 118, "depth": 12, "engine": "radial", "canopy": "long", "tail": "round", "spats": True, "bomb": True, "cockpit": 0.66},
    "hurricane": {"len": 115, "depth": 12, "engine": "inline", "canopy": "hump", "tail": "round"},
    "wildcat": {"len": 100, "depth": 13, "engine": "radial", "canopy": "framed", "tail": "square"},
    "hellcat": {"len": 120, "depth": 14, "engine": "radial", "canopy": "framed", "tail": "square"},
    "avenger": {"len": 130, "depth": 15, "engine": "radial", "canopy": "long", "tail": "square", "turret": True, "cockpit": 0.68},
    "yak_9": {"len": 112, "depth": 10, "engine": "inline", "canopy": "framed", "tail": "round"},
    "il_2": {"len": 125, "depth": 13, "engine": "inline", "canopy": "long", "tail": "round", "bomb": True, "cockpit": 0.64},
    "p_40": {"len": 115, "depth": 11, "engine": "inline", "canopy": "framed", "tail": "round", "chin": True},
    "d520": {"len": 110, "depth": 10, "engine": "inline", "canopy": "framed", "tail": "round"},
}
LANCASTER = {"len": 210, "depth": 16, "twin_fin": True, "engines": (0.6, 0.71), "turrets": ((0.6, -0.55),)}
B29 = {"len": 230, "depth": 15, "glazed_nose": True, "engines": (0.56, 0.68), "turrets": ((0.66, -0.55), (0.42, -0.55), (0.46, 0.55))}


def flight(key):
    return lambda p: squadron(p, PLANES[key])


DRAW = {
    **{k: (lambda s: lambda p: one_ship(p, warship, s))(s) for k, s in SHIPS.items()},
    **{k: (lambda s: lambda p: one_ship(p, carrier, s))(s) for k, s in CARRIERS.items()},
    "axis_destroyer_flotilla": lambda p: fleet(p, warship, [DESTROYER] * 3),
    "allied_destroyer_flotilla": lambda p: fleet(p, warship, [BRITISH_DESTROYER] * 3),
    "fletcher_class_destroyer_flotilla": lambda p: fleet(p, warship, [FLETCHER] * 3),
    "flower_class_corvette_group": lambda p: fleet(p, warship, [CORVETTE] * 3),
    "u_boat_flotilla": lambda p: fleet(p, submarine, [UBOAT] * 3),
    "gato_class_submarine_flotilla": lambda p: fleet(p, submarine, [GATO] * 3),
    "axis_transport_convoy": lambda p: fleet(p, merchant, [CARGO] * 3),
    "axis_supply_convoy": lambda p: fleet(p, merchant, [TANKER, CARGO, TANKER]),
    "japanese_transport_convoy": lambda p: fleet(p, merchant, [LIBERTY, CARGO, CARGO]),
    "liberty_ship_convoy": lambda p: fleet(p, merchant, [LIBERTY] * 3),
    "troopship_convoy": lambda p: fleet(p, merchant, [LINER, LINER, CARGO]),
    "atomic_bomber_wing": lambda p: squadron(p, B29, bomber),
    "lancaster_squadron": lambda p: squadron(p, LANCASTER, bomber),
    "bf_109_squadron": flight("bf_109"), "fw_190_squadron": flight("fw_190"), "ju_87_stuka_squadron": flight("ju_87"),
    "a6m_zero_squadron": flight("zero"), "spitfire_squadron": flight("spitfire"), "p_51_mustang_squadron": flight("p_51"),
    "sbd_dauntless_squadron": flight("sbd"), "macchi_c202_squadron": flight("macchi"), "ki_43_oscar_squadron": flight("ki_43"),
    "d3a_val_squadron": flight("d3a"), "hurricane_squadron": flight("hurricane"), "f4f_wildcat_squadron": flight("wildcat"),
    "f6f_hellcat_squadron": flight("hellcat"), "tbf_avenger_squadron": flight("avenger"), "yak_9_squadron": flight("yak_9"),
    "il_2_sturmovik_squadron": flight("il_2"), "p_40_warhawk_squadron": flight("p_40"), "dewoitine_d520_squadron": flight("d520"),
    "waffen_ss_division": waffen,
    "wehrmacht_infantry_division": infantry(["stahlhelm"] * 4),
    "panzer_division": armour("panzer"),
    "fallschirmjager_division": airborne,
    "axis_naval_infantry_battalion": landing(["stahlhelm", "stahlhelm"]),
    "royal_marines_brigade": landing(["brodie", "brodie"]),
    "british_infantry_division": infantry(["brodie"] * 4),
    "chinese_infantry_division": infantry(["cap"] * 4),
    "soviet_guards_rifle_division": guards_rifles,
    "soviet_rifle_division": infantry(["ssh40"] * 4),
    "guards_tank_corps": armour("t34"),
    "us_marine_division": landing(["m1", "m1"]),
    "us_infantry_division": infantry(["m1"] * 4),
    "us_armored_division": armour("sherman"),
    "italian_infantry_division": infantry(["m33"] * 4),
    "alpini_division": alpini,
    "japanese_infantry_division": infantry(["type90"] * 4),
    "snlf_brigade": landing(["type90", "type90"], pointed=True),
    "allied_naval_infantry_battalion": landing(["m1", "brodie"]),
    "french_infantry_division": infantry(["adrian"] * 4),
    "commonwealth_division": commonwealth,
    "abwehr_agents": abwehr,
    "sd_intelligence_cell": sd_cell,
    "brandenburgers": brandenburgers,
    "kempeitai_operatives": kempeitai,
    "resistance_cell": resistance,
    "commandos": commando_raid,
    "photo_reconnaissance_flight": photo_recon,
    "soe_agents": soe,
}


# ---- the three sizes, and the credits -------------------------------------------

def render(uid, w, h, k, ox, oy, wm, fine):
    canvas = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    DRAW[uid](F.Pen(canvas, k, ox, oy, wm, fine))
    return canvas


def plate(uid, number, name):
    art = render(uid, 400, 200, 1.0, 16, 16, 1.0, True)
    d = ImageDraw.Draw(art)
    s = SS
    d.rectangle([7 * s, 7 * s, 393 * s - 1, 193 * s - 1], outline=INK + (255,), width=int(1.6 * s))
    d.rectangle([10 * s, 10 * s, 390 * s - 1, 190 * s - 1], outline=INK + (255,), width=int(0.6 * s))
    d.line([(10 * s, 170 * s), (390 * s, 170 * s)], fill=INK + (255,), width=int(0.6 * s))
    d.line([(88 * s, 170 * s), (88 * s, 190 * s)], fill=INK + (255,), width=int(0.6 * s))
    d.text((49 * s, 180.5 * s), "PLATE %d" % number, font=F.font(F.FONT_PLATE, 10), fill=INK + (255,), anchor="mm")
    label = " ".join(name.upper())
    size = 11
    while size > 7 and d.textlength(label, font=F.font(F.FONT_NAME, size, 500)) > 290 * s:
        size -= 1
    d.text((239 * s, 180.5 * s), label, font=F.font(F.FONT_NAME, size, 500), fill=INK + (255,), anchor="mm")
    base = F.paper(400, 200, number)
    base.alpha_composite(art.resize((400, 200), Image.LANCZOS))
    return base.convert("RGB")


def small(uid, number, w, h, wm, fine, border):
    k = (w - 2 * border) / W
    oy = (h - H * k) / 2
    art = render(uid, w, h, k, border, oy, wm, fine)
    base = F.paper(w, h, number + 40)
    base.alpha_composite(art.resize((w, h), Image.LANCZOS))
    ImageDraw.Draw(base).rectangle([0, 0, w - 1, h - 1], outline=INK_MUTED + (255,))
    return base.convert("RGB")


def write_credits(ids):
    path = os.path.join(PACK, "credits.json")
    raw = open(path, encoding="utf-8").read()
    data = json.loads(raw)
    files = []
    for uid in ids:
        files += ["art/units/%s.png" % uid, "art/portraits/units/%s.png" % uid, "art/miniatures/units/%s.png" % uid]
    entry = {"title": "Unit plates",
             "what": "The %d unit types' Encyclopedia pictures, portraits and list miniatures: engineering plates in ink on paper" % len(ids),
             "author": "Faction Wars, drawn by tools/look/make_ww2_units.py",
             "source": "https://github.com/TeeJS/faction-wars",
             "licence": "Original work of the Faction Wars project",
             "changes": "",
             "files": files}
    assets = data["assets"]
    at = next((i for i, a in enumerate(assets) if a.get("title") == "Unit plates"), None)
    if at is None:
        fac = next((i for i, a in enumerate(assets) if a.get("title") == "Facility plates"), len(assets) - 1)
        assets.insert(fac + 1, entry)
    else:
        assets[at] = entry
    text = json.dumps(data, indent=2, ensure_ascii=False)
    # Lists of names on one line, as the file is written by hand (the
    # portraits' generator's rule).
    text = re.sub(r'\[\s+("(?:[^"\\]|\\.)*"(?:,\s+"(?:[^"\\]|\\.)*")*)\s+\]',
                  lambda m: "[" + re.sub(r'",\s+"', '", "', m.group(1)) + "]", text)
    open(path, "w", encoding="utf-8", newline="\n").write(text + "\n")


def main():
    rows = json.load(open(os.path.join(PACK, "units.json"), encoding="utf-8"))["units"]
    ids = [r["id"] for r in rows]
    missing = sorted(set(ids) - set(DRAW))
    if missing:
        sys.exit("no drawing for: %s" % ", ".join(missing))
    only = sys.argv[1:]
    for n, r in enumerate(rows):
        uid = r["id"]
        if only and uid not in only:
            continue
        number = FIRST_PLATE + n
        F.save(plate(uid, number, r["display_name"]), "units/%s.png" % uid)
        F.save(small(uid, number, 122, 50, 2.3, True, 2), "portraits/units/%s.png" % uid)
        F.save(small(uid, number, 61, 25, 3.6, False, 1), "miniatures/units/%s.png" % uid)
        print("plate %2d  %s" % (number, uid))
    if not only:
        write_credits(ids)


if __name__ == "__main__":
    main()

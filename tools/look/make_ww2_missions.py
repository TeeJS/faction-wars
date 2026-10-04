"""The WWII pack's mission pictures: each of its 14 missions drawn as a 1940s
plate - ink line and a light wash on the look's paper, in the style of the
facility and unit plates (make_ww2_facilities.py, make_ww2_units.py, whose
pen, paper and figures this uses) - and the stand-in plate for a picture the
pack does not have (TeeJ, 2026-10-03: "can we come up with a generic 1940's
wartime image to use when no other exists?"):

    packs/ww2/art/missions/<id>.png     400x200  the mission's picture: the
                                                 Create Mission window, the
                                                 Mission window, the Encyclopedia
                                                 (Art.MissionPicture; one for both
                                                 sides, its <id>.png fallback)
    packs/ww2/art/placeholder.png       400x200  the stand-in (Art.Placeholder)

    python tools\\look\\make_ww2_missions.py

Each picture is a scene of the mission at work in the 368 x 150 drawing
space, the ground line at y = 128: envoys shaking hands, a camera at a
factory fence, a charge at a railway bridge. Everything is drawn here, from
straight lines, arcs and hatching - no photograph, scan or third-party
picture goes in - so the pictures are the project's own work and the same
bytes come out every run. No flag, badge, roundel, rune or marking is drawn
on anything, and nothing is shown being harmed (TeeJ, 2026-09-29: no Nazi
symbols in the game at all). Plates are numbered on from the territories'
(make_ww2_flags.py), in the pack's order; the stand-in has no number.

Also writes the pictures' entry in packs/ww2/credits.json ("Mission plates"),
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
import make_ww2_units as U        # noqa: E402  the figures, the craft, the scenery

W, H, SS, GL = F.W, F.H, F.SS, F.GL
PAPER, INK, INK_MUTED = F.PAPER, F.INK, F.INK_MUTED
WASH, WASH_DARK, GLASS = F.WASH, F.WASH_DARK, F.GLASS
PACK, ART = F.PACK, F.ART
View, soldier = U.View, U.soldier
FIRST_PLATE = 181          # facilities 1-15, units 16-92, territories 93-180
FIG = 1.5                  # a figure's scale on the plate


def inset(p, x, y, s):
    """A pen drawing in its own 368 x 150 space at scale s, placed at (x, y)
    of this drawing: a drawing pinned to a board."""
    return F.Pen(p.c, p.k * s, p.ox + x * p.k, p.oy + y * p.k, p.wm, p.fine)


def figure(p, x, hat, carry="none", flip=False, **kw):
    """One person standing on the ground at x, facing right (left if flip)."""
    soldier(View(p, x, GL, FIG, flip), 0, hat, carry, **kw)


def shoulder(x, flip=False, kneel=False):
    """Where a figure's near shoulder is on the plate (soldier()'s own point)."""
    hip = -14.0 if kneel else -22.0
    return (x + (-2.0 if flip else 2.0) * FIG, GL + (hip - 12.5) * FIG)


def arm(p, x, to, flip=False, kneel=False, hand=True):
    """A second arm, reaching from the shoulder to `to`."""
    s = shoulder(x, flip, kneel)
    p.line([s, to], 1.3 * FIG ** 0.5)
    if hand:
        p.circle(to[0], to[1], 1.6, PAPER, 0.5)


def car(v):
    """A saloon car side-on on y = 0, bonnet to the right."""
    body = [(0, -6), (3, -15), (28, -16), (38, -27), (70, -27), (80, -16), (104, -14), (110, -8), (109, -3), (1, -3)]
    v.poly(body, WASH, 1.0)
    v.poly([(41, -25), (55, -25), (55, -17), (36, -17)], GLASS, 0.6)
    v.poly([(58, -25), (68, -25), (76, -17), (58, -17)], GLASS, 0.6)
    v.line([(57, -16), (57, -4)], 0.5)
    v.line([(2, -9), (108, -9)], 0.4)
    v.rect(104, -12, 110, -9, PAPER, 0.4)                                     # the headlamp
    U.wheels(v, [20, 88], -3, 7.5)


def easel(p, x0, x1, top, legs=True):
    """A drawing board on an easel: the board from x0 to x1, its top at `top`."""
    if legs:
        mid = (x0 + x1) / 2
        p.line([(x0 + 8, GL), (mid, top - 6)], 1.2)
        p.line([(x1 - 8, GL), (mid, top - 6)], 1.2)
        p.line([(mid, GL), (mid, top)], 0.9)
    p.rect(x0, top, x1, top + (x1 - x0) * 0.55, PAPER, 1.1)
    p.line([(x0 - 2, top + (x1 - x0) * 0.55 + 2), (x1 + 2, top + (x1 - x0) * 0.55 + 2)], 1.6)


def grid(p, x0, y0, x1, y1, step=8.0):
    x = x0 + step
    while x < x1:
        p.line([(x, y0), (x, y1)], 0.25, INK_MUTED)
        x += step
    y = y0 + step
    while y < y1:
        p.line([(x0, y), (x1, y)], 0.25, INK_MUTED)
        y += step


def wire_fence(p, x0, x1, top=GL - 42, gap=None):
    """Posts and barbed wire; `gap` (x0, x1) is cut through."""
    for x in range(int(x0), int(x1) + 1, 26):
        p.line([(x, GL), (x, top)], 1.3)
        p.line([(x, top), (x - 5, top - 6)], 0.9)
    for i in range(5):
        y = top + 4 + i * 8
        segs = [(x0, x1)] if gap is None else [(x0, gap[0] - (2 if i % 2 else 6)), (gap[1] + (2 if i % 2 else 6), x1)]
        for a, b in segs:
            p.line([(a, y), (b, y)], 0.6)
            for x in range(int(a) + 4, int(b), 9):
                p.line([(x - 1.5, y - 1.5), (x + 1.5, y + 1.5)], 0.5)
                p.line([(x - 1.5, y + 1.5), (x + 1.5, y - 1.5)], 0.5)
    p.line([(x0 - 5, top - 6), (x1 - 5, top - 6)], 0.5)


def tower(p, x):
    """A guard tower: four legs, a hut, a searchlight."""
    p.line([(x, GL), (x + 6, GL - 64)], 1.2)
    p.line([(x + 30, GL), (x + 24, GL - 64)], 1.2)
    for y in (GL - 20, GL - 42):
        p.line([(x + 2, y), (x + 28, y - 4)], 0.6)
        p.line([(x + 2, y - 4), (x + 28, y)], 0.6)
    p.rect(x - 2, GL - 82, x + 32, GL - 64, WASH, 1.0)
    p.rect(x + 4, GL - 78, x + 26, GL - 70, GLASS, 0.5)
    p.poly([(x - 6, GL - 82), (x + 15, GL - 92), (x + 36, GL - 82)], WASH_DARK, 0.9)


def building(p, x0, x1, top, windows=(3, 2), roof="flat"):
    p.rect(x0, top, x1, GL, WASH, 1.0)
    if roof == "gable":
        p.poly([(x0 - 4, top), ((x0 + x1) / 2, top - 22), (x1 + 4, top)], WASH_DARK, 1.0)
    elif roof == "saw":
        n = max(2, int((x1 - x0) / 22))
        for i in range(n):
            a = x0 + (x1 - x0) * i / n
            b = x0 + (x1 - x0) * (i + 1) / n
            p.poly([(a, top), (a, top - 14), (b, top)], WASH_DARK, 0.8)
            p.rect(a + 1.5, top - 12, a + 4, top - 2, GLASS, 0.3)
    cols, rows = windows
    ww = (x1 - x0) / (cols * 2 + 1)
    for r in range(rows):
        for c in range(cols):
            x = x0 + ww * (1 + c * 2)
            y = top + 8 + r * 18
            if y + 10 < GL - 4:
                p.rect(x, y, x + ww, y + 10, GLASS, 0.5)


def searchlight(p, x, y, to):
    p.circle(x, y, 3.2, WASH_DARK, 0.7)
    p.line([(x, y - 3), to[0]], 0.35, INK_MUTED)
    p.line([(x, y + 3), to[1]], 0.35, INK_MUTED)


def charge(p, x, y):
    """A demolition charge: three sticks bound together, a cap."""
    for i in range(3):
        p.rect(x + i * 3.2, y - 10, x + i * 3.2 + 3, y, WASH_DARK, 0.5)
    p.line([(x - 0.5, y - 6), (x + 10, y - 6)], 0.9)
    p.line([(x + 4.6, y - 10), (x + 6, y - 14)], 0.6)


def plunger(p, x):
    """A detonator box with its T handle."""
    p.rect(x, GL - 12, x + 14, GL, WASH_DARK, 0.9)
    p.line([(x + 7, GL - 12), (x + 7, GL - 24)], 1.0)
    p.line([(x + 1, GL - 24), (x + 13, GL - 24)], 1.6)


def camera(p, x, y, s=1.0):
    p.rect(x - 5 * s, y - 3.5 * s, x + 5 * s, y + 3.5 * s, WASH_DARK, 0.6)
    p.circle(x + 6.5 * s, y, 2.4 * s, GLASS, 0.5)


def binoculars(p, x, y):
    p.rect(x - 2, y - 3.6, x + 6, y - 0.6, WASH_DARK, 0.5)
    p.rect(x - 2, y + 0.6, x + 6, y + 3.6, WASH_DARK, 0.5)


def bicycle(p, x):
    for c in (x, x + 30):
        p.circle(c, GL - 9, 9, None, 0.8)
    p.line([(x, GL - 9), (x + 12, GL - 22), (x + 26, GL - 22), (x + 30, GL - 9)], 0.8)
    p.line([(x + 12, GL - 22), (x + 15, GL - 9), (x, GL - 9)], 0.8)
    p.line([(x + 15, GL - 9), (x + 26, GL - 22)], 0.7)
    p.line([(x + 10, GL - 26), (x + 15, GL - 26)], 1.2)


# ---- the fourteen scenes ------------------------------------------------------

def diplomacy(p):
    """Envoys shaking hands before a tall window, the papers on the table."""
    for x0 in (128, 214):                                                    # the windows behind
        p.rect(x0, 18, x0 + 26, 86, GLASS, 0.8)
        p.arc(x0, 4, x0 + 26, 30, 180, 360, 0.8)
        p.line([(x0 + 13, 18), (x0 + 13, 86)], 0.5)
        p.line([(x0, 50), (x0 + 26, 50)], 0.5)
    p.rect(26, GL - 34, 112, GL - 30, WASH, 0.9)                              # the table, the treaty on it
    for x in (32, 104):
        p.line([(x, GL - 30), (x, GL)], 1.2)
    p.poly([(44, GL - 34), (80, GL - 34), (82, GL - 36), (46, GL - 36)], PAPER, 0.6)
    p.rect(88, GL - 39, 96, GL - 34, WASH_DARK, 0.6)                          # the inkwell and pen
    p.line([(94, GL - 39), (102, GL - 48)], 0.7)
    figure(p, 170, "fedora", coat=True, stride=0.45)
    figure(p, 206, "peaked", flip=True, coat=True, stride=0.45)
    arm(p, 170, (187, GL - 39))
    arm(p, 206, (189, GL - 39), flip=True)
    figure(p, 300, "fedora", "case", flip=True, coat=True, stride=0.4)       # an aide waits
    p.ground()


def rescue(p):
    """A man led out through a cut in the wire under the guard tower."""
    wire_fence(p, 150, W, gap=(206, 240))
    tower(p, 320)
    searchlight(p, 330, GL - 88, ((150, 30), (120, 52)))
    figure(p, 226, "cap", "none", flip=True, stride=0.8)                     # the prisoner, through the gap
    figure(p, 168, "knit", "smg", kneel=True)
    arm(p, 168, (196, GL - 24), kneel=True)                                  # holding the wire back
    figure(p, 96, "knit", "smg", flip=True, stride=0.7)                      # the cover, watching behind
    p.ground()


def sabotage(p):
    """A charge on the railway bridge, the wire run back to the plunger."""
    U.sea(p, 196, W, GL - 6)
    bank = [(0, GL - 20), (196, GL - 20), (196, GL), (0, GL)]
    p.poly(bank, WASH, 0.8)                                                  # the embankment
    p.hatch(bank, 3.4, 60, 0.4)
    U.rails(View(p), 0, 196, GL - 20)
    U.truss_bridge(View(p), 196, W, GL - 20, 30, 5)
    p.rect(190, GL - 20, 204, GL, WASH_DARK, 0.9)                            # the pier
    charge(p, 192, GL - 4)
    p.line([(197, GL - 6), (150, GL - 1), (96, GL - 1)], 0.45, INK)          # the wire
    plunger(p, 82)
    figure(p, 62, "beret", "none", kneel=True)
    arm(p, 62, (89, GL - 24), kneel=True)
    p.line([(0, GL), (196, GL)], 1.8)


def espionage(p):
    """A camera at the factory fence, at night."""
    building(p, 168, 340, 62, (5, 2), "saw")
    p.rect(300, 22, 312, 62, WASH_DARK, 0.9)                                 # the chimney
    p.smoke(306, 18, 4)
    wire_fence(p, 150, W, GL - 34)
    U.street(View(p, 0, GL, 0.85))
    figure(p, 112, "fedora", "none", coat=True, stride=0.4)
    camera(p, 122, GL - 54)
    arm(p, 112, (118, GL - 52))
    p.ground()


def reconnaissance(p):
    """An aircraft photographing the ground below."""
    U.clouds(p, ((50, 30, 12), (320, 22, 10)))
    U.aircraft(View(p, 92, 48, 1.3), U.PLANES["spitfire_pr"])
    for x in (110, 246):                                                     # the camera's view
        p.line([(178, 62), (x, GL - 6)], 0.4, INK_MUTED)
    for i, x in enumerate(range(96, 300, 22)):                               # the town it sees
        h = 14 + (i * 7) % 12
        p.rect(x, GL - h, x + 16, GL, WASH, 0.7)
        p.poly([(x - 2, GL - h), (x + 8, GL - h - 7), (x + 18, GL - h)], WASH_DARK, 0.6)
    p.line([(0, GL - 2), (W, GL - 2)], 0.5)
    p.ground()


def recruitment(p):
    """Volunteers in line at the recruiting office."""
    building(p, 222, W - 6, 34, (2, 2), "gable")
    p.rect(286, GL - 44, 310, GL, GLASS, 0.8)                                # the door
    p.rect(232, 74, 278, 104, PAPER, 0.8)                                    # the poster board, blank
    p.line([(236, 80), (274, 80)], 0.4, INK_MUTED)
    p.rect(182, GL - 30, 230, GL - 26, WASH, 0.9)                            # the table, the ledger
    for x in (186, 226):
        p.line([(x, GL - 26), (x, GL)], 1.1)
    p.poly([(196, GL - 30), (216, GL - 30), (218, GL - 32), (194, GL - 32)], PAPER, 0.6)
    figure(p, 252, "peaked", "none", flip=True, stride=0.4)
    for x, hat, carry in ((156, "cap", "case"), (118, "fedora", "none"), (80, "cap", "case"), (42, "fedora", "case")):
        figure(p, x, hat, carry, stride=0.5)
    p.ground()


def abduction(p):
    """A man walked to a waiting car under the street lamp."""
    U.street(View(p, 0, GL, 1.0))
    car(View(p, 236, GL, 1.15))
    figure(p, 150, "peaked", "none", stride=0.7)                             # the one taken
    figure(p, 120, "fedora", "none", coat=True, stride=0.7)
    arm(p, 120, (146, GL - 44))
    figure(p, 186, "fedora", "none", coat=True, flip=True, stride=0.5)      # holding the door
    p.ground()


def ship_design_research(p):
    """A warship's lines on the drawing board, its model on the stand."""
    easel(p, 34, 214, 20)
    grid(p, 34, 20, 214, 119, 9)
    U.DRAW["king_george_v_class_battleship"](inset(p, 40, 34, 0.46))
    p.line([(40, 104), (208, 104)], 0.5)                                     # the T-square
    p.rect(30, 101, 40, 107, WASH_DARK, 0.5)
    p.rect(244, GL - 30, 340, GL - 26, WASH, 0.9)                            # the model on its stand
    for x in (250, 334):
        p.line([(x, GL - 26), (x, GL)], 1.1)
    U.hull(View(p, 252, GL - 34, 0.28), 300, 9)
    p.rect(286, GL - 34, 302, GL - 30, WASH_DARK, 0.5)
    figure(p, 232, "peaked", "none", flip=True, stride=0.4)
    arm(p, 232, (196, GL - 62), flip=True)
    p.ground()


def facility_design_research(p):
    """A fortress's section on the drawing board; the theodolite outside."""
    easel(p, 94, 274, 20)
    grid(p, 94, 20, 274, 119, 9)
    F.DRAW["fortress_line"](inset(p, 100, 28, 0.46))
    p.line([(100, 104), (268, 104)], 0.5)
    p.rect(90, 101, 100, 107, WASH_DARK, 0.5)
    for dx in (-10, 0, 10):                                                   # the theodolite
        p.line([(326, GL - 40), (326 + dx * 1.2, GL)], 0.9)
    p.rect(320, GL - 50, 332, GL - 40, WASH_DARK, 0.8)
    p.rect(314, GL - 56, 338, GL - 50, WASH, 0.7)
    figure(p, 62, "cap", "none", stride=0.4)
    arm(p, 62, (100, GL - 64))
    p.ground()


def troop_training_research(p):
    """The field map on the easel: the ground, the units, the arrows."""
    easel(p, 120, 320, 16)
    for i in range(5):                                                        # the contours
        pts = [(124 + j * 6.6, 46 + i * 13 + 6 * math.sin(j / 4.0 + i)) for j in range(30)]
        p.line(pts, 0.4, INK_MUTED)
    p.line([(130, 108), (180, 70), (240, 66), (312, 30)], 0.7, INK_MUTED)    # a river
    for x, y in ((160, 92), (196, 96), (232, 90)):                           # units, the field sign
        p.rect(x, y, x + 14, y + 9, PAPER, 0.7)
        p.line([(x, y), (x + 14, y + 9)], 0.5)
        p.line([(x, y + 9), (x + 14, y)], 0.5)
    for a, b in (((168, 88), (196, 60)), ((204, 92), (246, 56)), ((240, 86), (282, 66))):   # the arrows
        p.line([a, b], 1.2)
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        for t in (2.6, -2.6):
            p.line([b, (b[0] - 7 * math.cos(ang + t * 0.2), b[1] - 7 * math.sin(ang + t * 0.2))], 1.2)
    figure(p, 80, "peaked", "none", stride=0.4)
    arm(p, 80, (150, GL - 60))
    p.line([(150, GL - 60), (176, GL - 80)], 0.8)                             # the pointer
    p.ground()


def incite_uprising(p):
    """A supply drop by the barn: the canister down, the set calling home."""
    building(p, 18, 120, 70, (1, 1), "gable")
    p.rect(52, 96, 84, GL, GLASS, 0.8)                                       # the barn door
    bicycle(p, 128)
    U.parachute(View(p), 280, 30, 18)
    p.rect(275, 55, 285, 74, WASH_DARK, 0.8)                                 # its canister
    p.rect(300, GL - 9, 326, GL, WASH_DARK, 0.8)                             # one already down
    figure(p, 196, "beret", "radio", kneel=True)
    figure(p, 236, "cap", "rifle", stride=0.6)
    p.ground()


def sabotage_atomic_program(p):
    """A charge set at the great bomber's wheels, behind the airfield fence."""
    U.bomber(View(p, 120, 92, 0.95), U.B29)
    for x in (184, 214):                                                      # its undercarriage
        p.line([(x, 102), (x, GL - 8)], 1.4)
        p.circle(x, GL - 7, 7, WASH_DARK, 0.8)
    p.line([(312, 100), (312, GL - 5)], 1.0)
    p.circle(312, GL - 4, 4, WASH_DARK, 0.6)
    wire_fence(p, 8, 110, GL - 30)
    charge(p, 220, GL - 1)                                                   # at the main wheels
    figure(p, 250, "knit", "none", flip=True, kneel=True)
    arm(p, 250, (229, GL - 8), flip=True, kneel=True)
    p.ground()


def subdue_uprising(p):
    """The checkpoint on the road: papers shown at the end of the barrier."""
    U.barrier(View(p, 0, GL, 1.0), 72)
    searchlight(p, 52, GL - 76, ((150, 20), (190, 44)))
    figure(p, 214, "cap", "rifle", stride=0.4)
    figure(p, 252, "fedora", "case", flip=True, coat=True, stride=0.5)
    arm(p, 252, (232, GL - 46), flip=True)
    p.rect(227, GL - 50, 234, GL - 43, PAPER, 0.4)                            # the papers
    building(p, 290, W - 4, 64, (2, 2))
    p.ground()


def assassination(p):
    """A rifle with its telescopic sight on an upper window's sill."""
    building(p, 214, 330, 66, (3, 2))                                        # across the street
    car(View(p, 236, GL, 0.72))
    p.line([(150, GL), (W, GL)], 1.8)
    wall = [(0, 0), (150, 0), (150, 150), (0, 150)]
    hole = [(58, 22), (138, 22), (138, 100), (58, 100)]
    p.poly(wall, WASH_DARK, 0)
    p.hatch(wall, 3.0, 70, 0.4)
    p.poly(hole, PAPER, 1.4)                                                 # the window, open
    p.line([(98, 22), (98, 100)], 0.8)                                       # its frame
    p.line([(58, 60), (138, 60)], 0.8)
    p.rect(52, 100, 150, 108, WASH, 1.0)                                     # the sill
    p.line([(36, 98), (150, 96)], 2.6)                                       # the rifle, over the sill
    p.rect(76, 87, 110, 93, WASH_DARK, 0.8)                                  # its sight
    p.line([(84, 93.5), (84, 96.5)], 0.7)
    p.line([(102, 93.5), (102, 96.5)], 0.7)
    p.line([(36, 98), (26, 106)], 2.6)                                       # the stock
    p.line([(150, 0), (150, 150)], 1.4)


DRAW = {
    "diplomacy": diplomacy, "rescue": rescue, "sabotage": sabotage, "espionage": espionage,
    "reconnaissance": reconnaissance, "recruitment": recruitment, "abduction": abduction,
    "ship_design_research": ship_design_research, "facility_design_research": facility_design_research,
    "troop_training_research": troop_training_research, "incite_uprising": incite_uprising,
    "sabotage_atomic_program": sabotage_atomic_program, "subdue_uprising": subdue_uprising,
    "assassination": assassination,
}


def placeholder(p):
    """The stand-in: a field desk - the map with its compass, the telephone,
    the binoculars and a steel helmet - the war in general, no side's."""
    p.rect(70, 8, 298, 80, PAPER, 1.0)                                       # the wall map
    for i in range(4):
        pts = [(76 + j * 7.4, 20 + i * 15 + 5 * math.sin(j / 3.0 + i * 1.7)) for j in range(30)]
        p.line(pts, 0.4, INK_MUTED)
    p.line([(120, 74), (150, 52), (190, 48), (232, 30), (262, 34)], 1.0)    # a front line
    for x, y in ((128, 36), (176, 62), (214, 24), (250, 58), (280, 40)):
        p.circle(x, y, 2.2, WASH_DARK, 0.5)                                  # its pins
    p.rect(30, GL - 30, 338, GL - 24, WASH, 1.0)                             # the desk
    for x in (40, 328):
        p.line([(x, GL - 24), (x, GL)], 1.4)
    p.poly([(60, GL - 30), (180, GL - 30), (190, GL - 36), (70, GL - 36)], PAPER, 0.7)   # the map, unrolled
    for i in range(3):
        p.line([(76 + i * 30, GL - 35), (98 + i * 30, GL - 31)], 0.35, INK_MUTED)
    p.circle(150, GL - 37, 5, PAPER, 0.7)                                    # the compass on it
    p.line([(150, GL - 41), (150, GL - 33)], 0.5)
    p.rect(206, GL - 46, 236, GL - 30, WASH_DARK, 0.9)                        # the field telephone
    p.line([(208, GL - 50), (234, GL - 50)], 2.4)
    p.circle(240, GL - 40, 2.6, WASH, 0.6)
    p.line([(242, GL - 40), (246, GL - 44)], 0.7)
    binoculars(p, 258, GL - 36)
    dome = [(300 + 22 * math.cos(math.pi * i / 16), GL - 30 - 18 * math.sin(math.pi * i / 16)) for i in range(17)]
    p.poly(dome, WASH_DARK, 1.0)                                              # the helmet, plain
    p.line([(276, GL - 30), (324, GL - 30)], 1.6)
    p.ground()


# ---- the plate, and the credits ----------------------------------------------------

def render(draw, w, h, k, ox, oy, wm, fine):
    canvas = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    draw(F.Pen(canvas, k, ox, oy, wm, fine))
    return canvas


def plate(draw, number, name, seed):
    art = render(draw, 400, 200, 1.0, 16, 16, 1.0, True)
    d = ImageDraw.Draw(art)
    s = SS
    d.rectangle([7 * s, 7 * s, 393 * s - 1, 193 * s - 1], outline=INK + (255,), width=int(1.6 * s))
    d.rectangle([10 * s, 10 * s, 390 * s - 1, 190 * s - 1], outline=INK + (255,), width=int(0.6 * s))
    d.line([(10 * s, 170 * s), (390 * s, 170 * s)], fill=INK + (255,), width=int(0.6 * s))
    d.line([(88 * s, 170 * s), (88 * s, 190 * s)], fill=INK + (255,), width=int(0.6 * s))
    d.text((49 * s, 180.5 * s), ("PLATE %d" % number) if number else "PLATE", font=F.font(F.FONT_PLATE, 10), fill=INK + (255,), anchor="mm")
    label = " ".join(name.upper())
    size = 11
    while size > 7 and d.textlength(label, font=F.font(F.FONT_NAME, size, 500)) > 290 * s:
        size -= 1
    d.text((239 * s, 180.5 * s), label, font=F.font(F.FONT_NAME, size, 500), fill=INK + (255,), anchor="mm")
    base = F.paper(400, 200, seed)
    base.alpha_composite(art.resize((400, 200), Image.LANCZOS))
    return base.convert("RGB")


def write_credits(files):
    path = os.path.join(PACK, "credits.json")
    data = json.loads(open(path, encoding="utf-8").read())
    entry = {"title": "Mission plates",
             "what": "The %d missions' pictures and the stand-in for a picture the pack does not have: plates in ink on paper" % (len(files) - 1),
             "author": "Faction Wars, drawn by tools/look/make_ww2_missions.py",
             "source": "https://github.com/TeeJS/faction-wars",
             "licence": "Original work of the Faction Wars project",
             "changes": "",
             "files": files}
    assets = data["assets"]
    at = next((i for i, a in enumerate(assets) if a.get("title") == "Mission plates"), None)
    if at is None:
        after = next((i for i, a in enumerate(assets) if a.get("title") == "Unit plates"), len(assets) - 1)
        assets.insert(after + 1, entry)
    else:
        assets[at] = entry
    text = json.dumps(data, indent=2, ensure_ascii=False)
    text = re.sub(r'\[\s+("(?:[^"\\]|\\.)*"(?:,\s+"(?:[^"\\]|\\.)*")*)\s+\]',
                  lambda m: "[" + re.sub(r'",\s+"', '", "', m.group(1)) + "]", text)
    open(path, "w", encoding="utf-8", newline="\n").write(text + "\n")


def main():
    rows = [r for r in json.load(open(os.path.join(PACK, "missions.json"), encoding="utf-8"))["missions"]
            if not r["id"].startswith("unnamed")]
    missing = sorted(set(r["id"] for r in rows) - set(DRAW))
    if missing:
        sys.exit("no drawing for: %s" % ", ".join(missing))
    files = []
    for n, r in enumerate(rows):
        number = FIRST_PLATE + n
        F.save(plate(DRAW[r["id"]], number, r["display_name"], number), "missions/%s.png" % r["id"])
        files.append("art/missions/%s.png" % r["id"])
        print("plate %3d  %s" % (number, r["id"]))
    F.save(plate(placeholder, 0, "1939 - 1945", 7), "placeholder.png")
    files.append("art/placeholder.png")
    print("stand-in   placeholder")
    write_credits(files)


if __name__ == "__main__":
    main()

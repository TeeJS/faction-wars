"""Draw the five sector-window corner glyphs (manual p070 Fig 3.7) as white
silhouettes on alpha, into assets/icons/<name>.png at 16 px (the corner button
size). The map tints them with the faction colour. Our own artwork - the
original's sprites are LucasArts'. Also writes a 4x tinted preview sheet next
to this script's output for a look.

    python tools\draw_corner_icons.py
"""
from PIL import Image, ImageDraw
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "icons")
os.makedirs(OUT, exist_ok=True)
S = 64  # draw size

def canvas():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)

W = (255, 255, 255, 255)

def factory():
    im, d = canvas()
    # base hall
    d.rectangle([6, 34, 58, 56], fill=W)
    # sawtooth roof
    for x in (6, 24, 42):
        d.polygon([(x, 34), (x, 22), (x + 16, 34)], fill=W)
    # two chimneys
    d.rectangle([12, 8, 18, 30], fill=W)
    d.rectangle([28, 12, 34, 30], fill=W)
    # doors cut out
    d.rectangle([28, 44, 36, 56], fill=(0, 0, 0, 0))
    return im

def tower():
    im, d = canvas()
    # ground plate
    d.rectangle([10, 52, 54, 58], fill=W)
    # shaft, tapering
    d.polygon([(26, 52), (38, 52), (35, 22), (29, 22)], fill=W)
    # turret head with a barrel to the upper right
    d.ellipse([20, 8, 44, 30], fill=W)
    d.polygon([(38, 14), (58, 4), (60, 10), (42, 22)], fill=W)
    return im

def fleet():
    im, d = canvas()
    # a stubby arrowhead ship pointing right, with two engine blocks
    d.polygon([(20, 10), (60, 32), (20, 54), (28, 32)], fill=W)
    d.rectangle([6, 14, 22, 26], fill=W)
    d.rectangle([6, 38, 22, 50], fill=W)
    return im

def mission():
    im, d = canvas()
    # an agent: head and cloaked shoulders
    d.ellipse([22, 6, 42, 26], fill=W)
    d.polygon([(8, 58), (20, 30), (44, 30), (56, 58)], fill=W)
    # hat brim
    d.rectangle([16, 14, 48, 18], fill=W)
    return im

def flame():
    im, d = canvas()
    # outer flame
    d.polygon([(32, 4), (46, 22), (52, 36), (50, 50), (40, 60), (24, 60), (14, 50), (12, 36), (20, 24), (26, 30)], fill=W)
    # inner cut-out
    d.polygon([(32, 30), (40, 42), (38, 54), (26, 54), (24, 42)], fill=(0, 0, 0, 0))
    return im

GLYPHS = {"manufacturing": factory, "defenses": tower, "fleet": fleet, "mission": mission, "uprising": flame}

for name, fn in GLYPHS.items():
    big = fn()
    big.resize((16, 16), Image.LANCZOS).save(os.path.join(OUT, f"{name}.png"))

# preview sheet: each glyph at 16 px shown 4x, tinted like the map tints them
TINTS = {"green": (58, 220, 80), "red": (230, 60, 50), "blue": (80, 150, 255)}
cell = 80
sheet = Image.new("RGBA", (cell * len(GLYPHS), cell * (len(TINTS) + 1)), (36, 41, 54, 255))
for col, (name, fn) in enumerate(GLYPHS.items()):
    small = fn().resize((16, 16), Image.LANCZOS)
    rows = [("white", (255, 255, 255))] + list(TINTS.items())
    for row, (_, rgb) in enumerate(rows):
        tinted = Image.new("RGBA", (16, 16), rgb + (255,))
        tinted.putalpha(small.getchannel("A"))
        zoom = tinted.resize((64, 64), Image.NEAREST)
        sheet.alpha_composite(zoom, (col * cell + 8, row * cell + 8))
d = ImageDraw.Draw(sheet)
for col, name in enumerate(GLYPHS):
    d.text((col * cell + 8, cell * len(rows) - 6), name, fill=(200, 200, 200, 255))
sheet.save(os.path.join(OUT, "_preview.png"))
print("ok")

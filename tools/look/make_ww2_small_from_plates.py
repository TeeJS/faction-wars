"""The WWII pack's small pictures, cut from the installed Encyclopedia plates
(TeeJ, 2026-10-04: the plates were redrawn by hand in the vintage 1940s comic
style - see art-archive/ww2/<kind>/vintage-1940s-comic-masters-2026-10-04/README.md
- and "update them in game"):

    units, facilities
        packs/ww2/art/portraits/<kind>/<id>.png        122x50  portrait
        packs/ww2/art/miniatures/<kind>/<id>.png        61x25  list miniature
    characters
        packs/ww2/art/portraits/characters/<id>.png     80x80  portrait
        packs/ww2/art/miniatures/characters/<id>.png    61x25  list miniature
    flags
        packs/ww2/art/location_sprites/<artwork_id>.png 37x37  the system's map picture

    python tools\\look\\make_ww2_small_from_plates.py [units|facilities|characters|flags ...]

Units and facilities: each is the plate's picture - inside its frame, above
its caption strip (x 11-389, y 11-168 of the 400 x 200 plate) - cut to the
small picture's shape about its middle, brought down with a light sharpening
and framed in the look's muted ink, as the drawn ones were. The miniature
takes the picture's middle three-quarters, so at 61 x 25 its subject still
reads.

Characters: the drawn print on the personnel card, cut from the card's
1600 x 800 master. make_ww2_portraits.py mounted the 150 x 150 print at the
card's (221, 25), turned a little about (296, 100) by an angle taken from the
id; that turn is undone and the print taken, square, from just under its top
edge and clear of its photo corners (a print pasted square later, as its
<id>-redraw.json records, is taken as it lies). The portrait is the print, as
the photographs' were; the miniature is its face in the old miniatures' frame.
A character whose card was not redrawn (no master) keeps the pictures it has.

Flags: the flag on the system's plate, cut from the plate's 1600 x 800 master
inside its ink edge, and dressed as make_ww2_flags.py dressed the sprites:
fitted into 35 x 27 at its own proportions, a hair of shadow, the ink edge, on
a clear 37 x 37 square. The flag is found on the plate itself (its rows and
columns that are not paper), so a redrawn plate's own flag is the one used.

This replaces make_ww2_units.py, make_ww2_facilities.py, make_ww2_portraits.py
and make_ww2_flags.py for the small sizes: those would draw the old pictures
again (the READMEs' warnings). Needs Pillow and numpy.
"""
import json
import os
import sys
import zlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PACK = os.path.join(ROOT, "packs", "ww2")
ART = os.path.join(PACK, "art")
# The redraws' masters and records, outside the pack (TeeJ, 2026-10-04: the
# pack folder holds only what the game uses).
ARCHIVE = os.path.join(ROOT, "art-archive", "ww2")
MASTERS = "vintage-1940s-comic-masters-2026-10-04"
PICTURE = (11, 11, 389, 168)          # the plate's picture, inside the frame, above the caption
LOOK = json.load(open(os.path.join(PACK, "look.json"), encoding="utf-8"))


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


INK = hexrgb(LOOK["colors"]["ink"])
INK_MUTED = hexrgb(LOOK["colors"]["ink_muted"])
PAPER = hexrgb(LOOK["colors"]["paper"])
ROWS = {"units": ("units.json", "units"), "facilities": ("facilities.json", "facilities")}


def cut(plate, w, h, keep=1.0):
    """The plate's picture cut to w:h about its middle (`keep` of it), at w x h."""
    x0, y0, x1, y1 = PICTURE
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    pw, ph = (x1 - x0) * keep, (y1 - y0) * keep
    if pw / ph > w / h:
        pw = ph * w / h
    else:
        ph = pw * h / w
    box = (round(cx - pw / 2), round(cy - ph / 2), round(cx + pw / 2), round(cy + ph / 2))
    im = plate.crop(box).resize((w, h), Image.LANCZOS)
    im = im.filter(ImageFilter.UnsharpMask(radius=0.6, percent=60, threshold=1))
    ImageDraw.Draw(im).rectangle([0, 0, w - 1, h - 1], outline=INK_MUTED)
    return im


def save(im, rel):
    out = os.path.join(ART, rel)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im.save(out, optimize=True)


def plates(kind):
    file, key = ROWS[kind]
    ids = [r["id"] for r in json.load(open(os.path.join(PACK, file), encoding="utf-8"))[key]]
    for i in ids:
        plate = Image.open(os.path.join(ART, kind, i + ".png")).convert("RGB")
        if plate.size != (400, 200):
            sys.exit("%s/%s.png is %dx%d, not 400x200" % (kind, i, plate.size[0], plate.size[1]))
        save(cut(plate, 122, 50), "portraits/%s/%s.png" % (kind, i))
        save(cut(plate, 61, 25, 0.75), "miniatures/%s/%s.png" % (kind, i))
    print("%s: %d portraits and miniatures" % (kind, len(ids)))


def master(kind, i):
    """The plate's 1600 x 800 master, or None when the plate was not redrawn."""
    path = os.path.join(ARCHIVE, kind, MASTERS, i + ".png")
    if not os.path.exists(path):
        return None
    im = Image.open(path).convert("RGB")
    if im.size != (1600, 800):
        sys.exit("%s is %dx%d, not 1600x800" % (path, im.size[0], im.size[1]))
    return im


def drawn_print(card, pid):
    """The personnel card's print, square, inside its photo corners, at 4x
    (make_ww2_portraits.card: the 150 x 150 print centred on (296, 100),
    turned by -2.0 .. +2.0 degrees from the id's CRC)."""
    s = 4
    # Hitler, Himmler, Raeder and Leclerc were redrawn later and their prints
    # pasted square over the old mount: <id>-redraw.json's assembly_dest_rect
    # (x, y, w, h on the 400 x 200 card). The same 2 px off the top and 7 px
    # off each side, square.
    record = os.path.join(ARCHIVE, "characters", MASTERS, pid + "-redraw.json")
    if os.path.exists(record):
        x, y, w, h = json.load(open(record, encoding="utf-8"))["assembly_dest_rect"]
        side = w - 14
        return card.crop((int((x + 7) * s), int((y + 2) * s), int((x + 7 + side) * s), int((y + 2 + side) * s)))
    angle = ((zlib.crc32(pid.encode("utf-8")) % 41) - 20) / 10.0
    cx, cy = 296 * s, 100 * s
    mount = card.crop((cx - 100 * s, cy - 100 * s, cx + 100 * s, cy + 100 * s))
    mount = mount.rotate(-angle, resample=Image.BICUBIC)
    # The print is (25, 25)-(175, 175) of the 200 x 200 mount; its photo
    # corners cover x + y < 8 at each corner. 2 px off the top keeps the
    # head's room (caps reach near it), 7 px off each side clears the corners,
    # and the square ends 12 px above the print's foot, in the chest.
    return mount.crop((32 * s, 27 * s, 168 * s, 163 * s))


def characters():
    chars = json.load(open(os.path.join(PACK, "characters.json"), encoding="utf-8"))["characters"]
    done, kept = 0, []
    for c in chars:
        pid = c["id"]
        card = master("characters", pid)
        if card is None:
            kept.append(pid)
            continue
        p = drawn_print(card, pid)
        save(p.resize((80, 80), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=0.8, percent=45, threshold=1)),
             "portraits/characters/%s.png" % pid)
        # The old miniature (make_ww2_portraits.miniature): the face, 23 x 23,
        # framed, in the middle of the paper.
        n = p.size[0]
        face = p.crop((int(n * 0.10), int(n * 0.08), int(n * 0.90), int(n * 0.88)))
        mini = Image.new("RGB", (61, 25), PAPER)
        ImageDraw.Draw(mini).rectangle([18, 0, 42, 24], outline=INK_MUTED)
        mini.paste(face.resize((23, 23), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=0.8, percent=45, threshold=1)), (19, 1))
        save(mini, "miniatures/characters/%s.png" % pid)
        done += 1
    print("characters: %d portraits and miniatures; not redrawn, kept: %s" % (done, ", ".join(kept) or "none"))


def flag_box(plate):
    """The flag's box on a 400 x 200 plate, ink edge included: the outermost
    rows and columns of the picture that are mostly not paper (the paper's
    specks are too few to count, the flag's shadow too pale)."""
    a = np.asarray(plate, np.float64)
    x0, y0, x1, y1 = PICTURE
    paper = np.median(a[y0 + 2:y1 - 2, x0 + 2:x0 + 40].reshape(-1, 3), axis=0)
    far = np.sqrt(((a - paper) ** 2).sum(axis=2)) > 70
    pic = far[y0 + 2:y1 - 2, x0 + 2:x1 - 2]
    rows = np.where(pic.sum(axis=1) >= 40)[0]
    cols = np.where(pic.sum(axis=0) >= 30)[0]
    if len(rows) == 0 or len(cols) == 0:
        return None
    return (x0 + 2 + cols[0], y0 + 2 + rows[0], x0 + 2 + cols[-1] + 1, y0 + 2 + rows[-1] + 1)


def sprite(flag):
    """make_ww2_flags.finish without the toning (the redrawn flag already is):
    fitted into 35 x 27, a hair of shadow, the ink edge, on a clear 37 x 37."""
    k = min(35 / flag.width, 27 / flag.height)
    fw, fh = max(1, int(round(flag.width * k))), max(1, int(round(flag.height * k)))
    small = flag.resize((fw * 4, fh * 4), Image.LANCZOS).resize((fw, fh), Image.LANCZOS)
    small = small.filter(ImageFilter.UnsharpMask(radius=0.6, percent=40, threshold=1)).convert("RGBA")
    im = Image.new("RGBA", (37, 37), (0, 0, 0, 0))
    x0, y0 = (37 - fw) // 2, (37 - fh) // 2
    d = ImageDraw.Draw(im)
    d.rectangle([x0, y0 + 1, x0 + fw, y0 + fh], fill=INK + (70,))
    im.alpha_composite(small, (x0, y0))
    d = ImageDraw.Draw(im)
    d.rectangle([x0 - 1, y0 - 1, x0 + fw, y0 + fh], outline=INK + (225,))
    return im


def flags():
    planets = json.load(open(os.path.join(PACK, "map.json"), encoding="utf-8"))["planets"]
    for p in planets:
        plate = Image.open(os.path.join(ART, "locations", p["id"] + ".png")).convert("RGB")
        box = flag_box(plate)
        big = master("locations", p["id"])
        if box is None or big is None:
            sys.exit("locations/%s: no flag found / no master" % p["id"])
        # Inside the ink edge (2 px on the plate), from the 4x master.
        l, t, r, b = box
        flag = big.crop(((l + 2) * 4, (t + 2) * 4, (r - 2) * 4, (b - 2) * 4))
        save(sprite(flag), "location_sprites/%d.png" % p["artwork_id"])
    print("flags: %d system pictures" % len(planets))


def main():
    for kind in sys.argv[1:] or ["units", "facilities", "characters", "flags"]:
        if kind in ROWS:
            plates(kind)
        elif kind == "characters":
            characters()
        elif kind == "flags":
            flags()
        else:
            sys.exit(__doc__)


if __name__ == "__main__":
    main()

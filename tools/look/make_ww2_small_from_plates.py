"""The WWII pack's small unit and facility pictures, cut from the installed
Encyclopedia plates (TeeJ, 2026-10-04: the plates were redrawn by hand in the
Joe Palooka style - packs/ww2/art/units/joe-palooka-masters-2026-10-04/README.md
- and "update them in game"):

    packs/ww2/art/portraits/<kind>/<id>.png     122x50  portrait
    packs/ww2/art/miniatures/<kind>/<id>.png     61x25  list miniature

    python tools\\look\\make_ww2_small_from_plates.py [units|facilities ...]

Each is the plate's picture - inside its frame, above its caption strip
(x 11-389, y 11-168 of the 400 x 200 plate) - cut to the small picture's
shape about its middle, brought down with a light sharpening and framed in
the look's muted ink, as the drawn ones were. The miniature takes the
picture's middle three-quarters, so at 61 x 25 its subject still reads.

This replaces make_ww2_units.py / make_ww2_facilities.py for the small sizes:
those would draw the old line plates again (the README's warning). Needs
Pillow.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PACK = os.path.join(ROOT, "packs", "ww2")
ART = os.path.join(PACK, "art")
PICTURE = (11, 11, 389, 168)          # the plate's picture, inside the frame, above the caption
LOOK = json.load(open(os.path.join(PACK, "look.json"), encoding="utf-8"))
INK_MUTED = tuple(int(LOOK["colors"]["ink_muted"][i:i + 2], 16) for i in (1, 3, 5))
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


def main():
    kinds = sys.argv[1:] or list(ROWS)
    for kind in kinds:
        file, key = ROWS[kind]
        ids = [r["id"] for r in json.load(open(os.path.join(PACK, file), encoding="utf-8"))[key]]
        for i in ids:
            plate = Image.open(os.path.join(ART, kind, i + ".png")).convert("RGB")
            if plate.size != (400, 200):
                sys.exit("%s/%s.png is %dx%d, not 400x200" % (kind, i, plate.size[0], plate.size[1]))
            for folder, (w, h), keep in (("portraits", (122, 50), 1.0), ("miniatures", (61, 25), 0.75)):
                out = os.path.join(ART, folder, kind, i + ".png")
                os.makedirs(os.path.dirname(out), exist_ok=True)
                cut(plate, w, h, keep).save(out, optimize=True)
        print("%s: %d portraits and miniatures" % (kind, len(ids)))


if __name__ == "__main__":
    main()

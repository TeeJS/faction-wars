"""The WWII pack's personnel pictures: every character's Encyclopedia picture,
portrait and list miniature, cut from a photograph on Wikimedia Commons, and the
drawn stand-in for the few without one.

    python tools\\look\\make_ww2_portraits.py <download folder>

Reads tools/look/ww2_portraits.json: per character, the Commons file, its
original's address and SHA-1 (as Commons publishes them), its licence and
author, and the crop. Downloads each original into <download folder> (kept
there, so a second run fetches nothing), stops on any SHA-1 that differs, and
writes, in the original's sizes (SCHEMA.md section 14):

    packs/ww2/art/characters/<id>.png              400x200  Encyclopedia picture
    packs/ww2/art/portraits/characters/<id>.png     80x80   portrait
    packs/ww2/art/miniatures/characters/<id>.png    61x25   list miniature

and, from the same records, packs/ww2/art/PORTRAITS.md (the provenance of every
picture) and the pictures' entries in packs/ww2/credits.json (the portraits'
own, at the end of the list; every other entry is left as it is).

The look: the photograph in black and white, lightly toned to the paper; the
Encyclopedia picture is a personnel card - ruled index card on the left, the
photograph mounted in photo corners on the right, the side's colour on the
card's head. A character marked `generic` gets a drawn head-and-shoulders in
the same mount. No picture shows a swastika or an Iron Cross, each German
portrait checked by eye (TeeJ, 2026-09-29: no Nazi symbols in the game at all;
2026-09-30: an eagle may show, as long as the swastika does not). A record's
`note` says how a crop keeps one out.

Colours are look.json's tokens (packs/ww2/look.json); the paper is
packs/ww2/look/paper.png (make_ww2_textures.py). The same bytes come out every
run. Needs Pillow and numpy.
"""
import hashlib
import json
import os
import re
import sys
import time
import urllib.request
import zlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SOURCES = os.path.join(ROOT, "tools", "look", "ww2_portraits.json")
PACK = os.path.join(ROOT, "packs", "ww2")
ART = os.path.join(PACK, "art")
UA = "faction-wars-portrait-provenance/1.0 (https://github.com/TeeJS/faction-wars)"
FOLDERS = ("characters", "portraits/characters", "miniatures/characters")


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


LOOK = json.load(open(os.path.join(PACK, "look.json"), encoding="utf-8"))
PAPER = hexrgb(LOOK["colors"]["paper"])
PAPER_EDGE = hexrgb(LOOK["colors"]["paper_edge"])
INK = hexrgb(LOOK["colors"]["ink"])
INK_MUTED = hexrgb(LOOK["colors"]["ink_muted"])
SIGNAL = hexrgb(LOOK["colors"]["signal"])
SIDES = {k: hexrgb(v) for k, v in LOOK["sides"].items() if not k.startswith("_")}
PHOTO_DARK = (0x1c, 0x19, 0x15)        # the toned photograph's black: ink, deepened
PHOTO_LIGHT = (0xf2, 0xea, 0xd6)       # and its white: the paper, lifted
MOUNT = (0xf6, 0xf1, 0xe4)             # the print's border
RULED = (0x8d, 0x9c, 0xae)             # an index card's blue rule


# ---- the photographs -------------------------------------------------------

def fetch(rec, folder):
    """The original, downloaded once into `folder` and checked against the
    SHA-1 Commons publishes for it."""
    ext = os.path.splitext(rec["url"])[1].lower()
    path = os.path.join(folder, rec["sha1"] + ext)
    if not os.path.exists(path):
        req = urllib.request.Request(rec["url"], headers={"User-Agent": UA})
        for attempt in range(5):
            try:
                with urllib.request.urlopen(req, timeout=120) as r:
                    data = r.read()
                break
            except Exception as e:  # a busy server: wait and try again
                err = e
                time.sleep(4 + attempt * 6)
        else:
            sys.exit("could not download %s: %s" % (rec["url"], err))
        with open(path + ".part", "wb") as f:
            f.write(data)
        os.replace(path + ".part", path)
        time.sleep(1)
    got = hashlib.sha1(open(path, "rb").read()).hexdigest()
    if got != rec["sha1"]:
        sys.exit("%s: SHA-1 %s, Commons published %s - a different file; not used" % (rec["file"], got, rec["sha1"]))
    return path


def crop(path, c):
    """The square [cx, cy, side] (fractions: of the width and height for the
    centre, of the height for the side), as greyscale. Past an edge the
    photograph's own edge is carried on, out of focus, so a face can stand in
    the middle with room round its head (TeeJ, 2026-09-30: "the face should be
    centered horizontally ... it should look like an ID picture") without a
    hard seam or streaks. A fourth number is where the photograph is cut off
    first (a fraction of its height): below it is a Nazi symbol, so nothing
    under that line is used - the line is carried on as the bottom edge."""
    im = ImageOps.exif_transpose(Image.open(path))
    if im.mode in ("I;16", "I;16B", "I;16L", "I"):
        im = im.point(lambda v: v / 256)
    g = np.asarray(im.convert("L"))
    h, w = g.shape
    side = int(round(c[2] * h))
    x0, y0 = int(round(c[0] * w - side / 2)), int(round(c[1] * h - side / 2))
    if len(c) > 3:
        g = g[:int(round(c[3] * h))]
        h = g.shape[0]
    pad = ((max(0, -y0), max(0, y0 + side - h)), (max(0, -x0), max(0, x0 + side - w)))
    seam = h - y0          # where the photograph ends, in the square's rows
    if any(v for p in pad for v in p):
        g = _extend(g.astype(np.float64), pad, side)
    x0, y0 = x0 + pad[1][0], y0 + pad[0][0]
    sq = np.ascontiguousarray(g[y0:y0 + side, x0:x0 + side])
    if pad[0][1]:
        sq = _vignette(sq, seam, side)
    return Image.fromarray(sq, "L")


def _vignette(sq, seam, side):
    """Under the photograph's bottom edge (its own, or the cut above a Nazi
    symbol): a studio print's fade to light, starting well above the edge so
    no line shows, light from just below it."""
    a = sq.astype(np.float64)
    light = np.percentile(a, 92)
    start, end = seam - side * 0.16, seam + side * 0.03
    y = np.arange(side, dtype=np.float64)[:, None]
    t = np.clip((y - start) / max(1.0, end - start), 0.0, 1.0)
    t = t * t * (3 - 2 * t)
    return np.round(a * (1 - t) + light * t).astype(np.uint8)


def _extend(g, pad, side):
    """The photograph carried past its edges as a studio print's soft fade:
    each new row (or column) is the edge's own row, smoothed along its
    length, fading over a seventh of the picture to the same row smoothed
    much further (a dark coat stays dark below, a light wall light) - no
    streaks - with the seam itself softened."""
    reach = max(1.0, side * 0.14)
    smooth = max(2.0, side * 0.04)
    wide = max(4.0, side * 0.16)

    def blur1d(v, r):
        n = len(v)
        k = int(3 * r) + 1
        x = np.arange(-k, k + 1)
        kern = np.exp(-0.5 * (x / r) ** 2)
        kern /= kern.sum()
        return np.convolve(np.pad(v, k, mode="edge"), kern, mode="same")[k:k + n]

    def grow(a, before, after):
        """Rows added above (`before`) and below (`after`) array `a`."""
        parts = []
        if before:
            edge = a[0]
            e, t = blur1d(edge, smooth), blur1d(edge, wide)
            k = np.arange(before, 0, -1)[:, None]
            wgt = np.minimum(1.0, k / reach)
            parts.append(e[None, :] * (1 - wgt) + t * wgt)
        parts.append(a)
        if after:
            edge = a[-1]
            e, t = blur1d(edge, smooth), blur1d(edge, wide)
            k = np.arange(1, after + 1)[:, None]
            wgt = np.minimum(1.0, k / reach)
            parts.append(e[None, :] * (1 - wgt) + t * wgt)
        return np.vstack(parts)

    h0, w0 = g.shape
    g = grow(g, pad[0][0], pad[0][1])
    g = grow(g.T, pad[1][0], pad[1][1]).T
    # Soften the seam: the band round the original edge, blended.
    mask = np.ones(g.shape, np.uint8) * 255
    mask[pad[0][0]:pad[0][0] + h0, pad[1][0]:pad[1][0] + w0] = 0
    r = max(2.0, side * 0.05)
    m = np.asarray(Image.fromarray(mask, "L").filter(ImageFilter.GaussianBlur(r)), np.float64) / 255.0
    m = np.maximum(m, mask / 255.0)
    soft = np.asarray(Image.fromarray(np.clip(g, 0, 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(r)), np.float64)
    return np.round(np.clip(g * (1 - m) + soft * m, 0, 255)).astype(np.uint8)


def tone(gray):
    """Black and white, stretched to its own range, then mapped from the
    photograph's toned black to its toned white."""
    a = np.asarray(ImageOps.autocontrast(gray, cutoff=(0.5, 0.5)), np.float64) / 255.0
    lo, hi = np.array(PHOTO_DARK, np.float64), np.array(PHOTO_LIGHT, np.float64)
    return Image.fromarray(np.round(lo + (hi - lo) * a[..., None]).astype(np.uint8), "RGB")


def generic(size=600):
    """The stand-in: a head and shoulders in muted ink on a studio backdrop,
    drawn at four times the size and brought down, so its edges are smooth."""
    n = size * 4
    y = np.linspace(0.0, 1.0, n)[:, None, None]
    top, bottom = np.array((0xe8, 0xe0, 0xcb), float), np.array((0xcf, 0xc5, 0xac), float)
    back = np.broadcast_to(top + (bottom - top) * y, (n, n, 3))
    im = Image.fromarray(np.round(back).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    f = lambda v: int(round(v * n))
    d.rounded_rectangle([f(0.10), f(0.70), f(0.90), f(1.20)], radius=f(0.26), fill=INK_MUTED)
    d.rectangle([f(0.43), f(0.54), f(0.57), f(0.74)], fill=INK_MUTED)
    d.ellipse([f(0.31), f(0.18), f(0.69), f(0.64)], fill=INK_MUTED)
    return im.resize((size, size), Image.LANCZOS)


def sharp(im, size):
    return im.resize(size, Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=0.8, percent=45, threshold=1))


# ---- the three pictures ----------------------------------------------------

def paper(w, h):
    """The look's parchment, darkened a little towards the edges."""
    tex = Image.open(os.path.join(PACK, "look", "paper.png")).convert("RGB")
    a = np.asarray(tex.crop((0, 0, w, h)), np.float64)
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)).astype(np.float64)
    a *= (1.0 - 0.10 * np.clip(1.0 - edge / 14.0, 0.0, 1.0))[..., None]
    return Image.fromarray(np.round(a).astype(np.uint8), "RGB")


def card(photo, side, pid):
    """The Encyclopedia picture: a personnel card, 400x200."""
    im = paper(400, 200).convert("RGBA")
    over = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    d.rectangle([18, 18, 196, 23], fill=SIDES.get(side, INK_MUTED) + (230,))    # the side's colour
    d.line([18, 40, 196, 40], fill=SIGNAL + (150,), width=1)                    # the card's head rule
    for y in range(58, 186, 18):
        d.line([18, y, 196, y], fill=RULED + (95,), width=1)                    # its ruled lines
    im = Image.alpha_composite(im, over)

    # The print: the photograph in a border, in four photo corners, a little
    # askew (the same angle every run, from the id), with its shadow.
    p = sharp(photo, (150, 150))
    mount = Image.new("RGBA", (164, 164), MOUNT + (255,))
    mount.paste(p, (7, 7))
    md = ImageDraw.Draw(mount)
    md.rectangle([0, 0, 163, 163], outline=PAPER_EDGE + (255,))
    for cx, cy, sx, sy in ((0, 0, 1, 1), (163, 0, -1, 1), (0, 163, 1, -1), (163, 163, -1, -1)):
        md.polygon([(cx, cy), (cx + 22 * sx, cy), (cx, cy + 22 * sy)], fill=INK + (235,))
    angle = ((zlib.crc32(pid.encode("utf-8")) % 41) - 20) / 10.0              # -2.0 .. +2.0 degrees
    big = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
    big.paste(mount, (18, 18))
    big = big.rotate(angle, resample=Image.BICUBIC, center=(100, 100))
    shadow = Image.new("RGBA", big.size, INK + (0,))
    shadow.putalpha(big.getchannel("A").point(lambda v: int(v * 0.40)).filter(ImageFilter.GaussianBlur(3)))
    im.alpha_composite(shadow, (196 + 2, 0 + 3))
    im.alpha_composite(big, (196, 0))
    return im.convert("RGB")


def miniature(photo):
    """The list miniature, 61x25: the face, framed, on the paper."""
    s = photo.size[0]
    inner = photo.crop((int(s * 0.10), int(s * 0.08), int(s * 0.90), int(s * 0.88)))
    im = Image.new("RGB", (61, 25), PAPER)
    ImageDraw.Draw(im).rectangle([18, 0, 42, 24], outline=INK_MUTED)
    im.paste(sharp(inner, (23, 23)), (19, 1))
    return im


def save(im, rel):
    path = os.path.join(ART, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)


# ---- the records -----------------------------------------------------------

def credit_entries(people, names):
    out, generic_files = [], []
    for pid, p in people.items():
        files = ["art/%s/%s.png" % (f, pid) for f in FOLDERS]
        if "generic" in p:
            generic_files += files
            continue
        cc = p["licence"].upper().startswith("CC")
        lic = p["licence"] if cc or not p["licence_basis"] else "%s (%s)" % (p["licence"], ", ".join(p["licence_basis"]))
        changes = "Cut to a square around the face, clear of any swastika or Iron Cross, black and white, toned; drawn as a 400 x 200 personnel card, an 80 x 80 portrait and a 61 x 25 miniature. Original SHA-1 %s." % p["sha1"]
        if "SA" in p["licence"].upper():
            changes += " These pictures are shared under the same licence."
        e = {
            "title": "Portrait: %s" % names.get(pid, p["name"]),
            "what": "%s's Encyclopedia picture, portrait and list miniature" % names.get(pid, p["name"]),
            "author": p["attribution"] or p["author"],
            "source": p["page"],
            "licence": lic,
        }
        if p["licence_url"]:
            # Commons publishes some as http://; the pack's credits take https:// only.
            e["licence_url"] = re.sub(r"^http://", "https://", p["licence_url"])
        e["changes"] = changes
        e["files"] = files
        out.append(e)
    if not generic_files:
        return out
    out.append({
        "title": "Portrait: the generic stand-in",
        "what": "The picture of a person without a usable photograph: %s" % ", ".join(names.get(pid, people[pid]["name"]) for pid in people if "generic" in people[pid]),
        "author": "Faction Wars, drawn by tools/look/make_ww2_portraits.py",
        "source": "https://github.com/TeeJS/faction-wars",
        "licence": "Original work of the Faction Wars project",
        "changes": "",
        "files": generic_files,
    })
    return out


def write_credits(entries):
    """Replaces the portraits' entries in credits.json (any entry whose files
    are all personnel pictures) and keeps every other entry as it was."""
    path = os.path.join(PACK, "credits.json")
    doc = json.load(open(path, encoding="utf-8"))
    ours = lambda a: a.get("files") and all(any(f.startswith("art/%s/" % d) for d in FOLDERS) for f in a["files"])
    doc["assets"] = [a for a in doc["assets"] if not ours(a)] + entries
    text = json.dumps(doc, ensure_ascii=False, indent=2)
    # Lists of names on one line, as the file is written by hand.
    text = re.sub(r'\[\s+("(?:[^"\\]|\\.)*"(?:,\s+"(?:[^"\\]|\\.)*")*)\s+\]',
                  lambda m: "[" + re.sub(r'",\s+"', '", "', m.group(1)) + "]", text)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text + "\n")


def write_provenance(people, names):
    rows, notes = [], []
    for pid, p in people.items():
        n = names.get(pid, p["name"])
        if p.get("note"):
            notes.append("- **%s**: %s" % (n, p["note"]))
        if "generic" in p:
            rows.append("| %s | `%s` | the generic stand-in: %s | | | |" % (n, pid, p["generic"]))
            continue
        rows.append("| %s | `%s` | [%s](%s) | %s | %s | `%s` `[%s]` |" % (
            n, pid, p["file"].replace("|", "\\|"), p["page"], p["licence"] + (" (" + ", ".join(p["licence_basis"]) + ")" if p["licence_basis"] else ""),
            (p["attribution"] or p["author"]).replace("|", "\\|"), p["sha1"], ", ".join("%g" % v for v in p["crop"])))
    text = """# WWII personnel pictures: where each comes from

Made by `tools/look/make_ww2_portraits.py` from `tools/look/ww2_portraits.json`;
regenerate rather than edit. Each character's three pictures (SCHEMA.md
section 14: `characters/<id>.png` 400x200, `portraits/characters/<id>.png`
80x80, `miniatures/characters/<id>.png` 61x25) are cut from one photograph on
Wikimedia Commons: public domain, CC0, CC BY or CC BY-SA only, checked on the
file's own page. The SHA-1 is Commons' own for the original, and the script
refuses a download that does not match it. The crop is `[cx, cy, side]`: the
square's centre as fractions of the picture's width and height, its side as a
fraction of the height. Each is framed as an ID photograph (TeeJ,
2026-09-30): the whole head, its top a tenth of the way down, centred
across, the head about half to three-fifths of the height with the
shoulders below - checked by eye in each rendered square, not only on the
original. Where the photograph runs out it fades out like a studio print.
Where a Nazi symbol sits below the head, a fourth number cuts the
photograph off above it and the print fades out below the cut (the notes);
Model alone keeps his cap cut, below the swastika on its eagle.
No picture shows a swastika or an Iron Cross, and
each German portrait was checked by eye; an eagle may show, as long as the
swastika does not (TeeJ, 2026-09-30). A person with no freely licensed
photograph gets the drawn stand-in instead.

| Character | id | Commons file | Licence | Author / attribution | SHA-1 and crop |
|---|---|---|---|---|---|
""" + "\n".join(rows) + "\n" + ("\n## Notes\n\n" + "\n".join(notes) + "\n" if notes else "")
    with open(os.path.join(ART, "PORTRAITS.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    folder = sys.argv[1]
    os.makedirs(folder, exist_ok=True)
    people = json.load(open(SOURCES, encoding="utf-8"))["people"]
    chars = json.load(open(os.path.join(PACK, "characters.json"), encoding="utf-8"))["characters"]
    names = {c["id"]: c["display_name"] for c in chars}
    sides = {c["id"]: c["faction"] for c in chars}
    missing = sorted(set(names) - set(people))
    if missing:
        sys.exit("no record for: %s" % ", ".join(missing))
    stand_in = generic()
    for pid, p in people.items():
        if "generic" in p:
            photo = stand_in
        else:
            photo = tone(crop(fetch(p, folder), p["crop"]))
            if photo.size[0] < 150:
                print("  %s: only %d px across the crop" % (pid, photo.size[0]))
        save(card(photo, sides[pid], pid), "characters/%s.png" % pid)
        save(sharp(photo, (80, 80)), "portraits/characters/%s.png" % pid)
        save(miniature(photo), "miniatures/characters/%s.png" % pid)
        print("%-16s %s" % (pid, "generic" if "generic" in p else "%s, %d px" % (p["licence"], photo.size[0])))
    write_credits(credit_entries(people, names))
    write_provenance(people, names)
    print("%d characters, %d generic" % (len(people), sum(1 for p in people.values() if "generic" in p)))


if __name__ == "__main__":
    main()

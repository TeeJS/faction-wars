"""The WWII pack's system pictures: each of its 88 systems flies a flag, as
its 37x37 system picture (SCHEMA.md section 14's planet_sprites/<artwork_id>.png,
which the sector window, the System window's title bar and the mission
windows show).

    python tools\\look\\make_ww2_flags.py <download folder>

Reads tools/look/ww2_flags.json: the Wikimedia Commons file of each flag - its
SVG's address and SHA-1 as Commons publishes them, the PNG Commons renders
from it and that PNG's SHA-256, its licence - and which flag each system flies,
and why. The rule (TeeJ, 2026-09-30: "identify the countries, not who
conquered them", and nothing a historian would call wrong): the country's own
flag of the war years - its national flag (a government in exile's counts),
else its own state's, national movement's or colony's flag of those years;
the flag of whoever held it only where it had none of its own then, or is
part of that country (Sicily, Siberia). A flag with `parts` is those flags
side by side (the Baltic States: Estonia, Latvia, Lithuania). Germany flies
the black-white-red tricolour, never the swastika flag (TeeJ, 2026-09-29: no
Nazi symbols in the game at all).

Downloads the SVG and the rendition into <download folder> (kept, so a second
run fetches nothing), stops on any hash that differs, and writes:

    packs/ww2/art/planet_sprites/<artwork_id>.png   37x37, per system (map.json)
    packs/ww2/art/FLAGS.md                          the provenance of each flag
    packs/ww2/credits.json                          the flags' entries (after
                                                    the Europe map's; every
                                                    other entry is left as is)

The picture: the flag at its own proportions, as large as fits 35 x 27, a
little toned to the paper, edged in ink, on clear. The same bytes come out
every run. Needs Pillow and numpy.
"""
import hashlib
import json
import os
import re
import sys
import time
import urllib.request

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SOURCES = os.path.join(ROOT, "tools", "look", "ww2_flags.json")
PACK = os.path.join(ROOT, "packs", "ww2")
ART = os.path.join(PACK, "art")
UA = "faction-wars-portrait-provenance/1.0 (https://github.com/TeeJS/faction-wars)"
SIZE, FIT_W, FIT_H = 37, 35, 27
TONE = 0.35                 # how far the flag's colours go towards "multiplied by the paper"


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


LOOK = json.load(open(os.path.join(PACK, "look.json"), encoding="utf-8"))
PAPER = np.array(hexrgb(LOOK["colors"]["paper"]), np.float64)
INK = hexrgb(LOOK["colors"]["ink"])


def fetch(url, folder, name, check):
    """`url`, downloaded once into `folder` as `name`, and `check`ed."""
    path = os.path.join(folder, name)
    if not os.path.exists(path):
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        for attempt in range(5):
            try:
                with urllib.request.urlopen(req, timeout=120) as r:
                    data = r.read()
                break
            except Exception as e:  # a busy server: wait and try again
                err = e
                time.sleep(4 + attempt * 6)
        else:
            sys.exit("could not download %s: %s" % (url, err))
        with open(path + ".part", "wb") as f:
            f.write(data)
        os.replace(path + ".part", path)
        time.sleep(0.5)
    check(open(path, "rb").read(), path)
    return path


def sprite(png):
    flag = Image.open(png).convert("RGBA")
    k = min(FIT_W / flag.width, FIT_H / flag.height)
    fw, fh = max(1, int(round(flag.width * k))), max(1, int(round(flag.height * k)))
    return finish(flag.resize((fw, fh), Image.LANCZOS), [])


def side_by_side(pngs):
    """Several flags as one picture (a system that is several countries): the
    3:2 box cut into as many upright panels, each the middle of one flag at its
    full height, with an ink line between them."""
    fw, fh = FIT_W, int(round(FIT_W * 2 / 3))
    n = len(pngs)
    widths = [(fw - (n - 1)) // n + (1 if i < (fw - (n - 1)) % n else 0) for i in range(n)]
    out = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    x, seps = 0, []
    for png, pw in zip(pngs, widths):
        flag = Image.open(png).convert("RGBA")
        cw = flag.height * pw / fh
        left = (flag.width - cw) / 2
        part = flag.crop((int(round(left)), 0, int(round(left + cw)), flag.height)).resize((pw, fh), Image.LANCZOS)
        out.alpha_composite(part, (x, 0))
        x += pw
        if x < fw:
            seps.append(x)
            x += 1
    return finish(out, seps)


def finish(flag, seps):
    """Toned a little to the paper, a hair of shadow, the ink edge (and ink
    lines at `seps`, x within the flag), centred on a clear 37x37 square."""
    fw, fh = flag.size
    a = np.asarray(flag, np.float64)
    rgb = a[..., :3]
    a[..., :3] = rgb * (1.0 - TONE) + rgb * (PAPER / 255.0) * TONE
    flag = Image.fromarray(np.round(a).astype(np.uint8), "RGBA")
    im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    x0, y0 = (SIZE - fw) // 2, (SIZE - fh) // 2
    d = ImageDraw.Draw(im)
    d.rectangle([x0, y0 + 1, x0 + fw, y0 + fh], fill=INK + (70,))          # a hair of shadow
    im.alpha_composite(flag, (x0, y0))
    d = ImageDraw.Draw(im)
    for sx in seps:
        d.line([(x0 + sx, y0), (x0 + sx, y0 + fh - 1)], fill=INK + (225,))
    d.rectangle([x0 - 1, y0 - 1, x0 + fw, y0 + fh], outline=INK + (225,))  # the ink edge
    return im


def licence_of(flags, key):
    """A flag's licence; a side-by-side one's is its parts' when they share one."""
    f = flags[key]
    if "parts" not in f:
        return f["licence"]
    lics = {flags[p]["licence"] for p in f["parts"]}
    return lics.pop() if len(lics) == 1 else "mixed"


def write_credits(flags, used):
    """Replaces the flags' entries in credits.json (any entry whose files are
    all system pictures) and puts them after the Europe map's."""
    path = os.path.join(PACK, "credits.json")
    doc = json.load(open(path, encoding="utf-8"))
    ours = lambda a: a.get("files") and all(f.startswith("art/planet_sprites/") for f in a["files"])
    assets = [a for a in doc["assets"] if not ours(a)]
    by_licence = {}
    for key, files in used.items():
        lic = licence_of(flags, key)
        if lic == "mixed":
            sys.exit("%s: its parts have different licences - give it credits entries of its own" % key)
        by_licence.setdefault(lic, []).append(key)
    entries = []
    by_number = lambda f: int(os.path.splitext(os.path.basename(f))[0])
    pd = sorted(by_licence.pop("Public domain", []))
    if pd:
        count = len({p for k in pd for p in flags[k].get("parts", [k])})
        entries.append({
            "title": "Flags of the war years",
            "what": "The systems' pictures: each country's own flag of the war years (%d flags)" % count,
            "author": "Wikimedia Commons contributors; each file's page, author and SHA-1 are in art/FLAGS.md",
            "source": "https://commons.wikimedia.org/wiki/Category:Flags_by_country",
            "licence": "Public domain (each file's grounds in art/FLAGS.md)",
            "changes": "The PNG Commons renders from each SVG, fitted into 35 x 27 at its own proportions (the Baltic States: Estonia's, Latvia's and Lithuania's side by side), a little toned to the paper, edged in ink, on a 37 x 37 clear square.",
            "files": sorted((f for k in pd for f in used[k]), key=by_number),
        })
    for licence, keys in sorted(by_licence.items()):
        for key in sorted(keys):
            f = flags[key]
            e = {"title": "Flag: %s" % f["name"], "what": "The picture of the systems that fly it", "author": f["author"],
                 "source": f["page"], "licence": licence}
            if f["licence_url"]:
                e["licence_url"] = re.sub(r"^http://", "https://", f["licence_url"])
            e["changes"] = "Commons' PNG rendering, fitted into 35 x 27, a little toned to the paper, edged in ink, on a 37 x 37 clear square." + \
                (" Shared under the same licence." if "SA" in licence.upper() else "")
            e["files"] = sorted(used[key], key=by_number)
            entries.append(e)
    at = next((i + 1 for i, a in enumerate(assets) if "look/europe_1941.jpg" in a.get("files", [])), len(assets))
    doc["assets"] = assets[:at] + entries + assets[at:]
    text = json.dumps(doc, ensure_ascii=False, indent=2)
    text = re.sub(r'\[\s+("(?:[^"\\]|\\.)*"(?:,\s+"(?:[^"\\]|\\.)*")*)\s+\]',
                  lambda m: "[" + re.sub(r'",\s+"', '", "', m.group(1)) + "]", text)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text + "\n")


def write_provenance(flags, systems, planets):
    rows_f = []
    for key in sorted(flags):
        f = flags[key]
        if "parts" in f:
            rows_f.append("| %s | side by side: %s | %s | | |" % (f["name"], ", ".join(flags[p]["name"] for p in f["parts"]), licence_of(flags, key)))
            continue
        rows_f.append("| %s | [%s](%s) | %s%s | %s | `%s` |" % (
            f["name"], f["file"].replace("|", "\\|"), f["page"], f["licence"],
            " (" + ", ".join(f["licence_basis"]) + ")" if f["licence_basis"] else "", f["author"].replace("|", "\\|"), f["sha1"]))
    rows_s = []
    for p in planets:
        s = systems[p["id"]]
        rows_s.append("| %s | `%d.png` | %s | %s |" % (p["display_name"], p["artwork_id"], flags[s["flag"]]["name"], s["why"]))
    text = """# WWII system pictures: the flags

Made by `tools/look/make_ww2_flags.py` from `tools/look/ww2_flags.json`;
regenerate rather than edit. Each system's picture (SCHEMA.md section 14:
`planet_sprites/<artwork_id>.png`, 37x37) is a flag, fixed like a planet's
artwork, that identifies the country itself, never its conqueror (TeeJ,
2026-09-30), and that holds up for the war years:

1. the country's own national flag (a government in exile's counts: Poland,
   Czechoslovakia, Korea);
2. else its own state's, national movement's or colony's flag of the war
   years (Burma, India, Indochina, Indonesia, Algeria, Malaya, Ceylon...);
3. the flag of whoever held it only where it had none of its own in those
   years (Formosa, Madagascar, Greenland, Gibraltar...) or is part of that
   country (Sicily, Crete, Siberia).

The reason for each system is in the table below. **Germany flies the
black-white-red tricolour**, its national flag of 1933-35, never the swastika
flag: no Nazi symbols in the game at all (TeeJ, 2026-09-29). The other flags
are as they were, regime emblems included.

Every flag is an SVG on Wikimedia Commons; the picture is made from the PNG
Commons renders from it. The SHA-1 is Commons' own for the SVG, and the script
refuses an SVG or a rendering whose hash differs from the one recorded.

## The flags

| Flag | Commons file | Licence | Author | SVG SHA-1 |
|---|---|---|---|---|
""" + "\n".join(rows_f) + """

## Which system flies which

| System | Picture | Flag | Why |
|---|---|---|---|
""" + "\n".join(rows_s) + "\n"
    with open(os.path.join(ART, "FLAGS.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    folder = sys.argv[1]
    os.makedirs(folder, exist_ok=True)
    doc = json.load(open(SOURCES, encoding="utf-8"))
    flags, systems = doc["flags"], doc["systems"]
    planets = json.load(open(os.path.join(PACK, "map.json"), encoding="utf-8"))["planets"]
    missing = sorted(p["id"] for p in planets if p["id"] not in systems)
    if missing:
        sys.exit("no flag for: %s" % ", ".join(missing))
    made, pngs = {}, {}
    for key, f in sorted(flags.items()):
        if "parts" in f:
            continue

        def sha1(data, path, want=f["sha1"]):
            if hashlib.sha1(data).hexdigest() != want:
                sys.exit("%s: SHA-1 differs from Commons' %s - a different file; not used" % (path, want))

        def sha256(data, path, want=f["rendition_sha256"]):
            if hashlib.sha256(data).hexdigest() != want:
                sys.exit("%s: Commons' rendering has changed (SHA-256 %s recorded) - look at it, then record the new one" % (path, want))
        fetch(f["url"], folder, f["sha1"] + ".svg", sha1)
        pngs[key] = fetch(f["rendition"], folder, f["sha1"] + ".320.png", sha256)
        made[key] = sprite(pngs[key])
    for key, f in flags.items():
        if "parts" in f:
            made[key] = side_by_side([pngs[p] for p in f["parts"]])
    out = os.path.join(ART, "planet_sprites")
    os.makedirs(out, exist_ok=True)
    used = {}
    for p in planets:
        key = systems[p["id"]]["flag"]
        name = "%d.png" % p["artwork_id"]
        made[key].save(os.path.join(out, name), optimize=True)
        used.setdefault(key, []).append("art/planet_sprites/" + name)
    write_credits(flags, used)
    write_provenance(flags, systems, planets)
    print("%d systems, %d flags" % (len(planets), len(used)))


if __name__ == "__main__":
    main()

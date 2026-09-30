"""The WWII pack's sector-window corner icons (display.json `icons`, SCHEMA.md
section 10): five pictures from game-icons.net, white on clear at 20 px, which
the map tints (the look draws them in ink on a paper tab).

    python tools\\look\\make_ww2_icons.py <download folder>

TeeJ, 2026-09-30: "the icons are garbage - we need better", "use
game-icons.net". The five are chosen to read at this size, where every drawing
of a whole ship turned to mush:

    manufacturing  a factory       Delapouite
    fleet          an anchor       Lorc
    defenses       a stone tower   Lorc
    mission        a spy           Delapouite
    uprising       a flame         Carl Olsen   (manual p091: "a flaming icon")

The SVGs come from the game-icons/icons repository at a fixed commit, each
checked against the SHA-256 recorded below, so the same bytes come out every
run. game-icons.net's icons are CC BY 3.0 (credited in packs/ww2/credits.json).
Each is rendered at 1024 px and brought down to 20 so its edges stay smooth.
20 px, not the engine's 16: the corner is laid out around the picture's own
size, and there is room for it between the flag and the bars below.
Needs Pillow and PyMuPDF (fitz).
"""
import hashlib
import os
import re
import sys
import urllib.request

import fitz
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "packs", "ww2", "look", "icons")
UA = "faction-wars-portrait-provenance/1.0 (https://github.com/TeeJS/faction-wars)"
COMMIT = "82d948812bfe3f269ef8f731dcdb07b08160edc4"   # game-icons/icons, 2026-04-23
SIZE = 20
ICONS = {  # corner glyph: (the icon's path in the repository, its author)
    "manufacturing": ("delapouite/factory.svg", "Delapouite"),
    "fleet": ("lorc/anchor.svg", "Lorc"),
    "defenses": ("lorc/stone-tower.svg", "Lorc"),
    "mission": ("delapouite/spy.svg", "Delapouite"),
    "uprising": ("carl-olsen/flame.svg", "Carl Olsen"),
}
SHA256 = {
    "delapouite/factory.svg": "970049a503a93715dfc8cb51b2b0c0df949e07e86067f3b81181661bc925b9c7",
    "lorc/anchor.svg": "134bba71f6b20c1983e821a0a36d6c83b813080951f1a5806c86a8136556f550",
    "lorc/stone-tower.svg": "38013e8d79d3e02f036fabf5b450ca960235a806e5b79c22fa77f739db480d1c",
    "delapouite/spy.svg": "f869fdb27f7d8bf83623542e91abab7def217a325c0421f4d0d78705c547f652",
    "carl-olsen/flame.svg": "49e7468e3d989f6130242d024eb1f4f42686ccfc5792db6dceac2ee13edcf727",
}


def fetch(rel, folder):
    path = os.path.join(folder, rel.replace("/", "__"))
    if not os.path.exists(path):
        url = "https://raw.githubusercontent.com/game-icons/icons/%s/%s" % (COMMIT, rel)
        data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=60).read()
        with open(path, "wb") as f:
            f.write(data)
    data = open(path, "rb").read()
    got = hashlib.sha256(data).hexdigest()
    want = SHA256.get(rel)
    if want is not None and got != want:
        sys.exit("%s: SHA-256 %s, recorded %s - a different file; not used" % (rel, got, want))
    return data.decode("utf-8"), got


def render(svg):
    """White on clear at SIZE px: the icon's shape as the alpha, rendered big
    and brought down."""
    svg = re.sub(r'<path d="M0 0h512v512H0z"\s*/>', "", svg)   # the black square game-icons draws behind
    doc = fitz.open(stream=svg.encode("utf-8"), filetype="svg")
    page = doc[0]
    k = 1024 / max(page.rect.width, page.rect.height)
    pix = page.get_pixmap(matrix=fitz.Matrix(k, k), alpha=True)
    shape = Image.frombytes("RGBA", (pix.width, pix.height), pix.samples).getchannel("A")
    alpha = shape.resize((SIZE, SIZE), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    folder = sys.argv[1]
    os.makedirs(folder, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    for glyph, (rel, _) in ICONS.items():
        svg, sha = fetch(rel, folder)
        render(svg).save(os.path.join(OUT, glyph + ".png"), optimize=True)
        print("%-14s %-26s %s" % (glyph, rel, sha))


if __name__ == "__main__":
    main()

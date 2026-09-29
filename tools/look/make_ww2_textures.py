"""Generate the WWII pack's look textures (docs/ww2-look-plan.md) into
packs/ww2/look/. Everything here is drawn from seeded noise - no photograph,
scan or third-party picture goes in - so the textures are the project's own
and the same bytes come out every run.

    python tools\\look\\make_ww2_textures.py

Writes:
    paper.png        512x512, tiles: parchment with mottling and fibres
                     (headers and edges only - never under long text)
    paper_frame.png  128x128 nine-slice (margin 20): a FLAT parchment centre,
                     the texture and a worn darkening only at the edges
    desk.png         512x512, tiles: the matte charcoal chassis
    grain.png        256x256, tiles: static film grain (alpha), laid over the
                     desk at low strength
    rule.png         64x3, tiles horizontally: the engraved brass rule

Colours are look.json's tokens (packs/ww2/look.json); change them there and
here together. Needs Pillow and numpy.
"""
import os

import numpy as np
from PIL import Image, ImageDraw

SEED = 1941
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "packs", "ww2", "look")

PAPER = (0xE9, 0xDF, 0xC6)
PAPER_EDGE = (0xD8, 0xC9, 0xA3)
PAPER_SHADE = (0xC4, 0xB2, 0x86)
CHASSIS = (0x1B, 0x1B, 0x19)
BRASS = (0xA8, 0x8A, 0x4E)
BRASS_DARK = (0x6B, 0x5A, 0x34)
BRASS_LIGHT = (0xD1, 0xB7, 0x7A)


def periodic_noise(rng, n, scale):
    """Band-limited noise that tiles: white noise filtered in the frequency
    domain (an FFT field is periodic by construction). `scale` is the feature
    size in pixels. Returns an n x n array in [-1, 1]."""
    white = rng.standard_normal((n, n))
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx * fx + fy * fy)
    sigma = 1.0 / max(scale, 1.0)
    spectrum = np.fft.fft2(white) * np.exp(-(r * r) / (2 * sigma * sigma))
    field = np.real(np.fft.ifft2(spectrum))
    field -= field.mean()
    peak = np.abs(field).max()
    return field / peak if peak > 0 else field


def tint(base, field, amount):
    """base colour * (1 + amount * field), per channel, clipped."""
    arr = np.empty(field.shape + (3,), dtype=np.float64)
    for c in range(3):
        arr[..., c] = base[c] * (1.0 + amount * field)
    return np.clip(arr, 0, 255)


def fibres(rng, img, count, colours, length=(6, 22), wrap=True):
    """Short curved fibres, drawn with their wrapped copies so the picture
    still tiles."""
    n = img.size[0]
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(count):
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        ang = rng.uniform(0, np.pi)
        ln = rng.uniform(*length)
        bend = rng.uniform(-0.6, 0.6)
        col = colours[rng.integers(len(colours))]
        pts = []
        for t in np.linspace(0, 1, 6):
            a = ang + bend * t
            pts.append((x + np.cos(a) * ln * t, y + np.sin(a) * ln * t))
        offsets = [(dx, dy) for dx in (-n, 0, n) for dy in (-n, 0, n)] if wrap else [(0, 0)]
        for dx, dy in offsets:
            d.line([(px + dx, py + dy) for px, py in pts], fill=col, width=1)


def paper(rng):
    n = 512
    mottle = 0.6 * periodic_noise(rng, n, 90) + 0.4 * periodic_noise(rng, n, 24)
    fine = periodic_noise(rng, n, 2.5)
    arr = tint(PAPER, mottle, 0.035) * (1.0 + 0.012 * fine[..., None])
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    fibres(rng, img, 1400, [(120, 100, 70, 26), (255, 250, 235, 34), (150, 128, 90, 18)])
    # A few specks, as real stock has.
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(90):
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        r = rng.uniform(0.4, 1.1)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(95, 80, 55, 60))
    return img


def paper_frame(paper_img):
    """A nine-slice: flat parchment centre, the paper's texture and a gentle
    darkening only within `margin` pixels of the edge."""
    n, margin = 128, 20
    tex = np.asarray(paper_img.crop((0, 0, n, n)), dtype=np.float64)
    flat = np.empty((n, n, 3))
    flat[...] = PAPER
    yy, xx = np.mgrid[0:n, 0:n]
    edge = np.minimum(np.minimum(xx, n - 1 - xx), np.minimum(yy, n - 1 - yy)).astype(np.float64)
    w = np.clip(1.0 - edge / margin, 0, 1) ** 1.6          # 1 at the rim, 0 inside the margin
    shade = np.empty((n, n, 3))
    for c in range(3):
        shade[..., c] = PAPER_EDGE[c] + (PAPER_SHADE[c] - PAPER_EDGE[c]) * np.clip(1.0 - edge / 3.0, 0, 1)
    textured = tex * (1 - 0.55 * w[..., None]) + shade * (0.55 * w[..., None])
    arr = flat * (1 - w[..., None]) + textured * w[..., None]
    # The outermost pixel: a hairline in the shade colour, the sheet's cut edge.
    arr[edge == 0] = PAPER_SHADE
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def desk(rng):
    n = 512
    low = periodic_noise(rng, n, 120)
    # Fine grain stretched along x: a matte, faintly brushed surface.
    white = rng.standard_normal((n, n))
    spec = np.fft.fft2(white)
    fx, fy = np.meshgrid(np.fft.fftfreq(n), np.fft.fftfreq(n))
    spec *= np.exp(-(fx * fx) / (2 * 0.004 ** 2) - (fy * fy) / (2 * 0.12 ** 2))
    streak = np.real(np.fft.ifft2(spec))
    streak /= np.abs(streak).max()
    arr = tint(CHASSIS, 0.7 * low + 0.3 * streak, 0.05)
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def grain(rng):
    n = 256
    g = rng.standard_normal((n, n))
    lum = np.where(g > 0, 255, 0).astype(np.uint8)
    alpha = np.clip(np.abs(g) * 4, 0, 10).astype(np.uint8)   # at most ~4% - a whisper
    rgba = np.dstack([lum, lum, lum, alpha])
    return Image.fromarray(rgba, "RGBA")


def rule():
    img = Image.new("RGBA", (64, 3))
    for x in range(64):
        img.putpixel((x, 0), BRASS_DARK + (255,))
        img.putpixel((x, 1), BRASS + (255,))
        img.putpixel((x, 2), BRASS_LIGHT + (90,))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(SEED)
    p = paper(rng)
    outputs = {
        "paper.png": p,
        "paper_frame.png": paper_frame(p),
        "desk.png": desk(rng),
        "grain.png": grain(rng),
        "rule.png": rule(),
    }
    for name, img in outputs.items():
        path = os.path.join(OUT, name)
        img.save(path, optimize=True)
        print("%-16s %s %7d bytes" % (name, img.size, os.path.getsize(path)))


if __name__ == "__main__":
    main()

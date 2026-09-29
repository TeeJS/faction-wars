"""The WWII pack's Europe inset (packs/ww2/look/MAP-DETAIL.md, "The Europe
inset"): page 14 of the same 1941 atlas, "Western Europe - political map" at
1:25,000,000, warped onto the strategic map's frame so each system sits over its
own place, for the sector windows of the small European theatres.

    python tools/look/make_ww2_map_europe.py <downloaded page 14> <out.jpg>

Needs numpy and opencv-python, and packs/ww2/look/world_1941_detail.jpg (made
by make_ww2_map_detail.py), which is the frame it is lined up with.

Page 14 is a different projection (Lambert azimuthal) from the world page, so
no single transform fits. The fit, all automatic and deterministic:
  1. the sea on both maps (pale, unsaturated) as masks;
  2. a search over scale, rotation and offset for the best overlap of the masks;
  3. a smooth polynomial pulled onto the coastlines; then patches of coastline
     matched shape against shape, searched for 30, 14, 8 and 6 px around
     where a spline through the last round's anchors puts them, anchors the
     others disagree with dropped each round;
  4. patches of country fill (both pages use the atlas's one palette) matched
     inland, three times, where the coast says nothing;
  5. a thin-plate spline through all those anchors (smoothing 0.1), which is
     the warp; it is checked by leaving each anchor out in turn, and it stops
     if any theatre it is for lacks anchors of its own.
It prints each stage's figures: a different download is caught there.

How close it is: the anchors agree to about 1 px of the detail map. Checked
against city symbols read on both maps, the fit is 5-15 detail px out at some
(Prague, Lisbon), while the pack's own systems were placed on the world page
with a fit of 18 px RMS on the 1750-px map (PACK.md, "Map layout"), about
40 detail px. So the plate sits every system in its own country, as the
strategic map does; the page is not the limit.
"""
import sys
import numpy as np
import cv2

DETAIL = "packs/ww2/look/world_1941_detail.jpg"
MAP_UNITS = (700.0, 420.0)             # pack.json map_image_rect size
AT = (328.0, 120.0, 57.0, 52.0)        # the inset, in map units (look.json map_insets)
DENSITY = 21.0                         # output px per map unit: page 14's own
LAM = 0.1
DET_ROI = (1800, 450, 2500, 1100)      # detail px searched for coast
FIT = (1905, 690, 2265, 1020)          # detail px refined inland: the five theatres + margin
P14_ROI = (200, 140, 2545, 3000)       # page 14's map frame
# The theatres the inset is for: each sector window's area in detail px, as the
# game lays it out (the same at every window size). Every one must have
# anchors of its own, or the warp there is a guess.
THEATRES = {
    "British Isles": (1933.9, 719.8, 87.8, 56.2),
    "Western Europe": (2037.0, 738.1, 86.3, 109.7),
    "Central Europe": (2118.2, 746.7, 117.0, 106.0),
    "Iberia": (1935.9, 923.5, 60.4, 70.5),
    "Italian Peninsula": (2115.6, 886.8, 69.7, 86.2),
}
REACH = 40                             # detail px around a theatre that count as its own


def seamask(img, roi, rc, ro, min_area):
    x0, y0, x1, y1 = roi
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    h, s, v = hsv[..., 0].astype(int), hsv[..., 1].astype(int), hsv[..., 2].astype(int)
    m = ((h >= 18) & (h <= 48) & (s < 55) & (v > 140)).astype(np.uint8) * 255
    out = np.zeros_like(m)
    out[y0:y1, x0:x1] = m[y0:y1, x0:x1]
    el = lambda r: cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
    out = cv2.morphologyEx(out, cv2.MORPH_CLOSE, el(rc))
    out = cv2.morphologyEx(out, cv2.MORPH_OPEN, el(ro))
    n, lab, st, _ = cv2.connectedComponentsWithStats(out)
    keep = np.zeros_like(out)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] > min_area:
            keep[lab == i] = 255
    return keep


C0, CS = np.array([1250.0, 2100.0]), 1000.0


def basis(p, deg):
    u = (p[:, 0] - C0[0]) / CS
    v = (p[:, 1] - C0[1]) / CS
    return np.stack([u ** i * v ** j for i in range(deg + 1) for j in range(deg + 1 - i)], 1)


def poly(coef, p, deg):
    B = basis(np.atleast_2d(p).astype(float), deg)
    return np.stack([B @ coef[0], B @ coef[1]], 1)


def lsq(p, q, deg):
    B = basis(p, deg)
    return [np.linalg.lstsq(B, q[:, 0], rcond=None)[0], np.linalg.lstsq(B, q[:, 1], rcond=None)[0]]


def _U(r2):
    with np.errstate(divide="ignore", invalid="ignore"):
        u = 0.5 * r2 * np.log(r2)
    u[r2 == 0] = 0
    return u


class TPS:
    """Thin-plate spline from src to dst; lam smooths (0 passes through every anchor)."""
    def __init__(self, src, dst, lam=0.0, scale=100.0):
        self.o, self.s = src.mean(0), scale
        c = (src - self.o) / self.s
        n = len(c)
        L = np.zeros((n + 3, n + 3))
        L[:n, :n] = _U(((c[:, None] - c[None]) ** 2).sum(-1)) + lam * np.eye(n)
        L[:n, n:] = np.hstack([np.ones((n, 1)), c])
        L[n:, :n] = L[:n, n:].T
        rhs = np.zeros((n + 3, 2))
        rhs[:n] = dst
        sol = np.linalg.solve(L, rhs)
        self.c, self.w, self.a = c, sol[:n], sol[n:]

    def __call__(self, q):
        q = (np.atleast_2d(q) - self.o) / self.s
        out = np.hstack([np.ones((len(q), 1)), q]) @ self.a
        for i in range(0, len(q), 20000):
            qq = q[i:i + 20000]
            out[i:i + 20000] += _U(((qq[:, None] - self.c[None]) ** 2).sum(-1)) @ self.w
        return out


def subpixel(r, px, py):
    if 0 < px < r.shape[1] - 1 and 0 < py < r.shape[0] - 1:
        dx = (r[py, px + 1] - r[py, px - 1]) / (2 * (2 * r[py, px] - r[py, px + 1] - r[py, px - 1]) + 1e-9)
        dy = (r[py + 1, px] - r[py - 1, px]) / (2 * (2 * r[py, px] - r[py + 1, px] - r[py - 1, px]) + 1e-9)
        return dx, dy
    return 0.0, 0.0


def search(mp, md):
    """Step 2: the scale, rotation and offset that overlap the two seas best."""
    DX0, DY0, R = 1750, 400, 0.5
    dimg = cv2.resize(md[DY0:1150, DX0:2550], None, fx=R, fy=R, interpolation=cv2.INTER_AREA).astype(np.float32) / 255
    PX0, PY0 = 250, 1300
    tsrc = mp[PY0:2900, PX0:2500].astype(np.float32) / 255
    best = None
    for sc in np.arange(0.20, 0.36, 0.005):
        for rot in np.arange(-15, 15.1, 1.0):
            h, w = tsrc.shape
            k = sc * R
            M = cv2.getRotationMatrix2D((w / 2, h / 2), rot, k)
            ow, oh = int(w * k), int(h * k)
            M[0, 2] += ow / 2 - w / 2
            M[1, 2] += oh / 2 - h / 2
            t = cv2.warpAffine(tsrc, M, (ow, oh), flags=cv2.INTER_AREA, borderValue=0.5)
            if t.shape[0] >= dimg.shape[0] or t.shape[1] >= dimg.shape[1]:
                continue
            _, mv, _, ml = cv2.minMaxLoc(cv2.matchTemplate(dimg, t, cv2.TM_CCOEFF_NORMED))
            if best is None or mv > best[0]:
                best = (mv, sc, rot, ml, M.copy())
    mv, sc, rot, ml, M = best
    print("search: overlap %.3f at scale %.3f, rotation %.1f deg" % (mv, sc, rot))
    A = np.vstack([M, [0, 0, 1]])
    T0 = np.array([[1, 0, -PX0], [0, 1, -PY0], [0, 0, 1]], float)
    S = np.array([[1 / R, 0, DX0 + ml[0] / R], [0, 1 / R, DY0 + ml[1] / R], [0, 0, 1]], float)
    return S @ A @ T0


def icp(mp, md, H):
    """Step 3a: a degree-3 polynomial pulled onto the world page's coastline."""
    grad = lambda m: cv2.morphologyEx(m, cv2.MORPH_GRADIENT, np.ones((3, 3), np.uint8))
    x0, y0, x1, y1 = DET_ROI
    ed = grad(md)
    ed[:y0 + 3] = 0
    ed[y1 - 3:] = 0
    ed[:, :x0 + 3] = 0
    ed[:, x1 - 3:] = 0
    src = np.where(ed > 0, 0, 255).astype(np.uint8)
    dist, lab = cv2.distanceTransformWithLabels(src, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
    zy, zx = np.where(src == 0)
    lut = np.zeros(lab.max() + 1, dtype=np.int64)
    lut[lab[zy, zx]] = np.arange(len(zy))
    py, px = np.where(grad(mp) > 0)
    P = np.stack([px, py], 1).astype(np.float64)[::3]
    coef = lsq(P, P @ H[:2, :2].T + H[:2, 2], 3)
    for thr in [20, 15, 12, 10, 8, 6, 5, 4, 3, 3, 3, 2.5, 2.5, 2.5]:
        Q = poly(coef, P, 3)
        xi, yi = np.round(Q[:, 0]).astype(int), np.round(Q[:, 1]).astype(int)
        inside = (xi > x0 + 5) & (xi < x1 - 5) & (yi > y0 + 5) & (yi < y1 - 5)
        xi, yi = np.clip(xi, 0, md.shape[1] - 1), np.clip(yi, 0, md.shape[0] - 1)
        near = lut[lab[yi, xi]]
        ok = inside & (dist[yi, xi] < thr)
        coef = lsq(P[ok], np.stack([zx[near], zy[near]], 1).astype(np.float64)[ok], 3)
    return coef


def unknown_outside(mask, roi):
    """The mask as 0-1 floats, with everything outside `roi` 0.5 - neither sea
    nor land - so a page's margin does not read as a coast."""
    x0, y0, x1, y1 = roi
    f = np.full(mask.shape, 0.5, np.float32)
    f[y0:y1, x0:x1] = mask[y0:y1, x0:x1].astype(np.float32) / 255
    return f


def patches(mp, md, pred, slack):
    """Step 3b: coastline patches of page 14, matched shape against shape, each
    searched for within `slack` detail px of where `pred` (page 14 px -> detail
    px) puts it."""
    mpf, mdf = unknown_outside(mp, P14_ROI), unknown_outside(md, DET_ROI)
    edge = cv2.morphologyEx(mp, cv2.MORPH_GRADIENT, np.ones((3, 3), np.uint8))
    x0, y0, x1, y1 = DET_ROI
    R = 150
    A, T, S = [], [], []
    for cy in range(200, 3000, 60):
        for cx in range(230, 2530, 60):
            if edge[cy - 30:cy + 30, cx - 30:cx + 30].sum() < 255 * 20:
                continue
            a = np.array([cx, cy], float)
            q = pred(a)[0]
            if not (x0 + 60 < q[0] < x1 - 60 and y0 + 60 < q[1] < y1 - 60):
                continue
            J = np.stack([pred(a + [1, 0])[0] - q, pred(a + [0, 1])[0] - q], 1)
            patch = mpf[cy - R:cy + R, cx - R:cx + R]
            if patch.shape != (2 * R, 2 * R) or patch.std() < 0.3:
                continue
            n = int(2 * R * np.sqrt(abs(np.linalg.det(J)))) | 1
            c = n // 2
            M = np.hstack([J, (np.array([c, c]) - J @ np.array([R, R]))[:, None]])
            t = cv2.warpAffine(patch, M, (n, n), flags=cv2.INTER_AREA, borderValue=0.5)
            rx, ry = int(round(q[0])) - c - slack, int(round(q[1])) - c - slack
            r = cv2.matchTemplate(mdf[ry:ry + n + 2 * slack, rx:rx + n + 2 * slack], t, cv2.TM_CCOEFF_NORMED)
            _, mv, _, ml = cv2.minMaxLoc(r)
            dx, dy = subpixel(r, *ml)
            rr = r.copy()
            cv2.circle(rr, ml, 4, -1, -1)
            A.append(a)
            T.append([rx + ml[0] + dx + c, ry + ml[1] + dy + c])
            S.append((mv, mv - rr.max()))
    A, T, S = np.array(A), np.array(T), np.array(S)
    return A, T, (S[:, 0] > 0.75) & (S[:, 1] > 0.02)


def loo(A, T, lam):
    """Each anchor's distance from where the others put it."""
    out = np.zeros(len(A))
    for k in range(len(A)):
        m = np.ones(len(A), bool)
        m[k] = False
        out[k] = np.linalg.norm(TPS(A[m], T[m], lam)(A[k])[0] - T[k])
    return out


def prune(A, T, lam, floor):
    """Drop anchors the others disagree with (a patch matched to the wrong
    stretch of coast), worst first, until none is out by more than
    max(floor, 3 x the median) detail px."""
    keep = np.ones(len(A), bool)
    while True:
        res = loo(A[keep], T[keep], lam)
        worst = int(np.argmax(res))
        if res[worst] <= max(floor, 3 * np.median(res)):
            return keep, res
        keep[np.where(keep)[0][worst]] = False


def lab_ab(img):
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB).astype(np.float32)
    return cv2.GaussianBlur(lab[..., 1:], (0, 0), 1.6)


def fills(p14, det, cs, cd):
    """Step 4: country-fill patches inland, where the coast says nothing. Each
    round starts again from the coast anchors (cs -> cd) plus that round's."""
    X0, Y0, X1, Y1 = FIT
    src, dst = cs, cd
    D = lab_ab(det[Y0:Y1, X0:X1])
    H, SR = 16, 5
    for rnd in range(3):
        f = TPS(src, dst, 0.0)
        K = 2
        xs, ys = X0 + (np.arange((X1 - X0) * K) + 0.5) / K, Y0 + (np.arange((Y1 - Y0) * K) + 0.5) / K
        qx, qy = np.meshgrid(xs, ys)
        pp = f(np.stack([qx.ravel(), qy.ravel()], 1))
        w = cv2.remap(p14, pp[:, 0].reshape(qx.shape).astype(np.float32), pp[:, 1].reshape(qx.shape).astype(np.float32), cv2.INTER_LINEAR)
        W = lab_ab(cv2.resize(w, (X1 - X0, Y1 - Y0), interpolation=cv2.INTER_AREA))
        ns, nd, shifts = [], [], []
        for cy in range(H + SR, (Y1 - Y0) - H - SR, 10):
            for cx in range(H + SR, (X1 - X0) - H - SR, 10):
                tD = D[cy - H:cy + H, cx - H:cx + H]
                if tD.std() < 4:
                    continue
                reg = W[cy - H - SR:cy + H + SR, cx - H - SR:cx + H + SR]
                r = sum(cv2.matchTemplate(np.ascontiguousarray(reg[..., c]), np.ascontiguousarray(tD[..., c]), cv2.TM_CCOEFF_NORMED) for c in range(2)) / 2
                _, mv, _, ml = cv2.minMaxLoc(r)
                if mv < 0.85 or ml[0] in (0, r.shape[1] - 1) or ml[1] in (0, r.shape[0] - 1):
                    continue
                dx, dy = subpixel(r, *ml)
                d = np.array([ml[0] + dx - SR, ml[1] + dy - SR])
                q = np.array([X0 + cx, Y0 + cy], float)
                ns.append(q)
                nd.append(f(q + d)[0])
                shifts.append(np.linalg.norm(d))
        print("fills round %d: %d anchors, shift median %.2f px" % (rnd, len(shifts), float(np.median(shifts))))
        src2, dst2 = np.vstack([cs, ns]), np.vstack([cd, nd])
        res = np.linalg.norm(TPS(src2, dst2, 0.5)(src2) - dst2, axis=1) * 0.28
        src, dst = src2[res < 1.5], dst2[res < 1.5]
    return src, dst


def main(p14_path, out_path):
    p14 = cv2.imread(p14_path)
    det = cv2.imread(DETAIL)
    if p14 is None or det is None:
        sys.exit("could not read %s or %s" % (p14_path, DETAIL))
    mp = seamask(p14, P14_ROI, 3, 3, (p14.shape[1] * 0.02) ** 2)
    md = seamask(det, DET_ROI, 3, 1, 400)
    coef = icp(mp, md, search(mp, md))
    pred = lambda p: poly(coef, p, 3)
    # Wide searches first, from the rough fit; then narrower, each from a spline
    # through the last round's anchors, so a region the polynomial misses (it
    # was 20 px out at Iberia) is found and then held.
    for slack, lam in ((30, 5.0), (14, 1.0), (8, 0.5), (6, 0.5)):
        A, T, good = patches(mp, md, pred, slack)
        keep, res = prune(A[good], T[good], lam, 3.0)
        A, T = A[good][keep], T[good][keep]
        print("coast patches, search %2d px: %d matched, %d kept, leave-one-out median %.2f px" % (slack, good.sum(), keep.sum(), float(np.median(res))))
        pred = TPS(A, T, lam)
    src, dst = fills(p14, det, T, A)
    res = loo(src, dst, LAM) * 0.28
    print("anchors %d; leaving each out: median %.2f, 90%% %.2f, worst %.2f detail px" % (len(src), np.median(res), np.percentile(res, 90), res.max()))
    # Every theatre must have anchors of its own close by, so the warp there is
    # held, not extrapolated (a first build had none near Iberia and was 15 px
    # out there).
    short = []
    for name, (x, y, w, h) in THEATRES.items():
        near = (src[:, 0] > x - REACH) & (src[:, 0] < x + w + REACH) & (src[:, 1] > y - REACH) & (src[:, 1] < y + h + REACH)
        print("  %-18s %3d anchors within %d px, leave-one-out median %.2f, worst %.2f detail px" % (name, near.sum(), REACH, np.median(res[near]) if near.any() else np.nan, res[near].max() if near.any() else np.nan))
        if near.sum() < 4:
            short.append(name)
    if short:
        sys.exit("too few anchors to trust the fit in: %s" % ", ".join(short))
    f = TPS(src, dst, LAM)
    # Output pixel (i, j) is map unit AT + (i + 0.5) / DENSITY, which is detail
    # px (map unit) * detail size / map units, which is page-14 px f(that).
    w, h = round(AT[2] * DENSITY), round(AT[3] * DENSITY)
    kx, ky = det.shape[1] / MAP_UNITS[0], det.shape[0] / MAP_UNITS[1]
    qx, qy = np.meshgrid((AT[0] + (np.arange(w) + 0.5) * AT[2] / w) * kx, (AT[1] + (np.arange(h) + 0.5) * AT[3] / h) * ky)
    pp = f(np.stack([qx.ravel(), qy.ravel()], 1))
    out = cv2.remap(p14, pp[:, 0].reshape(qx.shape).astype(np.float32), pp[:, 1].reshape(qx.shape).astype(np.float32), cv2.INTER_LANCZOS4)
    cv2.imwrite(out_path, out, [cv2.IMWRITE_JPEG_QUALITY, 88])
    print("wrote %s, %d x %d, covering map units %s" % (out_path, w, h, list(AT)))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])

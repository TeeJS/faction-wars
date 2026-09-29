"""The WWII pack's detail map (packs/ww2/look/MAP-DETAIL.md): the Commons scan
of the 1941 atlas's Political Map of the World, lined up with
packs/ww2/world_1941.jpg (the same scan, cropped and shrunk) and resampled
onto its frame at 4096 wide.

    python tools/look/make_ww2_map_detail.py <downloaded original> <out.jpg>

Needs numpy and opencv-python. Prints the fit, so a different download (or a
different scan) is caught: the fit should have thousands of inliers, a
rotation near 0 and a residual under a pixel.
"""
import sys
import numpy as np
import cv2

OURS = "packs/ww2/world_1941.jpg"
WIDTH = 4096


def main(scan_path: str, out_path: str) -> None:
    ours = cv2.imread(OURS)
    scan = cv2.imread(scan_path)
    if ours is None or scan is None:
        sys.exit("could not read %s or %s" % (OURS, scan_path))
    g1 = cv2.cvtColor(ours, cv2.COLOR_BGR2GRAY)
    # Features at comparable detail: the scan halved, the transform doubled back.
    half = cv2.resize(cv2.cvtColor(scan, cv2.COLOR_BGR2GRAY), None, fx=0.5, fy=0.5, interpolation=cv2.INTER_AREA)
    sift = cv2.SIFT_create(nfeatures=20000)
    k1, d1 = sift.detectAndCompute(g1, None)
    k2, d2 = sift.detectAndCompute(half, None)
    good = [m for m, n in cv2.BFMatcher(cv2.NORM_L2).knnMatch(d1, d2, k=2) if m.distance < 0.7 * n.distance]
    src = np.float32([k1[m.queryIdx].pt for m in good])
    dst = np.float32([k2[m.trainIdx].pt for m in good]) * 2.0
    M, inliers = cv2.estimateAffinePartial2D(src, dst, method=cv2.RANSAC, ransacReprojThreshold=3.0, maxIters=20000)
    keep = inliers.ravel() == 1
    res = np.linalg.norm((src[keep] @ M[:, :2].T + M[:, 2]) - dst[keep], axis=1)
    print("matches %d, inliers %d, scale %.5f, rotation %.4f deg, median residual %.2f px" % (
        len(good), int(keep.sum()), float(np.hypot(M[0, 0], M[1, 0])),
        float(np.degrees(np.arctan2(M[1, 0], M[0, 0]))), float(np.median(res))))

    # Output pixel (u, v) is our pixel (u / k, v / k), which is scan pixel M (u / k, v / k).
    k = 3
    A = M.copy()
    A[:, :2] = A[:, :2] / k
    big = cv2.warpAffine(scan, A, (ours.shape[1] * k, ours.shape[0] * k),
                         flags=cv2.INTER_CUBIC | cv2.WARP_INVERSE_MAP, borderMode=cv2.BORDER_REPLICATE)
    height = round(WIDTH * ours.shape[0] / ours.shape[1])
    out = cv2.resize(big, (WIDTH, height), interpolation=cv2.INTER_AREA)
    cv2.imwrite(out_path, out, [cv2.IMWRITE_JPEG_QUALITY, 88])
    back = cv2.resize(out, (ours.shape[1], ours.shape[0]), interpolation=cv2.INTER_AREA)
    corr = np.corrcoef(cv2.cvtColor(back, cv2.COLOR_BGR2GRAY).ravel().astype(float), g1.ravel().astype(float))[0, 1]
    print("wrote %s, %d x %d; back at %d x %d it correlates %.4f with %s" % (
        out_path, WIDTH, height, ours.shape[1], ours.shape[0], corr, OURS))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])

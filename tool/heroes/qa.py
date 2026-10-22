# Blind check of a cut: how much backdrop got kept, how much figure got lost.
# kept_bg: share of kept pixels within 6px of the edge that look like backdrop.
# lost_fig: share of removed pixels inside the kept silhouette's hull area that
# are clearly not backdrop (dist > 45), relative to kept area.
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi


def qa(jpg, png):
    im = np.asarray(Image.open(jpg).convert('RGB')).astype(float)
    cut = Image.open(png)
    a = np.asarray(cut.getchannel('A')) > 128
    # locate crop in source by matching size via bbox search on alpha: cut was bbox-cropped,
    # so find offset by template match on a few rows (cheap: exact pixel match of RGB)
    c = np.asarray(cut.convert('RGB')).astype(float)
    h, w = a.shape
    H, W, _ = im.shape
    best = None
    ys, xs = np.where(a)
    pick = np.linspace(0, len(ys) - 1, 200).astype(int)
    for oy in range(0, H - h + 1):
        for ox in range(0, W - w + 1):
            d = np.abs(im[ys[pick] + oy, xs[pick] + ox] - c[ys[pick], xs[pick]]).mean()
            if best is None or d < best[0]:
                best = (d, oy, ox)
            if d < 1:
                break
        if best[0] < 1:
            break
    _, oy, ox = best
    full = np.zeros((H, W), bool)
    full[oy:oy + h, ox:ox + w] = a
    band = 20
    border = np.concatenate([im[:band].reshape(-1, 3), im[-band:].reshape(-1, 3),
                             im[:, :band].reshape(-1, 3), im[:, -band:].reshape(-1, 3)])
    bg = np.median(border, 0)
    dist = np.sqrt(((im - bg) ** 2).sum(2))
    ring = full & ~ndi.binary_erosion(full, iterations=6)
    kept_bg = (dist[ring] < 22).mean()
    hull = ndi.binary_closing(full, iterations=25)
    lost = hull & ~full & (dist > 45)
    lost_fig = lost.sum() / max(1, full.sum())
    return round(float(kept_bg), 3), round(float(lost_fig), 3)


if __name__ == '__main__':
    for n in sys.argv[1:]:
        for suf in ('_cut.png', '_cut2.png'):
            try:
                print(n, suf, qa(n + '.jpg', n + suf))
            except FileNotFoundError:
                pass

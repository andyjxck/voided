# Stricter cutter for figures with white or grey parts (wings, fans, steel)
# that the light-backdrop cutter eats. Backdrop = pixels close to a smooth
# backdrop model (fitted per image from the border), flood filled from the
# border. Soft cast shadows are only dropped below the figure's feet line.
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi


def cut(path, out, thr=30.0):
    im = np.asarray(Image.open(path).convert('RGB')).astype(float)
    h, w, _ = im.shape
    # smooth backdrop: fit a quadratic surface to the border band per channel
    band = 20
    m = np.zeros((h, w), bool)
    m[:band] = m[-band:] = True
    m[:, :band] = m[:, -band:] = True
    yy, xx = np.mgrid[0:h, 0:w]
    X = np.stack([np.ones(h * w), xx.ravel() / w, yy.ravel() / h, (xx.ravel() / w) ** 2,
                  (yy.ravel() / h) ** 2, xx.ravel() * yy.ravel() / (w * h)], 1)
    bgm = np.zeros_like(im)
    sel = m.ravel()
    for c in range(3):
        coef, *_ = np.linalg.lstsq(X[sel], im[..., c].ravel()[sel], rcond=None)
        bgm[..., c] = (X @ coef).reshape(h, w)
    dist = np.sqrt(((im - bgm) ** 2).sum(2))
    sm = ndi.uniform_filter(dist, 3)
    cand = sm < thr
    lab, _ = ndi.label(cand)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    fg = ~np.isin(lab, list(edge))
    # shadow: darker than backdrop, low colour, mostly in the bottom quarter of the figure
    lum = im.mean(2)
    bl = bgm.mean(2)
    sat = im.max(2) - im.min(2)
    rows = np.where(fg.any(1))[0]
    if len(rows):
        top, bot = rows[0], rows[-1]
        foot = top + 0.8 * (bot - top)
        shadow = (lum < bl) & (lum > 0.45 * bl) & (sat < 22) & (yy > foot) & (ndi.uniform_filter(lum, 9) - lum < 6)
        fg &= ~shadow
    fg = ndi.binary_opening(fg, iterations=2)
    lab2, n = ndi.label(fg)
    if n:
        sizes = ndi.sum(fg, lab2, range(1, n + 1))
        fg = np.isin(lab2, [i + 1 for i, s in enumerate(sizes) if s > 0.02 * sizes.max()])
    fg = ndi.binary_fill_holes(fg)
    a = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    rgba = Image.fromarray(im.astype(np.uint8)).convert('RGBA')
    rgba.putalpha(a)
    bb = rgba.getbbox()
    rgba.crop(bb).save(out)
    print(path, 'bbox', bb, 'fg %.1f%%' % (100 * fg.mean()))


if __name__ == '__main__':
    thr = float(sys.argv[2]) if len(sys.argv) > 2 else 30.0
    n = sys.argv[1]
    cut(n + '.jpg', n + '_cut2.png', thr)

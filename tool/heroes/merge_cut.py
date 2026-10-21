# Final cut = clean cut (cut.py) plus any part only the strict cutter kept
# that is clearly not backdrop (white wings, pale fans). Writes <n>_final.png.
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi
sys.path.insert(0, '.')
import cut as c1
import cut2 as c2


def full_mask(jpg, fn):
    import tempfile, os
    t = tempfile.mktemp(suffix='.png')
    # re-run cutter without cropping: reproduce by pasting crop back at bbox
    fn(jpg, t)
    im = Image.open(jpg)
    cutim = Image.open(t)
    src = np.asarray(im.convert('RGB')).astype(float)
    cc = np.asarray(cutim.convert('RGB')).astype(float)
    a = np.asarray(cutim.getchannel('A')).astype(float)
    h, w = a.shape
    H, W, _ = src.shape
    ys, xs = np.where(a > 128)
    pick = np.linspace(0, len(ys) - 1, 150).astype(int)
    best = (1e9, 0, 0)
    for oy in range(H - h + 1):
        for ox in range(W - w + 1):
            d = np.abs(src[ys[pick] + oy, xs[pick] + ox] - cc[ys[pick], xs[pick]]).mean()
            if d < best[0]:
                best = (d, oy, ox)
            if d < 1:
                break
        if best[0] < 1:
            break
    out = np.zeros((H, W))
    out[best[1]:best[1] + h, best[2]:best[2] + w] = a
    os.remove(t)
    return out


def run(n):
    jpg = n + '.jpg'
    a1 = full_mask(jpg, c1.cut)
    a2 = full_mask(jpg, lambda p, o: c2.cut(p, o))
    im = np.asarray(Image.open(jpg).convert('RGB')).astype(float)
    band = 20
    border = np.concatenate([im[:band].reshape(-1, 3), im[-band:].reshape(-1, 3),
                             im[:, :band].reshape(-1, 3), im[:, -band:].reshape(-1, 3)])
    bg = np.median(border, 0)
    dist = ndi.uniform_filter(np.sqrt(((im - bg) ** 2).sum(2)), 3)
    extra = (a2 > 128) & (dist > 40) & ~(a1 > 128)
    extra = ndi.binary_opening(extra, iterations=2)
    m = (a1 > 128) | extra
    m = ndi.binary_fill_holes(ndi.binary_closing(m, iterations=2))
    alpha = np.where(extra | ((a1 <= 128) & m), 255, a1)
    alpha = np.where(m, np.maximum(alpha, 0), 0)
    al = Image.fromarray(alpha.astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    rgba = Image.fromarray(im.astype(np.uint8)).convert('RGBA')
    rgba.putalpha(al)
    bb = rgba.getbbox()
    rgba.crop(bb).save(n + '_final.png')
    print(n, 'cut %.1f%% strict %.1f%% added %.1f%% final %.1f%%' % (
        100 * (a1 > 128).mean(), 100 * (a2 > 128).mean(), 100 * extra.mean(), 100 * m.mean()))


if __name__ == '__main__':
    for n in sys.argv[1:]:
        run(n)

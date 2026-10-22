# Remove a mid-grey cast shadow (not dark boots or hems) left under the feet: in the bottom 15% of
# the cut, drop low-colour pixels darker than the backdrop that connect to the
# bottom edge. Prints how many pixels went. Usage: trim_shadow.py name [name..]
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi


def trim(n, write=True):
    p = f'{n}S_final.png'
    im = Image.open(p).convert('RGBA')
    arr = np.asarray(im).astype(float)
    a = arr[..., 3]
    rgb = arr[..., :3]
    src = np.asarray(Image.open(f'{n}S.jpg').convert('RGB')).astype(float)
    bg = np.median(np.concatenate([src[:20].reshape(-1, 3), src[:, :20].reshape(-1, 3), src[:, -20:].reshape(-1, 3)]), 0)
    bl = bg.mean()
    h, w = a.shape
    lum = rgb.mean(2)
    sat = rgb.max(2) - rgb.min(2)
    y0 = int(h * 0.85)
    cand = np.zeros_like(a, bool)
    cand[y0:] = (a[y0:] > 0) & (sat[y0:] < 22) & (lum[y0:] < 0.92 * bl) & (lum[y0:] > 0.45 * bl) & (np.abs(rgb[y0:] - rgb[y0:].mean(2, keepdims=True)).max(2) < 14)
    lab, k = ndi.label(cand)
    if not k:
        print(n, 'no shadow')
        return 0
    # components touching the bottom rows of the mask or its lower outline
    outside = ndi.binary_dilation(a <= 10, iterations=2)
    keep = set()
    for i in range(1, k + 1):
        comp = lab == i
        if (comp & outside).any() and comp.sum() > 30:
            ys = np.where(comp)[0]
            if ys.max() >= h - 6:
                keep.add(i)
    rm = np.isin(lab, list(keep))
    rm = ndi.binary_dilation(rm, iterations=1) & (a > 0) & (sat < 26)
    n_rm = int(rm.sum())
    print(n, 'shadow px removed', n_rm, 'of', int((a > 128).sum()))
    if write and n_rm:
        arr[..., 3] = np.where(rm, 0, a)
        out = Image.fromarray(arr.astype(np.uint8), 'RGBA')
        out.crop(out.getbbox()).save(p)
    return n_rm


if __name__ == '__main__':
    write = '--dry' not in sys.argv
    for n in [x for x in sys.argv[1:] if x != '--dry']:
        trim(n, write)

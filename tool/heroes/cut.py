# Cut a miniature off its plain light backdrop: flood fill the backdrop (and its soft
# cast shadow) from the image border, keep the biggest solid piece, feather the edge.
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

def cut(path, out):
    im = np.asarray(Image.open(path).convert('RGB')).astype(float)
    h, w, _ = im.shape
    # Smooth backdrop model: per-row/col median of the border band, blended.
    band = 24
    border = np.concatenate([im[:band].reshape(-1, 3), im[-band:].reshape(-1, 3),
                             im[:, :band].reshape(-1, 3), im[:, -band:].reshape(-1, 3)])
    bg = np.median(border, 0)
    lum = im.mean(2)
    sat = im.max(2) - im.min(2)
    dist = np.sqrt(((im - bg) ** 2).sum(2))
    bglum = bg.mean()
    # Backdrop: close to the backdrop colour, or a grey shadow on it (low colour,
    # not too dark). The base and figure are darker or more colourful.
    # Smooth light areas count too, so a warm light spill on the backdrop goes.
    m = ndi.uniform_filter(lum, 7)
    sd = np.sqrt(np.maximum(ndi.uniform_filter(lum * lum, 7) - m * m, 0))
    cand = (dist < 34) | ((sat < 30) & (lum > 0.5 * bglum)) | ((sd < 4) & (lum > 150) & (sat < 50))
    lab, _ = ndi.label(cand)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgmask = np.isin(lab, list(edge))
    fg = ~bgmask
    fg = ndi.binary_opening(fg, iterations=2)
    lab2, n = ndi.label(fg)
    if n:
        sizes = ndi.sum(fg, lab2, range(1, n + 1))
        keep = 1 + int(np.argmax(sizes))
        big = sizes.max()
        fg = np.isin(lab2, [i + 1 for i, s in enumerate(sizes) if s > 0.02 * big])
    # Thin bridges to backdrop junk: erode, keep the main body, grow back.
    er = ndi.binary_erosion(fg, iterations=8)
    lab3, n3 = ndi.label(er)
    if n3 > 1:
        sizes = ndi.sum(er, lab3, range(1, n3 + 1))
        main = np.isin(lab3, [i + 1 for i, s in enumerate(sizes) if s > 0.05 * sizes.max()])
        fg = fg & ndi.binary_dilation(main, iterations=10)
    fg = ndi.binary_fill_holes(fg)
    a = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    rgba = Image.fromarray(im.astype(np.uint8)).convert('RGBA')
    rgba.putalpha(a)
    bb = rgba.getbbox()
    rgba = rgba.crop(bb)
    rgba.save(out)
    print(path, 'bg', bg.round(), 'bbox', bb, 'fg %.1f%%' % (100 * fg.mean()))

if __name__ == '__main__':
    for n in sys.argv[1:]:
        cut(n + '.jpg', n + '_cut.png')

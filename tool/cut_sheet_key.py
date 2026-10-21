#!/usr/bin/env python3
"""Blob-based sheet cutter for sheets whose flat background is not pure
magenta (the generator sometimes returns a muted mauve). Same idea as
cut_sheet_blobs.py, but the key colour is read from the sheet border and alpha
comes from colour distance to it; edges are shaved and feathered so no key
colour or drawn rim is left on them.
usage: cut_sheet_key.py sheet out_dir names...   ('-' skips a figure)
env: DIL (blob merge dilation, default 10), LO/HI (key distance ramp, default
28/70), ERODE (px shaved off the edge to drop the generator's thin dark rim,
default 2), HOLE (enclosed gaps smaller than this many px are filled, default 150)"""
import sys, os, numpy as np
from PIL import Image
from scipy import ndimage
src, out = sys.argv[1], sys.argv[2]; names = sys.argv[3:]
os.makedirs(out, exist_ok=True)
a = np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
H, W = a.shape[:2]
border = np.concatenate([a[:6].reshape(-1, 3), a[-6:].reshape(-1, 3),
                         a[:, :6].reshape(-1, 3), a[:, -6:].reshape(-1, 3)])
bg = np.median(border, axis=0)
print('key', bg.round())
LO, HI = float(os.environ.get('LO', 28)), float(os.environ.get('HI', 70))
ERODE = int(os.environ.get('ERODE', 2)); HOLE = int(os.environ.get('HOLE', 150))
dist = np.sqrt(((a - bg) ** 2).sum(-1))
alpha = np.clip((dist - LO) / (HI - LO), 0, 1)
fg = alpha > 0.5
fg = ndimage.binary_opening(fg, iterations=1)
d = ndimage.binary_dilation(fg, iterations=int(os.environ.get('DIL', '10')))
lab, n = ndimage.label(d)
objs = ndimage.find_objects(lab)
sizes = ndimage.sum(fg, lab, range(1, n + 1))
cand = [i for i, s in enumerate(objs)
        if not ((s[0].stop - s[0].start) > 0.6 * H or (s[1].stop - s[1].start) > 0.6 * W)]
big = max(sizes[i] for i in cand)
figs = [i for i in cand if sizes[i] >= 0.12 * big]
cy = {i: (objs[i][0].start + objs[i][0].stop) / 2 for i in figs}
cx = {i: (objs[i][1].start + objs[i][1].stop) / 2 for i in figs}
figs.sort(key=lambda i: cy[i])
rows = []; cur = []
for i in figs:
    if cur and cy[i] - np.mean([cy[j] for j in cur]) > 0.09 * H:
        rows.append(cur); cur = []
    cur.append(i)
rows.append(cur)
order = [i for r in rows for i in sorted(r, key=lambda j: cx[j])]
print('rows', [len(r) for r in rows], 'figs', len(order))
for name, i in zip(names, order):
    if name == '-': continue
    keep = (lab == i + 1) & fg
    # fill only small holes (speckle inside the figure); real gaps stay clear
    holes = ndimage.binary_fill_holes(keep) & ~keep
    hl, hn = ndimage.label(holes)
    if hn:
        hs = ndimage.sum(holes, hl, range(1, hn + 1))
        keep |= np.isin(hl, 1 + np.where(hs < HOLE)[0])
    if ERODE:  # shave the generator's thin dark rim
        keep = ndimage.binary_erosion(keep, iterations=ERODE)
    al = np.clip(ndimage.gaussian_filter(keep.astype(np.float32), 0.8) * 1.6 - 0.3, 0, 1)
    rgb = a.copy()
    rgba = np.dstack([np.clip(rgb, 0, 255), al * 255]).astype(np.uint8)
    ys, xs = np.where(al > 0.05)
    crop = Image.fromarray(rgba, 'RGBA').crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    side = 320 if name.startswith('b_') else (128 if name.startswith('i_') else 256)
    crop.thumbnail((side, side), Image.LANCZOS)
    # 1px clear margin so corners are transparent for the validator
    pad = Image.new('RGBA', (crop.width + 2, crop.height + 2), (0, 0, 0, 0))
    pad.paste(crop, (1, 1))
    if max(pad.size) > side:
        pad.thumbnail((side, side), Image.LANCZOS)
    pad.save(os.path.join(out, name + '.png')); print(name, pad.size)

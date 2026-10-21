#!/usr/bin/env python3
"""Cut a 2x2 magenta-keyed sprite sheet into transparent PNG sprites.

usage: cut_sheet.py <sheet|url> <out_dir> <cols>x<rows> names... (row-major)
Each name is like u_gull or e_drip or b_brine (or '-' to skip).
Size: u_/e_ 256 max side, b_ 320 max side.
"""
import sys, os, io, urllib.request
import numpy as np
from PIL import Image
from scipy import ndimage

src, out = sys.argv[1], sys.argv[2]
cols, rows = map(int, sys.argv[3].split('x'))
names = sys.argv[4:]
if src.startswith('http'):
    data = urllib.request.urlopen(src).read()
    im = Image.open(io.BytesIO(data)).convert('RGB')
else:
    im = Image.open(src).convert('RGB')
os.makedirs(out, exist_ok=True)
a = np.asarray(im).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
# magenta-ness: high R and B, low G
mag = np.minimum(r, b) - g
alpha = np.clip((140 - mag) / 60.0, 0, 1)  # mag>=140 -> 0, mag<=80 -> 1
fg = alpha > 0.5
lab, n = ndimage.label(fg)
H, W = fg.shape
sizes = ndimage.sum(fg, lab, range(1, n + 1))
coms = ndimage.center_of_mass(fg, lab, range(1, n + 1))
for qi, name in enumerate(names):
    if name == '-':
        continue
    qy, qx = divmod(qi, cols)
    keep = np.zeros_like(fg)
    mine = [i for i, (s, (cy, cx)) in enumerate(zip(sizes, coms))
            if s >= 150 and min(int(cy * rows / H), rows - 1) == qy and min(int(cx * cols / W), cols - 1) == qx]
    big = max((sizes[i] for i in mine), default=0)
    for i in mine:
        # drop caption letters and specks: keep only parts >= 4% of the main figure
        if sizes[i] >= 0.04 * big:
            keep |= lab == (i + 1)
    nk = len(np.unique(lab[keep])) - (0 in lab[keep])
    ky, kx = np.where(keep)
    if len(ky):
        cw, ch = W / cols, H / rows
        if kx.min() < qx * cw - 2 or kx.max() > (qx + 1) * cw + 2 or ky.min() < qy * ch - 2 or ky.max() > (qy + 1) * ch + 2:
            print('WARN crosses cell', name)
    keep = ndimage.binary_dilation(keep, iterations=3)
    al = alpha * keep
    # despill: pull magenta tint out of semi-transparent edge pixels
    rgb = a.copy()
    edge = (al > 0) & (al < 1)
    m = np.minimum(rgb[..., 0], rgb[..., 2])
    spill = np.clip(m - rgb[..., 1], 0, None) * edge
    rgb[..., 0] -= spill * 0.8
    rgb[..., 2] -= spill * 0.8
    rgba = np.dstack([np.clip(rgb, 0, 255), al * 255]).astype(np.uint8)
    ys, xs = np.where(al > 0.05)
    if len(ys) == 0:
        print('EMPTY', name); continue
    crop = Image.fromarray(rgba, 'RGBA').crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    side = 320 if name.startswith('b_') else 256
    crop.thumbnail((side, side), Image.LANCZOS)
    crop.save(os.path.join(out, name + '.png'))
    print(name, crop.size, 'parts', nk)

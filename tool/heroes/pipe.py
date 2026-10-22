#!/usr/bin/env python3
"""Hero sprite pipeline.

fetch: python3 pipe.py fetch <name> <image_id> <url>   (saves <name>S.jpg, cuts, prints metrics)
prep:  python3 pipe.py prep <name> [src_png]           (writes the game sprite u_<name>.png)
"""
import subprocess, sys, os
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

D = os.path.dirname(os.path.abspath(__file__))
SPR = '/home/sprite/voided-heroes/assets/sprites/'
sys.path.insert(0, D)
import cut as cutmod  # noqa
import metric  # noqa


def fetch(name, iid, url):
    jpg = os.path.join(D, name + 'S.jpg')
    subprocess.run(['curl', '-s', '-o', jpg, url], check=True)
    with open(os.path.join(D, 'ids.txt'), 'a') as f:
        f.write(f'{name}S {iid}\n')
    import merge_cut
    os.chdir(D)
    merge_cut.run(name + 'S')
    print(name, metric.m(os.path.join(D, name + 'S_final.png')))


def defringe(im):
    """Pull the edge in by a pixel and bleed interior colour into the soft
    edge, so no light or grey halo from the backdrop is left."""
    a = np.asarray(im.getchannel('A')).astype(float)
    rgb = np.asarray(im.convert('RGB')).astype(float)
    solid = a > 250
    # colour of the nearest solid pixel for every pixel
    idx = ndi.distance_transform_edt(~solid, return_distances=False, return_indices=True)
    near = rgb[idx[0], idx[1]]
    edge = (a > 0) & ~solid
    rgb[edge] = near[edge]
    am = Image.fromarray(a.astype(np.uint8)).filter(ImageFilter.MinFilter(3))
    am = am.filter(ImageFilter.GaussianBlur(0.7))
    out = Image.fromarray(rgb.clip(0, 255).astype(np.uint8)).convert('RGBA')
    out.putalpha(am)
    return out


def prep(name, src=None):
    src = src or os.path.join(D, name + 'S_final.png')
    im = Image.open(src).convert('RGBA')
    im = defringe(im)
    im = im.crop(im.getbbox())
    s = 248 / max(im.size)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    canvas = Image.new('RGBA', (im.width + 8, im.height + 8), (0, 0, 0, 0))
    canvas.alpha_composite(im, (4, 4))
    out = SPR + 'u_' + name + '.png'
    canvas.save(out, optimize=True)
    print('wrote', out, canvas.size)


if __name__ == '__main__':
    if sys.argv[1] == 'fetch':
        fetch(*sys.argv[2:5])
    else:
        prep(*sys.argv[2:])

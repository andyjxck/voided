#!/usr/bin/env python3
"""Build or check sprite_manifest.json (repo root).

build: python3 tool/sprite_manifest.py build <ids.json> [extra_ids.json]
check: python3 tool/sprite_manifest.py check <ids.json>

ids.json comes from `dart run tool/dump_ids.dart`. extra_ids.json holds ids from
the uncommitted content work in the main checkout; they go under
"pending_content" so the art is ready when that code lands.
"""
import json, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAN = os.path.join(ROOT, 'sprite_manifest.json')
PRE = {'units': 'u_', 'enemies': 'e_', 'bosses': 'b_'}
MAXSIDE = {'units': 256, 'enemies': 256, 'bosses': 320}


def path_for(kind, i):
    return f'assets/sprites/{PRE[kind]}{i}.png'


def build(ids, extra):
    man = {k: {i: path_for(k, i) for i in ids[k]} for k in PRE}
    if extra:
        man['pending_content'] = {
            k: {i: path_for(k, i) for i in extra.get(k, []) if i not in ids[k]} for k in PRE}
    json.dump(man, open(MAN, 'w'), indent=1, sort_keys=False)
    print('wrote', MAN)


def check(ids):
    man = json.load(open(MAN))
    bad = []
    n = 0
    sections = [(k, man[k]) for k in PRE]
    sections += [(k, man.get('pending_content', {}).get(k, {})) for k in PRE]
    for k in PRE:
        for i in ids[k]:
            if i not in man[k]:
                bad.append(f'missing from manifest: {k}/{i}')
    for k, sec in sections:
        for i, p in sec.items():
            n += 1
            fp = os.path.join(ROOT, p)
            if not os.path.exists(fp):
                bad.append(f'no file: {p}')
                continue
            im = Image.open(fp)
            if im.format != 'PNG' or im.mode != 'RGBA':
                bad.append(f'not RGBA PNG: {p}')
            if max(im.size) > MAXSIDE[k] or min(im.size) < 64:
                bad.append(f'bad size {im.size}: {p}')
            a = im.getchannel('A')
            if a.getextrema()[0] != 0:
                bad.append(f'no transparency: {p}')
            corners = [a.getpixel((0, 0)), a.getpixel((im.width - 1, 0)),
                       a.getpixel((0, im.height - 1)), a.getpixel((im.width - 1, im.height - 1))]
            if max(corners) > 200:
                bad.append(f'opaque corner (bad key?): {p}')
    print(f'checked {n} entries:', 'OK' if not bad else f'{len(bad)} problems')
    for b in bad:
        print(' ', b)
    return not bad


if __name__ == '__main__':
    cmd, f = sys.argv[1], sys.argv[2]
    ids = json.load(open(f))
    if cmd == 'build':
        build(ids, json.load(open(sys.argv[3])) if len(sys.argv) > 3 else None)
    else:
        sys.exit(0 if check(ids) else 1)

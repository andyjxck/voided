# Contact sheet: the approved test sheet on top, then every new hero sprite
# at large size with its board-size copy and name underneath.
import json, re, sys
from PIL import Image, ImageDraw, ImageFont

REPO = '/home/sprite/voided-heroes/'
TEST = '/home/sprite/voided_style_test2_sheet.jpg'


def names():
    out = {}
    for f in ('lib/game/data.dart', 'lib/game/content.dart'):
        s = open(REPO + f).read()
        for m in re.finditer(r"UnitDef\(\s*id: '(\w+)',\s*name: '((?:[^'\\]|\\.)*)',.*?tier: Tier\.(\w+)", s, re.S):
            out[m.group(1)] = (m.group(2).replace("\\'", "'"), m.group(3))
    return out


def font(sz):
    for p in ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',):
        try:
            return ImageFont.truetype(p, sz)
        except OSError:
            pass
    return ImageFont.load_default()


def main(ids, out):
    nm = names()
    cols = 6
    cw, ch = 300, 400
    rows = (len(ids) + cols - 1) // cols
    test = Image.open(TEST).convert('RGB')
    tw = cols * cw
    test = test.resize((tw, round(test.height * tw / test.width)))
    sheet = Image.new('RGB', (tw, test.height + 60 + rows * ch), (38, 40, 48))
    d = ImageDraw.Draw(sheet)
    d.text((16, 12), 'Approved style test (top)  /  new Riftwardens hero sprites (below, big and at board size)', fill=(230, 225, 210), font=font(22))
    sheet.paste(test, (0, 50))
    y0 = test.height + 60
    f1 = font(15)
    for k, i in enumerate(ids):
        x = (k % cols) * cw
        y = y0 + (k // cols) * ch
        # slate tile like the board
        d.rectangle((x + 6, y + 6, x + cw - 6, y + ch - 6), fill=(64, 68, 78))
        sp = Image.open(f'{REPO}assets/sprites/u_{i}.png').convert('RGBA')
        s = 250 / max(sp.size)
        big = sp.resize((round(sp.width * s), round(sp.height * s)), Image.LANCZOS)
        sheet.paste(big, (x + (cw - big.width) // 2 - 30, y + 12), big)
        s = 56 / max(sp.size)
        sm = sp.resize((round(sp.width * s), round(sp.height * s)), Image.LANCZOS)
        sheet.paste(sm, (x + cw - 70, y + 200), sm)
        n, t = nm.get(i, (i, ''))
        d.text((x + 14, y + 300), n, fill=(240, 236, 220), font=f1)
        d.text((x + 14, y + 326), f'{t}  ({i})', fill=(170, 175, 190), font=f1)
    sheet.save(out, quality=88)
    print('wrote', out, sheet.size)


if __name__ == '__main__':
    main(sys.argv[2].split(','), sys.argv[1])

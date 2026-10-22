# Contact sheet of all 44 Riftwardens heroes, grouped by union, from main.
import re, sys
from PIL import Image, ImageDraw, ImageFont

REPO = '/home/sprite/lucky-defense-game/'
OUT = sys.argv[1] if len(sys.argv) > 1 else '/home/sprite/voided_riftwardens_44_contact.jpg'
UNIONS = [('Birds', 'Skyborn'), ('Staff', 'Wardens'), ('Sweets', 'Alchemists'),
          ('Arcade', 'Rogues'), ('Sea', 'Tidecallers'), ('Lamp', 'Lightbringers'), ('ALL', 'Every union')]
TIERS = ['common', 'rare', 'epic', 'legendary', 'mythic']


def units():
    out = []
    for f in ('lib/game/data.dart', 'lib/game/content.dart'):
        s = open(REPO + f).read()
        for m in re.finditer(r"UnitDef\(\s*id: '(\w+)',\s*name: '((?:[^'\\]|\\.)*)',\s*tier: Tier\.(\w+),\s*tags: (\[[^\]]*\]|kAllUnions)", s):
            tags = ['ALL'] if m.group(4) == 'kAllUnions' else re.findall(r"'(\w+)'", m.group(4))
            out.append((m.group(1), m.group(2).replace("\\'", "'"), m.group(3), tags))
    return out


def font(sz):
    try:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', sz)
    except OSError:
        return ImageFont.load_default()


us = units()
CELL, COLS, PAD, HEAD = 200, 9, 16, 44
f_name, f_tier, f_head = font(13), font(11), font(24)
rows = []
seen = set()
for tag, disp in UNIONS:
    mem = [u for u in us if u[3] and u[3][0] == tag]
    mem.sort(key=lambda u: TIERS.index(u[2]) if u[2] in TIERS else 9)
    seen.update(u[0] for u in mem)
    rows.append((disp, mem))
rest = [u for u in us if u[0] not in seen]
if rest:
    rows.append(('Other', rest))
height = PAD
for _, mem in rows:
    height += HEAD + ((len(mem) + COLS - 1) // COLS) * (CELL + 40) + PAD
W = PAD * 2 + COLS * CELL
sheet = Image.new('RGB', (W, height), (38, 42, 70))
d = ImageDraw.Draw(sheet)
y = PAD
total = 0
for disp, mem in rows:
    d.text((PAD, y + 8), f'{disp} ({len(mem)})', font=f_head, fill=(255, 216, 107))
    y += HEAD
    for i, (uid, name, tier, tags) in enumerate(mem):
        x = PAD + (i % COLS) * CELL
        yy = y + (i // COLS) * (CELL + 40)
        d.rounded_rectangle((x + 4, yy + 4, x + CELL - 4, yy + CELL - 4), 10, fill=(58, 65, 112))
        im = Image.open(REPO + f'assets/sprites/u_{uid}.png').convert('RGBA')
        im.thumbnail((CELL - 24, CELL - 24), Image.LANCZOS)
        sheet.paste(im, (x + (CELL - im.width) // 2, yy + (CELL - im.height) // 2), im)
        short = name if len(name) <= 24 else name[:23] + '…'
        d.text((x + CELL // 2, yy + CELL + 4), short, font=f_name, fill=(240, 240, 250), anchor='ma')
        d.text((x + CELL // 2, yy + CELL + 21), tier.capitalize(), font=f_tier, fill=(170, 176, 210), anchor='ma')
        total += 1
    y += ((len(mem) + COLS - 1) // COLS) * (CELL + 40) + PAD
sheet.save(OUT, quality=90)
print('heroes', total, [(r[0], len(r[1])) for r in rows], OUT, sheet.size)

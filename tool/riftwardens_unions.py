#!/usr/bin/env python3
"""Riftwardens: union display names (tags in code and saves are unchanged).

Adds kUnionNames and unionName() to data.dart and rewrites the union rule
text and the few lines that name a union. Run after riftwardens_rename.py,
from the repo root.
"""
import pathlib

DATA_RULES_OLD = """const Map<String, String> kUnionRules = {
  'Birds': 'Birds attack 20% faster',
  'Staff': 'Staff hit 20% harder',
  'Sweets': 'Sweets slow 50% harder and longer',
  'Arcade': '+1 penny every 8 kills by Arcade',
  'Sea': 'Sea figurines get +0.6 range',
  'Lamp':
      'Lamp figurines show hidden things to everyone, and Lamp hits never miss',
};"""

DATA_RULES_NEW = """const Map<String, String> kUnionRules = {
  'Birds': 'Skyborn attack 20% faster',
  'Staff': 'Wardens hit 20% harder',
  'Sweets': 'Alchemists slow 50% harder and longer',
  'Arcade': '+1 penny every 8 kills by Rogues',
  'Sea': 'Tidecallers get +0.6 range',
  'Lamp':
      'Lightbringers show hidden things to everyone, and their hits never miss',
};

/// The name the player sees for each union tag. The tags themselves stay the
/// same in code and saves; only the display name changed (the Riftwardens).
const Map<String, String> kUnionNames = {
  'Birds': 'Skyborn',
  'Staff': 'Wardens',
  'Sweets': 'Alchemists',
  'Arcade': 'Rogues',
  'Sea': 'Tidecallers',
  'Lamp': 'Lightbringers',
};

/// Display name for union [tag].
String unionName(String tag) => kUnionNames[tag] ?? tag;"""

CONTENT_RULES = [
    ("'Birds': 'Birds attack 35% faster'", "'Birds': 'Skyborn attack 35% faster'"),
    ("'Staff': 'Staff hit 35% harder'", "'Staff': 'Wardens hit 35% harder'"),
    ("+1 penny every 5 kills by Arcade", "+1 penny every 5 kills by Rogues"),
    ("Sea figurines get +1 range and hit submerged things", "Tidecallers get +1 range and hit submerged things"),
    ("The whole lane is lit and Lamp figurines hit 20% harder", "The whole lane is lit and Lightbringers hit 20% harder"),
    ("Hidden until a Lamp, the beam", "Hidden until a Lightbringer, the beam"),
    ("Lamp figurines and chains cut through", "Lightbringers and chains cut through"),
    ("can only be hit by Lamp figurines or when lit", "can only be hit by Lightbringers or when lit"),
]


def sub(path, pairs):
    p = pathlib.Path(path)
    s = p.read_text()
    for a, b in pairs:
        assert a in s, (path, a)
        s = s.replace(a, b)
    p.write_text(s)


sub('lib/game/data.dart', [
    (DATA_RULES_OLD, DATA_RULES_NEW),
    ('// Tags (the "unions" on the pier).', '// Tags (the "unions" of the Riftwardens).'),
    ('inside its ring only area and Lamp hits land', 'inside its ring only area and Lightbringer hits land'),
])
sub('lib/game/content.dart', CONTENT_RULES)
sub('lib/ui/synergy_ui.dart', [
    ("items.add(('$t $n/", "items.add(('${unionName(t)} $n/"),
    ("text: '$t $n/3  ',", "text: '${unionName(t)} $n/3  ',"),
])
print('unions done')

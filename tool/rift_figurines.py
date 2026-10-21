#!/usr/bin/env python3
"""Rift stage 1b: figurine names, descs and quips, plus leftover pier/season text.

Ids, tags, stats and sprite files are untouched. Run from the repo root.
"""
import pathlib
import re

# id: (name, desc or None to keep, quip)
UNITS = {
    'gull': ('Riftgull', 'Fast pecks at one target, straight through the crack.',
             'Flew into the Rift once. Came back angrier. Chips. Now.'),
    'dave': ('Driftwood Dave', 'Swings a splintered deckchair. Small splash.',
             'Folding this since 1987. No crack in the sky is unfolding me.'),
    'rock': ('Rift Rock Kid', 'Sticky rock with a purple seam. Slows 20%.',
             'It says RIFT all the way through. Like me.'),
    'carl': ('Shard-Pusher Carl', 'Weak, but every kill pays 1 penny.',
             'Nearly. Nearly. It is right on the edge. NEARLY.'),
    'thwack': ('Mister Crack', 'Puppet with a split stick. 15% chance to stun.',
               'That is NOT how you close a Rift.'),
    'floss': ('Voidfloss Nan', 'Sticky violet splash. Slows 35%.',
              'You look thin. Have some floss, love. It is only a bit purple.'),
    'lou': ('Riftguard Lou', 'Whistle blast chains to 3 targets.',
            'NO. CLIMBING. OUT. OF. THE. RIFT.'),
    'admiral': ('Admiral Ashbeak', 'Birds within 2 cells attack 25% faster.',
                'Formation! FORMATION! Oh, they have flown into the crack.'),
    'claw': ('The Rift Claw', 'Every 4th grab drags a target back down the lane.',
             'It is rigged. The Rift is rigged too. I checked.'),
    'sal': ('Big Sal the Scorcher', 'Flings hot oil: splash plus a 3s burn.',
            'Salt and vinegar? Void and vinegar? You are getting both.'),
    'morag': ('Riftwife Morag', 'Curses 2 targets: they take 25% more damage, armour ignored.',
              'The Rift told me your name. It mispronounced it.'),
    'squall': ('The Rift Squall', 'Hits 4 targets at once.',
               'MINE MINE MINE MINE. The crack is MINE.'),
    'vex': ('Madame Fissure', '25% to crit for 3x. Kills pay 2 pennies.',
            'I foresee... a crack in everything. And a significant loss of pennies. Yours.'),
    'bertie': ('Broken Wheel Bertie', 'Every 2s hits everything in range.',
               'Round and round the Rift. Nobody ever gets off.'),
    'keeper': ('The Dark Lamp Keeper', 'Huge range beam. Double damage to bosses.',
               'I keep the light on the Rift. The light keeps nothing.'),
    'albatross': ('The Void Albatross', 'Hangs over 2 targets at once. They take 15% more damage.',
                  'I am not a bad omen. I am what came through after the bad omen.'),
    'tide': ('Old Mother Rift', 'Every 8s the Rift holds its breath: everything freezes 1.5s and takes 650.',
             'Everything falls back into me, dear. Everything.'),
    'jackpot': ('The Rift Jackpot', 'Hits harder the more pennies you hold. Every 10th pull: JACKPOT.',
                'Three cherries. Three cracks. THREE CHERRIES.'),
    'velvet': ('Velvet, the Last Act', 'Every figurine attacks 30% faster. Finishes non-bosses under 12%.',
               'Thirty-one years at the edge of the Rift, darling. I AM the edge.'),
    'gullivan': ('Saint Riftwing', 'Machine-gun pecks. +6% damage for every bird on your board.',
                 'Blessed are the chip-takers, for they shall fly through the crack.'),
    'lil': ('Riftwick Lil', 'A small lantern. Shows hidden things in range so everyone can hit them. Lamp hits never miss.',
            'I am not scared of the dark. The Rift is scared of me. Mostly.'),
    'bandsman': ('The Rift Bandsman', None,
                 'Oom-pah. OOM-PAH. Louder than the Rift.'),
    'mouse': ('Sugar Riftmouse', None,
              'Squeak. That means "you are stuck on this side now".'),
    'tess': ('Shatter Hammer Tess',
             'Every 5th hit shatters shields and shells outright, and slows. Hollow Hermits, Rift Clams and the Landlord hate her.',
             'Hard toffee. Harder hammer. The Rift is just a big crack.'),
    'lamplighter': ('The Riftlighter', "Lights the lane in range. Enemies there can\\'t dodge or hide and take 10% more damage.",
                    'Every lamp along the Rift, lit by hand. Every one.'),
    'hale': ('Riftmaster Hale', None,
             'Back. BACK. This is a Rift, not a holiday.'),
    'icecream': ('The Void Ice Cream Man', None,
                 'Greensleeves, played slightly wrong, from the far side of the crack, forever.'),
    'elmo': ('Saint Riftfire', None,
             'Sailors used to pray for me. Now they just point at the crack.'),
    'watchman': ('The Rift Watchman', None,
                 "Twelve o\\'clock, the Rift is open, and all is NOT well."),
    'diver': ('The Rift Diver', None,
              'Holding my breath since 1952. The Rift goes deeper than the sea.'),
    'confectioner': ('The Void Confectioner', None,
                     'Boiling point. Hard crack. Rift crack. Everybody stay still.'),
    'beacon': ('The Rift Beacon', None,
               'Lights on. Everyone. Look at me, not the crack.'),
    'freeholder': ('The Rift Freeholder', None,
                   'I own the Rift now. And you are all trespassing.'),
    'cannon': ("Cuttle\\'s Rift Cannon", None,
               'The Captain sends his regards. And his ink, by way of the Rift.'),
    'crown': ('The Cracked Crown', None,
              'Kneel. Sideways is fine. The crack goes sideways too.'),
    'lasttrain': ('The Last Train Through', 'Every 10s a phantom train comes out of the Rift, laps the lane and hits everything once, one carriage per active union.',
                  'All aboard. No, really, all of you. Next stop: the other side.'),
    'kshadow': ("The Lamp Keeper\\'s Shadow", None,
                'He kept the light on the Rift. I kept everything else.'),
    'nothing': ('The Nothing', None, '...'),
}

LIT = r"'((?:[^'\\]|\\.)*)'"


def patch_units(path: pathlib.Path) -> int:
    s = path.read_text()
    n = 0
    for uid, (name, desc, quip) in UNITS.items():
        m = re.search(r"id: '" + re.escape(uid) + r"',", s)
        if not m:
            continue
        start = m.start()
        nxt = s.find('UnitDef(', m.end())
        end = nxt if nxt != -1 else len(s)
        block = s[start:end]
        new = block
        new = re.sub(r"name:\s*" + LIT, lambda _: "name: '" + name + "'", new, count=1)
        if desc is not None:
            new = re.sub(r"desc:\s*" + LIT, lambda _: "desc:\n        '" + desc + "'", new, count=1)
        new = re.sub(r"quip:\s*" + LIT, lambda _: "quip: '" + quip + "'", new, count=1)
        if new != block:
            s = s[:start] + new + s[end:]
            n += 1
    path.write_text(s)
    return n


OTHER = [
    ('lib/ui/game_screen.dart', "Madame Vex\\'s cup decides.", "Madame Fissure\\'s cup decides."),
    ('lib/ui/game_screen.dart',
     "Last night of the season, the Rift tore open at the end of the pier, and things are climbing out of it.",
     "The Rift has torn the town in two, and things are climbing out of it."),
    ('lib/ui/game_screen.dart', "'OFF SEASON OVER'", "'THE RIFT SWALLOWED YOU'"),
    ('lib/game/meta.dart', "'Last Night of the Season',", "'First Night at the Rift',"),
    ('lib/game/meta.dart', "'Off Season',", "'Past the Edge',"),
    ('lib/game/data.dart', "'Grimley Borough Council',", "'Department of Rifts',"),
    ('lib/game/data.dart', "'The Rift tore open on the last night of the season. Something is climbing out.',",
     "'The Rift has just torn open. Something is climbing out.',"),
]


def main() -> None:
    total = 0
    for f in ('lib/game/data.dart', 'lib/game/content.dart'):
        total += patch_units(pathlib.Path(f))
    print('figurines patched:', total)
    for f, old, new in OTHER:
        p = pathlib.Path(f)
        s = p.read_text()
        if old not in s:
            print('NOT FOUND in', f, ':', old[:60])
            continue
        p.write_text(s.replace(old, new))


if __name__ == '__main__':
    main()

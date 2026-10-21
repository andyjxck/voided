#!/usr/bin/env python3
"""Rift stage 1: rename player-facing text to the Rift theme.

Only touches string literals' text (exact quoted names, and phrases that
cannot be identifiers because they contain spaces or punctuation). IDs,
sprite keys, save keys and the Dart package name are left alone.
Run from the repo root: python3 tool/rift_rename.py
"""
import pathlib
import re

# Exact quoted names: 'Old' -> 'New'
NAMES = {
    # levels
    'Grimley Pier': 'The Breach',
    'Fogbank Arcade': 'The Fogbound Arcade',
    'Crab Cove': 'Shattered Cove',
    'The Night Fair': 'The Rift Fair',
    'Lighthouse Point': 'The Dark Lamp',
    'The Void Pier': "The Rift\\'s Edge",
    # bosses
    'The Pier Inspector': 'The Rift Inspector',
    'What Was Under the Pier': 'What Came Through the Rift',
    'Mother Brine': 'Mother Brine',
    # enemies (ids unchanged, so their sprites still load)
    'Drip': 'Seep',
    'Pinchy': 'Riftpinch',
    'Slick Eel': 'Void Eel',
    'Wibble': 'Flicker',
    'Kelp Nanny': 'Rift Nanny',
    'Sea Mist': 'Rift Mist',
    'Lucky Pollock': 'Glintfish',
    'Big Drip': 'Big Seep',
    'Bailiff': 'Void Bailiff',
    'Chip Dart': 'Rift Dart',
    'Barnacle Bob': 'Rift Barnacle',
    'Tin Hermit': 'Hollow Hermit',
    'Puffer': 'Void Puffer',
    'Razor Clam': 'Rift Clam',
    'Bruiser Crab': 'Breach Crab',
    'Sand Castle': 'Ash Castle',
    'Carousel Pony': 'Hollow Pony',
    'Dodgem': 'Phantom Dodgem',
    'Lampmoth': 'Riftmoth',
    'Lantern Fish': 'Void Lantern',
    'The Fog Horn': 'The Rift Horn',
    'Clown': 'Cracked Clown',
    'Circus Lion': 'Rift Lion',
}

# Phrases inside text. Order matters (longer first).
PHRASES = [
    ('Calm Seas', 'Hairline'),
    ('Storm Warning', 'Full Breach'),
    ("'Choppy'", "'Widening'"),
    ('Spawns three Drips', 'Spawns three Seeps'),
    ('alone with Drips', 'alone with Seeps'),
    ('Sea things', 'Riftlings'),
    ('sea things', 'riftlings'),
    ('Sea thing', 'Riftling'),
    ('sea thing', 'riftling'),
    ('Sea glass', 'Rift glass'),
    ('sea glass', 'rift glass'),
    ('Voided. A seaside tower defence.', 'Voided. A tower defence at the Rift.'),
    ('Hold the pier till the season ends', 'Hold the line till the Rift closes'),
    ('runs the other half of the pier', 'holds the other side of the Rift'),
    ('from one season to the next', 'from one night to the next'),
    ('Welcome to Grimley Pier', 'Welcome to the Rift'),
    ("Last night of the season, and things are climbing out of the sea.",
     "Last night of the season, the Rift tore open at the end of the pier, and things are climbing out of it."),
    ('Last night of the season. Something is climbing out of the sea.',
     'The Rift tore open on the last night of the season. Something is climbing out.'),
    ('The fog has come in, and so has a pirate.', 'The Rift breathes fog, and a drowned pirate rode it in.'),
    ('Shells, claws and a crab who thinks he is royalty.',
     'The Rift split the cove. Shells, claws and a crab who thinks he is royalty.'),
    ('The end of the pier is not where it used to be.', 'The edge of the world is not where it used to be.'),
    ('Last night of the season. Should be quiet.', 'Only a hairline crack so far. Should be quiet.'),
    ('The council has closed the pier. You have not.', 'The Rift is wide open. You are still here.'),
    ('The pier. $boards', 'The Rift. $boards'),
    ('on the pier at', 'off the Rift at'),
    ("on the pier'", "loose'"),
    ('sea things on the pier', 'riftlings loose'),
    ('riftlings on the pier', 'riftlings loose'),
    ('Clear Level 4, the Void Pier.', 'Clear Level 4, the Rift Fair.'),
    ('Halfway Down the Pier', 'Halfway Into the Rift'),
    ('Tidy Pier', 'Tidy Rift'),
    ('The pier is overrun.', 'The Rift is overrun.'),
    ('on the boardwalk.', 'loose.'),
    ('outstayed the season.', 'held the Rift open.'),
    ('The pier collapses: limit now 80', 'The Rift widens: limit now 80'),
    ('Less pier. Same amount of you.', 'More Rift. Same amount of you.'),
    ('Go and play on the nice pier.', 'Go and play by the nice Rift.'),
    ('Lovely little pier. Shame about the rent.', 'Lovely little Rift. Shame about the rent.'),
    ('You can keep the pier. It is falling into the sea anyway.',
     'You can keep the Rift. It is falling into itself anyway.'),
    ('This pier be mine now.', 'This Rift be mine now.'),
    ('Abandon... pier...', 'Abandon... Rift...'),
    ('I have clung to this pier since before your grandmother.',
     'I have clung to this crack since before your grandmother.'),
    ('I have worked this pier for twenty years and I have never seen a crab that angry.',
     'I have worked this front for twenty years and I have never seen a crab come out of the Rift that angry.'),
    ('Thirty-one years at the end of the pier, darling. I AM the end.',
     'Thirty-one years at the edge of the Rift, darling. I AM the edge.'),
    ('Every lamp on this pier, lit by hand.', 'Every lamp along the Rift, lit by hand.'),
    ('I own the pier now.', 'I own the Rift now.'),
    ('a seaside tower defence. Hold the pier till the season ends.',
     'a tower defence at the Rift. Hold the line till the Rift closes.'),
]


def rename(text: str) -> str:
    for old, new in NAMES.items():
        text = text.replace(f"'{old}'", f"'{new}'")
    for old, new in PHRASES:
        text = text.replace(old, new)
    return text


def main() -> None:
    root = pathlib.Path('.')
    files = list(root.glob('lib/**/*.dart')) + [root / 'web/index.html', root / 'web/manifest.json']
    changed = 0
    for f in files:
        src = f.read_text()
        out_lines = []
        for line in src.split('\n'):
            if line.lstrip().startswith(('import ', 'export ', 'part ')):
                out_lines.append(line)
            else:
                out_lines.append(rename(line))
        out = '\n'.join(out_lines)
        if out != src:
            f.write_text(out)
            changed += 1
            print('changed', f)
    print(changed, 'files changed')


if __name__ == '__main__':
    main()

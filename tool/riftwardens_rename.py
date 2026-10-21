#!/usr/bin/env python3
"""Riftwardens: give all 44 figurines their hero names, descriptions and quips.

Only name, mono, desc and quip change. Ids, tiers, tags, stats and abilities
are left alone, so saves and sprite keys still line up.
Run from the repo root: python3 tool/riftwardens_rename.py
"""
import pathlib
import re

# id: (name, mono, desc, quip). Plain text; apostrophes are escaped for Dart.
HEROES = {
    # Skyborn (Birds)
    'gull': ('Wren, Sparrow Scout', 'Wr',
             'Rapid slingshot shots at one target.',
             'Scouted the Rift twice. Brought snacks both times.'),
    'admiral': ('Captain Talonne', 'Ta',
                'Her signal horn: Skyborn within 2 cells attack 25% faster.',
                'Wings level. Eyes on the crack. FLY.'),
    'squall': ('Zephra the Gale Dancer', 'Ze',
               'Throws four razor feathers: hits 4 targets at once.',
               'One fan for the wind. One fan for you.'),
    'albatross': ('Vael the Skywarden', 'Vl',
                  'Hovers over 2 targets at once. They take 15% more damage.',
                  'From up here every riftling looks small. Because they are.'),
    'gullivan': ('Solenne, Seraph of Quills', 'So',
                 'A stream of golden quills. +6% damage for every Skyborn on your board.',
                 'Every feather is a prayer. Every prayer is pointed.'),
    'murmuration': ('The Flockmother', 'Fm',
                    'Her cloak of Rift birds strikes five times at once. Every Skyborn on your board adds 6% to its damage.',
                    'Every bird in my cloak has a name. You only need one: sharp.'),
    # Wardens (Staff)
    'dave': ('Bramble the Squire', 'Br',
             'Swings an oversized wooden mace. Small splash.',
             'Squire today. Knight tomorrow. Mace forever.'),
    'lou': ('Rook Sparkhelm', 'Ro',
            'His halberd arcs lightning that chains to 3 targets.',
            'Helm on. Hair up. Everything up, actually.'),
    'bandsman': ('Tobb the Bannerman', 'To',
                 'Every 6s he plants his standard: cells next to him can\'t be silenced, condemned, locked or grabbed for 3s.',
                 'Where the banner stands, we stand.'),
    'sal': ('Brakka of the Emberforge', 'Bk',
            'Swings a molten hammer: splash plus a 3s burn.',
            'Forged in the Emberforge. Cooled on your face.'),
    'watchman': ('Sentinel Ysolde', 'Ys',
                 'Her eye-lance stops healing for 4s and marks the target to take 15% more damage.',
                 'I see you. I always see you.'),
    'velvet': ('Maestra Valenne', 'Mv',
               'Conducts the board: every figurine attacks 30% faster. Finishes non-bosses under 12%.',
               'And one, and two, and STRIKE.'),
    'crown': ('King Bastion the Unbroken', 'Kb',
              'Neighbouring cells can\'t be silenced, locked or condemned. His gauntlet strips 30% armour.',
              'Small king. Large armour. Larger grudge.'),
    'foreman': ('Commander Grael', 'Gr',
                'Wardens within 2.6 cells work 30% faster. His shield bash stuns 12% of the time.',
                'One eye is plenty. I have seen enough of you.'),
    # Alchemists (Sweets)
    'rock': ('Gil the Gumflask', 'Gi',
             'Lobs sticky violet slime flasks. Slows 20%.',
             'It is meant to be that colour. Probably.'),
    'floss': ('Bubbla the Brewwitch', 'Bu',
              'Blows sticky violet bubbles that splash. Slows 35%.',
              'Double, double, pop and bubble.'),
    'mouse': ('Nib the Glue Gremlin', 'Nb',
              'Glue launcher: for 2s the target can\'t blink, dive, ram or teleport.',
              'Stay. Stay! Good riftling.'),
    'tess': ('Otta Shardcleaver', 'Ot',
             'Her crystal maul: every 5th hit shatters shields and shells outright, and slows. Hollow Hermits, Rift Clams and the Landlord hate her.',
             'Gem skin. Gem maul. Your shell is the soft bit.'),
    'icecream': ('Nim the Frostbell Yeti', 'Ni',
                 'Every 6s his frost bell freezes a patch of lane solid for 1s.',
                 'Ding. That is the sound of you stopping.'),
    'confectioner': ('The Amber Archmage', 'Am',
                     'Every 10s floods the lane with amber resin: everything is stuck for 2s, sticky, and loses its shell.',
                     'Hold that pose. For a thousand years.'),
    'matchmaker': ('Lumi and Lark, the Twinbinders', 'LL',
                   'Their glowing thread makes bonds in the cells next to them count double. Fires two shards at a time.',
                   'You two. Hold hands. There. Stronger.'),
    # Rogues (Arcade)
    'carl': ('Kip Copperfinger', 'Kp',
             'Flicks coins. Weak, but every kill pays 1 penny.',
             'Finders keepers. Riftlings, losers weepers.'),
    'thwack': ('Thump the Brawler Imp', 'Tp',
               'Swings a knuckle-wrapped cudgel. 15% chance to stun.',
               'Thump. That is the name and the plan.'),
    'claw': ('Hesper Hookshot', 'He',
             'Every 4th grab hooks a target and yanks it back down the lane.',
             'Going somewhere? Not any more.'),
    'vex': ('Duchess Vanta, Card Sharp', 'Va',
            'Razor cards: 25% to crit for 3x. Kills pay 2 pennies.',
            'Pick a card. Any card. They all cut.'),
    'bertie': ('Gyro the Clockwork Knight', 'Gy',
               'Spins his blades: every 2s hits everything in range.',
               'Wind me up and stand well back.'),
    'jackpot': ('The Gilded Djinn', 'Dj',
                'Hits harder the more pennies you hold. Every 10th pull: JACKPOT.',
                'Three wishes? Three cherries. Same thing.'),
    'freeholder': ('Quillon the Portalmancer', 'Qu',
                   'Every 12s opens a portal that throws the three front non-boss enemies back to the start of the lane.',
                   'Back you go. Mind the step.'),
    'lasttrain': ('Orin the Stormrider', 'Or',
                  'Every 10s his lightning ram gallops a lap of the lane and hits everything once, one strike per active union.',
                  'Hold on to your horns!'),
    'tollkeeper': ('The Tribute Golem', 'Tg',
                   'Every 6s takes a penny for every 3 riftlings in range, up to 6. Hits harder the more you hold.',
                   'Tribute first. Then passage. Possibly.'),
    # Tidecallers (Sea)
    'morag': ('Nerys Coralhex', 'Ne',
              'Her coral staff curses 2 targets: they take 25% more damage, armour ignored.',
              'The tide told me your name. It was not impressed.'),
    'hale': ('Halvard the Conch Knight', 'Hv',
             'Every 4s his war conch pushes everything in range back 0.6 cells (bosses 0.2).',
             'One blast for back. Two blasts for further back.'),
    'keeper': ('Oshen the Tidecaller', 'Os',
               'Huge range tidal beam. Double damage to bosses.',
               'The sea is patient. I am the sea, briefly impatient.'),
    'diver': ('Kai the Abyss Hunter', 'Ka',
              'His harpoon hits diving, inked, tunnelled and submerged things. The Undertow, the Ghost Train\'s tunnel and Wrecker\'s Ghosts.',
              'The deep is dark. My harpoon is not scared of it.'),
    'tide': ('Thalassa, Heart of the Deep', 'Th',
             'Every 8s her whirlpool rises: everything freezes 1.5s and takes 650.',
             'All water returns to me, little ones. So will you.'),
    'cannon': ('Captain Inkwell', 'In',
               'Every 9s his brass hand cannon fires a heavy ink shot that splashes and blinds: no healing or dodging for 3s.',
               'Eight arms. One cannon. No patience.'),
    'pearl': ('Marisol, Pearl Valkyrie', 'Ms',
              'Her pearl trident finishes off any riftling under 12% health. Deals 30% more to bosses.',
              'Grit becomes a pearl. You become grit.'),
    # Lightbringers (Lamp)
    'lil': ('Wick the Lantern Sprite', 'Wk',
            'A tiny lantern spirit. Shows hidden things in range so everyone can hit them. Lightbringer hits never miss.',
            'Small flame. Big opinions about the dark.'),
    'lamplighter': ('Aldo the Torchbearer', 'Ao',
                    'His sunflame torch lights the lane in range. Enemies there can\'t dodge or hide and take 10% more damage.',
                    'Stay in the light. Or do not. It finds you anyway.'),
    'elmo': ('Saint Solara, Sunlance', 'Sl',
             'Her prism beam ignores dodging, hiding and Null, and burns 15% hotter for every second on the same target.',
             'Hold still. The sun is still warming up.'),
    'beacon': ('The Dawnkeeper', 'Dk',
               'Its sun-disc halo lights the whole lane so nothing can hide or dodge. Figurines in its light deal 20% more damage.',
               'Morning comes for everyone. Even down here.'),
    'kshadow': ('Umbra the Mirror Shade', 'Um',
                'Copies the attack of the strongest neighbouring non-Mythic at 150%.',
                'Whatever you can do, I can do darker.'),
    'choir': ('Cantor Solace', 'Cs',
              'Her floating flame bells ring a song that jumps between 5 riftlings and leaves each one burning for 3s.',
              'Sing up. The dark hates a harmony.'),
    # Every union
    'nothing': ('The Riftborn', None, None, None),
}

STR = r"(?:'(?:[^'\\]|\\.)*'\s*)+"


def main():
    done = set()
    for f in ['lib/game/data.dart', 'lib/game/content.dart']:
        p = pathlib.Path(f)
        s = p.read_text()

        def fix(m):
            uid = m.group(1)
            if uid not in HEROES:
                return m.group(0)
            name, mono, desc, quip = HEROES[uid]
            b = m.group(0)
            b = re.sub(r"name: " + STR + ",", lambda _: "name: '" + name.replace("'", "\\'") + "',", b, count=1)
            if mono:
                b = re.sub(r"mono: '[^']*',", lambda _: f"mono: '{mono}',", b, count=1)
            esc = lambda t: t.replace("'", "\\'")
            if desc:
                desc = esc(desc)
                b = re.sub(r"desc:\s*" + STR + ",", lambda _: "desc:\n        '" + desc + "',", b, count=1)
            if quip:
                quip = esc(quip)
                b = re.sub(r"quip:\s*" + STR + ",", lambda _: "quip: '" + quip + "',", b, count=1)
            done.add(uid)
            return b

        s = re.sub(r"UnitDef\(\s*id: '(\w+)',.*?\n  \),", fix, s, flags=re.S)
        p.write_text(s)
    missing = set(HEROES) - done
    print('renamed', len(done), 'missing', sorted(missing))


if __name__ == '__main__':
    main()

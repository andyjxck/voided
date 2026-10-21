# Voided: sprites the new content still needs

**Status, 21 October 2026: all 16 are drawn** and saved under assets/sprites with the names below. Source sheets: art_src/sheets_rift/m5.jpg (Mythics; its 3rd figure is an unused extra), e4.jpg (riftlings), b4.jpg (bosses), cut with tool/cut_sheet_key.py (ERODE=3 for e4, 2 for the others). sprite_manifest.json is rebuilt (tool/dump_ids.dart now lists all 18 bosses from kBossById) and `sprite_manifest.py check` passes for 108 entries.

The new Voided content needs 16 sprites that don't exist yet: 6 Mythic figurines, 6 riftlings and 4 bosses. Every item icon the code uses already exists.

Checked on 21 October 2026 against the working tree of /home/sprite/voided-combined (HEAD 1d780c2 plus the uncommitted content changes in content.dart, data.dart, mech.dart, rules.dart and sim.dart).

## How this was checked

The game builds its sprite list from the data, not from a fixed list (lib/ui/sprites.dart): `u_<id>` for every entry in `kUnits`, `e_<id>` for every entry in `kEnemies` and `b_<id>` for every entry in `kBossById`. The album and info cards (lib/ui/art.dart) and the level and boss screens (`SpriteImg('b_...')` in menus.dart and game_screen.dart) use the same names. The ids were read by loading the game data in a throwaway Flutter test, which was deleted afterwards, and compared with the 101 files in assets/sprites.

- Figurines: 44 in the code, 38 with sprites.
- Riftlings: 46 in the code, 40 with sprites. Wibble has no file of its own on purpose and borrows e_wobbler.
- Bosses: 18 in the code, 14 with sprites.
- Items: the code uses i_book, i_buoy, i_cup, i_dice, i_glass, i_leaf, i_penny, i_trophy and i_upgrade. All 9 exist.

Until these files exist, the board paints the old drawn shapes in their place, the album and info cards do the same, and the level screens show an empty square where a new boss should be. Nothing crashes.

## Style to match

Same as the 101 redrawn sprites (see /home/sprite/voided_new_sprites.jpg): chunky, toy-like 3D figures with soft lighting and shading and no flat outlines, on a transparent background (RGBA PNG), weathered seaside-meets-Rift look with purple Rift glow as the accent. Figurines and riftlings are at most 256 px on the longest side, bosses at most 320 px (the limits in tool/sprite_manifest.py). Mythics should read a step grander than ordinary figurines. All designs original, nothing borrowed from Lucky Defense.

## Mythic figurines (6)

| id | File | Name | Look |
|---|---|---|---|
| matchmaker | assets/sprites/u_matchmaker.png | The Matchmaker | A plump pink candyfloss cupid in a fairground waistcoat, holding two glowing heart-shaped shards tied together with a red ribbon. |
| tollkeeper | assets/sprites/u_tollkeeper.png | The Tollkeeper | A hunched gold-and-brass figure in a battered toll booth cap, with a rusted coin box on its belly and a striped barrier pole held like a staff. |
| murmuration | assets/sprites/u_murmuration.png | The Murmuration | A grey swirling storm of starlings and one gull, packed tight into a bird-shaped mass with a few beady eyes catching the light. |
| foreman | assets/sprites/u_foreman.png | The Night Foreman | A stocky brown-coated night foreman in a dented hard hat with a lamp, a heavy clipboard under one arm and a whistle on a chain. |
| pearl | assets/sprites/u_pearl.png | Mother of Pearl | A tall, serene figure rising out of an open oyster shell, skin pearly white with a shimmering sheen and a single huge pearl held up in both hands. |
| choir | assets/sprites/u_choir.png | The Ember Choir | Three small hooded singers in orange robes huddled together, open mouths glowing like embers, holding one old brass lamp between them. |

## Riftlings (6)

| id | File | Name | Look |
|---|---|---|---|
| leech | assets/sprites/e_leech.png | Hoard Leech | A fat tan leech, its body swollen and lumpy with swallowed coins showing through, and a round sucker mouth ringed with tiny teeth. |
| bulwark | assets/sprites/e_bulwark.png | Rift Bulwark | A squat slate-grey crab-like brute behind a driftwood-and-rivet shield, with a purple Rift-light barrier humming off its edge. |
| plated | assets/sprites/e_plated.png | Glass Grub | A pale aqua grub armoured in overlapping plates of sea glass, slightly translucent with a dim glow inside. |
| revenant | assets/sprites/e_revenant.png | Twice-Drowned | A sea-green drowned sailor, waterlogged and slumped, kelp in its hair, one old stitched wound and faint purple eyes that have opened twice. |
| drummer | assets/sprites/e_drummer.png | Rift Drummer | A small red imp with a dented marching-band drum strapped on, beating it with two bone sticks, sound-ring ripples around it. |
| burrower | assets/sprites/e_burrower.png | Rift Mole | A brown, heavy-clawed mole with mining goggles pushed up, half sunk into a mound of cracked planks and sand. |

## Bosses (4)

Each of these is the level guest (comes back on wave 20 and shares wave 40), so it also appears on that level's card.

| id | File | Name | Level | Look |
|---|---|---|---|---|
| auditor | assets/sprites/b_auditor.png | The Auditor, "Everything Is Deductible" | Shattered Cove | A tall charcoal-grey figure in a sodden pinstripe suit and bowler hat, holding a ledger and a long ink quill, coins slipping into his pockets. |
| severer | assets/sprites/b_severer.png | The Severer, "Snip, Snip" | The Rift Fair | A lanky deep-red tailor's dummy with giant rusty shears for hands, cut threads and ribbons trailing from its arms. |
| hollowchoir | assets/sprites/b_hollowchoir.png | The Hollow Choir, "All Together Now" | The Dark Lamp | A dark teal mass of hollow-eyed drowned singers fused into one hulking body, mouths open mid-note, water dripping off it. Should feel like the Twice-Drowned grown huge. |
| colossus | assets/sprites/b_colossus.png | The Glass Colossus, "Handle With Care" | The Rift's Edge | A towering pale-blue golem built from sea glass and cracked bottle panes, light glowing through it, small Glass Grubs flaking off its shoulders. |

## When the art is made

- Drop the PNGs into assets/sprites with exactly these names. pubspec.yaml already includes the whole folder, and the loader picks them up by id, so no code change is needed.
- sprite_manifest.json is out of date (it still lists 20 figurines, 18 riftlings and 7 bosses). Rebuild it with tool/sprite_manifest.py once the content code is committed.

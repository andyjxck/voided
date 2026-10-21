# Pier Pressure: design

Pier Pressure is a Lucky Defense-style merge tower defence set on a run-down seaside pier on the last night of the season. You summon random figurines onto a small board, merge three of a kind into something rarer, craft Mythics from recipes, and hold off 40 waves of sea things and four bosses, either alone (Solo) or beside an AI partner, Brenda (Co-op). This document describes the game as built after step 3 (October 2026), the numbers it runs on, what the balance sims measured, and what is still open.

All tunable numbers live in `lib/game/data.dart` (the run) and `lib/game/meta.dart` (progression between runs). The simulation (`lib/game/sim.dart`) is pure Dart with no Flutter, so the tests, the balance sims and the AI all drive the same code the screen does.

## Concept

- **Fantasy:** you and Brenda staff the pier's arcade on closing night. The sea has other plans. Your defenders are prize-counter figurines (a gull with a grudge, a fortune teller, the lighthouse keeper), each with a short quip.
- **Tone:** British seaside comedy, dry and a bit grim. The difficulty blurbs, boss titles and Brenda's lines carry it.
- **Reference:** the core loop follows Lucky Defense: random summons, merge three, a shared lane that loses you the game when it overfills, bosses on a timer, and a gamble currency.

## Modes

- **Co-op:** two boards, yours and Brenda's, around one shared lane loop. Sea things walk the loop past both boards. Brenda is an AI (see below) who summons, merges, gambles and upgrades on her own, chats now and then, and can receive figurines you give her.
- **Solo:** your board alone. Every enemy, mini-boss and boss has `kSoloHpMultiplier` (0.5) of its Co-op health. Bosses scale the same way (`kSoloBossExtra` is 1.0).
- **Endless:** after a win you can carry on past wave 40. Bosses beyond wave 40 gain 4% health per extra wave, and progression pays only for new waves.

## Core loop

1. A wave starts every 20 seconds and pays wages: 10 + 2 × wave pennies.
2. Enemies spawn (16 + wave ÷ 3 per wave) and walk the lane. Kills pay 2 + wave ÷ 8 pennies.
3. You spend pennies on summons (20, rising 1 per summon) and place figurines on an 18-spot board (6 × 3). A spot holds up to three of the same figurine.
4. Three of a kind on one spot merge into one random figurine of the next tier.
5. One of each recipe ingredient anywhere on the board crafts a Mythic.
6. You lose if 100 sea things are on the pier at once, or if a boss outlasts its 60-second timer. You win by beating the wave 40 boss.

Controls: tap or click a spot to select it, drag a figurine to another spot to move or swap, and use the panel (below the board on phones, at the side on desktop) to merge, sell, shake (reroll, 12 pennies), give to Brenda, gamble and upgrade. Keyboard: Space or S summons, M merges the selected spot, F toggles 2× speed, P or Escape pauses.

## Figurines

Twenty figurines across five tiers. Each has damage, attack interval and range, one union tag, and a special.

| Tier | Figurines |
|---|---|
| Common | Gull With A Grudge, Deckchair Dave, Rock Candy Kid, Coin-Pusher Carl |
| Rare | Mister Thwack, Candyfloss Nan, Lifeguard Lou, Admiral Tinbeak |
| Epic | The Claw, Big Sal the Fryer, Fogwife Morag, Squall of Gulls |
| Legendary | Madame Vex, Big Wheel Bertie, The Lighthouse Keeper, The Albatross |
| Mythic | Old Mother Tide, The Jackpot, Velvet the Headliner, Saint Gullivan |

Specials cover the usual roles: slows (Rock Candy Kid, Candyfloss Nan), stuns (Mister Thwack), chains and multi-hit (Lifeguard Lou, Squall of Gulls), splash and burn (Big Sal), curses that raise damage taken (Fogwife Morag, The Albatross), pull-backs (The Claw), economy (Coin-Pusher Carl and Madame Vex pay pennies per kill), boss damage (The Lighthouse Keeper) and auras (Admiral Tinbeak speeds up nearby birds).

**Unions.** Three different figurines of one union on your board switch on its rule:

- **Birds:** attack 20% faster.
- **Staff:** hit 20% harder.
- **Sweets:** slow 50% harder and longer.
- **Arcade:** +1 penny every 8 kills by Arcade figurines.
- **Sea:** +0.6 range.

**Mythic recipes** (one of each, anywhere on your board):

- **Old Mother Tide:** The Lighthouse Keeper, Fogwife Morag, Lifeguard Lou. Every 8 seconds the tide stops: everything freezes for 1.5 seconds and takes 650 damage.
- **The Jackpot:** Madame Vex, The Claw, Coin-Pusher Carl. Hits harder the more pennies you hold; every 10th pull is a jackpot.
- **Velvet, the Headliner:** Big Wheel Bertie, Big Sal the Fryer, Candyfloss Nan. Every figurine attacks 30% faster, and she finishes non-bosses under 12% health.
- **Saint Gullivan:** The Albatross, Squall of Gulls, Admiral Tinbeak. Machine-gun pecks, +6% damage per bird on your board.

## Summon odds and luck

- **Base odds:** Common 70%, Rare 24%, Epic 5%, Legendary 1%.
- **Lucky Penny:** an in-run upgrade, up to level 5, costing 60 + 40 × level pennies. Each level moves 4 points off Common: +2 Rare, +1.5 Epic, +0.5 Legendary.
- **Mercy:** a seventh Common in a row turns into a Rare.

## Economy

- **Pennies** buy summons, shakes and upgrades. You start with 100.
- **Tea leaves** fund gambles ("Read the Leaves"): 1 leaf for a 60% shot at a Rare, 1 leaf for 20% at an Epic, 2 leaves for 10% at a Legendary.
- **Selling:** a Common pays 8 pennies, a Rare 20; an Epic pays 1 leaf, a Legendary 3 leaves. Mythics can't be sold.
- **Elbow Grease (in run):** damage upgrades in three groups (Common & Rare, Epic, Legendary & Mythic), +12% damage a level up to level 15. A level costs 30 / 50 / 80 pennies plus 25 / 40 / 60 per level owned.
- **Lucky Pollock:** a rare fast fish. Kill it within one lap for a tea leaf and 15 pennies.

## Enemies and bosses

Ordinary health starts at 150 and grows 15% a wave to wave 15, 12% to wave 30 and 9% after. The pool widens as waves go on: Drip from the start, Slick Eel (fast) from wave 3, Pinchy (40% armour) from 6, Wobbler (splits into two Wibbles) from 8, Sea Mist (dodges 35%) from 12, Kelp Nanny (heals nearby enemies) from 14, with more Pinchies and Mists from 22. Every wave ending in 5 brings a Big Drip mini-boss with 8 × normal health.

Every tenth wave is a boss with a 60-second timer, cycling through four:

| Wave | Boss | Mechanic |
|---|---|---|
| 10 | Mother Brine, She Who Puddles | Spawns three Drips every 6 seconds |
| 20 | The Pier Inspector | Every 7 seconds condemns your strongest spot for 4 seconds; immune to stun and slow |
| 30 | The Undertow | Every 9 seconds dives for 2.5 seconds: can't be hit, heals 4%, then surges |
| 40 | The Landlord, Owner of Everything | Takes 15% of your pennies each lap; shields and calls Bailiffs at 66% and 33% |

## Difficulty

| Setting | Enemy health | Sea glass |
|---|---|---|
| Calm Seas | × 1.0 | × 1 |
| Choppy | × 1.45 | × 1.5 |
| Storm Warning | × 1.8 | × 2 |

Calm is open from the start. Winning a difficulty unlocks the next.

## Progression between runs

**Sea glass** is the meta currency: 1 per wave reached, 5 per boss beaten and 25 for a win, times the difficulty multiplier, plus job rewards. A run is paid once; carrying on into Endless pays only for the new waves.

**Back Room upgrades** (permanent):

| Upgrade | Effect per level | Levels | Cost |
|---|---|---|---|
| Float in the Till | +15 starting pennies | 5 | 20, +15 a level |
| Pressed Clover | +1 starting tea leaf | 3 | 40, +30 a level |
| Bent Coin | summons 1 penny cheaper | 5 | 30, +20 a level |
| Elbow Grease | +4% damage on your board | 5 | 35, +25 a level |

Everything together costs 1,235 sea glass, which we estimate at 10 to 14 runs.

**Jobs** (one-off, each pays sea glass once): Pest Control (beat a boss, 15), Halfway Down the Pier (wave 20, 20), Last Night of the Season (win, 50), Skeleton Staff (win Solo, 40), Brenda's Favourite (win Co-op, 40), Council Can Do One (win on Storm, 80), Something in the Back (craft a Mythic, 25), Three Into One (15 merges in a run, 15), Feeling Lucky (3 gamble wins in a run, 20), Seafood Platter (1,000 kills in a run, 25), Off Season (wave 50 in Endless, 40).

**Records:** the figurine album (every figurine you've placed), best wave per mode and difficulty, wins and runs. The save is JSON in local storage; a missing or broken save starts fresh.

## The AI teammate

Brenda (`lib/game/ai.dart`) takes a round of decisions every 0.9 seconds in the game, at skill 0.9, a bit slower than a keen player (the balance sims' default is every 0.6 seconds at full skill). Each round she:

1. crafts any Mythic she can,
2. merges, keeping recipe ingredients she might need,
3. spends tea leaves on gambles,
4. buys whichever of a summon or an upgrade adds more damage per penny, valuing a summon as its average figurine plus the merges it feeds.

In Co-op she chats every 38 to 68 seconds. A `skill` setting makes her slower and sloppier; the same bot plays your side in the balance sims.

## Accessibility

With a screen reader on (Flutter semantics, which the web build exposes as the browser's accessibility tree):

- **Top bar:** one readable line, for example "Wave 3 of 40. Next wave in 12 seconds. 23 of 100 sea things on the pier. 114 pennies, 0 tea leaves." It's built from whole seconds and counts, so it changes about once a second, not every frame.
- **Boss bar:** name, title, health rounded to 5%, shield, seconds left.
- **Board:** a summary of both boards (how full, what's on them, how many spots can merge). Each of your 18 spots is also a button ("Spot 4, row 1: 2 Lifeguard Lou, Rare. Ready to merge."): double-tap selects it, and a custom action swaps it with the selected spot. These buttons paint nothing, let pointer events through, and are only built while semantics are on.
- **Spoken updates:** wave starts, boss arrivals with their mechanic, 15 seconds left on a boss, boss defeated, the pier filling past 50, 75 and 90, the result of your own summons, merges, gambles, sells, gifts and upgrades, error messages, and the end of the run. At most one line every 2 seconds, at most 3 waiting (oldest dropped), quick summons replace each other, warnings re-arm only after the pier clears, and the end of the run always goes out at once.
- **Summon button:** "Summon a figurine, 23 pennies".

## Balance targets and measured results

The targets are written as tests in `test/balance_test.dart`; the AI plays your side, 16 games per setting, no Back Room upgrades unless stated.

**Targets:**

- Calm is winnable in both modes: at least 75% wins, median run reaches wave 40.
- Calm is still winnable for a slow, sloppy player: at least 60%.
- The final boss is a real fight even for a perfect player: it uses more than a third of its timer.
- Each difficulty is a real step up: Choppy at least 20 points below Calm, Storm at least 10 below Choppy and under 50%, Choppy above 20%.
- Solo at `kSoloHpMultiplier` plays closer to Co-op than Solo at 0.65 does.
- Back Room upgrades help on Storm but don't make it a walkover (under 95%).

**Measured win rates** (step 2, unchanged in step 3):

| Setting | Co-op | Solo |
|---|---|---|
| Calm | 100% | 88% |
| Calm, slow and sloppy AI | 81% | 75% |
| Choppy | 63% | 50% |
| Storm | 19% | 25% |
| Storm, every upgrade bought | 44% | 69% |

The perfect AI still needs 30 to 38 seconds of the final boss's 60. A typical losing Storm run ends around wave 30.

**Solo health.** The brief asked for 65%. Adding each mode's Calm and Choppy win rates: Co-op 1.63, Solo at 0.5 scored 1.38, Solo at 0.65 scored 0.88. Half is clearly closest to Co-op, so `kSoloHpMultiplier` is 0.5, and a test keeps it the better match.

## Layout targets

Every screen is tested at three sizes: 390 × 844 (phone), 360 × 640 (small phone) and 1280 × 800 (desktop), including 40 seconds of play in each mode and the tutorial. Any text overflowing its box fails the test. On phones the action panel sits below the board and gambles and upgrades open in sheets; on desktop they sit in a side panel. The start button stays pinned below scrolling lists on every size.

## Testing and tools

- **Tests (106):** core rules, progression and saves, balance, layout, screen-reader labels and announcements, and touch drag-to-swap at phone sizes. Run `flutter test`.
- **`tool/balance.dart`:** the balance sims behind the numbers above.
- **`tool/meta_smoke.dart`:** a quick end-to-end check of progression.
- **`tool/trace.dart`:** traces a single AI run: `dart run tool/trace.dart coop|solo [seed]`.

## Running it locally

- In a browser while developing: `flutter run -d chrome`.
- The release web build: `flutter build web`, then serve it, for example `python3 -m http.server 8080 -d build/web`, and open http://localhost:8080.

## Known gaps

- **Balance is AI-measured only.** No human has played a full run. Upgrade sizes, sea glass rates and job rewards are first guesses that passed the sims.
- **Calm may be easy** for an experienced player (the perfect AI wins every Co-op Calm run).
- **Screen readers:** checked in headless Chrome's accessibility tree and in widget tests, not with a real screen reader (VoiceOver, TalkBack, NVDA). The board is playable by spot buttons, but the Brenda chat is readable, not spoken, and enemies' positions aren't described beyond the lane count.
- **Browser playtests** were scripted in headless Chrome; how the game looks and feels still needs a person.
- **Font warning:** the web build warns about the missing Cupertino icon font. The game doesn't use those icons.
- **No remote:** the repository is local only.

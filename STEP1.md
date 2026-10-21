# Step 1: meta.dart and a clean analyze

Project: Pier Pressure (Flutter package `pier_pressure`), at /home/sprite/lucky-defense-game.

## Where it started

- Not a git repo yet (a `main` branch existed with no commits). Everything was untracked.
- `flutter analyze`: 29 issues, 17 of them errors, all from the missing `lib/game/meta.dart`
  (`MetaSave`, `RunSummary`, `kMissions`, `kMetaUpgrades` used by main.dart, ui/menus.dart and ui/game_screen.dart).
  The other 12 were infos.
- No `test/` folder exists, though comments in data.dart and balance.dart refer to `test/balance_test.dart` and DESIGN.md.

## What changed

- **New `lib/game/meta.dart`** (pure Dart, no Flutter):
  - `MetaSave`: sea glass, Back Room upgrade levels, finished jobs, album (discovered figurines), best wave per
    mode and difficulty, unlocked difficulty, runs, wins, tutorial flag, and the sound, music and shake settings.
  - `configFor(mode, difficulty, seed)` turns upgrades into the existing `GameConfig` bonuses
    (`bonusPennies`, `bonusLeaves`, `summonDiscount`, `dmgBonus`).
  - `finishRun(game)` pays sea glass (1 a wave, 5 a boss, 25 for a win, times 1, 1.5 or 2 by difficulty),
    unlocks the next difficulty on a win, records best wave, adds new figurines to the album and pays out jobs.
    Calling it again for the same game after Endless only pays the extra progress and counts the run once.
  - `kMetaUpgrades`: four upgrades (Float in the Till, Pressed Clover, Bent Coin, Elbow Grease).
  - `kMissions`: eleven jobs (first boss, wave 20, win, Solo win, Co-op win, Storm win, a Mythic, 15 merges,
    3 gamble wins, 1,000 kills, Endless wave 50).
  - `encode()` / `decode()`: JSON save in shared_preferences. A missing or corrupt save gives a fresh one,
    unknown ids are dropped, levels are clamped.
- **`lib/game/sim.dart`**: `PlayerSide.seen` records every figurine placed on the board, for the album.
- **Lint fixes**: `FontWeight.index` to `.value` (art.dart), `__` to `_` in two builders, package imports and
  an `avoid_print` ignore in the two tool scripts.
- **New `tool/meta_smoke.dart`**: a headless check of the meta layer.

## Results

- `flutter analyze`: No issues found.
- `flutter build web --release`: built (about 45 s). Not served or played in a browser.
- `dart run ./tool/meta_smoke.dart` (bot plays a full Calm run in each mode, seed 7):
  - Co-op: won at wave 40, 4 bosses, +270 sea glass, 7 jobs, unlocked Choppy, 20 figurines added.
  - Solo: won at wave 40, +150 sea glass, 2 jobs.
  - Re-finishing the same game pays 0 and keeps the run count right; save round-trips exactly; corrupt saves
    load fresh; buying upgrades and `configFor` work; `simulateRun` still runs.
- Existing tests: none, because there is no `test/` folder.

## For step 2 and step 3

- Tests have to be written from scratch, including the `test/balance_test.dart` that data.dart mentions.
- `kSoloHpMultiplier` is 0.5, not the brief's 0.65. Its comment says sims put Solo closest to Co-op at 0.5.
  Re-check this in step 2.
- The bot wins Calm in both modes at seed 7, so Calm may be easy for a good player. Worth a balance pass.
- Upgrade sizes, sea glass rates and job rewards are first guesses and haven't been tuned.
- DESIGN.md doesn't exist, though data.dart refers to it for the balance numbers.
- The web build reports a missing CupertinoIcons font. The game's code doesn't use CupertinoIcons, so it's harmless.

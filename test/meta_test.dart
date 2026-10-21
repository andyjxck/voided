// Meta progression: sea glass payouts, Back Room upgrades, jobs, album,
// difficulty unlocks, and the save file (including broken saves).

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/meta.dart';
import 'package:pier_pressure/game/sim.dart';

/// A finished game, without playing it: set the wave, bosses and result.
Game finished({
  GameMode mode = GameMode.coop,
  Difficulty difficulty = Difficulty.calm,
  int wave = 12,
  int bosses = 1,
  bool won = false,
}) {
  final g = Game(GameConfig(mode: mode, difficulty: difficulty));
  g.wave = wave;
  g.bossesKilled = bosses;
  g.status = won ? GameStatus.won : GameStatus.lost;
  return g;
}

void main() {
  group('payouts', () {
    test('a loss pays per wave and per boss, plus any jobs', () {
      final m = MetaSave();
      final r = m.finishRun(finished(wave: 12, bosses: 1));
      // 12 waves + 1 boss, plus Pest Control (first boss).
      expect(
        r.seaGlass,
        12 * kGlassPerWave + kGlassPerBoss + kMissionById['first_boss']!.reward,
      );
      expect(m.seaGlass, r.seaGlass);
      expect(m.runs, 1);
      expect(m.wins, 0);
    });

    test('harder difficulties pay more for the same run', () {
      int base(Difficulty d) {
        final m = MetaSave()..missions.addAll(kMissionById.keys);
        return m
            .finishRun(finished(difficulty: d, wave: 15, bosses: 1))
            .seaGlass;
      }

      expect(base(Difficulty.calm), 20);
      expect(base(Difficulty.choppy), 30);
      expect(base(Difficulty.storm), 40);
    });

    test(
      'a win pays the win bonus, counts a win and unlocks the next difficulty',
      () {
        final m = MetaSave();
        final r = m.finishRun(finished(wave: 40, bosses: 4, won: true));
        expect(m.wins, 1);
        expect(m.maxDifficulty, 1);
        expect(r.unlocks, contains('Unlocked: ${Difficulty.choppy.label}'));
        expect(
          r.newMissions.map((x) => x.id),
          containsAll(['first_boss', 'wave20', 'win', 'coop_win']),
        );
        expect(r.newMissions.map((x) => x.id), isNot(contains('solo_win')));
      },
    );

    test('winning Calm again does not unlock anything new', () {
      final m = MetaSave()..maxDifficulty = 2;
      final r = m.finishRun(finished(wave: 40, bosses: 4, won: true));
      expect(m.maxDifficulty, 2);
      expect(r.unlocks.where((u) => u.startsWith('Unlocked')), isEmpty);
    });

    test('paying out the same game twice pays nothing the second time', () {
      final m = MetaSave();
      final g = finished(wave: 40, bosses: 4, won: true);
      m.finishRun(g);
      final glass = m.seaGlass;
      final again = m.finishRun(g);
      expect(again.seaGlass, 0);
      expect(m.seaGlass, glass);
      expect(m.runs, 1);
      expect(m.wins, 1);
    });

    test('Endless after a win only pays the new progress', () {
      final m = MetaSave();
      final g = finished(wave: 40, bosses: 4, won: true);
      m.finishRun(g);
      final before = m.seaGlass;
      g
        ..status = GameStatus.lost
        ..endless = true
        ..wave = 45;
      final r = m.finishRun(g);
      expect(r.seaGlass, 5 * kGlassPerWave);
      expect(m.seaGlass, before + 5);
      expect(m.runs, 1);
      expect(m.wins, 1);
    });

    test('best wave is kept per mode and difficulty', () {
      final m = MetaSave();
      expect(m.finishRun(finished(wave: 12)).newBest, isTrue);
      expect(m.finishRun(finished(wave: 8)).newBest, isFalse);
      expect(
        m.finishRun(finished(wave: 8, mode: GameMode.solo)).newBest,
        isTrue,
      );
      expect(m.best, {'coop-calm': 12, 'solo-calm': 8});
    });

    test('figurines you placed go into the album once', () {
      final m = MetaSave();
      final g = finished();
      g.place(g.you, kUnitById['gull']!);
      g.place(g.you, kUnitById['dave']!);
      final r = m.finishRun(g);
      expect(m.discovered, {'gull', 'dave'});
      expect(r.unlocks, contains('2 new figurines in the album'));
      final g2 = finished();
      g2.place(g2.you, kUnitById['gull']!);
      expect(
        m.finishRun(g2).unlocks.where((u) => u.contains('album')),
        isEmpty,
      );
    });
  });

  group('Back Room upgrades', () {
    test('buying spends sea glass at a rising price and stops at max', () {
      final m = MetaSave()..seaGlass = 10000;
      final u = kMetaUpgradeById['float']!;
      var spent = 0;
      for (var l = 0; l < u.max; l++) {
        spent += u.cost(l);
        expect(m.buy(u), isTrue);
      }
      expect(m.level('float'), u.max);
      expect(m.seaGlass, 10000 - spent);
      expect(m.buy(u), isFalse);
    });

    test('cannot buy what you cannot afford', () {
      final m = MetaSave()..seaGlass = 5;
      expect(m.buy(kMetaUpgrades.first), isFalse);
      expect(m.seaGlass, 5);
    });

    test('upgrades feed into the game settings', () {
      final m = MetaSave();
      for (final u in kMetaUpgrades) {
        m.upgrades[u.id] = 2;
      }
      final c = m.configFor(GameMode.solo, Difficulty.choppy, 4);
      expect(c.mode, GameMode.solo);
      expect(c.difficulty, Difficulty.choppy);
      expect(c.bonusPennies, 2 * kFloatPerLevel);
      expect(c.bonusLeaves, 2 * kCloverPerLevel);
      expect(c.summonDiscount, 2 * kBentCoinPerLevel);
      expect(c.dmgBonus, closeTo(2 * kElbowGreasePerLevel, 1e-9));
      final g = Game(c);
      expect(g.you.pennies, kStartPennies + 2 * kFloatPerLevel);
    });

    test(
      'the whole Back Room takes a good number of runs, not one or fifty',
      () {
        final total = kMetaUpgrades.fold(
          0,
          (a, u) =>
              a +
              [for (var l = 0; l < u.max; l++) u.cost(l)]
                  .reduce((x, y) => x + y),
        );
        // A Choppy win pays (40 + 4*5 + 25) * 1.5 = 127 before jobs.
        final choppyWin =
            ((40 * kGlassPerWave + 4 * kGlassPerBoss + kGlassForWin) *
                    kDifficultyGlassMult[1])
                .round();
        expect(total / choppyWin, inInclusiveRange(6, 20));
      },
    );
  });

  group('jobs', () {
    test('there are eleven, with unique ids and positive rewards', () {
      expect(kMissions.length, 11);
      expect(kMissionById.length, 11);
      expect(kMissions.every((x) => x.reward > 0), isTrue);
    });

    test('a job pays once', () {
      final m = MetaSave();
      final first = m.finishRun(finished(wave: 12, bosses: 1));
      expect(first.newMissions.map((x) => x.id), contains('first_boss'));
      final second = m.finishRun(finished(wave: 12, bosses: 1));
      expect(second.newMissions, isEmpty);
      expect(second.seaGlass, 12 + kGlassPerBoss);
    });

    test('Solo and Storm wins have their own jobs', () {
      final m = MetaSave();
      final r = m.finishRun(
        finished(
          mode: GameMode.solo,
          difficulty: Difficulty.storm,
          wave: 40,
          bosses: 4,
          won: true,
        ),
      );
      expect(
        r.newMissions.map((x) => x.id),
        containsAll(['solo_win', 'storm_win']),
      );
      expect(
        m.maxDifficulty,
        0,
        reason: 'Storm is the top; nothing past it to unlock',
      );
    });

    test('in-run stat jobs read your side', () {
      final m = MetaSave();
      final g = finished(wave: 5, bosses: 0);
      g.you.stats
        ..merges = 15
        ..gambleWins = 3
        ..kills = 1000
        ..mythics = 1;
      final r = m.finishRun(g);
      expect(
        r.newMissions.map((x) => x.id),
        containsAll(['merges', 'gamble', 'kills', 'mythic']),
      );
    });
  });

  group('save and load', () {
    test('a full save round-trips exactly', () {
      final m = MetaSave()
        ..seaGlass = 321
        ..maxDifficulty = 2
        ..runs = 9
        ..wins = 3
        ..tutorialDone = true
        ..sound = false
        ..music = false
        ..shake = false;
      m.upgrades['grease'] = 4;
      m.missions.addAll(['win', 'mythic']);
      m.discovered.addAll(['gull', 'tide']);
      m.best['solo-storm'] = 33;
      final back = MetaSave.decode(m.encode());
      expect(back.encode(), m.encode());
      expect(back.level('grease'), 4);
      expect(back.tutorialDone, isTrue);
      expect(back.sound, isFalse);
    });

    for (final raw in <String?>[
      null,
      '',
      'not json',
      '[1,2,3]',
      '{"seaGlass": "lots"}',
      '{"upgrades": 7}',
      '{{{',
    ]) {
      test('a broken save ($raw) loads fresh without throwing', () {
        final m = MetaSave.decode(raw);
        expect(m.seaGlass, 0);
        expect(m.upgrades, isEmpty);
        expect(m.maxDifficulty, 0);
        expect(m.sound, isTrue);
      });
    }

    test('unknown ids are dropped and out-of-range values clamped', () {
      final m = MetaSave.decode(
        '{"seaGlass": -50, "upgrades": {"float": 99, "jetpack": 3}, "missions": ["win", "fly", 4],'
        ' "discovered": ["gull", "dragon"], "maxDifficulty": 12, "best": {"coop-calm": 20, "x": "y"}}',
      );
      expect(m.seaGlass, 0);
      expect(m.upgrades, {'float': kMetaUpgradeById['float']!.max});
      expect(m.missions, {'win'});
      expect(m.discovered, {'gull'});
      expect(m.maxDifficulty, Difficulty.values.length - 1);
      expect(m.best, {'coop-calm': 20});
    });
  });
}

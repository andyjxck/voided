// Meta progression: sea glass payouts, Back Room upgrades, jobs, album,
// levels, and the save file (including broken saves).

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
  int level = 1,
}) {
  final g = Game(GameConfig(mode: mode, difficulty: difficulty, level: level));
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
        12 * kGlassPerWave + kGlassPerBoss + kMissionById['boss1']!.reward,
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
      'a win pays the win bonus, counts a win and unlocks the next level',
      () {
        final m = MetaSave();
        final r = m.finishRun(finished(wave: kFinalWave, bosses: 5, won: true));
        expect(m.wins, 1);
        expect(m.levelReached, 2);
        expect(r.unlocks, contains('Level 2 unlocked: ${levelDef(2).name}'));
        expect(
          r.newMissions.map((x) => x.id),
          containsAll(['boss1', 'wave25', 'boss4', 'level1', 'coop_win']),
        );
        expect(r.newMissions.map((x) => x.id), isNot(contains('solo_win')));
      },
    );

    test('clearing an earlier level again does not unlock anything new', () {
      final m = MetaSave()..levelReached = 3;
      final r = m.finishRun(finished(wave: kFinalWave, bosses: 5, won: true));
      expect(m.levelReached, 3);
      expect(r.unlocks.where((u) => u.contains('unlocked')), isEmpty);
    });

    test('a loss keeps you on the same level', () {
      final m = MetaSave();
      m.finishRun(finished(wave: kFinalWave, bosses: 4));
      expect(m.levelReached, 1);
    });

    test('paying out the same game twice pays nothing the second time', () {
      final m = MetaSave();
      final g = finished(wave: kFinalWave, bosses: 5, won: true);
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
      final g = finished(wave: kFinalWave, bosses: 5, won: true);
      m.finishRun(g);
      final before = m.seaGlass;
      g
        ..status = GameStatus.lost
        ..endless = true
        ..wave = kFinalWave + 5;
      final r = m.finishRun(g);
      expect(r.seaGlass, 5 * kGlassPerWave);
      expect(m.seaGlass, before + 5);
      expect(m.runs, 1);
      expect(m.wins, 1);
    });

    test('best wave is kept per mode and level', () {
      final m = MetaSave();
      expect(m.finishRun(finished(wave: 12)).newBest, isTrue);
      expect(m.finishRun(finished(wave: 8)).newBest, isFalse);
      expect(
        m.finishRun(finished(wave: 8, mode: GameMode.solo)).newBest,
        isTrue,
      );
      expect(m.finishRun(finished(wave: 5, level: 2)).newBest, isTrue);
      expect(m.best, {'coop-L1': 12, 'solo-L1': 8, 'coop-L2': 5});
      expect(m.bestOnLevel(1), 12);
    });

    test('figurines you placed count toward their album pages', () {
      final m = MetaSave();
      final g = finished();
      g.place(g.you, kUnitById['gull']!);
      g.place(g.you, kUnitById['dave']!);
      m.finishRun(g);
      expect(m.discovered, {'gull', 'dave'});
      expect(m.copies, {'gull': 1, 'dave': 1});
      // Paying out the same game again adds nothing.
      m.finishRun(g);
      expect(m.copies, {'gull': 1, 'dave': 1});
    });

    test('a full album page pays once and says so', () {
      final m = MetaSave()..missions.addAll(kMissionById.keys);
      final d = kUnits.firstWhere((u) => u.tier == Tier.values.last);
      final g = finished(wave: 1, bosses: 0);
      for (var i = 0; i < albumNeed(d.tier); i++) {
        g.you.got[d.id] = (g.you.got[d.id] ?? 0) + 1;
      }
      final r = m.finishRun(g);
      expect(m.collected(d), isTrue);
      expect(r.unlocks, contains('Album page filled: ${d.name}'));
      expect(r.seaGlass, kGlassPerWave + albumReward(d.tier));
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
        // A Choppy level clear pays (50 + 5*5 + 25) * 1.5 = 150 before jobs.
        final choppyWin =
            ((kFinalWave * kGlassPerWave + 5 * kGlassPerBoss + kGlassForWin) *
                    kDifficultyGlassMult[1])
                .round();
        expect(total / choppyWin, inInclusiveRange(6, 20));
      },
    );
  });

  group('jobs', () {
    test('every job has a unique id and a positive reward', () {
      expect(kMissions.length, greaterThanOrEqualTo(11));
      expect(kMissionById.length, kMissions.length);
      expect(kMissions.every((x) => x.reward > 0), isTrue);
    });

    test('a job pays once', () {
      final m = MetaSave();
      final first = m.finishRun(finished(wave: 12, bosses: 1));
      expect(first.newMissions.map((x) => x.id), contains('boss1'));
      final second = m.finishRun(finished(wave: 12, bosses: 1));
      expect(second.newMissions, isEmpty);
      expect(second.seaGlass, 12 + kGlassPerBoss);
    });

    test('Solo clears and later levels have their own jobs', () {
      final m = MetaSave()..levelReached = 2;
      final r = m.finishRun(
        finished(
          mode: GameMode.solo,
          wave: kFinalWave,
          bosses: 5,
          won: true,
          level: 2,
        ),
      );
      expect(
        r.newMissions.map((x) => x.id),
        containsAll(['solo_win', 'level1', 'level2']),
      );
      expect(r.newMissions.map((x) => x.id), isNot(contains('level3')));
      expect(m.levelReached, 3);
    });

    test('in-run stat jobs read your side', () {
      final m = MetaSave();
      final g = finished(wave: 5, bosses: 0);
      g.you.stats
        ..merges = 40
        ..gambleWins = 6
        ..kills = 3000
        ..mythics = 1;
      final r = m.finishRun(g);
      expect(
        r.newMissions.map((x) => x.id),
        containsAll(['merges40', 'gamble6', 'kills3k', 'mythic']),
      );
    });
  });

  group('save and load', () {
    test('a full save round-trips exactly', () {
      final m = MetaSave()
        ..seaGlass = 321
        ..maxDifficulty = 2
        ..levelReached = 3
        ..runs = 9
        ..wins = 3
        ..tutorialDone = true
        ..sound = false
        ..music = false
        ..shake = false;
      m.upgrades['grease'] = 4;
      m.missions.addAll(['level1', 'mythic']);
      m.discovered.addAll(['gull', 'tide']);
      m.copies['gull'] = 14;
      m.best['solo-storm'] = 33;
      final back = MetaSave.decode(m.encode());
      expect(back.encode(), m.encode());
      expect(back.level('grease'), 4);
      expect(back.tutorialDone, isTrue);
      expect(back.sound, isFalse);
      expect(back.levelReached, 3);
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
        '{"seaGlass": -50, "upgrades": {"float": 99, "jetpack": 3}, "missions": ["level1", "fly", 4],'
        ' "discovered": ["gull", "dragon"], "maxDifficulty": 12, "levelReached": -4,'
        ' "best": {"coop-calm": 20, "x": "y"}}',
      );
      expect(m.seaGlass, 0);
      expect(m.upgrades, {'float': kMetaUpgradeById['float']!.max});
      expect(m.missions, {'level1'});
      expect(m.levelReached, 1);
      expect(m.discovered, {'gull'});
      expect(m.maxDifficulty, Difficulty.values.length - 1);
      expect(m.best, {'coop-calm': 20});
    });
  });
}

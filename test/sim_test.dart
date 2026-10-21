// Core rules: summon odds, merge-3, economy, wave scaling, Solo health and
// the four bosses.

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

import 'helpers.dart';

void main() {
  group('summon odds', () {
    test('base odds add up to 100 at every luck level', () {
      for (var l = 0; l <= kMaxLuck; l++) {
        expect(
          summonOdds(l).reduce((a, b) => a + b),
          closeTo(100, 1e-9),
          reason: 'luck $l',
        );
      }
      expect(summonOdds(0), [70, 24, 5, 1]);
    });

    test('luck moves odds away from Common and is clamped', () {
      expect(summonOdds(kMaxLuck)[0], lessThan(summonOdds(0)[0]));
      expect(summonOdds(kMaxLuck)[3], greaterThan(summonOdds(0)[3]));
      expect(summonOdds(99), summonOdds(kMaxLuck));
      expect(summonOdds(-3), summonOdds(0));
    });

    test('rolled tiers match the odds over many rolls', () {
      final g = Game(const GameConfig(seed: 11));
      const n = 40000;
      final counts = List.filled(4, 0);
      for (var i = 0; i < n; i++) {
        counts[g.rollTier(0).index]++;
      }
      for (var t = 0; t < 4; t++) {
        expect(
          100 * counts[t] / n,
          closeTo(kBaseOdds[t], 1.0),
          reason: Tier.values[t].label,
        );
      }
    });

    test(
      'the Machine\'s Mercy: never more than ${kMercyStreak - 1} Commons in a row',
      () {
        final g = Game(const GameConfig(seed: 5));
        final p = g.you;
        var streak = 0;
        var worst = 0;
        for (var i = 0; i < 400; i++) {
          p.pennies = 1000;
          for (final c in p.cells) {
            c.units.clear();
          }
          final r = g.summon(p);
          expect(r.ok, isTrue);
          streak = r.unit!.tier == Tier.common ? streak + 1 : 0;
          if (streak > worst) worst = streak;
        }
        expect(worst, lessThan(kMercyStreak));
      },
    );

    test('summon costs pennies, the price climbs, and Bent Coin discounts only you', () {
      final g = Game(const GameConfig(seed: 1, summonDiscount: 3));
      final p = g.you;
      expect(g.summonCost(p), kSummonBaseCost - 3);
      expect(g.summonCost(g.partner!), kSummonBaseCost);
      final before = p.pennies;
      expect(g.summon(p).ok, isTrue);
      expect(p.pennies, before - (kSummonBaseCost - 3));
      expect(g.summonCost(p), kSummonBaseCost - 3 + kSummonStep);
    });

    test('summon refuses when broke or when the board is full', () {
      final g = Game(const GameConfig(seed: 1));
      final p = g.you;
      p.pennies = 0;
      expect(g.summon(p).ok, isFalse);
      p.pennies = 10000;
      for (var i = 0; i < p.cells.length; i++) {
        p.cells[i].units
          ..clear()
          ..add(UnitInst(kUnits[i % kUnits.length], 1000 + i, 0));
      }
      final r = g.summon(p);
      expect(r.ok, isFalse);
      expect(r.msg, contains('No room'));
    });
  });

  group('merge-3', () {
    test('three of a kind become one figurine of the next tier', () {
      final g = Game(const GameConfig(seed: 2));
      final p = g.you;
      final cell = stack(g, p, 'gull', 3);
      expect(p.cells[cell].units.length, 3);
      expect(g.canMerge(p, cell), isTrue);
      final r = g.merge(p, cell);
      expect(r.ok, isTrue);
      expect(r.unit!.tier, Tier.rare);
      expect(p.unitCount, 1);
      expect(p.stats.merges, 1);
    });

    test('two is not enough, and Legendaries do not merge', () {
      final g = Game(const GameConfig(seed: 2));
      final p = g.you;
      final two = stack(g, p, 'gull', 2);
      expect(g.canMerge(p, two), isFalse);
      expect(g.merge(p, two).ok, isFalse);
      final leg = unitsOfTier(Tier.legendary).first.id;
      final c = stack(g, p, leg, 3);
      expect(g.canMerge(p, c), isFalse);
    });

    test(
      'placing joins a matching stack before using an empty cell, up to $kStackMax',
      () {
        final g = Game(const GameConfig(seed: 2));
        final p = g.you;
        final a = g.place(p, kUnitById['dave']!);
        final b = g.place(p, kUnitById['dave']!);
        expect(b, a);
        g.place(p, kUnitById['dave']!);
        final d = g.place(p, kUnitById['dave']!);
        expect(d, isNot(a));
      },
    );

    test('a Mythic recipe uses one of each ingredient', () {
      final g = Game(const GameConfig(seed: 2));
      final p = g.you;
      for (final id in kRecipes['tide']!) {
        g.place(p, kUnitById[id]!);
      }
      expect(g.canCraft(p, 'tide'), isTrue);
      final r = g.craft(p, 'tide');
      expect(r.unit!.tier, Tier.mythic);
      expect(p.unitCount, 1);
      expect(p.sideDpsOf(g), greaterThan(0));
    });
  });

  group('economy', () {
    test('starting purse, Float and Clover bonuses go to you only', () {
      final g = Game(const GameConfig(bonusPennies: 30, bonusLeaves: 2));
      expect(g.you.pennies, kStartPennies + 30);
      expect(g.you.leaves, 2);
      expect(g.partner!.pennies, kStartPennies);
      expect(g.partner!.leaves, 0);
    });

    test(
      'each wave pays wages to both sides, plus a tea leaf every fifth wave',
      () {
        final g = Game(const GameConfig());
        final p0 = g.you.pennies;
        for (var w = 1; w <= 5; w++) {
          g.startNextWave();
        }
        final wages = [for (var w = 1; w <= 5; w++) waveWages(w)]
            .reduce((a, b) => a + b);
        expect(g.you.pennies, p0 + wages);
        expect(g.partner!.pennies, kStartPennies + wages);
        expect(g.you.leaves, 1);
      },
    );

    test('kill rewards and wages grow with the wave', () {
      expect(killReward(1), 2);
      expect(killReward(40), greaterThan(killReward(1)));
      expect(waveWages(40), greaterThan(waveWages(1)));
    });

    test('selling pays back, Mythics are not for sale', () {
      final g = Game(const GameConfig());
      final p = g.you;
      final c = g.place(p, kUnitById['gull']!);
      final before = p.pennies;
      expect(g.sell(p, c).ok, isTrue);
      expect(p.pennies, before + sellPennies(Tier.common));
      final m = g.place(p, kUnitById['tide']!);
      expect(g.sell(p, m).ok, isFalse);
    });

    test(
      'in-run upgrades cost pennies and add ${(kUpgradeStep * 100).round()}% damage a level',
      () {
        final g = Game(const GameConfig());
        final p = g.you;
        p.pennies = 1000;
        final d = kUnitById['gull']!;
        expect(g.dmgMult(p, d), 1);
        expect(g.upgrade(p, 0).ok, isTrue);
        expect(p.pennies, 1000 - upgradeCost(0, 0));
        expect(g.dmgMult(p, d), closeTo(1 + kUpgradeStep, 1e-9));
        p.pennies = 0;
        expect(g.upgrade(p, 0).ok, isFalse);
      },
    );

    test('Elbow Grease multiplies your damage, not Brenda\'s', () {
      final g = Game(const GameConfig(dmgBonus: 0.2));
      final d = kUnitById['gull']!;
      expect(g.dmgMult(g.you, d), closeTo(1.2, 1e-9));
      expect(g.dmgMult(g.partner!, d), 1);
    });

    test('gambling spends leaves and wins about as often as it says', () {
      final g = Game(const GameConfig(seed: 9));
      final p = g.you;
      var wins = 0;
      const n = 3000;
      for (var i = 0; i < n; i++) {
        p.leaves = 1;
        for (final c in p.cells) {
          c.units.clear();
        }
        if (g.gamble(p, kGambles[0]).ok) wins++;
        expect(p.leaves, 0);
      }
      expect(wins / n, closeTo(kGambles[0].chance, 0.03));
      expect(g.gamble(p, kGambles[0]).ok, isFalse);
    });
  });

  group('wave scaling', () {
    test('enemy health climbs every wave, steeply early and gently late', () {
      for (var w = 2; w <= 60; w++) {
        expect(baseHp(w), greaterThan(baseHp(w - 1)));
      }
      expect(baseHp(10) / baseHp(9), closeTo(1.15, 1e-9));
      expect(baseHp(25) / baseHp(24), closeTo(1.12, 1e-9));
      expect(baseHp(35) / baseHp(34), closeTo(1.07, 1e-9));
    });

    test('more enemies and more kinds of enemy as waves go on', () {
      expect(spawnCount(30), greaterThan(spawnCount(1)));
      expect(enemyPool(1).toSet(), {'drip'});
      expect(
        enemyPool(14).toSet(),
        containsAll(['eel', 'pinchy', 'wobbler', 'mist', 'nanny']),
      );
    });

    test('bosses every 10 waves, Big Drip on the fives, in boss order', () {
      expect(kFinalWave, 50);
      expect(
        [
          for (var w = 1; w <= kFinalWave; w++)
            if (isBossWave(w)) w,
        ],
        [10, 20, 30, 40, 50],
      );
      expect(
        [
          for (var w = 1; w <= kFinalWave; w++)
            if (isMiniBossWave(w)) w,
        ],
        [5, 15, 25, 35, 45],
      );
      expect(
        [
          for (final w in [10, 20, 30, 40, 50]) bossForWave(w).id,
        ],
        ['brine', 'inspector', 'brine', 'brine', 'landlord'],
      );
      // Level 1's wave 40 is a double bill: the warden and the guest.
      expect(
        [for (final b in bossesForWave(40)) b.id],
        ['brine', 'inspector'],
      );
    });

    test('every level has its own final boss on wave $kFinalWave', () {
      final finals = [
        for (var l = 1; l <= kLevels.length; l++) bossForWave(kFinalWave, l).id,
      ];
      expect(finals, [
        'landlord',
        'cuttle',
        'kingcrab',
        'ghosttrain',
        'shadowkeeper',
        'void',
      ]);
      expect(finals.toSet().length, kLevels.length);
      for (var l = 1; l <= kLevels.length * 2; l++) {
        expect(bossForWave(kFinalWave, l).id, levelDef(l).finalBoss);
        for (final w in [10, 20, 30, 40]) {
          // The final boss never turns up early on its own level.
          expect(bossForWave(w, l).id, isNot(levelDef(l).finalBoss));
        }
      }
      // Laps after the sixth level come round tougher.
      expect(levelDef(7).hpMult, greaterThan(levelDef(6).hpMult));
      expect(levelDef(7).finalBoss, levelDef(1).finalBoss);
    });

    test('a level run spawns that level\'s final boss and enemies', () {
      final g = Game(const GameConfig(level: 6, seed: 3));
      g.wave = kFinalWave - 1;
      g.startNextWave();
      expect(g.boss?.boss?.id, 'void');
      expect(enemyPool(10, 6), contains('voidling'));
      expect(enemyPool(10, 1), isNot(contains('voidling')));
    });

    test(
      'a normal wave queues its enemies and a timer; difficulty adds health',
      () {
        final calm = Game(const GameConfig(difficulty: Difficulty.calm));
        final storm = Game(const GameConfig(difficulty: Difficulty.storm));
        calm.startNextWave();
        expect(calm.waveTimer, kWaveSeconds);
        expect(
          storm.enemyHp('drip', 7) / calm.enemyHp('drip', 7),
          closeTo(Difficulty.storm.hpMult, 1e-9),
        );
        expect(
          Difficulty.calm.hpMult < Difficulty.choppy.hpMult &&
              Difficulty.choppy.hpMult < Difficulty.storm.hpMult,
          isTrue,
        );
      },
    );

    test('the pier is overrun at $kLaneLimit enemies', () {
      final g = Game(const GameConfig());
      for (var i = 0; i < kLaneLimit; i++) {
        g.enemies.add(Enemy(i, kEnemyById['drip'], null, 1e9, 0, 0, 0, 0));
      }
      advance(g, 0.1);
      expect(g.status, GameStatus.lost);
      expect(g.endReason, contains('overrun'));
    });
  });

  group('Solo health scaling', () {
    test('Solo is one constant inside the range the brief allows', () {
      expect(kSoloHpMultiplier, inInclusiveRange(0.5, 0.65));
    });

    test(
      'every enemy, mini-boss, boss and Bailiff in Solo takes the Solo factor',
      () {
        for (final d in Difficulty.values) {
          final co = Game(GameConfig(mode: GameMode.coop, difficulty: d));
          final so = Game(GameConfig(mode: GameMode.solo, difficulty: d));
          for (final e in kEnemies) {
            expect(
              so.enemyHp(e.id, 12) / co.enemyHp(e.id, 12),
              closeTo(kSoloHpMultiplier, 1e-9),
              reason: e.id,
            );
          }
          for (final w in [10, 20, 30, 40]) {
            expect(
              so.bossHp(w) / co.bossHp(w),
              closeTo(kSoloHpMultiplier * kSoloBossExtra, 1e-9),
            );
          }
        }
      },
    );

    test('Solo has one side and no Brenda; Co-op has two', () {
      expect(Game(const GameConfig(mode: GameMode.solo)).partner, isNull);
      expect(Game(const GameConfig(mode: GameMode.coop)).sides.length, 2);
    });
  });

  group('the Hatch', () {
    for (final mode in GameMode.values) {
      test('${mode.name}: things climb out in twins, one left, one right', () {
        final g = Game(GameConfig(mode: mode, seed: 5));
        g.wave = 2;
        g.startNextWave();
        advance(g, 0.05);
        final out = g.enemies.where((e) => !e.dead).toList();
        expect(out.length, 2);
        expect(out[0].def!.id, out[1].def!.id);
        expect(out.map((e) => e.route).toSet(), {0, 1});
        // Both start at the Hatch...
        final h = g.field.hatch;
        for (final e in out) {
          expect(g.field.posAt(0, e.route).dist(h), lessThan(0.3));
        }
        // ...and the left one heads left, the right one heads right.
        final l = g.field.posAt(1, 0), r = g.field.posAt(1, 1);
        expect(l.x, lessThan(h.x));
        expect(r.x, greaterThan(h.x));
      });
    }

    test('co-op: the Hatch is dead centre and each route rounds one board', () {
      final f = Field(GameMode.coop);
      expect(f.hatch.x, closeTo(f.w / 2, 1e-9));
      expect(f.hatch.y, closeTo(f.h / 2, 1e-9));
      expect(f.sideOfRoute(0), 1);
      expect(f.sideOfRoute(1), 0);
      // The two routes are the same length, so neither side gets the short one.
      var len1 = 0.0;
      final pts = f.routes[1];
      for (var i = 0; i < pts.length; i++) {
        len1 += pts[i].dist(pts[(i + 1) % pts.length]);
      }
      expect(len1, closeTo(f.lap, 1e-9));
      // Route 0 stays in the top half, route 1 in the bottom half.
      for (var i = 0; i < 40; i++) {
        expect(f.posAt(f.lap * i / 40, 0).y, lessThanOrEqualTo(f.h / 2));
        expect(f.posAt(f.lap * i / 40, 1).y, greaterThanOrEqualTo(f.h / 2));
      }
    });
  });

  group('bosses', () {
    test(
      'a boss wave spawns the boss with the right health and a ${kBossSeconds.round()}s timer',
      () {
        final g = gameAtBoss(10);
        expect(g.boss, isNotNull);
        expect(g.boss!.boss!.id, 'brine');
        // Twins: one heads left, one heads right, half the health each.
        g.update(0.02);
        expect(g.bossList.length, 2);
        expect(g.bossList.map((b) => b.route).toSet(), {0, 1});
        expect(g.bossList.where((b) => b.twinLead).length, 1);
        for (final b in g.bossList) {
          expect(b.maxHp, closeTo(baseHp(10) * 7 * kBossHpScale * 0.5, 1e-6));
        }
        expect(g.bossHpMax, closeTo(baseHp(10) * 7 * kBossHpScale, 1e-6));
        expect(g.bossTimer, kBossSeconds);
      },
    );

    test('the boss timer running out loses the run', () {
      final g = gameAtBoss(10);
      advance(g, kBossSeconds + 1);
      expect(g.status, GameStatus.lost);
      expect(g.endReason, contains('timer'));
    });

    test('Mother Brine spawns three Drips every 6 seconds', () {
      final g = gameAtBoss(10);
      advance(g, 4.2);
      expect(g.enemies.where((e) => e.def?.id == 'drip').length, 3);
      advance(g, 6);
      expect(g.enemies.where((e) => e.def?.id == 'drip').length, 6);
    });

    test(
      'the Inspector condemns your strongest cell and ignores slow and stun',
      () {
        final g = gameAtBoss(20);
        final weak = stack(g, g.you, 'gull', 1);
        final strong = stack(g, g.you, 'sal', 2);
        g.boss!
          ..stunT = 5
          ..slowPct = 0.5;
        advance(g, 0.1);
        expect(g.boss!.stunT, 0);
        expect(g.boss!.slowPct, 0);
        advance(g, 4.2);
        expect(g.you.cells[strong].disabled, greaterThan(0));
        expect(g.you.cells[weak].disabled, 0);
        advance(g, 4.5);
        expect(g.you.cells[strong].disabled, lessThanOrEqualTo(0));
      },
    );

    test('the Undertow dives out of reach, heals, then surges', () {
      // The Undertow is level 2's guest, on wave 20.
      final g = Game(const GameConfig(level: 2, seed: 3));
      g.wave = 19;
      g.startNextWave();
      expect(g.boss!.boss!.id, 'undertow');
      final b = g.boss!;
      b.hp = b.maxHp * 0.5;
      advance(g, 4.1);
      expect(b.submerged, isTrue);
      final hpBefore = b.hp;
      advance(g, 2.5);
      expect(b.submerged, isFalse);
      expect(b.hp, greaterThan(hpBefore));
      expect(b.surgeT, greaterThan(0));
    });

    test('the Landlord shields and calls four Bailiffs at 66% and 33%', () {
      final g = gameAtBoss(kFinalWave);
      final b = g.boss!;
      b.hp = b.maxHp * 0.6;
      advance(g, 0.1);
      expect(b.phase, 1);
      expect(b.shield, closeTo(b.maxHp * 0.15, 1e-6));
      expect(g.enemies.where((e) => e.def?.id == 'bailiff').length, 4);
      b.hp = b.maxHp * 0.3;
      advance(g, 0.1);
      expect(b.phase, 2);
      expect(g.enemies.where((e) => e.def?.id == 'bailiff').length, 8);
    });

    test('the Landlord takes 15% of everyone\'s pennies each lap', () {
      final g = gameAtBoss(kFinalWave);
      g.you.pennies = 1000;
      g.update(0.02);
      g.boss!.traveled = g.field.cycle - 0.001;
      advance(g, 0.1);
      expect(g.you.pennies, 850);
    });

    test(
      'beating a boss pays 3 leaves and 40 pennies; the last one wins the run',
      () {
        // Solo, so the boss starts next to your board.
        final g = gameAtBoss(10, mode: GameMode.solo);
        final leaves = g.you.leaves;
        g.update(0.02);
        for (final b in g.bossList) {
          b.hp = 0.0001;
        }
        fillBoard(g.you);
        advance(g, 3);
        expect(g.boss, isNull);
        expect(g.bossesKilled, 1);
        expect(g.you.leaves, greaterThanOrEqualTo(leaves + 3));
        expect(g.status, GameStatus.playing);

        final last = gameAtBoss(kFinalWave, mode: GameMode.solo);
        last.update(0.02);
        for (final b in last.bossList) {
          b
            ..hp = 0.0001
            ..phase = 2; // past both shield phases
        }
        fillBoard(last.you);
        advance(last, 3);
        expect(last.status, GameStatus.won);
      },
    );
  });
}

extension on PlayerSide {
  double sideDpsOf(Game g) => g.sideDps(this);
}

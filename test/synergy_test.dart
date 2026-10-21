// Bonds, full stacks and the house rules (hoard, interest, clean sweep,
// quick kill).

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

import 'helpers.dart';

void put(PlayerSide p, int cell, String id, {int n = 1}) {
  for (var i = 0; i < n; i++) {
    p.cells[cell].units.add(UnitInst(kUnitById[id]!, 9000 + cell * 10 + i, 0));
  }
}

void main() {
  group('bond data', () {
    test('every bond names two different, real, non-Mythic figurines', () {
      for (final b in kBonds) {
        expect(kUnitById[b.a], isNotNull, reason: b.name);
        expect(kUnitById[b.b], isNotNull, reason: b.name);
        expect(b.a, isNot(b.b), reason: b.name);
        expect(kUnitById[b.a]!.tier, isNot(Tier.mythic), reason: b.name);
        expect(kUnitById[b.b]!.tier, isNot(Tier.mythic), reason: b.name);
      }
    });

    test('bond names and pairs are unique', () {
      expect(kBonds.map((b) => b.name).toSet().length, kBonds.length);
      final pairs = kBonds.map((b) => ([b.a, b.b]..sort()).join('+'));
      expect(pairs.toSet().length, kBonds.length);
    });

    test('each bond explains itself in one short line', () {
      for (final b in kBonds) {
        expect(b.effect, startsWith('both '), reason: b.name);
        expect(b.effect.length, lessThan(80), reason: b.name);
        expect(b.effect, isNot(contains('\n')));
      }
    });

    test('at least one bond is open to Commons, so it shows up early', () {
      expect(
        kBonds.any(
          (b) =>
              kUnitById[b.a]!.tier == Tier.common &&
              kUnitById[b.b]!.tier == Tier.common,
        ),
        isTrue,
      );
    });

    test('cells touch sideways, up and down and on the diagonal', () {
      expect(cellsTouch(0, 1), isTrue);
      expect(cellsTouch(0, kBoardCols), isTrue);
      expect(cellsTouch(0, kBoardCols + 1), isTrue);
      expect(cellsTouch(0, 2), isFalse);
      expect(cellsTouch(kBoardCols - 1, kBoardCols), isFalse); // row wrap
      expect(cellsTouch(3, 3), isFalse);
    });
  });

  group('bonds on the board', () {
    test('a pair in touching cells switches its bond on for both', () {
      final g = Game(const GameConfig(seed: 1));
      final p = g.you;
      put(p, 0, 'gull');
      put(p, 1, 'rock');
      g.refreshBonds(p);
      expect(p.bonds.map((b) => b.def.name), ['Chip Shop']);
      expect(p.bondMods[0]!.dmg, closeTo(0.15, 1e-9));
      expect(p.bondMods[1]!.dmg, closeTo(0.15, 1e-9));
      expect(p.bondMods[2], isNull);
    });

    test('the same pair far apart does nothing', () {
      final g = Game(const GameConfig(seed: 1));
      final p = g.you;
      put(p, 0, 'gull');
      put(p, 5, 'rock');
      g.refreshBonds(p);
      expect(p.bonds, isEmpty);
    });

    test('diagonal neighbours bond, and one cell can hold two bonds', () {
      final g = Game(const GameConfig(seed: 1));
      final p = g.you;
      put(p, kBoardCols + 1, 'gull');
      put(p, 0, 'rock'); // diagonal
      put(p, 2, 'admiral'); // diagonal the other way
      g.refreshBonds(p);
      expect(p.bonds.map((b) => b.def.name).toSet(), {
        'Chip Shop',
        'Flight Line',
      });
      final m = p.bondMods[kBoardCols + 1]!;
      expect(m.dmg, closeTo(0.15, 1e-9));
      expect(m.spd, closeTo(0.2, 1e-9));
    });

    test('a bonded pair deals more damage than the same pair apart', () {
      double damageDone(bool together) {
        final g = Game(const GameConfig(seed: 4));
        final p = g.you;
        put(p, 0, 'dave', n: 2);
        put(p, together ? 1 : 5, 'lou', n: 2);
        // Tough dummies all the way round the loop, so every cell has
        // something in range the whole time.
        for (var i = 0; i < 60; i++) {
          g.enemies.add(
            Enemy(
              i,
              kEnemyById['drip'],
              null,
              1e9,
              g.field.lap * i / 60,
              0,
              0,
              0,
            ),
          );
        }
        advance(g, 6);
        return g.enemies.fold(0.0, (a, e) => a + (e.maxHp - e.hp));
      }

      expect(damageDone(true), greaterThan(damageDone(false) * 1.1));
    });

    test('the Severer cut switches every bond off until it ends', () {
      final g = Game(const GameConfig(seed: 1));
      final p = g.you;
      put(p, 0, 'gull');
      put(p, 1, 'rock');
      g.bondsCut = 3;
      g.refreshBonds(p);
      expect(p.bonds, isEmpty);
      expect(p.bondsWaiting, hasLength(1));
      g.bondsCut = 0;
      g.refreshBonds(p);
      expect(p.bonds, hasLength(1));
    });
  });

  group('house rules', () {
    test('every rule fits on one short line', () {
      expect(kHouseRules.length, greaterThanOrEqualTo(5));
      for (final r in kHouseRules) {
        expect(r.line.length, lessThan(90), reason: r.name);
        expect(r.line, isNot(contains('\n')));
      }
    });

    test('hoard: 2% damage per 100 pennies held, capped at 10%', () {
      expect(hoardTier(0), 0);
      expect(hoardTier(99), 0);
      expect(hoardTier(250), 2);
      expect(hoardTier(5000), kHoardTiers);
      final g = Game(const GameConfig(seed: 1));
      final p = g.you;
      final d = kUnitById['lou']!;
      p.pennies = 0;
      final base = g.dmgMult(p, d);
      p.pennies = 300;
      expect(g.dmgMult(p, d) / base, closeTo(1.06, 1e-9));
      p.pennies = 9999;
      expect(g.dmgMult(p, d) / base, closeTo(1.10, 1e-9));
    });

    test('interest: 1 penny per 40 held at each wave start, up to 6', () {
      expect(interestFor(39), 0);
      expect(interestFor(200), 5);
      expect(interestFor(10000), kInterestMax);
      final g = Game(const GameConfig(seed: 1));
      final p = g.you;
      p.pennies = 200;
      g.startNextWave(); // wave 1: no clean sweep on the first wave
      expect(p.pennies, 205 + waveWages(1));
      expect(p.interestPaid, 5);
    });

    test('clean sweep pays when few riftlings are out at a wave start', () {
      final g = Game(const GameConfig(seed: 1));
      final p = g.you;
      g.startNextWave();
      g.enemies.clear();
      p.pennies = 0;
      g.startNextWave();
      expect(p.pennies, kCleanSweepPay + waveWages(2));
      expect(p.sweeps, 1);
    });

    test('no clean sweep with a crowded lane', () {
      final g = Game(const GameConfig(seed: 1));
      final p = g.you;
      g.startNextWave();
      advance(g, 14);
      expect(
        g.enemies.where((e) => !e.dead).length,
        greaterThan(kCleanSweepMax),
      );
      p.pennies = 0;
      g.startNextWave();
      expect(p.sweeps, 0);
    });

    test('quick kill pays when a boss falls with half its timer left', () {
      final g = gameAtBoss(10);
      final before = g.you.pennies;
      for (final b in [...g.bossList]) {
        b.hp = 1;
      }
      fillBoard(g.you);
      advance(g, 3);
      expect(g.bossList.where((b) => !b.dead), isEmpty);
      expect(g.you.quickKills, 1);
      expect(g.you.pennies - before, greaterThanOrEqualTo(kQuickKillPay));
    });

    test('full stack: three of a kind attack faster, two do not', () {
      final g = Game(const GameConfig(seed: 1));
      final p = g.you;
      put(p, 0, 'gull', n: 2);
      expect(g.fullStackBonus(p.cells[0]), 0);
      put(p, 0, 'gull');
      expect(g.fullStackBonus(p.cells[0]), kFullStackSpeed);
    });
  });
}

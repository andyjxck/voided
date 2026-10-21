// The six riftlings and four bosses added with bonds and house rules.

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

const newRiftlings = [
  'leech',
  'bulwark',
  'plated',
  'revenant',
  'drummer',
  'burrower',
];

const newBosses = ['auditor', 'severer', 'hollowchoir', 'colossus'];

Game fresh() => Game(const GameConfig(seed: 3));

void put(PlayerSide p, int cell, String id) {
  p.cells[cell].units.add(UnitInst(kUnitById[id]!, 8000 + cell, 0));
}

int countOf(Game g, String id) =>
    g.enemies.where((e) => !e.dead && e.def?.id == id).length;

void main() {
  group('roster', () {
    test('every new riftling exists and turns up in at least one level', () {
      for (final id in newRiftlings) {
        expect(kEnemyById[id], isNotNull, reason: id);
        final levels = kLevelRoster.values.where((r) => r.containsKey(id));
        expect(levels, isNotEmpty, reason: id);
        for (final r in levels) {
          expect(r[id], inInclusiveRange(2, 50), reason: id);
        }
      }
    });

    test('every new boss is a guest of a level and spawns real riftlings', () {
      final guests = kLevels.map((l) => l.guest).toSet();
      for (final id in newBosses) {
        final b = kBossById[id];
        expect(b, isNotNull, reason: id);
        expect(guests, contains(id), reason: id);
        expect(kEnemyById[b!.spawn], isNotNull, reason: id);
        expect(b.mechText, isNotEmpty, reason: id);
      }
    });

    test('new riftlings explain themselves in their blurb', () {
      for (final id in newRiftlings) {
        expect(kEnemyById[id]!.blurb.length, greaterThan(20), reason: id);
      }
    });
  });

  group('riftlings', () {
    test('Hoard Leech switches Hoard off while it lives', () {
      final g = fresh();
      final p = g.you;
      p.pennies = 500;
      expect(g.hoardBonus(p), greaterThan(0));
      final l = g.debugSpawn('leech', s: 3);
      expect(g.hoardBlocked, isTrue);
      expect(g.hoardBonus(p), 0);
      g.debugHit(l, l.maxHp * 10);
      expect(l.dead, isTrue);
      expect(g.hoardBlocked, isFalse);
      expect(g.hoardBonus(p), greaterThan(0));
    });

    test('Rift Bulwark shields riftlings near it, not far ones or itself', () {
      final g = fresh();
      final w = g.debugSpawn('bulwark', s: 5);
      final near = g.debugSpawn('drip', s: 5.3);
      final far = g.debugSpawn('drip', s: 15);
      g.debugTraitSpeed(w, 0.1);
      expect(near.shield, 0);
      g.debugTraitSpeed(w, 5);
      expect(near.shield, closeTo(near.maxHp * 0.12, 1e-6));
      expect(far.shield, 0);
      expect(w.shield, 0);
    });

    test('the Bulwark shield soaks a hit before health', () {
      final g = fresh();
      final w = g.debugSpawn('bulwark', s: 5);
      final near = g.debugSpawn('drip', s: 5.2);
      g.debugTraitSpeed(w, 5.1);
      final shield = near.shield;
      g.debugHit(near, shield / 2);
      expect(near.hp, near.maxHp);
      expect(near.shield, closeTo(shield / 2, 1e-6));
    });

    test('Glass Grub: no single hit takes more than 8%', () {
      final g = fresh();
      final e = g.debugSpawn('plated', s: 2);
      g.debugHit(e, e.maxHp * 100);
      expect(e.dead, isFalse);
      expect(e.hp, closeTo(e.maxHp * 0.92, 1e-6));
      final before = e.hp;
      g.debugHit(e, e.maxHp * 0.01);
      expect(e.hp, closeTo(before - e.maxHp * 0.01, 1e-6));
      for (var i = 0; i < 12; i++) {
        g.debugHit(e, e.maxHp * 100);
      }
      expect(e.dead, isTrue);
    });

    test('Twice-Drowned gets back up once at 40% after a single hit', () {
      final g = fresh();
      final e = g.debugSpawn('revenant', s: 2);
      g.debugHit(e, e.maxHp * 2);
      expect(e.dead, isFalse);
      expect(e.hp, closeTo(e.maxHp * 0.4, 1e-6));
      expect(e.stunT, greaterThan(0));
      g.debugHit(e, e.maxHp * 2);
      expect(e.dead, isTrue);
    });

    test('area damage puts the Twice-Drowned down for good', () {
      final g = fresh();
      final e = g.debugSpawn('revenant', s: 2);
      g.debugHit(e, e.maxHp * 2, area: true);
      expect(e.dead, isTrue);
    });

    test('Rift Drummer speeds up riftlings close to it on its route', () {
      final g = fresh();
      final near = g.debugSpawn('drip', s: 5);
      final far = g.debugSpawn('drip', s: 12);
      g.debugMechTick(0.01);
      final nearBase = g.debugTraitSpeed(near, 0.01);
      final farBase = g.debugTraitSpeed(far, 0.01);
      final dr = g.debugSpawn('drummer', s: 5.5);
      g.debugMechTick(0.01);
      expect(g.debugTraitSpeed(near, 0.01), closeTo(nearBase * 1.25, 1e-6));
      expect(g.debugTraitSpeed(far, 0.01), closeTo(farBase, 1e-6));
      g.debugHit(dr, dr.maxHp * 10);
      g.debugMechTick(0.01);
      expect(g.debugTraitSpeed(near, 0.01), closeTo(nearBase, 1e-6));
    });

    test('Rift Mole digs under every 5s: out of reach and twice as fast', () {
      final g = fresh();
      final m = g.debugSpawn('burrower', s: 3);
      final base = g.debugTraitSpeed(m, 0.1);
      expect(m.tunnelT, 0);
      var dugAt = -1;
      var fast = 0.0;
      for (var i = 1; i <= 60; i++) {
        final sp = g.debugTraitSpeed(m, 0.1);
        if (m.tunnelT > 0 && dugAt < 0) {
          dugAt = i;
          fast = sp;
        }
      }
      expect(dugAt, inInclusiveRange(48, 50));
      expect(fast, closeTo(base * 2, 1e-6));
      final m2 = g.debugSpawn('burrower', s: 8);
      g.debugTraitSpeed(m2, 5.01);
      expect(m2.tunnelT, greaterThan(0));
      for (var i = 0; i < 16; i++) {
        g.debugTraitSpeed(m2, 0.1);
      }
      expect(m2.tunnelT, lessThanOrEqualTo(0));
    });
  });

  group('bosses', () {
    test('The Auditor blocks Hoard and takes a tenth of pennies, max 25', () {
      final g = fresh();
      g.sides[0].pennies = 500;
      if (g.sides.length > 1) g.sides[1].pennies = 120;
      final b = g.debugSpawnBoss('auditor', s: 2);
      expect(g.hoardBlocked, isTrue);
      g.debugBossTick(b, 4.01);
      expect(g.sides[0].pennies, 475);
      if (g.sides.length > 1) expect(g.sides[1].pennies, 108);
      g.debugBossTick(b, 4);
      expect(g.sides[0].pennies, 475);
      g.debugBossTick(b, 5.01);
      expect(g.sides[0].pennies, 450);
      g.debugHit(b, b.maxHp * 10);
      expect(b.dead, isTrue);
      expect(g.hoardBlocked, isFalse);
    });

    test('The Severer warns, then cuts every bond for 5s', () {
      final g = fresh();
      final p = g.you;
      put(p, 0, 'gull');
      put(p, 1, 'rock');
      g.refreshBonds(p);
      expect(p.bonds, isNotEmpty);
      final b = g.debugSpawnBoss('severer', s: 2);
      final tellsBefore = g.tells.length;
      g.debugBossTick(b, 2.5);
      expect(g.tells.length, greaterThan(tellsBefore));
      expect(g.bondsCut, 0);
      g.debugBossTick(b, 1.6);
      expect(g.bondsCut, closeTo(5, 1e-9));
      g.refreshBonds(p);
      expect(p.bonds, isEmpty);
      expect(p.bondsWaiting, isNotEmpty);
      g.debugMechTick(5.01);
      expect(g.bondsCut, 0);
      g.refreshBonds(p);
      expect(p.bonds, isNotEmpty);
    });

    test('The Hollow Choir raises three Twice-Drowned every 10s', () {
      final g = fresh();
      final b = g.debugSpawnBoss('hollowchoir', s: 4);
      expect(countOf(g, 'revenant'), 0);
      g.debugBossTick(b, 4.01);
      g.debugSpawn('drip', s: 0);
      expect(countOf(g, 'revenant'), 3);
      g.debugBossTick(b, 9);
      g.debugSpawn('drip', s: 0);
      expect(countOf(g, 'revenant'), 3);
      g.debugBossTick(b, 1.01);
      g.debugSpawn('drip', s: 0);
      expect(countOf(g, 'revenant'), 6);
    });

    test('The Glass Colossus: 3% cap on each hit, sheds two Glass Grubs', () {
      final g = fresh();
      final b = g.debugSpawnBoss('colossus', s: 4);
      g.debugHit(b, b.maxHp * 100);
      expect(b.dead, isFalse);
      expect(b.hp, closeTo(b.maxHp * 0.97, 1e-6));
      g.debugBossTick(b, 4.01);
      g.debugSpawn('drip', s: 0);
      expect(countOf(g, 'plated'), 2);
      g.debugBossTick(b, 12.01);
      g.debugSpawn('drip', s: 0);
      expect(countOf(g, 'plated'), 4);
    });
  });
}

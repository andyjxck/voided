// The six Mythics added with bonds and house rules.

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

import 'helpers.dart';

const newMythics = [
  'matchmaker',
  'tollkeeper',
  'murmuration',
  'foreman',
  'pearl',
  'choir',
];

void put(PlayerSide p, int cell, String id) {
  p.cells[cell].units.add(UnitInst(kUnitById[id]!, 8000 + cell, 0));
}

void main() {
  test('there are now 18 Mythics, each with a recipe', () {
    final mythics = kUnits.where((u) => u.tier == Tier.mythic).toList();
    expect(mythics, hasLength(18));
    for (final m in mythics) {
      expect(kRecipes[m.id], isNotNull, reason: m.id);
    }
  });

  test('each new recipe takes a Legendary and two lesser figurines', () {
    for (final id in newMythics) {
      final r = kRecipes[id]!;
      expect(r, hasLength(3), reason: id);
      final tiers = r.map((x) => kUnitById[x]!.tier).toList();
      expect(tiers.where((t) => t == Tier.legendary), hasLength(1), reason: id);
      expect(tiers, isNot(contains(Tier.mythic)), reason: id);
    }
  });

  test('no two Mythics share the same recipe', () {
    final sets = kRecipes.values.map((r) => ([...r]..sort()).join('+'));
    expect(sets.toSet().length, kRecipes.length);
  });

  test('each new Mythic can be crafted from its recipe', () {
    for (final id in newMythics) {
      final g = Game(const GameConfig(seed: 3));
      final p = g.you;
      var cell = 0;
      for (final ing in kRecipes[id]!) {
        put(p, cell++, ing);
      }
      expect(g.canCraft(p, id), isTrue, reason: id);
      expect(g.craft(p, id).ok, isTrue, reason: id);
      expect(p.allUnits.map((u) => u.def.id), contains(id), reason: id);
    }
  });

  test('Mythic damage stays in the range of the old twelve', () {
    final old = kUnits
        .where((u) => u.tier == Tier.mythic && !newMythics.contains(u.id))
        .map((u) => u.dps);
    final lo = old.reduce((a, b) => a < b ? a : b);
    final hi = old.reduce((a, b) => a > b ? a : b);
    for (final id in newMythics) {
      final d = kUnitById[id]!;
      expect(d.dps, inInclusiveRange(lo * 0.8, hi * 1.1), reason: id);
    }
  });

  test('the Matchmaker doubles the bonds next to it', () {
    final g = Game(const GameConfig(seed: 1));
    final p = g.you;
    put(p, 0, 'gull');
    put(p, 1, 'rock');
    g.refreshBonds(p);
    expect(p.bondMods[0]!.dmg, closeTo(0.15, 1e-9));
    put(p, 2, 'matchmaker'); // touches the rock
    g.refreshBonds(p);
    expect(p.bonds.single.k, 2);
    expect(p.bondMods[0]!.dmg, closeTo(0.30, 1e-9));
  });

  test('the Tollkeeper takes pennies from a crowd in range', () {
    int earned(bool withToll) {
      final g = Game(const GameConfig(seed: 1));
      final p = g.you;
      put(p, 0, withToll ? 'tollkeeper' : 'gull');
      // Line the loop with tough dummies; some will sit in range.
      for (var i = 0; i < 80; i++) {
        g.enemies.add(
          Enemy(
            i,
            kEnemyById['drip'],
            null,
            1e9,
            g.field.lap * i / 80,
            0,
            0,
            0,
          ),
        );
      }
      p.pennies = 0;
      advance(g, 6.5);
      return p.pennies;
    }

    final toll = earned(true) - earned(false);
    expect(toll, greaterThan(0));
    expect(toll, lessThanOrEqualTo(6 * 2)); // at most 6 a go, two goes
  });

  test('the Night Foreman speeds up Staff near it', () {
    final g = Game(const GameConfig(seed: 1));
    final p = g.you;
    put(p, 1, 'dave');
    final before = g.speedBonus(p, 1, p.activeUnions());
    put(p, 0, 'foreman');
    final after = g.speedBonus(p, 1, p.activeUnions());
    expect(after - before, closeTo(0.3, 1e-9));
  });
}

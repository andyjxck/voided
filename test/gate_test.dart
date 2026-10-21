// The Hatch: everything climbs out of one spot in the middle and splits, one
// left and one right, on two lanes that never touch. Ported from the
// centre-gate spawning work (center-pair-spawns) onto the content plan's
// Hatch and twin system, where each Enemy carries its route.

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

import 'helpers.dart';

/// A game at the start of [wave], with nothing on the boards to kill
/// anything.
Game atWave(int wave, GameMode mode) {
  final g = Game(GameConfig(mode: mode, difficulty: Difficulty.calm, seed: 21));
  g.wave = wave - 1;
  g.startNextWave();
  return g;
}

List<int> perRoute(Iterable<Enemy> es) => [
      es.where((e) => e.route == 0).length,
      es.where((e) => e.route == 1).length,
    ];

void main() {
  group('geometry', () {
    test('co-op Hatch is the exact centre of the map', () {
      final f = Field(GameMode.coop);
      expect(f.gate.x, closeTo(f.w / 2, 1e-9));
      expect(f.gate.y, closeTo(f.h / 2, 1e-9));
    });

    for (final mode in GameMode.values) {
      test('${mode.name}: both routes leave the Hatch, one left, one right', () {
        final f = Field(mode);
        expect(f.routes, hasLength(2));
        for (var r = 0; r < 2; r++) {
          expect(f.posAt(0, r).dist(f.gate), lessThan(Field.laneGap));
        }
        expect(f.posAt(1, 0).x, lessThan(f.gate.x - 0.5));
        expect(f.posAt(1, 1).x, greaterThan(f.gate.x + 0.5));
      });

      test('${mode.name}: both loops are walked in the same lap', () {
        final f = Field(mode);
        final l0 = f.routeLength(0), l1 = f.routeLength(1);
        expect((l0 + l1) / 2, closeTo(f.lap, 1e-9));
        // Co-op loops are identical; solo's outside lane is a little longer.
        expect((l0 - l1).abs() / f.lap, lessThan(0.2));
        if (mode == GameMode.coop) expect(l0, closeTo(l1, 1e-9));
        for (var r = 0; r < 2; r++) {
          expect(f.posAt(0, r).dist(f.posAt(f.lap, r)), lessThan(1e-9));
          // Halfway through the lap is halfway round the loop.
          final half = f.posAt(f.lap / 2, r);
          var d = double.infinity;
          final pts = f.routes[r];
          // The point half a loop along, measured on the route itself.
          var acc = 0.0;
          for (var i = 0; i < pts.length; i++) {
            final a = pts[i], b = pts[(i + 1) % pts.length];
            final seg = a.dist(b);
            if (acc + seg >= f.routeLength(r) / 2) {
              final t = (f.routeLength(r) / 2 - acc) / seg;
              d = half.dist(V2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t));
              break;
            }
            acc += seg;
          }
          expect(d, lessThan(1e-9));
        }
      });

      test('${mode.name}: the two lanes never run on top of each other', () {
        final f = Field(mode);
        const n = 400;
        var closest = double.infinity;
        for (var i = 0; i < n; i++) {
          final a = f.posAt(f.lap * i / n, 0);
          for (var j = 0; j < n; j++) {
            final d = a.dist(f.posAt(f.lap * j / n, 1));
            if (d < closest) closest = d;
          }
        }
        expect(closest, greaterThanOrEqualTo(Field.laneGap - 0.02));
      });

      test('${mode.name}: lanes stay off the boards', () {
        final f = Field(mode);
        for (var r = 0; r < 2; r++) {
          for (var i = 0; i < 200; i++) {
            final p = f.posAt(f.lap * i / 200, r);
            for (var side = 0; side < (mode == GameMode.solo ? 1 : 2); side++) {
              final o = f.boardOrigin(side);
              final inside = p.x > o.x && p.x < o.x + kBoardCols &&
                  p.y > o.y && p.y < o.y + kBoardRows;
              expect(inside, isFalse);
            }
          }
        }
      });
    }

    test('co-op: route 0 goes round Brenda\'s board, route 1 round yours', () {
      final f = Field(GameMode.coop);
      final mid = f.h / 2;
      expect(f.posAt(f.lap / 2, 0).y, lessThan(mid - 2));
      expect(f.posAt(f.lap / 2, 1).y, greaterThan(mid + 2));
      expect(f.sideOfRoute(0), 1);
      expect(f.sideOfRoute(1), 0);
    });
  });

  group('pairs', () {
    for (final mode in GameMode.values) {
      test('${mode.name}: sea things come out in matching pairs', () {
        final g = atWave(1, mode);
        advance(g, 0.05);
        expect(g.enemies, hasLength(2));
        final a = g.enemies[0], b = g.enemies[1];
        expect(a.def!.id, b.def!.id);
        expect({a.route, b.route}, {0, 1});
        advance(g, 0.8);
        expect(g.enemies, hasLength(4));
      });

      test('${mode.name}: a wave splits evenly, each one on its own lane', () {
        final g = atWave(1, mode);
        advance(g, 40);
        final split = perRoute(g.enemies.where((e) => !e.dead));
        expect(split[0], split[1]);
        expect(split[0], greaterThan(4));
        for (final e in g.enemies) {
          expect(g.field.at(e).dist(g.field.posAt(e.s, e.route)), 0);
        }
      });

      test('${mode.name}: twins head opposite ways from the Hatch', () {
        final g = atWave(1, mode);
        advance(g, 1.0);
        final first = g.enemies.take(2).toList();
        final left = first.firstWhere((e) => e.route == 0);
        final right = first.firstWhere((e) => e.route == 1);
        expect(g.field.at(left).x, lessThan(g.field.gate.x));
        expect(g.field.at(right).x, greaterThan(g.field.gate.x));
      });
    }
  });

  group('twin bosses', () {
    for (final mode in GameMode.values) {
      test('${mode.name}: two of the boss, one each way', () {
        final g = gameAtBoss(10, mode: mode);
        advance(g, 0.05);
        expect(g.bosses, hasLength(2));
        expect(g.enemies.where((e) => e.isBoss), hasLength(2));
        expect(g.bosses.map((b) => b.route).toSet(), {0, 1});
        expect(g.boss, same(g.bosses.firstWhere((b) => b.twinLead)));
        advance(g, 1);
        final l = g.bosses.firstWhere((b) => b.route == 0);
        final r = g.bosses.firstWhere((b) => b.route == 1);
        expect(g.field.at(l).x, lessThan(g.field.gate.x));
        expect(g.field.at(r).x, greaterThan(g.field.gate.x));
      });
    }

    test('helpers a boss calls in walk behind their own twin', () {
      final g = gameAtBoss(10);
      advance(g, 10.3);
      final helpers = g.enemies.where((e) => !e.isBoss).toList();
      expect(helpers, isNotEmpty);
      final split = perRoute(helpers);
      expect(split[0], split[1]);
    });

    test('the wave isn\'t over until both twins are down', () {
      final g = gameAtBoss(10, mode: GameMode.solo);
      final wave = g.wave;
      advance(g, 0.05);
      final lead = g.bosses.firstWhere((b) => b.twinLead);
      final other = g.bosses.firstWhere((b) => !b.twinLead);
      other.hp = 0;
      other.dead = true;
      g.enemies.remove(other);
      advance(g, 3);
      expect(g.boss, same(lead));
      expect(g.wave, wave);
      expect(g.status, GameStatus.playing);
    });

    test('the timer runs out if either twin is still standing', () {
      final g = gameAtBoss(10);
      advance(g, 0.05);
      final lead = g.bosses.firstWhere((b) => b.twinLead);
      lead.hp = 0;
      lead.dead = true;
      g.enemies.remove(lead);
      advance(g, kBossSeconds + 1);
      expect(g.status, GameStatus.lost);
    });
  });
}

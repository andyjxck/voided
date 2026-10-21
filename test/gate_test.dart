// The centre gate: everything comes out of one gate and splits, one left and
// one right. Pairs, the odd one out, twin bosses and the two lanes.

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

void main() {
  group('geometry', () {
    test('co-op gate is the exact centre of the map', () {
      final f = Field(GameMode.coop);
      expect(f.gate.x, closeTo(f.w / 2, 1e-9));
      expect(f.gate.y, closeTo(f.h / 2, 1e-9));
    });

    for (final mode in GameMode.values) {
      test('${mode.name}: both routes leave the gate, one left, one right', () {
        final f = Field(mode);
        expect(f.routeCount, 2);
        for (var r = 0; r < 2; r++) {
          final start = f.posAt(f.routeBase(r));
          expect(start.dist(f.gate), lessThan(Field.laneGap));
        }
        final left = f.posAt(f.routeBase(0) + 1);
        final right = f.posAt(f.routeBase(1) + 1);
        expect(left.x, lessThan(f.gate.x - 0.5));
        expect(right.x, greaterThan(f.gate.x + 0.5));
      });

      test('${mode.name}: both loops are walked in the same lap', () {
        final f = Field(mode);
        double length(List<V2> pts) {
          var d = 0.0;
          for (var i = 0; i < pts.length; i++) {
            d += pts[i].dist(pts[(i + 1) % pts.length]);
          }
          return d;
        }

        final l0 = length(f.routes[0]), l1 = length(f.routes[1]);
        expect((l0 + l1) / 2, closeTo(f.lap, 1e-9));
        // Co-op loops are identical in length; solo's outside lane is about
        // an eighth longer than the inside one.
        expect((l0 - l1).abs() / f.lap, lessThan(0.15));
        if (mode == GameMode.coop) expect(l0, closeTo(l1, 1e-9));
        // Back at the gate after one lap.
        for (var r = 0; r < 2; r++) {
          expect(
            f.posAt(f.routeBase(r)).dist(f.posAt(f.routeBase(r) + f.lap)),
            lessThan(1e-9),
          );
        }
      });

      test('${mode.name}: the two lanes never run on top of each other', () {
        final f = Field(mode);
        const n = 400;
        var closest = double.infinity;
        for (var i = 0; i < n; i++) {
          final a = f.posAt(f.routeBase(0) + f.lap * i / n);
          for (var j = 0; j < n; j++) {
            final b = f.posAt(f.routeBase(1) + f.lap * j / n);
            final d = a.dist(b);
            if (d < closest) closest = d;
          }
        }
        expect(closest, greaterThanOrEqualTo(Field.laneGap - 0.02));
      });

      test('${mode.name}: s % lap still means distance round the loop', () {
        final f = Field(mode);
        for (var r = 0; r < 2; r++) {
          final s = f.routeBase(r) + 3.25;
          expect(s % f.lap, closeTo(3.25, 1e-6));
          expect(f.routeOf(s), r);
          // A little behind the gate stays on the same route.
          expect(f.routeOf(f.routeBase(r) - 0.3), r);
          expect(
            f
                .posAt(f.routeBase(r) - 0.3)
                .dist(f.posAt(f.routeBase(r) + f.lap - 0.3)),
            lessThan(1e-9),
          );
        }
      });
    }

    test('co-op: left goes round your board, right round Brenda\'s', () {
      final f = Field(GameMode.coop);
      final mid = f.h / 2;
      // Halfway round each loop is the far side of its board.
      expect(f.posAt(f.routeBase(0) + f.lap / 2).y, greaterThan(mid + 2));
      expect(f.posAt(f.routeBase(1) + f.lap / 2).y, lessThan(mid - 2));
      expect(f.boardOfRoute(0), 0);
      expect(f.boardOfRoute(1), 1);
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
        expect({g.field.routeOf(a.s), g.field.routeOf(b.s)}, {0, 1});
        // The next pair comes two singles' worth of time later.
        advance(g, kSpawnGap * 2 - 0.1);
        expect(g.enemies, hasLength(2));
        advance(g, 0.15);
        expect(g.enemies, hasLength(4));
      });

      test(
        '${mode.name}: an even wave has the same head count, split evenly',
        () {
          final g = atWave(1, mode);
          final n = spawnCount(1);
          expect(n.isEven, isTrue);
          advance(g, n * kSpawnGap + 0.5);
          expect(g.enemies, hasLength(n));
          expect(g.laneCountByRoute(), [n ~/ 2, n ~/ 2]);
        },
      );

      test('${mode.name}: an odd wave lets the odd one out walk alone', () {
        final g = atWave(3, mode);
        final n = spawnCount(3);
        expect(n.isOdd, isTrue);
        advance(g, n * kSpawnGap + 0.5);
        expect(g.enemies, hasLength(n));
        final split = g.laneCountByRoute();
        expect(split[0] + split[1], n);
        expect((split[0] - split[1]).abs(), 1);
      });
    }

    test('the mini-boss walks alone and is not doubled', () {
      final g = atWave(5, GameMode.coop);
      advance(g, spawnCount(5) * kSpawnGap + 1.5);
      expect(g.enemies.where((e) => e.def!.id == 'bigdrip'), hasLength(1));
      expect(g.enemies, hasLength(spawnCount(5) + 1));
    });

    test('the odd ones out take turns, so neither side always gets them', () {
      final g = atWave(3, GameMode.coop);
      advance(g, spawnCount(3) * kSpawnGap + 0.5);
      final first = g.laneCountByRoute();
      g.enemies.clear();
      g.wave = 4;
      g.startNextWave(); // wave 5: 17 regulars plus the mini-boss, both single
      advance(g, (spawnCount(5) + 1) * kSpawnGap + 1);
      final second = g.laneCountByRoute();
      expect(first[0] - first[1], isNot(0));
      // Wave 5's two singles go one each way after wave 3's single.
      expect(second[0] - second[1], 0);
    });
  });

  group('twin bosses', () {
    for (final mode in GameMode.values) {
      test('${mode.name}: two of the boss, one each way', () {
        final g = gameAtBoss(10, mode: mode);
        expect(g.bosses, hasLength(2));
        expect(g.enemies.where((e) => e.isBoss), hasLength(2));
        expect(g.bosses.map((b) => g.field.routeOf(b.s)).toSet(), {0, 1});
        expect(g.boss, same(g.bosses.first));
        advance(g, 1);
        expect(g.bosses[0].pos(g).x, lessThan(g.field.gate.x));
        expect(g.bosses[1].pos(g).x, greaterThan(g.field.gate.x));
      });
    }

    test('Mother Brine\'s Drips come out behind their own twin', () {
      final g = gameAtBoss(10);
      advance(g, 10.3);
      final drips = g.enemies.where((e) => e.def?.id == 'drip').toList();
      expect(drips, hasLength(6));
      expect(drips.where((d) => g.field.routeOf(d.s) == 0), hasLength(3));
      expect(drips.where((d) => g.field.routeOf(d.s) == 1), hasLength(3));
    });

    test('the wave isn\'t over until both twins are down', () {
      final g = gameAtBoss(10, mode: GameMode.solo);
      final wave = g.wave;
      g.bosses[1].hp = 0.0001;
      fillBoard(g.you);
      advance(g, 3);
      expect(g.bosses[1].dead, isTrue);
      expect(g.boss, same(g.bosses[0]));
      expect(g.wave, wave);
      expect(g.bossesKilled, 0);
    });

    test('the timer runs out if either twin is still standing', () {
      final g = gameAtBoss(10);
      g.bosses[0].hp = 0;
      g.bosses[0].dead = true;
      g.enemies.remove(g.bosses[0]);
      g.boss = g.bosses[1];
      advance(g, kBossSeconds + 1);
      expect(g.status, GameStatus.lost);
    });
  });
}

extension on Enemy {
  V2 pos(Game g) => g.field.posAt(s);
}
